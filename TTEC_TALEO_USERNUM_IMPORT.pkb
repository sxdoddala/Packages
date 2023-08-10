create or replace PACKAGE BODY      ttec_taleo_usernum_import
/************************************************************************************
        Program Name: TTEC_PO_TSG_INTERFACE 

        Description:   

        Developed by : 
        Date         :  

       Modification Log
       Name                  Version #    Date            Description
       -----                 --------     -----           -------------
   MXKEERTHI(ARGANO)  17-JUL-2023           1.0          R12.2 Upgrade Remediation
    ****************************************************************************************/
IS
--************************************************************************************--
--*                                                                                  *--
--*     Program Name: ttec_Taleo_USer Number Import                                  *--
--*                                                                                  *--
--*                                                                                  *--
--*                                                                                  *--
--*     Input/Output Parameters:                                                     *--
--*                                                                                  *--
--*     Tables Accessed:                                                             *--
--*                        ttec_taleo_usernum_OAD                                    *--
--*                        TTEC_ERROR_HANDLING                                       *--
 --                                                                                  *--
--*                                                                                  *--
--*     Tables Modified:                                                             *--
--*                        TTEC_ERROR_HANDLING                                       *--
--*                        CUST.TTEC_TALEO_usernum_import                            *--
--*                                                                                  *--
--*     PROCEDUREs Called:                                                           *--
--*     LOGIC   -- Logic used here is linear. Makes it easier to follow and easier to modify
-- *               Logic used here is linear. Makes it easier to follow and easier to modify
--*                Logic used here is linear. Makes it easier to follow and easier to modify
--*                Logic used here is linear. Makes it easier to follow and easier to modify
--*                eliminated fancy complex code for sake of ease of modification
--*                select * from regexp  was tried in different varieties to learn from it
--*                and to make it flexiable for future changes.
--*     note on use of ttec_error_handling table
--*             label2 is blank
--*             reference 2 us blank
--*             label14 is FND MESSGAE ID
--*             reference14 is business_group id
--*             label15   is recruiter employee number
--*             reference15 is recruiter email address
--*Modification Log:                                                                 *--
--*Developer          Date        Description                                     *--
--*---------          ----        -----------                                     *--
--*  Wasim Manasfi      Feb 3 2008       Created
--************************************************************************************--

   --    SET TIMING ON
   -- SET SERVEROUTPUT ON SIZE 1000000;
   --    DECLARE
   --*** VARIABLES USED BY COMMON ERROR HANDLING PROCEDURES ***--
   g_run_date             CONSTANT DATE                    := TRUNC (SYSDATE);
   g_oracle_start_date    CONSTANT DATE            := TO_DATE ('01-JAN-1950');
   g_oracle_end_date      CONSTANT DATE            := TO_DATE ('31-DEC-4712');
   l_stat                 NUMBER;
   
        --START R12.2 Upgrade Remediation
	  /*
	    	Commented code by MXKEERTHI-ARGANO,07/17/2023
    e_initial_status                cust.ttec_error_handling.status%TYPE
                                                                 := 'INITIAL';
   e_warning_status                cust.ttec_error_handling.status%TYPE
                                                                 := 'WARNING';
   e_failure_status                cust.ttec_error_handling.status%TYPE
                                                                 := 'FAILURE';
   g_len_64                        NUMBER                               := 64;
   e_application_code              cust.ttec_error_handling.application_code%TYPE
                                                                      := 'HR';
   e_interface                     cust.ttec_error_handling.INTERFACE%TYPE
                                                                   := 'TALEO';
   e_program_name                  cust.ttec_error_handling.program_name%TYPE
                                                     := 'TtecTaleoEPNUM';
   e_module_name                   cust.ttec_error_handling.module_name%TYPE
                                                                      := NULL;
   e_conc                          cust.ttec_error_handling.concurrent_request_id%TYPE
                                                                         := 0;
   e_execution_date                cust.ttec_error_handling.execution_date%TYPE
                                                                   := SYSDATE;
   e_status                        cust.ttec_error_handling.status%TYPE
                                                                      := NULL;
   e_error_code                    cust.ttec_error_handling.ERROR_CODE%TYPE
                                                                         := 0;
   e_error_message                 cust.ttec_error_handling.error_message%TYPE
                                                                      := NULL;
   e_label1                        cust.ttec_error_handling.label1%TYPE
                                                                      := NULL;
   e_reference1                    cust.ttec_error_handling.reference1%TYPE
                                                                      := NULL;
   e_label2                        cust.ttec_error_handling.label2%TYPE
                                                                      := NULL;
   e_reference2                    cust.ttec_error_handling.reference2%TYPE
                                                                      := NULL;
   e_label3                        cust.ttec_error_handling.label3%TYPE
                                                                      := NULL;
   e_reference3                    cust.ttec_error_handling.reference3%TYPE
                                                                      := NULL;
   e_label4                        cust.ttec_error_handling.label4%TYPE
                                                                      := NULL;
   e_reference4                    cust.ttec_error_handling.reference4%TYPE
                                                                      := NULL;
   e_label5                        cust.ttec_error_handling.label5%TYPE
                                                                      := NULL;
   e_reference5                    cust.ttec_error_handling.reference5%TYPE
                                                                      := NULL;
   e_label6                        cust.ttec_error_handling.label6%TYPE
                                                                      := NULL;
   e_reference6                    cust.ttec_error_handling.reference6%TYPE
                                                                      := NULL;
   e_label7                        cust.ttec_error_handling.label7%TYPE
                                                                      := NULL;
   e_reference7                    cust.ttec_error_handling.reference7%TYPE
                                                                      := NULL;
   e_label8                        cust.ttec_error_handling.label8%TYPE
                                                                      := NULL;
   e_reference8                    cust.ttec_error_handling.reference8%TYPE
                                                                      := NULL;
   e_label9                        cust.ttec_error_handling.label9%TYPE
                                                                      := NULL;
   e_reference9                    cust.ttec_error_handling.reference9%TYPE
                                                                      := NULL;
   e_label10                       cust.ttec_error_handling.label10%TYPE
                                                                      := NULL;
   e_reference10                   cust.ttec_error_handling.reference10%TYPE
                                                                      := NULL;
   e_label11                       cust.ttec_error_handling.label11%TYPE
                                                                      := NULL;
   e_reference11                   cust.ttec_error_handling.reference11%TYPE
                                                                      := NULL;
   e_label12                       cust.ttec_error_handling.label12%TYPE
                                                                      := NULL;
   e_reference12                   cust.ttec_error_handling.reference12%TYPE
                                                                      := NULL;
   e_label13                       cust.ttec_error_handling.label13%TYPE
                                                                      := NULL;
   e_reference13                   cust.ttec_error_handling.reference13%TYPE
                                                                      := NULL;
   e_label14                       cust.ttec_error_handling.label14%TYPE
                                                                      := NULL;
   e_reference14                   cust.ttec_error_handling.reference14%TYPE
                                                                      := NULL;
   e_label15                       cust.ttec_error_handling.label15%TYPE
                                                                      := NULL;
   e_reference15                   cust.ttec_error_handling.reference15%TYPE
                                                                      := NULL;
   e_last_update_date              cust.ttec_error_handling.last_update_date%TYPE
                                                                      := NULL;
   e_last_updated_by               cust.ttec_error_handling.last_updated_by%TYPE
                                                                      := NULL;
   e_last_update_logi              cust.ttec_error_handling.last_update_login%TYPE
                                                                      := NULL;
   e_creation_date                 cust.ttec_error_handling.creation_date%TYPE
                                                                      := NULL;
   e_created_by                    cust.ttec_error_handling.created_by%TYPE
                                                                      := NULL;

	   */
	  --code Added  by MXKEERTHI-ARGANO, 07/17/2023
   e_initial_status                apps.ttec_error_handling.status%TYPE
                                                                 := 'INITIAL';
   e_warning_status                apps.ttec_error_handling.status%TYPE
                                                                 := 'WARNING';
   e_failure_status                apps.ttec_error_handling.status%TYPE
                                                                 := 'FAILURE';
   g_len_64                        NUMBER                               := 64;
   e_application_code              apps.ttec_error_handling.application_code%TYPE
                                                                      := 'HR';
   e_interface                     apps.ttec_error_handling.INTERFACE%TYPE
                                                                   := 'TALEO';
   e_program_name                  apps.ttec_error_handling.program_name%TYPE
                                                     := 'TtecTaleoEPNUM';
   e_module_name                   apps.ttec_error_handling.module_name%TYPE
                                                                      := NULL;
   e_conc                          apps.ttec_error_handling.concurrent_request_id%TYPE
                                                                         := 0;
   e_execution_date                apps.ttec_error_handling.execution_date%TYPE
                                                                   := SYSDATE;
   e_status                        apps.ttec_error_handling.status%TYPE
                                                                      := NULL;
   e_error_code                    apps.ttec_error_handling.ERROR_CODE%TYPE
                                                                         := 0;
   e_error_message                 apps.ttec_error_handling.error_message%TYPE
                                                                      := NULL;
   e_label1                        apps.ttec_error_handling.label1%TYPE
                                                                      := NULL;
   e_reference1                    apps.ttec_error_handling.reference1%TYPE
                                                                      := NULL;
   e_label2                        apps.ttec_error_handling.label2%TYPE
                                                                      := NULL;
   e_reference2                    apps.ttec_error_handling.reference2%TYPE
                                                                      := NULL;
   e_label3                        apps.ttec_error_handling.label3%TYPE
                                                                      := NULL;
   e_reference3                    apps.ttec_error_handling.reference3%TYPE
                                                                      := NULL;
   e_label4                        apps.ttec_error_handling.label4%TYPE
                                                                      := NULL;
   e_reference4                    apps.ttec_error_handling.reference4%TYPE
                                                                      := NULL;
   e_label5                        apps.ttec_error_handling.label5%TYPE
                                                                      := NULL;
   e_reference5                    apps.ttec_error_handling.reference5%TYPE
                                                                      := NULL;
   e_label6                        apps.ttec_error_handling.label6%TYPE
                                                                      := NULL;
   e_reference6                    apps.ttec_error_handling.reference6%TYPE
                                                                      := NULL;
   e_label7                        apps.ttec_error_handling.label7%TYPE
                                                                      := NULL;
   e_reference7                    apps.ttec_error_handling.reference7%TYPE
                                                                      := NULL;
   e_label8                        apps.ttec_error_handling.label8%TYPE
                                                                      := NULL;
   e_reference8                    apps.ttec_error_handling.reference8%TYPE
                                                                      := NULL;
   e_label9                        apps.ttec_error_handling.label9%TYPE
                                                                      := NULL;
   e_reference9                    apps.ttec_error_handling.reference9%TYPE
                                                                      := NULL;
   e_label10                       apps.ttec_error_handling.label10%TYPE
                                                                      := NULL;
   e_reference10                   apps.ttec_error_handling.reference10%TYPE
                                                                      := NULL;
   e_label11                       apps.ttec_error_handling.label11%TYPE
                                                                      := NULL;
   e_reference11                   apps.ttec_error_handling.reference11%TYPE
                                                                      := NULL;
   e_label12                       apps.ttec_error_handling.label12%TYPE
                                                                      := NULL;
   e_reference12                   apps.ttec_error_handling.reference12%TYPE
                                                                      := NULL;
   e_label13                       apps.ttec_error_handling.label13%TYPE
                                                                      := NULL;
   e_reference13                   apps.ttec_error_handling.reference13%TYPE
                                                                      := NULL;
   e_label14                       apps.ttec_error_handling.label14%TYPE
                                                                      := NULL;
   e_reference14                   apps.ttec_error_handling.reference14%TYPE
                                                                      := NULL;
   e_label15                       apps.ttec_error_handling.label15%TYPE
                                                                      := NULL;
   e_reference15                   apps.ttec_error_handling.reference15%TYPE
                                                                      := NULL;
   e_last_update_date              apps.ttec_error_handling.last_update_date%TYPE
                                                                      := NULL;
   e_last_updated_by               apps.ttec_error_handling.last_updated_by%TYPE
                                                                      := NULL;
   e_last_update_logi              apps.ttec_error_handling.last_update_login%TYPE
                                                                      := NULL;
   e_creation_date                 apps.ttec_error_handling.creation_date%TYPE
                                                                      := NULL;
   e_created_by                    apps.ttec_error_handling.created_by%TYPE
                                                                      := NULL;

	  --END R12.2.10 Upgrade remediation
   --User specified variables


   p_org_name                      VARCHAR2 (64)  := 'TeleTech Holdings - US';
   --*** Global Variable Declarations ***--
   g_default_code_comb_seg5        VARCHAR2 (4)                     := '0000';
   g_default_code_comb_seg6        VARCHAR2 (4)                     := '0000';
   g_proportion                    NUMBER                                := 1;
   g_total_employees_read          NUMBER                                := 0;
   g_total_employees_processed     NUMBER                                := 0;
   g_total_record_count            NUMBER                                := 0;
   g_primary_column                VARCHAR2 (64)                      := NULL;
   l_commit_point                  NUMBER                               := 20;
   l_rows_processed                NUMBER                                := 0;
   g_admin_email                   VARCHAR2 (256)
                                               := 'Wasim.Manasfi@teltech.com';
											        --START R12.2 Upgrade Remediation
	  /*
	    	Commented code by MXKEERTHI-ARGANO,07/17/2023
    g_defaults                      cust.ttec_taleo_defaults%ROWTYPE;
   g_stage                         cust.ttec_taleo_stage%ROWTYPE;
	   */
	  --code Added  by MXKEERTHI-ARGANO, 07/17/2023
   g_defaults                      apps.ttec_taleo_defaults%ROWTYPE;
   g_stage                         apps.ttec_taleo_stage%ROWTYPE;
	  --END R12.2.10 Upgrade remediation

   g_trunc_table                     VARCHAR2 (100)
                         := 'truncate table cust.TTEC_TALEO_USERNUM_LOAD_TMP';

   /* error routine variables*/

   --*** EXCEPTIONS ***--
   skip_record                     EXCEPTION;

   --*** CURSOR DECLARATION TO SELECT ROWS FROM CONV_HR_ASSIGNMENT_STAGE STAGING TABLE ***--
   CURSOR taleo_load
   IS
      SELECT *
        FROM TTEC_TALEO_USERNUM_LOAD;

		  CURSOR taleo_load_tmp_master
		  IS
		  select distinct user_num, active
		   --	 from cust.TTEC_TALEO_USERNUM_LOAD_TMP--Commented code by MXKEERTHI-ARGANO,07/17/2023
		  		 from apps.TTEC_TALEO_USERNUM_LOAD_TMP --code added by MXKEERTHI-ARGANO, 07/17/2023
                  -- where user_num NOT IN (select user_num from cust.TTEC_TALEO_USERNUM_LOAD_MASTER);--Commented code by MXKEERTHI-ARGANO,07/17/2023
				 where user_num NOT IN (select user_num from apps.TTEC_TALEO_USERNUM_LOAD_MASTER); --code added by MXKEERTHI-ARGANO, 07/17/2023


