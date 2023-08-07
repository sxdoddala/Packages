create or replace PACKAGE      TTEC_AUTOREC_GL_OUTBOUND_INT AUTHID CURRENT_USER AS
--
-- Program Name:  TTEC_AUTOREC_GL_OUTBOUND_INT
-- /* $Header: TTEC_AUTOREC_GL_OUTBOUND_INT.pks 1.0 2013/02/14  chchan ship $ */
--
-- /*== START ================================================================================================*\
--    Author: Christiane Chan
--      Date: 14-FEB-2013
--
-- Call From: Concurrent Program ->TeleTech AutoRec GL Outbound Interface
--      Desc: This program generates GL Data Feed mandated by Cheasapeak T-Recs requirements
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
--      1.3  04/27/13   CChan     Adding additional columns + Pick up Detail Account only on GL Detail Extract + Add condition to re-enforced the Actual + Posted flags
--      1.4  08/01/13   CChan     TeleTech US Set of Books - add the ability to reconcile by GL location
--      1.6  08/29/13   CChan     Adding Logic to Ledger Cursor, so that All Ledger that has location setup can run individualy from Ledger without Location.
--                                So, we can submit submit 2 request Sets individually without providing the Ledger at the parameter level and will pick up the ledger automatically once the accounts are added
--      2.0  09/30/13   CChan     TTSD I#2758506 - AutoRec GL Balance include account with no activities with zero balance
--      2.1  02/14/14   CChan     Fix for By Location should only show account with location + remove header column being repeated
--      3.0  08/03/15   AmirA     changes for Re hosting Project

-- \*== END =====================================
    -- Error Constants
	--START R12.2 Upgrade Remediation
    /*g_application_code   cust.ttec_error_handling.application_code%TYPE := 'GL';						 -- Commented code by IXPRAVEEN-ARGANO,17-May-2023	
    g_interface          cust.ttec_error_handling.INTERFACE%TYPE        := 'AutoRec GL Intf';
    g_package            cust.ttec_error_handling.program_name%TYPE     := 'TTEC_AUTOREC_GL_OUTBOUND_INT';
    g_label1             cust.ttec_error_handling.label1%TYPE           := 'Err Location';
    g_label2             cust.ttec_error_handling.label1%TYPE           := 'Acct ID';
    g_warning_status     cust.ttec_error_handling.status%TYPE           := 'WARNING';
    g_error_status       cust.ttec_error_handling.status%TYPE           := 'ERROR';
    g_failure_status     cust.ttec_error_handling.status%TYPE           := 'FAILURE';*/
	g_application_code   apps.ttec_error_handling.application_code%TYPE := 'GL';						--  code Added by IXPRAVEEN-ARGANO,   17-May-2023
    g_interface          apps.ttec_error_handling.INTERFACE%TYPE        := 'AutoRec GL Intf';
    g_package            apps.ttec_error_handling.program_name%TYPE     := 'TTEC_AUTOREC_GL_OUTBOUND_INT';
    g_label1             apps.ttec_error_handling.label1%TYPE           := 'Err Location';
    g_label2             apps.ttec_error_handling.label1%TYPE           := 'Acct ID';
    g_warning_status     apps.ttec_error_handling.status%TYPE           := 'WARNING';
    g_error_status       apps.ttec_error_handling.status%TYPE           := 'ERROR';
    g_failure_status     apps.ttec_error_handling.status%TYPE           := 'FAILURE';
    g_by_location_indicator  varchar2(1);
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
    g_print_balance_header_flag     varchar2(1); /* 2.1 */

  -- declare cursors
    cursor c_ledger is
    SELECT distinct attribute1 ledger_id
    FROM fnd_lookup_values flv
    WHERE flv.lookup_type = 'TTEC_AUTO_RECON_ACCOUNTS'
    AND flv.LANGUAGE = 'US'
    AND flv.enabled_flag = 'Y'
    AND (    (g_by_location_indicator = 'Y' AND  flv.attribute2 IS NOT NULL)  /* 2.1 */
         OR  (g_by_location_indicator = 'N' AND  flv.attribute2 IS NULL) /* 2.1 */
     );

    cursor c_directory_path is
    --select ttec_library.get_directory('CUST_TOP')||'/data/EBS/FIN/GL/AutoRec/Outbound/'||g_country_code file_path --1.2
    select ttec_library.get_directory('CUST_TOP')||'/data/EBS/FIN/GL/AutoRec/Outbound' file_path --1.2
    -- , decode(HOST_NAME,'den-erp046','','TEST_')||'GL_DETAIL_FEED_'||to_char(g_posted_date,'RRRRMMDD')||'_'||replace(short_name,' ','_')||'.DAT' file_name                     -- -- Chnages for Version 3.0
    , decode(HOST_NAME,ttec_library.XX_TTEC_PROD_HOST_NAME,'','TEST_')||'GL_DETAIL_FEED_'||to_char(g_posted_date,'RRRRMMDD')||'_'||replace(short_name,' ','_')||'.DAT' file_name   -- Chnages for Version 3.0
    from v$INSTANCE,gl_ledgers
    where ledger_id = g_ledger_id;

    cursor c_directory_path2 is
    --select ttec_library.get_directory('CUST_TOP')||'/data/EBS/FIN/GL/AutoRec/Outbound/'||g_country_code file_path -- 1.2
    select ttec_library.get_directory('CUST_TOP')||'/data/EBS/FIN/GL/AutoRec/Outbound' file_path
    -- , decode(HOST_NAME,'den-erp046','','TEST_')||'GL_BALANCE_FEED_'||g_period_name||'_'
     , decode(HOST_NAME,ttec_library.XX_TTEC_PROD_HOST_NAME,'','TEST_')||'GL_BALANCE_FEED_'||g_period_name||'_'
        ||replace(short_name,' ','_')
        ||decode(g_by_location_indicator,'Y','_ByLoc','') /* 2.1 */
        ||'.DAT' file_name
    from v$INSTANCE,gl_ledgers
    where ledger_id = g_ledger_id;

    /* main query to obtain US employees data from HR tables */


    cursor c_header is
    SELECT 'H'                  Record_Type,
           gl.ledger_id          ledger_id, -- 1.2
           flv.tag               Acct_FLAG, -- 1.2
           decode(g_by_location_indicator,'Y',gcc.segment1,'') location, -- 1.2  1.4
           gcc.segment4          account,
           gb.currency_code       currency,
           TO_CHAR(g_posted_date, 'YYYYMMDD')  closing_Date,
           SUM(nvl(gb.period_net_dr,0) + nvl(gb.BEGIN_BALANCE_DR,0)) - SUM(nvl(gb.period_net_cr,0) + nvl(gb.BEGIN_BALANCE_CR,0) )  Closing_Balance
      FROM gl_code_combinations gcc,
           gl_balances           gb,
           gl_periods            gp,
           fnd_lookup_values    flv,
           gl_ledgers            gl
     WHERE gcc.code_combination_id = gb.code_combination_id
       AND gb.period_name          = gp.period_name
       AND gl.ledger_id            = gb.ledger_id
