create or replace PACKAGE      TTEC_AUTOREC_AR_OUTBOUND_INT AUTHID CURRENT_USER AS
--
-- Program Name:  TTEC_AUTOREC_AR_OUTBOUND_INT
-- /* $Header: TTEC_AUTOREC_AR_OUTBOUND_INT.pks 1.0 2013/02/14  chchan ship $ */
--
-- /*== START ================================================================================================*\
--    Author: Christiane Chan
--      Date: 14-FEB-2013
--
-- Call From: Concurrent Program ->TeleTech AutoRec AR Outbound Interface
--      Desc: This program generates AR Data Feed mandated by Cheasapeak T-Recs requirements
--
--     Parameter Description:
--
--         p_ledger_id               :
--         p_period_name             :
--         p_posted_date             :
--
--       Oracle Standard Parameters:
--
--   Modification History:
--
--  Version    Date     Author   Description (Include Ticket--)
--  -------  --------  --------  ------------------------------------------------------------------------------
--      1.0  02/14/13   CChan     Initial Version TTSD R#2204084 - AutoRec Project
--      1.1  02/27/13   CChan     Comment out the  exclusion of zero balance at the header level, also, do not send the detail lines of
--                                balance that have zero amount
--      1.2  03/06/13   CChan     Enable Looping through Ledgers + Modify file naming convention + eliminate directory structure by Country Code+ replace GL Location with Ledger ID in the Account IS section
--     1.3   03/07/15   Amir Aslam   changes for Re hosting Project
--     1.0	12-May-2023 IXPRAVEEN(ARGANO)   		R12.2 Upgrade Remediation
-- \*== END =====================================
    -- Error Constants
	--START R12.2 Upgrade Remediation
    /*g_application_code   cust.ttec_error_handling.application_code%TYPE := 'AR';						-- Commented code by IXPRAVEEN-ARGANO,12-May-2023
    g_interface          cust.ttec_error_handling.INTERFACE%TYPE        := 'AutoRec AR Intf';           
    g_package            cust.ttec_error_handling.program_name%TYPE     := 'TTEC_AUTOREC_AR_OUTBOUND_INT';
    g_label1             cust.ttec_error_handling.label1%TYPE           := 'Err Location';
    g_label2             cust.ttec_error_handling.label1%TYPE           := 'Acct ID';
    g_warning_status     cust.ttec_error_handling.status%TYPE           := 'WARNING';
    g_error_status       cust.ttec_error_handling.status%TYPE           := 'ERROR';
    g_failure_status     cust.ttec_error_handling.status%TYPE           := 'FAILURE';*/
	g_application_code   apps.ttec_error_handling.application_code%TYPE := 'AR';						--  code Added by IXPRAVEEN-ARGANO,   12-May-2023
    g_interface          apps.ttec_error_handling.INTERFACE%TYPE        := 'AutoRec AR Intf';
    g_package            apps.ttec_error_handling.program_name%TYPE     := 'TTEC_AUTOREC_AR_OUTBOUND_INT';
    g_label1             apps.ttec_error_handling.label1%TYPE           := 'Err Location';
    g_label2             apps.ttec_error_handling.label1%TYPE           := 'Acct ID';
    g_warning_status     apps.ttec_error_handling.status%TYPE           := 'WARNING';
    g_error_status       apps.ttec_error_handling.status%TYPE           := 'ERROR';
    g_failure_status     apps.ttec_error_handling.status%TYPE           := 'FAILURE';
	--END R12.2.12 Upgrade remediation

    -- Process FAILURE variables
    g_fail_flag                   BOOLEAN := FALSE;

    -- Filehandle Variables
    v_file_path                    varchar2(400);
    v_filename                     varchar2(100);
    v_country                      varchar2(2);

    v_output_file                    UTL_FILE.FILE_TYPE;

    -- Declare variables
    g_ledger_id            number(5);
    g_application_id       number(10);
    g_period_name          VARCHAR2(10);
    g_latest_closed_period VARCHAR2(10);   /* 1.1 */
    g_org_id               number(10);
    g_COA                  number(10);
    g_currency_code        VARCHAR2(3);
    g_country_code         VARCHAR2(2);
    g_posted_date          DATE;
    g_import_acct          VARCHAR2(100);

  -- declare cursors
    cursor c_directory_path is  -- Change for version 1.3
    select ttec_library.get_directory('CUST_TOP')||'/data/EBS/FIN/AR/AutoRec/Outbound' file_path --1.2
    -- , decode(HOST_NAME,'den-erp046','','TEST_')||'AR_DETAIL_FEED_'||to_char(g_posted_date,'RRRRMMDD')||'_'||replace(short_name,' ','_')||'.DAT' file_name
    , decode(HOST_NAME,TTEC_LIBRARY.XX_TTEC_PROD_HOST_NAME,'','TEST_')||'AR_DETAIL_FEED_'||to_char(g_posted_date,'RRRRMMDD')||'_'||replace(short_name,' ','_')||'.DAT' file_name

    from v$INSTANCE,gl_ledgers
    where ledger_id = g_ledger_id;

    /* main query to obtain US employees data from HR tables */


    cursor c_header is
