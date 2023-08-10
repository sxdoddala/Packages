create or replace PACKAGE BODY      TTEC_US_VAC_BAL_ACTIVE
AS
/* $Header: ttec_us_vac_bal_active1 .Date unknown   */

   /*== START =================================================================*\
       Author:

         Date:
         Desc:  This package is intended to be ran to determine vacation balance for employees

       Modification History:

       Mod#  Date        Author      Description (Include Ticket#)
      -----  ----------  ----------  --------------------------------------------
        1.1  6/0/2010   Wasim Manasfi   June 2007
        v1.1 11/3/2010  Wasim Manasfi
        v1.2 12/4/2015  Manuel Larsen   2016 PTO Project
        v1.3 13/12/2019 Hari Varma      Added outer join to show costing details
		v1.4 22/01/2020 Hari Varma      Added State Column
		v1.0 17-MAY-2023 RXNETHI-ARGANO  R12.2 Upgrade Remediation
   \*== END ===================================================================*/
   PROCEDURE WRITE_FILE (
      ERRCODE            VARCHAR2,
      ERRBUFF            VARCHAR2,
      P_END_MONTH   IN   DATE
   )
   IS
--  Program to write run vacation  "US Monthly Vacation Balance - Active Employees"
--    Wasim Manasfi   June 2007

      -- requirement of file on disk was withdrawn, just commented it out
--
-- Filehandle Variables
      P_FILEDIR         VARCHAR2 (200);
      P_FILENAME        VARCHAR2 (50);
      P_COUNTRY         VARCHAR2 (10);
      V_BANK_FILE       UTL_FILE.FILE_TYPE;
-- Declare variables
      L_MSG             VARCHAR2 (2000);
      L_STAGE           VARCHAR2 (400);
      L_ELEMENT         VARCHAR2 (400);
      L_REC             VARCHAR2 (600);
      L_KEY             VARCHAR2 (400);
      L_TITLE           VARCHAR2 (200)
         := 'US Monthly Vacation Balance - Active Employees - Pay Period End Date: ';
      L_ENDOFMONTH      DATE;
      L_TOT_REC_COUNT   NUMBER;
      L_SEQ             NUMBER;
      L_FILE_SEQ        NUMBER;
      L_NEXT_FILE_SEQ   NUMBER;
      L_TEST_FLAG       VARCHAR2 (4);
      L_PROGRAM         AP_CARD_PROGRAMS_ALL.CARD_PROGRAM_NAME%TYPE;
      L_RATE            NUMBER;
      L_ACCRUAL_CATEGORY VARCHAR(100);

-- set directory destination for output file
--      CURSOR C_DIRECTORY_PATH
--      IS
--         SELECT    '/d21/oradev2/dev2appl/teletech/11.5.0/data/BenefitInterface/'
--                                                              DIRECTORY_PATH,
--                   'TTEC_'
--                || 'US'
--                || '_Terminated_Vac'
--                || TO_CHAR (SYSDATE, '_MMDDYYYY')
--                || '.out' FILE_NAME
--           FROM V$DATABASE;

