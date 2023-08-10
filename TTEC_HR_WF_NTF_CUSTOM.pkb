create or replace PACKAGE BODY TTEC_HR_WF_NTF_CUSTOM AS
/* $Header: TTEC_HR_WF_NTF_CUSTOM.pkb 1.3 2010/05/27 mdodge ship $ */

/*== START ================================================================================================*\
   Author: Michelle Dodge
     Date: July 14, 2009
Call From: HRSSA workflow
     Desc: This package contains the code for building custom dynamic notification
           content for the HRSSA Workflow.  It is part of the US/CAN MSS
           Reimplementation but can be added to for subsequent country implementations.

  Modification History:

 Version    Date     Author   Description (Include Ticket#)
 -------  --------  --------  ------------------------------------------------------------------------------
     1.0  07/31/09  MDodge    MSS US/Can Reimplementation Project - Initial Version
     1.1  10/10/09  MDodge    Updated with following mods
                                1. Correct Term Reason display (on Term FYI)
                                2. Add Effective Date to Assignment FYI
                                3. Only display TRUE Reassigned Direct Reports vs all Direct Reports
                                4. Separate the New Manager display from the Reassigned Direct Reports
                                5. Partially correct the Reassigned Direct Reports Overflow
     1.2  10/26/09  MDodge    Redesign to use a PL/SQL CLOB document.  The overloaded PL/SQL
                              document procedures are now obsolete and only need to be maintained
                              for the duration of the pre-existing notifications (approx 30 days after go-live).
     1.3  05/27/10  MDodge    Add Location Column to Summary section, includes following mods:
                                1. New Function build_3_col_row_html for 3 column output
                                2. Add Location_Code Output param and lookup to get_employee_info
                                3. Update build_summary_html to call new and mod functions and add additional
                                   output formatting for 3rd column.
	1.0	 04-May-2023  IXPRAVEEN(ARGANO)   	R12.2 Upgrade Remediation							   

\*== END ==================================================================================================*/

  -- Error Constants
 --START R12.2 Upgrade Remediation 
  /*g_application_code   cust.ttec_error_handling.application_code%TYPE := 'HR';				-- Commented code by IXPRAVEEN-ARGANO, 04-May-2023
  g_interface          cust.ttec_error_handling.INTERFACE%TYPE        := 'HRSSA';
  g_package            cust.ttec_error_handling.program_name%TYPE     := 'TTEC_HR_WF_NTF_CUSTOM';*/
  g_application_code   apps.ttec_error_handling.application_code%TYPE := 'HR';					--  code Added by IXPRAVEEN-ARGANO, 04-May-2023
  g_interface          apps.ttec_error_handling.INTERFACE%TYPE        := 'HRSSA';
  g_package            apps.ttec_error_handling.program_name%TYPE     := 'TTEC_HR_WF_NTF_CUSTOM';
  --END R12.2.10 Upgrade remediation
  g_status_warning     VARCHAR2( 7 )                                  := 'WARNING';
  g_status_failure     VARCHAR2( 7 )                                  := 'FAILURE';

  -- HTML String Constants
  g_row_header    VARCHAR2(32767) :=
    '<th scope="row" style="border-color:#f7f7e7;font-family:Arial,Helvetica,Geneva,sans-serif;font-size:10pt;font-weight:bold;text-align:right;background-color:#d2d8b0;color:#336699">';
  g_col_header    VARCHAR2(32767) :=
    '<th scope="col" style="border-color:#f7f7e7;font-family:Arial,Helvetica,Geneva,sans-serif;font-size:10pt;font-weight:bold;text-align:left;background-color:#d2d8b0;color:#336699;vertical-align:bottom" ';
  g_row_detail    VARCHAR2(32767) :=
    '<td style="font-family:Arial,Helvetica,Geneva,sans-serif;font-size:10pt;color:#000000;vertical-align:baseline;background-color:#f7f7e7;border-color:#d2d8b0">';
  g_change_image  VARCHAR2(32767) :=
    '<img src="http://den-erp040.teletech.com:8000/OA_MEDIA/changeditemicon_status.gif" border="0" align="middle">';
  g_html_len      NUMBER := 29500;  -- Allow overflow wrapup room

/*********************************************************
**  Private Procedures and Functions
*********************************************************/


--
-- PROCEDURE process_error
--   Description: This is a wrapper procedure to the ttec_process_error procedure
--                which will pull in certain params from global variables so as
--                to minimize the number of variables input in the main code.
--
PROCEDURE process_error ( module_name    CHAR
                        , status         CHAR
                        , error_code     NUMBER := NULL
                        , error_message  CHAR   := NULL
                        , location       NUMBER := NULL
                        , itemtype       CHAR   := NULL
                        , itemkey        CHAR   := NULL
                        , trx_id         CHAR   := NULL
                        , trx_step_id    CHAR   := NULL
                        , ntf_type       CHAR   := NULL
                        , label1         CHAR   := NULL
                        , reference1     CHAR   := NULL
                        , label2         CHAR   := NULL
                        , reference2     CHAR   := NULL
                        , label3         CHAR   := NULL
                        , reference3     CHAR   := NULL
                        , label4         CHAR   := NULL
                        , reference4     CHAR   := NULL
                        , label5         CHAR   := NULL
                        , reference5     CHAR   := NULL ) IS

  PRAGMA AUTONOMOUS_TRANSACTION;

