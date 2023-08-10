create or replace PACKAGE BODY TTEC_TALEO_PERFO_INITIAL_U
IS
   g_run_date            CONSTANT DATE                     := TRUNC (SYSDATE);
   g_oracle_start_date   CONSTANT DATE             := TO_DATE ('01-JAN-1950');
   g_oracle_end_date     CONSTANT DATE             := TO_DATE ('31-DEC-4712');
   g_user_role1          CONSTANT VARCHAR2 (100)
                                  := 'com.taleo.orion.role.business.Manager2';
   g_no_email             CONSTANT VARCHAR2(100) := 'no_email_address@teletech.com';
   trunc_stat                     VARCHAR2 (100)
                         := 'truncate table cust.ttec_taleoPerf_EmpUpdate_db';
   g_rec2_w                       cust.ttec_taleoperf_empupdate_tbl%ROWTYPE;
   -- record to write to file
   g_rec2_db                      cust.ttec_taleoperf_empupdate_db%ROWTYPE;
   g_msg             			  VARCHAR2 (256);
   -- * ggg_tail                       cust.ttec_rsu_rec_2_trl%ROWTYPE;
   --- * ggg_head                       cust.ttec_rsu_rec_2_hdr%ROWTYPE;
   e_program_run_status           NUMBER                                 := 0;
   -- record to get match data from query
   e_initial_status               cust.ttec_error_handling.status%TYPE
                                                                 := 'INITIAL';
   e_warning_status               cust.ttec_error_handling.status%TYPE
                                                                 := 'WARNING';
   e_failure_status               cust.ttec_error_handling.status%TYPE
                                                                 := 'FAILURE';
   g_len_64                       NUMBER                                := 64;
   e_application_code             cust.ttec_error_handling.application_code%TYPE
                                                                      := 'HR';
   e_interface                    cust.ttec_error_handling.INTERFACE%TYPE
                                                          := 'TTECTALEOPRFOU';
   e_program_name                 cust.ttec_error_handling.program_name%TYPE
                                                 := 'TTEC_TALEO_PERFO_ONET_U';
   e_module_name                  cust.ttec_error_handling.module_name%TYPE
                                                                      := NULL;
   e_conc                         cust.ttec_error_handling.concurrent_request_id%TYPE
                                                                         := 0;
   e_execution_date               cust.ttec_error_handling.execution_date%TYPE
                                                                   := SYSDATE;
   e_status                       cust.ttec_error_handling.status%TYPE
                                                                      := NULL;
   e_error_code                   cust.ttec_error_handling.ERROR_CODE%TYPE
                                                                         := 0;
   e_error_message                cust.ttec_error_handling.error_message%TYPE
                                                                      := NULL;
   e_label1                       cust.ttec_error_handling.label1%TYPE
                                                                      := NULL;
   e_reference1                   cust.ttec_error_handling.reference1%TYPE
                                                                      := NULL;
   e_label2                       cust.ttec_error_handling.label2%TYPE
                                                                      := NULL;
   e_reference2                   cust.ttec_error_handling.reference2%TYPE
                                                                      := NULL;
   e_label3                       cust.ttec_error_handling.label3%TYPE
                                                                      := NULL;
   e_reference3                   cust.ttec_error_handling.reference3%TYPE
                                                                      := NULL;
   e_label4                       cust.ttec_error_handling.label4%TYPE
                                                                      := NULL;
   e_reference4                   cust.ttec_error_handling.reference4%TYPE
                                                                      := NULL;
   e_label5                       cust.ttec_error_handling.label5%TYPE
                                                                      := NULL;
   e_reference5                   cust.ttec_error_handling.reference5%TYPE
                                                                      := NULL;
   e_label6                       cust.ttec_error_handling.label6%TYPE
                                                                      := NULL;
   e_reference6                   cust.ttec_error_handling.reference6%TYPE
                                                                      := NULL;
   e_label7                       cust.ttec_error_handling.label7%TYPE
                                                                      := NULL;
   e_reference7                   cust.ttec_error_handling.reference7%TYPE
                                                                      := NULL;
   e_label8                       cust.ttec_error_handling.label8%TYPE
                                                                      := NULL;
   e_reference8                   cust.ttec_error_handling.reference8%TYPE
                                                                      := NULL;
   e_label9                       cust.ttec_error_handling.label9%TYPE
                                                                      := NULL;
   e_reference9                   cust.ttec_error_handling.reference9%TYPE
                                                                      := NULL;
   e_label10                      cust.ttec_error_handling.label10%TYPE
                                                                      := NULL;
   e_reference10                  cust.ttec_error_handling.reference10%TYPE
                                                                      := NULL;
   e_label11                      cust.ttec_error_handling.label11%TYPE
                                                                      := NULL;
   e_reference11                  cust.ttec_error_handling.reference11%TYPE
                                                                      := NULL;
   e_label12                      cust.ttec_error_handling.label12%TYPE
                                                                      := NULL;
   e_reference12                  cust.ttec_error_handling.reference12%TYPE
                                                                      := NULL;
   e_label13                      cust.ttec_error_handling.label13%TYPE
                                                                      := NULL;
   e_reference13                  cust.ttec_error_handling.reference13%TYPE
                                                                      := NULL;
   e_label14                      cust.ttec_error_handling.label14%TYPE
                                                                      := NULL;
   e_reference14                  cust.ttec_error_handling.reference14%TYPE
                                                                      := NULL;
   e_label15                      cust.ttec_error_handling.label15%TYPE
                                                                      := NULL;
   e_reference15                  cust.ttec_error_handling.reference15%TYPE
                                                                      := NULL;
   e_last_update_date             cust.ttec_error_handling.last_update_date%TYPE
                                                                      := NULL;
   e_last_updated_by              cust.ttec_error_handling.last_updated_by%TYPE
                                                                      := NULL;
   e_last_update_logi             cust.ttec_error_handling.last_update_login%TYPE
                                                                      := NULL;
   e_creation_date                cust.ttec_error_handling.creation_date%TYPE
                                                                      := NULL;
   e_created_by                   cust.ttec_error_handling.created_by%TYPE
                                                                      := NULL;

