create or replace PACKAGE BODY      ttec_hr_wf_custom
AS
/* $Header: TTEC_HR_WF_CUSTOM.pkb 1.0 2009/07/14 mdodge ship $ */

   /*== START ================================================================================================*\
      Author: Michelle Dodge
        Date: July 14, 2009
   Call From: HRSSA workflow
        Desc: This package contains all code necessary to support the customizations
              to the HRSSA Workflow.  It is part of the US/CAN MSS Reimplementation.
              As such this package is meant to ultimately replace the
              TELTEC_CUSTOM_WF_UTILITY package used by the prior implementation of MSS.

     Modification History:

    Version    Date     Author   Description (Include Ticket#)
    -------  --------  --------  ------------------------------------------------------------------------------
        1.0  09/07/14  MDodge    MSS US/Can Reimplementation Project - Initial Version
        1.1  09/09/29  K&W        added TO_DATE to get_pay_period_start_date   to eliminate NULL effective Date
        1.2 28-May-10  Elango    Added ttec_bg_chk procedure for MSS PHL Phase 2 project
                                 called from HR work flow  process name is TTEC_HR_TRANSFER_JSP_PRC
        1.2 11-JUN-10  Wasim     MSS PHL Phase 2 project Added procedures  check_regularization_date & ttec_update_regularz
                                 to defualt tattribute6 for the regularization date in the employee record when status
                                 is changed from Probation to Reqularization
                                 check_regularization_date is called from WF TTEC_HR_TRANSFER_JSP_PRC
        1.3  20-Feb-13 Elango  MSS US CAN REVANA Salary Basis Change
		1.4  25-Aug-13 Kaushik MSS code change for update_asgn_trx (PHL Costing project MSS customization) -
								   To display error page and to warn the users within MSS when changing the Location of the employee
								   which would imply a change on the GRE
		1.0  15-May-23 RXNETHI-ARGANO  R12.2 Upgrade Remediation
   \*== END ==================================================================================================*/

   -- Error Constants
   /*
   START R12.2 Upgrade Remediation
   code commented by RXNETHI-ARGANO,15/05/23
   g_application_code   cust.ttec_error_handling.application_code%TYPE
                                                                      := 'HR';
   g_interface          cust.ttec_error_handling.INTERFACE%TYPE    := 'HRSSA';
   g_package            cust.ttec_error_handling.program_name%TYPE
                                                       := 'TTEC_HR_WF_CUSTOM';
   */
   --code added by RXNETHI-ARGANO,15/05/23
   g_application_code   apps.ttec_error_handling.application_code%TYPE
                                                                      := 'HR';
   g_interface          apps.ttec_error_handling.INTERFACE%TYPE    := 'HRSSA';
   g_package            apps.ttec_error_handling.program_name%TYPE
                                                       := 'TTEC_HR_WF_CUSTOM';
   --END R12.2 Upgrade Remediation
   g_status_warning     VARCHAR2 (7)                             := 'WARNING';
   g_status_failure     VARCHAR2 (7)                             := 'FAILURE';

  -- Soft Coding Keyflex Variables
--  g_no_segments          NUMBER;
--  g_app_short_name       fnd_application.application_short_name%TYPE;
--  g_key_flex_name        fnd_id_flexs.id_flex_name%TYPE := 'Soft Coded KeyFlexfield';
--  g_key_flex_code        fnd_id_flexs.id_flex_code%TYPE;
--  g_structure_num        fnd_id_flex_structures.id_flex_num%TYPE;
--  g_validation_date      DATE    := TRUNC(SYSDATE);

   /*********************************************************
   /**  Private Procedures and Functions
   *********************************************************/

   --
