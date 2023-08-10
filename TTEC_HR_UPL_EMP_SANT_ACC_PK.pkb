create or replace PACKAGE BODY      TTEC_HR_UPL_EMP_SANT_ACC_PK
AS

/*== START ==========================================================*\
  Author:  Sergio Morra
    Date:  23-SEP-2010
Call From: Concurrent Program => "TTEC Upload Santander Accounts"
    Desc:  This Package contains the specificacions to Upload a new
           employees account assigned by the Santander Bank.


    PROCEDURE MAIN : This is the main procedure.

    Parameter Description:
       P_SOURCE        -  Type of Source File.
       P_PATH          -  Directory where the file is located.
       P_FILE_NAME     -  Name of the file.
       P_REC_STATUS    -  Record status to process.
       P_ORG_ID        -  Organization id.
       P_LOGIN_ID      -  Login id.
       P_USER_ID       -  User id.


  Modification History:

Version    Date     Author             Description (Include Ticket#)
 -----  --------  --------           ----------------------------------
 1.1        29-feb-2012  rpasula  TTECH I#1326195 added alter session code
 1.2        08-Sep-2022  Neelofar  Mexico Percepta New GRE Payroll Project.


\*== END ============================================================*/



-- Global Teletech Exceptions variables
--START R12.2 Upgrade Remediation
   /*G_APPLICATION_CODE   CUST.TTEC_ERROR_HANDLING.APPLICATION_CODE%TYPE				-- Commented code by IXPRAVEEN-ARGANO,18-july-2023
                                                                      := 'HR';
   G_INTERFACE          CUST.TTEC_ERROR_HANDLING.INTERFACE%TYPE
                                                         := 'Santander Inter';
   G_PACKAGE            CUST.TTEC_ERROR_HANDLING.PROGRAM_NAME%TYPE
                                            := 'TTEC_HR_UPL_EMP_SANT_ACC_PK';
   G_WARNING_STATUS     CUST.TTEC_ERROR_HANDLING.STATUS%TYPE     := 'WARNING';
   G_ERROR_STATUS       CUST.TTEC_ERROR_HANDLING.STATUS%TYPE       := 'ERROR';
   G_FAILURE_STATUS     CUST.TTEC_ERROR_HANDLING.STATUS%TYPE     := 'FAILURE';*/
   G_APPLICATION_CODE   apps.TTEC_ERROR_HANDLING.APPLICATION_CODE%TYPE						--  code Added by IXPRAVEEN-ARGANO,   18-july-2023

                                                                      := 'HR';
   G_INTERFACE          apps.TTEC_ERROR_HANDLING.INTERFACE%TYPE
                                                         := 'Santander Inter';
   G_PACKAGE            apps.TTEC_ERROR_HANDLING.PROGRAM_NAME%TYPE
                                            := 'TTEC_HR_UPL_EMP_SANT_ACC_PK';
   G_WARNING_STATUS     apps.TTEC_ERROR_HANDLING.STATUS%TYPE     := 'WARNING';
   G_ERROR_STATUS       apps.TTEC_ERROR_HANDLING.STATUS%TYPE       := 'ERROR';
   G_FAILURE_STATUS     apps.TTEC_ERROR_HANDLING.STATUS%TYPE     := 'FAILURE';
   --END R12.2.12 Upgrade remediation
   -- Global variables
   G_GLOBAL_STATUS      VARCHAR2 (10)                                := 'NAV';
   G_RECORD_PROCESSED   INTEGER;
   G_RECORD_ERROR       INTEGER;