-- get requireed info for transmission
      CURSOR C_DETAIL_RECORD_OP4
      IS
         /*       Report Name: Finance Report US - Active Employees          *
                               *        Created By: Hern?Albanesi                                    *
                               *          Created date: 16-May-2007                                    *
                               *          Updated By:                                                 *
                               *          Updated Date:                                                *
                               */
         SELECT    "Business Group"
                || '|'
                || "Employee Number"
                || '|'
                || "Employee Full Name"
                || '|'
                || TO_CHAR ("Hire Date", 'DD-MON-YYYY')
                || '|'
                || "Location Code"
                || '|'
                || "Location"
                || '|'
                || "Proportion"
                || '|'
                || "Location Override"
                || '|'
                || "Client"
                || '|'
                || "Department"
                || '|'
                || "Department Override"
                || '|'
                || "Assignment Number"
                || '|'
                || "Assignment Status"
                || '|'
                || "Employment Category" A_OUT,
                "Payrate", "Salary Basis", "Vacation Hours",
                ROUND ("Payrate" * "Vacation Hours" * NVL ("Proportion", 1),
                       2
                      ) "Vacation Dollars",

                -- v1.1      "Rate",
                "Assignment_id",                                      -- v1.1
                                "JOB", "End Of Month"
								, "State"              --v1.4
           FROM (SELECT DISTINCT 'US' "Business Group",
                                 PAPF.EMPLOYEE_NUMBER "Employee Number",
                                 PAPF.FULL_NAME "Employee Full Name",
                                 PPOS.DATE_START "Hire Date",
                                 LOC.LOCATION_CODE "Location Code",
                                 LOC.ATTRIBUTE2 "Location",
                                 ALLOC.PROPORTION "Proportion",
                                 ASG_COST.SEGMENT1 "Location Override",
                                 ASG_COST.SEGMENT2 "Client",
                                 I_ORG.SEGMENT3 "Department",
                                 ASG_COST.SEGMENT3 "Department Override",
                                 PAAF.ASSIGNMENT_NUMBER "Assignment Number",
                                 PAST.USER_STATUS "Assignment Status",
                                 FND_ASG_CAT.MEANING "Employment Category",
                                 ROUND
                                    (DECODE (PPB.PAY_BASIS,
                                             'ANNUAL', PPP.PROPOSED_SALARY_N
                                              / 2080,
                                             PPP.PROPOSED_SALARY_N
                                            ),
                                     2
                                    ) "Payrate",
                                 PPB.PAY_BASIS "Salary Basis",
                                 (SELECT PAI.ACTION_INFORMATION6
                                    FROM APPS.PAY_ACTION_INFORMATION PAI
                                   WHERE PAI.ASSIGNMENT_ID =
                                                            PAAF.ASSIGNMENT_ID
                                     AND PAI.ACTION_INFORMATION_CATEGORY =
                                                           'EMPLOYEE ACCRUALS'
                                     AND PAI.ACTION_INFORMATION4 = L_ACCRUAL_CATEGORY
                                     AND PAI.EFFECTIVE_DATE =
                                            (SELECT MAX (PAI2.EFFECTIVE_DATE)
                                               FROM APPS.PAY_ACTION_INFORMATION PAI2
                                              WHERE PAI2.ASSIGNMENT_ID =
                                                             PAI.ASSIGNMENT_ID
                                                AND PAI2.ACTION_INFORMATION_CATEGORY =
                                                           'EMPLOYEE ACCRUALS'
                                                AND PAI2.ACTION_INFORMATION4 =
                                                                         L_ACCRUAL_CATEGORY
                                                AND PAI2.EFFECTIVE_DATE <=
                                                                  L_ENDOFMONTH
                                                AND PAI.ACTION_CONTEXT_ID =
                                                       (SELECT MAX
                                                                  (PAI3.ACTION_CONTEXT_ID
                                                                  )
                                                          FROM APPS.PAY_ACTION_INFORMATION PAI3
                                                         WHERE PAI3.ASSIGNMENT_ID =
                                                                  PAI.ASSIGNMENT_ID
                                                           AND PAI3.ACTION_INFORMATION_CATEGORY =
                                                                  'EMPLOYEE ACCRUALS'
                                                           AND PAI3.ACTION_INFORMATION4 =
                                                                         L_ACCRUAL_CATEGORY
                                                           AND PAI3.EFFECTIVE_DATE <=
                                                                  L_ENDOFMONTH
                                                           AND PAI.ACTION_INFORMATION_ID =
                                                                  (SELECT MAX
                                                                             (PAI4.ACTION_INFORMATION_ID
                                                                             )
                                                                     --esta condici?n fue agregada porque la tabla ten?un registro duplicado
                                                                   FROM   APPS.PAY_ACTION_INFORMATION PAI4
                                                                    WHERE PAI4.ASSIGNMENT_ID =
                                                                             PAI.ASSIGNMENT_ID
                                                                      AND PAI4.ACTION_INFORMATION_CATEGORY =
                                                                             'EMPLOYEE ACCRUALS'
                                                                      AND PAI4.ACTION_INFORMATION4 =
                                                                             L_ACCRUAL_CATEGORY
                                                                      AND PAI4.EFFECTIVE_DATE <=
                                                                             L_ENDOFMONTH))))
                                                             "Vacation Hours",
                                 NULL "Vacation Dollars",
                                 L_ENDOFMONTH "End Of Month",
                                                             -- v1.1 ,
                                                             JOB.NAME "JOB",

                                 -- v1.1               (APPS.TTEC_Get_vacation_accrual_rate.ttec_get_accrual_rate(paaf.assignment_id, l_endofmonth)*80) "Rate"
                                 PAAF.ASSIGNMENT_ID "Assignment_id"
								 , decode ( paypf.payroll_name, 'At Home', pa.region_2, loc.region_2) "State"   --v1.4
                            FROM PER_ALL_PEOPLE_F PAPF,
                                 PER_ALL_ASSIGNMENTS_F PAAF,
                                 HR_LOCATIONS_ALL LOC,
                                 PER_JOBS JOB,
                                 PER_ASSIGNMENT_STATUS_TYPES PAST,
                                 PER_PAY_PROPOSALS PPP,
                                 PER_PAY_BASES PPB,
                                 PER_PERIODS_OF_SERVICE PPOS,
                                 --HR.PAY_COST_ALLOCATIONS_F ALLOC,  --Added to resolve TASK0687848
                                 --code commented by RXNETHI-ARGANO,17/05/23
								 APPS.PAY_COST_ALLOCATIONS_F ALLOC,  --Added to resolve TASK0687848
								 --code added by RXNETHI-ARGANO,17/05/23
                                 /*(SELECT   PCA1.ASSIGNMENT_ID,   --Comment to resolve TASK0687848
                                           PCA1.COST_ALLOCATION_KEYFLEX_ID
                                                   COST_ALLOCATION_KEYFLEX_ID,
                                           PROPORTION
                                      FROM HR.PAY_COST_ALLOCATIONS_F PCA1
                                     WHERE PCA1.EFFECTIVE_END_DATE =
                                              (SELECT MAX
                                                         (PCA2.EFFECTIVE_END_DATE
                                                         )
                                                 FROM HR.PAY_COST_ALLOCATIONS_F PCA2
                                                WHERE PCA2.ASSIGNMENT_ID =
                                                            PCA1.ASSIGNMENT_ID)
                                       AND L_ENDOFMONTH
                                              BETWEEN PCA1.EFFECTIVE_START_DATE
                                                  AND PCA1.EFFECTIVE_END_DATE
                                  GROUP BY PCA1.ASSIGNMENT_ID,
                                           PCA1.COST_ALLOCATION_KEYFLEX_ID,
                                           PROPORTION) ALLOC,*/     ----Comment to resolve TASK0687848
                                 /*
								 START R12.2 Upgrade Remediation
								 code commented by RXNETHI-ARGANO,17/05/23
								 HR.PAY_COST_ALLOCATION_KEYFLEX ASG_COST,
                                 HR_ORGANIZATION_UNITS ORG,
                                 HR.PAY_COST_ALLOCATION_KEYFLEX I_ORG,
                                 APPS.FND_LOOKUP_VALUES FND_ASG_CAT,
								 HR.PAY_ALL_PAYROLLS_F PAYPF,       --Added to resolve  TASK1286197
								 HR.PER_ADDRESSES PA                --Added to resolve  TASK1286197
								 */
								 --code added by RXNETHI-ARGANO,17/05/23
								 APPS.PAY_COST_ALLOCATION_KEYFLEX ASG_COST,
                                 HR_ORGANIZATION_UNITS ORG,
                                 APPS.PAY_COST_ALLOCATION_KEYFLEX I_ORG,
                                 APPS.FND_LOOKUP_VALUES FND_ASG_CAT,
								 APPS.PAY_ALL_PAYROLLS_F PAYPF,       --Added to resolve  TASK1286197
								 APPS.PER_ADDRESSES PA                --Added to resolve  TASK1286197
								 --END R12.2 Upgrade Remediation
                           WHERE PAPF.EFFECTIVE_END_DATE =
                                    (SELECT MAX (PAPF2.EFFECTIVE_END_DATE)
                                       FROM PER_ALL_PEOPLE_F PAPF2
                                      WHERE PAPF.PERSON_ID = PAPF2.PERSON_ID
                                        AND L_ENDOFMONTH
                                               BETWEEN PAPF2.EFFECTIVE_START_DATE
                                                   AND PAPF2.EFFECTIVE_END_DATE)
                             AND PAPF.PERSON_ID = PAAF.PERSON_ID
                             AND PAAF.EFFECTIVE_END_DATE =
                                    (SELECT MAX (PAAF_2.EFFECTIVE_END_DATE)
                                       FROM PER_ALL_ASSIGNMENTS_F PAAF_2
                                      WHERE PAAF_2.PERSON_ID = PAAF.PERSON_ID
                                        AND L_ENDOFMONTH
                                               BETWEEN PAAF_2.EFFECTIVE_START_DATE
                                                   AND PAAF_2.EFFECTIVE_END_DATE)
                             AND PAAF.LOCATION_ID = LOC.LOCATION_ID(+)
                             AND PAAF.JOB_ID = JOB.JOB_ID
                             AND PPP.ASSIGNMENT_ID(+) = PAAF.ASSIGNMENT_ID
                             AND PPP.CHANGE_DATE =
                                    (SELECT MAX (PPP2.CHANGE_DATE)
                                       FROM PER_PAY_PROPOSALS PPP2
                                      WHERE PPP2.ASSIGNMENT_ID =
                                                             PPP.ASSIGNMENT_ID
                                        AND PPP2.CHANGE_DATE <= L_ENDOFMONTH)
                             AND PPB.PAY_BASIS_ID(+) = PAAF.PAY_BASIS_ID
                             AND PAPF.PERSON_ID = PPOS.PERSON_ID
                             AND PAAF.PERIOD_OF_SERVICE_ID =
                                                     PPOS.PERIOD_OF_SERVICE_ID
                             AND ALLOC.ASSIGNMENT_ID(+) = PAAF.ASSIGNMENT_ID
                             AND ALLOC.COST_ALLOCATION_KEYFLEX_ID = ASG_COST.COST_ALLOCATION_KEYFLEX_ID(+)
                             AND L_ENDOFMONTH BETWEEN ALLOC.effective_start_date(+) and ALLOC.effective_end_date(+)  ----Added to resolve TASK0687848  v1.3
                             AND PAAF.ASSIGNMENT_STATUS_TYPE_ID = PAST.ASSIGNMENT_STATUS_TYPE_ID(+)
                             AND PAPF.BUSINESS_GROUP_ID = 325
                             AND PAPF.CURRENT_EMPLOYEE_FLAG = 'Y'
                             AND PAAF.ASSIGNMENT_STATUS_TYPE_ID = 1
                             AND PAAF.ORGANIZATION_ID = ORG.ORGANIZATION_ID(+)
							 AND PAYPF.PAYROLL_ID=PAAF.PAYROLL_ID
							 AND PAPF.PERSON_ID=PA.PERSON_ID
							 AND PA.PRIMARY_FLAG='Y'
							 AND L_ENDOFMONTH BETWEEN PAYPF.EFFECTIVE_START_DATE AND PAYPF.EFFECTIVE_END_DATE
							 AND L_ENDOFMONTH BETWEEN PA.DATE_FROM AND
                                         NVL(PA.DATE_TO, L_ENDOFMONTH)
                             AND I_ORG.COST_ALLOCATION_KEYFLEX_ID(+) =
                                                ORG.COST_ALLOCATION_KEYFLEX_ID
                             AND FND_ASG_CAT.LOOKUP_CODE(+) =
                                                      PAAF.EMPLOYMENT_CATEGORY
                             AND FND_ASG_CAT.LANGUAGE(+) = USERENV ('LANG')
                             AND FND_ASG_CAT.LOOKUP_TYPE(+) = 'EMP_CAT'
                             AND FND_ASG_CAT.SECURITY_GROUP_ID(+) =
                                    DECODE (PAAF.BUSINESS_GROUP_ID,
                                            325, 2,
                                            326, 3,
                                            1517, 22,
                                            1631, 23,
                                            1633, 25,
                                            2
                                           ));
   BEGIN
      L_STAGE := 'c_directory_path';
      L_ENDOFMONTH := TO_DATE (SYSDATE, 'DD-MON-YYYY');

      -- Fnd_File.put_line(Fnd_File.LOG, '1');
