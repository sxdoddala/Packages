create or replace PACKAGE BODY      TTEC_MEX_TERM_CANCL
AS
/* $Header: TTEC_MEX_TERM_CANCL_1  $ */

   /*== START =================================================================*\
     Author:  Wasim Manasfi
       Date:  11/12/10
       Desc:  This package is intended to be ran once for canceling the termination of specific employees in  Mexico


     Modification History:

     Mod#  Date        Author       Description (Include Ticket#)
    -----  ----------  ----------   --------------------------------------------
      001  11/12/10  Wasim Manasfi  Initial Creation (MEX version)
      001  11/MAY/23 RXNETHI-ARGANO R12.2 Upgrade Remediation

   \*== END ===================================================================*/

   -- Testing Variables - NOT FOR PROD
   T_EMPLOYEE_NUMBER_LOW    NUMBER;                       --      := 7000820;
   T_EMPLOYEE_NUMBER_HIGH   NUMBER;                       --      := 7000820;
   T_TEST_MODE              BOOLEAN                                   := TRUE;
   -- Global Constants
   G_EFFECTIVE_DATE         DATE                   := TO_DATE ('01-AUG-2010');
   G_EFFECTIVE_END_DATE     DATE                   := TO_DATE ('31-AUG-2010');
   --G_BUS_GRP_ID             HR.PER_ALL_PEOPLE_F.BUSINESS_GROUP_ID%TYPE          --code commented by RXNETHI-ARGANO,11/05/23
   G_BUS_GRP_ID             APPS.PER_ALL_PEOPLE_F.BUSINESS_GROUP_ID%TYPE          --code added by RXNETHI-ARGANO,11/05/23
                                                                      := 1633;
   -- added BS
   --g_old_mgmt_payroll     hr.pay_all_payrolls_f.payroll_name%TYPE := 'PHL Management_OLD';
   --g_old_non_mgmt_payroll hr.pay_all_payrolls_f.payroll_name%TYPE := 'PHL Non-Management_OLD';
   --g_new_mgmt_payroll     hr.pay_all_payrolls_f.payroll_name%TYPE := 'PHL Management';
   --g_new_non_mgmt_payroll hr.pay_all_payrolls_f.payroll_name%TYPE := 'PHL Non-Management';
   G_VALIDATE_DELETE_EES    BOOLEAN                                  := FALSE;
   G_VALIDATE_UPDATE_ASG    BOOLEAN                                  := FALSE;
   G_BATCH_RUN_NUMBER       NUMBER                                       := 0;
   -- Global Count Variables for logging information
   G_TOTAL_EMP_CNT          NUMBER                                       := 0;
   G_SUCCESS_EMP_CNT        NUMBER                                       := 0;
   G_FAIL_EMP_CNT           NUMBER                                       := 0;
   G_TOTAL_ASGN_CNT         NUMBER                                       := 0;
   G_SUCCESS_ASGN_CNT       NUMBER                                       := 0;
   G_FAIL_ASGN_CNT          NUMBER                                       := 0;
   G_EMP_ASGN_FAIL_FLAG     BOOLEAN;

--
-- PROCEDURE log_message
--
-- Description: User the hr_batch_message_line_api to log a error / warning message
--   to the HR_API_BATCH_MESSAGE_LINES table.
--
   PROCEDURE LOG_MESSAGE (
      P_BATCH_RUN_NUMBER         IN   NUMBER,
      P_API_NAME                 IN   VARCHAR2,
      P_STATUS                   IN   VARCHAR2,
      P_ERROR_NUMBER             IN   NUMBER,
      P_ERROR_MESSAGE            IN   VARCHAR2,
      P_EXTENDED_ERROR_MESSAGE   IN   VARCHAR2,
      P_SOURCE_ROW_INFO          IN   VARCHAR2
   )
   IS
      PRAGMA AUTONOMOUS_TRANSACTION;
      L_VALIDATE   BOOLEAN := FALSE;
      L_LINE_ID    NUMBER;
   BEGIN
      INSERT INTO HR_API_BATCH_MESSAGE_LINES
           VALUES (HR_API_BATCH_MESSAGE_LINES_S.NEXTVAL, P_API_NAME,
                   P_BATCH_RUN_NUMBER, P_STATUS, P_ERROR_MESSAGE,
                   P_ERROR_NUMBER, P_EXTENDED_ERROR_MESSAGE,
                   P_SOURCE_ROW_INFO, NULL);