--    SELECT 'B'                              || '|' ||                    --"Record Type"
--       gcc.segment1 || ' ' || -- location
--       gcc.segment4 || ' ' || -- account
--       gb.currency_code                 || '|' ||                                                                             --"Import Account ID"
--       TO_CHAR(gp.end_date, 'YYYYMMDD') || '|' ||          --"Adjusted Balance Date"
--       sum(gb.period_net_dr -
--           gb.period_net_cr)            || '|' ||               --"Adjusted Balance"
--       DECODE(SIGN(gb.period_net_dr -
--                   gb.period_net_cr ), -1, 'C', 1, 'D', 0) --"Adjusted Balance Sign"
    SELECT 'H'    Record_Type,
       gl.ledger_id          ledger_id, -- 1.2
       flv.tag               Acct_FLAG, -- 1.2
     --gcc.segment1  location, --1.2
       gcc.segment4   account,
       gb.currency_code      currency,                                                                        --"Import Account ID"
       TO_CHAR(g_posted_date, 'YYYYMMDD') Adjusted_Balance_Date,
       SUM(nvl(gb.period_net_dr,0) + nvl(gb.BEGIN_BALANCE_DR,0)) - SUM(nvl(gb.period_net_cr,0) + nvl(gb.BEGIN_BALANCE_CR,0) )    Adjusted_Balance          --"Adjusted Balance"
--       DECODE(SIGN(gb.period_net_dr -
--                   gb.period_net_cr ), -1, 'C', 1, 'D', 0) Adjusted_Balance_sign
  FROM gl_code_combinations gcc,
       gl_balances           gb,
       gl_periods            gp,
       fnd_lookup_values    flv,
       gl_ledgers            gl
 WHERE gcc.code_combination_id = gb.code_combination_id
   AND gb.period_name          = gp.period_name
   AND substr(flv.lookup_code,1,4) = gcc.segment4 -- 1.2
   AND gl.ledger_id            = gb.ledger_id
   AND flv.description         = NVL('Accounts Receivables - Aging', flv.description)   -- ledger_name
   --AND flv.lookup_type         = 'XXTT_MEXICO_AUTO_ACCOUNT_RECON' --1.2
   AND flv.lookup_type         = 'TTEC_AUTO_RECON_ACCOUNTS'  --1.2
   AND flv.enabled_flag = 'Y'
   AND flv.attribute1 = g_ledger_id /* 1.2 */            -- Ledger
--   AND gcc.segment1              IN ('03105', '03122', '03123')    -- location
/* 1.2
   AND gcc.segment1              IN (   SELECT lookup_code
                                          FROM fnd_lookup_values flv
                                         WHERE flv.lookup_type = 'XXTT_AUTO_RECON_LL_MAP'
                                           AND flv.LANGUAGE = 'US'
                                           AND flv.enabled_flag = 'Y'
                                           AND tag = g_ledger_id)
*/
--   AND gcc.segment4                 BETWEEN '0000'
--                                        AND '3999'                  -- account
   AND gb.currency_code        = NVL(g_currency_code, gb.currency_code)                           -- Currency
   AND gp.period_name          = NVL(g_period_name, gp.period_name)                          -- Period_name
   AND flv.LANGUAGE            = 'US'
   AND gb.LEDGER_ID            = g_ledger_id
   AND gb.actual_flag          = 'A'
 GROUP BY 'H' ,
          flv.tag, --1.2
          gl.ledger_id ,
          --gcc.segment1 , 1.2
          gcc.segment4 ,
          gb.currency_code ,
          TO_CHAR(g_posted_date, 'YYYYMMDD')