PROCEDURE MAIN (
      ERRBUF         OUT NOCOPY      VARCHAR2,
      RETCODE        OUT NOCOPY      VARCHAR2,
      P_SOURCE       IN              VARCHAR2 DEFAULT NULL,
      P_PATH         IN              VARCHAR2 DEFAULT NULL,
      P_FILE_NAME    IN              VARCHAR2 DEFAULT NULL,
      P_REC_STATUS   IN              VARCHAR2 DEFAULT NULL,
      P_EFFECTIVE_DATE IN  DATE,
      P_ORG_ID       IN              VARCHAR2 DEFAULT NULL,
      P_LOGIN_ID     IN              VARCHAR2 DEFAULT NULL,
      P_USER_ID      IN              VARCHAR2 DEFAULT NULL
   )
   IS
      -- UTL File Variables
      L_FILE               UTL_FILE.FILE_TYPE;
      L_LINE               VARCHAR2 (300);
      L_ERROR              VARCHAR2 (500);
      L_FILE_NAME          VARCHAR2 (50);
      L_LINE_COUNTER       INTEGER                                       := 0;
      L_EMP_NUMBER         VARCHAR2 (100);
      L_EMP_ACCOUNT        VARCHAR2 (100);
      L_STATUS             VARCHAR2 (100);
      L_ORG_ID             NUMBER;
      L_STATUS_CODE        VARCHAR2 (10);
      L_PROCESS_FLAG       VARCHAR2 (10);
      L_USER_ID            NUMBER;
      L_LOGIN              NUMBER;
      L_TO_INSERT          VARCHAR2 (10)                               := 'N';
      L_SOURCE             VARCHAR2 (100)                         := P_SOURCE;
      L_END_OF_FILE        BOOLEAN                                   := FALSE;
      -- Employee Account insert
      -- Variables
      L_ORG_PAY_MET_NAME   PAY_ORG_PAYMENT_METHODS_F.ORG_PAYMENT_METHOD_NAME%TYPE;
      L_ORG_PAY_MET_ID     PAY_ORG_PAYMENT_METHODS_F.ORG_PAYMENT_METHOD_ID%TYPE;
      L_BANK_NAME          PAY_EXTERNAL_ACCOUNTS.SEGMENT1%TYPE;
      L_ACCOUNT_TYPE       PAY_EXTERNAL_ACCOUNTS.SEGMENT4%TYPE;
      L_TERRITORY          PAY_EXTERNAL_ACCOUNTS.TERRITORY_CODE%TYPE;
      L_ASSIGNMENT_ID      PER_ALL_ASSIGNMENTS_F.ASSIGNMENT_ID%TYPE;
      L_PAYROLL_NAME       PAY_ALL_PAYROLLS_F.PAYROLL_NAME%TYPE;
      L_EMPLOYEE_NUMBER    PER_ALL_PEOPLE_F.EMPLOYEE_NUMBER%TYPE;
      L_BANK_BRANCH        FND_LOOKUP_VALUES.LOOKUP_CODE%TYPE;
      L_EMPLOYEE_BK_ACC    VARCHAR2 (100);
      L_MODULE             TTEC_ERROR_HANDLING.MODULE_NAME%TYPE
                           := 'Upload new employee bank account to int.table';
      L_RECORD_READ        INTEGER                                       := 0;
      L_PROCESS_STATUS     VARCHAR2 (100);
      L_EMP_BK_ACC_ID      NUMBER;
      L_ERROR_GEA          BOOLEAN                                   := FALSE;
      L_ERROR_GOP          BOOLEAN                                   := FALSE;

      -- Cursor
      CURSOR C_EMP_BANK_ACC
      IS
         SELECT   EMP_BK_ACC_ID, EMPLOYEE_NUMBER, ACCOUNT_NUMBER
             FROM TTEC_HR_EMPLOYEE_BK_ACC_INT
            WHERE STATUS_CODE =
                      DECODE (P_REC_STATUS,
                              'ALL', STATUS_CODE,
                              P_REC_STATUS
                             )
              AND STATUS_CODE != 'PRC'
              AND ORG_ID = P_ORG_ID
         ORDER BY EMPLOYEE_NUMBER;
   BEGIN
      G_RECORD_ERROR := 0;
      G_RECORD_PROCESSED := 0;
      L_FILE_NAME := P_FILE_NAME;
      Begin

            execute immediate 'alter session set "_fix_control"=''5909305:OFF''' ; --1.1
      end;

      -- Verify if is a record re-processing
      IF L_FILE_NAME IS NOT NULL AND P_REC_STATUS != 'ERR'
      THEN
         BEGIN
            L_ORG_ID := P_ORG_ID;
            L_STATUS_CODE := 'NEW';
            L_USER_ID := P_USER_ID;
            L_LOGIN := P_LOGIN_ID;
            L_PROCESS_FLAG := 'N';
            L_FILE := UTL_FILE.FOPEN (P_PATH, L_FILE_NAME, 'R');

            -- Read file and insert into TTEC_HR_EMPLOYEE_BK_ACC_INT interface table
            WHILE NOT L_END_OF_FILE
            LOOP
               L_TO_INSERT := 'N';
               GET_NEXTLINE (L_FILE, L_LINE, L_END_OF_FILE);
               L_LINE_COUNTER := L_LINE_COUNTER + 1;

               IF P_SOURCE = 'REPORT'
               THEN
                  IF L_LINE_COUNTER > 19
                  THEN
                     L_EMP_NUMBER := SUBSTR (L_LINE, 3, 7);
                     L_EMP_ACCOUNT := SUBSTR (L_LINE, 118, 11);
                     L_STATUS := SUBSTR (L_LINE, 136, 9);

                     IF     L_STATUS = 'Procesado'
                        AND L_EMP_NUMBER IS NOT NULL
                        AND L_EMP_ACCOUNT IS NOT NULL
                     THEN
                        L_TO_INSERT := 'Y';
                     END IF;
                  END IF;
               ELSIF P_SOURCE = 'CSV'
               THEN
                  L_EMP_NUMBER := SUBSTR (L_LINE, 1, 7);
                  L_EMP_ACCOUNT := SUBSTR (L_LINE, 9, 11);

                  IF L_EMP_NUMBER IS NOT NULL AND L_EMP_ACCOUNT IS NOT NULL
                  THEN
                     L_TO_INSERT := 'Y';
                  END IF;
               END IF;

               IF L_TO_INSERT = 'Y'
               THEN
                  INSERT INTO TTEC_HR_EMPLOYEE_BK_ACC_INT
                              (EMP_BK_ACC_ID,
                               EMPLOYEE_NUMBER, ACCOUNT_NUMBER, ORG_ID,
                               STATUS_CODE, PROCESS_FLAG, LAST_UPDATE_DATE,
                               LAST_UPDATED_BY, LAST_UPDATE_LOGIN,
                               CREATION_DATE, CREATED_BY
                              )
                       VALUES (TTEC_HR_EMP_BK_ACC_INT_SEQ.NEXTVAL,
                               L_EMP_NUMBER, L_EMP_ACCOUNT, L_ORG_ID,
                               L_STATUS_CODE, L_PROCESS_FLAG, SYSDATE,
                               L_USER_ID, L_LOGIN,
                               SYSDATE, L_USER_ID
                              );

                  -- If insert into interface table count like a record read
                  IF SQL%ROWCOUNT > 0
                  THEN
                     L_RECORD_READ := L_RECORD_READ + 1;
                  END IF;
               END IF;
            END LOOP;

            COMMIT;
            UTL_FILE.FCLOSE (L_FILE);
         EXCEPTION
            WHEN NO_DATA_FOUND
            THEN
               UTL_FILE.FCLOSE (L_FILE);
               TTEC_ERROR_LOGGING.PROCESS_ERROR
                                        (G_APPLICATION_CODE,
                                         G_INTERFACE,
                                         G_PACKAGE,
                                         L_MODULE,
                                         G_ERROR_STATUS,
                                         SQLCODE,
                                         'File without data, please verify ',
                                         'SOURCE',
                                         P_SOURCE,
                                         'FILE_PATH',
                                         'TTEC_TEST_DIR',
                                         'FILE_NAME',
                                         L_FILE_NAME
                                        );
               FND_FILE.PUT_LINE (FND_FILE.LOG,
                                     '** Error in Module: '
                                  || L_MODULE
                                  || ' - '
                                  || SQLCODE
                                  || ' - '
                                  || 'File without data, please verify'
                                 );
            WHEN UTL_FILE.INVALID_PATH
            THEN
               IF UTL_FILE.IS_OPEN (L_FILE)
               THEN
                  UTL_FILE.FCLOSE (L_FILE);
               END IF;

               TTEC_ERROR_LOGGING.PROCESS_ERROR
                                 (G_APPLICATION_CODE,
                                  G_INTERFACE,
                                  G_PACKAGE,
                                  L_MODULE,
                                  G_ERROR_STATUS,
                                  SQLCODE,
                                  'Invalid path, please try another directory'
                                 );
               FND_FILE.PUT_LINE (FND_FILE.LOG,
                                     '** Error in Module: '
                                  || L_MODULE
                                  || ' - '
                                  || SQLCODE
                                  || ' - '
                                  || 'Invalid path, please try another directory'
                                 );
            WHEN OTHERS
            THEN
               TTEC_ERROR_LOGGING.PROCESS_ERROR (G_APPLICATION_CODE,
                                                 G_INTERFACE,
                                                 G_PACKAGE,
                                                 L_MODULE,
                                                 G_ERROR_STATUS,
                                                 SQLCODE,
                                                 SQLERRM
                                                );
               FND_FILE.PUT_LINE (FND_FILE.LOG,
                                     '** Error in Module: '
                                  || L_MODULE
                                  || ' - '
                                  || SQLCODE
                                  || ' - '
                                  || SQLERRM
                                 );
         END;
      END IF;