--      OPEN C_DIRECTORY_PATH;

--      FETCH C_DIRECTORY_PATH
--       INTO P_FILEDIR, P_FILENAME;

--      CLOSE C_DIRECTORY_PATH;

      -- Fnd_File.put_line(Fnd_File.LOG, '2');
      -- Fnd_File.put_line(Fnd_File.LOG, '3');
      L_STAGE := 'c_open_file';
    --  V_BANK_FILE := UTL_FILE.FOPEN (P_FILEDIR, P_FILENAME, 'w');
      FND_FILE.PUT_LINE (FND_FILE.LOG, '**********************************');
      -- fnd_file.put_line (fnd_file.LOG,
      --                       'Output file created >>> '
      --                    || p_filedir
      --                    || p_filename
      --                   );
      FND_FILE.PUT_LINE (FND_FILE.LOG, '**********************************');
      -- Fnd_File.put_line(Fnd_File.LOG, '4');

      --
      L_TOT_REC_COUNT := 0;
      L_ENDOFMONTH := P_END_MONTH;    -- TO_DATE (p_end_month, 'DD-MM-YYYY');
      -- Fnd_File.put_line(Fnd_File.LOG, '5');
      L_REC := L_TITLE || P_END_MONTH;
      APPS.FND_FILE.PUT_LINE (APPS.FND_FILE.OUTPUT, L_REC);
      L_REC :=
         'Business Group|Employee Number|Employee Full Name|Hire Date|Location Code|Location|Proportion|Location Override|Client|Department|Department Override|Assignment Number|Assignment Status|Employment Category|Payrate|Salary Basis|Vacation Hours|Vacation Dollars|Accrual Rate per Pay Period|Job|End Of Month|State';
      -- UTL_FILE.put_line (v_bank_file, l_rec);
      APPS.FND_FILE.PUT_LINE (APPS.FND_FILE.OUTPUT, L_REC);

      IF L_ENDOFMONTH >= '01-JAN-2016' THEN
        L_ACCRUAL_CATEGORY := 'Vacation';
      ELSE
        L_ACCRUAL_CATEGORY := 'PTO';
      END IF;

      FOR SEL IN C_DETAIL_RECORD_OP4
      LOOP
