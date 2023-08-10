create or replace PACKAGE BODY      ttec_us_emp_state_of_res
AS
/* $Header: ttec_us_vac_bal_active1 .Date unknown   */

   /*== START =================================================================*\
       Author:

         Date:
         Desc:  This package is intended to be ran to determine vacation balance for employees

       Modification History:

       Mod#  Date        Author      Description (Include Ticket#)
      -----  ----------  ----------  --------------------------------------------
        1.1  24-Dec-2021  Neelofar   List of Employees with State of Residence
		1.0  15-May-2023  RXNETHI-ARGANO  R12.2 Upgrade Remediation
   \*== END ===================================================================*/
   PROCEDURE WRITE_FILE (
      ERRCODE            VARCHAR2,
      ERRBUFF            VARCHAR2,
      P_END_MONTH   IN   DATE
   )
   IS
--  Program to write List of Employees with State of Residence


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
         := 'List of Employees with State of Residence ';
      L_ENDOFMONTH      DATE;
      L_TOT_REC_COUNT   NUMBER;
      L_SEQ             NUMBER;
      L_FILE_SEQ        NUMBER;
      L_NEXT_FILE_SEQ   NUMBER;
      L_TEST_FLAG       VARCHAR2 (4);
      L_PROGRAM         AP_CARD_PROGRAMS_ALL.CARD_PROGRAM_NAME%TYPE;
      L_RATE            NUMBER;
      L_ACCRUAL_CATEGORY VARCHAR(100);


      CURSOR C_DETAIL_RECORD_OP4
      IS

        SELECT DISTINCT 'US Active' "Business Group",
                                 PAPF.EMPLOYEE_NUMBER "Employee Number",
                                 PAPF.FULL_NAME "Employee Full Name",
                                                                                                                                decode ( paypf.payroll_name, 'At Home', pa.region_2, loc.region_2) "State" ,  --v1.4
PAAF.Work_at_home "Work At Home Flag",
(select pad.REGION_2
from apps.per_addresses pad
where pad.person_id(+) = papf.person_id
AND PAD.DATE_TO IS NULL
AND PAD.PRIMARY_FLAG='Y'
--AND PAD.ADDRESS_TYPE='HOME'
) AS "State of Residence"-- v 1.2
                            /*
							START R12.2 Upgrade Remediation
							code commented by RXNETHI-ARGANO,15/05/23
							FROM  hr.PER_ALL_PEOPLE_F PAPF,
                                  hr.PER_ALL_ASSIGNMENTS_F PAAF,
                                  hr.PER_PERIODS_OF_SERVICE PPOS,
                                 hr.HR_LOCATIONS_ALL LOC,
                                                                                                                                HR.PER_ADDRESSES PA,
                                                                                                                                 HR.PAY_ALL_PAYROLLS_F PAYPF 
*/
--code added by RXNETHI-ARGANO,15/05/23
     FROM  apps.PER_ALL_PEOPLE_F PAPF,
                                  apps.PER_ALL_ASSIGNMENTS_F PAAF,
                                  apps.PER_PERIODS_OF_SERVICE PPOS,
                                 apps.HR_LOCATIONS_ALL LOC,
                                                                                                                                APPS.PER_ADDRESSES PA,
                                                                                                                                 APPS.PAY_ALL_PAYROLLS_F PAYPF
--END R12.2 Upgrade Remediation
                         WHERE PAPF.EFFECTIVE_END_DATE =    (SELECT MAX (PAPF2.EFFECTIVE_END_DATE)
                                                                                                            --FROM  hr.PER_ALL_PEOPLE_F PAPF2
                                                                                                  --code commented by RXNETHI-ARGANO,15/05/23
																								  FROM  apps.PER_ALL_PEOPLE_F PAPF2
                                                                                                  --code added by RXNETHI-ARGANO,15/05/23
																											WHERE PAPF.PERSON_ID = PAPF2.PERSON_ID
                                                                                                           AND L_ENDOFMONTH
                                                                                                              BETWEEN PAPF2.EFFECTIVE_START_DATE
                                                                                                            AND PAPF2.EFFECTIVE_END_DATE)
                             AND PAPF.PERSON_ID = PAAF.PERSON_ID
                                                          AND PAAF.LOCATION_ID = LOC.LOCATION_ID(+)
                             AND PAAF.EFFECTIVE_END_DATE =
                                                                                                                    (SELECT MAX (PAAF_2.EFFECTIVE_END_DATE)
                                                                                                                       --FROM  hr.PER_ALL_ASSIGNMENTS_F PAAF_2
																										--code commented by RXNETHI-ARGANO,15/05/23
																										FROM  apps.PER_ALL_ASSIGNMENTS_F PAAF_2
																										--code added by RXNETHI-ARGANO,15/05/23
                                                                                                                      WHERE PAAF_2.PERSON_ID = PAAF.PERSON_ID
                                                                                                                        AND L_ENDOFMONTH
                                                                                                                              BETWEEN PAAF_2.EFFECTIVE_START_DATE
                                                                                                                                   AND PAAF_2.EFFECTIVE_END_DATE)
                             AND PAPF.PERSON_ID = PPOS.PERSON_ID
                             AND PAAF.PERIOD_OF_SERVICE_ID =       PPOS.PERIOD_OF_SERVICE_ID
                             AND PAPF.BUSINESS_GROUP_ID = 325
                             AND PAPF.CURRENT_EMPLOYEE_FLAG = 'Y'
                             AND PAAF.ASSIGNMENT_STATUS_TYPE_ID = 1
                                                                                                                AND PAYPF.PAYROLL_ID=PAAF.PAYROLL_ID
                                                                                                                AND PAPF.PERSON_ID=PA.PERSON_ID
                                                                                                                AND PA.PRIMARY_FLAG='Y'
                                                                                                                AND L_ENDOFMONTH BETWEEN PA.DATE_FROM AND  NVL(PA.DATE_TO,L_ENDOFMONTH)
                                                                                                                 AND L_ENDOFMONTH BETWEEN PAYPF.EFFECTIVE_START_DATE AND PAYPF.EFFECTIVE_END_DATE