-- Create employee payment method with the API
      BEGIN
         FOR R_EMP_BANK_ACC IN C_EMP_BANK_ACC
         LOOP
            L_EMPLOYEE_NUMBER := R_EMP_BANK_ACC.EMPLOYEE_NUMBER;
            L_EMPLOYEE_BK_ACC := R_EMP_BANK_ACC.ACCOUNT_NUMBER;
            L_EMP_BK_ACC_ID := R_EMP_BANK_ACC.EMP_BK_ACC_ID;
            L_ERROR_GEA := FALSE;
            L_ERROR_GOP := FALSE;
            -- Get an employee primary assignment, payroll type and bank branch
            GET_EMP_ASSIGNMENT (L_EMPLOYEE_NUMBER,
                                L_ASSIGNMENT_ID,
                                P_EFFECTIVE_DATE,
                                L_PAYROLL_NAME,
                                L_BANK_BRANCH,
                                L_ERROR_GEA
                               );

            -- Define a Organizational payment method name according to the Employee Payroll Type
            IF L_PAYROLL_NAME = 'MX_SSI_Payroll'
            THEN
               L_ORG_PAY_MET_NAME := 'Deposit SSI';
            ELSIF L_PAYROLL_NAME = 'MX_SAB_Payroll'
            THEN
               L_ORG_PAY_MET_NAME := 'Deposit SAB';
            ELSIF L_PAYROLL_NAME = 'MX Percepta Payroll'--added as part of 1.2
            THEN
               L_ORG_PAY_MET_NAME := 'Deposit PCTA';--end of 1.2
            ELSE
               L_ORG_PAY_MET_NAME := NULL;
            END IF;

            -- Verify the error status of GET_EMP_ASSIGNMENT procedure
            IF NOT L_ERROR_GEA
            THEN
               -- Get an Organizational payment method ID , Territory code, Bank Name and Account type
               GET_ORG_PAY_METHOD (L_EMPLOYEE_NUMBER,
                                   L_ORG_PAY_MET_NAME,
                                   L_ORG_PAY_MET_ID,
                                   L_TERRITORY,
                                   L_BANK_NAME,
                                   L_ACCOUNT_TYPE,
                                   L_ERROR_GOP
                                  );

               -- Verify the error status of GET_ORG_PAY_METHOD procedure
               IF NOT L_ERROR_GOP
               THEN
                  --  Create an Employee Payment Method
                  CREATE_EMP_BANK_ACCOUNT (L_EMPLOYEE_NUMBER,
                                           L_ASSIGNMENT_ID,
                                           P_EFFECTIVE_DATE,
                                           L_ORG_PAY_MET_ID,
                                           L_TERRITORY,
                                           L_BANK_NAME,
                                           L_BANK_BRANCH,
                                           L_EMPLOYEE_BK_ACC,
                                           L_ACCOUNT_TYPE,
                                           L_EMPLOYEE_BK_ACC,
                                           L_STATUS
                                          );
               END IF;
            END IF;

            -- Get Global process Status
            IF L_STATUS = 'ERR'
            THEN
               G_GLOBAL_STATUS := 'ERR';

               --Update Employee account record
               UPDATE TTEC_HR_EMPLOYEE_BK_ACC_INT
                  SET STATUS_CODE = 'ERR',
                      PROCESS_FLAG = 'Y',
                      LAST_UPDATE_DATE = SYSDATE,
                      LAST_UPDATED_BY = L_USER_ID
                WHERE EMP_BK_ACC_ID = L_EMP_BK_ACC_ID;
            ELSIF L_STATUS = 'UPD'
            THEN
               IF G_GLOBAL_STATUS = 'UNV'
               THEN
                  G_GLOBAL_STATUS := 'UPD';
               END IF;

               --Update Employee account record
               UPDATE TTEC_HR_EMPLOYEE_BK_ACC_INT
                  SET STATUS_CODE = 'PRC',
                      PROCESS_FLAG = 'Y',
                      LAST_UPDATE_DATE = SYSDATE,
                      LAST_UPDATED_BY = L_USER_ID
                WHERE EMP_BK_ACC_ID = L_EMP_BK_ACC_ID;
            END IF;
         END LOOP;

         -- Define a process status
         IF G_GLOBAL_STATUS = 'UNV'
         THEN
            L_PROCESS_STATUS := 'Unavailable';
         ELSIF G_GLOBAL_STATUS = 'UPD'
         THEN
            L_PROCESS_STATUS := 'Validated and Updated';
         ELSIF G_GLOBAL_STATUS = 'ERR'
         THEN
            L_PROCESS_STATUS :=
               'Validated with ERRORS, please see a LOG for detailed information.';
         END IF;

         FND_FILE.PUT_LINE (FND_FILE.OUTPUT,
                               'Input source file type:  '
                            || L_SOURCE
                            || CHR (10)
                            || CHR (10)
                            || 'Total Record read:       '
                            || L_RECORD_READ
                            || CHR (10)
                            || CHR (10)
                            || 'Total Record processed:  '
                            || G_RECORD_PROCESSED
                            || CHR (10)
                            || CHR (10)
                            || 'Process Status: '
                            || L_PROCESS_STATUS
                           );
      EXCEPTION
         WHEN OTHERS
         THEN
            TTEC_ERROR_LOGGING.PROCESS_ERROR (G_APPLICATION_CODE,
                                              G_INTERFACE,
                                              G_PACKAGE,
                                              L_MODULE,
                                              G_ERROR_STATUS,
                                              SQLCODE,
                                              SQLERRM
                                             );
            FND_FILE.PUT_LINE (FND_FILE.LOG,
                                  '** Error in Module: '
                               || L_MODULE
                               || ' - '
                               || SQLCODE
                               || ' - '
                               || SQLERRM
                              );
      END;
   END MAIN;

