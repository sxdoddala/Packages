create or replace PACKAGE      ttec_assign_costing_rules AUTHID CURRENT_USER
AS
/* $Header: TTEC_ASSIGN_COSTING_RULES.pks 1.0 2009/05/28 mdodge ship $ */

   /*== START =====================================================================*\
      Author: Michelle Dodge
        Date: May 28, 2009
   Call From:
        Desc: This is a generic package intended to be used by any and all customs
              to build the Assignment Costing using the same set of business
              rules.  An assignment ID will be passed in, and a Table of Assignment
              Cost Allocation Records will be passed out.  The Table will be
              ordered by:
                (1) Proportion - Highest to Lowest
                (2) Cost Allocation Date - Oldest to Newest
                (3) ROWID - Lowest to Highest

     Modification History:

    Version    Date     Author   Description (Include Ticket#)
    -------  --------  --------  ---------------------------------------------------
        1.0  05/28/09  MDodge    Initial version
        1.1 11/03/09   Kgonguntla   Added more logic into the package to determine
                                   and generate costing information - WO 637755
       1.2  05/21/10  Kgonuguntla Added logic to get costing string for terminated employee.
                                 changed as part of rewrite of custom costing TTSD 124797, TTSD 328917
	 1.0	09-May-2023 IXPRAVEEN(ARGANO)   		R12.2 Upgrade Remediation						 
   \*== END =======================================================================*/

   -- Error Constants
   --START R12.2 Upgrade Remediation
   /*g_application_code   cust.ttec_error_handling.application_code%TYPE   := 'HR';				-- Commented code by IXPRAVEEN-ARGANO,09-May-2023
   g_interface          cust.ttec_error_handling.INTERFACE%TYPE          := 'Asgn Cost Rules';  
   g_package            cust.ttec_error_handling.program_name%TYPE       := 'TTEC_ASSIGN_COSTING_RULES';*/
   g_application_code   apps.ttec_error_handling.application_code%TYPE   := 'HR';				--  code Added by IXPRAVEEN-ARGANO,09-May-2023
   g_interface          apps.ttec_error_handling.INTERFACE%TYPE          := 'Asgn Cost Rules';
   g_package            apps.ttec_error_handling.program_name%TYPE       := 'TTEC_ASSIGN_COSTING_RULES';
   --END R12.2.10 Upgrade remediation
   
   g_status_warning     VARCHAR2 (7)                                     := 'WARNING';
   g_status_failure     VARCHAR2 (7)                                     := 'FAILURE';
   g_valid_date         DATE                                             := TRUNC (SYSDATE);
                                                                                          -- Version 1.2

   -- Revision 1.1
   TYPE asgncostrecord IS RECORD (
   --START R12.2 Upgrade Remediation
      /*assignment_id    hr.per_all_assignments_f.assignment_id%TYPE,			-- Commented code by IXPRAVEEN-ARGANO,09-May-2023
      LOCATION         gl.gl_code_combinations.segment1%TYPE,
      client           gl.gl_code_combinations.segment2%TYPE,
      department       gl.gl_code_combinations.segment3%TYPE,
      ACCOUNT          gl.gl_code_combinations.segment4%TYPE,*/
	  assignment_id    apps.per_all_assignments_f.assignment_id%TYPE,			--  code Added by IXPRAVEEN-ARGANO,09-May-2023
      LOCATION         apps.gl_code_combinations.segment1%TYPE,
      client           apps.gl_code_combinations.segment2%TYPE,
      department       apps.gl_code_combinations.segment3%TYPE,
      ACCOUNT          apps.gl_code_combinations.segment4%TYPE,
	  --END R12.2.10 Upgrade remediation
      location_src     VARCHAR2 (25),
      client_src       VARCHAR2 (25),
      department_src   VARCHAR2 (25),
      account_src      VARCHAR2 (25),
      location_att     VARCHAR2 (25),
      department_att   VARCHAR2 (25),
      client_att       VARCHAR2 (25),
      proportion       hr.pay_cost_allocations_f.proportion%TYPE,
      active_emp       VARCHAR2 (1)
   );

   TYPE asgncosttable IS TABLE OF asgncostrecord
      INDEX BY BINARY_INTEGER;

-- PROCEDURE build_cost_accts
--
-- Description: This procedure will take an assignment_id as input and will build
--              a table of the Costing Allocations according to the TeleTech
--              Costing Rules.  It will order the output table by:
--                (1) Proportion - Highest to Lowest
--                (2) Cost Allocation Date - Oldest to Newest
--                (3) ROWID - Lowest to Highest
--
-- Arguments:
--      In: p_assignment_id - Assignment_id to Build the Costing Allocations for
--     Out: p_asgn_cost     - Table of Costing Allocations built for the input
--                            Assignment_id
--          p_return_msg    - Error message if Status = FALSE
--          p_status        - TRUE if Costing build with no errors
--                          - FALSE if error occurred preventing full building of
--                            costing
--
   PROCEDURE build_cost_accts (
      p_assignment_id   IN              hr.per_all_assignments_f.assignment_id%TYPE,
      p_asgn_costs      OUT NOCOPY      asgncosttable,
      p_return_msg      OUT             VARCHAR2,                                         -- Revision 1.1
      p_status          OUT             BOOLEAN                                           -- Revision 1.1
   );
END ttec_assign_costing_rules;
/
show errors;
/