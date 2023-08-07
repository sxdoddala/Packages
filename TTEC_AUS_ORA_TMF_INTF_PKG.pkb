create or replace PACKAGE BODY ttec_aus_ora_tmf_intf_pkg
IS
    /*$Header:   APPS.TTEC_AUS_ORA_TMF_INTF_PKG 1.0 04-JUN-2019
    == START ==========================================================
       Author:  Arpita/Vaitheghi CTS
         Date:  6/4/2019
         Desc:  This package is to process AUS data to TMF

     Modification History:
     Version   Date          Author      Description (Include Ticket#)
     ----------------------------------------------------------------------
     1.0       04-JUN-2019   CTS            Draft version
     1.1       27-JUL-2021  CChan           Salary Change Date is incorrect, must not consider  the sal.last_update_date, but to stay with sal.change_date
     1.2       17-Oct-2022  Venkat Kovvuri  Added condition to restrict the VF employees
	 1.0	   15-May-2023 IXPRAVEEN(ARGANO)   		R12.2 Upgrade Remediation
   == END ============================================================*/
   PROCEDURE ttec_intf_error (
      p_application_code   VARCHAR2,
      p_program_name       VARCHAR2,
      p_module_name        VARCHAR2,
      p_status             VARCHAR2,
      p_error_code         VARCHAR2,
      p_error_message      VARCHAR2,
      p_label1             VARCHAR2,
      p_reference1         VARCHAR2,
      p_label2             VARCHAR2,
      p_reference2         VARCHAR2
   )
   IS
   BEGIN
      INSERT INTO apps.ttec_aus_intf_error
                  (transaction_id, application_code,
                   INTERFACE, program_name,
                   module_name, concurrent_request_id, status, ERROR_CODE,
                   error_message, label1, reference1, label2,
                   reference2, last_update_date, last_updated_by,
                   creation_date, created_by
                  )
           VALUES (ttec_aus_intf_error_s.NEXTVAL, p_application_code,
                   'Austraila Oracle to TMF Interface', p_program_name,
                   p_module_name, g_conc_req_id, p_status, p_error_code,
                   p_error_message, p_label1, p_reference1, p_label2,
                   p_reference2, SYSDATE, g_user_id,
                   SYSDATE, g_user_id
                  );

      COMMIT;
   EXCEPTION
      WHEN OTHERS
      THEN
         fnd_file.put_line
                    (fnd_file.LOG,
                        'Error while Inserting into ttec_intf_error Table-- '
                     || SQLERRM
                    );
   END ttec_intf_error;

   PROCEDURE ttec_aus_per_change (p_errbuff OUT VARCHAR2, p_retcode OUT NUMBER)
   IS
      v_table_name                   all_tables.table_name%TYPE
                                                       := 'TTEC_AUS_TMF_INTF';
      v_table_owner                  all_tables.owner%TYPE          := 'APPS';
      v_loc                          NUMBER;
      v_select                       VARCHAR2 (500);
      v_from                         VARCHAR2 (500);
      v_where                        VARCHAR2 (15000);
      v_col_pis                      VARCHAR2 (200);
      v_col_pi                       VARCHAR2 (200);
      v_sql                          VARCHAR2 (15000);
      comp_emp                       sys_refcursor;
      v_employee_number              apps.ttec_aus_tmf_intf_stg.employee_number%TYPE;
      v_person_id                    apps.ttec_aus_tmf_intf_stg.person_id%TYPE;
      v_cost_allocation_id           apps.ttec_aus_tmf_intf_stg.cost_allocation_id%TYPE;
      v_personal_payment_method_id   apps.ttec_aus_tmf_intf_stg.personal_payment_method_id%TYPE;
      v_err                          VARCHAR2 (15000);

      CURSOR c_emp_cr
      IS
         SELECT *
           FROM apps.ttec_aus_tmf_intf_stg
          WHERE action_type = 'C';

      CURSOR c_col_pers
      IS
         SELECT column_name, data_type
           FROM all_tab_columns
          WHERE owner = v_table_owner
            AND table_name = v_table_name
            AND column_name IN
                   ('SALUTATION_CODE', 'FIRST_NAME', 'MIDDLE_NAMES',
                    'FAMILY_NAME', 'PREFERRED_NAME', 'PERSON_NAME_INITIALS',
                    'MAIDEN_OR_PREVIOUS_NAME', 'DATE_OF_BIRTH',
                    'COUNTRY_OF_BIRTH', 'GENDER', 'MARITAL_STATUS',
                    'PRIMARY_LANGUAGE', 'NATIONALITY', 'NATIONAL_ID',
                    'NATIONAL_ID_TYPE', 'NATIONAL_ID2', 'NATIONAL_ID2_TYPE',
                    'NATIONAL_ID3', 'NATIONAL_ID3_TYPE', 'NATIONAL_ID4',
                    'NATIONAL_ID4_TYPE');

      emp_rec                        c_emp_cr%ROWTYPE;
      columns_rec                    c_col_pers%ROWTYPE;
   BEGIN
      FOR emp_rec IN c_emp_cr
      LOOP
         v_loc := 100;
         v_select :=
            ' SELECT pis.employee_number, pis.person_id, pis.cost_allocation_id,pis.personal_payment_method_id';
         v_from :=
            ' FROM apps.ttec_aus_tmf_intf_stg pis, apps.ttec_aus_tmf_intf pi ';
         v_where :=
            ' WHERE pis.employee_number = pi.employee_number AND pis.person_id = pi.person_id
                AND nvl(pis.cost_allocation_id,-9999) = nvl(pi.cost_allocation_id,-9999)
                AND nvl(pis.personal_payment_method_id,-9999) = nvl(pi.personal_payment_method_id,-9999)';
         v_loc := 105;

         FOR columns_rec IN c_col_pers
         LOOP
            IF columns_rec.data_type = 'VARCHAR2'
            THEN
               v_col_pis :=
                         ' NVL(pis.' || columns_rec.column_name || ',''*'') ';
               v_col_pi :=
                          ' NVL(pi.' || columns_rec.column_name || ',''*'') ';
            ELSIF columns_rec.data_type = 'NUMBER'
            THEN
               v_col_pis :=
                        ' NVL(pis.' || columns_rec.column_name || ', -9999) ';
               v_col_pi :=
                         ' NVL(pi.' || columns_rec.column_name || ', -9999) ';
            ELSIF columns_rec.data_type = 'DATE'
            THEN
               v_col_pis :=
                     ' NVL(pis.'
                  || columns_rec.column_name
                  || ', ''01-JAN-1000'') ';
               v_col_pi :=
                  ' NVL(pi.' || columns_rec.column_name
                  || ', ''01-JAN-1000'') ';
            END IF;

            v_where := v_where || ' AND ' || v_col_pis || ' = ' || v_col_pi;
            v_loc := 110;
         END LOOP;

         v_loc := 115;
         v_where :=
               v_where
            || ' AND pis.employee_number = NVL(:employee_number, pis.employee_number) ';
         v_where :=
             v_where || ' AND pis.person_id = NVL(:person_id, pis.person_id) ';
         v_where :=
               v_where
            || ' AND nvl(pis.cost_allocation_id,-9999) = NVL(:cost_allocation_id, nvl(pis.cost_allocation_id,-9999))  ';
         v_where :=
               v_where
            || ' AND nvl(pis.personal_payment_method_id,-9999)  = NVL(:personal_payment_method_id, nvl(pis.personal_payment_method_id,-9999))  ';
         v_sql := v_select || v_from || v_where;
         fnd_file.put_line (fnd_file.LOG, 'Dynamic SQL Statement');
         fnd_file.put_line (fnd_file.LOG,
                            '------------------------------------'
                           );
         fnd_file.put_line (fnd_file.LOG, v_sql);
         fnd_file.new_line (fnd_file.LOG, 1);
         v_loc := 120;

         OPEN comp_emp FOR v_sql
         USING emp_rec.employee_number,
               emp_rec.person_id,
               emp_rec.cost_allocation_id,
               emp_rec.personal_payment_method_id;

         LOOP
            v_loc := 125;

            FETCH comp_emp
             INTO v_employee_number, v_person_id, v_cost_allocation_id,
                  v_personal_payment_method_id;

            v_loc := 130;

            IF comp_emp%NOTFOUND
            THEN
               UPDATE apps.ttec_aus_tmf_intf
                  SET effective_date_per_change =
                                             emp_rec.effective_date_per_change,
                      salutation_code = emp_rec.salutation_code,
                      first_name = emp_rec.first_name,
                      middle_names = emp_rec.middle_names,
                      family_name = emp_rec.family_name,
                      preferred_name = emp_rec.preferred_name,
                      person_name_initials = emp_rec.person_name_initials,
                      maiden_or_previous_name =
                                               emp_rec.maiden_or_previous_name,
                      date_of_birth = emp_rec.date_of_birth,
                      country_of_birth = emp_rec.country_of_birth,
                      gender = emp_rec.gender,
                      marital_status = emp_rec.marital_status,
                      primary_language = emp_rec.primary_language,
                      nationality = emp_rec.nationality,
                      national_id = emp_rec.national_id,
                      national_id_type = emp_rec.national_id_type,
                      national_id2 = emp_rec.national_id2,
                      national_id2_type = emp_rec.national_id2_type,
                      national_id3 = emp_rec.national_id3,
                      national_id3_type = emp_rec.national_id3_type,
                      national_id4 = emp_rec.national_id4,
                      national_id4_type = emp_rec.national_id4_type,
                      last_update_date = SYSDATE,
                      last_updated_by = g_user_id,
                      effective_date = SYSDATE,
                      request_id = g_conc_req_id,
                      action_type = emp_rec.action_type
                WHERE employee_number = emp_rec.employee_number
                  AND person_id = emp_rec.person_id
                  AND NVL (cost_allocation_id, '-9999') =
                                     NVL (emp_rec.cost_allocation_id, '-9999')
                  AND NVL (personal_payment_method_id, '-9999') =
                             NVL (emp_rec.personal_payment_method_id, '-9999');
            ELSE
               UPDATE apps.ttec_aus_tmf_intf_stg
                  SET effective_date_per_change = NULL,
                      salutation_code = NULL,
                      first_name = NULL,
                      middle_names = NULL,
                      family_name = NULL,
                      preferred_name = NULL,
                      person_name_initials = NULL,
                      maiden_or_previous_name = NULL,
                      date_of_birth = NULL,
                      country_of_birth = NULL,
                      gender = NULL,
                      marital_status = NULL,
                      primary_language = NULL,
                      nationality = NULL,
                      national_id = NULL,
                      national_id_type = NULL,
                      national_id2 = NULL,
                      national_id2_type = NULL,
                      national_id3 = NULL,
                      national_id3_type = NULL,
                      national_id4 = NULL,
                      national_id4_type = NULL
                WHERE employee_number = emp_rec.employee_number
                  AND person_id = emp_rec.person_id
                  AND NVL (cost_allocation_id, '-9999') =
                                     NVL (emp_rec.cost_allocation_id, '-9999')
                  AND NVL (personal_payment_method_id, '-9999') =
                             NVL (emp_rec.personal_payment_method_id, '-9999');
            END IF;

            EXIT;
            v_loc := 135;
            emp_rec.employee_number := NULL;
            emp_rec.person_id := NULL;
            emp_rec.cost_allocation_id := NULL;
            emp_rec.personal_payment_method_id := NULL;
         END LOOP;

         v_loc := 140;

         CLOSE comp_emp;
      END LOOP;

      COMMIT;
      v_loc := 145;
   EXCEPTION
      WHEN OTHERS
      THEN
         ttec_intf_error (NULL,
                          'ttec_aus_ora_tmf_intf_pkg.ttec_aus_per_change',
                          'Person Change Interface',
                          'Error',
                          v_loc,
                          SQLERRM,
                          'Employee Number',
                          emp_rec.employee_number,
                          'Person ID',
                          emp_rec.person_id
                         );
   END ttec_aus_per_change;

    PROCEDURE ttec_aus_extra_change (p_errbuff OUT VARCHAR2, p_retcode OUT NUMBER)
   IS
      v_table_name                   all_tables.table_name%TYPE
                                                       := 'TTEC_AUS_TMF_INTF';
      v_table_owner                  all_tables.owner%TYPE          := 'APPS';
      v_loc                          NUMBER;
      v_select                       VARCHAR2 (500);
      v_from                         VARCHAR2 (500);
      v_where                        VARCHAR2 (15000);
      v_col_pis                      VARCHAR2 (200);
      v_col_pi                       VARCHAR2 (200);
      v_sql                          VARCHAR2 (15000);
      comp_emp                       sys_refcursor;
      v_employee_number              apps.ttec_aus_tmf_intf_stg.employee_number%TYPE;
      v_person_id                    apps.ttec_aus_tmf_intf_stg.person_id%TYPE;
      v_cost_allocation_id           apps.ttec_aus_tmf_intf_stg.cost_allocation_id%TYPE;
      v_personal_payment_method_id   apps.ttec_aus_tmf_intf_stg.personal_payment_method_id%TYPE;
      v_err                          VARCHAR2 (15000);

      CURSOR c_emp_cr
      IS
         SELECT *
           FROM apps.ttec_aus_tmf_intf_stg
          WHERE action_type = 'C';

      CURSOR c_col_pers
      IS
         SELECT column_name, data_type
           FROM all_tab_columns
          WHERE owner = v_table_owner
            AND table_name = v_table_name
            AND column_name IN
                   ('AUSTRALIAN_RESD_TAX_PURPOSE','TAX_FREE_THRESH_CLAIMED_OR_NOT','HECS_DEBT',
                    'SFSS_DEBT', 'SUPER_FUND_NAME','TAX_FILE_NUMBER','EMP_FUND_MEMBERSHIP_NUMBER'
                    );

      emp_rec                        c_emp_cr%ROWTYPE;
      columns_rec                    c_col_pers%ROWTYPE;
   BEGIN
      FOR emp_rec IN c_emp_cr
      LOOP
         v_loc := 100;
         v_select :=
            ' SELECT pis.employee_number, pis.person_id, pis.cost_allocation_id,pis.personal_payment_method_id';
         v_from :=
            ' FROM apps.ttec_aus_tmf_intf_stg pis, apps.ttec_aus_tmf_intf pi ';
         v_where :=
            ' WHERE pis.employee_number = pi.employee_number AND pis.person_id = pi.person_id
                AND nvl(pis.cost_allocation_id,-9999) = nvl(pi.cost_allocation_id,-9999)
                AND nvl(pis.personal_payment_method_id,-9999) = nvl(pi.personal_payment_method_id,-9999)';
         v_loc := 105;

         FOR columns_rec IN c_col_pers
         LOOP
            IF columns_rec.data_type = 'VARCHAR2'
            THEN
               v_col_pis :=
                         ' NVL(pis.' || columns_rec.column_name || ',''*'') ';
               v_col_pi :=
                          ' NVL(pi.' || columns_rec.column_name || ',''*'') ';
            ELSIF columns_rec.data_type = 'NUMBER'
            THEN
               v_col_pis :=
                        ' NVL(pis.' || columns_rec.column_name || ', -9999) ';
               v_col_pi :=
                         ' NVL(pi.' || columns_rec.column_name || ', -9999) ';
            ELSIF columns_rec.data_type = 'DATE'
            THEN
               v_col_pis :=
                     ' NVL(pis.'
                  || columns_rec.column_name
                  || ', ''01-JAN-1000'') ';
               v_col_pi :=
                  ' NVL(pi.' || columns_rec.column_name
                  || ', ''01-JAN-1000'') ';
            END IF;

            v_where := v_where || ' AND ' || v_col_pis || ' = ' || v_col_pi;
            v_loc := 110;
         END LOOP;

         v_loc := 115;
         v_where :=
               v_where
            || ' AND pis.employee_number = NVL(:employee_number, pis.employee_number) ';
         v_where :=
             v_where || ' AND pis.person_id = NVL(:person_id, pis.person_id) ';
         v_where :=
               v_where
            || ' AND nvl(pis.cost_allocation_id,-9999) = NVL(:cost_allocation_id, nvl(pis.cost_allocation_id,-9999))  ';
         v_where :=
               v_where
            || ' AND nvl(pis.personal_payment_method_id,-9999)  = NVL(:personal_payment_method_id, nvl(pis.personal_payment_method_id,-9999))  ';
         v_sql := v_select || v_from || v_where;
         fnd_file.put_line (fnd_file.LOG, 'Dynamic SQL Statement');
         fnd_file.put_line (fnd_file.LOG,
                            '------------------------------------'
                           );
         fnd_file.put_line (fnd_file.LOG, v_sql);
         fnd_file.new_line (fnd_file.LOG, 1);
         v_loc := 120;

         OPEN comp_emp FOR v_sql
         USING emp_rec.employee_number,
               emp_rec.person_id,
               emp_rec.cost_allocation_id,
               emp_rec.personal_payment_method_id;

         LOOP
            v_loc := 125;

            FETCH comp_emp
             INTO v_employee_number, v_person_id, v_cost_allocation_id,
                  v_personal_payment_method_id;

            v_loc := 130;

            IF comp_emp%NOTFOUND
            THEN
               UPDATE apps.ttec_aus_tmf_intf
                  SET effective_date_per_change =
                                             emp_rec.effective_date_per_change,
				  AUSTRALIAN_RESD_TAX_PURPOSE = emp_rec.AUSTRALIAN_RESD_TAX_PURPOSE,
                      TAX_FREE_THRESH_CLAIMED_OR_NOT = emp_rec.TAX_FREE_THRESH_CLAIMED_OR_NOT,
                      HECS_DEBT = emp_rec.HECS_DEBT,
                      SFSS_DEBT = emp_rec.SFSS_DEBT,
                      SUPER_FUND_NAME = emp_rec.SUPER_FUND_NAME,
                      TAX_FILE_NUMBER = emp_rec.TAX_FILE_NUMBER,
					  EMP_FUND_MEMBERSHIP_NUMBER=emp_rec.EMP_FUND_MEMBERSHIP_NUMBER
                      WHERE employee_number = emp_rec.employee_number
                  AND person_id = emp_rec.person_id
                  AND NVL (cost_allocation_id, '-9999') =
                                     NVL (emp_rec.cost_allocation_id, '-9999')
                  AND NVL (personal_payment_method_id, '-9999') =
                             NVL (emp_rec.personal_payment_method_id, '-9999');
            ELSE
               UPDATE apps.ttec_aus_tmf_intf_stg
                  SET effective_date_per_change=NULL,
				  AUSTRALIAN_RESD_TAX_PURPOSE = NULL,
                      TAX_FREE_THRESH_CLAIMED_OR_NOT = NULL,
                      HECS_DEBT = NULL,
                      SFSS_DEBT = NULL,
                      SUPER_FUND_NAME = NULL,
                      TAX_FILE_NUMBER = NULL,
					  EMP_FUND_MEMBERSHIP_NUMBER=NULL
                      WHERE employee_number = emp_rec.employee_number
                  AND person_id = emp_rec.person_id
                  AND NVL (cost_allocation_id, '-9999') =
                                     NVL (emp_rec.cost_allocation_id, '-9999')
                  AND NVL (personal_payment_method_id, '-9999') =
                             NVL (emp_rec.personal_payment_method_id, '-9999');
            END IF;

            EXIT;
            v_loc := 135;
            emp_rec.employee_number := NULL;
            emp_rec.person_id := NULL;
            emp_rec.cost_allocation_id := NULL;
            emp_rec.personal_payment_method_id := NULL;
         END LOOP;

         v_loc := 140;

         CLOSE comp_emp;
      END LOOP;

      COMMIT;
      v_loc := 145;
   EXCEPTION
      WHEN OTHERS
      THEN
         ttec_intf_error (NULL,
                          'ttec_aus_ora_tmf_intf_pkg.ttec_aus_per_change',
                          'Person Change Interface',
                          'Error',
                          v_loc,
                          SQLERRM,
                          'Employee Number',
                          emp_rec.employee_number,
                          'Person ID',
                          emp_rec.person_id
                         );
   END ttec_aus_extra_change;

   PROCEDURE ttec_aus_asg_change (p_errbuff OUT VARCHAR2, p_retcode OUT NUMBER)
   AS
      v_table_name                   all_tables.table_name%TYPE
                                                       := 'TTEC_AUS_TMF_INTF';
      v_table_owner                  all_tables.owner%TYPE          := 'APPS';
      v_loc                          NUMBER;
      v_select                       VARCHAR2 (500);
      v_from                         VARCHAR2 (500);
      v_where                        VARCHAR2 (15000);
      v_col_pis                      VARCHAR2 (200);
      v_col_pi                       VARCHAR2 (200);
      v_sql                          VARCHAR2 (15000);
      comp_emp                       sys_refcursor;
      v_employee_number              apps.ttec_aus_tmf_intf_stg.employee_number%TYPE;
      v_person_id                    apps.ttec_aus_tmf_intf_stg.person_id%TYPE;
      v_cost_allocation_id           apps.ttec_aus_tmf_intf_stg.cost_allocation_id%TYPE;
      v_personal_payment_method_id   apps.ttec_aus_tmf_intf_stg.personal_payment_method_id%TYPE;
      v_err                          VARCHAR2 (15000);

      CURSOR c_emp_cr
      IS
         SELECT *
           FROM apps.ttec_aus_tmf_intf_stg
          WHERE action_type = 'C';

      CURSOR c_columns_pers
      IS
         SELECT column_name, data_type
           FROM all_tab_columns
          WHERE owner = v_table_owner
            AND table_name = v_table_name
            AND column_name IN
                   ('HIRE_DATE', 'CONTINUOUS_SERVICE_DATE', 'CONTRACT_TYPE',
                    'PERIOD_TYPE', 'JOB_TITLE', 'COST_CENTER_CODE',
                    'COST_CENTER_NAME', 'COST_CENTRE_ALLO_SPLIT_PERCNT',
                    'DEPARTMENT_CODE', 'DEPARTMENT_NAME',
                    'OTHER_COST_ALLOCATION_CODE',
                    'OTHER_COST_ALLOCATION_NAME', 'WORK_LOCATION',
                    'GCA_LEVEL');

      emp_rec                        c_emp_cr%ROWTYPE;
      columns_rec                    c_columns_pers%ROWTYPE;
   BEGIN
      FOR emp_rec IN c_emp_cr
      LOOP
         v_loc := 150;
         v_select :=
            ' SELECT pis.employee_number, pis.person_id, pis.cost_allocation_id,pis.personal_payment_method_id';
         v_from :=
            ' FROM apps.ttec_aus_tmf_intf_stg pis, apps.TTEC_AUS_TMF_INTF pi ';
         v_where :=
            ' WHERE pis.employee_number = pi.employee_number AND pis.person_id = pi.person_id
                AND nvl(pis.cost_allocation_id,-9999) = nvl(pi.cost_allocation_id,-9999)
                AND nvl(pis.personal_payment_method_id,-9999) = nvl(pi.personal_payment_method_id,-9999)';
         v_loc := 155;

         FOR columns_rec IN c_columns_pers
         LOOP
            IF columns_rec.data_type = 'VARCHAR2'
            THEN
               v_col_pis :=
                         ' NVL(pis.' || columns_rec.column_name || ',''*'') ';
               v_col_pi :=
                          ' NVL(pi.' || columns_rec.column_name || ',''*'') ';
            ELSIF columns_rec.data_type = 'NUMBER'
            THEN
               v_col_pis :=
                        ' NVL(pis.' || columns_rec.column_name || ', -9999) ';
               v_col_pi :=
                         ' NVL(pi.' || columns_rec.column_name || ', -9999) ';
            ELSIF columns_rec.data_type = 'DATE'
            THEN
               v_col_pis :=
                     ' NVL(pis.'
                  || columns_rec.column_name
                  || ', ''01-JAN-1000'') ';
               v_col_pi :=
                  ' NVL(pi.' || columns_rec.column_name
                  || ', ''01-JAN-1000'') ';
            END IF;

            v_where := v_where || ' AND ' || v_col_pis || ' = ' || v_col_pi;
            v_loc := 160;
         END LOOP;

         v_loc := 165;
         v_where :=
               v_where
            || ' AND pis.employee_number = NVL(:employee_number, pis.employee_number) ';
         v_where :=
             v_where || ' AND pis.person_id = NVL(:person_id, pis.person_id) ';
         v_where :=
               v_where
            || 'AND nvl(pis.cost_allocation_id,-9999) = NVL(:cost_allocation_id, nvl(pis.cost_allocation_id,-9999)) ';
         v_where :=
               v_where
            || ' AND nvl(pis.personal_payment_method_id,-9999) = NVL(:personal_payment_method_id, nvl(pis.personal_payment_method_id,-9999)) ';
         v_sql := v_select || v_from || v_where;
         fnd_file.put_line (fnd_file.LOG, 'Dynamic SQL Statement');
         fnd_file.put_line (fnd_file.LOG,
                            '------------------------------------'
                           );
         fnd_file.put_line (fnd_file.LOG, v_sql);
         fnd_file.new_line (fnd_file.LOG, 1);
         v_loc := 170;

         OPEN comp_emp FOR v_sql
         USING emp_rec.employee_number,
               emp_rec.person_id,
               emp_rec.cost_allocation_id,
               emp_rec.personal_payment_method_id;

         LOOP
            v_loc := 175;

            FETCH comp_emp
             INTO v_employee_number, v_person_id, v_cost_allocation_id,
                  v_personal_payment_method_id;

            v_loc := 180;

            IF comp_emp%NOTFOUND
            THEN
               UPDATE apps.ttec_aus_tmf_intf
                  SET effective_date_contract_change =
                                        emp_rec.effective_date_contract_change,
                      hire_date = emp_rec.hire_date,
                      continuous_service_date =
                                               emp_rec.continuous_service_date,
                      contract_type = emp_rec.contract_type,
                      period_type = emp_rec.period_type,
                      job_title = emp_rec.job_title,
                      cost_center_code = emp_rec.cost_center_code,
                      cost_center_name = emp_rec.cost_center_name,
                      cost_centre_allo_split_percnt =
                                         emp_rec.cost_centre_allo_split_percnt,
                      department_code = emp_rec.department_code,
                      department_name = emp_rec.department_name,
                      other_cost_allocation_code =
                                            emp_rec.other_cost_allocation_code,
                      other_cost_allocation_name =
                                            emp_rec.other_cost_allocation_name,
                      work_location = emp_rec.work_location,
                      gca_level = emp_rec.gca_level,
                      last_update_date = SYSDATE,
                      last_updated_by = g_user_id,
                      effective_date = SYSDATE,
                      request_id = g_conc_req_id,
                      action_type = emp_rec.action_type
                WHERE employee_number = emp_rec.employee_number
                  AND person_id = emp_rec.person_id
                  AND NVL (cost_allocation_id, '-9999') =
                                     NVL (emp_rec.cost_allocation_id, '-9999')
                  AND NVL (personal_payment_method_id, '-9999') =
                             NVL (emp_rec.personal_payment_method_id, '-9999');
            ELSE
               UPDATE apps.ttec_aus_tmf_intf_stg
                  SET effective_date_contract_change = NULL,
                      hire_date = NULL,
                      continuous_service_date = NULL,
                      contract_type = NULL,
                      period_type = NULL,
                      job_title = NULL,
                      cost_center_code = NULL,
                      cost_center_name = NULL,
                      cost_centre_allo_split_percnt = NULL,
                      department_code = NULL,
                      department_name = NULL,
                      other_cost_allocation_code = NULL,
                      other_cost_allocation_name = NULL,
                      work_location = NULL,
                      gca_level = NULL
                WHERE employee_number = emp_rec.employee_number
                  AND person_id = emp_rec.person_id
                  AND NVL (cost_allocation_id, '-9999') =
                                     NVL (emp_rec.cost_allocation_id, '-9999')
                  AND NVL (personal_payment_method_id, '-9999') =
                             NVL (emp_rec.personal_payment_method_id, '-9999');
            END IF;

            EXIT;
            v_loc := 185;
            emp_rec.employee_number := NULL;
            emp_rec.person_id := NULL;
            emp_rec.cost_allocation_id := NULL;
            emp_rec.personal_payment_method_id := NULL;
         END LOOP;

         v_loc := 190;

         CLOSE comp_emp;
      END LOOP;

      COMMIT;
      v_loc := 195;
   EXCEPTION
      WHEN OTHERS
      THEN
         ttec_intf_error (NULL,
                          'ttec_aus_ora_tmf_intf_pkg.ttec_aus_asg_change',
                          'Assignment Change Interface',
                          'Error',
                          v_loc,
                          SQLERRM,
                          'Employee Number',
                          emp_rec.employee_number,
                          'Person ID',
                          emp_rec.person_id
                         );
   END ttec_aus_asg_change;

   PROCEDURE ttec_aus_address_change (
      p_errbuff   OUT   VARCHAR2,
      p_retcode   OUT   NUMBER
   )
   AS
      v_table_name                   all_tables.table_name%TYPE
                                                       := 'TTEC_AUS_TMF_INTF';
      v_table_owner                  all_tables.owner%TYPE          := 'APPS';
      v_loc                          NUMBER;
      v_select                       VARCHAR2 (500);
      v_from                         VARCHAR2 (500);
      v_where                        VARCHAR2 (15000);
      v_col_pis                      VARCHAR2 (200);
      v_col_pi                       VARCHAR2 (200);
      v_sql                          VARCHAR2 (15000);
      comp_emp                       sys_refcursor;
      v_employee_number              apps.ttec_aus_tmf_intf_stg.employee_number%TYPE;
      v_person_id                    apps.ttec_aus_tmf_intf_stg.person_id%TYPE;
      v_cost_allocation_id           apps.ttec_aus_tmf_intf_stg.cost_allocation_id%TYPE;
      v_personal_payment_method_id   apps.ttec_aus_tmf_intf_stg.personal_payment_method_id%TYPE;
      v_err                          VARCHAR2 (15000);

      CURSOR c_emp_cr
      IS
         SELECT *
           FROM apps.ttec_aus_tmf_intf_stg
          WHERE action_type = 'C';

      CURSOR c_columns_pers
      IS
         SELECT column_name, data_type
           FROM all_tab_columns
          WHERE owner = v_table_owner
            AND table_name = v_table_name
            AND column_name IN
                   ('BUILDING_NUMBER', 'ADDRESS_LINE1', 'ADDRESS_LINE2',
                    'ADDRESS_LINE3', 'ADDRESS_LINE4', 'CITY_NAME',
                    'POSTAL_CODE', 'STATE', 'COUNTRY', 'EMAIL_ADDRESS');

      emp_rec                        c_emp_cr%ROWTYPE;
      columns_rec                    c_columns_pers%ROWTYPE;
   BEGIN
      FOR emp_rec IN c_emp_cr
      LOOP
         v_loc := 200;
         v_select :=
            ' SELECT pis.employee_number, pis.person_id, pis.cost_allocation_id,pis.personal_payment_method_id';
         v_from :=
            ' FROM apps.ttec_aus_tmf_intf_stg pis, apps.TTEC_AUS_TMF_INTF pi ';
         v_where :=
            ' WHERE pis.employee_number = pi.employee_number AND pis.person_id = pi.person_id
                AND nvl(pis.cost_allocation_id,-9999) = nvl(pi.cost_allocation_id,-9999)
                AND nvl(pis.personal_payment_method_id,-9999) = nvl(pi.personal_payment_method_id,-9999)';
         v_loc := 205;

         FOR columns_rec IN c_columns_pers
         LOOP
            IF columns_rec.data_type = 'VARCHAR2'
            THEN
               v_col_pis :=
                         ' NVL(pis.' || columns_rec.column_name || ',''*'') ';
               v_col_pi :=
                          ' NVL(pi.' || columns_rec.column_name || ',''*'') ';
            ELSIF columns_rec.data_type = 'NUMBER'
            THEN
               v_col_pis :=
                        ' NVL(pis.' || columns_rec.column_name || ', -9999) ';
               v_col_pi :=
                         ' NVL(pi.' || columns_rec.column_name || ', -9999) ';
            ELSIF columns_rec.data_type = 'DATE'
            THEN
               v_col_pis :=
                     ' NVL(pis.'
                  || columns_rec.column_name
                  || ', ''01-JAN-1000'') ';
               v_col_pi :=
                  ' NVL(pi.' || columns_rec.column_name
                  || ', ''01-JAN-1000'') ';
            END IF;

            v_where := v_where || ' AND ' || v_col_pis || ' = ' || v_col_pi;
            v_loc := 210;
         END LOOP;

         v_loc := 215;
         v_where :=
               v_where
            || ' AND pis.employee_number = NVL(:employee_number, pis.employee_number) ';
         v_where :=
             v_where || ' AND pis.person_id = NVL(:person_id, pis.person_id) ';
         v_where :=
               v_where
            || ' AND nvl(pis.cost_allocation_id,-9999) = NVL(:cost_allocation_id, nvl(pis.cost_allocation_id,-9999)) ';
         v_where :=
               v_where
            || ' AND nvl(pis.personal_payment_method_id,-9999)  = NVL(:personal_payment_method_id, nvl(pis.personal_payment_method_id,-9999)) ';
         v_sql := v_select || v_from || v_where;
         fnd_file.put_line (fnd_file.LOG, 'Dynamic SQL Statement');
         fnd_file.put_line (fnd_file.LOG,
                            '------------------------------------'
                           );
         fnd_file.put_line (fnd_file.LOG, v_sql);
         fnd_file.new_line (fnd_file.LOG, 1);
         v_loc := 220;

         OPEN comp_emp FOR v_sql
         USING emp_rec.employee_number,
               emp_rec.person_id,
               emp_rec.cost_allocation_id,
               emp_rec.personal_payment_method_id;

         LOOP
            v_loc := 225;

            FETCH comp_emp
             INTO v_employee_number, v_person_id, v_cost_allocation_id,
                  v_personal_payment_method_id;

            v_loc := 230;

            IF comp_emp%NOTFOUND
            THEN
               UPDATE apps.ttec_aus_tmf_intf
                  SET effective_date_address_change =
                                         emp_rec.effective_date_address_change,
                      building_number = emp_rec.building_number,
                      address_line1 = emp_rec.address_line1,
                      address_line2 = emp_rec.address_line2,
                      address_line3 = emp_rec.address_line3,
                      address_line4 = emp_rec.address_line4,
                      city_name = emp_rec.city_name,
                      postal_code = emp_rec.postal_code,
                      state = emp_rec.state,
                      country = emp_rec.country,
                      email_address = emp_rec.email_address,
                      last_update_date = SYSDATE,
                      last_updated_by = g_user_id,
                      effective_date = SYSDATE,
                      request_id = g_conc_req_id,
                      action_type = emp_rec.action_type
                WHERE employee_number = emp_rec.employee_number
                  AND person_id = emp_rec.person_id
                  AND NVL (cost_allocation_id, '-9999') =
                                     NVL (emp_rec.cost_allocation_id, '-9999')
                  AND NVL (personal_payment_method_id, '-9999') =
                             NVL (emp_rec.personal_payment_method_id, '-9999');
            ELSE
               UPDATE apps.ttec_aus_tmf_intf_stg
                  SET effective_date_address_change = NULL,
                      building_number = NULL,
                      address_line1 = NULL,
                      address_line2 = NULL,
                      address_line3 = NULL,
                      address_line4 = NULL,
                      city_name = NULL,
                      postal_code = NULL,
                      state = NULL,
                      country = NULL,
                      email_address = NULL
                WHERE employee_number = emp_rec.employee_number
                  AND person_id = emp_rec.person_id
                  AND NVL (cost_allocation_id, '-9999') =
                                     NVL (emp_rec.cost_allocation_id, '-9999')
                  AND NVL (personal_payment_method_id, '-9999') =
                             NVL (emp_rec.personal_payment_method_id, '-9999');
            END IF;

            EXIT;
            v_loc := 235;
            emp_rec.employee_number := NULL;
            emp_rec.person_id := NULL;
            emp_rec.cost_allocation_id := NULL;
            emp_rec.personal_payment_method_id := NULL;
         END LOOP;

         v_loc := 240;

         CLOSE comp_emp;
      END LOOP;

      COMMIT;
      v_loc := 245;
   EXCEPTION
      WHEN OTHERS
      THEN
         ttec_intf_error
                        (NULL,
                         'ttec_aus_ora_tmf_intf_pkg.ttec_aus_address_change',
                         'Address change Interface',
                         'Error',
                         v_loc,
                         SQLERRM,
                         'Employee Number',
                         emp_rec.employee_number,
                         'Person ID',
                         emp_rec.person_id
                        );
   END ttec_aus_address_change;

   PROCEDURE ttec_aus_schedule_change (
      p_errbuff   OUT   VARCHAR2,
      p_retcode   OUT   NUMBER
   )
   AS
      v_table_name                   all_tables.table_name%TYPE
                                                       := 'TTEC_AUS_TMF_INTF';
      v_table_owner                  all_tables.owner%TYPE          := 'APPS';
      v_loc                          NUMBER;
      v_select                       VARCHAR2 (500);
      v_from                         VARCHAR2 (500);
      v_where                        VARCHAR2 (15000);
      v_col_pis                      VARCHAR2 (200);
      v_col_pi                       VARCHAR2 (200);
      v_sql                          VARCHAR2 (15000);
      comp_emp                       sys_refcursor;
      v_employee_number              apps.ttec_aus_tmf_intf_stg.employee_number%TYPE;
      v_person_id                    apps.ttec_aus_tmf_intf_stg.person_id%TYPE;
      v_cost_allocation_id           apps.ttec_aus_tmf_intf_stg.cost_allocation_id%TYPE;
      v_personal_payment_method_id   apps.ttec_aus_tmf_intf_stg.personal_payment_method_id%TYPE;
      v_err                          VARCHAR2 (15000);

      CURSOR c_emp_cr
      IS
         SELECT *
           FROM apps.ttec_aus_tmf_intf_stg
          WHERE action_type = 'C';

      CURSOR c_columns_pers
      IS
         SELECT column_name, data_type
           FROM all_tab_columns
          WHERE owner = v_table_owner
            AND table_name = v_table_name
            AND column_name IN
                   ('FULLTIME_OR_PARTTIME', 'PERCENTAGE_WORKING',
                    'CONTRACTED_WEEKLY_HOURS', 'WORK_SCHEDULE_CODE',
                    'WORK_SCHEDULE_DESCRIPTION');

      emp_rec                        c_emp_cr%ROWTYPE;
      columns_rec                    c_columns_pers%ROWTYPE;
   BEGIN
      FOR emp_rec IN c_emp_cr
      LOOP
         v_loc := 250;
         v_select :=
            ' SELECT pis.employee_number, pis.person_id, pis.cost_allocation_id,pis.personal_payment_method_id';
         v_from :=
            ' FROM apps.ttec_aus_tmf_intf_stg pis, apps.TTEC_AUS_TMF_INTF pi ';
         v_where :=
            ' WHERE pis.employee_number = pi.employee_number AND pis.person_id = pi.person_id
                     AND nvl(pis.cost_allocation_id,-9999) = nvl(pi.cost_allocation_id,-9999)
                AND nvl(pis.personal_payment_method_id,-9999) = nvl(pi.personal_payment_method_id,-9999)';
         v_loc := 255;

         FOR columns_rec IN c_columns_pers
         LOOP
            IF columns_rec.data_type = 'VARCHAR2'
            THEN
               v_col_pis :=
                         ' NVL(pis.' || columns_rec.column_name || ',''*'') ';
               v_col_pi :=
                          ' NVL(pi.' || columns_rec.column_name || ',''*'') ';
            ELSIF columns_rec.data_type = 'NUMBER'
            THEN
               v_col_pis :=
                        ' NVL(pis.' || columns_rec.column_name || ', -9999) ';
               v_col_pi :=
                         ' NVL(pi.' || columns_rec.column_name || ', -9999) ';
            ELSIF columns_rec.data_type = 'DATE'
            THEN
               v_col_pis :=
                     ' NVL(pis.'
                  || columns_rec.column_name
                  || ', ''01-JAN-1000'') ';
               v_col_pi :=
                  ' NVL(pi.' || columns_rec.column_name
                  || ', ''01-JAN-1000'') ';
            END IF;

            v_where := v_where || ' AND ' || v_col_pis || ' = ' || v_col_pi;
            v_loc := 260;
         END LOOP;

         v_loc := 265;
         v_where :=
               v_where
            || ' AND pis.employee_number = NVL(:employee_number, pis.employee_number) ';
         v_where :=
             v_where || ' AND pis.person_id = NVL(:person_id, pis.person_id) ';
         v_where :=
               v_where
            || ' AND  nvl(pis.cost_allocation_id,-9999) = NVL(:cost_allocation_id, nvl(pis.cost_allocation_id,-9999)) ';
         v_where :=
               v_where
            || ' AND nvl(pis.personal_payment_method_id,-9999) = NVL(:personal_payment_method_id, nvl(pis.personal_payment_method_id,-9999)) ';
         v_sql := v_select || v_from || v_where;
         fnd_file.put_line (fnd_file.LOG, 'Dynamic SQL Statement');
         fnd_file.put_line (fnd_file.LOG,
                            '------------------------------------'
                           );
         fnd_file.put_line (fnd_file.LOG, v_sql);
         fnd_file.new_line (fnd_file.LOG, 1);
         v_loc := 270;

         OPEN comp_emp FOR v_sql
         USING emp_rec.employee_number,
               emp_rec.person_id,
               emp_rec.cost_allocation_id,
               emp_rec.personal_payment_method_id;

         LOOP
            v_loc := 275;

            FETCH comp_emp
             INTO v_employee_number, v_person_id, v_cost_allocation_id,
                  v_personal_payment_method_id;

            v_loc := 280;

            IF comp_emp%NOTFOUND
            THEN
               UPDATE apps.ttec_aus_tmf_intf
                  SET effective_date_schedule_change =
                                        emp_rec.effective_date_schedule_change,
                      fulltime_or_parttime = emp_rec.fulltime_or_parttime,
                      percentage_working = emp_rec.percentage_working,
                      contracted_weekly_hours =
                                               emp_rec.contracted_weekly_hours,
                      work_schedule_code = emp_rec.work_schedule_code,
                      work_schedule_description =
                                             emp_rec.work_schedule_description,
                      last_update_date = SYSDATE,
                      last_updated_by = g_user_id,
                      effective_date = SYSDATE,
                      request_id = g_conc_req_id,
                      action_type = emp_rec.action_type
                WHERE employee_number = emp_rec.employee_number
                  AND person_id = emp_rec.person_id
                  AND NVL (cost_allocation_id, '-9999') =
                                     NVL (emp_rec.cost_allocation_id, '-9999')
                  AND NVL (personal_payment_method_id, '-9999') =
                             NVL (emp_rec.personal_payment_method_id, '-9999');
            ELSE
               UPDATE apps.ttec_aus_tmf_intf_stg
                  SET effective_date_schedule_change = NULL,
                      fulltime_or_parttime = NULL,
                      percentage_working = NULL,
                      contracted_weekly_hours = NULL,
                      work_schedule_code = NULL,
                      work_schedule_description = NULL
                WHERE employee_number = emp_rec.employee_number
                  AND person_id = emp_rec.person_id
                  AND NVL (cost_allocation_id, '-9999') =
                                     NVL (emp_rec.cost_allocation_id, '-9999')
                  AND NVL (personal_payment_method_id, '-9999') =
                             NVL (emp_rec.personal_payment_method_id, '-9999');
            END IF;

            EXIT;
            v_loc := 285;
            emp_rec.employee_number := NULL;
            emp_rec.person_id := NULL;
            emp_rec.cost_allocation_id := NULL;
            emp_rec.personal_payment_method_id := NULL;
         END LOOP;

         v_loc := 290;

         CLOSE comp_emp;
      END LOOP;

      COMMIT;
      v_loc := 295;
   EXCEPTION
      WHEN OTHERS
      THEN
         ttec_intf_error
                       (NULL,
                        'ttec_aus_ora_tmf_intf_pkg.ttec_aus_schedule_change',
                        'Schedule Change Interface',
                        'Error',
                        v_loc,
                        SQLERRM,
                        'Employee Number',
                        emp_rec.employee_number,
                        'Person ID',
                        emp_rec.person_id
                       );
   END ttec_aus_schedule_change;

   PROCEDURE ttec_aus_bank_change (p_errbuff OUT VARCHAR2, p_retcode OUT NUMBER)
   AS
      v_table_name                   all_tables.table_name%TYPE
                                                       := 'TTEC_AUS_TMF_INTF';
      v_table_owner                  all_tables.owner%TYPE          := 'APPS';
      v_loc                          NUMBER;
      v_select                       VARCHAR2 (500);
      v_from                         VARCHAR2 (500);
      v_where                        VARCHAR2 (15000);
      v_col_pis                      VARCHAR2 (200);
      v_col_pi                       VARCHAR2 (200);
      v_sql                          VARCHAR2 (15000);
      comp_emp                       sys_refcursor;
      v_employee_number              apps.ttec_aus_tmf_intf_stg.employee_number%TYPE;
      v_person_id                    apps.ttec_aus_tmf_intf_stg.person_id%TYPE;
      v_cost_allocation_id           apps.ttec_aus_tmf_intf_stg.cost_allocation_id%TYPE;
      v_personal_payment_method_id   apps.ttec_aus_tmf_intf_stg.personal_payment_method_id%TYPE;
      v_err                          VARCHAR2 (15000);

      CURSOR c_emp_cr
      IS
         SELECT *
           FROM apps.ttec_aus_tmf_intf_stg
          WHERE action_type = 'C';

      CURSOR c_columns_pers
      IS
         SELECT column_name, data_type
           FROM all_tab_columns
          WHERE owner = v_table_owner
            AND table_name = v_table_name
            AND column_name IN
                   ('PAYMENT_METHOD', 'ACCOUNT_TYPE', 'SWIFT_OR_BIC_CODE',
                    'LOCAL_BANK_CODE', 'BANK_NAME', 'BRANCH_CODE',
                    'BANK_ACCOUNT_NUMBER', 'ADDITIONAL_ACCOUNT_ID',
                    'ACCOUNT_NAME', 'IBAN_NUMBER', 'BANK_COUNTRY_CODE',
                    'CURRENCY_CODE', 'PAYMENT_DISTRIBUTION_AMOUNT',
                    'PAYMENT_DISTRIBUTION_PERCENT');

      emp_rec                        c_emp_cr%ROWTYPE;
      columns_rec                    c_columns_pers%ROWTYPE;
   BEGIN
      FOR emp_rec IN c_emp_cr
      LOOP
         v_loc := 300;
         v_select :=
            ' SELECT pis.employee_number, pis.person_id, pis.cost_allocation_id,pis.personal_payment_method_id';
         v_from :=
            ' FROM apps.ttec_aus_tmf_intf_stg pis, apps.TTEC_AUS_TMF_INTF pi ';
         v_where :=
            ' WHERE pis.employee_number = pi.employee_number AND pis.person_id = pi.person_id
                     AND nvl(pis.cost_allocation_id,-9999) = nvl(pi.cost_allocation_id,-9999)
                AND nvl(pis.personal_payment_method_id,-9999) = nvl(pi.personal_payment_method_id,-9999)';
         v_loc := 305;

         FOR columns_rec IN c_columns_pers
         LOOP
            IF columns_rec.data_type = 'VARCHAR2'
            THEN
               v_col_pis :=
                         ' NVL(pis.' || columns_rec.column_name || ',''*'') ';
               v_col_pi :=
                          ' NVL(pi.' || columns_rec.column_name || ',''*'') ';
            ELSIF columns_rec.data_type = 'NUMBER'
            THEN
               v_col_pis :=
                        ' NVL(pis.' || columns_rec.column_name || ', -9999) ';
               v_col_pi :=
                         ' NVL(pi.' || columns_rec.column_name || ', -9999) ';
            ELSIF columns_rec.data_type = 'DATE'
            THEN
               v_col_pis :=
                     ' NVL(pis.'
                  || columns_rec.column_name
                  || ', ''01-JAN-1000'') ';
               v_col_pi :=
                  ' NVL(pi.' || columns_rec.column_name
                  || ', ''01-JAN-1000'') ';
            END IF;

            v_where := v_where || ' AND ' || v_col_pis || ' = ' || v_col_pi;
            v_loc := 310;
         END LOOP;

         v_loc := 315;
         v_where :=
               v_where
            || ' AND pis.employee_number = NVL(:employee_number, pis.employee_number) ';
         v_where :=
             v_where || ' AND pis.person_id = NVL(:person_id, pis.person_id) ';
         v_where :=
               v_where
            || ' AND nvl(pis.cost_allocation_id,-9999) = NVL(:cost_allocation_id, nvl(pis.cost_allocation_id,-9999)) ';
         v_where :=
               v_where
            || ' AND nvl(pis.personal_payment_method_id,-9999)  = NVL(:personal_payment_method_id, nvl(pis.personal_payment_method_id,-9999)) ';
         v_sql := v_select || v_from || v_where;
         fnd_file.put_line (fnd_file.LOG, 'Dynamic SQL Statement');
         fnd_file.put_line (fnd_file.LOG,
                            '------------------------------------'
                           );
         fnd_file.put_line (fnd_file.LOG, v_sql);
         fnd_file.new_line (fnd_file.LOG, 1);
         v_loc := 320;

         OPEN comp_emp FOR v_sql
         USING emp_rec.employee_number,
               emp_rec.person_id,
               emp_rec.cost_allocation_id,
               emp_rec.personal_payment_method_id;

         LOOP
            v_loc := 325;

            FETCH comp_emp
             INTO v_employee_number, v_person_id, v_cost_allocation_id,
                  v_personal_payment_method_id;

            v_loc := 330;

            IF comp_emp%NOTFOUND
            THEN
               UPDATE apps.ttec_aus_tmf_intf
                  SET effective_date_bank_change =
                                            emp_rec.effective_date_bank_change,
                      payment_method = emp_rec.payment_method,
                      account_type = emp_rec.account_type,
                      swift_or_bic_code = emp_rec.swift_or_bic_code,
                      local_bank_code = emp_rec.local_bank_code,
                      bank_name = emp_rec.bank_name,
                      branch_code = emp_rec.branch_code,
                      bank_account_number = emp_rec.bank_account_number,
                      additional_account_id = emp_rec.additional_account_id,
                      account_name = emp_rec.account_name,
                      iban_number = emp_rec.iban_number,
                      bank_country_code = emp_rec.bank_country_code,
                      currency_code = emp_rec.currency_code,
                      payment_distribution_amount =
                                           emp_rec.payment_distribution_amount,
                      payment_distribution_percent =
                                          emp_rec.payment_distribution_percent,
                      last_update_date = SYSDATE,
                      last_updated_by = g_user_id,
                      effective_date = SYSDATE,
                      request_id = g_conc_req_id,
                      action_type = emp_rec.action_type
                WHERE employee_number = emp_rec.employee_number
                  AND person_id = emp_rec.person_id
                  AND NVL (cost_allocation_id, '-9999') =
                                     NVL (emp_rec.cost_allocation_id, '-9999')
                  AND NVL (personal_payment_method_id, '-9999') =
                             NVL (emp_rec.personal_payment_method_id, '-9999');
            ELSE
               UPDATE apps.ttec_aus_tmf_intf_stg
                  SET effective_date_bank_change = NULL,
                      payment_method = NULL,
                      account_type = NULL,
                      swift_or_bic_code = NULL,
                      local_bank_code = NULL,
                      bank_name = NULL,
                      branch_code = NULL,
                      bank_account_number = NULL,
                      additional_account_id = NULL,
                      account_name = NULL,
                      iban_number = NULL,
                      bank_country_code = NULL,
                      currency_code = NULL,
                      payment_distribution_amount = NULL,
                      payment_distribution_percent = NULL
                WHERE employee_number = emp_rec.employee_number
                  AND person_id = emp_rec.person_id
                  AND NVL (cost_allocation_id, '-9999') =
                                     NVL (emp_rec.cost_allocation_id, '-9999')
                  AND NVL (personal_payment_method_id, '-9999') =
                             NVL (emp_rec.personal_payment_method_id, '-9999');
            END IF;

            EXIT;
            v_loc := 335;
            emp_rec.employee_number := NULL;
            emp_rec.person_id := NULL;
            emp_rec.cost_allocation_id := NULL;
            emp_rec.personal_payment_method_id := NULL;
         END LOOP;

         v_loc := 340;

         CLOSE comp_emp;
      END LOOP;

      COMMIT;
      v_loc := 345;
   EXCEPTION
      WHEN OTHERS
      THEN
         NULL;
         ttec_intf_error (NULL,
                          'ttec_aus_ora_tmf_intf_pkg.ttec_aus_bank_change',
                          'Bank change Interface',
                          'Error',
                          v_loc,
                          SQLERRM,
                          'Employee Number',
                          emp_rec.employee_number,
                          'Person ID',
                          emp_rec.person_id
                         );
   END ttec_aus_bank_change;

   PROCEDURE ttec_aus_salary_change (
      p_errbuff   OUT   VARCHAR2,
      p_retcode   OUT   NUMBER
   )
   AS
      v_table_name                   all_tables.table_name%TYPE
                                                       := 'TTEC_AUS_TMF_INTF';
      v_table_owner                  all_tables.owner%TYPE          := 'APPS';
      v_loc                          NUMBER;
      v_select                       VARCHAR2 (500);
      v_from                         VARCHAR2 (500);
      v_where                        VARCHAR2 (15000);
      v_col_pis                      VARCHAR2 (200);
      v_col_pi                       VARCHAR2 (200);
      v_sql                          VARCHAR2 (15000);
      comp_emp                       sys_refcursor;
      v_employee_number              apps.ttec_aus_tmf_intf_stg.employee_number%TYPE;
      v_person_id                    apps.ttec_aus_tmf_intf_stg.person_id%TYPE;
      v_cost_allocation_id           apps.ttec_aus_tmf_intf_stg.cost_allocation_id%TYPE;
      v_personal_payment_method_id   apps.ttec_aus_tmf_intf_stg.personal_payment_method_id%TYPE;
      v_err                          VARCHAR2 (15000);

      CURSOR c_emp_cr
      IS
         SELECT *
           FROM apps.ttec_aus_tmf_intf_stg
          WHERE action_type = 'C';

      emp_rec                        c_emp_cr%ROWTYPE;
   BEGIN
      FOR emp_rec IN c_emp_cr
      LOOP
         v_loc := 350;
         v_sql :=
            ' SELECT pis.employee_number, pis.person_id, pis.cost_allocation_id,pis.personal_payment_method_id
       FROM apps.ttec_aus_tmf_intf_stg pis, apps.TTEC_AUS_TMF_INTF pi
       WHERE pis.employee_number = pi.employee_number
         AND pis.person_id = pi.person_id
          AND nvl(pis.cost_allocation_id,-9999) = nvl(pi.cost_allocation_id,-9999)
          AND nvl(pis.personal_payment_method_id,-9999) = nvl(pi.personal_payment_method_id,-9999)
         AND  NVL(pis.BASIC_SALARY_RATE, -9999)  =  NVL(pi.BASIC_SALARY_RATE, -9999)
         AND  NVL(pis.SALARY_RATE_TYPE,''*'')  =  NVL(pi.SALARY_RATE_TYPE,''*'')
         AND pis.employee_number = NVL(:employee_number, pis.employee_number)
         AND pis.person_id = NVL(:person_id, pis.person_id)
         AND nvl(pis.cost_allocation_id,-9999) = NVL(:cost_allocation_id, nvl(pis.cost_allocation_id,-9999))
         AND  nvl(pis.personal_payment_method_id,-9999) = NVL(:personal_payment_method_id, nvl(pis.personal_payment_method_id,-9999))';
         fnd_file.put_line (fnd_file.LOG, 'Dynamic SQL Statement');
         fnd_file.put_line (fnd_file.LOG,
                            '------------------------------------'
                           );
         fnd_file.put_line (fnd_file.LOG, v_sql);
         fnd_file.new_line (fnd_file.LOG, 1);
         v_loc := 355;

         OPEN comp_emp FOR v_sql
         USING emp_rec.employee_number,
               emp_rec.person_id,
               emp_rec.cost_allocation_id,
               emp_rec.personal_payment_method_id;

         LOOP
            v_loc := 360;

            FETCH comp_emp
             INTO v_employee_number, v_person_id, v_cost_allocation_id,
                  v_personal_payment_method_id;

            v_loc := 365;

            IF comp_emp%NOTFOUND
            THEN
               UPDATE apps.ttec_aus_tmf_intf
                  SET effective_date_salary = emp_rec.effective_date_salary,
                      basic_salary_rate = emp_rec.basic_salary_rate,
                      salary_rate_type = emp_rec.salary_rate_type,
                      last_update_date = SYSDATE,
                      last_updated_by = g_user_id,
                      effective_date = SYSDATE,
                      request_id = g_conc_req_id,
                      action_type = emp_rec.action_type
                WHERE employee_number = emp_rec.employee_number
                  AND person_id = emp_rec.person_id
                  AND NVL (cost_allocation_id, '-9999') =
                                     NVL (emp_rec.cost_allocation_id, '-9999')
                  AND NVL (personal_payment_method_id, '-9999') =
                             NVL (emp_rec.personal_payment_method_id, '-9999');
            ELSE
               UPDATE apps.ttec_aus_tmf_intf_stg
                  SET effective_date_salary = NULL,
                      basic_salary_rate = NULL,
                      salary_rate_type = NULL
                WHERE employee_number = emp_rec.employee_number
                  AND person_id = emp_rec.person_id
                  AND NVL (cost_allocation_id, '-9999') =
                                     NVL (emp_rec.cost_allocation_id, '-9999')
                  AND NVL (personal_payment_method_id, '-9999') =
                             NVL (emp_rec.personal_payment_method_id, '-9999');
            END IF;

            EXIT;
            v_loc := 370;
            emp_rec.employee_number := NULL;
            emp_rec.person_id := NULL;
            emp_rec.cost_allocation_id := NULL;
            emp_rec.personal_payment_method_id := NULL;
         END LOOP;

         v_loc := 375;

         CLOSE comp_emp;
      END LOOP;

      COMMIT;
      v_loc := 380;
   EXCEPTION
      WHEN OTHERS
      THEN
         ttec_intf_error (NULL,
                          'ttec_aus_ora_tmf_intf_pkg.ttec_aus_salary_change',
                          'Salary Change Interface',
                          'Error',
                          v_loc,
                          SQLERRM,
                          'Employee Number',
                          emp_rec.employee_number,
                          'Person ID',
                          emp_rec.person_id
                         );
   END ttec_aus_salary_change;

   PROCEDURE ttec_aus_per_term (
      p_errbuff         OUT   VARCHAR2,
      p_retcode         OUT   NUMBER,
      p_last_run_date         DATE
   )
   AS
      v_table_name                   all_tables.table_name%TYPE
                                                       := 'TTEC_AUS_TMF_INTF';
      v_table_owner                  all_tables.owner%TYPE          := 'APPS';
      v_loc                          NUMBER;
      comp_emp                       sys_refcursor;
      v_employee_number              apps.ttec_aus_tmf_intf_stg.employee_number%TYPE;
      v_person_id                    apps.ttec_aus_tmf_intf_stg.person_id%TYPE;
      v_cost_allocation_id           apps.ttec_aus_tmf_intf_stg.cost_allocation_id%TYPE;
      v_personal_payment_method_id   apps.ttec_aus_tmf_intf_stg.personal_payment_method_id%TYPE;
      v_last_run_date                DATE;
      lv_term_date_flag              VARCHAR2 (1);

      CURSOR c_emp_cr
      IS
         SELECT *
           FROM apps.ttec_aus_tmf_intf_stg
          WHERE termination_effective_date IS NOT NULL;

      emp_rec                        c_emp_cr%ROWTYPE;
   BEGIN
      FOR emp_rec IN c_emp_cr
      LOOP
         lv_term_date_flag := 'N';

         BEGIN
            SELECT 'Y'
              INTO lv_term_date_flag
              FROM apps.ttec_aus_tmf_intf
             WHERE 1 = 1
               AND employee_number = emp_rec.employee_number
               AND person_id = emp_rec.person_id
               AND NVL (cost_allocation_id, '-9999') =
                                     NVL (emp_rec.cost_allocation_id, '-9999')
               AND NVL (personal_payment_method_id, '-9999') =
                             NVL (emp_rec.personal_payment_method_id, '-9999')
               AND NVL (termination_effective_date, '01-JAN-1000') <>
                                            emp_rec.termination_effective_date;
         EXCEPTION
            WHEN OTHERS
            THEN
               lv_term_date_flag := 'N';
         END;

         IF   /*emp_rec.termination_effective_date >=
                                  NVL (trunc(p_last_run_date), TRUNC (SYSDATE - 15))
            AND*/    (    emp_rec.termination_effective_date < TRUNC (SYSDATE)
                      AND lv_term_date_flag = 'Y'
                     )
                  OR (emp_rec.termination_effective_date = TRUNC (SYSDATE))
         THEN                                                           --IF 1
            IF emp_rec.action_type IS NULL
            THEN                                  --IF 2 --Only Leaver record
               UPDATE apps.ttec_aus_tmf_intf_stg
                  SET action_type = 'L',
                      effective_date_per_change = NULL,
                      salutation_code = NULL,
                      first_name = NULL,
                      middle_names = NULL,
                      family_name = NULL,
                      preferred_name = NULL,
                      person_name_initials = NULL,
                      maiden_or_previous_name = NULL,
                      date_of_birth = NULL,
                      country_of_birth = NULL,
                      gender = NULL,
                      marital_status = NULL,
                      primary_language = NULL,
                      nationality = NULL,
                      national_id = NULL,
                      national_id_type = NULL,
                      national_id2 = NULL,
                      national_id2_type = NULL,
                      national_id3 = NULL,
                      national_id3_type = NULL,
                      national_id4 = NULL,
                      national_id4_type = NULL,
                      effective_date_contract_change = NULL,
                      hire_date = NULL,
                      continuous_service_date = NULL,
                      contract_type = NULL,
                      period_type = NULL,
                      job_title = NULL,
                      cost_center_code = NULL,
                      cost_center_name = NULL,
                      cost_centre_allo_split_percnt = NULL,
                      department_code = NULL,
                      department_name = NULL,
                      other_cost_allocation_code = NULL,
                      other_cost_allocation_name = NULL,
                      work_location = NULL,
                      effective_date_address_change = NULL,
                      building_number = NULL,
                      address_line1 = NULL,
                      address_line2 = NULL,
                      address_line3 = NULL,
                      address_line4 = NULL,
                      city_name = NULL,
                      postal_code = NULL,
                      state = NULL,
                      country = NULL,
                      email_address = NULL,
                      effective_date_salary = NULL,
                      basic_salary_rate = NULL,
                      salary_rate_type = NULL,
                      effective_date_schedule_change = NULL,
                      fulltime_or_parttime = NULL,
                      percentage_working = NULL,
                      contracted_weekly_hours = NULL,
                      work_schedule_code = NULL,
                      work_schedule_description = NULL,
                      effective_date_bank_change = NULL,
                      payment_method = NULL,
                      account_type = NULL,
                      swift_or_bic_code = NULL,
                      local_bank_code = NULL,
                      bank_name = NULL,
                      branch_code = NULL,
                      bank_account_number = NULL,
                      additional_account_id = NULL,
                      account_name = NULL,
                      iban_number = NULL,
                      bank_country_code = NULL,
                      currency_code = NULL,
                      payment_distribution_amount = NULL,
                      payment_distribution_percent = NULL,
                      other_person_id = NULL,
                      other_person_id_desc = NULL,
                      gca_level = NULL
                WHERE employee_number = emp_rec.employee_number
                  AND person_id = emp_rec.person_id
                  AND NVL (cost_allocation_id, '-9999') =
                                     NVL (emp_rec.cost_allocation_id, '-9999')
                  AND NVL (personal_payment_method_id, '-9999') =
                             NVL (emp_rec.personal_payment_method_id, '-9999');
            ELSE    --Incase Change record available
               INSERT INTO apps.ttec_aus_tmf_intf_stg
                           (employee_number,
                            organization_name, country_code,
                            entity_number, effective_date,
							entity_code,					--Added by Vaibhav 02-DEC-2019 to pass entity code
                            action_type, termination_effective_date,
                            termination_reason_code,
                            termination_reason_desc,
                            last_paid_date, person_id,
                            cost_allocation_id,
                            personal_payment_method_id, last_update_date,
                            last_updated_by, creation_date,
                            created_by, request_id
                           )
                    VALUES (emp_rec.employee_number,
                            emp_rec.organization_name, emp_rec.country_code,
                            emp_rec.entity_number, emp_rec.effective_date,
							emp_rec.entity_code,					--Added by Vaibhav 02-DEC-2019 to pass entity code
                            'L', emp_rec.termination_effective_date,
                            emp_rec.termination_reason_code,
                            emp_rec.termination_reason_desc,
                            emp_rec.last_paid_date, emp_rec.person_id,
                            emp_rec.cost_allocation_id,
                            emp_rec.personal_payment_method_id, SYSDATE,
                            emp_rec.last_updated_by, SYSDATE,
                            emp_rec.created_by, emp_rec.request_id
                           );
            UPDATE apps.ttec_aus_tmf_intf_stg
               SET termination_effective_date = NULL,
                   termination_reason_code = NULL,
                   termination_reason_desc = NULL,
                   last_paid_date = NULL
             WHERE 1=1
               AND action_type = 'C'
               AND employee_number = emp_rec.employee_number
               AND person_id = emp_rec.person_id
               AND NVL (cost_allocation_id, '-9999') =
                                     NVL (emp_rec.cost_allocation_id, '-9999')
               AND NVL (personal_payment_method_id, '-9999') =
                             NVL (emp_rec.personal_payment_method_id, '-9999');
            END IF;                                                     --IF 2

            UPDATE apps.ttec_aus_tmf_intf
               SET action_type = 'L',
                   termination_effective_date =
                                            emp_rec.termination_effective_date,
                   termination_reason_code = emp_rec.termination_reason_code,
                   termination_reason_desc = emp_rec.termination_reason_desc,
                   last_paid_date = emp_rec.last_paid_date,
                   last_update_date = SYSDATE,
                   last_updated_by = g_user_id,
                   effective_date = SYSDATE,
                   request_id = g_conc_req_id
             WHERE employee_number = emp_rec.employee_number
               AND person_id = emp_rec.person_id
               AND NVL (cost_allocation_id, '-9999') =
                                     NVL (emp_rec.cost_allocation_id, '-9999')
               AND NVL (personal_payment_method_id, '-9999') =
                             NVL (emp_rec.personal_payment_method_id, '-9999');
         END IF;                                                        --IF 1
      END LOOP;

      COMMIT;
      v_loc := 385;
   EXCEPTION
      WHEN OTHERS
      THEN
         ttec_intf_error (NULL,
                          'ttec_aus_ora_tmf_intf_pkg.ttec_aus_per_term',
                          'Person Term Interface',
                          'Error',
                          v_loc,
                          SQLERRM,
                          'Employee Number',
                          emp_rec.employee_number,
                          'Person ID',
                          emp_rec.person_id
                         );
   END ttec_aus_per_term;

   PROCEDURE ttec_aus_file_gen (p_errbuff OUT VARCHAR2, p_retcode OUT NUMBER)
   IS
      r_employee        apps.ttec_aus_tmf_intf_stg%ROWTYPE;
      v_host_name       VARCHAR2 (50);
      v_instance_name   VARCHAR2 (50);
      v_file_extn       VARCHAR2 (10);
      v_dir_path        VARCHAR2 (250);
      v_out_file        VARCHAR2 (120);
      v_text            VARCHAR2 (30000);
      v_dt_time         VARCHAR2 (15);
      v_aus_file        UTL_FILE.file_type;
      v_count_utl       NUMBER;
      v_loc             NUMBER;
      v_date            VARCHAR2 (10);
   BEGIN
      fnd_global.apps_initialize (g_user_id, g_resp_id, g_resp_appl_id);
      v_loc := 390;

      SELECT    TO_CHAR (SYSDATE, 'YYYY')
             || '_'
             || TO_CHAR (SYSDATE, 'MM')
             || '_'
             || ptp.period_num
        INTO v_date
        FROM per_time_periods ptp, pay_all_payrolls_f pap
       WHERE 1 = 1
         AND pap.payroll_name = 'FORTNIGHTLY TELETECH'
         AND TRUNC (SYSDATE) BETWEEN ptp.start_date AND ptp.end_date
         AND pap.payroll_id = ptp.payroll_id
         AND TRUNC (SYSDATE) BETWEEN pap.effective_start_date
                                 AND NVL (pap.effective_end_date,
                                          '31-DEC-4712'
                                         );

      v_loc := 395;

      SELECT TO_CHAR (SYSDATE, 'YYYYMMDDHH24MISS')
        INTO v_dt_time
        FROM DUAL;

      v_loc := 400;

      SELECT directory_path || '/data/EBS/HC/Payroll/TMF/Australia/Outbound'
        INTO v_dir_path
        FROM dba_directories
       WHERE directory_name = 'CUST_TOP';

      v_loc := 405;

      SELECT host_name,
             DECODE (host_name,
                     ttec_library.xx_ttec_prod_host_name, NULL,
                     '-TEST'
                    )
        INTO v_host_name,
             v_instance_name
        FROM v$instance;

      v_loc := 410;

      BEGIN
         SELECT '.CSV'
           INTO v_file_extn
           FROM v$instance;
      EXCEPTION
         WHEN OTHERS
         THEN
            v_file_extn := '.csv';
      END;

      BEGIN
         v_loc := 415;

         FOR c_gre_name IN (SELECT DISTINCT entity_number,entity_code
                                       FROM apps.ttec_aus_tmf_intf_stg
                                      WHERE action_type IN ('S', 'C', 'L'))
         LOOP                                                  --start loop 1
            v_count_utl := 0;
            fnd_file.put_line (fnd_file.LOG,
                               'Extension name:' || v_file_extn);
            v_out_file :=
                  'TTEC_HRP_AU_'
               || replace(c_gre_name.entity_code,' ','-')
               || '_'
               || v_date
               || '_CMDC_'
               || v_dt_time
               || '_Payroll'
               || v_instance_name
               || v_file_extn;
            v_loc := 420;
            fnd_file.put_line (fnd_file.LOG, 'FILE name:' || v_out_file);
            v_aus_file := UTL_FILE.fopen (v_dir_path, v_out_file, 'w', 32000);
            fnd_file.put_line (fnd_file.LOG, 'DIR path: ' || v_dir_path);
            v_loc := 425;
            --Header for the File
            v_text :=
               'Employee Number|Organization Name|Country Code|Entity Number|Effective Date|Action Type|Effective Date|Salutation Code|First Name|Middle Name|Family Name|Preferred Name|Person Name Initials|Maiden or Previous Name|Date of Birth|Country of Birth|Gender|Marital Status|Primary Language|Nationality|National ID |National ID Type |2nd National ID |2nd National ID Type|3rd National ID |3rd National ID Type|4th National ID |4th National ID Type|Effective Date|Hire Date|Continuous Service Date|Contract Type|Payroll Frequency|Job Title|Cost Center Code|Cost Center Name|Cost Centre Allocation Split % (Total Pay)|Department Code|Department Name|Other Cost Allocation Code|Other Cost Allocation Name|Work Location|Effective Date|Building Number|Address 1|Address 2|Address 3|Address 4|City Name|Postal Code|State/Country/Municipality|Country of residence|E-mail address|Effective Date|Basic Salary Rate|Salary Rate Type|Effective Date|Fulltime/Parttime|Percentage Working|Contracted Weekly Hours|Work Schedule Code|Work Schedule Description|Effective Date|Payment Method|Account Type|SWIFT/BIC Code|Local Bank code|Bank Name|Branch Name/Branch Code|Bank Account Number|Additional Account ID|Name on Account|IBAN Number|Country Code|Currency Code|Payment Distribution Amount|Payment Distribution Percentage|Termination Effective Date|Termination Reason Code|Termination Reason Description|Last Paid Date|Other Person Id|Other Person Id Description|Australian Resident for Tax Purposes|Employee tax status|Has the tax free threshold been claimed?|HECS Debt|SFSS debt|Super Fund Name|Super Fund ABN|Employee Fund Membership Number|Work Location (State)|Tax File Number|Super Fund USI|Annual Leave Entitlements Days Per year|Personal Leave Entitlement Days per year|GCA Level';
            v_loc := 430;
            UTL_FILE.put_line (v_aus_file, v_text);
            v_loc := 435;

            FOR r_emp_rec IN
               (SELECT DISTINCT employee_number, organization_name,
                                country_code, entity_number,
                                TO_CHAR (effective_date,
                                         'DD/MM/YYYY'
                                        ) effective_date,
                                action_type,
                                TO_CHAR
                                   (effective_date_per_change,
                                    'DD/MM/YYYY'
                                   ) effective_date_per_change,
                                salutation_code, first_name, middle_names,
                                family_name, preferred_name,
                                person_name_initials, maiden_or_previous_name,
                                date_of_birth, country_of_birth, gender,
                                marital_status, primary_language, nationality,
                                national_id, national_id_type, national_id2,
                                national_id2_type, national_id3,
                                national_id3_type, national_id4,
                                national_id4_type,
                                TO_CHAR
                                   (effective_date_contract_change,
                                    'DD/MM/YYYY'
                                   ) effective_date_contract_change,
                                TO_CHAR
                                   (hire_date,
                                    'DD/MM/YYYY')hire_date,
                                TO_CHAR
                                   (continuous_service_date,
                                    'DD/MM/YYYY')continuous_service_date,
                                contract_type, period_type, job_title,
                                cost_center_code, cost_center_name,
                                cost_centre_allo_split_percnt,
                                department_code, department_name,
                                other_cost_allocation_code,
                                other_cost_allocation_name, work_location,
                                TO_CHAR
                                   (effective_date_address_change,
                                    'DD/MM/YYYY'
                                   ) effective_date_address_change,
                                building_number, address_line1, address_line2,
                                address_line3, address_line4, city_name,
                                postal_code, state, country, email_address,
                                TO_CHAR
                                   (effective_date_salary,
                                    'DD/MM/YYYY'
                                   ) effective_date_salary,
                                basic_salary_rate, salary_rate_type,
                                TO_CHAR
                                   (effective_date_schedule_change,
                                    'DD/MM/YYYY'
                                   ) effective_date_schedule_change,
                                fulltime_or_parttime, percentage_working,
                                contracted_weekly_hours, work_schedule_code,
                                work_schedule_description,
                                TO_CHAR
                                   (effective_date_bank_change,
                                    'DD/MM/YYYY'
                                   ) effective_date_bank_change,
                                payment_method, account_type,
                                swift_or_bic_code, local_bank_code, bank_name,
                                branch_code, bank_account_number,
                                additional_account_id, account_name,
                                iban_number, bank_country_code, currency_code,
                                payment_distribution_amount,
                                payment_distribution_percent,
                                TO_CHAR
                                   (termination_effective_date,
                                    'DD/MM/YYYY')termination_effective_date,
                                termination_reason_code,
                                termination_reason_desc,
                                TO_CHAR
                                   (last_paid_date,
                                    'DD/MM/YYYY')last_paid_date,
                                other_person_id, other_person_id_desc,
                                australian_resd_tax_purpose australian_resd_tax_purpose,
                                NULL employee_tax_status,
                                tax_free_thresh_claimed_or_not tax_free_thresh_claimed_or_not,
                                hecs_debt hecs_debt, sfss_debt sfss_debt,
                                super_fund_name super_fund_name, NULL super_fund_abn,
                                emp_fund_membership_number emp_fund_membership_number,
                                NULL work_location_state,
                                tax_file_number tax_file_number, NULL super_fund_usi,
                                NULL annual_leav_entitle_days_peryr,
                                NULL pers_leav_entitle_days_peryr, gca_level
                           FROM apps.ttec_aus_tmf_intf_stg
                          WHERE action_type IN ('S', 'C', 'L')
                            AND entity_number = c_gre_name.entity_number
                       ORDER BY employee_number,action_type)
            LOOP                                                --start loop 2
               v_text := '';
               v_loc := 440;
               v_text :=
                     r_emp_rec.employee_number
                  || '|'
                  || r_emp_rec.organization_name
                  || '|'
                  || r_emp_rec.country_code
                  || '|'
                  || r_emp_rec.entity_number
                  || '|'
                  || r_emp_rec.effective_date
                  || '|'
                  || r_emp_rec.action_type
                  || '|'
                  || r_emp_rec.effective_date_per_change
                  || '|'
                  || r_emp_rec.salutation_code
                  || '|'
                  || r_emp_rec.first_name
                  || '|'
                  || r_emp_rec.middle_names
                  || '|'
                  || r_emp_rec.family_name
                  || '|'
                  || r_emp_rec.preferred_name
                  || '|'
                  || r_emp_rec.person_name_initials
                  || '|'
                  || r_emp_rec.maiden_or_previous_name
                  || '|'
                  || r_emp_rec.date_of_birth
                  || '|'
                  || r_emp_rec.country_of_birth
                  || '|'
                  || r_emp_rec.gender
                  || '|'
                  || r_emp_rec.marital_status
                  || '|'
                  || r_emp_rec.primary_language
                  || '|'
                  || r_emp_rec.nationality
                  || '|'
                  || r_emp_rec.national_id
                  || '|'
                  || r_emp_rec.national_id_type
                  || '|'
                  || r_emp_rec.national_id2
                  || '|'
                  || r_emp_rec.national_id2_type
                  || '|'
                  || r_emp_rec.national_id3
                  || '|'
                  || r_emp_rec.national_id3_type
                  || '|'
                  || r_emp_rec.national_id4
                  || '|'
                  || r_emp_rec.national_id4_type
                  || '|'
                  || r_emp_rec.effective_date_contract_change
                  || '|'
                  || r_emp_rec.hire_date
                  || '|'
                  || r_emp_rec.continuous_service_date
                  || '|'
                  || r_emp_rec.contract_type
                  || '|'
                  || r_emp_rec.period_type
                  || '|'
                  || '"'
                  || r_emp_rec.job_title
                  || '"'
                  || '|'
                  || r_emp_rec.cost_center_code
                  || '|'
                  || r_emp_rec.cost_center_name
                  || '|'
                  || r_emp_rec.cost_centre_allo_split_percnt
                  || '|'
                  || r_emp_rec.department_code
                  || '|'
                  || r_emp_rec.department_name
                  || '|'
                  || r_emp_rec.other_cost_allocation_code
                  || '|'
                  || r_emp_rec.other_cost_allocation_name
                  || '|'
                  || '"'
                  || r_emp_rec.work_location
                  || '"'
                  || '|'
                  || r_emp_rec.effective_date_address_change
                  || '|'
                  || r_emp_rec.building_number
                  || '|'
                  || '"'
                  || r_emp_rec.address_line1
                  || '"'
                  || '|'
                  || r_emp_rec.address_line2
                  || '|'
                  || r_emp_rec.address_line3
                  || '|'
                  || r_emp_rec.address_line4
                  || '|'
                  || r_emp_rec.city_name
                  || '|'
                  || r_emp_rec.postal_code
                  || '|'
                  || r_emp_rec.state
                  || '|'
                  || r_emp_rec.country
                  || '|'
                  || r_emp_rec.email_address
                  || '|'
                  || r_emp_rec.effective_date_salary
                  || '|'
                  || r_emp_rec.basic_salary_rate
                  || '|'
                  || r_emp_rec.salary_rate_type
                  || '|'
                  || r_emp_rec.effective_date_schedule_change
                  || '|'
                  || r_emp_rec.fulltime_or_parttime
                  || '|'
                  || r_emp_rec.percentage_working
                  || '|'
                  || r_emp_rec.contracted_weekly_hours
                  || '|'
                  || r_emp_rec.work_schedule_code
                  || '|'
                  || r_emp_rec.work_schedule_description
                  || '|'
                  || r_emp_rec.effective_date_bank_change
                  || '|'
                  || r_emp_rec.payment_method
                  || '|'
                  || r_emp_rec.account_type
                  || '|'
                  || r_emp_rec.swift_or_bic_code
                  || '|'
                  || r_emp_rec.local_bank_code
                  || '|'
                  || r_emp_rec.bank_name
                  || '|'
                  || r_emp_rec.branch_code
                  || '|'
                  || r_emp_rec.bank_account_number
                  || '|'
                  || r_emp_rec.additional_account_id
                  || '|'
                  || r_emp_rec.account_name
                  || '|'
                  || r_emp_rec.iban_number
                  || '|'
                  || r_emp_rec.bank_country_code
                  || '|'
                  || r_emp_rec.currency_code
                  || '|'
                  || r_emp_rec.payment_distribution_amount
                  || '|'
                  || r_emp_rec.payment_distribution_percent
                  || '|'
                  || r_emp_rec.termination_effective_date
                  || '|'
                  || r_emp_rec.termination_reason_code
                  || '|'
                  || r_emp_rec.termination_reason_desc
                  || '|'
                  || r_emp_rec.last_paid_date
                  || '|'
                  || r_emp_rec.other_person_id
                  || '|'
                  || r_emp_rec.other_person_id_desc
                  || '|'
                  || r_emp_rec.australian_resd_tax_purpose
                  || '|'
                  || r_emp_rec.employee_tax_status
                  || '|'
                  || r_emp_rec.tax_free_thresh_claimed_or_not
                  || '|'
                  || r_emp_rec.hecs_debt
                  || '|'
                  || r_emp_rec.sfss_debt
                  || '|'
                  || r_emp_rec.super_fund_name
                  || '|'
                  || r_emp_rec.super_fund_abn
                  || '|'
                  || r_emp_rec.emp_fund_membership_number
                  || '|'
                  || r_emp_rec.work_location_state
                  || '|'
                  || r_emp_rec.tax_file_number
                  || '|'
                  || r_emp_rec.super_fund_usi
                  || '|'
                  || r_emp_rec.annual_leav_entitle_days_peryr
                  || '|'
                  || r_emp_rec.pers_leav_entitle_days_peryr
                  || '|'
                  || r_emp_rec.gca_level;
               v_loc := 435;
               UTL_FILE.put_line (v_aus_file, v_text);
               v_count_utl := v_count_utl + 1;
               v_loc := 440;
            END LOOP;                                             --end loop 2

            fnd_file.put_line
                            (fnd_file.output,
                             'Please go to below path for the file generated.'
                            );
            fnd_file.put_line (fnd_file.output, v_dir_path);
            fnd_file.put_line (fnd_file.LOG,
                                  'Total number of records processed : '
                               || v_count_utl
                              );
            COMMIT;
            UTL_FILE.fclose (v_aus_file);
            v_loc := 443;
         END LOOP;                                                --end loop 1

         v_loc := 445;
      EXCEPTION
         WHEN OTHERS
         THEN
            ttec_intf_error
                          (NULL,
                           'ttec_aus_tmf_csv_pkg.ttec_aus_file_gen',
                           'TTech AUS TMF CSV Interface -UTL file Issues',
                           'Error',
                           v_loc,
                           SQLERRM,
                           'Error during Util file - CSV generation process',
                           NULL,
                           NULL,
                           NULL
                          );
      END;

      v_loc := 455;
      COMMIT;
   EXCEPTION
      WHEN OTHERS
      THEN
         ttec_intf_error (NULL,
                          'ttec_aus_tmf_csv_pkg.ttec_aus_file_gen',
                          'TTech AUS TMF Interface',
                          'Error',
                          v_loc,
                          SQLERRM,
                          'Error during CSV File generation process',
                          NULL,
                          NULL,
                          NULL
                         );
         fnd_file.put_line (fnd_file.LOG, SQLERRM || '-' || SQLCODE);
   END ttec_aus_file_gen;

   PROCEDURE main (p_errbuff OUT VARCHAR2, p_retcode OUT NUMBER)
   IS
      r_employee                     apps.ttec_aus_tmf_intf_stg%ROWTYPE;
      v_employee_number              apps.ttec_aus_tmf_intf_stg.employee_number%TYPE;
      v_person_id                    apps.ttec_aus_tmf_intf_stg.person_id%TYPE;
      v_cost_allocation_id           apps.ttec_aus_tmf_intf_stg.cost_allocation_id%TYPE;
	  v_action_type		             apps.ttec_aus_tmf_intf_stg.action_type%TYPE;
      v_personal_payment_method_id   apps.ttec_aus_tmf_intf_stg.personal_payment_method_id%TYPE;
      v_table_name                   all_tables.table_name%TYPE
                                                       := 'TTEC_AUS_TMF_INTF';
      v_table_owner                  all_tables.owner%TYPE          := 'APPS';
      v_select                       VARCHAR2 (500);
      v_from                         VARCHAR2 (500);
      v_where                        VARCHAR2 (15000);
      v_col_pis                      VARCHAR2 (200);
      v_col_pi                       VARCHAR2 (200);
      v_sql                          VARCHAR2 (15000);
      comp_emp                       sys_refcursor;
      v_count                        NUMBER;
      v_instance_name                VARCHAR2 (50);
      v_dir_path                     VARCHAR2 (250);
      v_dt_time                      VARCHAR2 (12);
      v_aus_file                     UTL_FILE.file_type;
      v_chng_count                   NUMBER;
      v_loc                          NUMBER;
      v_last_run_date                DATE;
      c                              sys_refcursor;
      v_ctx                          DBMS_XMLQUERY.ctxtype;
      RESULT                         CLOB;
      pos                            INTEGER                             := 1;
      buffer                         VARCHAR2 (32767);
      amount                         BINARY_INTEGER                  := 32000;

      --Main cursor to fetch all eligible records for AUS TMF interface
      CURSOR c_employee (v_last_run_date DATE)
      IS
         SELECT DISTINCT papf.employee_number, 'TTEC' organization_name,
                         'AU' country_code, hou.NAME entity_number,
						 (SELECT lookup_code
                            FROM apps.fnd_lookup_values_vl
                           WHERE lookup_type = 'TTEC_TMF_LEGAL_ENTITY_CODES'
                             AND meaning = hou.NAME
							 AND ENABLED_FLAG = 'Y'
							 AND SYSDATE BETWEEN NVL(START_DATE_ACTIVE,SYSDATE) AND  NVL(END_DATE_ACTIVE,SYSDATE+1)) entity_code,		--Added by Vaibhav 19-DEC-2019 to pass entity code
                         NULL effective_date, NULL action_type,
                         GREATEST
                            (papf.effective_start_date,
                             papf.last_update_date
                            ) effective_date_per_change,
                         papf.title salutation_code
						 --Started modifiing by Vaibhav 07-FEB-2020 changes suggested by Ugander to Substr
						 --, papf.first_name
						 --, papf.middle_names
						 --, papf.last_name family_name
						 , SUBSTR(papf.first_name,1,25) first_name
						 , SUBSTR(papf.middle_names,1,25) middle_names
						 , SUBSTR(papf.last_name,1,25) family_name
						 --Ended modifiing by Vaibhav 07-FEB-2020 changes suggested by Ugander to Substr
						 ,NULL preferred_name, NULL person_name_initials,
                         NULL maiden_or_previous_name,
                         TO_CHAR (papf.date_of_birth,
                                  'DD/MM/YYYY'
                                 ) date_of_birth,
                         country_of_birth, sex gender,
                         DECODE (NVL (marital_status, 'Unknown'),
                                 'M', 'Married',
                                 'S', 'Single',
                                 'BE_LIV_TOG', 'Co-Habiting',
                                 'DP', 'Civil Partnership',
                                 'W', 'Widowed',
                                 'L', 'Separated',
                                 'D', 'Divorced',
                                 'Unknown', 'Unknown',
                                 'Other'
                                ) marital_status,
                         NULL primary_language,
                         SUBSTR (DECODE (nationality,
                                         'TTAU_AU', 'AU',
                                         nationality
                                        ),
                                 1,
                                 2
                                ) nationality,
                         (SELECT eev13.screen_entry_value
                            FROM pay_element_entries_f pee,
                                 pay_element_types_f pet,
                                 pay_input_values_f piv13,
                                 pay_element_entry_values_f eev13
                           WHERE (piv13.NAME) = 'Tax File Number'
                             AND eev13.input_value_id = piv13.input_value_id
                             AND piv13.element_type_id = pet.element_type_id
                             AND eev13.element_entry_id = pee.element_entry_id
                             AND pet.element_name = 'Tax Information'
                             AND TRUNC (SYSDATE)
                                    BETWEEN pet.effective_start_date
                                        AND pet.effective_end_date
                             AND TRUNC (SYSDATE)
                                    BETWEEN eev13.effective_start_date
                                        AND eev13.effective_end_date
                             AND TRUNC (SYSDATE)
                                    BETWEEN piv13.effective_start_date
                                        AND piv13.effective_end_date
                             AND TRUNC (SYSDATE)
                                    BETWEEN pee.effective_start_date
                                        AND pee.effective_end_date
                             AND pee.assignment_id = paaf.assignment_id)
                                                                 national_id,
                         'Tax File Number' national_id_type,
                         NULL national_id2, NULL national_id2_type,
                         NULL national_id3, NULL national_id3_type,
                         NULL national_id4, NULL national_id4_type,
                         GREATEST
                            (paaf.effective_start_date,
                             paaf.last_update_date,
                             NVL (pcaf.effective_start_date,
                                  paaf.effective_start_date
                                 ),
                             NVL (pcaf.last_update_date,
                                  paaf.last_update_date)
                            ) effective_date_contract_change,
                         ppos.date_start hire_date,
                         NVL (ppos.adjusted_svc_date,
                              ppos.date_start
                             ) continuous_service_date,
                         'P' contract_type,
                         DECODE (pap.period_type,
                                 'Bi-Week', 'Bi-weekly'
                                ) period_type,
                         (jdef.segment1 || '-' || jdef.segment2) job_title,
						 --Started modifiing by Vaibhav 07-FEB-2020 changes suggested by Ugander to Substr
                         --pcak_asg.segment2 cost_center_code,
						 SUBSTR(pcak_asg.segment2,1,10) cost_center_code,
						 --Ended modifiing by Vaibhav 07-FEB-2020 changes suggested by Ugander to Substr
                         (SELECT ffvl.description
                            FROM apps.fnd_flex_values_vl ffvl,
                                 apps.fnd_flex_value_sets ffvs
                           WHERE flex_value = pcak_asg.segment2
                             AND ffvl.flex_value_set_id =
                                                        ffvs.flex_value_set_id
                             AND flex_value_set_name = 'TELETECH_CLIENT')
                                                            cost_center_name,
                         (proportion * 100) cost_centre_allo_split_percnt,
                         (SELECT segment3
                            FROM apps.pay_cost_allocation_keyflex
                           WHERE cost_allocation_keyflex_id =
                                               hou1.cost_allocation_keyflex_id)
                                                             department_code,
                         hou1.NAME department_name,
                         NULL other_cost_allocation_code,
                         (SELECT location_code
                            FROM apps.hr_locations
                           WHERE location_id = paaf.location_id) other_cost_allocation_name,
                         (SELECT attribute2
                            FROM apps.hr_locations
                           WHERE location_id = paaf.location_id)work_location,
                         GREATEST
                            (pa.date_from,
                             pa.last_update_date
                            ) effective_date_address_change,
                         NULL building_number
						 --Started modifiing by Vaibhav 07-FEB-2020 changes suggested by Ugander to Substr
                         --, pa.address_line1
						 --, pa.address_line2
						 --, pa.address_line3
						   , SUBSTR(pa.address_line1,1,30) address_line1
						   , SUBSTR(pa.address_line2,1,30) address_line2
						   , SUBSTR(pa.address_line3,1,30) address_line3
						 --Ended modifiing by Vaibhav 07-FEB-2020 changes suggested by Ugander to Substr
						 , NULL address_line4
						 , pa.town_or_city city_name,
                         pa.postal_code,
                         (SELECT meaning
                            FROM apps.fnd_lookup_values_vl
                           WHERE lookup_type = 'AU_STATE'
                             AND lookup_code = pa.region_1) state,
                         country, papf.email_address,
 /* 1.1  Begin*/
