create or replace PACKAGE TTEC_PHL_LEGISLATIVE_INFO_PKG AUTHID CURRENT_USER AS
/* $Header: ttec_phl_legislative_info_pkg.pks 1.0 2008/06/25 mdodge ship $ */

/*== START ================================================================================================*\
  Author:  Michelle Dodge
    Date:  June 25, 2008
    Desc:  This package is intended to be ran once to Move the legislative infor from the person DFF
           to the Statutory Info KFF on their current or latest assignment.

  Modification History:

  Mod#  Date        Author      Description (Include Ticket#)
 -----  ----------  ----------  ----------------------------------------------
   001  06/25/2008  M Dodge     Initial Creation
   1.0  13/JUL/2023 RXNETHI-ARGANO  R12.2 Upgrade Remediation
\*== END ==================================================================================================*/

--
-- PROCEDURE initialize_global
--
-- Description: Set global variables for the Soft Coding KeyFlex
--
PROCEDURE initialize_global;

--
-- FUNCTION format_tax_id
--
-- Description: This function will take an input string and try to reformat it to the
--              stardard tax id structure of xxx-xxx-xxx where x is a numeric.
--
--              The following formats will be reformatted (x = numeric in all formats)
--                xxxxxxxxx
--                xxx-xxx-xxx-000
--
-- Arguments:
--   IN:  p_tax_id_str  -  Input string to be evaluated and reformatted.
--
FUNCTION format_tax_id( p_tax_id_str IN  VARCHAR2 ) RETURN VARCHAR2;

--
-- FUNCTION build_sc_kff
--
-- Description: This function will take an input DFF and KFF arrays.  It will lookup the
--              current soft_coding KeyFlex and override segments from the Not Null segments
--              of the DFF.
--
-- Arguments:
--   IN:  p_sc_keyflex_id - Soft Coding Keyflex ID already on Assignment Record
--        p_dff_segments  - Segment Array of DFF on Person record
--   OUT: p_kff_segments  - Merged Segment Array of existing KFF overridden by Not NULL
--                          values from the DFF Array.
--
--FUNCTION build_sc_kff ( p_sc_keyflex_id IN  hr.per_all_assignments_f.soft_coding_keyflex_id%TYPE  --code commented by RXNETHI-ARGANO,13/07/23
FUNCTION build_sc_kff ( p_sc_keyflex_id IN  apps.per_all_assignments_f.soft_coding_keyflex_id%TYPE  --code added by RXNETHI-ARGANO,13/07/23
                      , p_dff_segments  IN  fnd_flex_ext.SegmentArray
                      , p_kff_segments  OUT fnd_flex_ext.SegmentArray ) RETURN BOOLEAN;

--
-- PROCEDURE get_sc_flex_id
--
-- Description: This procedure will take the input KFF Segment Array and call the FND_FLEX_EXT
--              package which will return the ID if it already exists or build it and return the
--              new ID.  It will also check Cross validation and Security rules and validate the
--              combination.
--
-- Arguments:
--   IN:  p_kff_segments  - Merged Segment Array of existing KFF overridden by Not NULL
--                          values from the DFF Array.
--   OUT: p_sc_keyflex_id - Soft Coding Keyflex ID returned by call to FND_FLEX_EXT
--
PROCEDURE get_sc_flex_id( p_kff_segments   IN  fnd_flex_ext.SegmentArray
                        --, p_sc_keyflex_id  OUT hr.per_all_assignments_f.soft_coding_keyflex_id%TYPE );  --code commented by RXNETHI-ARGANO,13/07/23
                        , p_sc_keyflex_id  OUT apps.per_all_assignments_f.soft_coding_keyflex_id%TYPE );  --code added by RXNETHI-ARGANO,13/07/23

--
-- PROCEDURE update_asg
--
-- Description: This procedure will use the hr_assignment_api to Update the Soft Coded Flexfield ID
--   on the input assignment record with the specified OVN.  It will use the CORRECTION mode.
--
-- Arguments:
--      In: p_effective_date  -- Effective Date of Correction to record = effective start date of record
--          p_assignment_id   -- Assignment ID to be updated with new Payroll
--          p_ovn             -- Object Version Number of Assignment ID to be updated
--          p_sc_keyflex_id   -- Soft Coding Keyflex ID returned by call to FND_FLEX_EXT
--          p_update_mode     -- CORRECTION
--
/*
START R12.2 Upgrade Remediation
code commented by RXENTHI-ARGANO,13/07/23
PROCEDURE update_asg( p_effective_date IN DATE
                    , p_assignment_id  IN hr.per_all_assignments_f.assignment_id%TYPE
                    , p_ovn            IN hr.per_all_assignments_f.object_version_number%TYPE
                    , p_sc_keyflex_id  IN hr.per_all_assignments_f.soft_coding_keyflex_id%TYPE
                    , p_update_mode    IN VARCHAR2 );
*/
--code added by RXNETHI-ARGANO,13/07/23
PROCEDURE update_asg( p_effective_date IN DATE
                    , p_assignment_id  IN apps.per_all_assignments_f.assignment_id%TYPE
                    , p_ovn            IN apps.per_all_assignments_f.object_version_number%TYPE
                    , p_sc_keyflex_id  IN apps.per_all_assignments_f.soft_coding_keyflex_id%TYPE
                    , p_update_mode    IN VARCHAR2 );

--END R12.2 Upgrade Remediaition
--
-- PROCEDURE Main
--
-- Description: This is the front end procedure that will be called to copy the legislative information
--              for each PHL employee from the person DFF to the Statutory Info KFF on their assignment.
--
PROCEDURE main;

--
-- PROCEDURE conc_mgr_wrapper
--
-- Description: This is a wrapper procedure to be called directly from the Concurrent
--   Mgr.  It will set Test Globals from input parameters and will output the final log.
--   This approach will allow the Main process to be ran/tested from the Conc Mgr.
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

END TTEC_PHL_LEGISLATIVE_INFO_PKG;
/
show errors;
/