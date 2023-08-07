create or replace PACKAGE BODY ttec_ap_amex_svi_interface
IS
/*== START ================================================================================================*\
  Author:  Kaushik Babu
    Date:  May 06, 2009
    Desc:  This package is for the purpose of adding new credit cards to the custom table and update
           changes for employee location/dept info, address, terminations, email address. This
           process sends email to the user about the changes as per scheduled in prodcution
  Concurrent program: TeleTech Amex Payables SVI Outbound Interface
  Parameters:     Run Date: Changes queried as per run date
                  email address: receipient email address for the changes to be sent
                  First time run : IF 'the value is Y' select all the credit cards in the database and upload into custom table
                                   IF the value is 'N' then changes are compared to the first run and sent to the user about the changes
  Modification History:

 Mod#  Person         Date     Comments
---------------------------------------------------------------------------
 1.0  Kaushik Babu  01-AUG-08 Created package
 1.1  Kaushik BAbu  14-May-09 Fixed code for 'CC' invalid identifier error
 1.2  Kaushik Babu  02-Jun-09 Fixed code for invalid identifier error
 1.3  Lalitha       21-AUG-15 Rehosting changes for smtp server
 1.0  MXKEERTHI(ARGANO)  18-JUL-2023              R12.2 Upgrade Remediation
\*== END ==================================================================================================*/
   g_run_date                CONSTANT DATE                 := TRUNC (SYSDATE);
   g_oracle_start_date       CONSTANT DATE         := TO_DATE ('01-JAN-1950');
   g_oracle_end_date         CONSTANT DATE         := TO_DATE ('31-DEC-4712');
   g_basic_cntl_acc_number   CONSTANT NUMBER               := 379114191901000;
   --
   g_delimt                           CHAR (1)                         := '|';
   /* error handling parameters */
   g_e_program_run_status             NUMBER                             := 0;
    --   g_e_error_hand                     cust.ttec_error_handling%ROWTYPE;  --Commented code by MXKEERTHI-ARGANO,07/18/2023
   g_e_error_hand                     apps.ttec_error_handling%ROWTYPE;  --code added by MXKEERTHI-ARGANO, 07/18/2023

   g_out_table_name                   VARCHAR2 (64)
                                             --:= 'CUST.TTEC_AP_AMEX_INTERF_DB'; --Commented code by MXKEERTHI-ARGANO,07/18/2023
                                             := 'APPS.TTEC_AP_AMEX_INTERF_DB'; --Added code by MXKEERTHI-ARGANO,07/18/2023

/*
------------------------------------------------------------------------------------------------
print a line to the log
------------------------------------------------------------------------------------------------
*/
   PROCEDURE print_line (p_data IN VARCHAR2)
   IS
   BEGIN
      fnd_file.put_line (fnd_file.LOG, p_data);
   END;

/* email results and output file as requested */
   PROCEDURE send_email_result (
      p_status          IN   NUMBER,
      p_host_name       IN   VARCHAR2,
      p_email_to_list   IN   VARCHAR2,
      p_filedir         IN   VARCHAR2,
      p_filename        IN   VARCHAR2
   )
   IS
      v_body          VARCHAR2 (4000) := ' Please review output file';
      v_email_from    VARCHAR2 (80)   := 'EBSDevelopment@teletech.com';
      v_email_subj    VARCHAR2 (256);
      v_email_body1   VARCHAR2 (256)  := NULL;
      v_email_body2   VARCHAR2 (256)  := NULL;
      v_email_body3   VARCHAR2 (256)  := NULL;
      v_email_body4   VARCHAR2 (256)  := NULL;
      v_mesg          VARCHAR2 (256)  := NULL;
      crlf            CHAR (2)        := CHR (10) || CHR (13);
      cr              CHAR (2)        := CHR (13);
      v_status2       NUMBER;
   BEGIN
      g_e_error_hand.module_name := 'send_email_result';
      v_body := 'Main Processed: ';

      IF (LENGTH (p_email_to_list) < 5)
      THEN
         RETURN;
      END IF;

      IF g_e_program_run_status = 0
      THEN
         v_email_subj :=
               'SUCCESS - TeleTech AMEX Employee Update Information Interface Output- '
            || v_email_subj
            || TO_CHAR (SYSDATE, 'DD-MON-RR  HH:MI AM');
         v_body :=
               'Run Result for TeleTech AMEX Employee Update Information Interface : * * * SUCCESS * * * '
            || crlf
            || v_email_body3
            || crlf
            || 'File attached'
            || p_filedir
            || '/'
            || p_filename
            || crlf
            || v_email_body4;
      ELSE
         v_email_subj :=
               'FAILURE - TeleTech AMEX Employee Update Information Interface Output '
            || v_email_subj;
         v_body :=
               'Run Result for TeleTech AMEX Employee Update Information Interface Output : * * * FAILURE * * * '
            || crlf
            || v_email_body3
            || crlf
            || 'Output File Creation Error: Check email list. Contact EBS Development '
            || p_filedir
            || '/'
            || p_filename
            || crlf
            || v_email_body4;
      END IF;

      send_email (ttec_library.XX_TTEC_SMTP_SERVER, /*p_host_name,*/ --rehosting changes
                  v_email_from,
                  p_email_to_list,
                  NULL,
                  NULL,
                  v_email_subj,                                  -- v_subject,
                  crlf || v_email_body1 || v_email_body2 || crlf,
                  -- NULL, --                        v_line1,
                  v_body,
                  NULL,
                  NULL,
                  NULL,
                  p_filedir || '/' || p_filename,
                  -- file_to_send,                                 -- v_file_name,
                  NULL,
                  NULL,
                  NULL,
                  NULL,
                  v_status2,
                  v_mesg
                 );
   EXCEPTION
      WHEN OTHERS
      THEN
         log_error ('Routine',
                    g_e_error_hand.module_name,
                    'Error Message',
                    SUBSTR (SQLERRM, 1, 80)
                   );
         print_line ('Error in module: ' || g_e_error_hand.module_name);
         print_line (   'Failed  with Error '
                     || SQLCODE
                     || '|'
                     || SUBSTR (SQLERRM, 1, 80)
                    );
         g_e_program_run_status := 1;
   END;

/*
------------------------------------------------------------------------------------------------
not used at present, we are using max two parameters to report errror
use to null all error parameters, remember you may not use all error parameters for every call
------------------------------------------------------------------------------------------------
*/
   PROCEDURE errvar_null (p_status OUT NUMBER)
   IS
   BEGIN
      g_e_error_hand := NULL;
      g_e_error_hand.module_name := 'errval_null';
      g_e_error_hand.status := 'FAILURE';
      g_e_error_hand.application_code := 'AP';
      g_e_error_hand.INTERFACE := 'TTECAPINTRFTBL';
      g_e_error_hand.program_name := 'TTEC_AP_AMEX_SVI_IFACE';
      g_e_error_hand.ERROR_CODE := 0;                            -- if needed
   EXCEPTION
      WHEN OTHERS
      THEN
         log_error ('SQLCODE',
                    TO_CHAR (SQLCODE),
                    'Error Message',
                    SUBSTR (SQLERRM, 1, 64)
                   );
         print_line ('Error in module: ' || g_e_error_hand.module_name);
         print_line (   'Failed  with Error '
                     || TO_CHAR (SQLCODE)
                     || '|'
                     || SUBSTR (SQLERRM, 1, 64)
                    );
         g_e_program_run_status := 1;
   END;