/*
------------------------------------------------------------------------------------------------
------------------------------------------------------------------------------------------------
*/
   PROCEDURE print_msg (v_data IN VARCHAR2)
   IS
   BEGIN
      Fnd_File.put_line (Fnd_File.output, v_data);
     --    fnd_file.put_line (fnd_file.LOG, v_data);
   --     DBMS_OUTPUT.put_line (v_data);
   END;

/*
------------------------------------------------------------------------------------------------
------------------------------------------------------------------------------------------------
*/
   PROCEDURE print_line (v_data IN VARCHAR2)
   IS
   BEGIN
      --   fnd_file.put_line (fnd_file.output, v_data);
      Fnd_File.put_line (Fnd_File.LOG,
                            'Employee success Status in routine is :'
                         || TO_CHAR (g_stage.emp_val_err)
                        );
      Fnd_File.put_line (Fnd_File.LOG, v_data);
   --     DBMS_OUTPUT.put_line (v_data);
   END;

/*
------------------------------------------------------------------------------------------------
------------------------------------------------------------------------------------------------
*/

/*
------------------------------------------------------------------------------------------------
------------------------------------------------------------------------------------------------
*/

   PROCEDURE processx (p_stat OUT NUMBER)
   IS
      --  l_business_group_id       NUMBER                           := NULL;
      l_user_num             apps.TTEC_TALEO_USERNUM_LOAD.USER_NUM%TYPE;
      l_active             apps.TTEC_TALEO_USERNUM_LOAD.ACTIVE%TYPE;


   BEGIN
      e_module_name := 'Process X';
      print_line (e_module_name);
