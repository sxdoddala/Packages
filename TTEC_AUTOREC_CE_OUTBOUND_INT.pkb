 /************************************************************************************
        Program Name:  ttec_autorec_ce_outbound_int


       Modification Log
       Name                  Version #    Date            Description
       -----                 --------     -----           -------------
    IXPRAVEEN(ARGANO)            1.0     18-july-2023     R12.2 Upgrade Remediation
    ****************************************************************************************/
create or replace PACKAGE BODY      ttec_autorec_ce_outbound_int
AS
   PROCEDURE get_bank_end_balance_details (
      errbuff         OUT      VARCHAR2,
      retcode         OUT      VARCHAR2,
      p_period_name   IN       VARCHAR2,
      p_ledger        IN       NUMBER
   )
   IS
      --v_module   cust.ttec_error_handling.module_name%TYPE   := 'Main';		-- Commented code by IXPRAVEEN-ARGANO,18-july-2023
      v_module   apps.ttec_error_handling.module_name%TYPE   := 'Main';         --  code Added by IXPRAVEEN-ARGANO,   18-july-2023
      v_loc      NUMBER;
      v_msg      VARCHAR2 (2000);
      v_rec      VARCHAR2 (5000);
   -- CE_BALANCE_FEED_MON-YY_LEDGER_SHORT_NAME.DAT
   BEGIN
      v_ledger := NULL;
      v_rec := NULL;
      v_rec_output := NULL;
      v_rec_output_detail := NULL;
      v_rec_output :=
            'Record Type'
         || '|'
         || 'Import Account ID'
         || '|'
         || 'Period End Date'
         || '|'
         || 'Balance'
         || '|'
         || 'Balance Sign'
         || '|'
         || 'Bank Acct Name-Number.Currency';
      fnd_file.put_line (fnd_file.output, v_rec_output);

      --DBMS_OUTPUT.put_line (v_rec_output);
      OPEN c_directory_path (p_period_name, p_ledger);

      FETCH c_directory_path
       INTO v_file_path, v_file_name;

      CLOSE c_directory_path;

      v_file_type := UTL_FILE.fopen (v_file_path, v_file_name, 'w');
      fnd_file.put_line (fnd_file.LOG, '');
      fnd_file.put_line
         (fnd_file.LOG,
          '>>>>>>>>>>>>>>>> Processing CM Balance Extract For <<<<<<<<<<<<<<<<<<<'
         );
      fnd_file.put_line (fnd_file.LOG, '');
      fnd_file.put_line (fnd_file.LOG, '           Ledger ID: ' || p_ledger);
      fnd_file.put_line (fnd_file.LOG,
                         '         Period Name: ' || p_period_name
                        );
      fnd_file.put_line (fnd_file.LOG,
                         '           File Path: ' || v_file_path);
      fnd_file.put_line (fnd_file.LOG,
                         '           File Name: ' || v_file_name);
      fnd_file.put_line (fnd_file.LOG,
                            '         Starts Time: '
                         || TO_CHAR (SYSDATE, 'DD-MON-YYYY HH24:MI:SS')
                        );
      fnd_file.put_line (fnd_file.LOG, '');

      BEGIN
         FOR r_data IN c_data (p_period_name, p_ledger)
         LOOP
            v_rec := NULL;
            v_rec_output := NULL;
            v_rec :=
                  'B'
               || '|'
               || SUBSTR ((   r_data.ledger_id
                           || '.'
                           || r_data.loc
                           || '-'
                           || r_data.cash_account
                           || '.'
                           || r_data.currency_code
                           || '_CM'
                          ),
                          1,
                          255
                         )
               || '|'
               || TO_CHAR (r_data.period_end_date, 'YYYYMMDD')
               || '|'
               || SUBSTR ((r_data.balance), 1, 23)
               || '|'
               || CASE
                     WHEN r_data.balance < 0
                        THEN 'C'
                     ELSE 'D'
                  END
               || '|'
               || r_data.bank_account_name
               || '_'
               || r_data.bank_account_num
               || '.'
               || r_data.currency_code;