UNION ALL
SELECT DISTINCT
                        'US Inactive' "Business Group",
                        papf.employee_number "Employee Number",
                        papf.full_name "Employee Full Name",
                                                                                                decode ( paypf.payroll_name, 'At Home', pa.region_2, loc.region_2) "State" , -- v 1.2
PAAF.Work_at_home "Work At Home Flag",
(select pad.REGION_2
from apps.per_addresses pad
where pad.person_id(+) = papf.person_id
AND PAD.DATE_TO IS NULL
AND PAD.PRIMARY_FLAG='Y'
--AND PAD.ADDRESS_TYPE='HOME'
) AS "State of Residence"-- v 1.2
                   /*
				   FROM  hr.per_all_people_f papf,
                         hr.per_all_assignments_f paaf,
                         hr. hr_locations_all loc,
                         hr.per_periods_of_service ppos,
                                                                                                hr.per_addresses pa ,                 -- v 1.2
                        HR.PAY_ALL_PAYROLLS_F PAYPF
						*/
				  --code added by RXNETHI-ARGANO,15/05/23
				  FROM  apps.per_all_people_f papf,
                         apps.per_all_assignments_f paaf,
                         apps. hr_locations_all loc,
                         apps.per_periods_of_service ppos,
                                                                                                apps.per_addresses pa ,                 -- v 1.2
                        APPS.PAY_ALL_PAYROLLS_F PAYPF
				  --END R12.2 Upgrade Remediation
                  WHERE papf.effective_end_date =     (SELECT MAX (papf2.effective_end_date)
                                                                                                              --FROM  hr.per_all_people_f papf2
																							--code commented by RXNETHI-ARGANO,15/05/23
																							FROM  apps.per_all_people_f papf2
																							--code added by RXNETHI-ARGANO,15/05/23
                                                                                    WHERE papf.person_id = papf2.person_id
                                                                                   AND  L_ENDOFMONTH BETWEEN papf2.effective_start_date
                                                                                   AND papf2.effective_end_date)
                        AND papf.person_id = paaf.person_id
                        AND paaf.effective_start_date =  (SELECT MAX (paaf_2.effective_start_date)
                                                                                --FROM  hr.per_all_assignments_f paaf_2
                                                                                --code commented by RXNETHI-ARGANO,15/05/23
																				FROM  apps.per_all_assignments_f paaf_2
                                                                                --code added by RXNETHI-ARGANO,15/05/23
																				WHERE paaf_2.person_id = paaf.person_id
                                                                                 AND  L_ENDOFMONTH BETWEEN paaf_2.effective_start_date
                                                                                 AND paaf_2.effective_end_date)
                        AND paaf.location_id = loc.location_id(+)
                        AND papf.person_id = ppos.person_id
                        AND paaf.period_of_service_id =     ppos.period_of_service_id
                        AND papf.business_group_id = 325
                        AND papf.current_employee_flag = 'Y'
                        AND paaf.assignment_status_type_id NOT IN (1, 145, 150)
                                                                                                and paypf.payroll_id=paaf.payroll_id
                                                                                                and papf.person_id=pa.person_id
                                                                                                and pa.primary_flag='Y'
                                                                                                AND  L_ENDOFMONTH BETWEEN paypf.effective_start_date and paypf.effective_end_date
                                                                                                AND  L_ENDOFMONTH BETWEEN pa.date_from AND    NVL(pa.date_to,  L_ENDOFMONTH)
