create or replace PACKAGE BODY ttec_kr_otl_time_outbound AS
  /* $Header: TTEC_KR_PERSON_OUTBOUND.pkb 1.3 2010/05/20 mdodge ship $ */

  /*== START ================================================================================================*\
     Author: Michelle Dodge
       Date: 12/28/2009
  Call From:
         Desc: This is the package for the Kronos Time Outbound process.  It provides
             the time data of PSA Employees from OTL to the Kronos application for
             processing Payroll.

             This package is built by referencing existing Kronos processes for person
             and accrual processes

             a.Identify PSA Employees using the assignment level DFF
             b.Ignore contingent workers
             c.Pass data for past 45 days
             d.Merely dump data into the custom table. Kronos has inbuilt logic to
             identify new rows/changed rows etc
             e.Cost Allocation - Logic to find Location code is simialr to Person
             Kronos Interface
    Modification History:

   Version  Date      Author        Description (Include Ticket#)
   -------  --------  ------------  ------------------------------------------------------------------------------
       1.0  09/23/14  Lalitha       PSA OTL to Kronos Project :  Initial Version.
       1.4  06/21/2022 Neelofar     Added condition to exclude AU and NZ Employees
       1.5  10/10/2022 Neelofar     Rollback of Cloud Migration project
	   1.0  18/MAY/2023 RXNETHI-ARGANO  R12.2 Upgrade Remediation
  \*== END ==================================================================================================*/
  --g_kr_time_data cust.ttec_kr_time_master%ROWTYPE;   --code commented by RXNETHI-ARGANO,17/05/23
  g_kr_time_data apps.ttec_kr_time_master%ROWTYPE;     --code added by RXNETHI-ARGANO,17/05/23

  -- Error Constants
  /*
  START R12.2 Upgrade Remediation
  code commented by RXNETHI-ARGANO,17/05/23
  g_label1    cust.ttec_error_handling.label1%TYPE := 'Err Location';
  g_label2    cust.ttec_error_handling.label1%TYPE := 'Emp_Number';
  */
  --code added by RXNETHI-ARGANO,17/05/23
  g_label1    apps.ttec_error_handling.label1%TYPE := 'Err Location';
  g_label2    apps.ttec_error_handling.label1%TYPE := 'Emp_Number';
  --END R12.2 Upgrade Remediation
  g_keep_days NUMBER := 7;

  -- Number of days to keep error logging.
  g_keep_run_times NUMBER := 90;

  -- Number of days to keep process run times

  -- Process FAILURE variables
  g_fail_flag BOOLEAN := FALSE;
  g_fail_msg  VARCHAR2(240);

  -- Global Count Variables for logging information
  g_records_read      NUMBER := 0;
  g_records_processed NUMBER := 0;
  g_records_errored   NUMBER := 0;
  g_commit_count      NUMBER := 0;

  -- declare commit counter
  g_commit_point NUMBER := 100;

  -- declare who columns
  g_request_id NUMBER := fnd_global.conc_request_id;
  g_created_by NUMBER := fnd_global.user_id;

  -- declare exceptions
  error_record EXCEPTION;
  term_record EXCEPTION;

  /*********************************************************
  **  Private Procedures and Functions
  *********************************************************/

  /************************************************************************************/
  /*                               TRUNCATE truncate_kr_time_master TABLE PROCEDURE                  */
  /*  This procedure prepares the Time Master tables for the data set that is about to */
  /*  be processed.  It clears the Time Master Backup table of the data set.  It then  */
  /*  copies all records for the data set from the Time Master to the Time Master       */
  /*  backup table and deletes them from the Time Master.                              */
  /************************************************************************************/
  PROCEDURE truncate_kr_time_master(p_business_group_id IN NUMBER,
                                    p_bucket_number     IN NUMBER,
                                    p_buckets           IN NUMBER) IS
    --v_module cust.ttec_error_handling.module_name%TYPE := 'truncate_kr_time_master';   --code commented by RXNETHI-ARGANO,17/05/23
    v_module apps.ttec_error_handling.module_name%TYPE := 'truncate_kr_time_master';     --code added by RXNETHI-ARGANO,17/05/23
    v_loc    NUMBER;
  BEGIN
    v_loc := 10;

    --Remove records from the backup table that you are about to process.
    --DELETE cust.ttec_kr_time_master_bk   --code commented by RXNETHI-ARGANO,17/05/23
    DELETE apps.ttec_kr_time_master_bk     --code added by RXNETHI-ARGANO,17/05/23
     WHERE business_group_id = NVL(p_business_group_id, business_group_id)
       AND MOD(employee_number, NVL(p_buckets, 1)) =
           NVL(p_bucket_number, 0);

    v_loc := 20;

    --Move records from the master to backup table that you are about to process.
    --INSERT INTO cust.ttec_kr_time_master_bk   --code commented by RXNETHI-ARGANO,17/05/23
    INSERT INTO apps.ttec_kr_time_master_bk     --code added by RXNETHI-ARGANO,17/05/23
      (SELECT *
         --FROM cust.ttec_kr_time_master   --code commented by RXNETHI-ARGANO,17/05/23
         FROM apps.ttec_kr_time_master     --code added by RXNETHI-ARGANO,17/05/23
        WHERE business_group_id =
              NVL(p_business_group_id, business_group_id)
                           /*  and business_group_id not in (select lookup_code from fnd_lookup_values
													where lookup_type = 'TTEC_EBS_DECOMMISION_COUNTRY'
													and language = 'US') -- Added as part of Cloud Migration v1.4*/--1.5
          AND MOD(employee_number, NVL(p_buckets, 1)) =
              NVL(p_bucket_number, 0));

    v_loc := 30;

    --Delete the master records for the bucket being processed.
    --DELETE cust.ttec_kr_time_master    --code commented by RXNETHI-ARGANO,17/05/23
    DELETE apps.ttec_kr_time_master      --code added by RXNETHI-ARGANO,17/05/23
     WHERE business_group_id = NVL(p_business_group_id, business_group_id)
       AND MOD(employee_number, NVL(p_buckets, 1)) =
           NVL(p_bucket_number, 0);

    COMMIT;
  EXCEPTION
    WHEN OTHERS THEN
      ttec_error_logging.process_error(g_application_code,
                                       g_interface,
                                       g_package,
                                       v_module,
                                       g_failure_status,
                                       SQLCODE,
                                       SQLERRM,
                                       g_label1,
                                       v_loc);
      RAISE;
  END truncate_kr_time_master;

  /*************************************************************************************/
  /*                              insert_kr_time_master                                 */
  /*  This procedure will insert the Employee time data structure into the Time Master table */
  /*************************************************************************************/
  PROCEDURE insert_kr_time_master IS
    --v_module cust.ttec_error_handling.module_name%TYPE := 'insert_kr_time_master';   --code commented by RXNETHI-ARGANO,17/05/23
    v_module apps.ttec_error_handling.module_name%TYPE := 'insert_kr_time_master';     --code added by RXNETHI-ARGANO,17/05/23
    v_loc    NUMBER;
  BEGIN
    v_loc := 10;
    -- Add Who columns to record
    g_kr_time_data.create_request_id := g_request_id;
    g_kr_time_data.created_by        := g_created_by;
    g_kr_time_data.last_updated_by   := g_created_by;
    g_kr_time_data.creation_date     := SYSDATE;
    g_kr_time_data.last_update_date  := SYSDATE;
    v_loc                            := 20;

    --INSERT INTO cust.ttec_kr_time_master VALUES g_kr_time_data;   --code commented by RXNETHI-ARGANO,17/05/23
    INSERT INTO apps.ttec_kr_time_master VALUES g_kr_time_data;     --code added by RXNETHI-ARGANO,17/05/23

  EXCEPTION
    WHEN OTHERS THEN
      ttec_error_logging.process_error(g_application_code,
                                       g_interface,
                                       g_package,
                                       v_module,
                                       g_error_status,
                                       SQLCODE,
                                       SQLERRM,
                                       g_label1,
                                       v_loc,
                                       g_label2,
                                       g_kr_time_data.employee_number);
      RAISE error_record;
  END insert_kr_time_master;

  /*********************************************************
  **  Public Functions
  *********************************************************/

  /*************************************************************************************/
  /*                               MAIN PROGRAM PROCEDURE                              */
  /*  This is the main procedure that controls the processing of the selected employee */
  /*  data set.  It is called by the conc_mgr_wrapper process which controls the       */
  /*  concurrent manager output and logging                                            */
  /*************************************************************************************/
  PROCEDURE main(p_business_group_id IN NUMBER,
                 p_bucket_number     IN NUMBER,
                 p_buckets           IN NUMBER,
                 p_employee_number   IN VARCHAR2,
                 p_number_of_days    IN NUMBER) IS
    --v_module cust.ttec_error_handling.module_name%TYPE := 'main';    --code commented by RXNETHI-ARGANO,17/05/23
    v_module apps.ttec_error_handling.module_name%TYPE := 'main';      --code added by RXNETHI-ARGANO,17/05/23
    v_loc    NUMBER;
    -- declare local variables

    v_control_id      NUMBER;
	/*
	START R12.2 Upgrade Remediation
	code commentde by RXNETHI-ARGANO,17/05/23
	v_process_status  cust.ttec_kr_time_control.process_status%TYPE;
    v_process_country cust.ttec_kr_time_control.country%TYPE;
    */
	--code commented by RXNETHI-ARGANO,17/05/23
	v_process_status  apps.ttec_kr_time_control.process_status%TYPE;
    v_process_country apps.ttec_kr_time_control.country%TYPE;
	--END R12.2 Upgrade Remediation
    -- local variables for Assignment Costing Rules
    v_asgn_costs ttec_assign_costing_rules.asgncosttable;
    v_error_msg  VARCHAR2(250);
    v_status     BOOLEAN;
    --v_number_of_days NUMBER;
  BEGIN
    v_loc := 10;
    fnd_file.put_line(fnd_file.LOG,
                      TO_CHAR(SYSDATE, 'DD-MON-YYYY HH24:MI:SS') ||
                      ' -> Starting Process');

    -- Set Globals of Shared Package for Error Logging
    ttec_kr_utils.g_application_code := 'HR';
    ttec_kr_utils.g_interface        := 'Kronos Time';

    -- Create Kronos Control Record  /* 1.2 */
    v_loc            := 14;
    v_process_status := 'IN PROCESS';

    --SELECT cust.ttec_kr_time_control_s.NEXTVAL INTO v_control_id FROM DUAL;   --code commented by RXNETHI-ARGANO,17/05/23
    SELECT apps.ttec_kr_time_control_s.NEXTVAL INTO v_control_id FROM DUAL;     --code added by RXNETHI-ARGANO,17/05/23

    IF p_business_group_id IS NULL THEN
      v_process_country := 'ALL';
    ELSE

      SELECT hl.country
        INTO v_process_country
        --FROM hr.hr_all_organization_units hou, hr.hr_locations_all hl    --code commented by RXNETHI-ARGANO,17/05/23
        FROM apps.hr_all_organization_units hou, apps.hr_locations_all hl  --code added by RXNETHI-ARGANO,17/05/23
       WHERE hou.organization_id = p_business_group_id
         /*  and hou.business_group_id not in (select lookup_code from fnd_lookup_values
													where lookup_type = 'TTEC_EBS_DECOMMISION_COUNTRY'
													and language = 'US') -- Added as part of Cloud Migration  ---- 1.4*/--1.5
         AND hl.location_id = hou.location_id;

    END IF;

    v_loc := 16;

    -- Insert process control record for Kronos
    --INSERT INTO cust.ttec_kr_time_control    --code commented by RXNETHI-ARGANO,17/05/23
    INSERT INTO apps.ttec_kr_time_control      --code added by RXNETHI-ARGANO,17/05/23
      (timecard_control_id,
       request_id,
       actual_start_date,
       actual_completion_date,
       process_status,
       country,
       creation_date,
       created_by,
       last_update_date,
       last_updated_by,
       last_update_login)
    VALUES
      (v_control_id,
       g_request_id,
       SYSDATE,
       NULL,
       v_process_status,
       v_process_country,
       SYSDATE,
       g_created_by,
       SYSDATE,
       g_created_by,
       NULL);

    COMMIT;
    /* 1.2  End of Kronos process control */

    v_loc := 20;
    -- Initialize Who values
    g_request_id := fnd_global.conc_request_id;
    g_created_by := fnd_global.user_id;

    v_loc := 30;
    -- Backup and truncate employee staging table
    truncate_kr_time_master(p_business_group_id,
                            p_bucket_number,
                            p_buckets);

    -- Initialize counters
    g_records_read      := 0; -- Record count retrieved from Cursor
    g_records_processed := 0;
    g_records_errored   := 0;
    g_commit_count      := 0;

    v_loc := 40;
    /* -- Get Last Run Date
    ttec_kr_utils.get_last_run_date(p_program_name  => g_conc_prog_name,
                                    p_arg1          => p_business_group_id,
                                    p_arg2          => p_bucket_number,
                                    p_arg3          => p_buckets,
                                    p_last_run_date => v_last_run_date);*/
    fnd_file.put_line(fnd_file.LOG, 'BG ID: ' || p_business_group_id);
    /*fnd_file.put_line(fnd_file.LOG,
    'Last Run Date :' ||
    TO_CHAR(v_last_run_date, 'DD-MON-YYYY HH24:MI:SS'));*/
    fnd_file.put_line(fnd_file.LOG, 'Bucket Number :' || p_bucket_number);
    fnd_file.put_line(fnd_file.LOG, 'Number of Buckets :' || p_buckets);
    fnd_file.new_line(fnd_file.LOG);

    -- Check to see if cursor is open
    IF csr_emp_data%ISOPEN THEN

      CLOSE csr_emp_data;

    END IF;

    fnd_file.put_line(fnd_file.LOG,
                      TO_CHAR(SYSDATE, 'DD-MON-YYYY HH24:MI:SS') ||
                      ' -> Entering Main Loop');
    v_loc := 50;

    FOR sel IN csr_emp_data(p_business_group_id,
                            -- v_last_run_date,
                            p_bucket_number,
                            p_buckets,
                            p_employee_number,
                            fnd_number.canonical_to_number(p_number_of_days)) LOOP

      BEGIN
        v_loc := 60;
        -- update records read counter
        g_records_read := g_records_read + 1;

        -- initialize record and error variables
        g_kr_time_data := NULL;

        -- set all record data with all employee data
        g_kr_time_data.country           := sel.emp_country;
        g_kr_time_data.hours_in_date     := sel.OTLDate;
        g_kr_time_data.Employee_Name     := sel.Employee_Name;
        g_kr_time_data.Employee_Number   := sel.Oracle_ID;
        g_kr_time_data.total_hours       := sel.Hours_in_Task;
        g_kr_time_data.Task              := sel.task_desc;
        g_kr_time_data.pay_basis         := sel.pay_basis;
        g_kr_time_data.person_id         := sel.person_id;
        g_kr_time_data.business_group_id := sel.business_group_id;

        -- Build the Costing Accounts for the Employee Assignment
        ttec_assign_costing_rules.build_cost_accts(p_assignment_id => sel.assignment_id,
                                                   p_asgn_costs    => v_asgn_costs,
                                                   p_return_msg    => v_error_msg,
                                                   p_status        => v_status);

        IF v_asgn_costs.COUNT = 0 THEN
          ttec_error_logging.process_error(g_application_code,
                                           g_interface,
                                           g_package,
                                           v_module,
                                           g_warning_status,
                                           NULL,
                                           'No Costing Records built for Employee Assignment',
                                           g_label1,
                                           v_loc,
                                           g_label2,
                                           g_kr_time_data.employee_number,
                                           'Assignment ID',
                                           sel.assignment_id);
        ELSE
          -- Use first costing record returned
          g_kr_time_data.LOCATION_CODE := v_asgn_costs(1).location;

          begin
            select ffvt.description
              into g_kr_time_data.LOCATION_name
              from apps.fnd_flex_values_tl  ffvt,
                   apps.fnd_flex_values     ffv,
                   apps.fnd_flex_value_sets ffvs
             where ffvt.flex_value_id = ffv.flex_value_id
               and ffv.flex_value_set_id = ffvs.flex_value_set_id
               and ffvs.flex_value_set_name = 'TELETECH_LOCATION'
               and ffv.flex_value = g_kr_time_data.LOCATION_CODE
               and language = userenv('LANG');
          exception
            when others then
              ttec_error_logging.process_error(g_application_code,
                                               g_interface,
                                               g_package,
                                               v_module,
                                               g_warning_status,
                                               NULL,
                                               'Unable to get Location Name',
                                               g_label1,
                                               v_loc,
                                               g_label2,
                                               g_kr_time_data.employee_number,
                                               'Assignment ID',
                                               sel.assignment_id);
          end;

        END IF;

        v_loc := 155;
        -- insert record data into employee master table
        insert_kr_time_master;

        v_loc := 160;

        -- update records completed counter
        g_records_processed := g_records_processed + 1;
        -- Check commit loop
        g_commit_count := g_commit_count + 1;

        IF g_commit_count = g_commit_point THEN
          COMMIT;
          g_commit_count := 0;
          fnd_file.put_line(fnd_file.LOG,
                            TO_CHAR(SYSDATE, 'DD-MON-YYYY HH24:MI:SS') ||
                            ' -> ' || g_records_processed ||
                            ' Records Processed');
        END IF;

      EXCEPTION
        WHEN error_record THEN
          g_records_errored := g_records_errored + 1;
        WHEN term_record THEN
          -- Subtract one as this record is NOT to be processed
          g_records_read := g_records_read - 1;
        WHEN OTHERS THEN
          ttec_error_logging.process_error(g_application_code,
                                           g_interface,
                                           g_package,
                                           v_module,
                                           g_error_status,
                                           SQLCODE,
                                           SQLERRM,
                                           g_label1,
                                           v_loc,
                                           g_label2,
                                           g_kr_time_data.employee_number,
                                           'Country',
                                           g_kr_time_data.country);
          g_records_errored := g_records_errored + 1;
      END;

    END LOOP;

    fnd_file.put_line(fnd_file.LOG,
                      TO_CHAR(SYSDATE, 'DD-MON-YYYY HH24:MI:SS') ||
                      ' -> Exiting Main Loop');

    v_loc := 190;
    -- final commit
    COMMIT;

    -- Save process info to temp table
    ttec_kr_utils.save_process_run_time(g_request_id);
    v_loc := 210;

    -- Purge Process Run Times table of old data
    --DELETE cust.ttec_kr_process_times   --code commented by RXNETHI-ARGANO,17/05/23
    DELETE apps.ttec_kr_process_times     --code added by RXNETHI-ARGANO,17/05/23
     WHERE creation_date < SYSDATE - g_keep_run_times;

    -- Update process control record for Kronos
    IF g_fail_flag THEN
      v_process_status := 'ERROR';
    ELSE
      v_process_status := 'SUCCESS';
    END IF;

    v_loc := 180;

    --UPDATE cust.ttec_kr_time_control   --code commented by RXNETHI-ARGANO,17/05/23
    UPDATE apps.ttec_kr_time_control     --code added by RXNETHI-ARGANO,17/05/23
       SET actual_completion_date = SYSDATE,
           process_status         = v_process_status
     WHERE timecard_control_id = v_control_id;

    COMMIT;
    fnd_file.put_line(fnd_file.LOG,
                      TO_CHAR(SYSDATE, 'DD-MON-YYYY HH24:MI:SS') ||
                      ' -> Ending Process');
  EXCEPTION
    /** CURSOR RELATED ERRORS **/
    WHEN INVALID_CURSOR THEN
      ttec_error_logging.process_error(g_application_code,
                                       g_interface,
                                       g_package,
                                       v_module,
                                       g_failure_status,
                                       SQLCODE,
                                       'Invalid Cursor',
                                       g_label1,
                                       v_loc,
                                       'Records Read',
                                       g_records_read);
      g_fail_flag := TRUE;
      g_fail_msg  := SQLERRM;
    WHEN OTHERS THEN
      ttec_error_logging.process_error(g_application_code,
                                       g_interface,
                                       g_package,
                                       v_module,
                                       g_failure_status,
                                       SQLCODE,
                                       SQLERRM,
                                       g_label1,
                                       v_loc,
                                       'Records Read',
                                       g_records_read);
      g_fail_flag := TRUE;
      g_fail_msg  := SQLERRM;
  END main;

  /*************************************************************************************/
  /*                               CONC_MGR_WRAPPER                                    */
  /*  This is a wrapper procedure to be called directly from the Concurrent Mgr.  It   */
  /*  will set Globals from input parameters and will output the final log.  This      */
  /*  approach will allow the Main process to be ran/tested from the Conc Mgr or SQL.  */
  /*************************************************************************************/
  PROCEDURE conc_mgr_wrapper(errbuf              OUT VARCHAR2,
                             retcode             OUT NUMBER,
                             p_business_group_id IN NUMBER,
                             p_bucket_number     IN NUMBER,
                             p_buckets           IN NUMBER,
                             p_employee_number   IN VARCHAR2,
                             p_number_of_days    IN NUMBER) IS

    e_cleanup_err EXCEPTION;

  BEGIN
    -- Submit the Main Process
    main(p_business_group_id,
         p_bucket_number,
         p_buckets,
         p_employee_number,
         p_number_of_days);

    -- Log Counts
    BEGIN
      -- Write to Log
      fnd_file.new_line(fnd_file.LOG, 1);
      fnd_file.put_line(fnd_file.LOG, 'COUNTS');
      fnd_file.put_line(fnd_file.LOG,
                        '---------------------------------------------------------');
      fnd_file.put_line(fnd_file.LOG,
                        '  # Read                : ' || g_records_read);
      fnd_file.put_line(fnd_file.LOG,
                        '  # Processed           : ' || g_records_processed);
      fnd_file.put_line(fnd_file.LOG,
                        '  # Errored             : ' || g_records_errored);
      fnd_file.put_line(fnd_file.LOG,
                        '---------------------------------------------------------');
      fnd_file.new_line(fnd_file.LOG, 2);
      -- Write to Output
      fnd_file.put_line(fnd_file.output, 'COUNTS');
      fnd_file.put_line(fnd_file.output,
                        '---------------------------------------------------------');
      fnd_file.put_line(fnd_file.output,
                        '  # Read                : ' || g_records_read);
      fnd_file.put_line(fnd_file.output,
                        '  # Processed           : ' || g_records_processed);
      fnd_file.put_line(fnd_file.output,
                        '  # Errored             : ' || g_records_errored);
      fnd_file.put_line(fnd_file.output,
                        '---------------------------------------------------------');
      fnd_file.new_line(fnd_file.output, 2);

      IF g_records_errored > 0 THEN
        retcode := 1; -- Lable CR with WARNING
      END IF;

    EXCEPTION
      WHEN OTHERS THEN
        fnd_file.put_line(fnd_file.LOG, '   Error reporting Counts');
        retcode := 1;
    END;

    -- Log Errors / Warnings
    BEGIN
      -- Critical Failures from this Package
      ttec_error_logging.log_error_details(p_application   => g_application_code,
                                           p_interface     => g_interface,
                                           p_message_type  => g_failure_status,
                                           p_message_label => 'CRITICAL ERRORS - FAILURE',
                                           p_request_id    => g_request_id);
      -- Errors from this Package
      ttec_error_logging.log_error_details(p_application   => g_application_code,
                                           p_interface     => g_interface,
                                           p_message_type  => g_error_status,
                                           p_message_label => 'SKIPPED Records Due to Errors',
                                           p_request_id    => g_request_id);
      -- Warnings from this Package
      ttec_error_logging.log_error_details(p_application   => g_application_code,
                                           p_interface     => g_interface,
                                           p_message_type  => g_warning_status,
                                           p_message_label => 'Additional Warning Messages (records not Skipped)',
                                           p_request_id    => g_request_id);
    EXCEPTION
      WHEN OTHERS THEN
        fnd_file.put_line(fnd_file.LOG,
                          '   Error Reporting Errors / Warnings');
        retcode := 1;
    END;

    -- Cleanup Log Table
    BEGIN
      -- Purge old Logging Records for this Interface
      ttec_error_logging.purge_log_errors(p_application => g_application_code,
                                          p_interface   => g_interface,
                                          p_keep_days   => g_keep_days);
    EXCEPTION
      WHEN OTHERS THEN
        fnd_file.put_line(fnd_file.LOG, 'Error Cleaning up Log tables');
        fnd_file.put_line(fnd_file.LOG, SQLCODE || ': ' || SQLERRM);
        retcode := 2;
        errbuf  := SQLERRM;
    END;

    IF g_fail_flag THEN
      fnd_file.put_line(fnd_file.LOG,
                        'Refer to Output for Detailed Errors and Warnings');
      retcode := 2;
      errbuf  := g_fail_msg;
    END IF;

  EXCEPTION
    WHEN OTHERS THEN
      fnd_file.put_line(fnd_file.LOG, SQLCODE || ': ' || SQLERRM);
      retcode := 2;
      errbuf  := SQLERRM;
  END conc_mgr_wrapper;
END ttec_kr_otl_time_outbound;
/
show errors;
/