--                  v_file_type := UTL_FILE.fopen(v_file_path, v_file_name, 'w');
--
            UTL_FILE.put_line (v_file_type, v_rec);
            fnd_file.put_line (fnd_file.output, v_rec);
--
--
/* Commented out by CC on Nov 14, 2014
               v_rec_output_detail :=
                          substr((r_data.ledger_id||'.'||r_data.loc||'-'||r_data.cash_account||'.'||r_data.currency_code),1,255)
                     || '|'
                     || to_char(r_data.period_end_date,'DD-MON-YYYY')
                     || '|'
                     || substr((r_data.balance),1,23)
                     || '|'
                     ||r_data.bank_account_num||'.'||r_data.currency_code;
                     fnd_file.put_line(FND_FILE.OUTPUT,v_rec_output_detail);
               --DBMS_OUTPUT.put_line (v_rec_output);
*/
         END LOOP;
      END;

      UTL_FILE.fclose (v_file_type);
   END get_bank_end_balance_details;

   PROCEDURE get_ar_open_items (
      errbuff         OUT      VARCHAR2,
      retcode         OUT      VARCHAR2,
      p_period_name   IN       VARCHAR2,
      p_ledger        IN       NUMBER
   )
   IS
      v_rec      VARCHAR2 (2000);
      --v_module   cust.ttec_error_handling.module_name%TYPE   := 'Main';		-- Commented code by IXPRAVEEN-ARGANO,18-july-2023
      v_module   apps.ttec_error_handling.module_name%TYPE   := 'Main';         --  code Added by IXPRAVEEN-ARGANO,   18-july-2023
      v_loc      NUMBER;
      v_msg      VARCHAR2 (2000);
   BEGIN
      v_rec := NULL;
      v_rec_output := NULL;
      v_rec_output_detail := NULL;
      v_rec_output :=
            'Ledger_Location_Account_Currency'
         || '|'
         || 'Functional_Currency'
         || '|'
         || 'Receipt_Number'
         || '|'
         || 'Customer_Name'
         || '|'
         || 'Operation_Unit'
         || '|'
         || 'Value_Date'
         || '|'
         || 'Amount'
         || '|'
         || 'Bank_Acct_Num';
      --DBMS_OUTPUT.put_line (v_rec_output);
      fnd_file.put_line (fnd_file.output, v_rec_output);

      OPEN c_directory_path2 (p_period_name, p_ledger);

      FETCH c_directory_path2
       INTO v_file_path_detail, v_file_name_detail;

      CLOSE c_directory_path2;

      v_file_detail_type :=
                  UTL_FILE.fopen (v_file_path_detail, v_file_name_detail, 'w');

      FOR r_ar_data IN c_ar_data (p_ledger)
      LOOP
         v_rec := NULL;
         v_rec_output := NULL;
         v_rec :=
               'D'
            || '|'
            || r_ar_data.ledger_id
            || '.'
            || r_ar_data.loc
            || '-'
            || r_ar_data.cash_account
            || '.'
            || r_ar_data.functional_currency
            || '_CM'
            || '|'
            || 'DE'
            || '|'
            || 'D'
            || '|'
            || SUBSTR (r_ar_data.functional_currency, 1, 5)
            || '|'
            || SUBSTR (r_ar_data.receipt_number, 1, 255)
            || '|'
            || SUBSTR (r_ar_data.party_name, 1, 255)
            || '|'
            || SUBSTR (r_ar_data.organization_name, 1, 255)
            || '|'
            || SUBSTR (r_ar_data.receipt_name, 1, 255)
            || '|'
            || TO_CHAR (r_ar_data.receipt_date, 'YYYYMMDD')
            || '|'
            || r_ar_data.amount
            || '|'
            || r_ar_data.bank_account_num
            || '.'
            || r_ar_data.currency_code
            || '|'
            || TO_CHAR (v_period_end_date, 'YYYYMMDD');              /* 1.1 */
         UTL_FILE.put_line (v_file_detail_type, v_rec);
         v_rec_output_detail :=
               r_ar_data.ledger_id
            || '.'
            || r_ar_data.loc
            || '-'
            || r_ar_data.cash_account
            || '.'
            || r_ar_data.currency_code
            || '|'
            || SUBSTR (r_ar_data.functional_currency, 1, 5)
            || '|'
            || SUBSTR (r_ar_data.receipt_number, 1, 255)
            || '|'
            || SUBSTR (r_ar_data.party_name, 1, 255)
            || '|'
            || SUBSTR (r_ar_data.organization_name, 1, 255)
            || '|'
            || TO_CHAR (r_ar_data.receipt_date, 'DD-MON-YYYY')
            || '|'
            || r_ar_data.amount
            || '|'
            || r_ar_data.bank_account_num
            || '|'
            || TO_CHAR (v_period_end_date, 'YYYYMMDD');              /* 1.1 */

         fnd_file.put_line (fnd_file.output, v_rec_output_detail);

      END LOOP;

   --UTL_FILE.FCLOSE(v_file_detail_type); /* CC need to put back the comment */

   EXCEPTION
      WHEN UTL_FILE.invalid_operation
      THEN
         UTL_FILE.fclose (v_file_detail_type);
         raise_application_error (-20051,
                                  v_file_name_detail || ':  Invalid Operation'
                                 );
      WHEN UTL_FILE.invalid_filehandle
      THEN
         UTL_FILE.fclose (v_file_detail_type);
         raise_application_error (-20052,
                                     v_file_name_detail
                                  || ':  Invalid File Handle'
                                 );
      WHEN UTL_FILE.read_error
      THEN
         UTL_FILE.fclose (v_file_detail_type);
         raise_application_error (-20053,
                                  v_file_name_detail || ':  Read Error'
                                 );
         ROLLBACK;
      WHEN UTL_FILE.invalid_path
      THEN
         UTL_FILE.fclose (v_file_detail_type);
         raise_application_error (-20054, v_file_path || ':  Invalid Path');
      WHEN UTL_FILE.invalid_mode
      THEN
         UTL_FILE.fclose (v_file_detail_type);
         raise_application_error (-20055,
                                  v_file_name_detail || ':  Invalid Mode'
                                 );
      WHEN UTL_FILE.write_error
      THEN
         UTL_FILE.fclose (v_file_detail_type);
         raise_application_error (-20056,
                                  v_file_name_detail || ':  Write Error'
                                 );
      WHEN UTL_FILE.internal_error
      THEN
         UTL_FILE.fclose (v_file_detail_type);
         raise_application_error (-20057,
                                  v_file_name_detail || ':  Internal Error'
                                 );
      WHEN UTL_FILE.invalid_maxlinesize
      THEN
         UTL_FILE.fclose (v_file_detail_type);
         raise_application_error (-20058,
                                  v_file_name_detail || ':  Maxlinesize Error'
                                 );
      WHEN INVALID_CURSOR
      THEN
         UTL_FILE.fclose (v_file_detail_type);
         ttec_error_logging.process_error
                                 (g_application_code                   -- 'CE'
                                                    ,
                                  g_interface            -- 'AutoRec CE Intf';
                                             ,
                                  g_package  -- 'TTEC_AUTOREC_CE_OUTBOUND_INT'
                                           ,
                                  v_module,
                                  g_failure_status,
                                  SQLCODE,
                                  SQLERRM,
                                  g_label1,
                                  v_loc,
                                  g_label2,
                                  g_autorec_acct
                                 );
         retcode := SQLCODE;
         errbuff := SUBSTR (SQLERRM, 1, 255);
      WHEN OTHERS
      THEN
         UTL_FILE.fclose (v_file_detail_type);
         ttec_error_logging.process_error
                                 (g_application_code                   -- 'CE'
                                                    ,
                                  g_interface            -- 'AutoRec CE Intf';
                                             ,
                                  g_package  -- 'TTEC_AUTOREC_CE_OUTBOUND_INT'
                                           ,
                                  v_module,
                                  g_failure_status,
                                  SQLCODE,
                                  SQLERRM,
                                  g_label1,
                                  v_loc,
                                  g_label2,
                                  g_autorec_acct
                                 );
         retcode := SQLCODE;
         errbuff := SUBSTR (SQLERRM, 1, 255);
         raise_application_error
            (-20003,
                'Exception OTHERS in TTEC_AUTOREC_CE_OUTBOUND_INT.process_balance: '
             || 'Module >-'
             || v_module
             || ' ['
             || g_label1
             || ']['
             || v_loc
             || ']['
             || g_label2
             || ']['
             || g_autorec_acct
             || '] ERROR:'
             || errbuff
            );
   END get_ar_open_items;

   PROCEDURE get_ap_open_items (
      errbuff         OUT      VARCHAR2,
      retcode         OUT      VARCHAR2,
      p_period_name   IN       VARCHAR2,
      p_ledger        IN       NUMBER
   )
   IS
      v_rec        VARCHAR2 (2000) DEFAULT NULL;
      v_filename   VARCHAR2 (2000) DEFAULT NULL;
   BEGIN
      v_rec := NULL;
      v_rec_output := NULL;
      v_rec_output_detail := NULL;
      v_rec_output :=
            'Ledger_Location_Account_Currency'
         || '|'
         || 'Functional_Currency'
         || '|'
         || 'Check_Number'
         || '|'
         || 'Customer_Name'
         || '|'
         || 'Operation_Unit'
         || '|'
         || 'Value_Date'
         || '|'
         || 'Amount'
         || '|'
         || 'Bank_Acct_Num'
         || '|'
         || 'Period_End_Date';
      fnd_file.put_line (fnd_file.output, v_rec_output);

      /* CC v_file_detail_type := UTL_FILE.fopen(v_file_path_detail, v_file_name_detail, 'w'); */

