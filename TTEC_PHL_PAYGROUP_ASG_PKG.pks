create or replace PACKAGE TTEC_PHL_PAYGROUP_ASG_PKG AUTHID CURRENT_USER AS
/* $Header: ttec_phl_paygroup_asg_pkg.pks 1.0 2008/06/05 mdodge ship $ */

/*== START ================================================================================================*\
  Author:  Michelle Dodge
    Date:  June 04, 2008
    Desc:  This package is intended to be ran once for reassigning all Philippine employees, active during
           2008, from the old PHL Payrolls to the new PHL Payrolls.

  Modification History:

  Mod#  Date        Author      Description (Include Ticket#)
 -----  ----------  ----------  ----------------------------------------------
   001  06/05/2008  M Dodge     Initial Creation
   002  05/12/2023  RXNETHI-ARGANO R12.2 Upgrade Remediation
\*== END ==================================================================================================*/

--
-- PROCEDURE log_message
--
-- Description: User the hr_batch_message_line_api to log a error / warning message
--   to the HR_API_BATCH_MESSAGE_LINES table.
--
-- Arguments:
--      In: p_batch_run_number   -- Unique Number identifying Messages for this run
--          p_api_name           -- API Call that raised error / warning being logged.
--          p_status             -- 'S' = Success; 'F' = Failure
--          p_error_number       -- Error Number (SQLCODE) identifying error raised
--          p_error_message      -- Error Message (SQLERRM) identifying error raised
--          p_extended_error_message
--          p_source_row_info    -- Info identifying row that errored.
--
PROCEDURE log_message ( p_batch_run_number        IN NUMBER
                      , p_api_name                IN VARCHAR2
                      , p_status                  IN VARCHAR2
                      , p_error_number            IN NUMBER
                      , p_error_message           IN VARCHAR2
                      , p_extended_error_message  IN VARCHAR2
                      , p_source_row_info         IN VARCHAR2 );

--
-- FUNCTION get_bus_grp_id
--
-- Description: Get the Busines Group ID for the Philippines
--
-- Arguments:
--      In: p_bus_grp_name       -- The business group name to look up the ID for
--
-- Return: Business Group ID
--

--FUNCTION get_bus_grp_id(p_bus_grp_name   IN hr.hr_all_organization_units.name%TYPE) --code commented by  RXNETHI-ARGANO,12/05/23
FUNCTION get_bus_grp_id(p_bus_grp_name   IN apps.hr_all_organization_units.name%TYPE) --code added by  RXNETHI-ARGANO,12/05/23
  RETURN NUMBER;

--
-- FUNCTION get_payroll_id
--
-- Description: Get the Payroll ID for the input Payroll Name
--
-- Arguments:
--      In: p_bus_grp_id        -- ID of the Business Group that the Payroll belongs to
--          p_payroll_name      -- Name of the Payroll to get the ID for
--
-- Return: Payroll ID
--
FUNCTION get_payroll_id( p_bus_grp_id     IN NUMBER
                       --, p_payroll_name   IN hr.pay_all_payrolls_f.payroll_name%TYPE) --code commented by RXNETHI-ARGANO,12/05/23
					   , p_payroll_name   IN apps.pay_all_payrolls_f.payroll_name%TYPE) --code added by RXNETHI-ARGANO,12/05/23
  RETURN NUMBER;

--
-- PROCEDURE zap_nonrecurring_ees
--
-- Description: Oracle prevents Updating the Payroll ID on an assignment if there are Unprocessed
--   Non-Recurring Element Entries for the effective dates of that assignment.  As all PHL
--   element entries in Oracle to date are unprocessed, these entries must be deleted.
--
-- Arguments:
--      In: p_person_id      -- Person to delete non-recurring element entries for
--          p_start_date     -- Delete non-recurring element entries for person_id from this
--                              date forward.
--          p_ees_del        -- Total # of Non-Recurring Element Entries deleted.
--
PROCEDURE zap_nonrecurring_ees( p_person_id      IN NUMBER
                              , p_start_date     IN DATE
                              , p_ees_del        OUT NUMBER );

--
-- PROCEDURE update_asg_payroll
--
-- Description: This procedure will use the hr_assignment_api to Update the Payroll on the
--   input assignment record with the specified OVN.  It will use the CORRECTION mode.
--
--
-- Arguments:
--      In: p_effective_date  -- Effective Date of Correction to record = effective start date of record
--          p_assignment_id   -- Assignment ID to be updated with new Payroll
--          p_ovn             -- Object Version Number of Assignment ID to be updated
--          p_payroll_id      -- New Payroll ID to update Assignement record with
--
/*
START R12.2 Upgrade Remediation
code commented by RXNETHI-ARGANO,12/05/23
PROCEDURE update_asg_payroll( p_effective_date IN DATE
                            , p_assignment_id  IN hr.per_all_assignments_f.assignment_id%TYPE
                            , p_ovn            IN hr.per_all_assignments_f.object_version_number%TYPE
                            , p_payroll_id     IN hr.pay_all_payrolls_f.payroll_id%TYPE
                            , p_update_mode    IN VARCHAR2 );
*/
--code added by RXNETHI-ARGANO,12/05/23
PROCEDURE update_asg_payroll( p_effective_date IN DATE
                            , p_assignment_id  IN apps.per_all_assignments_f.assignment_id%TYPE
                            , p_ovn            IN apps.per_all_assignments_f.object_version_number%TYPE
                            , p_payroll_id     IN apps.pay_all_payrolls_f.payroll_id%TYPE
                            , p_update_mode    IN VARCHAR2 );
--END R12.2 Upgrade Remediation
--
-- PROCEDURE Main
--
-- Description: This is the front end procedure that will be called to reassign all active Philippine
--   employees, as of the run date, from the old PHL Payrolls to the new PHL Payrolls.
--
-- Mapping:
--   Old Payroll               -> New Payroll
--   -------------------------    ---------------------
--   PHL Management Old           PHL Management
--   PHL Non- Management Old      PHL Non- Management
--
PROCEDURE main;

--
-- PROCEDURE conc_mgr_wrapper
--
-- Description: This is a wrapper procedure to be called directly from the Concurrent
--   Mgr.  It will set Test Globals from input parameters and will output the final log.
--   This approach will allow the Main process to be ran/tested from a SQL prompt and
--   the Cong Mgr.
--
-- Arguments:
--   IN:  p_emp_no_low  - Beginning Emp No of Range -> FOR TESTING ONLY
--        p_emp_no_high - Ending Emp No of Range -> FOR TESTING ONLY
--        p_test_mode   - TRUE if testing, otherwise FALSE
--   OUT: p_error_msg   - Required OUT param for Conc Requests
--        p_error_code  - Required OUT param for Conc Requests
--
PROCEDURE conc_mgr_wrapper( p_error_msg      OUT VARCHAR2
                          , p_error_code     OUT VARCHAR2
                          , p_emp_no_low     IN  NUMBER
                          , p_emp_no_high    IN  NUMBER
                          , p_test_mode      IN  VARCHAR2 );

END TTEC_PHL_PAYGROUP_ASG_PKG;
/
show errors;
/