--          DECODE(SIGN(gb.period_net_dr -
--                   gb.period_net_cr ), -1, 'C', 1, 'D', 0)
--    HAVING SUM(nvl(gb.period_net_dr,0) + nvl(gb.BEGIN_BALANCE_DR,0)) - SUM(nvl(gb.period_net_cr,0) + nvl(gb.BEGIN_BALANCE_CR,0) ) != 0 /* 1.1 */
 ORDER BY 'H' ,
          gl.ledger_id ,
          --gcc.segment1 , 1.2
          gcc.segment4 ,
          gb.currency_code ,
          TO_CHAR(g_posted_date, 'YYYYMMDD');
         -- DECODE(SIGN(gb.period_net_dr - gb.period_net_cr ), -1, 'C', 1, 'D', 0);


    --cursor c_detail(v_location varchar2, v_account varchar2) is --1.2
    cursor c_detail( v_account varchar2) is
SELECT 'D'                                      || '|' ||                   --"Record Type"
       gb.LEDGER_ID                             || ' ' ||  -- ledger   --1.2
       --gcc.segment1                             || ' ' ||  -- location   --1.2
       gcc.segment4                             || ' ' ||  -- account
       gb.currency_code                         || '|' ||            -- "Import Account ID"
       TO_CHAR(gjb.posted_date, 'YYYYMMDD')     || '|' ||                    -- "Post Date"
       TO_CHAR(gjl.effective_date, 'YYYYMMDD')  || '|' ||               -- "Effective Date"
       gjh.je_source                            || '|' ||              --"Transaction type"
       gjl.accounted_dr                         || '|' ||                  --"Debit Amount"
       gjl.accounted_cr                         || '|' ||                 --"Credit Amount"
       gcc.segment2                             || '|' ||                   --"Reference 1"
       gcc.segment3                             || '|' ||                   --"Reference 2"
       gcc.segment5                             || '|' ||                   --"Reference 3"
       hou.name                                 || '|' ||                   --"Reference 5"
       gjl.description                          || '|' ||                   --"Details"
       hp.party_number                          || '|' ||                   ---"Reference 6"
       hp.party_name                            || '|' ||                   --"Reference 7"
       rcta.TRX_NUMBER                          || '|' ||                   --"Reference 8"
       gjl.entered_dr                           || '|' || --"Entered Currency Amount Debit"
       gjl.entered_cr                                    --"Entered Currency Amount Credit"
       detail_line
  FROM xla_ae_headers               xah,
       xla_ae_lines                 xal,
       xla_events                   xae,
       --xla.xla_transaction_entities xte,				-- Commented code by IXPRAVEEN-ARGANO,12-May-2023
       apps.xla_transaction_entities xte,               --  code Added by IXPRAVEEN-ARGANO,   12-May-2023
       gl_import_references         gir,
       gl_je_batches                gjb,
       gl_je_headers                gjh,
       gl_je_lines                  gjl,
       gl_code_combinations         gcc,
       --ar.hz_cust_accounts          hca,				-- Commented code by IXPRAVEEN-ARGANO,12-May-2023
       apps.hz_cust_accounts          hca,              --  code Added by IXPRAVEEN-ARGANO,   12-May-2023
       hz_parties                    hp,
       hr_operating_units           hou,
       ra_customer_trx_all         rcta,
       gl_balances                   gb,
       fnd_lookup_values            flv,
       gl_ledgers                    gl
 WHERE 1 = 1
   AND gb.code_combination_id = gjl.code_combination_id
   AND gb.code_combination_id = gcc.code_combination_id
   AND gjl.je_header_id       = gjh.je_header_id
   AND gjh.je_batch_id        = gjb.je_batch_id
   AND gcc.segment4           = flv.lookup_code
   AND gl.ledger_id           = gb.ledger_id
   AND gjl.ledger_id          = gb.ledger_id
   AND gb.period_name         = gjl.period_name
   AND flv.description        = NVL('Accounts Receivables - Aging', flv.description)   -- ledger_name
   --AND flv.lookup_type         = 'XXTT_MEXICO_AUTO_ACCOUNT_RECON' --1.2
   AND flv.lookup_type         = 'TTEC_AUTO_RECON_ACCOUNTS'  --1.2
   AND flv.enabled_flag = 'Y'
   --AND gcc.segment1            = v_location -- 1.2
   AND gcc.segment4            = v_account
       AND (   NVL(gjl.accounted_dr, 0) != 0
            OR NVL(gjl.accounted_cr, 0)  != 0)
   AND gb.currency_code       = NVL(g_currency_code, gb.currency_code)                           -- Currency
   --AND gb.period_name         = NVL(g_period_name, gb.period_name)                          -- Period_name
   AND gb.period_name in (g_latest_closed_period , g_period_name) /* 1.1 */
   AND flv.LANGUAGE           = 'US'
   AND gb.LEDGER_ID           = g_ledger_id
   and TRUNC(gjb.posted_date) = g_posted_date
   AND gb.actual_flag         = 'A'
