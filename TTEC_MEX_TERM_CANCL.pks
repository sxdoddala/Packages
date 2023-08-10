create or replace PACKAGE      TTEC_MEX_TERM_CANCL AUTHID CURRENT_USER
AS
/* $Header: TTEC_MEX_TERM_CANCL  $ */

   /*== START =================================================================*\
     Author:  Wasim Manasfi
       Date:  11/12/10
       Desc:  This package is intended to be ran once for canceling the termination of specific employees in  Mexico


     Modification History:

     Mod#  Date        Author       Description (Include Ticket#)
    -----  ----------  ----------   --------------------------------------------
      001  11/12/10  Wasim Manasfi  Initial Creation (MEX version)
	  002  11/MAY/23 RXNETHI-ARGANO R12.2 Upgrade Remediation

   \*== END ===================================================================*/

   --
   PROCEDURE LOG_MESSAGE (
      P_BATCH_RUN_NUMBER         IN   NUMBER,
      P_API_NAME                 IN   VARCHAR2,
      P_STATUS                   IN   VARCHAR2,
      P_ERROR_NUMBER             IN   NUMBER,
      P_ERROR_MESSAGE            IN   VARCHAR2,
      P_EXTENDED_ERROR_MESSAGE   IN   VARCHAR2,
      P_SOURCE_ROW_INFO          IN   VARCHAR2
   );

   PROCEDURE TERM_CANCEL (
      P_EFFECTIVE_DATE   IN   DATE,
      --P_PERSON_ID        IN   HR.PER_ALL_ASSIGNMENTS_F.PERSON_ID%TYPE, --code commented by RXNETHI-ARGANO,11/05/23
      --P_EMP_NUMBER       IN   HR.PER_ALL_PEOPLE_F.EMPLOYEE_NUMBER%TYPE --code commented by RXNETHI-ARGANO,11/05/23
	  P_PERSON_ID        IN   APPS.PER_ALL_ASSIGNMENTS_F.PERSON_ID%TYPE, --code added by RXNETHI-ARGANO,11/05/23
      P_EMP_NUMBER       IN   APPS.PER_ALL_PEOPLE_F.EMPLOYEE_NUMBER%TYPE --code added by RXNETHI-ARGANO,11/05/23
   );

--
-- PROCEDURE Main
--
-- Description: This is the front end procedure that will be called to
-- cancel termination
--
   PROCEDURE MAIN;

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
PROCEDURE CONC_MGR_WRAPPER (
      P_ERROR_MSG            OUT      VARCHAR2,
      P_ERROR_CODE           OUT      VARCHAR2,
      P_EMP_NO_LOW           IN       NUMBER,
      P_EMP_NO_HIGH          IN       NUMBER,
      P_TEST_MODE            IN       VARCHAR2,
      P_EFFECTIVE_DATE       IN       VARCHAR2,
      P_EFFECTIVE_END_DATE   IN       VARCHAR2 )
     ;
END TTEC_MEX_TERM_CANCL;
/
show errors;
/