--   AND gcc.segment1              IN ('03105', '03122', '03123')    -- location
/* 1.2
       AND gcc.segment1              IN (   SELECT lookup_code
                                              FROM fnd_lookup_values flv
                                             WHERE flv.lookup_type = 'XXTT_AUTO_RECON_LL_MAP'
                                               AND flv.LANGUAGE = 'US'
                                               AND flv.enabled_flag = 'Y'
                                               AND tag = g_ledger_id)
*/
--       AND gcc.segment4              BETWEEN '0000'
--                                         AND '3999'                  -- account
       AND gcc.segment1  = decode(g_by_location_indicator,'Y',flv.attribute2,gcc.segment1) -- V. 1.4
       AND gcc.segment4  =SUBSTR(flv.lookup_code,1,4) -- 1.2
       AND flv.lookup_type = 'TTEC_AUTO_RECON_ACCOUNTS'
       AND flv.LANGUAGE = 'US'
       AND flv.enabled_flag = 'Y'
       AND flv.attribute1 = g_ledger_id /* 1.2 */            -- Ledger
       AND gb.currency_code        = NVL(g_currency_code, gb.currency_code)                           -- Currency
       AND gp.period_name          = NVL(g_period_name, gp.period_name)
       AND gb.LEDGER_ID            = g_ledger_id
       AND gb.actual_flag          = 'A'
       and flv.tag                 = 'D' /* 1.3 */  --Should only pick up  Detail account in the GL Detail Extract. Consulted Tim on 4/30 */
     GROUP BY 'H' ,
           gl.ledger_id, -- 1.2
           flv.tag, -- 1.2
           decode(g_by_location_indicator,'Y',gcc.segment1,''), -- 1.2 1.4
           gcc.segment4 ,
           gb.currency_code ,
           TO_CHAR(g_posted_date, 'YYYYMMDD')
    --HAVING SUM(nvl(gb.period_net_dr,0) + nvl(gb.BEGIN_BALANCE_DR,0)) - SUM(nvl(gb.period_net_cr,0) + nvl(gb.BEGIN_BALANCE_CR,0) ) != 0 /* 1.1 */