/*
------------------------------------------------------------------------------------------------
print a line to the log
------------------------------------------------------------------------------------------------
*/
   PROCEDURE print_line (v_data IN VARCHAR2)
   IS
   BEGIN
      fnd_file.put_line (fnd_file.LOG, v_data);
   END;


   /*
------------------------------------------------------------------------------------------------
main record 2 population routine
------------------------------------------------------------------------------------------------
*/
   PROCEDURE rec_taleo_c_fill (ggg IN c_rec2_q%ROWTYPE,
                                                       -- record to get match data from query
       l_rec OUT VARCHAR)
   IS
      ev_val          CHAR (2);
      l_loc_code      VARCHAR2 (100);
      l_address_tmp   VARCHAR2 (240);
   BEGIN
      e_module_name := 'rec_taleo_c_fill';
      g_rec2_db.delimit1 := '|';
      g_rec2_db.delimit2 := '|';
      g_rec2_db.delimit2 := '|';
      g_rec2_db.delimit3 := '|';
      g_rec2_db.delimit4 := '|';
      g_rec2_db.delimit5 := '|';
      g_rec2_db.delimit6 := '|';
      g_rec2_db.delimit7 := '|';
      g_rec2_db.delimit8 := '|';
      g_rec2_db.delimit9 := '|';
      g_rec2_db.delimit10 := '|';
      g_rec2_db.delimit11 := '|';
      g_rec2_db.delimit12 := '|';
      g_rec2_db.delimit13 := '|';
      g_rec2_db.delimit14 := '|';
      g_rec2_db.delimit15 := '|';
      g_rec2_db.delimit16 := '|';
      g_rec2_db.delimit17 := '|';
      g_rec2_db.delimit18 := '|';
      g_rec2_db.delimit19 := '|';
      g_rec2_db.delimit20 := '|';
      g_rec2_db.delimit21 := '|';

      g_rec2_db.IDENTIFIER := SUBSTR (ggg.xidentifier, 1, 30);
      g_rec2_db.user_name := SUBSTR (ggg.user_name, 1, 30);
      g_rec2_db.first_name := SUBSTR (ggg.first_name, 1, 250);
      g_rec2_db.middle_name := NULL; -- SUBSTR (ggg.middle_names, 1, 60);

      g_rec2_db.last_name := SUBSTR (ggg.last_name, 1, 250);
      g_rec2_db.employee_id := SUBSTR (ggg.employee_id, 1, 30);
      g_rec2_db.email := SUBSTR (replace(ggg.ttec_email, ' ', ''), 1, 150);
     	  g_rec2_db.email := replace (NVL(g_rec2_db.email, ggg.first_name||ggg.last_name||'@teletech.com'), ' ', '');

      -- Feb 5 2008 change requirement not to pass address info

      g_rec2_db.address_1 := NULL;      -- SUBSTR(ggg.address_line1, 1, 100);
      g_rec2_db.address_2 := NULL;     -- substr( ggg.address_line2, 1, 100);
      g_rec2_db.address_3 := NULL;     -- sUBSTR( ggg.address_line3, 1, 100);
      g_rec2_db.city := NULL;            -- SUBSTR(ggg.town_or_city, 1, 100);

      g_rec2_db.state := NULL;                -- substr(ggg.region_2, 1, 30);
      g_rec2_db.country := NULL;             -- substr( ggg.country, 1, 100);
      g_rec2_db.postal_code := NULL;       -- substr(ggg.postal_code, 1, 30);
      g_rec2_db.picture := SUBSTR (ggg.picture, 1, 100);
      g_rec2_db.ORGANIZATION := SUBSTR (ggg.xorganization, 1, 30);
      g_rec2_db.LOCATION := SUBSTR (ggg.xlocation, 1, 30);
      g_rec2_db.job_role := SUBSTR (ggg.job_role, 1, 30);

      IF ggg.status LIKE 'EMP%'
      THEN
         g_rec2_db.employee_status := SUBSTR (ggg.employee_status, 1, 30);
         g_rec2_db.status := 'Active';
         g_rec2_db.manager_id := SUBSTR (ggg.manager_id, 1, 150);
      ELSE
         g_rec2_db.employee_status := 'Former Employee';

         g_rec2_db.status := 'Inactive';        -- substr(ggg.status, 1, 30);
         g_rec2_db.manager_id := NULL;     -- substr(ggg.manager_id, 1, 150);

      /*   BEGIN
            UPDATE cust.ttec_taleoperf_empsenttotaleo
               SET active = 'N',
                   update_date = SYSDATE
             WHERE empl_num = ggg.xidentifier;
         EXCEPTION
            WHEN OTHERS
            THEN
               log_error ( 'Employee Number', ggg.xidentifier, NULL, NULL);

               print_line (   'Update cust.ttec_taleoperf_empsenttotaleo. Error in module: '
                           || e_module_name
                           || 'Employee Number' || ggg.xidentifier
                          );
         END;

         COMMIT;
		*/
      END IF;

      g_rec2_db.manager_level := NULL;   -- substr(ggg.manager_level, 1, 150);
      -- handle processing exceptions

   EXCEPTION
      WHEN OTHERS
      THEN
         log_error ( 'Employee Number', ggg.xidentifier, NULL, NULL);
         print_line (   'Error in module: '
                     || e_module_name
                     || g_rec2_db.IDENTIFIER
					);
         e_program_run_status := 1;
   END;

   /*
------------------------------------------------------------------------------------------------
not used at present
------------------------------------------------------------------------------------------------
*/
   PROCEDURE errvar_null (p_status OUT NUMBER)
   IS
   BEGIN
      e_module_name := 'ERRVAR_NULL';
      e_label1 := NULL;
      e_reference1 := NULL;
      e_label2 := NULL;
      e_reference2 := NULL;
      e_label3 := NULL;
      e_reference3 := NULL;
      e_label4 := NULL;
      e_reference4 := NULL;
      e_label5 := NULL;
      e_reference5 := NULL;
      e_label6 := NULL;
      e_reference6 := NULL;
      e_label7 := NULL;
      e_reference7 := NULL;
      e_label8 := NULL;
      e_reference8 := NULL;
      e_label9 := NULL;
      e_reference9 := NULL;
      e_label10 := NULL;
      e_reference10 := NULL;
      e_label11 := NULL;
      e_reference11 := NULL;
      e_label12 := NULL;
      e_reference12 := NULL;
      e_label13 := NULL;
      e_reference13 := NULL;
      p_status := 0;                                             -- if needed
   EXCEPTION
      WHEN OTHERS
      THEN
         log_error ('Routine', e_module_name, NULL, NULL);

         print_line ('Error in module: ' || e_module_name);
         e_program_run_status := 1;
   END;

