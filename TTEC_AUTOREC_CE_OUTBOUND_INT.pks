create or replace PACKAGE      ttec_autorec_ce_outbound_int AUTHID CURRENT_USER
AS
      /****************************************************************************
       *****************************************************************************
       *                                                                           *
       * PROGRAM NAME        : APPS.TTEC_AUTOREC_CM_OUTBOUND_INT                *
       *                                                                           *
       * PURPOSE             :                                                     *
       *                                                                           *
       *                                                                           *
       * CALLS               :Submitted by Concurrent Program                      *
       *                                                                           *
       *                                                                           *
       * UPDATE HISTORY      :                                                     *
       *                                                                           *
       * DATE             NAME               DESCRIPTION                           *
       * -------     ------------------ ------------------------------------------ *
       * 27-SEP-2013          Ravi Pasula   Initial Release                           *
   --   Modification History:
   --
   --  Version    Date     Author   Description (Include Ticket--)
   --  -------  --------  --------  ------------------------------------------------------------------------------
   --      1.0  09/27/13   Ravi Pasula   Initial Release     - AutoRec Project
   --      1.1  02/19/14   CChan
   --      1.3  08/03/15   Amir Aslam
   --1.0	18-july-2023 IXPRAVEEN(ARGANO)   		R12.2 Upgrade Remediation

   -- \*== END =====================================
       ****************************************************************************/

   -- Process FAILURE variables
   g_fail_flag           BOOLEAN                                     := FALSE;
   -- Error Constants
   --START R12.2 Upgrade Remediation
   /*g_application_code    cust.ttec_error_handling.application_code%TYPE					-- Commented code by IXPRAVEEN-ARGANO,18-july-2023
                                                                      := 'CE';              
   g_interface           cust.ttec_error_handling.INTERFACE%TYPE
                                                         := 'AutoRec CE Intf';
   g_package             cust.ttec_error_handling.program_name%TYPE
                                            := 'TTEC_AUTOREC_CE_OUTBOUND_INT';
   g_label1              cust.ttec_error_handling.label1%TYPE
                                                            := 'Err Location';
   g_label2              cust.ttec_error_handling.label1%TYPE    := 'Acct ID';
   g_warning_status      cust.ttec_error_handling.status%TYPE    := 'WARNING';
   g_error_status        cust.ttec_error_handling.status%TYPE      := 'ERROR';
   g_failure_status      cust.ttec_error_handling.status%TYPE    := 'FAILURE';*/
   g_application_code    APPS.ttec_error_handling.application_code%TYPE						--  code Added by IXPRAVEEN-ARGANO,   18-july-2023
                                                                      := 'CE';
   g_interface           apps.ttec_error_handling.INTERFACE%TYPE
                                                         := 'AutoRec CE Intf';
   g_package             apps.ttec_error_handling.program_name%TYPE
                                            := 'TTEC_AUTOREC_CE_OUTBOUND_INT';
   g_label1              APPS.ttec_error_handling.label1%TYPE
                                                            := 'Err Location';
   g_label2              APPS.ttec_error_handling.label1%TYPE    := 'Acct ID';
   g_warning_status      apps.ttec_error_handling.status%TYPE    := 'WARNING';
   g_error_status        apps.ttec_error_handling.status%TYPE      := 'ERROR';
   g_failure_status      apps.ttec_error_handling.status%TYPE    := 'FAILURE';
   --END R12.2.12 Upgrade remediation
   g_autorec_acct        VARCHAR2 (100);
   -- Filehandle Variables
   v_file_path           VARCHAR2 (400)                          DEFAULT NULL;
   v_file_name           VARCHAR2 (200)                          DEFAULT NULL;
   v_file_path_detail    VARCHAR2 (400)                          DEFAULT NULL;
   v_file_name_detail    VARCHAR2 (200)                          DEFAULT NULL;
   v_file_detail         VARCHAR2 (200);
   v_file_type           UTL_FILE.file_type;
   v_file_detail_type    UTL_FILE.file_type;
   v_rec                 VARCHAR2 (3000)                         DEFAULT NULL;
   v_rec_output          VARCHAR2 (3000)                         DEFAULT NULL;
   v_rec_output_detail   VARCHAR2 (3000)                         DEFAULT NULL;
   v_ledger              VARCHAR2 (50)                           DEFAULT NULL;
   v_period_end_date     DATE                                    DEFAULT NULL;
   v_statement_date     DATE                                    DEFAULT NULL;
                                                                    /* 1.1 */

   -- declare cursors
   CURSOR c_ledger
   IS
      SELECT DISTINCT flv.attribute1 ledger_id
                 FROM fnd_lookup_values flv
                WHERE flv.lookup_type = 'TTEC_AUTO_RECON_ACCOUNTS'
                  AND flv.LANGUAGE = 'US'
                  AND flv.enabled_flag = 'Y'
                  AND flv.attribute4 = 'Y'