--     ORDER BY 'H' || '|' ||
--              gl.ledger_id || ' ' || -- 1.2
--           --gcc.segment1 || ' ' ||
--              gcc.segment4 || ' ' ||
--              gb.currency_code || '|' ||
--              TO_CHAR(g_posted_date, 'YYYYMMDD') ||  '|' ;
     ORDER BY 'H',
              gl.ledger_id ,-- 1.2
              decode(g_by_location_indicator,'Y',gcc.segment1,''), -- 1.2 1.4
              gcc.segment4,
              gb.currency_code,
              TO_CHAR(g_posted_date, 'YYYYMMDD')   ;

    cursor c_detail_count( v_location varchar2,v_account varchar2) is
    SELECT count(*)  detail_count
      FROM gl_balances           gb,
           gl_je_lines          gjl,
           gl_code_combinations gcc,
           gl_je_headers        gjh,
           gl_je_batches        gjb,
           gl_ledgers            gl
     WHERE gb.code_combination_id     = gjl.code_combination_id
       AND gb.code_combination_id     = gcc.code_combination_id
       AND gjl.je_header_id           = gjh.je_header_id
       AND gjh.je_batch_id            = gjb.je_batch_id
       AND gl.ledger_id               = gb.ledger_id
       AND gjl.ledger_id              = gb.ledger_id
       AND gjl.period_name            = gb.period_name
       AND gcc.segment1               = decode(g_by_location_indicator,'Y',v_location,gcc.segment1) -- V. 1.4
       AND gcc.segment4               = v_account
       and TRUNC(gjb.posted_date)     = g_posted_date
       AND (   NVL(gjl.accounted_dr, 0) != 0
            OR NVL(gjl.accounted_cr, 0)  != 0)
       AND gb.currency_code           = NVL(g_currency_code, gb.currency_code)    -- Currency
--       AND gb.period_name             = NVL(g_period_name, gb.period_name)   -- Period_name /* 1.1 */
       AND gb.period_name in (g_latest_closed_period , g_period_name) /* 1.1 */
       AND gb.ledger_id               = g_ledger_id
       AND gb.actual_flag             = 'A'
       and gjb.ACTUAL_FLAG            = 'A'  /* 1.3 */
       and gjb.STATUS                 = 'P'  /* 1.3 */
       and gjl.status                 = 'P'  /* 1.3 */
       ;

    --cursor c_detail(v_location varchar2, v_account varchar2) is -- 1.2
    cursor c_detail( v_location varchar2,v_account varchar2) is
    SELECT 'D'                                     || '|' ||               -- "Record Type",
           gb.ledger_id                            || '.' ||               -- Ledger
           decode(g_by_location_indicator,'Y',gcc.segment1,'') ||          -- location -- 1.2 1.4
           decode(g_by_location_indicator,'Y','.','') ||
           gcc.segment4                            || '.' ||               -- account
           gb.currency_code                        || '|' ||               --    "Import Account ID",
           TO_CHAR(gjb.posted_date, 'YYYYMMDD')    || '|' ||               -- "Posted Date",
           TO_CHAR(gjl.effective_date, 'YYYYMMDD') || '|' ||               --"Effective Date",
           gjh.je_source                           || '|' ||               -- "Transaction Type",
           NVL(gjl.accounted_dr, 0)                || '|' ||               -- "Debit Amount",
           NVL(gjl.accounted_cr, 0)                || '|' ||               -- "Credit Amount",
           gcc.segment1                            || '|' ||               -- "Reference 1",
           gcc.segment2                            || '|' ||               -- "Reference 2",
           gcc.segment3                            || '|' ||               -- "Reference 3",
           gcc.segment4                            || '|' ||               -- "Reference 4",
           gcc.segment5                            || '|' ||               -- "Reference 5",
           gb.period_name                          || '|' ||               -- "Reference 6",
           replace(gl.short_name,'|',' ')          || '|' ||               -- "Reference 7",  /* 1.3 */
           replace(gjb.name,'|',' ')               || '|' ||               -- "Reference 8",  /* 1.3 */
           replace(gjl.description,'|',' ')        || '|' ||               -- "Details",      /* 1.3 */
           replace(gjh.name,'|',' ')               || '|' ||               -- "Reference 9",  /* 1.3 */
           replace(gjh.description,'|',' ')        || '|' ||               -- "Reference 10", /* 1.3 */
           replace(gjh.je_category,'|',' ')        || '|' ||               -- "Reference 11", /* 1.3 */
           gjh.currency_code                       || '|' ||               -- "Reference 12", /* 1.3 */
           NVL(gjl.entered_dr, 0)                  || '|' ||               -- "Numeric Reference Field 1",
           NVL(gjl.entered_cr, 0)                                          -- "Numeric Reference Field 2"
           detail_line
      FROM gl_balances           gb,
           gl_je_lines          gjl,
           gl_code_combinations gcc,
           gl_je_headers        gjh,
           gl_je_batches        gjb,
           gl_ledgers            gl
     WHERE gb.code_combination_id     = gjl.code_combination_id
       AND gb.code_combination_id     = gcc.code_combination_id
       AND gjl.je_header_id           = gjh.je_header_id
       AND gjh.je_batch_id            = gjb.je_batch_id
       AND gl.ledger_id               = gb.ledger_id
       AND gjl.ledger_id              = gb.ledger_id
       AND gjl.period_name            = gb.period_name
       AND gcc.segment1               = decode(g_by_location_indicator,'Y',v_location,gcc.segment1) -- V. 1.4
       AND gcc.segment4               = v_account
       and TRUNC(gjb.posted_date)     = g_posted_date