-- +=================================================================+
-- | PROCEDURE                                                       |
-- |   CREATE_EMP_BANK_ACCOUNT                                       |
-- +=================================================================+
-- |                                                                 |
-- | PURPOSE                                                         |
-- |     Insert the new employee bank account in the current active  |
-- |     employee assignment                                         |
-- |                                                                 |
-- | CREATED BY                                                      |
-- |   23-SEP-2010 Sergio Morra                                      |
-- |                                                                 |
-- | HISTORY                                                         |
-- |                                                                 |
-- +=================================================================+

   PROCEDURE CREATE_EMP_BANK_ACCOUNT (
      P_EMPLOYEE_NUMBER         IN       VARCHAR2,
      P_ASSIGNMENT_ID           IN       NUMBER,
      P_EFFECTIVE_DATE IN  DATE,
      P_ORG_PAYMENT_METHOD_ID   IN       NUMBER,
      P_TERRITORY_CODE          IN       VARCHAR2,
      P_BANK_NAME               IN       VARCHAR2,
      P_BRANCH                  IN       VARCHAR2,
      P_EMP_BK_ACCOUNT          IN       VARCHAR2,
      P_ACCOUNT_TYPE            IN       VARCHAR2,
      P_CLABE                   IN       VARCHAR2,
      P_STATUS                  OUT      VARCHAR2
   )
   IS
      L_VALIDATE                     BOOLEAN;
      L_EFFECTIVE_DATE               DATE;
      L_ASSIGNMENT_ID                NUMBER;
      L_ORG_PAYMENT_METHOD_ID        NUMBER;
      L_PERCENTAGE                   NUMBER;
      L_PRIORITY                     NUMBER;
      L_TERRITORY_CODE               VARCHAR2 (200);
      L_SEGMENT1                     VARCHAR2 (200);
      L_SEGMENT2                     VARCHAR2 (200);
      L_SEGMENT3                     VARCHAR2 (200);
      L_SEGMENT4                     VARCHAR2 (200);
      L_SEGMENT5                     VARCHAR2 (200);
      L_PAYEE_ID                     NUMBER;
      L_PERSONAL_PAYMENT_METHOD_ID   NUMBER;
      L_EXTERNAL_ACCOUNT_ID          NUMBER;
      L_OBJECT_VERSION_NUMBER        NUMBER;
      L_EFFECTIVE_START_DATE         DATE;
      L_EFFECTIVE_END_DATE           DATE;
      L_COMMENT_ID                   NUMBER;
      -- Exception Variables
      L_MODULE                       TTEC_ERROR_HANDLING.MODULE_NAME%TYPE
                                    := 'Create a new Employee payment method';
      L_EMPLOYEE_NUMBER              NUMBER              := P_EMPLOYEE_NUMBER;
   -- API Santander Employee Account Process
   BEGIN
      L_Validate := False;
      L_EFFECTIVE_DATE := TO_DATE(TO_CHAR(P_EFFECTIVE_DATE,'DD-MON-YYYY'));
      L_ASSIGNMENT_ID := P_ASSIGNMENT_ID;
      L_ORG_PAYMENT_METHOD_ID := P_ORG_PAYMENT_METHOD_ID;
      L_PERCENTAGE := 100;
      L_PRIORITY := 1;
      L_TERRITORY_CODE := P_TERRITORY_CODE;
      L_SEGMENT1 := P_BANK_NAME;
      L_SEGMENT2 := P_BRANCH;
      L_SEGMENT3 := P_EMP_BK_ACCOUNT;
      L_SEGMENT4 := P_ACCOUNT_TYPE;
      L_SEGMENT5 := P_CLABE;
      L_PERSONAL_PAYMENT_METHOD_ID := NULL;
      L_EXTERNAL_ACCOUNT_ID := NULL;
      L_OBJECT_VERSION_NUMBER := NULL;
      L_EFFECTIVE_START_DATE := NULL;
      L_EFFECTIVE_END_DATE := NULL;
      L_COMMENT_ID := NULL;



      APPS.HR_PERSONAL_PAY_METHOD_API.CREATE_PERSONAL_PAY_METHOD
                                               (    P_VALIDATE                       => L_VALIDATE,
                                                    P_EFFECTIVE_DATE                 => L_EFFECTIVE_DATE,
                                    P_ASSIGNMENT_ID                  => L_ASSIGNMENT_ID,
                                                    P_ORG_PAYMENT_METHOD_ID          => L_ORG_PAYMENT_METHOD_ID,
                                                    P_PERCENTAGE                  => L_PERCENTAGE,
                                      P_PRIORITY                 => L_PRIORITY,
                                    P_TERRITORY_CODE             => L_TERRITORY_CODE,
                                    P_SEGMENT1                 => L_SEGMENT1,
                                    P_SEGMENT2                => L_SEGMENT2,
                                      P_SEGMENT3                => L_SEGMENT3,
                                    P_SEGMENT4                => L_SEGMENT4,
                                    P_SEGMENT5                  => L_SEGMENT5,
                                      P_PERSONAL_PAYMENT_METHOD_ID    => L_PERSONAL_PAYMENT_METHOD_ID,
                                    P_EXTERNAL_ACCOUNT_ID        => L_EXTERNAL_ACCOUNT_ID,
                                    P_OBJECT_VERSION_NUMBER        => L_OBJECT_VERSION_NUMBER,
                                    P_EFFECTIVE_START_DATE        => L_EFFECTIVE_START_DATE,
                                         P_EFFECTIVE_END_DATE            => L_EFFECTIVE_END_DATE,
                                    P_COMMENT_ID                => L_COMMENT_ID
                                               );

      -- Record procees counter when Api not have any exception error
      G_RECORD_PROCESSED := G_RECORD_PROCESSED + 1;
      P_STATUS := 'UPD';
   EXCEPTION
      WHEN OTHERS
      THEN
         TTEC_ERROR_LOGGING.PROCESS_ERROR (G_APPLICATION_CODE,
                                           G_INTERFACE,
                                           G_PACKAGE,
                                           L_MODULE,
                                           G_ERROR_STATUS,
                                           SQLCODE,
                                           SQLERRM,
                                           'EMPLOYEE_NUMBER',
                                           L_EMPLOYEE_NUMBER,
                                           'ASSIGNMENT_ID',
                                           L_ASSIGNMENT_ID,
                                           'ORG_PAYMENT_METHOD_ID',
                                           L_ORG_PAYMENT_METHOD_ID,
                                           'TERRITORY_CODE',
                                           L_TERRITORY_CODE,
                                           'BANK_NAME',
                                           L_SEGMENT1,
                                           'BRANCH',
                                           L_SEGMENT2,
                                           'EMPLOYEE_BANK_ACCOUNT',
                                           L_SEGMENT3,
                                           'ACCOUNT_TYPE',
                                           L_SEGMENT4,
                                           'CLABE',
                                           L_SEGMENT5
                                          );
         FND_FILE.PUT_LINE (FND_FILE.LOG,
                               '** Error in Module: '
                            || L_MODULE
                            || ' - '
                            || 'EMPLOYEE_NUMBER: '
                            || L_EMPLOYEE_NUMBER
                            || ' '
                            || SQLCODE
                            || ' - '
                            || SQLERRM
                           );
         G_RECORD_ERROR := G_RECORD_ERROR + 1;
         P_STATUS := 'ERR';
   END CREATE_EMP_BANK_ACCOUNT;