/*
------------------------------------------------------------------------------------------------
build output file header
------------------------------------------------------------------------------------------------
*/
   PROCEDURE build_header_rec (p_rec OUT VARCHAR2)
   IS
   BEGIN
      g_e_error_hand.module_name := 'build_header_rec';
      p_rec :=
            'H'
         || '613330'
         || RPAD (' ', 2, ' ')
         || 'TELETECH SERVICE CO '
         || '3791-112609-21000'
         || TO_CHAR (TO_DATE (SYSDATE), 'MM/DD/YY')
         || RPAD (' ', 3, ' ')
         || RPAD (' ', 3, ' ')
         || RPAD (' ', 343, ' ');
   EXCEPTION
      WHEN OTHERS
      THEN
         log_error ('SQLCODE',
                    TO_CHAR (SQLCODE),
                    'Error Message',
                    SUBSTR (SQLERRM, 1, 64)
                   );
         print_line ('Error in module: ' || g_e_error_hand.module_name);
         print_line (   'Failed  with Error '
                     || TO_CHAR (SQLCODE)
                     || '|'
                     || SUBSTR (SQLERRM, 1, 64)
                    );
         g_e_program_run_status := 1;
   END;

/*
------------------------------------------------------------------------------------------------
file trailer record, account for recod count if needed
------------------------------------------------------------------------------------------------
*/
   PROCEDURE build_trailer_rec (
      p_rec_count        IN       NUMBER,
      p_first_time_run            VARCHAR2,
      p_rec              OUT      VARCHAR2
   )
   IS
      v_count   VARCHAR2 (7);
   BEGIN
      g_e_error_hand.module_name := 'build_trailer_rec';

      IF UPPER (p_first_time_run) = 'Y'
      THEN
         SELECT LPAD (COUNT (*), 6, 0)
           INTO v_count
		    --          FROM cust.ttec_ap_amex_interf_db;  --Commented code by MXKEERTHI-ARGANO,07/18/2023
          FROM apps.ttec_ap_amex_interf_db;  --code added by MXKEERTHI-ARGANO, 07/18/2023


         p_rec := 'T' || v_count || RPAD (' ', 393, ' ');
      ELSE
         SELECT LPAD (COUNT (*), 6, 0)
           INTO v_count
		    --          FROM cust.ttec_ap_amex_interf_db --Commented code by MXKEERTHI-ARGANO,07/18/2023
          FROM apps.ttec_ap_amex_interf_db --code added by MXKEERTHI-ARGANO, 07/18/2023

          WHERE tran_type IN ('NC', 'CC', '07', '13', '03', '05');

         p_rec := 'T' || v_count || RPAD (' ', 393, ' ');
      END IF;
   EXCEPTION
      WHEN OTHERS
      THEN
         log_error ('SQLCODE',
                    TO_CHAR (SQLCODE),
                    'Error Message',
                    SUBSTR (SQLERRM, 1, 64)
                   );
         print_line ('Error in module: ' || g_e_error_hand.module_name);
         print_line (   'Failed  with Error '
                     || TO_CHAR (SQLCODE)
                     || '|'
                     || SUBSTR (SQLERRM, 1, 64)
                    );
         g_e_program_run_status := 1;
   END;

   /* build the data record that is going to be output to the translated file */
   /* do translation and formatting in this routine */
   PROCEDURE build_data_rec (
      p_rec_in    IN       c_rec2_q%ROWTYPE,           -- in record from query
	 --      p_rec_out   OUT      cust.ttec_ap_amex_interf_db%ROWTYPE --Commented code by MXKEERTHI-ARGANO,07/18/2023
      p_rec_out   OUT      apps.ttec_ap_amex_interf_db%ROWTYPE  --code added by MXKEERTHI-ARGANO, 07/18/2023

   )                                                 -- out record to be built
   IS
   BEGIN
      g_e_error_hand.module_name := 'build_data_rec';
      -- null my output
      p_rec_out := NULL;
      p_rec_out.rec_type := 'D';
      p_rec_out.tran_type := 'NC';
      p_rec_out.cm_acc_num :=
            SUBSTR (p_rec_in.card_number, 1, 4)
         || '-'
         || SUBSTR (p_rec_in.card_number, 5, 6)
         || '-'
         || SUBSTR (p_rec_in.card_number, 11);
      p_rec_out.bc_acc_num :=
            SUBSTR (g_basic_cntl_acc_number, 1, 4)
         || '-'
         || SUBSTR (g_basic_cntl_acc_number, 5, 6)
         || '-'
         || SUBSTR (g_basic_cntl_acc_number, 11);
      p_rec_out.emp_name := RPAD (p_rec_in.full_name, 20, ' ');
      p_rec_out.corp_name := 'TELETECH SERVICE CO ';
      p_rec_out.m_add_street :=
                              RPAD (SUBSTR (p_rec_in.address, 1, 20), 20, ' ');
      p_rec_out.m_add_city_state :=
         RPAD (SUBSTR ((p_rec_in.town_or_city || ' ' || p_rec_in.region_2),
                       1,
                       20
                      ),
               20,
               ' '
              );
      p_rec_out.m_zipcode := RPAD (p_rec_in.postal_code, 5, ' ');
      p_rec_out.emp_id :=
                      RPAD (SUBSTR (p_rec_in.employee_number, 1, 10), 10, ' ');
      p_rec_out.emp_cost_ctr :=
                        RPAD (SUBSTR (p_rec_in.location_dept, 1, 10), 10, ' ');
      p_rec_out.h_add_street :=
                              RPAD (SUBSTR (p_rec_in.address, 1, 20), 20, ' ');
      p_rec_out.h_add_city :=
                         RPAD (SUBSTR (p_rec_in.town_or_city, 1, 18), 18, ' ');
      p_rec_out.h_add_state := RPAD (SUBSTR (p_rec_in.region_2, 1, 2), 2, ' ');
      p_rec_out.h_add_zcode := RPAD (p_rec_in.postal_code, 5, ' ');
      p_rec_out.h_phone_num :=
                         RPAD (SUBSTR (p_rec_in.phone_number, 1, 10), 10, ' ');
      p_rec_out.filler := RPAD (' ', 23, ' ');
      p_rec_out.gsi_data := RPAD (' ', 60, ' ');
      p_rec_out.emp_ssn :=
         RPAD (SUBSTR (REPLACE (p_rec_in.national_identifier, '-', ''), 1, 9),
               9,
               ' '
              );
      p_rec_out.emp_uni_num :=
                        RPAD (SUBSTR (p_rec_in.email_address, 1, 25), 25, ' ');
      p_rec_out.anp_ssn_num := RPAD (' ', 9, ' ');
      p_rec_out.anp_emp_id := RPAD (' ', 9, ' ');
      p_rec_out.anp_cost_ctr := RPAD (' ', 10, ' ');
      p_rec_out.anp_uni_num := RPAD (' ', 25, ' ');
      p_rec_out.m_filler := RPAD (' ', 30, ' ');
   EXCEPTION
      WHEN OTHERS
      THEN
         log_error ('SQLCODE',
                    TO_CHAR (SQLCODE),
                    'Error Message',
                    SUBSTR (SQLERRM, 1, 64)
                   );
         print_line ('Error in module: ' || g_e_error_hand.module_name);
         print_line (   'Failed  with Error '
                     || TO_CHAR (SQLCODE)
                     || '|'
                     || SUBSTR (SQLERRM, 1, 64)
                    );
         g_e_program_run_status := 1;
   END;

   /* initialize error message */
   PROCEDURE init_error_msg
   IS
   BEGIN
      g_e_error_hand := NULL;
      g_e_error_hand.module_name := 'main';
      g_e_error_hand.status := 'FAILURE';
      g_e_error_hand.application_code := 'GL';
      g_e_error_hand.INTERFACE := 'TTECAPINTRFTBL';
      g_e_error_hand.program_name := 'TTEC_AP_AMEX_SVI_IFACE';
      g_e_error_hand.ERROR_CODE := 0;
   END;