--      OPEN c_directory_path2 (p_period_name, p_ledger);

--      FETCH c_directory_path2
--       INTO v_file_path_detail, v_file_name_detail;

--      CLOSE c_directory_path2;

--      v_file_detail_type :=
--                  UTL_FILE.fopen (v_file_path_detail, v_file_name_detail, 'w');

      FOR r_ap_data IN c_ap_data (p_ledger)
      LOOP
         v_rec := NULL;
         v_rec_output := NULL;
         v_rec_output_detail := NULL;
         v_rec :=
               'C'
            || '|'
            || r_ap_data.ledger_id
            || '.'
            || r_ap_data.loc
            || '-'
            || r_ap_data.cash_account
            || '.'
            || r_ap_data.functional_currency
            || '_CM'
            || '|'
            || 'RC'
            || '|'
            || 'C'
            || '|'
            || SUBSTR (r_ap_data.functional_currency, 1, 5)
            || '|'
            || SUBSTR (r_ap_data.check_number, 1, 255)
            || '|'
            || SUBSTR (r_ap_data.vendor_name, 1, 255)
            || '|'
            || SUBSTR (r_ap_data.organization_name, 1, 255)
            || '|'
            || 'N/A'
            || '|'
            || TO_CHAR (r_ap_data.check_date, 'YYYYMMDD')
            || '|'
            || r_ap_data.check_amount
            || '|'
            || r_ap_data.bank_account_num
            || '.'
            || r_ap_data.currency_code
            || '|'
            || TO_CHAR (v_period_end_date, 'YYYYMMDD');              /* 1.1 */