-- +=================================================================+
-- | FUNCTION                                                        |
-- |   GET_EMP_ASSIGNMENT                                            |
-- +=================================================================+
-- |                                                                 |
-- | PURPOSE                                                         |
-- |     Get the employee Primary Assignment ID  and Payroll Name    |
-- |                                                                 |
-- |                                                                 |
-- | CREATED BY                                                      |
-- |   23-SEP-2010 Sergio Morra                                      |
-- |                                                                 |
-- | HISTORY                                                         |
-- |                                                                 |
-- +=================================================================+

   PROCEDURE GET_EMP_ASSIGNMENT (
      P_EMPLOYEE_NUMBER   IN       VARCHAR2,
      P_ASSIGNMENT_ID     OUT      VARCHAR2,
      P_EFFECTIVE_DATE IN  DATE,
      P_PAYROLL_NAME      OUT      VARCHAR2,
      P_BANK_BRANCH       OUT      VARCHAR2,
      P_ERROR             OUT      BOOLEAN
   )
   IS
      L_ASSIGNMENT_ID   PER_ALL_ASSIGNMENTS_F.ASSIGNMENT_ID%TYPE;
      L_PAYROLL_NAME    PAY_ALL_PAYROLLS_F.PAYROLL_NAME%TYPE;
      L_LOCATION_CODE   HR_LOCATIONS_ALL.LOCATION_CODE%TYPE;
      L_BANK_BRANCH     FND_LOOKUP_VALUES.LOOKUP_CODE%TYPE;
      L_MODULE          TTEC_ERROR_HANDLING.MODULE_NAME%TYPE
                                                 := 'Get Employee Assignment';
      L_ERROR           BOOLEAN                                    := FALSE;
   BEGIN
      SELECT DISTINCT PAA.ASSIGNMENT_ID, PAP.PAYROLL_NAME, HLA.LOCATION_CODE
                 INTO L_ASSIGNMENT_ID, L_PAYROLL_NAME, L_LOCATION_CODE
                 FROM PAY_ALL_PAYROLLS_F PAP,
                      PER_ALL_ASSIGNMENTS_F PAA,
                      PER_ALL_PEOPLE_F PEO,
                      HR_LOCATIONS_ALL HLA
                WHERE PAP.PAYROLL_ID = PAA.PAYROLL_ID
                  AND PAA.PERSON_ID = PEO.PERSON_ID
                  AND HLA.LOCATION_ID = PAA.LOCATION_ID
                  AND PEO.EMPLOYEE_NUMBER = P_EMPLOYEE_NUMBER
                  AND P_EFFECTIVE_DATE BETWEEN PAP.EFFECTIVE_START_DATE
                                         AND NVL(PAP.EFFECTIVE_END_DATE, trunc(SYSDATE))
                  AND P_EFFECTIVE_DATE BETWEEN PAA.EFFECTIVE_START_DATE
                                         AND NVL(PAA.EFFECTIVE_END_DATE, trunc(SYSDATE))
                  AND PAA.PRIMARY_FLAG = 'Y';

