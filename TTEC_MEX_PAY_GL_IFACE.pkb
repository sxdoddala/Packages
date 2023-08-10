create or replace PACKAGE BODY ttec_mex_pay_gl_iface
AS
/* $Header: ttec_mex_pay_gl_iface.pkb 1.0 2009/03/05 mdodge ship $ */

   /*== START ================================================================================================*\
      Author: Michelle Dodge
        Date: 05-MAR-2009
   Call From: 'TeleTech Mexico Payroll GL Interface' Conc Program AND
              'TeleTech Mex Pay GL Interface File Validate' Conc Program
        Desc: This package body contains the code necessary for processing the data
              in the ttec_mex_gl_iface_stg table and transferring it to the
              GL_INTERFACE table.  A wrapper procedure is provided which will be called
              from the registered concurrent program.  This procedure will call the
              Main procedure for data processing and will log the results and set the
              status on the Concurrent Request.
              The Submit_set function will be called by a Host Program to submit a request
              set for one File at a time.

     Modification History:

    Version    Date     Author   Description (Include Ticket#)
    -------  --------  --------  ------------------------------------------------------------------------------
        1.0  03/05/09  MDodge    WO #561427 - Initial Version
        1.0  16/MAY/2023 RXNETHI-ARGANO   R12.2 Upgrade Remediation 
   \*== END ==================================================================================================*/

   -- Error Constants
   /*
   START R12.2 Upgrade Remediation
   code commented by RXNETHI-ARGANO,16/05/23
   g_application_code   cust.ttec_error_handling.application_code%TYPE
                                                                      := 'GL';
   g_interface          cust.ttec_error_handling.INTERFACE%TYPE
                                                            := 'Mex GL Iface';
   g_package            cust.ttec_error_handling.program_name%TYPE
                                                   := 'ttec_mex_pay_gl_iface';
   g_status_warning     VARCHAR2 (7)                             := 'WARNING';
   g_status_failure     VARCHAR2 (7)                             := 'FAILURE';
   g_iface_hdr          cust.ttec_mex_gl_iface_stg.status%TYPE
                                                             := 'MEX PAY HDR';
   g_iface_line         cust.ttec_mex_gl_iface_stg.status%TYPE
                                                            := 'MEX PAY LINE';
	*/
   --code added by RXNETHI-ARGANO,16/05/23
   g_application_code   apps.ttec_error_handling.application_code%TYPE
                                                                      := 'GL';
   g_interface          apps.ttec_error_handling.INTERFACE%TYPE
                                                            := 'Mex GL Iface';
   g_package            apps.ttec_error_handling.program_name%TYPE
                                                   := 'ttec_mex_pay_gl_iface';
   g_status_warning     VARCHAR2 (7)                             := 'WARNING';
   g_status_failure     VARCHAR2 (7)                             := 'FAILURE';
   g_iface_hdr          apps.ttec_mex_gl_iface_stg.status%TYPE
                                                             := 'MEX PAY HDR';
   g_iface_line         apps.ttec_mex_gl_iface_stg.status%TYPE
                                                            := 'MEX PAY LINE';
   --END R12.2 Upgrade Remediation
   g_fail_flag          BOOLEAN                                      := FALSE;
   g_fail_msg           VARCHAR2 (240);
   -- Global Count Variables for logging information
   g_total_cnt          NUMBER                                           := 0;