--    AND ((g_by_location_indicator = 'Y' AND  flv.attribute2 IS NOT NULL)
--     OR  (g_by_location_indicator = 'N' AND  flv.attribute2 IS NULL))
   ;

   CURSOR c_directory_path (p_period_name IN VARCHAR2, p_ledger IN NUMBER)
   IS
      SELECT    ttec_library.get_directory ('CUST_TOP')
             || '/data/EBS/FIN/CE/AutoRec/Outbound' file_path            --1.2
              -- , DECODE (host_name, 'den-erp046', '', 'TEST_')                        -- change for ver 1.3
               , DECODE (host_name,TTEC_LIBRARY.XX_TTEC_PROD_HOST_NAME, '', 'TEST_')     -- change for ver 1.3
             || 'CE_BALANCE_FEED_'
             || p_period_name
             || '_'
             || REPLACE (short_name, ' ', '_')
             || '.DAT' file_name
        FROM v$instance, gl_ledgers
       WHERE ledger_id = p_ledger;           --upper(name) = upper(p_ledger) ;

   CURSOR c_directory_path2 (p_period_name IN VARCHAR2, p_ledger IN NUMBER)
   IS
      SELECT    ttec_library.get_directory ('CUST_TOP')
             || '/data/EBS/FIN/CE/AutoRec/Outbound' file_path            --1.2
             -- ,  DECODE (host_name, 'den-erp046', '', 'TEST_')                        -- change for ver 1.3
            ,  DECODE (host_name,TTEC_LIBRARY.XX_TTEC_PROD_HOST_NAME, '', 'TEST_')      -- change for ver 1.3
             || 'CE_OPEN_ITEMS_FEED_'
             || p_period_name
             || '_'
             || REPLACE (short_name, ' ', '_')
             || '.DAT' file_name
        FROM v$instance, gl_ledgers
       WHERE ledger_id = p_ledger;           --upper(name) = upper(p_ledger) ;

   CURSOR c_data (p_period_name IN VARCHAR2, p_ledger IN NUMBER)
   IS
      SELECT   SUM (csh.control_end_balance) balance, cba.currency_code,
               csh.gl_date period_end_date,
               TRIM (cba.bank_account_num) bank_account_num,
               cba.bank_account_name, gcc.segment4, gcc.segment1 loc,
               gl.ledger_id, gcc.segment4 cash_account, gl.short_name
          FROM gl_code_combinations gcc,
               ce_bank_accounts cba,
               org_organization_definitions ood,
               ce_statement_headers csh,
               gl_ledgers gl,
               apps.fnd_lookup_values flv
         WHERE cba.asset_code_combination_id = gcc.code_combination_id
           --AND gcc.segment4 = '1012'
           --AND gcc.segment1 = '01060'
           AND gcc.end_date_active IS NULL
           AND cba.end_date IS NULL
           AND ood.organization_id = cba.account_owner_org_id
           AND ood.organization_id <> 0
           AND ood.set_of_books_id = gl.ledger_id
           --AND UPPER (gl.NAME) = UPPER  (p_ledger)--('TELETECH PH SET OF BOOKS')--p_ledger
           AND gl.ledger_id = p_ledger
           AND cba.bank_account_id = csh.bank_account_id
           AND flv.lookup_type = 'TTEC_AUTO_RECON_ACCOUNTS'
           AND (SUBSTR (flv.lookup_code, 1, 4)) = gcc.segment4
           -- AND  SUBSTR (flv.lookup_code,-5) = gcc.segment1
           AND gcc.segment1 = flv.attribute2
           AND flv.LANGUAGE = 'US'
           AND flv.enabled_flag = 'Y'
           AND flv.attribute4 = 'Y'
           AND csh.gl_date =
                  (SELECT MAX (gl_date)
                     FROM ce_statement_headers csh, gl_periods gp
                    WHERE gl_date BETWEEN gp.start_date AND gp.end_date
                      AND gp.period_name = p_period_name            --'JUL-13'
                      AND control_end_balance IS NOT NULL
                      AND csh.bank_account_id = cba.bank_account_id)
      GROUP BY cba.currency_code,
               csh.gl_date,
               cba.bank_account_num,
               cba.bank_account_name,
               gcc.segment4,
               gcc.segment1,
               gl.ledger_id,
               gl.short_name;

   CURSOR c_ar_data (p_ledger IN VARCHAR)
   IS
      SELECT   cra.receipt_number, cra.receipt_date,
               gcc.segment4 cash_account, gcc.segment1 loc,
               NVL(crh.acctd_amount,crh.amount) amount,
               cba.bank_account_num, cra.currency_code, ood.organization_name,
               gl.ledger_id, NVL (hp.party_name, 'N/A') party_name,
               arm.NAME receipt_name, gl.currency_code functional_currency,
               gl.short_name
          -- crh.status,
          --cra.amount cash_amount,
          --crh.cash_receipt_id,
          -- cra.remit_bank_acct_use_id,
           -- crh.cash_receipt_history_id,
      FROM     apps.ar_cash_receipt_history_all crh,
               apps.ar_cash_receipts_all cra,
               apps.ce_bank_acct_uses_all cbu,
               apps.ce_bank_accounts cba,
               apps.org_organization_definitions ood,
               apps.gl_ledgers gl,
               apps.hz_parties hp,
               apps.gl_code_combinations gcc,
               apps.ar_receipt_methods arm,
               apps.fnd_lookup_values flv
         --apps.ce_statement_reconcils_all CRE
      WHERE    crh.cash_receipt_id = cra.cash_receipt_id
           -- AND cra.receipt_number = '6663099'
           AND cra.set_of_books_id = ood.set_of_books_id
           AND ood.set_of_books_id = gl.ledger_id
           --AND UPPER (gl.NAME) = UPPER (p_ledger) --p_ledger 'TELETECH PH SET OF BOOKS'
           AND gl.ledger_id = p_ledger
           AND crh.current_record_flag = 'Y'
           AND cra.remit_bank_acct_use_id = cbu.bank_acct_use_id
           AND cbu.bank_account_id = cba.bank_account_id
           --AND cba.bank_account_num = p_bank_acct              --'86661-10637'
          -- AND crh.status NOT IN ('CLEARED', 'REVERSED') /* 1.1 */
           AND cra.TYPE <> 'MISC'                                     /* CC */
           AND ood.set_of_books_id = cra.set_of_books_id
           AND ood.organization_id <> 0
           AND ood.organization_id = cba.account_owner_org_id
           AND hp.party_id(+) = cra.pay_from_customer
           AND cba.asset_code_combination_id = gcc.code_combination_id
           AND gcc.segment4 =
                             (SUBSTR (flv.lookup_code, 1, 4)
                             )                                --- cash account
           AND gcc.segment1 = flv.attribute2                     ---- location
           AND cra.receipt_date >
                   '01-APR-2012' -- to restric historic data before R12 upgrade
           AND flv.lookup_type = 'TTEC_AUTO_RECON_ACCOUNTS'
           AND flv.LANGUAGE = 'US'
           AND flv.enabled_flag = 'Y'
           AND flv.attribute1 = gl.ledger_id
           AND arm.receipt_method_id = cra.receipt_method_id
           AND flv.attribute4 = 'Y'                     -- this flag is for CM
           AND cra.CREATION_DATE <= v_period_end_date /* 1.1 */
           AND (   /* 1.1  begin*/
                   (    crh.status NOT IN ('CLEARED', 'REVERSED')
                    AND crh.cash_receipt_history_id NOT IN (
                                              SELECT reference_id
                                                FROM apps.ce_statement_reconcils_all csr
                                               WHERE org_id = ood.organization_id
                                               and TRUNC(csr.CREATION_DATE) <= v_period_end_date ))
              ) /* 1.1  end*/
      ORDER BY cba.bank_account_num;

   --where  csr.reference_type IN ('RECEIPT', 'DM REVERSAL')
   CURSOR c_ap_data (p_ledger IN VARCHAR)
   IS
      SELECT aca.check_number,
            -- aca.amount check_amount,
             nvl(aca.base_amount,aca.amount) check_amount,
             cba.bank_account_num,
             aca.currency_code, gl.ledger_id, gcc.segment4 cash_account,
             gcc.segment1 loc,
                              --aca.check_id,
                              aca.bank_account_name, aca.check_date,
             aca.status_lookup_code, ood.organization_name,
             gl.currency_code functional_currency, aca.vendor_name
        FROM apps.ap_checks_all aca,
             ce_bank_accounts cba,
             apps.org_organization_definitions ood,
             apps.gl_ledgers gl,
             apps.gl_code_combinations gcc,
             apps.fnd_lookup_values flv
       WHERE UPPER (aca.bank_account_name) = UPPER (cba.bank_account_name)
         --AND cba.bank_account_num = p_bank_acct                --'86661-10637'
         AND ood.organization_id = aca.org_id
         AND cba.account_owner_org_id = ood.organization_id
         AND ood.set_of_books_id = gl.ledger_id
         AND aca.check_date > '01-APR-2012'  -- to restric historic data before R12 upgrade
         AND gl.ledger_id = p_ledger
         AND ood.organization_id <> 0
         AND ood.organization_id = cba.account_owner_org_id
         AND cba.asset_code_combination_id = gcc.code_combination_id
         AND gcc.segment4 = (SUBSTR (flv.lookup_code, 1, 4))  --- cash account
         AND flv.attribute2  = gcc.segment1 -- location
         AND flv.lookup_type = 'TTEC_AUTO_RECON_ACCOUNTS'
         AND flv.LANGUAGE = 'US'
         AND flv.enabled_flag = 'Y'
         AND flv.attribute1 = gl.ledger_id
         AND flv.attribute4 = 'Y'    -- this flag is for CM
         AND (     TRUNC(aca.check_date) <= v_period_end_date
               and (TRUNC(aca.cleared_date)  <= v_statement_date
                    OR aca.cleared_date IS NULL))
         AND aca.status_lookup_code NOT IN ('RECONCILED', 'RECONCILED UNACCOUNTED','CLEARED BUT UNACCOUNTED','VOIDED')
      UNION
         SELECT aca.check_number,
            -- aca.amount check_amount,
             nvl(aca.base_amount,aca.amount) check_amount,
             cba.bank_account_num,
             aca.currency_code, gl.ledger_id, gcc.segment4 cash_account,
             gcc.segment1 loc,
                              --aca.check_id,
                              aca.bank_account_name, aca.check_date,
             aca.status_lookup_code, ood.organization_name,
             gl.currency_code functional_currency, aca.vendor_name
        FROM apps.ap_checks_all aca,
             ce_bank_accounts cba,
             apps.org_organization_definitions ood,
             apps.gl_ledgers gl,
             apps.gl_code_combinations gcc,
             apps.fnd_lookup_values flv
       WHERE UPPER (aca.bank_account_name) = UPPER (cba.bank_account_name)
         --AND cba.bank_account_num = p_bank_acct                --'86661-10637'
         AND ood.organization_id = aca.org_id
         AND cba.account_owner_org_id = ood.organization_id
         AND ood.set_of_books_id = gl.ledger_id
         AND aca.check_date > '01-APR-2012'  -- to restric historic data before R12 upgrade
         AND gl.ledger_id = p_ledger
         AND ood.organization_id <> 0
         AND ood.organization_id = cba.account_owner_org_id
         AND cba.asset_code_combination_id = gcc.code_combination_id
         AND gcc.segment4 = (SUBSTR (flv.lookup_code, 1, 4))  --- cash account
         AND flv.attribute2  = gcc.segment1 -- location
         AND flv.lookup_type = 'TTEC_AUTO_RECON_ACCOUNTS'
         AND flv.LANGUAGE = 'US'
         AND flv.enabled_flag = 'Y'
         AND flv.attribute1 = gl.ledger_id
         AND flv.attribute4 = 'Y'    -- this flag is for CM
         AND TRUNC(aca.check_date)   <= v_period_end_date
         AND TRUNC(aca.cleared_date)  > v_statement_date;

   PROCEDURE get_bank_end_balance_details (
      errbuff         OUT      VARCHAR2,
      retcode         OUT      VARCHAR2,
      p_period_name   IN       VARCHAR2,
      p_ledger        IN       NUMBER
   );

   PROCEDURE get_ar_open_items (
      errbuff         OUT      VARCHAR2,
      retcode         OUT      VARCHAR2,
      p_period_name   IN       VARCHAR2,
      p_ledger        IN       NUMBER
   );

   PROCEDURE get_ap_open_items (
      errbuff         OUT      VARCHAR2,
      retcode         OUT      VARCHAR2,
      p_period_name   IN       VARCHAR2,
      p_ledger        IN       NUMBER
   );

   PROCEDURE main_data (
      errbuff         OUT      VARCHAR2,
      retcode         OUT      VARCHAR2,
      p_period_name   IN       VARCHAR2,
      p_ledger_id     IN       NUMBER,
      p_process_date  IN       VARCHAR2
   );
END ttec_autorec_ce_outbound_int;
/
show errors;
/