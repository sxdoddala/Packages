create or replace PACKAGE BODY      ttec_po_email IS
  /************************************************************************************
          Program Name: TTEC_PO_EMAIL

          Description:  This program gets a query of the PO that were approved since the program last run
                         Each PO is printerd with the specific country PO print program. A copy is then email
                         to a the vendor, requestor and Corporate Purchasing

          Developed by : Wasim Manasfi
          Date         : Feb 5 2009

         Modification Log
         Name                  Modification #    Date            Description
         -----                    --------       -----           -------------
      Wasim Manasfi                              Feb 23 2007        Created
      Felipe A. Reyes Linares        1.0         Mar 08 2010        Modification (IF Statement line 2994/2995) INC# 104306
      Felipe A. Reyes Linares        1.1         Mar 11 2010        Modification (Email routing for Testing) INC# 104306
      Felipe A. Reyes Linares        2.0         Jun 10 2010        Modification (Diferent Languages for Not.) REQ# 77875

        There is an individual routine to print each country PO. these could have been combined
        into one single routine, but were not since each was developed and tested (major factor TESTED)  individually
        any change to a country or adding a country would not require testing of other countries.
        V 2.0: The package has been extended to include different notifications depending on the status of the
        PO and the language. The possible statuses are: Approved, Revised, and Cancelled.
        The notifications used are: (us) for most english notifications.
                                      (arg) for Argentina
                                      (spn) for Spain
                                      (phl) for Philippines
                                      (mx) for Mexico
                                      (br) for brazil
                                      (cr) for Costa Rica

      Wasim Manasfi                  2.1         Jun 16 2010        added US Government Solutions  161857
      Felipe A. Reyes Linares        2.2         Jul 28 2010        Fixed Canada Blank PO Generation INC# 293300
      Diaz Lasserre Leandro          3.0         Oct 28 2010        Modification (Added specifications for new site TT Ghana) REQ#349360
                                                                    Removed hard-coded paths and included code to point from DBA directories
      Michelle Dodge                 3.1         Feb 14, 2011       Updated Resp ID's in ttec_po_run* functions for new Purchasing Application
                                                                    responsibilities.  Disabled original Custom Application responsibilities.
      Christiane Chan                3.2         Feb 15 2011        added Prodovis
      Wasim Manasfi                  3.3         March 3 2011       Added PRG
      Wasim Manasfi                  3.4         April 11 2011      Added PRG Messaging
      Kaushik Gonuguntla             3.5         Jun 2nd 2011       Added new procedures for PRG dubai.
      Diego Bruses                   3.6         Jun 30 2011        Added specifications for new site Philippines Branch REQ#766054.
      Christiane Chan                3.7         Oct 24 2011        R12 Retrofit - REI ID 498
      Kaushik Babu                   3.8         Jun 19 2013        changed description to print on ARG PO Email - TTSD R 2483604
      Ravi Pasula                    3.9         Sep 03 2013        added 3 new address fields    2469370
      Kaushik Babu                   4.0         JAN 27 2014         Added new functionality to send email for Ireland PO's and fixing code to send email to the preparer - INC0089666
      Kaushik Babu                   4.1         FEB 19 2014         Added new functionality to send email for PRG BEL,SAF, LEB, PHBRANCH PO's - TASK0030962
      Deebak Kuppusamy               4.2          Mar 19 2014      Added new functionality to send email for new operating units Guidon, iKnowtion
      Deebak Kuppusamy               4.3          Apr 15 2014      Added new functionality to send email for new operating units eLoyalty US, Ireland and Canada
      Christiane Chan                4.4        Dec 30 2014        INC0842894 - Change the mail address for Payment inquiries from APInvoices@teletech.com to APInquiries@teletech.com on the Purchase Order mailer
      Christiane Chan                4.5        Jan 05 2015        INC0842894 - Can you please update that with APInvoicesInquiries@teletech.com , instead of cuentaspagar@teletech.com ? That's what we are currently using for our LATAM mailbox in AP
      Sunil Babu Sayala              4.6        Jan 30 2015        Added new operating unit TSG
      Sunil Babu Sayala              4.7        Feb 3 2015         PRG Belgium PO is not getting printed and emailed
      Sunil Babu Sayala              4.8        Feb 19 2015        Added PRG Turkey Operating Unit
      Sunil Babu Sayala              4.9        Feb 19 2015        To restrict E-Mails for TSG OU Direct Purchase Orders(created via TSG PO interface)
      Amir Aslam                      5.0      08/06/2015          changes for Re hosting Project
      Lalitha                        6.0       08/21/2015           changes for Re hosting Project  for smtp
      Amir Aslam                     6.1       09/28/2015          Change the Substr
      Amir Aslam                     7.0       09/28/2015           Added Logic for HongKong , SG , AUS and UK
      Arun Kumar                     8.0       02/12/2016          Modification (PDF generation conc. program change for
                                                                                 PHL, PHL Branch and PHL ROHQ) REQ#0206747
      Atul Vishwakarma               8.1       11/09/2016          Modifications in email notification messages for Spain/Mexico/
                                                                   Costa Rica/Argentina/US/Philippines OUs.Incident # INC2297177
      Hema Chakravarthi              8.2       01/18/2017          Added Bulgaria Operating Unit (TELETECH_BULGARIA_OU) # INC2672655
      Atul Vishwakarma               8.3       03/13/2017          Changed responsibility for PO PDF output conc. program for Bulgaria.
      Christiane Chan                9.0       03/06/2017          Added Logic for Rogen China
      Christiane Chan                9.1       03/09/2017          Added Logic for TTEC Consulting Belgium
      Christiane Chan                9.2       03/14/2017          Added Logic for Atelka Canada
      Atul Vishwakarma               9.3       03/28/2017          Buffer size increased and removed special characters from text message for Mexico, Spain, Costa Rica and Argentina
      Amir                           9.4       08/08/2017          Change for fixing the  failing Pos.
      Christiane Chan                9.5       01/25/2018          Fiddler Phase 1 - Added Logic for TTEC domain for US and Canada (Execpt TeleTech Canada)
      Christiane Chan                9.6       02/20/2018          Fiddler Phase 2 - Added Logic for TTEC domain for Rogensi UK, eLoy Ireland, TTEC Ireland/UK/AU/NZ
      Christiane Chan                9.7       02/28/2018          Fiddler Phase 2 - Chenge to call Global -> Graphic TTEC Global Purchase Order (No point to maintain different EDF with the same new Branding Logo
      Christiane Chan                9.8       03/20/2018          Fiddler Phase 2 - ELSE (9.7) is bad idea, it automatically emailed PO to Percepta US. Correct back to be country specific when calling Graphic TTEC Global Purchase Order
      Christiane Chan               10.0       03/19/2018          Fiddler Phase 3 - Added Logic for TTEC Logo/email domain for RogenSi AUS, BRZ,and CR.
      Christiane Chan               10.1       03/23/2018          Added Logic for - Motif PHL
      Christiane Chan               10.2       03/23/2018          Added Logic for - Motif India
      Christiane Chan               10.3       04/17/2018          Fiddler Phase 4 - Added Logic for TTEC Logo/email domain for  2 ledgers: TeleTech Bulgaria and TeleTech Poland (Poland was not included on the nightly automated process)
      Christiane Chan               10.4       04/17/2018          Add Raised an Error when PO output is not found
      Christiane Chan               10.5       04/17/2018          Adding TeleTech Poland
      Christiane Chan               10.6       04/19/2018          Fiddler Phase 4 - Added Logic for TTEC Logo/email domain for TT Mexico
      Christiane Chan               10.7       04/19/2018          Replace 'wfmailtesting@ttec.com' from'MailerTesting@teletech.com'
      Christiane Chan                          05/02/2018          Backed out Bulgaria (10.3) and TT Mexico (10.6)
      Christiane Chan               11.0       09/04/2018          Adding TTEC NETHERLAND ORG_ID - 53068
      Christiane Chan               11.1       01/17/2019          Adding TTEC GREECE ORG_ID - 54909
      Christiane Chan               11.2       06/20/2019          Motif India to TTEC Logo
      Christiane Chan               11.3       08/21/2019          PO Message update
      Christiane Chan               11.4       09/03/2019          Adding TTEC DIGITAL INDIA
      Chandra Shekar Aekula         11.5       08/Jan/2020        Commented email messages for RITM0779143
      Christiane Chan               12.0       28/Jan/2020         12.0.0 Change Logic to use LOOKUP instead hard code OU to rollout new country or merger
                                                                         Driven by OU inclusion under PO Super user Purchasing Lookup Type -> 'TTEC_PO_EMAIL_OU_ROLLOUT'
                                                                  12.0.1 Automatically email PO 30 days approved prior to instance vinstance startup_time
                                                                  12.0.2 Adding Term and Condition in PDF format as a second attachment
      Christiane Chan               12.1       29/Jan/2020
      Christiane Chan               12.2       04/Feb/2020        Adding FCR Logo
      Vaibhav Panchgade             12.3       12/Feb/2020        Added for India report having  GST , T and C    #12.3
      Rajesh Koneru                 12.4       06/08/2020         Added changes as part of syntax retrofit
      Narasimhulu Yellam            12.5       24/Apr/2021        Added changes in the email body from "the Accounts Payable Department at 6/F Tower A, Two Ecom Center, Palm Coast Avenue, Mall of Asia Complex, Pasay City" to
	                                                              "TeleTech Pioneer Career Hub, 2nd Floor, Robinson Cybergate Plaza, Edsa corner Pioneer, Mandaluyong City"
																  from "APInquiries@TTEC.com" to "GlobalAccountsPayable@ttec.com"
     Christiane Chan               12.6       06/22/2021        TASK2087334 - Enhancement request to add Alert when there is a PO creation issue
     Christiane Chan               12.7       07/07/2021        Adding the ability to reprocess a datetime range
      Laxmi Nagandla               12.8       08/21/2021        TASK2422827 telephone # on PO email to supplier and requester for PH, PH Branch and Motif PH ledger to +63.2.7739.7561.
	 RXNETHI-ARGANO                1.0        12/MAY/2023       R12.2 Upgrade Remediation
  ****************************************************************************************/
  CURSOR c_host IS
    SELECT host_name,
        apps.TTEC_GET_INSTANCE--INSTANCE_NAME -- changes made for 12.4
 FROM v$instance;
    --SELECT SUBSTR(host_name, 1, 10) FROM v$instance;    -- Commented for Ver 6.1

  -- Version 3.0
  --   CURSOR c_directory_path
  --   IS
  --        SELECT db.directory_path || '/admin/out/' || vi.instance_name || '_' || vi.host_name /*V3.0 This sentence was modified to take the path from dba_directories*/
  --          FROM dba_directories db, v$instance vi
  --          WHERE db.directory_name = 'COMMON_TOP';
  --
  --   CURSOR c_temp_dir_path
  --   IS
  --        SELECT db.directory_path || '/data/temp'
  --          FROM dba_directories db
  --         WHERE db.directory_name = 'CUST_TOP';
  CURSOR c_this_run IS
    SELECT SYSDATE FROM DUAL;

  /* cursor to get last run time of the program , Any PO approved after this date will be included in the run */
  CURSOR c_last_run IS
--SELECT MAX(actual_start_date-7) -- TESTING  AMIR
    SELECT MAX(actual_start_date)
      FROM fnd_conc_req_summary_v
     WHERE program_short_name = 'TTEC_PO_AUTO_EMAIL'
       AND phase_code = 'C'
       AND completion_text = 'Normal completion';

  /* get a list of PO's that were approved since a specific time */
  CURSOR c_get_po_info(g_date DATE,
                                               p_reprocess_flag VARCHAR2, /* 12.7 */
                                               p_begin_datetime VARCHAR2, /* 12.7 */
                                               p_end_datetime VARCHAR2 /* 12.7 */
                                               ) IS
    SELECT DISTINCT poh.segment1 l_po_num,
                    (poh.approved_flag) l_po_approved,
                    (poh.approved_date) l_po_approve_date,
                    poh.org_id l_org_id,
                    (ppf.full_name) l_requester_name,
                    (ppf.email_address) l_requester_email,
                    (pos.email_address) l_vendor_site_email,
                    (pov.vendor_name) l_vendor_name,
                    (pos.vendor_site_code) l_vendor_site,
                    (pos.fax_area_code) l_vendor_fax_area,
                    (pos.fax) l_vendor_fac,
                    (ppfb.email_address) l_buyer_email,
                    ppfb.full_name l_buyer_name,
                    poh.revision_num l_revision_num, -- 2.0 fields added
                    poh.cancel_flag l_cancel_flag -- 2.0
      /*
	  START R12.2 Upgrade Remediation
	  code commented by RXNETHI-ARGANO,12/05/23
	  FROM po.po_headers_all       poh,
           po.po_lines_all         pol,
           ap_suppliers            pov, -- V3.7 po.po_vendors
           ap_supplier_sites_all   pos, --V3.7 po.po_vendor_sites_all
           po.po_distributions_all pod,
           hr.per_all_people_f     ppf,
           hr.per_all_people_f     ppfb
		   */
	  --code added by RXNETHI-ARGANO,12/05/23
	  --START R12.2 Upgrade Remediation
	  --code commented by RXNETHI-ARGANO,12/05/23
	  FROM apps.po_headers_all       poh,
           apps.po_lines_all         pol,
           ap_suppliers            pov, -- V3.7 po.po_vendors
           ap_supplier_sites_all   pos, --V3.7 po.po_vendor_sites_all
           apps.po_distributions_all pod,
           apps.per_all_people_f     ppf,
           apps.per_all_people_f     ppfb
	  --END R12.2 Upgrade Remediation
     WHERE poh.po_header_id = pol.po_header_id
       AND poh.vendor_id = pov.vendor_id
       AND poh.po_header_id = pod.po_header_id
       AND ppf.person_id(+) = pod.deliver_to_person_id
       AND pov.vendor_id = pos.vendor_id
       AND poh.vendor_site_id = pos.vendor_site_id
       AND poh.approved_flag = 'Y'
       AND pos.inactive_date IS NULL
       AND poh.agent_id = ppfb.person_id
       AND  (       (p_reprocess_flag = 'N'    AND  poh.approved_date >= g_date)
                   OR ( p_reprocess_flag = 'Y'  AND   poh.approved_date  BETWEEN TO_DATE(TO_CHAR(p_begin_datetime ),'DD-MON-YYYY HH24:MI:SS')   /* 12.7 */
                                                                                                                                    AND  TO_DATE(TO_CHAR(p_end_datetime ),   'DD-MON-YYYY HH24:MI:SS')   /* 12.7 */
                           )
                  )
       AND TRUNC(SYSDATE) BETWEEN ppf.effective_start_date(+) AND
           ppf.effective_end_date(+)
       AND TRUNC(SYSDATE) BETWEEN ppfb.effective_start_date AND
           ppfb.effective_end_date /* 12.0.0 Begin */
       --AND poh.SEGMENT1 in ( '460054','460021','680687','450000')
       --AND poh.SEGMENT1 in ( '460015','460021','680687','450000','690023','700008')
       --AND poh.org_id = 54909; -- 56910; --
       AND poh.org_id in (SELECT   hou.ORGANIZATION_ID
                            FROM fnd_lookup_values_vl flv
                            ,apps.hr_organization_units hou
                           WHERE flv.lookup_type = 'TTEC_PO_EMAIL_OU_ROLLOUT'
                             AND (flv.lookup_type LIKE 'TTEC_PO_EMAIL_OU_ROLLOUT')
                             AND to_number(flv.LOOKUP_CODE) = hou.ORGANIZATION_ID
                             AND (flv.view_application_id = 201)
                             AND (flv.security_group_id = 0)
                             AND trunc(SYSDATE) BETWEEN flv.start_date_active and NVL(flv.end_date_active,to_date('31-DEC-4712'))
       )   /* 12.0.0 End */
       ------ Start of 4.9 Changes --------
       AND (poh.org_id <> 30633 OR (poh.org_id = 30633 AND poh.attribute1 IS NULL));
       ---- End of 4.9 Changes --------

  /* global settings and parameters */
  g_test_instance VARCHAR2(64) := 'TEST';
  -- 1.1 -- Added for mail routing
  g_test_emails VARCHAR(1024) := '';
  g_host_name   VARCHAR2(64);
  g_temp_dir    VARCHAR2(200) := apps.ttec_library.get_directory('CUST_TOP');
  -- Version 3.0
  --g_pur_dept_email      VARCHAR2(64) := 'CorporatePurchasing@TeleTech.com';
  g_pur_dept_email      VARCHAR2(64) := 'CorporatePurchasing@TTEC.com'; /* 9.5 */
  g_from_email          VARCHAR2(64) := 'CorporatePurchasing@TeleTech.com';
  g_file_prename        VARCHAR2(64) := 'TeleTech_PO_';
  g_file_extension      VARCHAR2(24) := '.PDF';
  g_request_default_dir VARCHAR2(128) := apps.ttec_library.get_applcsf_dir('out');
  -- Version 3.0
  g_body_main      VARCHAR2(10000);
  g_user_id        NUMBER;
  g_respon_id      NUMBER; /* 9.7 */
  g_respn_appl_id  NUMBER; /* 9.7 */
  g_cr             CHAR(2) := CHR(13);
  g_crlf           CHAR(2) := CHR(10) || CHR(13);
  g_last_run_date  DATE; -- key date from last run
  g_email_not_sent VARCHAR2(300) := 'This PO has not been emailed to vendor, as contact information was not available for them in the system.  Please either forward the PO to them directly, or provide the contact details to Procurement and it will be sent on your behalf.  Vendor Name: ';
  g_error_step     VARCHAR2(256) := '';
  g_operating_unit_name     VARCHAR2(240) := '';
  g_po_run_type             VARCHAR2(240) := ''; /* 12.0.0 */
  g_TC_attachment_filename  VARCHAR2(240) := ''; /* 12.0.2 */
  g_db_instance             VARCHAR(15)   := ''; /* 12.0.0 */
  g_organization_code       VARCHAR(15)   := ''; /* 12.0.0 */

  --  2.0 Shows the place where the error occurred
  PROCEDURE print_line(v_data IN VARCHAR2) IS
  BEGIN
    fnd_file.put_line(fnd_file.LOG, v_data);
  END;

  /* insert new date in the table */

  /* Build Message to be emailed to vendor */

  /* Start new code Vesion 2.0 */

  /******************************************************************************************
  ttec_build_msg_body_xx_yyy fucnctions: This functions build the correct message body depending
                                         on country (xx) and status (yyy).
  *****************************************************************************************/
  FUNCTION ttec_build_msg_body_us_can(p_po_number      IN VARCHAR2,
                                      p_vendor_name    IN VARCHAR2,
                                      p_requestor_name IN VARCHAR2) -- 2.0
   RETURN NUMBER IS
    v_body1   VARCHAR2(128) := 'Attached you will find the cancelled PO ';
    v_body1_1 VARCHAR2(128) := ' due to one or more of the following reasons: ';
    v_body2   VARCHAR2(128) := '     - Requestor informed us to cancel the order ';
    v_body3   VARCHAR2(128) := '     - Vendor name incorrect ';
    v_body4   VARCHAR2(128) := '     - Failure to deliver order(s) due to stock unavailability or unpaid accounts ';
    v_body5   VARCHAR2(128) := '     - Transaction failure ';
    v_body6   VARCHAR2(128) := 'TeleTech will not be expecting any invoices to match this PO. ';
    v_body7   VARCHAR2(128) := 'Please contact the TeleTech Procurement Department at procurement@teletech.com with any questions/concerns regarding this ';
    v_body8   VARCHAR2(128) := 'Purchase Order.';
  BEGIN
    g_body_main := NULL;
    g_body_main := p_vendor_name || g_cr || g_crlf || v_body1 ||
                   p_po_number || v_body1_1 || g_crlf || v_body2 || g_crlf ||
                   v_body3 || g_crlf || v_body4 || g_crlf || v_body5 || g_cr ||
                   g_crlf || v_body6 || g_cr || g_crlf || v_body7 || g_crlf ||
                   v_body8 || g_cr || g_crlf;
    RETURN(0);
  END ttec_build_msg_body_us_can;
/* 9.5 Begin */
  FUNCTION ttec_build_msg_body_us_can1(p_po_number      IN VARCHAR2,
                                      p_vendor_name    IN VARCHAR2,
                                      p_requestor_name IN VARCHAR2) -- 2.0
   RETURN NUMBER IS
    v_body1   VARCHAR2(128) := 'Attached you will find the cancelled PO ';
    v_body1_1 VARCHAR2(128) := ' due to one or more of the following reasons: ';
    v_body2   VARCHAR2(128) := '     - Requestor informed us to cancel the order ';
    v_body3   VARCHAR2(128) := '     - Vendor name incorrect ';
    v_body4   VARCHAR2(128) := '     - Failure to deliver order(s) due to stock unavailability or unpaid accounts ';
    v_body5   VARCHAR2(128) := '     - Transaction failure ';
    v_body6   VARCHAR2(128) := 'TeleTech will not be expecting any invoices to match this PO. ';
    v_body7   VARCHAR2(128) := 'Please contact the TTEC/TeleTech Procurement Department at procurement@TTEC.com with any questions/concerns regarding this ';
    v_body8   VARCHAR2(128) := 'Purchase Order.';
  BEGIN
    g_body_main := NULL;
    g_body_main := p_vendor_name || g_cr || g_crlf || v_body1 ||
                   p_po_number || v_body1_1 || g_crlf || v_body2 || g_crlf ||
                   v_body3 || g_crlf || v_body4 || g_crlf || v_body5 || g_cr ||
                   g_crlf || v_body6 || g_cr || g_crlf || v_body7 || g_crlf ||
                   v_body8 || g_cr || g_crlf;
    RETURN(0);
  END ttec_build_msg_body_us_can1;
/* 9.7 Begin */
  FUNCTION ttec_build_msg_body_global_can(p_po_number      IN VARCHAR2,
                                      p_vendor_name    IN VARCHAR2,
                                      p_requestor_name IN VARCHAR2) -- 2.0
   RETURN NUMBER IS
    v_body1   VARCHAR2(128) := 'Attached you will find the cancelled PO ';
    v_body1_1 VARCHAR2(128) := ' due to one or more of the following reasons: ';
    v_body2   VARCHAR2(128) := '     - Requestor informed us to cancel the order ';
    v_body3   VARCHAR2(128) := '     - Vendor name incorrect ';
    v_body4   VARCHAR2(128) := '     - Failure to deliver order(s) due to stock unavailability or unpaid accounts ';
    v_body5   VARCHAR2(128) := '     - Transaction failure ';
    v_body6   VARCHAR2(128) := 'TeleTech will not be expecting any invoices to match this PO. ';
    v_body7   VARCHAR2(128) := 'Please contact the TTEC Procurement Department at procurement@TTEC.com with any questions/concerns regarding this ';
    v_body8   VARCHAR2(128) := 'Purchase Order.';
  BEGIN
    g_body_main := NULL;
    g_body_main := p_vendor_name || g_cr || g_crlf || v_body1 ||
                   p_po_number || v_body1_1 || g_crlf || v_body2 || g_crlf ||
                   v_body3 || g_crlf || v_body4 || g_crlf || v_body5 || g_cr ||
                   g_crlf || v_body6 || g_cr || g_crlf || v_body7 || g_crlf ||
                   v_body8 || g_cr || g_crlf;
    RETURN(0);
  END ttec_build_msg_body_global_can;
  FUNCTION ttec_build_msg_body_arg_can(p_po_number      IN VARCHAR2,
                                       p_vendor_name    IN VARCHAR2,
                                       p_requestor_name IN VARCHAR2) -- 2.0
   RETURN NUMBER IS
    v_body1   VARCHAR2(128) := 'Adjunta se encuentra la Orden de Compra numero ';
    v_body1_1 VARCHAR2(128) := ' cancelada debido a alguna de las ';
    v_body2   VARCHAR2(128) := 'siguientes razones: ';
    v_body3   VARCHAR2(128) := '     - El solicitante nos pidio cancelacion ';
    v_body4   VARCHAR2(128) := '     - Nombre de Proveedor incorrecto. ';
    v_body5   VARCHAR2(128) := '     - Falta de stock o cuentas impagas. ';
    v_body6   VARCHAR2(128) := '     - Fallo en la transaccion. ';
    v_body7   VARCHAR2(128) := 'TeleTech no recibira facturas para asociar a esta Orden de Compra. ';
    v_body8   VARCHAR2(128) := 'Por favor, contactar al departamento de Compras a procurement@teletech.com por cualquier pregunta respecto de esta ';
    v_body9   VARCHAR2(128) := 'Orden de Compra.';
  BEGIN
    g_body_main := NULL;
    g_body_main := p_vendor_name || g_cr || g_crlf || v_body1 ||
                   p_po_number || v_body1_1 || g_crlf || v_body2 || g_crlf ||
                   v_body3 || g_crlf || v_body4 || g_crlf || v_body5 ||
                   g_crlf || v_body6 || g_cr || g_crlf || v_body7 || g_cr ||
                   g_crlf || v_body8 || g_crlf || v_body9 || g_cr || g_crlf;
    RETURN(0);
  END ttec_build_msg_body_arg_can;

  FUNCTION ttec_build_msg_body_spn_can(p_po_number      IN VARCHAR2,
                                       p_vendor_name    IN VARCHAR2,
                                       p_requestor_name IN VARCHAR2) -- 2.0
   RETURN NUMBER IS
    v_body1   VARCHAR2(128) := 'Adjunta se encuentra la Orden de Compra numero ';
    v_body1_1 VARCHAR2(128) := ' cancelada debido a alguna de las ';
    v_body2   VARCHAR2(128) := 'siguientes razones: ';
    v_body3   VARCHAR2(128) := '     - El solicitante nos pidio cancelacion ';
    v_body4   VARCHAR2(128) := '     - Nombre de Proveedor incorrecto. ';
    v_body5   VARCHAR2(128) := '     - Falta de stock o cuentas impagas. ';
    v_body6   VARCHAR2(128) := '     - Fallo en la transaccion. ';
    v_body7   VARCHAR2(128) := 'TeleTech no recibira facturas para asociar a esta Orden de Compra. ';
    v_body8   VARCHAR2(128) := 'Por favor, contactar al departamento de Compras a procurement@teletech.com por cualquier pregunta respecto de esta ';
    v_body9   VARCHAR2(128) := 'Orden de Compra.';
  BEGIN
    g_body_main := NULL;
    g_body_main := p_vendor_name || g_cr || g_crlf || v_body1 ||
                   p_po_number || v_body1_1 || g_crlf || v_body2 || g_crlf ||
                   v_body3 || g_crlf || v_body4 || g_crlf || v_body5 ||
                   g_crlf || v_body6 || g_cr || g_crlf || v_body7 || g_cr ||
                   g_crlf || v_body8 || g_crlf || v_body9 || g_cr || g_crlf;
    RETURN(0);
  END ttec_build_msg_body_spn_can;

  FUNCTION ttec_build_msg_body_phl_can(p_po_number      IN VARCHAR2,
                                       p_vendor_name    IN VARCHAR2,
                                       p_requestor_name IN VARCHAR2) -- 2.0
   RETURN NUMBER IS
    v_body1   VARCHAR2(128) := 'Attached you will find the cancelled PO ';
    v_body1_1 VARCHAR2(128) := ' due to one or more of the following reasons: ';
    v_body2   VARCHAR2(128) := '     - Requestor informed us to cancel the order ';
    v_body3   VARCHAR2(128) := '     - Vendor name incorrect ';
    v_body4   VARCHAR2(128) := '     - Failure to deliver order(s) due to stock unavailability or unpaid accounts ';
    v_body5   VARCHAR2(128) := '     - Transaction failure ';
    v_body6   VARCHAR2(128) := 'TeleTech will not be expecting any invoices to match this PO. ';
    v_body7   VARCHAR2(128) := 'Please contact the TeleTech Procurement Department at procurement@teletech.com with any questions/concerns regarding this ';
    v_body8   VARCHAR2(128) := 'Purchase Order.';
  BEGIN
    g_body_main := NULL;
    g_body_main := p_vendor_name || g_cr || g_crlf || v_body1 ||
                   p_po_number || v_body1_1 || g_crlf || v_body2 || g_crlf ||
                   v_body3 || g_crlf || v_body4 || g_crlf || v_body5 || g_cr ||
                   g_crlf || v_body6 || g_cr || g_crlf || v_body7 || g_crlf ||
                   v_body8 || g_cr || g_crlf;
    RETURN(0);
  END ttec_build_msg_body_phl_can;
/* 10.0 Begin */
  FUNCTION ttec_build_msg_body_latam_can(p_po_number      IN VARCHAR2,
                                      p_vendor_name    IN VARCHAR2,
                                      p_requestor_name IN VARCHAR2)
   RETURN NUMBER IS
    v_body1   VARCHAR2(128) := 'Adjunta se encuentra la Orden de Compra numero ';
    v_body1_1 VARCHAR2(128) := ' cancelada debido a alguna de las ';
    v_body2   VARCHAR2(128) := 'siguientes razones: ';
    v_body3   VARCHAR2(128) := '     - El solicitante nos pidio cancelacion ';
    v_body4   VARCHAR2(128) := '     - Nombre de Proveedor incorrecto. ';
    v_body5   VARCHAR2(128) := '     - Falta de stock o cuentas impagas. ';
    v_body6   VARCHAR2(128) := '     - Fallo en la transaccion. ';
    v_body7   VARCHAR2(128) := 'TTEC/TeleTech no recibira facturas para asociar a esta Orden de Compra. ';
    v_body8   VARCHAR2(128) := 'Por favor, contactar al departamento de Compras a GlobalProcurement@ttec.com por cualquier pregunta respecto de esta ';
    v_body9   VARCHAR2(128) := 'Orden de Compra.';
  BEGIN
    g_body_main := NULL;
    g_body_main := p_vendor_name || g_cr || g_crlf || v_body1 ||
                   p_po_number || v_body1_1 || g_crlf || v_body2 || g_crlf ||
                   v_body3 || g_crlf || v_body4 || g_crlf || v_body5 ||
                   g_crlf || v_body6 || g_cr || g_crlf || v_body7 || g_cr ||
                   g_crlf || v_body8 || g_crlf || v_body9 || g_cr || g_crlf;
    RETURN(0);
  END ttec_build_msg_body_latam_can;
  /* 10.0 End */
  FUNCTION ttec_build_msg_body_mx_can(p_po_number      IN VARCHAR2,
                                      p_vendor_name    IN VARCHAR2,
                                      p_requestor_name IN VARCHAR2) -- 2.0
   RETURN NUMBER IS
    v_body1   VARCHAR2(128) := 'Adjunta se encuentra la Orden de Compra numero ';
    v_body1_1 VARCHAR2(128) := ' cancelada debido a alguna de las ';
    v_body2   VARCHAR2(128) := 'siguientes razones: ';
    v_body3   VARCHAR2(128) := '     - El solicitante nos pidio cancelacion ';
    v_body4   VARCHAR2(128) := '     - Nombre de Proveedor incorrecto. ';
    v_body5   VARCHAR2(128) := '     - Falta de stock o cuentas impagas. ';
    v_body6   VARCHAR2(128) := '     - Fallo en la transaccion. ';
    v_body7   VARCHAR2(128) := 'TeleTech no recibira facturas para asociar a esta Orden de Compra. ';
    v_body8   VARCHAR2(128) := 'Por favor, contactar al departamento de Compras a procurement@teletech.com por cualquier pregunta respecto de esta ';
    v_body9   VARCHAR2(128) := 'Orden de Compra.';
  BEGIN
    g_body_main := NULL;
    g_body_main := p_vendor_name || g_cr || g_crlf || v_body1 ||
                   p_po_number || v_body1_1 || g_crlf || v_body2 || g_crlf ||
                   v_body3 || g_crlf || v_body4 || g_crlf || v_body5 ||
                   g_crlf || v_body6 || g_cr || g_crlf || v_body7 || g_cr ||
                   g_crlf || v_body8 || g_crlf || v_body9 || g_cr || g_crlf;
    RETURN(0);
  END ttec_build_msg_body_mx_can;

  FUNCTION ttec_build_msg_body_cr_can(p_po_number      IN VARCHAR2,
                                      p_vendor_name    IN VARCHAR2,
                                      p_requestor_name IN VARCHAR2) -- 2.0
   RETURN NUMBER IS
    v_body1   VARCHAR2(128) := 'Adjunta se encuentra la Orden de Compra numero ';
    v_body1_1 VARCHAR2(128) := ' cancelada debido a alguna de las ';
    v_body2   VARCHAR2(128) := 'siguientes razones: ';
    v_body3   VARCHAR2(128) := '     - El solicitante nos pidio cancelacion ';
    v_body4   VARCHAR2(128) := '     - Nombre de Proveedor incorrecto. ';
    v_body5   VARCHAR2(128) := '     - Falta de stock o cuentas impagas. ';
    v_body6   VARCHAR2(128) := '     - Fallo en la transaccion. ';
    v_body7   VARCHAR2(128) := 'TeleTech no recibira facturas para asociar a esta Orden de Compra. ';
    v_body8   VARCHAR2(128) := 'Por favor, contactar al departamento de Compras a procurement@teletech.com por cualquier pregunta respecto de esta ';
    v_body9   VARCHAR2(128) := 'Orden de Compra.';
  BEGIN
    g_body_main := NULL;
    g_body_main := p_vendor_name || g_cr || g_crlf || v_body1 ||
                   p_po_number || v_body1_1 || g_crlf || v_body2 || g_crlf ||
                   v_body3 || g_crlf || v_body4 || g_crlf || v_body5 ||
                   g_crlf || v_body6 || g_cr || g_crlf || v_body7 || g_cr ||
                   g_crlf || v_body8 || g_crlf || v_body9 || g_cr || g_crlf;
    RETURN(0);
  END ttec_build_msg_body_cr_can;

  /* 10.0 Begin -- Brazilian Portuguese */
  FUNCTION ttec_build_msg_body_ptb_can(p_po_number      IN VARCHAR2,
                                       p_vendor_name    IN VARCHAR2,
                                       p_requestor_name IN VARCHAR2) -- 2.0
  RETURN NUMBER IS
    v_body1   VARCHAR2(128) := 'Em anexo a Ordem de Compra número ';
    v_body1_1 VARCHAR2(128) := ' cancelada  devido a um ou mais motivos que ';
    v_body2   VARCHAR2(128) := 'seguem: ';
    v_body3   VARCHAR2(128) := '     - O requisitante solicitou o cancelamento. ';
    v_body4   VARCHAR2(128) := '     - Nome do fornecedor incorreto. ';
    v_body5   VARCHAR2(128) := '     - Impossibilidade de entrega da mercadoria devido a indisponibilidade ou contas não pagas. ';
    v_body6   VARCHAR2(128) := '     - Falha na transação. ';
    v_body7   VARCHAR2(128) := 'A TTEC/TeleTech não espera quaisquer faturas para esta OC. ';
    v_body8   VARCHAR2(128) := 'Em caso de dúvidas com relação a esta OC, favor contatar a área de Compras da TTEC/TeleTech através de ';
    v_body9   VARCHAR2(128) := 'procurement@TTEC.com.';
  BEGIN
    g_body_main := NULL;
    g_body_main := p_vendor_name || g_cr || g_crlf || v_body1 ||
                   p_po_number || v_body1_1 || g_crlf || v_body2 || g_crlf ||
                   v_body3 || g_crlf || v_body4 || g_crlf || v_body5 ||
                   g_crlf || v_body6 || g_cr || g_crlf || v_body7 || g_cr ||
                   g_crlf || v_body8 || g_crlf || v_body9 || g_cr || g_crlf;
    RETURN(0);
  END ttec_build_msg_body_ptb_can;
  /* 10.0 End */
  FUNCTION ttec_build_msg_body_brz_can(p_po_number      IN VARCHAR2,
                                       p_vendor_name    IN VARCHAR2,
                                       p_requestor_name IN VARCHAR2) -- 2.0
   RETURN NUMBER IS
    v_body1   VARCHAR2(128) := 'Em anexo a Ordem de Compra número ';
    v_body1_1 VARCHAR2(128) := ' cancelada  devido a um ou mais motivos que ';
    v_body2   VARCHAR2(128) := 'seguem: ';
    v_body3   VARCHAR2(128) := '     - O requisitante solicitou o cancelamento. ';
    v_body4   VARCHAR2(128) := '     - Nome do fornecedor incorreto. ';
    v_body5   VARCHAR2(128) := '     - Impossibilidade de entrega da mercadoria devido a indisponibilidade ou contas não pagas. ';
    v_body6   VARCHAR2(128) := '     - Falha na transação. ';
    v_body7   VARCHAR2(128) := 'A TeleTech não espera quaisquer faturas para esta OC. ';
    v_body8   VARCHAR2(128) := 'Em caso de dúvidas com relação a esta OC, favor contatar a área de Compras da TeleTech através de ';
    v_body9   VARCHAR2(128) := 'procurement@teletech.com.';

  BEGIN
    g_body_main := NULL;
    g_body_main := p_vendor_name || g_cr || g_crlf || v_body1 ||
                   p_po_number || v_body1_1 || g_crlf || v_body2 || g_crlf ||
                   v_body3 || g_crlf || v_body4 || g_crlf || v_body5 ||
                   g_crlf || v_body6 || g_cr || g_crlf || v_body7 || g_cr ||
                   g_crlf || v_body8 || g_crlf || v_body9 || g_cr || g_crlf;
    RETURN(0);
  END ttec_build_msg_body_brz_can;

  -- v 3.4 PRG messaging
  FUNCTION ttec_build_msg_body_prg_can(p_po_number      IN VARCHAR2,
                                       p_vendor_name    IN VARCHAR2,
                                       p_requestor_name IN VARCHAR2) -- 2.0
   RETURN NUMBER IS
    v_body1   VARCHAR2(128) := 'Attached you will find the cancelled PO ';
    v_body1_1 VARCHAR2(128) := ' due to one or more of the following reasons: ';
    v_body2   VARCHAR2(128) := '     - Requestor informed us to cancel the order ';
    v_body3   VARCHAR2(128) := '     - Vendor name incorrect ';
    v_body4   VARCHAR2(128) := '     - Failure to deliver order(s) due to stock unavailability or unpaid accounts ';
    v_body5   VARCHAR2(128) := '     - Transaction failure ';
    v_body6   VARCHAR2(128) := '1to1 Marketing LLC  will not be expecting any invoices to match this PO. ';
    v_body7   VARCHAR2(128) := 'Please contact our Procurement Department at procurement@teletech.com with any questions/concerns regarding this ';
    v_body8   VARCHAR2(128) := 'Purchase Order.';
  BEGIN
    g_body_main := NULL;
    g_body_main := p_vendor_name || g_cr || g_crlf || v_body1 ||
                   p_po_number || v_body1_1 || g_crlf || v_body2 || g_crlf ||
                   v_body3 || g_crlf || v_body4 || g_crlf || v_body5 || g_cr ||
                   g_crlf || v_body6 || g_cr || g_crlf || v_body7 || g_crlf ||
                   v_body8 || g_cr || g_crlf;
    RETURN(0);
  END ttec_build_msg_body_prg_can;

  -- Version 5.3 <Start>
  FUNCTION ttec_build_msg_prg_nonus_can(p_po_number      IN VARCHAR2,
                                        p_vendor_name    IN VARCHAR2,
                                        p_requestor_name IN VARCHAR2) -- 2.0
   RETURN NUMBER IS
    v_body1   VARCHAR2(128) := 'Attached you will find the cancelled PO ';
    v_body1_1 VARCHAR2(128) := ' due to one or more of the following reasons: ';
    v_body2   VARCHAR2(128) := '     - Requestor informed us to cancel the order ';
    v_body3   VARCHAR2(128) := '     - Vendor name incorrect ';
    v_body4   VARCHAR2(128) := '     - Failure to deliver order(s) due to stock unavailability or unpaid accounts ';
    v_body5   VARCHAR2(128) := '     - Transaction failure ';
    v_body6   VARCHAR2(128) := 'Peppers and Rogers Group will not be expecting any invoices to match this PO. ';
    v_body7   VARCHAR2(128) := 'Please contact our Procurement Department at procurement@teletech.com with any questions/concerns regarding this ';
    v_body8   VARCHAR2(128) := 'Purchase Order.';
  BEGIN
    g_body_main := NULL;
    g_body_main := p_vendor_name || g_cr || g_crlf || v_body1 ||
                   p_po_number || v_body1_1 || g_crlf || v_body2 || g_crlf ||
                   v_body3 || g_crlf || v_body4 || g_crlf || v_body5 || g_cr ||
                   g_crlf || v_body6 || g_cr || g_crlf || v_body7 || g_crlf ||
                   v_body8 || g_cr || g_crlf;
    RETURN(0);
  END ttec_build_msg_prg_nonus_can;

  -- Version 5.3 <End>

  -- Version 9.1<Start>
  FUNCTION ttec_build_msg_ttec_cnstg_can(p_po_number      IN VARCHAR2,
                                      p_vendor_name    IN VARCHAR2,
                                      p_requestor_name IN VARCHAR2)
   RETURN NUMBER IS
    v_body1   VARCHAR2(128) := 'Attached you will find the cancelled PO ';
    v_body1_1 VARCHAR2(128) := ' due to one or more of the following reasons: ';
    v_body2   VARCHAR2(128) := '     - Requestor informed us to cancel the order ';
    v_body3   VARCHAR2(128) := '     - Vendor name incorrect ';
    v_body4   VARCHAR2(128) := '     - Failure to deliver order(s) due to stock unavailability or unpaid accounts ';
    v_body5   VARCHAR2(128) := '     - Transaction failure ';
    v_body6   VARCHAR2(128) := 'TeleTech Consulting will not be expecting any invoices to match this PO. ';
    v_body7   VARCHAR2(128) := 'Please contact our Procurement Department at procurement@teletech.com with any questions/concerns regarding this ';
    v_body8   VARCHAR2(128) := 'Purchase Order.';
  BEGIN
    g_body_main := NULL;
    g_body_main := p_vendor_name || g_cr || g_crlf || v_body1 ||
                   p_po_number || v_body1_1 || g_crlf || v_body2 || g_crlf ||
                   v_body3 || g_crlf || v_body4 || g_crlf || v_body5 || g_cr ||
                   g_crlf || v_body6 || g_cr || g_crlf || v_body7 || g_crlf ||
                   v_body8 || g_cr || g_crlf;
    RETURN(0);
  END ttec_build_msg_ttec_cnstg_can;
  -- Version 9.1 <End>
  FUNCTION ttec_build_msg_body_us_rev(p_po_number      IN VARCHAR2,
                                      p_vendor_name    IN VARCHAR2,
                                      p_requestor_name IN VARCHAR2) -- 2.0
   RETURN NUMBER IS
    v_body1   VARCHAR2(128) := 'Attached you will find the REVISED Purchase Order ';
    v_body1_1 VARCHAR2(128) := ' due to one or more of the following reasons: ';
    v_body2   VARCHAR2(128) := '     - Change order details such as description, quantity or amount ';
    v_body3   VARCHAR2(128) := '     - Incorrect vendor email address ';
    v_body4   VARCHAR2(128) := '     - Additional order(s) on the Purchase Order ';
    v_body5   VARCHAR2(128) := 'For questions regarding this Purchase Order, contact our Procurement Department via email GlobalProcurement@TTEC.com. ';
    v_body6   VARCHAR2(128) := 'Invoices related to this Purchase Order should be submitted to the Accounts Payable Department via email ';
    v_body7   VARCHAR2(130) := 'APInvoices@teletech.com. Payment inquiries can be emailed to APInquiries@teletech.com or by calling +1.303.397.9390. For faster ';
    v_body8   VARCHAR2(128) := 'service, always remember to reference the Purchase Order Number when contacting TeleTech.s Accounts Payable Department. ';
    v_body9   VARCHAR2(128) := 'In addition, please ensure that your shipping label reflects the Purchase Order number and the name of the order requestor. ';
    v_body10  VARCHAR2(128) := 'Items may be rejected by our receiving dock if shipments are not adequately documented with this information. ';
    v_body11  VARCHAR2(128) := ' - When goods/services are received, you will need to acknowledge receipt on the Purchase Order to ';
    v_body12  VARCHAR2(128) := 'facilitate the timely and accurate processing of payment to the supplier. ';
  BEGIN
    g_body_main := NULL;
    g_body_main := p_vendor_name || g_cr || g_crlf || v_body1 ||
                   p_po_number || v_body1_1 || g_crlf || v_body2 || g_crlf ||
                   v_body3 || g_crlf || v_body4 || g_cr || g_crlf ||
                   v_body5 || g_cr || g_crlf || v_body6 || g_crlf ||
                   v_body7 || g_crlf || v_body8 || g_cr || g_crlf ||
                   v_body9 || g_crlf || v_body10 || g_cr || g_crlf ||
                   p_requestor_name || v_body11 || g_crlf || v_body12 || g_cr ||
                   g_crlf;
    RETURN(0);
  END ttec_build_msg_body_us_rev;
/* 9.5 Begin */
  FUNCTION ttec_build_msg_body_us_rev1(p_po_number      IN VARCHAR2,
                                      p_vendor_name    IN VARCHAR2,
                                      p_requestor_name IN VARCHAR2) -- 2.0
   RETURN NUMBER IS
    v_body1   VARCHAR2(128) := 'Attached you will find the REVISED Purchase Order ';
    v_body1_1 VARCHAR2(128) := ' due to one or more of the following reasons: ';
    v_body2   VARCHAR2(128) := '     - Change order details such as description, quantity or amount ';
    v_body3   VARCHAR2(128) := '     - Incorrect vendor email address ';
    v_body4   VARCHAR2(128) := '     - Additional order(s) on the Purchase Order ';
    v_body5   VARCHAR2(128) := 'For questions regarding this Purchase Order, contact our Procurement Department via email GlobalProcurement@TTEC.com. ';
    v_body6   VARCHAR2(128) := 'Invoices related to this Purchase Order should be submitted to the Accounts Payable Department via email ';
    v_body7   VARCHAR2(128) := 'APInvoices@TTEC.com. Payment inquiries can be emailed to APInquiries@TTEC.com or by calling +1.303.397.9390. For faster ';
    v_body8   VARCHAR2(128) := 'service, always remember to reference the Purchase Order Number when contacting TTEC/TeleTech.s Accounts Payable Department. ';
    v_body9   VARCHAR2(128) := 'In addition, please ensure that your shipping label reflects the Purchase Order number and the name of the order requestor. ';
    v_body10  VARCHAR2(128) := 'Items may be rejected by our receiving dock if shipments are not adequately documented with this information. ';
    v_body11  VARCHAR2(128) := ' - When goods/services are received, you will need to acknowledge receipt on the Purchase Order to ';
    v_body12  VARCHAR2(128) := 'facilitate the timely and accurate processing of payment to the supplier. ';
  BEGIN
    g_body_main := NULL;
    g_body_main := p_vendor_name || g_cr || g_crlf || v_body1 ||
                   p_po_number || v_body1_1 || g_crlf || v_body2 || g_crlf ||
                   v_body3 || g_crlf || v_body4 || g_cr || g_crlf ||
                   v_body5 || g_cr || g_crlf || v_body6 || g_crlf ||
                   v_body7 || g_crlf || v_body8 || g_cr || g_crlf ||
                   v_body9 || g_crlf || v_body10 || g_cr || g_crlf ||
                   p_requestor_name || v_body11 || g_crlf || v_body12 || g_cr ||
                   g_crlf;
    RETURN(0);
  END ttec_build_msg_body_us_rev1;
/* 9.5 End */

/* 9.7 Begin */
  FUNCTION ttec_build_msg_body_global_rev(p_po_number      IN VARCHAR2,
                                      p_vendor_name    IN VARCHAR2,
                                      p_requestor_name IN VARCHAR2) -- 2.0
   RETURN NUMBER IS
    v_body1   VARCHAR2(128) := 'Attached you will find the REVISED Purchase Order ';
    v_body1_1 VARCHAR2(128) := ' due to one or more of the following reasons: ';
    v_body2   VARCHAR2(128) := '     - Change order details such as description, quantity or amount ';
    v_body3   VARCHAR2(128) := '     - Incorrect vendor email address ';
    v_body4   VARCHAR2(128) := '     - Additional order(s) on the Purchase Order ';
    v_body5   VARCHAR2(128) := 'For questions regarding this Purchase Order, contact our Procurement Department via email GlobalProcurement@TTEC.com. ';
    v_body6   VARCHAR2(128) := 'Invoices related to this Purchase Order should be submitted to the Accounts Payable Department via email ';
    v_body7   VARCHAR2(130) := 'APInvoiceSubmission@TTEC.com. Payment inquiries can be emailed to APInquiries@TTEC.com or by calling +1.303.397.9390. For faster ';
    v_body8   VARCHAR2(128) := 'service, always remember to reference the Purchase Order Number when contacting TTEC''s Accounts Payable Department. ';
    v_body9   VARCHAR2(128) := 'In addition, please ensure that your shipping label reflects the Purchase Order number and the name of the order requestor. ';
    v_body10  VARCHAR2(128) := 'Items may be rejected by our receiving dock if shipments are not adequately documented with this information. ';
    v_body11  VARCHAR2(128) := ' - When goods/services are received, you will need to acknowledge receipt on the Purchase Order to ';
    v_body12  VARCHAR2(128) := 'facilitate the timely and accurate processing of payment to the supplier. ';
  BEGIN
    g_body_main := NULL;
    g_body_main := p_vendor_name || g_cr || g_crlf || v_body1 ||
                   p_po_number || v_body1_1 || g_crlf || v_body2 || g_crlf ||
                   v_body3 || g_crlf || v_body4 || g_cr || g_crlf ||
                   v_body5 || g_cr || g_crlf || v_body6 || g_crlf ||
                   v_body7 || g_crlf || v_body8 || g_cr || g_crlf ||
                   v_body9 || g_crlf || v_body10 || g_cr || g_crlf ||
                   p_requestor_name || v_body11 || g_crlf || v_body12 || g_cr ||
                   g_crlf;
    RETURN(0);
  END ttec_build_msg_body_global_rev;
/* 9.7 End */

  FUNCTION ttec_build_msg_body_arg_rev(p_po_number      IN VARCHAR2,
                                       p_vendor_name    IN VARCHAR2,
                                       p_requestor_name IN VARCHAR2) -- 2.0
   RETURN NUMBER IS
    v_body1   VARCHAR2(128) := 'Adjunto encontrará la versión revisada de la orden de compra ';
    v_body1_1 VARCHAR2(128) := ' debido a una o más de las ';
    v_body2   VARCHAR2(128) := 'siguientes razones: ';
    v_body3   VARCHAR2(128) := '     - Variación de los datos de la orden tales como la descripción, la cantidad o monto. ';
    v_body4   VARCHAR2(128) := '     - Dirección de correo electrónico incorrecta del proveedor. ';
    v_body5   VARCHAR2(128) := '     - Orden(es) adicional(es) en la orden de compra. ';
    v_body6   VARCHAR2(200) := 'Para preguntas con respecto a esta orden de compra, póngase en contacto con nuestro Departamento de Compras a través de correo electrónico  ';
    v_body7   VARCHAR2(128) := 'GlobalSupplyChain@TTEC.com. ';
    v_body8   VARCHAR2(128) := 'Las facturas relacionadas a esta orden de compra ';
    v_body9   VARCHAR2(128) := 'se debe(n) enviar a departamento de Cuentas a Pagar a través del correo electrónico APInvoicesInquiries@Teletech.com. ';
    v_body10  VARCHAR2(200) := 'Al igual que las consultas sobre pagos que pueden ser enviadas por correo electrónico a APInvoicesInquiries@Teletech.com o llamando al +1.303.397.9390.';
    v_body11  VARCHAR2(128) := 'Para un servicio más rápido, recuerde siempre hacer referencia al número de orden de compra ';
    v_body12   VARCHAR2(128) := 'cuando se comunique al departamento de Cuentas por Pagar de TeleTech. ';
    v_body13   VARCHAR2(128) := 'Además, asegúrese de que su etiqueta de envío refleja el número de orden de compra ';
    v_body14   VARCHAR2(128) := 'y el nombre del solicitante orden. ';
    v_body15  VARCHAR2(200) := 'Los artículos pueden ser rechazados por nuestro departamento de recepción si los envíos no contienen esta información adecuadamente.';
    v_body16  VARCHAR2(128) := '- Cuando los bienes o servicios se reciben, se deberá acusar ';
    v_body17  VARCHAR2(128) := 'de recibo de la orden de compra para facilitar ';
    v_body18  VARCHAR2(128) := 'el tratamiento oportuno de pago al proveedor.';
  BEGIN
    g_body_main := NULL;
    g_body_main := p_vendor_name || g_cr || g_crlf || v_body1 ||
                   p_po_number || v_body1_1 || g_crlf || v_body2 || g_crlf ||
                   v_body3 || g_crlf || v_body4 || g_crlf || v_body5 || g_cr ||
                   g_crlf || v_body6 || g_crlf || v_body7 || g_cr || g_crlf ||
                   v_body8 || v_body9 || v_body10 ||
                   g_crlf || v_body11 || v_body12 || g_crlf ||
                   v_body13 || v_body14 || g_crlf ||
                   v_body15 || g_crlf || p_requestor_name ||v_body16 || v_body17 || v_body18 || g_cr ||
                   g_crlf;
    RETURN(0);
  END ttec_build_msg_body_arg_rev;

  FUNCTION ttec_build_msg_body_spn_rev(p_po_number      IN VARCHAR2,
                                       p_vendor_name    IN VARCHAR2,
                                       p_requestor_name IN VARCHAR2) -- 2.0
   RETURN NUMBER IS
   v_body1   VARCHAR2(128) := 'Adjunto encontrará la versión revisada de la orden de compra ';
    v_body1_1 VARCHAR2(128) := ' debido a una o más de las ';
    v_body2   VARCHAR2(128) := 'siguientes razones: ';
    v_body3   VARCHAR2(128) := '     - Variación de los datos de la orden tales como la descripción, la cantidad o monto. ';
    v_body4   VARCHAR2(128) := '     - Dirección de correo electrónico incorrecta del proveedor. ';
    v_body5   VARCHAR2(128) := '     - Orden(es) adicional(es) en la orden de compra. ';
    v_body6   VARCHAR2(200) := 'Para preguntas con respecto a esta orden de compra, póngase en contacto con nuestro Departamento de Compras a través de correo electrónico  ';
    v_body7   VARCHAR2(128) := 'GlobalSupplyChain@TTEC.com. ';
    v_body8   VARCHAR2(128) := 'Las facturas relacionadas a esta orden de compra ';
    v_body9   VARCHAR2(128) := 'se debe(n) enviar a departamento de Cuentas a Pagar a través del correo electrónico APInvoicesInquiries@Teletech.com. ';
    v_body10  VARCHAR2(200) := 'Al igual que las consultas sobre pagos que pueden ser enviadas por correo electrónico a APInvoicesInquiries@Teletech.com o llamando al +1.303.397.9390.';
    v_body11  VARCHAR2(128) := 'Para un servicio más rápido, recuerde siempre hacer referencia al número de orden de compra ';
    v_body12   VARCHAR2(128) := 'cuando se comunique al departamento de Cuentas por Pagar de TeleTech. ';
    v_body13   VARCHAR2(128) := 'Además, asegúrese de que su etiqueta de envío refleja el número de orden de compra ';
    v_body14   VARCHAR2(128) := 'y el nombre del solicitante orden. ';
    v_body15  VARCHAR2(200) := 'Los artículos pueden ser rechazados por nuestro departamento de recepción si los envíos no contienen esta información adecuadamente.';
    v_body16  VARCHAR2(128) := '- Cuando los bienes o servicios se reciben, se deberá acusar ';
    v_body17  VARCHAR2(128) := 'de recibo de la orden de compra para facilitar ';
    v_body18  VARCHAR2(128) := 'el tratamiento oportuno de pago al proveedor.';
  BEGIN
    g_body_main := NULL;
    g_body_main := p_vendor_name || g_cr || g_crlf || v_body1 ||
                   p_po_number || v_body1_1 || g_crlf || v_body2 || g_crlf ||
                   v_body3 || g_crlf || v_body4 || g_crlf || v_body5 || g_cr ||
                   g_crlf || v_body6 || g_crlf || v_body7 || g_cr || g_crlf ||
                   v_body8 || v_body9 || v_body10 ||
                   g_crlf || v_body11 || v_body12 || g_crlf ||
                   v_body13 || v_body14 || g_crlf ||
                   v_body15 || g_crlf || p_requestor_name ||v_body16 || v_body17 || v_body18 || g_cr ||
                   g_crlf;
    RETURN(0);
  END ttec_build_msg_body_spn_rev;

  FUNCTION ttec_build_msg_body_phl_rev(p_po_number      IN VARCHAR2,
                                       p_vendor_name    IN VARCHAR2,
                                       p_requestor_name IN VARCHAR2) -- 2.0

   RETURN NUMBER IS
    v_body1   VARCHAR2(128) := 'Attached you will find the REVISED Purchase Order ';
    v_body1_1 VARCHAR2(128) := ' due to one or more of the following reasons: ';
    v_body2   VARCHAR2(128) := '     - Change order details such as description, quantity or amount ';
    v_body3   VARCHAR2(128) := '     - Incorrect vendor email address ';
    v_body4   VARCHAR2(128) := '     - Additional order(s) on the Purchase Order ';
    v_body5   VARCHAR2(128) := 'For questions regarding this Purchase Order, contact our Procurement Department via email GlobalProcurement@TTEC.com. ';--procurement@teletech.com.';
    v_body6   VARCHAR2(128) := 'Invoices related to this Purchase Order should be submitted to the Accounts Payable Department via email ';
    v_body7   VARCHAR2(128) := 'APInvoices@TTEC.com. Payment inquiries can be emailed to APInquiries@TTEC.com or by calling 02.902.7207. For faster ';
    v_body8   VARCHAR2(128) := 'service, always remember to reference the Purchase Order Number when contacting TeleTech.s Accounts Payable Department. ';
    v_body9   VARCHAR2(128) := 'In addition, please ensure that your shipping label reflects the Purchase Order number and the name of the order requestor. ';
    v_body10  VARCHAR2(128) := 'Items may be rejected by our receiving dock if shipments are not adequately documented with this information. ';
    v_body11  VARCHAR2(128) := ' - When goods/services are received, you will need to acknowledge receipt on the Purchase Order to ';
    v_body12  VARCHAR2(128) := 'facilitate the timely and accurate processing of payment to the supplier. ';
  BEGIN
    g_body_main := NULL;
    g_body_main := p_vendor_name || g_cr || g_crlf || v_body1 ||
                   p_po_number || v_body1_1 || g_crlf || v_body2 || g_crlf ||
                   v_body3 || g_crlf || v_body4 || g_cr || g_crlf ||
                   v_body5 || g_cr || g_crlf || v_body6 || g_crlf ||
                   v_body7 || g_crlf || v_body8 || g_cr || g_crlf ||
                   v_body9 || g_crlf || v_body10 || g_cr || g_crlf ||
                   p_requestor_name || v_body11 || g_crlf || v_body12 || g_cr ||
                   g_crlf;
    RETURN(0);
  END ttec_build_msg_body_phl_rev;
  /* 10.0 Begin */
  FUNCTION ttec_build_msg_body_latam_rev(p_po_number      IN VARCHAR2,
                                         p_vendor_name    IN VARCHAR2,
                                         p_requestor_name IN VARCHAR2)
   RETURN NUMBER IS
   v_body1   VARCHAR2(128) := 'Adjunto encontrará la versión revisada de la orden de compra ';
    v_body1_1 VARCHAR2(128) := ' debido a una o más de las ';
    v_body2   VARCHAR2(128) := 'siguientes razones: ';
    v_body3   VARCHAR2(128) := '     - Variación de los datos de la orden tales como la descripción, la cantidad o monto. ';
    v_body4   VARCHAR2(128) := '     - Dirección de correo electrónico incorrecta del proveedor. ';
    v_body5   VARCHAR2(128) := '     - Orden(es) adicional(es) en la orden de compra. ';
    v_body6   VARCHAR2(200) := 'Para preguntas con respecto a esta orden de compra, póngase en contacto con nuestro Departamento de Compras a través de correo electrónico  ';
    v_body7   VARCHAR2(128) := 'GlobalProcurement@ttec.com. ';
    v_body8   VARCHAR2(128) := 'Las facturas relacionadas a esta orden de compra ';
    v_body9   VARCHAR2(128) := 'se debe(n) enviar a departamento de Cuentas a Pagar a través del correo electrónico APInvoicesInquiries@TTEC.com. ';
    v_body10  VARCHAR2(200) := 'Al igual que las consultas sobre pagos que pueden ser enviadas por correo electrónico a APInvoicesInquiries@TTEC.com o llamando al +1.303.397.9390.';
    v_body11  VARCHAR2(128) := 'Para un servicio más rápido, recuerde siempre hacer referencia al número de orden de compra ';
    v_body12   VARCHAR2(128) := 'cuando se comunique al departamento de Cuentas por Pagar de TTEC/TeleTech. ';
    v_body13   VARCHAR2(128) := 'Además, asegúrese de que su etiqueta de envío refleja el número de orden de compra ';
    v_body14   VARCHAR2(128) := 'y el nombre del solicitante orden. ';
    v_body15  VARCHAR2(200) := 'Los artículos pueden ser rechazados por nuestro departamento de recepción si los envíos no contienen esta información adecuadamente.';
    v_body16  VARCHAR2(128) := '- Cuando los bienes o servicios se reciben, se deberá acusar ';
    v_body17  VARCHAR2(128) := 'de recibo de la orden de compra para facilitar ';
    v_body18  VARCHAR2(128) := 'el tratamiento oportuno de pago al proveedor.';
  BEGIN
    g_body_main := NULL;
    g_body_main := p_vendor_name || g_cr || g_crlf || v_body1 ||
                   p_po_number || v_body1_1 || g_crlf || v_body2 || g_crlf ||
                   v_body3 || g_crlf || v_body4 || g_crlf || v_body5 || g_cr ||
                   g_crlf || v_body6 || g_crlf || v_body7 || g_cr || g_crlf ||
                   v_body8 || v_body9 || v_body10 ||
                   g_crlf || v_body11 || v_body12 || g_crlf ||
                   v_body13 || v_body14 || g_crlf ||
                   v_body15 || g_crlf || p_requestor_name ||v_body16 || v_body17 || v_body18 || g_cr ||
                   g_crlf;

    RETURN(0);
  END ttec_build_msg_body_latam_rev;
  /* 10.0 End */
  FUNCTION ttec_build_msg_body_mx_rev(p_po_number      IN VARCHAR2,
                                      p_vendor_name    IN VARCHAR2,
                                      p_requestor_name IN VARCHAR2) -- 2.0
   RETURN NUMBER IS
   v_body1   VARCHAR2(128) := 'Adjunto encontrará la versión revisada de la orden de compra ';
    v_body1_1 VARCHAR2(128) := ' debido a una o más de las ';
    v_body2   VARCHAR2(128) := 'siguientes razones: ';
    v_body3   VARCHAR2(128) := '     - Variación de los datos de la orden tales como la descripción, la cantidad o monto. ';
    v_body4   VARCHAR2(128) := '     - Dirección de correo electrónico incorrecta del proveedor. ';
    v_body5   VARCHAR2(128) := '     - Orden(es) adicional(es) en la orden de compra. ';
    v_body6   VARCHAR2(200) := 'Para preguntas con respecto a esta orden de compra, póngase en contacto con nuestro Departamento de Compras a través de correo electrónico  ';
    v_body7   VARCHAR2(128) := 'GlobalSupplyChain@TTEC.com. ';
    v_body8   VARCHAR2(128) := 'Las facturas relacionadas a esta orden de compra ';
    v_body9   VARCHAR2(128) := 'se debe(n) enviar a departamento de Cuentas a Pagar a través del correo electrónico APInvoicesInquiries@Teletech.com. ';
    v_body10  VARCHAR2(200) := 'Al igual que las consultas sobre pagos que pueden ser enviadas por correo electrónico a APInvoicesInquiries@Teletech.com o llamando al +1.303.397.9390.';
    v_body11  VARCHAR2(128) := 'Para un servicio más rápido, recuerde siempre hacer referencia al número de orden de compra ';
    v_body12   VARCHAR2(128) := 'cuando se comunique al departamento de Cuentas por Pagar de TeleTech. ';
    v_body13   VARCHAR2(128) := 'Además, asegúrese de que su etiqueta de envío refleja el número de orden de compra ';
    v_body14   VARCHAR2(128) := 'y el nombre del solicitante orden. ';
    v_body15  VARCHAR2(200) := 'Los artículos pueden ser rechazados por nuestro departamento de recepción si los envíos no contienen esta información adecuadamente.';
    v_body16  VARCHAR2(128) := '- Cuando los bienes o servicios se reciben, se deberá acusar ';
    v_body17  VARCHAR2(128) := 'de recibo de la orden de compra para facilitar ';
    v_body18  VARCHAR2(128) := 'el tratamiento oportuno de pago al proveedor.';
  BEGIN
    g_body_main := NULL;
    g_body_main := p_vendor_name || g_cr || g_crlf || v_body1 ||
                   p_po_number || v_body1_1 || g_crlf || v_body2 || g_crlf ||
                   v_body3 || g_crlf || v_body4 || g_crlf || v_body5 || g_cr ||
                   g_crlf || v_body6 || g_crlf || v_body7 || g_cr || g_crlf ||
                   v_body8 || v_body9 || v_body10 ||
                   g_crlf || v_body11 || v_body12 || g_crlf ||
                   v_body13 || v_body14 || g_crlf ||
                   v_body15 || g_crlf || p_requestor_name ||v_body16 || v_body17 || v_body18 || g_cr ||
                   g_crlf;

    RETURN(0);
  END ttec_build_msg_body_mx_rev;

  FUNCTION ttec_build_msg_body_cr_rev(p_po_number      IN VARCHAR2,
                                      p_vendor_name    IN VARCHAR2,
                                      p_requestor_name IN VARCHAR2) -- 2.0
   RETURN NUMBER IS
   v_body1   VARCHAR2(128) := 'Adjunto encontrará la versión revisada de la orden de compra ';
    v_body1_1 VARCHAR2(128) := ' debido a una o más de las ';
    v_body2   VARCHAR2(128) := 'siguientes razones: ';
    v_body3   VARCHAR2(128) := '     - Variación de los datos de la orden tales como la descripción, la cantidad o monto. ';
    v_body4   VARCHAR2(128) := '     - Dirección de correo electrónico incorrecta del proveedor. ';
    v_body5   VARCHAR2(128) := '     - Orden(es) adicional(es) en la orden de compra. ';
    v_body6   VARCHAR2(200) := 'Para preguntas con respecto a esta orden de compra, póngase en contacto con nuestro Departamento de Compras a través de correo electrónico  ';
    v_body7   VARCHAR2(128) := 'GlobalSupplyChain@TTEC.com. ';
    v_body8   VARCHAR2(128) := 'Las facturas relacionadas a esta orden de compra ';
    v_body9   VARCHAR2(128) := 'se debe(n) enviar a departamento de Cuentas a Pagar a través del correo electrónico APInvoicesInquiries@Teletech.com. ';
    v_body10  VARCHAR2(200) := 'Al igual que las consultas sobre pagos que pueden ser enviadas por correo electrónico a APInvoicesInquiries@Teletech.com o llamando al +1.303.397.9390.';
    v_body11  VARCHAR2(128) := 'Para un servicio más rápido, recuerde siempre hacer referencia al número de orden de compra ';
    v_body12   VARCHAR2(128) := 'cuando se comunique al departamento de Cuentas por Pagar de TeleTech. ';
    v_body13   VARCHAR2(128) := 'Además, asegúrese de que su etiqueta de envío refleja el número de orden de compra ';
    v_body14   VARCHAR2(128) := 'y el nombre del solicitante orden. ';
    v_body15  VARCHAR2(200) := 'Los artículos pueden ser rechazados por nuestro departamento de recepción si los envíos no contienen esta información adecuadamente.';
    v_body16  VARCHAR2(128) := '- Cuando los bienes o servicios se reciben, se deberá acusar ';
    v_body17  VARCHAR2(128) := 'de recibo de la orden de compra para facilitar ';
    v_body18  VARCHAR2(128) := 'el tratamiento oportuno de pago al proveedor.';
  BEGIN
    g_body_main := NULL;
    g_body_main := p_vendor_name || g_cr || g_crlf || v_body1 ||
                   p_po_number || v_body1_1 || g_crlf || v_body2 || g_crlf ||
                   v_body3 || g_crlf || v_body4 || g_crlf || v_body5 || g_cr ||
                   g_crlf || v_body6 || g_crlf || v_body7 || g_cr || g_crlf ||
                   v_body8 || v_body9 || v_body10 ||
                   g_crlf || v_body11 || v_body12 || g_crlf ||
                   v_body13 || v_body14 || g_crlf ||
                   v_body15 || g_crlf || p_requestor_name ||v_body16 || v_body17 || v_body18 || g_cr ||
                   g_crlf;
    RETURN(0);
  END ttec_build_msg_body_cr_rev;
  /* 10.0 Begin */
  FUNCTION ttec_build_msg_body_ptb_rev(p_po_number      IN VARCHAR2,
                                       p_vendor_name    IN VARCHAR2,
                                       p_requestor_name IN VARCHAR2) -- 2.0
   RETURN NUMBER IS
    v_body1   VARCHAR2(128) := 'Em anexo a Ordem de Compra número ';
    v_body1_1 VARCHAR2(128) := ' alterada devido a um ou mais motivos que ';
    v_body2   VARCHAR2(128) := 'seguem: ';
    v_body3   VARCHAR2(128) := '     - Mudança nos detalhes de compra como por exemplo: descrição, quantidade ou montante. ';
    v_body4   VARCHAR2(128) := '     - Endereço de e-mail do fornecedor incorreto. ';
    v_body5   VARCHAR2(128) := '     - Pedidos adicionais a Ordem de Compra. ';
    v_body6   VARCHAR2(128) := 'Qualquer consulta a respeito dessa Ordem de Compra, favor contatar o Requisitante. ';
    v_body7   VARCHAR2(128) := 'As notas fiscais referentes a essa Ordem de Compra devem ser enviadas ao Requisitante até o dia 19. Para um  melhor ';
    v_body8   VARCHAR2(128) := 'processamento das notas fiscais, por favor, fazer referência ao número de Ordem de Compra e o nome do requisitante ao ';
    v_body9   VARCHAR2(128) := 'contatar o Departamento de Compras da TTEC/TeleTech.';
    v_body10  VARCHAR2(128) := 'Por favor, certifique-se também que na sua nota fiscal conste o número da Ordem de Compra e o nome do requisitante. A ';
    v_body11  VARCHAR2(128) := 'mercadoria poderá ser devolvida se esta informação não constar na Nota Fiscal. ';


  BEGIN
    g_body_main := NULL;
    g_body_main := p_vendor_name || g_cr || g_crlf || v_body1 ||
                   p_po_number || v_body1_1 || g_crlf || v_body2 || g_crlf ||
                   v_body3 || g_crlf || v_body4 || g_crlf || v_body5 || g_cr ||
                   g_crlf || v_body6 || g_cr || g_crlf || v_body7 || g_crlf ||
                   v_body8 || g_crlf || v_body9 || g_cr || g_crlf ||
                   v_body10 || g_crlf || v_body11 || g_cr || g_crlf;
    RETURN(0);
  END ttec_build_msg_body_ptb_rev;
  /* 10.0 End */
  FUNCTION ttec_build_msg_body_brz_rev(p_po_number      IN VARCHAR2,
                                       p_vendor_name    IN VARCHAR2,
                                       p_requestor_name IN VARCHAR2) -- 2.0
   RETURN NUMBER IS
    v_body1   VARCHAR2(128) := 'Em anexo a Ordem de Compra número ';
    v_body1_1 VARCHAR2(128) := ' alterada devido a um ou mais motivos que ';
    v_body2   VARCHAR2(128) := 'seguem: ';
    v_body3   VARCHAR2(128) := '     - Mudança nos detalhes de compra como por exemplo: descrição, quantidade ou montante. ';
    v_body4   VARCHAR2(128) := '     - Endereço de e-mail do fornecedor incorreto. ';
    v_body5   VARCHAR2(128) := '     - Pedidos adicionais a Ordem de Compra. ';
    v_body6   VARCHAR2(128) := 'Qualquer consulta a respeito dessa Ordem de Compra, favor contatar o Requisitante. ';
    v_body7   VARCHAR2(128) := 'As notas fiscais referentes a essa Ordem de Compra devem ser enviadas ao Requisitante até o dia 19. Para um  melhor ';
    v_body8   VARCHAR2(128) := 'processamento das notas fiscais, por favor, fazer referência ao número de Ordem de Compra e o nome do requisitante ao ';
    v_body9   VARCHAR2(128) := 'contatar o Departamento de Compras da TeleTech.';
    v_body10  VARCHAR2(128) := 'Por favor, certifique-se também que na sua nota fiscal conste o número da Ordem de Compra e o nome do requisitante. A ';
    v_body11  VARCHAR2(128) := 'mercadoria poderá ser devolvida se esta informação não constar na Nota Fiscal. ';

  BEGIN
    g_body_main := NULL;
    g_body_main := p_vendor_name || g_cr || g_crlf || v_body1 ||
                   p_po_number || v_body1_1 || g_crlf || v_body2 || g_crlf ||
                   v_body3 || g_crlf || v_body4 || g_crlf || v_body5 || g_cr ||
                   g_crlf || v_body6 || g_cr || g_crlf || v_body7 || g_crlf ||
                   v_body8 || g_crlf || v_body9 || g_cr || g_crlf ||
                   v_body10 || g_crlf || v_body11 || g_cr || g_crlf;
    RETURN(0);
  END ttec_build_msg_body_brz_rev;

  -- v 3.4 PRG messaging
  FUNCTION ttec_build_msg_body_prg_rev(p_po_number      IN VARCHAR2,
                                       p_vendor_name    IN VARCHAR2,
                                       p_requestor_name IN VARCHAR2) -- 2.0
   RETURN NUMBER IS
    v_body1   VARCHAR2(128) := 'Attached you will find the REVISED Purchase Order ';
    v_body1_1 VARCHAR2(128) := ' due to one or more of the following reasons: ';
    v_body2   VARCHAR2(128) := '     - Change order details such as description, quantity or amount ';
    v_body3   VARCHAR2(128) := '     - Incorrect vendor email address ';
    v_body4   VARCHAR2(128) := '     - Additional order(s) on the Purchase Order ';
    v_body5   VARCHAR2(128) := 'For questions regarding this Purchase Order, contact our Procurement Department via email procurement@teletech.com. ';
    v_body6   VARCHAR2(128) := 'Invoices related to this Purchase Order should be submitted to the Accounts Payable Department via email ';
    v_body7   VARCHAR2(128) := 'APInvoices@teletech.com. Payment inquiries can be emailed to APInquiries@teletech.com or by calling +1.303.397.9390. For faster ';
    v_body8   VARCHAR2(128) := 'service, always remember to reference the Purchase Order Number when contacting the Accounts Payable Department. ';
    v_body9   VARCHAR2(128) := 'In addition, please ensure that your shipping label reflects the Purchase Order number and the name of the order requestor. ';
    v_body10  VARCHAR2(128) := 'Items may be rejected by our receiving dock if shipments are not adequately documented with this information. ';
    v_body11  VARCHAR2(128) := ' - When goods/services are received, you will need to acknowledge receipt on the Purchase Order to ';
    v_body12  VARCHAR2(128) := 'facilitate the timely and accurate processing of payment to the supplier. ';
  BEGIN
    g_body_main := NULL;
    g_body_main := p_vendor_name || g_cr || g_crlf || v_body1 ||
                   p_po_number || v_body1_1 || g_crlf || v_body2 || g_crlf ||
                   v_body3 || g_crlf || v_body4 || g_cr || g_crlf ||
                   v_body5 || g_cr || g_crlf || v_body6 || g_crlf ||
                   v_body7 || g_crlf || v_body8 || g_cr || g_crlf ||
                   v_body9 || g_crlf || v_body10 || g_cr || g_crlf ||
                   p_requestor_name || v_body11 || g_crlf || v_body12 || g_cr ||
                   g_crlf;
    RETURN(0);
  END ttec_build_msg_body_prg_rev;

  -- Version 5.3 <Start>
  FUNCTION ttec_build_msg_prg_nonus_rev(p_po_number      IN VARCHAR2,
                                        p_vendor_name    IN VARCHAR2,
                                        p_requestor_name IN VARCHAR2) -- 2.0
   RETURN NUMBER IS
    v_body1   VARCHAR2(128) := 'Attached you will find the REVISED Purchase Order ';
    v_body1_1 VARCHAR2(128) := ' due to one or more of the following reasons: ';
    v_body2   VARCHAR2(128) := '     - Change order details such as description, quantity or amount ';
    v_body3   VARCHAR2(128) := '     - Incorrect vendor email address ';
    v_body4   VARCHAR2(128) := '     - Additional order(s) on the Purchase Order ';
    v_body5   VARCHAR2(128) := 'For questions regarding this Purchase Order, contact our Procurement Department via email GlobalSupplyChain@TTEC.com. ';
    v_body6   VARCHAR2(128) := 'Invoices related to this Purchase Order should be submitted to the Accounts Payable Department via email ';
    v_body7   VARCHAR2(128) := 'APInvoices@teletech.com. Payment inquiries can be emailed to APInquiries@teletech.com or by calling +1.303.397.9390. For faster ';
    v_body8   VARCHAR2(128) := 'service, always remember to reference the Purchase Order Number when contacting the Accounts Payable Department. ';
    v_body9   VARCHAR2(128) := 'In addition, please ensure that your shipping label reflects the Purchase Order number and the name of the order requestor. ';
    v_body10  VARCHAR2(128) := 'Items may be rejected by our receiving dock if shipments are not adequately documented with this information. ';
    v_body11  VARCHAR2(128) := ' - When goods/services are received, you will need to acknowledge receipt on the Purchase Order to ';
    v_body12  VARCHAR2(128) := 'facilitate the timely and accurate processing of payment to the supplier. ';
  BEGIN
    g_body_main := NULL;
    g_body_main := p_vendor_name || g_cr || g_crlf || v_body1 ||
                   p_po_number || v_body1_1 || g_crlf || v_body2 || g_crlf ||
                   v_body3 || g_crlf || v_body4 || g_cr || g_crlf ||
                   v_body5 || g_cr || g_crlf || v_body6 || g_crlf ||
                   v_body7 || g_crlf || v_body8 || g_cr || g_crlf ||
                   v_body9 || g_crlf || v_body10 || g_cr || g_crlf ||
                   p_requestor_name || v_body11 || g_crlf || v_body12 || g_cr ||
                   g_crlf;
    RETURN(0);
  END ttec_build_msg_prg_nonus_rev;

  -- Version 5.3 <end>

  -- Version 9.1 <Start>
  FUNCTION ttec_build_msg_ttec_cnstg_rev(p_po_number      IN VARCHAR2,
                                        p_vendor_name    IN VARCHAR2,
                                        p_requestor_name IN VARCHAR2) -- 2.0
   RETURN NUMBER IS
    v_body1   VARCHAR2(128) := 'Attached you will find the REVISED Purchase Order ';
    v_body1_1 VARCHAR2(128) := ' due to one or more of the following reasons: ';
    v_body2   VARCHAR2(128) := '     - Change order details such as description, quantity or amount ';
    v_body3   VARCHAR2(128) := '     - Incorrect vendor email address ';
    v_body4   VARCHAR2(128) := '     - Additional order(s) on the Purchase Order ';
    v_body5   VARCHAR2(128) := 'For questions regarding this Purchase Order, contact our Procurement Department via email GlobalSupplyChain@TTEC.com. ';
    v_body6   VARCHAR2(128) := 'Invoices related to this Purchase Order should be submitted to the Accounts Payable Department via email ';
    v_body7   VARCHAR2(128) := 'APInvoices@teletech.com. Payment inquiries can be emailed to APInquiries@teletech.com or by calling +1.303.397.9390. For faster ';
    v_body8   VARCHAR2(128) := 'service, always remember to reference the Purchase Order Number when contacting the Accounts Payable Department. ';
    v_body9   VARCHAR2(128) := 'In addition, please ensure that your shipping label reflects the Purchase Order number and the name of the order requestor. ';
    v_body10  VARCHAR2(128) := 'Items may be rejected by our receiving dock if shipments are not adequately documented with this information. ';
    v_body11  VARCHAR2(128) := ' - When goods/services are received, you will need to acknowledge receipt on the Purchase Order to ';
    v_body12  VARCHAR2(128) := 'facilitate the timely and accurate processing of payment to the supplier. ';
  BEGIN
    g_body_main := NULL;
    g_body_main := p_vendor_name || g_cr || g_crlf || v_body1 ||
                   p_po_number || v_body1_1 || g_crlf || v_body2 || g_crlf ||
                   v_body3 || g_crlf || v_body4 || g_cr || g_crlf ||
                   v_body5 || g_cr || g_crlf || v_body6 || g_crlf ||
                   v_body7 || g_crlf || v_body8 || g_cr || g_crlf ||
                   v_body9 || g_crlf || v_body10 || g_cr || g_crlf ||
                   p_requestor_name || v_body11 || g_crlf || v_body12 || g_cr ||
                   g_crlf;
    RETURN(0);
  END ttec_build_msg_ttec_cnstg_rev;

  -- Version 9.1 <end>

  FUNCTION ttec_build_msg_body_us_app(p_po_number      IN VARCHAR2,
                                      p_vendor_name    IN VARCHAR2,
                                      p_requestor_name IN VARCHAR2) -- 2.0
   RETURN NUMBER IS
    v_body1   VARCHAR2(128) := 'Attached you will find Purchase Order ';
    v_body1_1 VARCHAR2(128) := ' on behalf of TeleTech. For questions regarding this  ';
    v_body2   VARCHAR2(128) := 'Purchase Order, contact our Procurement Department via email GlobalProcurement@TTEC.com. ';
    v_body3   VARCHAR2(128) := 'Invoices related to this Purchase Order should be submitted to the Accounts Payable Department via email ';
    v_body4   VARCHAR2(128) := 'APInvoices@teletech.com. Payment inquiries can be emailed to APInquiries@teletech.com or by calling +1.303.397.9390. For faster ';
    v_body5   VARCHAR2(128) := 'service, always remember to reference the Purchase Order Number when contacting TeleTech''s Accounts Payable Department. ';
    v_body6   VARCHAR2(128) := 'In addition, please ensure that your shipping label reflects the Purchase Order number and the name of the order requestor. ';
    v_body7   VARCHAR2(128) := 'Items may be rejected by our receiving dock if shipments are not adequately documented with this information. ';
    v_body8   VARCHAR2(128) := ' - When goods/services are received, you will need to acknowledge receipt on the Purchase Order to ';
    v_body9   VARCHAR2(128) := 'facilitate the timely and accurate processing of payment to the supplier.';
  BEGIN
    g_body_main := NULL;
    g_body_main := p_vendor_name || g_cr || g_crlf || v_body1 ||
                   p_po_number || v_body1_1 || g_cr || v_body2 || g_cr ||
                   g_crlf || v_body3 || g_cr || v_body4 || g_cr || v_body5 || g_cr ||
                   g_crlf || v_body6 || g_cr || v_body7 || g_cr || g_crlf ||
                   p_requestor_name || v_body8 || g_cr || v_body9 || g_cr ||
                   g_crlf;
    RETURN(0);
  END ttec_build_msg_body_us_app;
/* 9.5 Begin */
  FUNCTION ttec_build_msg_body_us_app1(p_po_number      IN VARCHAR2,
                                      p_vendor_name    IN VARCHAR2,
                                      p_requestor_name IN VARCHAR2) -- 2.0
   RETURN NUMBER IS
    v_body1   VARCHAR2(128) := 'Attached you will find Purchase Order ';
    v_body1_1 VARCHAR2(128) := ' on behalf of TTEC/TeleTech. For questions regarding this  ';
    v_body2   VARCHAR2(128) := 'Purchase Order, contact our Procurement Department via email GlobalProcurement@TTEC.com. ';
    v_body3   VARCHAR2(128) := 'Invoices related to this Purchase Order should be submitted to the Accounts Payable Department via email ';
    v_body4   VARCHAR2(128) := 'APInvoices@TTEC.com. Payment inquiries can be emailed to APInquiries@TTEC.com or by calling +1.303.397.9390. For faster ';
    v_body5   VARCHAR2(128) := 'service, always remember to reference the Purchase Order Number when contacting TTEC''s Accounts Payable Department. ';
    v_body6   VARCHAR2(128) := 'In addition, please ensure that your shipping label reflects the Purchase Order number and the name of the order requestor. ';
    v_body7   VARCHAR2(128) := 'Items may be rejected by our receiving dock if shipments are not adequately documented with this information. ';
    v_body8   VARCHAR2(128) := ' - When goods/services are received, you will need to acknowledge receipt on the Purchase Order to ';
    v_body9   VARCHAR2(128) := 'facilitate the timely and accurate processing of payment to the supplier.';
  BEGIN
    g_body_main := NULL;
    g_body_main := p_vendor_name || g_cr || g_crlf || v_body1 ||
                   p_po_number || v_body1_1 || g_cr || v_body2 || g_cr ||
                   g_crlf || v_body3 || g_cr || v_body4 || g_cr || v_body5 || g_cr ||
                   g_crlf || v_body6 || g_cr || v_body7 || g_cr || g_crlf ||
                   p_requestor_name || v_body8 || g_cr || v_body9 || g_cr ||
                   g_crlf;
    RETURN(0);
  END ttec_build_msg_body_us_app1;
/* 9.5 End */

/* 9.7 Begin */
  FUNCTION ttec_build_msg_body_global_app(p_po_number      IN VARCHAR2,
                                      p_vendor_name    IN VARCHAR2,
                                      p_requestor_name IN VARCHAR2) -- 2.0
   RETURN NUMBER IS
    v_body1   VARCHAR2(128) := 'Attached you will find Purchase Order ';
    v_body1_1 VARCHAR2(128) := ' on behalf of TTEC. For questions regarding this  ';
    v_body2   VARCHAR2(128) := 'Purchase Order, contact our Procurement Department via email GlobalProcurement@TTEC.com. ';
    v_body3   VARCHAR2(128) := 'Invoices related to this Purchase Order should be submitted to the Accounts Payable Department via email ';
   -- v_body4   VARCHAR2(130) := 'APInvoiceSubmission@TTEC.com. Payment inquiries can be emailed to APInquiries@TTEC.com or by calling +1.303.397.9390. For faster '; --commented by Chandra 11.5
    v_body4   VARCHAR2(130) := 'APInvoiceSubmission@TTEC.com. Payment inquiries can be emailed to GlobalAccountsPayable@ttec.com . For faster ';
    v_body5   VARCHAR2(128) := 'service, always remember to reference the Purchase Order Number when contacting TTEC''s Accounts Payable Department. ';
    v_body6   VARCHAR2(128) := 'In addition, please ensure that your shipping label reflects the Purchase Order number and the name of the order requestor. ';
    v_body7   VARCHAR2(128) := 'Items may be rejected by our receiving dock if shipments are not adequately documented with this information. ';
    v_body8   VARCHAR2(128) := ' - When goods/services are received, you will need to acknowledge receipt on the Purchase Order to ';
    v_body9   VARCHAR2(128) := 'facilitate the timely and accurate processing of payment to the supplier.';
  BEGIN
    g_body_main := NULL;
    g_body_main := p_vendor_name || g_cr || g_crlf || v_body1 ||
                   p_po_number || v_body1_1 || g_cr || v_body2 || g_cr ||
                   g_crlf || v_body3 || g_cr || v_body4 || g_cr || v_body5 || g_cr ||
                   g_crlf || v_body6 || g_cr || v_body7 || g_cr || g_crlf ||
                   p_requestor_name || v_body8 || g_cr || v_body9 || g_cr ||
                   g_crlf;
    RETURN(0);
  END ttec_build_msg_body_global_app;
/* 9.7 End */

  FUNCTION ttec_build_msg_body_arg_app(p_po_number      IN VARCHAR2,
                                       p_vendor_name    IN VARCHAR2,
                                       p_requestor_name IN VARCHAR2) -- 2.0
   RETURN NUMBER IS
v_body1   VARCHAR2(128) := 'Adjunto encontrará la orden de compra : ';
    v_body1_1 VARCHAR2(128) := ' en nombre de TeleTech. Para preguntas con respecto a esta orden de compra ';
    v_body2   VARCHAR2(128) := ', póngase en contacto con nuestro Departamento de Compras a través de correo electrónico GlobalSupplyChain@TTEC.com. ';
    v_body3   VARCHAR2(128) := 'Las facturas relacionadas a esta orden de compra ';
    v_body4   VARCHAR2(128) := 'deberán enviarse al Departamento de Cuentas por Pagar a través del correo electrónico APInvoicesInquiries@teletech.com. ';
    v_body5   VARCHAR2(128) := 'Las consultas sobre pagos pueden ser enviadas por correo electrónico a APInvoicesInquiries@teletech.com. ';
    v_body6   VARCHAR2(128) := 'Para un servicio más rápido, recuerde siempre hacer referencia al número de orden de compra ';
    v_body7   VARCHAR2(128) := 'cuando se comunique con el Departamento de Cuentas por Pagar de TeleTech. ';
    v_body8   VARCHAR2(128) := 'Además, asegúrese de que la etiqueta del envío de la factura refleje el ';
    v_body9   VARCHAR2(128) := 'número de orden de compra y el nombre del solicitante de la orden. ';
    v_body10  VARCHAR2(200) := 'Los artículos pueden ser rechazados por nuestro departamento de recepción si los envíos no contienen esta información adecuadamente.';
    v_body11  VARCHAR2(128) := '- Cuando los bienes o servicios se reciben, se deberá acusar ';
    v_body12  VARCHAR2(128) := 'de recibo de la orden de compra para facilitar ';
    v_body13  VARCHAR2(128) := 'el tratamiento oportuno de pago al proveedor.';
  BEGIN
    g_body_main := NULL;
--    g_body_main := p_vendor_name || g_cr || g_crlf || v_body1 ||
--                   p_po_number || v_body1_1 || g_crlf || v_body2 || g_cr ||
--                   g_crlf || v_body3 || g_crlf || v_body4 || g_crlf ||
--                   v_body5 || g_crlf || v_body6 || g_crlf || v_body7 ||
--                   g_crlf || v_body8 || g_cr || g_crlf || v_body9 || g_crlf ||
--                   v_body10 || g_cr || g_crlf || p_requestor_name ||
--                   v_body11 || g_cr || g_crlf || v_body12 || g_crlf ||
--                   v_body13 || g_cr || g_crlf;
    g_body_main := p_vendor_name || g_cr || g_crlf || v_body1 ||
                   p_po_number || v_body1_1 || v_body2 || g_cr || g_crlf ||
                   v_body3 || v_body4 || v_body5 || v_body6 || v_body7 || g_cr ||
                   g_crlf || v_body8 || v_body9 || g_crlf ||
                   v_body10 || g_cr || g_crlf || p_requestor_name ||
                   v_body11 || v_body12 || v_body13 || g_cr || g_crlf;
    RETURN(0);
  END ttec_build_msg_body_arg_app;

  FUNCTION ttec_build_msg_body_spn_app(p_po_number      IN VARCHAR2,
                                       p_vendor_name    IN VARCHAR2,
                                       p_requestor_name IN VARCHAR2) -- 2.0
   RETURN NUMBER IS
v_body1   VARCHAR2(128) := 'Adjunto encontrará la orden de compra : ';
    v_body1_1 VARCHAR2(128) := ' en nombre de TeleTech. Para preguntas con respecto a esta orden de compra ';
    v_body2   VARCHAR2(128) := ', póngase en contacto con nuestro Departamento de Compras a través de correo electrónico GlobalSupplyChain@TTEC.com. ';
    v_body3   VARCHAR2(128) := 'Las facturas relacionadas a esta orden de compra ';
    v_body4   VARCHAR2(128) := 'deberán enviarse al Departamento de Cuentas por Pagar a través del correo electrónico APInvoicesInquiries@teletech.com. ';
    v_body5   VARCHAR2(128) := 'Las consultas sobre pagos pueden ser enviadas por correo electrónico a APInvoicesInquiries@teletech.com. ';
    v_body6   VARCHAR2(128) := 'Para un servicio más rápido, recuerde siempre hacer referencia al número de orden de compra ';
    v_body7   VARCHAR2(128) := 'cuando se comunique con el Departamento de Cuentas por Pagar de TeleTech. ';
    v_body8   VARCHAR2(128) := 'Además, asegúrese de que la etiqueta del envío de la factura refleje el ';
    v_body9   VARCHAR2(128) := 'número de orden de compra y el nombre del solicitante de la orden. ';
    v_body10  VARCHAR2(200) := 'Los artículos pueden ser rechazados por nuestro departamento de recepción si los envíos no contienen esta información adecuadamente.';
    v_body11  VARCHAR2(128) := '- Cuando los bienes o servicios se reciben, se deberá acusar ';
    v_body12  VARCHAR2(128) := 'de recibo de la orden de compra para facilitar ';
    v_body13  VARCHAR2(128) := 'el tratamiento oportuno de pago al proveedor.';
  BEGIN
    g_body_main := NULL;
--    g_body_main := p_vendor_name || g_cr || g_crlf || v_body1 ||
--                   p_po_number || v_body1_1 || g_crlf || v_body2 || g_cr ||
--                   g_crlf || v_body3 || g_crlf || v_body4 || g_crlf ||
--                   v_body5 || g_crlf || v_body6 || g_crlf || v_body7 ||
--                   g_crlf || v_body8 || g_cr || g_crlf || v_body9 || g_crlf ||
--                   v_body10 || g_cr || g_crlf || p_requestor_name ||
--                   v_body11 || g_cr || g_crlf || v_body12 || g_crlf ||
--                   v_body13 || g_cr || g_crlf;
    g_body_main := p_vendor_name || g_cr || g_crlf || v_body1 ||
                   p_po_number || v_body1_1 || v_body2 || g_cr || g_crlf ||
                   v_body3 || v_body4 || v_body5 || v_body6 || v_body7 || g_cr ||
                   g_crlf || v_body8 || v_body9 || g_crlf ||
                   v_body10 || g_cr || g_crlf || p_requestor_name ||
                   v_body11 || v_body12 || v_body13 || g_cr || g_crlf;
    RETURN(0);
  END ttec_build_msg_body_spn_app;

  FUNCTION ttec_build_msg_body_phl_app(p_po_number      IN VARCHAR2,
                                       p_vendor_name    IN VARCHAR2,
                                       p_requestor_name IN VARCHAR2) -- 2.0
   RETURN NUMBER IS
    v_body1   VARCHAR2(128) := 'Attached you will find Purchase Order ';
    v_body1_1 VARCHAR2(128) := ' on behalf of TTEC. For questions regarding this ';
    v_body2   VARCHAR2(128) := 'Purchase Order, contact our Procurement Department via email GlobalProcurement@TTEC.com. ';
    --v_body3   VARCHAR2(160) := 'Hard copy of the invoices related to this Purchase Order should be submitted to the Accounts Payable Department at 6/F Tower A, Two Ecom Center, Palm Coast ';
    --v_body4   VARCHAR2(160) := 'Avenue, Mall of Asia Complex, Pasay City from Monday to Friday, 9am to 11am. Payment inquiries can be emailed to APInquiries@TTEC.com ';
    v_body3   VARCHAR2(400) := 'Hard copy of the invoices related to this Purchase Order should be submitted to TeleTech Pioneer Career Hub, 2nd Floor, Robinson Cybergate Plaza,'; --12.5
    v_body4   VARCHAR2(200) := 'Edsa corner Pioneer, Mandaluyong City from Monday to Friday, 9am to 11am. Payment inquiries can be emailed to GlobalAccountsPayable@ttec.com '; --12.5
    v_body5   VARCHAR2(160) := 'or by calling +63.2.7739.7561. For faster service, always remember to reference the Purchase Order Number when contacting TTEC''s Accounts Payable Department.';
    v_body6   VARCHAR2(128) := 'In addition, please ensure that your shipping label reflects the Purchase Order number and the name of the order requestor. ';
    v_body7   VARCHAR2(128) := 'Items may be rejected by our receiving dock if shipments are not adequately documented with this information. ';
    v_body8   VARCHAR2(128) := ' - When goods/services are received, you will need to acknowledge receipt on the Purchase Order to ';
    v_body9   VARCHAR2(128) := 'facilitate the timely and accurate processing of payment to the supplier.';
  BEGIN
    g_body_main := NULL;
    g_body_main := p_vendor_name || g_cr || g_crlf || v_body1 ||
                   p_po_number || v_body1_1 || g_cr || v_body2 || g_cr ||
                   g_crlf || v_body3 || g_cr || v_body4 || g_cr || v_body5 || g_cr ||
                   g_crlf || v_body6 || g_cr || v_body7 || g_cr || g_crlf ||
                   p_requestor_name || v_body8 || g_cr || v_body9 || g_cr ||
                   g_crlf;
    RETURN(0);
  END ttec_build_msg_body_phl_app;
  /* 10.0 Begin */
  FUNCTION ttec_build_msg_body_latam_app(p_po_number      IN VARCHAR2,
                                      p_vendor_name    IN VARCHAR2,
                                      p_requestor_name IN VARCHAR2) -- 2.0
   RETURN NUMBER IS
   v_body1   VARCHAR2(128) := 'Adjunto encontrará la orden de compra : ';
    v_body1_1 VARCHAR2(128) := ' en nombre de TTEC/TeleTech. Para preguntas con respecto a esta orden de compra ';
    v_body2   VARCHAR2(128) := ', póngase en contacto con nuestro Departamento de Compras a través de correo electrónico GlobalProcurement@ttec.com. ';
    v_body3   VARCHAR2(128) := 'Las facturas relacionadas a esta orden de compra ';
    v_body4   VARCHAR2(128) := 'deberán enviarse al Departamento de Cuentas por Pagar a través del correo electrónico APInvoicesInquiries@TTEC.com. ';
    v_body5   VARCHAR2(128) := 'Las consultas sobre pagos pueden ser enviadas por correo electrónico a APInvoicesInquiries@TTEC.com. ';
    v_body6   VARCHAR2(128) := 'Para un servicio más rápido, recuerde siempre hacer referencia al número de orden de compra ';
    v_body7   VARCHAR2(128) := 'cuando se comunique con el Departamento de Cuentas por Pagar de TTEC/TeleTech. ';
    v_body8   VARCHAR2(128) := 'Además, asegúrese de que la etiqueta del envío de la factura refleje el ';
    v_body9   VARCHAR2(128) := 'número de orden de compra y el nombre del solicitante de la orden. ';
    v_body10  VARCHAR2(200) := 'Los artículos pueden ser rechazados por nuestro departamento de recepción si los envíos no contienen esta información adecuadamente.';
    v_body11  VARCHAR2(128) := '- Cuando los bienes o servicios se reciben, se deberá acusar ';
    v_body12  VARCHAR2(128) := 'de recibo de la orden de compra para facilitar ';
    v_body13  VARCHAR2(128) := 'el tratamiento oportuno de pago al proveedor.';
  BEGIN
    g_body_main := NULL;
    g_body_main := p_vendor_name || g_cr || g_crlf || v_body1 ||
                   p_po_number || v_body1_1 || v_body2 || g_cr || g_crlf ||
                   v_body3 || v_body4 || v_body5 || v_body6 || v_body7 || g_cr ||
                   g_crlf || v_body8 || v_body9 || g_crlf ||
                   v_body10 || g_cr || g_crlf || p_requestor_name ||
                   v_body11 || v_body12 || v_body13 || g_cr || g_crlf;

    RETURN(0);
  END ttec_build_msg_body_latam_app;
  /* 10.0 End */
  FUNCTION ttec_build_msg_body_mx_app(p_po_number      IN VARCHAR2,
                                      p_vendor_name    IN VARCHAR2,
                                      p_requestor_name IN VARCHAR2) -- 2.0
   RETURN NUMBER IS
   v_body1   VARCHAR2(128) := 'Adjunto encontrará la orden de compra : ';
    v_body1_1 VARCHAR2(128) := ' en nombre de TeleTech. Para preguntas con respecto a esta orden de compra ';
    v_body2   VARCHAR2(128) := ', póngase en contacto con nuestro Departamento de Compras a través de correo electrónico GlobalSupplyChain@TTEC.com. ';
    v_body3   VARCHAR2(128) := 'Las facturas relacionadas a esta orden de compra ';
    v_body4   VARCHAR2(128) := 'deberán enviarse al Departamento de Cuentas por Pagar a través del correo electrónico APInvoicesInquiries@teletech.com. ';
    v_body5   VARCHAR2(128) := 'Las consultas sobre pagos pueden ser enviadas por correo electrónico a APInvoicesInquiries@teletech.com. ';
    v_body6   VARCHAR2(128) := 'Para un servicio más rápido, recuerde siempre hacer referencia al número de orden de compra ';
    v_body7   VARCHAR2(128) := 'cuando se comunique con el Departamento de Cuentas por Pagar de TeleTech. ';
    v_body8   VARCHAR2(128) := 'Además, asegúrese de que la etiqueta del envío de la factura refleje el ';
    v_body9   VARCHAR2(128) := 'número de orden de compra y el nombre del solicitante de la orden. ';
    v_body10  VARCHAR2(200) := 'Los artículos pueden ser rechazados por nuestro departamento de recepción si los envíos no contienen esta información adecuadamente.';
    v_body11  VARCHAR2(128) := '- Cuando los bienes o servicios se reciben, se deberá acusar ';
    v_body12  VARCHAR2(128) := 'de recibo de la orden de compra para facilitar ';
    v_body13  VARCHAR2(128) := 'el tratamiento oportuno de pago al proveedor.';
  BEGIN
    g_body_main := NULL;
--    g_body_main := p_vendor_name || g_cr || g_crlf || v_body1 ||
--                   p_po_number || v_body1_1 || g_crlf || v_body2 || g_cr ||
--                   g_crlf || v_body3 || g_crlf || v_body4 || g_crlf ||
--                   v_body5 || g_crlf || v_body6 || g_crlf || v_body7 ||
--                   g_crlf || v_body8 || g_cr || g_crlf || v_body9 || g_crlf ||
--                   v_body10 || g_cr || g_crlf || p_requestor_name ||
--                   v_body11 || g_cr || g_crlf || v_body12 || g_crlf ||
--                   v_body13 || g_cr || g_crlf;
    g_body_main := p_vendor_name || g_cr || g_crlf || v_body1 ||
                   p_po_number || v_body1_1 || v_body2 || g_cr || g_crlf ||
                   v_body3 || v_body4 || v_body5 || v_body6 || v_body7 || g_cr ||
                   g_crlf || v_body8 || v_body9 || g_crlf ||
                   v_body10 || g_cr || g_crlf || p_requestor_name ||
                   v_body11 || v_body12 || v_body13 || g_cr || g_crlf;

    RETURN(0);
  END ttec_build_msg_body_mx_app;

  FUNCTION ttec_build_msg_body_cr_app(p_po_number      IN VARCHAR2,
                                      p_vendor_name    IN VARCHAR2,
                                      p_requestor_name IN VARCHAR2) -- 2.0
   RETURN NUMBER IS
v_body1   VARCHAR2(128) := 'Adjunto encontrará la orden de compra : ';
    v_body1_1 VARCHAR2(128) := ' en nombre de TeleTech. Para preguntas con respecto a esta orden de compra ';
    v_body2   VARCHAR2(128) := ', póngase en contacto con nuestro Departamento de Compras a través de correo electrónico GlobalSupplyChain@TTEC.com. ';
    v_body3   VARCHAR2(128) := 'Las facturas relacionadas a esta orden de compra ';
    v_body4   VARCHAR2(128) := 'deberán enviarse al Departamento de Cuentas por Pagar a través del correo electrónico APInvoicesInquiries@teletech.com. ';
    v_body5   VARCHAR2(128) := 'Las consultas sobre pagos pueden ser enviadas por correo electrónico a APInvoicesInquiries@teletech.com. ';
    v_body6   VARCHAR2(128) := 'Para un servicio más rápido, recuerde siempre hacer referencia al número de orden de compra ';
    v_body7   VARCHAR2(128) := 'cuando se comunique con el Departamento de Cuentas por Pagar de TeleTech. ';
    v_body8   VARCHAR2(128) := 'Además, asegúrese de que la etiqueta del envío de la factura refleje el ';
    v_body9   VARCHAR2(128) := 'número de orden de compra y el nombre del solicitante de la orden. ';
    v_body10  VARCHAR2(200) := 'Los artículos pueden ser rechazados por nuestro departamento de recepción si los envíos no contienen esta información adecuadamente.';
    v_body11  VARCHAR2(128) := '- Cuando los bienes o servicios se reciben, se deberá acusar ';
    v_body12  VARCHAR2(128) := 'de recibo de la orden de compra para facilitar ';
    v_body13  VARCHAR2(128) := 'el tratamiento oportuno de pago al proveedor.';
  BEGIN
    g_body_main := NULL;
--    g_body_main := p_vendor_name || g_cr || g_crlf || v_body1 ||
--                   p_po_number || v_body1_1 || g_crlf || v_body2 || g_cr ||
--                   g_crlf || v_body3 || g_crlf || v_body4 || g_crlf ||
--                   v_body5 || g_crlf || v_body6 || g_crlf || v_body7 ||
--                   g_crlf || v_body8 || g_cr || g_crlf || v_body9 || g_crlf ||
--                   v_body10 || g_cr || g_crlf || p_requestor_name ||
--                   v_body11 || g_cr || g_crlf || v_body12 || g_crlf ||
--                   v_body13 || g_cr || g_crlf;
    g_body_main := p_vendor_name || g_cr || g_crlf || v_body1 ||
                   p_po_number || v_body1_1 || v_body2 || g_cr || g_crlf ||
                   v_body3 || v_body4 || v_body5 || v_body6 || v_body7 || g_cr ||
                   g_crlf || v_body8 || v_body9 || g_crlf ||
                   v_body10 || g_cr || g_crlf || p_requestor_name ||
                   v_body11 || v_body12 || v_body13 || g_cr || g_crlf;
    RETURN(0);
  END ttec_build_msg_body_cr_app;
  /* 10.0 Begin */
  FUNCTION ttec_build_msg_body_ptb_app(p_po_number      IN VARCHAR2,
                                       p_vendor_name    IN VARCHAR2,
                                       p_requestor_name IN VARCHAR2) -- 2.0
   RETURN NUMBER IS
    v_body1   VARCHAR2(128) := 'Em anexo enviamos a Ordem de Compra ';
    v_body1_1 VARCHAR2(128) := ' em nome da Teletech Brasil. Qualquer consulta ';
    v_body2   VARCHAR2(128) := 'respeito dessa Ordem de Compra, favor contatar o Departamento de Compras via e-mail: GlobalProcurement@TTEC.com. ';
    v_body3   VARCHAR2(128) := 'As notas fiscais referentes a essa Ordem de Compra devem ser encaminhadas a: Av. Maria Coelho Aguiar, 215, Bloco A - ';
    v_body4   VARCHAR2(128) := '7º andar - São Paulo - SP 05805-000. Qualquer consulta sobre pagamentos por favor ligue no +3747-7966.  Para um ';
    v_body5   VARCHAR2(128) := 'atendimento mais rápido, lembre-se sempre de fazer referência ao número de Ordem de Compra quando entrar em ';
    v_body6   VARCHAR2(128) := 'contato com o Departamento de Contas a Pagar. ';
    v_body7   VARCHAR2(128) := 'Além disso, solicitamos colocar o número de Ordem de Compra na nota fiscal. Sem essa informação a nota fiscal poderá ';
    v_body8   VARCHAR2(128) := 'ser rejeitada.';

  BEGIN
    g_body_main := NULL;
    g_body_main := p_vendor_name || g_cr || g_crlf || v_body1 ||
                   p_po_number || v_body1_1 || g_crlf || v_body2 || g_cr ||
                   g_crlf || v_body3 || g_crlf || v_body4 || g_crlf ||
                   v_body5 || g_crlf || v_body6 || g_crlf || v_body7 ||
                   g_crlf || v_body8 || g_cr || g_crlf;
    RETURN(0);
  END ttec_build_msg_body_ptb_app;
  /* 10.0 End */
  FUNCTION ttec_build_msg_body_brz_app(p_po_number      IN VARCHAR2,
                                       p_vendor_name    IN VARCHAR2,
                                       p_requestor_name IN VARCHAR2) -- 2.0
   RETURN NUMBER IS
    v_body1   VARCHAR2(128) := 'Em anexo enviamos a Ordem de Compra ';
    v_body1_1 VARCHAR2(128) := ' em nome da Teletech Brasil. Qualquer consulta ';
    v_body2   VARCHAR2(128) := 'respeito dessa Ordem de Compra, favor contatar o Departamento de Compras via e-mail: GlobalProcurement@TTEC.com. ';
    v_body3   VARCHAR2(128) := 'As notas fiscais referentes a essa Ordem de Compra devem ser encaminhadas a: Av. Maria Coelho Aguiar, 215, Bloco A - ';
    v_body4   VARCHAR2(128) := '7º andar - São Paulo - SP 05805-000. Qualquer consulta sobre pagamentos por favor ligue no +3747-7966.  Para um ';
    v_body5   VARCHAR2(128) := 'atendimento mais rápido, lembre-se sempre de fazer referência ao número de Ordem de Compra quando entrar em ';
    v_body6   VARCHAR2(128) := 'contato com o Departamento de Contas a Pagar. ';
    v_body7   VARCHAR2(128) := 'Além disso, solicitamos colocar o número de Ordem de Compra na nota fiscal. Sem essa informação a nota fiscal poderá ';
    v_body8   VARCHAR2(128) := 'ser rejeitada.';

  BEGIN
    g_body_main := NULL;
    g_body_main := p_vendor_name || g_cr || g_crlf || v_body1 ||
                   p_po_number || v_body1_1 || g_crlf || v_body2 || g_cr ||
                   g_crlf || v_body3 || g_crlf || v_body4 || g_crlf ||
                   v_body5 || g_crlf || v_body6 || g_crlf || v_body7 ||
                   g_crlf || v_body8 || g_cr || g_crlf;
    RETURN(0);
  END ttec_build_msg_body_brz_app;

  -- v 3.4 PRG messaging
  FUNCTION ttec_build_msg_body_prg_app(p_po_number      IN VARCHAR2,
                                       p_vendor_name    IN VARCHAR2,
                                       p_requestor_name IN VARCHAR2) -- 2.0
   RETURN NUMBER IS
    v_body1   VARCHAR2(128) := 'Attached you will find Purchase Order ';
    v_body1_1 VARCHAR2(128) := ' on behalf of 1to1 Marketing LLC. For questions regarding this  ';
    v_body2   VARCHAR2(128) := 'Purchase Order, contact our Procurement Department via email procurement@teletech.com. ';
    v_body3   VARCHAR2(128) := 'Invoices related to this Purchase Order should be submitted to the Accounts Payable Department via email ';
    v_body4   VARCHAR2(128) := 'APInvoices@teletech.com. Payment inquiries can be emailed to APInquiries@teletech.com or by calling +1.303.397.9390. For faster ';
    v_body5   VARCHAR2(128) := 'service, always remember to reference the Purchase Order Number when contacting the Accounts Payable Department. ';
    v_body6   VARCHAR2(128) := 'In addition, please ensure that your shipping label reflects the Purchase Order number and the name of the order requestor. ';
    v_body7   VARCHAR2(128) := 'Items may be rejected by our receiving dock if shipments are not adequately documented with this information. ';
    v_body8   VARCHAR2(128) := ' - When goods/services are received, you will need to acknowledge receipt on the Purchase Order to ';
    v_body9   VARCHAR2(128) := 'facilitate the timely and accurate processing of payment to the supplier.';
  BEGIN
    g_body_main := NULL;
    g_body_main := p_vendor_name || g_cr || g_crlf || v_body1 ||
                   p_po_number || v_body1_1 || g_cr || v_body2 || g_cr ||
                   g_crlf || v_body3 || g_cr || v_body4 || g_cr || v_body5 || g_cr ||
                   g_crlf || v_body6 || g_cr || v_body7 || g_cr || g_crlf ||
                   p_requestor_name || v_body8 || g_cr || v_body9 || g_cr ||
                   g_crlf;
    RETURN(0);
  END ttec_build_msg_body_prg_app;

  -- Version 5.3 <Start>
  FUNCTION ttec_build_msg_prg_nonus_app(p_po_number      IN VARCHAR2,
                                        p_vendor_name    IN VARCHAR2,
                                        p_requestor_name IN VARCHAR2) -- 2.0
   RETURN NUMBER IS
    v_body1   VARCHAR2(128) := 'Attached you will find Purchase Order ';
    v_body1_1 VARCHAR2(128) := ' on behalf of Peppers and Rogers Group. For questions regarding this  ';
    v_body2   VARCHAR2(128) := 'Purchase Order, contact our Procurement Department via email GlobalSupplyChain@TTEC.com. ';
    v_body3   VARCHAR2(128) := 'Invoices related to this Purchase Order should be submitted to the Accounts Payable Department via email ';
    v_body4   VARCHAR2(128) := 'APInvoices@teletech.com. Payment inquiries can be emailed to APInquiries@teletech.com or by calling +1.303.397.9390. For faster ';
    v_body5   VARCHAR2(128) := 'service, always remember to reference the Purchase Order Number when contacting the Accounts Payable Department. ';
    v_body6   VARCHAR2(128) := 'In addition, please ensure that your shipping label reflects the Purchase Order number and the name of the order requestor. ';
    v_body7   VARCHAR2(128) := 'Items may be rejected by our receiving dock if shipments are not adequately documented with this information. ';
    v_body8   VARCHAR2(128) := ' - When goods/services are received, you will need to acknowledge receipt on the Purchase Order to ';
    v_body9   VARCHAR2(128) := 'facilitate the timely and accurate processing of payment to the supplier.';
  BEGIN
    g_body_main := NULL;
    g_body_main := p_vendor_name || g_cr || g_crlf || v_body1 ||
                   p_po_number || v_body1_1 || g_cr || v_body2 || g_cr ||
                   g_crlf || v_body3 || g_cr || v_body4 || g_cr || v_body5 || g_cr ||
                   g_crlf || v_body6 || g_cr || v_body7 || g_cr || g_crlf ||
                   p_requestor_name || v_body8 || g_cr || v_body9 || g_cr ||
                   g_crlf;
    RETURN(0);
  END ttec_build_msg_prg_nonus_app;

  -- Version 5.3 <end>
  -- Version 9.1 <Start>
  FUNCTION ttec_build_msg_ttec_cnstg_app(p_po_number      IN VARCHAR2,
                                        p_vendor_name    IN VARCHAR2,
                                        p_requestor_name IN VARCHAR2) -- 2.0
   RETURN NUMBER IS
    v_body1   VARCHAR2(128) := 'Attached you will find Purchase Order ';
    v_body1_1 VARCHAR2(128) := ' on behalf of TeleTech Consulting. For questions regarding this  ';
    v_body2   VARCHAR2(128) := 'Purchase Order, contact our Procurement Department via email GlobalSupplyChain@TTEC.com. ';
    v_body3   VARCHAR2(128) := 'Invoices related to this Purchase Order should be submitted to the Accounts Payable Department via email ';
    v_body4   VARCHAR2(128) := 'APInvoices@teletech.com. Payment inquiries can be emailed to APInquiries@teletech.com or by calling +1.303.397.9390. For faster ';
    v_body5   VARCHAR2(128) := 'service, always remember to reference the Purchase Order Number when contacting the Accounts Payable Department. ';
    v_body6   VARCHAR2(128) := 'In addition, please ensure that your shipping label reflects the Purchase Order number and the name of the order requestor. ';
    v_body7   VARCHAR2(128) := 'Items may be rejected by our receiving dock if shipments are not adequately documented with this information. ';
    v_body8   VARCHAR2(128) := ' - When goods/services are received, you will need to acknowledge receipt on the Purchase Order to ';
    v_body9   VARCHAR2(128) := 'facilitate the timely and accurate processing of payment to the supplier.';
  BEGIN
    g_body_main := NULL;
    g_body_main := p_vendor_name || g_cr || g_crlf || v_body1 ||
                   p_po_number || v_body1_1 || g_cr || v_body2 || g_cr ||
                   g_crlf || v_body3 || g_cr || v_body4 || g_cr || v_body5 || g_cr ||
                   g_crlf || v_body6 || g_cr || v_body7 || g_cr || g_crlf ||
                   p_requestor_name || v_body8 || g_cr || v_body9 || g_cr ||
                   g_crlf;
    RETURN(0);
  END ttec_build_msg_ttec_cnstg_app;

  -- Version 9.1 <end>
  /******************************************************************************************
  ttec_po_email_xx_gen fucnctions: This functions call the appropiate function for the status,
                                   language and country required.
  *****************************************************************************************/
  FUNCTION ttec_po_email_us_gen(p_po_number      IN VARCHAR2,
                                p_vendor_name    IN VARCHAR2,
                                p_requester_name IN VARCHAR2,
                                p_po_status      IN VARCHAR2,
                                p_stat           IN NUMBER) -- 2.0
   RETURN NUMBER IS
    v_stat NUMBER := p_stat;
  BEGIN
    g_error_step := 'Step 5.3.1: Inside Case. Generating Email Body (US). PO Status: ' ||
                    p_po_status;

    IF v_stat != 0 THEN
      CASE p_po_status
        WHEN 'C' THEN
          -- cancelled PO
          v_stat := ttec_build_msg_body_us_can(p_po_number,
                                               p_vendor_name,
                                               p_requester_name);
        WHEN 'R' THEN
          -- revised PO
          v_stat := ttec_build_msg_body_us_rev(p_po_number,
                                               p_vendor_name,
                                               p_requester_name);
        ELSE
          -- Approved Once
          v_stat := ttec_build_msg_body_us_app(p_po_number,
                                               p_vendor_name,
                                               p_requester_name);
      END CASE;ELSE
      v_stat := -1;
    END IF;

    RETURN v_stat; -- -1 error generating PO Graphic
  END ttec_po_email_us_gen;
/* 9.5 begin */
  FUNCTION ttec_po_email_us_gen_ttec(p_po_number      IN VARCHAR2,
                                p_vendor_name    IN VARCHAR2,
                                p_requester_name IN VARCHAR2,
                                p_po_status      IN VARCHAR2,
                                p_stat           IN NUMBER) -- 2.0
   RETURN NUMBER IS
    v_stat NUMBER := p_stat;
  BEGIN
    g_error_step := 'Step 5.3.1: Inside Case. Generating Email Body (US). PO Status: ' ||
                    p_po_status;

    IF v_stat != 0 THEN
      CASE p_po_status
        WHEN 'C' THEN
          -- cancelled PO
          v_stat := ttec_build_msg_body_us_can1(p_po_number,
                                               p_vendor_name,
                                               p_requester_name);
        WHEN 'R' THEN
          -- revised PO
          v_stat := ttec_build_msg_body_us_rev1(p_po_number,
                                               p_vendor_name,
                                               p_requester_name);
        ELSE
          -- Approved Once
          v_stat := ttec_build_msg_body_us_app1(p_po_number,
                                               p_vendor_name,
                                               p_requester_name);
      END CASE;ELSE
      v_stat := -1;
    END IF;

    RETURN v_stat; -- -1 error generating PO Graphic
  END ttec_po_email_us_gen_ttec;
/* 9.5 End*/

/* 9.7 begin */
  FUNCTION ttec_po_email_global_gen(p_po_number      IN VARCHAR2,
                                p_vendor_name    IN VARCHAR2,
                                p_requester_name IN VARCHAR2,
                                p_po_status      IN VARCHAR2,
                                p_stat           IN NUMBER) -- 2.0
   RETURN NUMBER IS
    v_stat NUMBER := p_stat;
  BEGIN
    g_error_step := 'Step 5.3.1: Inside Case. Generating Email Body (Global). for Operation Unit:'||g_operating_unit_name ||' PO Status: ' ||
                    p_po_status;

    IF v_stat != 0 THEN
      CASE p_po_status
        WHEN 'C' THEN
          -- cancelled PO
          v_stat := ttec_build_msg_body_global_can(p_po_number,
                                               p_vendor_name,
                                               p_requester_name);
        WHEN 'R' THEN
          -- revised PO
          v_stat := ttec_build_msg_body_global_rev(p_po_number,
                                               p_vendor_name,
                                               p_requester_name);
        ELSE
          -- Approved Once
          v_stat := ttec_build_msg_body_global_app(p_po_number,
                                               p_vendor_name,
                                               p_requester_name);
      END CASE;ELSE
      v_stat := -1;
    END IF;

    RETURN v_stat; -- -1 error generating PO Graphic
  END ttec_po_email_global_gen;
/* 9.7 End*/

  FUNCTION ttec_po_email_arg_gen(p_po_number      IN VARCHAR2,
                                 p_vendor_name    IN VARCHAR2,
                                 p_requester_name IN VARCHAR2,
                                 p_po_status      IN VARCHAR2,
                                 p_stat           IN NUMBER) -- 2.0
   RETURN NUMBER IS
    v_stat NUMBER := p_stat;
  BEGIN
    g_error_step := 'Step 5.3.1: Inside Case. Generating Email Body (Arg). PO Status: ' ||
                    p_po_status;

    IF v_stat != 0 THEN
      CASE p_po_status
        WHEN 'C' THEN
          -- cancelled
          v_stat := ttec_build_msg_body_arg_can(p_po_number,
                                                p_vendor_name,
                                                p_requester_name);
        WHEN 'R' THEN
          -- revised
          v_stat := ttec_build_msg_body_arg_rev(p_po_number,
                                                p_vendor_name,
                                                p_requester_name);
        ELSE
          -- Approved Once
          v_stat := ttec_build_msg_body_arg_app(p_po_number,
                                                p_vendor_name,
                                                p_requester_name);
      END CASE;ELSE
      v_stat := -1;
    END IF;

    RETURN v_stat; -- -1 error generating PO Graphic
  END ttec_po_email_arg_gen;

  FUNCTION ttec_po_email_spn_gen(p_po_number      IN VARCHAR2,
                                 p_vendor_name    IN VARCHAR2,
                                 p_requester_name IN VARCHAR2,
                                 p_po_status      IN VARCHAR2,
                                 p_stat           IN NUMBER) -- 2.0
   RETURN NUMBER IS
    v_stat NUMBER := p_stat;
  BEGIN
    g_error_step := 'Step 5.3.1: Inside Case. Generating Email Body (Spain). PO Status: ' ||
                    p_po_status;

    IF v_stat != 0 THEN
      CASE p_po_status
        WHEN 'C' THEN
          -- cancelled
          v_stat := ttec_build_msg_body_spn_can(p_po_number,
                                                p_vendor_name,
                                                p_requester_name);
        WHEN 'R' THEN
          -- revised
          v_stat := ttec_build_msg_body_spn_rev(p_po_number,
                                                p_vendor_name,
                                                p_requester_name);
        ELSE
          -- Approved Once
          v_stat := ttec_build_msg_body_spn_app(p_po_number,
                                                p_vendor_name,
                                                p_requester_name);
      END CASE;ELSE
      v_stat := -1;
    END IF;

    RETURN v_stat; -- -1 error generating PO Graphic
  END ttec_po_email_spn_gen;

  FUNCTION ttec_po_email_phl_gen(p_po_number      IN VARCHAR2,
                                 p_vendor_name    IN VARCHAR2,
                                 p_requester_name IN VARCHAR2,
                                 p_po_status      IN VARCHAR2,
                                 p_stat           IN NUMBER) -- 2.0
   RETURN NUMBER IS
    v_stat NUMBER := p_stat;
  BEGIN
    g_error_step := 'Step 5.3.1: Inside Case. Generating Email Body (Phl). PO Status: ' ||
                    p_po_status;

    IF v_stat != 0 THEN
      CASE p_po_status
        WHEN 'C' THEN
          -- cancelled
          v_stat := ttec_build_msg_body_phl_can(p_po_number,
                                                p_vendor_name,
                                                p_requester_name);
        WHEN 'R' THEN
          -- revised
          v_stat := ttec_build_msg_body_phl_rev(p_po_number,
                                                p_vendor_name,
                                                p_requester_name);
        ELSE
          -- Approved Once
          v_stat := ttec_build_msg_body_phl_app(p_po_number,
                                                p_vendor_name,
                                                p_requester_name);
      END CASE;ELSE
      v_stat := -1;
    END IF;

    RETURN v_stat; -- -1 error generating PO Graphic
  END ttec_po_email_phl_gen;

  /* 10.0 Begin */
  FUNCTION ttec_po_email_latam_gen(p_po_number      IN VARCHAR2,
                                p_vendor_name    IN VARCHAR2,
                                p_requester_name IN VARCHAR2,
                                p_po_status      IN VARCHAR2,
                                p_stat           IN NUMBER)
   RETURN NUMBER IS
    v_stat NUMBER := p_stat;
  BEGIN
    g_error_step := 'Step 5.3.1: Inside Case. Generating Email Body (LATAM). PO Status: ' ||
                    p_po_status;

    IF v_stat != 0 THEN
      CASE p_po_status
        WHEN 'C' THEN
          -- cancelled
          v_stat := ttec_build_msg_body_latam_can(p_po_number,
                                                  p_vendor_name,
                                                  p_requester_name);
        WHEN 'R' THEN
          -- revised
          v_stat := ttec_build_msg_body_latam_rev(p_po_number,
                                                  p_vendor_name,
                                                  p_requester_name);
        ELSE
          -- Approved Once
          v_stat := ttec_build_msg_body_latam_app(p_po_number,
                                                  p_vendor_name,
                                                  p_requester_name);
      END CASE;ELSE
      v_stat := -1;
    END IF;

    RETURN v_stat; -- -1 error generating PO Graphic
  END ttec_po_email_latam_gen;
  /* 10.0 End */

  FUNCTION ttec_po_email_mx_gen(p_po_number      IN VARCHAR2,
                                p_vendor_name    IN VARCHAR2,
                                p_requester_name IN VARCHAR2,
                                p_po_status      IN VARCHAR2,
                                p_stat           IN NUMBER) -- 2.0
   RETURN NUMBER IS
    v_stat NUMBER := p_stat;
  BEGIN
    g_error_step := 'Step 5.3.1: Inside Case. Generating Email Body (Mexico). PO Status: ' ||
                    p_po_status;

    IF v_stat != 0 THEN
      CASE p_po_status
        WHEN 'C' THEN
          -- cancelled
          v_stat := ttec_build_msg_body_mx_can(p_po_number,
                                               p_vendor_name,
                                               p_requester_name);
        WHEN 'R' THEN
          -- revised
          v_stat := ttec_build_msg_body_mx_rev(p_po_number,
                                               p_vendor_name,
                                               p_requester_name);
        ELSE
          -- Approved Once
          v_stat := ttec_build_msg_body_mx_app(p_po_number,
                                               p_vendor_name,
                                               p_requester_name);
      END CASE;ELSE
      v_stat := -1;
    END IF;

    RETURN v_stat; -- -1 error generating PO Graphic
  END ttec_po_email_mx_gen;

  FUNCTION ttec_po_email_cr_gen(p_po_number      IN VARCHAR2,
                                p_vendor_name    IN VARCHAR2,
                                p_requester_name IN VARCHAR2,
                                p_po_status      IN VARCHAR2,
                                p_stat           IN NUMBER) -- 2.0
   RETURN NUMBER IS
    v_stat NUMBER := p_stat;
  BEGIN
    g_error_step := 'Step 5.3.1: Inside Case. Generating Email Body (CR). PO Status: ' ||
                    p_po_status;

    IF v_stat != 0 THEN
      CASE p_po_status
        WHEN 'C' THEN
          -- cancelled
          v_stat := ttec_build_msg_body_cr_can(p_po_number,
                                               p_vendor_name,
                                               p_requester_name);
        WHEN 'R' THEN
          -- revised
          v_stat := ttec_build_msg_body_cr_rev(p_po_number,
                                               p_vendor_name,
                                               p_requester_name);
        ELSE
          -- Approved Once
          v_stat := ttec_build_msg_body_cr_app(p_po_number,
                                               p_vendor_name,
                                               p_requester_name);
      END CASE;ELSE
      v_stat := -1;
    END IF;

    RETURN v_stat; -- -1 error generating PO Graphic
  END ttec_po_email_cr_gen;

  /* 10.0 Begin */
  FUNCTION ttec_po_email_ptb_gen(p_po_number      IN VARCHAR2,
                                 p_vendor_name    IN VARCHAR2,
                                 p_requester_name IN VARCHAR2,
                                 p_po_status      IN VARCHAR2,
                                 p_stat           IN NUMBER) -- 2.0
   RETURN NUMBER IS
    v_stat NUMBER := p_stat;
  BEGIN
    g_error_step := 'Step 5.3.1: Inside Case. Generating Email Body (Brazil). PO Status: ' ||
                    p_po_status;

    IF v_stat != 0 THEN
      CASE p_po_status
        WHEN 'C' THEN
          -- cancelled
          v_stat := ttec_build_msg_body_ptb_can(p_po_number,
                                                p_vendor_name,
                                                p_requester_name);
        WHEN 'R' THEN
          -- revised
          v_stat := ttec_build_msg_body_ptb_rev(p_po_number,
                                                p_vendor_name,
                                                p_requester_name);
        ELSE
          -- Approved Once
          v_stat := ttec_build_msg_body_ptb_app(p_po_number,
                                                p_vendor_name,
                                                p_requester_name);
      END CASE;ELSE
      v_stat := -1;
    END IF;

    RETURN v_stat; -- -1 error generating PO Graphic
  END ttec_po_email_ptb_gen;
  /* 10.0 End */

  FUNCTION ttec_po_email_brz_gen(p_po_number      IN VARCHAR2,
                                 p_vendor_name    IN VARCHAR2,
                                 p_requester_name IN VARCHAR2,
                                 p_po_status      IN VARCHAR2,
                                 p_stat           IN NUMBER) -- 2.0
   RETURN NUMBER IS
    v_stat NUMBER := p_stat;
  BEGIN
    g_error_step := 'Step 5.3.1: Inside Case. Generating Email Body (Brazil). PO Status: ' ||
                    p_po_status;

    IF v_stat != 0 THEN
      CASE p_po_status
        WHEN 'C' THEN
          -- cancelled
          v_stat := ttec_build_msg_body_brz_can(p_po_number,
                                                p_vendor_name,
                                                p_requester_name);
        WHEN 'R' THEN
          -- revised
          v_stat := ttec_build_msg_body_brz_rev(p_po_number,
                                                p_vendor_name,
                                                p_requester_name);
        ELSE
          -- Approved Once
          v_stat := ttec_build_msg_body_brz_app(p_po_number,
                                                p_vendor_name,
                                                p_requester_name);
      END CASE;ELSE
      v_stat := -1;
    END IF;

    RETURN v_stat; -- -1 error generating PO Graphic
  END ttec_po_email_brz_gen;

  /* End of new code version 2.0 */
  -- v 3.4 PRG messaging
  FUNCTION ttec_po_email_prg_gen(p_po_number      IN VARCHAR2,
                                 p_vendor_name    IN VARCHAR2,
                                 p_requester_name IN VARCHAR2,
                                 p_po_status      IN VARCHAR2,
                                 p_stat           IN NUMBER) -- 2.0
   RETURN NUMBER IS
    v_stat NUMBER := p_stat;
  BEGIN
    g_error_step := 'Step 5.3.1: Inside Case. Generating Email Body (PRG). PO Status: ' ||
                    p_po_status;

    IF v_stat != 0 THEN
      CASE p_po_status
        WHEN 'C' THEN
          -- cancelled PO
          v_stat := ttec_build_msg_body_prg_can(p_po_number, -- v 3.4 PRG messaging
                                                p_vendor_name,
                                                p_requester_name);
        WHEN 'R' THEN
          -- revised PO
          v_stat := ttec_build_msg_body_prg_rev(p_po_number, -- v 3.4 PRG messaging
                                                p_vendor_name,
                                                p_requester_name);
        ELSE
          -- Approved Once
          v_stat := ttec_build_msg_body_prg_app(p_po_number, -- v 3.4 PRG messaging
                                                p_vendor_name,
                                                p_requester_name);
      END CASE;ELSE
      v_stat := -1;
    END IF;

    RETURN v_stat; -- -1 error generating PO Graphic
  END ttec_po_email_prg_gen;

  -- Version 5.3 <Start>
  FUNCTION ttec_po_email_prg_nonus_gen(p_po_number      IN VARCHAR2,
                                       p_vendor_name    IN VARCHAR2,
                                       p_requester_name IN VARCHAR2,
                                       p_po_status      IN VARCHAR2,
                                       p_stat           IN NUMBER) -- 2.0
   RETURN NUMBER IS
    v_stat NUMBER := p_stat;
  BEGIN
    g_error_step := 'Step 5.3.1: Inside Case. Generating Email Body (PRG). PO Status: ' ||
                    p_po_status;

    IF v_stat != 0 THEN
      CASE p_po_status
        WHEN 'C' THEN
          -- cancelled PO
          v_stat := ttec_build_msg_prg_nonus_can(p_po_number, -- v 3.4 PRG messaging
                                                 p_vendor_name,
                                                 p_requester_name);
        WHEN 'R' THEN
          -- revised PO
          v_stat := ttec_build_msg_prg_nonus_rev(p_po_number, -- v 3.4 PRG messaging
                                                 p_vendor_name,
                                                 p_requester_name);
        ELSE
          -- Approved Once
          v_stat := ttec_build_msg_prg_nonus_app(p_po_number, -- v 3.4 PRG messaging
                                                 p_vendor_name,
                                                 p_requester_name);
      END CASE;ELSE
      v_stat := -1;
    END IF;

    RETURN v_stat; -- -1 error generating PO Graphic
  END ttec_po_email_prg_nonus_gen;

  -- Version 5.3 <end>

  -- Version 9.1 <Start>
  FUNCTION ttec_po_email_ttec_cnstg_gen(p_po_number      IN VARCHAR2,
                                       p_vendor_name    IN VARCHAR2,
                                       p_requester_name IN VARCHAR2,
                                       p_po_status      IN VARCHAR2,
                                       p_stat           IN NUMBER) -- 2.0
   RETURN NUMBER IS
    v_stat NUMBER := p_stat;
  BEGIN
    g_error_step := 'Step 5.3.1: Inside Case. Generating Email Body (PRG). PO Status: ' ||
                    p_po_status;

    IF v_stat != 0 THEN
      CASE p_po_status
        WHEN 'C' THEN
          -- cancelled PO
          v_stat := ttec_build_msg_ttec_cnstg_can(p_po_number, -- v 3.4 PRG messaging
                                                 p_vendor_name,
                                                 p_requester_name);
        WHEN 'R' THEN
          -- revised PO
          v_stat := ttec_build_msg_ttec_cnstg_rev(p_po_number, -- v 3.4 PRG messaging
                                                 p_vendor_name,
                                                 p_requester_name);
        ELSE
          -- Approved Once
          v_stat := ttec_build_msg_ttec_cnstg_app(p_po_number, -- v 3.4 PRG messaging
                                                 p_vendor_name,
                                                 p_requester_name);
      END CASE;ELSE
      v_stat := -1;
    END IF;

    RETURN v_stat; -- -1 error generating PO Graphic
  END ttec_po_email_ttec_cnstg_gen;

  -- Version 9.1 <end>

  /* Routine to email the PO */
  FUNCTION ttec_email_out_file(p_email_to   VARCHAR2,
                               p_email_from VARCHAR2,
                               p_file_name  VARCHAR2,
                               p_subject    VARCHAR2,
                               p_body       VARCHAR2) RETURN NUMBER IS
    l_msg       VARCHAR2(2000):=NULL;
    l_mesg      VARCHAR2(400):=NULL;
    l_status    NUMBER;
    l_host_name VARCHAR2(256);
    l_filedir   VARCHAR2(256);
    l_tc_filename   VARCHAR2(256):=NULL;
    l_filename_tc   VARCHAR2(256):=NULL;
    l_request_id    NUMBER:=NULL;
    v_interval              NUMBER := 30; -- time change to 60
    v_max_wait              NUMBER := 0;
    v_request_phase         VARCHAR2(64);
    v_request_status        VARCHAR2(64);
    v_dev_request_phase     VARCHAR2(64);
    v_dev_request_status    VARCHAR2(64);
    v_request_status_mesg   VARCHAR2(64);
    v_call_status           BOOLEAN;
    --  crlf          CHAR (2)        := CHR (10) || CHR (13);
  BEGIN

    /* 12.0.2 Begin */
    IF g_TC_attachment_filename IS NOT NULL THEN
          l_tc_filename := g_temp_dir || '/' ||g_TC_attachment_filename;

          l_filename_tc := REPLACE(p_file_name,'.PDF','_TC.PDF');

          l_request_id := fnd_request.submit_request(application => 'CUST',
                                                     program     => 'TTEC_CONCAT_PDF_FILES_2',
                                                     argument1   => p_file_name,
                                                     argument2   => l_tc_filename,
                                                     argument3   => l_filename_tc);

          commit;


          if l_request_id > 0 then

             fnd_file.put_line(fnd_file.LOG,'Successfully submitted ... Request ID:'||l_request_id);

          --Wait for request to finish
          v_call_status := fnd_concurrent.wait_for_request(l_request_id,
                                                     v_interval,
                                                     v_max_wait,
                                                     v_request_phase,
                                                     v_request_status,
                                                     v_dev_request_phase,
                                                     v_dev_request_status,
                                                     v_request_status_mesg);


              IF (v_dev_request_phase = 'COMPLETE' AND
                  v_dev_request_status = 'NORMAL')
              THEN
                fnd_file.put_line(fnd_file.LOG,'TTEC_CONCAT_PDF_FILES_2 completed Successfully...');
              ELSE
                fnd_file.put_line(fnd_file.LOG,'TTEC_CONCAT_PDF_FILES_2 has raised an issue, ERROR: '|| v_request_status_mesg);
                l_filename_tc :=p_file_name;
              END IF;

          else

             fnd_file.put_line(fnd_file.LOG,'Not Submitted');
          end if;
    ELSE
       l_filename_tc :=p_file_name;
    END IF;
    /* 12.0.2 End */


    print_line(' send_email->ttec_library.XX_TTEC_SMTP_SERVER: PO ' ||
               l_filename_tc);

    print_line('Email Subject - '||p_subject||' Length - '||lengthb(p_subject));
    print_line('Email Body Length - '||lengthb(p_body));
    print_line('Time Before Send Email Procedure' || to_char(sysdate,'DD-MON-YYYY HH24:MI:SS'));

    send_email(ttec_library.XX_TTEC_SMTP_SERVER, /* Rehosting project change for smtp */
               --g_host_name,
               p_email_from,
               p_email_to,
               NULL,
               NULL,
               p_subject, -- v_subject,
               p_body,
               NULL,
               NULL,
               NULL,
               NULL,
               l_filename_tc, --p_file_name, -- v_file_name,
               NULL, --l_tc_filename, /* 12.0.2 */ --NULL,
               NULL,
               NULL,
               NULL,
               l_status,
               l_mesg);

        print_line('Time After Send Email Procedure' || to_char(sysdate,'DD-MON-YYYY HH24:MI:SS'));
        print_line('Success sending email status '|| to_char(l_status) ||' '|| l_mesg);

    IF l_status > 0 THEN
      print_line('Error sending email ' || '|' || SQLCODE || '|' ||
                 SUBSTR(SQLERRM, 1, 80));
      -- let it return zero
    END IF;

    RETURN(0);
  END ttec_email_out_file;

  /* print AUS PO */
  FUNCTION ttec_po_run_aus_pdf(p_po_number IN VARCHAR2, p_date IN DATE)
    RETURN NUMBER IS
    v_request_id            NUMBER := 0;
    v_application_shrt_name VARCHAR2(20) := 'CUST';
    v_concprogramshortn     VARCHAR2(32) := 'POXPRPOP_TELETECH_NZ';
    v_description           VARCHAR2(64) := 'Graphic Teletech NZ Purchase Order Print';
    v_start_time            VARCHAR2(64) := ''; --  NULL;
    v_sub_request           BOOLEAN := FALSE;
    v_parameter1            VARCHAR2(64) := 'R';
    v_parameter2            VARCHAR2(64) := ''; -- Buyer number
    v_parameter3            VARCHAR2(64) := '813798'; -- PO from
    v_parameter4            VARCHAR2(64) := '813798'; -- PO from
    v_parameter5            VARCHAR2(64) := '';
    v_parameter6            VARCHAR2(64) := '';
    v_parameter7            VARCHAR2(64) := '';
    v_parameter8            VARCHAR2(64) := '';
    v_parameter9            VARCHAR2(64) := ''; -- approved
    v_parameter10           VARCHAR2(64) := ''; -- test
    v_parameter11           VARCHAR2(64) := 'Y'; -- print release option
    v_parameter12           VARCHAR2(64) := ''; -- sort by
    v_parameter13           VARCHAR2(64) := '46077';
    v_parameter14           VARCHAR2(64) := '2'; -- Fax Enable
    v_parameter15           VARCHAR2(64) := 'N'; -- fax number
    v_parameter16           VARCHAR2(64) := ''; --
    v_parameter17           VARCHAR2(64) := 'Y'; -- print canceled lines
    v_parameter18           VARCHAR2(64) := 'N'; -- print blankets
    v_parameter19           VARCHAR2(64) := '';
    v_parameter20           VARCHAR2(64) := '';
    v_interval              NUMBER := 30; -- time change to 60
    v_max_wait              NUMBER := 0;
    v_request_phase         VARCHAR2(64);
    v_request_status        VARCHAR2(64);
    v_dev_request_phase     VARCHAR2(64);
    v_dev_request_status    VARCHAR2(64);
    v_request_status_mesg   VARCHAR2(64);
    v_call_status           BOOLEAN;
    v_err                   VARCHAR2(64);
   -- v_user_id               NUMBER := 411890;
    v_respon_id             NUMBER := g_respon_id;
    v_respn_appl_id         NUMBER := g_respn_appl_id;
  BEGIN
    fnd_global.apps_initialize(g_user_id, v_respon_id, v_respn_appl_id);
    COMMIT;
    /*
     fnd_profile.get('USER_ID', v_user_id);
     fnd_profile.get('RESP_ID', v_resp_id);
     fnd_profile.get('RESP_APPL_ID', v_resp_appl_id);
    */

    /* to set default options
       function FND_REQUEST.SET_OPTIONS

              (implicit  IN varchar2 default 'NO',
               protected IN varchar2 default 'NO',
               language  IN varchar2 default NULL,
               territory IN varchar2 default NULL)
               return boolean;
    */
    /* submit a request to run */
    v_parameter3 := p_po_number;
    v_parameter4 := p_po_number;
    v_request_id := fnd_request.submit_request(v_application_shrt_name,
                                               v_concprogramshortn,
                                               v_description,
                                               v_start_time,
                                               v_sub_request,
                                               v_parameter1,
                                               v_parameter2,
                                               v_parameter3,
                                               v_parameter4,
                                               v_parameter5,
                                               v_parameter6,
                                               v_parameter7,
                                               v_parameter8,
                                               v_parameter9,
                                               v_parameter10,
                                               v_parameter11,
                                               v_parameter12,
                                               v_parameter13,
                                               v_parameter14,
                                               v_parameter15,
                                               v_parameter16,
                                               v_parameter17,
                                               v_parameter18,
                                               v_parameter19,
                                               v_parameter20);
    COMMIT;
    print_line('Submitted AUS PO print request. Request ID: ' ||
               TO_CHAR(v_request_id) || 'for PO Number: ' || p_po_number);

    IF v_request_id = 0 THEN
      RETURN(0); -- failed request return 0
    END IF;

    /* wait for the concurrent program to complete */
    v_call_status := fnd_concurrent.wait_for_request(v_request_id,
                                                     v_interval,
                                                     v_max_wait,
                                                     v_request_phase,
                                                     v_request_status,
                                                     v_dev_request_phase,
                                                     v_dev_request_status,
                                                     v_request_status_mesg);
    COMMIT;

    IF (v_dev_request_phase = 'COMPLETE' AND
       v_dev_request_status = 'NORMAL') THEN
      RETURN(v_request_id);
    ELSE
      RETURN(v_request_id);  -- version 9.4
     -- RETURN(0);
    END IF;
  EXCEPTION
    WHEN OTHERS THEN
      v_err := SUBSTR(SQLERRM, 1, 50);
      print_line('Error in  ttec_po_run_pdf ' || v_err);
      RETURN(0);
  END ttec_po_run_aus_pdf;





  /* print ROGENSI AUS PO   Ver 7.0 */
  FUNCTION ttec_po_run_rogenaus_pdf(p_po_number IN VARCHAR2, p_date IN DATE)
    RETURN NUMBER IS
    v_request_id            NUMBER := 0;
    v_application_shrt_name VARCHAR2(20) := 'CUST';
    v_concprogramshortn     VARCHAR2(32) := 'TTEC_ROGENSI_AUS_PO_PDF';--'POXPRPOP_TELETECH_NZ';
    v_description           VARCHAR2(64) := 'Graphic RogenSi Australia Purchase Order'; --'Graphic Teletech NZ Purchase Order Print';
    v_start_time            VARCHAR2(64) := ''; --  NULL;
    v_sub_request           BOOLEAN := FALSE;
    v_parameter1            VARCHAR2(64) := 'R';
    v_parameter2            VARCHAR2(64) := ''; -- Buyer number
    v_parameter3            VARCHAR2(64) := '813798'; -- PO from
    v_parameter4            VARCHAR2(64) := '813798'; -- PO from
    v_parameter5            VARCHAR2(64) := '';
    v_parameter6            VARCHAR2(64) := '';
    v_parameter7            VARCHAR2(64) := '';
    v_parameter8            VARCHAR2(64) := '';
    v_parameter9            VARCHAR2(64) := ''; -- approved
    v_parameter10           VARCHAR2(64) := ''; -- test
    v_parameter11           VARCHAR2(64) := 'Y'; -- print release option
    v_parameter12           VARCHAR2(64) := ''; -- sort by
    v_parameter13           VARCHAR2(64) := '46077';
    v_parameter14           VARCHAR2(64) := '2'; -- Fax Enable
    v_parameter15           VARCHAR2(64) := 'N'; -- fax number
    v_parameter16           VARCHAR2(64) := ''; --
    v_parameter17           VARCHAR2(64) := 'Y'; -- print canceled lines
    v_parameter18           VARCHAR2(64) := 'N'; -- print blankets
    v_parameter19           VARCHAR2(64) := '';
    v_parameter20           VARCHAR2(64) := '';
    v_interval              NUMBER := 30; -- time change to 60
    v_max_wait              NUMBER := 0;
    v_request_phase         VARCHAR2(64);
    v_request_status        VARCHAR2(64);
    v_dev_request_phase     VARCHAR2(64);
    v_dev_request_status    VARCHAR2(64);
    v_request_status_mesg   VARCHAR2(64);
    v_call_status           BOOLEAN;
    v_err                   VARCHAR2(64);
   -- v_user_id               NUMBER := 411890;
    v_respon_id             NUMBER := g_respon_id;
    v_respn_appl_id         NUMBER := g_respn_appl_id;
  BEGIN
    fnd_global.apps_initialize(g_user_id, v_respon_id, v_respn_appl_id);
    COMMIT;
    /* submit a request to run */
    v_parameter3 := p_po_number;
    v_parameter4 := p_po_number;
    v_request_id := fnd_request.submit_request(v_application_shrt_name,
                                               v_concprogramshortn,
                                               v_description,
                                               v_start_time,
                                               v_sub_request,
                                               v_parameter1,
                                               v_parameter2,
                                               v_parameter3,
                                               v_parameter4,
                                               v_parameter5,
                                               v_parameter6,
                                               v_parameter7,
                                               v_parameter8,
                                               v_parameter9,
                                               v_parameter10,
                                               v_parameter11,
                                               v_parameter12,
                                               v_parameter13,
                                               v_parameter14,
                                               v_parameter15,
                                               v_parameter16,
                                               v_parameter17,
                                               v_parameter18,
                                               v_parameter19,
                                               v_parameter20);
    COMMIT;
    print_line('Submitted AUS PO print request. Request ID: ' ||
               TO_CHAR(v_request_id) || 'for PO Number: ' || p_po_number);

    IF v_request_id = 0 THEN
      RETURN(0); -- failed request return 0
    END IF;

    /* wait for the concurrent program to complete */
    v_call_status := fnd_concurrent.wait_for_request(v_request_id,
                                                     v_interval,
                                                     v_max_wait,
                                                     v_request_phase,
                                                     v_request_status,
                                                     v_dev_request_phase,
                                                     v_dev_request_status,
                                                     v_request_status_mesg);
    COMMIT;

    IF (v_dev_request_phase = 'COMPLETE' AND
       v_dev_request_status = 'NORMAL') THEN
      RETURN(v_request_id);
    ELSE
      RETURN(v_request_id);  -- version 9.4
      -- RETURN(0);
    END IF;
  EXCEPTION
    WHEN OTHERS THEN
      v_err := SUBSTR(SQLERRM, 1, 50);
      print_line('Error in  ttec_po_run_pdf ' || v_err);
      RETURN(0);
  END ttec_po_run_rogenaus_pdf;

  /* print ROGENSI CHN PO   Ver 9.0 */
  FUNCTION ttec_po_run_rogenchn_pdf(p_po_number IN VARCHAR2, p_date IN DATE)
    RETURN NUMBER IS
    v_request_id            NUMBER := 0;
    v_application_shrt_name VARCHAR2(20) := 'CUST';
    v_concprogramshortn     VARCHAR2(32) := 'TTEC_ROGENSI_CHN_PO_PDF';--'POXPRPOP_TELETECH_NZ';
    v_description           VARCHAR2(64) := 'Graphic RogenSi China Purchase Order'; --'Graphic Teletech NZ Purchase Order Print';
    v_start_time            VARCHAR2(64) := ''; --  NULL;
    v_sub_request           BOOLEAN := FALSE;
    v_parameter1            VARCHAR2(64) := 'R';
    v_parameter2            VARCHAR2(64) := ''; -- Buyer number
    v_parameter3            VARCHAR2(64) := '813798'; -- PO from
    v_parameter4            VARCHAR2(64) := '813798'; -- PO from
    v_parameter5            VARCHAR2(64) := '';
    v_parameter6            VARCHAR2(64) := '';
    v_parameter7            VARCHAR2(64) := '';
    v_parameter8            VARCHAR2(64) := '';
    v_parameter9            VARCHAR2(64) := ''; -- approved
    v_parameter10           VARCHAR2(64) := ''; -- test
    v_parameter11           VARCHAR2(64) := 'Y'; -- print release option
    v_parameter12           VARCHAR2(64) := ''; -- sort by
    v_parameter13           VARCHAR2(64) := '46077';
    v_parameter14           VARCHAR2(64) := '2'; -- Fax Enable
    v_parameter15           VARCHAR2(64) := 'N'; -- fax number
    v_parameter16           VARCHAR2(64) := ''; --
    v_parameter17           VARCHAR2(64) := 'Y'; -- print canceled lines
    v_parameter18           VARCHAR2(64) := 'N'; -- print blankets
    v_parameter19           VARCHAR2(64) := '';
    v_parameter20           VARCHAR2(64) := '';
    v_interval              NUMBER := 30; -- time change to 60
    v_max_wait              NUMBER := 0;
    v_request_phase         VARCHAR2(64);
    v_request_status        VARCHAR2(64);
    v_dev_request_phase     VARCHAR2(64);
    v_dev_request_status    VARCHAR2(64);
    v_request_status_mesg   VARCHAR2(64);
    v_call_status           BOOLEAN;
    v_err                   VARCHAR2(64);
   -- v_user_id               NUMBER := 411890;
    v_respon_id             NUMBER := g_respon_id;
    v_respn_appl_id         NUMBER := g_respn_appl_id;
  BEGIN
    fnd_global.apps_initialize(g_user_id, v_respon_id, v_respn_appl_id);
    COMMIT;
    /* submit a request to run */
    v_parameter3 := p_po_number;
    v_parameter4 := p_po_number;
    v_request_id := fnd_request.submit_request(v_application_shrt_name,
                                               v_concprogramshortn,
                                               v_description,
                                               v_start_time,
                                               v_sub_request,
                                               v_parameter1,
                                               v_parameter2,
                                               v_parameter3,
                                               v_parameter4,
                                               v_parameter5,
                                               v_parameter6,
                                               v_parameter7,
                                               v_parameter8,
                                               v_parameter9,
                                               v_parameter10,
                                               v_parameter11,
                                               v_parameter12,
                                               v_parameter13,
                                               v_parameter14,
                                               v_parameter15,
                                               v_parameter16,
                                               v_parameter17,
                                               v_parameter18,
                                               v_parameter19,
                                               v_parameter20);
    COMMIT;
    print_line('Submitted Rogen China PO print request. Request ID: ' ||
               TO_CHAR(v_request_id) || 'for PO Number: ' || p_po_number);

    IF v_request_id = 0 THEN
      RETURN(0); -- failed request return 0
    END IF;

    /* wait for the concurrent program to complete */
    v_call_status := fnd_concurrent.wait_for_request(v_request_id,
                                                     v_interval,
                                                     v_max_wait,
                                                     v_request_phase,
                                                     v_request_status,
                                                     v_dev_request_phase,
                                                     v_dev_request_status,
                                                     v_request_status_mesg);
    COMMIT;

    IF (v_dev_request_phase = 'COMPLETE' AND
       v_dev_request_status = 'NORMAL') THEN
      RETURN(v_request_id);
    ELSE
      RETURN(v_request_id);  -- version 9.4
      -- RETURN(0);
    END IF;
  EXCEPTION
    WHEN OTHERS THEN
      v_err := SUBSTR(SQLERRM, 1, 50);
      print_line('Error in ttec_po_run_rogenchn_pdf ' || v_err);
      RETURN(0);
  END ttec_po_run_rogenchn_pdf;

  /* print TTEC Consulting Belgium   Ver 9.1 */
  FUNCTION ttec_po_run_ttec_cnstg_bel_pdf(p_po_number IN VARCHAR2, p_date IN DATE)
    RETURN NUMBER IS
    v_request_id            NUMBER := 0;
    v_application_shrt_name VARCHAR2(20) := 'CUST';
    v_concprogramshortn     VARCHAR2(32) := 'TTEC_CSLTG_BELGIUM_PO_PDF';--'POXPRPOP_TELETECH_NZ';
    v_description           VARCHAR2(64) := 'Graphic TTEC Consulting Belgium Purchase Order'; --'Graphic Teletech NZ Purchase Order Print';
    v_start_time            VARCHAR2(64) := ''; --  NULL;
    v_sub_request           BOOLEAN := FALSE;
    v_parameter1            VARCHAR2(64) := 'R';
    v_parameter2            VARCHAR2(64) := ''; -- Buyer number
    v_parameter3            VARCHAR2(64) := '813798'; -- PO from
    v_parameter4            VARCHAR2(64) := '813798'; -- PO from
    v_parameter5            VARCHAR2(64) := '';
    v_parameter6            VARCHAR2(64) := '';
    v_parameter7            VARCHAR2(64) := '';
    v_parameter8            VARCHAR2(64) := '';
    v_parameter9            VARCHAR2(64) := ''; -- approved
    v_parameter10           VARCHAR2(64) := ''; -- test
    v_parameter11           VARCHAR2(64) := 'Y'; -- print release option
    v_parameter12           VARCHAR2(64) := ''; -- sort by
    v_parameter13           VARCHAR2(64) := '46077';
    v_parameter14           VARCHAR2(64) := '2'; -- Fax Enable
    v_parameter15           VARCHAR2(64) := 'N'; -- fax number
    v_parameter16           VARCHAR2(64) := ''; --
    v_parameter17           VARCHAR2(64) := 'Y'; -- print canceled lines
    v_parameter18           VARCHAR2(64) := 'N'; -- print blankets
    v_parameter19           VARCHAR2(64) := '';
    v_parameter20           VARCHAR2(64) := '';
    v_interval              NUMBER := 30; -- time change to 60
    v_max_wait              NUMBER := 0;
    v_request_phase         VARCHAR2(64);
    v_request_status        VARCHAR2(64);
    v_dev_request_phase     VARCHAR2(64);
    v_dev_request_status    VARCHAR2(64);
    v_request_status_mesg   VARCHAR2(64);
    v_call_status           BOOLEAN;
    v_err                   VARCHAR2(64);
   -- v_user_id               NUMBER := 411890;
    v_respon_id             NUMBER := g_respon_id;
    v_respn_appl_id         NUMBER := g_respn_appl_id;
  BEGIN
    fnd_global.apps_initialize(g_user_id, v_respon_id, v_respn_appl_id);
    COMMIT;
    /* submit a request to run */
    v_parameter3 := p_po_number;
    v_parameter4 := p_po_number;
    v_request_id := fnd_request.submit_request(v_application_shrt_name,
                                               v_concprogramshortn,
                                               v_description,
                                               v_start_time,
                                               v_sub_request,
                                               v_parameter1,
                                               v_parameter2,
                                               v_parameter3,
                                               v_parameter4,
                                               v_parameter5,
                                               v_parameter6,
                                               v_parameter7,
                                               v_parameter8,
                                               v_parameter9,
                                               v_parameter10,
                                               v_parameter11,
                                               v_parameter12,
                                               v_parameter13,
                                               v_parameter14,
                                               v_parameter15,
                                               v_parameter16,
                                               v_parameter17,
                                               v_parameter18,
                                               v_parameter19,
                                               v_parameter20);
    COMMIT;
    print_line('Submitted TTEC Consulting Belgium PO print request. Request ID: ' ||
               TO_CHAR(v_request_id) || 'for PO Number: ' || p_po_number);

    IF v_request_id = 0 THEN
      RETURN(0); -- failed request return 0
    END IF;

    /* wait for the concurrent program to complete */
    v_call_status := fnd_concurrent.wait_for_request(v_request_id,
                                                     v_interval,
                                                     v_max_wait,
                                                     v_request_phase,
                                                     v_request_status,
                                                     v_dev_request_phase,
                                                     v_dev_request_status,
                                                     v_request_status_mesg);
    COMMIT;

    IF (v_dev_request_phase = 'COMPLETE' AND
       v_dev_request_status = 'NORMAL') THEN
      RETURN(v_request_id);
    ELSE
      RETURN(v_request_id);  -- version 9.4
      -- RETURN(0);
    END IF;
  EXCEPTION
    WHEN OTHERS THEN
      v_err := SUBSTR(SQLERRM, 1, 50);
      print_line('Error in ttec_po_run_ttec_cnstg_bel_pdf ' || v_err);
      RETURN(0);
  END ttec_po_run_ttec_cnstg_bel_pdf;

  /* print Atelka Canada Ver 9.2 */
  FUNCTION ttec_po_run_atelka_ca_pdf(p_po_number IN VARCHAR2, p_date IN DATE)
    RETURN NUMBER IS
    v_request_id            NUMBER := 0;
    v_application_shrt_name VARCHAR2(20) := 'CUST';
    v_concprogramshortn     VARCHAR2(32) := 'TTEC_ATELKA_CA_PO_PDF';
    v_description           VARCHAR2(64) := 'Graphic Atelka CA Purchase Order';
    v_start_time            VARCHAR2(64) := ''; --  NULL;
    v_sub_request           BOOLEAN := FALSE;
    v_parameter1            VARCHAR2(64) := 'R';
    v_parameter2            VARCHAR2(64) := ''; -- Buyer number
    v_parameter3            VARCHAR2(64) := '106202'; -- PO from
    v_parameter4            VARCHAR2(64) := '106202'; -- PO from
    v_parameter5            VARCHAR2(64) := '';
    v_parameter6            VARCHAR2(64) := '';
    v_parameter7            VARCHAR2(64) := '';
    v_parameter8            VARCHAR2(64) := '';
    v_parameter9            VARCHAR2(64) := ''; -- approved
    v_parameter10           VARCHAR2(64) := ''; -- test
    v_parameter11           VARCHAR2(64) := 'Y'; -- print release option
    v_parameter12           VARCHAR2(64) := ''; -- sort by
    v_parameter13           VARCHAR2(64) := '46077';
    v_parameter14           VARCHAR2(64) := '2'; -- Fax Enable
    v_parameter15           VARCHAR2(64) := 'N'; -- fax number
    v_parameter16           VARCHAR2(64) := ''; --
    v_parameter17           VARCHAR2(64) := 'Y'; -- print canceled lines
    v_parameter18           VARCHAR2(64) := 'N'; -- print blankets
    v_parameter19           VARCHAR2(64) := '';
    v_parameter20           VARCHAR2(64) := '';
    v_interval              NUMBER := 30; -- time change to 60
    v_max_wait              NUMBER := 0;
    v_request_phase         VARCHAR2(64);
    v_request_status        VARCHAR2(64);
    v_dev_request_phase     VARCHAR2(64);
    v_dev_request_status    VARCHAR2(64);
    v_request_status_mesg   VARCHAR2(64);
    v_call_status           BOOLEAN;
    v_err                   VARCHAR2(64);
   -- v_user_id               NUMBER := 411890;
    v_respon_id             NUMBER := g_respon_id;
    v_respn_appl_id         NUMBER := g_respn_appl_id;
  BEGIN
    fnd_global.apps_initialize(g_user_id, v_respon_id, v_respn_appl_id);
    COMMIT;
    /* submit a request to run */
    v_parameter3 := p_po_number;
    v_parameter4 := p_po_number;
    v_request_id := fnd_request.submit_request(v_application_shrt_name,
                                               v_concprogramshortn,
                                               v_description,
                                               v_start_time,
                                               v_sub_request,
                                               v_parameter1,
                                               v_parameter2,
                                               v_parameter3,
                                               v_parameter4,
                                               v_parameter5,
                                               v_parameter6,
                                               v_parameter7,
                                               v_parameter8,
                                               v_parameter9,
                                               v_parameter10,
                                               v_parameter11,
                                               v_parameter12,
                                               v_parameter13,
                                               v_parameter14,
                                               v_parameter15,
                                               v_parameter16,
                                               v_parameter17,
                                               v_parameter18,
                                               v_parameter19,
                                               v_parameter20);
    COMMIT;
    print_line('Submitted Atelka Canada PO print request. Request ID: ' ||
               TO_CHAR(v_request_id) || ' for PO Number: ' || p_po_number);

    IF v_request_id = 0 THEN
      RETURN(0); -- failed request return 0
    END IF;

    /* wait for the concurrent program to complete */
    v_call_status := fnd_concurrent.wait_for_request(v_request_id,
                                                     v_interval,
                                                     v_max_wait,
                                                     v_request_phase,
                                                     v_request_status,
                                                     v_dev_request_phase,
                                                     v_dev_request_status,
                                                     v_request_status_mesg);
    COMMIT;

    IF (v_dev_request_phase = 'COMPLETE' AND
       v_dev_request_status = 'NORMAL') THEN
      RETURN(v_request_id);
    ELSE
     -- RETURN(v_request_id);  -- version 9.4
      RETURN(0);
    END IF;
  EXCEPTION
    WHEN OTHERS THEN
      v_err := SUBSTR(SQLERRM, 1, 50);
      print_line('Error in ttec_po_run_atelka_ca_pdf ' || v_err);
      RETURN(0);
  END ttec_po_run_atelka_ca_pdf;

  /* print Spain PO */
  FUNCTION ttec_po_run_spn_pdf(p_po_number IN VARCHAR2, p_date IN DATE)
    RETURN NUMBER IS
    v_request_id            NUMBER := 0;
    v_application_shrt_name VARCHAR2(20) := 'CUST';
    v_concprogramshortn     VARCHAR2(32) := 'TTEC_SPAIN_PDF_PO';
    v_description           VARCHAR2(64) := 'Graphic Teletech Spain Purchase Orde';
    v_start_time            VARCHAR2(64) := ''; --  NULL;
    v_sub_request           BOOLEAN := FALSE;
    v_parameter1            VARCHAR2(64) := 'R';
    v_parameter2            VARCHAR2(64) := ''; -- Buyer number
    v_parameter3            VARCHAR2(64) := '902624'; -- PO from
    v_parameter4            VARCHAR2(64) := '902624'; -- PO from
    v_parameter5            VARCHAR2(64) := '';
    v_parameter6            VARCHAR2(64) := '';
    v_parameter7            VARCHAR2(64) := '';
    v_parameter8            VARCHAR2(64) := '';
    v_parameter9            VARCHAR2(64) := ''; -- approved
    v_parameter10           VARCHAR2(64) := ''; -- test
    v_parameter11           VARCHAR2(64) := 'Y'; -- print release option
    v_parameter12           VARCHAR2(64) := ''; -- sort by
    v_parameter13           VARCHAR2(64) := '46077';
    v_parameter14           VARCHAR2(64) := '2'; -- Fax Enable
    v_parameter15           VARCHAR2(64) := 'N'; -- fax number
    v_parameter16           VARCHAR2(64) := ''; --
    v_parameter17           VARCHAR2(64) := 'Y'; -- print canceled lines
    v_parameter18           VARCHAR2(64) := 'N'; -- print blankets
    v_parameter19           VARCHAR2(64) := '';
    v_parameter20           VARCHAR2(64) := '';
    v_interval              NUMBER := 30; -- time change to 60
    v_max_wait              NUMBER := 0;
    v_request_phase         VARCHAR2(64);
    v_request_status        VARCHAR2(64);
    v_dev_request_phase     VARCHAR2(64);
    v_dev_request_status    VARCHAR2(64);
    v_request_status_mesg   VARCHAR2(64);
    v_call_status           BOOLEAN;
    v_err                   VARCHAR2(64);
   -- v_user_id               NUMBER := 411890;
    v_respon_id             NUMBER := g_respon_id;
    v_respn_appl_id         NUMBER := g_respn_appl_id;
  BEGIN
    fnd_global.apps_initialize(g_user_id, v_respon_id, v_respn_appl_id);
    COMMIT;
    /*
     fnd_profile.get('USER_ID', v_user_id);
     fnd_profile.get('RESP_ID', v_resp_id);
     fnd_profile.get('RESP_APPL_ID', v_resp_appl_id);

    */

    /* to set default options
       function FND_REQUEST.SET_OPTIONS

              (implicit  IN varchar2 default 'NO',
               protected IN varchar2 default 'NO',
               language  IN varchar2 default NULL,
               territory IN varchar2 default NULL)
               return boolean;
    */
    /* submit a request to run */
    v_parameter3 := p_po_number;
    v_parameter4 := p_po_number;
    v_request_id := fnd_request.submit_request(v_application_shrt_name,
                                               v_concprogramshortn,
                                               v_description,
                                               v_start_time,
                                               v_sub_request,
                                               v_parameter1,
                                               v_parameter2,
                                               v_parameter3,
                                               v_parameter4,
                                               v_parameter5,
                                               v_parameter6,
                                               v_parameter7,
                                               v_parameter8,
                                               v_parameter9,
                                               v_parameter10,
                                               v_parameter11,
                                               v_parameter12,
                                               v_parameter13,
                                               v_parameter14,
                                               v_parameter15,
                                               v_parameter16,
                                               v_parameter17,
                                               v_parameter18,
                                               v_parameter19,
                                               v_parameter20);
    COMMIT;
    print_line('Submitted Spain PO print request. Request ID: ' ||
               TO_CHAR(v_request_id) || ' for PO Number: ' || p_po_number);

    IF v_request_id = 0 THEN
      RETURN(0); -- failed request return 0
    END IF;

    /* wait for the concurrent program to complete */
    v_call_status := fnd_concurrent.wait_for_request(v_request_id,
                                                     v_interval,
                                                     v_max_wait,
                                                     v_request_phase,
                                                     v_request_status,
                                                     v_dev_request_phase,
                                                     v_dev_request_status,
                                                     v_request_status_mesg);
    COMMIT;

    IF (v_dev_request_phase = 'COMPLETE' AND
       v_dev_request_status = 'NORMAL') THEN
      RETURN(v_request_id);
    ELSE
      RETURN(v_request_id);  -- version 9.4
      -- RETURN(0);
    END IF;
  EXCEPTION
    WHEN OTHERS THEN
      v_err := SUBSTR(SQLERRM, 1, 50);
      print_line('Error in  ttec_po_run_pdf ' || v_err);
      RETURN(0);
  END ttec_po_run_spn_pdf;

  /* print UK PO */
  FUNCTION ttec_po_run_uk_pdf(p_po_number IN VARCHAR2, p_date IN DATE)
    RETURN NUMBER IS
    v_request_id            NUMBER := 0;
    v_application_shrt_name VARCHAR2(20) := 'CUST';
    v_concprogramshortn     VARCHAR2(32) := 'TTEC_UK_PDF_PO';
    v_description           VARCHAR2(64) := 'Graphic Teletech UK Purchase Order';
    v_start_time            VARCHAR2(64) := ''; --  NULL;
    v_sub_request           BOOLEAN := FALSE;
    v_parameter1            VARCHAR2(64) := 'R';
    v_parameter2            VARCHAR2(64) := ''; -- Buyer number
    v_parameter3            VARCHAR2(64) := '403284'; -- PO from
    v_parameter4            VARCHAR2(64) := '403284'; -- PO from
    v_parameter5            VARCHAR2(64) := '';
    v_parameter6            VARCHAR2(64) := '';
    v_parameter7            VARCHAR2(64) := '';
    v_parameter8            VARCHAR2(64) := '';
    v_parameter9            VARCHAR2(64) := ''; -- approved
    v_parameter10           VARCHAR2(64) := ''; -- test
    v_parameter11           VARCHAR2(64) := 'Y'; -- print release option
    v_parameter12           VARCHAR2(64) := ''; -- sort by
    v_parameter13           VARCHAR2(64) := '46077';
    v_parameter14           VARCHAR2(64) := '2'; -- Fax Enable
    v_parameter15           VARCHAR2(64) := 'N'; -- fax number
    v_parameter16           VARCHAR2(64) := ''; --
    v_parameter17           VARCHAR2(64) := 'Y'; -- print canceled lines
    v_parameter18           VARCHAR2(64) := 'N'; -- print blankets
    v_parameter19           VARCHAR2(64) := '';
    v_parameter20           VARCHAR2(64) := '';
    v_interval              NUMBER := 30; -- time change to 60
    v_max_wait              NUMBER := 0;
    v_request_phase         VARCHAR2(64);
    v_request_status        VARCHAR2(64);
    v_dev_request_phase     VARCHAR2(64);
    v_dev_request_status    VARCHAR2(64);
    v_request_status_mesg   VARCHAR2(64);
    v_call_status           BOOLEAN;
    v_err                   VARCHAR2(64);
   -- v_user_id               NUMBER := 411890;
    v_respon_id             NUMBER := g_respon_id;
    v_respn_appl_id         NUMBER := g_respn_appl_id;
  BEGIN
    fnd_global.apps_initialize(g_user_id, v_respon_id, v_respn_appl_id);
    COMMIT;
    v_parameter3 := p_po_number;
    v_parameter4 := p_po_number;
    v_request_id := fnd_request.submit_request(v_application_shrt_name,
                                               v_concprogramshortn,
                                               v_description,
                                               v_start_time,
                                               v_sub_request,
                                               v_parameter1,
                                               v_parameter2,
                                               v_parameter3,
                                               v_parameter4,
                                               v_parameter5,
                                               v_parameter6,
                                               v_parameter7,
                                               v_parameter8,
                                               v_parameter9,
                                               v_parameter10,
                                               v_parameter11,
                                               v_parameter12,
                                               v_parameter13,
                                               v_parameter14,
                                               v_parameter15,
                                               v_parameter16,
                                               v_parameter17,
                                               v_parameter18,
                                               v_parameter19,
                                               v_parameter20);
    COMMIT;
    print_line('Submitted UK PO print request. Request ID: ' ||
               TO_CHAR(v_request_id) || ' for PO Number: ' || p_po_number);

    IF v_request_id = 0 THEN
      RETURN(0); -- failed request return 0
    END IF;

    /* wait for the concurrent program to complete */
    v_call_status := fnd_concurrent.wait_for_request(v_request_id,
                                                     v_interval,
                                                     v_max_wait,
                                                     v_request_phase,
                                                     v_request_status,
                                                     v_dev_request_phase,
                                                     v_dev_request_status,
                                                     v_request_status_mesg);
    COMMIT;

    IF (v_dev_request_phase = 'COMPLETE' AND
       v_dev_request_status = 'NORMAL') THEN
      RETURN(v_request_id);
    ELSE
      RETURN(v_request_id);  -- version 9.4
      -- RETURN(0);
    END IF;
  EXCEPTION
    WHEN OTHERS THEN
      v_err := SUBSTR(SQLERRM, 1, 50);
      print_line('Error in  ttec_po_run_pdf ' || v_err);
      RETURN(0);
  END ttec_po_run_uk_pdf;




  /* print RogensiUK PO   Ver 7.0 */
  FUNCTION ttec_po_run_rogenuk_pdf(p_po_number IN VARCHAR2, p_date IN DATE)
    RETURN NUMBER IS
    v_request_id            NUMBER := 0;
    v_application_shrt_name VARCHAR2(20) := 'CUST';
    v_concprogramshortn     VARCHAR2(32) := 'TTEC_UK_PO_PDF'; -- 'TTEC_UK_PDF_PO';
    v_description           VARCHAR2(64) := 'Graphic United Kingdom Purchase Order'; --'Graphic Teletech UK Purchase Order';
    v_start_time            VARCHAR2(64) := ''; --  NULL;
    v_sub_request           BOOLEAN := FALSE;
    v_parameter1            VARCHAR2(64) := 'R';
    v_parameter2            VARCHAR2(64) := ''; -- Buyer number
    v_parameter3            VARCHAR2(64) := '403284'; -- PO from
    v_parameter4            VARCHAR2(64) := '403284'; -- PO from
    v_parameter5            VARCHAR2(64) := '';
    v_parameter6            VARCHAR2(64) := '';
    v_parameter7            VARCHAR2(64) := '';
    v_parameter8            VARCHAR2(64) := '';
    v_parameter9            VARCHAR2(64) := ''; -- approved
    v_parameter10           VARCHAR2(64) := ''; -- test
    v_parameter11           VARCHAR2(64) := 'Y'; -- print release option
    v_parameter12           VARCHAR2(64) := ''; -- sort by
    v_parameter13           VARCHAR2(64) := '46077';
    v_parameter14           VARCHAR2(64) := '2'; -- Fax Enable
    v_parameter15           VARCHAR2(64) := 'N'; -- fax number
    v_parameter16           VARCHAR2(64) := ''; --
    v_parameter17           VARCHAR2(64) := 'Y'; -- print canceled lines
    v_parameter18           VARCHAR2(64) := 'N'; -- print blankets
    v_parameter19           VARCHAR2(64) := '';
    v_parameter20           VARCHAR2(64) := '';
    v_interval              NUMBER := 30; -- time change to 60
    v_max_wait              NUMBER := 0;
    v_request_phase         VARCHAR2(64);
    v_request_status        VARCHAR2(64);
    v_dev_request_phase     VARCHAR2(64);
    v_dev_request_status    VARCHAR2(64);
    v_request_status_mesg   VARCHAR2(64);
    v_call_status           BOOLEAN;
    v_err                   VARCHAR2(64);
   -- v_user_id               NUMBER := 411890;
    v_respon_id             NUMBER := g_respon_id;
    v_respn_appl_id         NUMBER := g_respn_appl_id;
  BEGIN
    fnd_global.apps_initialize(g_user_id, v_respon_id, v_respn_appl_id);
    COMMIT;
    v_parameter3 := p_po_number;
    v_parameter4 := p_po_number;
    v_request_id := fnd_request.submit_request(v_application_shrt_name,
                                               v_concprogramshortn,
                                               v_description,
                                               v_start_time,
                                               v_sub_request,
                                               v_parameter1,
                                               v_parameter2,
                                               v_parameter3,
                                               v_parameter4,
                                               v_parameter5,
                                               v_parameter6,
                                               v_parameter7,
                                               v_parameter8,
                                               v_parameter9,
                                               v_parameter10,
                                               v_parameter11,
                                               v_parameter12,
                                               v_parameter13,
                                               v_parameter14,
                                               v_parameter15,
                                               v_parameter16,
                                               v_parameter17,
                                               v_parameter18,
                                               v_parameter19,
                                               v_parameter20);
    COMMIT;
    print_line('Submitted UK PO print request. Request ID: ' ||
               TO_CHAR(v_request_id) || ' for PO Number: ' || p_po_number);

    IF v_request_id = 0 THEN
      RETURN(0); -- failed request return 0
    END IF;

    /* wait for the concurrent program to complete */
    v_call_status := fnd_concurrent.wait_for_request(v_request_id,
                                                     v_interval,
                                                     v_max_wait,
                                                     v_request_phase,
                                                     v_request_status,
                                                     v_dev_request_phase,
                                                     v_dev_request_status,
                                                     v_request_status_mesg);
    COMMIT;

    IF (v_dev_request_phase = 'COMPLETE' AND
       v_dev_request_status = 'NORMAL') THEN
      RETURN(v_request_id);
    ELSE
      RETURN(v_request_id);  -- version 9.4
      -- RETURN(0);
    END IF;
  EXCEPTION
    WHEN OTHERS THEN
      v_err := SUBSTR(SQLERRM, 1, 50);
      print_line('Error in  ttec_po_run_pdf ' || v_err);
      RETURN(0);
  END ttec_po_run_rogenuk_pdf;






  /* print Ireland PO Ver 4.0*/
  FUNCTION ttec_po_run_ire_pdf(p_po_number IN VARCHAR2, p_date IN DATE)
    RETURN NUMBER IS
    v_request_id            NUMBER := 0;
    v_application_shrt_name VARCHAR2(20) := 'CUST';
    v_concprogramshortn     VARCHAR2(32) := 'TTEC_UK_PDF_PO';
    v_description           VARCHAR2(64) := 'Graphic Teletech UK Purchase Order';
    v_start_time            VARCHAR2(64) := ''; --  NULL;
    v_sub_request           BOOLEAN := FALSE;
    v_parameter1            VARCHAR2(64) := 'R';
    v_parameter2            VARCHAR2(64) := ''; -- Buyer number
    v_parameter3            VARCHAR2(64) := '3'; -- PO from
    v_parameter4            VARCHAR2(64) := '3'; -- PO from
    v_parameter5            VARCHAR2(64) := '';
    v_parameter6            VARCHAR2(64) := '';
    v_parameter7            VARCHAR2(64) := '';
    v_parameter8            VARCHAR2(64) := '';
    v_parameter9            VARCHAR2(64) := ''; -- approved
    v_parameter10           VARCHAR2(64) := ''; -- test
    v_parameter11           VARCHAR2(64) := 'Y'; -- print release option
    v_parameter12           VARCHAR2(64) := ''; -- sort by
    v_parameter13           VARCHAR2(64) := '46077';
    v_parameter14           VARCHAR2(64) := '2'; -- Fax Enable
    v_parameter15           VARCHAR2(64) := 'N'; -- fax number
    v_parameter16           VARCHAR2(64) := ''; --
    v_parameter17           VARCHAR2(64) := 'Y'; -- print canceled lines
    v_parameter18           VARCHAR2(64) := 'N'; -- print blankets
    v_parameter19           VARCHAR2(64) := '';
    v_parameter20           VARCHAR2(64) := '';
    v_interval              NUMBER := 30; -- time change to 60
    v_max_wait              NUMBER := 0;
    v_request_phase         VARCHAR2(64);
    v_request_status        VARCHAR2(64);
    v_dev_request_phase     VARCHAR2(64);
    v_dev_request_status    VARCHAR2(64);
    v_request_status_mesg   VARCHAR2(64);
    v_call_status           BOOLEAN;
    v_err                   VARCHAR2(64);
   -- v_user_id               NUMBER := 411890;
    v_respon_id             NUMBER := g_respon_id;
    v_respn_appl_id         NUMBER := g_respn_appl_id;
  BEGIN
    fnd_global.apps_initialize(g_user_id, v_respon_id, v_respn_appl_id);
    COMMIT;
    v_parameter3 := p_po_number;
    v_parameter4 := p_po_number;
    v_request_id := fnd_request.submit_request(v_application_shrt_name,
                                               v_concprogramshortn,
                                               v_description,
                                               v_start_time,
                                               v_sub_request,
                                               v_parameter1,
                                               v_parameter2,
                                               v_parameter3,
                                               v_parameter4,
                                               v_parameter5,
                                               v_parameter6,
                                               v_parameter7,
                                               v_parameter8,
                                               v_parameter9,
                                               v_parameter10,
                                               v_parameter11,
                                               v_parameter12,
                                               v_parameter13,
                                               v_parameter14,
                                               v_parameter15,
                                               v_parameter16,
                                               v_parameter17,
                                               v_parameter18,
                                               v_parameter19,
                                               v_parameter20);
    COMMIT;
    print_line('Submitted Ireland PO print request. Request ID: ' ||
               TO_CHAR(v_request_id) || ' for PO Number: ' || p_po_number);

    IF v_request_id = 0 THEN
      RETURN(0); -- failed request return 0
    END IF;

    /* wait for the concurrent program to complete */
    v_call_status := fnd_concurrent.wait_for_request(v_request_id,
                                                     v_interval,
                                                     v_max_wait,
                                                     v_request_phase,
                                                     v_request_status,
                                                     v_dev_request_phase,
                                                     v_dev_request_status,
                                                     v_request_status_mesg);
    COMMIT;

    IF (v_dev_request_phase = 'COMPLETE' AND
       v_dev_request_status = 'NORMAL') THEN
      RETURN(v_request_id);
    ELSE
      RETURN(v_request_id);  -- version 9.4
      -- RETURN(0);
    END IF;
  EXCEPTION
    WHEN OTHERS THEN
      v_err := SUBSTR(SQLERRM, 1, 50);
      print_line('Error in  ttec_po_run_ire_pdf ' || v_err);
      RETURN(0);
  END ttec_po_run_ire_pdf;

  /* print ARG PO */
  FUNCTION ttec_po_run_arg_pdf(p_po_number IN VARCHAR2, p_date IN DATE)
    RETURN NUMBER IS
    v_request_id            NUMBER := 0;
    v_application_shrt_name VARCHAR2(20) := 'CUST';
    v_concprogramshortn     VARCHAR2(32) := 'TTEC_ARGENTINE_PDF_PO';
    v_description           VARCHAR2(64) := 'Graphic TeleTech Argentina Purchase Order';
    v_start_time            VARCHAR2(64) := ''; --  NULL;
    v_sub_request           BOOLEAN := FALSE;
    v_parameter1            VARCHAR2(64) := 'R';
    v_parameter2            VARCHAR2(64) := ''; -- Buyer number
    v_parameter3            VARCHAR2(64) := '44515'; -- PO from
    v_parameter4            VARCHAR2(64) := '44515'; -- PO from
    v_parameter5            VARCHAR2(64) := '';
    v_parameter6            VARCHAR2(64) := '';
    v_parameter7            VARCHAR2(64) := '';
    v_parameter8            VARCHAR2(64) := '';
    v_parameter9            VARCHAR2(64) := ''; -- approved
    v_parameter10           VARCHAR2(64) := ''; -- test
    v_parameter11           VARCHAR2(64) := 'Y'; -- print release option
    v_parameter12           VARCHAR2(64) := ''; -- sort by
    v_parameter13           VARCHAR2(64) := '46077';
    v_parameter14           VARCHAR2(64) := '2'; -- Fax Enable
    v_parameter15           VARCHAR2(64) := 'N'; -- fax number
    v_parameter16           VARCHAR2(64) := ''; --
    v_parameter17           VARCHAR2(64) := 'Y'; -- print canceled lines
    v_parameter18           VARCHAR2(64) := 'N'; -- print blankets
    v_parameter19           VARCHAR2(64) := '';
    v_parameter20           VARCHAR2(64) := '';
    v_interval              NUMBER := 30; -- time change to 60
    v_max_wait              NUMBER := 0;
    v_request_phase         VARCHAR2(64);
    v_request_status        VARCHAR2(64);
    v_dev_request_phase     VARCHAR2(64);
    v_dev_request_status    VARCHAR2(64);
    v_request_status_mesg   VARCHAR2(64);
    v_call_status           BOOLEAN;
    v_err                   VARCHAR2(64);
   -- v_user_id               NUMBER := 411890;
    v_respon_id             NUMBER := g_respon_id;
    v_respn_appl_id         NUMBER := g_respn_appl_id;
  BEGIN
    fnd_global.apps_initialize(g_user_id, v_respon_id, v_respn_appl_id);
    COMMIT;
    /* submit a request to run */
    v_parameter3 := p_po_number;
    v_parameter4 := p_po_number;
    v_request_id := fnd_request.submit_request(v_application_shrt_name,
                                               v_concprogramshortn,
                                               v_description,
                                               v_start_time,
                                               v_sub_request,
                                               v_parameter1,
                                               v_parameter2,
                                               v_parameter3,
                                               v_parameter4,
                                               v_parameter5,
                                               v_parameter6,
                                               v_parameter7,
                                               v_parameter8,
                                               v_parameter9,
                                               v_parameter10,
                                               v_parameter11,
                                               v_parameter12,
                                               v_parameter13,
                                               v_parameter14,
                                               v_parameter15,
                                               v_parameter16,
                                               v_parameter17,
                                               v_parameter18,
                                               v_parameter19 --,
                                               -- v_parameter20
                                               );
    COMMIT;
    print_line('Submitted ARG PO print request. Request ID: ' ||
               TO_CHAR(v_request_id) || ' for PO Number: ' || p_po_number);

    IF v_request_id = 0 THEN
      RETURN(0); -- failed request return 0
    END IF;

    /* wait for the concurrent program to complete */
    v_call_status := fnd_concurrent.wait_for_request(v_request_id,
                                                     v_interval,
                                                     v_max_wait,
                                                     v_request_phase,
                                                     v_request_status,
                                                     v_dev_request_phase,
                                                     v_dev_request_status,
                                                     v_request_status_mesg);
    COMMIT;

    IF (v_dev_request_phase = 'COMPLETE' AND
       v_dev_request_status = 'NORMAL') THEN
      RETURN(v_request_id);
    ELSE
      RETURN(v_request_id);  -- version 9.4
      -- RETURN(0);
    END IF;
  EXCEPTION
    WHEN OTHERS THEN
      v_err := SUBSTR(SQLERRM, 1, 50);
      print_line('Error in  ttec_po_run_pdf ' || v_err);
      RETURN(0);
  END ttec_po_run_arg_pdf;

  /* Canada */
  FUNCTION ttec_po_run_can_pdf(p_po_number IN VARCHAR2, p_date IN DATE)
    RETURN NUMBER IS
    v_request_id            NUMBER := 0;
    v_application_shrt_name VARCHAR2(20) := 'CUST';
    v_concprogramshortn     VARCHAR2(32) := 'TTEC_US_CA_PDF_PO';
    v_description           VARCHAR2(64) := 'Graphic Teletech US/Canada Purchase Order';
    v_start_time            VARCHAR2(64) := ''; --  NULL;
    v_sub_request           BOOLEAN := FALSE;
    v_parameter1            VARCHAR2(64) := 'R';
    v_parameter2            VARCHAR2(64) := ''; -- Buyer number
    v_parameter3            VARCHAR2(64) := '106202'; -- PO from
    v_parameter4            VARCHAR2(64) := '106202'; -- PO from
    v_parameter5            VARCHAR2(64) := '';
    v_parameter6            VARCHAR2(64) := '';
    v_parameter7            VARCHAR2(64) := '';
    v_parameter8            VARCHAR2(64) := '';
    v_parameter9            VARCHAR2(64) := ''; -- approved
    v_parameter10           VARCHAR2(64) := ''; -- test
    v_parameter11           VARCHAR2(64) := 'Y'; -- print release option
    v_parameter12           VARCHAR2(64) := ''; -- sort by
    v_parameter13           VARCHAR2(64) := '46077';
    v_parameter14           VARCHAR2(64) := '2'; -- Fax Enable
    v_parameter15           VARCHAR2(64) := 'N'; -- fax number
    v_parameter16           VARCHAR2(64) := ''; --
    v_parameter17           VARCHAR2(64) := 'Y'; -- print canceled lines
    v_parameter18           VARCHAR2(64) := 'N'; -- print blankets
    v_parameter19           VARCHAR2(64) := '';
    v_parameter20           VARCHAR2(64) := '';
    v_interval              NUMBER := 30; -- time change to 60
    v_max_wait              NUMBER := 0;
    v_request_phase         VARCHAR2(64);
    v_request_status        VARCHAR2(64);
    v_dev_request_phase     VARCHAR2(64);
    v_dev_request_status    VARCHAR2(64);
    v_request_status_mesg   VARCHAR2(64);
    v_call_status           BOOLEAN;
    v_err                   VARCHAR2(64);
   -- v_user_id               NUMBER := 411890;
    v_respon_id             NUMBER := g_respon_id;
    v_respn_appl_id         NUMBER := g_respn_appl_id;
  BEGIN
    fnd_global.apps_initialize(g_user_id, v_respon_id, v_respn_appl_id);
    COMMIT;
    /* submit a request to run */
    v_parameter3 := p_po_number;
    v_parameter4 := p_po_number;
    v_request_id := fnd_request.submit_request(v_application_shrt_name,
                                               v_concprogramshortn,
                                               v_description,
                                               v_start_time,
                                               v_sub_request,
                                               v_parameter1,
                                               v_parameter2,
                                               v_parameter3,
                                               v_parameter4,
                                               v_parameter5,
                                               v_parameter6,
                                               v_parameter7,
                                               v_parameter8,
                                               v_parameter9,
                                               v_parameter10,
                                               v_parameter11,
                                               v_parameter12,
                                               v_parameter13,
                                               v_parameter14,
                                               v_parameter15,
                                               v_parameter16,
                                               v_parameter17,
                                               v_parameter18,
                                               v_parameter19,
                                               v_parameter20);
    COMMIT;
    print_line('Submitted Canada PO print request. Request ID: ' ||
               TO_CHAR(v_request_id) || ' for PO Number: ' || p_po_number);

    IF v_request_id = 0 THEN
      RETURN(0); -- failed request return 0
    END IF;

    /* wait for the concurrent program to complete */
    v_call_status := fnd_concurrent.wait_for_request(v_request_id,
                                                     v_interval,
                                                     v_max_wait,
                                                     v_request_phase,
                                                     v_request_status,
                                                     v_dev_request_phase,
                                                     v_dev_request_status,
                                                     v_request_status_mesg);
    COMMIT;

    IF (v_dev_request_phase = 'COMPLETE' AND
       v_dev_request_status = 'NORMAL') THEN
      RETURN(v_request_id);
    ELSE
      RETURN(v_request_id);  -- version 9.4
      -- RETURN(0);
    END IF;
  EXCEPTION
    WHEN OTHERS THEN
      v_err := SUBSTR(SQLERRM, 1, 50);
      print_line('Error in  ttec_po_run_pdf ' || v_err);
      RETURN(0);
  END ttec_po_run_can_pdf;

  /* US */
  FUNCTION ttec_po_run_us_pdf(p_po_number IN VARCHAR2, p_date IN DATE)
    RETURN NUMBER IS
    v_request_id            NUMBER := 0;
    v_application_shrt_name VARCHAR2(20) := 'CUST';
    v_concprogramshortn     VARCHAR2(32) := 'TTEC_US_CA_PDF_PO_TTEC_LOGO';
    v_description           VARCHAR2(64) := 'Graphic TTEC US/Canada Purchase Order';
    v_start_time            VARCHAR2(64) := ''; --  NULL;
    v_sub_request           BOOLEAN := FALSE;
    v_parameter1            VARCHAR2(64) := 'R';
    v_parameter2            VARCHAR2(64) := ''; -- Buyer number
    v_parameter3            VARCHAR2(64) := '220018'; -- PO from
    v_parameter4            VARCHAR2(64) := '220018'; -- PO from
    v_parameter5            VARCHAR2(64) := '';
    v_parameter6            VARCHAR2(64) := '';
    v_parameter7            VARCHAR2(64) := '';
    v_parameter8            VARCHAR2(64) := '';
    v_parameter9            VARCHAR2(64) := ''; -- approved
    v_parameter10           VARCHAR2(64) := ''; -- test
    v_parameter11           VARCHAR2(64) := 'Y'; -- print release option
    v_parameter12           VARCHAR2(64) := ''; -- sort by
    v_parameter13           VARCHAR2(64) := '46077';
    v_parameter14           VARCHAR2(64) := '2'; -- Fax Enable
    v_parameter15           VARCHAR2(64) := 'N'; -- fax number
    v_parameter16           VARCHAR2(64) := ''; --
    v_parameter17           VARCHAR2(64) := 'Y'; -- print canceled lines
    v_parameter18           VARCHAR2(64) := 'N'; -- print blankets
    v_parameter19           VARCHAR2(64) := '';
    v_parameter20           VARCHAR2(64) := '';
    v_interval              NUMBER := 30; -- time change to 60
    v_max_wait              NUMBER := 0;
    v_request_phase         VARCHAR2(64);
    v_request_status        VARCHAR2(64);
    v_dev_request_phase     VARCHAR2(64);
    v_dev_request_status    VARCHAR2(64);
    v_request_status_mesg   VARCHAR2(64);
    v_call_status           BOOLEAN;
    v_err                   VARCHAR2(64);
   -- v_user_id               NUMBER := 411890;
    v_respon_id             NUMBER := g_respon_id;
    v_respn_appl_id         NUMBER := g_respn_appl_id;
  BEGIN
    fnd_global.apps_initialize(g_user_id, v_respon_id, v_respn_appl_id);
    COMMIT;
    /* submit a request to run */
    v_parameter3 := p_po_number;
    v_parameter4 := p_po_number;
    v_request_id := fnd_request.submit_request(v_application_shrt_name,
                                               v_concprogramshortn,
                                               v_description,
                                               v_start_time,
                                               v_sub_request,
                                               v_parameter1,
                                               v_parameter2,
                                               v_parameter3,
                                               v_parameter4,
                                               v_parameter5,
                                               v_parameter6,
                                               v_parameter7,
                                               v_parameter8,
                                               v_parameter9,
                                               v_parameter10,
                                               v_parameter11,
                                               v_parameter12,
                                               v_parameter13,
                                               v_parameter14,
                                               v_parameter15,
                                               v_parameter16,
                                               v_parameter17,
                                               v_parameter18,
                                               v_parameter19,
                                               v_parameter20);
    COMMIT;
    print_line('Submitted US PO print request. Request ID: ' ||
               TO_CHAR(v_request_id) || ' for PO Number: ' || p_po_number);

    IF v_request_id = 0 THEN
      RETURN(0); -- failed request return 0
    END IF;

    /* wait for the concurrent program to complete */
    v_call_status := fnd_concurrent.wait_for_request(v_request_id,
                                                     v_interval,
                                                     v_max_wait,
                                                     v_request_phase,
                                                     v_request_status,
                                                     v_dev_request_phase,
                                                     v_dev_request_status,
                                                     v_request_status_mesg);
    COMMIT;

    IF (v_dev_request_phase = 'COMPLETE' AND
       v_dev_request_status = 'NORMAL') THEN
      RETURN(v_request_id);
    ELSE
      RETURN(v_request_id);  -- version 9.4
      -- RETURN(0);
    END IF;
  EXCEPTION
    WHEN OTHERS THEN
      v_err := SUBSTR(SQLERRM, 1, 50);
      print_line('Error in  ttec_po_run_pdf ' || v_err);
      RETURN(0);
  END ttec_po_run_us_pdf;

/* 9.7  Begin */
  FUNCTION ttec_po_run_global_pdf(p_po_number IN VARCHAR2, p_date IN DATE)
    RETURN NUMBER IS
    v_request_id            NUMBER := 0;
    v_application_shrt_name VARCHAR2(20) := 'CUST';
    v_concprogramshortn     VARCHAR2(32) := 'TTEC_GLOBAL_PDF_PO_BRANDING';
    v_description           VARCHAR2(64) := 'Graphic TTEC Global Purchase Order';
    v_start_time            VARCHAR2(64) := ''; --  NULL;
    v_sub_request           BOOLEAN := FALSE;
    v_parameter1            VARCHAR2(64) := 'R';
    v_parameter2            VARCHAR2(64) := ''; -- Buyer number
    v_parameter3            VARCHAR2(64) := '220018'; -- PO from
    v_parameter4            VARCHAR2(64) := '220018'; -- PO from
    v_parameter5            VARCHAR2(64) := '';
    v_parameter6            VARCHAR2(64) := '';
    v_parameter7            VARCHAR2(64) := '';
    v_parameter8            VARCHAR2(64) := '';
    v_parameter9            VARCHAR2(64) := ''; -- approved
    v_parameter10           VARCHAR2(64) := ''; -- test
    v_parameter11           VARCHAR2(64) := 'Y'; -- print release option
    v_parameter12           VARCHAR2(64) := ''; -- sort by
    v_parameter13           VARCHAR2(64) := '46077';
    v_parameter14           VARCHAR2(64) := '2'; -- Fax Enable
    v_parameter15           VARCHAR2(64) := 'N'; -- fax number
    v_parameter16           VARCHAR2(64) := ''; --
    v_parameter17           VARCHAR2(64) := 'Y'; -- print canceled lines
    v_parameter18           VARCHAR2(64) := 'N'; -- print blankets
    v_parameter19           VARCHAR2(64) := '';
    v_parameter20           VARCHAR2(64) := '';
    v_interval              NUMBER := 30; -- time change to 60
    v_max_wait              NUMBER := 0;
    v_request_phase         VARCHAR2(64);
    v_request_status        VARCHAR2(64);
    v_dev_request_phase     VARCHAR2(64);
    v_dev_request_status    VARCHAR2(64);
    v_request_status_mesg   VARCHAR2(64);
    v_call_status           BOOLEAN;
    v_err                   VARCHAR2(64);
   -- v_user_id               NUMBER := 411890;
    v_respon_id             NUMBER := g_respon_id;
    v_respn_appl_id         NUMBER := g_respn_appl_id;
  BEGIN



    --fnd_global.apps_initialize(g_user_id, v_respon_id, v_respn_appl_id);
    fnd_global.apps_initialize(g_user_id, g_respon_id, g_respn_appl_id); /* 9.7 */
    COMMIT;
    /* submit a request to run */
    v_parameter3 := p_po_number;
    v_parameter4 := p_po_number;
    v_request_id := fnd_request.submit_request(v_application_shrt_name,
                                               v_concprogramshortn,
                                               v_description,
                                               v_start_time,
                                               v_sub_request,
                                               v_parameter1,
                                               v_parameter2,
                                               v_parameter3,
                                               v_parameter4,
                                               v_parameter5,
                                               v_parameter6,
                                               v_parameter7,
                                               v_parameter8,
                                               v_parameter9,
                                               v_parameter10,
                                               v_parameter11,
                                               v_parameter12,
                                               v_parameter13,
                                               v_parameter14,
                                               v_parameter15,
                                               v_parameter16,
                                               v_parameter17,
                                               v_parameter18,
                                               v_parameter19,
                                               v_parameter20);
    COMMIT;
    print_line('Submitted Global PO print request. Request ID: ' ||
               TO_CHAR(v_request_id) || ' for PO Number: ' || p_po_number
                                                           || ' for Operating Unit:'||g_operating_unit_name);

    IF v_request_id = 0 THEN
      RETURN(0); -- failed request return 0
    END IF;

    /* wait for the concurrent program to complete */
    v_call_status := fnd_concurrent.wait_for_request(v_request_id,
                                                     v_interval,
                                                     v_max_wait,
                                                     v_request_phase,
                                                     v_request_status,
                                                     v_dev_request_phase,
                                                     v_dev_request_status,
                                                     v_request_status_mesg);
    COMMIT;

    IF (v_dev_request_phase = 'COMPLETE' AND
       v_dev_request_status = 'NORMAL') THEN
      RETURN(v_request_id);
    ELSE
      RETURN(v_request_id);  -- version 9.4
      -- RETURN(0);
    END IF;
  EXCEPTION
    WHEN OTHERS THEN
      v_err := SUBSTR(SQLERRM, 1, 50);
      print_line('Error in  ttec_po_run_pdf ' || v_err);
      RETURN(0);
  END ttec_po_run_global_pdf;

/* 9.7 End */

/* 12.1  Begin */
  FUNCTION ttec_po_run_global_pdf_am_notc(p_po_number IN VARCHAR2, p_date IN DATE)
    RETURN NUMBER IS
    v_request_id            NUMBER := 0;
    v_application_shrt_name VARCHAR2(20) := 'CUST';
    v_concprogramshortn     VARCHAR2(32) := 'TTEC_GLOBAL_PDF_PO_AM_NO_TC';
    v_description           VARCHAR2(64) := 'Graphic TTEC Global Purchase Order (American)';
    v_start_time            VARCHAR2(64) := ''; --  NULL;
    v_sub_request           BOOLEAN := FALSE;
    v_parameter1            VARCHAR2(64) := 'R';
    v_parameter2            VARCHAR2(64) := ''; -- Buyer number
    v_parameter3            VARCHAR2(64) := '220018'; -- PO from
    v_parameter4            VARCHAR2(64) := '220018'; -- PO from
    v_parameter5            VARCHAR2(64) := '';
    v_parameter6            VARCHAR2(64) := '';
    v_parameter7            VARCHAR2(64) := '';
    v_parameter8            VARCHAR2(64) := '';
    v_parameter9            VARCHAR2(64) := ''; -- approved
    v_parameter10           VARCHAR2(64) := ''; -- test
    v_parameter11           VARCHAR2(64) := 'Y'; -- print release option
    v_parameter12           VARCHAR2(64) := ''; -- sort by
    v_parameter13           VARCHAR2(64) := '46077';
    v_parameter14           VARCHAR2(64) := '2'; -- Fax Enable
    v_parameter15           VARCHAR2(64) := 'N'; -- fax number
    v_parameter16           VARCHAR2(64) := ''; --
    v_parameter17           VARCHAR2(64) := 'Y'; -- print canceled lines
    v_parameter18           VARCHAR2(64) := 'N'; -- print blankets
    v_parameter19           VARCHAR2(64) := '';
    v_parameter20           VARCHAR2(64) := '';
    v_interval              NUMBER := 30; -- time change to 60
    v_max_wait              NUMBER := 0;
    v_request_phase         VARCHAR2(64);
    v_request_status        VARCHAR2(64);
    v_dev_request_phase     VARCHAR2(64);
    v_dev_request_status    VARCHAR2(64);
    v_request_status_mesg   VARCHAR2(64);
    v_call_status           BOOLEAN;
    v_err                   VARCHAR2(64);
   -- v_user_id               NUMBER := 411890;
    v_respon_id             NUMBER := g_respon_id;
    v_respn_appl_id         NUMBER := g_respn_appl_id;
  BEGIN



    --fnd_global.apps_initialize(g_user_id, v_respon_id, v_respn_appl_id);
    fnd_global.apps_initialize(g_user_id, g_respon_id, g_respn_appl_id); /* 9.7 */
    COMMIT;
    /* submit a request to run */
    v_parameter3 := p_po_number;
    v_parameter4 := p_po_number;
    v_request_id := fnd_request.submit_request(v_application_shrt_name,
                                               v_concprogramshortn,
                                               v_description,
                                               v_start_time,
                                               v_sub_request,
                                               v_parameter1,
                                               v_parameter2,
                                               v_parameter3,
                                               v_parameter4,
                                               v_parameter5,
                                               v_parameter6,
                                               v_parameter7,
                                               v_parameter8,
                                               v_parameter9,
                                               v_parameter10,
                                               v_parameter11,
                                               v_parameter12,
                                               v_parameter13,
                                               v_parameter14,
                                               v_parameter15,
                                               v_parameter16,
                                               v_parameter17,
                                               v_parameter18,
                                               v_parameter19,
                                               v_parameter20);
    COMMIT;
    print_line('Submitted Global PO print request. Request ID: ' ||
               TO_CHAR(v_request_id) || ' for PO Number: ' || p_po_number
                                                           || ' for Operating Unit:'||g_operating_unit_name);

    IF v_request_id = 0 THEN
      RETURN(0); -- failed request return 0
    END IF;

    /* wait for the concurrent program to complete */
    v_call_status := fnd_concurrent.wait_for_request(v_request_id,
                                                     v_interval,
                                                     v_max_wait,
                                                     v_request_phase,
                                                     v_request_status,
                                                     v_dev_request_phase,
                                                     v_dev_request_status,
                                                     v_request_status_mesg);
    COMMIT;

    IF (v_dev_request_phase = 'COMPLETE' AND
       v_dev_request_status = 'NORMAL') THEN
      RETURN(v_request_id);
    ELSE
      RETURN(v_request_id);  -- version 9.4
      -- RETURN(0);
    END IF;
  EXCEPTION
    WHEN OTHERS THEN
      v_err := SUBSTR(SQLERRM, 1, 50);
      print_line('Error in  ttec_po_run_pdf ' || v_err);
      RETURN(0);
  END ttec_po_run_global_pdf_am_notc;
/* 12.1 End */

/* 12.2  Begin */
  FUNCTION ttec_po_run_global_pdf_fcr(p_po_number IN VARCHAR2, p_date IN DATE)
    RETURN NUMBER IS
    v_request_id            NUMBER := 0;
    v_application_shrt_name VARCHAR2(20) := 'CUST';
    v_concprogramshortn     VARCHAR2(32) := 'TTEC_GLOBAL_PDF_PO_FCR';
    v_description           VARCHAR2(64) := 'Graphic TTEC Global Purchase Order - FCR';
    v_start_time            VARCHAR2(64) := ''; --  NULL;
    v_sub_request           BOOLEAN := FALSE;
    v_parameter1            VARCHAR2(64) := 'R';
    v_parameter2            VARCHAR2(64) := ''; -- Buyer number
    v_parameter3            VARCHAR2(64) := '220018'; -- PO from
    v_parameter4            VARCHAR2(64) := '220018'; -- PO from
    v_parameter5            VARCHAR2(64) := '';
    v_parameter6            VARCHAR2(64) := '';
    v_parameter7            VARCHAR2(64) := '';
    v_parameter8            VARCHAR2(64) := '';
    v_parameter9            VARCHAR2(64) := ''; -- approved
    v_parameter10           VARCHAR2(64) := ''; -- test
    v_parameter11           VARCHAR2(64) := 'Y'; -- print release option
    v_parameter12           VARCHAR2(64) := ''; -- sort by
    v_parameter13           VARCHAR2(64) := '46077';
    v_parameter14           VARCHAR2(64) := '2'; -- Fax Enable
    v_parameter15           VARCHAR2(64) := 'N'; -- fax number
    v_parameter16           VARCHAR2(64) := ''; --
    v_parameter17           VARCHAR2(64) := 'Y'; -- print canceled lines
    v_parameter18           VARCHAR2(64) := 'N'; -- print blankets
    v_parameter19           VARCHAR2(64) := '';
    v_parameter20           VARCHAR2(64) := '';
    v_interval              NUMBER := 30; -- time change to 60
    v_max_wait              NUMBER := 0;
    v_request_phase         VARCHAR2(64);
    v_request_status        VARCHAR2(64);
    v_dev_request_phase     VARCHAR2(64);
    v_dev_request_status    VARCHAR2(64);
    v_request_status_mesg   VARCHAR2(64);
    v_call_status           BOOLEAN;
    v_err                   VARCHAR2(64);
   -- v_user_id               NUMBER := 411890;
    v_respon_id             NUMBER := g_respon_id;
    v_respn_appl_id         NUMBER := g_respn_appl_id;
  BEGIN



    --fnd_global.apps_initialize(g_user_id, v_respon_id, v_respn_appl_id);
    fnd_global.apps_initialize(g_user_id, g_respon_id, g_respn_appl_id); /* 9.7 */
    COMMIT;
    /* submit a request to run */
    v_parameter3 := p_po_number;
    v_parameter4 := p_po_number;
    v_request_id := fnd_request.submit_request(v_application_shrt_name,
                                               v_concprogramshortn,
                                               v_description,
                                               v_start_time,
                                               v_sub_request,
                                               v_parameter1,
                                               v_parameter2,
                                               v_parameter3,
                                               v_parameter4,
                                               v_parameter5,
                                               v_parameter6,
                                               v_parameter7,
                                               v_parameter8,
                                               v_parameter9,
                                               v_parameter10,
                                               v_parameter11,
                                               v_parameter12,
                                               v_parameter13,
                                               v_parameter14,
                                               v_parameter15,
                                               v_parameter16,
                                               v_parameter17,
                                               v_parameter18,
                                               v_parameter19,
                                               v_parameter20);
    COMMIT;
    print_line('Submitted PO print request with FCR Logo. Request ID: ' ||
               TO_CHAR(v_request_id) || ' for PO Number: ' || p_po_number
                                                           || ' for Operating Unit:'||g_operating_unit_name);

    IF v_request_id = 0 THEN
      RETURN(0); -- failed request return 0
    END IF;

    /* wait for the concurrent program to complete */
    v_call_status := fnd_concurrent.wait_for_request(v_request_id,
                                                     v_interval,
                                                     v_max_wait,
                                                     v_request_phase,
                                                     v_request_status,
                                                     v_dev_request_phase,
                                                     v_dev_request_status,
                                                     v_request_status_mesg);
    COMMIT;

    IF (v_dev_request_phase = 'COMPLETE' AND
       v_dev_request_status = 'NORMAL') THEN
      RETURN(v_request_id);
    ELSE
      RETURN(v_request_id);  -- version 9.4
      -- RETURN(0);
    END IF;
  EXCEPTION
    WHEN OTHERS THEN
      v_err := SUBSTR(SQLERRM, 1, 50);
      print_line('Error in  ttec_po_run_pdf ' || v_err);
      RETURN(0);
  END ttec_po_run_global_pdf_fcr;
/* 12.2 End */

/* 10.0 Begin */
  FUNCTION ttec_po_run_global_latam_pdf(p_po_number IN VARCHAR2, p_date IN DATE)
    RETURN NUMBER IS
    v_request_id            NUMBER := 0;
    v_application_shrt_name VARCHAR2(20) := 'CUST';
    v_concprogramshortn     VARCHAR2(32) := 'TTEC_GLOBAL_PDF_PO_LATAM';
    v_description           VARCHAR2(64) := 'Graphic TTEC Global Purchase Order (Latin American)';
    v_start_time            VARCHAR2(64) := ''; --  NULL;
    v_sub_request           BOOLEAN := FALSE;
    v_parameter1            VARCHAR2(64) := 'R';
    v_parameter2            VARCHAR2(64) := ''; -- Buyer number
    v_parameter3            VARCHAR2(64) := '220018'; -- PO from
    v_parameter4            VARCHAR2(64) := '220018'; -- PO from
    v_parameter5            VARCHAR2(64) := '';
    v_parameter6            VARCHAR2(64) := '';
    v_parameter7            VARCHAR2(64) := '';
    v_parameter8            VARCHAR2(64) := '';
    v_parameter9            VARCHAR2(64) := ''; -- approved
    v_parameter10           VARCHAR2(64) := ''; -- test
    v_parameter11           VARCHAR2(64) := 'Y'; -- print release option
    v_parameter12           VARCHAR2(64) := ''; -- sort by
    v_parameter13           VARCHAR2(64) := '46077';
    v_parameter14           VARCHAR2(64) := '2'; -- Fax Enable
    v_parameter15           VARCHAR2(64) := 'N'; -- fax number
    v_parameter16           VARCHAR2(64) := ''; --
    v_parameter17           VARCHAR2(64) := 'Y'; -- print canceled lines
    v_parameter18           VARCHAR2(64) := 'N'; -- print blankets
    v_parameter19           VARCHAR2(64) := '';
    v_parameter20           VARCHAR2(64) := '';
    v_interval              NUMBER := 30; -- time change to 60
    v_max_wait              NUMBER := 0;
    v_request_phase         VARCHAR2(64);
    v_request_status        VARCHAR2(64);
    v_dev_request_phase     VARCHAR2(64);
    v_dev_request_status    VARCHAR2(64);
    v_request_status_mesg   VARCHAR2(64);
    v_call_status           BOOLEAN;
    v_err                   VARCHAR2(64);
   -- v_user_id               NUMBER := 411890;
    v_respon_id             NUMBER := g_respon_id;
    v_respn_appl_id         NUMBER := g_respn_appl_id;
  BEGIN



    --fnd_global.apps_initialize(g_user_id, v_respon_id, v_respn_appl_id);
    fnd_global.apps_initialize(g_user_id, g_respon_id, g_respn_appl_id); /* 9.7 */
    COMMIT;
    /* submit a request to run */
    v_parameter3 := p_po_number;
    v_parameter4 := p_po_number;
    v_request_id := fnd_request.submit_request(v_application_shrt_name,
                                               v_concprogramshortn,
                                               v_description,
                                               v_start_time,
                                               v_sub_request,
                                               v_parameter1,
                                               v_parameter2,
                                               v_parameter3,
                                               v_parameter4,
                                               v_parameter5,
                                               v_parameter6,
                                               v_parameter7,
                                               v_parameter8,
                                               v_parameter9,
                                               v_parameter10,
                                               v_parameter11,
                                               v_parameter12,
                                               v_parameter13,
                                               v_parameter14,
                                               v_parameter15,
                                               v_parameter16,
                                               v_parameter17,
                                               v_parameter18,
                                               v_parameter19,
                                               v_parameter20);
    COMMIT;
    print_line('Submitted Global PO print request. Request ID: ' ||
               TO_CHAR(v_request_id) || ' for PO Number: ' || p_po_number
                                                           || ' for Operating Unit:'||g_operating_unit_name);

    IF v_request_id = 0 THEN
      RETURN(0); -- failed request return 0
    END IF;

    /* wait for the concurrent program to complete */
    v_call_status := fnd_concurrent.wait_for_request(v_request_id,
                                                     v_interval,
                                                     v_max_wait,
                                                     v_request_phase,
                                                     v_request_status,
                                                     v_dev_request_phase,
                                                     v_dev_request_status,
                                                     v_request_status_mesg);
    COMMIT;

    IF (v_dev_request_phase = 'COMPLETE' AND
       v_dev_request_status = 'NORMAL') THEN
      RETURN(v_request_id);
    ELSE
      RETURN(v_request_id);  -- version 9.4
      -- RETURN(0);
    END IF;
  EXCEPTION
    WHEN OTHERS THEN
      v_err := SUBSTR(SQLERRM, 1, 50);
      print_line('Error in  ttec_po_run_pdf ' || v_err);
      RETURN(0);
  END ttec_po_run_global_latam_pdf;
/* 10.0 End */

/* 10.0 Begin */
  FUNCTION ttec_po_run_global_ptb_pdf(p_po_number IN VARCHAR2, p_date IN DATE)
    RETURN NUMBER IS
    v_request_id            NUMBER := 0;
    v_application_shrt_name VARCHAR2(20) := 'CUST';
    v_concprogramshortn     VARCHAR2(32) := 'TTEC_GLOBAL_PDF_PO_PTB';
    v_description           VARCHAR2(64) := 'Graphic TTEC Global Purchase Order (Brazilian Portuguese)';
    v_start_time            VARCHAR2(64) := ''; --  NULL;
    v_sub_request           BOOLEAN := FALSE;
    v_parameter1            VARCHAR2(64) := 'R';
    v_parameter2            VARCHAR2(64) := ''; -- Buyer number
    v_parameter3            VARCHAR2(64) := '220018'; -- PO from
    v_parameter4            VARCHAR2(64) := '220018'; -- PO from
    v_parameter5            VARCHAR2(64) := '';
    v_parameter6            VARCHAR2(64) := '';
    v_parameter7            VARCHAR2(64) := '';
    v_parameter8            VARCHAR2(64) := '';
    v_parameter9            VARCHAR2(64) := ''; -- approved
    v_parameter10           VARCHAR2(64) := ''; -- test
    v_parameter11           VARCHAR2(64) := 'Y'; -- print release option
    v_parameter12           VARCHAR2(64) := ''; -- sort by
    v_parameter13           VARCHAR2(64) := '46077';
    v_parameter14           VARCHAR2(64) := '2'; -- Fax Enable
    v_parameter15           VARCHAR2(64) := 'N'; -- fax number
    v_parameter16           VARCHAR2(64) := ''; --
    v_parameter17           VARCHAR2(64) := 'Y'; -- print canceled lines
    v_parameter18           VARCHAR2(64) := 'N'; -- print blankets
    v_parameter19           VARCHAR2(64) := '';
    v_parameter20           VARCHAR2(64) := '';
    v_interval              NUMBER := 30; -- time change to 60
    v_max_wait              NUMBER := 0;
    v_request_phase         VARCHAR2(64);
    v_request_status        VARCHAR2(64);
    v_dev_request_phase     VARCHAR2(64);
    v_dev_request_status    VARCHAR2(64);
    v_request_status_mesg   VARCHAR2(64);
    v_call_status           BOOLEAN;
    v_err                   VARCHAR2(64);
   -- v_user_id               NUMBER := 411890;
    v_respon_id             NUMBER := g_respon_id;
    v_respn_appl_id         NUMBER := g_respn_appl_id;
  BEGIN



    --fnd_global.apps_initialize(g_user_id, v_respon_id, v_respn_appl_id);
    fnd_global.apps_initialize(g_user_id, g_respon_id, g_respn_appl_id); /* 9.7 */
    COMMIT;
    /* submit a request to run */
    v_parameter3 := p_po_number;
    v_parameter4 := p_po_number;
    v_request_id := fnd_request.submit_request(v_application_shrt_name,
                                               v_concprogramshortn,
                                               v_description,
                                               v_start_time,
                                               v_sub_request,
                                               v_parameter1,
                                               v_parameter2,
                                               v_parameter3,
                                               v_parameter4,
                                               v_parameter5,
                                               v_parameter6,
                                               v_parameter7,
                                               v_parameter8,
                                               v_parameter9,
                                               v_parameter10,
                                               v_parameter11,
                                               v_parameter12,
                                               v_parameter13,
                                               v_parameter14,
                                               v_parameter15,
                                               v_parameter16,
                                               v_parameter17,
                                               v_parameter18,
                                               v_parameter19,
                                               v_parameter20);
    COMMIT;
    print_line('Submitted Global PO print request. Request ID: ' ||
               TO_CHAR(v_request_id) || ' for PO Number: ' || p_po_number
                                                           || ' for Operating Unit:'||g_operating_unit_name);

    IF v_request_id = 0 THEN
      RETURN(0); -- failed request return 0
    END IF;

    /* wait for the concurrent program to complete */
    v_call_status := fnd_concurrent.wait_for_request(v_request_id,
                                                     v_interval,
                                                     v_max_wait,
                                                     v_request_phase,
                                                     v_request_status,
                                                     v_dev_request_phase,
                                                     v_dev_request_status,
                                                     v_request_status_mesg);
    COMMIT;

    IF (v_dev_request_phase = 'COMPLETE' AND
       v_dev_request_status = 'NORMAL') THEN
      RETURN(v_request_id);
    ELSE
      RETURN(v_request_id);  -- version 9.4
      -- RETURN(0);
    END IF;
  EXCEPTION
    WHEN OTHERS THEN
      v_err := SUBSTR(SQLERRM, 1, 50);
      print_line('Error in  ttec_po_run_pdf ' || v_err);
      RETURN(0);
  END ttec_po_run_global_ptb_pdf;
/* 10.0 End */

  -- us government solutions
  FUNCTION ttec_po_run_gvs_us_pdf(p_po_number IN VARCHAR2, p_date IN DATE)
    RETURN NUMBER IS
    v_request_id            NUMBER := 0;
    v_application_shrt_name VARCHAR2(20) := 'CUST';
    v_concprogramshortn     VARCHAR2(32) := 'TTEC_US_CA_PDF_PO_TTEC_LOGO';
    v_description           VARCHAR2(64) := 'Graphic TTEC US/Canada Purchase Order';
    v_start_time            VARCHAR2(64) := ''; --  NULL;
    v_sub_request           BOOLEAN := FALSE;
    v_parameter1            VARCHAR2(64) := 'R';
    v_parameter2            VARCHAR2(64) := ''; -- Buyer number
    v_parameter3            VARCHAR2(64) := '220018'; -- PO from
    v_parameter4            VARCHAR2(64) := '220018'; -- PO from
    v_parameter5            VARCHAR2(64) := '';
    v_parameter6            VARCHAR2(64) := '';
    v_parameter7            VARCHAR2(64) := '';
    v_parameter8            VARCHAR2(64) := '';
    v_parameter9            VARCHAR2(64) := ''; -- approved
    v_parameter10           VARCHAR2(64) := ''; -- test
    v_parameter11           VARCHAR2(64) := 'Y'; -- print release option
    v_parameter12           VARCHAR2(64) := ''; -- sort by
    v_parameter13           VARCHAR2(64) := '46077';
    v_parameter14           VARCHAR2(64) := '2'; -- Fax Enable
    v_parameter15           VARCHAR2(64) := 'N'; -- fax number
    v_parameter16           VARCHAR2(64) := ''; --
    v_parameter17           VARCHAR2(64) := 'Y'; -- print canceled lines
    v_parameter18           VARCHAR2(64) := 'N'; -- print blankets
    v_parameter19           VARCHAR2(64) := 'TTEC';
    v_parameter20           VARCHAR2(64) := 'US';
    v_interval              NUMBER := 30; -- time change to 60
    v_max_wait              NUMBER := 0;
    v_request_phase         VARCHAR2(64);
    v_request_status        VARCHAR2(64);
    v_dev_request_phase     VARCHAR2(64);
    v_dev_request_status    VARCHAR2(64);
    v_request_status_mesg   VARCHAR2(64);
    v_call_status           BOOLEAN;
    v_err                   VARCHAR2(64);
   -- v_user_id               NUMBER := 411890;
    v_respon_id             NUMBER := g_respon_id;
    v_respn_appl_id         NUMBER := g_respn_appl_id;
  BEGIN
    fnd_global.apps_initialize(g_user_id, v_respon_id, v_respn_appl_id);
    COMMIT;
    /* submit a request to run */
    v_parameter3 := p_po_number;
    v_parameter4 := p_po_number;
    v_request_id := fnd_request.submit_request(v_application_shrt_name,
                                               v_concprogramshortn,
                                               v_description,
                                               v_start_time,
                                               v_sub_request,
                                               v_parameter1,
                                               v_parameter2,
                                               v_parameter3,
                                               v_parameter4,
                                               v_parameter5,
                                               v_parameter6,
                                               v_parameter7,
                                               v_parameter8,
                                               v_parameter9,
                                               v_parameter10,
                                               v_parameter11,
                                               v_parameter12,
                                               v_parameter13,
                                               v_parameter14,
                                               v_parameter15,
                                               v_parameter16,
                                               v_parameter17,
                                               v_parameter18,
                                               v_parameter19,
                                               v_parameter20);
    COMMIT;
    print_line('Submitted US Government Solutions PO print request. Request ID: ' ||
               TO_CHAR(v_request_id) || ' for PO Number: ' || p_po_number);

    IF v_request_id = 0 THEN
      RETURN(0); -- failed request return 0
    END IF;

    /* wait for the concurrent program to complete */
    v_call_status := fnd_concurrent.wait_for_request(v_request_id,
                                                     v_interval,
                                                     v_max_wait,
                                                     v_request_phase,
                                                     v_request_status,
                                                     v_dev_request_phase,
                                                     v_dev_request_status,
                                                     v_request_status_mesg);
    COMMIT;

    IF (v_dev_request_phase = 'COMPLETE' AND
       v_dev_request_status = 'NORMAL') THEN
      RETURN(v_request_id);
    ELSE
      RETURN(v_request_id);  -- version 9.4
      -- RETURN(0);
    END IF;
  EXCEPTION
    WHEN OTHERS THEN
      v_err := SUBSTR(SQLERRM, 1, 50);
      print_line('Error in  ttec_po_run_pdf ' || v_err);
      RETURN(0);
  END ttec_po_run_gvs_us_pdf;

  /* US - Prodovis */
  /* v3.2 Begin */
  FUNCTION ttec_po_run_prodovis_us_pdf(p_po_number IN VARCHAR2,
                                       p_date      IN DATE) RETURN NUMBER IS
    v_request_id            NUMBER := 0;
    v_application_shrt_name VARCHAR2(20) := 'CUST';
    v_concprogramshortn     VARCHAR2(32) := 'TTEC_PRODOVIS_US_PDF_PO';
    /* v3.2 */
    v_description VARCHAR2(64) := 'Graphic TeleTech PRODOVIS US Purchase Order';
    /* v3.2 */
    v_start_time          VARCHAR2(64) := ''; --  NULL;
    v_sub_request         BOOLEAN := FALSE;
    v_parameter1          VARCHAR2(64) := 'R';
    v_parameter2          VARCHAR2(64) := ''; -- Buyer number
    v_parameter3          VARCHAR2(64) := '220018'; -- PO from
    v_parameter4          VARCHAR2(64) := '220018'; -- PO from
    v_parameter5          VARCHAR2(64) := '';
    v_parameter6          VARCHAR2(64) := '';
    v_parameter7          VARCHAR2(64) := '';
    v_parameter8          VARCHAR2(64) := '';
    v_parameter9          VARCHAR2(64) := ''; -- approved
    v_parameter10         VARCHAR2(64) := ''; -- test
    v_parameter11         VARCHAR2(64) := 'Y'; -- print release option
    v_parameter12         VARCHAR2(64) := ''; -- sort by
    v_parameter13         VARCHAR2(64) := '46077';
    v_parameter14         VARCHAR2(64) := '2'; -- Fax Enable
    v_parameter15         VARCHAR2(64) := 'N'; -- fax number
    v_parameter16         VARCHAR2(64) := ''; --
    v_parameter17         VARCHAR2(64) := 'Y'; -- print canceled lines
    v_parameter18         VARCHAR2(64) := 'N'; -- print blankets
    v_parameter19         VARCHAR2(64) := '';
    v_parameter20         VARCHAR2(64) := '';
    v_interval            NUMBER := 30; -- time change to 60
    v_max_wait            NUMBER := 0;
    v_request_phase       VARCHAR2(64);
    v_request_status      VARCHAR2(64);
    v_dev_request_phase   VARCHAR2(64);
    v_dev_request_status  VARCHAR2(64);
    v_request_status_mesg VARCHAR2(64);
    v_call_status         BOOLEAN;
    v_err                 VARCHAR2(64);
   -- v_user_id               NUMBER := 411890;
    v_respon_id             NUMBER := g_respon_id;
    v_respn_appl_id         NUMBER := g_respn_appl_id;
  BEGIN
    fnd_global.apps_initialize(g_user_id, v_respon_id, v_respn_appl_id);
    COMMIT;
    /* submit a request to run */
    v_parameter3 := p_po_number;
    v_parameter4 := p_po_number;
    v_request_id := fnd_request.submit_request(v_application_shrt_name,
                                               v_concprogramshortn,
                                               v_description,
                                               v_start_time,
                                               v_sub_request,
                                               v_parameter1,
                                               v_parameter2,
                                               v_parameter3,
                                               v_parameter4,
                                               v_parameter5,
                                               v_parameter6,
                                               v_parameter7,
                                               v_parameter8,
                                               v_parameter9,
                                               v_parameter10,
                                               v_parameter11,
                                               v_parameter12,
                                               v_parameter13,
                                               v_parameter14,
                                               v_parameter15,
                                               v_parameter16,
                                               v_parameter17,
                                               v_parameter18,
                                               v_parameter19,
                                               v_parameter20);
    COMMIT;
    print_line('Submitted PRODOVIS US PO print request. Request ID: ' ||
               TO_CHAR(v_request_id) || ' for PO Number: ' || p_po_number);

    IF v_request_id = 0 THEN
      RETURN(0); -- failed request return 0
    END IF;

    /* wait for the concurrent program to complete */
    v_call_status := fnd_concurrent.wait_for_request(v_request_id,
                                                     v_interval,
                                                     v_max_wait,
                                                     v_request_phase,
                                                     v_request_status,
                                                     v_dev_request_phase,
                                                     v_dev_request_status,
                                                     v_request_status_mesg);
    COMMIT;

    IF (v_dev_request_phase = 'COMPLETE' AND
       v_dev_request_status = 'NORMAL') THEN
      RETURN(v_request_id);
    ELSE
      RETURN(v_request_id);  -- version 9.4
      -- RETURN(0);
    END IF;
  EXCEPTION
    WHEN OTHERS THEN
      v_err := SUBSTR(SQLERRM, 1, 50);
      print_line('Error in  ttec_po_run_pdf ' || v_err);
      RETURN(0);
  END ttec_po_run_prodovis_us_pdf; /* v3.2 */

  /* v3.2 End */
  /* South Africa */
  FUNCTION ttec_po_run_sa_pdf(p_po_number IN VARCHAR2, p_date IN DATE)
    RETURN NUMBER IS
    v_request_id            NUMBER := 0;
    v_application_shrt_name VARCHAR2(20) := 'CUST';
    v_concprogramshortn     VARCHAR2(32) := 'TTEC_US_CA_PDF_PO';
    v_description           VARCHAR2(64) := 'Graphic Teletech US/Canada Purchase Order';
    v_start_time            VARCHAR2(64) := ''; --  NULL;
    v_sub_request           BOOLEAN := FALSE;
    v_parameter1            VARCHAR2(64) := 'R';
    v_parameter2            VARCHAR2(64) := ''; -- Buyer number
    v_parameter3            VARCHAR2(64) := '90214'; -- PO from
    v_parameter4            VARCHAR2(64) := '90214'; -- PO from
    v_parameter5            VARCHAR2(64) := '';
    v_parameter6            VARCHAR2(64) := '';
    v_parameter7            VARCHAR2(64) := '';
    v_parameter8            VARCHAR2(64) := '';
    v_parameter9            VARCHAR2(64) := ''; -- approved
    v_parameter10           VARCHAR2(64) := ''; -- test
    v_parameter11           VARCHAR2(64) := 'Y'; -- print release option
    v_parameter12           VARCHAR2(64) := ''; -- sort by
    v_parameter13           VARCHAR2(64) := '46077';
    v_parameter14           VARCHAR2(64) := '2'; -- Fax Enable
    v_parameter15           VARCHAR2(64) := 'N'; -- fax number
    v_parameter16           VARCHAR2(64) := ''; --
    v_parameter17           VARCHAR2(64) := 'Y'; -- print canceled lines
    v_parameter18           VARCHAR2(64) := 'N'; -- print blankets
    v_parameter19           VARCHAR2(64) := '';
    v_parameter20           VARCHAR2(64) := '';
    v_interval              NUMBER := 30; -- time change to 60
    v_max_wait              NUMBER := 0;
    v_request_phase         VARCHAR2(64);
    v_request_status        VARCHAR2(64);
    v_dev_request_phase     VARCHAR2(64);
    v_dev_request_status    VARCHAR2(64);
    v_request_status_mesg   VARCHAR2(64);
    v_call_status           BOOLEAN;
    v_err                   VARCHAR2(64);
   -- v_user_id               NUMBER := 411890;
    v_respon_id             NUMBER := g_respon_id;
    v_respn_appl_id         NUMBER := g_respn_appl_id;
  BEGIN
    fnd_global.apps_initialize(g_user_id, v_respon_id, v_respn_appl_id);
    COMMIT;
    /* submit a request to run */
    v_parameter3 := p_po_number;
    v_parameter4 := p_po_number;
    v_request_id := fnd_request.submit_request(v_application_shrt_name,
                                               v_concprogramshortn,
                                               v_description,
                                               v_start_time,
                                               v_sub_request,
                                               v_parameter1,
                                               v_parameter2,
                                               v_parameter3,
                                               v_parameter4,
                                               v_parameter5,
                                               v_parameter6,
                                               v_parameter7,
                                               v_parameter8,
                                               v_parameter9,
                                               v_parameter10,
                                               v_parameter11,
                                               v_parameter12,
                                               v_parameter13,
                                               v_parameter14,
                                               v_parameter15,
                                               v_parameter16,
                                               v_parameter17,
                                               v_parameter18,
                                               v_parameter19,
                                               v_parameter20);
    COMMIT;
    print_line('Submitted South Africa PO print request. Request ID: ' ||
               TO_CHAR(v_request_id) || ' for PO Number: ' || p_po_number);

    IF v_request_id = 0 THEN
      RETURN(0); -- failed request return 0
    END IF;

    /* wait for the concurrent program to complete */
    v_call_status := fnd_concurrent.wait_for_request(v_request_id,
                                                     v_interval,
                                                     v_max_wait,
                                                     v_request_phase,
                                                     v_request_status,
                                                     v_dev_request_phase,
                                                     v_dev_request_status,
                                                     v_request_status_mesg);
    COMMIT;

    IF (v_dev_request_phase = 'COMPLETE' AND
       v_dev_request_status = 'NORMAL') THEN
      RETURN(v_request_id);
    ELSE
      RETURN(v_request_id);  -- version 9.4
      -- RETURN(0);
    END IF;
  EXCEPTION
    WHEN OTHERS THEN
      v_err := SUBSTR(SQLERRM, 1, 50);
      print_line('Error in  ttec_po_run_pdf ' || v_err);
      RETURN(0);
  END ttec_po_run_sa_pdf;

  /* SGP Singapore */
  FUNCTION ttec_po_run_sgp_pdf(p_po_number IN VARCHAR2, p_date IN DATE)
    RETURN NUMBER IS
    v_request_id            NUMBER := 0;
    v_application_shrt_name VARCHAR2(20) := 'CUST';
    v_concprogramshortn     VARCHAR2(32) := 'TTEC_SG_PO_PDF'; --'POXPRPOP_TELETECH_SGP';
    v_description           VARCHAR2(64) := 'Graphic Singapore Purchase Order'; --'TeleTech SGP Purchase Order Printt';
    v_start_time            VARCHAR2(64) := ''; --  NULL;
    v_sub_request           BOOLEAN := FALSE;
    v_parameter1            VARCHAR2(64) := 'R';
    v_parameter2            VARCHAR2(64) := ''; -- Buyer number
    v_parameter3            VARCHAR2(64) := '71630'; -- PO from
    v_parameter4            VARCHAR2(64) := '71630'; -- PO from
    v_parameter5            VARCHAR2(64) := '';
    v_parameter6            VARCHAR2(64) := '';
    v_parameter7            VARCHAR2(64) := '';
    v_parameter8            VARCHAR2(64) := '';
    v_parameter9            VARCHAR2(64) := ''; -- approved
    v_parameter10           VARCHAR2(64) := ''; -- test
    v_parameter11           VARCHAR2(64) := 'Y'; -- print release option
    v_parameter12           VARCHAR2(64) := ''; -- sort by
    v_parameter13           VARCHAR2(64) := '46077';
    v_parameter14           VARCHAR2(64) := '2'; -- Fax Enable
    v_parameter15           VARCHAR2(64) := 'N'; -- fax number
    v_parameter16           VARCHAR2(64) := ''; --
    v_parameter17           VARCHAR2(64) := 'Y'; -- print canceled lines
    v_parameter18           VARCHAR2(64) := 'N'; -- print blankets
    v_parameter19           VARCHAR2(64) := '';
    v_parameter20           VARCHAR2(64) := '';
    v_interval              NUMBER := 30; -- time change to 60
    v_max_wait              NUMBER := 0;
    v_request_phase         VARCHAR2(64);
    v_request_status        VARCHAR2(64);
    v_dev_request_phase     VARCHAR2(64);
    v_dev_request_status    VARCHAR2(64);
    v_request_status_mesg   VARCHAR2(64);
    v_call_status           BOOLEAN;
    v_err                   VARCHAR2(64);
   -- v_user_id               NUMBER := 411890;
    v_respon_id             NUMBER := g_respon_id;
    v_respn_appl_id         NUMBER := g_respn_appl_id;
  BEGIN
    fnd_global.apps_initialize(g_user_id, v_respon_id, v_respn_appl_id);
    COMMIT;
    /* submit a request to run */
    v_parameter3 := p_po_number;
    v_parameter4 := p_po_number;
    v_request_id := fnd_request.submit_request(v_application_shrt_name,
                                               v_concprogramshortn,
                                               v_description,
                                               v_start_time,
                                               v_sub_request,
                                               v_parameter1,
                                               v_parameter2,
                                               v_parameter3,
                                               v_parameter4,
                                               v_parameter5,
                                               v_parameter6,
                                               v_parameter7,
                                               v_parameter8,
                                               v_parameter9,
                                               v_parameter10,
                                               v_parameter11,
                                               v_parameter12,
                                               v_parameter13,
                                               v_parameter14,
                                               v_parameter15,
                                               v_parameter16,
                                               v_parameter17,
                                               v_parameter18,
                                               v_parameter19,
                                               v_parameter20);
    COMMIT;
    print_line('Submitted SPG PO print request. Request ID: ' ||
               TO_CHAR(v_request_id) || ' for PO Number: ' || p_po_number);

    IF v_request_id = 0 THEN
      RETURN(0); -- failed request return 0
    END IF;

    /* wait for the concurrent program to complete */
    v_call_status := fnd_concurrent.wait_for_request(v_request_id,
                                                     v_interval,
                                                     v_max_wait,
                                                     v_request_phase,
                                                     v_request_status,
                                                     v_dev_request_phase,
                                                     v_dev_request_status,
                                                     v_request_status_mesg);
    COMMIT;

    IF (v_dev_request_phase = 'COMPLETE' AND
       v_dev_request_status = 'NORMAL') THEN
      RETURN(v_request_id);
    ELSE
      RETURN(v_request_id);  -- version 9.4
      -- RETURN(0);
    END IF;
  EXCEPTION
    WHEN OTHERS THEN
      v_err := SUBSTR(SQLERRM, 1, 50);
      print_line('Error in  ttec_po_run_pdf ' || v_err);
      RETURN(0);
  END ttec_po_run_sgp_pdf;

  /* PHL */
  FUNCTION ttec_po_run_phl_pdf(p_po_number IN VARCHAR2, p_date IN DATE)
    RETURN NUMBER IS
    v_request_id            NUMBER := 0;
    v_application_shrt_name VARCHAR2(20) := 'CUST';
    /* v8.0 start */
    --v_concprogramshortn     VARCHAR2(32) := 'TTEC_US_CA_PDF_PO';
    --v_description           VARCHAR2(64) := 'Graphic Teletech US/Canada Purchase Order';
    v_concprogramshortn     VARCHAR2(32) := 'TTEC_PHP_PO';
    v_description           VARCHAR2(64) := 'TeleTech Philippines Graphic Purchase Order';
    /* v8.0 end */
    v_start_time            VARCHAR2(64) := ''; --  NULL;
    v_sub_request           BOOLEAN := FALSE;
    v_parameter1            VARCHAR2(64) := 'R';
    v_parameter2            VARCHAR2(64) := ''; -- Buyer number
    v_parameter3            VARCHAR2(64) := '311437'; -- PO from
    v_parameter4            VARCHAR2(64) := '311437'; -- PO from
    v_parameter5            VARCHAR2(64) := '';
    v_parameter6            VARCHAR2(64) := '';
    v_parameter7            VARCHAR2(64) := '';
    v_parameter8            VARCHAR2(64) := '';
    v_parameter9            VARCHAR2(64) := ''; -- approved
    v_parameter10           VARCHAR2(64) := ''; -- test
    v_parameter11           VARCHAR2(64) := 'Y'; -- print release option
    v_parameter12           VARCHAR2(64) := ''; -- sort by
    v_parameter13           VARCHAR2(64) := '46077';
    v_parameter14           VARCHAR2(64) := '2'; -- Fax Enable
    v_parameter15           VARCHAR2(64) := 'N'; -- fax number
    v_parameter16           VARCHAR2(64) := ''; --
    v_parameter17           VARCHAR2(64) := 'Y'; -- print canceled lines
    v_parameter18           VARCHAR2(64) := 'N'; -- print blankets
    v_parameter19           VARCHAR2(64) := '';
    v_parameter20           VARCHAR2(64) := '';
    v_interval              NUMBER := 30; -- time change to 60
    v_max_wait              NUMBER := 0;
    v_request_phase         VARCHAR2(64);
    v_request_status        VARCHAR2(64);
    v_dev_request_phase     VARCHAR2(64);
    v_dev_request_status    VARCHAR2(64);
    v_request_status_mesg   VARCHAR2(64);
    v_call_status           BOOLEAN;
    v_err                   VARCHAR2(64);
   -- v_user_id               NUMBER := 411890;
    v_respon_id             NUMBER := g_respon_id;
    v_respn_appl_id         NUMBER := g_respn_appl_id;
  BEGIN
    fnd_global.apps_initialize(g_user_id, v_respon_id, v_respn_appl_id);
    COMMIT;
    /* submit a request to run */
    v_parameter3 := p_po_number;
    v_parameter4 := p_po_number;
    v_request_id := fnd_request.submit_request(v_application_shrt_name,
                                               v_concprogramshortn,
                                               v_description,
                                               v_start_time,
                                               v_sub_request,
                                               v_parameter1,
                                               v_parameter2,
                                               v_parameter3,
                                               v_parameter4,
                                               v_parameter5,
                                               v_parameter6,
                                               v_parameter7,
                                               v_parameter8,
                                               v_parameter9,
                                               v_parameter10,
                                               v_parameter11,
                                               v_parameter12,
                                               v_parameter13,
                                               v_parameter14,
                                               v_parameter15,
                                               v_parameter16,
                                               v_parameter17,
                                               v_parameter18,
                                               v_parameter19,
                                               v_parameter20);
    COMMIT;
    print_line('Submitted PHL PO print request. Request ID: ' ||
               TO_CHAR(v_request_id) || ' for PO Number: ' || p_po_number);

    IF v_request_id = 0 THEN
      RETURN(0); -- failed request return 0
    END IF;

    /* wait for the concurrent program to complete */
    v_call_status := fnd_concurrent.wait_for_request(v_request_id,
                                                     v_interval,
                                                     v_max_wait,
                                                     v_request_phase,
                                                     v_request_status,
                                                     v_dev_request_phase,
                                                     v_dev_request_status,
                                                     v_request_status_mesg);
    COMMIT;

    IF (v_dev_request_phase = 'COMPLETE' AND
       v_dev_request_status = 'NORMAL') THEN
      RETURN(v_request_id);
    ELSE
      RETURN(v_request_id);  -- version 9.4
      -- RETURN(0);
    END IF;
  EXCEPTION
    WHEN OTHERS THEN
      v_err := SUBSTR(SQLERRM, 1, 50);
      print_line('Error in  ttec_po_run_pdf ' || v_err);
      RETURN(0);
  END ttec_po_run_phl_pdf;

  /* PHL BR*/
  -- v 3.6
  FUNCTION ttec_po_run_phl_br_pdf(p_po_number IN VARCHAR2, p_date IN DATE)
    RETURN NUMBER IS
    v_request_id            NUMBER := 0;
    v_application_shrt_name VARCHAR2(20) := 'CUST';
    /* v8.0 start */
    --v_concprogramshortn     VARCHAR2(32) := 'TTEC_US_CA_PDF_PO';
    --v_description           VARCHAR2(64) := 'Graphic Teletech US/Canada Purchase Order';
    v_concprogramshortn     VARCHAR2(32) := 'TTEC_PHP_PO_BNH';
    v_description           VARCHAR2(64) := 'TeleTech Philippines Branch Graphic Purchase Order';
    /* v8.0 end */
    v_start_time            VARCHAR2(64) := ''; --  NULL;
    v_sub_request           BOOLEAN := FALSE;
    v_parameter1            VARCHAR2(64) := 'R';
    v_parameter2            VARCHAR2(64) := ''; -- Buyer number
    v_parameter3            VARCHAR2(64) := '311437'; -- PO from
    v_parameter4            VARCHAR2(64) := '311437'; -- PO from
    v_parameter5            VARCHAR2(64) := '';
    v_parameter6            VARCHAR2(64) := '';
    v_parameter7            VARCHAR2(64) := '';
    v_parameter8            VARCHAR2(64) := '';
    v_parameter9            VARCHAR2(64) := ''; -- approved
    v_parameter10           VARCHAR2(64) := ''; -- test
    v_parameter11           VARCHAR2(64) := 'Y'; -- print release option
    v_parameter12           VARCHAR2(64) := ''; -- sort by
    v_parameter13           VARCHAR2(64) := '46077';
    v_parameter14           VARCHAR2(64) := '2'; -- Fax Enable
    v_parameter15           VARCHAR2(64) := 'N'; -- fax number
    v_parameter16           VARCHAR2(64) := ''; --
    v_parameter17           VARCHAR2(64) := 'Y'; -- print canceled lines
    v_parameter18           VARCHAR2(64) := 'N'; -- print blankets
    v_parameter19           VARCHAR2(64) := '';
    v_parameter20           VARCHAR2(64) := '';
    v_interval              NUMBER := 30; -- time change to 60
    v_max_wait              NUMBER := 0;
    v_request_phase         VARCHAR2(64);
    v_request_status        VARCHAR2(64);
    v_dev_request_phase     VARCHAR2(64);
    v_dev_request_status    VARCHAR2(64);
    v_request_status_mesg   VARCHAR2(64);
    v_call_status           BOOLEAN;
    v_err                   VARCHAR2(64);
   -- v_user_id               NUMBER := 411890;
    v_respon_id             NUMBER := g_respon_id;
    v_respn_appl_id         NUMBER := g_respn_appl_id;
  BEGIN
    fnd_global.apps_initialize(g_user_id, v_respon_id, v_respn_appl_id);
    COMMIT;
    /* submit a request to run */
    v_parameter3 := p_po_number;
    v_parameter4 := p_po_number;
    v_request_id := fnd_request.submit_request(v_application_shrt_name,
                                               v_concprogramshortn,
                                               v_description,
                                               v_start_time,
                                               v_sub_request,
                                               v_parameter1,
                                               v_parameter2,
                                               v_parameter3,
                                               v_parameter4,
                                               v_parameter5,
                                               v_parameter6,
                                               v_parameter7,
                                               v_parameter8,
                                               v_parameter9,
                                               v_parameter10,
                                               v_parameter11,
                                               v_parameter12,
                                               v_parameter13,
                                               v_parameter14,
                                               v_parameter15,
                                               v_parameter16,
                                               v_parameter17,
                                               v_parameter18,
                                               v_parameter19,
                                               v_parameter20);
    COMMIT;
    print_line('Submitted PHL BRANCH PO print request. Request ID: ' ||
               TO_CHAR(v_request_id) || ' for PO Number: ' || p_po_number);

    IF v_request_id = 0 THEN
      RETURN(0); -- failed request return 0
    END IF;

    /* wait for the concurrent program to complete */
    v_call_status := fnd_concurrent.wait_for_request(v_request_id,
                                                     v_interval,
                                                     v_max_wait,
                                                     v_request_phase,
                                                     v_request_status,
                                                     v_dev_request_phase,
                                                     v_dev_request_status,
                                                     v_request_status_mesg);
    COMMIT;

    IF (v_dev_request_phase = 'COMPLETE' AND
       v_dev_request_status = 'NORMAL') THEN
      RETURN(v_request_id);
    ELSE
      RETURN(v_request_id);  -- version 9.4
      -- RETURN(0);
    END IF;
  EXCEPTION
    WHEN OTHERS THEN
      v_err := SUBSTR(SQLERRM, 1, 50);
      print_line('Error in  ttec_po_run_pdf ' || v_err);
      RETURN(0);
  END ttec_po_run_phl_br_pdf; -- v 3.6 <End>
  FUNCTION ttec_po_run_phl_rohq_pdf(p_po_number IN VARCHAR2,
                                    p_date      IN DATE) RETURN NUMBER IS
    v_request_id            NUMBER := 0;
    v_application_shrt_name VARCHAR2(20) := 'CUST';
    /* v8.0 start */
    --v_concprogramshortn     VARCHAR2(32) := 'TTEC_US_CA_PDF_PO';
    --v_description           VARCHAR2(64) := 'Graphic Teletech US/Canada Purchase Order';
    v_concprogramshortn     VARCHAR2(32) := 'TTEC_PHP_PO_ROHQ';
    v_description           VARCHAR2(64) := 'TeleTech Philippines ROHQ Graphic Purchase Order';
    /* v8.0 end */
    v_start_time            VARCHAR2(64) := ''; --  NULL;
    v_sub_request           BOOLEAN := FALSE;
    v_parameter1            VARCHAR2(64) := 'R';
    v_parameter2            VARCHAR2(64) := ''; -- Buyer number
    v_parameter3            VARCHAR2(64) := '8300000'; -- PO from
    v_parameter4            VARCHAR2(64) := '8300000'; -- PO from
    v_parameter5            VARCHAR2(64) := '';
    v_parameter6            VARCHAR2(64) := '';
    v_parameter7            VARCHAR2(64) := '';
    v_parameter8            VARCHAR2(64) := '';
    v_parameter9            VARCHAR2(64) := ''; -- approved
    v_parameter10           VARCHAR2(64) := ''; -- test
    v_parameter11           VARCHAR2(64) := 'Y'; -- print release option
    v_parameter12           VARCHAR2(64) := ''; -- sort by
    v_parameter13           VARCHAR2(64) := '46077';
    v_parameter14           VARCHAR2(64) := '2'; -- Fax Enable
    v_parameter15           VARCHAR2(64) := 'N'; -- fax number
    v_parameter16           VARCHAR2(64) := ''; --
    v_parameter17           VARCHAR2(64) := 'Y'; -- print canceled lines
    v_parameter18           VARCHAR2(64) := 'N'; -- print blankets
    v_parameter19           VARCHAR2(64) := '';
    v_parameter20           VARCHAR2(64) := '';
    v_interval              NUMBER := 30; -- time change to 60
    v_max_wait              NUMBER := 0;
    v_request_phase         VARCHAR2(64);
    v_request_status        VARCHAR2(64);
    v_dev_request_phase     VARCHAR2(64);
    v_dev_request_status    VARCHAR2(64);
    v_request_status_mesg   VARCHAR2(64);
    v_call_status           BOOLEAN;
    v_err                   VARCHAR2(64);
   -- v_user_id               NUMBER := 411890;
    v_respon_id             NUMBER := g_respon_id;
    v_respn_appl_id         NUMBER := g_respn_appl_id;
  BEGIN
    fnd_global.apps_initialize(g_user_id, v_respon_id, v_respn_appl_id);
    COMMIT;
    /* submit a request to run */
    v_parameter3 := p_po_number;
    v_parameter4 := p_po_number;
    v_request_id := fnd_request.submit_request(v_application_shrt_name,
                                               v_concprogramshortn,
                                               v_description,
                                               v_start_time,
                                               v_sub_request,
                                               v_parameter1,
                                               v_parameter2,
                                               v_parameter3,
                                               v_parameter4,
                                               v_parameter5,
                                               v_parameter6,
                                               v_parameter7,
                                               v_parameter8,
                                               v_parameter9,
                                               v_parameter10,
                                               v_parameter11,
                                               v_parameter12,
                                               v_parameter13,
                                               v_parameter14,
                                               v_parameter15,
                                               v_parameter16,
                                               v_parameter17,
                                               v_parameter18,
                                               v_parameter19,
                                               v_parameter20);
    COMMIT;
    print_line('Submitted PHL BRANCH PO print request. Request ID: ' ||
               TO_CHAR(v_request_id) || ' for PO Number: ' || p_po_number);

    IF v_request_id = 0 THEN
      RETURN(0); -- failed request return 0
    END IF;

    /* wait for the concurrent program to complete */
    v_call_status := fnd_concurrent.wait_for_request(v_request_id,
                                                     v_interval,
                                                     v_max_wait,
                                                     v_request_phase,
                                                     v_request_status,
                                                     v_dev_request_phase,
                                                     v_dev_request_status,
                                                     v_request_status_mesg);
    COMMIT;

    IF (v_dev_request_phase = 'COMPLETE' AND
       v_dev_request_status = 'NORMAL') THEN
      RETURN(v_request_id);
    ELSE
      RETURN(v_request_id);  -- version 9.4
      -- RETURN(0);
    END IF;
  EXCEPTION
    WHEN OTHERS THEN
      v_err := SUBSTR(SQLERRM, 1, 50);
      print_line('Error in  ttec_po_run_pdf ' || v_err);
      RETURN(0);
  END ttec_po_run_phl_rohq_pdf;
  /* 10.1 Begin */
  FUNCTION ttec_po_run_phl_motif_pdf(p_po_number IN VARCHAR2,
                                     p_date      IN DATE) RETURN NUMBER IS
    v_request_id            NUMBER := 0;
    v_application_shrt_name VARCHAR2(20) := 'CUST';

    v_concprogramshortn     VARCHAR2(32) := 'TTEC_PHP_PO_MOTIF_RGB';
    v_description           VARCHAR2(64) := 'Motif Graphic Purchase Order - PHL';
    v_start_time            VARCHAR2(64) := ''; --  NULL;
    v_sub_request           BOOLEAN := FALSE;
    v_parameter1            VARCHAR2(64) := 'R';
    v_parameter2            VARCHAR2(64) := ''; -- Buyer number
    v_parameter3            VARCHAR2(64) := '670000'; -- PO from
    v_parameter4            VARCHAR2(64) := '670000'; -- PO from
    v_parameter5            VARCHAR2(64) := '';
    v_parameter6            VARCHAR2(64) := '';
    v_parameter7            VARCHAR2(64) := '';
    v_parameter8            VARCHAR2(64) := '';
    v_parameter9            VARCHAR2(64) := ''; -- approved
    v_parameter10           VARCHAR2(64) := ''; -- test
    v_parameter11           VARCHAR2(64) := 'Y'; -- print release option
    v_parameter12           VARCHAR2(64) := ''; -- sort by
    v_parameter13           VARCHAR2(64) := '46077';
    v_parameter14           VARCHAR2(64) := '2'; -- Fax Enable
    v_parameter15           VARCHAR2(64) := 'N'; -- fax number
    v_parameter16           VARCHAR2(64) := ''; --
    v_parameter17           VARCHAR2(64) := 'Y'; -- print canceled lines
    v_parameter18           VARCHAR2(64) := 'N'; -- print blankets
    v_parameter19           VARCHAR2(64) := '';
    v_parameter20           VARCHAR2(64) := '';
    v_interval              NUMBER := 30; -- time change to 60
    v_max_wait              NUMBER := 0;
    v_request_phase         VARCHAR2(64);
    v_request_status        VARCHAR2(64);
    v_dev_request_phase     VARCHAR2(64);
    v_dev_request_status    VARCHAR2(64);
    v_request_status_mesg   VARCHAR2(64);
    v_call_status           BOOLEAN;
    v_err                   VARCHAR2(64);
   -- v_user_id               NUMBER := 411890;
    v_respon_id             NUMBER := g_respon_id;
    v_respn_appl_id         NUMBER := g_respn_appl_id;
  BEGIN
    fnd_global.apps_initialize(g_user_id, v_respon_id, v_respn_appl_id);
    COMMIT;
    /* submit a request to run */
    v_parameter3 := p_po_number;
    v_parameter4 := p_po_number;
    v_request_id := fnd_request.submit_request(v_application_shrt_name,
                                               v_concprogramshortn,
                                               v_description,
                                               v_start_time,
                                               v_sub_request,
                                               v_parameter1,
                                               v_parameter2,
                                               v_parameter3,
                                               v_parameter4,
                                               v_parameter5,
                                               v_parameter6,
                                               v_parameter7,
                                               v_parameter8,
                                               v_parameter9,
                                               v_parameter10,
                                               v_parameter11,
                                               v_parameter12,
                                               v_parameter13,
                                               v_parameter14,
                                               v_parameter15,
                                               v_parameter16,
                                               v_parameter17,
                                               v_parameter18,
                                               v_parameter19,
                                               v_parameter20);
    COMMIT;
    print_line('Submitted PHL Motif PO print request. Request ID: ' ||
               TO_CHAR(v_request_id) || ' for PO Number: ' || p_po_number);

    IF v_request_id = 0 THEN
      RETURN(0); -- failed request return 0
    END IF;

    /* wait for the concurrent program to complete */
    v_call_status := fnd_concurrent.wait_for_request(v_request_id,
                                                     v_interval,
                                                     v_max_wait,
                                                     v_request_phase,
                                                     v_request_status,
                                                     v_dev_request_phase,
                                                     v_dev_request_status,
                                                     v_request_status_mesg);
    COMMIT;

    IF (v_dev_request_phase = 'COMPLETE' AND
       v_dev_request_status = 'NORMAL') THEN
      RETURN(v_request_id);
    ELSE
      RETURN(v_request_id);
      -- RETURN(0);
    END IF;
  EXCEPTION
    WHEN OTHERS THEN
      v_err := SUBSTR(SQLERRM, 1, 50);
      print_line('Error in  TTEC_PHP_PO_MOTIF_RGB ' || v_err);
      RETURN(0);
  END ttec_po_run_phl_motif_pdf;
 /* 10.1 End */
 /* 10.2 Begin */
  FUNCTION ttec_po_run_ind_motif_pdf(p_po_number IN VARCHAR2,
                                     p_date      IN DATE) RETURN NUMBER IS
    v_request_id            NUMBER := 0;
    v_application_shrt_name VARCHAR2(20) := 'CUST';

    v_concprogramshortn     VARCHAR2(32) := 'TTEC_IND_PO_MOTIF_RGB';
    v_description           VARCHAR2(64) := 'Motif Graphic Purchase Order - India';
    v_start_time            VARCHAR2(64) := ''; --  NULL;
    v_sub_request           BOOLEAN := FALSE;
    v_parameter1            VARCHAR2(64) := 'R';
    v_parameter2            VARCHAR2(64) := ''; -- Buyer number
    v_parameter3            VARCHAR2(64) := '680000'; -- PO from
    v_parameter4            VARCHAR2(64) := '680000'; -- PO from
    v_parameter5            VARCHAR2(64) := '';
    v_parameter6            VARCHAR2(64) := '';
    v_parameter7            VARCHAR2(64) := '';
    v_parameter8            VARCHAR2(64) := '';
    v_parameter9            VARCHAR2(64) := ''; -- approved
    v_parameter10           VARCHAR2(64) := ''; -- test
    v_parameter11           VARCHAR2(64) := 'Y'; -- print release option
    v_parameter12           VARCHAR2(64) := ''; -- sort by
    v_parameter13           VARCHAR2(64) := '46077';
    v_parameter14           VARCHAR2(64) := '2'; -- Fax Enable
    v_parameter15           VARCHAR2(64) := 'N'; -- fax number
    v_parameter16           VARCHAR2(64) := ''; --
    v_parameter17           VARCHAR2(64) := 'Y'; -- print canceled lines
    v_parameter18           VARCHAR2(64) := 'N'; -- print blankets
    v_parameter19           VARCHAR2(64) := '';
    v_parameter20           VARCHAR2(64) := '';
    v_interval              NUMBER := 30; -- time change to 60
    v_max_wait              NUMBER := 0;
    v_request_phase         VARCHAR2(64);
    v_request_status        VARCHAR2(64);
    v_dev_request_phase     VARCHAR2(64);
    v_dev_request_status    VARCHAR2(64);
    v_request_status_mesg   VARCHAR2(64);
    v_call_status           BOOLEAN;
    v_err                   VARCHAR2(64);
   -- v_user_id               NUMBER := 411890;
    v_respon_id             NUMBER := g_respon_id;
    v_respn_appl_id         NUMBER := g_respn_appl_id;
  BEGIN
    fnd_global.apps_initialize(g_user_id, v_respon_id, v_respn_appl_id);
    COMMIT;
    /* submit a request to run */
    v_parameter3 := p_po_number;
    v_parameter4 := p_po_number;
    v_request_id := fnd_request.submit_request(v_application_shrt_name,
                                               v_concprogramshortn,
                                               v_description,
                                               v_start_time,
                                               v_sub_request,
                                               v_parameter1,
                                               v_parameter2,
                                               v_parameter3,
                                               v_parameter4,
                                               v_parameter5,
                                               v_parameter6,
                                               v_parameter7,
                                               v_parameter8,
                                               v_parameter9,
                                               v_parameter10,
                                               v_parameter11,
                                               v_parameter12,
                                               v_parameter13,
                                               v_parameter14,
                                               v_parameter15,
                                               v_parameter16,
                                               v_parameter17,
                                               v_parameter18,
                                               v_parameter19,
                                               v_parameter20);
    COMMIT;
    print_line('Submitted India Motif PO print request. Request ID: ' ||
               TO_CHAR(v_request_id) || ' for PO Number: ' || p_po_number);

    IF v_request_id = 0 THEN
      RETURN(0); -- failed request return 0
    END IF;

    /* wait for the concurrent program to complete */
    v_call_status := fnd_concurrent.wait_for_request(v_request_id,
                                                     v_interval,
                                                     v_max_wait,
                                                     v_request_phase,
                                                     v_request_status,
                                                     v_dev_request_phase,
                                                     v_dev_request_status,
                                                     v_request_status_mesg);
    COMMIT;

    IF (v_dev_request_phase = 'COMPLETE' AND
       v_dev_request_status = 'NORMAL') THEN
      RETURN(v_request_id);
    ELSE
      RETURN(v_request_id);
      -- RETURN(0);
    END IF;
  EXCEPTION
    WHEN OTHERS THEN
      v_err := SUBSTR(SQLERRM, 1, 50);
      print_line('Error in  TTEC_IND_PO_MOTIF_RGB ' || v_err);
      RETURN(0);
  END ttec_po_run_ind_motif_pdf;
 /* 10.2 End */
  /* PCP US */
  FUNCTION ttec_po_run_pcp_us_pdf(p_po_number IN VARCHAR2, p_date IN DATE)
    RETURN NUMBER IS
    v_request_id            NUMBER := 0;
    v_application_shrt_name VARCHAR2(20) := 'CUST';
    v_concprogramshortn     VARCHAR2(32) := 'TTEC_PCP_US_CA_PDF_PO';
    v_description           VARCHAR2(64) := 'Graphic Percepta US/Canada Purchase Order';
    v_start_time            VARCHAR2(64) := ''; --  NULL;
    v_sub_request           BOOLEAN := FALSE;
    v_parameter1            VARCHAR2(64) := 'R';
    v_parameter2            VARCHAR2(64) := ''; -- Buyer number
    v_parameter3            VARCHAR2(64) := '51433'; -- PO from
    v_parameter4            VARCHAR2(64) := '51433'; -- PO from
    v_parameter5            VARCHAR2(64) := '';
    v_parameter6            VARCHAR2(64) := '';
    v_parameter7            VARCHAR2(64) := '';
    v_parameter8            VARCHAR2(64) := '';
    v_parameter9            VARCHAR2(64) := ''; -- approved
    v_parameter10           VARCHAR2(64) := ''; -- test
    v_parameter11           VARCHAR2(64) := 'Y'; -- print release option
    v_parameter12           VARCHAR2(64) := ''; -- sort by
    v_parameter13           VARCHAR2(64) := '46077';
    v_parameter14           VARCHAR2(64) := '2'; -- Fax Enable
    v_parameter15           VARCHAR2(64) := 'N'; -- fax number
    v_parameter16           VARCHAR2(64) := ''; --
    v_parameter17           VARCHAR2(64) := 'Y'; -- print canceled lines
    v_parameter18           VARCHAR2(64) := 'N'; -- print blankets
    v_parameter19           VARCHAR2(64) := '';
    v_parameter20           VARCHAR2(64) := '';
    v_interval              NUMBER := 30; -- time change to 60
    v_max_wait              NUMBER := 0;
    v_request_phase         VARCHAR2(64);
    v_request_status        VARCHAR2(64);
    v_dev_request_phase     VARCHAR2(64);
    v_dev_request_status    VARCHAR2(64);
    v_request_status_mesg   VARCHAR2(64);
    v_call_status           BOOLEAN;
    v_err                   VARCHAR2(64);
   -- v_user_id               NUMBER := 411890;
    v_respon_id             NUMBER := g_respon_id;
    v_respn_appl_id         NUMBER := g_respn_appl_id;
  BEGIN
    fnd_global.apps_initialize(g_user_id, v_respon_id, v_respn_appl_id);
    COMMIT;
    /* submit a request to run */
    v_parameter3 := p_po_number;
    v_parameter4 := p_po_number;
    v_request_id := fnd_request.submit_request(v_application_shrt_name,
                                               v_concprogramshortn,
                                               v_description,
                                               v_start_time,
                                               v_sub_request,
                                               v_parameter1,
                                               v_parameter2,
                                               v_parameter3,
                                               v_parameter4,
                                               v_parameter5,
                                               v_parameter6,
                                               v_parameter7,
                                               v_parameter8,
                                               v_parameter9,
                                               v_parameter10,
                                               v_parameter11,
                                               v_parameter12,
                                               v_parameter13,
                                               v_parameter14,
                                               v_parameter15,
                                               v_parameter16,
                                               v_parameter17,
                                               v_parameter18,
                                               v_parameter19,
                                               v_parameter20);
    COMMIT;
    print_line('Submitted PCP US PO print request. Request ID: ' ||
               TO_CHAR(v_request_id) || ' for PO Number: ' || p_po_number);

    IF v_request_id = 0 THEN
      RETURN(0); -- failed request return 0
    END IF;

    /* wait for the concurrent program to complete */
    v_call_status := fnd_concurrent.wait_for_request(v_request_id,
                                                     v_interval,
                                                     v_max_wait,
                                                     v_request_phase,
                                                     v_request_status,
                                                     v_dev_request_phase,
                                                     v_dev_request_status,
                                                     v_request_status_mesg);
    COMMIT;

    IF (v_dev_request_phase = 'COMPLETE' AND
       v_dev_request_status = 'NORMAL') THEN
      RETURN(v_request_id);
    ELSE
      RETURN(v_request_id);  -- version 9.4
      -- RETURN(0);
    END IF;
  EXCEPTION
    WHEN OTHERS THEN
      v_err := SUBSTR(SQLERRM, 1, 50);
      print_line('Error in  ttec_po_run_pdf ' || v_err);
      RETURN(0);
  END ttec_po_run_pcp_us_pdf;

  /* PCP UK */
  FUNCTION ttec_po_run_pcp_uk_pdf(p_po_number IN VARCHAR2, p_date IN DATE)
    RETURN NUMBER IS
    v_request_id            NUMBER := 0;
    v_application_shrt_name VARCHAR2(20) := 'CUST';
    v_concprogramshortn     VARCHAR2(32) := 'TTEC_PCP_UK_PDF_PO';
    v_description           VARCHAR2(64) := 'Graphic Percepta UK Purchase Ordert';
    v_start_time            VARCHAR2(64) := ''; --  NULL;
    v_sub_request           BOOLEAN := FALSE;
    v_parameter1            VARCHAR2(64) := 'R';
    v_parameter2            VARCHAR2(64) := ''; -- Buyer number
    v_parameter3            VARCHAR2(64) := '501141'; -- PO from
    v_parameter4            VARCHAR2(64) := '501141'; -- PO from
    v_parameter5            VARCHAR2(64) := '';
    v_parameter6            VARCHAR2(64) := '';
    v_parameter7            VARCHAR2(64) := '';
    v_parameter8            VARCHAR2(64) := '';
    v_parameter9            VARCHAR2(64) := ''; -- approved
    v_parameter10           VARCHAR2(64) := ''; -- test
    v_parameter11           VARCHAR2(64) := 'Y'; -- print release option
    v_parameter12           VARCHAR2(64) := ''; -- sort by
    v_parameter13           VARCHAR2(64) := '46077';
    v_parameter14           VARCHAR2(64) := '2'; -- Fax Enable
    v_parameter15           VARCHAR2(64) := 'N'; -- fax number
    v_parameter16           VARCHAR2(64) := ''; --
    v_parameter17           VARCHAR2(64) := 'Y'; -- print canceled lines
    v_parameter18           VARCHAR2(64) := 'N'; -- print blankets
    v_parameter19           VARCHAR2(64) := '';
    v_parameter20           VARCHAR2(64) := '';
    v_interval              NUMBER := 30; -- time change to 60
    v_max_wait              NUMBER := 0;
    v_request_phase         VARCHAR2(64);
    v_request_status        VARCHAR2(64);
    v_dev_request_phase     VARCHAR2(64);
    v_dev_request_status    VARCHAR2(64);
    v_request_status_mesg   VARCHAR2(64);
    v_call_status           BOOLEAN;
    v_err                   VARCHAR2(64);
   -- v_user_id               NUMBER := 411890;
    v_respon_id             NUMBER := g_respon_id;
    v_respn_appl_id         NUMBER := g_respn_appl_id;
  BEGIN
    fnd_global.apps_initialize(g_user_id, v_respon_id, v_respn_appl_id);
    COMMIT;
    /* submit a request to run */
    v_parameter3 := p_po_number;
    v_parameter4 := p_po_number;
    v_request_id := fnd_request.submit_request(v_application_shrt_name,
                                               v_concprogramshortn,
                                               v_description,
                                               v_start_time,
                                               v_sub_request,
                                               v_parameter1,
                                               v_parameter2,
                                               v_parameter3,
                                               v_parameter4,
                                               v_parameter5,
                                               v_parameter6,
                                               v_parameter7,
                                               v_parameter8,
                                               v_parameter9,
                                               v_parameter10,
                                               v_parameter11,
                                               v_parameter12,
                                               v_parameter13,
                                               v_parameter14,
                                               v_parameter15,
                                               v_parameter16,
                                               v_parameter17,
                                               v_parameter18,
                                               v_parameter19,
                                               v_parameter20);
    COMMIT;
    print_line('Submitted PCP UK PO print request. Request ID: ' ||
               TO_CHAR(v_request_id) || ' for PO Number: ' || p_po_number);

    IF v_request_id = 0 THEN
      RETURN(0); -- failed request return 0
    END IF;

    /* wait for the concurrent program to complete */
    v_call_status := fnd_concurrent.wait_for_request(v_request_id,
                                                     v_interval,
                                                     v_max_wait,
                                                     v_request_phase,
                                                     v_request_status,
                                                     v_dev_request_phase,
                                                     v_dev_request_status,
                                                     v_request_status_mesg);
    COMMIT;

    IF (v_dev_request_phase = 'COMPLETE' AND
       v_dev_request_status = 'NORMAL') THEN
      RETURN(v_request_id);
    ELSE
      RETURN(v_request_id);  -- version 9.4
      -- RETURN(0);
    END IF;
  EXCEPTION
    WHEN OTHERS THEN
      v_err := SUBSTR(SQLERRM, 1, 50);
      print_line('Error in  ttec_po_run_pdf ' || v_err);
      RETURN(0);
  END ttec_po_run_pcp_uk_pdf;

  /* PCP CA */
  FUNCTION ttec_po_run_pcp_ca_pdf(p_po_number IN VARCHAR2, p_date IN DATE)
    RETURN NUMBER IS
    v_request_id            NUMBER := 0;
    v_application_shrt_name VARCHAR2(20) := 'CUST';
    v_concprogramshortn     VARCHAR2(32) := 'TTEC_PCP_US_CA_PDF_PO';
    v_description           VARCHAR2(64) := ' Graphic Percepta US/Canada Purchase Order';
    v_start_time            VARCHAR2(64) := ''; --  NULL;
    v_sub_request           BOOLEAN := FALSE;
    v_parameter1            VARCHAR2(64) := 'R';
    v_parameter2            VARCHAR2(64) := ''; -- Buyer number
    v_parameter3            VARCHAR2(64) := '700163'; -- PO from
    v_parameter4            VARCHAR2(64) := '700163'; -- PO from
    v_parameter5            VARCHAR2(64) := '';
    v_parameter6            VARCHAR2(64) := '';
    v_parameter7            VARCHAR2(64) := '';
    v_parameter8            VARCHAR2(64) := '';
    v_parameter9            VARCHAR2(64) := ''; -- approved
    v_parameter10           VARCHAR2(64) := ''; -- test
    v_parameter11           VARCHAR2(64) := 'Y'; -- print release option
    v_parameter12           VARCHAR2(64) := ''; -- sort by
    v_parameter13           VARCHAR2(64) := '46077';
    v_parameter14           VARCHAR2(64) := '2'; -- Fax Enable
    v_parameter15           VARCHAR2(64) := 'N'; -- fax number
    v_parameter16           VARCHAR2(64) := ''; --
    v_parameter17           VARCHAR2(64) := 'Y'; -- print canceled lines
    v_parameter18           VARCHAR2(64) := 'N'; -- print blankets
    v_parameter19           VARCHAR2(64) := '';
    v_parameter20           VARCHAR2(64) := '';
    v_interval              NUMBER := 30; -- time change to 60
    v_max_wait              NUMBER := 0;
    v_request_phase         VARCHAR2(64);
    v_request_status        VARCHAR2(64);
    v_dev_request_phase     VARCHAR2(64);
    v_dev_request_status    VARCHAR2(64);
    v_request_status_mesg   VARCHAR2(64);
    v_call_status           BOOLEAN;
    v_err                   VARCHAR2(64);
   -- v_user_id               NUMBER := 411890;
    v_respon_id             NUMBER := g_respon_id;
    v_respn_appl_id         NUMBER := g_respn_appl_id;
  BEGIN
    fnd_global.apps_initialize(g_user_id, v_respon_id, v_respn_appl_id);
    COMMIT;
    /* submit a request to run */
    v_parameter3 := p_po_number;
    v_parameter4 := p_po_number;
    v_request_id := fnd_request.submit_request(v_application_shrt_name,
                                               v_concprogramshortn,
                                               v_description,
                                               v_start_time,
                                               v_sub_request,
                                               v_parameter1,
                                               v_parameter2,
                                               v_parameter3,
                                               v_parameter4,
                                               v_parameter5,
                                               v_parameter6,
                                               v_parameter7,
                                               v_parameter8,
                                               v_parameter9,
                                               v_parameter10,
                                               v_parameter11,
                                               v_parameter12,
                                               v_parameter13,
                                               v_parameter14,
                                               v_parameter15,
                                               v_parameter16,
                                               v_parameter17,
                                               v_parameter18,
                                               v_parameter19,
                                               v_parameter20);
    COMMIT;
    print_line('Submitted PCP CA PO print request. Request ID: ' ||
               TO_CHAR(v_request_id) || ' for PO Number: ' || p_po_number);

    IF v_request_id = 0 THEN
      RETURN(0); -- failed request return 0
    END IF;

    /* wait for the concurrent program to complete */
    v_call_status := fnd_concurrent.wait_for_request(v_request_id,
                                                     v_interval,
                                                     v_max_wait,
                                                     v_request_phase,
                                                     v_request_status,
                                                     v_dev_request_phase,
                                                     v_dev_request_status,
                                                     v_request_status_mesg);
    COMMIT;

    IF (v_dev_request_phase = 'COMPLETE' AND
       v_dev_request_status = 'NORMAL') THEN
      RETURN(v_request_id);
    ELSE
      RETURN(v_request_id);  -- version 9.4
      -- RETURN(0);
    END IF;
  EXCEPTION
    WHEN OTHERS THEN
      v_err := SUBSTR(SQLERRM, 1, 50);
      print_line('Error in  ttec_po_run_pdf ' || v_err);
      RETURN(0);
  END ttec_po_run_pcp_ca_pdf;

  /* New Zealand */
  FUNCTION ttec_po_run_nz_pdf(p_po_number IN VARCHAR2, p_date IN DATE)
    RETURN NUMBER IS
    v_request_id            NUMBER := 0;
    v_application_shrt_name VARCHAR2(20) := 'CUST';
    v_concprogramshortn     VARCHAR2(32) := 'POXPRPOP_TELETECH_NZ';
    v_description           VARCHAR2(64) := 'Graphic Teletech NZ Purchase Order Print';
    v_start_time            VARCHAR2(64) := ''; --  NULL;
    v_sub_request           BOOLEAN := FALSE;
    v_parameter1            VARCHAR2(64) := 'R';
    v_parameter2            VARCHAR2(64) := ''; -- Buyer number
    v_parameter3            VARCHAR2(64) := '62446'; -- PO from
    v_parameter4            VARCHAR2(64) := '62446'; -- PO from
    v_parameter5            VARCHAR2(64) := '';
    v_parameter6            VARCHAR2(64) := '';
    v_parameter7            VARCHAR2(64) := '';
    v_parameter8            VARCHAR2(64) := '';
    v_parameter9            VARCHAR2(64) := ''; -- approved
    v_parameter10           VARCHAR2(64) := ''; -- test
    v_parameter11           VARCHAR2(64) := 'Y'; -- print release option
    v_parameter12           VARCHAR2(64) := ''; -- sort by
    v_parameter13           VARCHAR2(64) := '46077';
    v_parameter14           VARCHAR2(64) := '2'; -- Fax Enable
    v_parameter15           VARCHAR2(64) := 'N'; -- fax number
    v_parameter16           VARCHAR2(64) := ''; --
    v_parameter17           VARCHAR2(64) := 'Y'; -- print canceled lines
    v_parameter18           VARCHAR2(64) := 'N'; -- print blankets
    v_parameter19           VARCHAR2(64) := '';
    v_parameter20           VARCHAR2(64) := '';
    v_interval              NUMBER := 30; -- time change to 60
    v_max_wait              NUMBER := 0;
    v_request_phase         VARCHAR2(64);
    v_request_status        VARCHAR2(64);
    v_dev_request_phase     VARCHAR2(64);
    v_dev_request_status    VARCHAR2(64);
    v_request_status_mesg   VARCHAR2(64);
    v_call_status           BOOLEAN;
    v_err                   VARCHAR2(64);
   -- v_user_id               NUMBER := 411890;
    v_respon_id             NUMBER := g_respon_id;
    v_respn_appl_id         NUMBER := g_respn_appl_id;
  BEGIN
    fnd_global.apps_initialize(g_user_id, v_respon_id, v_respn_appl_id);
    COMMIT;
    /* submit a request to run */
    v_parameter3 := p_po_number;
    v_parameter4 := p_po_number;
    v_request_id := fnd_request.submit_request(v_application_shrt_name,
                                               v_concprogramshortn,
                                               v_description,
                                               v_start_time,
                                               v_sub_request,
                                               v_parameter1,
                                               v_parameter2,
                                               v_parameter3,
                                               v_parameter4,
                                               v_parameter5,
                                               v_parameter6,
                                               v_parameter7,
                                               v_parameter8,
                                               v_parameter9,
                                               v_parameter10,
                                               v_parameter11,
                                               v_parameter12,
                                               v_parameter13,
                                               v_parameter14,
                                               v_parameter15,
                                               v_parameter16,
                                               v_parameter17,
                                               v_parameter18,
                                               v_parameter19,
                                               v_parameter20);
    COMMIT;
    print_line('Submitted New Zealand PO print request. Request ID: ' ||
               TO_CHAR(v_request_id) || ' for PO Number: ' || p_po_number);

    IF v_request_id = 0 THEN
      RETURN(0); -- failed request return 0
    END IF;

    /* wait for the concurrent program to complete */
    v_call_status := fnd_concurrent.wait_for_request(v_request_id,
                                                     v_interval,
                                                     v_max_wait,
                                                     v_request_phase,
                                                     v_request_status,
                                                     v_dev_request_phase,
                                                     v_dev_request_status,
                                                     v_request_status_mesg);
    COMMIT;

    IF (v_dev_request_phase = 'COMPLETE' AND
       v_dev_request_status = 'NORMAL') THEN
      RETURN(v_request_id);
    ELSE
      RETURN(v_request_id);  -- version 9.4
      -- RETURN(0);
    END IF;
  EXCEPTION
    WHEN OTHERS THEN
      v_err := SUBSTR(SQLERRM, 1, 50);
      print_line('Error in  ttec_po_run_pdf ' || v_err);
      RETURN(0);
  END ttec_po_run_nz_pdf;

  /* Mexico */
  FUNCTION ttec_po_run_mx_pdf(p_po_number IN VARCHAR2, p_date IN DATE)
    RETURN NUMBER IS
    v_request_id            NUMBER := 0;
    v_application_shrt_name VARCHAR2(20) := 'CUST';
    v_concprogramshortn     VARCHAR2(32) := 'TTEC_MEX_PDF_PO';
    v_description           VARCHAR2(64) := 'Graphic Teletech Mexico Purchase Order';
    v_start_time            VARCHAR2(64) := ''; --  NULL;
    v_sub_request           BOOLEAN := FALSE;
    v_parameter1            VARCHAR2(64) := 'R';
    v_parameter2            VARCHAR2(64) := ''; -- Buyer number
    v_parameter3            VARCHAR2(64) := '613329'; -- PO from
    v_parameter4            VARCHAR2(64) := '613329'; -- PO from
    v_parameter5            VARCHAR2(64) := '';
    v_parameter6            VARCHAR2(64) := '';
    v_parameter7            VARCHAR2(64) := '';
    v_parameter8            VARCHAR2(64) := '';
    v_parameter9            VARCHAR2(64) := ''; -- approved
    v_parameter10           VARCHAR2(64) := ''; -- test
    v_parameter11           VARCHAR2(64) := 'Y'; -- print release option
    v_parameter12           VARCHAR2(64) := ''; -- sort by
    v_parameter13           VARCHAR2(64) := '46077';
    v_parameter14           VARCHAR2(64) := '2'; -- Fax Enable
    v_parameter15           VARCHAR2(64) := 'N'; -- fax number
    v_parameter16           VARCHAR2(64) := ''; --
    v_parameter17           VARCHAR2(64) := 'Y'; -- print canceled lines
    v_parameter18           VARCHAR2(64) := 'N'; -- print blankets
    v_parameter19           VARCHAR2(64) := '';
    v_parameter20           VARCHAR2(64) := '';
    v_interval              NUMBER := 30; -- time change to 60
    v_max_wait              NUMBER := 0;
    v_request_phase         VARCHAR2(64);
    v_request_status        VARCHAR2(64);
    v_dev_request_phase     VARCHAR2(64);
    v_dev_request_status    VARCHAR2(64);
    v_request_status_mesg   VARCHAR2(64);
    v_call_status           BOOLEAN;
    v_err                   VARCHAR2(64);
   -- v_user_id               NUMBER := 411890;
    v_respon_id             NUMBER := g_respon_id;
    v_respn_appl_id         NUMBER := g_respn_appl_id;
  BEGIN
    fnd_global.apps_initialize(g_user_id, v_respon_id, v_respn_appl_id);
    COMMIT;
    /* submit a request to run */
    v_parameter3 := p_po_number;
    v_parameter4 := p_po_number;
    v_request_id := fnd_request.submit_request(v_application_shrt_name,
                                               v_concprogramshortn,
                                               v_description,
                                               v_start_time,
                                               v_sub_request,
                                               v_parameter1,
                                               v_parameter2,
                                               v_parameter3,
                                               v_parameter4,
                                               v_parameter5,
                                               v_parameter6,
                                               v_parameter7,
                                               v_parameter8,
                                               v_parameter9,
                                               v_parameter10,
                                               v_parameter11,
                                               v_parameter12,
                                               v_parameter13,
                                               v_parameter14,
                                               v_parameter15,
                                               v_parameter16,
                                               v_parameter17,
                                               v_parameter18,
                                               v_parameter19,
                                               v_parameter20);
    COMMIT;
    print_line('Submitted Mexico PO print request. Request ID: ' ||
               TO_CHAR(v_request_id) || ' for PO Number: ' || p_po_number);

    IF v_request_id = 0 THEN
      RETURN(0); -- failed request return 0
    END IF;

    /* wait for the concurrent program to complete */
    v_call_status := fnd_concurrent.wait_for_request(v_request_id,
                                                     v_interval,
                                                     v_max_wait,
                                                     v_request_phase,
                                                     v_request_status,
                                                     v_dev_request_phase,
                                                     v_dev_request_status,
                                                     v_request_status_mesg);
    COMMIT;

    IF (v_dev_request_phase = 'COMPLETE' AND
       v_dev_request_status = 'NORMAL') THEN
      RETURN(v_request_id);
    ELSE
      RETURN(v_request_id);  -- version 9.4
      -- RETURN(0);
    END IF;
  EXCEPTION
    WHEN OTHERS THEN
      v_err := SUBSTR(SQLERRM, 1, 50);
      print_line('Error in  ttec_po_run_pdf ' || v_err);
      RETURN(0);
  END ttec_po_run_mx_pdf;

  /* Mexico Bajio*/
  FUNCTION ttec_po_run_mxb_pdf(p_po_number IN VARCHAR2, p_date IN DATE)
    RETURN NUMBER IS
    v_request_id            NUMBER := 0;
    v_application_shrt_name VARCHAR2(20) := 'CUST';
    v_concprogramshortn     VARCHAR2(32) := 'TTEC_MEX_PDF_PO';
    v_description           VARCHAR2(64) := 'Graphic Teletech Mexico Purchase Order';
    v_start_time            VARCHAR2(64) := ''; --  NULL;
    v_sub_request           BOOLEAN := FALSE;
    v_parameter1            VARCHAR2(64) := 'R';
    v_parameter2            VARCHAR2(64) := ''; -- Buyer number
    v_parameter3            VARCHAR2(64) := '613329'; -- PO from
    v_parameter4            VARCHAR2(64) := '613329'; -- PO from
    v_parameter5            VARCHAR2(64) := '';
    v_parameter6            VARCHAR2(64) := '';
    v_parameter7            VARCHAR2(64) := '';
    v_parameter8            VARCHAR2(64) := '';
    v_parameter9            VARCHAR2(64) := ''; -- approved
    v_parameter10           VARCHAR2(64) := ''; -- test
    v_parameter11           VARCHAR2(64) := 'Y'; -- print release option
    v_parameter12           VARCHAR2(64) := ''; -- sort by
    v_parameter13           VARCHAR2(64) := '46077';
    v_parameter14           VARCHAR2(64) := '2'; -- Fax Enable
    v_parameter15           VARCHAR2(64) := 'N'; -- fax number
    v_parameter16           VARCHAR2(64) := ''; --
    v_parameter17           VARCHAR2(64) := 'Y'; -- print canceled lines
    v_parameter18           VARCHAR2(64) := 'N'; -- print blankets
    v_parameter19           VARCHAR2(64) := '';
    v_parameter20           VARCHAR2(64) := '';
    v_interval              NUMBER := 30; -- time change to 60
    v_max_wait              NUMBER := 0;
    v_request_phase         VARCHAR2(64);
    v_request_status        VARCHAR2(64);
    v_dev_request_phase     VARCHAR2(64);
    v_dev_request_status    VARCHAR2(64);
    v_request_status_mesg   VARCHAR2(64);
    v_call_status           BOOLEAN;
    v_err                   VARCHAR2(64);
   -- v_user_id               NUMBER := 411890;
    v_respon_id             NUMBER := g_respon_id;
    v_respn_appl_id         NUMBER := g_respn_appl_id;
  BEGIN
    fnd_global.apps_initialize(g_user_id, v_respon_id, v_respn_appl_id);
    COMMIT;
    /* submit a request to run */
    v_parameter3 := p_po_number;
    v_parameter4 := p_po_number;
    v_request_id := fnd_request.submit_request(v_application_shrt_name,
                                               v_concprogramshortn,
                                               v_description,
                                               v_start_time,
                                               v_sub_request,
                                               v_parameter1,
                                               v_parameter2,
                                               v_parameter3,
                                               v_parameter4,
                                               v_parameter5,
                                               v_parameter6,
                                               v_parameter7,
                                               v_parameter8,
                                               v_parameter9,
                                               v_parameter10,
                                               v_parameter11,
                                               v_parameter12,
                                               v_parameter13,
                                               v_parameter14,
                                               v_parameter15,
                                               v_parameter16,
                                               v_parameter17,
                                               v_parameter18,
                                               v_parameter19,
                                               v_parameter20);
    COMMIT;
    print_line('Submitted Mexico PO print request. Request ID: ' ||
               TO_CHAR(v_request_id) || ' for PO Number: ' || p_po_number);

    IF v_request_id = 0 THEN
      RETURN(0); -- failed request return 0
    END IF;

    /* wait for the concurrent program to complete */
    v_call_status := fnd_concurrent.wait_for_request(v_request_id,
                                                     v_interval,
                                                     v_max_wait,
                                                     v_request_phase,
                                                     v_request_status,
                                                     v_dev_request_phase,
                                                     v_dev_request_status,
                                                     v_request_status_mesg);
    COMMIT;

    IF (v_dev_request_phase = 'COMPLETE' AND
       v_dev_request_status = 'NORMAL') THEN
      RETURN(v_request_id);
    ELSE
      RETURN(v_request_id);  -- version 9.4
      -- RETURN(0);
    END IF;
  EXCEPTION
    WHEN OTHERS THEN
      v_err := SUBSTR(SQLERRM, 1, 50);
      print_line('Error in  ttec_po_run_pdf ' || v_err);
      RETURN(0);
  END ttec_po_run_mxb_pdf;

  /* Mexico SSI*/
  FUNCTION ttec_po_run_mxs_pdf(p_po_number IN VARCHAR2, p_date IN DATE)
    RETURN NUMBER IS
    v_request_id            NUMBER := 0;
    v_application_shrt_name VARCHAR2(20) := 'CUST';
    v_concprogramshortn     VARCHAR2(32) := 'TTEC_MEX_PDF_PO';
    v_description           VARCHAR2(64) := 'Graphic Teletech Mexico Purchase Order';
    v_start_time            VARCHAR2(64) := ''; --  NULL;
    v_sub_request           BOOLEAN := FALSE;
    v_parameter1            VARCHAR2(64) := 'R';
    v_parameter2            VARCHAR2(64) := ''; -- Buyer number
    v_parameter3            VARCHAR2(64) := '613329'; -- PO from
    v_parameter4            VARCHAR2(64) := '613329'; -- PO from
    v_parameter5            VARCHAR2(64) := '';
    v_parameter6            VARCHAR2(64) := '';
    v_parameter7            VARCHAR2(64) := '';
    v_parameter8            VARCHAR2(64) := '';
    v_parameter9            VARCHAR2(64) := ''; -- approved
    v_parameter10           VARCHAR2(64) := ''; -- test
    v_parameter11           VARCHAR2(64) := 'Y'; -- print release option
    v_parameter12           VARCHAR2(64) := ''; -- sort by
    v_parameter13           VARCHAR2(64) := '46077';
    v_parameter14           VARCHAR2(64) := '2'; -- Fax Enable
    v_parameter15           VARCHAR2(64) := 'N'; -- fax number
    v_parameter16           VARCHAR2(64) := ''; --
    v_parameter17           VARCHAR2(64) := 'Y'; -- print canceled lines
    v_parameter18           VARCHAR2(64) := 'N'; -- print blankets
    v_parameter19           VARCHAR2(64) := '';
    v_parameter20           VARCHAR2(64) := '';
    v_interval              NUMBER := 30; -- time change to 60
    v_max_wait              NUMBER := 0;
    v_request_phase         VARCHAR2(64);
    v_request_status        VARCHAR2(64);
    v_dev_request_phase     VARCHAR2(64);
    v_dev_request_status    VARCHAR2(64);
    v_request_status_mesg   VARCHAR2(64);
    v_call_status           BOOLEAN;
    v_err                   VARCHAR2(64);
   -- v_user_id               NUMBER := 411890;
    v_respon_id             NUMBER := g_respon_id;
    v_respn_appl_id         NUMBER := g_respn_appl_id;
  BEGIN
    fnd_global.apps_initialize(g_user_id, v_respon_id, v_respn_appl_id);
    COMMIT;
    /* submit a request to run */
    v_parameter3 := p_po_number;
    v_parameter4 := p_po_number;
    v_request_id := fnd_request.submit_request(v_application_shrt_name,
                                               v_concprogramshortn,
                                               v_description,
                                               v_start_time,
                                               v_sub_request,
                                               v_parameter1,
                                               v_parameter2,
                                               v_parameter3,
                                               v_parameter4,
                                               v_parameter5,
                                               v_parameter6,
                                               v_parameter7,
                                               v_parameter8,
                                               v_parameter9,
                                               v_parameter10,
                                               v_parameter11,
                                               v_parameter12,
                                               v_parameter13,
                                               v_parameter14,
                                               v_parameter15,
                                               v_parameter16,
                                               v_parameter17,
                                               v_parameter18,
                                               v_parameter19,
                                               v_parameter20);
    COMMIT;
    print_line('Submitted Mexico PO print request. Request ID: ' ||
               TO_CHAR(v_request_id) || ' for PO Number: ' || p_po_number);

    IF v_request_id = 0 THEN
      RETURN(0); -- failed request return 0
    END IF;

    /* wait for the concurrent program to complete */
    v_call_status := fnd_concurrent.wait_for_request(v_request_id,
                                                     v_interval,
                                                     v_max_wait,
                                                     v_request_phase,
                                                     v_request_status,
                                                     v_dev_request_phase,
                                                     v_dev_request_status,
                                                     v_request_status_mesg);
    COMMIT;

    IF (v_dev_request_phase = 'COMPLETE' AND
       v_dev_request_status = 'NORMAL') THEN
      RETURN(v_request_id);
    ELSE
      RETURN(v_request_id);  -- version 9.4
      -- RETURN(0);
    END IF;
  EXCEPTION
    WHEN OTHERS THEN
      v_err := SUBSTR(SQLERRM, 1, 50);
      print_line('Error in  ttec_po_run_pdf ' || v_err);
      RETURN(0);
  END ttec_po_run_mxs_pdf;

  /* MAL */
  FUNCTION ttec_po_run_mal_pdf(p_po_number IN VARCHAR2, p_date IN DATE)
    RETURN NUMBER IS
    v_request_id            NUMBER := 0;
    v_application_shrt_name VARCHAR2(20) := 'CUST';
    v_concprogramshortn     VARCHAR2(32) := 'POXPRPOP_TELETECH_MAL';
    v_description           VARCHAR2(64) := 'TeleTech MAL Purchase Order Print';
    v_start_time            VARCHAR2(64) := ''; --  NULL;
    v_sub_request           BOOLEAN := FALSE;
    v_parameter1            VARCHAR2(64) := 'R';
    v_parameter2            VARCHAR2(64) := ''; -- Buyer number
    v_parameter3            VARCHAR2(64) := '80911'; -- PO from
    v_parameter4            VARCHAR2(64) := '80911'; -- PO from
    v_parameter5            VARCHAR2(64) := '';
    v_parameter6            VARCHAR2(64) := '';
    v_parameter7            VARCHAR2(64) := '';
    v_parameter8            VARCHAR2(64) := '';
    v_parameter9            VARCHAR2(64) := ''; -- approved
    v_parameter10           VARCHAR2(64) := ''; -- test
    v_parameter11           VARCHAR2(64) := 'Y'; -- print release option
    v_parameter12           VARCHAR2(64) := ''; -- sort by
    v_parameter13           VARCHAR2(64) := '46077';
    v_parameter14           VARCHAR2(64) := '2'; -- Fax Enable
    v_parameter15           VARCHAR2(64) := 'N'; -- fax number
    v_parameter16           VARCHAR2(64) := ''; --
    v_parameter17           VARCHAR2(64) := 'Y'; -- print canceled lines
    v_parameter18           VARCHAR2(64) := 'N'; -- print blankets
    v_parameter19           VARCHAR2(64) := '';
    v_parameter20           VARCHAR2(64) := '';
    v_interval              NUMBER := 30; -- time change to 60
    v_max_wait              NUMBER := 0;
    v_request_phase         VARCHAR2(64);
    v_request_status        VARCHAR2(64);
    v_dev_request_phase     VARCHAR2(64);
    v_dev_request_status    VARCHAR2(64);
    v_request_status_mesg   VARCHAR2(64);
    v_call_status           BOOLEAN;
    v_err                   VARCHAR2(64);
   -- v_user_id               NUMBER := 411890;
    v_respon_id             NUMBER := g_respon_id;
    v_respn_appl_id         NUMBER := g_respn_appl_id;
  BEGIN
    fnd_global.apps_initialize(g_user_id, v_respon_id, v_respn_appl_id);
    COMMIT;
    /* submit a request to run */
    v_parameter3 := p_po_number;
    v_parameter4 := p_po_number;
    v_request_id := fnd_request.submit_request(v_application_shrt_name,
                                               v_concprogramshortn,
                                               v_description,
                                               v_start_time,
                                               v_sub_request,
                                               v_parameter1,
                                               v_parameter2,
                                               v_parameter3,
                                               v_parameter4,
                                               v_parameter5,
                                               v_parameter6,
                                               v_parameter7,
                                               v_parameter8,
                                               v_parameter9,
                                               v_parameter10,
                                               v_parameter11,
                                               v_parameter12,
                                               v_parameter13,
                                               v_parameter14,
                                               v_parameter15,
                                               v_parameter16,
                                               v_parameter17,
                                               v_parameter18,
                                               v_parameter19,
                                               v_parameter20);
    COMMIT;
    print_line('Submitted MAL PO print request. Request ID: ' ||
               TO_CHAR(v_request_id) || ' for PO Number: ' || p_po_number);

    IF v_request_id = 0 THEN
      RETURN(0); -- failed request return 0
    END IF;

    /* wait for the concurrent program to complete */
    v_call_status := fnd_concurrent.wait_for_request(v_request_id,
                                                     v_interval,
                                                     v_max_wait,
                                                     v_request_phase,
                                                     v_request_status,
                                                     v_dev_request_phase,
                                                     v_dev_request_status,
                                                     v_request_status_mesg);
    COMMIT;

    IF (v_dev_request_phase = 'COMPLETE' AND
       v_dev_request_status = 'NORMAL') THEN
      RETURN(v_request_id);
    ELSE
      RETURN(v_request_id);  -- version 9.4
      -- RETURN(0);
    END IF;
  EXCEPTION
    WHEN OTHERS THEN
      v_err := SUBSTR(SQLERRM, 1, 50);
      print_line('Error in  ttec_po_run_pdf ' || v_err);
      RETURN(0);
  END ttec_po_run_mal_pdf;

  /* Hong Kong  changed by Ver 7.0 */
  FUNCTION ttec_po_run_hkg_pdf(p_po_number IN VARCHAR2, p_date IN DATE)
    RETURN NUMBER IS
    v_request_id            NUMBER := 0;
    v_application_shrt_name VARCHAR2(20) := 'CUST';
    v_concprogramshortn     VARCHAR2(32) := 'TTEC_HKG_PO_PDF'; --'POXPRPOP_TELETECH_HKG';
    v_description           VARCHAR2(64) := 'Graphic Hong Kong Purchase Order'; --'TeleTech HKG Purchase Order Print';
    v_start_time            VARCHAR2(64) := ''; --  NULL;
    v_sub_request           BOOLEAN := FALSE;
    v_parameter1            VARCHAR2(64) := 'R';
    v_parameter2            VARCHAR2(64) := ''; -- Buyer number
    v_parameter3            VARCHAR2(64) := '1001519'; -- PO from
    v_parameter4            VARCHAR2(64) := '1001519'; -- PO from
    v_parameter5            VARCHAR2(64) := '';
    v_parameter6            VARCHAR2(64) := '';
    v_parameter7            VARCHAR2(64) := '';
    v_parameter8            VARCHAR2(64) := '';
    v_parameter9            VARCHAR2(64) := ''; -- approved
    v_parameter10           VARCHAR2(64) := ''; -- test
    v_parameter11           VARCHAR2(64) := 'Y'; -- print release option
    v_parameter12           VARCHAR2(64) := ''; -- sort by
    v_parameter13           VARCHAR2(64) := '46077';
    v_parameter14           VARCHAR2(64) := '2'; -- Fax Enable
    v_parameter15           VARCHAR2(64) := 'N'; -- fax number
    v_parameter16           VARCHAR2(64) := ''; --
    v_parameter17           VARCHAR2(64) := 'Y'; -- print canceled lines
    v_parameter18           VARCHAR2(64) := 'N'; -- print blankets
    v_parameter19           VARCHAR2(64) := '';
    v_parameter20           VARCHAR2(64) := '';
    v_interval              NUMBER := 30; -- time change to 60
    v_max_wait              NUMBER := 0;
    v_request_phase         VARCHAR2(64);
    v_request_status        VARCHAR2(64);
    v_dev_request_phase     VARCHAR2(64);
    v_dev_request_status    VARCHAR2(64);
    v_request_status_mesg   VARCHAR2(64);
    v_call_status           BOOLEAN;
    v_err                   VARCHAR2(64);
   -- v_user_id               NUMBER := 411890;
    v_respon_id             NUMBER := g_respon_id;
    v_respn_appl_id         NUMBER := g_respn_appl_id;
  BEGIN
    fnd_global.apps_initialize(g_user_id, v_respon_id, v_respn_appl_id);
    COMMIT;
    /* submit a request to run */
    v_parameter3 := p_po_number;
    v_parameter4 := p_po_number;
    v_request_id := fnd_request.submit_request(v_application_shrt_name,
                                               v_concprogramshortn,
                                               v_description,
                                               v_start_time,
                                               v_sub_request,
                                               v_parameter1,
                                               v_parameter2,
                                               v_parameter3,
                                               v_parameter4,
                                               v_parameter5,
                                               v_parameter6,
                                               v_parameter7,
                                               v_parameter8,
                                               v_parameter9,
                                               v_parameter10,
                                               v_parameter11,
                                               v_parameter12,
                                               v_parameter13,
                                               v_parameter14,
                                               v_parameter15,
                                               v_parameter16,
                                               v_parameter17,
                                               v_parameter18,
                                               v_parameter19,
                                               v_parameter20);
    COMMIT;
    print_line('Submitted HKG PO print request. Request ID: ' ||
               TO_CHAR(v_request_id) || ' for PO Number: ' || p_po_number);

    IF v_request_id = 0 THEN
      RETURN(0); -- failed request return 0
    END IF;

    /* wait for the concurrent program to complete */
    v_call_status := fnd_concurrent.wait_for_request(v_request_id,
                                                     v_interval,
                                                     v_max_wait,
                                                     v_request_phase,
                                                     v_request_status,
                                                     v_dev_request_phase,
                                                     v_dev_request_status,
                                                     v_request_status_mesg);
    COMMIT;

    IF (v_dev_request_phase = 'COMPLETE' AND
       v_dev_request_status = 'NORMAL') THEN
      RETURN(v_request_id);
    ELSE
      RETURN(v_request_id);  -- version 9.4
      -- RETURN(0);
    END IF;
  EXCEPTION
    WHEN OTHERS THEN
      v_err := SUBSTR(SQLERRM, 1, 50);
      print_line('Error in  ttec_po_run_pdf ' || v_err);
      RETURN(0);
  END ttec_po_run_hkg_pdf;

  /* DAC */
  FUNCTION ttec_po_run_dac_pdf(p_po_number IN VARCHAR2, p_date IN DATE)
    RETURN NUMBER IS
    v_request_id            NUMBER := 0;
    v_application_shrt_name VARCHAR2(20) := 'CUST';
    v_concprogramshortn     VARCHAR2(32) := 'TTEC_DAC_US_PDF_PO';
    v_description           VARCHAR2(64) := 'Graphic DAC US Printed Purchase Order';
    v_start_time            VARCHAR2(64) := ''; --  NULL;
    v_sub_request           BOOLEAN := FALSE;
    v_parameter1            VARCHAR2(64) := 'R';
    v_parameter2            VARCHAR2(64) := ''; -- Buyer number
    v_parameter3            VARCHAR2(64) := '700775'; -- PO from
    v_parameter4            VARCHAR2(64) := '700775'; -- PO from
    v_parameter5            VARCHAR2(64) := '';
    v_parameter6            VARCHAR2(64) := '';
    v_parameter7            VARCHAR2(64) := '';
    v_parameter8            VARCHAR2(64) := '';
    v_parameter9            VARCHAR2(64) := ''; -- approved
    v_parameter10           VARCHAR2(64) := ''; -- test
    v_parameter11           VARCHAR2(64) := 'Y'; -- print release option
    v_parameter12           VARCHAR2(64) := ''; -- sort by
    v_parameter13           VARCHAR2(64) := '46077';
    v_parameter14           VARCHAR2(64) := '2'; -- Fax Enable
    v_parameter15           VARCHAR2(64) := 'N'; -- fax number
    v_parameter16           VARCHAR2(64) := ''; --
    v_parameter17           VARCHAR2(64) := 'Y'; -- print canceled lines
    v_parameter18           VARCHAR2(64) := 'N'; -- print blankets
    v_parameter19           VARCHAR2(64) := '';
    v_parameter20           VARCHAR2(64) := '';
    v_interval              NUMBER := 30; -- time change to 60
    v_max_wait              NUMBER := 0;
    v_request_phase         VARCHAR2(64);
    v_request_status        VARCHAR2(64);
    v_dev_request_phase     VARCHAR2(64);
    v_dev_request_status    VARCHAR2(64);
    v_request_status_mesg   VARCHAR2(64);
    v_call_status           BOOLEAN;
    v_err                   VARCHAR2(64);
   -- v_user_id               NUMBER := 411890;
    v_respon_id             NUMBER := g_respon_id;
    v_respn_appl_id         NUMBER := g_respn_appl_id;
  BEGIN
    fnd_global.apps_initialize(g_user_id, v_respon_id, v_respn_appl_id);
    COMMIT;
    /* submit a request to run */
    v_parameter3 := p_po_number;
    v_parameter4 := p_po_number;
    v_request_id := fnd_request.submit_request(v_application_shrt_name,
                                               v_concprogramshortn,
                                               v_description,
                                               v_start_time,
                                               v_sub_request,
                                               v_parameter1,
                                               v_parameter2,
                                               v_parameter3,
                                               v_parameter4,
                                               v_parameter5,
                                               v_parameter6,
                                               v_parameter7,
                                               v_parameter8,
                                               v_parameter9,
                                               v_parameter10,
                                               v_parameter11,
                                               v_parameter12,
                                               v_parameter13,
                                               v_parameter14,
                                               v_parameter15,
                                               v_parameter16,
                                               v_parameter17,
                                               v_parameter18,
                                               v_parameter19,
                                               v_parameter20);
    COMMIT;
    print_line('Submitted DAC PO print request. Request ID: ' ||
               TO_CHAR(v_request_id) || ' for PO Number: ' || p_po_number);

    IF v_request_id = 0 THEN
      RETURN(0); -- failed request return 0
    END IF;

    /* wait for the concurrent program to complete */
    v_call_status := fnd_concurrent.wait_for_request(v_request_id,
                                                     v_interval,
                                                     v_max_wait,
                                                     v_request_phase,
                                                     v_request_status,
                                                     v_dev_request_phase,
                                                     v_dev_request_status,
                                                     v_request_status_mesg);
    COMMIT;

    IF (v_dev_request_phase = 'COMPLETE' AND
       v_dev_request_status = 'NORMAL') THEN
      RETURN(v_request_id);
    ELSE
      RETURN(v_request_id);  -- version 9.4
      -- RETURN(0);
    END IF;
  EXCEPTION
    WHEN OTHERS THEN
      v_err := SUBSTR(SQLERRM, 1, 50);
      print_line('Error in  ttec_po_run_pdf ' || v_err);
      RETURN(0);
  END ttec_po_run_dac_pdf;

  /* Costa Rica */
  FUNCTION ttec_po_run_cr_pdf(p_po_number IN VARCHAR2, p_date IN DATE)
    RETURN NUMBER IS
    v_request_id            NUMBER := 0;
    v_application_shrt_name VARCHAR2(20) := 'CUST';
    v_concprogramshortn     VARCHAR2(32) := 'TTEC_TTEC_CR_PDF_PO';
    v_description           VARCHAR2(64) := 'Graphic Teletech Costa Rica Purchase Order';
    v_start_time            VARCHAR2(64) := ''; --  NULL;
    v_sub_request           BOOLEAN := FALSE;
    v_parameter1            VARCHAR2(64) := 'R';
    v_parameter2            VARCHAR2(64) := ''; -- Buyer number
    v_parameter3            VARCHAR2(64) := '3000930'; -- PO from
    v_parameter4            VARCHAR2(64) := '3000930'; -- PO from
    v_parameter5            VARCHAR2(64) := '';
    v_parameter6            VARCHAR2(64) := '';
    v_parameter7            VARCHAR2(64) := '';
    v_parameter8            VARCHAR2(64) := '';
    v_parameter9            VARCHAR2(64) := ''; -- approved
    v_parameter10           VARCHAR2(64) := ''; -- test
    v_parameter11           VARCHAR2(64) := 'Y'; -- print release option
    v_parameter12           VARCHAR2(64) := ''; -- sort by
    v_parameter13           VARCHAR2(64) := '46077';
    v_parameter14           VARCHAR2(64) := '2'; -- Fax Enable
    v_parameter15           VARCHAR2(64) := 'N'; -- fax number
    v_parameter16           VARCHAR2(64) := ''; --
    v_parameter17           VARCHAR2(64) := 'Y'; -- print canceled lines
    v_parameter18           VARCHAR2(64) := 'N'; -- print blankets
    v_parameter19           VARCHAR2(64) := '';
    v_parameter20           VARCHAR2(64) := '';
    v_interval              NUMBER := 30; -- time change to 60
    v_max_wait              NUMBER := 0;
    v_request_phase         VARCHAR2(64);
    v_request_status        VARCHAR2(64);
    v_dev_request_phase     VARCHAR2(64);
    v_dev_request_status    VARCHAR2(64);
    v_request_status_mesg   VARCHAR2(64);
    v_call_status           BOOLEAN;
    v_err                   VARCHAR2(64);
   -- v_user_id               NUMBER := 411890;
    v_respon_id             NUMBER := g_respon_id;
    v_respn_appl_id         NUMBER := g_respn_appl_id;
  BEGIN
    fnd_global.apps_initialize(g_user_id, v_respon_id, v_respn_appl_id);
    COMMIT;
    /* submit a request to run */
    v_parameter3 := p_po_number;
    v_parameter4 := p_po_number;
    v_request_id := fnd_request.submit_request(v_application_shrt_name,
                                               v_concprogramshortn,
                                               v_description,
                                               v_start_time,
                                               v_sub_request,
                                               v_parameter1,
                                               v_parameter2,
                                               v_parameter3,
                                               v_parameter4,
                                               v_parameter5,
                                               v_parameter6,
                                               v_parameter7,
                                               v_parameter8,
                                               v_parameter9,
                                               v_parameter10,
                                               v_parameter11,
                                               v_parameter12,
                                               v_parameter13,
                                               v_parameter14,
                                               v_parameter15,
                                               v_parameter16,
                                               v_parameter17,
                                               v_parameter18,
                                               v_parameter19,
                                               v_parameter20);
    COMMIT;
    print_line('Submitted Costa Rica PO print request. Request ID: ' ||
               TO_CHAR(v_request_id) || ' for PO Number: ' || p_po_number);

    IF v_request_id = 0 THEN
      RETURN(0); -- failed request return 0
    END IF;

    /* wait for the concurrent program to complete */
    v_call_status := fnd_concurrent.wait_for_request(v_request_id,
                                                     v_interval,
                                                     v_max_wait,
                                                     v_request_phase,
                                                     v_request_status,
                                                     v_dev_request_phase,
                                                     v_dev_request_status,
                                                     v_request_status_mesg);
    COMMIT;

    IF (v_dev_request_phase = 'COMPLETE' AND
       v_dev_request_status = 'NORMAL') THEN
      RETURN(v_request_id);
    ELSE
      RETURN(v_request_id);  -- version 9.4
      -- RETURN(0);
    END IF;
  EXCEPTION
    WHEN OTHERS THEN
      v_err := SUBSTR(SQLERRM, 1, 50);
      print_line('Error in  ttec_po_run_pdf ' || v_err);
      RETURN(0);
  END ttec_po_run_cr_pdf;

  /* Spain Costa Rica */
  FUNCTION ttec_po_run_scr_pdf(p_po_number IN VARCHAR2, p_date IN DATE)
    RETURN NUMBER IS
    v_request_id            NUMBER := 0;
    v_application_shrt_name VARCHAR2(20) := 'CUST';
    v_concprogramshortn     VARCHAR2(32) := 'TTEC_TTEC_CR_PDF_PO';
    v_description           VARCHAR2(64) := 'Graphic Teletech Costa Rica Purchase Order';
    v_start_time            VARCHAR2(64) := ''; --  NULL;
    v_sub_request           BOOLEAN := FALSE;
    v_parameter1            VARCHAR2(64) := 'R';
    v_parameter2            VARCHAR2(64) := ''; -- Buyer number
    v_parameter3            VARCHAR2(64) := '3000930'; -- PO from
    v_parameter4            VARCHAR2(64) := '3000930'; -- PO from
    v_parameter5            VARCHAR2(64) := '';
    v_parameter6            VARCHAR2(64) := '';
    v_parameter7            VARCHAR2(64) := '';
    v_parameter8            VARCHAR2(64) := '';
    v_parameter9            VARCHAR2(64) := ''; -- approved
    v_parameter10           VARCHAR2(64) := ''; -- test
    v_parameter11           VARCHAR2(64) := 'Y'; -- print release option
    v_parameter12           VARCHAR2(64) := ''; -- sort by
    v_parameter13           VARCHAR2(64) := '46077';
    v_parameter14           VARCHAR2(64) := '2'; -- Fax Enable
    v_parameter15           VARCHAR2(64) := 'N'; -- fax number
    v_parameter16           VARCHAR2(64) := ''; --
    v_parameter17           VARCHAR2(64) := 'Y'; -- print canceled lines
    v_parameter18           VARCHAR2(64) := 'N'; -- print blankets
    v_parameter19           VARCHAR2(64) := '';
    v_parameter20           VARCHAR2(64) := '';
    v_interval              NUMBER := 30; -- time change to 60
    v_max_wait              NUMBER := 0;
    v_request_phase         VARCHAR2(64);
    v_request_status        VARCHAR2(64);
    v_dev_request_phase     VARCHAR2(64);
    v_dev_request_status    VARCHAR2(64);
    v_request_status_mesg   VARCHAR2(64);
    v_call_status           BOOLEAN;
    v_err                   VARCHAR2(64);
   -- v_user_id               NUMBER := 411890;
    v_respon_id             NUMBER := g_respon_id;
    v_respn_appl_id         NUMBER := g_respn_appl_id;
  BEGIN
    fnd_global.apps_initialize(g_user_id, v_respon_id, v_respn_appl_id);
    COMMIT;
    /* submit a request to run */
    v_parameter3 := p_po_number;
    v_parameter4 := p_po_number;
    v_request_id := fnd_request.submit_request(v_application_shrt_name,
                                               v_concprogramshortn,
                                               v_description,
                                               v_start_time,
                                               v_sub_request,
                                               v_parameter1,
                                               v_parameter2,
                                               v_parameter3,
                                               v_parameter4,
                                               v_parameter5,
                                               v_parameter6,
                                               v_parameter7,
                                               v_parameter8,
                                               v_parameter9,
                                               v_parameter10,
                                               v_parameter11,
                                               v_parameter12,
                                               v_parameter13,
                                               v_parameter14,
                                               v_parameter15,
                                               v_parameter16,
                                               v_parameter17,
                                               v_parameter18,
                                               v_parameter19,
                                               v_parameter20);
    COMMIT;
    print_line('Submitted Costa Rica PO print request. Request ID: ' ||
               TO_CHAR(v_request_id) || ' for PO Number: ' || p_po_number);

    IF v_request_id = 0 THEN
      RETURN(0); -- failed request return 0
    END IF;

    /* wait for the concurrent program to complete */
    v_call_status := fnd_concurrent.wait_for_request(v_request_id,
                                                     v_interval,
                                                     v_max_wait,
                                                     v_request_phase,
                                                     v_request_status,
                                                     v_dev_request_phase,
                                                     v_dev_request_status,
                                                     v_request_status_mesg);
    COMMIT;

    IF (v_dev_request_phase = 'COMPLETE' AND
       v_dev_request_status = 'NORMAL') THEN
      RETURN(v_request_id);
    ELSE
      RETURN(v_request_id);  -- version 9.4
      -- RETURN(0);
    END IF;
  EXCEPTION
    WHEN OTHERS THEN
      v_err := SUBSTR(SQLERRM, 1, 50);
      print_line('Error in  ttec_po_run_pdf ' || v_err);
      RETURN(0);
  END ttec_po_run_scr_pdf;

  /* Brazil */
  FUNCTION ttec_po_run_brz_pdf(p_po_number IN VARCHAR2, p_date IN DATE)
    RETURN NUMBER IS
    v_request_id            NUMBER := 0;
    v_application_shrt_name VARCHAR2(20) := 'CUST';
    v_concprogramshortn     VARCHAR2(32) := 'TTEC_BRAZIL_PDF_PO';
    v_description           VARCHAR2(64) := 'Graphic TeleTech Brazil Purchase Order';
    v_start_time            VARCHAR2(64) := ''; --  NULL;
    v_sub_request           BOOLEAN := FALSE;
    v_parameter1            VARCHAR2(64) := 'R';
    v_parameter2            VARCHAR2(64) := ''; -- Buyer number
    v_parameter3            VARCHAR2(64) := '43950'; -- PO from
    v_parameter4            VARCHAR2(64) := '43950'; -- PO from
    v_parameter5            VARCHAR2(64) := '';
    v_parameter6            VARCHAR2(64) := '';
    v_parameter7            VARCHAR2(64) := '';
    v_parameter8            VARCHAR2(64) := '';
    v_parameter9            VARCHAR2(64) := ''; -- approved
    v_parameter10           VARCHAR2(64) := ''; -- test
    v_parameter11           VARCHAR2(64) := 'Y'; -- print release option
    v_parameter12           VARCHAR2(64) := ''; -- sort by
    v_parameter13           VARCHAR2(64) := '46077';
    v_parameter14           VARCHAR2(64) := '2'; -- Fax Enable
    v_parameter15           VARCHAR2(64) := 'N'; -- fax number
    v_parameter16           VARCHAR2(64) := ''; --
    v_parameter17           VARCHAR2(64) := 'Y'; -- print canceled lines
    v_parameter18           VARCHAR2(64) := 'N'; -- print blankets
    v_parameter19           VARCHAR2(64) := '';
    v_parameter20           VARCHAR2(64) := '';
    v_interval              NUMBER := 30; -- time change to 60
    v_max_wait              NUMBER := 0;
    v_request_phase         VARCHAR2(64);
    v_request_status        VARCHAR2(64);
    v_dev_request_phase     VARCHAR2(64);
    v_dev_request_status    VARCHAR2(64);
    v_request_status_mesg   VARCHAR2(64);
    v_call_status           BOOLEAN;
    v_err                   VARCHAR2(64);
   -- v_user_id               NUMBER := 411890;
    v_respon_id             NUMBER := g_respon_id;
    v_respn_appl_id         NUMBER := g_respn_appl_id;
  BEGIN
    fnd_global.apps_initialize(g_user_id, v_respon_id, v_respn_appl_id);
    COMMIT;
    /* submit a request to run */
    v_parameter3 := p_po_number;
    v_parameter4 := p_po_number;
    v_request_id := fnd_request.submit_request(v_application_shrt_name,
                                               v_concprogramshortn,
                                               v_description,
                                               v_start_time,
                                               v_sub_request,
                                               v_parameter1,
                                               v_parameter2,
                                               v_parameter3,
                                               v_parameter4,
                                               v_parameter5,
                                               v_parameter6,
                                               v_parameter7,
                                               v_parameter8,
                                               v_parameter9,
                                               v_parameter10,
                                               v_parameter11,
                                               v_parameter12,
                                               v_parameter13,
                                               v_parameter14,
                                               v_parameter15,
                                               v_parameter16,
                                               v_parameter17,
                                               v_parameter18,
                                               v_parameter19 --,
                                               -- v_parameter20
                                               );
    COMMIT;
    print_line('Submitted Brazil PO print request. Request ID: ' ||
               TO_CHAR(v_request_id) || ' for PO Number: ' || p_po_number);

    IF v_request_id = 0 THEN
      RETURN(0); -- failed request return 0
    END IF;

    /* wait for the concurrent program to complete */
    v_call_status := fnd_concurrent.wait_for_request(v_request_id,
                                                     v_interval,
                                                     v_max_wait,
                                                     v_request_phase,
                                                     v_request_status,
                                                     v_dev_request_phase,
                                                     v_dev_request_status,
                                                     v_request_status_mesg);
    COMMIT;

    IF (v_dev_request_phase = 'COMPLETE' AND
       v_dev_request_status = 'NORMAL') THEN
      RETURN(v_request_id);
    ELSE
      RETURN(v_request_id);  -- version 9.4
      -- RETURN(0);
    END IF;
  EXCEPTION
    WHEN OTHERS THEN
      v_err := SUBSTR(SQLERRM, 1, 50);
      print_line('Error in  ttec_po_run_pdf ' || v_err);
      RETURN(0);
  END ttec_po_run_brz_pdf;

  /* GHANA */
  ---New specification on R#349360 v3.0
  FUNCTION ttec_po_run_gha_pdf(p_po_number IN VARCHAR2, p_date IN DATE)
    RETURN NUMBER IS
    v_request_id            NUMBER := 0;
    v_application_shrt_name VARCHAR2(20) := 'CUST';
    v_concprogramshortn     VARCHAR2(32) := 'TTEC_US_CA_PDF_PO';
    v_description           VARCHAR2(64) := 'Graphic Teletech US/Canada Purchase Order';
    v_start_time            VARCHAR2(64) := ''; --  NULL;
    v_sub_request           BOOLEAN := FALSE;
    v_parameter1            VARCHAR2(64) := 'R';
    v_parameter2            VARCHAR2(64) := ''; -- Buyer number
    v_parameter3            VARCHAR2(64) := '220018'; -- PO from
    v_parameter4            VARCHAR2(64) := '220018'; -- PO from
    v_parameter5            VARCHAR2(64) := '';
    v_parameter6            VARCHAR2(64) := '';
    v_parameter7            VARCHAR2(64) := '';
    v_parameter8            VARCHAR2(64) := '';
    v_parameter9            VARCHAR2(64) := ''; -- approved
    v_parameter10           VARCHAR2(64) := ''; -- test
    v_parameter11           VARCHAR2(64) := 'Y'; -- print release option
    v_parameter12           VARCHAR2(64) := ''; -- sort by
    v_parameter13           VARCHAR2(64) := '46077';
    v_parameter14           VARCHAR2(64) := '2'; -- Fax Enable
    v_parameter15           VARCHAR2(64) := 'N'; -- fax number
    v_parameter16           VARCHAR2(64) := ''; --
    v_parameter17           VARCHAR2(64) := 'Y'; -- print canceled lines
    v_parameter18           VARCHAR2(64) := 'N'; -- print blankets
    v_parameter19           VARCHAR2(64) := '';
    v_parameter20           VARCHAR2(64) := '';
    v_interval              NUMBER := 30; -- time change to 60
    v_max_wait              NUMBER := 0;
    v_request_phase         VARCHAR2(64);
    v_request_status        VARCHAR2(64);
    v_dev_request_phase     VARCHAR2(64);
    v_dev_request_status    VARCHAR2(64);
    v_request_status_mesg   VARCHAR2(64);
    v_call_status           BOOLEAN;
    v_err                   VARCHAR2(64);
   -- v_user_id               NUMBER := 411890;
    v_respon_id             NUMBER := g_respon_id;
    v_respn_appl_id         NUMBER := g_respn_appl_id;
  BEGIN
    fnd_global.apps_initialize(g_user_id, v_respon_id, v_respn_appl_id);
    COMMIT;
    /* submit a request to run */
    v_parameter3 := p_po_number;
    v_parameter4 := p_po_number;
    v_request_id := fnd_request.submit_request(v_application_shrt_name,
                                               v_concprogramshortn,
                                               v_description,
                                               v_start_time,
                                               v_sub_request,
                                               v_parameter1,
                                               v_parameter2,
                                               v_parameter3,
                                               v_parameter4,
                                               v_parameter5,
                                               v_parameter6,
                                               v_parameter7,
                                               v_parameter8,
                                               v_parameter9,
                                               v_parameter10,
                                               v_parameter11,
                                               v_parameter12,
                                               v_parameter13,
                                               v_parameter14,
                                               v_parameter15,
                                               v_parameter16,
                                               v_parameter17,
                                               v_parameter18,
                                               v_parameter19,
                                               v_parameter20);
    COMMIT;
    print_line('Submitted GHA PO print request. Request ID: ' ||
               TO_CHAR(v_request_id) || ' for PO Number: ' || p_po_number);

    IF v_request_id = 0 THEN
      RETURN(0); -- failed request return 0
    END IF;

    /* wait for the concurrent program to complete */
    v_call_status := fnd_concurrent.wait_for_request(v_request_id,
                                                     v_interval,
                                                     v_max_wait,
                                                     v_request_phase,
                                                     v_request_status,
                                                     v_dev_request_phase,
                                                     v_dev_request_status,
                                                     v_request_status_mesg);
    COMMIT;

    IF (v_dev_request_phase = 'COMPLETE' AND
       v_dev_request_status = 'NORMAL') THEN
      RETURN(v_request_id);
    ELSE
      RETURN(v_request_id);  -- version 9.4
      -- RETURN(0);
    END IF;
  EXCEPTION
    WHEN OTHERS THEN
      v_err := SUBSTR(SQLERRM, 1, 50);
      print_line('Error in  ttec_po_run_pdf ' || v_err);
      RETURN(0);
  END ttec_po_run_gha_pdf;

  /*End GHANA End New specification on R#349360 v3.0 */
  -- 3.3 PRG
  FUNCTION ttec_po_run_prg_pdf(p_po_number IN VARCHAR2, p_date IN DATE)
    RETURN NUMBER IS
    v_request_id            NUMBER := 0;
    v_application_shrt_name VARCHAR2(20) := 'CUST';
    v_concprogramshortn     VARCHAR2(32) := 'TTEC_PRG_US_PDF_PO';
    v_description           VARCHAR2(64) := 'Graphic PRG Purchase Order';
    v_start_time            VARCHAR2(64) := ''; --  NULL;
    v_sub_request           BOOLEAN := FALSE;
    v_parameter1            VARCHAR2(64) := 'R';
    v_parameter2            VARCHAR2(64) := ''; -- Buyer number
    v_parameter3            VARCHAR2(64) := '220018'; -- PO from
    v_parameter4            VARCHAR2(64) := '220018'; -- PO from
    v_parameter5            VARCHAR2(64) := '';
    v_parameter6            VARCHAR2(64) := '';
    v_parameter7            VARCHAR2(64) := '';
    v_parameter8            VARCHAR2(64) := '';
    v_parameter9            VARCHAR2(64) := ''; -- approved
    v_parameter10           VARCHAR2(64) := ''; -- test
    v_parameter11           VARCHAR2(64) := 'Y'; -- print release option
    v_parameter12           VARCHAR2(64) := ''; -- sort by
    v_parameter13           VARCHAR2(64) := '46077';
    v_parameter14           VARCHAR2(64) := '2'; -- Fax Enable
    v_parameter15           VARCHAR2(64) := 'N'; -- fax number
    v_parameter16           VARCHAR2(64) := ''; --
    v_parameter17           VARCHAR2(64) := 'Y'; -- print canceled lines
    v_parameter18           VARCHAR2(64) := 'N'; -- print blankets
    v_parameter19           VARCHAR2(64) := 'TTEC'; -- prg
    v_parameter20           VARCHAR2(64) := 'US'; -- prg
    -- v_parameter19             VARCHAR2 (64) := '';
    --  v_parameter20             VARCHAR2 (64) := '';
    v_interval            NUMBER := 30; -- time change to 60
    v_max_wait            NUMBER := 0;
    v_request_phase       VARCHAR2(64);
    v_request_status      VARCHAR2(64);
    v_dev_request_phase   VARCHAR2(64);
    v_dev_request_status  VARCHAR2(64);
    v_request_status_mesg VARCHAR2(64);
    v_call_status         BOOLEAN;
    v_err                 VARCHAR2(64);
   -- v_user_id               NUMBER := 411890;
    v_respon_id             NUMBER := g_respon_id;
    v_respn_appl_id         NUMBER := g_respn_appl_id;
  BEGIN
    fnd_global.apps_initialize(g_user_id, v_respon_id, v_respn_appl_id);
    COMMIT;
    /* submit a request to run */
    v_parameter3 := p_po_number;
    v_parameter4 := p_po_number;
    v_request_id := fnd_request.submit_request(v_application_shrt_name,
                                               v_concprogramshortn,
                                               v_description,
                                               v_start_time,
                                               v_sub_request,
                                               v_parameter1,
                                               v_parameter2,
                                               v_parameter3,
                                               v_parameter4,
                                               v_parameter5,
                                               v_parameter6,
                                               v_parameter7,
                                               v_parameter8,
                                               v_parameter9,
                                               v_parameter10,
                                               v_parameter11,
                                               v_parameter12,
                                               v_parameter13,
                                               v_parameter14,
                                               v_parameter15,
                                               v_parameter16,
                                               v_parameter17,
                                               v_parameter18,
                                               v_parameter19,
                                               v_parameter20);
    COMMIT;
    print_line('Submitted PRG PO print request. Request ID: ' ||
               TO_CHAR(v_request_id) || ' for PO Number: ' || p_po_number);

    IF v_request_id = 0 THEN
      RETURN(0); -- failed request return 0
    END IF;

    /* wait for the concurrent program to complete */
    v_call_status := fnd_concurrent.wait_for_request(v_request_id,
                                                     v_interval,
                                                     v_max_wait,
                                                     v_request_phase,
                                                     v_request_status,
                                                     v_dev_request_phase,
                                                     v_dev_request_status,
                                                     v_request_status_mesg);
    COMMIT;

    IF (v_dev_request_phase = 'COMPLETE' AND
       v_dev_request_status = 'NORMAL') THEN
      RETURN(v_request_id);
    ELSE
      RETURN(v_request_id);  -- version 9.4
      -- RETURN(0);
    END IF;
  EXCEPTION
    WHEN OTHERS THEN
      v_err := SUBSTR(SQLERRM, 1, 50);
      print_line('Error in  ttec_po_run_pdf ' || v_err);
      RETURN(0);
  END ttec_po_run_prg_pdf;

  /*TTSD R 653870 implementation for Dubai*/
  -- Version 5.3 <Start>
  FUNCTION ttec_po_run_prg_dubai_pdf(p_po_number IN VARCHAR2,
                                     p_date      IN DATE) RETURN NUMBER IS
    v_request_id            NUMBER := 0;
    v_application_shrt_name VARCHAR2(20) := 'CUST';
    v_concprogramshortn     VARCHAR2(32) := 'TTEC_PRG_US_PDF_PO';
    v_description           VARCHAR2(64) := 'Graphic PRG Purchase Order';
    v_start_time            VARCHAR2(64) := ''; --  NULL;
    v_sub_request           BOOLEAN := FALSE;
    v_parameter1            VARCHAR2(64) := 'R';
    v_parameter2            VARCHAR2(64) := ''; -- Buyer number
    v_parameter3            VARCHAR2(64) := '220018'; -- PO from
    v_parameter4            VARCHAR2(64) := '220018'; -- PO from
    v_parameter5            VARCHAR2(64) := '';
    v_parameter6            VARCHAR2(64) := '';
    v_parameter7            VARCHAR2(64) := '';
    v_parameter8            VARCHAR2(64) := '';
    v_parameter9            VARCHAR2(64) := ''; -- approved
    v_parameter10           VARCHAR2(64) := ''; -- test
    v_parameter11           VARCHAR2(64) := 'Y'; -- print release option
    v_parameter12           VARCHAR2(64) := ''; -- sort by
    v_parameter13           VARCHAR2(64) := '46077';
    v_parameter14           VARCHAR2(64) := '2'; -- Fax Enable
    v_parameter15           VARCHAR2(64) := 'N'; -- fax number
    v_parameter16           VARCHAR2(64) := ''; --
    v_parameter17           VARCHAR2(64) := 'Y'; -- print canceled lines
    v_parameter18           VARCHAR2(64) := 'N'; -- print blankets
    v_parameter19           VARCHAR2(64) := 'TTEC'; -- prg
    v_parameter20           VARCHAR2(64) := 'US'; -- prg
    -- v_parameter19             VARCHAR2 (64) := '';
    --  v_parameter20             VARCHAR2 (64) := '';
    v_interval            NUMBER := 30; -- time change to 60
    v_max_wait            NUMBER := 0;
    v_request_phase       VARCHAR2(64);
    v_request_status      VARCHAR2(64);
    v_dev_request_phase   VARCHAR2(64);
    v_dev_request_status  VARCHAR2(64);
    v_request_status_mesg VARCHAR2(64);
    v_call_status         BOOLEAN;
    v_err                 VARCHAR2(64);
   -- v_user_id               NUMBER := 411890;
    v_respon_id             NUMBER := g_respon_id;
    v_respn_appl_id         NUMBER := g_respn_appl_id;
  BEGIN
    fnd_global.apps_initialize(g_user_id, v_respon_id, v_respn_appl_id);
    COMMIT;
    /* submit a request to run */
    v_parameter3 := p_po_number;
    v_parameter4 := p_po_number;
    v_request_id := fnd_request.submit_request(v_application_shrt_name,
                                               v_concprogramshortn,
                                               v_description,
                                               v_start_time,
                                               v_sub_request,
                                               v_parameter1,
                                               v_parameter2,
                                               v_parameter3,
                                               v_parameter4,
                                               v_parameter5,
                                               v_parameter6,
                                               v_parameter7,
                                               v_parameter8,
                                               v_parameter9,
                                               v_parameter10,
                                               v_parameter11,
                                               v_parameter12,
                                               v_parameter13,
                                               v_parameter14,
                                               v_parameter15,
                                               v_parameter16,
                                               v_parameter17,
                                               v_parameter18,
                                               v_parameter19,
                                               v_parameter20);
    COMMIT;
    print_line('Submitted PRG PO print request. Request ID: ' ||
               TO_CHAR(v_request_id) || ' for PO Number: ' || p_po_number);

    IF v_request_id = 0 THEN
      RETURN(0); -- failed request return 0
    END IF;

    /* wait for the concurrent program to complete */
    v_call_status := fnd_concurrent.wait_for_request(v_request_id,
                                                     v_interval,
                                                     v_max_wait,
                                                     v_request_phase,
                                                     v_request_status,
                                                     v_dev_request_phase,
                                                     v_dev_request_status,
                                                     v_request_status_mesg);
    COMMIT;

    IF (v_dev_request_phase = 'COMPLETE' AND
       v_dev_request_status = 'NORMAL') THEN
      RETURN(v_request_id);
    ELSE
      RETURN(v_request_id);  -- version 9.4
      -- RETURN(0);
    END IF;
  EXCEPTION
    WHEN OTHERS THEN
      v_err := SUBSTR(SQLERRM, 1, 50);
      print_line('Error in  ttec_po_run_pdf ' || v_err);
      RETURN(0);
  END ttec_po_run_prg_dubai_pdf;

  FUNCTION ttec_po_run_prg_bel_pdf(p_po_number IN VARCHAR2, p_date IN DATE)
    RETURN NUMBER IS
    v_request_id            NUMBER := 0;
    v_application_shrt_name VARCHAR2(20) := 'CUST';
    v_concprogramshortn     VARCHAR2(32) := 'TTEC_PRG_US_PDF_PO';
    v_description           VARCHAR2(64) := 'Graphic PRG Purchase Order';
    v_start_time            VARCHAR2(64) := ''; --  NULL;
    v_sub_request           BOOLEAN := FALSE;
    v_parameter1            VARCHAR2(64) := 'R';
    v_parameter2            VARCHAR2(64) := ''; -- Buyer number
    v_parameter3            VARCHAR2(64) := '1'; -- PO from
    v_parameter4            VARCHAR2(64) := '1'; -- PO from
    v_parameter5            VARCHAR2(64) := '';
    v_parameter6            VARCHAR2(64) := '';
    v_parameter7            VARCHAR2(64) := '';
    v_parameter8            VARCHAR2(64) := '';
    v_parameter9            VARCHAR2(64) := ''; -- approved
    v_parameter10           VARCHAR2(64) := ''; -- test
    v_parameter11           VARCHAR2(64) := 'Y'; -- print release option
    v_parameter12           VARCHAR2(64) := ''; -- sort by
    v_parameter13           VARCHAR2(64) := '46077';
    v_parameter14           VARCHAR2(64) := '2'; -- Fax Enable
    v_parameter15           VARCHAR2(64) := 'N'; -- fax number
    v_parameter16           VARCHAR2(64) := ''; --
    v_parameter17           VARCHAR2(64) := 'Y'; -- print canceled lines
    v_parameter18           VARCHAR2(64) := 'N'; -- print blankets
    v_parameter19           VARCHAR2(64) := 'TTEC'; -- prg
    v_parameter20           VARCHAR2(64) := 'US'; -- prg
    -- v_parameter19             VARCHAR2 (64) := '';
    --  v_parameter20             VARCHAR2 (64) := '';
    v_interval            NUMBER := 30; -- time change to 60
    v_max_wait            NUMBER := 0;
    v_request_phase       VARCHAR2(64);
    v_request_status      VARCHAR2(64);
    v_dev_request_phase   VARCHAR2(64);
    v_dev_request_status  VARCHAR2(64);
    v_request_status_mesg VARCHAR2(64);
    v_call_status         BOOLEAN;
    v_err                 VARCHAR2(64);
   -- v_user_id               NUMBER := 411890;
    v_respon_id             NUMBER := g_respon_id;
    v_respn_appl_id         NUMBER := g_respn_appl_id;
  BEGIN
    fnd_global.apps_initialize(g_user_id, v_respon_id, v_respn_appl_id);
    COMMIT;
    /* submit a request to run */
    v_parameter3 := p_po_number;
    v_parameter4 := p_po_number;
    v_request_id := fnd_request.submit_request(v_application_shrt_name,
                                               v_concprogramshortn,
                                               v_description,
                                               v_start_time,
                                               v_sub_request,
                                               v_parameter1,
                                               v_parameter2,
                                               v_parameter3,
                                               v_parameter4,
                                               v_parameter5,
                                               v_parameter6,
                                               v_parameter7,
                                               v_parameter8,
                                               v_parameter9,
                                               v_parameter10,
                                               v_parameter11,
                                               v_parameter12,
                                               v_parameter13,
                                               v_parameter14,
                                               v_parameter15,
                                               v_parameter16,
                                               v_parameter17,
                                               v_parameter18,
                                               v_parameter19,
                                               v_parameter20);
    COMMIT;
    print_line('Submitted PRG PO print request. Request ID: ' ||
               TO_CHAR(v_request_id) || ' for PO Number: ' || p_po_number);

    IF v_request_id = 0 THEN
      RETURN(0); -- failed request return 0
    END IF;

    /* wait for the concurrent program to complete */
    v_call_status := fnd_concurrent.wait_for_request(v_request_id,
                                                     v_interval,
                                                     v_max_wait,
                                                     v_request_phase,
                                                     v_request_status,
                                                     v_dev_request_phase,
                                                     v_dev_request_status,
                                                     v_request_status_mesg);
    COMMIT;

    IF (v_dev_request_phase = 'COMPLETE' AND
       v_dev_request_status = 'NORMAL') THEN
      RETURN(v_request_id);
    ELSE
      RETURN(v_request_id);  -- version 9.4
      -- RETURN(0);
    END IF;
  EXCEPTION
    WHEN OTHERS THEN
      v_err := SUBSTR(SQLERRM, 1, 50);
      print_line('Error in  ttec_po_run_pdf ' || v_err);
      RETURN(0);
  END ttec_po_run_prg_bel_pdf;

  FUNCTION ttec_po_run_prg_saf_pdf(p_po_number IN VARCHAR2, p_date IN DATE)
    RETURN NUMBER IS
    v_request_id            NUMBER := 0;
    v_application_shrt_name VARCHAR2(20) := 'CUST';
    v_concprogramshortn     VARCHAR2(32) := 'TTEC_PRG_US_PDF_PO';
    v_description           VARCHAR2(64) := 'Graphic PRG Purchase Order';
    v_start_time            VARCHAR2(64) := ''; --  NULL;
    v_sub_request           BOOLEAN := FALSE;
    v_parameter1            VARCHAR2(64) := 'R';
    v_parameter2            VARCHAR2(64) := ''; -- Buyer number
    v_parameter3            VARCHAR2(64) := '1'; -- PO from
    v_parameter4            VARCHAR2(64) := '1'; -- PO from
    v_parameter5            VARCHAR2(64) := '';
    v_parameter6            VARCHAR2(64) := '';
    v_parameter7            VARCHAR2(64) := '';
    v_parameter8            VARCHAR2(64) := '';
    v_parameter9            VARCHAR2(64) := ''; -- approved
    v_parameter10           VARCHAR2(64) := ''; -- test
    v_parameter11           VARCHAR2(64) := 'Y'; -- print release option
    v_parameter12           VARCHAR2(64) := ''; -- sort by
    v_parameter13           VARCHAR2(64) := '46077';
    v_parameter14           VARCHAR2(64) := '2'; -- Fax Enable
    v_parameter15           VARCHAR2(64) := 'N'; -- fax number
    v_parameter16           VARCHAR2(64) := ''; --
    v_parameter17           VARCHAR2(64) := 'Y'; -- print canceled lines
    v_parameter18           VARCHAR2(64) := 'N'; -- print blankets
    v_parameter19           VARCHAR2(64) := 'TTEC'; -- prg
    v_parameter20           VARCHAR2(64) := 'US'; -- prg
    -- v_parameter19             VARCHAR2 (64) := '';
    --  v_parameter20             VARCHAR2 (64) := '';
    v_interval            NUMBER := 30; -- time change to 60
    v_max_wait            NUMBER := 0;
    v_request_phase       VARCHAR2(64);
    v_request_status      VARCHAR2(64);
    v_dev_request_phase   VARCHAR2(64);
    v_dev_request_status  VARCHAR2(64);
    v_request_status_mesg VARCHAR2(64);
    v_call_status         BOOLEAN;
    v_err                 VARCHAR2(64);
   -- v_user_id               NUMBER := 411890;
    v_respon_id             NUMBER := g_respon_id;
    v_respn_appl_id         NUMBER := g_respn_appl_id;
  BEGIN
    fnd_global.apps_initialize(g_user_id, v_respon_id, v_respn_appl_id);
    COMMIT;
    /* submit a request to run */
    v_parameter3 := p_po_number;
    v_parameter4 := p_po_number;
    v_request_id := fnd_request.submit_request(v_application_shrt_name,
                                               v_concprogramshortn,
                                               v_description,
                                               v_start_time,
                                               v_sub_request,
                                               v_parameter1,
                                               v_parameter2,
                                               v_parameter3,
                                               v_parameter4,
                                               v_parameter5,
                                               v_parameter6,
                                               v_parameter7,
                                               v_parameter8,
                                               v_parameter9,
                                               v_parameter10,
                                               v_parameter11,
                                               v_parameter12,
                                               v_parameter13,
                                               v_parameter14,
                                               v_parameter15,
                                               v_parameter16,
                                               v_parameter17,
                                               v_parameter18,
                                               v_parameter19,
                                               v_parameter20);
    COMMIT;
    print_line('Submitted PRG PO print request. Request ID: ' ||
               TO_CHAR(v_request_id) || ' for PO Number: ' || p_po_number);

    IF v_request_id = 0 THEN
      RETURN(0); -- failed request return 0
    END IF;

    /* wait for the concurrent program to complete */
    v_call_status := fnd_concurrent.wait_for_request(v_request_id,
                                                     v_interval,
                                                     v_max_wait,
                                                     v_request_phase,
                                                     v_request_status,
                                                     v_dev_request_phase,
                                                     v_dev_request_status,
                                                     v_request_status_mesg);
    COMMIT;

    IF (v_dev_request_phase = 'COMPLETE' AND
       v_dev_request_status = 'NORMAL') THEN
      RETURN(v_request_id);
    ELSE
      RETURN(v_request_id);  -- version 9.4
      -- RETURN(0);
    END IF;
  EXCEPTION
    WHEN OTHERS THEN
      v_err := SUBSTR(SQLERRM, 1, 50);
      print_line('Error in  ttec_po_run_pdf ' || v_err);
      RETURN(0);
  END ttec_po_run_prg_saf_pdf;

  FUNCTION ttec_po_run_prg_leb_pdf(p_po_number IN VARCHAR2, p_date IN DATE)
    RETURN NUMBER IS
    v_request_id            NUMBER := 0;
    v_application_shrt_name VARCHAR2(20) := 'CUST';
    v_concprogramshortn     VARCHAR2(32) := 'TTEC_PRG_US_PDF_PO';
    v_description           VARCHAR2(64) := 'Graphic PRG Purchase Order';
    v_start_time            VARCHAR2(64) := ''; --  NULL;
    v_sub_request           BOOLEAN := FALSE;
    v_parameter1            VARCHAR2(64) := 'R';
    v_parameter2            VARCHAR2(64) := ''; -- Buyer number
    v_parameter3            VARCHAR2(64) := '1'; -- PO from
    v_parameter4            VARCHAR2(64) := '1'; -- PO from
    v_parameter5            VARCHAR2(64) := '';
    v_parameter6            VARCHAR2(64) := '';
    v_parameter7            VARCHAR2(64) := '';
    v_parameter8            VARCHAR2(64) := '';
    v_parameter9            VARCHAR2(64) := ''; -- approved
    v_parameter10           VARCHAR2(64) := ''; -- test
    v_parameter11           VARCHAR2(64) := 'Y'; -- print release option
    v_parameter12           VARCHAR2(64) := ''; -- sort by
    v_parameter13           VARCHAR2(64) := '46077';
    v_parameter14           VARCHAR2(64) := '2'; -- Fax Enable
    v_parameter15           VARCHAR2(64) := 'N'; -- fax number
    v_parameter16           VARCHAR2(64) := ''; --
    v_parameter17           VARCHAR2(64) := 'Y'; -- print canceled lines
    v_parameter18           VARCHAR2(64) := 'N'; -- print blankets
    v_parameter19           VARCHAR2(64) := 'TTEC'; -- prg
    v_parameter20           VARCHAR2(64) := 'US'; -- prg
    -- v_parameter19             VARCHAR2 (64) := '';
    --  v_parameter20             VARCHAR2 (64) := '';
    v_interval            NUMBER := 30; -- time change to 60
    v_max_wait            NUMBER := 0;
    v_request_phase       VARCHAR2(64);
    v_request_status      VARCHAR2(64);
    v_dev_request_phase   VARCHAR2(64);
    v_dev_request_status  VARCHAR2(64);
    v_request_status_mesg VARCHAR2(64);
    v_call_status         BOOLEAN;
    v_err                 VARCHAR2(64);
   -- v_user_id               NUMBER := 411890;
    v_respon_id             NUMBER := g_respon_id;
    v_respn_appl_id         NUMBER := g_respn_appl_id;
  BEGIN
    fnd_global.apps_initialize(g_user_id, v_respon_id, v_respn_appl_id);
    COMMIT;
    /* submit a request to run */
    v_parameter3 := p_po_number;
    v_parameter4 := p_po_number;
    v_request_id := fnd_request.submit_request(v_application_shrt_name,
                                               v_concprogramshortn,
                                               v_description,
                                               v_start_time,
                                               v_sub_request,
                                               v_parameter1,
                                               v_parameter2,
                                               v_parameter3,
                                               v_parameter4,
                                               v_parameter5,
                                               v_parameter6,
                                               v_parameter7,
                                               v_parameter8,
                                               v_parameter9,
                                               v_parameter10,
                                               v_parameter11,
                                               v_parameter12,
                                               v_parameter13,
                                               v_parameter14,
                                               v_parameter15,
                                               v_parameter16,
                                               v_parameter17,
                                               v_parameter18,
                                               v_parameter19,
                                               v_parameter20);
    COMMIT;
    print_line('Submitted PRG PO print request. Request ID: ' ||
               TO_CHAR(v_request_id) || ' for PO Number: ' || p_po_number);

    IF v_request_id = 0 THEN
      RETURN(0); -- failed request return 0
    END IF;

    /* wait for the concurrent program to complete */
    v_call_status := fnd_concurrent.wait_for_request(v_request_id,
                                                     v_interval,
                                                     v_max_wait,
                                                     v_request_phase,
                                                     v_request_status,
                                                     v_dev_request_phase,
                                                     v_dev_request_status,
                                                     v_request_status_mesg);
    COMMIT;

    IF (v_dev_request_phase = 'COMPLETE' AND
       v_dev_request_status = 'NORMAL') THEN
      RETURN(v_request_id);
    ELSE
      RETURN(v_request_id);  -- version 9.4
      -- RETURN(0);
    END IF;
  EXCEPTION
    WHEN OTHERS THEN
      v_err := SUBSTR(SQLERRM, 1, 50);
      print_line('Error in  ttec_po_run_pdf ' || v_err);
      RETURN(0);
  END ttec_po_run_prg_leb_pdf;

  /*END TTSD R 653870 implementation for Dubai -- Version 5.3 <End>*/

  /*Start 4.2 Changes*/
  FUNCTION ttec_po_run_guidon_pdf(p_po_number IN VARCHAR2, p_date IN DATE)
    RETURN NUMBER IS
    v_request_id            NUMBER := 0;
    v_application_shrt_name VARCHAR2(20) := 'CUST';
    v_concprogramshortn     VARCHAR2(32) := 'TTEC_US_CA_PDF_PO_TTEC_LOGO';
    v_description           VARCHAR2(64) := 'Graphic TTEC US/Canada Purchase Order';
    v_start_time            VARCHAR2(64) := ''; --  NULL;
    v_sub_request           BOOLEAN := FALSE;
    v_parameter1            VARCHAR2(64) := 'R';
    v_parameter2            VARCHAR2(64) := ''; -- Buyer number
    v_parameter3            VARCHAR2(64); -- PO from
    v_parameter4            VARCHAR2(64); -- PO from
    v_parameter5            VARCHAR2(64) := '';
    v_parameter6            VARCHAR2(64) := '';
    v_parameter7            VARCHAR2(64) := '';
    v_parameter8            VARCHAR2(64) := '';
    v_parameter9            VARCHAR2(64) := ''; -- approved
    v_parameter10           VARCHAR2(64) := ''; -- test
    v_parameter11           VARCHAR2(64) := 'Y'; -- print release option
    v_parameter12           VARCHAR2(64) := ''; -- sort by
    v_parameter13           VARCHAR2(64) := '46077';
    v_parameter14           VARCHAR2(64) := '2'; -- Fax Enable
    v_parameter15           VARCHAR2(64) := 'N'; -- fax number
    v_parameter16           VARCHAR2(64) := ''; --
    v_parameter17           VARCHAR2(64) := 'Y'; -- print cancelled lines
    v_parameter18           VARCHAR2(64) := 'N'; -- print blankets
    v_parameter19           VARCHAR2(64) := '';
    v_parameter20           VARCHAR2(64) := '';
    v_interval              NUMBER := 30; -- time change to 60
    v_max_wait              NUMBER := 0;
    v_request_phase         VARCHAR2(64);
    v_request_status        VARCHAR2(64);
    v_dev_request_phase     VARCHAR2(64);
    v_dev_request_status    VARCHAR2(64);
    v_request_status_mesg   VARCHAR2(64);
    v_call_status           BOOLEAN;
    v_err                   VARCHAR2(64);
    v_respon_id             NUMBER :='1013888';-- fnd_global.resp_id;
    v_respn_appl_id         NUMBER := '201'; --fnd_global.resp_appl_id;
  BEGIN
    fnd_global.apps_initialize(g_user_id, v_respon_id, v_respn_appl_id);
    COMMIT;
    /* submit a request to run */
    v_parameter3 := p_po_number;
    v_parameter4 := p_po_number;
    v_request_id := fnd_request.submit_request(v_application_shrt_name,
                                               v_concprogramshortn,
                                               v_description,
                                               v_start_time,
                                               v_sub_request,
                                               v_parameter1,
                                               v_parameter2,
                                               v_parameter3,
                                               v_parameter4,
                                               v_parameter5,
                                               v_parameter6,
                                               v_parameter7,
                                               v_parameter8,
                                               v_parameter9,
                                               v_parameter10,
                                               v_parameter11,
                                               v_parameter12,
                                               v_parameter13,
                                               v_parameter14,
                                               v_parameter15,
                                               v_parameter16,
                                               v_parameter17,
                                               v_parameter18,
                                               v_parameter19,
                                               v_parameter20);
    COMMIT;
    print_line('Submitted Guidon PO print request. Request ID: ' ||
               TO_CHAR(v_request_id) || ' for PO Number: ' || p_po_number);

    IF v_request_id = 0 THEN
      RETURN(0); -- failed request return 0
    END IF;

    /* wait for the concurrent program to complete */
    v_call_status := fnd_concurrent.wait_for_request(v_request_id,
                                                     v_interval,
                                                     v_max_wait,
                                                     v_request_phase,
                                                     v_request_status,
                                                     v_dev_request_phase,
                                                     v_dev_request_status,
                                                     v_request_status_mesg);
    COMMIT;

    IF (v_dev_request_phase = 'COMPLETE' AND
       v_dev_request_status = 'NORMAL') THEN
      RETURN(v_request_id);
    ELSE
      RETURN(v_request_id);  -- version 9.4
      -- RETURN(0);
    END IF;
  EXCEPTION
    WHEN OTHERS THEN
      v_err := SUBSTR(SQLERRM, 1, 50);
      print_line('Error in  ttec_po_run_guidon_pdf ' || v_err);
      RETURN(0);
  END ttec_po_run_guidon_pdf;

  FUNCTION ttec_po_run_iknowtion_pdf(p_po_number IN VARCHAR2,
                                     p_date      IN DATE) RETURN NUMBER IS
    v_request_id            NUMBER := 0;
    v_application_shrt_name VARCHAR2(20) := 'CUST';
    v_concprogramshortn     VARCHAR2(32) := 'TTEC_US_CA_PDF_PO_TTEC_LOGO';
    v_description           VARCHAR2(64) := 'Graphic TTEC US/Canada Purchase Order';
    v_start_time            VARCHAR2(64) := ''; --  NULL;
    v_sub_request           BOOLEAN := FALSE;
    v_parameter1            VARCHAR2(64) := 'R';
    v_parameter2            VARCHAR2(64) := ''; -- Buyer number
    v_parameter3            VARCHAR2(64); -- PO from
    v_parameter4            VARCHAR2(64); -- PO from
    v_parameter5            VARCHAR2(64) := '';
    v_parameter6            VARCHAR2(64) := '';
    v_parameter7            VARCHAR2(64) := '';
    v_parameter8            VARCHAR2(64) := '';
    v_parameter9            VARCHAR2(64) := ''; -- approved
    v_parameter10           VARCHAR2(64) := ''; -- test
    v_parameter11           VARCHAR2(64) := 'Y'; -- print release option
    v_parameter12           VARCHAR2(64) := ''; -- sort by
    v_parameter13           VARCHAR2(64) := '46077';
    v_parameter14           VARCHAR2(64) := '2'; -- Fax Enable
    v_parameter15           VARCHAR2(64) := 'N'; -- fax number
    v_parameter16           VARCHAR2(64) := ''; --
    v_parameter17           VARCHAR2(64) := 'Y'; -- print cancelled lines
    v_parameter18           VARCHAR2(64) := 'N'; -- print blankets
    v_parameter19           VARCHAR2(64) := '';
    v_parameter20           VARCHAR2(64) := '';
    v_interval              NUMBER := 30; -- time change to 60
    v_max_wait              NUMBER := 0;
    v_request_phase         VARCHAR2(64);
    v_request_status        VARCHAR2(64);
    v_dev_request_phase     VARCHAR2(64);
    v_dev_request_status    VARCHAR2(64);
    v_request_status_mesg   VARCHAR2(64);
    v_call_status           BOOLEAN;
    v_err                   VARCHAR2(64);
    v_respon_id             NUMBER := '1013889';--fnd_global.resp_id;
    v_respn_appl_id         NUMBER := '201';--fnd_global.resp_appl_id;
  BEGIN
    fnd_global.apps_initialize(g_user_id, v_respon_id, v_respn_appl_id);
    COMMIT;
    /* submit a request to run */
    v_parameter3 := p_po_number;
    v_parameter4 := p_po_number;
    v_request_id := fnd_request.submit_request(v_application_shrt_name,
                                               v_concprogramshortn,
                                               v_description,
                                               v_start_time,
                                               v_sub_request,
                                               v_parameter1,
                                               v_parameter2,
                                               v_parameter3,
                                               v_parameter4,
                                               v_parameter5,
                                               v_parameter6,
                                               v_parameter7,
                                               v_parameter8,
                                               v_parameter9,
                                               v_parameter10,
                                               v_parameter11,
                                               v_parameter12,
                                               v_parameter13,
                                               v_parameter14,
                                               v_parameter15,
                                               v_parameter16,
                                               v_parameter17,
                                               v_parameter18,
                                               v_parameter19,
                                               v_parameter20);
    COMMIT;
    print_line('Submitted iKnowtion PO print request. Request ID: ' ||
               TO_CHAR(v_request_id) || ' for PO Number: ' || p_po_number);

    IF v_request_id = 0 THEN
      RETURN(0); -- failed request return 0
    END IF;

    /* wait for the concurrent program to complete */
    v_call_status := fnd_concurrent.wait_for_request(v_request_id,
                                                     v_interval,
                                                     v_max_wait,
                                                     v_request_phase,
                                                     v_request_status,
                                                     v_dev_request_phase,
                                                     v_dev_request_status,
                                                     v_request_status_mesg);
    COMMIT;

    IF (v_dev_request_phase = 'COMPLETE' AND
       v_dev_request_status = 'NORMAL') THEN
      RETURN(v_request_id);
    ELSE
      RETURN(v_request_id);  -- version 9.4
      -- RETURN(0);
    END IF;
  EXCEPTION
    WHEN OTHERS THEN
      v_err := SUBSTR(SQLERRM, 1, 50);
      print_line('Error in  ttec_po_run_iknowtion_pdf ' || v_err);
      RETURN(0);
  END ttec_po_run_iknowtion_pdf;
  /*End 4.2 Changes*/

  /*Start 4.3 Changes*/
  FUNCTION ttec_po_run_elt_us_pdf(p_po_number IN VARCHAR2, p_date IN DATE)
    RETURN NUMBER IS
    v_request_id            NUMBER := 0;
    v_application_shrt_name VARCHAR2(20) := 'CUST';
    v_concprogramshortn     VARCHAR2(32) := 'TTEC_ELOYALTY_PDF_PO';
    v_description           VARCHAR2(64) := 'Graphic Teletech eLoyalty Purchase Order';
    v_start_time            VARCHAR2(64) := ''; --  NULL;
    v_sub_request           BOOLEAN := FALSE;
    v_parameter1            VARCHAR2(64) := 'R';
    v_parameter2            VARCHAR2(64) := ''; -- Buyer number
    v_parameter3            VARCHAR2(64); -- PO from
    v_parameter4            VARCHAR2(64); -- PO from
    v_parameter5            VARCHAR2(64) := '';
    v_parameter6            VARCHAR2(64) := '';
    v_parameter7            VARCHAR2(64) := '';
    v_parameter8            VARCHAR2(64) := '';
    v_parameter9            VARCHAR2(64) := ''; -- approved
    v_parameter10           VARCHAR2(64) := ''; -- test
    v_parameter11           VARCHAR2(64) := 'Y'; -- print release option
    v_parameter12           VARCHAR2(64) := ''; -- sort by
    v_parameter13           VARCHAR2(64) := '46077';
    v_parameter14           VARCHAR2(64) := '2'; -- Fax Enable
    v_parameter15           VARCHAR2(64) := 'N'; -- fax number
    v_parameter16           VARCHAR2(64) := ''; --
    v_parameter17           VARCHAR2(64) := 'Y'; -- print cancelled lines
    v_parameter18           VARCHAR2(64) := 'N'; -- print blankets
    v_parameter19           VARCHAR2(64) := '';
    v_parameter20           VARCHAR2(64) := '';
    v_interval              NUMBER := 30; -- time change to 60
    v_max_wait              NUMBER := 0;
    v_request_phase         VARCHAR2(64);
    v_request_status        VARCHAR2(64);
    v_dev_request_phase     VARCHAR2(64);
    v_dev_request_status    VARCHAR2(64);
    v_request_status_mesg   VARCHAR2(64);
    v_call_status           BOOLEAN;
    v_err                   VARCHAR2(64);
    v_respon_id             NUMBER := 1013887;
    v_respn_appl_id         NUMBER := 201;
  BEGIN
    fnd_global.apps_initialize(g_user_id, v_respon_id, v_respn_appl_id);
    COMMIT;
    /* submit a request to run */
    v_parameter3 := p_po_number;
    v_parameter4 := p_po_number;
    v_request_id := fnd_request.submit_request(v_application_shrt_name,
                                               v_concprogramshortn,
                                               v_description,
                                               v_start_time,
                                               v_sub_request,
                                               v_parameter1,
                                               v_parameter2,
                                               v_parameter3,
                                               v_parameter4,
                                               v_parameter5,
                                               v_parameter6,
                                               v_parameter7,
                                               v_parameter8,
                                               v_parameter9,
                                               v_parameter10,
                                               v_parameter11,
                                               v_parameter12,
                                               v_parameter13,
                                               v_parameter14,
                                               v_parameter15,
                                               v_parameter16,
                                               v_parameter17,
                                               v_parameter18,
                                               v_parameter19,
                                               v_parameter20);
    COMMIT;
    print_line('Submitted eLoyalty US PO print request. Request ID: ' ||
               TO_CHAR(v_request_id) || ' for PO Number: ' || p_po_number);

    IF v_request_id = 0 THEN
      RETURN(0); -- failed request return 0
    END IF;

    /* wait for the concurrent program to complete */
    v_call_status := fnd_concurrent.wait_for_request(v_request_id,
                                                     v_interval,
                                                     v_max_wait,
                                                     v_request_phase,
                                                     v_request_status,
                                                     v_dev_request_phase,
                                                     v_dev_request_status,
                                                     v_request_status_mesg);
    COMMIT;

    IF (v_dev_request_phase = 'COMPLETE' AND
       v_dev_request_status = 'NORMAL') THEN
      RETURN(v_request_id);
    ELSE
      RETURN(v_request_id);  -- version 9.4
      -- RETURN(0);
    END IF;
  EXCEPTION
    WHEN OTHERS THEN
      v_err := SUBSTR(SQLERRM, 1, 50);
      print_line('Error in  ttec_po_run_elt_us_pdf ' || v_err);
      RETURN(0);
  END ttec_po_run_elt_us_pdf;

  FUNCTION ttec_po_run_elt_can_pdf(p_po_number IN VARCHAR2, p_date IN DATE)
    RETURN NUMBER IS
    v_request_id            NUMBER := 0;
    v_application_shrt_name VARCHAR2(20) := 'CUST';
    v_concprogramshortn     VARCHAR2(32) := 'TTEC_ELOYALTY_PDF_PO';
    v_description           VARCHAR2(64) := 'Graphic Teletech eLoyalty Purchase Order';
    v_start_time            VARCHAR2(64) := ''; --  NULL;
    v_sub_request           BOOLEAN := FALSE;
    v_parameter1            VARCHAR2(64) := 'R';
    v_parameter2            VARCHAR2(64) := ''; -- Buyer number
    v_parameter3            VARCHAR2(64); -- PO from
    v_parameter4            VARCHAR2(64); -- PO from
    v_parameter5            VARCHAR2(64) := '';
    v_parameter6            VARCHAR2(64) := '';
    v_parameter7            VARCHAR2(64) := '';
    v_parameter8            VARCHAR2(64) := '';
    v_parameter9            VARCHAR2(64) := ''; -- approved
    v_parameter10           VARCHAR2(64) := ''; -- test
    v_parameter11           VARCHAR2(64) := 'Y'; -- print release option
    v_parameter12           VARCHAR2(64) := ''; -- sort by
    v_parameter13           VARCHAR2(64) := '46077';
    v_parameter14           VARCHAR2(64) := '2'; -- Fax Enable
    v_parameter15           VARCHAR2(64) := 'N'; -- fax number
    v_parameter16           VARCHAR2(64) := ''; --
    v_parameter17           VARCHAR2(64) := 'Y'; -- print cancelled lines
    v_parameter18           VARCHAR2(64) := 'N'; -- print blankets
    v_parameter19           VARCHAR2(64) := '';
    v_parameter20           VARCHAR2(64) := '';
    v_interval              NUMBER := 30; -- time change to 60
    v_max_wait              NUMBER := 0;
    v_request_phase         VARCHAR2(64);
    v_request_status        VARCHAR2(64);
    v_dev_request_phase     VARCHAR2(64);
    v_dev_request_status    VARCHAR2(64);
    v_request_status_mesg   VARCHAR2(64);
    v_call_status           BOOLEAN;
    v_err                   VARCHAR2(64);
    v_respon_id             NUMBER := 1013886;
    v_respn_appl_id         NUMBER := 201;
  BEGIN
    fnd_global.apps_initialize(g_user_id, v_respon_id, v_respn_appl_id);
    COMMIT;
    /* submit a request to run */
    v_parameter3 := p_po_number;
    v_parameter4 := p_po_number;
    v_request_id := fnd_request.submit_request(v_application_shrt_name,
                                               v_concprogramshortn,
                                               v_description,
                                               v_start_time,
                                               v_sub_request,
                                               v_parameter1,
                                               v_parameter2,
                                               v_parameter3,
                                               v_parameter4,
                                               v_parameter5,
                                               v_parameter6,
                                               v_parameter7,
                                               v_parameter8,
                                               v_parameter9,
                                               v_parameter10,
                                               v_parameter11,
                                               v_parameter12,
                                               v_parameter13,
                                               v_parameter14,
                                               v_parameter15,
                                               v_parameter16,
                                               v_parameter17,
                                               v_parameter18,
                                               v_parameter19,
                                               v_parameter20);
    COMMIT;
    print_line('Submitted eLoyalty Canada PO print request. Request ID: ' ||
               TO_CHAR(v_request_id) || ' for PO Number: ' || p_po_number);

    IF v_request_id = 0 THEN
      RETURN(0); -- failed request return 0
    END IF;

    /* wait for the concurrent program to complete */
    v_call_status := fnd_concurrent.wait_for_request(v_request_id,
                                                     v_interval,
                                                     v_max_wait,
                                                     v_request_phase,
                                                     v_request_status,
                                                     v_dev_request_phase,
                                                     v_dev_request_status,
                                                     v_request_status_mesg);
    COMMIT;

    IF (v_dev_request_phase = 'COMPLETE' AND
       v_dev_request_status = 'NORMAL') THEN
      RETURN(v_request_id);
    ELSE
      RETURN(v_request_id);  -- version 9.4
      -- RETURN(0);
    END IF;
  EXCEPTION
    WHEN OTHERS THEN
      v_err := SUBSTR(SQLERRM, 1, 50);
      print_line('Error in  ttec_po_run_elt_can_pdf ' || v_err);
      RETURN(0);
  END ttec_po_run_elt_can_pdf;

  FUNCTION ttec_po_run_elt_ire_pdf(p_po_number IN VARCHAR2, p_date IN DATE)
    RETURN NUMBER IS
    v_request_id            NUMBER := 0;
    v_application_shrt_name VARCHAR2(20) := 'CUST';
    v_concprogramshortn     VARCHAR2(32) := 'TTEC_ELOYALTY_PDF_PO';
    v_description           VARCHAR2(64) := 'Graphic Teletech eLoyalty Purchase Order';
    v_start_time            VARCHAR2(64) := ''; --  NULL;
    v_sub_request           BOOLEAN := FALSE;
    v_parameter1            VARCHAR2(64) := 'R';
    v_parameter2            VARCHAR2(64) := ''; -- Buyer number
    v_parameter3            VARCHAR2(64); -- PO from
    v_parameter4            VARCHAR2(64); -- PO from
    v_parameter5            VARCHAR2(64) := '';
    v_parameter6            VARCHAR2(64) := '';
    v_parameter7            VARCHAR2(64) := '';
    v_parameter8            VARCHAR2(64) := '';
    v_parameter9            VARCHAR2(64) := ''; -- approved
    v_parameter10           VARCHAR2(64) := ''; -- test
    v_parameter11           VARCHAR2(64) := 'Y'; -- print release option
    v_parameter12           VARCHAR2(64) := ''; -- sort by
    v_parameter13           VARCHAR2(64) := '46077';
    v_parameter14           VARCHAR2(64) := '2'; -- Fax Enable
    v_parameter15           VARCHAR2(64) := 'N'; -- fax number
    v_parameter16           VARCHAR2(64) := ''; --
    v_parameter17           VARCHAR2(64) := 'Y'; -- print cancelled lines
    v_parameter18           VARCHAR2(64) := 'N'; -- print blankets
    v_parameter19           VARCHAR2(64) := '';
    v_parameter20           VARCHAR2(64) := '';
    v_interval              NUMBER := 30; -- time change to 60
    v_max_wait              NUMBER := 0;
    v_request_phase         VARCHAR2(64);
    v_request_status        VARCHAR2(64);
    v_dev_request_phase     VARCHAR2(64);
    v_dev_request_status    VARCHAR2(64);
    v_request_status_mesg   VARCHAR2(64);
    v_call_status           BOOLEAN;
    v_err                   VARCHAR2(64);
    v_respon_id             NUMBER := 1013885;
    v_respn_appl_id         NUMBER := 201;
  BEGIN
    fnd_global.apps_initialize(g_user_id, v_respon_id, v_respn_appl_id);
    COMMIT;
    /* submit a request to run */
    v_parameter3 := p_po_number;
    v_parameter4 := p_po_number;
    v_request_id := fnd_request.submit_request(v_application_shrt_name,
                                               v_concprogramshortn,
                                               v_description,
                                               v_start_time,
                                               v_sub_request,
                                               v_parameter1,
                                               v_parameter2,
                                               v_parameter3,
                                               v_parameter4,
                                               v_parameter5,
                                               v_parameter6,
                                               v_parameter7,
                                               v_parameter8,
                                               v_parameter9,
                                               v_parameter10,
                                               v_parameter11,
                                               v_parameter12,
                                               v_parameter13,
                                               v_parameter14,
                                               v_parameter15,
                                               v_parameter16,
                                               v_parameter17,
                                               v_parameter18,
                                               v_parameter19,
                                               v_parameter20);
    COMMIT;
    print_line('Submitted eLoyalty Ireland PO print request. Request ID: ' ||
               TO_CHAR(v_request_id) || ' for PO Number: ' || p_po_number);

    IF v_request_id = 0 THEN
      RETURN(0); -- failed request return 0
    END IF;

    /* wait for the concurrent program to complete */
    v_call_status := fnd_concurrent.wait_for_request(v_request_id,
                                                     v_interval,
                                                     v_max_wait,
                                                     v_request_phase,
                                                     v_request_status,
                                                     v_dev_request_phase,
                                                     v_dev_request_status,
                                                     v_request_status_mesg);
    COMMIT;

    IF (v_dev_request_phase = 'COMPLETE' AND
       v_dev_request_status = 'NORMAL') THEN
      RETURN(v_request_id);
    ELSE
      RETURN(v_request_id);  -- version 9.4
      -- RETURN(0);
    END IF;
  EXCEPTION
    WHEN OTHERS THEN
      v_err := SUBSTR(SQLERRM, 1, 50);
      print_line('Error in  ttec_po_run_elt_ire_pdf ' || v_err);
      RETURN(0);
  END ttec_po_run_elt_ire_pdf;
  /*End 4.3 Changes*/

  /* Start 4.6 Changes */
  FUNCTION ttec_po_run_tsg_pdf(p_po_number IN VARCHAR2, p_date IN DATE)
    RETURN NUMBER IS
    v_request_id            NUMBER := 0;
    v_application_shrt_name VARCHAR2(20) := 'CUST';
    v_concprogramshortn     VARCHAR2(32) := 'TTEC_TSG_US_PDF_PO';
    v_description           VARCHAR2(64) := 'Graphic TeleTech TSG Purchase Order'; /* 9.5 */
    v_start_time            VARCHAR2(64) := ''; --  NULL;
    v_sub_request           BOOLEAN := FALSE;
    v_parameter1            VARCHAR2(64) := 'R';
    v_parameter2            VARCHAR2(64) := ''; -- Buyer number
    v_parameter3            VARCHAR2(64); -- PO from
    v_parameter4            VARCHAR2(64); -- PO from
    v_parameter5            VARCHAR2(64) := '';
    v_parameter6            VARCHAR2(64) := '';
    v_parameter7            VARCHAR2(64) := '';
    v_parameter8            VARCHAR2(64) := '';
    v_parameter9            VARCHAR2(64) := ''; -- approved
    v_parameter10           VARCHAR2(64) := ''; -- test
    v_parameter11           VARCHAR2(64) := 'Y'; -- print release option
    v_parameter12           VARCHAR2(64) := ''; -- sort by
    v_parameter13           VARCHAR2(64) := '46077';
    v_parameter14           VARCHAR2(64) := '2'; -- Fax Enable
    v_parameter15           VARCHAR2(64) := 'N'; -- fax number
    v_parameter16           VARCHAR2(64) := ''; --
    v_parameter17           VARCHAR2(64) := 'Y'; -- print cancelled lines
    v_parameter18           VARCHAR2(64) := 'N'; -- print blankets
    v_parameter19           VARCHAR2(64) := '';
    v_parameter20           VARCHAR2(64) := '';
    v_interval              NUMBER := 30; -- time change to 60
    v_max_wait              NUMBER := 0;
    v_request_phase         VARCHAR2(64);
    v_request_status        VARCHAR2(64);
    v_dev_request_phase     VARCHAR2(64);
    v_dev_request_status    VARCHAR2(64);
    v_request_status_mesg   VARCHAR2(64);
    v_call_status           BOOLEAN;
    v_err                   VARCHAR2(64);
    v_respon_id             NUMBER := 1014364;  --TSG PO Super User
    v_respn_appl_id         NUMBER := 201;
  BEGIN
    fnd_global.apps_initialize(g_user_id, v_respon_id, v_respn_appl_id);
    COMMIT;
    /* submit a request to run */
    v_parameter3 := p_po_number;
    v_parameter4 := p_po_number;
    v_request_id := fnd_request.submit_request(v_application_shrt_name,
                                               v_concprogramshortn,
                                               v_description,
                                               v_start_time,
                                               v_sub_request,
                                               v_parameter1,
                                               v_parameter2,
                                               v_parameter3,
                                               v_parameter4,
                                               v_parameter5,
                                               v_parameter6,
                                               v_parameter7,
                                               v_parameter8,
                                               v_parameter9,
                                               v_parameter10,
                                               v_parameter11,
                                               v_parameter12,
                                               v_parameter13,
                                               v_parameter14,
                                               v_parameter15,
                                               v_parameter16,
                                               v_parameter17,
                                               v_parameter18,
                                               v_parameter19,
                                               v_parameter20);
    COMMIT;
    print_line('Submitted TSG PO print request. Request ID: ' ||
               TO_CHAR(v_request_id) || ' for PO Number: ' || p_po_number);

    IF v_request_id = 0 THEN
      RETURN(0); -- failed request return 0
    END IF;

    /* wait for the concurrent program to complete */
    v_call_status := fnd_concurrent.wait_for_request(v_request_id,
                                                     v_interval,
                                                     v_max_wait,
                                                     v_request_phase,
                                                     v_request_status,
                                                     v_dev_request_phase,
                                                     v_dev_request_status,
                                                     v_request_status_mesg);
    COMMIT;

    IF (v_dev_request_phase = 'COMPLETE' AND
       v_dev_request_status = 'NORMAL') THEN
      RETURN(v_request_id);
    ELSE
      RETURN(v_request_id);  -- version 9.4
      -- RETURN(0);
    END IF;
  EXCEPTION
    WHEN OTHERS THEN
      v_err := SUBSTR(SQLERRM, 1, 50);
      print_line('Error in  ttec_po_run_tsg_pdf ' || v_err);
      RETURN(0);
  END ttec_po_run_tsg_pdf;
  /*End 4.6 Changes*/

  /* Start of 4.8 Changes */
  FUNCTION ttec_po_run_prg_turkey_pdf(p_po_number IN VARCHAR2, p_date IN DATE)
    RETURN NUMBER IS
    v_request_id            NUMBER := 0;
    v_application_shrt_name VARCHAR2(20) := 'CUST';
    v_concprogramshortn     VARCHAR2(32) := 'TTEC_PRG_US_PDF_PO';
    v_description           VARCHAR2(64) := 'Graphic PRG Purchase Order';
    v_start_time            VARCHAR2(64) := ''; --  NULL;
    v_sub_request           BOOLEAN := FALSE;
    v_parameter1            VARCHAR2(64) := 'R';
    v_parameter2            VARCHAR2(64) := ''; -- Buyer number
    v_parameter3            VARCHAR2(64) := '1'; -- PO from
    v_parameter4            VARCHAR2(64) := '1'; -- PO from
    v_parameter5            VARCHAR2(64) := '';
    v_parameter6            VARCHAR2(64) := '';
    v_parameter7            VARCHAR2(64) := '';
    v_parameter8            VARCHAR2(64) := '';
    v_parameter9            VARCHAR2(64) := ''; -- approved
    v_parameter10           VARCHAR2(64) := ''; -- test
    v_parameter11           VARCHAR2(64) := 'Y'; -- print release option
    v_parameter12           VARCHAR2(64) := ''; -- sort by
    v_parameter13           VARCHAR2(64) := '46077';
    v_parameter14           VARCHAR2(64) := '2'; -- Fax Enable
    v_parameter15           VARCHAR2(64) := 'N'; -- fax number
    v_parameter16           VARCHAR2(64) := ''; --
    v_parameter17           VARCHAR2(64) := 'Y'; -- print canceled lines
    v_parameter18           VARCHAR2(64) := 'N'; -- print blankets
    v_parameter19           VARCHAR2(64) := 'TTEC'; -- prg
    v_parameter20           VARCHAR2(64) := 'US'; -- prg
    -- v_parameter19             VARCHAR2 (64) := '';
    -- v_parameter20             VARCHAR2 (64) := '';
    v_interval            NUMBER := 30; -- time change to 60
    v_max_wait            NUMBER := 0;
    v_request_phase       VARCHAR2(64);
    v_request_status      VARCHAR2(64);
    v_dev_request_phase   VARCHAR2(64);
    v_dev_request_status  VARCHAR2(64);
    v_request_status_mesg VARCHAR2(64);
    v_call_status         BOOLEAN;
    v_err                 VARCHAR2(64);
   -- v_user_id               NUMBER := 411890;
    v_respon_id             NUMBER := g_respon_id;
    v_respn_appl_id         NUMBER := g_respn_appl_id;
  BEGIN
    fnd_global.apps_initialize(g_user_id, v_respon_id, v_respn_appl_id);
    COMMIT;
    /* submit a request to run */
    v_parameter3 := p_po_number;
    v_parameter4 := p_po_number;
    v_request_id := fnd_request.submit_request(v_application_shrt_name,
                                               v_concprogramshortn,
                                               v_description,
                                               v_start_time,
                                               v_sub_request,
                                               v_parameter1,
                                               v_parameter2,
                                               v_parameter3,
                                               v_parameter4,
                                               v_parameter5,
                                               v_parameter6,
                                               v_parameter7,
                                               v_parameter8,
                                               v_parameter9,
                                               v_parameter10,
                                               v_parameter11,
                                               v_parameter12,
                                               v_parameter13,
                                               v_parameter14,
                                               v_parameter15,
                                               v_parameter16,
                                               v_parameter17,
                                               v_parameter18,
                                               v_parameter19,
                                               v_parameter20);
    COMMIT;
    print_line('Submitted PRG Turkey PO print request. Request ID: ' ||
               TO_CHAR(v_request_id) || ' for PO Number: ' || p_po_number);

    IF v_request_id = 0 THEN
      RETURN(0); -- failed request return 0
    END IF;

    /* wait for the concurrent program to complete */
    v_call_status := fnd_concurrent.wait_for_request(v_request_id,
                                                     v_interval,
                                                     v_max_wait,
                                                     v_request_phase,
                                                     v_request_status,
                                                     v_dev_request_phase,
                                                     v_dev_request_status,
                                                     v_request_status_mesg);
    COMMIT;

    IF (v_dev_request_phase = 'COMPLETE' AND
       v_dev_request_status = 'NORMAL') THEN
      RETURN(v_request_id);
    ELSE
      RETURN(v_request_id);  -- version 9.4
      -- RETURN(0);
    END IF;
  EXCEPTION
    WHEN OTHERS THEN
      v_err := SUBSTR(SQLERRM, 1, 50);
      print_line('Error in  ttec_po_run_prg_turkey_pdf ' || v_err);
      RETURN(0);
  END ttec_po_run_prg_turkey_pdf;
  /* End of 4.8 Changes */

  /* Start of 8.2 Changes */
  FUNCTION ttec_po_run_prg_bulgaria_pdf(p_po_number IN VARCHAR2, p_date IN DATE)
    RETURN NUMBER IS
    v_request_id            NUMBER := 0;
    v_application_shrt_name VARCHAR2(20) := 'CUST';
    v_concprogramshortn     VARCHAR2(32) := 'TTEC_SOF_BGR_PO_PDF'; -- TTEC_SOF_BGR_PO_PDF / TTEC_PRG_US_PDF_PO
    v_description           VARCHAR2(64) := 'Graphic Sofica Bulgaria Purchase Order'; -- Graphic Sofica Bulgaria Purchase Order / Graphic PRG Purchase Order
    v_start_time            VARCHAR2(64) := ''; --  NULL;
    v_sub_request           BOOLEAN := FALSE;
    v_parameter1            VARCHAR2(64) := 'R';
    v_parameter2            VARCHAR2(64) := ''; -- Buyer number
    v_parameter3            VARCHAR2(64) := '1'; -- PO from
    v_parameter4            VARCHAR2(64) := '1'; -- PO from
    v_parameter5            VARCHAR2(64) := '';
    v_parameter6            VARCHAR2(64) := '';
    v_parameter7            VARCHAR2(64) := '';
    v_parameter8            VARCHAR2(64) := '';
    v_parameter9            VARCHAR2(64) := ''; -- approved
    v_parameter10           VARCHAR2(64) := ''; -- test
    v_parameter11           VARCHAR2(64) := 'Y'; -- print release option
    v_parameter12           VARCHAR2(64) := ''; -- sort by
    v_parameter13           VARCHAR2(64) := '400386';
    v_parameter14           VARCHAR2(64) := '2'; -- Fax Enable
    v_parameter15           VARCHAR2(64) := 'N'; -- fax number
    v_parameter16           VARCHAR2(64) := ''; --
    v_parameter17           VARCHAR2(64) := 'Y'; -- print canceled lines
    v_parameter18           VARCHAR2(64) := 'N'; -- print blankets
    v_parameter19           VARCHAR2(64) := 'TTEC'; -- prg
    v_parameter20           VARCHAR2(64) := 'US'; -- prg
    -- v_parameter19             VARCHAR2 (64) := '';
    -- v_parameter20             VARCHAR2 (64) := '';
    v_interval            NUMBER := 30; -- time change to 60
    v_max_wait            NUMBER := 0;
    v_request_phase       VARCHAR2(64);
    v_request_status      VARCHAR2(64);
    v_dev_request_phase   VARCHAR2(64);
    v_dev_request_status  VARCHAR2(64);
    v_request_status_mesg VARCHAR2(64);
    v_call_status         BOOLEAN;
    v_err                 VARCHAR2(64);
   -- v_user_id               NUMBER := 411890;
    v_respon_id             NUMBER := g_respon_id;
    v_respn_appl_id         NUMBER := g_respn_appl_id;
  BEGIN
    fnd_global.apps_initialize(g_user_id, v_respon_id, v_respn_appl_id);
    COMMIT;
    /* submit a request to run */
    v_parameter3 := p_po_number;
    v_parameter4 := p_po_number;
    v_request_id := fnd_request.submit_request(v_application_shrt_name,
                                               v_concprogramshortn,
                                               v_description,
                                               v_start_time,
                                               v_sub_request,
                                               v_parameter1,
                                               v_parameter2,
                                               v_parameter3,
                                               v_parameter4,
                                               v_parameter5,
                                               v_parameter6,
                                               v_parameter7,
                                               v_parameter8,
                                               v_parameter9,
                                               v_parameter10,
                                               v_parameter11,
                                               v_parameter12,
                                               v_parameter13,
                                               v_parameter14,
                                               v_parameter15,
                                               v_parameter16,
                                               v_parameter17,
                                               v_parameter18,
                                               v_parameter19,
                                               v_parameter20);
    COMMIT;
    print_line('Submitted TELETECH_BULGARIA_OU PO print request. Request ID: ' ||
               TO_CHAR(v_request_id) || ' for PO Number: ' || p_po_number);

    IF v_request_id = 0 THEN
      RETURN(0); -- failed request return 0
    END IF;

    /* wait for the concurrent program to complete */
    v_call_status := fnd_concurrent.wait_for_request(v_request_id,
                                                     v_interval,
                                                     v_max_wait,
                                                     v_request_phase,
                                                     v_request_status,
                                                     v_dev_request_phase,
                                                     v_dev_request_status,
                                                     v_request_status_mesg);
    COMMIT;

    IF (v_dev_request_phase = 'COMPLETE' AND
       v_dev_request_status = 'NORMAL') THEN
      RETURN(v_request_id);
    ELSE
      RETURN(v_request_id);  -- version 9.4
      -- RETURN(0);
    END IF;
  EXCEPTION
    WHEN OTHERS THEN
      v_err := SUBSTR(SQLERRM, 1, 50);
      print_line('Error in  ttec_po_run_prg_bulgaria_pdf' || v_err);
      RETURN(0);
  END ttec_po_run_prg_bulgaria_pdf;
  /* End of 8.2 Changes */

/* 12.3     Begin */
FUNCTION ttec_po_run_ind_pdf(p_po_number IN VARCHAR2,
                                     p_date      IN DATE) RETURN NUMBER IS
    v_request_id            NUMBER := 0;
    v_application_shrt_name VARCHAR2(20) := 'CUST';

    v_concprogramshortn     VARCHAR2(32) := 'TTEC_GLOBAL_PDF_PO_BRANDINGIND';
    v_description           VARCHAR2(64) := 'Graphic TTEC Global Purchase Order India';
    v_start_time            VARCHAR2(64) := ''; --  NULL;
    v_sub_request           BOOLEAN := FALSE;
    v_parameter1            VARCHAR2(64) := 'R';
    v_parameter2            VARCHAR2(64) := ''; -- Buyer number
    v_parameter3            VARCHAR2(64) := '680000'; -- PO from
    v_parameter4            VARCHAR2(64) := '680000'; -- PO from
    v_parameter5            VARCHAR2(64) := '';
    v_parameter6            VARCHAR2(64) := '';
    v_parameter7            VARCHAR2(64) := '';
    v_parameter8            VARCHAR2(64) := '';
    v_parameter9            VARCHAR2(64) := ''; -- approved
    v_parameter10           VARCHAR2(64) := ''; -- test
    v_parameter11           VARCHAR2(64) := 'Y'; -- print release option
    v_parameter12           VARCHAR2(64) := ''; -- sort by
    v_parameter13           VARCHAR2(64) := '46077';
    v_parameter14           VARCHAR2(64) := '2'; -- Fax Enable
    v_parameter15           VARCHAR2(64) := 'N'; -- fax number
    v_parameter16           VARCHAR2(64) := ''; --
    v_parameter17           VARCHAR2(64) := 'Y'; -- print canceled lines
    v_parameter18           VARCHAR2(64) := 'N'; -- print blankets
    v_parameter19           VARCHAR2(64) := '';
    v_parameter20           VARCHAR2(64) := '';
    v_interval              NUMBER := 30; -- time change to 60
    v_max_wait              NUMBER := 0;
    v_request_phase         VARCHAR2(64);
    v_request_status        VARCHAR2(64);
    v_dev_request_phase     VARCHAR2(64);
    v_dev_request_status    VARCHAR2(64);
    v_request_status_mesg   VARCHAR2(64);
    v_call_status           BOOLEAN;
    v_err                   VARCHAR2(64);
   -- v_user_id               NUMBER := 411890;
    v_respon_id             NUMBER := g_respon_id;
    v_respn_appl_id         NUMBER := g_respn_appl_id;
  BEGIN
    fnd_global.apps_initialize(g_user_id, v_respon_id, v_respn_appl_id);
    COMMIT;
    /* submit a request to run */
    v_parameter3 := p_po_number;
    v_parameter4 := p_po_number;
    v_request_id := fnd_request.submit_request(v_application_shrt_name,
                                               v_concprogramshortn,
                                               v_description,
                                               v_start_time,
                                               v_sub_request,
                                               v_parameter1,
                                               v_parameter2,
                                               v_parameter3,
                                               v_parameter4,
                                               v_parameter5,
                                               v_parameter6,
                                               v_parameter7,
                                               v_parameter8,
                                               v_parameter9,
                                               v_parameter10,
                                               v_parameter11,
                                               v_parameter12,
                                               v_parameter13,
                                               v_parameter14,
                                               v_parameter15,
                                               v_parameter16,
                                               v_parameter17,
                                               v_parameter18,
                                               v_parameter19,
                                               v_parameter20);
    COMMIT;
    print_line('Submitted Graphic TTEC Global Purchase Order India. Request ID: ' ||
               TO_CHAR(v_request_id) || ' for PO Number: ' || p_po_number);

    IF v_request_id = 0 THEN
      RETURN(0); -- failed request return 0
    END IF;

    /* wait for the concurrent program to complete */
    v_call_status := fnd_concurrent.wait_for_request(v_request_id,
                                                     v_interval,
                                                     v_max_wait,
                                                     v_request_phase,
                                                     v_request_status,
                                                     v_dev_request_phase,
                                                     v_dev_request_status,
                                                     v_request_status_mesg);
    COMMIT;

    IF (v_dev_request_phase = 'COMPLETE' AND
       v_dev_request_status = 'NORMAL') THEN
      RETURN(v_request_id);
    ELSE
      RETURN(v_request_id);
      -- RETURN(0);
    END IF;
  EXCEPTION
    WHEN OTHERS THEN
      v_err := SUBSTR(SQLERRM, 1, 50);
      print_line('Error in  TTEC_GLOBAL_PDF_PO_BRANDINGIND ' || v_err);
      RETURN(0);
  END ttec_po_run_ind_pdf;
/* 12.3     End */

   FUNCTION ttec_copy_file(p_in_dir        IN VARCHAR2,
                           p_file_name_in  IN VARCHAR2,
                           p_out_dir       IN VARCHAR2,
                           p_file_name_out IN VARCHAR2,
                           p_stat          IN NUMBER) /* 10.4 */
    RETURN NUMBER IS

    l_filedir VARCHAR2(256);

    v_stat NUMBER := p_stat; /* 10.4 */

  BEGIN
    UTL_FILE.fcopy(src_location  => p_in_dir,
                   src_filename  => p_file_name_in,
                   dest_location => p_out_dir,
                   dest_filename => p_file_name_out);

    RETURN v_stat; /* 10.4 */

  EXCEPTION
    WHEN UTL_FILE.invalid_path THEN
      print_line('File Copy Error - Invalid Path');
      v_stat := -1;  /* 10.4 */
      RETURN v_stat; /* 10.4 */
    WHEN UTL_FILE.invalid_operation THEN
      print_line('File Copy Error - Invalid Operation');
      v_stat := -1;  /* 10.4 */
      RETURN v_stat; /* 10.4 */
    WHEN UTL_FILE.invalid_mode THEN
      print_line('File Copy Error - Invalid Mode');
      v_stat := -1;  /* 10.4 */
      RETURN v_stat; /* 10.4 */
    WHEN UTL_FILE.read_error THEN
      print_line('File Copy Error - Read Error');
      v_stat := -1;  /* 10.4 */
      RETURN v_stat; /* 10.4 */
    WHEN UTL_FILE.write_error THEN
      print_line('File Copy Error - Write Error');
      v_stat := -1;  /* 10.4 */
      RETURN v_stat; /* 10.4 */
    WHEN OTHERS THEN
      print_line('Error in module ttec_copy_file File Copy Error - ' || '|' ||
                 SQLCODE || '|' || SUBSTR(SQLERRM, 1, 80));
      NULL;
      v_stat := -1;  /* 10.4 */
      RETURN v_stat; /* 10.4 */
  END ttec_copy_file;

  /* SEND EMAIL  THAT THERE IS NO VENDOR EMAIL */
  /* hold down error from email v_stat for time being */
  FUNCTION ttec_send_no_vendor_email(p_po_number         IN VARCHAR2,
                                     p_org_id            IN NUMBER,
                                     p_file_name_out     IN VARCHAR2,
                                     p_vendor_name       IN VARCHAR2,
                                     p_vendor_site_email IN VARCHAR2,
                                     p_requester_name    IN VARCHAR2,
                                     p_requester_email   IN VARCHAR2,
                                     p_buyer_email       IN VARCHAR2,
                                     p_vendor_fax        IN VARCHAR2)
    RETURN NUMBER IS
    v_email_to       VARCHAR2(256);
    v_email_from     VARCHAR2(256);
    v_subject        VARCHAR2(256) := 'PO Not Emailed. PO Number: ';
    v_body           VARCHAR2(5000);
    v_sep            VARCHAR2(8) := ',';
    v_file_name      VARCHAR2(256);
    v_stat           NUMBER;
    v_preparer_email VARCHAR2(256) DEFAULT NULL;
  BEGIN
    BEGIN
      --- 4.0
      apps.fnd_file.put_line(apps.fnd_file.LOG, 'Stage2');
      v_preparer_email := NULL;

      SELECT DISTINCT pap.email_address
        INTO v_preparer_email
        FROM apps.po_distributions_all       pda,
             apps.po_headers_all             pha,
             apps.po_req_distributions_all   prd,
             apps.po_requisition_lines_all   prl,
             apps.po_requisition_headers_all prh,
             apps.per_all_people_f           pap,
             apps.po_lines_all               pla,
             apps.ap_suppliers               sup
       WHERE pda.po_header_id = pha.po_header_id
         AND pda.po_header_id = pla.po_header_id
         AND pda.po_line_id = pla.po_line_id
         AND pda.req_distribution_id = prd.distribution_id
         AND prd.requisition_line_id = prl.requisition_line_id
         AND prl.requisition_header_id = prh.requisition_header_id
         AND prh.preparer_id = pap.person_id
         AND pha.segment1 = p_po_number
         AND pha.org_id = p_org_id
         AND pha.vendor_id = sup.vendor_id
         AND TO_DATE(pha.creation_date) BETWEEN pap.effective_start_date AND
             pap.effective_end_date;
    EXCEPTION
      WHEN NO_DATA_FOUND THEN
        v_preparer_email := NULL;
      WHEN TOO_MANY_ROWS THEN
        v_preparer_email := NULL;
      WHEN OTHERS THEN
        v_preparer_email := NULL;
    END; --- 3.9

    apps.fnd_file.put_line(apps.fnd_file.LOG,
                           'Preparer Email1:' || v_preparer_email);
     --v_email_to := 'atul.vishwakarma2@cognizant.com'|| ';'||'atulvishwakarma@teletech.com'; -- 'MarkSchoenenberger@teletech.com';


    v_email_to   := REPLACE(p_requester_email || v_sep || p_buyer_email ||
                            v_sep || g_pur_dept_email || v_sep ||
                            v_preparer_email,
                            ';',
                            ',');
    v_email_to   := REPLACE(v_email_to, ',,', ',');
    v_email_from := g_from_email;
    v_subject    := v_subject || p_po_number;
    v_body       := 'This PO has not been emailed to vendor, Organization not incorporated, or  PO failed to print.  Please  Contact Purchasing Department.  Vendor Name: ' ||
                    p_vendor_name || g_crlf || g_test_emails;
    -- 1.1 -- ADDED emails at the bottom of the msg body for test instances
    v_file_name := NULL; -- in case we want to send furture instruction file
    v_stat      := ttec_email_out_file(v_email_to,
                                       v_email_from,
                                       v_file_name,
                                       g_test_instance || v_subject, -- 1.1
                                       v_body);

    IF v_stat > 0 THEN
      print_line('Error sending email to ' || v_email_to || '|' || SQLCODE || '|' ||
                 SUBSTR(SQLERRM, 1, 80));
      -- let it return zero
    END IF;

    RETURN(0);
  END ttec_send_no_vendor_email;

  /* Build Final email */
  FUNCTION ttec_build_send_po_email(p_po_number         IN VARCHAR2,
                                    p_org_id            IN NUMBER,
                                    p_file_name_out     IN VARCHAR2,
                                    p_vendor_name       IN VARCHAR2,
                                    p_vendor_site_email IN OUT VARCHAR2,
                                    p_requester_name    IN VARCHAR2,
                                    p_requester_email   IN OUT VARCHAR2,
                                    p_buyer_email       IN OUT VARCHAR2,
                                    p_vendor_fax        IN VARCHAR2)
    RETURN NUMBER IS
    v_email_to       VARCHAR2(500);
    v_email_from     VARCHAR2(256);
    v_subject        VARCHAR2(256) := 'TeleTech Purchase Order Number: ';
    v_body           VARCHAR2(1024);
    v_sep            VARCHAR2(8) := ',';
    v_file_name      VARCHAR2(256);
    v_stat           NUMBER;
    v_stat_email     NUMBER := 0;
    v_last_comma     NUMBER := 0;
    v_email1         VARCHAR2(256) DEFAULT NULL;
    v_email2         VARCHAR2(256) DEFAULT NULL;
    v_email3         VARCHAR2(256) DEFAULT NULL;
    v_preparer_email VARCHAR2(256) DEFAULT NULL;
  BEGIN
    BEGIN
      --- 3.9
      apps.fnd_file.put_line(apps.fnd_file.LOG, 'Stage1');
      v_email1 := NULL;
      v_email2 := NULL;
      v_email3 := NULL;

      SELECT site.attribute1, site.attribute2, site.attribute3
        INTO v_email1, v_email2, v_email3
        FROM ap_suppliers          sup,
             ap_supplier_sites_all site,
             po_headers_all        ph
       WHERE UPPER(p_vendor_name) = (sup.vendor_name)
         AND site.attribute_category = 'Email'
         AND ph.segment1 = p_po_number
         AND ph.vendor_id = sup.vendor_id
         AND ph.vendor_site_id = site.vendor_site_id
         AND ph.org_id = site.org_id;
    EXCEPTION
      WHEN NO_DATA_FOUND THEN
        v_email1 := NULL;
        v_email2 := NULL;
        v_email3 := NULL;
      WHEN TOO_MANY_ROWS THEN
        v_email1 := NULL;
        v_email2 := NULL;
        v_email3 := NULL;
      WHEN OTHERS THEN
        v_email1 := NULL;
        v_email2 := NULL;
        v_email3 := NULL;
    END; --- 3.9

    apps.fnd_file.put_line(apps.fnd_file.LOG,
                           'Email1:' || v_email1 || 'Email1:' || v_email2);

    BEGIN
      --- 4.0
      apps.fnd_file.put_line(apps.fnd_file.LOG, 'Stage2');
      v_preparer_email := NULL;

      SELECT DISTINCT pap.email_address
        INTO v_preparer_email
        FROM apps.po_distributions_all       pda,
             apps.po_headers_all             pha,
             apps.po_req_distributions_all   prd,
             apps.po_requisition_lines_all   prl,
             apps.po_requisition_headers_all prh,
             apps.per_all_people_f           pap,
             apps.po_lines_all               pla,
             apps.ap_suppliers               sup
       WHERE pda.po_header_id = pha.po_header_id
         AND pda.po_header_id = pla.po_header_id
         AND pda.po_line_id = pla.po_line_id
         AND pda.req_distribution_id = prd.distribution_id
         AND prd.requisition_line_id = prl.requisition_line_id
         AND prl.requisition_header_id = prh.requisition_header_id
         AND prh.preparer_id = pap.person_id
         AND pha.segment1 = p_po_number
         AND pha.org_id = p_org_id
         AND pha.vendor_id = sup.vendor_id
         AND TO_DATE(pha.creation_date) BETWEEN pap.effective_start_date AND
             pap.effective_end_date;
    EXCEPTION
      WHEN NO_DATA_FOUND THEN
        v_preparer_email := NULL;
      WHEN TOO_MANY_ROWS THEN
        v_preparer_email := NULL;
      WHEN OTHERS THEN
        v_preparer_email := NULL;
    END; --- 3.9

    apps.fnd_file.put_line(apps.fnd_file.LOG,
                           'Preparer Email1:' || v_preparer_email);

    IF p_vendor_site_email IS NULL OR (LENGTH(p_vendor_site_email) < 5) THEN
      p_vendor_site_email := '';
      v_stat_email        := 1;
    END IF;

    IF p_requester_email IS NULL OR (LENGTH(p_requester_email) < 5) THEN
      p_requester_email := '';
      v_stat_email      := 2;
    END IF;

    IF p_buyer_email IS NULL OR (LENGTH(p_buyer_email) < 5) THEN
      p_buyer_email := '';
      v_stat_email  := 3;
    END IF;

    --3.9
    IF v_email1 IS NULL OR (LENGTH(v_email1) < 5) THEN
      v_email1     := '';
      v_stat_email := 5;
    END IF;

    IF v_email2 IS NULL OR (LENGTH(v_email2) < 5) THEN
      v_email2     := '';
      v_stat_email := 6;
    END IF;

    IF v_email3 IS NULL OR (LENGTH(v_email3) < 5) THEN
      v_email3     := '';
      v_stat_email := 7;
    END IF; -- 3.9

    IF v_preparer_email IS NULL OR (LENGTH(v_preparer_email) < 5) THEN
      v_preparer_email := '';
      v_stat_email     := 8;
    END IF;

    IF (p_vendor_site_email IS NULL OR (LENGTH(p_vendor_site_email) < 5)) AND
       (p_requester_email IS NULL OR (LENGTH(p_requester_email) < 5)) -- 1.0 --Added Parenthesis for Operator's precedence
     THEN
      p_vendor_site_email := '';
      p_requester_email   := '';
      v_stat_email        := 4;
      --v_subject := v_subject || p_po_number;
    END IF;

--     v_email_to :=
--       'atul.vishwakarma2@cognizant.com'
--    || ','
--    || 'atulvishwakarma@teletech.com'
--    || ','
--    || v_preparer_email;

    IF g_test_instance IS NOT NULL THEN
        v_email1 := '';
        v_email2 := '';
        v_email3 := '';
        v_preparer_email    := '';
    END IF;


    v_email_to := REPLACE(p_requester_email || v_sep || p_buyer_email ||
                          v_sep || p_vendor_site_email || v_sep || v_email1 ||
                          v_sep || v_email2 || v_sep || v_email3 || v_sep ||
                          v_preparer_email || v_sep || g_pur_dept_email,
                          ';',
                          ',');
--  apps.fnd_file.put_line(apps.fnd_file.LOG, 'Final_Email:' || v_email_to);
--  v_email_to := 'amiraslam@teletech.com';


    apps.fnd_file.put_line(apps.fnd_file.LOG, 'Final_Email:' || v_email_to);
    v_email_to   := REPLACE(v_email_to, ',,', ',');
    v_email_from := g_from_email;
    print_line('Sending PO ' || p_po_number || ' To email list: ' ||
               v_email_to);
    print_line(' ');
    g_body_main := g_body_main || g_crlf || g_test_emails;
    -- 1.1 -- ADDED emails at the bottom of the msg body for test instances
    v_subject := v_subject || p_po_number;

    IF v_stat_email = 1 THEN
      v_subject   := 'Missing Email Recipient ' || v_subject;
      g_body_main := g_email_not_sent || p_vendor_name || g_crlf ||
                     g_body_main;
    END IF;

    IF v_stat_email = 4 THEN
      v_subject   := 'Missing Email Recipient ' || v_subject;
      g_body_main := g_email_not_sent || p_vendor_name || g_crlf ||
                     g_body_main;
    END IF;

    --  v_body := 'Hello';
    v_file_name := p_file_name_out;
    v_stat      := ttec_email_out_file(v_email_to,
                                       v_email_from,
                                       v_file_name,
                                       g_test_instance || v_subject, -- 1.1
                                       g_body_main);

    IF v_stat > 0 THEN
      print_line('Error sending email ' || v_email_to || '|' || SQLCODE || '|' ||
                 SUBSTR(SQLERRM, 1, 80));
      -- send email to coporate purchasing, so they at leas have a record
      v_stat := ttec_email_out_file(g_pur_dept_email,
                                    v_email_from,
                                    v_file_name,
                                    g_test_instance || 'NOT SENT' ||
                                    v_subject,
                                    -- 1.1
                                    g_body_main);
      -- let it return zero
    END IF;

    RETURN(0);
  END ttec_build_send_po_email;

/* 12.6 Begin */
   PROCEDURE send_PO_email_ERROR(v_email_recipients IN varchar2,
                                                                           v_po_number          IN varchar2,
                                                                           v_error_msg            IN varchar2) IS
      l_email_from                VARCHAR2 (256)
                                     := '@ttec.com';
      l_email_to                  VARCHAR2 (256) := v_email_recipients;
      l_email_dir                 VARCHAR2 (256) := NULL;
      l_email_subj              VARCHAR2 (256) :=  'ALERT ALERT! Notice from TTEC_PO_EMAIL failure. Please refer to email body for failure details !!!!!  ';
      l_email_body1          VARCHAR2 (256)  := 'Global Procurement/Oracle ERP Support,';
      l_email_body2          VARCHAR2 (256)  := substr(' Automated email cannot be processed on PO Number: ' || v_po_number||' Due to >>'||v_error_msg,1,256) ;
      l_email_body3           VARCHAR2 (256) := 'Please review the reported ERROR and take necessary action(s) to ensure the PO is delivered to the vendor without any delay. SYSTEM Error Time >>> '||to_char(SYSDATE,'DD-MON-YYYY HH24:MI:SS');
      l_email_body4           VARCHAR2 (256) := 'If you have any questions, please contact Global Procurement and/or Oracle ERP Support';
      crlf                               CHAR (2) := CHR (10) || CHR (13);
      w_mesg                      VARCHAR2 (256);
      p_status                    NUMBER;

    BEGIN

                 IF g_host_name <> ttec_library.XX_TTEC_PROD_HOST_NAME THEN
                        l_email_subj := g_host_name|| '  '|| g_db_instance||' TESTING!! Please ignore... '||l_email_subj;
                 END IF;


                  send_email (
                     ttec_library.XX_TTEC_SMTP_SERVER, /*l_host_name,*/
                     g_db_instance||l_email_from,
                     l_email_to,
                     NULL,
                     NULL,
                     l_email_subj,
                        crlf
                     || l_email_body1
                     || crlf
                     || l_email_body2
                     || crlf
                     || l_email_body3
                     || crlf
                     || l_email_body4,
                     NULL,
                     NULL,
                     NULL,
                     NULL,
                     NULL,
                     NULL,
                     NULL,
                     NULL,
                     NULL,
                     p_status,
                     w_mesg);
    END send_PO_email_ERROR;
   /* 12.6 End*/

  PROCEDURE main(errbuf OUT VARCHAR2, retcode OUT NUMBER,
                   rerun_date                     IN DATE,
                   rerun_range_flag         IN VARCHAR2, /* 12.7 */
                   rerun_date_time_from IN VARCHAR2, /* 12.7 */
                   rerun_date_time_to      IN VARCHAR2 /* 12.7 */
                   ) IS
    v_stat       NUMBER;
    v_request_id NUMBER;
    --2.0 Stores request id after graphic geneartion.
    v_filedir           VARCHAR2(256);
    v_file_name         VARCHAR2(256);
    v_file_request      VARCHAR2(256);
    v_file_name_out     VARCHAR2(256);
    v_file_name_pdf     VARCHAR2(256);
    /*
	START R12.2 Upgrade Remediation
	code commented by RXNETHI-ARGANO,12/05/23
	v_po_number         po.po_headers_all.segment1%TYPE;
    v_po_approved       po.po_headers_all.approved_flag%TYPE;
    v_po_approve_date   po.po_headers_all.approved_date%TYPE;
    v_org_id            po.po_headers_all.org_id%TYPE;
    v_requester_name    hr.per_all_people_f.full_name%TYPE;
    v_requester_email   hr.per_all_people_f.email_address%TYPE;
    v_buyer_email       hr.per_all_people_f.email_address%TYPE;
    v_buyer_name        hr.per_all_people_f.full_name%TYPE;
	*/
	--code added by RXNETHI-ARGANO,12/05/23
	v_po_number         apps.po_headers_all.segment1%TYPE;
    v_po_approved       apps.po_headers_all.approved_flag%TYPE;
    v_po_approve_date   apps.po_headers_all.approved_date%TYPE;
    v_org_id            apps.po_headers_all.org_id%TYPE;
    v_requester_name    apps.per_all_people_f.full_name%TYPE;
    v_requester_email   apps.per_all_people_f.email_address%TYPE;
    v_buyer_email       apps.per_all_people_f.email_address%TYPE;
    v_buyer_name        apps.per_all_people_f.full_name%TYPE;
	--END R12.2 Upgrade Remediation
    v_vendor_site_email ap_supplier_sites_all.email_address%TYPE;
    -- V3.7 po.po_vendor_sites_all
    v_vendor_name ap_suppliers.vendor_name%TYPE;
    -- V3.7 po.po_vendors
    v_vendor_site ap_supplier_sites_all.vendor_site_code%TYPE;
    -- V3.7 po.po_vendor_sites_all
    v_vendor_fax   VARCHAR2(64);
    v_stat2        NUMBER;
    v_stat3        NUMBER; /* 10.4 */
    v_stat4        NUMBER; /* 10.4 */
    v_run_update   BOOLEAN := FALSE;
    v_stat_v_email NUMBER := 0;
    v_po_status    CHAR := NULL;
    --  2.0 Status of the po
    v_pur_dept_email_aux VARCHAR2(64) := g_pur_dept_email;
    -- 1.1 retain purchasing department information for TEST instances.
    v_from_email_aux VARCHAR2(64) := g_from_email;
    -- 4.2 Changes
    v_org_name hr_operating_units.name%TYPE;
    v_status     VARCHAR2(256):=NULL;
    v_mesg       VARCHAR2(256):=NULL;
    v_dummy  VARCHAR2(1):=NULL; /* 12.7 */

  BEGIN
    print_line('TeleTech - PO Email Automatic  ');
    print_line('Start time:' || SYSDATE);
    print_line('Rerun Date:' || rerun_date);
    fnd_profile.get('USER_ID', g_user_id);
    g_error_step := 'Step 1: Getting Host Name';

    OPEN c_host; -- 1.1 --get host name

    FETCH c_host
      INTO g_host_name, g_db_instance;

    CLOSE c_host;

    g_error_step := 'Step 2: Checking instance';
/*  -- commented for Ver 5.0
    IF LOWER(g_host_name) = 'den-erp046' OR
       LOWER(g_host_name) = 'den-erp044' THEN
      -- 1.1 check instance
      g_test_instance := NULL;
    ELSE
      g_test_instance := 'TEST - ' || UPPER(g_host_name) || ' - ';
    END IF;
*/
    -- Added for Ver 5.0
    IF LOWER(g_host_name) = ttec_library.XX_TTEC_PROD_HOST_NAME
       -- OR LOWER(g_host_name) = ttec_library.XX_TTEC_PREPROD_HOST_NAME
    THEN
      -- 1.1 check instance
      g_test_instance := NULL;
    ELSE
      g_test_instance := 'TEST - ' || UPPER(g_host_name) || ' - ';
    END IF;



    g_error_step          := 'Step 3: Getting directory Path';
    g_request_default_dir := g_request_default_dir; -- Version 3.0
    --      OPEN c_directory_path;

    --      FETCH c_directory_path
    --       INTO g_request_default_dir;

    --      CLOSE c_directory_path;

       /* 12.7 begin */
         print_line('Step 3.5: Run Date Time Validation rerun_range_flag->'||rerun_range_flag);
         print_line('Step 3.5: Run Date Time Validation rerun_date_time_from ->'||rerun_date_time_from);
         print_line('Step 3.5: Run Date Time Validation rerun_date_time_to ->'||rerun_date_time_to);
    g_error_step := 'Step 3.5: Run Date Time Validation';
    IF rerun_range_flag = 'Yes' THEN
         print_line('Came to Rerun_range is YES->'||rerun_date_time_to);
         print_line('Step 3.5: Run Date Time Validation rerun_range_flag->'||rerun_range_flag);
         print_line('Step 3.5: Run Date Time Validation rerun_date_time_from ->'||rerun_date_time_from);
         print_line('Step 3.5: Run Date Time Validation rerun_date_time_to ->'||rerun_date_time_to);
      BEGIN
            SELECT 1
            INTO v_dummy
            FROM DUAL
            WHERE TO_DATE(TO_CHAR(rerun_date_time_from ),'DD-MON-YYYY HH24:MI:SS')  <= TO_DATE(TO_CHAR( rerun_date_time_to ),'DD-MON-YYYY HH24:MI:SS');

              print_line('After from dual->'||rerun_date_time_to);
      EXCEPTION
       WHEN OTHERS
      THEN
       print_line('came to Exception invalid Rerun Date Time From'||rerun_date_time_to);
        RAISE_APPLICATION_ERROR(-20000,'Exception invalid Rerun Date Time From ' ||g_error_step||' >>>[' ||rerun_date_time_from||'] must be <= ['|| rerun_date_time_to||']');
      END;
   END IF;
     /* 12.7 end*/

    g_error_step := 'Step 4: Getting last run date';





    IF g_db_instance = 'PROD' THEN /* 12.1 */

        OPEN c_last_run;

        FETCH c_last_run
          INTO g_last_run_date;

        CLOSE c_last_run;

    ELSE /* 12.1 Added Begin */

        IF rerun_date IS NULL
        THEN
            SELECT DECODE(apps.TTEC_GET_INSTANCE,--INSTANCE_NAME -- changes made as part of 12.4
            'PROD', TRUNC(SYSDATE),TRUNC(startup_time) - 2) last_run_date -- To avoid creating new PO to test overall OU
            INTO  g_last_run_date
            FROM v$instance;
        ELSE
            g_last_run_date:= to_date(rerun_date);

        END IF;

        g_file_prename  := 'TT'||g_db_instance ||'_PO_'; -- To fix the copy file permission on PO already printed in PROD into Temp directory

    END IF; /* 12.1 Added End*/

    g_error_step := 'Step 4.5: Getting temp directory path';
    g_temp_dir   := g_temp_dir || '/data/temp'; -- Version 3.0

    --      OPEN c_temp_dir_path;
    --      FETCH c_temp_dir_path
    --        INTO g_temp_dir;
    --      CLOSE c_temp_dir_path;


    -- use this to test only     g_last_run_date := NULL;
    IF g_last_run_date IS NULL THEN
      print_line('No Previous run found - last_run date is set to SYSDATE');
      g_last_run_date := SYSDATE;
    END IF;

    print_line('last_run date is ' ||
               TO_CHAR(g_last_run_date, 'DD-MM-YYYY HH24:MI:SS'));
    g_error_step := 'Step 5: Entering main LOOP';

    /* pick all the PO's found. Print them and email them */
    FOR sel IN c_get_po_info(g_last_run_date, rerun_range_flag,rerun_date_time_from,rerun_date_time_to) LOOP /* 12.7 */
      v_stat        := 0;
      v_stat2       := 0; /* 10.4 */
      v_stat3       := 0; /* 10.4 */
      v_stat4       := 0; /* 10.4 */
      v_request_id := 0;
      -- 2.0 Added to retain request id after PDF generation
      v_po_number         := NULL;
      v_po_approved       := NULL;
      v_po_approve_date   := NULL;
      v_org_id            := NULL;
      v_requester_name    := NULL;
      v_requester_email   := NULL;
      v_vendor_site_email := NULL;
      v_vendor_name       := NULL;
      v_vendor_site       := NULL;
      v_vendor_fax        := NULL;
      v_buyer_email       := NULL;
      v_buyer_name        := NULL;
      v_stat_v_email      := 0;
      v_po_status         := NULL;
      v_po_number         := sel.l_po_num;
      v_po_approved       := sel.l_po_approved;
      v_po_approve_date   := sel.l_po_approve_date;
      v_org_id            := sel.l_org_id;
      v_requester_name    := sel.l_requester_name;
      v_vendor_name       := sel.l_vendor_name;
      v_vendor_site       := sel.l_vendor_site;
      v_vendor_fax        := sel.l_vendor_site;
      v_buyer_name        := sel.l_buyer_name;
      g_error_step        := 'Step 5.1: Setting status according to PO';

      IF sel.l_revision_num > 0 THEN
        -- Approved vs changed POs  -- 2.0
        v_po_status := 'R';
      ELSE
        v_po_status := 'A';
      END IF;

      IF sel.l_cancel_flag IS NOT NULL AND sel.l_cancel_flag = 'Y' THEN
        -- Cancelled POs  -- 2.0
        v_po_status := 'C';
      END IF;

      g_error_step := 'Step 5.2: Seting emailing list in DEV enviroment';

      IF g_test_instance IS NULL THEN
        -- 1.1 -- IF PROD THEN real emails else WF Mailer
        v_requester_email   := sel.l_requester_email;
        v_vendor_site_email := sel.l_vendor_site_email;
        v_buyer_email       := sel.l_buyer_email;
      ELSE
        g_test_emails       := ''; -- 1.1 -- Reset global variables in loop
        g_pur_dept_email    := v_pur_dept_email_aux;
        g_from_email        := v_from_email_aux;
        v_requester_email   := sel.l_requester_email;

        v_vendor_site_email := sel.l_vendor_site_email;
        --v_vendor_site_email := 'AtulVishwakarma@teletech.com';

        v_buyer_email       := sel.l_buyer_email;
        print_line('Vendor Email Before Change:' || v_vendor_site_email);
        print_line('Requester Email Before change:' || v_requester_email);
        print_line('Buyer Email Before Change:' || v_buyer_email);

        IF sel.l_requester_email IS NULL OR
           (LENGTH(sel.l_requester_email) < 5) THEN
          v_requester_email := '';
        ELSE
          g_test_emails     := g_test_emails || 'Requester: ' ||
                               sel.l_requester_email || g_crlf;
          v_requester_email := 'wfmailtesting@TTEC.com'; --'MailerTesting@teletech.com'; /* 10.7 */
        END IF;

        IF sel.l_vendor_site_email IS NULL OR
           (LENGTH(sel.l_vendor_site_email) < 5) THEN
          v_vendor_site_email := '';
        ELSE
          g_test_emails       := g_test_emails || 'Vendor: ' ||
                                 sel.l_vendor_site_email || g_crlf;

          v_vendor_site_email := 'wfmailtesting@TTEC.com';--'MailerTesting@teletech.com'; /* 10.7 */
           -- v_vendor_site_email := 'AtulVishwakarma@teletech.com';

        END IF;

        IF sel.l_buyer_email IS NULL OR (LENGTH(sel.l_buyer_email) < 5) THEN
          v_buyer_email := '';
        ELSE
          g_test_emails := g_test_emails || 'Buyer: ' || sel.l_buyer_email ||
                           g_crlf;
          v_buyer_email := 'wfmailtesting@TTEC.com';--'MailerTesting@teletech.com'; /* 10.7 */
        END IF;

        g_test_emails    := 'THIS EMAILS WILL BE SHOWN FOR NON PRODUCTION INSTANCES ONLY: ' ||
                            g_crlf || g_test_emails || 'Purchasing: ' ||
                            g_pur_dept_email || g_crlf;
        g_test_emails    := REPLACE(g_test_emails, ';', ',');
        g_test_emails    := REPLACE(g_test_emails, ',,', ',');


        g_pur_dept_email := 'wfmailtesting@TTEC.com'; --'MailerTesting@teletech.com'; /* 10.7 */


        g_from_email     := 'TEST_CorporatePurchasing@TeleTech.com';
      END IF;

      print_line(' ');
      print_line('Processing PO :' || v_po_number);
      print_line('Vendor Name :' || v_vendor_name);
      print_line('Vendor Email :' || v_vendor_site_email);
      print_line('Requester Email :' || v_requester_email);
      print_line('Buyer Email :' || v_buyer_email);
      v_stat_v_email := 0;

      /* simple test of valid email */
      IF v_vendor_site_email IS NULL OR (LENGTH(v_vendor_site_email) < 5) THEN
        v_stat_v_email := 1;
        print_line('Invalid/Missing email address found for vendor ' ||
                   v_vendor_name);
      END IF;

      g_error_step := 'Step 5.3: Generating PDF and emails according to org_id: ' ||
                      TO_CHAR(v_org_id);

--    select UPPER(name)
--      into g_operating_unit_name
--      from hr_operating_units
--     where organization_id = v_org_id;

    SELECT   frv.RESPONSIBILITY_ID, frv.APPLICATION_ID,UPPER(hou.NAME), ood.ORGANIZATION_CODE,--,frv.responsibility_name, fpov.profile_option_value org_id,
             flv.description, flv.tag  /* 12.0.0 */
       INTO g_respon_id, g_respn_appl_id, g_operating_unit_name, g_organization_code,
            g_po_run_type, g_TC_attachment_filename /* 12.0.2 */
        FROM apps.fnd_lookup_values_vl flv, /* 12.0.0 */
             apps.hr_organization_units hou,
             apps.org_organization_definitions ood,
             apps.fnd_profile_options_vl fpo,
             apps.fnd_profile_option_values fpov,
             apps.fnd_responsibility_vl frv
       WHERE flv.lookup_type = 'TTEC_PO_EMAIL_OU_ROLLOUT'     /* 12.0.0 */
         AND to_number(flv.LOOKUP_CODE) = hou.ORGANIZATION_ID /* 12.0.0 */
         AND ood.ORGANIZATION_ID = hou.ORGANIZATION_ID /* 12.0.0 */
         AND (flv.view_application_id = 201)                  /* 12.0.0 */
         AND (flv.security_group_id = 0)                      /* 12.0.0 */
         AND trunc(SYSDATE) BETWEEN flv.start_date_active and NVL(flv.end_date_active,to_date('31-DEC-4712'))
         AND frv.responsibility_name like '%PO Super User%' /* 10.1 Motif does not have Modified Super User */
         AND fpov.level_value = frv.responsibility_id
         AND fpo.profile_option_id = fpov.profile_option_id
         AND fpo.user_profile_option_name = 'MO: Operating Unit'
         AND fpov.profile_option_id = fpo.profile_option_id
         and fpov.profile_option_value = to_char(v_org_id)
         AND hou.organization_id =  v_org_id
         AND ROWNUM < 2;

      /*  Case includes call to functions to generate emails version 2.0 */
      -- 12.0 Driven by OU inclusion under PO Super user Purchasing Lookup Type -> 'TTEC_PO_EMAIL_OU_ROLLOUT'
      CASE g_po_run_type /* 12.0 */
        WHEN 'ttec_po_run_global_pdf' -- TTUS 101, TTUK 161, TTAU 265, RogSi-AU 36893,
         THEN

          v_stat       := ttec_po_run_global_pdf(v_po_number, SYSDATE);
          v_request_id := v_stat;
          v_stat       := ttec_po_email_global_gen(v_po_number,
                                               v_vendor_name,
                                               v_requester_name,
                                               v_po_status,
                                               v_stat);
        WHEN 'ttec_po_run_global_pdf_am_notc' --  Morroco /* 12.1 */
         THEN

          v_stat       := ttec_po_run_global_pdf_am_notc(v_po_number, SYSDATE);
          v_request_id := v_stat;
          v_stat       := ttec_po_email_global_gen(v_po_number,
                                               v_vendor_name,
                                               v_requester_name,
                                               v_po_status,
                                               v_stat);

        WHEN 'ttec_po_run_global_pdf_fcr' --  First Call Resolution US Logo /* 12.2 */
         THEN

          v_stat       := ttec_po_run_global_pdf_fcr(v_po_number, SYSDATE);
          v_request_id := v_stat;
          v_stat       := ttec_po_email_global_gen(v_po_number,
                                               v_vendor_name,
                                               v_requester_name,
                                               v_po_status,
                                               v_stat);

        WHEN 'ttec_po_run_pcp_ca_pdf' --142 -- Percepta Canada
         THEN
          v_stat       := ttec_po_run_pcp_ca_pdf(v_po_number, SYSDATE);
          v_request_id := v_stat;
          v_stat       := ttec_po_email_us_gen(v_po_number,
                                               v_vendor_name,
                                               v_requester_name,
                                               v_po_status,
                                               v_stat);

        WHEN 'ttec_po_run_pcp_uk_pdf' --181 -- Percepta UK
         THEN
          v_stat       := ttec_po_run_pcp_uk_pdf(v_po_number, SYSDATE);
          v_request_id := v_stat;
          v_stat       := ttec_po_email_us_gen(v_po_number,
                                               v_vendor_name,
                                               v_requester_name,
                                               v_po_status,
                                               v_stat);

        WHEN 'ttec_po_run_global_latam_pdf' -- Mexico
         THEN
          v_stat       := ttec_po_run_global_latam_pdf(v_po_number, SYSDATE);
          v_request_id := v_stat;
          v_stat       := ttec_po_email_latam_gen(v_po_number,
                                                  v_vendor_name,
                                                  v_requester_name,
                                                  v_po_status,
                                                  v_stat);
        WHEN 'ttec_po_run_mxb_pdf' -- Mexico Bajio
         THEN
          v_stat       := ttec_po_run_mxb_pdf(v_po_number, SYSDATE);
          v_request_id := v_stat;
          v_stat       := ttec_po_email_mx_gen(v_po_number,
                                               v_vendor_name,
                                               v_requester_name,
                                               v_po_status,
                                               v_stat);

        WHEN 'ttec_po_run_mxs_pdf' -- Mexico SSI
         THEN
          v_stat       := ttec_po_run_mxs_pdf(v_po_number, SYSDATE);
          v_request_id := v_stat;
          v_stat       := ttec_po_email_mx_gen(v_po_number,
                                               v_vendor_name,
                                               v_requester_name,
                                               v_po_status,
                                               v_stat);

        WHEN 'ttec_po_run_rogenchn_pd' --43782 -- RogenSi-China      -- Changed for Ver 9.0
         THEN
          v_stat       := ttec_po_run_rogenchn_pdf(v_po_number, SYSDATE);
          v_request_id := v_stat;
          v_stat       := ttec_po_email_us_gen(v_po_number,
                                               v_vendor_name,
                                               v_requester_name,
                                               v_po_status,
                                               v_stat);

        WHEN 'ttec_po_run_sgp_pdf' --1441 -- Singapore
         THEN
          v_stat       := ttec_po_run_sgp_pdf(v_po_number, SYSDATE);
          v_request_id := v_stat;
          v_stat       := ttec_po_email_us_gen(v_po_number,
                                               v_vendor_name,
                                               v_requester_name,
                                               v_po_status,
                                               v_stat);

        WHEN 'ttec_po_run_phl_pdf' --1462 -- Philippines
         THEN
          v_stat       := ttec_po_run_phl_pdf(v_po_number, SYSDATE);
          v_request_id := v_stat;
          v_stat       := ttec_po_email_phl_gen(v_po_number,
                                                v_vendor_name,
                                                v_requester_name,
                                                v_po_status,
                                                v_stat);

        WHEN 'ttec_po_run_global_ptb_pdf' --1476 -- BRZ
         THEN
          v_stat       := ttec_po_run_global_ptb_pdf(v_po_number, SYSDATE); /* 10. 0 */
          v_request_id := v_stat;                                           /* 10. 0 */
          v_stat       := ttec_po_email_ptb_gen(v_po_number,                /* 10. 0 */
                                                v_vendor_name,
                                                v_requester_name,
                                                v_po_status,
                                                v_stat);

        WHEN 'ttec_po_run_hkg_pdf' --1488 THEN
         THEN
          v_stat       := ttec_po_run_hkg_pdf(v_po_number, SYSDATE);
          v_request_id := v_stat;
          v_stat       := ttec_po_email_us_gen(v_po_number,
                                               v_vendor_name,
                                               v_requester_name,
                                               v_po_status,
                                               v_stat);

        WHEN 'ttec_po_run_phl_br_pdf' --16899 --Philippines Branch v3.6
         THEN
          v_stat       := ttec_po_run_phl_br_pdf(v_po_number, SYSDATE);
          v_request_id := v_stat;
          v_stat       := ttec_po_email_phl_gen(v_po_number,
                                                v_vendor_name,
                                                v_requester_name,
                                                v_po_status,
                                                v_stat); --Philippines Branch v3.6 <End>
        WHEN 'ttec_po_run_phl_rohq_pdf' --19435 --Philippines ROHQ
         THEN
          v_stat       := ttec_po_run_phl_rohq_pdf(v_po_number, SYSDATE);
          v_request_id := v_stat;
          v_stat       := ttec_po_email_phl_gen(v_po_number,
                                                v_vendor_name,
                                                v_requester_name,
                                                v_po_status,
                                                v_stat); --Philippines ROHQ
        WHEN 'ttec_po_run_phl_motif_pdf' --48458 --Motif Philippines /* 10.1 */
         THEN
          v_stat       := ttec_po_run_phl_motif_pdf(v_po_number, SYSDATE);
          v_request_id := v_stat;
          v_stat       := ttec_po_email_phl_gen(v_po_number,
                                                v_vendor_name,
                                                v_requester_name,
                                                v_po_status,
                                                v_stat); --Motif Philippines /* 10.1 */

        WHEN 'ttec_po_run_ttec_cnstg_bel_pd' --17579 -- TT prg belgium
         THEN
          v_stat       := ttec_po_run_ttec_cnstg_bel_pdf(v_po_number, SYSDATE); /* 9.1 */
          v_request_id := v_stat;
          v_stat       := ttec_po_email_ttec_cnstg_gen(v_po_number, /* 9.1 */
                                                      v_vendor_name,
                                                      v_requester_name,
                                                      v_po_status,
                                                      v_stat);

        WHEN 'ttec_po_run_prg_dubai_pdf' --16740 -- PRG Dubai
         THEN
          v_stat       := ttec_po_run_prg_dubai_pdf(v_po_number, SYSDATE);
          v_request_id := v_stat;
          v_stat       := ttec_po_email_prg_nonus_gen(v_po_number,
                                                      v_vendor_name,
                                                      v_requester_name,
                                                      v_po_status,
                                                      v_stat); -- Version 5.3 <End>

        WHEN 'ttec_po_run_prg_saf_pdf' --16738 -- TT PRG SAF
         THEN
          v_stat       := ttec_po_run_prg_saf_pdf(v_po_number, SYSDATE);
          v_request_id := v_stat;
          v_stat       := ttec_po_email_prg_nonus_gen(v_po_number,
                                                      v_vendor_name,
                                                      v_requester_name,
                                                      v_po_status,
                                                      v_stat);
        WHEN 'ttec_po_run_prg_leb_pdf' --17580 -- TT PRG lebenon
         THEN
          v_stat       := ttec_po_run_prg_leb_pdf(v_po_number, SYSDATE);
          v_request_id := v_stat;
          v_stat       := ttec_po_email_prg_nonus_gen(v_po_number,
                                                      v_vendor_name,
                                                      v_requester_name,
                                                      v_po_status,
                                                      v_stat);

        WHEN 'ttec_po_run_prg_turkey_pdf' --17599  ----PRG TURKEY
         THEN
          v_stat       := ttec_po_run_prg_turkey_pdf(v_po_number, SYSDATE);
          v_request_id := v_stat;
          v_stat       := ttec_po_email_prg_nonus_gen(v_po_number,
                                                      v_vendor_name,
                                                      v_requester_name,
                                                      v_po_status,
                                                      v_stat);

        WHEN 'ttec_po_run_ind_pdf' --48618  ----TTEC INDIA /*12.3 */
         THEN
          v_stat       := ttec_po_run_ind_pdf(v_po_number, SYSDATE);
          v_request_id := v_stat;
          v_stat       := ttec_po_email_global_gen(v_po_number,
                                                   v_vendor_name,
                                                   v_requester_name,
                                                   v_po_status,
                                                   v_stat);

      ELSE
         send_email(ttec_library.XX_TTEC_SMTP_SERVER, /* Rehosting project change for smtp */
               --g_host_name,
               'EBS_Development@ttec.com',
               'wfmailtesting@ttec.com, ERPDevelopment@ttec.com, oraclefinancialssupport@ttec.com',
               NULL,
               NULL,
               'ALERT ALERT FROM '||g_db_instance ||' !!! Function is missing in TTEC_PO_EMAIL ->' ||g_po_run_type, -- v_subject,
               'New Entry was added to LOOKUP -> TTEC_PO_EMAIL_OU_ROLLOUT for '||g_operating_unit_name ||' Please notify ERP Development to Add new function',
               NULL,
               NULL,
               NULL,
               NULL,
               NULL, --l_filename_tc, --p_file_name, -- v_file_name,
               NULL, --l_tc_filename, /* 12.0.2 */ --NULL,
               NULL,
               NULL,
               NULL,
               v_status,
               v_mesg);

         print_line('Success sending email PO process status '|| to_char(v_status) ||' '|| v_mesg);

        IF v_status > 0 THEN
          print_line('Error sending email PO process status ' || '|' || SQLCODE || '|' ||
                     SUBSTR(SQLERRM, 1, 80));
        END IF;
      END CASE;

--      /*  Case includes call to functions to generate emails version 2.0 */
--      -- based on org id of the PO print it by the country program
--      CASE v_org_id
--      /* 9.7 commented out begin */
--        WHEN 101 -- US /* 9.8 uncommented out */
--         THEN          /* 9.8 uncommented out */

--          v_stat       := ttec_po_run_global_pdf(v_po_number, SYSDATE);   /* 9.8  */
--          v_request_id := v_stat;                                         /* 9.8  */
--          v_stat       := ttec_po_email_global_gen(v_po_number,           /* 9.8  */
--                                               v_vendor_name,
--                                               v_requester_name,
--                                               v_po_status,
--                                               v_stat);

--          --            WHEN 121                                          -- Percepta US
--      --            THEN v_stat := ttec_po_run_pcp_us_pdf (v_po_number, SYSDATE);
--        WHEN 141 -- Canada
--         THEN
--          v_stat       := ttec_po_run_can_pdf(v_po_number, SYSDATE); --2.2
--          v_request_id := v_stat;
--          v_stat       := ttec_po_email_us_gen(v_po_number,
--                                               v_vendor_name,
--                                               v_requester_name,
--                                               v_po_status,
--                                               v_stat);
--        WHEN 142 -- Percepta Canada
--         THEN
--          v_stat       := ttec_po_run_pcp_ca_pdf(v_po_number, SYSDATE);
--          v_request_id := v_stat;
--          v_stat       := ttec_po_email_us_gen(v_po_number,
--                                               v_vendor_name,
--                                               v_requester_name,
--                                               v_po_status,
--                                               v_stat);
--        WHEN 161 -- UK  /* 9.8 uncommented out */
--         THEN           /* 9.8 uncommented out */
--          v_stat       := ttec_po_run_global_pdf(v_po_number, SYSDATE);   /* 9.8  */
--          v_request_id := v_stat;                                         /* 9.8  */
--          v_stat       := ttec_po_email_global_gen(v_po_number,           /* 9.8  */
--                                               v_vendor_name,
--                                               v_requester_name,
--                                               v_po_status,
--                                               v_stat);
--        WHEN 181 -- Percepta UK
--         THEN
--          v_stat       := ttec_po_run_pcp_uk_pdf(v_po_number, SYSDATE);
--          v_request_id := v_stat;
--          v_stat       := ttec_po_email_us_gen(v_po_number,
--                                               v_vendor_name,
--                                               v_requester_name,
--                                               v_po_status,
--                                               v_stat);
--        WHEN 261 -- Mexico
--         THEN
--          v_stat       := ttec_po_run_global_latam_pdf(v_po_number, SYSDATE); /* 10.6 */
--          v_request_id := v_stat;                                             /* 10.6 */
--          v_stat       := ttec_po_email_latam_gen(v_po_number,                /* 10.6 */
--                                                  v_vendor_name,
--                                                  v_requester_name,
--                                                  v_po_status,
--                                                  v_stat);
--        WHEN 10466 -- Mexico Bajio
--         THEN
--          v_stat       := ttec_po_run_mxb_pdf(v_po_number, SYSDATE);
--          v_request_id := v_stat;
--          v_stat       := ttec_po_email_mx_gen(v_po_number,
--                                               v_vendor_name,
--                                               v_requester_name,
--                                               v_po_status,
--                                               v_stat);
--        WHEN 10465 -- Mexico SSI
--         THEN
--          v_stat       := ttec_po_run_mxs_pdf(v_po_number, SYSDATE);
--          v_request_id := v_stat;
--          v_stat       := ttec_po_email_mx_gen(v_po_number,
--                                               v_vendor_name,
--                                               v_requester_name,
--                                               v_po_status,
--                                               v_stat);
--        WHEN 265 -- AUS
--         THEN
--          v_stat       := ttec_po_run_global_pdf(v_po_number, SYSDATE);   /* 9.8  */
--          v_request_id := v_stat;                                         /* 9.8  */
--          v_stat       := ttec_po_email_global_gen(v_po_number,           /* 9.8  */
--                                               v_vendor_name,
--                                               v_requester_name,
--                                               v_po_status,
--                                               v_stat);

--        WHEN 36893 -- RogenSi-AUS       -- Changed for Ver 7.0
--         THEN
--          v_stat       := ttec_po_run_global_pdf(v_po_number, SYSDATE);   /* 10.0 */
--          v_request_id := v_stat;                                         /* 10.0 */
--          v_stat       := ttec_po_email_global_gen(v_po_number,           /* 10.0 */
--                                               v_vendor_name,
--                                               v_requester_name,
--                                               v_po_status,
--                                               v_stat);

--        WHEN 36453 -- RogenSi-UK       -- Changed for Ver 7.0 /* 9.8 uncommented out */
--         THEN    /* 9.8 uncommented out */
--          v_stat       := ttec_po_run_global_pdf(v_po_number, SYSDATE);   /* 9.8  */
--          v_request_id := v_stat;                                         /* 9.8  */
--          v_stat       := ttec_po_email_global_gen(v_po_number,           /* 9.8  */
--                                               v_vendor_name,
--                                               v_requester_name,
--                                               v_po_status,
--                                               v_stat);

--        WHEN 43782 -- RogenSi-China      -- Changed for Ver 9.0
--         THEN
--          v_stat       := ttec_po_run_rogenchn_pdf(v_po_number, SYSDATE);
--          v_request_id := v_stat;
--          v_stat       := ttec_po_email_us_gen(v_po_number,
--                                               v_vendor_name,
--                                               v_requester_name,
--                                               v_po_status,
--                                               v_stat);

--        WHEN 45364-- Atelka Canada    -- Changed for Ver 9.2 /* 9.8 uncommented out */
--         THEN     /* 9.8 uncommented out */
--          v_stat       := ttec_po_run_global_pdf(v_po_number, SYSDATE);   /* 9.8  */
--          v_request_id := v_stat;                                         /* 9.8  */
--          v_stat       := ttec_po_email_global_gen(v_po_number,           /* 9.8  */
--                                               v_vendor_name,
--                                               v_requester_name,
--                                               v_po_status,
--                                               v_stat);

--        WHEN 1366 -- New Zealand   /* 9.8 uncommented out */
--         THEN  /* 9.8 uncommented out */
--          v_stat       := ttec_po_run_global_pdf(v_po_number, SYSDATE);   /* 9.8  */
--          v_request_id := v_stat;                                         /* 9.8  */
--          v_stat       := ttec_po_email_global_gen(v_po_number,           /* 9.8  */
--                                               v_vendor_name,
--                                               v_requester_name,
--                                               v_po_status,
--                                               v_stat);

--        WHEN 1411 -- US government solutions  /* 9.8 uncommented out */
--         THEN     /* 9.8 uncommented out */
--          v_stat       := ttec_po_run_global_pdf(v_po_number, SYSDATE);   /* 9.8  */
--          v_request_id := v_stat;                                         /* 9.8  */
--          v_stat       := ttec_po_email_global_gen(v_po_number,           /* 9.8  */
--                                               v_vendor_name,
--                                               v_requester_name,
--                                               v_po_status,
--                                               v_stat);
--/* 9.7 commented out end */
--        WHEN 1440 -- Malaysia
--         THEN
--          v_stat       := ttec_po_run_mal_pdf(v_po_number, SYSDATE);
--          v_request_id := v_stat;
--          v_stat       := ttec_po_email_us_gen(v_po_number,
--                                               v_vendor_name,
--                                               v_requester_name,
--                                               v_po_status,
--                                               v_stat);
--        WHEN 1441 -- Singapore
--         THEN
--          v_stat       := ttec_po_run_sgp_pdf(v_po_number, SYSDATE);
--          v_request_id := v_stat;
--          v_stat       := ttec_po_email_us_gen(v_po_number,
--                                               v_vendor_name,
--                                               v_requester_name,
--                                               v_po_status,
--                                               v_stat);
--        WHEN 1462 -- Philippines
--         THEN
--          v_stat       := ttec_po_run_phl_pdf(v_po_number, SYSDATE);
--          v_request_id := v_stat;
--          v_stat       := ttec_po_email_phl_gen(v_po_number,
--                                                v_vendor_name,
--                                                v_requester_name,
--                                                v_po_status,
--                                                v_stat);
--        WHEN 1475 -- Argentina
--         THEN
--          v_stat       := ttec_po_run_arg_pdf(v_po_number, SYSDATE);
--          v_request_id := v_stat;
--          v_stat       := ttec_po_email_arg_gen(v_po_number,
--                                                v_vendor_name,
--                                                v_requester_name,
--                                                v_po_status,
--                                                v_stat);
--        WHEN 1476 -- BRZ
--         THEN
--          v_stat       := ttec_po_run_global_ptb_pdf(v_po_number, SYSDATE); /* 10. 0 */
--          v_request_id := v_stat;                                           /* 10. 0 */
--          v_stat       := ttec_po_email_ptb_gen(v_po_number,                /* 10. 0 */
--                                                v_vendor_name,
--                                                v_requester_name,
--                                                v_po_status,
--                                                v_stat);
--/* 10.0 Commented Out End */
--        WHEN 1488 THEN
--          v_stat       := ttec_po_run_hkg_pdf(v_po_number, SYSDATE);
--          v_request_id := v_stat;
--          v_stat       := ttec_po_email_us_gen(v_po_number,
--                                               v_vendor_name,
--                                               v_requester_name,
--                                               v_po_status,
--                                               v_stat);
--        /* 9.5 Begin 16358 is eLoyalty US not PRG
--        WHEN 16358 -- PRG
--         THEN
--          v_stat       := ttec_po_run_prg_pdf(v_po_number, SYSDATE);
--          v_request_id := v_stat;
--          v_stat       := ttec_po_email_prg_gen(v_po_number,
--                                                v_vendor_name,
--                                                v_requester_name,
--                                                v_po_status,
--                                                v_stat);
--        9.5 End */
--/* 9.7 commented out begin */
--        WHEN 4027 -- DAC  /* 9.8 uncommented out */
--         THEN   /* 9.8 uncommented out */
--          v_stat       := ttec_po_run_global_pdf(v_po_number, SYSDATE);   /* 9.8  */
--          v_request_id := v_stat;                                         /* 9.8  */
--          v_stat       := ttec_po_email_global_gen(v_po_number,           /* 9.8  */
--                                               v_vendor_name,
--                                               v_requester_name,
--                                               v_po_status,
--                                               v_stat);
----          v_stat       := ttec_po_run_dac_pdf(v_po_number, SYSDATE);
----          v_request_id := v_stat;
----          v_stat       := ttec_po_email_us_gen_ttec(v_po_number, /* 9.5 */
----                                               v_vendor_name,
----                                               v_requester_name,
----                                               v_po_status,
----                                               v_stat);
----/* 9.7 commented out end */
--        WHEN 5075 -- Costa Rica
--         THEN
--          v_stat       := ttec_po_run_global_latam_pdf(v_po_number, SYSDATE); /* 10.0 */
--          v_request_id := v_stat;                                             /* 10.0 */
--          v_stat       := ttec_po_email_latam_gen(v_po_number,                /* 10.0 */
--                                                  v_vendor_name,
--                                                  v_requester_name,
--                                                  v_po_status,
--                                                  v_stat);
--/* 10.0 commented out begin */
----          v_stat       := ttec_po_run_cr_pdf(v_po_number, SYSDATE);
----          v_request_id := v_stat;
----          v_stat       := ttec_po_email_cr_gen(v_po_number,
----                                               v_vendor_name,
----                                               v_requester_name,
----                                               v_po_status,
----                                               v_stat);
--/* 10.0 commented out end */
--        WHEN 6536 -- South Africa
--         THEN
--          v_stat       := ttec_po_run_sa_pdf(v_po_number, SYSDATE);
--          v_request_id := v_stat;
--          v_stat       := ttec_po_email_us_gen(v_po_number,
--                                               v_vendor_name,
--                                               v_requester_name,
--                                               v_po_status,
--                                               v_stat);
--        WHEN 9713 --Spain
--         THEN
--          v_stat       := ttec_po_run_spn_pdf(v_po_number, SYSDATE);
--          v_request_id := v_stat;
--          v_stat       := ttec_po_email_spn_gen(v_po_number,
--                                                v_vendor_name,
--                                                v_requester_name,
--                                                v_po_status,
--                                                v_stat);
--        WHEN 6354 --Spain Global Services Costa Rica
--         THEN
--          v_stat       := ttec_po_run_scr_pdf(v_po_number, SYSDATE);
--          v_request_id := v_stat;
--          v_stat       := ttec_po_email_cr_gen(v_po_number,
--                                               v_vendor_name,
--                                               v_requester_name,
--                                               v_po_status,
--                                               v_stat);
--        WHEN 14825 --Ghana v3.0
--         THEN
--          v_stat       := ttec_po_run_gha_pdf(v_po_number, SYSDATE);
--          v_request_id := v_stat;
--          v_stat       := ttec_po_email_us_gen(v_po_number,
--                                               v_vendor_name,
--                                               v_requester_name,
--                                               v_po_status,
--                                               v_stat);
--/* 9.7 commented out begin*/
----        WHEN 15739 -- US Prodovis /* v3.2 */
----         THEN
----          v_stat       := ttec_po_run_prodovis_us_pdf(v_po_number, SYSDATE);
----          v_request_id := v_stat;
----          v_stat       := ttec_po_email_us_gen_ttec(v_po_number, /* 9.5 */
----                                               v_vendor_name,
----                                               v_requester_name,
----                                               v_po_status,
----                                               v_stat);
--/* 9.7 commented out end */
--          -- Version 5.3 <Start>
--        WHEN 16740 -- PRG Dubai
--         THEN
--          v_stat       := ttec_po_run_prg_dubai_pdf(v_po_number, SYSDATE);
--          v_request_id := v_stat;
--          v_stat       := ttec_po_email_prg_nonus_gen(v_po_number,
--                                                      v_vendor_name,
--                                                      v_requester_name,
--                                                      v_po_status,
--                                                      v_stat); -- Version 5.3 <End>
--        WHEN 16899 --Philippines Branch v3.6
--         THEN
--          v_stat       := ttec_po_run_phl_br_pdf(v_po_number, SYSDATE);
--          v_request_id := v_stat;
--          v_stat       := ttec_po_email_phl_gen(v_po_number,
--                                                v_vendor_name,
--                                                v_requester_name,
--                                                v_po_status,
--                                                v_stat); --Philippines Branch v3.6 <End>
--        WHEN 19435 --Philippines ROHQ
--         THEN
--          v_stat       := ttec_po_run_phl_rohq_pdf(v_po_number, SYSDATE);
--          v_request_id := v_stat;
--          v_stat       := ttec_po_email_phl_gen(v_po_number,
--                                                v_vendor_name,
--                                                v_requester_name,
--                                                v_po_status,
--                                                v_stat); --Philippines ROHQ
--        WHEN 48458 --Motif Philippines /* 10.1 */
--         THEN
--          v_stat       := ttec_po_run_phl_motif_pdf(v_po_number, SYSDATE);
--          v_request_id := v_stat;
--          v_stat       := ttec_po_email_phl_gen(v_po_number,
--                                                v_vendor_name,
--                                                v_requester_name,
--                                                v_po_status,
--                                                v_stat); --Motif Philippines /* 10.1 */
--        WHEN 48618 -- Motif India /* 10.2 */
--         THEN
--               /* 11.2 Begin*/
--              v_stat       := ttec_po_run_global_pdf(v_po_number, SYSDATE);   /* 11.2  */
--              v_request_id := v_stat;                                         /* 11.2  */
--              v_stat       := ttec_po_email_global_gen(v_po_number,           /* 11.2  */
--                                                   v_vendor_name,
--                                                   v_requester_name,
--                                                   v_po_status,
--                                                   v_stat);
--               /* 11.2  End */
--/* 11.2  commented out begin */
----          v_stat       := ttec_po_run_ind_motif_pdf(v_po_number, SYSDATE);
----          v_request_id := v_stat;
----          v_stat       := ttec_po_email_global_gen(v_po_number,           /* 9.8  */
----                                               v_vendor_name,
----                                               v_requester_name,
----                                               v_po_status,
----                                               v_stat);      --Motif India /* 10.2 */
--/* 11.2  commented out End */
--/* 10.2 commented out begin */
----          v_stat       := ttec_po_email_phl_gen(v_po_number,
----                                                v_vendor_name,
----                                                v_requester_name,
----                                                v_po_status,
----                                                v_stat);
--/* 10.2 commented out end */
--/* 9.7 commented out begin */
--        WHEN 20705 -- TT Ireland  /* 9.8 uncommented out */
--         THEN   /* 9.8 uncommented out */
--          v_stat       := ttec_po_run_global_pdf(v_po_number, SYSDATE);   /* 9.8  */
--          v_request_id := v_stat;                                         /* 9.8  */
--          v_stat       := ttec_po_email_global_gen(v_po_number,           /* 9.8  */
--                                               v_vendor_name,
--                                               v_requester_name,
--                                               v_po_status,
--                                               v_stat);
----          v_stat       := ttec_po_run_ire_pdf(v_po_number, SYSDATE);
----          v_request_id := v_stat;
----          v_stat       := ttec_po_email_us_gen_ttec(v_po_number, /* 9.6 */
----                                               v_vendor_name,
----                                               v_requester_name,
----                                               v_po_status,
----                                               v_stat);
--/* 9.7 commented out end */
--        WHEN 17579 -- TT prg belgium
--         THEN
--          --v_stat       := ttec_po_run_prg_bel_pdf(v_po_number, SYSDATE); /* 9.1 */
--          v_stat       := ttec_po_run_ttec_cnstg_bel_pdf(v_po_number, SYSDATE); /* 9.1 */
--          v_request_id := v_stat;
--         -- v_stat       := ttec_po_email_prg_nonus_gen(v_po_number, /* 9.1 */
--          v_stat       := ttec_po_email_ttec_cnstg_gen(v_po_number, /* 9.1 */
--                                                      v_vendor_name,
--                                                      v_requester_name,
--                                                      v_po_status,
--                                                      v_stat);
--        WHEN 16738 -- TT PRG SAF
--         THEN
--          v_stat       := ttec_po_run_prg_saf_pdf(v_po_number, SYSDATE);
--          v_request_id := v_stat;
--          v_stat       := ttec_po_email_prg_nonus_gen(v_po_number,
--                                                      v_vendor_name,
--                                                      v_requester_name,
--                                                      v_po_status,
--                                                      v_stat);
--        WHEN 17580 -- TT PRG lebenon
--         THEN
--          v_stat       := ttec_po_run_prg_leb_pdf(v_po_number, SYSDATE);
--          v_request_id := v_stat;
--          v_stat       := ttec_po_email_prg_nonus_gen(v_po_number,
--                                                      v_vendor_name,
--                                                      v_requester_name,
--                                                      v_po_status,
--                                                      v_stat);
--/* 9.7 commented out begin */
----        ------Start of 4.6 Changes -------
--        WHEN 30633  ----TSG (Technology Solutions Group, Inc).
--         THEN /* 9.8 uncommented out */
--          v_stat       := ttec_po_run_global_pdf(v_po_number, SYSDATE);   /* 9.8  */
--          v_request_id := v_stat;                                         /* 9.8  */
--          v_stat       := ttec_po_email_global_gen(v_po_number,           /* 9.8  */
--                                               v_vendor_name,
--                                               v_requester_name,
--                                               v_po_status,
--                                               v_stat);
----          v_stat       := ttec_po_run_tsg_pdf(v_po_number, SYSDATE);
----          v_request_id := v_stat;
----          v_stat       := ttec_po_email_us_gen_ttec(v_po_number, /* 9.5 */
----                                               v_vendor_name,
----                                               v_requester_name,
----                                               v_po_status,
----                                               v_stat);
----        -------End of 4.6 Changes -------
--/* 9.7 commented out end */
--        -------Start of 4.8 Changes ----------
--        WHEN 17599  ----PRG TURKEY
--         THEN
--          v_stat       := ttec_po_run_prg_turkey_pdf(v_po_number, SYSDATE);
--          v_request_id := v_stat;
--          v_stat       := ttec_po_email_prg_nonus_gen(v_po_number,
--                                                      v_vendor_name,
--                                                      v_requester_name,
--                                                      v_po_status,
--                                                      v_stat);
--         -------End of 4.8 Changes -------

--         -------Start of 8.2 Changes ----------
--        WHEN 35593  ----TELETECH_BULGARIA_OU
--         THEN
--               /* 10.3 Begin*/
--              v_stat       := ttec_po_run_global_pdf(v_po_number, SYSDATE);   /* 10.3  */
--              v_request_id := v_stat;                                         /* 10.3  */
--              v_stat       := ttec_po_email_global_gen(v_po_number,           /* 10.3  */
--                                                   v_vendor_name,
--                                                   v_requester_name,
--                                                   v_po_status,
--                                                   v_stat);
--               /* 10.3  End */
--/* 10.3  commented out begin */
----          v_stat       := ttec_po_run_prg_bulgaria_pdf(v_po_number, SYSDATE);
----          v_request_id := v_stat;
----          v_stat       := ttec_po_email_us_gen(v_po_number,
----                                               v_vendor_name,
----                                               v_requester_name,
----                                               v_po_status,
----                                               v_stat);
--/* 10.3  commented out End */
--         -------End of 8.2 Changes -------

--        /* ---Below ELSE part is only for some specific OU's  */
--         /* 9.8 commented out */
--        WHEN 34693 --TELETECH_POLAND /* 10.5  */
--         THEN
--              v_stat       := ttec_po_run_global_pdf(v_po_number, SYSDATE);   /* 10.5  */
--              v_request_id := v_stat;                                         /* 10.5  */
--              v_stat       := ttec_po_email_global_gen(v_po_number,           /* 10.5  */
--                                                   v_vendor_name,
--                                                   v_requester_name,
--                                                   v_po_status,
--                                                   v_stat);
--        WHEN 53068 --TTEC NETHERLAND /* 11.0  */
--         THEN
--              v_stat       := ttec_po_run_global_pdf(v_po_number, SYSDATE);   /* 11.0   */
--              v_request_id := v_stat;                                         /* 11.0  */
--              v_stat       := ttec_po_email_global_gen(v_po_number,           /* 11.0  */
--                                                   v_vendor_name,
--                                                   v_requester_name,
--                                                   v_po_status,
--                                                   v_stat);
--        WHEN 54909 --TTEC GREECE /* 11.1  */
--         THEN
--              v_stat       := ttec_po_run_global_pdf(v_po_number, SYSDATE);   /* 11.1   */
--              v_request_id := v_stat;                                         /* 11.1  */
--              v_stat       := ttec_po_email_global_gen(v_po_number,           /* 11.1  */
--                                                   v_vendor_name,
--                                                   v_requester_name,
--                                                   v_po_status,
--                                                   v_stat);
--        ELSE
----
----           /* ---Below ELSE part is for OU without any exception  */
----          /* 9.7 begin */
----          v_stat       := ttec_po_run_global_pdf(v_po_number, SYSDATE);
----          v_request_id := v_stat;
----          v_stat       := ttec_po_email_global_gen(v_po_number,
----                                               v_vendor_name,
----                                               v_requester_name,
----                                               v_po_status,
----                                               v_stat);
--          /* 9.7 end */
--           /* 9.8 commented out */

--/* 9.7 commented out begin */
--          --Start 4.2 changes
--          BEGIN
--            select UPPER(name)
--              into v_org_name
--              from hr_operating_units
--             where organization_id = v_org_id;

--            IF v_org_name = 'GUIDON' THEN
--               /* 9.8 Begin*/
--              v_stat       := ttec_po_run_global_pdf(v_po_number, SYSDATE);   /* 9.8  */
--              v_request_id := v_stat;                                         /* 9.8  */
--              v_stat       := ttec_po_email_global_gen(v_po_number,           /* 9.8  */
--                                                   v_vendor_name,
--                                                   v_requester_name,
--                                                   v_po_status,
--                                                   v_stat);
--               /* 9.8 End */
--/* 9.8 commented out begin */
----              v_stat       := ttec_po_run_guidon_pdf(v_po_number, SYSDATE);
----              v_request_id := v_stat;
----              v_stat       := ttec_po_email_us_gen_ttec(v_po_number, /* 9.5 */
----                                                   v_vendor_name,
----                                                   v_requester_name,
----                                                   v_po_status,
----                                                   v_stat);
--/* 9.8 commented out end */
--            ELSIF v_org_name = 'IKNOWTION' THEN
--               /* 9.8 Begin*/
--              v_stat       := ttec_po_run_global_pdf(v_po_number, SYSDATE);   /* 9.8  */
--              v_request_id := v_stat;                                         /* 9.8  */
--              v_stat       := ttec_po_email_global_gen(v_po_number,           /* 9.8  */
--                                                   v_vendor_name,
--                                                   v_requester_name,
--                                                   v_po_status,
--                                                   v_stat);
--               /* 9.8 End */
--/* 9.8 commented out begin */
----              v_stat       := ttec_po_run_iknowtion_pdf(v_po_number,
----                                                        SYSDATE);
----              v_request_id := v_stat;
----              v_stat       := ttec_po_email_us_gen_ttec(v_po_number,  /* 9.5 */
----                                                   v_vendor_name,
----                                                   v_requester_name,
----                                                   v_po_status,
----                                                   v_stat);
--/* 9.8 commented out end */
--            ELSIF v_org_name = 'ELOYALTY, LLC' THEN /*Start 4.3 Changes*/
--               /* 9.8 Begin*/
--              v_stat       := ttec_po_run_global_pdf(v_po_number, SYSDATE);   /* 9.8  */
--              v_request_id := v_stat;                                         /* 9.8  */
--              v_stat       := ttec_po_email_global_gen(v_po_number,           /* 9.8  */
--                                                   v_vendor_name,
--                                                   v_requester_name,
--                                                   v_po_status,
--                                                   v_stat);
--               /* 9.8 End */
--/* 9.8 commented out begin */
----              v_stat              := ttec_po_run_elt_us_pdf(v_po_number,
----                                                            SYSDATE);
----              v_request_id        := v_stat;
----              v_stat              := ttec_po_email_us_gen_ttec(v_po_number,  /* 9.5 */
----                                                          v_vendor_name,
----                                                          v_requester_name,
----                                                          v_po_status,
----                                                          v_stat);

--            ELSIF v_org_name = 'ELOYALTY CANADA' THEN
--               /* 9.8 Begin*/
--              v_stat       := ttec_po_run_global_pdf(v_po_number, SYSDATE);   /* 9.8  */
--              v_request_id := v_stat;                                         /* 9.8  */
--              v_stat       := ttec_po_email_global_gen(v_po_number,           /* 9.8  */
--                                                   v_vendor_name,
--                                                   v_requester_name,
--                                                   v_po_status,
--                                                   v_stat);
--               /* 9.8 End */
--/* 9.8 commented out begin */
----              v_stat              := ttec_po_run_elt_can_pdf(v_po_number,
----                                                             SYSDATE);
----              v_request_id        := v_stat;
----              v_stat              := ttec_po_email_us_gen_ttec(v_po_number, /* 9.5 */
----                                                          v_vendor_name,
----                                                          v_requester_name,
----                                                          v_po_status,
----                                                          v_stat);
--/* 9.8 commented out end*/
--            ELSIF v_org_name = 'ELOYALTY IRELAND' THEN
--               /* 9.8 Begin*/
--              v_stat       := ttec_po_run_global_pdf(v_po_number, SYSDATE);   /* 9.8  */
--              v_request_id := v_stat;                                         /* 9.8  */
--              v_stat       := ttec_po_email_global_gen(v_po_number,           /* 9.8  */
--                                                   v_vendor_name,
--                                                   v_requester_name,
--                                                   v_po_status,
--                                                   v_stat);
--               /* 9.8 End */
--/* 9.8 commented out begin */
----              v_stat              := ttec_po_run_elt_ire_pdf(v_po_number,
----                                                             SYSDATE);
----              v_request_id        := v_stat;
----              v_stat              := ttec_po_email_us_gen_ttec(v_po_number, /* 9.6 */
----                                                          v_vendor_name,
----                                                          v_requester_name,
----                                                          v_po_status,
----                                                          v_stat);  /*End 4.3 Changes*/
--/* 9.8 commented out end*/
--            ELSIF v_org_name = 'TTEC DIGITAL ANALYTICS INDIA' THEN
--               /* 11.5 Begin*/
--              v_stat       := ttec_po_run_global_pdf(v_po_number, SYSDATE);   /* 9.8  */
--              v_request_id := v_stat;                                         /* 9.8  */
--              v_stat       := ttec_po_email_global_gen(v_po_number,           /* 9.8  */
--                                                   v_vendor_name,
--                                                   v_requester_name,
--                                                   v_po_status,
--                                                   v_stat);
--               /* 11.5 End */
--            ELSE
--              print_line('PO Number' || v_po_number ||
--                         ' Has not been sent due to non Incorporated Organization ID: ' ||
--                         TO_CHAR(v_org_id));
--              v_stat := -1;
--            END IF;

--          EXCEPTION
--            WHEN NO_DATA_FOUND THEN
--              print_line('PO Number' || v_po_number ||
--                         ' Has not been sent due to non Incorporated Organization ID: ' ||
--                         TO_CHAR(v_org_id));
--              v_stat := -1;
--          END; --End 4.2 changes
--/* 9.7 commented out end */
--      /* commented for 4.2 changes
--                           print_line
--                              (   'PO Number'
--                               || v_po_number
--                               || ' Has not been sent due to non Incorporated Organization ID: '
--                               || TO_CHAR (v_org_id)
--                              );
--                           v_stat := -1;
--                     -- force send message that the PO has not been mailed */
--      END CASE;

      IF v_stat = -1 THEN

            -- ver 9.4
             print_line('No File regerated for the request ' || TO_CHAR(v_request_id) );

        /*  failed to generate PDF state so  */
        IF v_org_id != 121 THEN
          -- since we took US Percepta OUT, then do not send any emails
          v_stat2 := ttec_send_no_vendor_email(v_po_number,
                                               v_org_id,
                                               v_file_name_out,
                                               v_vendor_name,
                                               v_vendor_site_email,
                                               v_requester_name,
                                               v_requester_email,
                                               v_buyer_email,
                                               v_vendor_fax);
        END IF;
      ELSE

        g_error_step := 'Step 5.3: Copying PDF file';
        /* now using request ID, build the file name */
        v_file_request  := 'o' || TO_CHAR(v_request_id) || '.out';
        v_file_name_out := g_file_prename || v_po_number ||'_'||g_organization_code||
                           g_file_extension;
        print_line('file ' || v_file_request || ' dir ' ||
                   g_request_default_dir || ' to ' || g_temp_dir ||
                   ' file out ' || v_file_name_out);
        fnd_file.put_line(fnd_file.LOG, '=================================>V_stat3 Before calling ttec_copy_file >>>>'|| v_stat3);
        v_stat3 := ttec_copy_file(g_request_default_dir,
                       v_file_request,
                       g_temp_dir,
                       v_file_name_out,
                       v_stat); /* 10.4 */

         fnd_file.put_line(fnd_file.LOG, '=================================>V_stat3 After calling ttec_copy_file >>>>'|| v_stat3);
        /* 10.4 Begin */
          IF v_stat3 = -1 THEN

                -- ver 9.4
                print_line('No File generated for ' || v_file_request );

                /*  failed to generate PDF state so  */
                IF v_org_id != 121 THEN
                  -- since we took US Percepta OUT, then do not send any emails
                  fnd_file.put_line(fnd_file.LOG,'Calling ttec_send_no_vendor_email for PO number >>>>'||v_po_number);

                  v_stat4 := ttec_send_no_vendor_email(v_po_number,
                                                       v_org_id,
                                                       v_file_name_out,
                                                       v_vendor_name,
                                                       v_vendor_site_email,
                                                       v_requester_name,
                                                       v_requester_email,
                                                       v_buyer_email,
                                                       v_vendor_fax);
                END IF;
          ELSE
            v_file_name_out := g_temp_dir || '/' || v_file_name_out;
            g_error_step    := 'Step 5.4 Sending Email';
            v_stat          := ttec_build_send_po_email(v_po_number,
                                                        v_org_id,
                                                        v_file_name_out,
                                                        v_vendor_name,
                                                        v_vendor_site_email,
                                                        v_requester_name,
                                                        v_requester_email,
                                                        v_buyer_email,
                                                        v_vendor_fax);
          END IF;
          /* 10.4 End */

      END IF;

    END LOOP;

    IF v_stat != 0 THEN
      print_line('Error in running PO Print And or sending email for PO ' ||
                 v_po_number);
    END IF;
  EXCEPTION
    --   when utl_file.invalid_path then dbms_output.put_line('Invalid Path');
    --   when utl_file.invalid_operation then dbms_output.put_line('Invalid Operation');
    --   when utl_file.invalid_mode then dbms_output.put_line('Invalid Mode');
    --   when utl_file.read_error then dbms_output.put_line('Read Error');
    --   when utl_file.write_error then dbms_output.put_line('Write Error');
    --
    WHEN OTHERS THEN
      print_line('Error in Processing - Contact ERP Development' || '|' ||
                 SQLCODE || '|' || SUBSTR(SQLERRM, 1, 80) ||
                 ' - ERROR at: ' || g_error_step || ' PO Number: ' ||
                 v_po_number);
      /* 12.6 */
     send_PO_email_ERROR('ebs_development@ttec.com, globalprocurement@ttec.com, oraclefinancialssupport@ttec.com',
                                                    v_po_number       ,
                                                    SQLCODE || ': ' || SUBSTR(SQLERRM, 1, 80)|| ' - ERROR at: ' || g_error_step);
      NULL;
  END main;
END ttec_po_email;
/
show errors;
/