/*
  hr_batch_message_line_api.create_message_line
    ( p_validate                      => l_validate
    , p_batch_run_number              => p_batch_run_number
    , p_api_name                      => p_api_name
    , p_status                        => p_status
    , p_error_number                  => p_error_number
    , p_error_message                 => p_error_message
    , p_extended_error_message        => p_extended_error_message
    , p_source_row_information        => p_source_row_info
    , p_line_id                       => l_line_id );
*/
      COMMIT;
   EXCEPTION
      WHEN OTHERS
      THEN
         NULL;
   END LOG_MESSAGE;

   PROCEDURE TERM_CANCEL (
      P_EFFECTIVE_DATE   IN   DATE,
      --P_PERSON_ID        IN   HR.PER_ALL_ASSIGNMENTS_F.PERSON_ID%TYPE,  --code commented by RXNETHI-ARGANO,11/05/23
      --P_EMP_NUMBER       IN   HR.PER_ALL_PEOPLE_F.EMPLOYEE_NUMBER%TYPE  --code commented by RXNETHI-ARGANO,11/05/23
	  P_PERSON_ID        IN   APPS.PER_ALL_ASSIGNMENTS_F.PERSON_ID%TYPE,  --code added by RXNETHI-ARGANO,11/05/23
      P_EMP_NUMBER       IN   APPS.PER_ALL_PEOPLE_F.EMPLOYEE_NUMBER%TYPE  --code added by RXNETHI-ARGANO,11/05/23
   )
   IS
      L_API_NAME       VARCHAR2 (20) := 'TERM_CANCEL';
      L_CLEAR_FIELDS   VARCHAR2 (2)  := 'Y';
   BEGIN
      G_TOTAL_ASGN_CNT := G_TOTAL_ASGN_CNT + 1;
      FND_FILE.PUT_LINE (FND_FILE.LOG,
                            '- UPDATE_ASG -Before Term Cancelation '
                         || 'Employee Number : '
                         || P_EMP_NUMBER
                         || 'Terminartion Date:'
                         || TO_CHAR (P_EFFECTIVE_DATE, 'DD/MM/YYYY')
                        );

      BEGIN
         APPS.HREMPTER.CANCEL_TERMINATION (P_PERSON_ID,
                                           P_EFFECTIVE_DATE,
                                           L_CLEAR_FIELDS
                                          );
         FND_FILE.PUT_LINE (FND_FILE.LOG,
                               '- Success - Term Canceled  '
                            || 'Employee Number : '
                            || P_EMP_NUMBER
                           );
      EXCEPTION
         WHEN OTHERS
         THEN
            FND_FILE.PUT_LINE (FND_FILE.LOG, 'Failed Cancelation -----');
            LOG_MESSAGE
                     (G_BATCH_RUN_NUMBER,
                      L_API_NAME,
                      'F',
                      SQLCODE                                -- p_error_number
                             ,
                      SQLERRM                               -- p_error_message
                             ,
                      FND_MESSAGE.GET              -- p_extended_error_message
                                     ,
                         '- UPDATE_ASG - Asg ID: Update Assg Criteria Error '
                      || P_EMP_NUMBER
                      || '; Eff Date: '
                      || P_EFFECTIVE_DATE
                     );
            G_FAIL_ASGN_CNT := G_FAIL_ASGN_CNT + 1;
            G_EMP_ASGN_FAIL_FLAG := TRUE;
      END;
--    RAISE;
   END TERM_CANCEL;