/*
      SELECT SUBSTR (LOOKUP_CODE, 1, 4)
        INTO L_BANK_BRANCH
        FROM FND_LOOKUP_VALUES
       WHERE LOOKUP_TYPE = 'TTEC_MEX_SANTANDER'
         AND LANGUAGE = USERENV ('LANG')
         AND MEANING = L_LOCATION_CODE; */


         SELECT SUBSTR (TAG, 1, 4)
        INTO L_BANK_BRANCH
        FROM FND_LOOKUP_VALUES
       WHERE LOOKUP_TYPE = 'TTEC_MEX_SANTANDER_NEW'
         AND LANGUAGE = USERENV ('LANG')
         AND MEANING = L_LOCATION_CODE;


      P_ASSIGNMENT_ID := L_ASSIGNMENT_ID;
      P_PAYROLL_NAME := L_PAYROLL_NAME;
      P_BANK_BRANCH := L_BANK_BRANCH;
      P_ERROR := L_ERROR;
   EXCEPTION
      WHEN NO_DATA_FOUND
      THEN
         TTEC_ERROR_LOGGING.PROCESS_ERROR
                                    (G_APPLICATION_CODE,
                                     G_INTERFACE,
                                     G_PACKAGE,
                                     L_MODULE,
                                     G_ERROR_STATUS,
                                     SQLCODE,
                                     'Unable to get the Employee assignment',
                                     'EMPLOYEE_NUMBER',
                                     P_EMPLOYEE_NUMBER
                                    );
         FND_FILE.PUT_LINE (FND_FILE.LOG,
                               '** Error in Module: '
                            || L_MODULE
                            || ' - '
                            || SQLCODE
                            || ' - Unable to get the Employee assignment'
                            || ' - EMPLOYEE_NUMBER: '
                            || P_EMPLOYEE_NUMBER
                           );
         P_ASSIGNMENT_ID := NULL;
         P_PAYROLL_NAME := NULL;
         P_BANK_BRANCH := NULL;
         P_ERROR := TRUE;
      WHEN OTHERS
      THEN
         TTEC_ERROR_LOGGING.PROCESS_ERROR (G_APPLICATION_CODE,
                                           G_INTERFACE,
                                           G_PACKAGE,
                                           L_MODULE,
                                           G_ERROR_STATUS,
                                           SQLCODE,
                                           SQLERRM
                                          );
         FND_FILE.PUT_LINE (FND_FILE.LOG,
                               '** Error in Module: '
                            || L_MODULE
                            || ' - '
                            || SQLCODE
                            || ' - '
                            || SQLERRM
                           );
         P_ASSIGNMENT_ID := NULL;
         P_PAYROLL_NAME := NULL;
         P_BANK_BRANCH := NULL;
         P_ERROR := TRUE;
   END GET_EMP_ASSIGNMENT;