UNION ALL
SELECT DISTINCT
                        'US Termed' "Business Group",
                        papf.employee_number "Employee Number",
                        papf.full_name "Employee Full Name",
                                                                                                decode ( paypf.payroll_name, 'At Home', pa.region_2, loc.region_2) "State",  -- v 1.2
PAAF.Work_at_home "Work At Home Flag",
(select pad.REGION_2
from apps.per_addresses pad
where pad.person_id(+) = papf.person_id
AND PAD.DATE_TO IS NULL
AND PAD.PRIMARY_FLAG='Y'
--AND PAD.ADDRESS_TYPE='HOME'
) AS "State of Residence"-- v 1.2
                   /*
				   START R12.2 Upgrade Remediation
				   code commented by RXNETHI-ARGANO,15/05/23
				   FROM  hr.per_all_people_f papf,
                         hr.per_all_assignments_f paaf,
                         hr.hr_locations_all loc,
                         hr.per_periods_of_service ppos,
                                                                                                hr.pay_all_payrolls_f paypf,         -- v 1.2
                                                                                                hr.per_addresses pa                  -- v 1.2
																								*/
					--code added by RXNETHI-ARGANO,15/05/23
					FROM  apps.per_all_people_f papf,
                         apps.per_all_assignments_f paaf,
                         apps.hr_locations_all loc,
                         apps.per_periods_of_service ppos,
                                                                                                apps.pay_all_payrolls_f paypf,         -- v 1.2
                                                                                                apps.per_addresses pa                  -- v 1.2
					--END R12.2 Upgrade Remediation
                  WHERE papf.effective_end_date =   (SELECT MAX (papf2.effective_end_date)
                                                                                        --FROM  hr.per_all_people_f papf2
                                                                                       --code commented by RXNETHI-ARGANO,15/05/23
																					   FROM  apps.per_all_people_f papf2
                                                                                       --code added by RXNETHI-ARGANO,15/05/23
																					   WHERE papf.person_id = papf2.person_id
                                                                                             AND  L_ENDOFMONTH BETWEEN papf2.effective_start_date
                                                                                                                  AND papf2.effective_end_date)
                        AND papf.person_id = paaf.person_id
                        AND paaf.effective_end_date =   (SELECT MAX (paaf_2.effective_end_date)
                                                                                            --FROM  hr.per_all_assignments_f paaf_2
                                                                                         --code commented by RXNETHI-ARGANO,15/05/23
																						 FROM  apps.per_all_assignments_f paaf_2
                                                                                         --code added by RXNETHI-ARGANO,15/05/23
																						   WHERE paaf_2.person_id = paaf.person_id
                                                                                                 AND  L_ENDOFMONTH BETWEEN paaf_2.effective_start_date
                                                                                                                 AND paaf_2.effective_end_date --added by Vaisakh on 06-Jan-2020
                                                                                                                                                                                                                                            )
                        AND paaf.location_id = loc.location_id(+)
                        AND papf.person_id = ppos.person_id
                        AND paaf.period_of_service_id =     ppos.period_of_service_id
                        --AND ppos.actual_termination_date <=  L_ENDOFMONTH
                        AND  ppos.actual_termination_date BETWEEN   L_ENDOFMONTH - 730 and L_ENDOFMONTH
                        AND papf.business_group_id = 325
                        AND papf.current_employee_flag IS NULL
                        AND paaf.assignment_status_type_id IN (145, 150, 3)
                        AND ppos.final_process_date IS NOT NULL
                                                                                                and paypf.payroll_id=paaf.payroll_id
                                                                                                and papf.person_id=pa.person_id
                                                                                                and pa.primary_flag='Y'
                                                                                                AND  L_ENDOFMONTH BETWEEN paypf.effective_start_date and paypf.effective_end_date
                                                                                                AND  L_ENDOFMONTH BETWEEN pa.date_from AND    NVL(pa.date_to,  L_ENDOFMONTH)
;


   BEGIN
      L_STAGE := 'c_directory_path';
      L_ENDOFMONTH := TO_DATE (SYSDATE, 'DD-MON-YYYY');


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
         'Business Group|Employee Number|Employee Full Name|State|Work at Home Flag|State of Residence';
      -- UTL_FILE.put_line (v_bank_file, l_rec);
      APPS.FND_FILE.PUT_LINE (APPS.FND_FILE.OUTPUT, L_REC);



      FOR SEL IN C_DETAIL_RECORD_OP4
      LOOP
--


         L_REC :=
             SEL."Business Group"
             || '|'
             ||SEL."Employee Number"
             || '|'
             || SEL."Employee Full Name"
             || '|'
             || SEL."State"
             || '|'
             || SEL."Work At Home Flag"
             || '|'
             || SEL."State of Residence";
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
END ttec_us_emp_state_of_res;
/
show errors;
/