--
-- PROCEDURE Main
--
-- Description: This is the main procedure to process the records in the ttec_mex_gl_iface_stg
--     table and then load into the GL_Interface table.
--
   PROCEDURE main (
      /*
	  START R12.2 Upgrade Remediation
	  code comented by RXNETHI-ARGANO,16/05/23
	  p_sob_id          IN   gl.gl_interface.set_of_books_id%TYPE,
      p_source          IN   gl.gl_interface.user_je_source_name%TYPE,
      p_category        IN   gl.gl_interface.user_je_category_name%TYPE,
      p_currency        IN   gl.gl_interface.currency_code%TYPE,
      p_batch_name      IN   gl.gl_interface.reference1%TYPE,
      p_batch_descr     IN   gl.gl_interface.reference2%TYPE,
      p_journal_name    IN   gl.gl_interface.reference4%TYPE,
      p_journal_descr   IN   gl.gl_interface.reference5%TYPE
      */
	  --code added by RXNETHI-ARGANO,16/05/23
	  p_sob_id          IN   apps.gl_interface.set_of_books_id%TYPE,
      p_source          IN   apps.gl_interface.user_je_source_name%TYPE,
      p_category        IN   apps.gl_interface.user_je_category_name%TYPE,
      p_currency        IN   apps.gl_interface.currency_code%TYPE,
      p_batch_name      IN   apps.gl_interface.reference1%TYPE,
      p_batch_descr     IN   apps.gl_interface.reference2%TYPE,
      p_journal_name    IN   apps.gl_interface.reference4%TYPE,
      p_journal_descr   IN   apps.gl_interface.reference5%TYPE
	  --END R12.2 Upgrade Remediation
   )
   IS
      --v_module          cust.ttec_error_handling.module_name%TYPE   := 'main';  --code commented by RXNETHI-ARGANO,16/05/23
      v_module          apps.ttec_error_handling.module_name%TYPE   := 'main';    --code added by RXNETHI-ARGANO,16/05/23
      v_user_id         fnd_user.user_id%TYPE;
      --v_acct_date       cust.ttec_mex_gl_iface_stg.accounting_date%TYPE; --code commented by RXNETHI-ARGANO,16/05/23
      v_acct_date       apps.ttec_mex_gl_iface_stg.accounting_date%TYPE;   --code added by RXNETHI-ARGANO,16/05/23
      e_no_hdr          EXCEPTION;
      e_too_many_hdrs   EXCEPTION;
      e_no_lines        EXCEPTION;
   BEGIN
      -- Get the UserID of the person who submitted the process
      v_user_id := fnd_global.user_id;

      -- Find the HDR record and copy the accouting date down to all Detail records
      BEGIN
         SELECT accounting_date
           INTO v_acct_date
           --FROM cust.ttec_mex_gl_iface_stg  --code commented by RXNETHI-ARGANO,16/05/23
           FROM apps.ttec_mex_gl_iface_stg    --code added by RXNETHI-ARGANO,16/05/23
          WHERE status = g_iface_hdr;
      EXCEPTION
         WHEN NO_DATA_FOUND
         THEN
            RAISE e_no_hdr;
         WHEN TOO_MANY_ROWS
         THEN
            RAISE e_too_many_hdrs;
         WHEN OTHERS
         THEN
            RAISE;
      END;

      -- Update the Acct Date on the Detail Records
      BEGIN
         --UPDATE cust.ttec_mex_gl_iface_stg   --code commented by RXNETHI-ARGANO,16/05/23
         UPDATE apps.ttec_mex_gl_iface_stg     --code added by RXNETHI-ARGANO,16/05/23
            SET accounting_date = v_acct_date
          WHERE status = g_iface_line;

         g_total_cnt := SQL%ROWCOUNT;

         IF g_total_cnt = 0
         THEN
            RAISE e_no_lines;
         END IF;
      EXCEPTION
         WHEN OTHERS
         THEN
            RAISE;
      END;

      -- Commit updates to the Staging table
      COMMIT;

      -- Copy the lines to the GL_INTERFACE table
      INSERT INTO gl_interface
                  (status, set_of_books_id, accounting_date, currency_code,
                   actual_flag, user_je_category_name, user_je_source_name,
                   user_currency_conversion_type, segment1, segment2,
                   segment3, segment4, segment5, segment6, entered_dr,
                   entered_cr, reference1, reference2, reference4, reference5,
                   date_created, created_by)
         SELECT 'NEW', p_sob_id, accounting_date, p_currency, actual_flag,
                p_category, p_source, user_currency_conversion_type, segment1,
                segment2, segment3, segment4, segment5, segment6, entered_dr,
                entered_cr, p_batch_name, p_batch_descr, p_journal_name,
                p_journal_descr, SYSDATE, v_user_id
           --FROM cust.ttec_mex_gl_iface_stg  --code commented by RXNETHI-ARGANO,16/05/23
           FROM apps.ttec_mex_gl_iface_stg    --code added by RXNETHI-ARGANO,16/05/23
          WHERE status = g_iface_line;

      COMMIT;
   EXCEPTION
      WHEN e_no_hdr
      THEN
         g_fail_flag := TRUE;
         g_fail_msg := 'Missing Header Record';
         --cust.ttec_process_error (application_code      => g_application_code,  --code commented by RXNETHI-ARGANO,16/05/23
         apps.ttec_process_error (application_code      => g_application_code,    --code added by RXNETHI-ARGANO,16/05/23
                                  INTERFACE             => g_interface,
                                  program_name          => g_package,
                                  module_name           => v_module,
                                  status                => g_status_failure,
                                  ERROR_CODE            => NULL,
                                  error_message         => g_fail_msg
                                 );
         ROLLBACK;
      WHEN e_too_many_hdrs
      THEN
         g_fail_flag := TRUE;
         g_fail_msg := 'More than one Header Record';
         --cust.ttec_process_error (application_code      => g_application_code,  --code commented by RXNETHI-ARGANO,16/05/23
         apps.ttec_process_error (application_code      => g_application_code,    --code added by RXNETHI-ARGANO,16/05/23
                                  INTERFACE             => g_interface,
                                  program_name          => g_package,
                                  module_name           => v_module,
                                  status                => g_status_failure,
                                  ERROR_CODE            => NULL,
                                  error_message         => g_fail_msg
                                 );
         ROLLBACK;
      WHEN e_no_lines
      THEN
         g_fail_flag := TRUE;
         g_fail_msg := 'No Detail Lines to process';
         --cust.ttec_process_error (application_code      => g_application_code,   --code commented by RXNETHI-ARGANO,16/05/23
         apps.ttec_process_error (application_code      => g_application_code,     --code added by RXNETHI-ARGANO,16/05/23
                                  INTERFACE             => g_interface,
                                  program_name          => g_package,
                                  module_name           => v_module,
                                  status                => g_status_failure,
                                  ERROR_CODE            => NULL,
                                  error_message         => g_fail_msg
                                 );
         ROLLBACK;
      WHEN OTHERS
      THEN
         g_fail_flag := TRUE;
         g_fail_msg := SUBSTR (SQLERRM, 1, 240);
         --cust.ttec_process_error (application_code      => g_application_code,   --code commented by RXNETHI-ARGANO,16/05/23
         apps.ttec_process_error (application_code      => g_application_code,     --code added by RXNETHI-ARGANO,16/05/23
                                  INTERFACE             => g_interface,
                                  program_name          => g_package,
                                  module_name           => v_module,
                                  status                => g_status_failure,
                                  ERROR_CODE            => SQLCODE,
                                  error_message         => g_fail_msg
                                 );
         ROLLBACK;
   END main;

--
-- PROCEDURE conc_mgr_wrapper
--
-- Description: This is a wrapper procedure to be called directly from the Concurrent
--   Mgr.  It will set Test Globals from input parameters and will output the final log.
--   This approach will allow the Main process to be ran/tested from the Conc Mgr.
--
   PROCEDURE conc_mgr_wrapper (
      errbuf            OUT      VARCHAR2,
      retcode           OUT      NUMBER,
      /*
	  START R12.2 Upgrade Remediation
	  code commented by RXNETHI-ARGANO,16/05/23
	  p_sob_id          IN       gl.gl_interface.set_of_books_id%TYPE,
      p_source          IN       gl.gl_interface.user_je_source_name%TYPE,
      p_category        IN       gl.gl_interface.user_je_category_name%TYPE,
      p_currency        IN       gl.gl_interface.currency_code%TYPE,
      p_batch_name      IN       gl.gl_interface.reference1%TYPE,
      p_batch_descr     IN       gl.gl_interface.reference2%TYPE,
      p_journal_name    IN       gl.gl_interface.reference4%TYPE,
      p_journal_descr   IN       gl.gl_interface.reference5%TYPE,
	  */
	  --code added by RXNETHI-ARGANO,16/05/23
	  p_sob_id          IN       apps.gl_interface.set_of_books_id%TYPE,
      p_source          IN       apps.gl_interface.user_je_source_name%TYPE,
      p_category        IN       apps.gl_interface.user_je_category_name%TYPE,
      p_currency        IN       apps.gl_interface.currency_code%TYPE,
      p_batch_name      IN       apps.gl_interface.reference1%TYPE,
      p_batch_descr     IN       apps.gl_interface.reference2%TYPE,
      p_journal_name    IN       apps.gl_interface.reference4%TYPE,
      p_journal_descr   IN       apps.gl_interface.reference5%TYPE,
	  --END R12.2 Upgrade Remediation
      p_keep_days       IN       NUMBER
   )
   IS
      v_start_timestamp   DATE      := SYSDATE;
      e_cleanup_err       EXCEPTION;
   BEGIN
      -- Submit the Main Process
      main (p_sob_id             => p_sob_id,
            p_source             => p_source,
            p_category           => p_category,
            p_currency           => p_currency,
            p_batch_name         => p_batch_name,
            p_batch_descr        => p_batch_descr,
            p_journal_name       => p_journal_name,
            p_journal_descr      => p_journal_descr
           );

      -- Log Counts
      BEGIN
         fnd_file.new_line (fnd_file.LOG, 1);
         fnd_file.put_line (fnd_file.LOG, 'COUNTS');
         fnd_file.put_line
                 (fnd_file.LOG,
                  '---------------------------------------------------------'
                 );
         fnd_file.put_line (fnd_file.LOG,
                            '# Records Processed         : ' || g_total_cnt
                           );
         fnd_file.put_line
                  (fnd_file.LOG,
                   '---------------------------------------------------------'
                  );
         fnd_file.new_line (fnd_file.LOG, 2);
         fnd_file.put_line (fnd_file.output, 'COUNTS');
         fnd_file.put_line
                  (fnd_file.output,
                   '---------------------------------------------------------'
                  );
         fnd_file.put_line (fnd_file.output,
                            '# Records Processed      : ' || g_total_cnt
                           );
         fnd_file.put_line
                  (fnd_file.output,
                   '---------------------------------------------------------'
                  );
         fnd_file.new_line (fnd_file.output, 2);
      EXCEPTION
         WHEN OTHERS
         THEN
            fnd_file.put_line (fnd_file.LOG, '   Error reporting Counts');
            retcode := 1;
      END;

      -- Log Errors / Warnings
      BEGIN
         ttec_error_logging.log_error_details
                                       (p_application        => g_application_code,
                                        p_interface          => g_interface,
                                        p_package            => g_package,
                                        p_message_type       => g_status_failure,
                                        p_message_label      => 'ERRORS',
                                        p_min_timestamp      => v_start_timestamp,
                                        p_max_timestamp      => SYSDATE
                                       );
      EXCEPTION
         WHEN OTHERS
         THEN
            fnd_file.put_line (fnd_file.LOG,
                               '   Error Reporting Errors / Warnings'
                              );
            retcode := 1;
      END;

      -- Remove Temp Data Files
      BEGIN
         NULL;
--    UTL_FILE.fremove( p_directory
--                    , p_filename );
      EXCEPTION
         WHEN OTHERS
         THEN
            fnd_file.put_line (fnd_file.LOG, SQLCODE || ': ' || SQLERRM);
            RAISE e_cleanup_err;
      END;

      -- Cleanup Batch Data Tables and Log Table
      BEGIN
         -- Purge old Logging Records for this Interface
         ttec_error_logging.purge_log_errors
                                        (p_application      => g_application_code,
                                         p_interface        => g_interface,
                                         p_package          => g_package,
                                         p_keep_days        => p_keep_days
                                        );
      EXCEPTION
         WHEN OTHERS
         THEN
            fnd_file.put_line (fnd_file.LOG, 'Error Cleaning up Log tables');
            fnd_file.put_line (fnd_file.LOG, SQLCODE || ': ' || SQLERRM);
            retcode := 2;
            errbuf := SQLERRM;
      END;

      IF g_fail_flag
      THEN
         fnd_file.put_line
                          (fnd_file.LOG,
                           'Refer to Output for Detailed Errors and Warnings'
                          );
         retcode := 2;
         errbuf := g_fail_msg;
      END IF;
   EXCEPTION
      WHEN e_cleanup_err
      THEN
         fnd_file.put_line (fnd_file.LOG, 'Error Cleaning Up Working Files');
         retcode := 1;
      WHEN OTHERS
      THEN
         fnd_file.put_line (fnd_file.LOG, SQLCODE || ': ' || SQLERRM);
         retcode := 2;
         errbuf := SQLERRM;
   END conc_mgr_wrapper;

--
-- FUNCTION submit_set
--
-- Description: This Procedure will be called by the Unix Shell script which loops
--   through all the files to be Interfaced and submits the Request Set once per
--   file.
--
   FUNCTION submit_set (
      p_user_id         IN   fnd_user.user_id%TYPE,
      p_resp_id         IN   fnd_responsibility.responsibility_id%TYPE,
      p_file_name       IN   VARCHAR2,
      /*
	  START R12.2 Upgrade Remediation
	  code commented by RXNETHI-ARGANO,16/05/23
	  p_sob_id          IN   gl_sets_of_books.set_of_books_id%TYPE,
      p_source          IN   gl.gl_interface.user_je_source_name%TYPE,
      p_category        IN   gl.gl_interface.user_je_category_name%TYPE,
      p_currency        IN   gl.gl_interface.currency_code%TYPE,
      p_batch_name      IN   gl.gl_interface.reference1%TYPE,
	  */
	  --code added by RXNETHI-ARGANO,16/05/23
	  p_sob_id          IN   gl_sets_of_books.set_of_books_id%TYPE,
      p_source          IN   apps.gl_interface.user_je_source_name%TYPE,
      p_category        IN   apps.gl_interface.user_je_category_name%TYPE,
      p_currency        IN   apps.gl_interface.currency_code%TYPE,
      p_batch_name      IN   apps.gl_interface.reference1%TYPE,
	  --END R12.2 Upgrade Remediation
      p_log_keep_days   IN   NUMBER,
      p_post_errors     IN   VARCHAR2,
      p_cr_summ_jrnls   IN   VARCHAR2,
      p_import_dff      IN   VARCHAR2
   )
      RETURN NUMBER
   IS
      success         BOOLEAN;
      v_procstep      VARCHAR2 (200);
      v_errmsg        VARCHAR2 (230);
      n_requestid     NUMBER (15)    := 0;
      v_resp_app_id   NUMBER;
      stop_program    EXCEPTION;
   BEGIN
      -- Get the Application ID for the Input Responsibility ID
      SELECT application_id
        INTO v_resp_app_id
        FROM fnd_responsibility
       WHERE responsibility_id = p_resp_id;

      fnd_global.apps_initialize (user_id           => p_user_id,
                                  resp_id           => p_resp_id,
                                  resp_appl_id      => v_resp_app_id
                                 );
      -- Submitting 'TeleTech Mexico Payroll GL Interface' request set
      v_procstep := 'Setting Context for Request Set';
      v_errmsg := 'Error while setting Conext for Request Set';
      success :=
         fnd_submit.set_request_set (application      => 'CUST',
                                     request_set      => 'TTEC_MEX_GL_IFACE_SET'
                                    );

      IF (NOT success)
      THEN
         RAISE stop_program;
      END IF;

      IF (success)
      THEN
         v_procstep := 'Submitting Stage10 for Request Set';
         v_errmsg := 'Error while Submitting Stage10 for Request Set';
         success :=
            fnd_submit.submit_program (application      => 'CUST',
                                       program          => 'TTEC_MEX_GL_IFACE_LOAD',
                                       stage            => 'STAGE10',
                                       argument1        => p_file_name
                                      );

         IF (NOT success)
         THEN
            RAISE stop_program;
         END IF;

         v_procstep := 'Submitting Stage20 for Request Set';
         v_errmsg := 'Error while Submitting Stage20 for Request Set';
         success :=
            fnd_submit.submit_program
                                     (application      => 'CUST',
                                      program          => 'TTEC_MEX_GL_IFACE_VALIDATE',
                                      stage            => 'STAGE20',
                                      argument1        => p_sob_id,
                                      argument2        => p_source,
                                      argument3        => p_category,
                                      argument4        => p_currency,
                                      argument5        => p_batch_name,   -- Batch Name
                                      argument6        => p_batch_name,   -- Batch Descr
                                      argument7        => p_batch_name,   -- JE Name
                                      argument8        => p_batch_name,   -- JE Descr
                                      argument9        => p_log_keep_days
                                     );

         IF (NOT success)
         THEN
            RAISE stop_program;
         END IF;

         v_procstep := 'Submitting Stage30 for Request Set';
         v_errmsg := 'Error while Submitting Stage30 for Request Set';
         success :=
            fnd_submit.submit_program (application      => 'GL',
                                       program          => 'GLLEZLSRS',
                                       stage            => 'STAGE30',
                                       argument1        => p_sob_id,
                                       argument2        => p_source,
                                       argument3        => NULL,   -- Group ID
                                       argument4        => p_post_errors,
                                       argument5        => p_cr_summ_jrnls,
                                       argument6        => p_import_dff
                                      );

         IF (NOT success)
         THEN
            RAISE stop_program;
         END IF;

         v_procstep := 'Submitting Request Set';
         v_errmsg := 'Error while Submitting Request Set';
         n_requestid :=
              fnd_submit.submit_set (start_time       => NULL,
                                     sub_request      => FALSE);
         fnd_file.put_line (fnd_file.LOG,
                            'Request ID for Request Set : ' || n_requestid
                           );

         IF (n_requestid <= 0)
         THEN
            RAISE stop_program;
         ELSE
            COMMIT;
         END IF;
      END IF;

      RETURN n_requestid;
   EXCEPTION
      WHEN stop_program
      THEN
         DBMS_OUTPUT.put_line ('Step: ' || v_procstep || ' Message: '
                               || v_errmsg
                              );
         fnd_file.put_line (fnd_file.LOG,
                            'Step :' || v_procstep || ' Message :' || v_errmsg
                           );
         DBMS_OUTPUT.put_line (fnd_message.get);
         fnd_file.put_line (fnd_file.LOG, fnd_message.get);
         ROLLBACK;
         RETURN 0;
      WHEN OTHERS
      THEN
         DBMS_OUTPUT.put_line ('Step: ' || v_procstep || ' Message: '
                               || v_errmsg
                              );
         fnd_file.put_line (fnd_file.LOG,
                            'Step :' || v_procstep || ' Message :' || v_errmsg
                           );
         DBMS_OUTPUT.put_line (   'SQLCODE :'
                               || TO_CHAR (SQLCODE)
                               || ' SQLERRM :'
                               || SUBSTR (SQLERRM, 1, 200)
                              );
         fnd_file.put_line (fnd_file.LOG,
                               'SQLCODE :'
                            || TO_CHAR (SQLCODE)
                            || ' SQLERRM :'
                            || SUBSTR (SQLERRM, 1, 200)
                           );
         ROLLBACK;
         RETURN 0;
   END submit_set;
END ttec_mex_pay_gl_iface;
/
show errors;
/