--         UTL_FILE.PUT_LINE (V_BANK_FILE,
--                               '----  Assignment ID '
--                            || TO_CHAR (SEL."Assignment_id")
--                           );
         L_STAGE :=
             'Getting accrual for Assignment' || TO_CHAR (SEL."Assignment_id");

         BEGIN
            L_RATE :=
               (  APPS.TTEC_GET_VACATION_ACCRUAL_RATE.TTEC_GET_ACCRUAL_RATE
                                                         (SEL."Assignment_id",
                                                          L_ENDOFMONTH
                                                         )
                * 80
               );
         EXCEPTION
            WHEN OTHERS
            THEN
               L_RATE := 0;
               APPS.FND_FILE.PUT_LINE (APPS.FND_FILE.log, 'Errored in getting rate for Assignment ' || TO_CHAR (SEL."Assignment_id") );
         END;

         L_REC :=
               SEL.A_OUT
            || '|'
            || TO_CHAR (SEL."Payrate")
            || '|'
            || SEL."Salary Basis"
            || '|'
            || TO_CHAR (SEL."Vacation Hours")
            || '|'
            || TO_CHAR (SEL."Vacation Dollars")
            --  || '|' || to_char(sel."Rate", '99.9999')   v1.1
            || '|'
            || TO_CHAR (L_RATE, '99.9999')
            || '|'
            || TO_CHAR (SEL."JOB")
            || '|'
            || SEL."End Of Month"
			|| '|'
			|| SEL."State";  --v1.4;