/*---------------------------------------------------------------------------------------------------------
    Name:  Log error  PROCEDURE
    Description:  PROCEDURE standardizes concurrent program EXCEPTION handling
    error reporting routine.
   ---------------------------------------------------------------------------------------------------------*/
   PROCEDURE log_error (
      label1       IN   VARCHAR2,
      reference1   IN   VARCHAR2,
      label2       IN   VARCHAR2,
      reference2   IN   VARCHAR2
   )
   IS
   BEGIN
      e_error_code := SQLCODE;
      e_error_message := SUBSTR (SQLERRM, 1, 240);
      cust.ttec_process_error (e_application_code,
                               e_interface,
                               e_program_name,
                               e_module_name,
                               e_warning_status,
                               e_error_code,
                               e_error_message,
                               label1,
                               reference1,
                               label2,
                               reference2,
                               e_label3,
                               e_reference3,
                               e_label4,
                               e_reference4,
                               e_label5,
                               e_reference5,
                               e_label6,
                               e_reference6,
                               e_label7,
                               e_reference7,
                               e_label8,
                               e_reference8,
                               e_label9,
                               e_reference9,
                               e_label10,
                               e_reference10,
                               e_label1,
                               e_reference11,
                               e_label12,
                               e_reference12,
                               e_label13,
                               e_reference13,
                               e_label14,
                               e_reference14,
                               e_label15,
                               e_reference15
                              );
   EXCEPTION
      WHEN OTHERS
      THEN
	   	 g_msg := SUBSTR(SQLERRM, 1, 249);
         log_error ('Routine', e_module_name, NULL, NULL);

         print_line ('Error in module: ' || e_module_name);
         e_program_run_status := 1;
   END;