--       AND gcc.segment1                 IN ('03105', '3122', '3123')    -- location
--       AND gcc.segment4                 BETWEEN '0000'
--                                            AND '3999'                  -- account
       AND (   NVL(gjl.accounted_dr, 0) != 0
            OR NVL(gjl.accounted_cr, 0)  != 0)
       AND gb.currency_code           = NVL(g_currency_code, gb.currency_code)    -- Currency
--       AND gb.period_name             = NVL(g_period_name, gb.period_name)   -- Period_name /* 1.1 */
       AND gb.period_name in (g_latest_closed_period , g_period_name) /* 1.1 */
       AND gb.ledger_id               = g_ledger_id
       AND gb.actual_flag             = 'A'
       and gjb.ACTUAL_FLAG            = 'A'  /* 1.3 */
       and gjb.STATUS                 = 'P'  /* 1.3 */
       and gjl.status                 = 'P'  /* 1.3 */
 ORDER BY gb.ledger_id,-- Ledger
          decode(g_by_location_indicator,'Y',gcc.segment1,''), -- 1.4
          gcc.segment4,
          gb.currency_code,
          gjb.posted_date ;

/* 2.0 Begin */
    CURSOR c_ledger_account IS
SELECT   SUBSTR (flv.lookup_code, 1, 4) account
       , decode(g_by_location_indicator,'Y',flv.attribute2,'') location
    FROM fnd_lookup_values flv
   WHERE flv.lookup_type = 'TTEC_AUTO_RECON_ACCOUNTS'
     AND flv.LANGUAGE = 'US'
     AND flv.enabled_flag = 'Y'
     AND ( ( g_by_location_indicator = 'Y'
          AND flv.attribute2 IS NOT NULL)
          OR (g_by_location_indicator = 'N'
          AND flv.attribute2 IS NULL)
          )
     AND flv.attribute1 = g_ledger_id
ORDER BY 1;
/* 2.0 End */