-- PROCEDURE process_error
--   Description: This is a wrapper procedure to the ttec_process_error procedure
--                which will pull in certain params from global variables so as
--                to minimize the number of variables input in the main code.
--
   PROCEDURE process_error (
      module_name     CHAR,
      status          CHAR,
      ERROR_CODE      NUMBER := NULL,
      error_message   CHAR := NULL,
      LOCATION        NUMBER := NULL,
      label2          CHAR := NULL,
      reference2      CHAR := NULL,
      label3          CHAR := NULL,
      reference3      CHAR := NULL,
      label4          CHAR := NULL,
      reference4      CHAR := NULL,
      label5          CHAR := NULL,
      reference5      CHAR := NULL,
      label6          CHAR := NULL,
      reference6      CHAR := NULL,
      label7          CHAR := NULL,
      reference7      CHAR := NULL,
      label8          CHAR := NULL,
      reference8      CHAR := NULL,
      label9          CHAR := NULL,
      reference9      CHAR := NULL,
      label10         CHAR := NULL,
      reference10     CHAR := NULL,
      label11         CHAR := NULL,
      reference11     CHAR := NULL,
      label12         CHAR := NULL,
      reference12     CHAR := NULL,
      label13         CHAR := NULL,
      reference13     CHAR := NULL,
      label14         CHAR := NULL,
      reference14     CHAR := NULL,
      label15         CHAR := NULL,
      reference15     CHAR := NULL
   )
   IS
      PRAGMA AUTONOMOUS_TRANSACTION;
   BEGIN
      --cust.ttec_process_error (application_code      => g_application_code, --code commented by RXNETHI-ARGANO,15/05/23
	  apps.ttec_process_error (application_code      => g_application_code, --code added by RXNETHI-ARGANO,15/05/23
                               INTERFACE             => g_interface,
                               program_name          => g_package,
                               module_name           => module_name,
                               status                => status,
                               ERROR_CODE            => ERROR_CODE,
                               error_message         => error_message,
                               label1                => 'Err Loc',
                               reference1            => LOCATION,
                               label2                => label2,
                               reference2            => reference2,
                               label3                => label3,
                               reference3            => reference3,
                               label4                => label4,
                               reference4            => reference4,
                               label5                => label5,
                               reference5            => reference5,
                               label6                => label6,
                               reference6            => reference6,
                               label7                => label7,
                               reference7            => reference7,
                               label8                => label8,
                               reference8            => reference8,
                               label9                => label9,
                               reference9            => reference9,
                               label10               => label10,
                               reference10           => reference10,
                               label11               => label11,
                               reference11           => reference11,
                               label12               => label12,
                               reference12           => reference12,
                               label13               => label13,
                               reference13           => reference13,
                               label14               => label14,
                               reference14           => reference14,
                               label15               => label15,
                               reference15           => reference15
                              );
      COMMIT;
   EXCEPTION
      WHEN OTHERS
      THEN
         NULL;
   END process_error;

--
-- FUNCTION init_sc_kff
--   Description: This function will initialize global variables for the Soft
--                Coding Keyflex.
--
-- Arguments:
--    In: p_business_group_id => Business Group ID of SC Keyflex Structure
--
   FUNCTION init_sc_kff (
      p_business_group_id   IN   apps.per_business_groups.business_group_id%TYPE
   )
      RETURN BOOLEAN
   IS
      /*
	  START R12.2 Upgrade Remediation
	  code commented by RXNETHI-ARGANO,15/05/23
	  c_module           cust.ttec_error_handling.module_name%TYPE
                                                             := 'init_sc_kff';
      v_error_msg        cust.ttec_error_handling.error_message%TYPE;
      */
	  --code added by RXNETHI-ARGANO,15/05/23
	  c_module           apps.ttec_error_handling.module_name%TYPE
                                                             := 'init_sc_kff';
      v_error_msg        apps.ttec_error_handling.error_message%TYPE;
	  --END R12.2 Upgrade Remediation
	  v_loc              NUMBER                                        := 0;
      v_application_id   fnd_application.application_id%TYPE;
   BEGIN
      -- Get the Key Flex Code
      v_loc := 10;

      SELECT fif.application_id, fa.application_short_name, fif.id_flex_code
        INTO v_application_id, g_app_short_name, g_key_flex_code
        FROM fnd_id_flexs fif, fnd_application fa
       WHERE fif.id_flex_name = g_key_flex_name
         AND fa.application_id = fif.application_id;

      -- Get the Structure Number
      v_loc := 20;

      SELECT plr.rule_mode
        INTO g_structure_num
        FROM per_business_groups pbg, pay_legislation_rules plr
       WHERE pbg.business_group_id = p_business_group_id
         AND pbg.legislation_code = plr.legislation_code(+)
         AND plr.rule_type(+) = 'S';

      -- Get Number of Segments
      v_loc := 30;

      SELECT COUNT (*)
        INTO g_no_segments
        FROM fnd_id_flex_segments
       WHERE application_id = v_application_id
         AND id_flex_code = g_key_flex_code
         AND id_flex_num = g_structure_num;

      RETURN TRUE;
   EXCEPTION
      WHEN OTHERS
      THEN
         v_error_msg := SQLERRM;
         process_error (module_name        => c_module,
                        status             => g_status_warning,
                        ERROR_CODE         => SQLCODE,
                        error_message      => v_error_msg,
                        LOCATION           => v_loc
                       );
         RETURN FALSE;
   END init_sc_kff;

--
-- PROCEDURE get_trx_value -- Overloaded Procedure for Number values
--   Description: Return the Number values from the Transaction for a
--                specified Value Name
--
-- Arguments:
--      In: p_itemtype   - ItemType of WF processing the transaction
--          p_itemkey    - ItemKey of specific WF processing the transaction
--          p_api_name   - API Name of Transaction Type to retrieve values from
--          p_value_name - Name of Number Value to be retreived from transaction
--     Out: p_value      - Current Number Value of specified Name retrieved
--          p_orig_value - Original Number Value of specified Name retrieved
--
   PROCEDURE get_trx_value (
      p_itemtype     IN       VARCHAR2,
      p_itemkey      IN       VARCHAR2,
      /*
	  START R12.2 Upgrade Remediation
	  code commente by RXNETHI-ARGANO,15/05/23
	  p_api_name     IN       hr.hr_api_transaction_steps.api_name%TYPE,
      p_value_name   IN       hr.hr_api_transaction_values.NAME%TYPE,
      p_value        OUT      hr.hr_api_transaction_values.number_value%TYPE,
      p_orig_value   OUT      hr.hr_api_transaction_values.original_number_value%TYPE
      */
	  --code added by RXNETHI-ARGANO,15/05/23
	  p_api_name     IN       apps.hr_api_transaction_steps.api_name%TYPE,
      p_value_name   IN       apps.hr_api_transaction_values.NAME%TYPE,
      p_value        OUT      apps.hr_api_transaction_values.number_value%TYPE,
      p_orig_value   OUT      apps.hr_api_transaction_values.original_number_value%TYPE
	  --END R12.2 Upgrade Remediation
   )
   IS
      /*
	  START R12.2 Upgrade Remediation
	  code commented by RXNETHI-ARGANO,15/05/23
	  c_module      cust.ttec_error_handling.module_name%TYPE
                                                  := 'get_trx_value (NUMBER)';
      
	  v_error_msg   cust.ttec_error_handling.error_message%TYPE;
      */
	  --code added by RXNETHI-ARGANO,15/05/23
      c_module      apps.ttec_error_handling.module_name%TYPE
                                                  := 'get_trx_value (NUMBER)';
      
	  v_error_msg   apps.ttec_error_handling.error_message%TYPE;
	  --END R12.2 Upgrade Remediation	  
	  v_loc         NUMBER                                        := 0;
   BEGIN
      v_loc := 10;

      SELECT number_value, original_number_value
        INTO p_value, p_orig_value
        FROM hr_api_transaction_values
       WHERE transaction_step_id IN (
                SELECT transaction_step_id
                  FROM hr_api_transaction_steps
                 WHERE item_type = p_itemtype
                   AND item_key = p_itemkey
                   AND api_name = p_api_name)
         AND NAME = p_value_name;
   EXCEPTION
      WHEN OTHERS
      THEN
         p_value := NULL;
         p_orig_value := NULL;
         v_error_msg := SQLERRM;
         process_error (module_name        => c_module,
                        status             => g_status_warning,
                        ERROR_CODE         => SQLCODE,
                        error_message      => v_error_msg,
                        LOCATION           => v_loc,
                        label2             => 'Item Key',
                        reference2         => p_itemkey,
                        label3             => 'API Name',
                        reference3         => p_api_name,
                        label4             => 'Value Name',
                        reference4         => p_value_name
                       );
   END get_trx_value;

--
-- PROCEDURE get_trx_value -- Overloaded Procedure for Text values
--   Description: Return the Text values from the Transaction for a
--                specified Value Name
--
-- Arguments:
--      In: p_itemtype   - ItemType of WF processing the transaction
--          p_itemkey    - ItemKey of specific WF processing the transaction
--          p_api_name   - API Name of Transaction Type to retrieve values from
--          p_value_name - Name of Text Value to be retreived from transaction
--     Out: p_value      - Current Text Value of specified Name retrieved
--          p_orig_value - Original Text Value of specified Name retrieved
--
   PROCEDURE get_trx_value (
      p_itemtype     IN       VARCHAR2,
      p_itemkey      IN       VARCHAR2,
      /*
	  START R12.2 Upgrade Remediation
	  code commented by RXNETHI-ARGANO,15/05/23
	  p_api_name     IN       hr.hr_api_transaction_steps.api_name%TYPE,
      p_value_name   IN       hr.hr_api_transaction_values.NAME%TYPE,
      p_value        OUT      hr.hr_api_transaction_values.varchar2_value%TYPE,
      p_orig_value   OUT      hr.hr_api_transaction_values.original_varchar2_value%TYPE
      */
	  --code added by RXNETHI-ARGANO,15/05/23
	  p_api_name     IN       apps.hr_api_transaction_steps.api_name%TYPE,
      p_value_name   IN       apps.hr_api_transaction_values.NAME%TYPE,
      p_value        OUT      apps.hr_api_transaction_values.varchar2_value%TYPE,
      p_orig_value   OUT      apps.hr_api_transaction_values.original_varchar2_value%TYPE
	  --END R12.2 Upgrade Remediation
   )
   IS
      /*
	  START R12.2 Upgrade Remediation
	  code commented by RXNETHI-ARGANO
	  c_module      cust.ttec_error_handling.module_name%TYPE
                                                := 'get_trx_value (VARCHAR2)';
      v_error_msg   cust.ttec_error_handling.error_message%TYPE;
	  */
	  --code added by RXNETHI-ARGANO,15/05/23
	  c_module      apps.ttec_error_handling.module_name%TYPE
                                                := 'get_trx_value (VARCHAR2)';
      v_error_msg   apps.ttec_error_handling.error_message%TYPE;
	  --END R12.2 Upgrade Remediation
      v_loc         NUMBER                                        := 0;
   BEGIN
      v_loc := 10;

      SELECT varchar2_value, original_varchar2_value
        INTO p_value, p_orig_value
        FROM hr_api_transaction_values
       WHERE transaction_step_id IN (
                SELECT transaction_step_id
                  FROM hr_api_transaction_steps
                 WHERE item_type = p_itemtype
                   AND item_key = p_itemkey
                   AND api_name = p_api_name)
         AND NAME = p_value_name;
   EXCEPTION
      WHEN OTHERS
      THEN
         p_value := NULL;
         p_orig_value := NULL;
         v_error_msg := SQLERRM;
         process_error (module_name        => c_module,
                        status             => g_status_warning,
                        ERROR_CODE         => SQLCODE,
                        error_message      => v_error_msg,
                        LOCATION           => v_loc,
                        label2             => 'Item Key',
                        reference2         => p_itemkey,
                        label3             => 'API Name',
                        reference3         => p_api_name,
                        label4             => 'Value Name',
                        reference4         => p_value_name
                       );
   END get_trx_value;

--
-- PROCEDURE get_trx_value -- Overloaded Procedure for Date values
--   Description: Return the Date values from the Transaction for a
--                specified Value Name
--
-- Arguments:
--      In: p_itemtype   - ItemType of WF processing the transaction
--          p_itemkey    - ItemKey of specific WF processing the transaction
--          p_api_name   - API Name of Transaction Type to retrieve values from
--          p_value_name - Name of Date Value to be retreived from transaction
--     Out: p_value      - Current Date Value of specified Name retrieved
--          p_orig_value - Original Date Value of specified Name retrieved
--
   PROCEDURE get_trx_value (
      p_itemtype     IN       VARCHAR2,
      p_itemkey      IN       VARCHAR2,
      /*
	  START R12.2 Upgrade Remediation
	  code commented by RXNETHI-ARGANO,15/05/23
	  p_api_name     IN       hr.hr_api_transaction_steps.api_name%TYPE,
      p_value_name   IN       hr.hr_api_transaction_values.NAME%TYPE,
      p_value        OUT      hr.hr_api_transaction_values.date_value%TYPE,
      p_orig_value   OUT      hr.hr_api_transaction_values.original_date_value%TYPE
      */
	  --code added by RXNETHI-ARGANO,15/05/23
	  p_api_name     IN       apps.hr_api_transaction_steps.api_name%TYPE,
      p_value_name   IN       apps.hr_api_transaction_values.NAME%TYPE,
      p_value        OUT      apps.hr_api_transaction_values.date_value%TYPE,
      p_orig_value   OUT      apps.hr_api_transaction_values.original_date_value%TYPE
	  --END R12.2 Upgrade Remediation
   )
   IS
      /*
	  START R12.2 Upgrade Remediation
	  code commented by RXNETHI-ARGANO,15/05/23
	  c_module      cust.ttec_error_handling.module_name%TYPE
                                                    := 'get_trx_value (DATE)';
      v_error_msg   cust.ttec_error_handling.error_message%TYPE;
      */
	  --code added by RXNETHI-ARGANO,15/05/23
	  c_module      apps.ttec_error_handling.module_name%TYPE
                                                    := 'get_trx_value (DATE)';
      v_error_msg   apps.ttec_error_handling.error_message%TYPE;
	  --END R12.2 Upgrade Remediation
	  v_loc         NUMBER                                        := 0;
   BEGIN
      v_loc := 10;

      SELECT date_value, original_date_value
        INTO p_value, p_orig_value
        FROM hr_api_transaction_values
       WHERE transaction_step_id IN (
                SELECT transaction_step_id
                  FROM hr_api_transaction_steps
                 WHERE item_type = p_itemtype
                   AND item_key = p_itemkey
                   AND api_name = p_api_name)
         AND NAME = p_value_name;
   EXCEPTION
      WHEN OTHERS
      THEN
         p_value := NULL;
         p_orig_value := NULL;
         v_error_msg := SQLERRM;
         process_error (module_name        => c_module,
                        status             => g_status_warning,
                        ERROR_CODE         => SQLCODE,
                        error_message      => v_error_msg,
                        LOCATION           => v_loc,
                        label2             => 'Item Key',
                        reference2         => p_itemkey,
                        label3             => 'API Name',
                        reference3         => p_api_name,
                        label4             => 'Value Name',
                        reference4         => p_value_name
                       );
   END get_trx_value;

--
-- FUNCTION update_trx_value_num
--   Description: Update the Number values in the Transaction for a
--                specified Value Name
--
-- Arguments:
--      In: p_trx_step_id - Step ID to be updated
--          p_value_name  - Name of Number Value to be updated for transaction
--          p_value       - Current Number Value of specified Name updated
--          p_orig_value  - Original Number Value of specified Name updated
--
   FUNCTION update_trx_value_num (
      p_trx_step_id   IN   NUMBER,
      /*
	  START R12.2 Upgrade Remediation
	  code commenred by RXNETHI-ARGANO,15/05/23
	  p_value_name    IN   hr.hr_api_transaction_values.NAME%TYPE,
      p_value         IN   hr.hr_api_transaction_values.number_value%TYPE,
      p_orig_value    IN   hr.hr_api_transaction_values.original_number_value%TYPE
   */
      --code added by RXNETHI-ARGANO,15/05/23
	  p_value_name    IN   apps.hr_api_transaction_values.NAME%TYPE,
      p_value         IN   apps.hr_api_transaction_values.number_value%TYPE,
      p_orig_value    IN   apps.hr_api_transaction_values.original_number_value%TYPE
	  --END R12.2 Upgrade Remediation
   )
      RETURN BOOLEAN
   IS
      /*
	  START R12.2 Upgrade Remediation
	  code commented by RXNETHI-ARGANO,15/05/23
	  c_module      cust.ttec_error_handling.module_name%TYPE
                                                    := 'update_trx_value_num';
      v_error_msg   cust.ttec_error_handling.error_message%TYPE;
      */
	  --code added by RXNETHI-ARGANO,15/05/23
	  c_module      apps.ttec_error_handling.module_name%TYPE
                                                    := 'update_trx_value_num';
      v_error_msg   apps.ttec_error_handling.error_message%TYPE;
	  --END R12.2 Upgrade Remediation
      v_loc         NUMBER                                        := 0;
   BEGIN
      v_loc := 10;

      UPDATE hr_api_transaction_values
         SET original_number_value = p_orig_value,
             number_value = p_value
       WHERE transaction_step_id = p_trx_step_id AND NAME = p_value_name;

      RETURN TRUE;
   EXCEPTION
      WHEN OTHERS
      THEN
         v_error_msg := SQLERRM;
         process_error (module_name        => c_module,
                        status             => g_status_warning,
                        ERROR_CODE         => SQLCODE,
                        error_message      => v_error_msg,
                        LOCATION           => v_loc
                       );
         RETURN FALSE;
   END update_trx_value_num;

--
-- FUNCTION get_pay_period_start_date
--   Description: Return the Start Date of the Pay Period following the input date
--                for the input Person
--
-- Arguments:
--      In: p_date       - Date that pay period must follow
--          p_assign_id  - Assignment ID to identify Start Date of next Pay Period
--  Return: Start Date of next Pay Period
--
   FUNCTION get_pay_period_start_date (
      p_date        IN   DATE,
      --p_assign_id   IN   hr.per_all_assignments_f.assignment_id%TYPE --code commented by RXNETHI-ARGANO,15/05/23
	  p_assign_id   IN   apps.per_all_assignments_f.assignment_id%TYPE --code added by RXNETHI-ARGANO,15/05/23
   )
      RETURN DATE
   IS
      /*
	  START R12.2 Upgrade Remediation
	  code commented by RXNETHI-ARGANO,15/05/23
	  c_module      cust.ttec_error_handling.module_name%TYPE
                                                    := 'get_pay_period_start_date';
      v_error_msg   cust.ttec_error_handling.error_message%TYPE;
      */
	  --code added by RXNETHI-ARGANO,15/05/23
	  c_module      apps.ttec_error_handling.module_name%TYPE
                                                    := 'get_pay_period_start_date';
      v_error_msg   apps.ttec_error_handling.error_message%TYPE;
	  --END R12.2 Upgrade Remediation
      v_loc         NUMBER                                        := 0;
      retdate       DATE;
   BEGIN
      v_loc := 10;

      -- Get the current Pay Period and add 1 to End Date
      -- to get Start Date of next period
      /* added TO_DATE to elimiate truncation */
      SELECT ptp.end_date + 1
        INTO retdate
        FROM per_all_assignments_f paa, per_time_periods ptp
       WHERE paa.assignment_id = p_assign_id
         AND SYSDATE BETWEEN paa.effective_start_date AND paa.effective_end_date
         AND ptp.payroll_id = paa.payroll_id
         AND TO_DATE (p_date) BETWEEN ptp.start_date AND ptp.end_date;

      RETURN retdate;
   EXCEPTION
      WHEN OTHERS
      THEN
         v_error_msg := SQLERRM;
         process_error (module_name        => c_module,
                        status             => g_status_warning,
                        ERROR_CODE         => SQLCODE,
                        error_message      => v_error_msg,
                        LOCATION           => v_loc
                       );
         RETURN NULL;
   END get_pay_period_start_date;

/*********************************************************
/**  Public Functions
*********************************************************/

   -- FUNCTION init_session_vars
-- Description: This function will initialize session and profile variables for
--              the MSS session to behave properly.
--
   FUNCTION init_session_vars (
      p_bus_grp_id   IN   NUMBER,
      p_org_id       IN   NUMBER,
      p_asgn_id      IN   NUMBER
   )
      RETURN BOOLEAN
   IS
      /*
	  START R12.2 Upgrade Remediation
	  code commented by RXNETHI-ARGANO,15/05/23
	  c_module       cust.ttec_error_handling.module_name%TYPE
                                                       := 'init_session_vars';
      v_error_msg    cust.ttec_error_handling.error_message%TYPE;
	  */
	  --code added by RXNETHI-ARGANO,15/05/23
	  c_module       apps.ttec_error_handling.module_name%TYPE
                                                       := 'init_session_vars';
      v_error_msg    apps.ttec_error_handling.error_message%TYPE;
	  --END R12.2 Upgrade Remediation
      v_loc          NUMBER                                        := 0;
      v_session_id   fnd_sessions.session_id%TYPE;
      v_sess_id      NUMBER;
      v_language     VARCHAR2 (10);
      v_found        VARCHAR2 (10)                                 := 'FALSE';
      v_org_id       NUMBER;
      v_bg_id        NUMBER;
   BEGIN
      v_loc := 10;

      -- Set Session values if not already set
      BEGIN
         SELECT session_id
           INTO v_session_id
           FROM fnd_sessions
          WHERE session_id = USERENV ('SESSIONID');
      EXCEPTION
         WHEN NO_DATA_FOUND
         THEN
            INSERT INTO fnd_sessions
                 VALUES (USERENV ('SESSIONID'), TRUNC (SYSDATE));
      END;

      -- Set Profile variables for Employee being transacted
      v_loc := 20;
      fnd_profile.put (NAME => 'PER_BUSINESS_GROUP_ID', val => p_bus_grp_id);
      fnd_profile.put (NAME => 'PER_ORGANIZATION_ID', val => p_org_id);
      fnd_profile.put (NAME => 'PER_ASSIGNMENT_ID', val => p_asgn_id);
      RETURN TRUE;
   EXCEPTION
      WHEN OTHERS
      THEN
         v_error_msg := SQLERRM;
         process_error (module_name        => c_module,
                        status             => g_status_warning,
                        ERROR_CODE         => SQLCODE,
                        error_message      => v_error_msg,
                        LOCATION           => v_loc
                       );
         RETURN FALSE;
   END init_session_vars;

--
-- FUNCTION get_sc_kff
--   Description: This function will retrieve the segment values of the Soft Coding
--                Keyflex from the input Keyflex ID.
--
   FUNCTION get_sc_kff (
      --p_sc_keyflex_id   IN       hr.per_all_assignments_f.soft_coding_keyflex_id%TYPE, --code commented by RXNETHI-ARGANO,15/05/23
	  p_sc_keyflex_id   IN       apps.per_all_assignments_f.soft_coding_keyflex_id%TYPE, --code added by RXNETHI-ARGANO,15/05/23
      p_kff_segments    OUT      fnd_flex_ext.segmentarray
   )
      RETURN BOOLEAN
   IS
      --c_module      cust.ttec_error_handling.module_name%TYPE := 'get_sc_kff'; --code commented by RXNETHI-ARGANO,15/05/23
      --v_error_msg   cust.ttec_error_handling.error_message%TYPE;               --code commented by RXNETHI-ARGANO,15/05/23
	  c_module      apps.ttec_error_handling.module_name%TYPE := 'get_sc_kff'; --code added by RXNETHI-ARGANO,15/05/23
      v_error_msg   apps.ttec_error_handling.error_message%TYPE;               --code added by RXNETHI-ARGANO,15/05/23
      v_loc         NUMBER                                        := 0;
      v_valid       BOOLEAN;
      e_error       EXCEPTION;
   BEGIN
      v_loc := 10;

      -- Get the Segments for the current Soft Coding KeyFlex ID
      IF p_sc_keyflex_id IS NULL
      THEN
         v_loc := 20;

         --Initialize the p_kff_segments
         FOR i IN 1 .. g_no_segments
         LOOP
            p_kff_segments (i) := NULL;
         END LOOP;

         v_valid := TRUE;
      ELSE
         v_loc := 30;
         v_valid :=
            fnd_flex_ext.get_segments
                                 (application_short_name      => g_app_short_name,
                                  key_flex_code               => g_key_flex_code,
                                  structure_number            => g_structure_num,
                                  combination_id              => p_sc_keyflex_id,
                                  n_segments                  => g_no_segments,
                                  segments                    => p_kff_segments
                                 );
      END IF;

      IF NOT v_valid
      THEN
         v_error_msg := fnd_message.get;
         RAISE e_error;
      END IF;

      RETURN TRUE;
   EXCEPTION
      WHEN e_error
      THEN
         process_error (module_name        => c_module,
                        status             => g_status_warning,
                        ERROR_CODE         => NULL,
                        error_message      => v_error_msg,
                        LOCATION           => v_loc
                       );
         RETURN FALSE;
      WHEN OTHERS
      THEN
         v_error_msg := SQLERRM;
         process_error (module_name        => c_module,
                        status             => g_status_warning,
                        ERROR_CODE         => SQLCODE,
                        error_message      => v_error_msg,
                        LOCATION           => v_loc
                       );
         RETURN FALSE;
   END get_sc_kff;

--
-- FUNCTION build_sc_kff
--   Description: This function will build/retrieve the Soft Coding Keyflex ID for
--                the input segment array values.
--
   FUNCTION build_sc_kff (
      p_kff_segments    IN       fnd_flex_ext.segmentarray,
     --p_sc_keyflex_id   OUT      hr.per_all_assignments_f.soft_coding_keyflex_id%TYPE --code commented by RXNETHI-ARGANO,15/05/23
	 p_sc_keyflex_id   OUT      apps.per_all_assignments_f.soft_coding_keyflex_id%TYPE --code added by RXNETHI-ARGANO,15/05/23
   )
      RETURN BOOLEAN
   IS
      /*
	  START R12.2 Upgrade Remediation
	  code commented by RXNETHI-ARGANO,15/05/23
	  c_module      cust.ttec_error_handling.module_name%TYPE
                                                            := 'build_sc_kff';
      v_error_msg   cust.ttec_error_handling.error_message%TYPE;
      */
	  --code added by RXNETHI-ARGANO,15/05/23
	  c_module      apps.ttec_error_handling.module_name%TYPE
                                                            := 'build_sc_kff';
      v_error_msg   apps.ttec_error_handling.error_message%TYPE;
	  --END R12.2 Upgrade Remediation
	  v_loc         NUMBER                                        := 0;
      v_valid       BOOLEAN;
      e_error       EXCEPTION;
   BEGIN
      v_loc := 10;
      -- Get the Combination ID for the Newly built Soft Coding KeyFlex Segment Array
      v_valid :=
         fnd_flex_ext.get_combination_id
                                 (application_short_name      => g_app_short_name,
                                  key_flex_code               => g_key_flex_code,
                                  structure_number            => g_structure_num,
                                  validation_date             => g_validation_date,
                                  n_segments                  => g_no_segments,
                                  segments                    => p_kff_segments,
                                  combination_id              => p_sc_keyflex_id
                                 );

      IF NOT v_valid
      THEN
         v_error_msg := fnd_message.get;
         RAISE e_error;
      END IF;

      RETURN TRUE;
   EXCEPTION
      WHEN e_error
      THEN
         process_error (module_name        => c_module,
                        status             => g_status_warning,
                        ERROR_CODE         => NULL,
                        error_message      => v_error_msg,
                        LOCATION           => v_loc
                       );
         RETURN FALSE;
      WHEN OTHERS
      THEN
         v_error_msg := SQLERRM;
         process_error (module_name        => c_module,
                        status             => g_status_warning,
                        ERROR_CODE         => SQLCODE,
                        error_message      => v_error_msg,
                        LOCATION           => v_loc
                       );
         RETURN FALSE;
   END build_sc_kff;

--
-- FUNCTION add_bus_days
--   Description: This Function will take a start date and number of business days
--                to add and return an end_date (in real time).  Currently Business
--                Days only excludes weekend days of Saturday and Sunday
--
   FUNCTION add_bus_days (p_start_date IN DATE, p_num_bus_days IN NUMBER)
      RETURN DATE
   IS
      /*
	  START R12.2 Upgrade Remediation
	  code commented by RXNETHI-ARGANO,15/05/23
	  c_module       cust.ttec_error_handling.module_name%TYPE
                                                            := 'add_bus_days';
      v_error_msg    cust.ttec_error_handling.error_message%TYPE;
      */
	  --code added by RXNETHI-ARGANO,15/05/23
	  c_module       apps.ttec_error_handling.module_name%TYPE
                                                            := 'add_bus_days';
      v_error_msg    apps.ttec_error_handling.error_message%TYPE;
	  --END R12.2 Upgrade Remediation
	  v_loc          NUMBER                                        := 0;
      v_start_date   DATE                                     := p_start_date;
      v_end_date     DATE;
      v_num_weeks    NUMBER;
      v_rem_days     NUMBER;
      v_start_dow    VARCHAR2 (10);                            -- Day of Week
      v_end_dow      VARCHAR2 (10);
      v_end_week     DATE;
   BEGIN
      v_loc := 10;
      -- Calculate the number of Weeks and Business Days left over
      v_num_weeks := TRUNC (p_num_bus_days / 5);
      v_rem_days := MOD (p_num_bus_days, 5);
      v_loc := 20;
      -- Get the Day of Week for the Start Day
      v_start_dow := TRIM (TO_CHAR (v_start_date, 'DAY'));

      -- If Start Date is on a weekend reset to 0 hours on Monday morning
      IF v_start_dow IN ('SATURDAY', 'SUNDAY')
      THEN
         v_start_date := TRUNC (NEXT_DAY (v_start_date, 'MONDAY'));
      END IF;

      v_loc := 30;
      -- Add Weeks to Start Date to get initial End Date
      v_end_date := v_start_date + (v_num_weeks * 7);
      -- Get Friday Date of current end date week
      v_end_dow := TRIM (TO_CHAR (v_end_date, 'DAY'));

      IF v_end_dow = 'FRIDAY'
      THEN
         v_end_week := TRUNC (v_end_date);
      ELSE
         v_end_week := TRUNC (NEXT_DAY (v_end_date, 'FRIDAY'));
      END IF;

      v_loc := 40;
      -- Add remaining days to end date
      v_end_date := v_end_date + v_rem_days;

      -- If the Remain Days cross a weekend or ends on a weekend add 2 days
      IF TRUNC (v_end_date) > v_end_week
      THEN
         v_end_date := v_end_date + 2;
      END IF;

      RETURN v_end_date;
   EXCEPTION
      WHEN OTHERS
      THEN
         v_error_msg := SQLERRM;
         process_error (module_name        => c_module,
                        status             => g_status_warning,
                        ERROR_CODE         => SQLCODE,
                        error_message      => v_error_msg,
                        LOCATION           => v_loc
                       );
         RETURN NULL;
   END add_bus_days;

/*********************************************************
/**  WF Procedures - Called directly from WF Functions
*********************************************************/

   --
-- PROCEDURE has_value_changed
--   Description: This Procedure will determine if the user has altered the input
--                column_name or not.
--
   PROCEDURE has_value_changed (
      p_itemtype   IN              VARCHAR2,
      p_itemkey    IN              VARCHAR2,
      p_actid      IN              NUMBER,
      p_funcmode   IN              VARCHAR2,
      p_result     OUT NOCOPY      VARCHAR2
   )
   IS
      /*
	  START R12.2 Upgrade Remediation
	  code commented by RXNETHI-ARGANO,15/05/23
	  c_module            cust.ttec_error_handling.module_name%TYPE
                                                       := 'has_value_changed';
      v_error_msg         cust.ttec_error_handling.error_message%TYPE;
      v_loc               NUMBER                                         := 0;
      v_datatype          hr.hr_api_transaction_values.datatype%TYPE;
      v_column_name       hr.hr_api_transaction_values.NAME%TYPE;
      v_new_char_value    hr.hr_api_transaction_values.varchar2_value%TYPE;
      v_new_num_value     hr.hr_api_transaction_values.number_value%TYPE;
      v_new_date_value    hr.hr_api_transaction_values.date_value%TYPE;
      v_orig_char_value   hr.hr_api_transaction_values.original_varchar2_value%TYPE;
      v_orig_num_value    hr.hr_api_transaction_values.original_number_value%TYPE;
      v_orig_date_value   hr.hr_api_transaction_values.original_date_value%TYPE;
      */
	  --code added by RXNETHI-ARGANO,15/05/23
	  c_module            apps.ttec_error_handling.module_name%TYPE
                                                       := 'has_value_changed';
      v_error_msg         apps.ttec_error_handling.error_message%TYPE;
      v_loc               NUMBER                                         := 0;
      v_datatype          apps.hr_api_transaction_values.datatype%TYPE;
      v_column_name       apps.hr_api_transaction_values.NAME%TYPE;
      v_new_char_value    apps.hr_api_transaction_values.varchar2_value%TYPE;
      v_new_num_value     apps.hr_api_transaction_values.number_value%TYPE;
      v_new_date_value    apps.hr_api_transaction_values.date_value%TYPE;
      v_orig_char_value   apps.hr_api_transaction_values.original_varchar2_value%TYPE;
      v_orig_num_value    apps.hr_api_transaction_values.original_number_value%TYPE;
      v_orig_date_value   apps.hr_api_transaction_values.original_date_value%TYPE;
	  --END R12.2 Upgrade Remediation
   BEGIN
      v_loc := 10;

      IF p_funcmode = 'RUN'
      THEN
         -- Get the parameter value for WF Activity
         v_column_name :=
            wf_engine.getactivityattrtext (itemtype      => p_itemtype,
                                           itemkey       => p_itemkey,
                                           actid         => p_actid,
                                           aname         => 'TTEC_COLUMN_NAME'
                                          );
         v_loc := 20;

         -- Get the column values
         SELECT datatype, varchar2_value, number_value,
                date_value, original_varchar2_value, original_number_value,
                original_date_value
           INTO v_datatype, v_new_char_value, v_new_num_value,
                v_new_date_value, v_orig_char_value, v_orig_num_value,
                v_orig_date_value
           FROM hr_api_transaction_values
          WHERE transaction_step_id IN (
                         SELECT transaction_step_id
                           FROM hr_api_transaction_steps
                          WHERE item_type = p_itemtype
                                AND item_key = p_itemkey)
            AND NAME = v_column_name
            AND ROWNUM < 2;

         v_loc := 30;

         -- Compare Values by Type
         IF v_datatype = 'VARCHAR2'
         THEN
            IF v_new_char_value != NVL (v_orig_char_value, v_new_char_value)
            THEN
               p_result := 'COMPLETE:Y';
            ELSE
               p_result := 'COMPLETE:N';
            END IF;
         ELSIF v_datatype = 'NUMBER'
         THEN
            IF v_new_num_value != NVL (v_orig_num_value, v_new_num_value)
            THEN
               p_result := 'COMPLETE:Y';
            ELSE
               p_result := 'COMPLETE:N';
            END IF;
         ELSIF v_datatype = 'DATE'
         THEN
            IF v_new_date_value != NVL (v_orig_date_value, v_new_date_value)
            THEN
               p_result := 'COMPLETE:Y';
            ELSE
               p_result := 'COMPLETE:N';
            END IF;
         END IF;
      END IF;
   EXCEPTION
      WHEN NO_DATA_FOUND
      THEN
         -- No Transaction Value record - thus no changes
         p_result := 'COMPLETE:N';
      WHEN OTHERS
      THEN
         v_error_msg := SQLERRM;
         process_error (module_name        => c_module,
                        status             => g_status_warning,
                        ERROR_CODE         => SQLCODE,
                        error_message      => v_error_msg,
                        LOCATION           => v_loc
                       );
         p_result := 'ERROR:' || SUBSTR (SQLERRM, 1, 30);
   END has_value_changed;

--
-- PROCEDURE update_asgn_trx
--   Description: This Procedure will update the Assignment Transaction based on a
--                changed Job or Location.  The fields that may be updated include
--                Salary Basis, GRE, Payroll, and TimeCard Required.
--
   PROCEDURE update_asgn_trx (
      p_itemtype   IN              VARCHAR2,
      p_itemkey    IN              VARCHAR2,
      p_actid      IN              NUMBER,
      p_funcmode   IN              VARCHAR2,
      p_result     OUT NOCOPY      VARCHAR2
   )
   IS
      /*
	  START R12.2 Upgrade Remediation
	  code commented by RXNETHI-ARGANO,15/05/23
	  c_module               cust.ttec_error_handling.module_name%TYPE
                                                         := 'update_asgn_trx';
      v_error_msg            cust.ttec_error_handling.error_message%TYPE;
      v_loc                  NUMBER                                      := 0;
      c_trx_step_api         hr.hr_api_transaction_steps.api_name%TYPE
                                    := 'HR_PROCESS_ASSIGNMENT_SS.PROCESS_API';
      c_job_id_name          hr.hr_api_transaction_values.NAME%TYPE
                                                                := 'P_JOB_ID';
      c_location_id_name     hr.hr_api_transaction_values.NAME%TYPE
                                                           := 'P_LOCATION_ID';
      c_pay_basis_name       hr.hr_api_transaction_values.NAME%TYPE
                                                          := 'P_PAY_BASIS_ID';
      c_payroll_id_name      hr.hr_api_transaction_values.NAME%TYPE
                                                            := 'P_PAYROLL_ID';
      c_stat_info_name       hr.hr_api_transaction_values.NAME%TYPE
                                                := 'P_SOFT_CODING_KEYFLEX_ID';
      c_bus_group_id_name    hr.hr_api_transaction_values.NAME%TYPE
                                                     := 'P_BUSINESS_GROUP_ID';
      c_assign_id_name       hr.hr_api_transaction_values.NAME%TYPE
                                                         := 'P_ASSIGNMENT_ID';
      c_org_id_name          hr.hr_api_transaction_values.NAME%TYPE
                                                       := 'P_ORGANIZATION_ID';
	  */
	  --code added by RXNETHI-ARGANO,15/05/23
	  c_module               apps.ttec_error_handling.module_name%TYPE
                                                         := 'update_asgn_trx';
      v_error_msg            apps.ttec_error_handling.error_message%TYPE;
      v_loc                  NUMBER                                      := 0;
      c_trx_step_api         apps.hr_api_transaction_steps.api_name%TYPE
                                    := 'HR_PROCESS_ASSIGNMENT_SS.PROCESS_API';
      c_job_id_name          apps.hr_api_transaction_values.NAME%TYPE
                                                                := 'P_JOB_ID';
      c_location_id_name     apps.hr_api_transaction_values.NAME%TYPE
                                                           := 'P_LOCATION_ID';
      c_pay_basis_name       apps.hr_api_transaction_values.NAME%TYPE
                                                          := 'P_PAY_BASIS_ID';
      c_payroll_id_name      apps.hr_api_transaction_values.NAME%TYPE
                                                            := 'P_PAYROLL_ID';
      c_stat_info_name       apps.hr_api_transaction_values.NAME%TYPE
                                                := 'P_SOFT_CODING_KEYFLEX_ID';
      c_bus_group_id_name    apps.hr_api_transaction_values.NAME%TYPE
                                                     := 'P_BUSINESS_GROUP_ID';
      c_assign_id_name       apps.hr_api_transaction_values.NAME%TYPE
                                                         := 'P_ASSIGNMENT_ID';
      c_org_id_name          apps.hr_api_transaction_values.NAME%TYPE
                                                       := 'P_ORGANIZATION_ID';
	  --END R12.2 Upgrade Remediation
      v_transaction_id       NUMBER;
      v_trx_step_id          NUMBER;
      v_bus_group_id         NUMBER;
      v_org_id               NUMBER;
      v_assign_id            NUMBER;
      v_job_id               NUMBER;
      v_location_id          NUMBER;
      v_curr_payroll_id      NUMBER;
      v_new_payroll_id       NUMBER;
      v_curr_pay_basis_id    NUMBER;
      v_new_pay_basis_id     NUMBER;
      v_curr_sc_kff_id       NUMBER;
      v_new_sc_kff_id        NUMBER;
      v_curr_gre             hr_locations_all.attribute7%TYPE;
      v_new_gre              hr_locations_all.attribute7%TYPE;
      v_curr_tc_req          VARCHAR2 (10);
      v_new_tc_req           VARCHAR2 (10);
      v_new_pay_basis_name   per_pay_bases.pay_basis%TYPE;
      v_kff_segments         fnd_flex_ext.segmentarray;
      v_valid                BOOLEAN;
      v_dummy                NUMBER;
      --v_tmp_message          cust.ttec_error_handling.error_message%TYPE; --code commented by RXNETHI-ARGANO,15/05/23
	  v_tmp_message          apps.ttec_error_handling.error_message%TYPE; --code added by RXNETHI-ARGANO,15/05/23
      e_error                EXCEPTION;

      CURSOR c_get_job_info (l_job_id IN NUMBER)
      IS
         SELECT NAME job_name, NVL (attribute9, 'XXX999') dac_flsa,
                NVL (job_information3, 'XXX999') flsa
           FROM per_jobs pj
          WHERE pj.job_id = l_job_id;

      r_job_info             c_get_job_info%ROWTYPE;
   BEGIN
      v_loc := 10;

      IF p_funcmode = 'RUN'
      THEN
         v_loc := 20;
         -- Get the Transaction ID from the WF Item Key
         v_transaction_id :=
            wf_engine.getitemattrnumber (itemtype      => p_itemtype,
                                         itemkey       => p_itemkey,
                                         aname         => 'TRANSACTION_ID'
                                        );

         -- Get the Trx Step ID
         SELECT transaction_step_id
           INTO v_trx_step_id
           FROM hr_api_transaction_steps
          WHERE transaction_id = v_transaction_id
            AND api_name = c_trx_step_api
            AND ROWNUM < 2;

         -- Get the Business Group ID
         get_trx_value (p_itemtype        => p_itemtype,
                        p_itemkey         => p_itemkey,
                        p_api_name        => c_trx_step_api,
                        p_value_name      => c_bus_group_id_name,
                        p_value           => v_bus_group_id,
                        p_orig_value      => v_dummy
                       );

         -- Only continue for US and CAN
         IF v_bus_group_id IN (325, 326, 1517)				-- v1.4
         THEN
            v_loc := 30;
/*************************************************************/
/* Initialize variables                                      */
/*************************************************************/

            -- Initialize the Global Variable for the Soft Coding Keyflex
            v_valid := init_sc_kff (p_business_group_id => v_bus_group_id);

            IF NOT v_valid
            THEN
               v_error_msg := 'Unable to Initialize SC KFF';
               RAISE e_error;
            END IF;

            -- Initialize KFF Segments
            FOR i IN 1 .. g_no_segments
            LOOP
               v_kff_segments (i) := NULL;
            END LOOP;

            -- Initialize session for employee being transacted
            get_trx_value (p_itemtype        => p_itemtype,
                           p_itemkey         => p_itemkey,
                           p_api_name        => c_trx_step_api,
                           p_value_name      => c_org_id_name,
                           p_value           => v_org_id,
                           p_orig_value      => v_dummy
                          );
            get_trx_value (p_itemtype        => p_itemtype,
                           p_itemkey         => p_itemkey,
                           p_api_name        => c_trx_step_api,
                           p_value_name      => c_assign_id_name,
                           p_value           => v_assign_id,
                           p_orig_value      => v_dummy
                          );
            -- Initialize Session Profiles
            v_valid :=
               init_session_vars (p_bus_grp_id      => v_bus_group_id,
                                  p_org_id          => v_org_id,
                                  p_asgn_id         => v_assign_id
                                 );

            IF NOT v_valid
            THEN
               v_error_msg :=
                            'Encountered Error initializing session profiles';
               RAISE e_error;
            END IF;

/*************************************************************/
/* Get New Job and Location as one has changed               */
/*************************************************************/
            v_loc := 40;
            get_trx_value (p_itemtype        => p_itemtype,
                           p_itemkey         => p_itemkey,
                           p_api_name        => c_trx_step_api,
                           p_value_name      => c_job_id_name,
                           p_value           => v_job_id,
                           p_orig_value      => v_dummy
                          );
            get_trx_value (p_itemtype        => p_itemtype,
                           p_itemkey         => p_itemkey,
                           p_api_name        => c_trx_step_api,
                           p_value_name      => c_location_id_name,
                           p_value           => v_location_id,
                           p_orig_value      => v_dummy
                          );
/*************************************************************/
/* Get Current Salary Basis, Payroll, Timecard Required      */
/* and GRE values for Assignment                             */
/*************************************************************/
            v_loc := 50;
            get_trx_value (p_itemtype        => p_itemtype,
                           p_itemkey         => p_itemkey,
                           p_api_name        => c_trx_step_api,
                           p_value_name      => c_payroll_id_name,
                           p_value           => v_curr_payroll_id,
                           p_orig_value      => v_dummy
                          );
            get_trx_value (p_itemtype        => p_itemtype,
                           p_itemkey         => p_itemkey,
                           p_api_name        => c_trx_step_api,
                           p_value_name      => c_pay_basis_name,
                           p_value           => v_curr_pay_basis_id,
                           p_orig_value      => v_dummy
                          );
            get_trx_value (p_itemtype        => p_itemtype,
                           p_itemkey         => p_itemkey,
                           p_api_name        => c_trx_step_api,
                           p_value_name      => c_stat_info_name,
                           p_value           => v_curr_sc_kff_id,
                           p_orig_value      => v_dummy
                          );
            -- Get the GRE and TimeCard Required Values from the Soft Coding Keyflex
            v_loc := 60;
            v_valid :=
               get_sc_kff (p_sc_keyflex_id      => v_curr_sc_kff_id,
                           p_kff_segments       => v_kff_segments
                          );

            IF v_valid
            THEN
               v_curr_gre := v_kff_segments (1);

               -- Segments are in order DISPLAYED, NOT order by segment#
               IF v_bus_group_id = 325
               THEN                                                     -- US
                  v_curr_tc_req := v_kff_segments (3);
               ELSE                                                     -- CAN
                  v_curr_tc_req := v_kff_segments (5);
               END IF;
            END IF;

/*************************************************************/
/* Calculate the new Salary Basis, Payroll, Timecard         */
/* Required and GRE Values from the Assignment changes       */
/*************************************************************/

            -- Calculate the new Payroll ID first as it drives the Salary Basis ID
            -- Get the GRE at the same time as they are stored on the same record
            v_loc := 70;

            BEGIN
               SELECT hl.attribute7, ppf.payroll_id
                 INTO v_new_gre, v_new_payroll_id
                 FROM hr_locations_all hl, pay_all_payrolls_f ppf
                WHERE hl.location_id = v_location_id
                  AND ppf.payroll_name(+) = hl.attribute8
                  AND SYSDATE BETWEEN ppf.effective_start_date(+) AND ppf.effective_end_date(+);
            EXCEPTION
               WHEN OTHERS
               THEN
                  v_new_gre := v_curr_gre;
                  v_new_payroll_id := v_curr_payroll_id;
            END;

            -- Now Get the Pay Basis ID
            v_loc := 80;

            OPEN c_get_job_info (v_job_id);

            FETCH c_get_job_info
             INTO r_job_info;

            CLOSE c_get_job_info;

            v_loc := 90;

/*   version 1.3  by elango pandurangan
            IF v_bus_group_id = 325
            THEN                                                         -- US
               IF r_job_info.job_name LIKE 'D%' AND v_new_payroll_id = 280
               THEN       -- US DAC - Use latest calculated Payroll ID here!!
                  IF r_job_info.dac_flsa = 'EX'
                  THEN
                     v_new_pay_basis_id := 63;
                  ELSIF r_job_info.dac_flsa = 'NEX'
                  THEN
                     v_new_pay_basis_id := 62;
                  ELSIF r_job_info.dac_flsa = 'SNE'
                  THEN
                     v_new_pay_basis_id := 239;
                  ELSE
                     v_new_pay_basis_id := v_curr_pay_basis_id;
                  END IF;
               ELSE                                              -- US Non-DAC
                  IF r_job_info.flsa = 'EX'
                  THEN
                     v_new_pay_basis_id := 63;
                  ELSIF r_job_info.flsa = 'NEX'
                  THEN
                     v_new_pay_basis_id := 62;
                  ELSE
                     v_new_pay_basis_id := v_curr_pay_basis_id;
                  END IF;
               END IF;
            ELSIF v_bus_group_id = 326
            THEN                                                        -- CAN
               IF r_job_info.flsa = 'EX'
               THEN
                  v_new_pay_basis_id := 43;
               ELSIF r_job_info.flsa = 'NEX'
               THEN
                  v_new_pay_basis_id := 42;
               ELSE
                  v_new_pay_basis_id := v_curr_pay_basis_id;
               END IF;
            ELSE
               v_new_pay_basis_id := v_curr_pay_basis_id;
            END IF;
*/
            IF v_bus_group_id = 325
            THEN
               IF v_new_payroll_id = 280
               THEN
                  IF r_job_info.dac_flsa = 'SNE'
                  THEN
                     v_new_pay_basis_id := 239;
                  ELSIF r_job_info.dac_flsa <> 'SNE'
                  THEN
                     IF r_job_info.flsa = 'EX'
                     THEN
                        v_new_pay_basis_id := 63;
                     ELSIF r_job_info.flsa = 'NEX'
                     THEN
                        v_new_pay_basis_id := 62;
                     ELSE
                        v_new_pay_basis_id := v_curr_pay_basis_id;
                     END IF;                                    -- FLSA en dif
                  END IF;
               ELSE                                        -- payroll 280 else
                  IF r_job_info.flsa = 'EX'
                  THEN
                     v_new_pay_basis_id := 63;
                  ELSIF r_job_info.flsa = 'NEX'
                  THEN
                     v_new_pay_basis_id := 62;
                  ELSE
                     v_new_pay_basis_id := v_curr_pay_basis_id;
                  END IF;
               END IF;                                         -- payroll else
            ELSIF v_bus_group_id = 326
            THEN
               IF v_new_payroll_id = 280
               THEN
                  IF r_job_info.dac_flsa <> 'SNE'
                  THEN
                     IF r_job_info.flsa = 'EX'
                     THEN
                        v_new_pay_basis_id := 43;
                     ELSIF r_job_info.flsa = 'NEX'
                     THEN
                        v_new_pay_basis_id := 42;
                     ELSE
                        v_new_pay_basis_id := v_curr_pay_basis_id;
                     END IF;                                    -- FLSA en dif
                  ELSE                                    -- dac flsa SNE else
                     v_new_pay_basis_id := v_curr_pay_basis_id;
                  END IF;                               -- dac_flsa sne end if
               ELSE                                        -- payroll 280 else
                  IF r_job_info.flsa = 'EX'
                  THEN
                     v_new_pay_basis_id := 43;
                  ELSIF r_job_info.flsa = 'NEX'
                  THEN
                     v_new_pay_basis_id := 42;
                  ELSE
                     v_new_pay_basis_id := v_curr_pay_basis_id;
                  END IF;
               END IF;
            END IF;

            -- Now Determine the TimeCard Required value
            v_loc := 100;

            BEGIN
               SELECT pay_basis
                 INTO v_new_pay_basis_name
                 FROM per_pay_bases
                WHERE pay_basis_id = v_new_pay_basis_id;

               IF v_new_pay_basis_name = 'ANNUAL'
               THEN
                  v_new_tc_req := 'No';
               ELSIF v_new_pay_basis_name = 'HOURLY'
               THEN
                  v_new_tc_req := 'Yes';
               ELSE
                  v_new_tc_req := v_curr_tc_req;
               END IF;
            EXCEPTION
               WHEN OTHERS
               THEN
                  v_new_tc_req := v_curr_tc_req;
            END;

/*************************************************************/
/* Update Transaction with changes to the Salary Basis,      */
/* Payroll, Timecard Required and GRE values for Assignment  */
/*************************************************************/
				-- v1.4
            IF     v_bus_group_id = 1517
               AND (   NVL (v_new_payroll_id, 0) != NVL (v_curr_payroll_id, 0)
                    OR NVL (v_new_gre, ' ') != NVL (v_curr_gre, ' ')
                   -- OR NVL (v_new_tc_req, ' ') != NVL (v_curr_tc_req, ' ')
                   )
            THEN
               v_loc := 105;
               v_error_msg := 'Transaction cannot be submitted Contact HR.';
               RAISE e_error;				-- v1.4
            ELSE
               -- Update the Payroll if it has changed
               v_loc := 110;

               IF NVL (v_new_payroll_id, 0) != NVL (v_curr_payroll_id, 0)
               THEN
                  v_valid :=
                     update_trx_value_num (p_trx_step_id      => v_trx_step_id,
                                           p_value_name       => c_payroll_id_name,
                                           p_value            => v_new_payroll_id,
                                           p_orig_value       => v_curr_payroll_id
                                          );

                  IF NOT v_valid
                  THEN
                     v_error_msg :=
                               'Encountered Error updating Payroll ID on Trx';
                     RAISE e_error;
                  END IF;
               END IF;

               -- Update the Salary Basis if it has changed
               v_loc := 120;

               IF NVL (v_new_pay_basis_id, 0) != NVL (v_curr_pay_basis_id, 0)
               THEN
                  v_valid :=
                     update_trx_value_num
                                         (p_trx_step_id      => v_trx_step_id,
                                          p_value_name       => c_pay_basis_name,
                                          p_value            => v_new_pay_basis_id,
                                          p_orig_value       => v_curr_pay_basis_id
                                         );

                  IF NOT v_valid
                  THEN
                     v_error_msg :=
                             'Encountered Error updating Pay Basis ID on Trx';
                     RAISE e_error;
                  END IF;
               END IF;

               -- Update the Soft Coding Keyflex (including TimeCard Required and GRE) if it has changed
               v_loc := 130;

               IF    NVL (v_new_gre, ' ') != NVL (v_curr_gre, ' ')
                  OR NVL (v_new_tc_req, ' ') != NVL (v_curr_tc_req, ' ')
               THEN
                  -- Segments must be input in order DISPLAYED, not order by segment #
                  v_kff_segments (1) := v_new_gre;

                  IF v_bus_group_id = 325
                  THEN                                                  -- US
                     v_kff_segments (3) := v_new_tc_req;
                  ELSE                                                  -- CAN
                     v_kff_segments (5) := v_new_tc_req;
                  END IF;

                  -- Build a new Soft Coding Keyflex ID
                  v_loc := 140;
                  v_valid :=
                     build_sc_kff (p_kff_segments       => v_kff_segments,
                                   p_sc_keyflex_id      => v_new_sc_kff_id
                                  );
                  v_loc := 150;

                  IF v_valid
                  THEN
                     v_valid :=
                        update_trx_value_num
                                           (p_trx_step_id      => v_trx_step_id,
                                            p_value_name       => c_stat_info_name,
                                            p_value            => v_new_sc_kff_id,
                                            p_orig_value       => v_curr_sc_kff_id
                                           );

                     IF NOT v_valid
                     THEN
                        v_error_msg :=
                           'Encountered Error updating Soft Coded Keyflex ID on Trx';
                        RAISE e_error;
                     END IF;
                  END IF;
               END IF;
            END IF;
         END IF;
      END IF;

      p_result := 'COMPLETE';
   EXCEPTION
      WHEN e_error
      THEN
         process_error (module_name        => c_module,
                        status             => g_status_warning,
                        ERROR_CODE         => SQLCODE,
                        error_message      => v_error_msg,
                        LOCATION           => v_loc
                       );
         p_result := 'ERROR:' || v_error_msg;
      WHEN OTHERS
      THEN
         v_error_msg := SQLERRM;
         process_error (module_name        => c_module,
                        status             => g_status_warning,
                        ERROR_CODE         => SQLCODE,
                        error_message      => v_error_msg,
                        LOCATION           => v_loc
                       );
         p_result := 'ERROR:' || SUBSTR (SQLERRM, 1, 30);
   END update_asgn_trx;

--
-- PROCEDURE has_pay_changed
--   Description: This Function will determine if a Pay Change has occurred and
--                return a YES/NO result
--
   PROCEDURE has_pay_changed (
      p_itemtype   IN              VARCHAR2,
      p_itemkey    IN              VARCHAR2,
      p_actid      IN              NUMBER,
      p_funcmode   IN              VARCHAR2,
      p_result     OUT NOCOPY      VARCHAR2
   )
   IS
      /*
	  START R12.2 Upgrade Remediation
	  code commented by RXNETHI-ARGANO,15/05/23
	  c_module            cust.ttec_error_handling.module_name%TYPE
                                                         := 'has_pay_changed';
      v_error_msg         cust.ttec_error_handling.error_message%TYPE;
      v_loc               NUMBER                                         := 0;
      c_trx_step_api      hr.hr_api_transaction_steps.api_name%TYPE
                                              := 'HR_PAY_RATE_SS.PROCESS_API';
      c_change_pct_name   hr.hr_api_transaction_values.NAME%TYPE
                                                        := 'P_CHANGE_PERCENT';
      c_change_type       hr.hr_api_transaction_values.NAME%TYPE
                                              := 'P_SALARY_BASIS_CHANGE_TYPE';
      v_pay_change_pct    hr.hr_api_transaction_values.number_value%TYPE;
      v_change_type       hr.hr_api_transaction_values.varchar2_value%TYPE;
      -- Throwaway Values
      v_orig_num_value    hr.hr_api_transaction_values.original_number_value%TYPE;
      v_orig_vc2_value    hr.hr_api_transaction_values.original_varchar2_value%TYPE;
      */
	  --code added by RXNETHI-ARGANO,15/05/23
	  c_module            apps.ttec_error_handling.module_name%TYPE
                                                         := 'has_pay_changed';
      v_error_msg         apps.ttec_error_handling.error_message%TYPE;
      v_loc               NUMBER                                         := 0;
      c_trx_step_api      apps.hr_api_transaction_steps.api_name%TYPE
                                              := 'HR_PAY_RATE_SS.PROCESS_API';
      c_change_pct_name   apps.hr_api_transaction_values.NAME%TYPE
                                                        := 'P_CHANGE_PERCENT';
      c_change_type       apps.hr_api_transaction_values.NAME%TYPE
                                              := 'P_SALARY_BASIS_CHANGE_TYPE';
      v_pay_change_pct    apps.hr_api_transaction_values.number_value%TYPE;
      v_change_type       apps.hr_api_transaction_values.varchar2_value%TYPE;
      -- Throwaway Values
      v_orig_num_value    apps.hr_api_transaction_values.original_number_value%TYPE;
      v_orig_vc2_value    apps.hr_api_transaction_values.original_varchar2_value%TYPE;
	  --END R12.2 Upgrade Remediation
   BEGIN
      v_loc := 10;

      IF p_funcmode = 'RUN'
      THEN
         get_trx_value (p_itemtype        => p_itemtype,
                        p_itemkey         => p_itemkey,
                        p_api_name        => c_trx_step_api,
                        p_value_name      => c_change_pct_name,
                        p_value           => v_pay_change_pct,
                        p_orig_value      => v_orig_num_value
                       );
         get_trx_value (p_itemtype        => p_itemtype,
                        p_itemkey         => p_itemkey,
                        p_api_name        => c_trx_step_api,
                        p_value_name      => c_change_type,
                        p_value           => v_change_type,
                        p_orig_value      => v_orig_vc2_value
                       );
         v_loc := 20;

         IF NVL (v_pay_change_pct, 0) != 0 OR v_change_type = 'CHANGE'
         THEN
            p_result := 'COMPLETE:Y';
         ELSE
            p_result := 'COMPLETE:N';
         END IF;
      END IF;
   EXCEPTION
      WHEN OTHERS
      THEN
         v_error_msg := SQLERRM;
         process_error (module_name        => c_module,
                        status             => g_status_warning,
                        ERROR_CODE         => SQLCODE,
                        error_message      => v_error_msg,
                        LOCATION           => v_loc
                       );
         p_result := 'ERROR:' || SUBSTR (SQLERRM, 1, 30);
   END has_pay_changed;

--
-- PROCEDURE update_pay_eff_date
--   Description: This Procedure will update the Effective Date of the transactions
--                appropriately based on the Employee Pay Change entered.
--
   PROCEDURE update_pay_eff_date (
      p_itemtype   IN              VARCHAR2,
      p_itemkey    IN              VARCHAR2,
      p_actid      IN              NUMBER,
      p_funcmode   IN              VARCHAR2,
      p_result     OUT NOCOPY      VARCHAR2
   )
   IS
      /*
	  START R12.2 Upgrade Remediation
	  code commented by RXNETHI-ARGANO,15/05/23
	  c_module              cust.ttec_error_handling.module_name%TYPE
                                                     := 'update_pay_eff_date';
      v_error_msg           cust.ttec_error_handling.error_message%TYPE;
      v_loc                 NUMBER                                       := 0;
      c_pay_rate_api        hr.hr_api_transaction_steps.api_name%TYPE
                                              := 'HR_PAY_RATE_SS.PROCESS_API';
      c_supervisor_api      hr.hr_api_transaction_steps.api_name%TYPE
                                            := 'HR_SUPERVISOR_SS.PROCESS_API';
      c_assignment_api      hr.hr_api_transaction_steps.api_name%TYPE
                                    := 'HR_PROCESS_ASSIGNMENT_SS.PROCESS_API';
      c_eff_date_name       hr.hr_api_transaction_values.NAME%TYPE
                                                        := 'P_EFFECTIVE_DATE';
      c_def_date_name       hr.hr_api_transaction_values.NAME%TYPE
                                                          := 'P_DEFAULT_DATE';
      c_sal_eff_date_name   hr.hr_api_transaction_values.NAME%TYPE
                                                 := 'P_SALARY_EFFECTIVE_DATE';
      c_mgr_eff_date_name   hr.hr_api_transaction_values.NAME%TYPE
                                                 := 'P_PASSED_EFFECTIVE_DATE';
      */
	  --code added by RXNETHI-ARGANO,15/05/23
	  c_module              apps.ttec_error_handling.module_name%TYPE
                                                     := 'update_pay_eff_date';
      v_error_msg           apps.ttec_error_handling.error_message%TYPE;
      v_loc                 NUMBER                                       := 0;
      c_pay_rate_api        apps.hr_api_transaction_steps.api_name%TYPE
                                              := 'HR_PAY_RATE_SS.PROCESS_API';
      c_supervisor_api      apps.hr_api_transaction_steps.api_name%TYPE
                                            := 'HR_SUPERVISOR_SS.PROCESS_API';
      c_assignment_api      apps.hr_api_transaction_steps.api_name%TYPE
                                    := 'HR_PROCESS_ASSIGNMENT_SS.PROCESS_API';
      c_eff_date_name       apps.hr_api_transaction_values.NAME%TYPE
                                                        := 'P_EFFECTIVE_DATE';
      c_def_date_name       apps.hr_api_transaction_values.NAME%TYPE
                                                          := 'P_DEFAULT_DATE';
      c_sal_eff_date_name   apps.hr_api_transaction_values.NAME%TYPE
                                                 := 'P_SALARY_EFFECTIVE_DATE';
      c_mgr_eff_date_name   apps.hr_api_transaction_values.NAME%TYPE
                                                 := 'P_PASSED_EFFECTIVE_DATE';
	  --END R12.2 Upgrade Remediation
	  v_good_date           BOOLEAN                                  := FALSE;
      v_asg_change          BOOLEAN;
      v_cnt                 NUMBER;
      --v_assignment_id       hr.per_all_assignments_f.assignment_id%TYPE; --code commented by RXNETHI-ARGANO,15/05/23
	  v_assignment_id       apps.per_all_assignments_f.assignment_id%TYPE; --code added by RXNETHI-ARGANO,15/05/23
      v_curr_eff_date       DATE;
      v_new_eff_date        DATE;

--  v_trx_step_id       hr.hr_api_transaction_steps.transaction_step_id%TYPE;
      CURSOR c_get_trx_step
      IS
         SELECT transaction_step_id, api_name
           FROM hr_api_transaction_steps
          WHERE item_type = p_itemtype AND item_key = p_itemkey;
   BEGIN
      v_loc := 10;

      IF p_funcmode = 'RUN'
      THEN
         -- Get Assignment ID from Workflow
         v_assignment_id :=
            wf_engine.getitemattrnumber (itemtype      => p_itemtype,
                                         itemkey       => p_itemkey,
                                         aname         => 'CURRENT_ASSIGNMENT_ID'
                                        );
         v_curr_eff_date :=
            wf_engine.getitemattrdate (itemtype      => p_itemtype,
                                       itemkey       => p_itemkey,
                                       aname         => 'CURRENT_EFFECTIVE_DATE'
                                      );
         -- Calculate the Start Date of the next Pay Period for this person
         v_loc := 20;
         v_new_eff_date :=
            get_pay_period_start_date (p_date           =>   GREATEST
                                                                (SYSDATE,
                                                                 v_curr_eff_date
                                                                )
                                                           - 1,
                                       p_assign_id      => v_assignment_id
                                      );
         -- Determine if there is also a Supervisor or Assignment Change as part of this Trx
         v_loc := 30;

         SELECT COUNT (*)
           INTO v_cnt
           FROM hr_api_transaction_steps
          WHERE item_type = p_itemtype
            AND item_key = p_itemkey
            AND api_name IN (c_supervisor_api, c_assignment_api);

         IF v_cnt > 0
         THEN
            v_asg_change := TRUE;
         ELSE
            v_asg_change := FALSE;
         END IF;

         -- Push to the next pay period if a change already entered for the calculated date
         WHILE NOT v_good_date
         LOOP
            v_loc := 40;

            -- See if a Pay Change already exists for this new Effective Date
            SELECT COUNT (*)
              INTO v_cnt
              FROM per_pay_proposals
             WHERE assignment_id = v_assignment_id
               AND TRUNC (change_date) = v_new_eff_date;

            -- If a Pay Change already exists calculate the next period date
            IF v_cnt > 0
            THEN
               v_loc := 50;
               v_new_eff_date :=
                  get_pay_period_start_date (p_date           => v_new_eff_date,
                                             p_assign_id      => v_assignment_id
                                            );
      -- Does this Trx contain a Manager or Assignment Change?
--      ELSIF v_asg_change THEN
--        v_loc := 60;

            --        -- See if a Manager or Assignment change already exists for this Effective Date
--        SELECT COUNT(*)
--          INTO v_cnt
--          FROM per_all_assignments_f
--         WHERE assignment_id = v_assignment_id
--           AND effective_start_date = v_new_eff_date;
--
--        -- If a Manager/Assignment change already exists calculate the next period date
--        IF v_cnt > 0 THEN
--          v_new_eff_date := get_pay_period_start_date ( p_date       => v_new_eff_date
--                                                      , p_assign_id  => v_assignment_id );
--        ELSE
--          v_good_date := TRUE;
--        END IF;
            ELSE
               v_good_date := TRUE;
            END IF;
         END LOOP;

         v_loc := 70;
         -- Update necessary Workflow Date Attributes
         wf_engine.setitemattrdate (itemtype      => p_itemtype,
                                    itemkey       => p_itemkey,
                                    aname         => 'CURRENT_EFFECTIVE_DATE',
                                    avalue        => v_new_eff_date
                                   );
         wf_engine.setitemattrtext (itemtype      => p_itemtype,
                                    itemkey       => p_itemkey,
                                    aname         => 'P_EFFECTIVE_DATE',
                                    avalue        => TO_CHAR (v_new_eff_date,
                                                              'YYYY-MM-DD'
                                                             )
                                   );
         -- Loop through all Trx Steps for this Transaction
         v_loc := 80;

         FOR r_trx_step IN c_get_trx_step
         LOOP
            -- Update the 3 relevant API Date Values
            UPDATE hr_api_transaction_values
               SET date_value = v_new_eff_date
             WHERE transaction_step_id = r_trx_step.transaction_step_id
               AND NAME IN
                      (c_eff_date_name,
                       c_def_date_name,
                       c_sal_eff_date_name,
                       c_mgr_eff_date_name
                      );
         END LOOP;
      END IF;

      p_result := 'COMPLETE';
   EXCEPTION
      WHEN OTHERS
      THEN
         v_error_msg := SQLERRM;
         process_error (module_name        => c_module,
                        status             => g_status_warning,
                        ERROR_CODE         => SQLCODE,
                        error_message      => v_error_msg,
                        LOCATION           => v_loc
                       );
         p_result := 'ERROR:' || SUBSTR (SQLERRM, 1, 30);
   END update_pay_eff_date;

--
-- PROCEDURE load_timeout_profile
--   Description: This value will load the TELETECH_DEFAULT_TIMEOUT profile into
--                a local attribute.  This value will be used to calculate the
--                dynamic timeout value
--
   PROCEDURE load_timeout_profile (
      p_itemtype   IN              VARCHAR2,
      p_itemkey    IN              VARCHAR2,
      p_actid      IN              NUMBER,
      p_funcmode   IN              VARCHAR2,
      p_result     OUT NOCOPY      VARCHAR2
   )
   IS
      /*
	  START R12.2 Upgrade Remediation
	  code commented by RXNETHI-ARGANO,15/05/23
	  c_module        cust.ttec_error_handling.module_name%TYPE
                                                    := 'load_timeout_profile';
      v_error_msg     cust.ttec_error_handling.error_message%TYPE;
	  */
	  --code added by RXNETHI-ARGANO,15/05/23
	  c_module        apps.ttec_error_handling.module_name%TYPE
                                                    := 'load_timeout_profile';
      v_error_msg     apps.ttec_error_handling.error_message%TYPE;
	  --END R12.2 Upgrade Remediation
      v_loc           NUMBER                                        := 0;
      v_def_timeout   NUMBER;
   BEGIN
      v_loc := 10;

      IF p_funcmode = 'RUN'
      THEN
         -- Get the Default Timeout Profile Value
         v_def_timeout := fnd_profile.VALUE ('TELETECH_DEFAULT_TIMEOUT');

         -- Only override the WF Default if a Profile value is actually set
         IF NVL (v_def_timeout, 0) > 0
         THEN
            v_loc := 20;
            wf_engine.setitemattrnumber (itemtype      => p_itemtype,
                                         itemkey       => p_itemkey,
                                         aname         => 'TTEC_DEFAULT_TIMEOUT',
                                         avalue        => v_def_timeout
                                        );
         END IF;
      END IF;

      p_result := 'COMPLETE';
   EXCEPTION
      WHEN OTHERS
      THEN
         v_error_msg := SQLERRM;
         process_error (module_name        => c_module,
                        status             => g_status_warning,
                        ERROR_CODE         => SQLCODE,
                        error_message      => v_error_msg,
                        LOCATION           => v_loc
                       );
         p_result := 'ERROR:' || SUBSTR (SQLERRM, 1, 30);
   END load_timeout_profile;

--
-- PROCEDURE calc_dynamic_timeout
--   Description: This procedure will calculate the 'real-time' timeout by converting
--                the default timeout from Business Days into Real Minutes.
--
   PROCEDURE calc_dynamic_timeout (
      p_itemtype   IN              VARCHAR2,
      p_itemkey    IN              VARCHAR2,
      p_actid      IN              NUMBER,
      p_funcmode   IN              VARCHAR2,
      p_result     OUT NOCOPY      VARCHAR2
   )
   IS
      /*
	  START R12.2 Upgrade Remediation
	  code commented by RXNETHI-ARGANO,15/05/23
	  c_module             cust.ttec_error_handling.module_name%TYPE
                                                    := 'calc_dynamic_timeout';
      v_error_msg          cust.ttec_error_handling.error_message%TYPE;
      */
	  --code added by RXNETHI-ARGANO,15/05/23
	  c_module             apps.ttec_error_handling.module_name%TYPE
                                                    := 'calc_dynamic_timeout';
      v_error_msg          apps.ttec_error_handling.error_message%TYPE;
	  --END R12.2 Upgrade Remediation
	  v_loc                NUMBER                                        := 0;
      v_start_date         DATE                                    := SYSDATE;
      v_end_date           DATE;
      v_bus_days_timeout   NUMBER;
      v_timeout_minutes    NUMBER;
   BEGIN
      v_loc := 10;

      IF p_funcmode = 'RUN'
      THEN
         -- Get Default Timeout Attribute
         v_bus_days_timeout :=
            wf_engine.getitemattrnumber (itemtype      => p_itemtype,
                                         itemkey       => p_itemkey,
                                         aname         => 'TTEC_DEFAULT_TIMEOUT'
                                        );
         v_loc := 20;
         -- Convert to Real Days from Business Days
         v_end_date := add_bus_days (v_start_date, v_bus_days_timeout);
         v_loc := 30;
         -- Convert Difference from Start to End into Minutes
         v_timeout_minutes := ROUND ((v_end_date - v_start_date) * 1440);

         IF NVL (v_timeout_minutes, 0) = 0
         THEN
            v_timeout_minutes := 2880;                              -- 2 Days
         END IF;

         v_loc := 40;
         -- Update Dynamic Timeout Attribute
         wf_engine.setitemattrnumber (itemtype      => p_itemtype,
                                      itemkey       => p_itemkey,
                                      aname         => 'TELETECH_DYNAMIC_TIMEOUT',
                                      avalue        => v_timeout_minutes
                                     );
      END IF;

      p_result := 'COMPLETE';
   EXCEPTION
      WHEN OTHERS
      THEN
         v_error_msg := SQLERRM;
         process_error (module_name        => c_module,
                        status             => g_status_warning,
                        ERROR_CODE         => SQLCODE,
                        error_message      => v_error_msg,
                        LOCATION           => v_loc
                       );
         p_result := 'ERROR:' || SUBSTR (SQLERRM, 1, 30);
   END calc_dynamic_timeout;

--
-- PROCEDURE load_reminder_profile
--   Description: This value will load the TELETECH_DEFAULT_REMINDERS profile into
--                a local attribute.  This value will be used to control the
--                reminder counter on the final Approver
--
   PROCEDURE load_reminder_profile (
      p_itemtype   IN              VARCHAR2,
      p_itemkey    IN              VARCHAR2,
      p_actid      IN              NUMBER,
      p_funcmode   IN              VARCHAR2,
      p_result     OUT NOCOPY      VARCHAR2
   )
   IS
      /*
	  START R12.2 Upgrade Remediation
	  code commented by RXNETHI-ARGANO,15/05/23
	  c_module         cust.ttec_error_handling.module_name%TYPE
                                                   := 'load_reminder_profile';
      v_error_msg      cust.ttec_error_handling.error_message%TYPE;
      */
	  --code added by RXNETHI-ARGANO,15/05/23
	  c_module         apps.ttec_error_handling.module_name%TYPE
                                                   := 'load_reminder_profile';
      v_error_msg      apps.ttec_error_handling.error_message%TYPE;
	  --END R12.2 Upgrade Remediation
	  v_loc            NUMBER                                        := 0;
      v_def_reminder   NUMBER;
   BEGIN
      v_loc := 10;

      IF p_funcmode = 'RUN'
      THEN
         -- Get the Default Timeout Profile Value
         v_def_reminder := fnd_profile.VALUE ('TELETECH_DEFAULT_REMINDERS');

         -- Only override the WF Default if a Profile value is actually set
         IF NVL (v_def_reminder, 0) > 0
         THEN
            v_loc := 20;
            wf_engine.setitemattrnumber (itemtype      => p_itemtype,
                                         itemkey       => p_itemkey,
                                         aname         => 'TTEC_DEFAULT_REMINDERS',
                                         avalue        => v_def_reminder
                                        );
         END IF;
      END IF;

      p_result := 'COMPLETE';
   EXCEPTION
      WHEN OTHERS
      THEN
         v_error_msg := SQLERRM;
         process_error (module_name        => c_module,
                        status             => g_status_warning,
                        ERROR_CODE         => SQLCODE,
                        error_message      => v_error_msg,
                        LOCATION           => v_loc
                       );
         p_result := 'ERROR:' || SUBSTR (SQLERRM, 1, 30);
   END load_reminder_profile;

--
-- PROCEDURE incr_reminder_cntr
--   Description: Increment the Reminder Counter by 1
--
   PROCEDURE incr_reminder_cntr (
      p_itemtype   IN              VARCHAR2,
      p_itemkey    IN              VARCHAR2,
      p_actid      IN              NUMBER,
      p_funcmode   IN              VARCHAR2,
      p_result     OUT NOCOPY      VARCHAR2
   )
   IS
      /*
	  START R12.2 Upgrade Remediation
	  code commented by RXNETHI-ARGANO,15/05/23
	  c_module          cust.ttec_error_handling.module_name%TYPE
                                                      := 'incr_reminder_cntr';
      v_error_msg       cust.ttec_error_handling.error_message%TYPE;
      */
	  --code added by RXNETHI-ARGANO,15/05/23
	  c_module          apps.ttec_error_handling.module_name%TYPE
                                                      := 'incr_reminder_cntr';
      v_error_msg       apps.ttec_error_handling.error_message%TYPE;
	  --END R12.2 Upgrade Remediation
	  v_loc             NUMBER                                        := 0;
      v_reminder_cntr   NUMBER;
      v_reminder_disp   VARCHAR2 (20);
   BEGIN
      v_loc := 10;

      IF p_funcmode = 'RUN'
      THEN
         -- Get the current Counter value
         v_reminder_cntr :=
            wf_engine.getitemattrnumber (itemtype      => p_itemtype,
                                         itemkey       => p_itemkey,
                                         aname         => 'TTEC_REMINDER_COUNTER'
                                        );
         -- Increment Counter
         v_reminder_cntr := NVL (v_reminder_cntr, 0) + 1;
         v_loc := 20;
         -- Update Counter with new value
         wf_engine.setitemattrnumber (itemtype      => p_itemtype,
                                      itemkey       => p_itemkey,
                                      aname         => 'TTEC_REMINDER_COUNTER',
                                      avalue        => v_reminder_cntr
                                     );
         -- Set the Reminder Subject Line Display
         v_reminder_disp := 'Reminder ' || v_reminder_cntr || ' : ';
         wf_engine.setitemattrtext (itemtype      => p_itemtype,
                                    itemkey       => p_itemkey,
                                    aname         => 'TTEC_REMINDER_DISPLAY',
                                    avalue        => v_reminder_disp
                                   );
      END IF;

      p_result := 'COMPLETE';
   EXCEPTION
      WHEN OTHERS
      THEN
         v_error_msg := SQLERRM;
         process_error (module_name        => c_module,
                        status             => g_status_warning,
                        ERROR_CODE         => SQLCODE,
                        error_message      => v_error_msg,
                        LOCATION           => v_loc
                       );
         p_result := 'ERROR:' || SUBSTR (SQLERRM, 1, 30);
   END incr_reminder_cntr;

--
-- PROCEDURE set_rejection_ntf
--   Description: This Procedure will set the Subject Reason for the Rejection NTF
--
   PROCEDURE set_rejection_ntf (
      p_itemtype   IN              VARCHAR2,
      p_itemkey    IN              VARCHAR2,
      p_actid      IN              NUMBER,
      p_funcmode   IN              VARCHAR2,
      p_result     OUT NOCOPY      VARCHAR2
   )
   IS
      /*
	  START R12.2 Upgrade Remediation
	  code commented by RXNETHI-ARGANO,15/05/23
	  c_module                 cust.ttec_error_handling.module_name%TYPE
                                                       := 'set_rejection_ntf';
      v_error_msg              cust.ttec_error_handling.error_message%TYPE;
      */
	  --code added by RXNETHI-ARGANO,15/05/23
	  c_module                 apps.ttec_error_handling.module_name%TYPE
                                                       := 'set_rejection_ntf';
      v_error_msg              apps.ttec_error_handling.error_message%TYPE;
	  --END R12.2 Upgrade Remediation
	  v_loc                    NUMBER                                    := 0;
      v_ntf_type               VARCHAR2 (10);
      v_process_name           VARCHAR2 (50);
      v_person_name            VARCHAR2 (50);
      v_last_approver_name     VARCHAR2 (50);
      v_reject_subject         VARCHAR2 (200);
      v_prior_reject_subject   VARCHAR2 (200);
   BEGIN
      v_loc := 10;

      IF p_funcmode = 'RUN'
      THEN
         v_loc := 20;
         v_ntf_type :=
            wf_engine.getactivityattrtext (itemtype      => p_itemtype,
                                           itemkey       => p_itemkey,
                                           actid         => p_actid,
                                           aname         => 'TTEC_NTF_TYPE'
                                          );
         v_process_name :=
            wf_engine.getitemattrtext (itemtype      => p_itemtype,
                                       itemkey       => p_itemkey,
                                       aname         => 'PROCESS_DISPLAY_NAME'
                                      );
         v_person_name :=
            wf_engine.getitemattrtext (itemtype      => p_itemtype,
                                       itemkey       => p_itemkey,
                                       aname         => 'CURRENT_PERSON_DISPLAY_NAME'
                                      );
         v_last_approver_name :=
            wf_engine.getitemattrtext (itemtype      => p_itemtype,
                                       itemkey       => p_itemkey,
                                       aname         => 'FORWARD_TO_DISPLAY_NAME'
                                      );

         IF v_ntf_type = 'TIMEOUT'
         THEN
            v_loc := 30;
            v_reject_subject :=
                  'Your '
               || v_process_name
               || ' for '
               || v_person_name
               || ' has timed out at '
               || v_last_approver_name
               || ' and has been cancelled';
            v_prior_reject_subject :=
                  'The '
               || v_process_name
               || ' for '
               || v_person_name
               || ' has timed out at '
               || v_last_approver_name
               || ' and has been cancelled';
         ELSE
            v_loc := 40;
            v_reject_subject :=
                  v_last_approver_name
               || ' has rejected your '
               || v_process_name
               || ' for '
               || v_person_name;
            v_prior_reject_subject :=
                  v_last_approver_name
               || ' has rejected your previously approved '
               || v_process_name
               || ' for '
               || v_person_name;
         END IF;

         v_loc := 50;
         wf_engine.setitemattrtext (itemtype      => p_itemtype,
                                    itemkey       => p_itemkey,
                                    aname         => 'TTEC_REJECTION_NTF_SUBJECT',
                                    avalue        => v_reject_subject
                                   );
         wf_engine.setitemattrtext (itemtype      => p_itemtype,
                                    itemkey       => p_itemkey,
                                    aname         => 'TTEC_PRIOR_REJECT_NTF_SUBJECT',
                                    avalue        => v_prior_reject_subject
                                   );
      END IF;
   EXCEPTION
      WHEN OTHERS
      THEN
         v_error_msg := SQLERRM;
         process_error (module_name        => c_module,
                        status             => g_status_warning,
                        ERROR_CODE         => SQLCODE,
                        error_message      => v_error_msg,
                        LOCATION           => v_loc
                       );
         p_result := 'ERROR:' || SUBSTR (SQLERRM, 1, 30);
   END set_rejection_ntf;

--
-- PROCEDURE is_final_approver
--   Description: Determine if the current approver is the Final
--                Approval Approver (nonFYI)
--
   PROCEDURE is_final_approver (
      p_itemtype   IN              VARCHAR2,
      p_itemkey    IN              VARCHAR2,
      p_actid      IN              NUMBER,
      p_funcmode   IN              VARCHAR2,
      p_result     OUT NOCOPY      VARCHAR2
   )
   IS
      /*
	  START R12.2 Upgrade Remediation
	  code commented by RXNETHI-ARGANO,15/05/23
	  c_module                cust.ttec_error_handling.module_name%TYPE
                                                       := 'is_final_approver';
      v_error_msg             cust.ttec_error_handling.error_message%TYPE;
      */
	  --code added by RXNETHI-ARGANO,15/05/23
	  c_module                apps.ttec_error_handling.module_name%TYPE
                                                       := 'is_final_approver';
      v_error_msg             apps.ttec_error_handling.error_message%TYPE;
	  --END R12.2 Upgrade Remediation
	  v_loc                   NUMBER                                     := 0;
      v_appr_orig_system      VARCHAR2 (10);
      v_appr_orig_system_id   NUMBER;
      /*
	  v_application_id        applsys.fnd_application.application_id%TYPE;
      v_transaction_type      hr.hr_api_transactions.transaction_type%TYPE;
      v_transaction_id        hr.hr_api_transactions.transaction_id%TYPE;
      */
	  --code added by RXNETHI-ARGANO,15/05/23
	  v_application_id        apps.fnd_application.application_id%TYPE;
      v_transaction_type      apps.hr_api_transactions.transaction_type%TYPE;
      v_transaction_id        apps.hr_api_transactions.transaction_id%TYPE;
	  --END R12.2 Upgrade Remediation
	  v_appr_complete_flag    VARCHAR2 (1);
      v_approvers_list        ame_util.approverstable2;
      v_approver              ame_util.approverrecord2;
      v_final                 VARCHAR2 (1)                             := 'Y';
   BEGIN
      v_loc := 10;

      IF p_funcmode = 'RUN'
      THEN
         -- Get Current Approver
         v_appr_orig_system :=
            wf_engine.getitemattrtext (itemtype      => p_itemtype,
                                       itemkey       => p_itemkey,
                                       aname         => 'HR_APR_ORIG_SYSTEM_ATTR'
                                      );
         v_appr_orig_system_id :=
            wf_engine.getitemattrnumber (itemtype      => p_itemtype,
                                         itemkey       => p_itemkey,
                                         aname         => 'HR_APR_ORIG_SYSTEM_ID_ATTR'
                                        );
         -- Get other values needed to retrieve the Approver List
         v_application_id :=
            wf_engine.getitemattrnumber (itemtype      => p_itemtype,
                                         itemkey       => p_itemkey,
                                         aname         => 'HR_AME_APP_ID_ATTR'
                                        );
         v_application_id := NVL (v_application_id, 800);
         v_transaction_id :=
            wf_engine.getitemattrnumber (itemtype      => p_itemtype,
                                         itemkey       => p_itemkey,
                                         aname         => 'TRANSACTION_ID'
                                        );
         v_transaction_type :=
            wf_engine.getitemattrtext (itemtype      => p_itemtype,
                                       itemkey       => p_itemkey,
                                       aname         => 'HR_AME_TRAN_TYPE_ATTR'
                                      );
         v_loc := 20;
         -- Get Current Approval List
         ame_api2.getallapprovers7
                        (applicationidin                   => v_application_id,
                         transactiontypein                 => v_transaction_type,
                         transactionidin                   => v_transaction_id,
                         approvalprocesscompleteynout      => v_appr_complete_flag,
                         approversout                      => v_approvers_list
                        );
         -- Loop through Approval List and see if any Approvers other than the
         -- current approver remain to approve
         v_loc := 30;

         FOR i IN 1 .. v_approvers_list.COUNT
         LOOP
            v_loc := 40;
            v_approver := v_approvers_list (i);

            IF     v_approver.approval_status IS NULL
               AND v_approver.approver_category =
                                             ame_util.approvalapprovercategory
               AND (   v_approver.orig_system != v_appr_orig_system
                    OR v_approver.orig_system_id != v_appr_orig_system_id
                   )
            THEN
               v_loc := 50;
               v_final := 'N';
            END IF;
         END LOOP;

         v_loc := 60;
         p_result := 'COMPLETE:' || v_final;
      END IF;
   EXCEPTION
      WHEN OTHERS
      THEN
         v_error_msg := SQLERRM;
         process_error (module_name        => c_module,
                        status             => g_status_warning,
                        ERROR_CODE         => SQLCODE,
                        error_message      => v_error_msg,
                        LOCATION           => v_loc
                       );
         p_result := 'ERROR:' || SUBSTR (SQLERRM, 1, 30);
   END is_final_approver;

--
-- PROCEDURE build_adhoc_apprvs_role
--   Description: Build an Adhoc role of all Approvers who have already
--                approved the transaction to be notified of rejection or
--                timeout by a later approver.
--
   PROCEDURE build_adhoc_apprvs_role (
      p_itemtype   IN              VARCHAR2,
      p_itemkey    IN              VARCHAR2,
      p_actid      IN              NUMBER,
      p_funcmode   IN              VARCHAR2,
      p_result     OUT NOCOPY      VARCHAR2
   )
   IS
      /*
	  START R12.2 Upgrade Remediation
	  code commented by RXNETHI-ARGANO,15/05/23
	  c_module               cust.ttec_error_handling.module_name%TYPE
                                                 := 'build_adhoc_apprvs_role';
      v_error_msg            cust.ttec_error_handling.error_message%TYPE;
      */
	  --code added by RXNETHI-ARGANO,15/05/23
	  c_module               apps.ttec_error_handling.module_name%TYPE
                                                 := 'build_adhoc_apprvs_role';
      v_error_msg            apps.ttec_error_handling.error_message%TYPE;
	  --END R12.2 Upgrade Remediation
	  v_loc                  NUMBER                                      := 0;
      v_cnt                  NUMBER                                      := 0;
      /*
	  START R12.2 Upgrade Remediation
	  code commented by RXNETHI-ARGANO,15/05/23
	  v_application_id       applsys.fnd_application.application_id%TYPE;
      v_transaction_type     hr.hr_api_transactions.transaction_type%TYPE;
      v_transaction_id       hr.hr_api_transactions.transaction_id%TYPE;
      v_appr_complete_flag   VARCHAR2 (1);
      v_approvers_list       ame_util.approverstable2;
      v_approver             ame_util.approverrecord2;
      v_role_name            applsys.wf_local_roles.NAME%TYPE;
      v_role_disp_name       applsys.wf_local_roles.display_name%TYPE;
      v_language             applsys.wf_local_roles.LANGUAGE%TYPE
                                                                := 'AMERICAN';
      v_role_desc            applsys.wf_local_roles.description%TYPE
                                               := 'TTEC Prior Approvers Role';
      v_notif_pref           applsys.wf_local_roles.notification_preference%TYPE
                                                                := 'MAILHTML';
      v_user                 applsys.fnd_user.user_name%TYPE;
      v_role_users           VARCHAR2 (1000);
      v_status               applsys.wf_local_roles.status%TYPE   := 'ACTIVE';
      v_exp_date             applsys.wf_local_roles.expiration_date%TYPE
                                                      := TRUNC (SYSDATE + 14);
	  */
	  --code added by RXNETHI-ARGANO,15/05/23
	  v_application_id       apps.fnd_application.application_id%TYPE;
      v_transaction_type     apps.hr_api_transactions.transaction_type%TYPE;
      v_transaction_id       apps.hr_api_transactions.transaction_id%TYPE;
      v_appr_complete_flag   VARCHAR2 (1);
      v_approvers_list       ame_util.approverstable2;
      v_approver             ame_util.approverrecord2;
      v_role_name            apps.wf_local_roles.NAME%TYPE;
      v_role_disp_name       apps.wf_local_roles.display_name%TYPE;
      v_language             apps.wf_local_roles.LANGUAGE%TYPE
                                                                := 'AMERICAN';
      v_role_desc            apps.wf_local_roles.description%TYPE
                                               := 'TTEC Prior Approvers Role';
      v_notif_pref           apps.wf_local_roles.notification_preference%TYPE
                                                                := 'MAILHTML';
      v_user                 apps.fnd_user.user_name%TYPE;
      v_role_users           VARCHAR2 (1000);
      v_status               apps.wf_local_roles.status%TYPE   := 'ACTIVE';
      v_exp_date             apps.wf_local_roles.expiration_date%TYPE
                                                      := TRUNC (SYSDATE + 14);
	  --END R12.2 Upgrade Remediation
   BEGIN
      v_loc := 10;

      IF p_funcmode = 'RUN'
      THEN
         -- Get other values needed to retrieve the Approver List
         v_application_id :=
            wf_engine.getitemattrnumber (itemtype      => p_itemtype,
                                         itemkey       => p_itemkey,
                                         aname         => 'HR_AME_APP_ID_ATTR'
                                        );
         v_application_id := NVL (v_application_id, 800);
         v_transaction_id :=
            wf_engine.getitemattrnumber (itemtype      => p_itemtype,
                                         itemkey       => p_itemkey,
                                         aname         => 'TRANSACTION_ID'
                                        );
         v_transaction_type :=
            wf_engine.getitemattrtext (itemtype      => p_itemtype,
                                       itemkey       => p_itemkey,
                                       aname         => 'HR_AME_TRAN_TYPE_ATTR'
                                      );
         v_loc := 20;

         -- Get current Approvers List for Transaction
         BEGIN
            ame_api2.getallapprovers7
                       (applicationidin                   => v_application_id,
                        transactiontypein                 => v_transaction_type,
                        transactionidin                   => v_transaction_id,
                        approvalprocesscompleteynout      => v_appr_complete_flag,
                        approversout                      => v_approvers_list
                       );
         EXCEPTION
            WHEN OTHERS
            THEN
               p_result := 'COMPLETE:NO_APPROVERS';
               process_error (module_name        => c_module,
                              status             => g_status_warning,
                              ERROR_CODE         => SQLCODE,
                              error_message      => SQLERRM,
                              LOCATION           => v_loc
                             );
         END;

         v_loc := 30;

         IF v_approvers_list.COUNT = 0
         THEN
            v_loc := 35;
            p_result := 'COMPLETE:NO_APPROVERS';
         ELSE
            -- Build Role Users from Approvers List
            FOR i IN 1 .. v_approvers_list.COUNT
            LOOP
               v_loc := 40;
               v_approver := v_approvers_list (i);

               -- The Approver Role consists of ALL Prior Approvers who have approved.
               IF     v_approver.approval_status IN
                         (ame_util.approvedstatus,
                          ame_util.approveandforwardstatus
                         )
                  AND v_approver.approver_category =
                                             ame_util.approvalapprovercategory
               THEN
                  -- Get the User Name for each Approver
                  IF v_approver.orig_system = 'PER'
                  THEN
                     BEGIN
                        SELECT user_name
                          INTO v_user
                          FROM fnd_user
                         WHERE employee_id = v_approver.orig_system_id
                           AND SYSDATE BETWEEN start_date
                                           AND NVL (end_date, SYSDATE + 1);

                        -- Build the Approver Name as 'Orig_System:Orig_System_ID'
                        v_role_users := v_role_users || v_user || ',';
                        v_cnt := v_cnt + 1;
                     EXCEPTION
                        WHEN OTHERS
                        THEN
                           -- Skip this Approver due to error and continue
                           NULL;
                     END;
                  END IF;
               END IF;
            END LOOP;

            IF v_cnt = 0
            THEN
               v_loc := 45;
               p_result := 'COMPLETE:NO_APPROVERS';
            ELSE
               v_loc := 50;
               v_role_users := RTRIM (v_role_users, ',');

               -- Create the AdHoc User Role for the notification
               BEGIN
                  wf_directory.createadhocrole
                                    (role_name                    => v_role_name,
                                     role_display_name            => v_role_disp_name,
                                     LANGUAGE                     => v_language,
                                     territory                    => NULL,
                                     role_description             => v_role_desc,
                                     notification_preference      => v_notif_pref,
                                     role_users                   => v_role_users,
                                     email_address                => NULL,
                                     fax                          => NULL,
                                     status                       => v_status,
                                     expiration_date              => v_exp_date,
                                     parent_orig_system           => NULL,
                                     parent_orig_system_id        => NULL,
                                     owner_tag                    => NULL
                                    );
               EXCEPTION
                  WHEN OTHERS
                  THEN
                     v_loc := 55;
                     p_result := 'COMPLETE:NO_APPROVERS';
                     process_error (module_name        => c_module,
                                    status             => g_status_warning,
                                    ERROR_CODE         => SQLCODE,
                                    error_message      => SQLERRM,
                                    LOCATION           => v_loc
                                   );
               END;

               v_loc := 60;
               -- Update the WF Attribute with the AdHoc Role Name
               wf_engine.setitemattrtext
                                        (itemtype      => p_itemtype,
                                         itemkey       => p_itemkey,
                                         aname         => 'TTEC_PRIOR_APPROVERS_ROLE',
                                         avalue        => v_role_name
                                        );
               p_result := 'COMPLETE:SUCCESS';
            END IF;
         END IF;
      END IF;
   EXCEPTION
      WHEN OTHERS
      THEN
         v_error_msg := SQLERRM;
         process_error (module_name        => c_module,
                        status             => g_status_warning,
                        ERROR_CODE         => SQLCODE,
                        error_message      => v_error_msg,
                        LOCATION           => v_loc
                       );
         p_result := 'ERROR:' || SUBSTR (SQLERRM, 1, 30);
   END build_adhoc_apprvs_role;

--
-- PROCEDURE is_valid_employee
--   Description: This procedure will evaluate if the employee selected to
--                be transacted is not valid.  Currently an employee MUST be
--                a US or Canadian employee to be transacted on.
--
   PROCEDURE is_valid_employee (
      p_itemtype   IN              VARCHAR2,
      p_itemkey    IN              VARCHAR2,
      p_actid      IN              NUMBER,
      p_funcmode   IN              VARCHAR2,
      p_result     OUT NOCOPY      VARCHAR2
   )
   IS
      /*
	  START R12.2 Upgrade Remediation
	  code commented by RXNETHI-ARGANO,15/05/23
	  c_module              cust.ttec_error_handling.module_name%TYPE
                                                       := 'is_valid_employee';
      v_error_msg           cust.ttec_error_handling.error_message%TYPE;
      */
	  --code added by RXNETHI-ARGANO,15/05/23
	  c_module              apps.ttec_error_handling.module_name%TYPE
                                                       := 'is_valid_employee';
      v_error_msg           apps.ttec_error_handling.error_message%TYPE;
	  --END R12.2 Upgrade Remediation
	  v_loc                 NUMBER                                       := 0;
      v_employee_id         NUMBER;
      v_business_group_id   NUMBER;
   BEGIN
      v_loc := 10;

      IF p_funcmode = 'RUN'
      THEN
         -- Get Employee from WF attribute
         v_employee_id :=
            wf_engine.getitemattrnumber (itemtype      => p_itemtype,
                                         itemkey       => p_itemkey,
                                         aname         => 'CURRENT_PERSON_ID'
                                        );
         -- Get the Business Group of Employee
         v_loc := 20;

         SELECT business_group_id
           INTO v_business_group_id
           FROM per_all_people_f
          WHERE person_id = v_employee_id
            AND SYSDATE BETWEEN effective_start_date AND effective_end_date;

         -- If BG not US or CAN then return 'No', otherwise 'Yes'
         v_loc := 30;

         IF v_business_group_id IN (325, 326, 1517)
         THEN
            p_result := 'COMPLETE:Y';
         ELSE
            p_result := 'COMPLETE:N';
         END IF;
      END IF;
   EXCEPTION
      WHEN OTHERS
      THEN
         v_error_msg := SQLERRM;
         process_error (module_name        => c_module,
                        status             => g_status_warning,
                        ERROR_CODE         => SQLCODE,
                        error_message      => v_error_msg,
                        LOCATION           => v_loc
                       );
         p_result := 'COMPLETE:N';
   END is_valid_employee;

--
-- PROCEDURE save_transaction_dtl
--   Description: This procedure will copy the Transaction Value information to the
--                custom table TTEC_HR_API_TRX_VALUES as the FYI notification that
--                uses this information is dynamically generated and will need to
--                have access after the Workflow has completed.
--
   PROCEDURE save_transaction_dtl (
      p_itemtype   IN              VARCHAR2,
      p_itemkey    IN              VARCHAR2,
      p_actid      IN              NUMBER,
      p_funcmode   IN              VARCHAR2,
      p_result     OUT NOCOPY      VARCHAR2
   )
   IS
      /*
	  START R12.2 Upgrade Remediation
	  code commented by RXNETHI-ARGANO,15/05/23
	  c_module           cust.ttec_error_handling.module_name%TYPE
                                                    := 'save_transaction_dtl';
      v_error_msg        cust.ttec_error_handling.error_message%TYPE;
      */
	  --code added by RXNETHI-ARGANO,15/05/23
	  c_module           apps.ttec_error_handling.module_name%TYPE
                                                    := 'save_transaction_dtl';
      v_error_msg        apps.ttec_error_handling.error_message%TYPE;
	  --END R12.2 Upgrade Remediation
	  v_loc              NUMBER                                        := 0;
      --v_transaction_id   hr.hr_api_transactions.transaction_id%TYPE; --code commented by RXNETHI-ARGANO,15/05/23
	  v_transaction_id   apps.hr_api_transactions.transaction_id%TYPE; --code added by RXNETHI-ARGANO,15/05/23
      v_cnt              NUMBER;
   BEGIN
      v_loc := 10;

      IF p_funcmode = 'RUN'
      THEN
         -- Get the Trx ID
         v_transaction_id :=
            wf_engine.getitemattrnumber (itemtype      => p_itemtype,
                                         itemkey       => p_itemkey,
                                         aname         => 'TRANSACTION_ID'
                                        );

         -- Determine if the Trx has already been saved to the Temp Table
         SELECT COUNT (*)
           INTO v_cnt
           --FROM cust.ttec_hr_api_trx_values  --code commented by RXNETHI-ARGANO,15/05/23
           FROM apps.ttec_hr_api_trx_values    --code added by RXNETHI-ARGANO,15/05/23
          WHERE transaction_id = v_transaction_id;

         -- Save the Trx Values to the temp table if not already saved
         IF v_cnt = 0
         THEN
            --INSERT INTO cust.ttec_hr_api_trx_values   --code commented by RXNETHI-ARGANO,15/05/23
            INSERT INTO apps.ttec_hr_api_trx_values     --code added by RXNETHI-ARGANO,15/05/23
               (SELECT tv.transaction_value_id, ts.transaction_step_id,
                       t.transaction_id, t.process_name, ts.api_name,
                       tv.datatype, tv.NAME, tv.varchar2_value,
                       tv.number_value, tv.date_value,
                       tv.original_varchar2_value, tv.original_number_value,
                       tv.original_date_value, tv.created_by,
                       tv.creation_date, tv.last_update_date,
                       tv.last_updated_by, tv.last_update_login,
                       tv.previous_varchar2_value, tv.previous_date_value,
                       tv.previous_number_value
                  /*
				  START R12.2 Upgrade Remediation
				  code commented by RXNETHI-ARGANO,15/05/23
				  FROM hr.hr_api_transactions t,
                       hr.hr_api_transaction_steps ts,
                       hr.hr_api_transaction_values tv
                  */
				  --code added by RXNETHI-ARGANO,15/05/23
				  FROM apps.hr_api_transactions t,
                       apps.hr_api_transaction_steps ts,
                       apps.hr_api_transaction_values tv
				  --END R12.2 Upgrade Remediation
				 WHERE t.transaction_id = v_transaction_id
                   AND ts.transaction_id = t.transaction_id
                   AND tv.transaction_step_id = ts.transaction_step_id);
         END IF;
      END IF;
   EXCEPTION
      WHEN OTHERS
      THEN
         v_error_msg := SQLERRM;
         process_error (module_name        => c_module,
                        status             => g_status_warning,
                        ERROR_CODE         => SQLCODE,
                        error_message      => v_error_msg,
                        LOCATION           => v_loc
                       );
         p_result := 'ERROR:' || SUBSTR (SQLERRM, 1, 30);
   END save_transaction_dtl;

--
-- ----------------------------------------------------------------------------
-- |-------------------------< ttec_bg_chk------------------------|
-- ----------------------------------------------------------------------------
-- Purpose: This procedure will get business group id and check against lookup setup ttec_hr_transfer_jsp_prc
-- and return the YES/NO Value. called from HR Wwork flow  process name is TTEC_HR_TRANSFER_JSP_PRC
-- (YES/NO/YES_DYNAMIC)
-- For
--  YES          => branch with Yes result
--  NO           => branch with No result
-- ----------------------------------------------------------------------------
   PROCEDURE ttec_bg_chk (
      itemtype    IN              VARCHAR2,
      itemkey     IN              VARCHAR2,
      actid       IN              NUMBER,
      funcmode    IN              VARCHAR2,
      resultout   OUT NOCOPY      VARCHAR2
   )
   IS
      v_employee_id         per_all_people_f.person_id%TYPE;
      v_business_group_id   per_all_people_f.business_group_id%TYPE;
      v_pay_rate_bg         fnd_lookup_values.lookup_code%TYPE;

      CURSOR c_bg_id
      IS
         SELECT business_group_id
           FROM per_all_people_f
          WHERE person_id = v_employee_id
            AND SYSDATE BETWEEN effective_start_date AND effective_end_date;

      CURSOR c_pay_rate_bg
      IS
         SELECT DISTINCT lookup_code
                    FROM fnd_lookup_values
                   WHERE lookup_type = 'TTEC_MSS_PAY_RATE_JSP'
                     AND TRUNC (SYSDATE) BETWEEN start_date_active
                                             AND NVL (end_date_active,
                                                      '31-DEC-4712'
                                                     )
                     AND enabled_flag = 'Y'
                     AND lookup_code = v_business_group_id;
   BEGIN
      v_employee_id :=
         wf_engine.getitemattrnumber (itemtype      => itemtype,
                                      itemkey       => itemkey,
                                      aname         => 'CURRENT_PERSON_ID'
                                     );

      OPEN c_bg_id;

      FETCH c_bg_id
       INTO v_business_group_id;

      CLOSE c_bg_id;

      v_pay_rate_bg := NULL;

      OPEN c_pay_rate_bg;

      FETCH c_pay_rate_bg
       INTO v_pay_rate_bg;

      CLOSE c_pay_rate_bg;

      IF v_pay_rate_bg IS NOT NULL
      THEN
         resultout := 'COMPLETE:' || 'N';
      ELSE
         resultout := 'COMPLETE:' || 'Y';
      END IF;
   EXCEPTION
      WHEN OTHERS
      THEN
         resultout := 'COMPLETE:' || 'Y';
   END ttec_bg_chk;

--
--
-- PROCEDURE check_regularization_dat
--   Description: Rotuine to get the change from Probation to Regular.
--  And if criteria is met, update attribute6 of per_all_people_f
--  Wasim
   PROCEDURE check_regularization_date (
      p_itemtype   IN              VARCHAR2,
      p_itemkey    IN              VARCHAR2,
      p_actid      IN              NUMBER,
      p_funcmode   IN              VARCHAR2,
      p_result     OUT NOCOPY      VARCHAR2
   )
   IS
      /*
	  START R12.2 Upgrade Remediation
	  code commented by RXNETHI-ARGANO,15/05/23
	  c_module               cust.ttec_error_handling.module_name%TYPE
                                               := 'check_regularization_date';
      v_error_msg            cust.ttec_error_handling.error_message%TYPE;
      */
	  --code added by RXNETHI-ARGANO,15/05/23
	  c_module               apps.ttec_error_handling.module_name%TYPE
                                               := 'check_regularization_date';
      v_error_msg            apps.ttec_error_handling.error_message%TYPE;
	  --END R12.2 Upgrade Remediation
	  v_loc                  NUMBER                                      := 0;
--      v_datatype          hr.hr_api_transaction_values.datatype%TYPE;
--      v_column_name       hr.hr_api_transaction_values.NAME%TYPE;
--      v_new_char_value    hr.hr_api_transaction_values.varchar2_value%TYPE;
--      v_new_num_value     hr.hr_api_transaction_values.number_value%TYPE;
--      v_new_date_value    hr.hr_api_transaction_values.date_value%TYPE;
--      v_orig_char_value   hr.hr_api_transaction_values.original_varchar2_value%TYPE;
--      v_orig_num_value    hr.hr_api_transaction_values.original_number_value%TYPE;
--      v_orig_date_value   hr.hr_api_transaction_values.original_date_value%TYPE;
      /* Wasim New Code */
      /*
	  v_transaction_id       hr.hr_api_transaction_steps.transaction_id%TYPE;
      v_prob_stat_new        hr.hr_api_transaction_values.varchar2_value%TYPE;
      v_prob_stat_org        hr.hr_api_transaction_values.original_varchar2_value%TYPE;
      v_person_id            hr.per_all_people_f.person_id%TYPE;
      */
	  --code added by RXNETHI-ARGANO,15/05/23
	  v_transaction_id       apps.hr_api_transaction_steps.transaction_id%TYPE;
      v_prob_stat_new        apps.hr_api_transaction_values.varchar2_value%TYPE;
      v_prob_stat_org        apps.hr_api_transaction_values.original_varchar2_value%TYPE;
      v_person_id            apps.per_all_people_f.person_id%TYPE;
	  --END R12.2 Upgrade Remedaition
	  v_probation_date       DATE;
      v_stat                 NUMBER;
      v_state_to_check_for   VARCHAR2 (40)          := 'PROBATION TO REGULAR';
   BEGIN
      IF p_funcmode = 'RUN'
      THEN
         -- get transaction id
         SELECT hats.transaction_id
           INTO v_transaction_id
           FROM hr_api_transaction_steps hats
          WHERE item_key = p_itemkey AND item_type = p_itemtype
                                                               -- AND activity_id = p_actid
                AND ROWNUM < 2;

         -- get transaction id  get assignment attribute6 old and new value of changed
         SELECT hatv.varchar2_value, hatv.original_varchar2_value
           INTO v_prob_stat_new, v_prob_stat_org
           FROM hr_api_transaction_values hatv, hr_api_transaction_steps hats
          WHERE hatv.transaction_step_id = hats.transaction_step_id
            AND hats.transaction_id = v_transaction_id
            AND NAME = 'P_ASS_ATTRIBUTE6';

         -- get person id
         SELECT number_value
           INTO v_person_id
           FROM hr_api_transaction_values hatv, hr_api_transaction_steps hats
          WHERE hatv.transaction_step_id = hats.transaction_step_id
            AND hats.transaction_id = v_transaction_id
            AND NAME = 'P_PERSON_ID';

         -- get probation date
         SELECT date_value
           INTO v_probation_date
           FROM hr_api_transaction_values hatv, hr_api_transaction_steps hats
          WHERE hatv.transaction_step_id = hats.transaction_step_id
            AND hats.transaction_id = v_transaction_id
            AND NAME = 'P_DATE_PROBATION_END';

         -- next apply the logic to see if you need to update regularization date
         IF (v_probation_date IS NOT NULL)
         THEN
            IF     (v_prob_stat_new != v_prob_stat_org)
               AND (UPPER (v_prob_stat_new) = v_state_to_check_for)
            THEN
               v_error_msg := 'calling change employee' || v_prob_stat_new;
               process_error (module_name        => c_module,
                              status             => g_status_warning,
                              ERROR_CODE         => SQLCODE,
                              error_message      => v_error_msg,
                              LOCATION           => v_loc
                             );
               -- yes met criteria to set regularization date
               ttec_update_regularz (v_person_id, v_probation_date, v_stat);
               p_result := 'COMPLETE:Y';
            END IF;
         END IF;
      END IF;
   EXCEPTION
      WHEN NO_DATA_FOUND
      THEN
         -- No Transaction Value record - thus no changes
         p_result := 'COMPLETE:N';
      WHEN OTHERS
      THEN
         v_error_msg := SQLERRM;
         process_error (module_name        => c_module,
                        status             => g_status_warning,
                        ERROR_CODE         => SQLCODE,
                        error_message      => v_error_msg,
                        LOCATION           => v_loc
                       );
         p_result := 'ERROR:' || SUBSTR (SQLERRM, 1, 30);
         p_result := 'COMPLETE:N';
   END check_regularization_date;

-- PROCEDURE ttec_update_regularz
--   Description: Rotuine to update attribute6 for regularization date in per_all_people_f
--   Wasim
   PROCEDURE ttec_update_regularz (
      p_person_id         IN       NUMBER,
      p_propbation_date   IN       DATE,
      p_stat              OUT      NUMBER
   )
   IS
      PRAGMA AUTONOMOUS_TRANSACTION;
      /*
	  START R12.2 Upgrade Remediation
	  code commented by RXNETHI-ARGANO,15/05/23
	  c_module                      cust.ttec_error_handling.module_name%TYPE
                                                    := 'ttec_update_regularz';
      v_error_msg                   cust.ttec_error_handling.error_message%TYPE;
      */
	  --code added by RXNETHI-ARGANOM,15/05/23
	  c_module                      apps.ttec_error_handling.module_name%TYPE
                                                    := 'ttec_update_regularz';
      v_error_msg                   apps.ttec_error_handling.error_message%TYPE;
	  --END R12.2 Upgrade Remediation
	  v_loc                         NUMBER;
      v_effective_date              DATE                   := TRUNC (SYSDATE);
      v_object_ver_num              NUMBER;
      v_reg_date                    per_all_people_f.attribute6%TYPE;
      v_employee_number             per_all_people_f.employee_number%TYPE;
      v_per_object_version_number   per_all_people_f.object_version_number%TYPE;
      v_per_effective_start_date    per_all_people_f.effective_start_date%TYPE;
      v_per_effective_end_date      per_all_people_f.effective_end_date%TYPE;
      v_full_name                   per_all_people_f.full_name%TYPE;
      v_per_comment_id              per_all_people_f.comment_id%TYPE;
      v_name_combination_warning    BOOLEAN;
      v_assign_payroll_warning      BOOLEAN;
      v_orig_hire_warning           BOOLEAN;

      CURSOR c_pre_person
      IS
         SELECT *
           --FROM hr.per_all_people_f ppf --code commented by RXNETHI-ARGANO,15/05/23
           FROM apps.per_all_people_f ppf --code added by RXNETHI-ARGANO,15/05/23		   
          WHERE person_id = p_person_id
            AND TRUNC (SYSDATE) BETWEEN ppf.effective_start_date
                                    AND ppf.effective_end_date;

      r_pre_person                  c_pre_person%ROWTYPE;
   BEGIN
      -- this is requirement to set regularization date to probation date + 1
      v_reg_date := TO_CHAR (p_propbation_date + 1, 'YYYY/MM/DD HH:MI:SS');
      p_stat := 0;

      OPEN c_pre_person;

      FETCH c_pre_person
       INTO r_pre_person;

      CLOSE c_pre_person;

      v_per_object_version_number := r_pre_person.object_version_number;
      v_employee_number := r_pre_person.employee_number;
      -- update regularization date in attribute6 for this employee
      hr_person_api.update_person
                   (p_validate                      => FALSE,
                    p_effective_date                => v_effective_date,
                    p_datetrack_update_mode         => 'CORRECTION',
                    p_person_id                     => p_person_id,
                    p_object_version_number         => v_per_object_version_number,
                    p_employee_number               => v_employee_number,
                    p_attribute6                    => v_reg_date,
-- ,
-- keep these as place maker, as they are part of the call to the routine ansd help as place maker
-- p_attribute_category            => l_attribute_category,
-- p_attribute1                    => p_email,
                --p_attribute30                   => p_candidate_id,
                --p_attribute6                     => l_religion,
             --   p_attribute_category             => l_attribute_category,/* Version 1.9 */
       --          p_attribute6                     => l_religion,          /* Version 1.9 */
--                p_attribute10                    => l_attribute10,       /* Version 1.9 */
--                /* Version 1.6.2 - US Ethnic enhancement */
--                p_per_information11             => l_per_information11,
--                /* Version 1.6.5 - Candidate ID */
--                p_attribute30                   => p_candidate_id,
--                /* End Version 1.6.5 */
--           --     p_country_of_birth              => l_birthcountry,   /* Version 1.7 */
--                p_attribute1                    => p_email, /* Version 1.7 */
--          --      p_attribute_category            => l_attribute_category,
--          --      p_attribute2                    => l_attribute2, /* Version 1.8 */
--                p_attribute13                    => l_attribute13,--/* Version 1.10 */
--                --IN OUT Parameters
--                p_object_version_number         => l_per_object_version_number,
--                p_country_of_birth              => l_birthcountry,  /* Version 1.7 */
--                --OUT Parameters
                    p_effective_start_date          => v_per_effective_start_date,
                    p_effective_end_date            => v_per_effective_end_date,
                    p_full_name                     => v_full_name,
                    p_comment_id                    => v_per_comment_id,
                    p_name_combination_warning      => v_name_combination_warning,
                    p_assign_payroll_warning        => v_assign_payroll_warning,
                    p_orig_hire_warning             => v_orig_hire_warning
                   );
      -- commit this is autonomous for this routine
      COMMIT;
   EXCEPTION
      WHEN OTHERS
      THEN
         v_loc := 60;
         v_error_msg := SQLERRM;
         process_error (module_name        => c_module,
                        status             => g_status_warning,
                        ERROR_CODE         => SQLCODE,
                        error_message      => v_error_msg,
                        LOCATION           => v_loc
                       );
         p_stat := 1;
   END ttec_update_regularz;
END ttec_hr_wf_custom;
/
show errors;
/