BEGIN
  --cust.ttec_process_error( application_code => g_application_code		-- Commented code by IXPRAVEEN-ARGANO, 04-May-2023
  apps.ttec_process_error( application_code => g_application_code       --  code Added by IXPRAVEEN-ARGANO, 04-May-2023
                         , interface        => g_interface
                         , program_name     => g_package
                         , module_name      => module_name
                         , status           => status
                         , error_code       => error_code
                         , error_message    => error_message
                         , label1           => 'WF Item Type'
                         , reference1       => itemtype
                         , label2           => 'WF Item Key'
                         , reference2       => itemkey
                         , label3           => 'Trx ID'
                         , reference3       => trx_id
                         , label4           => 'Trx Step ID'
                         , reference4       => trx_step_id
                         , label5           => 'Ntf Type'
                         , reference5       => ntf_type
                         , label6           => 'Err Loc'
                         , reference6       => location
                         , label7           => label1
                         , reference7       => reference1
                         , label8           => label2
                         , reference8       => reference2
                         , label9           => label3
                         , reference9       => reference3
                         , label10          => label4
                         , reference10      => reference4
                         , label11          => label5
                         , reference11      => reference5 );

  COMMIT;

EXCEPTION
  WHEN OTHERS THEN
    NULL;
END process_error;


--
-- FUNCTION get_num_val
--   Description: Return the Numeric Value from the Transaction based on the
--                Column Type specified
--   Arguments:
--        In: p_col_type  => Column to retrieve value from (CURRENT, ORIGINAL, PREVIOUS)
--            p_val_name  => Value Name to retrieve
--    Return: Numeric Value from specified Trx Value record
--
FUNCTION get_num_val ( p_trx_id    IN  NUMBER
                     , p_api_name  IN  VARCHAR2
                     , p_col_type  IN  VARCHAR2
                     , p_val_name  IN  VARCHAR2 ) RETURN NUMBER IS
					 
--START R12.2 Upgrade Remediation
  /*c_module           cust.ttec_error_handling.module_name%TYPE  := 'get_num_val';		-- Commented code by IXPRAVEEN-ARGANO, 04-May-2023
  v_error_msg        cust.ttec_error_handling.error_message%TYPE;*/
  c_module           apps.ttec_error_handling.module_name%TYPE  := 'get_num_val';		--  code Added by IXPRAVEEN-ARGANO, 04-May-2023
  v_error_msg        apps.ttec_error_handling.error_message%TYPE;
  --END R12.2.10 Upgrade remediation
  v_loc              NUMBER := 0;

  v_value            NUMBER;

BEGIN
  v_loc := 10;

  SELECT DECODE(p_col_type, 'CURRENT',  number_value
                          , 'ORIGINAL', original_number_value
                          , 'PREVIOUS', previous_number_value, NULL )
    INTO v_value
    --FROM cust.ttec_hr_api_trx_values		  -- Commented code by IXPRAVEEN-ARGANO, 04-May-2023
	FROM apps.ttec_hr_api_trx_values		  --  code Added by IXPRAVEEN-ARGANO, 04-May-2023
   WHERE transaction_id = p_trx_id
     AND api_name = p_api_name
     AND name = p_val_name;

  RETURN v_value;
EXCEPTION
  WHEN OTHERS THEN
    v_error_msg := SQLERRM;
    process_error( module_name      => c_module
                 , status           => g_status_warning
                 , error_code       => SQLCODE
                 , error_message    => v_error_msg
                 , location         => v_loc
                 , trx_id           => p_trx_id
                 , label1           => 'Trx API Name'
                 , reference1       => p_api_name
                 , label2           => 'Type'
                 , reference2       => p_col_type
                 , label3           => 'Value Name'
                 , reference3       => p_val_name );

    RETURN v_value;
END get_num_val;


--
-- FUNCTION get_text_val
--   Description: Return the Text Value from the Transaction based on the
--                Column Type specified
--   Arguments:
--        In: p_col_type  => Column to retrieve value from (CURRENT, ORIGINAL, PREVIOUS)
--            p_val_name  => Value Name to retrieve
--    Return: Numeric Value from specified Trx Value record
--
FUNCTION get_text_val ( p_trx_id    IN  NUMBER
                      , p_api_name  IN  VARCHAR2
                      , p_col_type  IN  VARCHAR2
                      , p_val_name  IN  VARCHAR2 ) RETURN VARCHAR2 IS
--START R12.2 Upgrade Remediation
 /* c_module           cust.ttec_error_handling.module_name%TYPE  := 'get_text_val';	-- Commented code by IXPRAVEEN-ARGANO, 04-May-2023
  v_error_msg        cust.ttec_error_handling.error_message%TYPE;*/
  c_module           apps.ttec_error_handling.module_name%TYPE  := 'get_text_val';		--  code Added by IXPRAVEEN-ARGANO, 04-May-2023
  v_error_msg        apps.ttec_error_handling.error_message%TYPE;
  --END R12.2.10 Upgrade remediation
  v_loc              NUMBER := 0;

  --v_value            cust.ttec_hr_api_trx_values.varchar2_value%TYPE;		-- Commented code by IXPRAVEEN-ARGANO, 04-May-2023
  v_value            apps.ttec_hr_api_trx_values.varchar2_value%TYPE;		--  code Added by IXPRAVEEN-ARGANO, 04-May-2023

BEGIN
  v_loc := 10;

  SELECT DECODE(p_col_type, 'CURRENT',  varchar2_value
                          , 'ORIGINAL', original_varchar2_value
                          , 'PREVIOUS', previous_varchar2_value, NULL )
    INTO v_value
    --FROM cust.ttec_hr_api_trx_values			-- Commented code by IXPRAVEEN-ARGANO, 04-May-2023
	 FROM apps.ttec_hr_api_trx_values			--  code Added by IXPRAVEEN-ARGANO, 04-May-2023
   WHERE transaction_id = p_trx_id
     AND api_name = p_api_name
     AND name = p_val_name;

  RETURN v_value;
EXCEPTION
  WHEN OTHERS THEN
    v_error_msg := SQLERRM;
    process_error( module_name      => c_module
                 , status           => g_status_warning
                 , error_code       => SQLCODE
                 , error_message    => v_error_msg
                 , location         => v_loc
                 , trx_id           => p_trx_id
                 , label1           => 'Trx API Name'
                 , reference1       => p_api_name
                 , label2           => 'Type'
                 , reference2       => p_col_type
                 , label3           => 'Value Name'
                 , reference3       => p_val_name );

    RETURN v_value;
END get_text_val;


--
-- FUNCTION get_date_val
--   Description: Return the Date Value from the Transaction based on the
--                Column Type specified
--   Arguments:
--        In: p_col_type  => Column to retrieve value from (CURRENT, ORIGINAL, PREVIOUS)
--            p_val_name  => Value Name to retrieve
--    Return: Numeric Value from specified Trx Value record
--
FUNCTION get_date_val ( p_trx_id    IN  NUMBER
                      , p_api_name  IN  VARCHAR2
                      , p_col_type  IN  VARCHAR2
                      , p_val_name  IN  VARCHAR2 ) RETURN DATE IS

  c_module           cust.ttec_error_handling.module_name%TYPE  := 'get_date_val';
  v_error_msg        cust.ttec_error_handling.error_message%TYPE;
  v_loc              NUMBER := 0;

  v_value            DATE;

BEGIN
  v_loc := 10;

  SELECT DECODE(p_col_type, 'CURRENT',  date_value
                          , 'ORIGINAL', original_date_value
                          , 'PREVIOUS', previous_date_value, NULL )
    INTO v_value
    --FROM cust.ttec_hr_api_trx_values			-- Commented code by IXPRAVEEN-ARGANO, 04-May-2023
	FROM apps.ttec_hr_api_trx_values			--  code Added by IXPRAVEEN-ARGANO, 04-May-2023
   WHERE transaction_id = p_trx_id
     AND api_name = p_api_name
     AND name = p_val_name;

  RETURN v_value;
EXCEPTION
  WHEN OTHERS THEN
    v_error_msg := SQLERRM;
    process_error( module_name      => c_module
                 , status           => g_status_warning
                 , error_code       => SQLCODE
                 , error_message    => v_error_msg
                 , location         => v_loc
                 , trx_id           => p_trx_id
                 , label1           => 'Trx API Name'
                 , reference1       => p_api_name
                 , label2           => 'Type'
                 , reference2       => p_col_type
                 , label3           => 'Value Name'
                 , reference3       => p_val_name );

    RETURN v_value;
END get_date_val;


--
-- FUNCTION get_sec_grp_id
--   Description: This Procedure will return the Security Group ID for the
--                input Business Group ID
--   Arguments:
--        In: p_bg_id     => Business Group ID
--    Return: Security Group ID
--
FUNCTION get_sec_grp_id ( p_bg_id  IN  NUMBER ) RETURN NUMBER IS
--START R12.2 Upgrade Remediation
  /*c_module           cust.ttec_error_handling.module_name%TYPE  := 'get_sec_grp_id';		-- Commented code by IXPRAVEEN-ARGANO, 04-May-2023
  v_error_msg        cust.ttec_error_handling.error_message%TYPE;*/
  c_module           apps.ttec_error_handling.module_name%TYPE  := 'get_sec_grp_id';		--  code Added by IXPRAVEEN-ARGANO, 04-May-2023
  v_error_msg        apps.ttec_error_handling.error_message%TYPE;
--END R12.2.10 Upgrade remediation  
  v_loc              NUMBER := 0;

  v_sec_grp_id  NUMBER;

BEGIN
  v_loc := 10;

  SELECT security_group_id
    INTO v_sec_grp_id
    FROM fnd_security_groups
   WHERE security_group_key = TO_CHAR(p_bg_id);

  RETURN v_sec_grp_id;
EXCEPTION
  WHEN OTHERS THEN
    process_error( module_name      => c_module
                 , status           => g_status_warning
                 , error_code       => SQLCODE
                 , error_message    => 'No Sec Grp ID found for Bus Grp ID '||p_bg_id
                 , location         => v_loc );

  RETURN 0;
END get_sec_grp_id;

--
-- PROCEDURE get_wf_dtl
--   Description: This Procedure will return WF information identified by the NID
--                to the calling routine.
--   Arguments:
--        In: p_nid       => Notification ID - Used to get WF Details
--       Out: p_trx_id    => Transaction ID of WF that owns the Notification
--            p_ntf_type  => Notification Role Type -> to determine content
--            p_item_type => Item Type of WF that owns the Notification
--            p_item_key  => Item Key of WF that owns the Notification
--
PROCEDURE get_wf_dtl ( p_nid         IN  NUMBER
                     , p_trx_id     OUT  NUMBER
                     , p_ntf_type   OUT  VARCHAR2
                     , p_itemtype   OUT  VARCHAR2
                     , p_itemkey    OUT  VARCHAR2 ) IS

--START R12.2 Upgrade Remediation
  /*c_module           cust.ttec_error_handling.module_name%TYPE  := 'get_wf_dtl';			-- Commented code by IXPRAVEEN-ARGANO, 04-May-2023
  v_error_msg        cust.ttec_error_handling.error_message%TYPE;*/
  c_module           apps.ttec_error_handling.module_name%TYPE  := 'get_wf_dtl';			--  code Added by IXPRAVEEN-ARGANO, 04-May-2023
  v_error_msg        apps.ttec_error_handling.error_message%TYPE;
  --  code Added by IXPRAVEEN-ARGANO, 04-May-2023
  v_loc              NUMBER := 0;

  v_performer        VARCHAR2(100);
  v_submitter_id     NUMBER;
  v_submitter_mgr    VARCHAR2(100);
  v_itemtype         wf_item_activity_statuses.item_type%TYPE;
  v_itemkey          wf_item_activity_statuses.item_key%TYPE;
  v_actid            wf_item_activity_statuses.process_activity%TYPE;

BEGIN
  v_loc := 10;
  -- Get the WF Item Type, Item Key and Activity ID from the NID
  BEGIN
    SELECT item_type, item_key, process_activity
      INTO v_itemtype, v_itemkey, v_actid
      FROM wf_item_activity_statuses
     WHERE notification_id = p_nid;
  EXCEPTION
    WHEN NO_DATA_FOUND THEN
      SELECT item_type, item_key, process_activity
        INTO v_itemtype, v_itemkey, v_actid
        FROM wf_item_activity_statuses_h
       WHERE notification_id = p_nid;
  END;

  v_loc := 20;
  -- Get the Trx ID from the WF Item
  p_trx_id := wf_engine.getitemattrnumber ( itemtype  => v_itemtype
                                          , itemkey   => v_itemkey
                                          , aname     => 'TRANSACTION_ID' );

  -- Identify the Role Type for the notification
  v_loc := 30;
  BEGIN
    SELECT recipient_role
      INTO v_performer
      FROM wf_notifications
     WHERE notification_id = p_nid;
  EXCEPTION
    WHEN OTHERS THEN
      v_error_msg := SQLERRM;
      process_error( module_name      => c_module
                   , status           => g_status_warning
                   , error_code       => SQLCODE
                   , error_message    => v_error_msg
                   , location         => v_loc
                   , label1           => 'NID'
                   , reference1       => p_nid );

      v_performer := 'UNKNOWN';
  END;

  -- Get the Submitter Person ID and UserName for this transaction
  v_loc := 40;
  v_submitter_id := wf_engine.getitemattrnumber ( itemtype  => v_itemtype
                                                , itemkey   => v_itemkey
                                                , aname     => 'CREATOR_PERSON_ID' );

  v_loc := 50;
  BEGIN
    SELECT user_name
      INTO v_submitter_mgr
      FROM per_all_assignments_f paa
         , fnd_user fu
     WHERE paa.person_id = v_submitter_id
       AND SYSDATE BETWEEN paa.effective_start_date AND paa.effective_end_date
       AND fu.employee_id = paa.supervisor_id;

  EXCEPTION
    WHEN OTHERS THEN
      v_error_msg := SQLERRM;
      process_error( module_name      => c_module
                   , status           => g_status_warning
                   , error_code       => SQLCODE
                   , error_message    => v_error_msg
                   , location         => v_loc
                   , label1           => 'NID'
                   , reference1       => p_nid
                   , label2           => 'Submitter ID'
                   , reference2       => v_submitter_id );
  END;

  IF v_performer = v_submitter_mgr THEN
    p_ntf_type := 'SMGR';
  ELSIF SUBSTR(v_performer,1,3) = 'HC_' THEN
    p_ntf_type := 'HC';
  ELSIF SUBSTR(v_performer,1,4) = 'OSC_' THEN
    p_ntf_type := 'OSC';
  ELSIF SUBSTR(v_performer,1,11) = 'FACILITIES_' THEN
    p_ntf_type := 'FAC';
  ELSE
    p_ntf_type := 'UNKNOWN';
  END IF;

  p_itemtype := v_itemtype;
  p_itemkey  := v_itemkey;

EXCEPTION
  WHEN OTHERS THEN
    v_error_msg := SQLERRM;
    process_error( module_name      => c_module
                 , status           => g_status_warning
                 , error_code       => SQLCODE
                 , error_message    => v_error_msg
                 , location         => v_loc
                 , itemtype         => v_itemtype
                 , itemkey          => v_itemkey
                 , trx_id           => p_trx_id
                 , ntf_type         => p_ntf_type
                 , label1           => 'NID'
                 , reference1       => p_nid
                 , label2           => 'Performer'
                 , reference2       => v_performer );

END get_wf_dtl;


--
-- PROCEDURE get_employee_info
--   Description: This Procedure will return an Employee Name and Number for the
--                input Employee ID.
--   Arguments:
--        In: p_employee_id   => Employee ID of employee to get Name and Num for.
--       Out: p_employee_name => Full Name of Employee
--            p_employee_num  => Employee Number of Employee
--            p_location_code => Employee Location Code
--
PROCEDURE get_employee_info ( p_employee_id    IN  NUMBER
                            , p_employee_name OUT  VARCHAR2
                            , p_employee_num  OUT  VARCHAR2
                            , p_location_code OUT  VARCHAR2 ) IS  /* 1.3 - 2 */

--START R12.2 Upgrade Remediation
  /*c_module           cust.ttec_error_handling.module_name%TYPE  := 'get_employee_info';		-- Commented code by IXPRAVEEN-ARGANO, 04-May-2023
  v_error_msg        cust.ttec_error_handling.error_message%TYPE;*/
  c_module           apps.ttec_error_handling.module_name%TYPE  := 'get_employee_info';			--  code Added by IXPRAVEEN-ARGANO, 04-May-2023
  v_error_msg        apps.ttec_error_handling.error_message%TYPE;
  --END R12.2.10 Upgrade remediation
  v_loc              NUMBER := 0;

BEGIN
  v_loc := 10;

  /* 1.3 - 2 */
  -- Updated code to join to assignment and location tables and select the
  -- location_code value to be output to calling routine.
  SELECT pap.full_name
       , pap.employee_number
       , hl.location_code
    INTO p_employee_name
       , p_employee_num
       , p_location_code
    FROM per_all_people_f pap
       , per_all_assignments_f paa
       , hr_locations_all hl
   WHERE pap.person_id = p_employee_id
     AND TRUNC(SYSDATE) BETWEEN pap.effective_start_date AND pap.effective_end_date
     AND paa.person_id = pap.person_id
     AND TRUNC(SYSDATE) BETWEEN paa.effective_start_date AND paa.effective_end_date
     AND hl.location_id (+) = paa.location_id;

EXCEPTION
  WHEN OTHERS THEN
      v_error_msg := SQLERRM;
      process_error( module_name      => c_module
                   , status           => g_status_warning
                   , error_code       => SQLCODE
                   , error_message    => v_error_msg
                   , location         => v_loc
                   , label1           => 'Employee ID'
                   , reference1       => p_employee_id );
END get_employee_info;


--
-- FUNCTION trx_api_exist
--   Description: This function will return a TRUE/FALSE boolean if the input API
--                data exists for the input Transaction
--   Arguments:
--        In: p_header_label   => Label used to identify the section in the Output
--    Return: HTML code for Header section
--
FUNCTION trx_api_exist ( p_trx_id   IN  NUMBER
                       , p_api_name IN  VARCHAR2 ) RETURN BOOLEAN IS
--START R12.2 Upgrade Remediation
  /*c_module           cust.ttec_error_handling.module_name%TYPE  := 'trx_api_exist';			-- Commented code by IXPRAVEEN-ARGANO, 04-May-2023
  v_error_msg        cust.ttec_error_handling.error_message%TYPE;*/
  c_module           apps.ttec_error_handling.module_name%TYPE  := 'trx_api_exist';				 --  code Added by IXPRAVEEN-ARGANO, 04-May-2023
  v_error_msg        apps.ttec_error_handling.error_message%TYPE;
  --END R12.2.10 Upgrade remediation
  v_loc              NUMBER := 0;

  v_cnt              NUMBER;

BEGIN
  v_loc := 10;

  SELECT COUNT(*)
    INTO v_cnt
    --FROM cust.ttec_hr_api_trx_values			-- Commented code by IXPRAVEEN-ARGANO, 04-May-2023
	FROM apps.ttec_hr_api_trx_values			--  code Added by IXPRAVEEN-ARGANO, 04-May-2023
   WHERE transaction_id = p_trx_id
     AND api_name = p_api_name;

  IF v_cnt > 0 THEN
    RETURN TRUE;
  ELSE
    RETURN FALSE;
  END IF;

EXCEPTION
  WHEN OTHERS THEN
    v_error_msg := SQLERRM;
    process_error( module_name      => c_module
                 , status           => g_status_warning
                 , error_code       => SQLCODE
                 , error_message    => v_error_msg
                 , location         => v_loc
                 , trx_id           => p_trx_id
                 , label1           => 'Trx API Name'
                 , reference1       => p_api_name );
    RETURN FALSE;
END trx_api_exist;


--
-- FUNCTION build_hdr_html
--   Description: This function will generate the HTML Header for the Detail Section
--                to be displayed.
--   Arguments:
--        In: p_header_label   => Label used to identify the section in the Output
--    Return: HTML code for Header section
--
FUNCTION build_hdr_html ( p_header_label  IN   VARCHAR2 ) RETURN VARCHAR2 IS

--START R12.2 Upgrade Remediation
  /*c_module           cust.ttec_error_handling.module_name%TYPE  := 'build_hdr_html';			-- Commented code by IXPRAVEEN-ARGANO, 04-May-2023
  v_error_msg        cust.ttec_error_handling.error_message%TYPE;*/
  c_module           apps.ttec_error_handling.module_name%TYPE  := 'build_hdr_html';			--  code Added by IXPRAVEEN-ARGANO, 04-May-2023
  v_error_msg        apps.ttec_error_handling.error_message%TYPE;
  --END R12.2.10 Upgrade remediation
  v_loc              NUMBER := 0;

  v_html             VARCHAR2(32767);

BEGIN
  v_loc := 10;

  v_html := v_html||'<table cellpadding="0" cellspacing="0" border="0" width="100%">';
  v_html := v_html|| '<tr><td height="17" width="20"></td></tr>';
  v_html := v_html|| '<tr><td rowspan="3" width="20"><script>t(20,1)</script></td>';
  v_html := v_html||     '<td><table cellpadding="0" cellspacing="0" border="0" width="100%">';
  v_html := v_html||           '<tr><td width="100%">';
  v_html := v_html||                 '<span style="color:#336699;font-family:Arial,Helvetica,Geneva,sans-serif;font-size:13pt;margin-bottom:0px;font-weight:bold">'||p_header_label||'</span>';
  v_html := v_html||           '</td></tr>';
  v_html := v_html||         '</table></td></tr></table>';

  RETURN v_html;
EXCEPTION
  WHEN OTHERS THEN
    v_error_msg := SQLERRM;
    process_error( module_name      => c_module
                 , status           => g_status_warning
                 , error_code       => SQLCODE
                 , error_message    => v_error_msg
                 , location         => v_loc
                 , label1           => 'Header Label'
                 , reference1       => p_header_label );

    RETURN v_html;
END build_hdr_html;


--
-- FUNCTION build_row_html (2 columns)
--   Description: This function will generate the HTML Row for the Assignment and
--                Pay Rate Transactions.
--   Arguments:
--        In: p_row_heading   => Heading Label for the row
--            p_col0_val      => Column Value for the 'Current' column
--            p_col1_val      => Column Value for the 'Proposed' column
--            p_change_flag   => Display the Change Icon for this row?
--    Return: HTML code for Row
--
FUNCTION build_row_html ( p_row_heading  IN  VARCHAR2
                        , p_col0_val     IN  VARCHAR2
                        , p_col1_val     IN  VARCHAR2
                        , p_change_flag  IN  BOOLEAN  ) RETURN VARCHAR2 IS

--START R12.2 Upgrade Remediation
 /* c_module           cust.ttec_error_handling.module_name%TYPE  := 'build_row_html';			-- Commented code by IXPRAVEEN-ARGANO, 04-May-2023
  v_error_msg        cust.ttec_error_handling.error_message%TYPE;*/
  c_module           apps.ttec_error_handling.module_name%TYPE  := 'build_row_html';			--  code Added by IXPRAVEEN-ARGANO, 04-May-2023
  v_error_msg        apps.ttec_error_handling.error_message%TYPE;
--END R12.2.10 Upgrade remediation  
  v_loc              NUMBER := 0;

  v_html             VARCHAR2(32767);

BEGIN
  v_loc := 10;

  v_html := v_html||'<tr>'||g_row_header||p_row_heading||'</th>';
  v_html := v_html||g_row_detail||p_col0_val||'</td>';
  v_html := v_html||g_row_detail||p_col1_val;

  IF NVL(p_col0_val,' ') != NVL(p_col1_val,' ') AND
       p_change_flag THEN -- Display Change Icon
    v_html := v_html||g_change_image;
  END IF;

  v_html := v_html||'</td></tr>';

  RETURN v_html;
EXCEPTION
  WHEN OTHERS THEN
    v_error_msg := SQLERRM;
    process_error( module_name      => c_module
                 , status           => g_status_warning
                 , error_code       => SQLCODE
                 , error_message    => v_error_msg
                 , location         => v_loc
                 , label1           => 'Row Heading'
                 , reference1       => p_row_heading
                 , label2           => 'Current Value'
                 , reference2       => p_col0_val
                 , label3           => 'Proposed Value'
                 , reference3       => p_col1_val );

    RETURN v_html;
END build_row_html;


--
-- FUNCTION build_3_col_row_html /* 1.3 - 1 */
--   Description: This function will generate the HTML Row for the Assignment and
--                Pay Rate Transactions.
--   Arguments:
--        In: p_row_heading   => Heading Label for the row
--            p_col0_val      => Column Value for the 1st column
--            p_col1_val      => Column Value for the 2nd column
--            p_col1_val      => Column Value for the 3rd column
--    Return: HTML code for Row
--
FUNCTION build_3_col_row_html ( p_row_heading  IN  VARCHAR2
                              , p_col0_val     IN  VARCHAR2
                              , p_col1_val     IN  VARCHAR2
                              , p_col2_val     IN  VARCHAR2 ) RETURN VARCHAR2 IS

--START R12.2 Upgrade Remediation
  /*c_module           cust.ttec_error_handling.module_name%TYPE  := 'build_3_col_row_html';		-- Commented code by IXPRAVEEN-ARGANO, 04-May-2023
  v_error_msg        cust.ttec_error_handling.error_message%TYPE;*/
  c_module           apps.ttec_error_handling.module_name%TYPE  := 'build_3_col_row_html';			--  code Added by IXPRAVEEN-ARGANO, 04-May-2023
  v_error_msg        apps.ttec_error_handling.error_message%TYPE;
  --END R12.2.10 Upgrade remediation
  v_loc              NUMBER := 0;

  v_html             VARCHAR2(32767);

BEGIN
  v_loc := 10;

  v_html := v_html||'<tr>'||g_row_header||p_row_heading||'</th>';
  v_html := v_html||g_row_detail||p_col0_val||'</td>';
  v_html := v_html||g_row_detail||p_col1_val||'</td>';
  v_html := v_html||g_row_detail||p_col2_val;
  v_html := v_html||'</td></tr>';

  RETURN v_html;
EXCEPTION
  WHEN OTHERS THEN
    v_error_msg := SQLERRM;
    process_error( module_name      => c_module
                 , status           => g_status_warning
                 , error_code       => SQLCODE
                 , error_message    => v_error_msg
                 , location         => v_loc
                 , label1           => 'Row Heading'
                 , reference1       => p_row_heading
                 , label2           => '1st Col Value'
                 , reference2       => p_col0_val
                 , label3           => '2nd Col Value'
                 , reference3       => p_col1_val
                 , label4           => '3rd Col Value'
                 , reference4       => p_col2_val );

    RETURN v_html;
END build_3_col_row_html;


--
-- FUNCTION build_summary_html
--   Description: This function will generate the HTML for the Summary section which
--                will include Submitter and Employee Info.
--   Arguments:
--    Return: HTML code for Summary section
--
FUNCTION build_summary_html ( p_trx_id     IN  NUMBER
                            , p_ntf_type   IN  VARCHAR2
                            , p_itemtype   IN  VARCHAR2
                            , p_itemkey    IN  VARCHAR2 )
                            RETURN VARCHAR2 IS
--START R12.2 Upgrade Remediation
  /*c_module              cust.ttec_error_handling.module_name%TYPE  := 'build_summary_html';			-- Commented code by IXPRAVEEN-ARGANO, 04-May-2023
  v_error_msg           cust.ttec_error_handling.error_message%TYPE;*/
  c_module              apps.ttec_error_handling.module_name%TYPE  := 'build_summary_html';			--  code Added by IXPRAVEEN-ARGANO, 04-May-2023
  v_error_msg           apps.ttec_error_handling.error_message%TYPE;
  --END R12.2.10 Upgrade remediation
  v_loc                 NUMBER := 0;

  v_html                VARCHAR2(32767);

  v_submitter_id        NUMBER;
  v_submitter_name      per_all_people_f.full_name%TYPE;
  v_submitter_num       per_all_people_f.employee_number%TYPE;
  v_submitter_loc       hr_locations_all.location_code%TYPE;   /* 1.3 */
  v_employee_id         NUMBER;
  v_employee_name       per_all_people_f.full_name%TYPE;
  v_employee_num        per_all_people_f.employee_number%TYPE;
  v_employee_loc        hr_locations_all.location_code%TYPE;   /* 1.3 */

BEGIN
  v_loc := 10;

  /************************
  ** Get the Summary Values
  ************************/
  v_submitter_id := wf_engine.getitemattrnumber ( itemtype  => p_itemtype
                                                , itemkey   => p_itemkey
                                                , aname     => 'CREATOR_PERSON_ID' );

  get_employee_info ( p_employee_id    => v_submitter_id
                    , p_employee_name  => v_submitter_name
                    , p_employee_num   => v_submitter_num
                    , p_location_code  => v_submitter_loc );   /* 1.3 */

  v_employee_id  := wf_engine.getitemattrnumber ( itemtype  => p_itemtype
                                                , itemkey   => p_itemkey
                                                , aname     => 'CURRENT_PERSON_ID' );

  get_employee_info ( p_employee_id    => v_employee_id
                    , p_employee_name  => v_employee_name
                    , p_employee_num   => v_employee_num
                    , p_location_code  => v_employee_loc );   /* 1.3 */

  /************************
  ** Formatting Details
  ************************/
  v_loc := 20;

  -- Create Table Structure
  v_html := v_html||'<table cellpadding="0" cellspacing="0" border="0" width="75%"><tr>';
  v_html := v_html||'<td style="background-color:#9fa57d">';
  v_html := v_html||'<table style="" cellpadding="1" cellspacing="1" border="0" width="100%"> ';

  -- Column Headers
  v_html := v_html||'<tr>'||g_col_header||' width="1"><br></th>';
  v_html := v_html||        g_col_header||' width="25%">Name</th>';
  v_html := v_html||        g_col_header||' width="25%">Employee Number</th>';
  v_html := v_html||        g_col_header||' width="25%">Location</th></tr>';   /* 1.3 */

  /************************
  ** Row Details
  ************************/

  v_html := v_html||build_3_col_row_html( p_row_heading => 'Submitted By'
                                        , p_col0_val    => v_submitter_name
                                        , p_col1_val    => v_submitter_num
                                        , p_col2_val    => v_submitter_loc );   /* 1.3 */

  v_html := v_html||build_3_col_row_html( p_row_heading => 'For Employee'
                                        , p_col0_val    => v_employee_name
                                        , p_col1_val    => v_employee_num
                                        , p_col2_val    => v_employee_loc );   /* 1.3 */

  /************************
  ** End Tags
  ************************/
  v_html := v_html||'</table></td></tr></table>';

  RETURN v_html;
EXCEPTION
  WHEN OTHERS THEN
    v_error_msg := SQLERRM;
    process_error( module_name      => c_module
                 , status           => g_status_warning
                 , error_code       => SQLCODE
                 , error_message    => v_error_msg
                 , location         => v_loc
                 , trx_id           => p_trx_id
                 , ntf_type         => p_ntf_type );

    RETURN v_html;
END build_summary_html;


--
-- FUNCTION build_assignment_html
--   Description: This function will generate the HTML for the Assignment changes
--   Arguments:
--    Return: HTML code for Assignment section
--
FUNCTION build_assignment_html ( p_trx_id    IN  NUMBER
                               , p_api_name  IN  VARCHAR2
                               , p_ntf_type  IN  VARCHAR2)
                               RETURN VARCHAR2 IS

--START R12.2 Upgrade Remediation
  /*c_module              cust.ttec_error_handling.module_name%TYPE  := 'build_assignment_html';
  v_error_msg           cust.ttec_error_handling.error_message%TYPE;			-- Commented code by IXPRAVEEN-ARGANO, 04-May-2023
  v_loc                 NUMBER := 0;

  c_curr_type           VARCHAR2(10)    := 'ORIGINAL';
  c_new_type            VARCHAR2(10)    := 'CURRENT';

  v_html                VARCHAR2(32767);
  v_business_group_id   NUMBER;
  v_sec_grp_id          NUMBER;
  v_leg_code            per_business_groups_perf.legislation_code%TYPE;
  v_org_id              NUMBER;
  v_assign_id           NUMBER;

  v_curr_reason_code    cust.ttec_hr_api_trx_values.varchar2_value%TYPE;
  v_curr_reason         fnd_lookup_values.meaning%TYPE;
  v_curr_department     cust.ttec_hr_api_trx_values.varchar2_value%TYPE;
  v_curr_loc_id         NUMBER;
  v_curr_location       cust.ttec_hr_api_trx_values.varchar2_value%TYPE;
  v_curr_job            cust.ttec_hr_api_trx_values.varchar2_value%TYPE;
  v_curr_basis_id       NUMBER;
  v_curr_pay_basis      cust.ttec_hr_api_trx_values.varchar2_value%TYPE;
  v_curr_assg_cat_code  cust.ttec_hr_api_trx_values.varchar2_value%TYPE;
  v_curr_assg_cat       cust.ttec_hr_api_trx_values.varchar2_value%TYPE;
  v_curr_payroll_id     NUMBER;
  v_curr_payroll        cust.ttec_hr_api_trx_values.varchar2_value%TYPE;
  v_curr_sc_key_id      NUMBER;
  v_curr_gre            cust.ttec_hr_api_trx_values.varchar2_value%TYPE;
  v_curr_tc_req         cust.ttec_hr_api_trx_values.varchar2_value%TYPE;
  v_curr_work_sched     cust.ttec_hr_api_trx_values.varchar2_value%TYPE;
  v_curr_work_hours     NUMBER;
  v_curr_frequency      cust.ttec_hr_api_trx_values.varchar2_value%TYPE;

  -- PHL Values
  v_curr_prob_status    cust.ttec_hr_api_trx_values.varchar2_value%TYPE;
  v_curr_prob_unit_code cust.ttec_hr_api_trx_values.varchar2_value%TYPE;
  v_curr_prob_unit      cust.ttec_hr_api_trx_values.varchar2_value%TYPE;
  v_curr_prob_period    NUMBER;
  v_curr_prob_end       DATE;

  v_new_eff_date        DATE;
  v_new_reason_code     cust.ttec_hr_api_trx_values.varchar2_value%TYPE;
  v_new_reason          fnd_lookup_values.meaning%TYPE;
  v_new_department      cust.ttec_hr_api_trx_values.varchar2_value%TYPE;
  v_new_loc_id          NUMBER;
  v_new_location        cust.ttec_hr_api_trx_values.varchar2_value%TYPE;
  v_new_job             cust.ttec_hr_api_trx_values.varchar2_value%TYPE;
  v_new_basis_id        NUMBER;
  v_new_pay_basis       cust.ttec_hr_api_trx_values.varchar2_value%TYPE;
  v_new_assg_cat_code   cust.ttec_hr_api_trx_values.varchar2_value%TYPE;
  v_new_assg_cat        cust.ttec_hr_api_trx_values.varchar2_value%TYPE;
  v_new_payroll_id      NUMBER;
  v_new_payroll         cust.ttec_hr_api_trx_values.varchar2_value%TYPE;
  v_new_sc_key_id       NUMBER;
  v_new_gre             cust.ttec_hr_api_trx_values.varchar2_value%TYPE;
  v_new_tc_req          cust.ttec_hr_api_trx_values.varchar2_value%TYPE;
  v_new_work_sched      cust.ttec_hr_api_trx_values.varchar2_value%TYPE;
  v_new_work_hours      NUMBER;
  v_new_frequency       cust.ttec_hr_api_trx_values.varchar2_value%TYPE;

  -- PHL Values
  v_new_prob_status     cust.ttec_hr_api_trx_values.varchar2_value%TYPE;
  v_new_prob_unit_code  cust.ttec_hr_api_trx_values.varchar2_value%TYPE;
  v_new_prob_unit       cust.ttec_hr_api_trx_values.varchar2_value%TYPE;
  v_new_prob_period     NUMBER;
  v_new_prob_end        DATE; */
  
  c_module              apps.ttec_error_handling.module_name%TYPE  := 'build_assignment_html';
  v_error_msg           apps.ttec_error_handling.error_message%TYPE;			--  code Added by IXPRAVEEN-ARGANO, 04-May-2023
  v_loc                 NUMBER := 0;

  c_curr_type           VARCHAR2(10)    := 'ORIGINAL';
  c_new_type            VARCHAR2(10)    := 'CURRENT';

  v_html                VARCHAR2(32767);
  v_business_group_id   NUMBER;
  v_sec_grp_id          NUMBER;
  v_leg_code            per_business_groups_perf.legislation_code%TYPE;
  v_org_id              NUMBER;
  v_assign_id           NUMBER;

  v_curr_reason_code    apps.ttec_hr_api_trx_values.varchar2_value%TYPE;
  v_curr_reason         fnd_lookup_values.meaning%TYPE;
  v_curr_department     apps.ttec_hr_api_trx_values.varchar2_value%TYPE;
  v_curr_loc_id         NUMBER;
  v_curr_location       apps.ttec_hr_api_trx_values.varchar2_value%TYPE;
  v_curr_job            apps.ttec_hr_api_trx_values.varchar2_value%TYPE;
  v_curr_basis_id       NUMBER;
  v_curr_pay_basis      apps.ttec_hr_api_trx_values.varchar2_value%TYPE;
  v_curr_assg_cat_code  apps.ttec_hr_api_trx_values.varchar2_value%TYPE;
  v_curr_assg_cat       apps.ttec_hr_api_trx_values.varchar2_value%TYPE;
  v_curr_payroll_id     NUMBER;
  v_curr_payroll        apps.ttec_hr_api_trx_values.varchar2_value%TYPE;
  v_curr_sc_key_id      NUMBER;
  v_curr_gre            apps.ttec_hr_api_trx_values.varchar2_value%TYPE;
  v_curr_tc_req         apps.ttec_hr_api_trx_values.varchar2_value%TYPE;
  v_curr_work_sched     apps.ttec_hr_api_trx_values.varchar2_value%TYPE;
  v_curr_work_hours     NUMBER;
  v_curr_frequency      apps.ttec_hr_api_trx_values.varchar2_value%TYPE;

  -- PHL Values
  v_curr_prob_status    apps.ttec_hr_api_trx_values.varchar2_value%TYPE;
  v_curr_prob_unit_code apps.ttec_hr_api_trx_values.varchar2_value%TYPE;
  v_curr_prob_unit      apps.ttec_hr_api_trx_values.varchar2_value%TYPE;
  v_curr_prob_period    NUMBER;
  v_curr_prob_end       DATE;

  v_new_eff_date        DATE;
  v_new_reason_code     apps.ttec_hr_api_trx_values.varchar2_value%TYPE;
  v_new_reason          fnd_lookup_values.meaning%TYPE;
  v_new_department      apps.ttec_hr_api_trx_values.varchar2_value%TYPE;
  v_new_loc_id          NUMBER;
  v_new_location        apps.ttec_hr_api_trx_values.varchar2_value%TYPE;
  v_new_job             apps.ttec_hr_api_trx_values.varchar2_value%TYPE;
  v_new_basis_id        NUMBER;
  v_new_pay_basis       apps.ttec_hr_api_trx_values.varchar2_value%TYPE;
  v_new_assg_cat_code   apps.ttec_hr_api_trx_values.varchar2_value%TYPE;
  v_new_assg_cat        apps.ttec_hr_api_trx_values.varchar2_value%TYPE;
  v_new_payroll_id      NUMBER;
  v_new_payroll         apps.ttec_hr_api_trx_values.varchar2_value%TYPE;
  v_new_sc_key_id       NUMBER;
  v_new_gre             apps.ttec_hr_api_trx_values.varchar2_value%TYPE;
  v_new_tc_req          apps.ttec_hr_api_trx_values.varchar2_value%TYPE;
  v_new_work_sched      apps.ttec_hr_api_trx_values.varchar2_value%TYPE;
  v_new_work_hours      NUMBER;
  v_new_frequency       apps.ttec_hr_api_trx_values.varchar2_value%TYPE;

  -- PHL Values
  v_new_prob_status     apps.ttec_hr_api_trx_values.varchar2_value%TYPE;
  v_new_prob_unit_code  apps.ttec_hr_api_trx_values.varchar2_value%TYPE;
  v_new_prob_unit       apps.ttec_hr_api_trx_values.varchar2_value%TYPE;
  v_new_prob_period     NUMBER;
  v_new_prob_end        DATE;
  
  
--END R12.2.10 Upgrade remediation

  v_valid               BOOLEAN;
  v_kff_segments        fnd_flex_ext.SegmentArray;

  CURSOR c_location_name ( l_location_id NUMBER ) IS
    SELECT location_code
      --FROM hr.hr_locations_all		-- Commented code by IXPRAVEEN-ARGANO, 04-May-2023
	  FROM apps.hr_locations_all			--  code Added by IXPRAVEEN-ARGANO, 04-May-2023
     WHERE location_id = l_location_id;

  CURSOR c_pay_basis_name ( l_pay_basis_id NUMBER ) IS
    SELECT name
	--FROM hr.per_pay_bases				-- Commented code by IXPRAVEEN-ARGANO, 04-May-2023
      FROM apps.per_pay_bases				--  code Added by IXPRAVEEN-ARGANO, 04-May-2023
     WHERE pay_basis_id = l_pay_basis_id;

  CURSOR c_payroll_name ( l_payroll_id NUMBER ) IS
    SELECT payroll_name
	--FROM hr.pay_all_payrolls_f				-- Commented code by IXPRAVEEN-ARGANO, 04-May-2023
      FROM apps.pay_all_payrolls_f		--  code Added by IXPRAVEEN-ARGANO, 04-May-2023
     WHERE payroll_id = l_payroll_id;

  CURSOR c_change_reason_disp ( l_reason_code VARCHAR2
                              , l_sec_grp_id  NUMBER   ) IS
    SELECT meaning
      FROM fnd_lookup_values
     WHERE lookup_type = 'EMP_ASSIGN_REASON'
       AND lookup_code = l_reason_code
       AND security_group_id = NVL(l_sec_grp_id, 0)
       AND language = userenv('LANG');

  CURSOR c_asg_category ( l_category_code VARCHAR2
                        , l_sec_grp_id  NUMBER   ) IS
    SELECT meaning
      FROM hr_leg_lookups
     WHERE lookup_type = 'EMP_CAT'
       AND lookup_code = l_category_code;

  CURSOR c_probation_unit ( l_probation_code VARCHAR2 ) IS
    SELECT meaning
      FROM fnd_lookup_values
     WHERE lookup_type = 'QUALIFYING_UNITS'
       AND language = userenv('LANG');

BEGIN
  v_loc := 10;

  /****************************
  ** Initialize Session Values
  ****************************/
  -- Initialize the Global Variable for the Soft Coding Keyflex
  v_business_group_id := get_num_val(p_trx_id, p_api_name, c_curr_type, 'P_BUSINESS_GROUP_ID');
  v_org_id            := get_num_val(p_trx_id, p_api_name, c_curr_type, 'P_ORGANIZATION_ID');
  v_assign_id         := get_num_val(p_trx_id, p_api_name, c_curr_type, 'P_ASSIGNMENT_ID');

  -- Set the Security Group ID appropriately for the Employee being processed.
  hr_api.validate_bus_grp_id(v_business_group_id);

  -- Set the Legislative Context for the Employee being processed
  v_leg_code := hr_api.return_legislation_code(v_business_group_id);
  hr_api.set_legislation_context(v_leg_code);

  v_valid := ttec_hr_wf_custom.init_sc_kff ( p_business_group_id   => v_business_group_id );

  IF NOT v_valid THEN
    v_error_msg := 'Unable to Initialize SC KFF';
    process_error( module_name      => c_module
                 , status           => g_status_warning
                 , error_code       => NULL
                 , error_message    => v_error_msg
                 , location         => v_loc
                 , trx_id           => p_trx_id
                 , ntf_type         => p_ntf_type
                 , label1           => 'Trx API Name'
                 , reference1       => p_api_name );
  END IF;

  -- Initialize Session Profiles
  v_valid := ttec_hr_wf_custom.init_session_vars( p_bus_grp_id => v_business_group_id
                                                , p_org_id     => v_org_id
                                                , p_asgn_id    => v_assign_id );

  IF NOT v_valid THEN
    v_error_msg := 'Encountered Error initializing session profiles';
    process_error( module_name      => c_module
                 , status           => g_status_warning
                 , error_code       => NULL
                 , error_message    => v_error_msg
                 , location         => v_loc
                 , trx_id           => p_trx_id
                 , ntf_type         => p_ntf_type
                 , label1           => 'Trx API Name'
                 , reference1       => p_api_name );
  END IF;

  v_sec_grp_id := get_sec_grp_id(v_business_group_id);

  /************************
  ** Get the Trx Values
  ************************/

  v_new_eff_date       := get_date_val(p_trx_id, p_api_name, c_new_type,  'P_EFFECTIVE_DATE'); /* 1.1 (2) */
  v_curr_reason_code   := get_text_val(p_trx_id, p_api_name, c_curr_type, 'P_CHANGE_REASON');
  v_new_reason_code    := get_text_val(p_trx_id, p_api_name, c_new_type,  'P_CHANGE_REASON');
  v_curr_department    := get_text_val(p_trx_id, p_api_name, c_curr_type, 'P_ORG_NAME');
  v_new_department     := get_text_val(p_trx_id, p_api_name, c_new_type,  'P_ORG_NAME');
  v_curr_loc_id        := get_num_val (p_trx_id, p_api_name, c_curr_type, 'P_LOCATION_ID');
  v_new_loc_id         := get_num_val (p_trx_id, p_api_name, c_new_type,  'P_LOCATION_ID');
  v_curr_job           := get_text_val(p_trx_id, p_api_name, c_curr_type, 'P_JOB_NAME');
  v_new_job            := get_text_val(p_trx_id, p_api_name, c_new_type,  'P_JOB_NAME');
  v_curr_basis_id      := get_num_val (p_trx_id, p_api_name, c_curr_type, 'P_PAY_BASIS_ID');
  v_new_basis_id       := get_num_val (p_trx_id, p_api_name, c_new_type,  'P_PAY_BASIS_ID');
  v_curr_assg_cat_code := get_text_val(p_trx_id, p_api_name, c_curr_type, 'P_EMPLOYMENT_CATEGORY');
  v_new_assg_cat_code  := get_text_val(p_trx_id, p_api_name, c_new_type,  'P_EMPLOYMENT_CATEGORY');
  v_curr_payroll_id    := get_num_val (p_trx_id, p_api_name, c_curr_type, 'P_PAYROLL_ID');
  v_new_payroll_id     := get_num_val (p_trx_id, p_api_name, c_new_type,  'P_PAYROLL_ID');
  v_curr_sc_key_id     := get_num_val (p_trx_id, p_api_name, c_curr_type, 'P_SOFT_CODING_KEYFLEX_ID');
  v_new_sc_key_id      := get_num_val (p_trx_id, p_api_name, c_new_type,  'P_SOFT_CODING_KEYFLEX_ID');
  v_curr_work_hours    := get_num_val (p_trx_id, p_api_name, c_curr_type, 'P_NORMAL_HOURS');
  v_new_work_hours     := get_num_val (p_trx_id, p_api_name, c_new_type,  'P_NORMAL_HOURS');
  v_curr_frequency     := get_text_val(p_trx_id, p_api_name, c_curr_type, 'P_FREQUENCY');
  v_new_frequency      := get_text_val(p_trx_id, p_api_name, c_new_type,  'P_FREQUENCY');

  -- PHL Trx Values
  v_curr_prob_status   := get_text_val(p_trx_id, p_api_name, c_curr_type, 'P_ASS_ATTRIBUTE6');
  v_new_prob_status    := get_text_val(p_trx_id, p_api_name, c_new_type,  'P_ASS_ATTRIBUTE6');
  v_curr_prob_unit_code:= get_text_val(p_trx_id, p_api_name, c_curr_type, 'P_PROBATION_UNIT');
  v_new_prob_unit_code := get_text_val(p_trx_id, p_api_name, c_new_type,  'P_PROBATION_UNIT');
  v_curr_prob_period   := get_num_val (p_trx_id, p_api_name, c_curr_type, 'P_PROBATION_PERIOD');
  v_new_prob_period    := get_num_val (p_trx_id, p_api_name, c_new_type,  'P_PROBATION_PERIOD');
  v_curr_prob_end      := get_date_val(p_trx_id, p_api_name, c_curr_type, 'P_DATE_PROBATION_END');
  v_new_prob_end       := get_date_val(p_trx_id, p_api_name, c_new_type,  'P_DATE_PROBATION_END');

  /************************
  ** Lookup Display Values
  ************************/
  v_loc := 20;

  -- Get the Change Reason Display
  OPEN c_change_reason_disp (v_curr_reason_code, v_sec_grp_id);
  FETCH c_change_reason_disp INTO v_curr_reason;
  CLOSE c_change_reason_disp;

  OPEN c_change_reason_disp (v_new_reason_code, v_sec_grp_id);
  FETCH c_change_reason_disp INTO v_new_reason;
  CLOSE c_change_reason_disp;

  -- Get the Location Name
  OPEN c_location_name (v_curr_loc_id);
  FETCH c_location_name INTO v_curr_location;
  CLOSE c_location_name;

  OPEN c_location_name (v_new_loc_id);
  FETCH c_location_name INTO v_new_location;
  CLOSE c_location_name;

  -- Get the Pay Basis Name
  OPEN c_pay_basis_name (v_curr_basis_id);
  FETCH c_pay_basis_name INTO v_curr_pay_basis;
  CLOSE c_pay_basis_name;

  OPEN c_pay_basis_name (v_new_basis_id);
  FETCH c_pay_basis_name INTO v_new_pay_basis;
  CLOSE c_pay_basis_name;

  -- Get the Payroll Name
  OPEN c_payroll_name (v_curr_payroll_id);
  FETCH c_payroll_name INTO v_curr_payroll;
  CLOSE c_payroll_name;

  OPEN c_payroll_name (v_new_payroll_id);
  FETCH c_payroll_name INTO v_new_payroll;
  CLOSE c_payroll_name;

  -- Get the Assignment Category
  OPEN c_asg_category (v_curr_assg_cat_code, v_sec_grp_id);
  FETCH c_asg_category INTO v_curr_assg_cat;
  CLOSE c_asg_category;

  OPEN c_asg_category (v_new_assg_cat_code, v_sec_grp_id);
  FETCH c_asg_category INTO v_new_assg_cat;
  CLOSE c_asg_category;

  -- Get the PHL Probation Period Unit
  OPEN c_probation_unit (v_curr_prob_unit_code);
  FETCH c_probation_unit INTO v_curr_prob_unit;
  CLOSE c_probation_unit;

  OPEN c_probation_unit (v_new_prob_unit_code);
  FETCH c_probation_unit INTO v_new_prob_unit;
  CLOSE c_probation_unit;

  -- Get the Gre/TimeCard Required/Work Schedule from the Soft Coded Keyflex ID
  v_loc := 30;
  v_valid := ttec_hr_wf_custom.get_sc_kff( p_sc_keyflex_id     => v_curr_sc_key_id
                                         , p_kff_segments      => v_kff_segments );

  v_curr_gre         := v_kff_segments(1);

  -- Soft Coded Segments are returned in order DISPLAYED
  IF v_business_group_id = 325 THEN          -- US
    v_curr_tc_req      := v_kff_segments(3);
    v_curr_work_sched  := v_kff_segments(4);
  ELSIF v_business_group_id = 326 THEN       -- CAN
    v_curr_tc_req      := v_kff_segments(5);
    v_curr_work_sched  := v_kff_segments(6);
  END IF;

  v_valid := ttec_hr_wf_custom.get_sc_kff( p_sc_keyflex_id     => v_new_sc_key_id
                                         , p_kff_segments      => v_kff_segments );

  v_new_gre          := v_kff_segments(1);

  IF v_business_group_id = 325 THEN          -- US
    v_new_tc_req      := v_kff_segments(3);
    v_new_work_sched  := v_kff_segments(4);
  ELSIF v_business_group_id = 326 THEN       -- CAN
    v_new_tc_req      := v_kff_segments(5);
    v_new_work_sched  := v_kff_segments(6);
  END IF;

  /************************
  ** Formatting Details
  ************************/
  v_loc := 40;

  -- Create Table Structure
  v_html := v_html||'<table cellpadding="0" cellspacing="0" border="0" width="75%"><tr>';
  v_html := v_html||'<td style="background-color:#9fa57d">';
  v_html := v_html||'<table style="" cellpadding="1" cellspacing="1" border="0" width="100%"> ';

  -- Column Headers
  v_html := v_html||'<tr>'||g_col_header||' width="1"><br></th>';
  v_html := v_html||        g_col_header||' width="36%">Current</th>';
  v_html := v_html||        g_col_header||' width="36%">Proposed</th></tr>';

  /************************
  ** Row Details
  ************************/

  /* 1.1 (2) */
  v_html := v_html||build_row_html( p_row_heading => 'Transaction Effective Date'
                                  , p_col0_val    => NULL
                                  , p_col1_val    => v_new_eff_date
                                  , p_change_flag => TRUE );

  v_html := v_html||build_row_html( p_row_heading => 'Change Reason'
                                  , p_col0_val    => v_curr_reason
                                  , p_col1_val    => v_new_reason
                                  , p_change_flag => TRUE );

  v_html := v_html||build_row_html( p_row_heading => 'Department'
                                  , p_col0_val    => v_curr_department
                                  , p_col1_val    => v_new_department
                                  , p_change_flag => TRUE );

  v_html := v_html||build_row_html( p_row_heading => 'Location'
                                  , p_col0_val    => v_curr_location
                                  , p_col1_val    => v_new_location
                                  , p_change_flag => TRUE );

  v_html := v_html||build_row_html( p_row_heading => 'Job'
                                  , p_col0_val    => v_curr_job
                                  , p_col1_val    => v_new_job
                                  , p_change_flag => TRUE );

  IF v_business_group_id IN (325, 326) THEN    -- Only display for US / CAN
    v_html := v_html||build_row_html( p_row_heading => 'Salary Basis'
                                    , p_col0_val    => v_curr_pay_basis
                                    , p_col1_val    => v_new_pay_basis
                                    , p_change_flag => TRUE );

    v_html := v_html||build_row_html( p_row_heading => 'Assignment Category'
                                    , p_col0_val    => v_curr_assg_cat
                                    , p_col1_val    => v_new_assg_cat
                                    , p_change_flag => TRUE );

    v_html := v_html||build_row_html( p_row_heading => 'Payroll Name'
                                    , p_col0_val    => v_curr_payroll
                                    , p_col1_val    => v_new_payroll
                                    , p_change_flag => TRUE );
  END IF;

  v_html := v_html||build_row_html( p_row_heading => 'GRE'
                                  , p_col0_val    => v_curr_gre
                                  , p_col1_val    => v_new_gre
                                  , p_change_flag => TRUE );

  IF v_curr_tc_req IS NOT NULL OR v_new_tc_req IS NOT NULL THEN
    v_html := v_html||build_row_html( p_row_heading => 'TimeCard Required'
                                    , p_col0_val    => v_curr_tc_req
                                    , p_col1_val    => v_new_tc_req
                                    , p_change_flag => TRUE );
  END IF;

  IF v_curr_work_sched IS NOT NULL OR v_new_work_sched IS NOT NULL THEN
    v_html := v_html||build_row_html( p_row_heading => 'Work Schedule'
                                    , p_col0_val    => v_curr_work_sched
                                    , p_col1_val    => v_new_work_sched
                                    , p_change_flag => TRUE );
  END IF;

  v_html := v_html||build_row_html( p_row_heading => 'Work Hours'
                                  , p_col0_val    => v_curr_work_hours
                                  , p_col1_val    => v_new_work_hours
                                  , p_change_flag => TRUE );

  v_html := v_html||build_row_html( p_row_heading => 'Frequency'
                                  , p_col0_val    => v_curr_frequency
                                  , p_col1_val    => v_new_frequency
                                  , p_change_flag => TRUE );

  IF v_business_group_id = 1517 THEN     -- Only display for PHL
    v_html := v_html||build_row_html( p_row_heading => 'Probation Status'
                                    , p_col0_val    => v_curr_prob_status
                                    , p_col1_val    => v_new_prob_status
                                    , p_change_flag => TRUE );

    v_html := v_html||build_row_html( p_row_heading => 'Probation Units'
                                    , p_col0_val    => v_curr_prob_unit
                                    , p_col1_val    => v_new_prob_unit
                                    , p_change_flag => TRUE );

    v_html := v_html||build_row_html( p_row_heading => 'Probation Length'
                                    , p_col0_val    => v_curr_prob_period
                                    , p_col1_val    => v_new_prob_period
                                    , p_change_flag => TRUE );

    v_html := v_html||build_row_html( p_row_heading => 'Probation End Date'
                                    , p_col0_val    => v_curr_prob_end
                                    , p_col1_val    => v_new_prob_end
                                    , p_change_flag => TRUE );
  END IF;

  /************************
  ** End Tags
  ************************/
  v_html := v_html||'</table></td></tr></table>';

  RETURN v_html;
EXCEPTION
  WHEN OTHERS THEN
    v_error_msg := SQLERRM;
    process_error( module_name      => c_module
                 , status           => g_status_warning
                 , error_code       => SQLCODE
                 , error_message    => v_error_msg
                 , location         => v_loc
                 , trx_id           => p_trx_id
                 , ntf_type         => p_ntf_type
                 , label1           => 'Trx API Name'
                 , reference1       => p_api_name );

    RETURN v_html;
END build_assignment_html;


--
-- FUNCTION build_pay_rate_html
--   Description: This function will generate the HTML for the Pay Rate changes
--   Arguments:
--    Return: HTML code for Pay Rate section
--
FUNCTION build_pay_rate_html ( p_trx_id    IN  NUMBER
                             , p_api_name  IN  VARCHAR2
                             , p_ntf_type  IN  VARCHAR2)
                             RETURN VARCHAR2 IS

--START R12.2 Upgrade Remediation
  /*c_module           cust.ttec_error_handling.module_name%TYPE  := 'build_pay_rate_html';		-- Commented code by IXPRAVEEN-ARGANO, 04-May-2023
  v_error_msg        cust.ttec_error_handling.error_message%TYPE;
  v_loc              NUMBER := 0;

  v_html             VARCHAR2(32767);
  c_col_type         VARCHAR2(10)    := 'CURRENT';

  v_bg_id            NUMBER;
  v_sec_grp_id       NUMBER;
  v_reason_code      cust.ttec_hr_api_trx_values.varchar2_value%TYPE;
  v_reason           fnd_lookup_values.meaning%TYPE;

  v_perf_inc         NUMBER;
  v_curr_pay_rate    NUMBER;
  v_new_pay_rate     NUMBER;
  v_curr_pay_annual  NUMBER;
  v_new_pay_annual   NUMBER;
  v_currency         cust.ttec_hr_api_trx_values.varchar2_value%TYPE;
  v_pay_factor       NUMBER;
  v_format_string    cust.ttec_hr_api_trx_values.varchar2_value%TYPE;
  v_eff_date         DATE;
  v_comments         cust.ttec_hr_api_trx_values.varchar2_value%TYPE;*/

  c_module           apps.ttec_error_handling.module_name%TYPE  := 'build_pay_rate_html';		--  code Added by IXPRAVEEN-ARGANO, 04-May-2023
  v_error_msg        apps.ttec_error_handling.error_message%TYPE;
  v_loc              NUMBER := 0;

  v_html             VARCHAR2(32767);
  c_col_type         VARCHAR2(10)    := 'CURRENT';

  v_bg_id            NUMBER;
  v_sec_grp_id       NUMBER;
  v_reason_code      apps.ttec_hr_api_trx_values.varchar2_value%TYPE;
  v_reason           fnd_lookup_values.meaning%TYPE;

  v_perf_inc         NUMBER;
  v_curr_pay_rate    NUMBER;
  v_new_pay_rate     NUMBER;
  v_curr_pay_annual  NUMBER;
  v_new_pay_annual   NUMBER;
  v_currency         apps.ttec_hr_api_trx_values.varchar2_value%TYPE;
  v_pay_factor       NUMBER;
  v_format_string    apps.ttec_hr_api_trx_values.varchar2_value%TYPE;
  v_eff_date         DATE;
  v_comments         apps.ttec_hr_api_trx_values.varchar2_value%TYPE;
  
  --END R12.2.10 Upgrade remediation 

  CURSOR c_reason_disp ( l_reason_code VARCHAR2
                       , l_sec_grp_id  NUMBER   ) IS
    SELECT meaning
      FROM fnd_lookup_values
     WHERE lookup_type = 'PROPOSAL_REASON'
       AND lookup_code = l_reason_code
       AND attribute1 = 'SS_PAYCHG'
       AND security_group_id = NVL(l_sec_grp_id, 0)
       AND language = userenv('LANG');

BEGIN
  v_loc := 10;

  /****************************
  ** Initialize Session Values
  ****************************/
  -- Initialize the Global Variable for the Soft Coding Keyflex
  v_bg_id        := get_num_val (p_trx_id, p_api_name, c_col_type, 'P_BUS_GROUP_ID');
  v_reason_code  := get_text_val(p_trx_id, p_api_name, c_col_type, 'P_PROPOSAL_REASON');
  v_sec_grp_id   := get_sec_grp_id(v_bg_id);

  -- Get the Change Reason Display
  OPEN c_reason_disp (v_reason_code, v_sec_grp_id);
  FETCH c_reason_disp INTO v_reason;
  CLOSE c_reason_disp;

  /************************
  ** Get the Trx Values
  ************************/
  v_loc := 15;

  v_perf_inc        := get_num_val (p_trx_id, p_api_name, c_col_type, 'P_CHANGE_AMOUNT');
  v_curr_pay_rate   := get_num_val (p_trx_id, p_api_name, c_col_type, 'P_CURRENT_SALARY');
  v_new_pay_rate    := get_num_val (p_trx_id, p_api_name, c_col_type, 'P_PROPOSED_SALARY');
  v_pay_factor      := get_num_val (p_trx_id, p_api_name, c_col_type, 'P_DEFAULT_PAY_ANNUAL_FACTOR');
  v_new_pay_annual  := get_num_val (p_trx_id, p_api_name, c_col_type, 'P_ANNUAL_EQUIVALENT');
  v_format_string   := get_text_val(p_trx_id, p_api_name, c_col_type, 'P_DEFAULT_FORMAT_STRING');
  v_currency        := get_text_val(p_trx_id, p_api_name, c_col_type, 'P_CURRENCY');
  v_eff_date        := get_date_val(p_trx_id, p_api_name, c_col_type, 'P_EFFECTIVE_DATE');
  v_comments        := get_text_val(p_trx_id, p_api_name, c_col_type, 'P_COMMENTS');

  v_curr_pay_annual := v_curr_pay_rate * v_pay_factor;

  /************************
  ** Formatting Details
  ************************/
  v_loc := 20;

  -- Create Table Structure
  v_html := v_html||'<table cellpadding="0" cellspacing="0" border="0" width="75%"><tr>';
  v_html := v_html||'<td style="background-color:#9fa57d">';
  v_html := v_html||'<table style="" cellpadding="1" cellspacing="1" border="0" width="100%"> ';

  -- Column Headers
  v_html := v_html||'<tr>'||g_col_header||' width="1"><br></th>';
  v_html := v_html||        g_col_header||' width="36%">Current</th>';
  v_html := v_html||        g_col_header||' width="36%">Proposed</th></tr>';

  /************************
  ** Row Details
  ************************/

  v_html := v_html||build_row_html( p_row_heading => v_reason
                                  , p_col0_val    => NULL
                                  , p_col1_val    => TO_CHAR(v_perf_inc,v_format_string)||' '||v_currency
                                  , p_change_flag => TRUE );

  v_html := v_html||build_row_html( p_row_heading => 'Pay Rate'
                                  , p_col0_val    => TO_CHAR(v_curr_pay_rate,v_format_string)||' '||v_currency
                                  , p_col1_val    => TO_CHAR(v_new_pay_rate,v_format_string) ||' '||v_currency
                                  , p_change_flag => TRUE );

  v_html := v_html||build_row_html( p_row_heading => 'Pay Rate ( Annual Equivalent )'
                                  , p_col0_val    => TO_CHAR(v_curr_pay_annual,v_format_string)||' '||v_currency
                                  , p_col1_val    => TO_CHAR(v_new_pay_annual,v_format_string) ||' '||v_currency
                                  , p_change_flag => TRUE );

  v_html := v_html||build_row_html( p_row_heading => 'Salary Effective Date'
                                  , p_col0_val    => NULL
                                  , p_col1_val    => v_eff_date
                                  , p_change_flag => TRUE );

  v_html := v_html||build_row_html( p_row_heading => 'Justification for Increase'
                                  , p_col0_val    => NULL
                                  , p_col1_val    => v_comments
                                  , p_change_flag => TRUE );

  /************************
  ** End Tags
  ************************/
  v_html := v_html||'</table></td></tr></table>';

  RETURN v_html;
EXCEPTION
  WHEN OTHERS THEN
    v_error_msg := SQLERRM;
    process_error( module_name      => c_module
                 , status           => g_status_warning
                 , error_code       => SQLCODE
                 , error_message    => v_error_msg
                 , location         => v_loc
                 , trx_id           => p_trx_id
                 , ntf_type         => p_ntf_type
                 , label1           => 'Trx API Name'
                 , reference1       => p_api_name );

    RETURN v_html;
END build_pay_rate_html;


--
-- FUNCTION build_termination_html
--   Description: This function will generate the HTML for the Termination Details
--   Arguments:
--    Return: HTML code for Termination section
--
FUNCTION build_termination_html ( p_trx_id    IN  NUMBER
                                , p_api_name  IN  VARCHAR2
                                , p_ntf_type  IN  VARCHAR2 )
                                RETURN VARCHAR2 IS

--START R12.2 Upgrade Remediation
  /*c_module           cust.ttec_error_handling.module_name%TYPE  := 'build_termination_html';		-- Commented code by IXPRAVEEN-ARGANO, 04-May-2023
  v_error_msg        cust.ttec_error_handling.error_message%TYPE;
  v_loc              NUMBER := 0;

  v_html             VARCHAR2(32767);
  c_col_type         VARCHAR2(10)    := 'CURRENT';

  v_term_date        DATE;
  v_notif_date       DATE;
  v_reason_code      cust.ttec_hr_api_trx_values.varchar2_value%TYPE;
  v_reason           cust.ttec_hr_api_trx_values.varchar2_value%TYPE;
  v_last_day         cust.ttec_hr_api_trx_values.varchar2_value%TYPE;
  v_rehire           cust.ttec_hr_api_trx_values.varchar2_value%TYPE;
  v_interview        cust.ttec_hr_api_trx_values.varchar2_value%TYPE;*/
  
  c_module           apps.ttec_error_handling.module_name%TYPE  := 'build_termination_html';		--  code Added by IXPRAVEEN-ARGANO, 04-May-2023
  v_error_msg        apps.ttec_error_handling.error_message%TYPE;
  v_loc              NUMBER := 0;

  v_html             VARCHAR2(32767);
  c_col_type         VARCHAR2(10)    := 'CURRENT';

  v_term_date        DATE;
  v_notif_date       DATE;
  v_reason_code      apps.ttec_hr_api_trx_values.varchar2_value%TYPE;
  v_reason           apps.ttec_hr_api_trx_values.varchar2_value%TYPE;
  v_last_day         apps.ttec_hr_api_trx_values.varchar2_value%TYPE;
  v_rehire           apps.ttec_hr_api_trx_values.varchar2_value%TYPE;
  v_interview        apps.ttec_hr_api_trx_values.varchar2_value%TYPE;
--END R12.2.10 Upgrade remediation
  v_pos_id           NUMBER;
  v_bg_id            NUMBER;
  v_sec_grp_id       NUMBER;

  CURSOR c_get_leave_reason ( l_reason_code VARCHAR2
                            , l_sec_grp_id  NUMBER   ) IS
    SELECT meaning
      FROM fnd_lookup_values
     WHERE lookup_type = 'LEAV_REAS'
       AND lookup_code = l_reason_code
       AND security_group_id = NVL(l_sec_grp_id, 0) /* 1.1 (1) */
       AND language = userenv('LANG');

BEGIN
  v_loc := 10;

  -- Get the Trx Values to display
  v_term_date    := get_date_val (p_trx_id, p_api_name, c_col_type, 'P_ACTUAL_TERMINATION_DATE');
  v_notif_date   := get_date_val (p_trx_id, p_api_name, c_col_type, 'P_NOTIFIED_TERMINATION_DATE');
  v_reason_code  := get_text_val (p_trx_id, p_api_name, c_col_type, 'P_LEAVING_REASON');
  v_last_day     := get_text_val (p_trx_id, p_api_name, c_col_type, 'P_ATTRIBUTE1');
  v_rehire       := get_text_val (p_trx_id, p_api_name, c_col_type, 'P_ATTRIBUTE9');
  v_interview    := get_text_val (p_trx_id, p_api_name, c_col_type, 'P_ATTRIBUTE10');
  v_pos_id       := get_num_val  (p_trx_id, p_api_name, c_col_type, 'P_PERIOD_OF_SERVICE_ID');

  /************************
  ** Lookup Display Values
  ************************/
  v_loc := 20;

  -- Get the BG ID and Sec Grp ID /* 1.1 (1) */
  BEGIN
    SELECT business_group_id
      INTO v_bg_id
      FROM per_periods_of_service
     WHERE period_of_service_id = v_pos_id;

    v_sec_grp_id   := get_sec_grp_id(v_bg_id);
  EXCEPTION
    WHEN OTHERS THEN
      v_sec_grp_id := 0;
  END;

  v_loc := 25;
  -- Get the Leave Reason
  OPEN c_get_leave_reason (v_reason_code, v_sec_grp_id);
  FETCH c_get_leave_reason INTO v_reason;
  CLOSE c_get_leave_reason;

  -- Reformat Last Day
  v_last_day := TO_CHAR(TO_DATE(v_last_day,'YYYY/MM/DD HH24:MI:SS'),'DD-MON-YYYY');

  -- Reformat Eligible for Rehire
  IF v_rehire = 'Y' THEN
    v_rehire := 'Yes';
  ELSIF v_rehire = 'N' THEN
    v_rehire := 'No';
  END IF;

  /************************
  ** Formatting Details
  ************************/
  v_loc := 30;

  -- Create Table Structure (No Headings)
  v_html := v_html||'<table cellpadding="0" cellspacing="0" border="0" width="50%"><tr>';
  v_html := v_html||'<td style="background-color:#9fa57d">';
  v_html := v_html||'<table style="" cellpadding="1" cellspacing="1" border="0" width="100%"> ';

  /************************
  ** Row Details
  ************************/
  v_html := v_html||'<tr>'||g_row_header||'Termination Date</th>';
  v_html := v_html||g_row_detail||v_term_date||'</td></tr>';

  v_loc := 40;
  -- Only include this information in the FYI to Human Capital.
  IF p_ntf_type IN ('HC','SMGR') THEN
    v_html := v_html||'<tr>'||g_row_header||'Notification Date</th>';
    v_html := v_html||g_row_detail||v_notif_date||'</td></tr>';
    v_html := v_html||'<tr>'||g_row_header||'Reason</th>';
    v_html := v_html||g_row_detail||v_reason||'</td></tr>';
    v_html := v_html||'<tr>'||g_row_header||'Last Physical Day at Work</th>';
    v_html := v_html||g_row_detail||v_last_day||'</td></tr>';
    v_html := v_html||'<tr>'||g_row_header||'Eligible for Rehire</th>';
    v_html := v_html||g_row_detail||v_rehire||'</td></tr>';
    v_html := v_html||'<tr>'||g_row_header||'Exit Interview Completed?</th>';
    v_html := v_html||g_row_detail||v_interview||'</td></tr>';
  END IF;

  /************************
  ** End Tags
  ************************/
  v_html := v_html||'</table></td></tr></table>';

  RETURN v_html;
EXCEPTION
  WHEN OTHERS THEN
    v_error_msg := SQLERRM;
    process_error( module_name      => c_module
                 , status           => g_status_warning
                 , error_code       => SQLCODE
                 , error_message    => v_error_msg
                 , location         => v_loc
                 , trx_id           => p_trx_id
                 , ntf_type         => p_ntf_type
                 , label1           => 'Trx API Name'
                 , reference1       => p_api_name );

    RETURN v_html;
END build_termination_html;


--
-- FUNCTION build_new_manager_html
--   Description: This function will generate the HTML for the New Manager Changes
--   Arguments:
--    Return: HTML code for New Manager section
--
FUNCTION build_new_manager_html ( p_trx_id    IN  NUMBER
                                , p_api_name  IN  VARCHAR2
                                , p_ntf_type  IN  VARCHAR2)
                                RETURN VARCHAR2 IS

--START R12.2 Upgrade Remediation
/*  c_module           cust.ttec_error_handling.module_name%TYPE  := 'build_new_manager_html';		-- Commented code by IXPRAVEEN-ARGANO, 04-May-2023
  v_error_msg        cust.ttec_error_handling.error_message%TYPE;
  v_loc              NUMBER := 0;

  v_html             VARCHAR2(32767);
  c_col_type         VARCHAR2(10)    := 'CURRENT';
  v_header_label     VARCHAR2(25)    := 'New Manager';

  v_emp_name         cust.ttec_hr_api_trx_values.varchar2_value%TYPE;
  v_curr_mgr_name    cust.ttec_hr_api_trx_values.varchar2_value%TYPE;
  v_new_mgr_name     cust.ttec_hr_api_trx_values.varchar2_value%TYPE;*/
  
  c_module           apps.ttec_error_handling.module_name%TYPE  := 'build_new_manager_html';		--  code Added by IXPRAVEEN-ARGANO, 04-May-2023
  v_error_msg        apps.ttec_error_handling.error_message%TYPE;
  v_loc              NUMBER := 0;

  v_html             VARCHAR2(32767);
  c_col_type         VARCHAR2(10)    := 'CURRENT';
  v_header_label     VARCHAR2(25)    := 'New Manager';

  v_emp_name         apps.ttec_hr_api_trx_values.varchar2_value%TYPE;
  v_curr_mgr_name    apps.ttec_hr_api_trx_values.varchar2_value%TYPE;
  v_new_mgr_name     apps.ttec_hr_api_trx_values.varchar2_value%TYPE;
  --END R12.2.10 Upgrade remediation
  v_eff_date         DATE;
  v_term_flag        VARCHAR2(5);

BEGIN
  v_loc := 10;

  -- Determine if this is a Termination Transaction (ie Display Reassigned only)
  v_term_flag      := get_text_val (p_trx_id, p_api_name, c_col_type, 'P_TERM_FLAG');

  -- Get the Trx Values to display
  v_emp_name       := get_text_val (p_trx_id, p_api_name, c_col_type, 'P_SELECTED_EMP_NAME');
  v_curr_mgr_name  := get_text_val (p_trx_id, p_api_name, c_col_type, 'P_SELECTED_PERSON_OLD_SUP_NAME');
  v_new_mgr_name   := get_text_val (p_trx_id, p_api_name, c_col_type, 'P_SELECTED_PERSON_SUP_NAME');
  v_eff_date       := get_date_val (p_trx_id, p_api_name, c_col_type, 'P_PASSED_EFFECTIVE_DATE');

  -- Only Display the Manager section if not a Termination Transaction
  -- AND the employees Mgr changed (vs. Changed Mgrs for Direct Reports)
  IF NVL(v_term_flag,'N') = 'N'
     AND NVL(v_curr_mgr_name,' ') != NVL(v_new_mgr_name,' ') THEN

    /************************
    ** Formatting Details
    ************************/
    v_loc := 20;

    -- Create Section Header
    v_html := v_html||build_hdr_html ( p_header_label  => v_header_label );

    -- Create Table Structure
    v_html := v_html||'<table cellpadding="0" cellspacing="0" border="0" width="85%"><tr>';
    v_html := v_html||'<td style="background-color:#9fa57d">';
    v_html := v_html||'<table style="" cellpadding="1" cellspacing="1" border="0" width="100%"> ';

    -- Column Headers
    v_html := v_html||'<tr>'||g_col_header||'>Worker Name</th>';
    v_html := v_html||        g_col_header||'>Current Manager Name</th>';
    v_html := v_html||        g_col_header||'>Proposed Manager Name</th>';
    v_html := v_html||        g_col_header||'>Effective Transfer Date</th></tr>';

    /************************
    ** Row Details
    ************************/
    v_loc := 30;

    v_html := v_html||'<tr>'||g_row_detail||v_emp_name||'</td>';
    v_html := v_html||g_row_detail||v_curr_mgr_name||'</td>';
    v_html := v_html||g_row_detail||v_new_mgr_name;

    IF NVL(v_new_mgr_name, ' ') != NVL(v_curr_mgr_name, ' ') THEN
      v_html := v_html||g_change_image;
    END IF;

    v_html := v_html||'</td>'||g_row_detail||v_eff_date||'</td></tr>';

    /************************
    ** End Tags
    ************************/
    v_html := v_html||'</table></td></tr></table>';
  END IF;

  RETURN v_html;
EXCEPTION
  WHEN OTHERS THEN
    v_error_msg := SQLERRM;
    process_error( module_name      => c_module
                 , status           => g_status_warning
                 , error_code       => SQLCODE
                 , error_message    => v_error_msg
                 , location         => v_loc
                 , trx_id           => p_trx_id
                 , ntf_type         => p_ntf_type
                 , label1           => 'Trx API Name'
                 , reference1       => p_api_name );

    RETURN v_html;
END build_new_manager_html;


--
-- FUNCTION build_direct_rpts_html
--   1.2 - Obsolete.  Can be removed when all related ntfs are no longer supported.
--   Description: This function will generate the HTML for the Reassign Direct
--                Reports section.
--   Arguments:
--    Return: HTML code for Reassign Direct Reports section
--
-- /* 1.1 (3, 4, 5) */
FUNCTION build_direct_rpts_html ( p_trx_id    IN  NUMBER
                                , p_api_name  IN  VARCHAR2
                                , p_ntf_type  IN  VARCHAR2)
                                RETURN VARCHAR2 IS
--START R12.2 Upgrade Remediation
  /*c_module           cust.ttec_error_handling.module_name%TYPE  := 'build_direct_rpts_html';		-- Commented code by IXPRAVEEN-ARGANO, 04-May-2023
  v_error_msg        cust.ttec_error_handling.error_message%TYPE;*/
  c_module           apps.ttec_error_handling.module_name%TYPE  := 'build_direct_rpts_html';		--  code Added by IXPRAVEEN-ARGANO, 04-May-2023
  v_error_msg        apps.ttec_error_handling.error_message%TYPE;
  --END R12.2.10 Upgrade remediation
  v_loc              NUMBER := 0;

  -- HTML variables
  v_html             VARCHAR2(32767);
  v_default_len      NUMBER := (length(g_row_detail)*3 + 55);  -- Line length minus vars
  v_line_len         NUMBER;

  c_col_type         VARCHAR2(10)    := 'CURRENT';
  v_header_label     VARCHAR2(25)    := 'Reassign Direct Reports';

  --v_emp_name         cust.ttec_hr_api_trx_values.varchar2_value%TYPE;		-- Commented code by IXPRAVEEN-ARGANO, 04-May-2023
  v_emp_name         apps.ttec_hr_api_trx_values.varchar2_value%TYPE;		--  code Added by IXPRAVEEN-ARGANO, 04-May-2023
  v_curr_mgr_id      NUMBER;
  v_new_mgr_id       NUMBER;
  --v_new_mgr_name     cust.ttec_hr_api_trx_values.varchar2_value%TYPE;		-- Commented code by IXPRAVEEN-ARGANO, 04-May-2023
  v_new_mgr_name     apps.ttec_hr_api_trx_values.varchar2_value%TYPE;		--  code Added by IXPRAVEEN-ARGANO, 04-May-2023
  v_eff_date         DATE;

  -- Direct Report Variables
  v_num_reports      NUMBER;
  v_cnt              NUMBER := 0;  -- Number of Actually Reassigned Direct Reports
  v_overflow         BOOLEAN := FALSE;

BEGIN
  v_loc := 10;

  -- Get Trx Values
  v_num_reports    := get_num_val  (p_trx_id, p_api_name, c_col_type, 'P_NO_OF_REPORTS');

  IF NVL(v_num_reports,0) > 0 THEN
    v_loc := 20;

    -- Get the Current Supervisor value
    v_curr_mgr_id    := get_num_val (p_trx_id, p_api_name, c_col_type, 'P_SELECTED_EMP_ID');

    FOR i IN 1 .. v_num_reports LOOP
      v_loc := 30;

      -- Get the Trx Values to display
      v_emp_name       := get_text_val (p_trx_id, p_api_name, c_col_type, 'P_FULL_NAME'||i);
      v_new_mgr_id     := get_num_val  (p_trx_id, p_api_name, c_col_type, 'P_SUPERVISOR_ID'||i);
      v_new_mgr_name   := get_text_val (p_trx_id, p_api_name, c_col_type, 'P_SUPERVISOR_NAME'||i);
      v_eff_date       := get_date_val (p_trx_id, p_api_name, c_col_type, 'P_EFFECTIVE_DATE'||i);

      IF NVL(v_new_mgr_id, -1) != NVL(v_curr_mgr_id, -1) THEN
        v_loc := 40;
        v_cnt := v_cnt + 1;

        /************************
        ** Formatting Details
        ************************/
        IF v_cnt = 1 THEN
          v_loc := 50;

          -- Create Section Header
          v_html := v_html||build_hdr_html ( p_header_label  => v_header_label );

          -- Create Table Structure
          v_html := v_html||'<table cellpadding="0" cellspacing="0" border="0" width="75%"><tr>';
          v_html := v_html||'<td style="background-color:#9fa57d">';
          v_html := v_html||'<table style="" cellpadding="1" cellspacing="1" border="0" width="100%">';

          -- Column Headers
          v_html := v_html||'<tr>'||g_col_header||'>Worker Name</th>';
          v_html := v_html||        g_col_header||'>New Manager Name</th>';
          v_html := v_html||        g_col_header||'>Effective Transfer Date</th></tr>';
        END IF;

        v_loc := 60;
        v_line_len := v_default_len + length(v_emp_name) + length(v_new_mgr_name) + length(v_eff_date);

        /************************
        ** Row Details
        ************************/

        -- Make sure not to OverFlow variable
        IF g_html_len >= length(v_html) + v_line_len THEN

          v_loc := 70;
          v_html := v_html||'<tr>'||g_row_detail||v_emp_name||'</td>';
          v_html := v_html||g_row_detail||v_new_mgr_name||'</td>';
          v_html := v_html||g_row_detail||v_eff_date||'</td></tr>';

        ELSIF NOT v_overflow THEN
          v_loc := 80;
          v_html := v_html||'<tr>'||g_row_detail||'More rows exist than can be displayed</td></tr>';
          v_overflow := TRUE;
        END IF;
      END IF;
    END LOOP;

    /************************
    ** End Tags
    ************************/
    v_loc := 90;
    v_html := v_html||'</table></td></tr></table>';

  END IF;

  RETURN v_html;
EXCEPTION
  WHEN OTHERS THEN
    v_error_msg := SQLERRM;
    process_error( module_name      => c_module
                 , status           => g_status_warning
                 , error_code       => SQLCODE
                 , error_message    => v_error_msg
                 , location         => v_loc
                 , trx_id           => p_trx_id
                 , ntf_type         => p_ntf_type
                 , label1           => 'Trx API Name'
                 , reference1       => p_api_name );

    RETURN v_html;
END build_direct_rpts_html;


--
-- FUNCTION build_direct_rpts_html_clob
--   Description: This function will generate the HTML for the Reassign Direct
--                Reports section.
--   Arguments:
--    Return: HTML code (as a CLOB) for Reassign Direct Reports section
--
-- /* 1.1 (3, 4, 5) */
FUNCTION build_direct_rpts_html_clob ( p_trx_id    IN  NUMBER
                                     , p_api_name  IN  VARCHAR2
                                     , p_ntf_type  IN  VARCHAR2)
                                     RETURN CLOB IS
--START R12.2 Upgrade Remediation
 /* c_module           cust.ttec_error_handling.module_name%TYPE  := 'build_direct_rpts_html_clob';		-- Commented code by IXPRAVEEN-ARGANO, 04-May-2023
  v_error_msg        cust.ttec_error_handling.error_message%TYPE;*/
  c_module           apps.ttec_error_handling.module_name%TYPE  := 'build_direct_rpts_html_clob';		--  code Added by IXPRAVEEN-ARGANO, 04-May-2023
  v_error_msg        apps.ttec_error_handling.error_message%TYPE;
    --END R12.2.10 Upgrade remediation
  v_loc              NUMBER := 0;

  -- HTML variables
  v_html             VARCHAR2(32767);
  v_clob             CLOB;

  c_col_type         VARCHAR2(10)    := 'CURRENT';
  v_header_label     VARCHAR2(25)    := 'Reassign Direct Reports';
--START R12.2 Upgrade Remediation
  /*v_emp_name         cust.ttec_hr_api_trx_values.varchar2_value%TYPE;				-- Commented code by IXPRAVEEN-ARGANO, 04-May-2023
  v_assign_id        cust.ttec_hr_api_trx_values.number_value%TYPE;
  v_emp_number       hr.per_all_people_f.employee_number%TYPE;*/
  v_emp_name         apps.ttec_hr_api_trx_values.varchar2_value%TYPE;				--  code Added by IXPRAVEEN-ARGANO, 04-May-2023
  v_assign_id        apps.ttec_hr_api_trx_values.number_value%TYPE;
  v_emp_number       apps.per_all_people_f.employee_number%TYPE;
  --END R12.2.10 Upgrade remediation
  v_curr_mgr_id      NUMBER;
  v_new_mgr_id       NUMBER;
  --v_new_mgr_name     cust.ttec_hr_api_trx_values.varchar2_value%TYPE;			-- Commented code by IXPRAVEEN-ARGANO, 04-May-2023
  v_new_mgr_name     apps.ttec_hr_api_trx_values.varchar2_value%TYPE;			--  code Added by IXPRAVEEN-ARGANO, 04-May-2023
  v_eff_date         DATE;

  -- Direct Report Variables
  v_num_reports      NUMBER;
  v_cnt              NUMBER := 0;  -- Number of Actually Reassigned Direct Reports
  v_overflow         BOOLEAN := FALSE;

BEGIN
  v_loc := 10;
  -- Get Trx Values
  v_num_reports    := get_num_val  (p_trx_id, p_api_name, c_col_type, 'P_NO_OF_REPORTS');

  IF NVL(v_num_reports,0) > 0 THEN
    v_loc := 20;
    -- Get the Current Supervisor value
    v_curr_mgr_id    := get_num_val (p_trx_id, p_api_name, c_col_type, 'P_SELECTED_EMP_ID');

    FOR i IN 1 .. v_num_reports LOOP
      v_loc := 30;
      v_new_mgr_id     := get_num_val  (p_trx_id, p_api_name, c_col_type, 'P_SUPERVISOR_ID'||i);

      IF NVL(v_new_mgr_id, -1) != NVL(v_curr_mgr_id, -1) THEN
        v_loc := 40;
        v_cnt := v_cnt + 1;

        -- Add HTML string to CLOB every 10th record
        IF MOD(v_cnt,10) = 0 THEN
          v_clob := v_clob||v_html;
          v_html := NULL;
        END IF;

        -- Get the Trx Values to display
        v_loc := 50;
        v_emp_name       := get_text_val (p_trx_id, p_api_name, c_col_type, 'P_FULL_NAME'||i);
        v_assign_id      := get_num_val  (p_trx_id, p_api_name, c_col_type, 'P_ASSIGNMENT_ID'||i);
        v_new_mgr_name   := get_text_val (p_trx_id, p_api_name, c_col_type, 'P_SUPERVISOR_NAME'||i);
        v_eff_date       := get_date_val (p_trx_id, p_api_name, c_col_type, 'P_EFFECTIVE_DATE'||i);

        -- Lookup the Employee Number
        v_loc := 60;
        BEGIN
          SELECT employee_number
            INTO v_emp_number
            FROM per_all_assignments_f paa
               , per_all_people_f pap
           WHERE paa.assignment_id = v_assign_id
             AND SYSDATE BETWEEN paa.effective_start_date AND paa.effective_end_date
             AND pap.person_id = paa.person_id
             AND SYSDATE BETWEEN pap.effective_start_date AND pap.effective_end_date;
        EXCEPTION
          WHEN OTHERS THEN
            v_error_msg := SQLERRM;
            process_error( module_name      => c_module
                         , status           => g_status_warning
                         , error_code       => SQLCODE
                         , error_message    => v_error_msg
                         , location         => v_loc
                         , label1           => 'Emp Name'
                         , reference1       => v_emp_name
                         , label2           => 'Emp Assignment ID'
                         , reference2       => v_assign_id );
            v_emp_number := NULL;
        END;

        /************************
        ** Formatting Details
        ************************/
        IF v_cnt = 1 THEN
          v_loc := 50;

          -- Create Section Header
          v_html := v_html||build_hdr_html ( p_header_label  => v_header_label );

          -- Create Table Structure
          v_html := v_html||'<table cellpadding="0" cellspacing="0" border="0" width="75%"><tr>';
          v_html := v_html||'<td style="background-color:#9fa57d">';
          v_html := v_html||'<table style="" cellpadding="1" cellspacing="1" border="0" width="100%">';

          -- Column Headers
          v_html := v_html||'<tr>'||g_col_header||'>Worker Name</th>';
          v_html := v_html||        g_col_header||'>Employee Number</th>';
          v_html := v_html||        g_col_header||'>New Manager Name</th>';
          v_html := v_html||        g_col_header||'>Effective Transfer Date</th></tr>';
        END IF;

        /************************
        ** Row Details
        ************************/

        v_loc := 60;
        v_html := v_html||'<tr>'||g_row_detail||v_emp_name||'</td>';
        v_html := v_html||g_row_detail||v_emp_number||'</td>';
        v_html := v_html||g_row_detail||v_new_mgr_name||'</td>';
        v_html := v_html||g_row_detail||v_eff_date||'</td></tr>';

      END IF;
    END LOOP;

    /************************
    ** End Tags
    ************************/
    v_loc := 70;
    v_html := v_html||'</table></td></tr></table>';

  END IF;

  v_clob := v_clob||v_html;
  RETURN v_clob;

EXCEPTION
  WHEN OTHERS THEN
    v_error_msg := SQLERRM;
    process_error( module_name      => c_module
                 , status           => g_status_warning
                 , error_code       => SQLCODE
                 , error_message    => v_error_msg
                 , location         => v_loc
                 , trx_id           => p_trx_id
                 , ntf_type         => p_ntf_type
                 , label1           => 'Trx API Name'
                 , reference1       => p_api_name );

    RETURN v_clob;
END build_direct_rpts_html_clob;


/*********************************************************
**  Public Functions
*********************************************************/

/*********************************************************
**  WF Procedures - Called directly from WF Functions
*********************************************************/


-- PROCEDURE hdr_summary
--
-- Description: This procedure will generate a Dynamic HTML Document for the
--              Header Summary portion of the FYI notification.  This section
--              is always displayed and includes Submitter and Employee details.
--
-- Arguments: Standard required WF parameters
--
PROCEDURE hdr_summary ( p_document_id   IN            VARCHAR2
                      , p_display_type  IN            VARCHAR2
                      , p_document      IN OUT NOCOPY CLOB
                      , p_document_type IN OUT NOCOPY VARCHAR2 ) IS
--START R12.2 Upgrade Remediation
  /*c_module           cust.ttec_error_handling.module_name%TYPE  := 'hdr_summary';		-- Commented code by IXPRAVEEN-ARGANO, 04-May-2023
  v_error_msg        cust.ttec_error_handling.error_message%TYPE;*/
  c_module           apps.ttec_error_handling.module_name%TYPE  := 'hdr_summary';		--  code Added by IXPRAVEEN-ARGANO, 04-May-2023
  v_error_msg        apps.ttec_error_handling.error_message%TYPE;
  --END R12.2.10 Upgrade remediation
  v_loc              NUMBER := 0;

  v_header_label     VARCHAR2(25) := 'Summary';
  --v_trx_id           cust.ttec_hr_api_trx_values.transaction_id%TYPE;		-- Commented code by IXPRAVEEN-ARGANO, 04-May-2023
  v_trx_id           apps.ttec_hr_api_trx_values.transaction_id%TYPE;		--  code Added by IXPRAVEEN-ARGANO, 04-May-2023
  v_ntf_type         VARCHAR2(10);
  v_itemtype         wf_item_activity_statuses.item_type%TYPE;
  v_itemkey          wf_item_activity_statuses.item_key%TYPE;

BEGIN
  v_loc := 10;
  p_document_type  := wf_notification.doc_html;

  get_wf_dtl ( p_nid        => p_document_id
             , p_trx_id     => v_trx_id
             , p_ntf_type   => v_ntf_type
             , p_itemtype   => v_itemtype
             , p_itemkey    => v_itemkey );

  v_loc := 20;
  p_document := p_document||build_hdr_html ( p_header_label  => v_header_label );
  p_document := p_document||build_summary_html( p_trx_id     => v_trx_id
                                              , p_ntf_type   => v_ntf_type
                                              , p_itemtype   => v_itemtype
                                              , p_itemkey    => v_itemkey );

EXCEPTION
  WHEN OTHERS THEN
    v_error_msg := SQLERRM;
    process_error( module_name      => c_module
                 , status           => g_status_warning
                 , error_code       => SQLCODE
                 , error_message    => v_error_msg
                 , location         => v_loc
                 , trx_id           => v_trx_id
                 , ntf_type         => v_ntf_type );
END hdr_summary;


--
-- PROCEDURE assignment_dtl
--   1.2 - Obsolete.  Can be removed when all related ntfs are no longer supported.
--   Description: This procedure will generate a Dynamic HTML Document for the
--                Assignment Detail portion of the FYI notification.  It will return
--                and empty document if this section is not to be displayed.
--
PROCEDURE assignment_dtl ( p_document_id   IN            VARCHAR2
                         , p_display_type  IN            VARCHAR2
                         , p_document      IN OUT NOCOPY VARCHAR2
                         , p_document_type IN OUT NOCOPY VARCHAR2 ) IS
--START R12.2 Upgrade Remediation
  /*c_module           cust.ttec_error_handling.module_name%TYPE  := 'assignment_dtl (old)';	-- Commented code by IXPRAVEEN-ARGANO, 04-May-2023
  v_error_msg        cust.ttec_error_handling.error_message%TYPE;
  v_loc              NUMBER := 0;

  v_header_label     VARCHAR2(25) := 'Assignment';
  v_api_name         cust.ttec_hr_api_trx_values.api_name%TYPE     := 'HR_PROCESS_ASSIGNMENT_SS.PROCESS_API';
  v_trx_id           cust.ttec_hr_api_trx_values.transaction_id%TYPE;*/
  c_module           apps.ttec_error_handling.module_name%TYPE  := 'assignment_dtl (old)';		--  code Added by IXPRAVEEN-ARGANO, 04-May-2023
  v_error_msg        apps.ttec_error_handling.error_message%TYPE;
  v_loc              NUMBER := 0;

  v_header_label     VARCHAR2(25) := 'Assignment';
  v_api_name         apps.ttec_hr_api_trx_values.api_name%TYPE     := 'HR_PROCESS_ASSIGNMENT_SS.PROCESS_API';
  v_trx_id           apps.ttec_hr_api_trx_values.transaction_id%TYPE;
  --END R12.2.10 Upgrade remediation
  v_ntf_type         VARCHAR2(10);
  v_itemtype         wf_item_activity_statuses.item_type%TYPE;
  v_itemkey          wf_item_activity_statuses.item_key%TYPE;

BEGIN
  v_loc := 10;

  p_document_type  := wf_notification.doc_html;

  get_wf_dtl ( p_nid        => p_document_id
             , p_trx_id     => v_trx_id
             , p_ntf_type   => v_ntf_type
             , p_itemtype   => v_itemtype
             , p_itemkey    => v_itemkey );

  -- Only include this information in the FYI to Human Capital.
  IF trx_api_exist ( p_trx_id   => v_trx_id
                   , p_api_name => v_api_name )
     AND v_ntf_type = 'HC' THEN

    v_loc := 20;
    p_document := build_hdr_html ( p_header_label  => v_header_label );
    p_document := p_document||build_assignment_html( p_trx_id   => v_trx_id
                                                   , p_api_name => v_api_name
                                                   , p_ntf_type => v_ntf_type );

  END IF;

EXCEPTION
  WHEN OTHERS THEN
    v_error_msg := SQLERRM;
    process_error( module_name      => c_module
                 , status           => g_status_warning
                 , error_code       => SQLCODE
                 , error_message    => v_error_msg
                 , location         => v_loc
                 , trx_id           => v_trx_id
                 , ntf_type         => v_ntf_type
                 , label1           => 'Trx API Name'
                 , reference1       => v_api_name );
END assignment_dtl;


--
-- PROCEDURE assignment_dtl
--   Description: This procedure will generate a Dynamic HTML Document for the
--                Assignment Detail portion of the FYI notification.  It will return
--                and empty document if this section is not to be displayed.
--
PROCEDURE assignment_dtl ( p_document_id   IN            VARCHAR2
                         , p_display_type  IN            VARCHAR2
                         , p_document      IN OUT NOCOPY CLOB
                         , p_document_type IN OUT NOCOPY VARCHAR2 ) IS
--START R12.2 Upgrade Remediation
  /*c_module           cust.ttec_error_handling.module_name%TYPE  := 'assignment_dtl'; -- Commented code by IXPRAVEEN-ARGANO, 04-May-2023
  v_error_msg        cust.ttec_error_handling.error_message%TYPE;
  v_loc              NUMBER := 0;

  v_header_label     VARCHAR2(25) := 'Assignment';
  v_api_name         cust.ttec_hr_api_trx_values.api_name%TYPE     := 'HR_PROCESS_ASSIGNMENT_SS.PROCESS_API';
  v_trx_id           cust.ttec_hr_api_trx_values.transaction_id%TYPE;*/
  
  c_module           apps.ttec_error_handling.module_name%TYPE  := 'assignment_dtl';		--  code Added by IXPRAVEEN-ARGANO, 04-May-2023
  v_error_msg        apps.ttec_error_handling.error_message%TYPE;
  v_loc              NUMBER := 0;

  v_header_label     VARCHAR2(25) := 'Assignment';						
  v_api_name         apps.ttec_hr_api_trx_values.api_name%TYPE     := 'HR_PROCESS_ASSIGNMENT_SS.PROCESS_API';
  v_trx_id           apps.ttec_hr_api_trx_values.transaction_id%TYPE;
  --END R12.2.10 Upgrade remediation
  v_ntf_type         VARCHAR2(10);
  v_itemtype         wf_item_activity_statuses.item_type%TYPE;
  v_itemkey          wf_item_activity_statuses.item_key%TYPE;

BEGIN
  v_loc := 10;

  p_document_type  := wf_notification.doc_html;

  get_wf_dtl ( p_nid        => p_document_id
             , p_trx_id     => v_trx_id
             , p_ntf_type   => v_ntf_type
             , p_itemtype   => v_itemtype
             , p_itemkey    => v_itemkey );

  -- Only include this information in the FYI to Human Capital.
  IF trx_api_exist ( p_trx_id   => v_trx_id
                   , p_api_name => v_api_name )
     AND v_ntf_type = 'HC' THEN

    v_loc := 20;
    p_document := p_document||build_hdr_html ( p_header_label  => v_header_label );
    p_document := p_document||build_assignment_html( p_trx_id   => v_trx_id
                                        , p_api_name => v_api_name
                                        , p_ntf_type => v_ntf_type );

  END IF;

EXCEPTION
  WHEN OTHERS THEN
    v_error_msg := SQLERRM;
    process_error( module_name      => c_module
                 , status           => g_status_warning
                 , error_code       => SQLCODE
                 , error_message    => v_error_msg
                 , location         => v_loc
                 , trx_id           => v_trx_id
                 , ntf_type         => v_ntf_type
                 , label1           => 'Trx API Name'
                 , reference1       => v_api_name );
END assignment_dtl;


--
-- PROCEDURE pay_rate_dtl
--   1.2 - Obsolete.  Can be removed when all related ntfs are no longer supported.
--   Description: This procedure will generate a Dynamic HTML Document for the
--                Pay Rate Detail portion of the FYI notification.  It will return
--                and empty document if this section is not to be displayed.
--
PROCEDURE pay_rate_dtl ( p_document_id   IN            VARCHAR2
                       , p_display_type  IN            VARCHAR2
                       , p_document      IN OUT NOCOPY VARCHAR2
                       , p_document_type IN OUT NOCOPY VARCHAR2 ) IS
--START R12.2 Upgrade Remediation
  /*c_module           cust.ttec_error_handling.module_name%TYPE  := 'pay_rate_dtl (old)';-- Commented code by IXPRAVEEN-ARGANO, 04-May-2023
  v_error_msg        cust.ttec_error_handling.error_message%TYPE;
  v_loc              NUMBER := 0;

  v_header_label     VARCHAR2(25) := 'Pay Rate';
  v_api_name         cust.ttec_hr_api_trx_values.api_name%TYPE     := 'HR_PAY_RATE_SS.PROCESS_API';
  v_trx_id           cust.ttec_hr_api_trx_values.transaction_id%TYPE;*/
  c_module           apps.ttec_error_handling.module_name%TYPE  := 'pay_rate_dtl (old)';		--  code Added by IXPRAVEEN-ARGANO, 04-May-2023
  v_error_msg        apps.ttec_error_handling.error_message%TYPE;
  v_loc              NUMBER := 0;

  v_header_label     VARCHAR2(25) := 'Pay Rate';
  v_api_name         apps.ttec_hr_api_trx_values.api_name%TYPE     := 'HR_PAY_RATE_SS.PROCESS_API';
  v_trx_id           apps.ttec_hr_api_trx_values.transaction_id%TYPE;
  --END R12.2.10 Upgrade remediation
  v_ntf_type         VARCHAR2(10);
  v_itemtype         wf_item_activity_statuses.item_type%TYPE;
  v_itemkey          wf_item_activity_statuses.item_key%TYPE;

BEGIN
  v_loc := 10;

  p_document_type  := wf_notification.doc_html;

  get_wf_dtl ( p_nid        => p_document_id
             , p_trx_id     => v_trx_id
             , p_ntf_type   => v_ntf_type
             , p_itemtype   => v_itemtype
             , p_itemkey    => v_itemkey );

  -- Only include this information in the FYI to Human Capital.
  IF trx_api_exist ( p_trx_id   => v_trx_id
                   , p_api_name => v_api_name )
     AND v_ntf_type = 'HC' THEN

    v_loc := 20;
    p_document := build_hdr_html ( p_header_label  => v_header_label );
    p_document := p_document||build_pay_rate_html( p_trx_id   => v_trx_id
                                                 , p_api_name => v_api_name
                                                 , p_ntf_type => v_ntf_type );

  END IF;

EXCEPTION
  WHEN OTHERS THEN
    v_error_msg := SQLERRM;
    process_error( module_name      => c_module
                 , status           => g_status_warning
                 , error_code       => SQLCODE
                 , error_message    => v_error_msg
                 , location         => v_loc
                 , trx_id           => v_trx_id
                 , ntf_type         => v_ntf_type
                 , label1           => 'Trx API Name'
                 , reference1       => v_api_name );
END pay_rate_dtl;


--
-- PROCEDURE pay_rate_dtl
--   Description: This procedure will generate a Dynamic HTML Document for the
--                Pay Rate Detail portion of the FYI notification.  It will return
--                and empty document if this section is not to be displayed.
--
PROCEDURE pay_rate_dtl ( p_document_id   IN            VARCHAR2
                       , p_display_type  IN            VARCHAR2
                       , p_document      IN OUT NOCOPY CLOB
                       , p_document_type IN OUT NOCOPY VARCHAR2 ) IS
--START R12.2 Upgrade Remediation
  /*c_module           cust.ttec_error_handling.module_name%TYPE  := 'pay_rate_dtl';		-- Commented code by IXPRAVEEN-ARGANO, 04-May-2023
  v_error_msg        cust.ttec_error_handling.error_message%TYPE;
  v_loc              NUMBER := 0;

  v_header_label     VARCHAR2(25) := 'Pay Rate';
  v_api_name         cust.ttec_hr_api_trx_values.api_name%TYPE     := 'HR_PAY_RATE_SS.PROCESS_API';
  v_trx_id           cust.ttec_hr_api_trx_values.transaction_id%TYPE;*/
  c_module           apps.ttec_error_handling.module_name%TYPE  := 'pay_rate_dtl';			--  code Added by IXPRAVEEN-ARGANO, 04-May-2023
  v_error_msg        apps.ttec_error_handling.error_message%TYPE;
  v_loc              NUMBER := 0;

  v_header_label     VARCHAR2(25) := 'Pay Rate';
  v_api_name         apps.ttec_hr_api_trx_values.api_name%TYPE     := 'HR_PAY_RATE_SS.PROCESS_API';
  v_trx_id           apps.ttec_hr_api_trx_values.transaction_id%TYPE;
  --END R12.2.10 Upgrade remediation
  v_ntf_type         VARCHAR2(10);
  v_itemtype         wf_item_activity_statuses.item_type%TYPE;
  v_itemkey          wf_item_activity_statuses.item_key%TYPE;

BEGIN
  v_loc := 10;

  p_document_type  := wf_notification.doc_html;

  get_wf_dtl ( p_nid        => p_document_id
             , p_trx_id     => v_trx_id
             , p_ntf_type   => v_ntf_type
             , p_itemtype   => v_itemtype
             , p_itemkey    => v_itemkey );

  -- Only include this information in the FYI to Human Capital.
  IF trx_api_exist ( p_trx_id   => v_trx_id
                   , p_api_name => v_api_name )
     AND v_ntf_type = 'HC' THEN

    v_loc := 20;
    p_document := p_document||build_hdr_html ( p_header_label  => v_header_label );
    p_document := p_document||build_pay_rate_html( p_trx_id   => v_trx_id
                                                 , p_api_name => v_api_name
                                                 , p_ntf_type => v_ntf_type );

  END IF;

EXCEPTION
  WHEN OTHERS THEN
    v_error_msg := SQLERRM;
    process_error( module_name      => c_module
                 , status           => g_status_warning
                 , error_code       => SQLCODE
                 , error_message    => v_error_msg
                 , location         => v_loc
                 , trx_id           => v_trx_id
                 , ntf_type         => v_ntf_type
                 , label1           => 'Trx API Name'
                 , reference1       => v_api_name );
END pay_rate_dtl;


--
-- PROCEDURE termination_dtl
--   1.2 - Obsolete.  Can be removed when all related ntfs are no longer supported.
--   Description: This procedure will generate a Dynamic HTML Document for the
--                Termination Detail portion of the FYI notification.  It will return
--                and empty document if this section is not to be displayed.
--
PROCEDURE termination_dtl ( p_document_id   IN            VARCHAR2
                          , p_display_type  IN            VARCHAR2
                          , p_document      IN OUT NOCOPY VARCHAR2
                          , p_document_type IN OUT NOCOPY VARCHAR2 ) IS
--START R12.2 Upgrade Remediation
  /*c_module           cust.ttec_error_handling.module_name%TYPE  := 'termination_dtl (old)';	-- Commented code by IXPRAVEEN-ARGANO, 04-May-2023
  v_error_msg        cust.ttec_error_handling.error_message%TYPE;
  v_loc              NUMBER := 0;

  v_header_label     VARCHAR2(25) := 'Termination Details';
  v_api_name         cust.ttec_hr_api_trx_values.api_name%TYPE     := 'HR_TERMINATION_SS.PROCESS_API';
  v_trx_id           cust.ttec_hr_api_trx_values.transaction_id%TYPE;*/
  c_module           apps.ttec_error_handling.module_name%TYPE  := 'termination_dtl (old)';		--  code Added by IXPRAVEEN-ARGANO, 04-May-2023
  v_error_msg        apps.ttec_error_handling.error_message%TYPE;
  v_loc              NUMBER := 0;

  v_header_label     VARCHAR2(25) := 'Termination Details';
  v_api_name         apps.ttec_hr_api_trx_values.api_name%TYPE     := 'HR_TERMINATION_SS.PROCESS_API';
  v_trx_id           apps.ttec_hr_api_trx_values.transaction_id%TYPE;
    --END R12.2.10 Upgrade remediation
  v_ntf_type         VARCHAR2(10);
  v_itemtype         wf_item_activity_statuses.item_type%TYPE;
  v_itemkey          wf_item_activity_statuses.item_key%TYPE;

BEGIN
  v_loc := 10;

  p_document_type  := wf_notification.doc_html;

  get_wf_dtl ( p_nid        => p_document_id
             , p_trx_id     => v_trx_id
             , p_ntf_type   => v_ntf_type
             , p_itemtype   => v_itemtype
             , p_itemkey    => v_itemkey );

  IF trx_api_exist ( p_trx_id   => v_trx_id
                   , p_api_name => v_api_name ) THEN

    v_loc := 20;
    p_document := build_hdr_html ( p_header_label  => v_header_label );
    p_document := p_document||build_termination_html( p_trx_id   => v_trx_id
                                                    , p_api_name => v_api_name
                                                    , p_ntf_type => v_ntf_type );

  END IF;

EXCEPTION
  WHEN OTHERS THEN
    v_error_msg := SQLERRM;
    process_error( module_name      => c_module
                 , status           => g_status_warning
                 , error_code       => SQLCODE
                 , error_message    => v_error_msg
                 , location         => v_loc
                 , trx_id           => v_trx_id
                 , ntf_type         => v_ntf_type
                 , label1           => 'Trx API Name'
                 , reference1       => v_api_name );
END termination_dtl;


--
-- PROCEDURE termination_dtl
--   Description: This procedure will generate a Dynamic HTML Document for the
--                Termination Detail portion of the FYI notification.  It will return
--                and empty document if this section is not to be displayed.
--
PROCEDURE termination_dtl ( p_document_id   IN            VARCHAR2
                          , p_display_type  IN            VARCHAR2
                          , p_document      IN OUT NOCOPY CLOB
                          , p_document_type IN OUT NOCOPY VARCHAR2 ) IS
--START R12.2 Upgrade Remediation
  /*c_module           cust.ttec_error_handling.module_name%TYPE  := 'termination_dtl';		-- Commented code by IXPRAVEEN-ARGANO, 04-May-2023
  v_error_msg        cust.ttec_error_handling.error_message%TYPE;
  v_loc              NUMBER := 0;

  v_header_label     VARCHAR2(25) := 'Termination Details';
  v_api_name         cust.ttec_hr_api_trx_values.api_name%TYPE     := 'HR_TERMINATION_SS.PROCESS_API';
  v_trx_id           cust.ttec_hr_api_trx_values.transaction_id%TYPE;*/
  c_module           apps.ttec_error_handling.module_name%TYPE  := 'termination_dtl';       --  code Added by IXPRAVEEN-ARGANO, 04-May-2023
  v_error_msg        apps.ttec_error_handling.error_message%TYPE;
  v_loc              NUMBER := 0;

  v_header_label     VARCHAR2(25) := 'Termination Details';
  v_api_name         apps.ttec_hr_api_trx_values.api_name%TYPE     := 'HR_TERMINATION_SS.PROCESS_API';
  v_trx_id           apps.ttec_hr_api_trx_values.transaction_id%TYPE;
      --END R12.2.10 Upgrade remediation
  v_ntf_type         VARCHAR2(10);
  v_itemtype         wf_item_activity_statuses.item_type%TYPE;
  v_itemkey          wf_item_activity_statuses.item_key%TYPE;

BEGIN
  v_loc := 10;

  p_document_type  := wf_notification.doc_html;

  get_wf_dtl ( p_nid        => p_document_id
             , p_trx_id     => v_trx_id
             , p_ntf_type   => v_ntf_type
             , p_itemtype   => v_itemtype
             , p_itemkey    => v_itemkey );

  IF trx_api_exist ( p_trx_id   => v_trx_id
                   , p_api_name => v_api_name )
     AND v_ntf_type IN ('HC','SMGR','FAC','OSC') THEN

    v_loc := 20;
    p_document := p_document||build_hdr_html ( p_header_label  => v_header_label );
    p_document := p_document||build_termination_html( p_trx_id   => v_trx_id
                                                    , p_api_name => v_api_name
                                                    , p_ntf_type => v_ntf_type );

  END IF;

EXCEPTION
  WHEN OTHERS THEN
    v_error_msg := SQLERRM;
    process_error( module_name      => c_module
                 , status           => g_status_warning
                 , error_code       => SQLCODE
                 , error_message    => v_error_msg
                 , location         => v_loc
                 , trx_id           => v_trx_id
                 , ntf_type         => v_ntf_type
                 , label1           => 'Trx API Name'
                 , reference1       => v_api_name );
END termination_dtl;


--
-- PROCEDURE new_manager_dtl
--   1.2 - Obsolete.  Can be removed when all related ntfs are no longer supported.
--   Description: This procedure will generate a Dynamic HTML Document for the
--                New Manager Detail portion of the FYI notification.  It will return
--                and empty document if this section is not to be displayed.
--
PROCEDURE new_manager_dtl ( p_document_id   IN            VARCHAR2
                          , p_display_type  IN            VARCHAR2
                          , p_document      IN OUT NOCOPY VARCHAR2
                          , p_document_type IN OUT NOCOPY VARCHAR2 ) IS
--START R12.2 Upgrade Remediation
  /*c_module           cust.ttec_error_handling.module_name%TYPE  := 'new_manager_dtl (old)';		-- Commented code by IXPRAVEEN-ARGANO, 04-May-2023
  v_error_msg        cust.ttec_error_handling.error_message%TYPE;
  v_loc              NUMBER := 0;

  v_api_name         cust.ttec_hr_api_trx_values.api_name%TYPE     := 'HR_SUPERVISOR_SS.PROCESS_API';
  v_trx_id           cust.ttec_hr_api_trx_values.transaction_id%TYPE;*/
  c_module           apps.ttec_error_handling.module_name%TYPE  := 'new_manager_dtl (old)';		--  code Added by IXPRAVEEN-ARGANO, 04-May-2023
  v_error_msg        apps.ttec_error_handling.error_message%TYPE;
  v_loc              NUMBER := 0;

  v_api_name         apps.ttec_hr_api_trx_values.api_name%TYPE     := 'HR_SUPERVISOR_SS.PROCESS_API';
  v_trx_id           apps.ttec_hr_api_trx_values.transaction_id%TYPE;
    --END R12.2.10 Upgrade remediation
  v_ntf_type         VARCHAR2(10);
  v_itemtype         wf_item_activity_statuses.item_type%TYPE;
  v_itemkey          wf_item_activity_statuses.item_key%TYPE;

BEGIN
  v_loc := 10;

  p_document_type  := wf_notification.doc_html;

  get_wf_dtl ( p_nid        => p_document_id
             , p_trx_id     => v_trx_id
             , p_ntf_type   => v_ntf_type
             , p_itemtype   => v_itemtype
             , p_itemkey    => v_itemkey );

  -- include this information in all FYI Notifications
  IF trx_api_exist ( p_trx_id   => v_trx_id
                   , p_api_name => v_api_name ) THEN

    v_loc := 20;
    p_document := p_document||build_new_manager_html( p_trx_id   => v_trx_id
                                                    , p_api_name => v_api_name
                                                    , p_ntf_type => v_ntf_type );

  END IF;

EXCEPTION
  WHEN OTHERS THEN
    v_error_msg := SQLERRM;
    process_error( module_name      => c_module
                 , status           => g_status_warning
                 , error_code       => SQLCODE
                 , error_message    => v_error_msg
                 , location         => v_loc
                 , trx_id           => v_trx_id
                 , ntf_type         => v_ntf_type
                 , label1           => 'Trx API Name'
                 , reference1       => v_api_name );
END new_manager_dtl;


--
-- PROCEDURE new_manager_dtl
--   Description: This procedure will generate a Dynamic HTML Document for the
--                New Manager Detail portion of the FYI notification.  It will return
--                and empty document if this section is not to be displayed.
--
PROCEDURE new_manager_dtl ( p_document_id   IN            VARCHAR2
                          , p_display_type  IN            VARCHAR2
                          , p_document      IN OUT NOCOPY CLOB
                          , p_document_type IN OUT NOCOPY VARCHAR2 ) IS
--START R12.2 Upgrade Remediation
  /*c_module           cust.ttec_error_handling.module_name%TYPE  := 'new_manager_dtl';		-- Commented code by IXPRAVEEN-ARGANO, 04-May-2023
  v_error_msg        cust.ttec_error_handling.error_message%TYPE;
  v_loc              NUMBER := 0;

  v_api_name         cust.ttec_hr_api_trx_values.api_name%TYPE     := 'HR_SUPERVISOR_SS.PROCESS_API';
  v_trx_id           cust.ttec_hr_api_trx_values.transaction_id%TYPE;*/
  c_module           apps.ttec_error_handling.module_name%TYPE  := 'new_manager_dtl';			--  code Added by IXPRAVEEN-ARGANO, 04-May-2023
  v_error_msg        apps.ttec_error_handling.error_message%TYPE;
  v_loc              NUMBER := 0;

  v_api_name         apps.ttec_hr_api_trx_values.api_name%TYPE     := 'HR_SUPERVISOR_SS.PROCESS_API';
  v_trx_id           apps.ttec_hr_api_trx_values.transaction_id%TYPE;
  --END R12.2.10 Upgrade remediation
  v_ntf_type         VARCHAR2(10);
  v_itemtype         wf_item_activity_statuses.item_type%TYPE;
  v_itemkey          wf_item_activity_statuses.item_key%TYPE;

BEGIN
  v_loc := 10;

  p_document_type  := wf_notification.doc_html;

  get_wf_dtl ( p_nid        => p_document_id
             , p_trx_id     => v_trx_id
             , p_ntf_type   => v_ntf_type
             , p_itemtype   => v_itemtype
             , p_itemkey    => v_itemkey );

  IF trx_api_exist ( p_trx_id   => v_trx_id
                   , p_api_name => v_api_name )
     AND v_ntf_type IN ('HC','OSC','SMGR','UNKNOWN') THEN

    v_loc := 20;
    p_document := p_document||build_new_manager_html( p_trx_id   => v_trx_id
                                                    , p_api_name => v_api_name
                                                    , p_ntf_type => v_ntf_type );

  END IF;

EXCEPTION
  WHEN OTHERS THEN
    v_error_msg := SQLERRM;
    process_error( module_name      => c_module
                 , status           => g_status_warning
                 , error_code       => SQLCODE
                 , error_message    => v_error_msg
                 , location         => v_loc
                 , trx_id           => v_trx_id
                 , ntf_type         => v_ntf_type
                 , label1           => 'Trx API Name'
                 , reference1       => v_api_name );
END new_manager_dtl;


--
-- PROCEDURE direct_rpts_dtl
--   1.2 - Obsolete.  Can be removed when all related ntfs are no longer supported.
--   Description: This procedure will generate a Dynamic HTML Document for the
--                Reassign Direct Reports portion of the FYI notification.  It will
--                return an empty document if this section is not to be displayed.
--
-- /* 1.1 (3, 4, 5) */
PROCEDURE direct_rpts_dtl ( p_document_id   IN            VARCHAR2
                          , p_display_type  IN            VARCHAR2
                          , p_document      IN OUT NOCOPY VARCHAR2
                          , p_document_type IN OUT NOCOPY VARCHAR2 ) IS
--START R12.2 Upgrade Remediation
  /*c_module           cust.ttec_error_handling.module_name%TYPE  := 'direct_rpts_dtl (old)'; -- Commented code by IXPRAVEEN-ARGANO, 04-May-2023
  v_error_msg        cust.ttec_error_handling.error_message%TYPE;
  v_loc              NUMBER := 0;

  v_api_name         cust.ttec_hr_api_trx_values.api_name%TYPE     := 'HR_SUPERVISOR_SS.PROCESS_API';
  v_trx_id           cust.ttec_hr_api_trx_values.transaction_id%TYPE;*/
  c_module           apps.ttec_error_handling.module_name%TYPE  := 'direct_rpts_dtl (old)';		--  code Added by IXPRAVEEN-ARGANO, 04-May-2023
  v_error_msg        apps.ttec_error_handling.error_message%TYPE;
  v_loc              NUMBER := 0;

  v_api_name         apps.ttec_hr_api_trx_values.api_name%TYPE     := 'HR_SUPERVISOR_SS.PROCESS_API';
  v_trx_id           apps.ttec_hr_api_trx_values.transaction_id%TYPE;
  --END R12.2.10 Upgrade remediation
  v_ntf_type         VARCHAR2(10);
  v_itemtype         wf_item_activity_statuses.item_type%TYPE;
  v_itemkey          wf_item_activity_statuses.item_key%TYPE;

BEGIN
  v_loc := 10;

  p_document_type  := wf_notification.doc_html;

  get_wf_dtl ( p_nid        => p_document_id
             , p_trx_id     => v_trx_id
             , p_ntf_type   => v_ntf_type
             , p_itemtype   => v_itemtype
             , p_itemkey    => v_itemkey );

  -- include this information in all FYI Notifications
  IF trx_api_exist ( p_trx_id   => v_trx_id
                   , p_api_name => v_api_name ) THEN

    v_loc := 20;
    p_document := p_document||build_direct_rpts_html( p_trx_id   => v_trx_id
                                                    , p_api_name => v_api_name
                                                    , p_ntf_type => v_ntf_type );

  END IF;

EXCEPTION
  WHEN OTHERS THEN
    v_error_msg := SQLERRM;
    process_error( module_name      => c_module
                 , status           => g_status_warning
                 , error_code       => SQLCODE
                 , error_message    => v_error_msg
                 , location         => v_loc
                 , trx_id           => v_trx_id
                 , ntf_type         => v_ntf_type
                 , label1           => 'Trx API Name'
                 , reference1       => v_api_name );
END direct_rpts_dtl;


--
-- PROCEDURE direct_rpts_dtl
--   Description: This procedure will generate a Dynamic HTML Document for the
--                Reassign Direct Reports portion of the FYI notification.  It will
--                return an empty document if this section is not to be displayed.
--
-- /* 1.1 (3, 4, 5) */
PROCEDURE direct_rpts_dtl ( p_document_id   IN            VARCHAR2
                          , p_display_type  IN            VARCHAR2
                          , p_document      IN OUT NOCOPY CLOB
                          , p_document_type IN OUT NOCOPY VARCHAR2 ) IS
--START R12.2 Upgrade Remediation
  /*c_module           cust.ttec_error_handling.module_name%TYPE  := 'direct_rpts_dtl';		- Commented code by IXPRAVEEN-ARGANO, 04-May-2023
  v_error_msg        cust.ttec_error_handling.error_message%TYPE;
  v_loc              NUMBER := 0;

  v_api_name         cust.ttec_hr_api_trx_values.api_name%TYPE     := 'HR_SUPERVISOR_SS.PROCESS_API';
  v_trx_id           cust.ttec_hr_api_trx_values.transaction_id%TYPE;*/
  c_module           apps.ttec_error_handling.module_name%TYPE  := 'direct_rpts_dtl';		--  code Added by IXPRAVEEN-ARGANO, 04-May-2023
  v_error_msg        apps.ttec_error_handling.error_message%TYPE;
  v_loc              NUMBER := 0;

  v_api_name         apps.ttec_hr_api_trx_values.api_name%TYPE     := 'HR_SUPERVISOR_SS.PROCESS_API';
  v_trx_id           apps.ttec_hr_api_trx_values.transaction_id%TYPE;
 --END R12.2.10 Upgrade remediation 
  v_ntf_type         VARCHAR2(10);
  v_itemtype         wf_item_activity_statuses.item_type%TYPE;
  v_itemkey          wf_item_activity_statuses.item_key%TYPE;

BEGIN
  v_loc := 10;

  p_document_type  := wf_notification.doc_html;

  get_wf_dtl ( p_nid        => p_document_id
             , p_trx_id     => v_trx_id
             , p_ntf_type   => v_ntf_type
             , p_itemtype   => v_itemtype
             , p_itemkey    => v_itemkey );

  -- include this information in all FYI Notifications
  IF trx_api_exist ( p_trx_id   => v_trx_id
                   , p_api_name => v_api_name )
     AND v_ntf_type IN ('HC','OSC','SMGR','UNKNOWN') THEN

    v_loc := 20;
    p_document := p_document||build_direct_rpts_html_clob( p_trx_id   => v_trx_id
                                                         , p_api_name => v_api_name
                                                         , p_ntf_type => v_ntf_type );

  END IF;

EXCEPTION
  WHEN OTHERS THEN
    v_error_msg := SQLERRM;
    process_error( module_name      => c_module
                 , status           => g_status_warning
                 , error_code       => SQLCODE
                 , error_message    => v_error_msg
                 , location         => v_loc
                 , trx_id           => v_trx_id
                 , ntf_type         => v_ntf_type
                 , label1           => 'Trx API Name'
                 , reference1       => v_api_name );
END direct_rpts_dtl;


--
-- PROCEDURE action_history
--   Description: This procedure is a wrapper for the standard
--                wf_notification(HISTORY).  It will translate the final
--                document into a CLOB which is consistent with the rest of the
--                notification sections.
--
PROCEDURE action_history ( p_document_id   IN            VARCHAR2
                         , p_display_type  IN            VARCHAR2
                         , p_document      IN OUT NOCOPY CLOB
                         , p_document_type IN OUT NOCOPY VARCHAR2 ) IS
--START R12.2 Upgrade Remediation
  /*c_module           cust.ttec_error_handling.module_name%TYPE  := 'action_history';		-- Commented code by IXPRAVEEN-ARGANO, 04-May-2023
  v_error_msg        cust.ttec_error_handling.error_message%TYPE;*/
  c_module           apps.ttec_error_handling.module_name%TYPE  := 'action_history';		--  code Added by IXPRAVEEN-ARGANO, 04-May-2023
  v_error_msg        apps.ttec_error_handling.error_message%TYPE;
  --END R12.2.10 Upgrade remediation
  v_loc              NUMBER := 0;

  v_nid              wf_notifications.notification_id%TYPE;
  v_clob             CLOB;

  --v_trx_id           cust.ttec_hr_api_trx_values.transaction_id%TYPE;			-- Commented code by IXPRAVEEN-ARGANO, 04-May-2023
  v_trx_id           apps.ttec_hr_api_trx_values.transaction_id%TYPE;			--  code Added by IXPRAVEEN-ARGANO, 04-May-2023
  v_ntf_type         VARCHAR2(10);
  v_itemtype         wf_item_activity_statuses.item_type%TYPE;
  v_itemkey          wf_item_activity_statuses.item_key%TYPE;

  CURSOR c_get_appr_nid( l_item_type VARCHAR2, l_item_key VARCHAR2) IS
    SELECT ias.notification_id
      FROM wf_item_activity_statuses_h ias
         , wf_process_activities pa
     WHERE ias.item_type = l_item_type
       AND ias.item_key = l_item_key
       AND pa.instance_id = ias.process_activity
       AND pa.process_item_type = ias.item_type
       AND pa.activity_name = 'TTEC_HR_APPROVER_NTF'  -- Ntf Activity Name
    ORDER BY ias.begin_date DESC;

BEGIN
  v_loc := 10;
  p_document_type  := wf_notification.doc_html;

  get_wf_dtl ( p_nid        => p_document_id
             , p_trx_id     => v_trx_id
             , p_ntf_type   => v_ntf_type
             , p_itemtype   => v_itemtype
             , p_itemkey    => v_itemkey );

  -- Only include the Action History on the NTF to HC
  IF v_ntf_type = 'HC' THEN

    v_loc := 20;
    -- Get the NID of the Last Approval Notification
    OPEN c_get_appr_nid( v_itemtype, v_itemkey );
    FETCH c_get_appr_nid INTO v_nid;
    CLOSE c_get_appr_nid;

    v_loc := 30;
    -- Call the Standard Process to build the Action History
    wf_notification.GetComments2( p_nid             => v_nid
                                , p_display_type    => p_display_type
                                , p_action_history  => v_clob );

    p_document := p_document||'<br>'||v_clob;

  END IF;

EXCEPTION
  WHEN OTHERS THEN
    v_error_msg := SQLERRM;
    process_error( module_name      => c_module
                 , status           => g_status_warning
                 , error_code       => SQLCODE
                 , error_message    => v_error_msg
                 , location         => v_loc
                 , trx_id           => v_trx_id
                 , ntf_type         => v_ntf_type );
END action_history;


END TTEC_HR_WF_NTF_CUSTOM;
/
show errors;
/