/* 2.0 Commented Out Cursor c_balance. Moved to Package Body */
--    cursor c_balance(v_account varchar2) is
--SELECT 'B'                record_type,
--       gl.ledger_id          ledger_id, -- 1.2
--       decode(g_by_location_indicator,'Y',gcc.segment1,'') location, -- 1.2  1.4
--       gcc.segment4       account,-- account
--       gb.currency_code   currency,
--       TO_CHAR(gp.end_date, 'YYYYMMDD')                Adjusted_balance_date,        --                                 "Adjusted Balance Date",
--       SUM(nvl(gb.period_net_dr,0) + nvl(gb.BEGIN_BALANCE_DR,0)) - SUM(nvl(gb.period_net_cr,0) + nvl(gb.BEGIN_BALANCE_CR,0) )        Adjusted_Balance                             --   "Adjusted Balance",
--  FROM gl_code_combinations gcc,
--       gl_balances           gb,
--       gl_periods            gp,
--       fnd_lookup_values    flv,
--       gl_ledgers            gl
--WHERE gcc.code_combination_id = gb.code_combination_id
--   AND gb.period_name          = gp.period_name
--   AND gl.ledger_id            = gb.ledger_id
----   AND gcc.segment1              IN ('03105', '03122', '03123')    -- location
--/* 1.2
--   AND gcc.segment1              IN (   SELECT lookup_code
--                                          FROM fnd_lookup_values flv
--                                         WHERE flv.lookup_type = 'XXTT_AUTO_RECON_LL_MAP'
--                                           AND flv.LANGUAGE = 'US'
--                                           AND flv.enabled_flag = 'Y'
--                                           AND tag = g_ledger_id)
--*/
----       AND gcc.segment4              BETWEEN '0000'
----                                         AND '3999'                  -- account
--   AND gcc.segment1  = decode(g_by_location_indicator,'Y',flv.attribute2,gcc.segment1) -- V. 1.4
--   AND gcc.segment4  = SUBSTR(flv.lookup_code,1,4) -- 1.2
--   AND flv.lookup_type = 'TTEC_AUTO_RECON_ACCOUNTS'
--   AND flv.LANGUAGE = 'US'
--   AND flv.enabled_flag = 'Y'
--   AND flv.attribute1 = g_ledger_id /* 1.2 */
--   AND SUBSTR(flv.lookup_code,1,4) = v_account
--   AND gb.currency_code        = NVL(g_currency_code, gb.currency_code)                           -- Currency
--   AND gp.period_name          = NVL(g_period_name, gp.period_name)   -- Period_name
--    AND gb.LEDGER_ID           = g_ledger_id
--   AND gb.actual_flag          = 'A'
--GROUP BY 'B',
--          gl.ledger_id,   --1.2
--          decode(g_by_location_indicator,'Y',gcc.segment1,'') , -- 1.2  1.4
--          gcc.segment4 ,
--          gb.currency_code,
--          TO_CHAR(gp.end_date, 'YYYYMMDD')
--          --DECODE(SIGN(gb.period_net_dr - gb.period_net_cr ), -1, 'C', 1, 'D', 0)
----HAVING SUM(nvl(gb.period_net_dr,0) + nvl(gb.BEGIN_BALANCE_DR,0)) - SUM(nvl(gb.period_net_cr,0) + nvl(gb.BEGIN_BALANCE_CR,0) ) != 0 /* 1.1 */
-- ORDER BY gl.ledger_id, --1.2
--        --  gcc.segment1, --1.2
--          gcc.segment4,
--          gb.currency_code,
--          TO_CHAR(gp.end_date, 'YYYYMMDD');

FUNCTION get_currency_code(p_ledger_id number) RETURN VARCHAR2;

FUNCTION get_org_id(p_ledger_id number)  RETURN NUMBER;

FUNCTION get_country_code(p_org_id number) RETURN VARCHAR2;

FUNCTION get_latest_open_period(p_ledger_id number, p_application_id number) RETURN VARCHAR2;

FUNCTION get_application_id(p_application_name varchar2) RETURN VARCHAR2;

FUNCTION get_latest_closed_period(p_ledger_id number, p_application_id number) RETURN VARCHAR2;

FUNCTION get_prior_period(p_ledger_id number, p_application_id number, p_period_name varchar2) RETURN VARCHAR2;

FUNCTION get_posted_period(p_ledger_id number, p_application_id number, p_posted_date date) RETURN VARCHAR2;

FUNCTION get_posted_date RETURN DATE;
PROCEDURE process_detail(
          errcode                     OUT VARCHAR2,
          errbuff                     OUT VARCHAR2,
          p_ledger_id                  IN NUMBER,
          p_period_name                IN VARCHAR2,
          p_posted_date                IN VARCHAR2,
          p_by_location_indicator      IN VARCHAR2);
PROCEDURE detail_main(
          errcode                     OUT VARCHAR2,
          errbuff                     OUT VARCHAR2,
          p_ledger_id                  IN NUMBER,
          p_period_name                IN VARCHAR2,
          p_posted_date                IN VARCHAR2,
          p_by_location_indicator      IN VARCHAR2);
PROCEDURE process_balance(
          errcode                     OUT VARCHAR2,
          errbuff                     OUT VARCHAR2,
          p_ledger_id                  IN NUMBER,
          p_period_name                IN VARCHAR2,
          p_by_location_indicator      IN VARCHAR2);
PROCEDURE balance_main(
          errcode                     OUT VARCHAR2,
          errbuff                     OUT VARCHAR2,
          p_ledger_id                  IN NUMBER,
          p_period_name                IN VARCHAR2,
          p_by_location_indicator      IN VARCHAR2);

END TTEC_AUTOREC_GL_OUTBOUND_INT;
/
show errors;
/