--
   AND gir.je_header_id      = gjh.je_header_id
   AND gir.je_batch_id       = gjb.je_batch_id
   AND gir.je_line_num       = gjl.je_line_num
--
   AND xah.entity_id           = gir.reference_5
   AND xah.event_id            = gir.reference_6
   AND xah.ae_header_id        = gir.reference_7
--
   AND xah.event_id            = xae.event_id
   AND xah.application_id      = xae.application_id
--
   AND xae.application_id      = xte.application_id
   AND xae.entity_id           = xte.entity_id
--
   AND xah.application_id      = xal.application_id
   AND xah.ae_header_id        = xal.ae_header_id
--
   AND xal.gl_sl_link_table    = gir.gl_sl_link_table
   AND xal.gl_sl_link_id       = gir.gl_sl_link_id
--
   AND rcta.customer_trx_id    = xte.source_id_int_1
--
   AND rcta.bill_to_customer_id = hca.cust_account_id
--
   AND hp.party_id              = hca.party_id
   AND rcta.org_id              = hou.organization_id
order by 1;

/*
UNION ALL
SELECT 'D'                                     || '|' ||                   --"Record Type"
       gcc.segment1 || ' ' || -- location
       gcc.segment4 || ' ' || -- account
       gb.currency_code                        || '|' ||             --"Import Account ID"
       TO_CHAR(gjb.posted_date, 'YYYYMMDD')    || '|' ||                     --"Post Date"
       TO_CHAR(gjl.effective_date, 'YYYYMMDD') || '|' ||                --"Effective Date"
       gjh.je_source                           || '|' ||              --"Transaction type"
       gjl.accounted_dr                        || '|' ||                  --"Debit Amount"
       gjl.accounted_cr                        || '|' ||                 --"Credit Amount"
       gcc.segment2                            || '|' ||                   --"Reference 1"
       gcc.segment3                            || '|' ||                   --"Reference 2"
       gcc.segment5                            || '|' ||                   --"Reference 3"
       null                                    || '|' ||                   --"Reference 5"
       null                                    || '|' ||                   --"Reference 6"
       null                                    || '|' ||                   --"Reference 7"
       null                                    || '|' ||                   --"Reference 8"
       gjl.entered_dr                          || '|' || --"Entered Currency Amount Debit"
       gjl.entered_cr                                   --"Entered Currency Amount Credit"
  FROM gl_je_batches                gjb,
       gl_je_headers                gjh,
       gl_je_lines                  gjl,
       gl_code_combinations         gcc,
       gl_balances                   gb,
       fnd_lookup_values            flv,
       gl_ledgers                    gl
 WHERE 1 = 1
   AND gb.code_combination_id = gjl.code_combination_id
   AND gb.code_combination_id = gcc.code_combination_id
   AND gjl.je_header_id       = gjh.je_header_id
   AND gjh.je_batch_id        = gjb.je_batch_id
   AND gcc.segment4           = flv.lookup_code
   AND gl.ledger_id           = gb.ledger_id
   and gjl.ledger_id          = gb.ledger_id
   AND gb.period_name         = gjl.period_name
--   AND flv.description        = NVL('Accounts Receivables - Aging', flv.description)   -- ledger_name
   AND flv.lookup_type         = 'XXTT_MEXICO_AUTO_ACCOUNT_RECON'
   AND gcc.segment1            = v_location
   AND gcc.segment4            = v_account                 -- account
   AND gb.currency_code       = NVL('MXN', gb.currency_code)                           -- Currency
   AND gb.period_name         = NVL('OCT-12', gb.period_name)                          -- Period_name
   AND flv.LANGUAGE           = 'US'
   AND gb.LEDGER_ID           = 122
   AND gb.actual_flag         = 'A'
--
   AND gjh.je_header_id      NOT IN (select a.je_header_id
                                       from gl_import_references a
                                      where a.je_header_id = gjh.je_header_id
                                        and a.je_line_num = gjl.je_line_num)
order by 1;
*/
PROCEDURE process_detail(
          errcode                     OUT VARCHAR2,
          errbuff                     OUT VARCHAR2,
          p_ledger_id                  IN NUMBER,
          p_period_name                IN VARCHAR2,
          p_posted_date                IN VARCHAR2
);
PROCEDURE detail_main(
          errcode                     OUT VARCHAR2,
          errbuff                     OUT VARCHAR2,
          p_ledger_id                  IN NUMBER,
          p_period_name                IN VARCHAR2,
          p_posted_date                IN VARCHAR2
);
END TTEC_AUTOREC_AR_OUTBOUND_INT;
/
show errors;
/