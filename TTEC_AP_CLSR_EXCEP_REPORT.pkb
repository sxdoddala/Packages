create or replace PACKAGE BODY      ttec_ap_clsr_excep_report
AS
  /*****************************************************************************************************************
  * PURPOSE:              To show unposted transactions from Oracle Payables
  * AUTHOR:               Bhushan Gangurde
  * CREATION DATE:        14-FEB-2017
  * DATETIME:             DateTime:  14-FEB-2017
  * LAST UPDATED BY:      Bhushan Gangurde
  * DATETIME:             DateTime:  14-FEB-2017
  ------------------------------------------------------------------------------------------------------------------
  CHANGE HISTORY:
  VERSION   MODFICATION DATE   MODIFIED BY           BUG#        DESCRIPTION
  V1.0      15-FEB-2017        Bhushan Gangurde                  Initial Version
  V2.0      28-MAY-2020        Venkat                            Commented hardcoded server name as part of Syntax Retrofit
	                                                             and retrieving value using profile option.
	--1.0	11-May-2023       IXPRAVEEN(ARGANO)   		R12.2 Upgrade Remediation
  ******************************************************************************************************************/
  PROCEDURE ttec_ap_clr_excep_report (
    errbuf            OUT       VARCHAR2
   ,retcode           OUT       VARCHAR2
   ,p_month_period    IN        VARCHAR2
   ,p_trx_type        IN        VARCHAR2
   ,p_mail_id         IN        VARCHAR2
   ,p_aging_days      IN        NUMBER
   ,p_org_id          IN        NUMBER
  )
  AS
    v_file_handle          UTL_FILE.FILE_TYPE;
    v_count                NUMBER              := 0;
    l_request_id           NUMBER;
    l_outfile_path         VARCHAR2 (255)      := NULL;
    l_outfile_name         VARCHAR2 (255)      := NULL;
    crlf                   VARCHAR2 (2)        := CHR (13) || CHR (10);
    v_instance             VARCHAR2 (9);
    p_output_file_email    VARCHAR2 (255);
    l_mail_msg             VARCHAR2 (1000);
    l_mail_conn            UTL_SMTP.connection;

	--l_mailhost             VARCHAR2 (64)       := 'mailgateway.teletech.com'; -- Commented for V2.0
	l_mailhost             VARCHAR2 (64)       := ttec_library.XX_TTEC_SMTP_SERVER; -- Added for V2.0

    l_error_code           VARCHAR2 (100);
    l_month_period         VARCHAR2 (100);

    CURSOR rep_inv_cur
    IS
      SELECT   ai.org_id
              ,ai.invoice_id
              ,hr.name ou
              ,ai.invoice_num
              ,ai.invoice_date
              ,pv.vendor_name
              ,ai.invoice_currency_code
              ,ai.invoice_amount
              ,ai.SOURCE
              ,ai.invoice_type_lookup_code
              ,TO_CHAR ((SELECT MAX (aid.accounting_date)
                           FROM ap_invoice_distributions_all aid
                          WHERE aid.posted_flag = 'N'
                            AND aid.accrual_posted_flag = 'N'
                            AND aid.invoice_id = ai.invoice_id
                            AND TO_CHAR (aid.accounting_date, 'MON-RR') = l_month_period
                            AND TRUNC (aid.creation_date) <= TRUNC (CASE
                                                                      WHEN p_aging_days IS NULL
                                                                       OR p_aging_days = 0
                                                                        THEN TRUNC (aid.creation_date)
                                                                      WHEN p_aging_days > 0
                                                                        THEN TRUNC (SYSDATE) - p_aging_days
                                                                    END)
                            AND aid.org_id = ai.org_id)
                       ,'DD-MON-RR') max_gl_date_in_dist
              , (SELECT user_name
                   FROM fnd_user
                  WHERE user_id = ai.created_by) created_by
              ,ap_invoices_utility_pkg.get_approval_status (ai.invoice_id, ai.invoice_amount, ai.payment_status_flag, ai.invoice_type_lookup_code) status
              ,DECODE (ap_invoices_utility_pkg.get_approval_status (ai.invoice_id, ai.invoice_amount, ai.payment_status_flag, ai.invoice_type_lookup_code)
                      ,'APPROVED', 'RUN CREATE ACCOUTING'
                      ,'CANCELLED', 'RUN CREATE ACCOUTING'
                      ,'NEEDS REAPPROVAL', 'VALIDATE THE INVOICE AND RUN CREATE ACCOUNTING'
                      ,'NEVER APPROVED', 'VALIDATE THE INVOICE AND RUN CREATE ACCOUNTING'
                      ,'UNPAID', 'RUN CREATE ACCOUTING'
                      ) action_required
          FROM ap_supplier_sites_all pvs
              ,ap_suppliers pv
              ,ap_invoices_all ai
              ,hr_operating_units hr
         WHERE 1 = 1
           AND ai.org_id = hr.organization_id
           AND hr.organization_id = NVL (p_org_id, hr.organization_id)
           AND pvs.vendor_site_id = ai.vendor_site_id
           AND pv.vendor_id = ai.vendor_id
           AND EXISTS (SELECT 1
                         FROM ap_invoice_distributions_all aid
                        WHERE aid.posted_flag = 'N'
                          AND aid.accrual_posted_flag = 'N'
                          AND aid.invoice_id = ai.invoice_id
                          AND TRUNC (aid.creation_date) <= TRUNC (CASE
                                                                    WHEN p_aging_days IS NULL
                                                                     OR p_aging_days = 0
                                                                      THEN TRUNC (aid.creation_date)
                                                                    WHEN p_aging_days > 0
                                                                      THEN TRUNC (SYSDATE) - p_aging_days
                                                                  END)
                          AND TO_CHAR (aid.accounting_date, 'MON-RR') = l_month_period
                          AND aid.org_id = ai.org_id)
      GROUP BY ai.org_id
              ,ai.invoice_num
              ,ai.invoice_date
              ,pv.vendor_name
              ,ai.doc_sequence_value
              ,ai.invoice_currency_code
              ,ai.invoice_id
              ,hr.name
              ,ai.invoice_amount
              ,ai.payment_status_flag
              ,ai.SOURCE
              ,ai.invoice_type_lookup_code
              ,ai.attribute1
              ,ai.created_by;

    CURSOR rep_pyt_cur
    IS
      SELECT   hr.name ou
              ,c.check_number
              ,c.check_date
              ,c.currency_code
              ,c.check_id
              ,c.amount
              ,c.base_amount
              ,MAX (b.accounting_date) max_gl_date
              , (SELECT user_name
                   FROM fnd_user
                  WHERE user_id = c.created_by) created_by
          FROM ap_checks_all c
              ,ap_payment_history_all b
              ,hr_operating_units hr
         WHERE 1 = 1
           AND c.check_id = b.check_id
           AND c.org_id = b.org_id
           AND b.org_id = hr.organization_id
           AND hr.organization_id = NVL (p_org_id, hr.organization_id)
           AND NVL (b.posted_flag, 'N') = 'N'
           AND TRUNC (b.creation_date) <= TRUNC (CASE
                                                   WHEN p_aging_days IS NULL
                                                    OR p_aging_days = 0
                                                     THEN TRUNC (b.creation_date)
                                                   WHEN p_aging_days > 0
                                                     THEN TRUNC (SYSDATE) - p_aging_days
                                                 END)
           AND TO_CHAR (b.accounting_date, 'MON-RR') = l_month_period
      GROUP BY hr.name
              ,c.check_number
              ,c.check_date
              ,c.currency_code
              ,c.check_id
              ,c.amount
              ,c.base_amount
              ,c.created_by;
  BEGIN
    l_request_id          := fnd_global.conc_request_id;
    p_output_file_email   := p_mail_id;

    SELECT period_name
      INTO l_month_period
      FROM gl_periods
     WHERE UPPER (period_name) LIKE UPPER (p_month_period)
       AND ROWNUM = 1;

    --   v_file_handle := UTL_FILE.fopen (l_outfile_path, l_outfile_name, 'w');
    BEGIN
      IF p_trx_type = 'INV'
      THEN
        FND_FILE.PUT_LINE (FND_FILE.LOG, 'Transaction type INV');
        FND_FILE.PUT_LINE (FND_FILE.OUTPUT
                          , 'Org ID' ||
                            '|' ||
                            'Invoice ID' ||
                            '|' ||
                            'Operating Unit' ||
                            '|' ||
                            'Invoice Number' ||
                            '|' ||
                            'Invoice Date' ||
                            '|' ||
                            'Vendor Name' ||
                            '|' ||
                            'Invoice Currency' ||
                            '|' ||
                            'Invoice Amount' ||
                            '|' ||
                            'Source' ||
                            '|' ||
                            'Max GL Date in Dist.' ||
                            '|' ||
                            'Created By' ||
                            '|' ||
                            'Status' ||
                            '|' ||
                            'Action Required' ||
                            '|' ||
                            'Error Code Description');

        FOR rec IN rep_inv_cur
        LOOP
          l_error_code   := ttec_ap_clsr_excep_report.ttec_error_code (rec.invoice_id, p_trx_type);
          v_count        := v_count + 1;
          FND_FILE.PUT_LINE (FND_FILE.OUTPUT
                            , rec.org_id ||
                              '|' ||
                              rec.invoice_id ||
                              '|' ||
                              rec.ou ||
                              '|' ||
                              rec.invoice_num ||
                              '|' ||
                              rec.invoice_date ||
                              '|' ||
                              rec.vendor_name ||
                              '|' ||
                              rec.invoice_currency_code ||
                              '|' ||
                              rec.invoice_amount ||
                              '|' ||
                              rec.SOURCE ||
                              '|' ||
                              rec.max_gl_date_in_dist ||
                              '|' ||
                              rec.created_by ||
                              '|' ||
                              rec.status ||
                              '|' ||
                              rec.action_required ||
                              '|' ||
                              l_error_code);
        END LOOP;

        FND_FILE.PUT_LINE (FND_FILE.LOG, 'Total no of unaccounted Invoices' || v_count);
      ELSIF p_trx_type = 'PAY'
      THEN
        FND_FILE.PUT_LINE (FND_FILE.LOG, 'Transaction type PAY');
        FND_FILE.PUT_LINE (FND_FILE.OUTPUT
                          , 'Operating Unit' ||
                            '|' ||
                            'Check Number' ||
                            '|' ||
                            'Check Date' ||
                            '|' ||
                            'Currency Code' ||
                            '|' ||
                            'Amount' ||
                            '|' ||
                            'Base Amount' ||
                            '|' ||
                            'Max GL Date' ||
                            '|' ||
                            'Created By' ||
                            '|' ||
                            'Error Code Description');

        FOR rec IN rep_pyt_cur
        LOOP
          l_error_code   := ttec_ap_clsr_excep_report.ttec_error_code (rec.check_id, p_trx_type);
          v_count        := v_count + 1;
          FND_FILE.PUT_LINE (FND_FILE.OUTPUT
                            , rec.ou ||
                              '|' ||
                              rec.check_number ||
                              '|' ||
                              rec.check_date ||
                              '|' ||
                              rec.currency_code ||
                              '|' ||
                              rec.amount ||
                              '|' ||
                              rec.base_amount ||
                              '|' ||
                              rec.max_gl_date ||
                              '|' ||
                              rec.created_by ||
                              '|' ||
                              l_error_code);
        END LOOP;

        FND_FILE.PUT_LINE (FND_FILE.LOG, 'Total no of unaccounted Payments' || v_count);
      END IF;
    EXCEPTION
      -- Utl_File.Get_Line will raise a No data found exception when last line is reached
      WHEN NO_DATA_FOUND
      THEN
        FND_FILE.PUT_LINE (FND_FILE.LOG, 'No data found for INV/PAY transaction');
             --UTL_SMTP.close_data (l_mail_conn);
             --UTL_SMTP.quit (l_mail_conn);
    --         UTL_FILE.fclose (v_file_handle);
    END;

    SELECT name
      INTO v_instance
      FROM v$database;

        --select * from fnd_lookup_types
        --where  lookup_type = 'EMAIL' ;
    --   fnd_file.put_line (fnd_file.LOG, 'Opening the CSV file');
    BEGIN
      SELECT fcp.plsql_dir
            ,fcp.plsql_out
        INTO l_outfile_path
            ,l_outfile_name
        FROM fnd_concurrent_requests fcr
            ,fnd_concurrent_processes fcp
       WHERE fcr.request_id = l_request_id
         AND fcp.concurrent_process_id = fcr.controlling_manager;
    EXCEPTION
      WHEN OTHERS
      THEN
        FND_FILE.PUT_LINE (FND_FILE.LOG, 'Error while fetching outfile path');
    END;

    DECLARE
      l_fexists        BOOLEAN;
      l_file_length    NUMBER;
      l_block_size     BINARY_INTEGER;
    BEGIN
      UTL_FILE.fgetattr (l_outfile_path
                        ,l_outfile_name
                        ,l_fexists
                        ,l_file_length
                        ,l_block_size
                        );

      IF l_fexists
      THEN
        FND_FILE.PUT_LINE (FND_FILE.LOG, 'l_file_length -> ' || l_file_length || '   ' || 'l_block_size -> ' || l_block_size);
      END IF;
    END;

    l_mail_msg            := 'Date: ' ||
                             TO_CHAR (SYSDATE, 'dd Mon yy hh24:mi:ss') ||
                             crlf ||
                             'From:' ||
                             'applmgr@teletech.com' ||
                             crlf ||
                             'Subject:' ||
                             v_instance ||
                             ':- AP MEC Exception Report REQUEST ID:' ||
                             l_request_id ||
                             crlf ||
                             'To: ' ||
                             p_output_file_email ||
                             crlf;
    l_mail_conn           := UTL_SMTP.open_connection (l_mailhost, 25);
    -- Open SMTP Connection
    UTL_SMTP.helo (l_mail_conn, l_mailhost);   -- HandShake
    UTL_SMTP.mail (l_mail_conn, 'applmgr@teletech.com');
    UTL_SMTP.rcpt (l_mail_conn, p_output_file_email);
    UTL_SMTP.open_data (l_mail_conn);
    -- This will send the data as attachment
    UTL_SMTP.write_data (l_mail_conn
                        , 'Content-Disposition' ||
                          ': ' ||
                          'attachment; filename="' ||
                          SUBSTR (l_outfile_name, 1, INSTR (l_outfile_name, '.') - 1) ||
                          '_out.txt' ||
                          '"' ||
                          l_mail_msg ||
                          crlf);
    v_file_handle         := UTL_FILE.FOPEN (l_outfile_path, l_outfile_name, 'r');

    BEGIN
      LOOP
        UTL_FILE.get_line (v_file_handle, l_mail_msg);
        UTL_SMTP.write_data (l_mail_conn, l_mail_msg || crlf);
      END LOOP;
    EXCEPTION
      -- Utl_File.Get_Line will raise a No data found exception when last line is reached
      WHEN NO_DATA_FOUND
      THEN
        UTL_SMTP.close_data (l_mail_conn);
        UTL_SMTP.quit (l_mail_conn);
        UTL_FILE.FCLOSE (v_file_handle);
    END;

    FND_FILE.PUT_LINE (FND_FILE.LOG, 'END OF FILE');
  EXCEPTION
    WHEN OTHERS
    THEN
      FND_FILE.PUT_LINE (FND_FILE.LOG, 'Period name is not valid');
  END ttec_ap_clr_excep_report;

  FUNCTION ttec_error_code (
    p_trx_id      IN    NUMBER
   ,p_trx_type    IN    VARCHAR2
  )
    RETURN VARCHAR2
  AS
    v_trx_id            NUMBER         := p_trx_id;
    v_trx_type          VARCHAR2 (3)   := p_trx_type;
    v_err_code          VARCHAR2 (100);
    v_cr_amount         NUMBER;
    v_dr_amount         NUMBER;
    v_err_code1         VARCHAR2 (100);
    v_err_code2         VARCHAR2 (100);
    v_err_code3         VARCHAR2 (100);
    v_acct_cr_amount    NUMBER;
    v_acct_dr_amount    NUMBER;
    v_start_date        DATE;
    v_end_date          DATE;
  BEGIN
    --error code A--'-1' in code combination_id
    IF v_trx_type = 'INV'
    THEN
      BEGIN
        SELECT 'CCID -1'
          INTO v_err_code
          FROM DUAL
         WHERE EXISTS (SELECT 1
                         FROM ap_invoices_all ai
                             ,ap_invoice_distributions_all aid
                             ,xla_events xe
                             ,xla_ae_headers xh
                             ,xla_ae_lines xl
                        WHERE ai.invoice_id = aid.invoice_id
                          AND aid.accounting_event_id = xe.event_id
                          AND xe.event_id = xh.event_id
                          AND xh.ae_header_id = xl.ae_header_id
                          AND xl.code_combination_id = '-1'
                          AND ai.invoice_id = v_trx_id);
      EXCEPTION
        WHEN NO_DATA_FOUND
        THEN
          v_err_code   := NULL;
      END;

      BEGIN
        SELECT SUM (NVL (entered_cr, 0))
              ,SUM (NVL (entered_dr, 0))
              ,SUM (NVL (accounted_cr, 0))
              ,SUM (NVL (accounted_dr, 0))
          INTO v_cr_amount
              ,v_dr_amount
              ,v_acct_cr_amount
              ,v_acct_dr_amount
          FROM ap_invoice_distributions_all aid
              ,xla_events xe
              ,xla_ae_headers xh
              ,xla_ae_lines xl
         WHERE aid.accounting_event_id = xe.event_id
           AND xe.event_id = xh.event_id
           AND xh.ae_header_id = xl.ae_header_id
           AND aid.invoice_id = v_trx_id;
      EXCEPTION
        WHEN NO_DATA_FOUND
        THEN
          v_err_code    := NULL;
          v_cr_amount   := 1;
          v_dr_amount   := 1;
      END;

      IF    v_cr_amount <> v_dr_amount
         OR v_acct_cr_amount <> v_acct_dr_amount
      THEN
        IF v_err_code IS NOT NULL
        THEN
          v_err_code   := v_err_code || ',' || 'Imbalance Ledger amount';
        ELSE
          v_err_code   := 'Imbalance Ledger amount';
        END IF;
      ELSE
        v_err_code   := v_err_code;
      END IF;

      BEGIN
        SELECT 'Posted and Accrual flag N in AP Invoice Distributions'
          INTO v_err_code1
          FROM DUAL
         WHERE EXISTS (SELECT 1
                         --START R12.2 Upgrade Remediation
						 /*FROM ap.ap_invoices_all ai							-- Commented code by IXPRAVEEN-ARGANO,11-May-2023
                             ,ap.ap_invoice_distributions_all aid*/             
						 FROM apps.ap_invoices_all ai							--  code Added by IXPRAVEEN-ARGANO,   11-May-2023
                             ,apps.ap_invoice_distributions_all aid	
						--END R12.2.11 Upgrade remediation
                        WHERE ai.invoice_id = aid.invoice_id
                          AND EXISTS (SELECT 'xla_flag_check'
                                        --START R12.2 Upgrade Remediation
										/*FROM xla.xla_events xle						-- Commented code by IXPRAVEEN-ARGANO,11-May-2023
                                            ,xla.xla_ae_headers xlh
                                            ,xla.xla_ae_lines xll
                                            ,gl.gl_import_references gir*/
										FROM apps.xla_events xle						--  code Added by IXPRAVEEN-ARGANO,   11-May-2023
                                            ,apps.xla_ae_headers xlh
                                            ,apps.xla_ae_lines xll
                                            ,apps.gl_import_references gir
										--END R12.2.11 Upgrade remediation
                                       WHERE xle.event_id = aid.accounting_event_id
                                         AND xle.event_id = xlh.event_id
                                         AND xle.application_id = xlh.application_id
                                         AND xlh.ae_header_id = xll.ae_header_id
                                         AND xlh.application_id = xll.application_id
                                         AND xll.gl_sl_link_id = gir.gl_sl_link_id
                                         AND xle.event_status_code = 'P'
                                         AND xle.process_status_code = 'P'
                                         AND xlh.gl_transfer_status_code = 'Y'
                                         AND xlh.accounting_entry_status_code = 'F')
                          AND aid.accrual_posted_flag = 'N'
                          AND aid.posted_flag = 'N'
                          AND ai.invoice_id = v_trx_id);
      EXCEPTION
        WHEN NO_DATA_FOUND
        THEN
          v_err_code1   := NULL;
          FND_FILE.PUT_LINE (FND_FILE.LOG, 'THIS INVOICE IS POSTED' || v_err_code);
      END;

      BEGIN
        SELECT 'Control account present and Party ID null'
          INTO v_err_code2
          FROM DUAL
         WHERE EXISTS (SELECT 1
                         FROM fnd_flex_values_vl
                        WHERE flex_value IN (SELECT segment2
                                               FROM gl_code_combinations
                                              WHERE code_combination_id IN (SELECT xl.code_combination_id
                                                                              FROM ap_invoice_distributions_all aid
                                                                                  ,xla_events xe
                                                                                  ,xla_ae_headers xh
                                                                                  ,xla_ae_lines xl
                                                                             WHERE aid.accounting_event_id = xe.event_id
                                                                               AND xe.event_id = xh.event_id
                                                                               AND xh.ae_header_id = xl.ae_header_id
                                                                               AND xl.party_id IS NULL
                                                                               AND xl.party_site_id IS NULL
                                                                               AND aid.invoice_id = v_trx_id))
                          AND SUBSTR (REPLACE (compiled_value_attributes, CHR (10), ''), 4, 1) = 'Y');
      EXCEPTION
        WHEN NO_DATA_FOUND
        THEN
          v_err_code2   := NULL;
          FND_FILE.PUT_LINE (FND_FILE.LOG, 'NO DATA FOUND FOR THIS TRX' || v_err_code);
      END;

      BEGIN
        SELECT 'Invoice having ' || LISTAGG(hold_lookup_code, ',') WITHIN GROUP(ORDER BY hold_lookup_code) || ' hold'
          INTO v_err_code3
          FROM ap_holds_all
         WHERE invoice_id = v_trx_id
           AND release_lookup_code IS NULL
           GROUP BY invoice_id;
      EXCEPTION
        WHEN NO_DATA_FOUND
        THEN
          v_err_code3   := NULL;
          FND_FILE.PUT_LINE (FND_FILE.LOG, 'NO DATA FOUND FOR THIS TRX' || v_err_code);
      END;

      IF     v_err_code IS NULL
         AND v_err_code1 IS NULL
         AND v_err_code2 IS NULL
         AND v_err_code3 IS NULL
      THEN
        v_err_code   := '';
      ELSE
        SELECT DECODE (v_err_code
                      ,NULL, NULL
                      , v_err_code || ','
                      ) ||
               DECODE (v_err_code1
                      ,NULL, NULL
                      , v_err_code1 || ','
                      ) ||
               DECODE (v_err_code2
                      ,NULL, NULL
                      , v_err_code2 || ','
                      ) ||
               v_err_code3
          INTO v_err_code
          FROM DUAL;
      END IF;

      FND_FILE.PUT_LINE (FND_FILE.LOG, 'Error code' || v_err_code);
    ELSIF v_trx_type = 'PAY'
    THEN
      BEGIN
        SELECT 'CCID -1'
          INTO v_err_code
          FROM DUAL
         WHERE EXISTS (SELECT 1
                         FROM ap_checks_all ac
                             ,ap_payment_history_all aph
                             ,xla_events xe
                             ,xla_ae_headers xh
                             ,xla_ae_lines xl
                        WHERE ac.check_id = aph.check_id
                          AND aph.accounting_event_id = xe.event_id
                          AND xe.event_id = xh.event_id
                          AND xh.ae_header_id = xl.ae_header_id
                          AND xl.code_combination_id = '-1'
                          AND ac.check_id = v_trx_id);
      EXCEPTION
        WHEN NO_DATA_FOUND
        THEN
          v_err_code   := NULL;
      END;

      BEGIN
        SELECT SUM (NVL (entered_cr, 0))
              ,SUM (NVL (entered_dr, 0))
              ,SUM (NVL (accounted_cr, 0))
              ,SUM (NVL (accounted_dr, 0))
          INTO v_cr_amount
              ,v_dr_amount
              ,v_acct_cr_amount
              ,v_acct_dr_amount
          FROM ap_payment_history_all aph
              ,xla_events xe
              ,xla_ae_headers xh
              ,xla_ae_lines xl
         WHERE aph.accounting_event_id = xe.event_id
           AND xe.event_id = xh.event_id
           AND xh.ae_header_id = xl.ae_header_id
           AND aph.check_id = v_trx_id;
      EXCEPTION
        WHEN NO_DATA_FOUND
        THEN
          v_err_code    := NULL;
          v_cr_amount   := 1;
          v_dr_amount   := 1;
      END;

      --group by xl.ae_header_id
      IF    v_cr_amount <> v_dr_amount
         OR v_acct_cr_amount <> v_acct_dr_amount
      THEN
        IF v_err_code IS NOT NULL
        THEN
          v_err_code   := v_err_code || ',' || 'Imbalance Ledger amount';
        ELSE
          v_err_code   := 'Imbalance Ledger amount';
        END IF;
      ELSE
        v_err_code   := v_err_code;
      END IF;

      BEGIN
        SELECT 'Unaccounted invoice present for payment'
          INTO v_err_code1
          FROM DUAL
         WHERE EXISTS (SELECT 1
                         FROM ap_invoice_payments_all aip
                        WHERE EXISTS (SELECT 'unaccount invoice exists'
                                        FROM ap_invoice_distributions_all aid
                                       WHERE aid.invoice_id = aip.invoice_id
                                         AND NVL (aid.posted_flag, 'N') = 'N')
                          AND aip.check_id = v_trx_id);
      EXCEPTION
        WHEN NO_DATA_FOUND
        THEN
          v_err_code1   := NULL;
      END;

      BEGIN
        SELECT 'Control account present and Party ID null'
          INTO v_err_code2
          FROM DUAL
         WHERE EXISTS (SELECT 1
                         FROM fnd_flex_values_vl
                        WHERE flex_value IN (SELECT segment2
                                               FROM gl_code_combinations
                                              WHERE code_combination_id IN (SELECT xl.code_combination_id
                                                                              FROM ap_payment_history_all aph
                                                                                  ,xla_events xe
                                                                                  ,xla_ae_headers xh
                                                                                  ,xla_ae_lines xl
                                                                             WHERE aph.accounting_event_id = xe.event_id
                                                                               AND xe.event_id = xh.event_id
                                                                               AND xh.ae_header_id = xl.ae_header_id
                                                                               AND xl.party_id IS NULL
                                                                               AND xl.party_site_id IS NULL
                                                                               AND aph.check_id = v_trx_id))
                          AND SUBSTR (REPLACE (compiled_value_attributes, CHR (10), ''), 4, 1) = 'Y');
      EXCEPTION
        WHEN NO_DATA_FOUND
        THEN
          v_err_code2   := NULL;
      END;

      IF     v_err_code IS NULL
         AND v_err_code1 IS NULL
         AND v_err_code2 IS NULL
      THEN
        v_err_code   := '';
      ELSE
        SELECT DECODE (v_err_code
                      ,NULL, NULL
                      , v_err_code || ','
                      ) || DECODE (v_err_code1
                                  ,NULL, NULL
                                  , v_err_code1 || ','
                                  ) || v_err_code2
          INTO v_err_code
          FROM DUAL;
      END IF;

      FND_FILE.PUT_LINE (FND_FILE.LOG, 'Error code' || v_err_code);
    END IF;

    RETURN v_err_code;
  EXCEPTION
    WHEN TOO_MANY_ROWS
    THEN
      RETURN NULL;
  END ttec_error_code;

  FUNCTION ttec_get_approval_status (
    p_invoice_id                  IN    NUMBER
   ,p_invoice_amount              IN    NUMBER
   ,p_payment_status_flag         IN    VARCHAR2
   ,p_invoice_type_lookup_code    IN    VARCHAR2
  )
    RETURN VARCHAR2
  AS
    l_invoice_approval_status    VARCHAR2 (25);
  BEGIN
    l_invoice_approval_status   := ap_invoices_pkg.get_approval_status (p_invoice_id, p_invoice_amount, p_payment_status_flag, p_invoice_type_lookup_code);
    RETURN (l_invoice_approval_status);
  EXCEPTION
    WHEN OTHERS
    THEN
      RETURN SUBSTR ('Error:' || SQLERRM, 1, 25);
  END ttec_get_approval_status;
END ttec_ap_clsr_excep_report;
/
show errors;
/