--
--
         UTL_FILE.put_line (v_file_detail_type, v_rec);
--
--
         v_rec_output_detail :=
               r_ap_data.ledger_id
            || '.'
            || r_ap_data.loc
            || '-'
            || r_ap_data.cash_account
            || '.'
            || r_ap_data.currency_code
            || '|'
            || SUBSTR (r_ap_data.functional_currency, 1, 5)
            || '|'
            || SUBSTR (r_ap_data.check_number, 1, 255)
            || '|'
            || SUBSTR (r_ap_data.vendor_name, 1, 255)
            || '|'
            || SUBSTR (r_ap_data.organization_name, 1, 255)
            || '|'
            || TO_CHAR (r_ap_data.check_date, 'DD-MON-YYYY')
            || '|'
            || r_ap_data.check_amount
            || '|'
            || r_ap_data.bank_account_num
            || '|'
            || TO_CHAR (v_period_end_date, 'YYYYMMDD');              /* 1.1 */

         fnd_file.put_line (fnd_file.output, v_rec_output_detail);

      END LOOP;

      UTL_FILE.fclose (v_file_detail_type);

   END get_ap_open_items;

   PROCEDURE main_data (
      errbuff         OUT      VARCHAR2,
      retcode         OUT      VARCHAR2,
      p_period_name   IN       VARCHAR2,
      p_ledger_id     IN       NUMBER,
      p_process_date  IN       VARCHAR2
   )
   IS
   BEGIN


      BEGIN
         SELECT TRUNC(end_date)
           INTO v_period_end_date
           FROM apps.gl_periods
          WHERE period_name = p_period_name;
      EXCEPTION
         WHEN NO_DATA_FOUND
         THEN
            v_period_end_date := TRUNC (SYSDATE);
      END;

    IF p_process_date IS NOT NULL THEN
       v_statement_date := to_date(p_process_date);
    ELSE
       v_statement_date := v_period_end_date;
    END IF;


      fnd_file.put_line (fnd_file.LOG, '');
      fnd_file.put_line
         (fnd_file.LOG,
          '--------------------------------------------------------------------------------------------------------------------------------------------------'
         );
      fnd_file.put_line (fnd_file.LOG, '');
      fnd_file.put_line
               (fnd_file.LOG,
                'Concurrent Program -> TeleTech AutoRec CE Balance Data Feed '
               );
      fnd_file.put_line (fnd_file.LOG, '');
      fnd_file.put_line (fnd_file.LOG, 'Parameters:                  ');
      fnd_file.put_line (fnd_file.LOG,
                         '            p_ledger_id: ' || p_ledger_id
                        );
      fnd_file.put_line (fnd_file.LOG,
                         '          p_period_name: ' || p_period_name
                        );
      fnd_file.put_line (fnd_file.LOG,
                         '        Period_End_Date: ' || v_period_end_date
                        );
      fnd_file.put_line (fnd_file.LOG,
                         '         Statement_Date: ' || v_statement_date
                        );
      fnd_file.put_line (fnd_file.LOG, '');
      fnd_file.put_line
         (fnd_file.LOG,
          '--------------------------------------------------------------------------------------------------------------------------------------------------'
         );

      IF p_ledger_id IS NOT NULL
      THEN

         get_bank_end_balance_details (errbuff, retcode, p_period_name, p_ledger_id);

         get_ar_open_items (errbuff, retcode, p_period_name, p_ledger_id);

         get_ap_open_items (errbuff, retcode, p_period_name, p_ledger_id);

      ELSE
         FOR ledger_rec IN c_ledger
         LOOP

            get_bank_end_balance_details (errbuff, retcode, p_period_name, ledger_rec.ledger_id);

            get_ar_open_items (errbuff, retcode,p_period_name, ledger_rec.ledger_id);

            get_ap_open_items (errbuff, retcode, p_period_name, ledger_rec.ledger_id);

         END LOOP;
      END IF;

   END main_data;

END ttec_autorec_ce_outbound_int;
/
show errors;
/