/*---------------------------------------------------------------------------------------------------------
    Name:  Log error  PROCEDURE
    Description:  PROCEDURE standardizes concurrent program EXCEPTION handling
    error reporting routine built on TTECH Error handling table and library
    here we are using two parameters max, I kept it since we will be using this as example
   ---------------------------------------------------------------------------------------------------------*/
   PROCEDURE log_error (
      p_label1       IN   VARCHAR2,
      p_reference1   IN   VARCHAR2,
      p_label2       IN   VARCHAR2,
      p_reference2   IN   VARCHAR2
   )
   IS
   BEGIN
      -- not in this routine g_e_error_hand.module_name := 'log_error'

      -- g_e_error_hand := NULL;
      g_e_error_hand.ERROR_CODE := TO_CHAR (SQLCODE);
      g_e_error_hand.error_message := SUBSTR (SQLERRM, 1, 240);
      --cust.ttec_process_error (g_e_error_hand.application_code, --Commented code by MXKEERTHI-ARGANO,07/18/2023
      apps.ttec_process_error (g_e_error_hand.application_code, --Added code by MXKEERTHI-ARGANO,07/18/2023
                               g_e_error_hand.INTERFACE,
                               g_e_error_hand.program_name,
                               g_e_error_hand.module_name,
                               g_e_error_hand.status,
                               g_e_error_hand.ERROR_CODE,
                               g_e_error_hand.error_message,
                               p_label1,
                               p_reference1,
                               p_label2,
                               p_reference2,
                               g_e_error_hand.label3,
                               g_e_error_hand.reference3,
                               g_e_error_hand.label4,
                               g_e_error_hand.reference4,
                               g_e_error_hand.label5,
                               g_e_error_hand.reference5,
                               g_e_error_hand.label6,
                               g_e_error_hand.reference6,
                               g_e_error_hand.label7,
                               g_e_error_hand.reference7,
                               g_e_error_hand.label8,
                               g_e_error_hand.reference8,
                               g_e_error_hand.label9,
                               g_e_error_hand.reference9,
                               g_e_error_hand.label10,
                               g_e_error_hand.reference10,
                               g_e_error_hand.label11,
                               g_e_error_hand.reference11,
                               g_e_error_hand.label12,
                               g_e_error_hand.reference12,
                               g_e_error_hand.label13,
                               g_e_error_hand.reference13,
                               g_e_error_hand.label14,
                               g_e_error_hand.reference14,
                               g_e_error_hand.label15,
                               g_e_error_hand.reference15
                              );
   EXCEPTION
      WHEN OTHERS
      THEN
         -- log_error ('Routine', e_module_name, 'Error Message', SUBSTR (SQLERRM, 1, 80) );
         print_line ('Error in module: ' || g_e_error_hand.module_name);
         print_line (   'Failed  with Error '
                     || TO_CHAR (SQLCODE)
                     || '|'
                     || SUBSTR (SQLERRM, 1, 64)
                    );
         g_e_program_run_status := 1;
   END;

   PROCEDURE write_data_to_record (
    --     p_rec_db    IN       cust.ttec_ap_amex_interf_db%ROWTYPE, --Commented code by MXKEERTHI-ARGANO,07/18/2023
     p_rec_db    IN       apps.ttec_ap_amex_interf_db%ROWTYPE,  --code added by MXKEERTHI-ARGANO, 07/18/2023

      p_rec_out   IN OUT   VARCHAR2
   )
   IS
   BEGIN
      g_e_error_hand.module_name := 'write_data_to_record';
      p_rec_out :=
            p_rec_db.rec_type
         || NVL (RPAD (p_rec_db.tran_type, 2, ' '), RPAD (' ', 2, ' '))
         || p_rec_db.cm_acc_num
         || p_rec_db.bc_acc_num
         || p_rec_db.emp_name
         || p_rec_db.corp_name
         || p_rec_db.m_add_street
         || p_rec_db.m_add_city_state
         || p_rec_db.m_zipcode
         || p_rec_db.emp_id
         || p_rec_db.emp_cost_ctr
         || p_rec_db.h_add_street
         || p_rec_db.h_add_city
         || p_rec_db.h_add_state
         || p_rec_db.h_add_zcode
         || p_rec_db.h_phone_num
         || p_rec_db.filler
         || p_rec_db.gsi_data
         || p_rec_db.emp_ssn
         || p_rec_db.emp_uni_num
         || p_rec_db.anp_ssn_num
         || p_rec_db.anp_emp_id
         || p_rec_db.anp_cost_ctr
         || p_rec_db.anp_uni_num
         || p_rec_db.m_filler;
   EXCEPTION
      WHEN OTHERS
      THEN
         log_error ('Routine',
                    g_e_error_hand.module_name,
                    'Error Message',
                    SUBSTR (SQLERRM, 1, 80)
                   );
         print_line ('Error in module: ' || g_e_error_hand.module_name);
         print_line (   'Failed  with Error '
                     || SQLCODE
                     || '|'
                     || SUBSTR (SQLERRM, 1, 80)
                    );
         g_e_program_run_status := 1;
   END;

   PROCEDURE insert_data_rec_in_db (
    --     p_rec_db   IN   cust.ttec_ap_amex_interf_db%ROWTYPE --Commented code by MXKEERTHI-ARGANO,07/18/2023
     p_rec_db   IN   apps.ttec_ap_amex_interf_db%ROWTYPE  --code added by MXKEERTHI-ARGANO, 07/18/2023

   )
   IS
   BEGIN
      g_e_error_hand.module_name := 'insert_data_rec_in_db';
 --     INSERT INTO cust.ttec_ap_amex_interf_db--Commented code by MXKEERTHI-ARGANO,07/18/2023
     INSERT INTO apps.ttec_ap_amex_interf_db --code added by MXKEERTHI-ARGANO, 07/18/2023

           VALUES p_rec_db;
   EXCEPTION
      WHEN OTHERS
      THEN
         log_error ('SQLCODE',
                    TO_CHAR (SQLCODE),
                    'Error Message',
                    SUBSTR (SQLERRM, 1, 64)
                   );
         print_line ('Error in module: ' || g_e_error_hand.module_name);
         print_line (   'Failed  with Error '
                     || TO_CHAR (SQLCODE)
                     || '|'
                     || SUBSTR (SQLERRM, 1, 64)
                    );
         g_e_program_run_status := 1;
   END;

/* procedure to build select statment
      p_owner_name    IN  name of owner
      p_table_name    IN   name of table
     p_where_clause  IN   where clause, must contain full clause e.g. WHERE X = Y
      p_order_by      IN    order by clause must contain full clause e.g order by 1 DESC- remember there is one field in SQL
      p_rec_out      IN OUT   the full built select statement
*/
   PROCEDURE build_sql_select_statement (
      p_owner_name     IN       VARCHAR2,
      p_table_name     IN       VARCHAR2,
      p_alias_name     IN       VARCHAR2,
      p_where_clause   IN       VARCHAR2,
      p_order_by       IN       VARCHAR2,
      p_rec_out        IN OUT   VARCHAR2
   )
   IS
      /* cursor to get the field names in a table */
      CURSOR c_tbl_field_names (
         p_table_name   IN   VARCHAR2,
         p_owner_name   IN   VARCHAR2
      )
      IS
         SELECT   column_name
             FROM all_tab_columns                         --  dba_tab_columns
            WHERE table_name = UPPER (p_table_name)
              AND owner = UPPER (p_owner_name)
         ORDER BY column_id;

      v_len          NUMBER;
      v_alias_name   VARCHAR2 (8) := 'V_DATA';
   BEGIN
      g_e_error_hand.module_name := 'build_sql_select_record';
      v_alias_name := NVL (p_alias_name, v_alias_name);
      p_rec_out := NULL;

      /* loop to collect all the coulmn names */
      FOR v_rec2 IN c_tbl_field_names (p_table_name, p_owner_name)
      LOOP
         IF v_rec2.column_name NOT IN ('EMP_SSN', 'CM_ACC_NUM')
         THEN
-------------------------------------------------------------------------------------------------------------------------
            p_rec_out := p_rec_out || ' || ' || v_rec2.column_name;
         END IF;
      END LOOP;

      /* remove first || */
      p_rec_out := SUBSTR (p_rec_out, 5) || ' ' || v_alias_name;
      /* build the query */
      p_rec_out :=
            'SELECT '
         || p_rec_out
         || ' FROM '
         || p_owner_name
         || '.'
         || p_table_name
         || ' '
         || p_where_clause
         || ' '
         || p_order_by;
      print_line (p_rec_out);
   EXCEPTION
      WHEN OTHERS
      THEN
         log_error ('SQLCODE',
                    TO_CHAR (SQLCODE),
                    'Error Message',
                    SUBSTR (SQLERRM, 1, 64)
                   );
         print_line ('Error in module: ' || g_e_error_hand.module_name);
         print_line (   'Failed  with Error '
                     || TO_CHAR (SQLCODE)
                     || '|'
                     || SUBSTR (SQLERRM, 1, 64)
                    );
         g_e_program_run_status := 1;
   END;

   /* this routine will read data from table and write it to an open file */
   PROCEDURE write_sql_results_file (
      p_output_file     IN   UTL_FILE.file_type,
      p_sql_statement   IN   VARCHAR2
   )
   IS
      TYPE cur_type IS REF CURSOR;

      c_get_data     cur_type;            --define variable of a cursor type.
      v_query_str    VARCHAR2 (4000);
      v_my_results   VARCHAR2 (4000);
   BEGIN
      g_e_error_hand.module_name := 'write_sql_results_file';
      v_query_str := p_sql_statement;

      /* open a reference cursor and select data from table, write data to open file */
      OPEN c_get_data FOR v_query_str;           -- vriable of a cursor type.

      LOOP
         FETCH c_get_data
          INTO v_my_results;

         EXIT WHEN c_get_data%NOTFOUND;
         UTL_FILE.put_line (p_output_file, v_my_results);
         fnd_file.put_line (fnd_file.output, v_my_results);
      END LOOP;

      CLOSE c_get_data;
   EXCEPTION
      WHEN OTHERS
      THEN
         log_error ('SQLCODE',
                    TO_CHAR (SQLCODE),
                    'Error Message',
                    SUBSTR (SQLERRM, 1, 64)
                   );
         print_line ('Error in module: ' || g_e_error_hand.module_name);
         print_line (   'Failed  with Error '
                     || TO_CHAR (SQLCODE)
                     || '|'
                     || SUBSTR (SQLERRM, 1, 64)
                    );
         g_e_program_run_status := 1;

         IF c_get_data%ISOPEN
         THEN
            CLOSE c_get_data;
         END IF;
   END;

   PROCEDURE truncate_table (p_owner_name IN VARCHAR2, p_table_name IN VARCHAR2)
   IS
      v_truncate_table   VARCHAR2 (64) := 'truncate table ';
   BEGIN
      g_e_error_hand.module_name := 'truncate_table';

      EXECUTE IMMEDIATE v_truncate_table || p_owner_name || '.'
                        || p_table_name;
   EXCEPTION
      WHEN OTHERS
      THEN
         log_error ('SQLCODE',
                    TO_CHAR (SQLCODE),
                    'Error Message',
                    SUBSTR (SQLERRM, 1, 64)
                   );
         print_line ('Error in module: ' || g_e_error_hand.module_name);
         print_line (   'Failed  with Error '
                     || TO_CHAR (SQLCODE)
                     || '|'
                     || SUBSTR (SQLERRM, 1, 64)
                    );
   END;

   PROCEDURE GET_FILE_NAME (p_dir_name OUT VARCHAR2, p_file_name OUT VARCHAR2)
   IS
   BEGIN
      OPEN c_directory_path;

      FETCH c_directory_path
       INTO p_dir_name, p_file_name;

      CLOSE c_directory_path;
   EXCEPTION
      WHEN OTHERS
      THEN
         log_error ('SQLCODE',
                    TO_CHAR (SQLCODE),
                    'Error Message',
                    SUBSTR (SQLERRM, 1, 64)
                   );
         print_line ('Error in module: ' || g_e_error_hand.module_name);
         print_line (   'Failed  with Error '
                     || TO_CHAR (SQLCODE)
                     || '|'
                     || SUBSTR (SQLERRM, 1, 64)
                    );
   END;

/*
------------------------------------------------------------------------------------------------
main processing program
------------------------------------------------------------------------------------------------
*/
   PROCEDURE main (
      errcode                 VARCHAR2,
      errbuff                 VARCHAR2,
      p_date             IN   VARCHAR2,
      p_email_to_list    IN   VARCHAR2,
      p_first_time_run   IN   VARCHAR2
   )
   IS
-- Filehandle Variables
      v_dir_name                  VARCHAR2 (128);
      v_file_name                 VARCHAR2 (64);
      v_full_file_path            VARCHAR2 (200);
      v_output_file               UTL_FILE.file_type;
      v_country                   VARCHAR2 (10);
      v_stage                     VARCHAR2 (64);
      v_status                    NUMBER                                 := 0;
      v_msg                       VARCHAR2 (256);
      -- Declare program variables
      v_rec                       VARCHAR2 (4000);
      v_key                       VARCHAR2 (400);
      v_file_num                  VARCHAR2 (4)                        := '01';
      v_host_name                 VARCHAR2 (256);
      v_tot_rec_count             NUMBER;
      v_seq                       NUMBER;
	   --     v_rec_db                    cust.ttec_ap_amex_interf_db%ROWTYPE;  --Commented code by MXKEERTHI-ARGANO,07/18/2023
     v_rec_db                    apps.ttec_ap_amex_interf_db%ROWTYPE;  --code added by MXKEERTHI-ARGANO, 07/18/2023

      v_table_name                VARCHAR2 (80)   := 'TTEC_AP_AMEX_INTERF_DB';
      --   v_my_sql VARCHAR2(4000);
      v_owner_name                VARCHAR2 (80)                     := 'CUST';
      v_alias_name                VARCHAR2 (16);
      v_where_clause              VARCHAR2 (32);
      v_where_clause1             VARCHAR2 (75)
         :=    'Where tran_type IN ('
            || ''''
            || 'NC'
            || ''''
            || ','
            || ''''
            || 'CC'
            || ''''
            || ','
            || ''''
            || '07'
            || ''''
            || ','
            || ''''
            || '13'
            || ''''
            || ','
            || ''''
            || '03'
            || ''''
            || ','
            || ''''
            || '05'
            || ''''
            || ')';                                             -- Verison 1.2
      v_order_by                  VARCHAR2 (32)                := 'Order by 1';
      v_rec_out                   VARCHAR2 (4000);
      v_email_err                 NUMBER;
      v_email_subj                VARCHAR2 (200);
      v_email_body                VARCHAR2 (200);
      v_value                     VARCHAR2 (1);
	      --START R12.2 Upgrade Remediation
	  /*
	    	Commented code by MXKEERTHI-ARGANO,07/18/2023
      v_cm_acc_num                cust.ttec_ap_amex_interf_db.cm_acc_num%TYPE;
      v_cost_cnt_chg              cust.ttec_ap_amex_interf_db.emp_cost_ctr%TYPE;
      v_add_street                cust.ttec_ap_amex_interf_db.m_add_street%TYPE;
      v_add_city_state            cust.ttec_ap_amex_interf_db.m_add_city_state%TYPE;
      v_zipcode                   cust.ttec_ap_amex_interf_db.m_zipcode%TYPE;
      v_emp_uni_num               cust.ttec_ap_amex_interf_db.emp_uni_num%TYPE;
      v_system_person_type        per_person_types.system_person_type%TYPE;
      v_tran_type                 cust.ttec_ap_amex_interf_db.tran_type%TYPE;
      v_actual_termination_date   per_periods_of_service.actual_termination_date%TYPE;
	   */
	  --code Added  by MXKEERTHI-ARGANO, 07/18/2023
     v_cm_acc_num                 apps.ttec_ap_amex_interf_db.cm_acc_num%TYPE;
      v_cost_cnt_chg              apps.ttec_ap_amex_interf_db.emp_cost_ctr%TYPE;
      v_add_street                apps.ttec_ap_amex_interf_db.m_add_street%TYPE;
      v_add_city_state            apps.ttec_ap_amex_interf_db.m_add_city_state%TYPE;
      v_zipcode                   apps.ttec_ap_amex_interf_db.m_zipcode%TYPE;
      v_emp_uni_num               apps.ttec_ap_amex_interf_db.emp_uni_num%TYPE;
      v_system_person_type        per_person_types.system_person_type%TYPE;
      v_tran_type                 apps.ttec_ap_amex_interf_db.tran_type%TYPE;
      v_actual_termination_date   per_periods_of_service.actual_termination_date%TYPE;
	  --END R12.2.10 Upgrade remediation


   BEGIN
      /* set global paramJeters for error handling */
      OPEN c_host;

      FETCH c_host
       INTO v_host_name;

      CLOSE c_host;

      init_error_msg;
      GET_FILE_NAME (v_dir_name, v_file_name);
      v_full_file_path := v_dir_name || '/' || v_file_name;
      print_line (v_file_name);
      -- v_stage := 'c_open_file';
      v_output_file := UTL_FILE.fopen (v_dir_name, v_file_name, 'w', 32000);
      print_line ('**********************************');
      print_line ('Output file created >>> ' || v_dir_name || '/'
                  || v_file_name
                 );
      print_line ('**********************************');
      print_line ('Output file created >>> ' || v_dir_name || '/'
                  || v_file_name
                 );
      print_line ('**********************************');
      v_tot_rec_count := 0;
      --truncate_table (v_owner_name, v_table_name);
      --  v_stage := 'Header Record';
      build_header_rec (v_rec);
      apps.fnd_file.put_line (apps.fnd_file.output, v_rec);
      UTL_FILE.put_line (v_output_file, v_rec);
      print_line ('**************build_out_record' || 'xx');

      --UPDATE cust.ttec_ap_amex_interf_db  --Commented code by MXKEERTHI-ARGANO,07/18/2023
      UPDATE apps.ttec_ap_amex_interf_db  --Added code by MXKEERTHI-ARGANO,07/18/2023
         SET tran_type = RPAD (' ', 2, ' ');

      COMMIT;

      IF UPPER (p_first_time_run) = 'Y'
      THEN
         --clear table when done
         truncate_table (v_owner_name, v_table_name);
      END IF;

      IF UPPER (p_first_time_run) <> 'Y'
      THEN
         FOR v_term_rec IN c_term_emp
         LOOP
            g_e_error_hand.module_name := 'termination logic';

            BEGIN
--               SELECT ppte.system_person_type
--                 INTO v_system_person_type
--                 FROM per_all_people_f papfe,
--                      per_all_assignments_f paafe,
--                      per_person_types ppte
--                WHERE paafe.person_id = papfe.person_id
--                  AND papfe.person_type_id = ppte.person_type_id
--                  AND ppte.system_person_type LIKE 'EX_EMP%'
--                  AND paafe.primary_flag = 'Y'
--                  AND RPAD (SUBSTR (papfe.employee_number, 1, 10), 10, ' ') LIKE
--                             RPAD (SUBSTR (v_term_rec.emp_id, 1, 10), 10, ' ')
--                  AND TO_DATE (p_date, 'YYYY/MM/DD HH24:MI:SS')
--                         BETWEEN papfe.effective_start_date
--                             AND papfe.effective_end_date
--                  AND TO_DATE (p_date, 'YYYY/MM/DD HH24:MI:SS')
--                         BETWEEN paafe.effective_start_date
--                             AND paafe.effective_end_date
--                  AND papfe.business_group_id = 325;
               SELECT MAX (ppos.actual_termination_date)
                 INTO v_actual_termination_date
                 FROM per_all_people_f papfe,
                      per_all_assignments_f paafe,
                      per_person_types ppte,
                      per_periods_of_service ppos
                WHERE paafe.person_id = papfe.person_id
                  AND papfe.person_id = ppos.person_id
                  AND papfe.person_type_id = ppte.person_type_id
                  AND paafe.primary_flag = 'Y'
                  AND RPAD (SUBSTR (papfe.employee_number, 1, 10), 10, ' ') LIKE
                             RPAD (SUBSTR (v_term_rec.emp_id, 1, 10), 10, ' ')
                  AND ppos.actual_termination_date
                         BETWEEN papfe.effective_start_date
                             AND papfe.effective_end_date
                  AND ppos.actual_termination_date
                         BETWEEN paafe.effective_start_date
                             AND paafe.effective_end_date
                  AND ppos.actual_termination_date
                         BETWEEN TO_DATE (p_date, 'YYYY/MM/DD HH24:MI:SS')
                             AND TO_DATE (p_date, 'YYYY/MM/DD HH24:MI:SS')
                  AND papfe.business_group_id = 325;

               fnd_file.put_line (fnd_file.LOG,
                                     v_term_rec.emp_id
                                  || '-'
                                  || v_system_person_type
                                 );

               --IF v_system_person_type LIKE 'EX_EMP'
               IF v_actual_termination_date IS NOT NULL
               THEN
			    --                UPDATE cust.ttec_ap_amex_interf_db --Commented code by MXKEERTHI-ARGANO,07/18/2023
                UPDATE apps.ttec_ap_amex_interf_db  --code added by MXKEERTHI-ARGANO, 07/18/2023

                     SET tran_type = '07'
                   WHERE emp_id = v_term_rec.emp_id;
               END IF;
            EXCEPTION
               WHEN NO_DATA_FOUND
               THEN
			    -- UPDATE cust.ttec_ap_amex_interf_db --Commented code by MXKEERTHI-ARGANO,07/18/2023
                UPDATE apps.ttec_ap_amex_interf_db --code added by MXKEERTHI-ARGANO, 07/18/2023

                     SET tran_type = v_term_rec.tran_type
                   WHERE emp_id = v_term_rec.emp_id;
               WHEN OTHERS
               THEN
                  log_error ('SQLCODE',
                             TO_CHAR (SQLCODE),
                             'Error Message',
                             SUBSTR (SQLERRM, 1, 64)
                            );
                  print_line ('Error in module: '
                              || g_e_error_hand.module_name
                             );
                  print_line (   'Failed  with Error '
                              || TO_CHAR (SQLCODE)
                              || '|'
                              || SUBSTR (SQLERRM, 1, 64)
                             );
                  g_e_program_run_status := 1;
            END;
         END LOOP;

         build_sql_select_statement (v_owner_name,
                                     v_table_name,
                                     v_alias_name,
                                     v_where_clause1,
                                     v_order_by,
                                     v_rec_out
                                    );
         write_sql_results_file (v_output_file, v_rec_out);
 --  UPDATE cust.ttec_ap_amex_interf_db  --Commented code by MXKEERTHI-ARGANO,07/18/2023
        UPDATE apps.ttec_ap_amex_interf_db  --code added by MXKEERTHI-ARGANO, 07/18/2023

            SET tran_type = RPAD (' ', 2, ' ');
      END IF;

      -- loop on all records
      FOR v_rec2 IN c_rec2_q (p_date)
      LOOP
         v_value := NULL;
         v_tran_type := NULL;

         BEGIN
            SELECT 'Y', cm_acc_num, tran_type
              INTO v_value, v_cm_acc_num, v_tran_type
			   --    FROM cust.ttec_ap_amex_interf_db --Commented code by MXKEERTHI-ARGANO,07/18/2023
             FROM apps.ttec_ap_amex_interf_db --code added by MXKEERTHI-ARGANO, 07/18/2023

             WHERE emp_id =
                        RPAD (SUBSTR (v_rec2.employee_number, 1, 10), 10, ' ');

            IF     v_value = 'Y'
               AND v_cm_acc_num <>
                      (   SUBSTR (v_rec2.card_number, 1, 4)
                       || '-'
                       || SUBSTR (v_rec2.card_number, 5, 6)
                       || '-'
                       || SUBSTR (v_rec2.card_number, 11)
                      )
               AND v_tran_type = RPAD (' ', 2, ' ')
            THEN
			 --   UPDATE cust.ttec_ap_amex_interf_db --Commented code by MXKEERTHI-ARGANO,07/18/2023
              UPDATE apps.ttec_ap_amex_interf_db--code added by MXKEERTHI-ARGANO, 07/18/2023

                  SET cm_acc_num =
                         (   SUBSTR (v_rec2.card_number, 1, 4)
                          || '-'
                          || SUBSTR (v_rec2.card_number, 5, 6)
                          || '-'
                          || SUBSTR (v_rec2.card_number, 11)
                         ),
                      tran_type = 'CC'
                WHERE emp_id =
                         RPAD (SUBSTR (v_rec2.employee_number, 1, 10), 10,
                               ' ');

               build_sql_select_statement (v_owner_name,
                                           v_table_name,
                                           v_alias_name,
                                           v_where_clause1,
                                           v_order_by,
                                           v_rec_out
                                          );
               write_sql_results_file (v_output_file, v_rec_out);
           -- UPDATE cust.ttec_ap_amex_interf_db --Commented code by MXKEERTHI-ARGANO,07/18/2023
             UPDATE apps.ttec_ap_amex_interf_db --code added by MXKEERTHI-ARGANO, 07/18/2023

                  SET tran_type = RPAD (' ', 2, ' ');
            END IF;
         EXCEPTION
            WHEN OTHERS
            THEN
               v_stage := 'build_data_rec';
               build_data_rec (v_rec2, v_rec_db);
               v_stage := 'insert_data_rec_in_db';
               insert_data_rec_in_db (v_rec_db);
         --      v_stage := 'write data to record';
         -- write_data_to_record (v_rec_db, v_rec);

         -- apps.fnd_file.put_line (apps.fnd_file.output, v_rec);
          --UTL_FILE.put_line (v_output_file, v_rec);
         END;

         BEGIN
            v_value := NULL;
            v_tran_type := NULL;

            SELECT 'Y', emp_cost_ctr, tran_type
              INTO v_value, v_cost_cnt_chg, v_tran_type
			   --   FROM cust.ttec_ap_amex_interf_db--Commented code by MXKEERTHI-ARGANO,07/18/2023
             FROM apps.ttec_ap_amex_interf_db  --code added by MXKEERTHI-ARGANO, 07/18/2023

             WHERE emp_id =
                        RPAD (SUBSTR (v_rec2.employee_number, 1, 10), 10, ' ');

            IF     v_value = 'Y'
               AND v_cost_cnt_chg <>
                          RPAD (SUBSTR (v_rec2.location_dept, 1, 10), 10, ' ')
               AND v_tran_type = RPAD (' ', 2, ' ')
            THEN
               --UPDATE cust.ttec_ap_amex_interf_db --Commented code by MXKEERTHI-ARGANO,07/18/2023
               UPDATE apps.ttec_ap_amex_interf_db --Added code by MXKEERTHI-ARGANO,07/18/2023
                  SET emp_cost_ctr =
                          RPAD (SUBSTR (v_rec2.location_dept, 1, 10), 10, ' '),
                      tran_type = '05'
                WHERE emp_id =
                         RPAD (SUBSTR (v_rec2.employee_number, 1, 10), 10,
                               ' ');

               build_sql_select_statement (v_owner_name,
                                           v_table_name,
                                           v_alias_name,
                                           v_where_clause1,
                                           v_order_by,
                                           v_rec_out
                                          );
               write_sql_results_file (v_output_file, v_rec_out);
                --  UPDATE cust.ttec_ap_amex_interf_db --Commented code by MXKEERTHI-ARGANO,07/18/2023
              UPDATE apps.ttec_ap_amex_interf_db --code added by MXKEERTHI-ARGANO, 07/18/2023

                  SET tran_type = RPAD (' ', 2, ' ');
            END IF;
         END;

         BEGIN
            v_value := NULL;
            v_tran_type := NULL;

            SELECT 'Y', m_add_street, m_add_city_state, m_zipcode,
                   tran_type
              INTO v_value, v_add_street, v_add_city_state, v_zipcode,
                   v_tran_type
				    --FROM cust.ttec_ap_amex_interf_db--Commented code by MXKEERTHI-ARGANO,07/18/2023
             FROM apps.ttec_ap_amex_interf_db --code added by MXKEERTHI-ARGANO, 07/18/2023

             WHERE emp_id =
                        RPAD (SUBSTR (v_rec2.employee_number, 1, 10), 10, ' ');

            IF     v_value = 'Y'
               AND (   v_add_street <>
                                RPAD (SUBSTR (v_rec2.address, 1, 20), 20, ' ')
                    OR v_add_city_state <>
                          RPAD (SUBSTR ((   v_rec2.town_or_city
                                         || ' '
                                         || v_rec2.region_2
                                        ),
                                        1,
                                        20
                                       ),
                                20,
                                ' '
                               )
                    OR v_zipcode <> RPAD (v_rec2.postal_code, 5, ' ')
                   )
               AND v_tran_type = RPAD (' ', 2, ' ')
            THEN
			 -- UPDATE cust.ttec_ap_amex_interf_db  --Commented code by MXKEERTHI-ARGANO,07/18/2023
            UPDATE apps.ttec_ap_amex_interf_db --code added by MXKEERTHI-ARGANO, 07/18/2023

                  SET m_add_street =
                                RPAD (SUBSTR (v_rec2.address, 1, 20), 20, ' '),
                      m_add_city_state =
                         RPAD (SUBSTR ((   v_rec2.town_or_city
                                        || ' '
                                        || v_rec2.region_2
                                       ),
                                       1,
                                       20
                                      ),
                               20,
                               ' '
                              ),
                      m_zipcode = RPAD (v_rec2.postal_code, 5, ' '),
                      tran_type = '03'
                WHERE emp_id =
                         RPAD (SUBSTR (v_rec2.employee_number, 1, 10), 10,
                               ' ');

               build_sql_select_statement (v_owner_name,
                                           v_table_name,
                                           v_alias_name,
                                           v_where_clause1,
                                           v_order_by,
                                           v_rec_out
                                          );
               write_sql_results_file (v_output_file, v_rec_out);
                 --  UPDATE cust.ttec_ap_amex_interf_db --Commented code by MXKEERTHI-ARGANO,07/18/2023
              UPDATE apps.ttec_ap_amex_interf_db --code added by MXKEERTHI-ARGANO, 07/18/2023

                  SET tran_type = RPAD (' ', 2, ' ');
            END IF;
         END;

         BEGIN
            v_value := NULL;
            v_tran_type := NULL;

            SELECT 'Y', emp_uni_num, tran_type
              INTO v_value, v_emp_uni_num, v_tran_type
			   -- FROM cust.ttec_ap_amex_interf_db --Commented code by MXKEERTHI-ARGANO,07/18/2023
             FROM apps.ttec_ap_amex_interf_db  --code added by MXKEERTHI-ARGANO, 07/18/2023

             WHERE emp_id =
                        RPAD (SUBSTR (v_rec2.employee_number, 1, 10), 10, ' ');

            IF     v_value = 'Y'
               AND v_emp_uni_num <>
                          RPAD (SUBSTR (v_rec2.email_address, 1, 25), 25, ' ')
               AND v_tran_type = RPAD (' ', 2, ' ')
            THEN
			 -- UPDATE cust.ttec_ap_amex_interf_db --Commented code by MXKEERTHI-ARGANO,07/18/2023
               UPDATE apps.ttec_ap_amex_interf_db --code added by MXKEERTHI-ARGANO, 07/18/2023

                  SET emp_uni_num =
                          RPAD (SUBSTR (v_rec2.email_address, 1, 25), 25, ' '),
                      tran_type = '13'
                WHERE emp_id =
                         RPAD (SUBSTR (v_rec2.employee_number, 1, 10), 10,
                               ' ');

               build_sql_select_statement (v_owner_name,
                                           v_table_name,
                                           v_alias_name,
                                           v_where_clause1,
                                           v_order_by,
                                           v_rec_out
                                          );
               write_sql_results_file (v_output_file, v_rec_out);
 --     UPDATE cust.ttec_ap_amex_interf_db --Commented code by MXKEERTHI-ARGANO,07/18/2023
              UPDATE apps.ttec_ap_amex_interf_db --code added by MXKEERTHI-ARGANO, 07/18/2023

                  SET tran_type = RPAD (' ', 2, ' ');
            END IF;
         END;
      END LOOP;

      BEGIN
         g_e_error_hand.module_name := 'Write Data to file';

         IF UPPER (p_first_time_run) = 'Y'
         THEN
            build_sql_select_statement (v_owner_name,
                                        v_table_name,
                                        v_alias_name,
                                        v_where_clause,
                                        v_order_by,
                                        v_rec_out
                                       );
/*         ELSE
            build_sql_select_statement (v_owner_name,
                                        v_table_name,
                                        v_alias_name,
                                        v_where_clause1,
                                        v_order_by,
                                        v_rec_out
                                       );*/
         END IF;

         write_sql_results_file (v_output_file, v_rec_out);
      EXCEPTION
         WHEN NO_DATA_FOUND
         THEN
            g_e_program_run_status := 0;
         WHEN OTHERS
         THEN
            log_error ('SQLCODE',
                       TO_CHAR (SQLCODE),
                       'Error Message',
                       SUBSTR (SQLERRM, 1, 64)
                      );
            print_line ('Error in module: ' || g_e_error_hand.module_name);
            print_line (   'Failed  with Error '
                        || TO_CHAR (SQLCODE)
                        || '|'
                        || SUBSTR (SQLERRM, 1, 64)
                       );
            g_e_program_run_status := 1;
      END;

      --write_table_to_file (v_output_file, v_rec_out);
-----------------------------------------------------------------------------------------------------------------------------  Trailer Record---- v_stage := 'Trailer Record';
      v_rec := NULL;
      build_trailer_rec (v_tot_rec_count, p_first_time_run, v_rec);
      UTL_FILE.put_line (v_output_file, v_rec);
      fnd_file.put_line (fnd_file.output, v_rec);
      UTL_FILE.fclose (v_output_file);
      -- Email the results
--      v_email_subj := 'Hello';
--      v_email_body := 'hello';
      send_email_result (v_status,
                         v_host_name,
                         p_email_to_list,
                         v_dir_name,
                         v_file_name
                        );
   EXCEPTION
      WHEN UTL_FILE.invalid_operation
      THEN
         UTL_FILE.fclose (v_output_file);
         log_error ('SQLCODE',
                    TO_CHAR (SQLCODE),
                    'Error Message',
                    SUBSTR (SQLERRM, 1, 64)
                   );
         raise_application_error (-20051,
                                  v_full_file_path || ':  Invalid Operation'
                                 );
         print_line ('Error in module: ' || g_e_error_hand.module_name);
         g_e_program_run_status := 1;
      WHEN UTL_FILE.invalid_filehandle
      THEN
         UTL_FILE.fclose (v_output_file);
         log_error ('SQLCODE',
                    TO_CHAR (SQLCODE),
                    'Error Message',
                    SUBSTR (SQLERRM, 1, 64)
                   );
         raise_application_error (-20052,
                                  v_full_file_path || ':  Invalid File Handle'
                                 );
         print_line ('Error in module: ' || g_e_error_hand.module_name);
         g_e_program_run_status := 1;
      WHEN UTL_FILE.read_error
      THEN
         UTL_FILE.fclose (v_output_file);
         log_error ('SQLCODE',
                    TO_CHAR (SQLCODE),
                    'Error Message',
                    SUBSTR (SQLERRM, 1, 64)
                   );
         raise_application_error (-20053, v_full_file_path || ':  Read Error');
         print_line ('Error in module: ' || g_e_error_hand.module_name);
         g_e_program_run_status := 1;
      WHEN UTL_FILE.invalid_path
      THEN
         UTL_FILE.fclose (v_output_file);
         log_error ('SQLCODE',
                    TO_CHAR (SQLCODE),
                    'Error Message',
                    SUBSTR (SQLERRM, 1, 64)
                   );
         raise_application_error (-20054, v_dir_name || ':  Invalid Path');
         print_line ('Error in module: ' || g_e_error_hand.module_name);
         g_e_program_run_status := 1;
      WHEN UTL_FILE.invalid_mode
      THEN
         UTL_FILE.fclose (v_output_file);
         log_error ('SQLCODE',
                    TO_CHAR (SQLCODE),
                    'Error Message',
                    SUBSTR (SQLERRM, 1, 64)
                   );
         raise_application_error (-20055,
                                  v_full_file_path || ':  Invalid Mode'
                                 );
         print_line ('Error in module: ' || g_e_error_hand.module_name);
         g_e_program_run_status := 1;
      WHEN UTL_FILE.write_error
      THEN
         UTL_FILE.fclose (v_output_file);
         log_error ('SQLCODE',
                    TO_CHAR (SQLCODE),
                    'Error Message',
                    SUBSTR (SQLERRM, 1, 64)
                   );
         raise_application_error (-20056,
                                  v_full_file_path || ':  Write Error');
         print_line ('Error in module: ' || g_e_error_hand.module_name);
         g_e_program_run_status := 1;
      WHEN UTL_FILE.internal_error
      THEN
         UTL_FILE.fclose (v_output_file);
         log_error ('SQLCODE',
                    TO_CHAR (SQLCODE),
                    'Error Message',
                    SUBSTR (SQLERRM, 1, 64)
                   );
         raise_application_error (-20057,
                                  v_full_file_path || ':  Internal Error'
                                 );
         print_line ('Error in module: ' || g_e_error_hand.module_name);
         g_e_program_run_status := 1;
      WHEN UTL_FILE.invalid_maxlinesize
      THEN
         UTL_FILE.fclose (v_output_file);
         log_error ('SQLCODE',
                    TO_CHAR (SQLCODE),
                    'Error Message',
                    SUBSTR (SQLERRM, 1, 64)
                   );
         raise_application_error (-20058,
                                  v_full_file_path || ':  Maxlinesize Error'
                                 );
         print_line ('Error in module: ' || g_e_error_hand.module_name);
         g_e_program_run_status := 1;
      WHEN OTHERS
      THEN
         UTL_FILE.fclose (v_output_file);
         log_error ('SQLCODE',
                    TO_CHAR (SQLCODE),
                    'Error Message',
                    SUBSTR (SQLERRM, 1, 64)
                   );
         print_line ('Error in module: ' || g_e_error_hand.module_name);
         DBMS_OUTPUT.put_line ('Operation fails on ' || v_stage);
         v_msg := SQLERRM;
         raise_application_error
                    (-20003,
                        'Exception OTHERS in TeleTech AP Amex SVI Interface  '
                     || v_msg
                    );
         g_e_program_run_status := 1;
   END main;
END ttec_ap_amex_svi_interface;
/
show errors;
/