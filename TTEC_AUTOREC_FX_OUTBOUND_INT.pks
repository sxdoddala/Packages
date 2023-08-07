create or replace PACKAGE      TTEC_AUTOREC_FX_OUTBOUND_INT AUTHID CURRENT_USER AS
--
-- Program Name:  TTEC_AUTOREC_FX_OUTBOUND_INT
-- /* $Header: TTEC_AUTOREC_FX_OUTBOUND_INT.pks 1.0 2013/06/03  chchan ship $ */
--
-- /*== START ================================================================================================*\
--    Author: Christiane Chan
--      Date: 03-JUN-2013
--
-- Call From: Concurrent Program ->TeleTech AutoRec FX Outbound Interface
--      Desc: This program generates FX Data Feed mandated by Cheasapeak T-Recs requirements
--
--     Parameter Description:
--
--         p_ledger_id               :
--         p_period_name             :
--         p_rate_type            :
--
--       Oracle Standard Parameters:
--
--   Modification History:
--
--  Version    Date     Author   Description (Include Ticket--)
--  -------  --------  --------  ------------------------------------------------------------------------------------------
--      1.0  06/03/13   CChan     Initial Version TTSD R#2340332 - AutoRec Project
--      1.1  06/18/13   CChan     6/18/2013 Tim Redetzke email   - For our purposes, we only need the month end rate
--                                                                 since we will be using it to show all reconciliations
--                                                                 in USD (if not already in USD) as an informational item.
--                                                                 Only sending the rate of last day of the pay period
--                                                                  instead of 1 rate per day for the entire pay period 30 day or 31 days
--      1.2  01/14/13   CChan     Commented out the limitation  on TO_CURRENCY = 'USD'
--      1.3  07/03/15   AmirA     changes for Re hosting Project
--      1.0	15-May-2023 IXPRAVEEN(ARGANO)   		R12.2 Upgrade Remediation

-- \*== END =====================================
    -- Error Constants
	--START R12.2 Upgrade Remediation
    /*g_application_code   cust.ttec_error_handling.application_code%TYPE := 'FX';
    g_interface          cust.ttec_error_handling.INTERFACE%TYPE        := 'AutoRec FX Intf';
    g_package            cust.ttec_error_handling.program_name%TYPE     := 'TTEC_AUTOREC_FX_OUTBOUND_INT ';
    g_label1             cust.ttec_error_handling.label1%TYPE           := 'Error Loc';
    g_label2             cust.ttec_error_handling.label1%TYPE           := 'Period Name';
    g_warning_status     cust.ttec_error_handling.status%TYPE           := 'WARNING';
    g_error_status       cust.ttec_error_handling.status%TYPE           := 'ERROR';
    g_failure_status     cust.ttec_error_handling.status%TYPE           := 'FAILURE';*/
	g_application_code   apps.ttec_error_handling.application_code%TYPE := 'FX';
    g_interface          apps.ttec_error_handling.INTERFACE%TYPE        := 'AutoRec FX Intf';
    g_package            apps.ttec_error_handling.program_name%TYPE     := 'TTEC_AUTOREC_FX_OUTBOUND_INT ';
    g_label1             apps.ttec_error_handling.label1%TYPE           := 'Error Loc';
    g_label2             apps.ttec_error_handling.label1%TYPE           := 'Period Name';
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

    v_output_file                  UTL_FILE.FILE_TYPE;

    -- Declare variables
    g_application_id       number(10);
    g_period_name          VARCHAR2(10);
    g_latest_closed_period VARCHAR2(10);
    g_rate_type_1          VARCHAR2(240);
    g_rate_type_2          VARCHAR2(240);

  -- declare cursors
    cursor c_directory_path is
    select ttec_library.get_directory('CUST_TOP')||'/data/EBS/FIN/GL/AutoRec/Outbound' file_path
    -- , decode(HOST_NAME,'den-erp046','','TEST_')||'FX_RATE_FEED_'||g_period_name||'.DAT' file_name        -- Chnages for Version 1.3
    , decode(HOST_NAME,TTEC_LIBRARY.XX_TTEC_PROD_HOST_NAME,'','TEST_')||'FX_RATE_FEED_'||g_period_name||'.DAT' file_name           -- Chnages for Version 1.3

    from v$INSTANCE;

    cursor c_fx is
/* Formatted on 2013/06/04 15:51 (Formatter Plus v4.8.8) */
SELECT      dr.user_conversion_type
         || '|'
         || dr.from_currency
         || '|'
         || dr.to_currency
         || '|'
         || TO_CHAR (dr.conversion_date, 'YYYYMM')
         || '01'
         || '|'
         || TO_CHAR(dr.conversion_date, 'YYYYMMDD')
         || '|'
         || dr.show_conversion_rate
         || '|'
         || dr.show_inverse_con_rate detail_line
    --FROM apps.gl_daily_rates_v dr, gl.gl_periods p			-- Commented code by IXPRAVEEN-ARGANO,15-May-2023
    FROM apps.gl_daily_rates_v dr, apps.gl_periods p            --  code Added by IXPRAVEEN-ARGANO,   15-May-2023
   WHERE dr.conversion_date = p.end_date                            /* 1.1 */
       --dr.conversion_date BETWEEN p.start_date AND p.end_date     /* 1.1 */
     --AND dr.user_conversion_type IN (g_rate_type_1,g_rate_type_2) /* 1.1 */
     AND dr.user_conversion_type = g_rate_type_1                    /* 1.1 */
     --AND dr.to_currency = 'USD'                                     /* 1.1 */ /* 1.2 */
     --AND dr.user_conversion_type IN ('Period End Rate','Period Average Rate')
     AND p.period_set_name = 'CORP CALENDAR'
     AND p.period_name = g_period_name
ORDER BY dr.user_conversion_type
       , dr.from_currency
       , dr.to_currency
       , dr.conversion_date;

PROCEDURE fx_main(
          errcode                     OUT VARCHAR2,
          errbuff                     OUT VARCHAR2,
          p_period_name                IN VARCHAR2,
          p_rate_type_1                IN VARCHAR2,
          p_rate_type_2                IN VARCHAR2
);
END TTEC_AUTOREC_FX_OUTBOUND_INT ;
/
show errors;
/