-- dbms_output.put_line('1');

      --      IF taleo_load%ISOPEN
      --     THEN
       --       CLOSE taleo_load;
        --   END IF;
      print_msg ('Program to Load Taleo User Numbers  ');
      print_msg (   'Start time:  '
                 || TO_CHAR (SYSDATE, 'MM/DD/YYYY - HH24:MI:SS ')
                );
      print_msg ('');
      print_msg ('Run Results: ');
      print_msg ('');
      EXECUTE IMMEDIATE g_trunc_table;

      BEGIN
         --*** OPEN AND FETCH EACH TEMPORARY ASSIGNMENT ***--
         l_rows_processed := 0;
         g_total_employees_read := 0;

         FOR sel IN taleo_load
         LOOP
            g_stage := NULL;                         -- NULL THE STAGE fields
            g_total_employees_read := g_total_employees_read + 1;
            --*** INITIALIZE VALUES  ***--

            l_user_num := sel.user_num;

            print_line (   '>>>>> Processing User Record # '
                        || l_user_num
                       );
            p_stat := 0;
            g_stage.emp_val_err := 1;
            g_stage.process_flag := 0;
            --   e_label14 := q_business_group_id;

/*
         IF l_skip_first = 1 THEN
         l_skip_first := 0;
         GOTO skipporcessing;

         END IF;
         */
            BEGIN
			 --	 INSERT INTO cust.TTEC_TALEO_USERNUM_LOAD_TMP--Commented code by MXKEERTHI-ARGANO,07/17/2023
			 INSERT INTO apps.TTEC_TALEO_USERNUM_LOAD_TMP--code added by MXKEERTHI-ARGANO, 07/17/2023

                           (user_num,
                           active
                           )
                    VALUES (l_user_num
                             , 'Y'
                           );

            -- record the processed record.
            EXCEPTION
               WHEN OTHERS
               THEN
                  log_error (l_user_num, NULL, 'TTEC_TALEO_E_6000', NULL);
                                             --Ah 03142007 ADDED ERROR NUMBER
                  -- candidate number is not numeric
                  g_stage.emp_val_err := 1;
                  g_stage.process_flag := 1;                    -- last write
                  l_user_num := -1;
                  l_stat := 1;
            END;
		END LOOP;
        EXCEPTION
               WHEN OTHERS
               THEN
                  log_error (l_user_num, NULL, 'TTEC_TALEO_E_6010', NULL);
                                             --Ah 03142007 ADDED ERROR NUMBER
                  -- insert error
                  print_line (   'Failed to Insert into Staging table cust.TTEC_TALEO_USERNUM_LOAD_TMP '
                              || '|'
                              || SQLCODE
                              || '|'
                              || SUBSTR (SQLERRM, 1, 80)
                             );
                  l_stat := 1;
            END;
         commit;

		 BEGIN
         --*** OPEN AND FETCH EACH TEMPORARY ASSIGNMENT ***--
         l_rows_processed := 0;
         g_total_employees_read := 0;

         FOR sel IN taleo_load_tmp_master
         LOOP
            g_stage := NULL;                         -- NULL THE STAGE fields
            g_total_employees_read := g_total_employees_read + 1;
            --*** INITIALIZE VALUES  ***--

            l_user_num := sel.user_num;

            print_line (   '>>>>> Processing User Record # '
                        || l_user_num
                       );
            p_stat := 0;
            g_stage.emp_val_err := 1;
            g_stage.process_flag := 0;
            --   e_label14 := q_business_group_id;