--         UTL_FILE.PUT_LINE (V_BANK_FILE, L_REC);
--         UTL_FILE.FFLUSH (V_BANK_FILE);
         APPS.FND_FILE.PUT_LINE (APPS.FND_FILE.OUTPUT, L_REC);
         L_TOT_REC_COUNT := L_TOT_REC_COUNT + 1;
      -- Fnd_File.put_line(Fnd_File.LOG, '8');
      END LOOP;                                                      /* pay */
-------------------------------------------------------------------------------------------------------------------------
      -- UTL_FILE.fclose (v_bank_file);
   -- Fnd_File.put_line(Fnd_File.LOG, '10');
   EXCEPTION
      WHEN UTL_FILE.INVALID_OPERATION
      THEN
         -- UTL_FILE.fclose (v_bank_file);
         RAISE_APPLICATION_ERROR (-20051,
                                  P_FILENAME || ':  Invalid Operation'
                                 );
         ROLLBACK;
      WHEN UTL_FILE.INVALID_FILEHANDLE
      THEN
         -- UTL_FILE.fclose (v_bank_file);
         RAISE_APPLICATION_ERROR (-20052,
                                  P_FILENAME || ':  Invalid File Handle'
                                 );
         ROLLBACK;
      WHEN UTL_FILE.READ_ERROR
      THEN
         -- UTL_FILE.fclose (v_bank_file);
         RAISE_APPLICATION_ERROR (-20053, P_FILENAME || ':  Read Error');
         ROLLBACK;
      WHEN UTL_FILE.INVALID_PATH
      THEN
         -- UTL_FILE.fclose (v_bank_file);
         RAISE_APPLICATION_ERROR (-20054, P_FILEDIR || ':  Invalid Path');
         ROLLBACK;
      WHEN UTL_FILE.INVALID_MODE
      THEN
         -- UTL_FILE.fclose (v_bank_file);
         RAISE_APPLICATION_ERROR (-20055, P_FILENAME || ':  Invalid Mode');
         ROLLBACK;
      WHEN UTL_FILE.WRITE_ERROR
      THEN
         -- UTL_FILE.fclose (v_bank_file);
         RAISE_APPLICATION_ERROR (-20056, P_FILENAME || ':  Write Error');
         ROLLBACK;
      WHEN UTL_FILE.INTERNAL_ERROR
      THEN
         -- UTL_FILE.fclose (v_bank_file);
         RAISE_APPLICATION_ERROR (-20057, P_FILENAME || ':  Internal Error');
         ROLLBACK;
      WHEN UTL_FILE.INVALID_MAXLINESIZE
      THEN
         -- UTL_FILE.fclose (v_bank_file);
         RAISE_APPLICATION_ERROR (-20058,
                                  P_FILENAME || ':  Maxlinesize Error'
                                 );
         ROLLBACK;
      WHEN OTHERS
      THEN
         -- UTL_FILE.fclose (v_bank_file);
         DBMS_OUTPUT.PUT_LINE ('Operation fails on ' || L_STAGE);
         L_MSG := SQLERRM;
         RAISE_APPLICATION_ERROR (-20003, 'Exception OTHER : ' || L_MSG);
         ROLLBACK;
   END WRITE_FILE;
END TTEC_US_VAC_BAL_ACTIVE;
/
show errors;
/