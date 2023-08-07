create or replace PACKAGE      TTEC_AUTOREC_AP_OUTBOUND_INT AUTHID CURRENT_USER AS
--
-- Program Name:  TTEC_AUTOREC_AP_OUTBOUND_INT
-- /* $Header: TTEC_AUTOREC_AP_OUTBOUND_INT.pks 1.0 2013/10/07  chchan ship $ */
--
-- /*== START ================================================================================================*\
--    Author: Christiane Chan
--      Date: 07-OCT-2013
--
-- Call From: Concurrent Program ->TeleTech AutoRec AP Outbound Interface
--      Desc: This program generates AP Data Feed mandated by Cheasapeak T-Recs requirements
--
--     Parameter Description:
--
--         p_ledger_id             :  Optional Value
--         p_AsOf_date             :  AP Trial Balance As Of Date DD-MON-RRRR
--         By Location             :  Hidden from End User -> Value will always be set to 'No'
--
--       Oracle Standard Parameters:
--
--   Modification History:
--
--  Version    Date     Author      Description (Include Ticket--)
--  -------  --------  --------     ------------------------------------------------------------------------------
--      1.0  10/07/13   CChan       Initial Version TTSD R#2744426 - Global AP Trial Balance Development
--      2.0  07/03/15   Amir Aslam   changes for Re hosting Project
--      1.0	15-May-2023 IXPRAVEEN(ARGANO)   		R12.2 Upgrade Remediation
--
-- \*== END =====================================
    -- Error Constants
    --START R12.2 Upgrade Remediation
	/*g_application_code   cust.ttec_error_handling.application_code%TYPE := 'AP';								-- Commented code by IXPRAVEEN-ARGANO,15-May-2023
    g_interface          cust.ttec_error_handling.INTERFACE%TYPE        := 'AutoRec AP Intf';
    g_package            cust.ttec_error_handling.program_name%TYPE     := 'TTEC_AUTOREC_AP_OUTBOUND_INT';
    g_label1             cust.ttec_error_handling.label1%TYPE           := 'Err Location';
    g_label2             cust.ttec_error_handling.label1%TYPE           := 'Acct ID';
    g_warning_status     cust.ttec_error_handling.status%TYPE           := 'WARNING';
    g_error_status       cust.ttec_error_handling.status%TYPE           := 'ERROR';
    g_failure_status     cust.ttec_error_handling.status%TYPE           := 'FAILURE';*/
	g_application_code   apps.ttec_error_handling.application_code%TYPE := 'AP';								--  code Added by IXPRAVEEN-ARGANO,   15-May-2023
    g_interface          apps.ttec_error_handling.INTERFACE%TYPE        := 'AutoRec AP Intf';
    g_package            apps.ttec_error_handling.program_name%TYPE     := 'TTEC_AUTOREC_AP_OUTBOUND_INT';
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
    g_latest_closed_period VARCHAR2(10);
    g_org_id               number(10);
    g_currency_code        VARCHAR2(3);
    g_country_code         VARCHAR2(2);
    g_process_date         DATE;
    g_import_acct          VARCHAR2(100);
    g_definition_code      VARCHAR2(100);
    g_by_location_indicator  varchar2(1);

  -- declare cursors

    cursor c_ledger is
    SELECT DISTINCT flv.attribute1 ledger_id
    FROM fnd_lookup_values flv
    WHERE flv.lookup_type = 'TTEC_AUTO_RECON_ACCOUNTS'
    AND flv.LANGUAGE = 'US'
    AND flv.enabled_flag = 'Y'
    AND flv.attribute3 = 'Y'
--    AND ((g_by_location_indicator = 'Y' AND  flv.attribute2 IS NOT NULL)
--     OR  (g_by_location_indicator = 'N' AND  flv.attribute2 IS NULL))
     ;

    cursor c_definition_code is
    SELECT definition_code
      FROM xla_tb_definitions_vl
     WHERE enabled_flag = 'Y'
       AND ledger_id = g_ledger_id
       AND definition_code IN (
              SELECT xtd.definition_code
                FROM xla_tb_defn_je_sources xtd, xla_subledgers xs
               WHERE xtd.je_source_name = xs.je_source_name
                 AND xs.application_id = g_application_id );

    CURSOR c_ledger_account IS
    SELECT   SUBSTR (flv.lookup_code, 1, 4) account
           , decode(g_by_location_indicator,'Y',flv.attribute2,'') location
        FROM fnd_lookup_values flv
       WHERE flv.lookup_type = 'TTEC_AUTO_RECON_ACCOUNTS'
         AND flv.LANGUAGE = 'US'
         AND flv.enabled_flag = 'Y'
         AND flv.attribute3 = 'Y'
         AND flv.attribute1 = g_ledger_id
--         AND ((g_by_location_indicator = 'Y' AND  flv.attribute2 IS NOT NULL)
--          OR  (g_by_location_indicator = 'N' AND  flv.attribute2 IS NULL))
    ORDER BY 1;

    cursor c_directory_path is          -- Change for Version 1.2
    select ttec_library.get_directory('CUST_TOP')||'/data/EBS/FIN/AP/AutoRec/Outbound' file_path
    --, decode(HOST_NAME,'den-erp046','','TEST_')||'AP_DETAIL_FEED_'||to_char(g_process_date,'RRRRMMDD')||'_'||replace(short_name,' ','_')||'.DAT' file_name
    , decode(HOST_NAME,TTEC_LIBRARY.XX_TTEC_PROD_HOST_NAME,'','TEST_')||'AP_DETAIL_FEED_'||to_char(g_process_date,'RRRRMMDD')||'_'||replace(short_name,' ','_')||'.DAT' file_name
    from v$INSTANCE,gl_ledgers
    where ledger_id = g_ledger_id;

    cursor c_directory_path2 is      -- Changed for Version 1.2
    select ttec_library.get_directory('CUST_TOP')||'/data/EBS/FIN/AP/AutoRec/Outbound' file_path
    --, decode(HOST_NAME,'den-erp046','','TEST_')||'AP_BALANCE_FEED_'||to_char(g_process_date,'RRRRMMDD')||'_'||replace(short_name,' ','_')||'.DAT' file_name
    , decode(HOST_NAME,TTEC_LIBRARY.XX_TTEC_PROD_HOST_NAME,'','TEST_')||'AP_BALANCE_FEED_'||to_char(g_process_date,'RRRRMMDD')||'_'||replace(short_name,' ','_')||'.DAT' file_name
    from v$INSTANCE,gl_ledgers
    where ledger_id = g_ledger_id;

    /* main query */

PROCEDURE process_balance(
          errcode                     OUT VARCHAR2,
          errbuff                     OUT VARCHAR2,
          p_ledger_id                  IN NUMBER,
          p_process_date               IN DATE);
PROCEDURE balance_main(
          errcode                     OUT VARCHAR2,
          errbuff                     OUT VARCHAR2,
          p_ledger_id                  IN NUMBER,
          p_process_date               IN VARCHAR2,
          p_by_location_indicator      IN VARCHAR2 );

END TTEC_AUTOREC_AP_OUTBOUND_INT;
/
show errors;
/