/*
------------------------------------------------------------------------------------------------
this is for debugging only. data is inserted in database table for ease of debugging
------------------------------------------------------------------------------------------------
*/
   PROCEDURE rec_taleo_c_insert_db
   IS
   BEGIN
      e_module_name := 'REC_TALEO_C_INSERT_DB';

      INSERT INTO cust.ttec_taleoperf_empupdate_db
           VALUES g_rec2_db;
   EXCEPTION
      WHEN OTHERS
      THEN
         log_error ('Routine', e_module_name, NULL, NULL);
         print_line ('Error in module: ' || e_module_name);
         e_program_run_status := 1;
   END;

/*
------------------------------------------------------------------------------------------------
main processing program
------------------------------------------------------------------------------------------------
*/
   PROCEDURE main (
      errcode              VARCHAR2,
      errbuff              VARCHAR2,
      email_to_list   IN   VARCHAR2,
      email_cc_list   IN   VARCHAR2
   )
   IS
--  Program to write Taleo Performance Employee Create
-- Individual bill/company data transmission
--    Wasim Manasfi    Jan 28 2008
--
-- Filehandle Variables
      p_filedir         VARCHAR2 (200);
      p_filename        VARCHAR2 (50);
      p_country         VARCHAR2 (10);
      l_stage           VARCHAR2 (100);
      v_output_file     UTL_FILE.file_type;
      p_status          NUMBER;
      crlf              CHAR (2)           := CHR (10) || CHR (13);
      cr                CHAR (2)           := CHR (13);
      /* email variables */
      l_email_from      VARCHAR2 (256)     := 'EBS_Development@Teletech.com';
      l_email_to        VARCHAR2 (400)     := NULL;
      l_email_subj      VARCHAR2 (256)
                  := 'TeleTech Taleo Performance Employee Update File Write ';
      l_email_body1     VARCHAR2 (256)
         := 'Running Concurrent Program: TeleTech Taleo Performance Employee Update File Write ';
      l_email_body2     VARCHAR2 (256)
         :=    crlf
            || 'Run Date: '
            || TO_CHAR (SYSDATE, 'MM/DD/YYYY HH24:MM' || '.');
      l_email_body3     VARCHAR2 (256)
                   := 'TeleTech Taleo Performance Employee Update File Write ';
      l_email_body4     VARCHAR2 (256)
             := 'If you have any questions, please contact the HR Department.';
      l_prcs_fail1      VARCHAR2 (256)
           := '* * * WARNING - Program failed. Check Program output and log: ';
      l_prcs_fail2      VARCHAR2 (256)
                         := '* * * WARNING - Error in record on line number: ';
      l_host_name       VARCHAR2 (256);
      l_body            VARCHAR2 (8000)
                                       := ' Please review log and output file';
      w_mesg            VARCHAR2 (256);

      -- Declare program variables
      l_rec             VARCHAR2 (4000);
      l_key             VARCHAR2 (400);
      l_file_num        VARCHAR2 (4)       := '01';
      l_tot_rec_count   NUMBER;
      l_seq             NUMBER;
   BEGIN
      fnd_file.put_line (fnd_file.LOG,
                         '********************************** 1');

      OPEN c_host;

      FETCH c_host
       INTO l_host_name;

      CLOSE c_host;

      fnd_file.put_line (fnd_file.LOG,
                         '********************************** 2 '
                        );
      e_module_name := 'main';

      EXECUTE IMMEDIATE trunc_stat;

      l_stage := 'c_directory_path';
      fnd_file.put_line (fnd_file.LOG,
                         '********************************** 3 ');

      OPEN c_directory_path;

      FETCH c_directory_path
       INTO p_filedir, p_filename;

      CLOSE c_directory_path;
