create or replace PACKAGE      TTEC_TANGOE_CARRIER_FEED_INT AUTHID CURRENT_USER AS
--
-- Program Name:  TTEC_TANGOE_CARRIER_FEED_INT
-- /* $Header: TTEC_TANGOE_CARRIER_FEED_INT.pks 1.0 2014/07/07 chchan ship $ */
--
-- /*== START ================================================================================================*\
--    Author: Christiane Chan
--      Date: 07-JUL-2014
--
-- Call From: Concurrent Program ->TeleTech Tangoe Carrier Outbound Interface
--      Desc: This program generates TeleTech TELECOM Supplier (CARRIER) data feed to TANGOE
--
--     Parameter Description:
--
--           p_business_group_id       :   Business Group to be pushed to Egencia, each BG will be generated on a seperate file with respect with the File Naming Convention
--
--       Oracle Standard Parameters:
--
--   Modification History:
--
--  Version    Date     Author   Description (Include Ticket--)
--  -------  --------  --------  ------------------------------------------------------------------------------
--      1.0  03/07/14   CChan     Initial Version REQ00???? - TeleTech Tangoe Carrier Outbound Interface
--      1.1  10/13/14   CChan     should modify the code to send NULL in Payment Terms column Silvina Bikel ctober 08, 2014 8:19 AM to send NULL value
--      1.2  11/06/14   Cchan     add back OU Name
--      1.3  11/06/14   CChan     add last_run_date
--     1.4   08/04/2015  Amir Aslam          changes for Re hosting Project
-- \*== END =========================================================================================================
    -- Error Constants
    /*
	START R12.2 Upgrade Remediation
	code commented by RXNETHI-ARGANO,04/05/23
	g_application_code   cust.ttec_error_handling.application_code%TYPE := 'AP';
    g_interface          cust.ttec_error_handling.INTERFACE%TYPE        := 'Tangoe Intf';
    g_package            cust.ttec_error_handling.program_name%TYPE     := 'TTEC_TANGOE_CARRIER_FEED_INT';
    g_label1             cust.ttec_error_handling.label1%TYPE           := 'Err Location';
    g_label2             cust.ttec_error_handling.label1%TYPE           := 'Supplier_Number';
    g_label3             cust.ttec_error_handling.label1%TYPE           := 'SiteId';
    g_warning_status     cust.ttec_error_handling.status%TYPE           := 'WARNING';
    g_error_status       cust.ttec_error_handling.status%TYPE           := 'ERROR';
    g_failure_status     cust.ttec_error_handling.status%TYPE           := 'FAILURE';
	*/
	--code added by RXNETHI-ARGANO,04/05/23
	g_application_code   apps.ttec_error_handling.application_code%TYPE := 'AP';
    g_interface          apps.ttec_error_handling.INTERFACE%TYPE        := 'Tangoe Intf';
    g_package            apps.ttec_error_handling.program_name%TYPE     := 'TTEC_TANGOE_CARRIER_FEED_INT';
    g_label1             apps.ttec_error_handling.label1%TYPE           := 'Err Location';
    g_label2             apps.ttec_error_handling.label1%TYPE           := 'Supplier_Number';
    g_label3             apps.ttec_error_handling.label1%TYPE           := 'SiteId';
    g_warning_status     apps.ttec_error_handling.status%TYPE           := 'WARNING';
    g_error_status       apps.ttec_error_handling.status%TYPE           := 'ERROR';
    g_failure_status     apps.ttec_error_handling.status%TYPE           := 'FAILURE';
	--END R12.2 Upgrade Remediation

    -- Process FAILURE variables
    g_fail_flag                   BOOLEAN := FALSE;

    -- Filehandle Variables
    v_file_path                      varchar2(400);
    v_filename                     varchar2(100);
    v_country                      varchar2(2);
    v_row_id                       number;

    v_output_file                    UTL_FILE.FILE_TYPE;

    -- Declare variables
    g_business_group_id            number(5);
    g_manual_upload                VARCHAR2(1);
    g_last_run                     DATE;
    --g_emp_no                       hr.per_all_people_f.employee_number%TYPE;  --code commented by RXNETHI-ARGANO,04/05/23
    g_emp_no                       apps.per_all_people_f.employee_number%TYPE;  --code added by RXNETHI-ARGANO,04/05/23


  -- declare cursors

    cursor c_directory_path is
    select ttec_library.get_directory('CUST_TOP')||'/data/EBS/FIN/AP/Tangoe/Outbound/'
    ||(select hla.COUNTRY
        from hr_organization_units ou
        , hr_locations_all hla
        where ou.ORGANIZATION_ID = g_business_group_id
        and ou.LOCATION_ID = hla.LOCATION_ID
            )  file_path
    ,  (select decode(HOST_NAME,ttec_library.XX_TTEC_PROD_HOST_NAME,'','TEST_')||'TTIvendor'
    --,  (select decode(HOST_NAME,'den-erp046','','TEST_')||'TTIvendor'
   -- || decode(sign(g_business_group_id),1,'_','') || g_business_group_id
    ||'_'||    to_char(SYSDATE,'RRRRMMDD')
    from v$INSTANCE)
    ||  '.csv' file_name
    from V$DATABASE;

   CURSOR c_last_run
   IS
      SELECT MAX (TRUNC(actual_start_date))
        FROM apps.fnd_conc_req_summary_v
       WHERE     program_short_name = 'TTEC_TANGOE_CARRIER_FEED_INT'
             AND phase_code = 'C'
             AND completion_text = 'Normal completion';

    /* main query to obtain carrier data from HR tables */
    cursor c_carrier_cur  is
SELECT DISTINCT
  DECODE(sign(assa.creation_date - g_last_run ),1,'"NEW"','"UPDATE"')
||',"'|| NVL((SELECT DESCRIPTION
                FROM fnd_lookup_values flv
               WHERE flv.lookup_type = 'TTEC_TANGOE_CARRIER_MAPPING'
                 AND flv.LANGUAGE = 'US'
                 AND flv.enabled_flag = 'Y'
                 AND TRIM(LOOKUP_CODE) = aps.SEGMENT1)
             ,aps.VENDOR_NAME)
||'","'||  ''
||'","'||  aps.SEGMENT1 ||'_'|| assa.VENDOR_SITE_CODE
||'","'||  assa.ADDRESS_LINE1
||'","'||  assa.ADDRESS_LINE2
||'","'||  assa.ADDRESS_LINE3
||'","'||  assa.CITY
||'","'||  decode(assa.COUNTRY,'US',assa.STATE,'')
||'","'||  assa.ZIP
||'","'||  assa.COUNTRY
||'","'||  (
 SELECT gl.name
FROM apps.hr_operating_units hou
   --, gl.gl_ledgers gl   --code commented by RXNETHI-ARGANO,04/05/23
   , apps.gl_ledgers gl   --code added by RXNETHI-ARGANO,04/05/23
where gl.ledger_id = hou.SET_OF_BOOKS_ID
and hou.ORGANIZATION_ID = assa.org_id
)/* 1.2 */
||'","'||  NULL --atl.due_days /* 1.1 */
||'","'||  'N'
||'","'||  ''
||'"' line
    FROM  apps.HR_ORGANIZATION_UNITS ou,
          --ap.AP_SUPPLIERS aps                 --code commented by RXNETHI-ARGANO,04/05/23
          apps.AP_SUPPLIERS aps                 --code added by RXNETHI-ARGANO,04/05/23
        --, ap.AP_SUPPLIER_SITES_ALL assa       --code commented by RXNETHI-ARGANO,04/05/23
        , apps.AP_SUPPLIER_SITES_ALL assa       --code added by RXNETHI-ARGANO,04/05/23
        --, ap.AP_TERMS_LINES atl /* 1.1 */
        --, ap.AP_TERMS_TL ata
    WHERE --atl.term_id  = assa.terms_id /* 1.1 */
    --and ou.ORGANIZATION_ID = assa.org_id
    --AND   ata.language = 'US'
    --AND   ata.term_id  = aps.terms_id
    --AND   gl.LEDGER_ID = aps.SET_OF_BOOKS_ID
    --AND
    assa.PAY_SITE_FLAG = 'Y'
    AND   aps.VENDOR_ID = assa.VENDOR_ID
    AND   aps.PAY_GROUP_LOOKUP_CODE = assa.PAY_GROUP_LOOKUP_CODE
    AND   aps.Pay_Group_Lookup_Code = 'TELECOM'
    AND   aps.ENABLED_FLAG = 'Y'
    --AND   aps.SEGMENT1 in ('34093', '43089')
    ORDER BY 1;
PROCEDURE print_detail_column_name (v_rec OUT VARCHAR2);
PROCEDURE main(
          errcode                     OUT VARCHAR2,
          errbuff                     OUT VARCHAR2,
          p_last_run                  IN  DATE
);
END TTEC_TANGOE_CARRIER_FEED_INT;
/
show errors;
/