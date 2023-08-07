create or replace PACKAGE BODY      TTEC_ATELKA_UPD_RESP_PKG
IS

  /*
   Description:   This package is created to enable responsibility of Atelka Employee
   Created Date:  19-May-2017
   Created by:     Manish Chauhan
   Version:        Initial
       Modification Log
       Name                  Version #    Date            Description
       -----                 --------     -----           -------------
   MXKEERTHI(ARGANO)  17-JUL-2023           1.0          R12.2 Upgrade Remediation
    ****************************************************************************************
   REM =====================================================================================================================
   */

   PROCEDURE Main (errbuf OUT VARCHAR2, retcode OUT NUMBER)
   IS
      ---local variables

      ln_object_version_number      PER_ALL_PEOPLE_F.OBJECT_VERSION_NUMBER%TYPE;
      lc_dt_ud_mode                 VARCHAR2 (100):=NULL;
      ln_assignment_id              PER_ALL_ASSIGNMENTS_F.ASSIGNMENT_ID%TYPE;
      lc_employee_number            NUMBER;
      l_person_id                  Number;
      l_total_count                NUMBER;
      l_change_count               NUMBER;
      l_error_count                NUMBER;
      l_old_date                    Date;
      v_user_id                    NUMBER;
      v_responsibility_id          NUMBER;
      v_person_id                  NUMBER;

      ------for Assignment update

      ln_a_object_version_number    PER_ALL_ASSIGNMENTS_F.OBJECT_VERSION_NUMBER%TYPE;  ---Assignemnt OVN

      --- Out Variable

      lb_update                     BOOLEAN;
      lb_correction                 BOOLEAN;
      lb_update_override            BOOLEAN;
      lb_update_change_insert       BOOLEAN;

      ---Out Variable to update employee

      ld_effective_start_date       Date;
      ld_effective_end_date         Date;
      lc_full_name                  VARCHAR2 (200);
      ln_comment_id                 PER_ALL_PEOPLE_F.COMMENT_ID%TYPE;
      lb_name_combination_warning   BOOLEAN;
      lb_assign_payroll_warning     BOOLEAN;
      lb_orig_hire_warning          BOOLEAN;
      l_warn_ee                     VARCHAR2 (100);

      ------for Assignment update

      ld_a_effective_start_date     PER_ALL_ASSIGNMENTS_F.EFFECTIVE_START_DATE%TYPE;     --Assignment Effective start
      ld_a_effective_end_date       PER_ALL_ASSIGNMENTS_F.EFFECTIVE_END_DATE%TYPE;        --Assignment Effective End
      ln_soft_coding_keyflex_id     HR_SOFT_CODING_KEYFLEX.SOFT_CODING_KEYFLEX_ID%TYPE;
      lc_concatenated_segments       VARCHAR2(2000);

      l_cagr_grade_def_id number;
      l_cagr_concatenated_segments varchar2(1000);
      l_concatenated_segments varchar2(1000);
      l_soft_coding_keyflex_id number;
      l_comment_id number;
      l_effective_start_date date;
      l_effective_end_date date;
      l_no_managers_warning boolean;
      l_other_manager_warning boolean;
      l_hourly_salaried_warning boolean;
      l_gsp_post_process_warning varchar2(1000);





    CURSOR C_EMP_DATA
      IS
           SELECT   *
           FROM   	--CUST.TTEC_ATELKA_EMP_DATA_CUSTOM--Commented code by MXKEERTHI-ARGANO,07/17/2023
	                 apps.TTEC_ATELKA_EMP_DATA_CUSTOM  --code added by MXKEERTHI-ARGANO, 07/17/2023 
           WHERE  EMPLOYEE_STATUS='Active Assignment';
          -- and EMPLOYEE_NUMBER=1044179;

      BEGIN



           DELETE FROM 	--CUST.TTEC_ATELKA_EMP_DATA_CUSTOM--Commented code by MXKEERTHI-ARGANO,07/17/2023
	apps.TTEC_ATELKA_EMP_DATA_CUSTOM  --code added by MXKEERTHI-ARGANO, 07/17/2023 ;
            COMMIT;

            -- fnd_file.put_line(fnd_file.log,'deleting processed data from staging table.');

           fnd_file.put_line(fnd_file.log,'Atelka ESS/MSS Responsibility Enable program' );
           l_total_count := 0;

            BEGIN

            -- fnd_file.put_line(fnd_file.log,'inserting records into staging table.');

                INSERT INTO 	--CUST.TTEC_ATELKA_EMP_DATA_CUSTOM--Commented code by MXKEERTHI-ARGANO,07/17/2023
	                              apps.TTEC_ATELKA_EMP_DATA_CUSTOM  --code added by MXKEERTHI-ARGANO, 07/17/2023 
                                       ( EMPLOYEE_NUMBER,
                                         ADJ_SERVICE_DATE,
                                         LATEST_START_DATE,
                                         SUPERVISOR,
                                         ATELKA_ID,
                                         EMPLOYEE_STATUS,
                                         ATELKA_REAL_TERM_DATE,
                                         ATELKA_TERM_DATE,
                                         EMP_STATUS
                                         )

              SELECT
                                         EMPLOYEE_NUMBER,
                                         ADJ_SERVICE_DATE,
                                         LATEST_START_DATE,
                                         SUPERVISOR,
                                         ATELKA_ID,
                                         EMPLOYEE_STATUS,
                                         ATELKA_REAL_TERM_DATE,
                                         ATELKA_TERM_DATE,
                                         EMP_STATUS
										  --   FROM       CUST.TTEC_ATELKA_EMP_DATA_EXT; --Commented code by MXKEERTHI-ARGANO,07/17/2023
             FROM       apps.TTEC_ATELKA_EMP_DATA_EXT;  --code added by MXKEERTHI-ARGANO, 07/17/2023
 


                   COMMIT;

              -- fnd_file.put_line(fnd_file.log,'NEW RECORDS INSERTED.');

              EXCEPTION WHEN OTHERS THEN
                      fnd_file.put_line(fnd_file.log,'ERROR WHILE INSERTING RECORDS INTO STAGING TABLE . ERROR MESSAGE - '||SUBSTR(SQLERRM,1,100));

            END ;


    FOR I IN C_EMP_DATA LOOP

                  l_total_count := l_total_count +1;
                --  v_person_id :=I.person_id;

              BEGIN
                   select
                         fur.user_id
                   INTO  v_user_id
                    from fnd_user_resp_groups_direct fur,
                         fnd_user fu,
                         Per_all_people_f papf
                    where
                          fu.user_id=fur.user_id
                      and fu.employee_id=papf.person_id
                      and sysdate between papf.effective_start_date and effective_end_date
                      and papf.employee_number=I.EMPLOYEE_NUMBER
                      and fur.end_date is not null
                      and fur.responsibility_id=1002374;


                   EXCEPTION
                   WHEN OTHERS THEN
                    fnd_file.put_line(fnd_file.log, 'No Employees have End dated ESS Responsibility');

                 END;

                -- fnd_file.put_line(fnd_file.log,'User Id:' || v_user_id );


                     BEGIN

                    -- lc_employee_number:=I.employee_number;



                          --------------
                          ---API to Remove End date of the employee
                          --------------
                       apps.fnd_user_resp_groups_api.update_assignment
                                                (user_id => v_user_id,--v_user_id,
                                                 responsibility_id => 1002374,
                                                 responsibility_application_id => 800,
                                                 security_group_id => '3',
                                                 start_date => SYSDATE,
                                                 end_date => NULL,
                                                description => NULL
                                                 );

                        COMMIT;

                   EXCEPTION
                   WHEN OTHERS THEN
                    fnd_file.put_line(fnd_file.log, 'Error for: While Enabling ESS Responsibility' || SUBSTR(SQLERRM,1,1000) );

                        END;

                      -------------For MSS Responsibility ------------------------------

                    --   fnd_file.put_line(fnd_file.log, 'MSS Enable Part Start');

             BEGIN
                      select
                         fur.user_id
                     INTO  v_user_id
                    from fnd_user_resp_groups_direct fur,
                         fnd_user fu,
                         Per_all_people_f papf
                    where
                          fu.user_id=fur.user_id
                      and fu.employee_id=papf.person_id
                      and sysdate between papf.effective_start_date and effective_end_date
                      and papf.employee_number=I.EMPLOYEE_NUMBER
                      and fur.end_date is not null
                      and fur.responsibility_id=1008504;

                 EXCEPTION
                   WHEN OTHERS THEN
                    fnd_file.put_line(fnd_file.log, 'No Employees have End dated MSS Responsibility');

               END;

              -- fnd_file.put_line(fnd_file.log, 'USER ID for MSS:' || v_user_id);


              BEGIN
                          --------------
                          ---API to Remove End date of the employee
                          --------------
                         apps.fnd_user_resp_groups_api.update_assignment
                                                (user_id =>  v_user_id,--v_user_id,
                                                 responsibility_id => 1008504,
                                                 responsibility_application_id => 800,
                                                 security_group_id => '3',
                                                 start_date => SYSDATE,
                                                 end_date => NULL,
                                                description => NULL
                                                 );

                     COMMIT;

                   EXCEPTION
                   WHEN OTHERS THEN
                   ROLLBACK;
                    fnd_file.put_line(fnd_file.log, 'Error for:' ||' '||I.employee_number || 'While Enabling MSS Responsibility' || SUBSTR(SQLERRM,1,1000) );

                 END;


          END LOOP;

         -- fnd_file.put_line(fnd_file.log,'Total Count:' ||' '||l_total_count);

          dbms_output.put_line('Total Count:' ||' '||l_total_count);


     END;


END TTEC_ATELKA_UPD_RESP_PKG;
/
show errors;
/