/*
         IF l_skip_first = 1 THEN
         l_skip_first := 0;
         GOTO skipporcessing;

         END IF;
         */
            BEGIN
			 --	 INSERT INTO cust.TTEC_TALEO_USERNUM_LOAD_MASTER --Commented code by MXKEERTHI-ARGANO,07/17/2023
			 INSERT INTO apps.TTEC_TALEO_USERNUM_LOAD_MASTER  --code added by MXKEERTHI-ARGANO, 07/17/2023

                           (user_num,
                           active,
						   date_in
                           )
                    VALUES (l_user_num
                             , 'Y',TRUNC(SYSDATE)
                           );
              commit;
            -- record the processed record.
            EXCEPTION
               WHEN OTHERS
               THEN
                  log_error (l_user_num, NULL, 'TTEC_TALEO_E_6000', NULL);
                                             --Ah 03142007 ADDED ERROR NUMBER
                  -- candidate number is not numeric
                  g_stage.emp_val_err := 1;
                  g_stage.process_flag := 1;                    -- last write
                  l_user_num := -1;
                  l_stat := 1;
            END;
		END LOOP;
        EXCEPTION
               WHEN OTHERS
               THEN
                  log_error (l_user_num, NULL, 'TTEC_TALEO_E_6010', NULL);
                                             --Ah 03142007 ADDED ERROR NUMBER
                  -- insert error
                  print_line (   'Failed to Insert into Staging table cust.TTEC_TALEO_USERNUM_LOAD_MASTER '
                              || '|'
                              || SQLCODE
                              || '|'
                              || SUBSTR (SQLERRM, 1, 80)
                             );
                  l_stat := 1;
            END;

         IF taleo_load%ISOPEN
         THEN
            CLOSE taleo_load;
         END IF;

         print_msg (   'Total Taleo User Number Load:   '
                    || TO_CHAR (l_rows_processed)
                   );
         print_msg (   'Total Taleo User Number Load: '
                    || TO_CHAR (g_total_employees_read - l_rows_processed)
                   );
         print_msg (   'Total Taleo Taleo User Number Load:       '
                    || TO_CHAR (g_total_employees_read)
                   );

   END;