/*
      OPEN c_last_run;

      FETCH c_last_run
       INTO v_last_run_date;

      CLOSE c_last_run;

      IF v_last_run_date IS NULL
      THEN
         v_last_run_date := SYSDATE;
      END IF;

      -- remove for PROD
      v_last_run_date := TRUNC (v_last_run_date);
	  */
	  v_last_run_date := TRUNC (SYSDATE);
      l_stage := 'c_open_file';
      v_output_file := UTL_FILE.fopen (p_filedir, p_filename, 'w', 32000);
      fnd_file.put_line (fnd_file.LOG, '**********************************');
      fnd_file.put_line (fnd_file.LOG,
                            'Output file created >>> '
                         || p_filedir
                         || '/'
                         || p_filename
                        );
      fnd_file.put_line (fnd_file.LOG, '**********************************');
      fnd_file.put_line (fnd_file.output,
                            'Output file created >>> '
                         || p_filedir
                         || '/'
                         || p_filename
                        );
      fnd_file.put_line (fnd_file.output,
                         '**********************************');
      --
      l_tot_rec_count := 0;
      -- set record type 1 all records 220 char long
      l_rec := 'Start Processing ';
      l_stage := 'Header Record';
      apps.fnd_file.put_line (apps.fnd_file.output, l_rec);
      apps.fnd_file.put_line (apps.fnd_file.output,
                                 'Processing Effective Date :'
                              || TO_CHAR (v_last_run_date, 'DD-MON-RRRR')
                             );
      l_rec := NULL;

         -- loop on all records
         -- rec_02_header (l_rec);
      --    UTL_FILE.put_line (v_output_file, l_rec);
      FOR l_rec2 IN c_rec2_q
      LOOP
-------------------------------------------------------------------------------------------------------------------------
         l_stage := 'rec_fill';
         rec_taleo_c_fill (l_rec2, l_rec);
         l_stage := 'rec_insert_db';
         rec_taleo_c_insert_db;
         l_tot_rec_count := l_tot_rec_count + 1;
         apps.fnd_file.put_line
                              (apps.fnd_file.output,
                                  'Inserting into temp table Record Number: '
                               || TO_CHAR (l_tot_rec_count)
                               || l_rec
                              );
      END LOOP;

      l_tot_rec_count := 0;
      UTL_FILE.put_line (v_output_file, g_header);

      FOR l_rec2_db IN c_req_db
      LOOP
         l_stage := 'rec_write_to_file';
         --   rec_taleo_c_write_to (l_rec);
         l_stage := 'writing to output file';
         UTL_FILE.put_line (v_output_file, l_rec2_db.l_out);
         UTL_FILE.fflush (v_output_file);
         l_tot_rec_count := l_tot_rec_count + 1;
         apps.fnd_file.put_line
                             (apps.fnd_file.output,
                                 'Inserting into Output File Record Number: '
                              || TO_CHAR (l_tot_rec_count)
                              || ' Employee Record '
                              || l_rec2_db.l_out
                             );
      -- get totals
      END LOOP;

---------------------------------------------------------------------------------------------------------------------------
      --  Account Trailer Record
      --
      l_stage := 'Finsih Record';
      -- l_rec := LPAD ('0', 18, '0') || LPAD (' ', 180, ' ');
      --rec_02_trailer (l_tot_rec_count, l_rec);