-- +=================================================================+
-- |  PROCEDURE                                                      |
-- |   GET_ORG_PAY_METHOD                                            |
-- +=================================================================+
-- |                                                                 |
-- | PURPOSE                                                         |
-- |     Get the Organization Payment Method ID, Territory Code,     |
-- |     Bank Name, Account Type and Bank Branch                     |
-- |                                                                 |
-- | CREATED BY                                                      |
-- |   23-SEP-2010 Sergio Morra                                      |
-- |                                                                 |
-- | HISTORY                                                         |
-- |                                                                 |
-- +=================================================================+

   PROCEDURE GET_ORG_PAY_METHOD (
      P_EMPLOYEE_NUMBER   IN       VARCHAR2,
      P_PAY_METHOD_NAME   IN       VARCHAR2,
      P_ORG_PAY_METHOD    OUT      VARCHAR2,
      P_TERRITORY_CODE    OUT      VARCHAR2,
      P_BANK_NAME         OUT      VARCHAR2,
      P_ACCOUNT_TYPE      OUT      VARCHAR2,
      P_ERROR             OUT      BOOLEAN
   )
   IS
      L_ORG_PAY_METHOD_ID   PAY_ORG_PAYMENT_METHODS_F.ORG_PAYMENT_METHOD_ID%TYPE;
      L_TERRITORY_CODE      PAY_EXTERNAL_ACCOUNTS.TERRITORY_CODE%TYPE;
      L_BANK_NAME           PAY_EXTERNAL_ACCOUNTS.SEGMENT1%TYPE;
      L_ACCOUNT_TYPE        PAY_EXTERNAL_ACCOUNTS.SEGMENT4%TYPE;
      L_MODULE              TTEC_ERROR_HANDLING.MODULE_NAME%TYPE
                                                      := 'Get Payment Method';
      L_ERROR               BOOLEAN                                  := FALSE;
   BEGIN
      SELECT POP.ORG_PAYMENT_METHOD_ID, PEA.TERRITORY_CODE TERRITORY_CODE,
             PEA.SEGMENT1 BANK_NAME, PEA.SEGMENT4 ACCOUNT_TYPE
        INTO L_ORG_PAY_METHOD_ID, L_TERRITORY_CODE,
             L_BANK_NAME, L_ACCOUNT_TYPE
        FROM PAY_ORG_PAYMENT_METHODS_F POP, PAY_EXTERNAL_ACCOUNTS PEA
       WHERE POP.EXTERNAL_ACCOUNT_ID = PEA.EXTERNAL_ACCOUNT_ID
         AND POP.CURRENCY_CODE = 'MXN'
         AND POP.ORG_PAYMENT_METHOD_NAME = P_PAY_METHOD_NAME
         AND trunc(SYSDATE) BETWEEN POP.EFFECTIVE_START_DATE AND POP.EFFECTIVE_END_DATE;--INC10580943


      P_ORG_PAY_METHOD := TO_CHAR (L_ORG_PAY_METHOD_ID);
      P_TERRITORY_CODE := 'MX';
      P_BANK_NAME := 'SANTANDER';
      P_ACCOUNT_TYPE := 'DEBIT';
      P_ERROR := L_ERROR;