-- Description: This procedure will use the hr_assignment_api to Update the
--   following fields: Payroll_id; Pay_basis_id; Employment_category; and,
--   GRE.  The mode will be determine by the status of the record.
--
--
   PROCEDURE MAIN
   IS
      L_CNT                  NUMBER;
      L_BUS_GRP_ID           NUMBER;
      L_NEW_SAB_PAYROLL_ID   NUMBER;
      L_NEW_SSI_PAYROLL_ID   NUMBER;
      L_NEW_PAYROLL_ID       NUMBER;
      L_API_NAME             VARCHAR2 (50)         := 'ttec_mex_asg_pkg.main';
      -- added BS
      L_EMP_CATEGORY         VARCHAR2 (64);
      L_PAY_BASIS            VARCHAR2 (64);
      L_PAY_BASIS_NAME       VARCHAR2 (64);
      L_PAY_BASIS_LKUP       VARCHAR2 (10);
      L_NEW_SCK_ID           NUMBER (10);     -- "sck" = "soft coded keyflex"
      L_SCK_CONCAT_SEGS      VARCHAR2 (150);
      L_ASG_PROCESS_DATE     DATE;
      -- end of add BS
      E_BUS_GRP_ERROR        EXCEPTION;
      E_SAB_PAYROLL_ERROR    EXCEPTION;
      E_SSI_PAYROLL_ERROR    EXCEPTION;
      E_EMP_CAT_ERROR        EXCEPTION;                           -- added BS
      E_PAY_BASIS_ERROR      EXCEPTION;                           -- added BS
      E_SCK_ERROR            EXCEPTION;                           -- added BS
      L_ORG_UNIT_NAME        VARCHAR2 (50);           -- new var for org name
      L_ORG_ID               NUMBER (10);               -- new var for org id

      -- SEED QUERY need revising
      CURSOR GET_MEX_EMPS
      IS
         SELECT DISTINCT PPL.EMPLOYEE_NUMBER, PPL.PERSON_ID, PPL.FULL_NAME,
                         ASG.ASSIGNMENT_NUMBER, ASG.ASSIGNMENT_ID,
                         PPOS.DATE_START, PPOS.ACTUAL_TERMINATION_DATE,

                         -- PPB.NAME PAY_BASIS,
                         (SELECT A4.EFFECTIVE_START_DATE
                            FROM PER_ALL_ASSIGNMENTS_F A4
                           WHERE ASG.ASSIGNMENT_ID =
                                            A4.ASSIGNMENT_ID
                             AND A4.EFFECTIVE_START_DATE =
                                    (SELECT MIN (A2.EFFECTIVE_START_DATE)
                                       FROM PER_ALL_ASSIGNMENTS_F A2
                                      WHERE
                                            -- A2.PAY_BASIS_ID IN (399, 379)  -- changed per Bob IM
                                                                 -- A2.PAY_BASIS_ID IN (359, 360)
                                            A2.PAY_BASIS_ID IN (
                                               SELECT PAY_BASIS_ID
                                                 --FROM HR.PER_PAY_BASES --code commented by RXNETHI-ARGANO,11/05/23
												 FROM APPS.PER_PAY_BASES --code added by RXNETHI-ARGANO,11/05/23
                                                -- where PAY_BASIS_ID IN (359, 360)
                                               WHERE  (    UPPER(PAY_BASIS) IN ('MONTHLY', 'HOURLY' )
                                                  AND BUSINESS_GROUP_ID = 1633
                                                  AND (UPPER(NAME )IN
                                                         ('MX HOURLY SALARY',
                                                         'MX MONTHLY SALARY')
                                                  )))
                                        AND A2.ASSIGNMENT_ID =
                                                              A4.ASSIGNMENT_ID))
                                                            PAY_BASIS_CHANGE,
                         ASG.PAYROLL_ID
                    FROM PER_ALL_PEOPLE_F PPL,
                         PER_ALL_ASSIGNMENTS_F ASG,
                         PER_PERIODS_OF_SERVICE PPOS,
                         PER_PAY_BASES PPB
                   WHERE PPL.BUSINESS_GROUP_ID = 1633
                     AND NVL (PPOS.ACTUAL_TERMINATION_DATE, TRUNC (SYSDATE))
                            BETWEEN PPL.EFFECTIVE_START_DATE
                                AND PPL.EFFECTIVE_END_DATE
                     AND PPL.PERSON_ID = ASG.PERSON_ID
                     AND NVL (PPOS.ACTUAL_TERMINATION_DATE, TRUNC (SYSDATE))
                            BETWEEN ASG.EFFECTIVE_START_DATE
                                AND ASG.EFFECTIVE_END_DATE
                     AND ASG.PERIOD_OF_SERVICE_ID = PPOS.PERIOD_OF_SERVICE_ID
                     AND (PPOS.ACTUAL_TERMINATION_DATE BETWEEN G_EFFECTIVE_DATE
                                                           AND G_EFFECTIVE_END_DATE
                         -- OR PPOS.ACTUAL_TERMINATION_DATE IS NOT NULL
                         )
                     AND PPOS.DATE_START < G_EFFECTIVE_DATE
                                                           --  AND PPL.EMPLOYEE_NUMBER = '7001362';
      ;