--       UTL_FILE.put_line (v_output_file, l_rec);
      UTL_FILE.fclose (v_output_file);
      --  EXECUTE IMMEDIATE trunc_stat;   -- remove if data becomes too large
      l_body := 'Taleo Peroformance Employee One Time Update Record ';

      IF e_program_run_status = 0
      THEN
         l_email_subj := 'SUCCESS - ' || l_email_subj;
         l_body :=
               'Run Result: * * * SUCCESS * * * '
            || crlf
            || l_email_body3
            || crlf
            || 'Created Output File'
            || p_filedir
            || '/'
            || p_filename
            || crlf
            || l_email_body4;
      ELSE
         l_email_subj := 'FAILURE - ' || l_email_subj;
         l_body :=
               ' Run Result: * * * FAILURE * * * '
            || crlf
            || l_email_body3
            || crlf
            || 'Output File Creation Error: '
            || p_filedir
            || '/'
            || p_filename
            || crlf
            || l_email_body4;
      END IF;

      send_email (ttec_library.XX_TTEC_SMTP_SERVER, /*Rehosting changes for smtp */
	               --l_host_name,
                  l_email_from,
                  email_to_list,
                  email_cc_list,
                  NULL,
                  l_email_subj,                                  -- v_subject,
                  crlf || l_email_body1 || l_email_body2 || crlf,
                  -- NULL, --                        v_line1,
                  l_body,
                  NULL,
                  NULL,
                  NULL,
                  NULL,
                  -- file_to_send,                                 -- v_file_name,
                  NULL,
                  NULL,
                  NULL,
                  NULL,
                  p_status,
                  w_mesg
                 );
      print_line ('p_status after email sent ' || p_status);
      print_line ('p_status after email sent' || w_mesg);
   EXCEPTION
      WHEN UTL_FILE.invalid_operation
      THEN
         UTL_FILE.fclose (v_output_file);
         raise_application_error (-20051,
                                  p_filename || ':  Invalid Operation'
                                 );
         print_line ('Error in module: ' || e_module_name);
         ROLLBACK;
      WHEN UTL_FILE.invalid_filehandle
      THEN
         UTL_FILE.fclose (v_output_file);
         raise_application_error (-20052,
                                  p_filename || ':  Invalid File Handle'
                                 );
         print_line ('Error in module: ' || e_module_name);
         ROLLBACK;
      WHEN UTL_FILE.read_error
      THEN
         UTL_FILE.fclose (v_output_file);
         raise_application_error (-20053, p_filename || ':  Read Error');
         print_line ('Error in module: ' || e_module_name);
         ROLLBACK;
      WHEN UTL_FILE.invalid_path
      THEN
         UTL_FILE.fclose (v_output_file);
         raise_application_error (-20054, p_filedir || ':  Invalid Path');
         print_line ('Error in module: ' || e_module_name);
         ROLLBACK;
      WHEN UTL_FILE.invalid_mode
      THEN
         UTL_FILE.fclose (v_output_file);
         raise_application_error (-20055, p_filename || ':  Invalid Mode');
         print_line ('Error in module: ' || e_module_name);
         ROLLBACK;
      WHEN UTL_FILE.write_error
      THEN
         UTL_FILE.fclose (v_output_file);
         raise_application_error (-20056, p_filename || ':  Write Error');
         print_line ('Error in module: ' || e_module_name);
         ROLLBACK;
      WHEN UTL_FILE.internal_error
      THEN
         UTL_FILE.fclose (v_output_file);
         raise_application_error (-20057, p_filename || ':  Internal Error');
         print_line ('Error in module: ' || e_module_name);
         ROLLBACK;
      WHEN UTL_FILE.invalid_maxlinesize
      THEN
         UTL_FILE.fclose (v_output_file);
         raise_application_error (-20058,
                                  p_filename || ':  Maxlinesize Error'
                                 );
         print_line ('Error in module: ' || e_module_name);
         ROLLBACK;
      WHEN OTHERS
      THEN
         UTL_FILE.fclose (v_output_file);
         g_msg := SUBSTR (SQLERRM, 1, 240);
         print_line ('Error in module: ' || e_module_name );
         DBMS_OUTPUT.put_line ('Operation fails on ' || l_stage);

         raise_application_error
              (-20003,
                  'Exception OTHERS in TeleTech Taleo Employee One Time Update Record: '
               || g_msg
              );
         ROLLBACK;
   END main;
END TTEC_TALEO_PERFO_INITIAL_U;