--      P_TERRITORY_CODE := L_TERRITORY_CODE; -- for future use, if territory change
--      P_BANK_NAME := L_BANK_NAME; -- for future use, if org bank change
--      P_ACCOUNT_TYPE := L_ACCOUNT_TYPE; -- for future use, if account type change
   EXCEPTION
      WHEN NO_DATA_FOUND
      THEN
         TTEC_ERROR_LOGGING.PROCESS_ERROR
                                      (G_APPLICATION_CODE,
                                       G_INTERFACE,
                                       G_PACKAGE,
                                       L_MODULE,
                                       G_ERROR_STATUS,
                                       SQLCODE,
                                       'Unable to get Org Payment Method ID',
                                       'EMPLOYEE_NUMBER',
                                       P_EMPLOYEE_NUMBER,
                                       'PAY_METHOD_NAME',
                                       P_PAY_METHOD_NAME
                                      );
         FND_FILE.PUT_LINE (FND_FILE.LOG,
                               '** Error in Module: '
                            || L_MODULE
                            || ' - '
                            || SQLCODE
                            || ' - Unable to get Org Payment Method ID'
                            || ' - EMPLOYEE_NUMBER: '
                            || P_EMPLOYEE_NUMBER
                            || ' - PAY_METHOD_NAME: '
                            || P_PAY_METHOD_NAME
                           );
         P_ORG_PAY_METHOD := NULL;
         P_TERRITORY_CODE := NULL;
         P_BANK_NAME := NULL;
         P_ACCOUNT_TYPE := NULL;
         P_ERROR := TRUE;
      WHEN OTHERS
      THEN
         TTEC_ERROR_LOGGING.PROCESS_ERROR (G_APPLICATION_CODE,
                                           G_INTERFACE,
                                           G_PACKAGE,
                                           L_MODULE,
                                           G_ERROR_STATUS,
                                           SQLCODE,
                                           SQLERRM
                                          );
         FND_FILE.PUT_LINE (FND_FILE.LOG,
                               '** Error in Module: '
                            || L_MODULE
                            || ' - '
                            || SQLCODE
                            || ' - '
                            || SQLERRM
                           );
         P_ORG_PAY_METHOD := NULL;
         P_TERRITORY_CODE := NULL;
         P_BANK_NAME := NULL;
         P_ACCOUNT_TYPE := NULL;
         P_ERROR := TRUE;
   END GET_ORG_PAY_METHOD;

-- +=================================================================+
-- |  PROCEDURE                                                      |
-- |   GET_NEXTLINE                                                  |
-- +=================================================================+
-- |                                                                 |
-- | PURPOSE                                                         |
-- |     Get the next line of file and inform the end of file (eof)  |
-- |                                                                 |
-- |                                                                 |
-- | CREATED BY                                                      |
-- |   23-SEP-2010 Sergio Morra                                      |
-- |                                                                 |
-- | HISTORY                                                         |
-- |                                                                 |
-- +=================================================================+

   PROCEDURE GET_NEXTLINE (
      P_FILE_IN    IN       UTL_FILE.FILE_TYPE,
      P_LINE_OUT   OUT      VARCHAR2,
      P_EOF_OUT    OUT      BOOLEAN
   )
   IS
      L_MODULE   TTEC_ERROR_HANDLING.MODULE_NAME%TYPE
                                               := 'Get the next line of file';
   BEGIN
      UTL_FILE.GET_LINE (P_FILE_IN, P_LINE_OUT);
      P_EOF_OUT := FALSE;
   EXCEPTION
      WHEN NO_DATA_FOUND
      THEN
         P_LINE_OUT := NULL;
         P_EOF_OUT := TRUE;
      WHEN OTHERS
      THEN
         TTEC_ERROR_LOGGING.PROCESS_ERROR (G_APPLICATION_CODE,
                                           G_INTERFACE,
                                           G_PACKAGE,
                                           L_MODULE,
                                           G_ERROR_STATUS,
                                           SQLCODE,
                                           SQLERRM
                                          );
         FND_FILE.PUT_LINE (FND_FILE.LOG,
                               '** Error in Module: '
                            || L_MODULE
                            || ' - '
                            || SQLCODE
                            || ' - '
                            || SQLERRM
                           );
         P_LINE_OUT := NULL;
         P_EOF_OUT := TRUE;
   END GET_NEXTLINE;
END TTEC_HR_UPL_EMP_SANT_ACC_PK;
/
show errors;
/