--         ORDER BY TAB.EMPLOYEE_NUMBER;
      MEX_EMP_REC            GET_MEX_EMPS%ROWTYPE;
   BEGIN
      -- Set the batch run number if not already set.
      IF G_BATCH_RUN_NUMBER = 0
      THEN
         SELECT NVL (MAX (BATCH_RUN_NUMBER), 0) + 1
           INTO G_BATCH_RUN_NUMBER
           --FROM HR.HR_API_BATCH_MESSAGE_LINES; --code commented by RXNETHI-ARGANO,11/05/23
		   FROM APPS.HR_API_BATCH_MESSAGE_LINES; --code added by RXNETHI-ARGANO,11/05/23
      END IF;

      -- Get the Business Group ID for Mexico

      -- Get all MEX Employees who have been assigned to one of the 2 specified Payrolls
      -- during 2010.  Any MEX Employee assignments to other Payrolls during 2010 will
      -- need to be manually Updated via the forms.
      OPEN GET_MEX_EMPS;

      LOOP
         FETCH GET_MEX_EMPS
          INTO MEX_EMP_REC;

         EXIT WHEN GET_MEX_EMPS%NOTFOUND;
         G_EMP_ASGN_FAIL_FLAG := FALSE;
         FND_FILE.PUT_LINE (FND_FILE.LOG, '----------------------------');
         FND_FILE.PUT_LINE (FND_FILE.LOG,
                               '-----------MAIN Employee Number '
                            || MEX_EMP_REC.EMPLOYEE_NUMBER
                            || 'Term Date: '
                            || TO_CHAR (MEX_EMP_REC.ACTUAL_TERMINATION_DATE)
                           );
         TERM_CANCEL (MEX_EMP_REC.ACTUAL_TERMINATION_DATE,
                      MEX_EMP_REC.PERSON_ID,
                      MEX_EMP_REC.EMPLOYEE_NUMBER
                     );
         FND_FILE.PUT_LINE (FND_FILE.LOG, 'MAIN - Term Cancled  ');
       -- added, BS
       -- set variables for info to be changed
      -- FND_FILE.PUT_LINE (FND_FILE.LOG, 'MAIN - Loop Getting EMP_EMP CATG  A' );
      END LOOP;

      -- COMMIT all updates for the Employee at one time.
      IF NOT T_TEST_MODE
      THEN
         COMMIT;                               -- No Auto Commit in Test Mode
         FND_FILE.PUT_LINE (FND_FILE.LOG, '-MAIN - commiting data');
      ELSE
         ROLLBACK;
         FND_FILE.PUT_LINE (FND_FILE.LOG, '-MAIN - Roll back ');
      END IF;

      IF G_EMP_ASGN_FAIL_FLAG
      THEN
         G_FAIL_EMP_CNT := G_FAIL_EMP_CNT + 1;
      ELSE
         G_SUCCESS_EMP_CNT := G_SUCCESS_EMP_CNT + 1;
      END IF;

      G_TOTAL_EMP_CNT := GET_MEX_EMPS%ROWCOUNT;

      CLOSE GET_MEX_EMPS;
   EXCEPTION
      WHEN OTHERS
      THEN
         -- Log SQLERRM error
         LOG_MESSAGE (G_BATCH_RUN_NUMBER,
                      L_API_NAME                                 -- p_api_name
                                ,
                      'F'                                          -- p_status
                         ,
                      SQLCODE                                -- p_error_number
                             ,
                      SQLERRM                               -- p_error_message
                             ,
                      FND_MESSAGE.GET              -- p_extended_error_message
                                     ,
                      NULL
                     );
    -- Unknown Error Point and State.  Rollback and Review.
--    ROLLBACK;
   END MAIN;

