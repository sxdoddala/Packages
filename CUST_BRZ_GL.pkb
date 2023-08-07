create or replace PACKAGE BODY      cust_brz_gl
IS
/*---------------------------------------------------------------------------------------
 Package      : CUST_BRZ_GL
 Objective    : Replace core description by a custom desc. on GL Lines
 Package Body
 Method:
 1. Replace core description by a Brazilian descrition for GL Lines
 Parameters:
           P_Ledger_id -- Code for Brazil set of Books
            p_date  -- effetive date of transactions

MODIFICATION HISTORY
Person               Version  Date        Comments
------------------------------------------------
Felipe Costa         1.0      05/09/2005  Initial Script
Kaushik Babu         1.1      06/30/2010 Issue during insertion of description column into GL_JE_LINES table TT 246787
                                          used substrb instead of substr function
Kaushik Gonuguntla   1.2      05/05/2010 Added a new procedure ttec_brz_ar_gl_history for changing description column to
                                         portuguse lang on AR lines imported to GL . TT 159916
Kaushik Gonuguntla   1.3      01/18/2010 Add more translations for Credit Memo JE receivable lines TTSD 509933
Ravi Pasula          1.4      changing columns and table as per new R12 Application.
Ravi Pasula          1.5     changing code as per R#1434950
Kaushik Gonuguntla   1.6     04/17/2012  Add new procedure as per TTSD I 2247241 ttec_brz_gl_upd_desc
RXNETHI-ARGANO       1.0     05/05/2023   R12.2 Upgrade Remediation
\*== END ==================================================================================================*/
   PROCEDURE ttec_brz_gl_upd_desc (
      errbuf             OUT      VARCHAR2,
      retcode            OUT      NUMBER,
      p_application_id   IN       NUMBER,
      p_ledger_id        IN       NUMBER,
      p_begin_date       IN       VARCHAR2,
      p_close_date       IN       VARCHAR2,
      p_batch_name       IN       VARCHAR2
   )
   IS
      CURSOR c_rec_trx_id (p_trx_id NUMBER)
      IS
         SELECT trx_id, trx_num, trx_type
           FROM (SELECT DISTINCT adj.adjustment_id trx_id,
                                 adj.adjustment_number trx_num,
                                 art.NAME trx_type
                            FROM apps.ar_adjustments_all adj,
                                 apps.ar_receivables_trx_all art
                           WHERE adj.set_of_books_id = p_ledger_id
                             AND adj.receivables_trx_id =
                                                        art.receivables_trx_id
                             AND adj.adjustment_id = p_trx_id
                 UNION ALL
                 SELECT DISTINCT customer_trx_id trx_id, trx_number trx_num,
                                 NULL trx_type
                            FROM apps.ra_customer_trx_all
                           WHERE set_of_books_id = p_ledger_id
                             AND customer_trx_id = p_trx_id
                 UNION ALL
                 SELECT DISTINCT cash_receipt_id trx_id,
                                 receipt_number trx_num, NULL trx_type
                            FROM apps.ar_cash_receipts_all
                           WHERE set_of_books_id = p_ledger_id
                             AND cash_receipt_id = p_trx_id) DUAL;

      CURSOR c_pay_trx_id (p_trx_id NUMBER, p_category VARCHAR2)
      IS
         SELECT invoice_id, invoice_num, vendor_name, check_number,
                payment_method_code
           FROM (SELECT DISTINCT ai.invoice_id, ai.invoice_num,
                                 asp.vendor_name, aca.check_number,
                                 aca.payment_method_code
                            FROM ap_invoices_all ai,
                                 ap_suppliers asp,
                                 ap_invoice_payments_all aip,
                                 ap_checks_all aca,
                                 ap_invoice_lines_all apl
                           WHERE ai.set_of_books_id = p_ledger_id
                             AND ai.vendor_id = asp.vendor_id
                             AND ai.invoice_id = apl.invoice_id
                             AND ai.invoice_id = aip.invoice_id
                             AND aip.check_id = aca.check_id
                             AND p_category IN
                                          ('Payments', 'Reconciled Payments')
                             AND aca.check_id = p_trx_id
                 UNION ALL
                 SELECT DISTINCT ai.invoice_id, ai.invoice_num,
                                 asp.vendor_name, NULL check_number,
                                 NULL payment_method_code
                            FROM ap_invoices_all ai,
                                 ap_suppliers asp,
                                 ap_invoice_lines_all apl
                           WHERE ai.set_of_books_id = p_ledger_id
                             AND ai.vendor_id = asp.vendor_id
                             AND ai.invoice_id = apl.invoice_id
                             AND p_category IN ('Purchase Invoices')
                             AND ai.invoice_id = p_trx_id) DUAL;

      CURSOR c_sel_trx
      IS
         SELECT DISTINCT jl.ROWID, jl.description, jh.je_source,
                         jh.je_category, xte.transaction_number reference_4,
                         hp.party_id reference_7, jh.period_name,
                         jh.currency_code, jh.je_header_id, jl.je_line_num,
                         xal.code_combination_id, jb.NAME batch_name,
                         hp.party_name trx_created_name, gcc.segment1,
                         gcc.segment2, gcc.segment3, gcc.segment4,
                         gcc.segment5, gcc.segment6, jh.ledger_id,
                         xah.event_type_code reference_8,
                         gir.subledger_doc_sequence_id,
                         gir.subledger_doc_sequence_value,
                         xal.accounting_class_code reference_9,
                         xal.accounting_date, xah.doc_category_code,
                         hca.account_number, xah.ae_header_id, xae.event_id,
                         xal.ae_line_num, xdl.tax_line_ref_id,
                         xte.source_id_int_1, hpca.party_name customer_name
                    /*
					START R12.2 Upgrade Remediation
					code commented by RXNETHI-ARGANO, 05/MAY/23
					FROM xla.xla_ae_headers xah,
                         xla.xla_ae_lines xal,
                         xla.xla_events xae,
                         xla.xla_transaction_entities xte,
                         xla.xla_distribution_links xdl,
                         apps.gl_import_references gir,
                         gl.gl_code_combinations gcc,
                         gl.gl_je_batches jb,
                         gl.gl_je_headers jh,
                         gl.gl_je_lines jl,
                         apps.hz_parties hp,
                         apps.hz_cust_accounts hca,
                         apps.hz_parties hpca
						 */
					--code added by RXNETHI-ARGANO, 05/MAY/23
					FROM apps.xla_ae_headers xah,
                         apps.xla_ae_lines xal,
                         apps.xla_events xae,
                         apps.xla_transaction_entities xte,
                         apps.xla_distribution_links xdl,
                         apps.gl_import_references gir,
                         apps.gl_code_combinations gcc,
                         apps.gl_je_batches jb,
                         apps.gl_je_headers jh,
                         apps.gl_je_lines jl,
                         apps.hz_parties hp,
                         apps.hz_cust_accounts hca,
                         apps.hz_parties hpca
					--END R12.2 Upgrade Remediation
                   WHERE xah.ae_header_id = xal.ae_header_id
                     AND xah.entity_id = xte.entity_id
                     AND xae.entity_id = xte.entity_id
                     AND xah.event_id = xae.event_id
                     AND xal.ae_header_id = xdl.ae_header_id(+)
                     AND xal.ae_line_num = xdl.ae_line_num(+)
                     --  AND xah.event_id = xdl.event_id
                     AND xal.gl_sl_link_id = gir.gl_sl_link_id
                     AND xal.gl_sl_link_table = gir.gl_sl_link_table
                     AND xah.application_id = xal.application_id
                     AND xal.application_id = xte.application_id
                     AND xal.application_id = xdl.application_id(+)
                     AND xae.application_id = xte.application_id
                     AND xah.application_id = xae.application_id
                     AND jb.je_batch_id = jh.je_batch_id
                     AND jh.je_header_id = jl.je_header_id
                     AND gir.je_header_id = jh.je_header_id
                     AND xal.code_combination_id = gcc.code_combination_id
                     AND gir.je_line_num = jl.je_line_num
                     AND jh.je_category IN
                            ('Purchase Invoices', 'Payments',
                             'Sales Invoices', 'Receipts', 'Misc Receipts',
                             'Adjustment', 'Credit Memos', 'Debit Memos',
                             'Reconciled Payments')
                     AND xal.party_id = hp.party_id(+)
                     AND hp.party_id = hca.cust_account_id(+)
                     AND hca.party_id = hpca.party_id(+)
                     AND xah.application_id = p_application_id
                     AND jh.ledger_id = p_ledger_id
                     AND jb.NAME = NVL (p_batch_name, jb.NAME)
                     --AND jh.je_header_id = 5134084
                     --AND xte.source_id_int_1 = 1712018
                     AND TO_DATE (jb.posted_date)
                            BETWEEN fnd_date.canonical_to_date (p_begin_date)
                                AND fnd_date.canonical_to_date (p_close_date);

      l_line_num      gl_je_lines.je_line_num%TYPE             DEFAULT NULL;
      l_upd_str       VARCHAR2 (2000)                          DEFAULT NULL;
      l_tax_name      zx_lines.tax%TYPE                        DEFAULT NULL;
      l_inv_id        ap_invoices_all.invoice_id%TYPE          DEFAULT NULL;
      l_inv_num       ap_invoices_all.invoice_num%TYPE         DEFAULT NULL;
      l_vendor_name   ap_suppliers.vendor_name%TYPE            DEFAULT NULL;
      l_chk_num       ap_checks_all.check_number%TYPE          DEFAULT NULL;
      l_pay_code      ap_checks_all.payment_method_code%TYPE   DEFAULT NULL;
   BEGIN
      fnd_file.put_line (fnd_file.output,
                            'DESCRIPTION'
                         || '|'
                         || 'TRANSACTION_NUM'
                         || '|'
                         || 'PERIOD_NAME'
                         || '|'
                         || 'CODE_COMBINATION'
                         || '|'
                         || 'CLIENT_NAME'
                         || '|'
                         || 'BATCH_NAME'
                         || '|'
                         || 'SOURCE_ID_INT_1'
                         || '|'
                         || 'HEADER_ID'
                         || '|'
                         || 'LINE_NUM'
                        );

      FOR r_sel_trx IN c_sel_trx
      LOOP
         BEGIN
            BEGIN
               l_upd_str := NULL;
               l_line_num := NULL;

               --UPDATE gl.gl_je_lines   --code commented by RXNETHI-ARGANO,05/05/23
               UPDATE apps.gl_je_lines   --code added by RXNETHI-ARGANO,05/05/23
                  SET description = l_upd_str
                WHERE ROWID = r_sel_trx.ROWID
                  AND je_header_id = r_sel_trx.je_header_id
                  AND je_line_num = r_sel_trx.je_line_num;
            EXCEPTION
               WHEN NO_DATA_FOUND
               THEN
                  fnd_file.put_line (fnd_file.LOG,
                                        'No Data GL_JE_LINES Tab -'
                                     || 'JE_HEADER_ID -'
                                     || r_sel_trx.je_header_id
                                     || 'JE_LINE_NUM-'
                                     || r_sel_trx.je_line_num
                                     || '-'
                                     || SQLERRM
                                    );
               WHEN OTHERS
               THEN
                  fnd_file.put_line (fnd_file.LOG,
                                        'Error GL_JE_LINES Tab -'
                                     || 'JE_HEADER_ID -'
                                     || r_sel_trx.je_header_id
                                     || 'JE_LINE_NUM-'
                                     || r_sel_trx.je_line_num
                                     || '-'
                                     || SQLERRM
                                    );
            END;

            IF p_application_id = 222
            THEN
               FOR r_rec_trx_id IN c_rec_trx_id (r_sel_trx.source_id_int_1)
               LOOP
                  IF r_sel_trx.tax_line_ref_id IS NULL
                  THEN
                     IF r_sel_trx.je_category = 'Adjustment'
                     THEN
                        l_upd_str :=
                              r_rec_trx_id.trx_type
                           || '-'
                           || r_sel_trx.customer_name
                           || '-'
                           || r_rec_trx_id.trx_num;
                     ELSE
                        l_upd_str :=
                              r_sel_trx.doc_category_code
                           || '-'
                           || r_sel_trx.customer_name
                           || '-'
                           || r_rec_trx_id.trx_num;
                     END IF;
                  ELSE
                     BEGIN
                        l_tax_name := NULL;

                        SELECT tax
                          INTO l_tax_name
                          FROM apps.zx_lines
                         WHERE tax_line_id = r_sel_trx.tax_line_ref_id;
                     EXCEPTION
                        WHEN NO_DATA_FOUND
                        THEN
                           l_tax_name := NULL;
                        WHEN OTHERS
                        THEN
                           l_tax_name := NULL;
                     END;

                     l_upd_str :=
                           l_tax_name
                        || '-'
                        || r_sel_trx.customer_name
                        || '-'
                        || r_rec_trx_id.trx_num;
                  END IF;

                  --UPDATE gl.gl_je_lines          --code commented by RXNETHI-ARGANO,05/05/23
                  UPDATE apps.gl_je_lines          --code added by RXNETHI-ARGANO,05/05/23
                     SET description = SUBSTRB (l_upd_str, 0, 240)
                   WHERE ROWID = r_sel_trx.ROWID
                     AND je_header_id = r_sel_trx.je_header_id
                     AND je_line_num = r_sel_trx.je_line_num;

                  COMMIT;
                  fnd_file.put_line (fnd_file.output,
                                        l_upd_str
                                     || '|'
                                     || r_sel_trx.reference_4
                                     || '|'
                                     || r_sel_trx.period_name
                                     || '|'
                                     || (   r_sel_trx.segment1
                                         || '.'
                                         || r_sel_trx.segment2
                                         || '.'
                                         || r_sel_trx.segment3
                                         || '.'
                                         || r_sel_trx.segment4
                                         || '.'
                                         || r_sel_trx.segment5
                                         || '.'
                                         || r_sel_trx.segment6
                                        )
                                     || '|'
                                     || r_sel_trx.customer_name
                                     || '|'
                                     || r_sel_trx.batch_name
                                     || '|'
                                     || r_sel_trx.source_id_int_1
                                     || '|'
                                     || r_sel_trx.je_header_id
                                     || '|'
                                     || r_sel_trx.je_line_num
                                    );
               END LOOP;
            ELSIF p_application_id = 200
            THEN
               FOR r_pay_trx_id IN c_pay_trx_id (r_sel_trx.source_id_int_1,
                                                 r_sel_trx.je_category
                                                )
               LOOP
                  BEGIN
                     IF r_sel_trx.tax_line_ref_id IS NULL
                     THEN
                        IF r_sel_trx.je_category IN
                                         ('Payments', 'Reconciled Payments')
                        THEN
                           l_upd_str :=
                                 r_pay_trx_id.payment_method_code
                              || '-'
                              || r_pay_trx_id.vendor_name
                              || '-'
                              || r_pay_trx_id.invoice_num;
                        ELSE
                           IF r_sel_trx.reference_9 = 'ITEM EXPENSE'
                           THEN
                              l_upd_str :=
                                    r_pay_trx_id.vendor_name
                                 || '-'
                                 || r_pay_trx_id.check_number
                                 || '-'
                                 || r_pay_trx_id.invoice_num;
                           ELSIF r_sel_trx.reference_9 =
                                                       'MISCELLANEOUS EXPENSE'
                           THEN
                              l_upd_str :=
                                    r_sel_trx.reference_9
                                 || '-'
                                 || r_pay_trx_id.vendor_name
                                 || '-'
                                 || r_pay_trx_id.invoice_num;
                           ELSE
                              l_upd_str :=
                                    r_pay_trx_id.vendor_name
                                 || '-'
                                 || r_pay_trx_id.invoice_num;
                           END IF;
                        END IF;
                     ELSE
                        BEGIN
                           l_tax_name := NULL;

                           SELECT tax
                             INTO l_tax_name
                             FROM apps.zx_lines
                            WHERE tax_line_id = r_sel_trx.tax_line_ref_id;
                        EXCEPTION
                           WHEN NO_DATA_FOUND
                           THEN
                              l_tax_name := NULL;
                           WHEN OTHERS
                           THEN
                              l_tax_name := NULL;
                        END;

                        l_upd_str :=
                              l_tax_name
                           || '-'
                           || r_pay_trx_id.vendor_name
                           || '-'
                           || r_pay_trx_id.invoice_num;
                     END IF;

                     --UPDATE gl.gl_je_lines       --code commented by RXNETHI-ARGANO,05/05/23
                     UPDATE apps.gl_je_lines       --code added by RXNETHI-ARGANO,05/05/23
                        SET description = SUBSTRB (l_upd_str, 0, 240)
                      WHERE ROWID = r_sel_trx.ROWID
                        AND je_header_id = r_sel_trx.je_header_id
                        AND je_line_num = r_sel_trx.je_line_num;

                     COMMIT;
                     fnd_file.put_line (fnd_file.output,
                                           l_upd_str
                                        || '|'
                                        || r_sel_trx.reference_4
                                        || '|'
                                        || r_sel_trx.period_name
                                        || '|'
                                        || (   r_sel_trx.segment1
                                            || '.'
                                            || r_sel_trx.segment2
                                            || '.'
                                            || r_sel_trx.segment3
                                            || '.'
                                            || r_sel_trx.segment4
                                            || '.'
                                            || r_sel_trx.segment5
                                            || '.'
                                            || r_sel_trx.segment6
                                           )
                                        || '|'
                                        || r_sel_trx.customer_name
                                        || '|'
                                        || r_sel_trx.batch_name
                                        || '|'
                                        || r_sel_trx.source_id_int_1
                                        || '|'
                                        || r_sel_trx.je_header_id
                                        || '|'
                                        || r_sel_trx.je_line_num
                                       );
                  END;
               END LOOP;
            END IF;
         EXCEPTION
            WHEN OTHERS
            THEN
               fnd_file.put_line
                             (fnd_file.LOG,
                                 'Error in updating the GL Receivable line -'
                              || 'JE_HEADER_ID - '
                              || p_application_id
                              || '-'
                              || r_sel_trx.je_header_id
                              || 'JE_LINE_NUM - '
                              || r_sel_trx.je_line_num
                              || '-'
                              || SQLERRM
                             );
               raise_application_error
                             (-20003,
                                 'Error in updating the GL Receivable line - '
                              || 'JE_HEADER_ID - '
                              || p_application_id
                              || '-'
                              || r_sel_trx.je_header_id
                              || 'JE_LINE_NUM - '
                              || r_sel_trx.je_line_num
                              || '-'
                              || SQLERRM
                             );
         END;
      END LOOP;
   EXCEPTION
      WHEN OTHERS
      THEN
         fnd_file.put_line (fnd_file.LOG,
                            'Error out of main loop -' || SQLERRM
                           );
         raise_application_error (-20003,
                                  'Error in the main query - ' || SQLERRM
                                 );
   END ttec_brz_gl_upd_desc;

   PROCEDURE cust_brz_gl_history (
      errbuf         OUT      VARCHAR2,
      retcode        OUT      NUMBER,
      p_ledger_id    IN       NUMBER,
      p_begin_date   IN       VARCHAR2,
      p_close_date   IN       VARCHAR2
   )
   IS