/*
------------------------------------------------------------------------------------------------
------------------------------------------------------------------------------------------------
*/
   PROCEDURE errvar_null (p_status OUT NUMBER)
   IS
   BEGIN
      e_label1 := NULL;
      e_reference1 := NULL;
      e_label2 := NULL;
      e_reference2 := NULL;
      e_label3 := NULL;
      e_reference3 := NULL;
      e_label4 := NULL;
      e_reference4 := NULL;
      e_label5 := NULL;
      e_reference5 := NULL;
      e_label6 := NULL;
      e_reference6 := NULL;
      e_label7 := NULL;
      e_reference7 := NULL;
      e_label8 := NULL;
      e_reference8 := NULL;
      e_label9 := NULL;
      e_reference9 := NULL;
      e_label10 := NULL;
      e_reference10 := NULL;
      e_label11 := NULL;
      e_reference11 := NULL;
      e_label12 := NULL;
      e_reference12 := NULL;
      e_label13 := NULL;
      e_reference13 := NULL;
      p_status := 0;                                             -- if needed
   END;


/* do not change the error layout */
/* label 14 is the TTEC FND message */

   /*---------------------------------------------------------------------------------------------------------
    Name:  Log error  PROCEDURE
    Description:  PROCEDURE standardizes concurrent program EXCEPTION handling
    error reporting routine.
   ---------------------------------------------------------------------------------------------------------*/
   PROCEDURE log_error (
      candidate_id   IN   NUMBER,
      reference1     IN   VARCHAR2,
      label14        IN   VARCHAR2,
      reference2     IN   VARCHAR2
   )
   IS
      l_label1       VARCHAR2 (64) := 'Candidate ID';
      l_reference1   VARCHAR2 (64) := NULL;
   BEGIN
      l_reference1 := TO_CHAR (candidate_id);
      e_error_code := SQLCODE;
      e_error_message := SUBSTR (SQLERRM, 1, 240);
	   -- cust.ttec_process_error (e_application_code, --Commented code by MXKEERTHI-ARGANO,07/17/2023
      apps.ttec_process_error (e_application_code, --code added by MXKEERTHI-ARGANO, 07/17/2023
                               e_interface,
                               e_program_name,
                               e_module_name,
                               e_warning_status,
                               e_error_code,
                               e_error_message,
                               l_label1,
                               l_reference1,
                               e_label2,
                               e_reference2,
                               e_label3,
                               e_reference3,
                               e_label4,
                               e_reference4,
                               e_label5,
                               e_reference5,
                               e_label6,
                               e_reference6,
                               e_label7,
                               e_reference7,
                               e_label8,
                               e_reference8,
                               e_label9,
                               e_reference9,
                               e_label10,
                               e_reference10,
                               e_label1,
                               e_reference11,
                               e_label12,
                               e_reference12,
                               e_label13,
                               e_reference13,
                               label14,         -- this is the FND  message ID
                               e_reference14, -- this is the business group ID
                               e_label15,
                               e_reference15
                              );
   END;                                                           -- log error

/*
------------------------------------------------------------------------------------------------
------------------------------------------------------------------------------------------------
*/
   PROCEDURE main (
      errbuf                OUT      VARCHAR2,
      retcode               OUT      NUMBER
   )
   IS
      --  l_business_group_id            NUMBER                           := NULL;


      p_stat                        NUMBER                               := 0;
   BEGIN
-- dbms_output.put_line('1');
      IF taleo_load%ISOPEN
      THEN
         CLOSE taleo_load;
      END IF;

      print_line ('Program to upload Taleo Employees  ');
      print_line ('Start time:' || SYSDATE);
            processx (p_stat);
   EXCEPTION
      WHEN OTHERS
      THEN                                                   -- error handling
         print_line (   'Error in reading input file - Check format'
                     || '|'
                     || SQLCODE
                     || '|'
                     || SUBSTR (SQLERRM, 1, 80)
                    );
         NULL;
   END main;
END ttec_taleo_usernum_import;
/
show errors;
/