--
-- PROCEDURE conc_mgr_wrapper
--
-- Description: This is a wrapper procedure to be called directly from the Concurrent
--   Mgr.  It will set Test Globals from input parameters and will output the final log.
--   This approach will allow the Main process to be ran/tested from a SQL prompt and
--   the Cong Mgr.
--
   PROCEDURE CONC_MGR_WRAPPER (
      P_ERROR_MSG            OUT      VARCHAR2,
      P_ERROR_CODE           OUT      VARCHAR2,
      P_EMP_NO_LOW           IN       NUMBER,
      P_EMP_NO_HIGH          IN       NUMBER,
      P_TEST_MODE            IN       VARCHAR2,
      P_EFFECTIVE_DATE       IN       VARCHAR2,
      P_EFFECTIVE_END_DATE   IN       VARCHAR2
   )
   IS
      L_EE_WARNING_CNT    NUMBER                      := 0;
      L_TERM_ASSIGN_CNT   NUMBER                      := 0;

      CURSOR GET_ERROR_MESSAGE
      IS
         SELECT UNIQUE ERROR_MESSAGE
                  FROM HR_API_BATCH_MESSAGE_LINES
                 WHERE BATCH_RUN_NUMBER = G_BATCH_RUN_NUMBER
                   AND STATUS = 'F'
                   AND NVL (EXTENDED_ERROR_MESSAGE, ' ') !=
                          'An assignment with status TERM_ASSIGN cannot have any other attributes updated.'
              ORDER BY ERROR_MESSAGE;

      ERROR_MESSAGE_REC   GET_ERROR_MESSAGE%ROWTYPE;

      CURSOR GET_ERRORS (P_ERR_MESS VARCHAR2)
      IS
         SELECT SOURCE_ROW_INFORMATION
           FROM HR_API_BATCH_MESSAGE_LINES
          WHERE BATCH_RUN_NUMBER = G_BATCH_RUN_NUMBER
            AND STATUS = 'F'
            AND ERROR_MESSAGE = P_ERR_MESS;

      ERROR_REC           GET_ERRORS%ROWTYPE;

      CURSOR GET_WARN_MESSAGE
      IS
         SELECT UNIQUE EXTENDED_ERROR_MESSAGE
                  FROM HR_API_BATCH_MESSAGE_LINES
                 WHERE BATCH_RUN_NUMBER = G_BATCH_RUN_NUMBER
                   AND STATUS = 'W'
                   AND NVL (EXTENDED_ERROR_MESSAGE, ' ') !=
                                                     'Element Entries Changed'
              ORDER BY EXTENDED_ERROR_MESSAGE;

      WARN_MESSAGE_REC    GET_WARN_MESSAGE%ROWTYPE;

      CURSOR GET_WARNS (P_WARN_MESS VARCHAR2)
      IS
         SELECT   SOURCE_ROW_INFORMATION
             FROM HR_API_BATCH_MESSAGE_LINES
            WHERE BATCH_RUN_NUMBER = G_BATCH_RUN_NUMBER
              AND STATUS = 'W'
              AND EXTENDED_ERROR_MESSAGE = P_WARN_MESS
         ORDER BY EXTENDED_ERROR_MESSAGE;

      WARN_REC            GET_WARNS%ROWTYPE;
   BEGIN
      -- Set Global Test Variables
      IF P_TEST_MODE = 'N'
      THEN
         T_TEST_MODE := FALSE;
      ELSE
         T_TEST_MODE := TRUE;
      END IF;

      T_EMPLOYEE_NUMBER_LOW := P_EMP_NO_LOW;
      T_EMPLOYEE_NUMBER_HIGH := P_EMP_NO_HIGH;
      G_EFFECTIVE_DATE := TO_DATE (P_EFFECTIVE_DATE, 'DD-MON-YYYY');
      -- -- TRUNC(P_EFFECTIVE_DATE);
      G_EFFECTIVE_END_DATE := TO_DATE (P_EFFECTIVE_END_DATE, 'DD-MON-YYYY');
      -- = TRUNC(P_EFFECTIVE_END_DATE);
      FND_FILE.NEW_LINE (FND_FILE.LOG, 1);
      FND_FILE.PUT_LINE (FND_FILE.LOG,
                         'Emp # Low : ' || T_EMPLOYEE_NUMBER_LOW);
      FND_FILE.PUT_LINE (FND_FILE.LOG,
                         'Emp # High: ' || T_EMPLOYEE_NUMBER_HIGH
                        );
      FND_FILE.PUT_LINE (FND_FILE.LOG, 'Test Mode?: ' || P_TEST_MODE);
      FND_FILE.PUT_LINE (FND_FILE.LOG,
                         'Effective Date?: ' || TO_CHAR (G_EFFECTIVE_DATE)
                        );
      FND_FILE.PUT_LINE (FND_FILE.LOG,
                            'Effective END Date?: '
                         || TO_CHAR (G_EFFECTIVE_END_DATE)
                        );
      -- Submit the Main Process
      MAIN;

      -- Log Counts
      BEGIN
         IF G_BATCH_RUN_NUMBER = 0
         THEN
            FND_FILE.PUT_LINE (FND_FILE.LOG,
                               'Message Batch #: No Messages Generated'
                              );
         ELSE
            FND_FILE.PUT_LINE (FND_FILE.LOG,
                               'Message Batch #: ' || G_BATCH_RUN_NUMBER
                              );
         END IF;

         FND_FILE.NEW_LINE (FND_FILE.LOG, 1);
         FND_FILE.PUT_LINE (FND_FILE.LOG, 'COUNTS');
         FND_FILE.PUT_LINE
                  (FND_FILE.LOG,
                   '---------------------------------------------------------'
                  );
         FND_FILE.PUT_LINE (FND_FILE.LOG,
                            '# Employees Processed       : '
                            || G_TOTAL_EMP_CNT
                           );
         FND_FILE.PUT_LINE (FND_FILE.LOG,
                               '   # Successful             : '
                            || G_SUCCESS_EMP_CNT
                           );
         FND_FILE.PUT_LINE (FND_FILE.LOG,
                            '   # Failed                 : ' || G_FAIL_EMP_CNT
                           );
         FND_FILE.NEW_LINE (FND_FILE.LOG, 1);
         FND_FILE.PUT_LINE (FND_FILE.LOG,
                               '# Emp Assignments Processed : '
                            || G_TOTAL_ASGN_CNT
                           );
         FND_FILE.PUT_LINE (FND_FILE.LOG,
                               '   # Successful             : '
                            || G_SUCCESS_ASGN_CNT
                           );
         FND_FILE.PUT_LINE (FND_FILE.LOG,
                            '   # Failed                 : '
                            || G_FAIL_ASGN_CNT
                           );
         FND_FILE.PUT_LINE
                  (FND_FILE.LOG,
                   '---------------------------------------------------------'
                  );
         FND_FILE.NEW_LINE (FND_FILE.LOG, 2);
         FND_FILE.PUT_LINE (FND_FILE.LOG, 'Expected Warning and Error Counts');
         FND_FILE.PUT_LINE (FND_FILE.OUTPUT, 'COUNTS');
         FND_FILE.PUT_LINE
                  (FND_FILE.OUTPUT,
                   '---------------------------------------------------------'
                  );
         FND_FILE.PUT_LINE (FND_FILE.OUTPUT,
                            '# Employees Processed: ' || G_TOTAL_EMP_CNT
                           );
         FND_FILE.PUT_LINE (FND_FILE.OUTPUT,
                            '   # Successful      : ' || G_SUCCESS_EMP_CNT
                           );
         FND_FILE.PUT_LINE (FND_FILE.OUTPUT,
                            '   # Failed          : ' || G_FAIL_EMP_CNT
                           );
         FND_FILE.NEW_LINE (FND_FILE.OUTPUT, 1);
         FND_FILE.PUT_LINE (FND_FILE.OUTPUT,
                               '# Emp Assignments Processed : '
                            || G_TOTAL_ASGN_CNT
                           );
         FND_FILE.PUT_LINE (FND_FILE.OUTPUT,
                               '   # Successful             : '
                            || G_SUCCESS_ASGN_CNT
                           );
         FND_FILE.PUT_LINE (FND_FILE.OUTPUT,
                            '   # Failed                 : '
                            || G_FAIL_ASGN_CNT
                           );
         FND_FILE.PUT_LINE
                  (FND_FILE.OUTPUT,
                   '---------------------------------------------------------'
                  );
         FND_FILE.NEW_LINE (FND_FILE.OUTPUT, 2);

         SELECT COUNT (*)
           INTO L_EE_WARNING_CNT
           FROM HR_API_BATCH_MESSAGE_LINES
          WHERE BATCH_RUN_NUMBER = G_BATCH_RUN_NUMBER
            AND STATUS = 'W'
            AND NVL (EXTENDED_ERROR_MESSAGE, ' ') = 'Element Entries Changed';

         FND_FILE.PUT_LINE (FND_FILE.LOG,
                               '   Element Entries Changed warning count: '
                            || L_EE_WARNING_CNT
                           );

         SELECT COUNT (*)
           INTO L_TERM_ASSIGN_CNT
           FROM HR_API_BATCH_MESSAGE_LINES
          WHERE BATCH_RUN_NUMBER = G_BATCH_RUN_NUMBER
            AND STATUS = 'F'
            AND NVL (EXTENDED_ERROR_MESSAGE, ' ') =
                   'An assignment with status TERM_ASSIGN cannot have any other attributes updated.';

         FND_FILE.PUT_LINE
                      (FND_FILE.LOG,
                          '   Number of Employee Asgs in TERM_ASSIGN status: '
                       || L_TERM_ASSIGN_CNT
                      );
      EXCEPTION
         WHEN OTHERS
         THEN
            FND_FILE.PUT_LINE
                           (FND_FILE.LOG,
                            '   Error reporting expected Warnings and Errors'
                           );
      END;

      -- Log Errors
      BEGIN
         FND_FILE.PUT_LINE
                          (FND_FILE.LOG,
                           'Refer to Output for Detailed Errors and Warnings'
                          );
         FND_FILE.NEW_LINE (FND_FILE.LOG, 1);
         FND_FILE.PUT_LINE (FND_FILE.OUTPUT, 'ERRORS');
         FND_FILE.PUT_LINE (FND_FILE.OUTPUT, '--------------------');

         OPEN GET_ERROR_MESSAGE;

         LOOP
            FETCH GET_ERROR_MESSAGE
             INTO ERROR_MESSAGE_REC;

            EXIT WHEN GET_ERROR_MESSAGE%NOTFOUND;
            FND_FILE.PUT_LINE (FND_FILE.OUTPUT,
                               ERROR_MESSAGE_REC.ERROR_MESSAGE
                              );

            FOR ERROR_REC IN GET_ERRORS (ERROR_MESSAGE_REC.ERROR_MESSAGE)
            LOOP
               FND_FILE.PUT_LINE (FND_FILE.OUTPUT,
                                  '      ' || ERROR_REC.SOURCE_ROW_INFORMATION
                                 );
            END LOOP;
         END LOOP;

         IF GET_ERROR_MESSAGE%ROWCOUNT = 0
         THEN
            FND_FILE.PUT_LINE (FND_FILE.OUTPUT, 'No Errors to Report');
         END IF;

         CLOSE GET_ERROR_MESSAGE;
      EXCEPTION
         WHEN OTHERS
         THEN
            FND_FILE.PUT_LINE (FND_FILE.LOG,
                               '   Error Reporting Detailed Errors'
                              );
      END;

      BEGIN
         FND_FILE.NEW_LINE (FND_FILE.OUTPUT, 1);
         FND_FILE.PUT_LINE (FND_FILE.OUTPUT, 'WARNINGS');
         FND_FILE.PUT_LINE (FND_FILE.OUTPUT, '--------------------');

         OPEN GET_WARN_MESSAGE;

         LOOP
            FETCH GET_WARN_MESSAGE
             INTO WARN_MESSAGE_REC;

            EXIT WHEN GET_WARN_MESSAGE%NOTFOUND;
            FND_FILE.PUT_LINE (FND_FILE.OUTPUT,
                               WARN_MESSAGE_REC.EXTENDED_ERROR_MESSAGE
                              );

            FOR WARN_REC IN GET_WARNS (WARN_MESSAGE_REC.EXTENDED_ERROR_MESSAGE)
            LOOP
               FND_FILE.PUT_LINE (FND_FILE.OUTPUT,
                                  '      ' || WARN_REC.SOURCE_ROW_INFORMATION
                                 );
            END LOOP;
         END LOOP;

         IF GET_WARN_MESSAGE%ROWCOUNT = 0
         THEN
            FND_FILE.PUT_LINE (FND_FILE.OUTPUT, 'No Warnings to Report');
         END IF;

         CLOSE GET_WARN_MESSAGE;
      EXCEPTION
         WHEN OTHERS
         THEN
            FND_FILE.PUT_LINE (FND_FILE.LOG,
                               '   Error Reporting Detailed Warnings'
                              );
      END;
   EXCEPTION
      WHEN OTHERS
      THEN
         FND_FILE.PUT_LINE (FND_FILE.LOG, SQLCODE || ': ' || SQLERRM);
   END CONC_MGR_WRAPPER;
END TTEC_MEX_TERM_CANCL;
/
show errors;
/