--                         GREATEST (sal.change_date,
--                                   sal.last_update_date
--                                  ) effective_date_salary,
                        sal.change_date effective_date_salary,
  /* 1.1 End */
                         sal.salary basic_salary_rate,
                         sal.pay_basis salary_rate_type,
                         GREATEST
                            (paaf.effective_start_date,
                             paaf.last_update_date
                            ) effective_date_schedule_change,
                         DECODE
                              (paaf.employment_category,
                               'TTAU_FT', 'Full-time',
                               'TTAU_PT', 'Part-time',
                               'TTAU_CS', 'Casual - AU',
                               NULL
                              ) fulltime_or_parttime,
                         ((paaf.normal_hours / 40) * 100
                         ) percentage_working,
                         normal_hours contracted_weekly_hours,
                         (   paaf.time_normal_start
                          || ' to '
                          || paaf.time_normal_finish
                         ) work_schedule_code,
                         NULL work_schedule_description,
                         GREATEST
                            (ppm.effective_start_date,
                             ppm.last_update_date
                            ) effective_date_bank_change,
                         DECODE
                            ((SELECT payment_type_name
                                FROM pay_payment_types ppt,
                                     pay_org_payment_methods_f popm
                               WHERE popm.org_payment_method_id =
                                                     ppm.org_payment_method_id
                                 AND SYSDATE BETWEEN popm.effective_start_date
                                                 AND popm.effective_end_date
                                 AND popm.payment_type_id =
                                                           ppt.payment_type_id),
                             'Direct Entry', 'Bank Transfer',
                             'Cheque', 'Check'
                            ) payment_method,
                         'Saving' account_type, NULL swift_or_bic_code,
                         NULL local_bank_code, NULL bank_name,
                         pea.segment1 branch_code,
                         pea.segment2 bank_account_number,
                         NULL additional_account_id,
                         pea.segment3 account_name, NULL iban_number,
                         'AU' bank_country_code,
                         (SELECT currency_code
                            FROM pay_org_payment_methods_f popm
                           WHERE popm.org_payment_method_id =
                                      ppm.org_payment_method_id
                             AND SYSDATE BETWEEN popm.effective_start_date
                                             AND popm.effective_end_date)
                                                               currency_code,
                         ppm.amount payment_distribution_amount,
                         ppm.percentage payment_distribution_percent,
                         ppos.actual_termination_date
                                                  termination_effective_date,
                         (SELECT meaning
                            FROM apps.hr_lookups
                           WHERE lookup_type LIKE
                                          'LEAV_REAS'
                             AND lookup_code = ppos.leaving_reason)
                                                     termination_reason_code,
                         (SELECT meaning
                            FROM apps.hr_lookups
                           WHERE lookup_type LIKE
                                          'LEAV_REAS'
                             AND lookup_code = ppos.leaving_reason)
                                                     termination_reason_desc,
                         actual_termination_date last_paid_date,
                         NULL other_person_id, NULL other_person_id_desc,
                         papf.person_id, personal_payment_method_id,
                         cost_allocation_id,
						 (SELECT DECODE(
            eev13.screen_entry_value,
            'YS',
            'Y',
            'YI',
            'Y',
            'YC',
            'Y',
            'NN',
            'N',
            'YN',
            'Y',
            'Y',
            'Y',
            'N',
            'N',
            NULL
        )Australia_resident_flag
                            FROM pay_element_entries_f pee,
                                 pay_element_types_f pet,
                                 pay_input_values_f piv13,
                                 pay_element_entry_values_f eev13
                           WHERE (piv13.NAME) = 'Australian Resident'
                             AND eev13.input_value_id = piv13.input_value_id
                             AND piv13.element_type_id = pet.element_type_id
                             AND eev13.element_entry_id = pee.element_entry_id
                             AND pet.element_name = 'Tax Information'
                             AND TRUNC (SYSDATE)
                                    BETWEEN pet.effective_start_date
                                        AND pet.effective_end_date
                             AND TRUNC (SYSDATE)
                                    BETWEEN eev13.effective_start_date
                                        AND eev13.effective_end_date
                             AND TRUNC (SYSDATE)
                                    BETWEEN piv13.effective_start_date
                                        AND piv13.effective_end_date
                             AND TRUNC (SYSDATE)
                                    BETWEEN pee.effective_start_date
                                        AND pee.effective_end_date
                             AND pee.assignment_id = paaf.assignment_id)
                                                                 Australia_resident_flag,
                         (SELECT eev13.screen_entry_value Tax_free_threshold
                            FROM pay_element_entries_f pee,
                                 pay_element_types_f pet,
                                 pay_input_values_f piv13,
                                 pay_element_entry_values_f eev13
                           WHERE (piv13.NAME) = 'Tax Free Threshold'
                             AND eev13.input_value_id = piv13.input_value_id
                             AND piv13.element_type_id = pet.element_type_id
                             AND eev13.element_entry_id = pee.element_entry_id
                             AND pet.element_name = 'Tax Information'
                             AND TRUNC (SYSDATE)
                                    BETWEEN pet.effective_start_date
                                        AND pet.effective_end_date
                             AND TRUNC (SYSDATE)
                                    BETWEEN eev13.effective_start_date
                                        AND eev13.effective_end_date
                             AND TRUNC (SYSDATE)
                                    BETWEEN piv13.effective_start_date
                                        AND piv13.effective_end_date
                             AND TRUNC (SYSDATE)
                                    BETWEEN pee.effective_start_date
                                        AND pee.effective_end_date
                             AND pee.assignment_id = paaf.assignment_id)
                                                                Tax_Free_Threshold,
                         (SELECT DECODE(
            eev13.screen_entry_value,
            'Y',
            'Y',
            'N',
            'N',
            'YY',
            'Y',
            'NY',
            'N',
            NULL
        ) hecs_entry_value
                            FROM pay_element_entries_f pee,
                                 pay_element_types_f pet,
                                 pay_input_values_f piv13,
                                 pay_element_entry_values_f eev13
                           WHERE (piv13.NAME) = 'HECS'
                             AND eev13.input_value_id = piv13.input_value_id
                             AND piv13.element_type_id = pet.element_type_id
                             AND eev13.element_entry_id = pee.element_entry_id
                             AND pet.element_name = 'Tax Information'
                             AND TRUNC (SYSDATE)
                                    BETWEEN pet.effective_start_date
                                        AND pet.effective_end_date
                             AND TRUNC (SYSDATE)
                                    BETWEEN eev13.effective_start_date
                                        AND eev13.effective_end_date
                             AND TRUNC (SYSDATE)
                                    BETWEEN piv13.effective_start_date
                                        AND piv13.effective_end_date
                             AND TRUNC (SYSDATE)
                                    BETWEEN pee.effective_start_date
                                        AND pee.effective_end_date
                             AND pee.assignment_id = paaf.assignment_id)
                                                                 hecs_entry_value,
                         (SELECT DECODE(
            eev13.screen_entry_value,
            'YY',
            'Y',
            'NY',
            'Y',
            'N'
        ) sfss_entry_value
                            FROM pay_element_entries_f pee,
                                 pay_element_types_f pet,
                                 pay_input_values_f piv13,
                                 pay_element_entry_values_f eev13
                           WHERE (piv13.NAME) = 'HECS'
                             AND eev13.input_value_id = piv13.input_value_id
                             AND piv13.element_type_id = pet.element_type_id
                             AND eev13.element_entry_id = pee.element_entry_id
                             AND pet.element_name = 'Tax Information'
                             AND TRUNC (SYSDATE)
                                    BETWEEN pet.effective_start_date
                                        AND pet.effective_end_date
                             AND TRUNC (SYSDATE)
                                    BETWEEN eev13.effective_start_date
                                        AND eev13.effective_end_date
                             AND TRUNC (SYSDATE)
                                    BETWEEN piv13.effective_start_date
                                        AND piv13.effective_end_date
                             AND TRUNC (SYSDATE)
                                    BETWEEN pee.effective_start_date
                                        AND pee.effective_end_date
                             AND pee.assignment_id = paaf.assignment_id)
                                                                 sfss_entry_value,
                                                                 (SELECT
            PET.ELEMENT_NAME Super_fund_name
                                        FROM pay_element_entries_f pee,
                                 pay_element_types_f pet,
                                 pay_input_values_f piv13,
                                 pay_element_entry_values_f eev13
                           WHERE (piv13.NAME) = 'Member Number'
                             AND eev13.input_value_id = piv13.input_value_id
                             AND piv13.element_type_id = pet.element_type_id
                             AND eev13.element_entry_id = pee.element_entry_id
                            -- AND pet.element_name = 'Tax Information'
                             AND TRUNC (SYSDATE)
                                    BETWEEN pet.effective_start_date
                                        AND pet.effective_end_date
                             AND TRUNC (SYSDATE)
                                    BETWEEN eev13.effective_start_date
                                        AND eev13.effective_end_date
                             AND TRUNC (SYSDATE)
                                    BETWEEN piv13.effective_start_date
                                        AND piv13.effective_end_date
                             AND TRUNC (SYSDATE)
                                    BETWEEN pee.effective_start_date
                                        AND pee.effective_end_date
                             AND pee.assignment_id = paaf.assignment_id)
                                                                 Super_fund_name,
                                                                  (SELECT
            eev13.screen_entry_value Emp_fund_mem
                                        FROM pay_element_entries_f pee,
                                 pay_element_types_f pet,
                                 pay_input_values_f piv13,
                                 pay_element_entry_values_f eev13
                           WHERE (piv13.NAME) = 'Member Number'
                             AND eev13.input_value_id = piv13.input_value_id
                             AND piv13.element_type_id = pet.element_type_id
                             AND eev13.element_entry_id = pee.element_entry_id
                            -- AND pet.element_name = 'Tax Information'
                             AND TRUNC (SYSDATE)
                                    BETWEEN pet.effective_start_date
                                        AND pet.effective_end_date
                             AND TRUNC (SYSDATE)
                                    BETWEEN eev13.effective_start_date
                                        AND eev13.effective_end_date
                             AND TRUNC (SYSDATE)
                                    BETWEEN piv13.effective_start_date
                                        AND piv13.effective_end_date
                             AND TRUNC (SYSDATE)
                                    BETWEEN pee.effective_start_date
                                        AND pee.effective_end_date
                             AND pee.assignment_id = paaf.assignment_id)
                                                                 Emp_fund_mem,
                                                                  (SELECT eev13.screen_entry_value
                            FROM pay_element_entries_f pee,
                                 pay_element_types_f pet,
                                 pay_input_values_f piv13,
                                 pay_element_entry_values_f eev13
                           WHERE (piv13.NAME) = 'Tax File Number'
                             AND eev13.input_value_id = piv13.input_value_id
                             AND piv13.element_type_id = pet.element_type_id
                             AND eev13.element_entry_id = pee.element_entry_id
                             AND pet.element_name = 'Tax Information'
                             AND TRUNC (SYSDATE)
                                    BETWEEN pet.effective_start_date
                                        AND pet.effective_end_date
                             AND TRUNC (SYSDATE)
                                    BETWEEN eev13.effective_start_date
                                        AND eev13.effective_end_date
                             AND TRUNC (SYSDATE)
                                    BETWEEN piv13.effective_start_date
                                        AND piv13.effective_end_date
                             AND TRUNC (SYSDATE)
                                    BETWEEN pee.effective_start_date
                                        AND pee.effective_end_date
                             AND pee.assignment_id = paaf.assignment_id)
                                                                 TAX_FILE_NUMBER,

						 job.attribute20 gca_level
                    FROM apps.per_all_people_f papf,
                         apps.per_all_assignments_f paaf,
                         apps.per_addresses pa,
                         apps.fnd_common_lookups fcl,
                         apps.pay_payautax_pye_ent_v DEC,
                         apps.per_periods_of_service ppos,
                         apps.per_jobs job,
                         apps.per_job_definitions jdef,
                         (SELECT asg.assignment_id,
                                 ROUND
                                     ((  ppb.pay_annualization_factor
                                       * ppps.proposed_salary_n
                                      ),
                                      2
                                     ) salary,
                                 change_date, ppb.pay_basis pay_basis,
                                 ppps.last_update_date
                            --START R12.2 Upgrade Remediation
							/*FROM hr.per_pay_proposals ppps,			-- Commented code by IXPRAVEEN-ARGANO,15-May-2023
                                 hr.per_pay_bases ppb,                  
                                 hr.per_all_assignments_f asg*/
							FROM apps.per_pay_proposals ppps,			--  code Added by IXPRAVEEN-ARGANO,   15-May-2023
                                 apps.per_pay_bases ppb,
                                 apps.per_all_assignments_f asg	 
							--END R12.2.12 Upgrade remediation	 
                           WHERE TRUNC (SYSDATE)
                                    BETWEEN asg.effective_start_date
                                        AND asg.effective_end_date
                             AND asg.pay_basis_id = ppb.pay_basis_id
                             AND asg.assignment_id = ppps.assignment_id
                             AND ppps.change_date =
                                    (SELECT MAX (x.change_date)
                                       --FROM hr.per_pay_proposals x				-- Commented code by IXPRAVEEN-ARGANO,15-May-2023
                                       FROM apps.per_pay_proposals x                  --  code Added by IXPRAVEEN-ARGANO,   15-May-2023
                                      WHERE asg.assignment_id =
                                                               x.assignment_id
                                        AND (x.change_date) <= TRUNC (SYSDATE))) sal,
                         (SELECT DISTINCT UPPER (l.lookup_code) code,
                                          l.meaning category_name,
                                          s.security_group_key
                                                           security_group_key
                                     FROM apps.fnd_lookup_values l,
                                          apps.fnd_security_groups s
                                    WHERE l.lookup_type = 'EMP_CAT'
                                      AND enabled_flag = 'Y'
                                      AND LANGUAGE = 'US'
                                      AND l.security_group_id =
                                                           s.security_group_id
                                      AND l.LANGUAGE = USERENV ('LANG')) emp_cat,
                         pay_personal_payment_methods_f ppm,
                         hr.pay_external_accounts pea,
                         apps.pay_cost_allocations_f pcaf,
                         apps.pay_cost_allocation_keyflex pcak_asg,
                         apps.hr_soft_coding_keyflex scl,
                         apps.hr_all_organization_units hou,
                         apps.hr_all_organization_units hou1,
                         apps.pay_all_payrolls_f pap
                   WHERE papf.person_id = paaf.person_id
                     AND TRUNC (SYSDATE) BETWEEN papf.effective_start_date
                                             AND papf.effective_end_date
                     AND TRUNC (SYSDATE) BETWEEN paaf.effective_start_date(+) AND paaf.effective_end_date(+)
                     AND paaf.primary_flag = 'Y'
                     AND current_employee_flag = 'Y'
                     AND papf.business_group_id = 1839
                     AND papf.person_id = pa.person_id(+)
                     AND pa.address_type = fcl.lookup_code(+)
                     AND fcl.lookup_type(+) = 'ADDRESS_TYPE'
                     AND pa.primary_flag(+) = 'Y'
                     AND paaf.assignment_id = DEC.assignment_id(+)
                     AND paaf.period_of_service_id = ppos.period_of_service_id
                     AND papf.person_id = ppos.person_id
                     AND paaf.job_id = job.job_id(+)
                     AND job.job_definition_id = jdef.job_definition_id(+)
                     AND paaf.assignment_id = sal.assignment_id(+)
                     AND paaf.employment_category = emp_cat.code(+)
                     AND TO_CHAR (paaf.business_group_id) = emp_cat.security_group_key(+)
                     AND SYSDATE BETWEEN pa.date_from(+) AND NVL
                                                                (pa.date_to(+),
                                                                 '31-DEC-4712'
                                                                )
                     AND ppm.assignment_id(+) = paaf.assignment_id
                     AND SYSDATE BETWEEN ppm.effective_start_date(+) AND ppm.effective_end_date(+)
                     AND ppm.external_account_id = pea.external_account_id(+)
                     AND pea.segment4(+) = 'TRUE'
                     AND paaf.assignment_id = pcaf.assignment_id(+)
                     AND SYSDATE BETWEEN pcaf.effective_start_date(+) AND pcaf.effective_end_date(+)
                     AND pcaf.cost_allocation_keyflex_id = pcak_asg.cost_allocation_keyflex_id(+)
                     AND paaf.soft_coding_keyflex_id = scl.soft_coding_keyflex_id(+)
                     AND scl.segment1 = to_char(hou.organization_id(+))
                     AND SYSDATE BETWEEN hou.date_from(+) AND NVL
                                                                (hou.date_to(+),
                                                                 '31-DEC-4712'
                                                                )
                     AND (   actual_termination_date IS NULL
                          OR actual_termination_date >= TRUNC (SYSDATE)
                         )
                     AND NVL (payee_type, 'N') != 'O'
                     AND pap.payroll_id(+) = paaf.payroll_id
                     AND SYSDATE BETWEEN pap.effective_start_date(+) AND NVL
                                                                           (pap.effective_end_date(+),
                                                                            '31-DEC-4712'
                                                                           )
                     AND paaf.organization_id = hou1.organization_id(+)
                     AND SYSDATE BETWEEN hou1.date_from(+) AND NVL
                                                                 (hou1.date_to(+),
                                                                  '31-DEC-4712'
                                                                 )
                     AND HOU.name in (SELECT meaning
                                        FROM apps.fnd_lookup_values_vl
                                        WHERE 1=1
                                        and lookup_type = 'TTEC_TMF_LEGAL_ENTITY_CODES'
                                        --AND meaning = hou.NAME
                                        AND enabled_flag = 'Y'
                                        and lookup_code like 'AU%'
                                        AND SYSDATE BETWEEN nvl(start_date_active, SYSDATE) AND nvl(end_date_active, SYSDATE + 1)) -- Added for 1.2
																UNION
         SELECT DISTINCT papf.employee_number, 'TTEC' organization_name,
                         'AU' country_code, hou.NAME entity_number,
						 (SELECT lookup_code
                            FROM apps.fnd_lookup_values_vl
                           WHERE lookup_type = 'TTEC_TMF_LEGAL_ENTITY_CODES'
                             AND meaning = hou.NAME
							 AND ENABLED_FLAG = 'Y'
							 AND SYSDATE BETWEEN NVL(START_DATE_ACTIVE,SYSDATE) AND  NVL(END_DATE_ACTIVE,SYSDATE+1)) entity_code,		--Added by Vaibhav 19-DEC-2019 to pass entity code
                         NULL effective_date, NULL action_type,
                         papf.effective_start_date effective_date_per_change,
                         papf.title salutation_code
						 --Started modifiing by Vaibhav 07-FEB-2020 changes suggested by Ugander to Substr
						 --, papf.first_name
						 --, papf.middle_names
						 --, papf.last_name family_name
						 , SUBSTR(papf.first_name,1,25) first_name
						 , SUBSTR(papf.middle_names,1,25) middle_names
						 , SUBSTR(papf.last_name,1,25) family_name
						 --Ended modifiing by Vaibhav 07-FEB-2020 changes suggested by Ugander to Substr
						 , NULL preferred_name, NULL person_name_initials,
                         NULL maiden_or_previous_name,
                         TO_CHAR (papf.date_of_birth,
                                  'DD/MM/YYYY'
                                 ) date_of_birth,
                         country_of_birth, sex gender,
                         DECODE (NVL (marital_status, 'Unknown'),
                                 'M', 'Married',
                                 'S', 'Single',
                                 'BE_LIV_TOG', 'Co-Habiting',
                                 'DP', 'Civil Partnership',
                                 'W', 'Widowed',
                                 'L', 'Separated',
                                 'D', 'Divorced',
                                 'Unknown', 'Unknown',
                                 'Other'
                                ) marital_status,
                         NULL primary_language,
                         SUBSTR (DECODE (nationality,
                                         'TTAU_AU', 'AU',
                                         nationality
                                        ),
                                 1,
                                 2
                                ) nationality,
                         (SELECT eev13.screen_entry_value
                            FROM pay_element_entries_f pee,
                                 pay_element_types_f pet,
                                 pay_input_values_f piv13,
                                 pay_element_entry_values_f eev13
                           WHERE (piv13.NAME) = 'Tax File Number'
                             AND eev13.input_value_id = piv13.input_value_id
                             AND piv13.element_type_id = pet.element_type_id
                             AND eev13.element_entry_id = pee.element_entry_id
                             AND pet.element_name = 'Tax Information'
                             AND paaf.effective_start_date
                                    BETWEEN pet.effective_start_date
                                        AND pet.effective_end_date
                             AND paaf.effective_start_date
                                    BETWEEN eev13.effective_start_date
                                        AND eev13.effective_end_date
                             AND paaf.effective_start_date
                                    BETWEEN piv13.effective_start_date
                                        AND piv13.effective_end_date
                             AND paaf.effective_start_date
                                    BETWEEN pee.effective_start_date
                                        AND pee.effective_end_date
                             AND pee.assignment_id = paaf.assignment_id)
                                                                  national_id,
                         'Tax File Number' national_id_type,
                         NULL national_id2, NULL national_id2_type,
                         NULL national_id3, NULL national_id3_type,
                         NULL national_id4, NULL national_id4_type,
                         GREATEST
                            (paaf.effective_start_date,
                             pcaf.effective_start_date
                            ) effective_date_contract_change,
                         ppos.date_start hire_date,
                         NVL (ppos.adjusted_svc_date,
                              ppos.date_start
                             ) continuous_service_date,
                         'P' contract_type,
                         DECODE (pap.period_type,
                                 'Bi-Week', 'Bi-weekly'
                                ) period_type,
                         (jdef.segment1 || '-' || jdef.segment2) job_title,
						 --Started modifiing by Vaibhav 07-FEB-2020 changes suggested by Ugander to Substr
                         --pcak_asg.segment2 cost_center_code,
						 SUBSTR(pcak_asg.segment2,1,10) cost_center_code,
						 --Ended modifiing by Vaibhav 07-FEB-2020 changes suggested by Ugander to Substr
                         (SELECT ffvl.description
                            FROM apps.fnd_flex_values_vl ffvl,
                                 apps.fnd_flex_value_sets ffvs
                           WHERE flex_value = pcak_asg.segment2
                             AND ffvl.flex_value_set_id =
                                                        ffvs.flex_value_set_id
                             AND flex_value_set_name = 'TELETECH_CLIENT')
                                                             cost_center_name,
                         (proportion * 100) cost_centre_allo_split_percnt,
                         (SELECT segment3
                            FROM apps.pay_cost_allocation_keyflex
                           WHERE cost_allocation_keyflex_id =
                                               hou1.cost_allocation_keyflex_id)
                                                              department_code,
                         hou1.NAME department_name,
                         NULL other_cost_allocation_code,
                         (SELECT location_code
                            FROM apps.hr_locations
                           WHERE location_id = paaf.location_id) other_cost_allocation_name,
                         (SELECT attribute2
                            FROM apps.hr_locations
                           WHERE location_id = paaf.location_id)work_location,
                         pa.date_from effective_date_address_change,
                         NULL building_number
						 --Started modifiing by Vaibhav 07-FEB-2020 changes suggested by Ugander to Substr
                         --, pa.address_line1
						 --, pa.address_line2
						 --, pa.address_line3
						   , SUBSTR(pa.address_line1,1,30) address_line1
						   , SUBSTR(pa.address_line2,1,30) address_line2
						   , SUBSTR(pa.address_line3,1,30) address_line3
						 --Ended modifiing by Vaibhav 07-FEB-2020 changes suggested by Ugander to Substr
                         , NULL address_line4, pa.town_or_city city_name,
                         pa.postal_code,
                         (SELECT meaning
                            FROM apps.fnd_lookup_values_vl
                           WHERE lookup_type = 'AU_STATE'
                             AND lookup_code = pa.region_1) state,
                         country, papf.email_address,
                         sal.change_date effective_date_salary,
                         sal.salary basic_salary_rate,
                         sal.pay_basis salary_rate_type,
                         paaf.effective_start_date
                                               effective_date_schedule_change,
                         DECODE
                              (paaf.employment_category,
                               'TTAU_FT', 'Full-time',
                               'TTAU_PT', 'Part-time',
                               'TTAU_CS', 'Casual - AU',
                               NULL
                              ) fulltime_or_parttime,
                         ((paaf.normal_hours / 40) * 100
                         ) percentage_working,
                         normal_hours contracted_weekly_hours,
                         (   paaf.time_normal_start
                          || ' to '
                          || paaf.time_normal_finish
                         ) work_schedule_code,
                         NULL work_schedule_description,
                         ppm.effective_start_date effective_date_bank_change,
                         DECODE
                            ((SELECT payment_type_name
                                FROM pay_payment_types ppt,
                                     pay_org_payment_methods_f popm
                               WHERE popm.org_payment_method_id =
                                                     ppm.org_payment_method_id
                                 AND SYSDATE BETWEEN popm.effective_start_date
                                                 AND popm.effective_end_date
                                 AND popm.payment_type_id =
                                                           ppt.payment_type_id),
                             'Direct Entry', 'Bank Transfer',
                             'Cheque', 'Check'
                            ) payment_method,
                         'Saving' account_type, NULL swift_or_bic_code,
                         NULL local_bank_code, NULL bank_name,
                         pea.segment1 branch_code,
                         pea.segment2 bank_account_number,
                         NULL additional_account_id,
                         pea.segment3 account_name, NULL iban_number,
                         'AU' bank_country_code,
                         (SELECT currency_code
                            FROM pay_org_payment_methods_f popm
                           WHERE popm.org_payment_method_id =
                                      ppm.org_payment_method_id
                             AND SYSDATE BETWEEN popm.effective_start_date
                                             AND popm.effective_end_date)
                                                                currency_code,
                         ppm.amount payment_distribution_amount,
                         ppm.percentage payment_distribution_percent,
                         ppos.actual_termination_date
                                                   termination_effective_date,
                         (SELECT meaning
                            FROM apps.hr_lookups
                           WHERE lookup_type LIKE
                                          'LEAV_REAS'
                             AND lookup_code = ppos.leaving_reason)
                                                      termination_reason_code,
                         (SELECT meaning
                            FROM apps.hr_lookups
                           WHERE lookup_type LIKE
                                          'LEAV_REAS'
                             AND lookup_code = ppos.leaving_reason)
                                                      termination_reason_desc,
                         actual_termination_date last_paid_date,
                         NULL other_person_id, NULL other_person_id_desc,
                         papf.person_id, personal_payment_method_id,
                         cost_allocation_id,
						 (SELECT DECODE(
            eev13.screen_entry_value,
            'YS',
            'Y',
            'YI',
            'Y',
            'YC',
            'Y',
            'NN',
            'N',
            'YN',
            'Y',
            'Y',
            'Y',
            'N',
            'N',
            NULL
        )Australia_resident_flag
                            FROM pay_element_entries_f pee,
                                 pay_element_types_f pet,
                                 pay_input_values_f piv13,
                                 pay_element_entry_values_f eev13
                           WHERE (piv13.NAME) = 'Australian Resident'
                             AND eev13.input_value_id = piv13.input_value_id
                             AND piv13.element_type_id = pet.element_type_id
                             AND eev13.element_entry_id = pee.element_entry_id
                             AND pet.element_name = 'Tax Information'
                             AND TRUNC (SYSDATE)
                                    BETWEEN pet.effective_start_date
                                        AND pet.effective_end_date
                             AND TRUNC (SYSDATE)
                                    BETWEEN eev13.effective_start_date
                                        AND eev13.effective_end_date
                             AND TRUNC (SYSDATE)
                                    BETWEEN piv13.effective_start_date
                                        AND piv13.effective_end_date
                             AND TRUNC (SYSDATE)
                                    BETWEEN pee.effective_start_date
                                        AND pee.effective_end_date
                             AND pee.assignment_id = paaf.assignment_id)
                                                                 Australia_resident_flag,
                         (SELECT eev13.screen_entry_value Tax_free_threshold
                            FROM pay_element_entries_f pee,
                                 pay_element_types_f pet,
                                 pay_input_values_f piv13,
                                 pay_element_entry_values_f eev13
                           WHERE (piv13.NAME) = 'Tax Free Threshold'
                             AND eev13.input_value_id = piv13.input_value_id
                             AND piv13.element_type_id = pet.element_type_id
                             AND eev13.element_entry_id = pee.element_entry_id
                             AND pet.element_name = 'Tax Information'
                             AND TRUNC (SYSDATE)
                                    BETWEEN pet.effective_start_date
                                        AND pet.effective_end_date
                             AND TRUNC (SYSDATE)
                                    BETWEEN eev13.effective_start_date
                                        AND eev13.effective_end_date
                             AND TRUNC (SYSDATE)
                                    BETWEEN piv13.effective_start_date
                                        AND piv13.effective_end_date
                             AND TRUNC (SYSDATE)
                                    BETWEEN pee.effective_start_date
                                        AND pee.effective_end_date
                             AND pee.assignment_id = paaf.assignment_id)
                                                                Tax_Free_Threshold,
                         (SELECT DECODE(
            eev13.screen_entry_value,
            'Y',
            'Y',
            'N',
            'N',
            'YY',
            'Y',
            'NY',
            'N',
            NULL
        ) hecs_entry_value
                            FROM pay_element_entries_f pee,
                                 pay_element_types_f pet,
                                 pay_input_values_f piv13,
                                 pay_element_entry_values_f eev13
                           WHERE (piv13.NAME) = 'HECS'
                             AND eev13.input_value_id = piv13.input_value_id
                             AND piv13.element_type_id = pet.element_type_id
                             AND eev13.element_entry_id = pee.element_entry_id
                             AND pet.element_name = 'Tax Information'
                             AND TRUNC (SYSDATE)
                                    BETWEEN pet.effective_start_date
                                        AND pet.effective_end_date
                             AND TRUNC (SYSDATE)
                                    BETWEEN eev13.effective_start_date
                                        AND eev13.effective_end_date
                             AND TRUNC (SYSDATE)
                                    BETWEEN piv13.effective_start_date
                                        AND piv13.effective_end_date
                             AND TRUNC (SYSDATE)
                                    BETWEEN pee.effective_start_date
                                        AND pee.effective_end_date
                             AND pee.assignment_id = paaf.assignment_id)
                                                                 hecs_entry_value,
                         (SELECT DECODE(
            eev13.screen_entry_value,
            'YY',
            'Y',
            'NY',
            'Y',
            'N'
        ) sfss_entry_value
                            FROM pay_element_entries_f pee,
                                 pay_element_types_f pet,
                                 pay_input_values_f piv13,
                                 pay_element_entry_values_f eev13
                           WHERE (piv13.NAME) = 'HECS'
                             AND eev13.input_value_id = piv13.input_value_id
                             AND piv13.element_type_id = pet.element_type_id
                             AND eev13.element_entry_id = pee.element_entry_id
                             AND pet.element_name = 'Tax Information'
                             AND TRUNC (SYSDATE)
                                    BETWEEN pet.effective_start_date
                                        AND pet.effective_end_date
                             AND TRUNC (SYSDATE)
                                    BETWEEN eev13.effective_start_date
                                        AND eev13.effective_end_date
                             AND TRUNC (SYSDATE)
                                    BETWEEN piv13.effective_start_date
                                        AND piv13.effective_end_date
                             AND TRUNC (SYSDATE)
                                    BETWEEN pee.effective_start_date
                                        AND pee.effective_end_date
                             AND pee.assignment_id = paaf.assignment_id)
                                                                 sfss_entry_value,
                                                                 (SELECT
            PET.ELEMENT_NAME Super_fund_name
                                        FROM pay_element_entries_f pee,
                                 pay_element_types_f pet,
                                 pay_input_values_f piv13,
                                 pay_element_entry_values_f eev13
                           WHERE (piv13.NAME) = 'Member Number'
                             AND eev13.input_value_id = piv13.input_value_id
                             AND piv13.element_type_id = pet.element_type_id
                             AND eev13.element_entry_id = pee.element_entry_id
                            -- AND pet.element_name = 'Tax Information'
                             AND TRUNC (SYSDATE)
                                    BETWEEN pet.effective_start_date
                                        AND pet.effective_end_date
                             AND TRUNC (SYSDATE)
                                    BETWEEN eev13.effective_start_date
                                        AND eev13.effective_end_date
                             AND TRUNC (SYSDATE)
                                    BETWEEN piv13.effective_start_date
                                        AND piv13.effective_end_date
                             AND TRUNC (SYSDATE)
                                    BETWEEN pee.effective_start_date
                                        AND pee.effective_end_date
                             AND pee.assignment_id = paaf.assignment_id)
                                                                 Super_fund_name,
                                                                  (SELECT
            eev13.screen_entry_value Emp_fund_mem
                                        FROM pay_element_entries_f pee,
                                 pay_element_types_f pet,
                                 pay_input_values_f piv13,
                                 pay_element_entry_values_f eev13
                           WHERE (piv13.NAME) = 'Member Number'
                             AND eev13.input_value_id = piv13.input_value_id
                             AND piv13.element_type_id = pet.element_type_id
                             AND eev13.element_entry_id = pee.element_entry_id
                            -- AND pet.element_name = 'Tax Information'
                             AND TRUNC (SYSDATE)
                                    BETWEEN pet.effective_start_date
                                        AND pet.effective_end_date
                             AND TRUNC (SYSDATE)
                                    BETWEEN eev13.effective_start_date
                                        AND eev13.effective_end_date
                             AND TRUNC (SYSDATE)
                                    BETWEEN piv13.effective_start_date
                                        AND piv13.effective_end_date
                             AND TRUNC (SYSDATE)
                                    BETWEEN pee.effective_start_date
                                        AND pee.effective_end_date
                             AND pee.assignment_id = paaf.assignment_id)
                                                                 Emp_fund_mem,
                                                                  (SELECT eev13.screen_entry_value
                            FROM pay_element_entries_f pee,
                                 pay_element_types_f pet,
                                 pay_input_values_f piv13,
                                 pay_element_entry_values_f eev13
                           WHERE (piv13.NAME) = 'Tax File Number'
                             AND eev13.input_value_id = piv13.input_value_id
                             AND piv13.element_type_id = pet.element_type_id
                             AND eev13.element_entry_id = pee.element_entry_id
                             AND pet.element_name = 'Tax Information'
                             AND TRUNC (SYSDATE)
                                    BETWEEN pet.effective_start_date
                                        AND pet.effective_end_date
                             AND TRUNC (SYSDATE)
                                    BETWEEN eev13.effective_start_date
                                        AND eev13.effective_end_date
                             AND TRUNC (SYSDATE)
                                    BETWEEN piv13.effective_start_date
                                        AND piv13.effective_end_date
                             AND TRUNC (SYSDATE)
                                    BETWEEN pee.effective_start_date
                                        AND pee.effective_end_date
                             AND pee.assignment_id = paaf.assignment_id)
                                                                 TAX_FILE_NUMBER,
                        						 job.attribute20 gca_level
                    FROM apps.per_all_people_f papf,
                         apps.per_all_assignments_f paaf,
                         apps.per_addresses pa,
                         apps.fnd_common_lookups fcl,
                         apps.pay_payautax_pye_ent_v DEC,
                         apps.per_periods_of_service ppos,
                         apps.per_jobs job,
                         apps.per_job_definitions jdef,
                         (SELECT asg.assignment_id,
                                 ROUND
                                     ((  ppb.pay_annualization_factor
                                       * ppps.proposed_salary_n
                                      ),
                                      2
                                     ) salary,
                                 change_date, ppb.pay_basis pay_basis
                            --START R12.2 Upgrade Remediation
							/*FROM hr.per_pay_proposals ppps,				-- Commented code by IXPRAVEEN-ARGANO,15-May-2023
                                 hr.per_pay_bases ppb,                      
                                 hr.per_all_assignments_f asg*/
							FROM apps.per_pay_proposals ppps,				--  code Added by IXPRAVEEN-ARGANO,   15-May-2023
                                 apps.per_pay_bases ppb,
                                 apps.per_all_assignments_f asg	 
								 --END R12.2.12 Upgrade remediation
                           WHERE TRUNC (SYSDATE)
                                    BETWEEN asg.effective_start_date
                                        AND asg.effective_end_date
                             AND asg.pay_basis_id = ppb.pay_basis_id
                             AND asg.assignment_id = ppps.assignment_id
                             AND ppps.change_date =
                                    (SELECT MAX (x.change_date)
                                       --FROM hr.per_pay_proposals x			-- Commented code by IXPRAVEEN-ARGANO,15-May-2023
                                       FROM apps.per_pay_proposals x              --  code Added by IXPRAVEEN-ARGANO,   15-May-2023
                                      WHERE asg.assignment_id =
                                                               x.assignment_id
                                        AND (x.change_date) <= TRUNC (SYSDATE))) sal,
                         (SELECT DISTINCT UPPER (l.lookup_code) code,
                                          l.meaning category_name,
                                          s.security_group_key
                                                           security_group_key
                                     FROM apps.fnd_lookup_values l,
                                          apps.fnd_security_groups s
                                    WHERE l.lookup_type = 'EMP_CAT'
                                      AND enabled_flag = 'Y'
                                      AND LANGUAGE = 'US'
                                      AND l.security_group_id =
                                                           s.security_group_id
                                      AND l.LANGUAGE = USERENV ('LANG')) emp_cat,
                         pay_personal_payment_methods_f ppm,
                         hr.pay_external_accounts pea,
                         apps.pay_cost_allocations_f pcaf,
                         apps.pay_cost_allocation_keyflex pcak_asg,
                         apps.hr_soft_coding_keyflex scl,
                         apps.hr_all_organization_units hou,
                         apps.hr_all_organization_units hou1,
                         apps.pay_all_payrolls_f pap
                   WHERE papf.person_id = paaf.person_id
                     AND NVL (papf.current_employee_flag, 'N') <> 'Y'
                     AND TRUNC (SYSDATE) BETWEEN papf.effective_start_date
                                             AND papf.effective_end_date
                     AND paaf.effective_start_date =
                                          (SELECT MAX (effective_start_date)
                                             FROM per_all_assignments_f
                                            WHERE person_id = papf.person_id)
                     AND paaf.primary_flag = 'Y'
                     AND papf.business_group_id = 1839
                     AND papf.person_id = pa.person_id(+)
                     AND pa.address_type = fcl.lookup_code(+)
                     AND fcl.lookup_type(+) = 'ADDRESS_TYPE'
                     AND pa.primary_flag(+) = 'Y'
                     AND paaf.assignment_id = DEC.assignment_id(+)
                     AND paaf.period_of_service_id = ppos.period_of_service_id
                     AND papf.person_id = ppos.person_id
                     AND paaf.job_id = job.job_id(+)
                     AND job.job_definition_id = jdef.job_definition_id(+)
                     AND paaf.assignment_id = sal.assignment_id(+)
                     AND paaf.employment_category = emp_cat.code(+)
                     AND TO_CHAR (paaf.business_group_id) = emp_cat.security_group_key(+)
                     AND SYSDATE BETWEEN pa.date_from(+) AND NVL
                                                                (pa.date_to(+),
                                                                 '31-DEC-4712'
                                                                )
                     AND ppm.assignment_id(+) = paaf.assignment_id
                     AND paaf.effective_end_date BETWEEN ppm.effective_start_date(+) AND ppm.effective_end_date(+)
                     AND ppm.external_account_id = pea.external_account_id(+)
                     AND pea.segment4(+) = 'TRUE'
                     AND paaf.assignment_id = pcaf.assignment_id(+)
                     AND paaf.effective_end_date BETWEEN pcaf.effective_start_date(+) AND pcaf.effective_end_date(+)
                     AND pcaf.cost_allocation_keyflex_id = pcak_asg.cost_allocation_keyflex_id(+)
                     AND paaf.soft_coding_keyflex_id = scl.soft_coding_keyflex_id(+)
                     AND scl.segment1 = to_char(hou.organization_id(+))
                     AND SYSDATE BETWEEN hou.date_from(+) AND NVL
                                                                (hou.date_to(+),
                                                                 '31-DEC-4712'
                                                                )
                     AND NVL (payee_type, 'N') != 'O'
                     AND ppos.actual_termination_date IS NOT NULL
                     AND GREATEST (ppos.actual_termination_date,
                                   TRUNC (ppos.last_update_date)
                                  ) BETWEEN NVL (TRUNC (v_last_run_date),
                                                 TRUNC (SYSDATE - 15)
                                                )
                                        AND TRUNC (SYSDATE)
                     AND pap.payroll_id(+) = paaf.payroll_id
                     AND SYSDATE BETWEEN pap.effective_start_date(+) AND NVL
                                                                           (pap.effective_end_date(+),
                                                                            '31-DEC-4712'
                                                                           )
                     AND paaf.organization_id = hou1.organization_id(+)
                     AND SYSDATE BETWEEN hou1.date_from(+) AND NVL
                                                                 (hou1.date_to(+),
                                                                  '31-DEC-4712'
                                                                 )
                     AND HOU.name in (SELECT meaning
                                        FROM apps.fnd_lookup_values_vl
                                        WHERE 1=1
                                        and lookup_type = 'TTEC_TMF_LEGAL_ENTITY_CODES'
                                        --AND meaning = hou.NAME
                                        AND enabled_flag = 'Y'
                                        and lookup_code like 'AU%'
                                        AND SYSDATE BETWEEN nvl(start_date_active, SYSDATE) AND nvl(end_date_active, SYSDATE + 1)) -- Added for 1.2
                ORDER BY employee_number;
				--c_employee
      CURSOR c_emp
      IS
         SELECT *
           FROM apps.ttec_aus_tmf_intf_stg;

      CURSOR c_columns
      IS
         SELECT column_name, data_type
           FROM all_tab_columns
          WHERE owner = v_table_owner
            AND table_name = v_table_name
            AND column_name NOT IN
                   ('ATTRIBUTE1', 'ATTRIBUTE2', 'ATTRIBUTE3', 'ATTRIBUTE4',
                    'ATTRIBUTE5', 'ATTRIBUTE6', 'ATTRIBUTE7', 'ATTRIBUTE8',
                    'ATTRIBUTE9', 'ATTRIBUTE10', 'ATTRIBUTE11', 'ATTRIBUTE12',
                    'ATTRIBUTE13', 'ATTRIBUTE14', 'ATTRIBUTE15', 'PERSON_ID',
                    'COST_ALLOCATION_ID', 'PERSONAL_PAYMENT_METHOD_ID',
                    'EFFECTIVE_DATE', 'LAST_UPDATE_DATE', 'LAST_UPDATED_BY',
                    'CREATION_DATE', 'CREATED_BY', 'REQUEST_ID',
                    'EMPLOYEE_NUMBER', 'ORGANIZATION_NAME', 'COUNTRY_CODE',
                    'ACTION_TYPE', 'EFFECTIVE_DATE_BANK_CHANGE',
                    'EFFECTIVE_DATE_SCHEDULE_CHANGE',
                    'EFFECTIVE_DATE_ADDRESS_CHANGE',
                    'EFFECTIVE_DATE_CONTRACT_CHANGE', 'EFFECTIVE_DATE_SALARY',
                    'EFFECTIVE_DATE_PER_CHANGE', 'TERMINATION_EFFECTIVE_DATE',
                    'TERMINATION_REASON_CODE', 'TERMINATION_REASON_DESC',
                    'LAST_PAID_DATE');

      employee_rec                   c_employee%ROWTYPE;
      emp_rec                        c_emp%ROWTYPE;
      columns_rec                    c_columns%ROWTYPE;
   BEGIN
      fnd_global.apps_initialize (g_user_id, g_resp_id, g_resp_appl_id);
      v_loc := 0;
	  --fnd_file.put_line (fnd_file.LOG,'v_loc '||v_loc);

      SELECT DECODE (host_name,
                     ttec_library.xx_ttec_prod_host_name, 'PROD',
                     'TEST'
                    )
        INTO v_instance_name
        FROM v$instance;

      BEGIN
         v_loc := 5;
		 --fnd_file.put_line (fnd_file.LOG,'v_loc '||v_loc);

         DELETE      apps.ttec_aus_tmf_intf_stg;

         --Staging table to store records temporarily
         DELETE      apps.ttec_aus_tmf_intf_bk;

         --Back up table to store last run records
         INSERT INTO apps.ttec_aus_tmf_intf_bk
            (SELECT *
               FROM apps.ttec_aus_tmf_intf);

         --main table to store latest records till next run
         v_loc := 10;
		 --fnd_file.put_line (fnd_file.LOG,'v_loc '||v_loc);
         COMMIT;
      EXCEPTION
         WHEN OTHERS
         THEN
            ttec_intf_error (NULL,
                             'ttec_aus_ora_tmf_intf_pkg.main',
                             'Main Interface',
                             'Error',
                             v_loc,
                             SQLERRM,
                             NULL,
                             NULL,
                             NULL,
                             NULL
                            );
      END;

      v_loc := 15;
	  --fnd_file.put_line (fnd_file.LOG,'v_loc '||v_loc);

      BEGIN
         r_employee.attribute1 := NULL;
         r_employee.attribute2 := NULL;
         r_employee.attribute3 := NULL;
         r_employee.attribute4 := NULL;
         r_employee.attribute5 := NULL;
         r_employee.attribute6 := NULL;
         r_employee.attribute7 := NULL;
         r_employee.attribute8 := NULL;
         r_employee.attribute9 := NULL;
         r_employee.attribute10 := NULL;
         r_employee.attribute11 := NULL;
         r_employee.attribute12 := NULL;
         r_employee.attribute13 := NULL;
         r_employee.attribute14 := NULL;
         r_employee.attribute15 := NULL;
         r_employee.effective_date := SYSDATE;
         r_employee.last_update_date := SYSDATE;
         r_employee.last_updated_by := g_user_id;
         r_employee.creation_date := SYSDATE;
         r_employee.created_by := g_user_id;
         r_employee.request_id := g_conc_req_id;
         v_loc := 20;
		 --fnd_file.put_line (fnd_file.LOG,'v_loc '||v_loc);

         SELECT NVL (MAX (actual_start_date), NULL)
           INTO v_last_run_date
           FROM apps.fnd_concurrent_requests fcr,
                apps.fnd_concurrent_programs fcp
          WHERE fcp.concurrent_program_id = fcr.concurrent_program_id
            AND fcp.concurrent_program_name = 'TTEC_AUS_TMF'
            AND fcr.status_code = 'C'
            AND fcr.phase_code = 'C';

         fnd_file.put_line (fnd_file.LOG,
                            TO_CHAR (v_last_run_date, 'dd:mm:yyyy hh24:mi:ss')
                           );

         FOR employee_rec IN c_employee (v_last_run_date)
         LOOP
            BEGIN
               r_employee.employee_number := employee_rec.employee_number;
               r_employee.organization_name := employee_rec.organization_name;
               r_employee.country_code := employee_rec.country_code;
               r_employee.entity_number := employee_rec.entity_number;
			   r_employee.entity_code := employee_rec.entity_code;
               r_employee.effective_date_per_change :=
                                       employee_rec.effective_date_per_change;
               r_employee.salutation_code := employee_rec.salutation_code;
               r_employee.first_name := employee_rec.first_name;
               r_employee.middle_names := employee_rec.middle_names;
               r_employee.family_name := employee_rec.family_name;
               r_employee.preferred_name := employee_rec.preferred_name;
               r_employee.person_name_initials :=
                                            employee_rec.person_name_initials;
               r_employee.maiden_or_previous_name :=
                                         employee_rec.maiden_or_previous_name;
               r_employee.date_of_birth := employee_rec.date_of_birth;
               r_employee.country_of_birth := employee_rec.country_of_birth;
               r_employee.gender := employee_rec.gender;
               r_employee.marital_status := employee_rec.marital_status;
               r_employee.primary_language := employee_rec.primary_language;
               r_employee.nationality := employee_rec.nationality;
               r_employee.national_id := employee_rec.national_id;
               r_employee.national_id_type := employee_rec.national_id_type;
               r_employee.national_id2 := employee_rec.national_id2;
               r_employee.national_id2_type := employee_rec.national_id2_type;
               r_employee.national_id3 := employee_rec.national_id3;
               r_employee.national_id3_type := employee_rec.national_id3_type;
               r_employee.national_id4 := employee_rec.national_id4;
               r_employee.national_id4_type := employee_rec.national_id4_type;
               r_employee.effective_date_contract_change :=
                                  employee_rec.effective_date_contract_change;
               r_employee.hire_date := employee_rec.hire_date;
               r_employee.continuous_service_date :=
                                         employee_rec.continuous_service_date;
               r_employee.contract_type := employee_rec.contract_type;
               r_employee.period_type := employee_rec.period_type;
               r_employee.job_title := employee_rec.job_title;
               r_employee.cost_center_code := employee_rec.cost_center_code;
               r_employee.cost_center_name := employee_rec.cost_center_name;
               r_employee.cost_centre_allo_split_percnt :=
                                   employee_rec.cost_centre_allo_split_percnt;
               r_employee.department_code := employee_rec.department_code;
               r_employee.department_name := employee_rec.department_name;
               r_employee.other_cost_allocation_code :=
                                      employee_rec.other_cost_allocation_code;
               r_employee.other_cost_allocation_name :=
                                      employee_rec.other_cost_allocation_name;
               r_employee.work_location := employee_rec.work_location;
               r_employee.effective_date_address_change :=
                                   employee_rec.effective_date_address_change;
               r_employee.building_number := employee_rec.building_number;
               r_employee.address_line1 := employee_rec.address_line1;
               r_employee.address_line2 := employee_rec.address_line2;
               r_employee.address_line3 := employee_rec.address_line3;
               r_employee.address_line4 := employee_rec.address_line4;
               r_employee.city_name := employee_rec.city_name;
               r_employee.postal_code := employee_rec.postal_code;
               r_employee.state := employee_rec.state;
               r_employee.country := employee_rec.country;
               r_employee.email_address := employee_rec.email_address;
               r_employee.effective_date_salary :=
                                           employee_rec.effective_date_salary;
               r_employee.basic_salary_rate := employee_rec.basic_salary_rate;
               r_employee.salary_rate_type := employee_rec.salary_rate_type;
               r_employee.effective_date_schedule_change :=
                                  employee_rec.effective_date_schedule_change;
               r_employee.fulltime_or_parttime :=
                                            employee_rec.fulltime_or_parttime;
               r_employee.percentage_working :=
                                              employee_rec.percentage_working;
               r_employee.contracted_weekly_hours :=
                                         employee_rec.contracted_weekly_hours;
               r_employee.work_schedule_code :=
                                              employee_rec.work_schedule_code;
               r_employee.work_schedule_description :=
                                       employee_rec.work_schedule_description;
               r_employee.effective_date_bank_change :=
                                      employee_rec.effective_date_bank_change;
               r_employee.payment_method := employee_rec.payment_method;
               r_employee.account_type := employee_rec.account_type;
               r_employee.swift_or_bic_code := employee_rec.swift_or_bic_code;
               r_employee.local_bank_code := employee_rec.local_bank_code;
               r_employee.bank_name := employee_rec.bank_name;
               r_employee.branch_code := employee_rec.branch_code;
               r_employee.bank_account_number :=
                                             employee_rec.bank_account_number;
               r_employee.additional_account_id :=
                                           employee_rec.additional_account_id;
               r_employee.account_name := employee_rec.account_name;
               r_employee.iban_number := employee_rec.iban_number;
               r_employee.bank_country_code := employee_rec.bank_country_code;
               r_employee.currency_code := employee_rec.currency_code;
               r_employee.payment_distribution_amount :=
                                     employee_rec.payment_distribution_amount;
               r_employee.payment_distribution_percent :=
                                    employee_rec.payment_distribution_percent;
               r_employee.termination_effective_date :=
                                      employee_rec.termination_effective_date;
               r_employee.termination_reason_code :=
                                         employee_rec.termination_reason_code;
               r_employee.termination_reason_desc :=
                                         employee_rec.termination_reason_desc;
               r_employee.last_paid_date := employee_rec.last_paid_date;
               r_employee.other_person_id := employee_rec.other_person_id;
               r_employee.other_person_id_desc :=
                                            employee_rec.other_person_id_desc;
               r_employee.person_id := employee_rec.person_id;
               r_employee.cost_allocation_id :=
                                              employee_rec.cost_allocation_id;
               r_employee.personal_payment_method_id :=
                                      employee_rec.personal_payment_method_id;
			   r_employee.australian_resd_tax_purpose := employee_rec.Australia_resident_flag;
			   r_employee.tax_free_thresh_claimed_or_not := employee_rec.Tax_free_threshold;
			   r_employee.hecs_debt := employee_rec.hecs_entry_value;
			   r_employee.sfss_debt := employee_rec.sfss_entry_value;
			   r_employee.Super_fund_name := employee_rec.Super_fund_name;
			   r_employee.emp_fund_membership_number := employee_rec.Emp_fund_mem;
			   r_employee.tax_file_number := employee_rec.TAX_FILE_NUMBER;
               r_employee.gca_level := employee_rec.gca_level;
               v_loc := 25;
			   --fnd_file.put_line (fnd_file.LOG,'v_loc '||v_loc);

               INSERT INTO apps.ttec_aus_tmf_intf_stg
                    VALUES r_employee;
            EXCEPTION
               WHEN OTHERS
               THEN
                  ttec_intf_error (NULL,
                                   'ttec_aus_ora_tmf_intf_pkg.main',
                                   'MAIN Interface',
                                   'Error',
                                   v_loc,
                                   SQLERRM,
                                   'Employee Number',
                                   employee_rec.employee_number,
                                   'Assignment ID',
                                   NULL
                                  );
            END;
         END LOOP;

         v_loc := 30;
		 --fnd_file.put_line (fnd_file.LOG,'v_loc '||v_loc);
      EXCEPTION
         WHEN OTHERS
         THEN
            ttec_intf_error (NULL,
                             'ttec_aus_ora_tmf_intf_pkg.main',
                             'MAIN Interface',
                             'Error',
                             v_loc,
                             SQLERRM,
                             'Employee Number',
                             employee_rec.employee_number,
                             'Assignment ID',
                             NULL
                            );
            p_retcode := 2;
            p_errbuff := 'Exception in Main cursor';
            RETURN;
      END;

      v_loc := 35;
	  --fnd_file.put_line (fnd_file.LOG,'v_loc '||v_loc);

      BEGIN
         FOR emp_rec IN c_emp
         LOOP
            v_loc := 40;
			--fnd_file.put_line (fnd_file.LOG,'v_loc '||v_loc);
            v_select :=
               ' SELECT pis.employee_number, pis.person_id, pis.cost_allocation_id,pis.personal_payment_method_id,pis.action_type';
            v_from :=
               ' FROM apps.ttec_aus_tmf_intf_stg pis, apps.ttec_aus_tmf_intf pi ';
            v_where :=
               ' WHERE pis.employee_number = pi.employee_number AND pis.person_id = pi.person_id
                AND nvl(pis.cost_allocation_id,-9999) = nvl(pi.cost_allocation_id,-9999)
                AND nvl(pis.personal_payment_method_id,-9999) = nvl(pi.personal_payment_method_id,-9999)';
            v_loc := 45;
			--fnd_file.put_line (fnd_file.LOG,'v_loc '||v_loc);

            FOR columns_rec IN c_columns
            LOOP
               IF columns_rec.data_type = 'VARCHAR2'
               THEN
                  v_col_pis :=
                         ' NVL(pis.' || columns_rec.column_name || ',''*'') ';
                  v_col_pi :=
                          ' NVL(pi.' || columns_rec.column_name || ',''*'') ';
               ELSIF columns_rec.data_type = 'NUMBER'
               THEN
                  v_col_pis :=
                        ' NVL(pis.' || columns_rec.column_name || ', -9999) ';
                  v_col_pi :=
                         ' NVL(pi.' || columns_rec.column_name || ', -9999) ';
               ELSIF columns_rec.data_type = 'DATE'
               THEN
                  v_col_pis :=
                        ' NVL(pis.'
                     || columns_rec.column_name
                     || ', ''01-JAN-1000'') ';
                  v_col_pi :=
                        ' NVL(pi.'
                     || columns_rec.column_name
                     || ', ''01-JAN-1000'') ';
               END IF;

               v_where := v_where || ' AND ' || v_col_pis || ' = ' || v_col_pi;
               v_loc := 50;
			   --fnd_file.put_line (fnd_file.LOG,'v_loc '||v_loc);
            END LOOP;

            v_loc := 55;
			--fnd_file.put_line (fnd_file.LOG,'v_loc '||v_loc);
            v_where :=
                  v_where
               || ' AND pis.employee_number = NVL(:employee_number, pis.employee_number) ';
            v_where :=
                  v_where
               || ' AND pis.person_id = NVL(:person_id, pis.person_id) ';
            v_where :=
                  v_where
               || ' AND nvl(pis.cost_allocation_id,-9999) = NVL(:cost_allocation_id, nvl(pis.cost_allocation_id,-9999)) ';
            v_where :=
                  v_where
               || ' AND nvl(pis.personal_payment_method_id,-9999) = NVL(:personal_payment_method_id, nvl(pis.personal_payment_method_id,-9999)) ';
            v_sql := v_select || v_from || v_where;
            fnd_file.put_line (fnd_file.LOG, 'Dynamic SQL Statement');
            fnd_file.put_line (fnd_file.LOG,
                               '------------------------------------'
                              );
            fnd_file.put_line (fnd_file.LOG, v_sql);
            fnd_file.new_line (fnd_file.LOG, 1);
            v_loc := 60;
			--fnd_file.put_line (fnd_file.LOG,'v_loc '||v_loc);

            OPEN comp_emp FOR v_sql
            USING emp_rec.employee_number,
                  emp_rec.person_id,
                  emp_rec.cost_allocation_id,
                  emp_rec.personal_payment_method_id;

            LOOP
               FETCH comp_emp
                INTO v_employee_number, v_person_id, v_cost_allocation_id,
                     v_personal_payment_method_id,v_action_type;

               v_loc := 65;
			   --fnd_file.put_line (fnd_file.LOG,'v_loc '||v_loc);

               IF comp_emp%NOTFOUND
               THEN
                  SELECT COUNT (*)
                    INTO v_count
                    FROM apps.ttec_aus_tmf_intf
                   WHERE employee_number = emp_rec.employee_number
                     AND person_id = emp_rec.person_id
                     AND NVL (cost_allocation_id, '-9999') =
                                     NVL (emp_rec.cost_allocation_id, '-9999')
                     AND NVL (personal_payment_method_id, '-9999') =
                             NVL (emp_rec.personal_payment_method_id, '-9999');

                  v_loc := 70;
				  --fnd_file.put_line (fnd_file.LOG,'v_loc '||v_loc);

				  fnd_file.put_line (fnd_file.LOG, 'Checking the count');
				  fnd_file.put_line (fnd_file.LOG,' Action Type for Stg :'||v_action_type);

				  fnd_file.put_line (fnd_file.LOG, v_count );

				  fnd_file.put_line (fnd_file.LOG, emp_rec.employee_number );

                  IF v_count > 0
                  THEN
                     UPDATE apps.ttec_aus_tmf_intf
                        SET entity_number = emp_rec.entity_number,
                            entity_code = emp_rec.entity_code,
                            last_update_date = SYSDATE,
                            last_updated_by = g_user_id,
                            effective_date = SYSDATE,
                            request_id = g_conc_req_id,
                            action_type = 'C'
                      WHERE employee_number = emp_rec.employee_number
                        AND person_id = emp_rec.person_id
                        AND NVL (cost_allocation_id, '-9999') =
                                     NVL (emp_rec.cost_allocation_id, '-9999')
                        AND NVL (personal_payment_method_id, '-9999') =
                               NVL (emp_rec.personal_payment_method_id,
                                    '-9999'
                                   )
                        AND (NVL (entity_number, 'A') <>
                                              NVL (emp_rec.entity_number, 'A')
											  OR
						 NVL (entity_code, 'A') <>
                                              NVL (emp_rec.entity_code, 'A'))			--Added by Vaibhav 19-DEC-2019 to pass entity code
											  ;

											  fnd_file.put_line (fnd_file.LOG,'v_loc '||v_loc);
											  fnd_file.put_line (fnd_file.LOG,'Updated ttec_aus_tmf_intf for action_type = Changed ');

                     UPDATE apps.ttec_aus_tmf_intf_stg
                        SET action_type = 'C'
                      WHERE employee_number = emp_rec.employee_number
                        AND person_id = emp_rec.person_id
                        AND NVL (cost_allocation_id, '-9999') =
                                     NVL (emp_rec.cost_allocation_id, '-9999')
                        AND NVL (personal_payment_method_id, '-9999') =
                               NVL (emp_rec.personal_payment_method_id,
                                    '-9999'
                                   );

                     v_loc := 75;
					 --fnd_file.put_line (fnd_file.LOG,'v_loc '||v_loc);
					 fnd_file.put_line (fnd_file.LOG,'Updated ttec_aus_tmf_intf_stg for action_type = Changed ');
                  ELSE	--IF v_count > 0

                  IF emp_rec.termination_effective_date is null then
                     UPDATE apps.ttec_aus_tmf_intf_stg
                        SET action_type = 'S'
                      WHERE employee_number = emp_rec.employee_number
                        AND person_id = emp_rec.person_id
                        AND NVL (cost_allocation_id, '-9999') =
                                     NVL (emp_rec.cost_allocation_id, '-9999')
                        AND NVL (personal_payment_method_id, '-9999') =
                               NVL (emp_rec.personal_payment_method_id,
                                    '-9999'
                                   );
								   				 fnd_file.put_line (fnd_file.LOG,'Updated Staging table  action type for Starter Record.');

                  ELSE --IF emp_rec.termination_effective_date is null
                   UPDATE apps.ttec_aus_tmf_intf_stg
                      SET action_type = 'L',
                          effective_date_per_change = NULL,
                          salutation_code = NULL,
                          first_name = NULL,
                          middle_names = NULL,
                          family_name = NULL,
                          preferred_name = NULL,
                          person_name_initials = NULL,
                          maiden_or_previous_name = NULL,
                          date_of_birth = NULL,
                          country_of_birth = NULL,
                          gender = NULL,
                          marital_status = NULL,
                          primary_language = NULL,
                          nationality = NULL,
                          national_id = NULL,
                          national_id_type = NULL,
                          national_id2 = NULL,
                          national_id2_type = NULL,
                          national_id3 = NULL,
                          national_id3_type = NULL,
                          national_id4 = NULL,
                          national_id4_type = NULL,
                          effective_date_contract_change = NULL,
                          hire_date = NULL,
                          continuous_service_date = NULL,
                          contract_type = NULL,
                          period_type = NULL,
                          job_title = NULL,
                          cost_center_code = NULL,
                          cost_center_name = NULL,
                          cost_centre_allo_split_percnt = NULL,
                          department_code = NULL,
                          department_name = NULL,
                          other_cost_allocation_code = NULL,
                          other_cost_allocation_name = NULL,
                          work_location = NULL,
                          effective_date_address_change = NULL,
                          building_number = NULL,
                          address_line1 = NULL,
                          address_line2 = NULL,
                          address_line3 = NULL,
                          address_line4 = NULL,
                          city_name = NULL,
                          postal_code = NULL,
                          state = NULL,
                          country = NULL,
                          email_address = NULL,
                          effective_date_salary = NULL,
                          basic_salary_rate = NULL,
                          salary_rate_type = NULL,
                          effective_date_schedule_change = NULL,
                          fulltime_or_parttime = NULL,
                          percentage_working = NULL,
                          contracted_weekly_hours = NULL,
                          work_schedule_code = NULL,
                          work_schedule_description = NULL,
                          effective_date_bank_change = NULL,
                          payment_method = NULL,
                          account_type = NULL,
                          swift_or_bic_code = NULL,
                          local_bank_code = NULL,
                          bank_name = NULL,
                          branch_code = NULL,
                          bank_account_number = NULL,
                          additional_account_id = NULL,
                          account_name = NULL,
                          iban_number = NULL,
                          bank_country_code = NULL,
                          currency_code = NULL,
                          payment_distribution_amount = NULL,
                          payment_distribution_percent = NULL,
                          other_person_id = NULL,
                          other_person_id_desc = NULL,
						  australian_resd_tax_purpose = NULL,
									  tax_free_thresh_claimed_or_not = NULL,
									  hecs_debt = NULL,
									  sfss_debt = NULL,
									  Super_fund_name = NULL,
									  emp_fund_membership_number = NULL,
									  tax_file_number = NULL,
                          gca_level = NULL
                    WHERE employee_number = emp_rec.employee_number
                      AND person_id = emp_rec.person_id
                      AND NVL (cost_allocation_id, '-9999') =
                                         NVL (emp_rec.cost_allocation_id, '-9999')
                      AND NVL (personal_payment_method_id, '-9999') =
                                 NVL (emp_rec.personal_payment_method_id, '-9999');
								 fnd_file.put_line (fnd_file.LOG,'Updated Staging table  action type for Leaver Record.');
                  END IF; --IF emp_rec.termination_effective_date is null
                     INSERT INTO apps.ttec_aus_tmf_intf
                        (SELECT *
                           FROM apps.ttec_aus_tmf_intf_stg
                          WHERE employee_number = emp_rec.employee_number
                            AND person_id = emp_rec.person_id
                            AND NVL (cost_allocation_id, '-9999') =
                                     NVL (emp_rec.cost_allocation_id, '-9999')
                            AND NVL (personal_payment_method_id, '-9999') =
                                   NVL (emp_rec.personal_payment_method_id,
                                        '-9999'
                                       ));

									   fnd_file.put_line (fnd_file.LOG,'Inserted Records into ttec_aus_tmf_intf table');
                  END IF;	--IF v_count > 0

                  EXIT;
                  v_loc := 80;
				  --fnd_file.put_line (fnd_file.LOG,'v_loc '||v_loc);
               END IF;	--IF comp_emp%NOTFOUND

               emp_rec.employee_number := NULL;
               emp_rec.person_id := NULL;
               emp_rec.cost_allocation_id := NULL;
               emp_rec.personal_payment_method_id := NULL;
            END LOOP;

            v_loc := 85;
			--fnd_file.put_line (fnd_file.LOG,'v_loc '||v_loc);

            CLOSE comp_emp;
         END LOOP;

         v_loc := 90;
		 --fnd_file.put_line (fnd_file.LOG,'v_loc '||v_loc);
      EXCEPTION
         WHEN OTHERS
         THEN
            ttec_intf_error (NULL,
                             'ttec_aus_ora_tmf_intf_pkg.main',
                             'MAIN Interface',
                             'Error',
                             v_loc,
                             SQLERRM,
                             'Employee Number',
                             NULL,
                             'Assignment ID',
                             NULL
                            );
      END;

      v_loc := 95;
	  --fnd_file.put_line (fnd_file.LOG,'v_loc '||v_loc);
      COMMIT;
      ttec_aus_per_change (p_errbuff, p_retcode);
	  ttec_aus_extra_change (p_errbuff,p_retcode);
      ttec_aus_asg_change (p_errbuff, p_retcode);
      ttec_aus_address_change (p_errbuff, p_retcode);
      ttec_aus_schedule_change (p_errbuff, p_retcode);
      ttec_aus_bank_change (p_errbuff, p_retcode);
      ttec_aus_salary_change (p_errbuff, p_retcode);
      ttec_aus_per_term (p_errbuff, p_retcode, v_last_run_date);
      ttec_aus_file_gen (p_errbuff, p_retcode);
   EXCEPTION
      WHEN OTHERS
      THEN
         ttec_intf_error (NULL,
                          'ttec_aus_ora_tmf_intf_pkg.main',
                          'Main Interface',
                          'Error',
                          v_loc,
                          SQLERRM,
                          NULL,
                          NULL,
                          NULL,
                          NULL
                         );
   END main;
END ttec_aus_ora_tmf_intf_pkg;
/
show errors;
/