-- local variables
      v_description    VARCHAR2 (1000);
      v_description1   VARCHAR2 (1000);
      v_reference_5    VARCHAR2 (1000) DEFAULT NULL;
      v_pos_sup        NUMBER;
      v_reference_1    VARCHAR2 (1000);
      v_update         NUMBER;
   BEGIN
      FOR c1 IN
         (SELECT DISTINCT jl.ROWID, jl.description, jh.je_source SOURCE,
                          ap.invoice_num reference_5, jh.je_header_id,
                          jl.je_line_num, xte.entity_code reference_6,
                          hp.party_name reference_1,
                          ac.check_number reference_4
                     /*
					 START R12.2 Upgrade Remediation
					 code commented by RXNETHI-ARGANO 05/MAY/2023
					 FROM gl.gl_je_headers jh,
                          gl.gl_je_lines jl,
                          apps.gl_import_references gr,
                          apps.xla_ae_lines xl,
                          apps.hz_parties hp,
                          apps.xla_ae_headers xah,
                          apps.xla_events xe,
                          xla.xla_transaction_entities xte,
                          ap.ap_invoices_all ap,
                          ap.ap_invoice_payments_all aip,
                          ap.ap_checks_all ac,
                          gl.gl_je_batches jb
						  */
						  --code added by RXNETHI-ARGANO, 05/MAY/2023
					 FROM apps.gl_je_headers jh,
                          apps.gl_je_lines jl,
                          apps.gl_import_references gr,
                          apps.xla_ae_lines xl,
                          apps.hz_parties hp,
                          apps.xla_ae_headers xah,
                          apps.xla_events xe,
                          apps.xla_transaction_entities xte,
                          apps.ap_invoices_all ap,
                          apps.ap_invoice_payments_all aip,
                          apps.ap_checks_all ac,
                          apps.gl_je_batches jb
					 --END R12.2 Upgrade Remediation
                    WHERE jh.je_source IN ('Payables', '22')
                      AND jh.ledger_id = p_ledger_id                     --254
                      --and   jh.period_name = 'APR-12'
                      AND jh.je_header_id = jl.je_header_id
                      AND gr.je_header_id = jh.je_header_id
                      AND gr.gl_sl_link_id = xl.gl_sl_link_id
                      AND xl.party_id = hp.party_id
                      AND xl.ae_header_id = xah.ae_header_id
                      AND xah.event_id = xe.event_id
                      AND xte.entity_id = xe.entity_id
                      AND ap.invoice_id = xte.source_id_int_1
                      AND aip.invoice_id = ap.invoice_id
                      AND ac.check_id = aip.check_id
                      AND jb.je_batch_id = jh.je_batch_id
                      --and jb.name = 'Payables A 1054399 21072089'--'Payables A 1054467 21092623'
                      AND TO_DATE (xl.accounting_date)
                             BETWEEN fnd_date.canonical_to_date (p_begin_date)
                                 AND fnd_date.canonical_to_date (p_close_date))
      LOOP
         BEGIN
            v_update := 0;
            v_description := NULL;
            v_description1 := NULL;
            v_reference_5 := NULL;
            v_reference_1 := NULL;
            v_pos_sup := 0;

            IF (c1.SOURCE = 'Payables')
            THEN
               BEGIN
                  --
                  IF (   c1.description = 'Journal Import Created'
                      OR c1.description LIKE 'Importa% Lan%ento Criada'
                      OR c1.description IS NULL
                     )
                  THEN
                     -- Redo the description for correction and attend Brzil financial needs
                     BEGIN
                        IF c1.reference_5 IS NOT NULL
                        THEN
                           v_description :=
                                           'NFF: ' || c1.reference_5 || ' - ';
                        END IF;

                        IF c1.reference_6 = 'AP Payments'
                        THEN
                           v_description :=
                                 v_description
                              || 'PGTO: '
                              || c1.reference_4
                              || ' - ';
                        END IF;

                        v_description := v_description || c1.reference_1;
                        v_update := 1;
                     END;
                  --
                  ELSIF (   c1.description != 'Journal Import Created'
                         OR c1.description NOT LIKE 'Importa% Lan%ento Criada'
                        )
                  THEN
                     -- Redo the description for correction and attend Brzil financial needs
                     --
                     BEGIN
                        IF (    (    c1.description NOT LIKE 'NFF:%'
                                 AND c1.description NOT LIKE 'PGTO:%'
                                )
                            AND c1.description NOT LIKE
                                                   '%Importa% Lan%ento Criada'
                           )
                        THEN
                           BEGIN
                              v_pos_sup := 0;

                              IF c1.reference_5 IS NOT NULL
                              THEN
                                 BEGIN
                                    v_description :=
                                           'NFF: ' || c1.reference_5 || ' - ';
                                    v_pos_sup := 1;
                                 END;
                              END IF;

                              IF c1.reference_6 = 'AP Payments'
                              THEN
                                 BEGIN
                                    v_description :=
                                          v_description
                                       || 'PGTO: '
                                       || c1.reference_4
                                       || ' - ';
                                    v_pos_sup := 1;
                                 END;
                              END IF;

                              v_description :=
                                    v_description
                                 || c1.reference_1
                                 || ' - '
                                 || c1.description;

                              IF v_pos_sup = 0
                              THEN
                                 v_update := 0;
                              ELSE
                                 v_update := 1;
                              END IF;
                           END;
                        END IF;

                        IF (    (   c1.description LIKE 'NFF:%'
                                 OR c1.description LIKE 'PGTO:%'
                                )
                            AND c1.description LIKE
                                                   '%Importa% Lan%ento Criada'
                           )
                        THEN
                           BEGIN
                              v_description :=
                                 SUBSTR (c1.description,
                                         0,
                                         INSTR (c1.description, 'Import') - 4
                                        );
                              v_update := 1;
                           END;
                        END IF;
                     END;
                  --
                  END IF;

                  IF v_update != 0
                  THEN
                     v_description1 := SUBSTRB (v_description, 1, 240); --1.1

                     BEGIN
                        --UPDATE gl.gl_je_lines --code commented by RXNETHI-ARGANO, 05/MAY/2023
						UPDATE apps.gl_je_lines --code added by RXNETHI-ARGANO, 05/MAY/2023
                           SET description = v_description1
                         WHERE ROWID = c1.ROWID;

                        COMMIT;
                     END;
                  END IF;
               END;
            ELSIF c1.SOURCE = '22'
            THEN
               --Fill the reference for invoice number and supplier number that came in blanket for Recebimento Integrado
               -- Redo the description for correction and attend Brazil financial needs
               BEGIN
                  v_pos_sup := 0;

                  IF c1.reference_5 IS NULL
                  THEN
                     BEGIN
                        v_reference_5 :=
                           SUBSTR (c1.description,
                                   INSTR (c1.description, 'Docto') + 6,
                                     INSTR (c1.description, ' de')
                                   - INSTR (c1.description, 'Docto')
                                   - 6
                                  );
                        v_pos_sup := INSTR (c1.description, ';');

                        IF v_pos_sup = 0
                        THEN
                           v_reference_1 :=
                              SUBSTR (c1.description,
                                      INSTR (c1.description, 'de') + 2,
                                      LENGTH (c1.description)
                                     );
                        ELSE
                           v_reference_1 :=
                              SUBSTR (c1.description,
                                      INSTR (c1.description, 'de') + 2,
                                        INSTR (c1.description, ';')
                                      - INSTR (c1.description, 'de')
                                      - 2
                                     );
                        END IF;

                        v_description :=
                              SUBSTR (c1.description,
                                      INSTR (c1.description, 'Docto'),
                                      LENGTH (c1.description)
                                     )
                           || ' '
                           || SUBSTR (c1.description,
                                      0,
                                      INSTR (c1.description, 'Docto') - 2
                                     );

                        --UPDATE gl.gl_je_lines      --code commented by RXNETHI-ARGANO,05/05/23
                        UPDATE apps.gl_je_lines      --code added by RXNETHI-ARGANO,05/05/23
                           SET reference_5 = SUBSTR (v_reference_5, 0, 240),
                               reference_1 = SUBSTR (v_reference_1, 0, 240),
                               description = SUBSTRB (v_description, 0, 240)
                         -- 1.1
                        WHERE  ROWID = c1.ROWID AND reference_5 IS NULL;

                        COMMIT;
                     END;
                  END IF;
               END;
            END IF;
         EXCEPTION
            WHEN OTHERS
            THEN
               fnd_file.put_line (fnd_file.LOG,
                                     'Error on the AP record -'
                                  || SQLERRM
                                  || ' - '
                                  || 'JE_HEADER_ID - '
                                  || c1.je_header_id
                                  || 'JE_LINE_NUM - '
                                  || c1.je_line_num
                                 );
               raise_application_error (-20003,
                                        'Error on the AP record - ' || SQLERRM
                                       );
         END;
      END LOOP;
   EXCEPTION
      WHEN OTHERS
      THEN
         fnd_file.put_line (fnd_file.LOG,
                               'Error out of main loop cust_brz_gl_history -'
                            || SQLERRM
                           );
   END cust_brz_gl_history;

   PROCEDURE ttec_brz_ar_gl_history (
      errbuf         OUT      VARCHAR2,
      retcode        OUT      NUMBER,
      p_ledger_id    IN       NUMBER,
      p_begin_date   IN       VARCHAR2,
      p_close_date   IN       VARCHAR2
   )
   IS
      -- Query to list all AR lines that is been imported to GL to translate description column to portuguse
      CURSOR c_gl_ar_line
      IS
         SELECT DISTINCT jl.ROWID, jl.description, jh.je_source,
                         xte.transaction_number reference_4,
                         xte.transaction_number reference_5,
                         hp.party_id reference_7, jh.period_name,
                         jh.currency_code, jh.je_header_id, jl.je_line_num,
                         xl.code_combination_id, hp.party_name customer_name,
                         gcc.segment1, gcc.segment2, gcc.segment3,
                         gcc.segment4, gcc.segment5, gcc.segment6,
                         jh.ledger_id, xah.event_type_code reference_8,
                         gr.subledger_doc_sequence_id,
                         gr.subledger_doc_sequence_value,
                         xl.accounting_class_code reference_9
                    /*
					
					START R12.2 Upgrade Remediation
					code commented by RXNETHI-ARGANO, 05/MAY/2023
					FROM gl.gl_je_headers jh,
                         gl.gl_je_lines jl,
                         apps.gl_import_references gr,
                         apps.xla_ae_lines xl,
                         apps.hz_parties hp,
                         apps.xla_ae_headers xah,
                         apps.xla_events xe,
                         xla.xla_transaction_entities xte,
                         apps.ra_customer_trx_all ract,
                         gl.gl_code_combinations gcc,
                         gl.gl_je_batches jb
						 */
					--code added by RXNETHI-ARGANO, 05/MAY/2023
					FROM apps.gl_je_headers jh,
                         apps.gl_je_lines jl,
                         apps.gl_import_references gr,
                         apps.xla_ae_lines xl,
                         apps.hz_parties hp,
                         apps.xla_ae_headers xah,
                         apps.xla_events xe,
                         apps.xla_transaction_entities xte,
                         apps.ra_customer_trx_all ract,
                         apps.gl_code_combinations gcc,
                         apps.gl_je_batches jb
					--END R12.2 Upgrade Remediation
                   WHERE jh.je_source = 'Receivables'
                     AND jh.ledger_id = p_ledger_id                      --254
                     --and   jh.period_name = 'APR-12'
                     AND jh.je_header_id = jl.je_header_id
                     AND gr.je_header_id = jh.je_header_id
                     AND gr.gl_sl_link_id = xl.gl_sl_link_id
                     AND xl.party_id = hp.party_id
                     AND xl.ae_header_id = xah.ae_header_id
                     AND xah.event_id = xe.event_id
                     AND xte.entity_id = xe.entity_id
                     AND ract.customer_trx_id = xte.source_id_int_1
                     AND xl.code_combination_id = gcc.code_combination_id
                     --and jb.name = 'Receivables A 1051778 21028410'
                     ---and jh.je_header_id = '3803517'
                     AND jb.je_batch_id = jh.je_batch_id
                     AND TO_DATE (xl.accounting_date)
                            BETWEEN fnd_date.canonical_to_date (p_begin_date)
                                AND fnd_date.canonical_to_date (p_close_date)
                ORDER BY xte.transaction_number;

      l_global_att12   apps.ar_vat_tax_all.global_attribute12%TYPE
                                                                  DEFAULT NULL;
      l_upd_str        VARCHAR2 (2000)                            DEFAULT NULL;
      --l_reference_5    xla.xla_transaction_entities.transaction_number%TYPE
      l_reference_5    apps.xla_transaction_entities.transaction_number%TYPE
                                                                  DEFAULT NULL;
   BEGIN
      fnd_file.put_line (fnd_file.output,
                            'DESCRIPTION'
                         || '|'
                         || 'TRANSACTION_NUM'
                         || '|'
                         || 'PERIOD_NAME'
                         || '|'
                         || 'CODE_COMBINATION'
                         || '|'
                         || 'CLIENT_NAME'
                        );

      BEGIN
         fnd_file.put_line (fnd_file.LOG, 'Test');
      END;

      FOR r_gl_ar_line IN c_gl_ar_line
      LOOP
         BEGIN
            l_upd_str := NULL;

            --l_reference_5 := NULL;
            --UPDATE gl.gl_je_lines --code commented by RXNETHI-ARGANO, 05/MAY/2023
			UPDATE apps.gl_je_lines --code added by RXNETHI-ARGANO, 05/MAY/2023
               SET description = l_upd_str
             WHERE ROWID = r_gl_ar_line.ROWID
               AND je_header_id = r_gl_ar_line.je_header_id
               AND je_line_num = r_gl_ar_line.je_line_num;

            COMMIT;
            l_global_att12 := NULL;

            --<1.3 Start>
            IF r_gl_ar_line.reference_8 = 'CMAPP'
            THEN                                                         --1.5
               l_reference_5 := r_gl_ar_line.reference_5;
            ELSE
               l_reference_5 := NULL;
            END IF;                                                      --1.5

            BEGIN
               SELECT DISTINCT avta.global_attribute12
                          INTO l_global_att12
                          FROM apps.ar_vat_tax_all avta,
                               --gl.gl_code_combinations gcc --code commented by RXNETHI-ARGANO, 05/MAY/2023
							   apps.gl_code_combinations gcc --code added by RXNETHI-ARGANO, 05/MAY/2023
                         WHERE tax_type = 'VAT'
                           AND avta.tax_account_id = gcc.code_combination_id
                           AND gcc.segment1 = r_gl_ar_line.segment1
                           AND gcc.segment3 = r_gl_ar_line.segment3
                           AND gcc.segment4 = r_gl_ar_line.segment4
                           AND gcc.segment5 = r_gl_ar_line.segment5
                           AND gcc.segment6 = r_gl_ar_line.segment6
                           AND avta.set_of_books_id = r_gl_ar_line.ledger_id;
            EXCEPTION
               WHEN NO_DATA_FOUND
               THEN
                  l_global_att12 := 'Faturamento';
               WHEN OTHERS
               THEN
                  l_global_att12 := NULL;
            END;

            --<1.3 Start>
            IF l_global_att12 IS NOT NULL
            THEN
               IF r_gl_ar_line.reference_8 LIKE 'CM%'
               THEN
                  l_upd_str :=
                     (   'Cancelamento '
                      || l_global_att12
                      || ' CR '
                      || LPAD (r_gl_ar_line.reference_4, 6, 0)
                      || ' - '
                      || r_gl_ar_line.customer_name
                      || ' ref NF '
                      || l_reference_5
                     );
               ELSIF r_gl_ar_line.reference_8 LIKE 'TRADE'
               THEN
                  IF r_gl_ar_line.reference_9 = 'TRADE_EDISC'
                  THEN
                     l_upd_str :=
                        (   'Desconto do Título - '
                         || ' NF '
                         || LPAD (r_gl_ar_line.reference_4, 7, 0)
                         || ' - '
                         || r_gl_ar_line.customer_name
                        );
                  ELSE
                     l_upd_str :=
                        (   'Baixa do Título - '
                         || ' NF '
                         || LPAD (r_gl_ar_line.reference_4, 7, 0)
                         || ' - '
                         || r_gl_ar_line.customer_name
                        );
                  END IF;
               ELSIF r_gl_ar_line.reference_8 LIKE 'ADJ'
               THEN
                  l_upd_str :=
                     (   'Juros Baixa do Título - '
                      || ' NF '
                      || LPAD (r_gl_ar_line.reference_4, 7, 0)
                      || ' - '
                      || r_gl_ar_line.customer_name
                     );
               ELSE
                  l_upd_str :=
                     (   l_global_att12
                      || ' NF '
                      || LPAD (r_gl_ar_line.reference_4, 6, 0)
                      || ' - '
                      || r_gl_ar_line.customer_name
                     );
               END IF;

               --<1.3 End>
               --UPDATE gl.gl_je_lines --code commented by RXNETHI-ARGANO, 05/MAY/2023
			   UPDATE apps.gl_je_lines --code added by RXNETHI-ARGANO, 05/MAY/2023
                  SET description = SUBSTRB (l_upd_str, 0, 240)
                WHERE ROWID = r_gl_ar_line.ROWID
                  AND je_header_id = r_gl_ar_line.je_header_id
                  AND je_line_num = r_gl_ar_line.je_line_num;
            END IF;

            COMMIT;
            fnd_file.put_line (fnd_file.output,
                                  l_upd_str
                               || '|'
                               || r_gl_ar_line.reference_4
                               || '|'
                               || r_gl_ar_line.period_name
                               || '|'
                               || (   r_gl_ar_line.segment1
                                   || '.'
                                   || r_gl_ar_line.segment2
                                   || '.'
                                   || r_gl_ar_line.segment3
                                   || '.'
                                   || r_gl_ar_line.segment4
                                   || '.'
                                   || r_gl_ar_line.segment5
                                   || '.'
                                   || r_gl_ar_line.segment6
                                  )
                               || '|'
                               || r_gl_ar_line.customer_name
                              );
         EXCEPTION
            WHEN OTHERS
            THEN
               fnd_file.put_line
                             (fnd_file.LOG,
                                 'Error in updating the GL Receivable line -'
                              || SQLERRM
                              || ' - '
                              || 'JE_HEADER_ID - '
                              || r_gl_ar_line.je_header_id
                              || 'JE_LINE_NUM - '
                              || r_gl_ar_line.je_line_num
                             );
               raise_application_error
                             (-20003,
                                 'Error in updating the GL Receivable line - '
                              || SQLERRM
                             );
         END;
      END LOOP;

      COMMIT;
   EXCEPTION
      WHEN OTHERS
      THEN
         fnd_file.put_line (fnd_file.LOG,
                            'Error out of main loop -' || SQLERRM
                           );
   END ttec_brz_ar_gl_history;
END cust_brz_gl;
/
show errors;
/