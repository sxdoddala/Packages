create or replace PACKAGE BODY TTEC_PA_PROJECTS_TASKS_PKG AS

  /*

  Teletech Code Version
  =================================================================================
  Version       jerric             V0         21-FEB-2014
  Version       Jerric             V1         24-FEB-2014    Default class code changed 'TT Capital' Removed
                                                             and Carrying out organization is changed
  Version       Jerric             V2         17-MAR-2014    Change in Location logic since location is removed from Templates as Requested by Gagan and Dharam
  Version       Jerric             V3         17-MAR-2014    Location is made as non mandatory for all Templates as Requested by Gagan and Dharam.
  Version       Jerric             V4         26-MAR-2014    Project opertaion manager logice change
  RXNETHI-ARGANO   17/MAY/2023     1.0     R12.2 Upgrade Remediation
  */

  lg_organization_id     number;
  gc_newrecord_flag      varchar2(1) := 'N';
  gc_error_flag          varchar2(1) := 'E';
  gc_validation_flag     varchar2(1) := 'V';
  gc_transformation_flag varchar2(1) := 'N';
  gc_process_flag        varchar2(1) := 'P';
  vgc_program_start_date date := sysdate;
  gn_request_id          number := fnd_global.conc_request_id;

  PROCEDURE wrtout(p_buff IN VARCHAR2) IS

    -------------------------------------------------------------------------------
  BEGIN

    fnd_file.put_line(fnd_file.output, p_buff);

  END wrtout;

  PROCEDURE write_report_header IS

  BEGIN
    wrtout('');
    wrtout('');
    wrtout('Date: ' ||
           TO_CHAR(vgc_program_start_date, 'DD-MON-YYYY HH24:MI') ||
           LPAD('Tata Teletech - Load Project and task details report', 60));
    -- wrtout('Run by: ' || vgc_who_values(who_user_name));
    wrtout('');
    wrtout('------- ------------------------------ ---------- --------------- --------------------------------------------------');
    wrtout('Project Number         ' || '|' || 'Error Message');
    wrtout('------- ------------------------------ ---------- --------------- --------------------------------------------------');

  END write_report_header;

  Procedure insert_errors(p_project_name   in varchar2,
                          p_project_number in varchar2,
                          p_error_flag     in varchar2,
                          p_error_message  varchar2) is

  BEGIN
    insert into tlt_pa_validation_error
      (project_name, Project_number, error_flag, error_message)
    values
      (p_project_name, p_project_number, p_error_flag, p_error_message);

  Exception
    When others then
      null;

  End insert_errors;

  PROCEDURE wrtlog(p_buff IN VARCHAR2) IS
    -------------------------------------------------------------------------------
  BEGIN

    fnd_file.put_line(fnd_file.LOG, p_buff);

  END wrtlog;

  Procedure validate_records(p_validate_data_flag IN VARCHAR2) IS

    ln_customer_id     Number;
    ln_location_id     Number;
    ln_person_id       Number;
    ln_cnt             Number;
    lc_project_type    pa_project_types_all.project_type%Type;
    lc_project_status  pa_project_statuses.project_status_code%Type;
    lc_employee_number Varchar2(300);
    lc_error_message   Varchar2(32000) := 'ERROR MSG:';
    lc_status_flag     Varchar2(300);
    lc_cross_charge    Varchar2(300);
    lc_allow_charges   Varchar2(300);

    ln_billto_address_id      Number;
    ln_shipto_address_id      Number;
    ln_task_manager_person_id Number;
    ln_product_code           Varchar2(60) := 'CONVERSION';
    ln_project_name           Varchar2(200);
    -- ln_organization_id  Number;
    ln_owning_org_id number;
    ln_status_code   varchar2(50);

    ln_long_name              Varchar2(200);
    ln_project_status         Varchar2(200);
    ln_effective_start_date   per_all_people_f.effective_start_date%type;
    ln_task_name              Varchar2(200);
    ln_task_number            Varchar2(200);
    ln_template_id            number;
    ln_task_start_date        date;
    ln_start_date             pa_projects_all.start_date%type;
    ln_completion_date        pa_projects_all.completion_date%type;
    ln_end_date               date;
    ln_task_end_date          date;
    ln_class_category         varchar2(100);
    ln_class_code             varchar(100);
    ln_attribute1             varchar(50);
    ln_attribute2             varchar(50);
    ln_completion_date_FORMAT Varchar2(11) := null;
    ln_start_date_format      Varchar2(11) := null;
    ln_prevalrec_cnt          number := 0;
    ln_valrec_cnt             number := 0;
    ln_count_update           number := 0;

    --==============================================
    --Cursor to get count of the  Validated records
    --==============================================
    CURSOR lcu_valrec_cnt(cp_status_flag VARCHAR2, cp_request_id NUMBER) IS
      SELECT COUNT(1)
        FROM tlt_pa_projects_conv_stg PAS
       WHERE NVL(PAS.status_flag, 'X') = cp_status_flag
         AND PAS.request_id = cp_request_id;

    Cursor cur_projects_data(cp_status_flag IN varchar2) Is
      Select rowid,
             trim(project_number) project_number,
             trim(Project_Name) Project_Name,
             trim(Project_Description) Project_Description,
             trim(long_name) long_name,
             trim(Project_Template) Project_Template,
             trim(Project_Type) Project_Type,
             Project_start_date Project_start_date,
             project_end_date Project_end_date,
             trim(Project_OU) Project_OU,
             trim(Location) Location,
             trim(IC_Type) IC_Type,
             trim(Capital) Capital,
             trim(Customer) Customer,
             trim(Customer_Bill_To) Customer_Bill_To,
             trim(Customer_ship_to) Customer_ship_to,
             --   trim(product_code) product_code,
             trim(Project_status) Project_status,
             --   trim(organization_name) organization_name,
             trim(Project_manager) Project_manager,
             trim(task_name) task_name,
             trim(task_number) task_number,
             trim(description) description,
             trim(start_date) start_date,
             trim(Completion_date) Completion_date,
             trim(attribute1) attribute1,
             trim(attribute2) attribute2,
             trim(attribute3) attribute3,
             trim(legacy_project_number) legacy_project_number,
             trim(Status_flag) Status_flag,
             trim(error_message) error_message
        From tlt_pa_projects_conv_stg a
       where status_flag = cp_status_flag
         for update nowait;

    --==============================================
    --Cursor to get count of the transformed records
    --==============================================
    CURSOR lcu_prevalrec_cnt(cp_status_flag VARCHAR2) IS
      SELECT COUNT(1)
        FROM tlt_pa_projects_conv_stg PAT
       WHERE NVL(PAT.status_flag, 'X') = cp_status_flag;

    --==============================================
    --Cursor to get address of customers
    --==============================================
    CURSOR lcu_address_id(cp_site_code VARCHAR2, cp_customer_id NUMBER, cp_proj_owning_org_id NUMBER) IS
      Select acct_site.cust_acct_site_id
        From hz_cust_acct_sites_all acct_site, hz_cust_site_uses_all su
       Where acct_site.cust_acct_site_id = su.cust_acct_site_id
         And nvl(acct_site.status, 'A') = 'A'
         And acct_site.cust_account_id = cp_customer_id --X_Bill_To_Customer_Id
         And nvl(su.status, 'A') = 'A'
         And su.primary_flag = 'Y'
         And su.site_use_code = cp_site_code
         And su.org_id = cp_proj_owning_org_id;

    /*    --==============================================
    --Cursor to get project type roles for employee
    --==============================================
         cursor lcu_project_role (cp_meaning varchar2) IS
           select project_role_type
            into ln_role_type
          from pa_project_role_types
          where meaning =cp_meaning;*/

  Begin

    --------------Deleting error table

    delete from tlt_pa_validation_error;
    commit;

    --Cursor to get count of the transformed records to be Validated
    --==============================================================
    OPEN lcu_prevalrec_cnt(p_validate_data_flag);
    FETCH lcu_prevalrec_cnt
      INTO ln_prevalrec_cnt;
    CLOSE lcu_prevalrec_cnt;

    IF ln_prevalrec_cnt > 0 THEN

      For i In cur_projects_data(p_validate_data_flag)
      --  EXIT WHEN cu_projects_data%NOTFOUND;
       Loop
        wrtlog('*********** Projects Start ************');
        wrtlog('Inside loop');
        -----------To Check Organization is valid or not------
        lc_status_flag     := Null;
        lc_error_message   := null;
        lg_organization_id := null;
        --   ln_project_status    := null;
        --  ln_billto_address_id := null;
        --   ln_shipto_address_id := null;
        i.error_message := Null;
        i.status_flag   := gc_transformation_flag;

        Begin

          Select organization_id
            Into lg_organization_id
            From hr_operating_units
           Where upper(name) = upper(i.Project_ou);
          --    And business_group_id = lc_bg_name;

          wrtlog('Organization_id-' || lg_organization_id);

        Exception
          When Others Then
            lc_error_message := lc_error_message || ' , OU is not valid';
            insert_errors(i.project_name,
                          i.legacy_project_number,
                          gc_error_flag,
                          lc_error_message);

        End;

        -----------To Check project name is unique--------------

        Begin

          If i.project_name Is Null Then

            i.status_flag   := gc_error_flag;
            i.error_message := i.error_message || ' , ' ||
                               ' Project Name Is NULL';

            lc_error_message := lc_error_message ||
                                ' , Project Name Is NULL';
            insert_errors(i.project_name,
                          i.legacy_project_number,
                          gc_error_flag,
                          lc_error_message);

          Else

            Select Name
              Into ln_project_name
              From pa_projects_all
             Where trim(Name) = substr(i.project_name, 0, 25)
                or segment1 = i.Project_number;

            If ln_project_name Is Not Null Then

              i.status_flag   := gc_error_flag;
              i.error_message := i.error_message || ' , ' ||
                                 '  Project Name already exist';

              lc_error_message := lc_error_message ||
                                  ' , Project Name already exist';

              insert_errors(i.project_name,
                            i.legacy_project_number,
                            gc_error_flag,
                            lc_error_message);
            End If;

          End If;

        Exception
          When Others Then

            wrtlog('Project name is unique');

            lc_error_message := null;

        End;

        -------------To check Template exist is oracle--------------------
        BEGIN
          If i.project_template Is Null Then

            i.status_flag   := gc_error_flag;
            i.error_message := i.error_message || ' , ' ||
                               ' Project Template is null';

            lc_error_message := lc_error_message ||
                                'Project Template is null';
            insert_errors(i.project_name,
                          i.legacy_project_number,
                          gc_error_flag,
                          lc_error_message);

          ELSE

            select project_id, project_status_code
              into ln_template_id, ln_status_code
              --from pa.pa_projects_all    --code commented by RXNETHI-ARGANO,17/05/23
              from apps.pa_projects_all    --code added by RXNETHI-ARGANO,17/05/23
             where name = i.project_template;
            --  where name like '%' || i.project_template || '%';

            IF ln_template_id is null THEN

              i.status_flag   := gc_error_flag;
              i.error_message := i.error_message || ' , ' ||
                                 ' Project Template do not exist in oracle';

              lc_error_message := lc_error_message ||
                                  ' , Project Template do not exist in oracle';
              insert_errors(i.project_name,
                            i.legacy_project_number,
                            gc_error_flag,
                            lc_error_message);

            ELSE

              lc_error_message := null;

            End If;

          End if;

        Exception
          When others then
            i.status_flag   := gc_error_flag;
            i.error_message := i.error_message || ' , ' ||
                               ' Project Template do not exist in oracle';

            lc_error_message := lc_error_message ||
                                ' , Project Template do not exist in oracle';
            insert_errors(i.project_name,
                          i.legacy_project_number,
                          gc_error_flag,
                          lc_error_message);

        END;

        --------------To check project start date and end date is null-----------

        BEGIN

          /*  select to_char(completion_date, 'DD-MON-RRRR'),
                 to_char(start_date, 'DD-MON-RRRR')
            into ln_completion_date_format, ln_start_date_format
            from pa.pa_projects_all
           where name = i.project_template;
          --  where name like '%' || i.project_template || '%';*/

          If i.project_start_date Is Null or i.project_end_date is null Then

            i.status_flag   := gc_error_flag;
            i.error_message := i.error_message || ' , ' ||
                               'Project dates should not be null';

            lc_error_message := lc_error_message ||
                                ' , Project dates should not be null';
            insert_errors(i.project_name,
                          i.legacy_project_number,
                          gc_error_flag,
                          lc_error_message);

          ELSIF i.project_start_date is not null and
                i.project_end_date is not null then

            -- ln_completion_date := to_date(ln_completion_date_format,'DD-MON-RRRR');
            -- ln_start_date      := to_date(ln_start_date_format,'DD-MON-RRRR');

            ln_start_date := i.project_start_date;

            --for template date updation --   ln_completion_date    := nvl(i.project_end_date,to_date(ln_completion_date_format,'DD-MON-RRRR'));

            ln_completion_date := i.project_end_date;

            lc_error_message := null;

            wrtlog('Project start date -' ||
                   to_date(ln_start_date, 'DD/MM/RRRR'));
            wrtlog('Project End date -' ||
                   to_date(ln_completion_date, 'DD/MM/RRRR'));

          End If;

        END;

        -------------------To check project type exist --------------------------

        Begin
          If i.project_type Is Null Then

            i.status_flag   := gc_error_flag;
            i.error_message := i.error_message || ' , ' ||
                               'Project Type Is NULL';

            lc_error_message := lc_error_message || ',Project Type Is NULL';
            insert_errors(i.project_name,
                          i.legacy_project_number,
                          gc_error_flag,
                          lc_error_message);

          Else

            Select project_type
              Into lc_project_type
              From apps.pa_project_types_all
             Where upper(project_type) = upper(i.project_type)
               and org_id = lg_organization_id;

            If lc_project_type Is not Null Then

              lc_error_message := null;

            End If;

          End If;

        Exception
          When Others Then

            i.status_flag   := gc_error_flag;
            i.error_message := i.error_message || ' , ' ||
                               'Project Type is invalid or null';

            lc_error_message := lc_error_message ||
                                ' ,Project Type is invalid or null';
            insert_errors(i.project_name,
                          i.legacy_project_number,
                          gc_error_flag,
                          lc_error_message);

        End;

        ------------------To check Class category and class Code ----------------------
        Begin

          IF substr(i.project_template, 0, 8) = 'T, Admin' THEN
            -----    Change for V2 version

            Select class_category, class_code
              into ln_class_category, ln_class_code
              From pa_class_codes
             Where class_category = ('TT Indirect Types') -----    Change for V2 version
               And upper(class_code) = upper(i.capital)
               And end_date_active Is Null;

          ELSE

            IF i.ic_type is null then

              i.status_flag   := gc_error_flag;
              i.error_message := i.error_message || ' , ' ||
                                 'IC_TYPE is null';

              lc_error_message := lc_error_message || 'IC_TYPE is null';
              insert_errors(i.project_name,
                            i.legacy_project_number,
                            gc_error_flag,
                            lc_error_message);

            ELSE

              Select class_category, class_code
                into ln_class_category, ln_class_code
                From pa_class_codes
               Where class_category = ('TT IC Type')
                 And upper(class_code) = upper(i.ic_type)
                 And end_date_active Is Null;

              IF ln_class_category is not null and
                 ln_class_code is not null then

                lc_error_message := null;
              ELSE
                i.status_flag   := gc_error_flag;
                i.error_message := i.error_message || ' , ' ||
                                   'class category and code is not found';

                lc_error_message := lc_error_message ||
                                    'class category and code is not found';
                insert_errors(i.project_name,
                              i.legacy_project_number,
                              gc_error_flag,
                              lc_error_message);
              End if;

              IF i.location is not null then
                ----- Change for V3 version

                Select class_category, class_code
                  into ln_class_category, ln_class_code
                  From pa_class_codes
                 Where upper(class_category) = UPPER('TT Location')
                   And upper(class_code) = UPPER(i.location)
                   And end_date_active Is Null;

              ELSE

                wrtlog('location is null');
                lc_error_message := null;

              END If;

            End IF;

          end if;

        Exception
          When Others Then

            ln_class_category := null;
            ln_class_code     := null;

            /*Select class_category, class_code
              into ln_class_category, ln_class_code
              From pa_class_codes
             Where upper(class_category) = UPPER('TT Capital') --Client Geographical Segment ,Asset Name, Billing UOM ,Billing Override , Billing Rounding Rules ,Revenue Split
               And upper(class_code) = 'N'
               And end_date_active Is Null;

            IF ln_class_category is not null and ln_class_code is not null then

              lc_error_message := null;

            Else*/

            i.status_flag   := gc_error_flag;
            i.error_message := i.error_message || ' , ' ||
                               'class category Default value not found';

            lc_error_message := lc_error_message ||
                                'class category Default value not found';
            insert_errors(i.project_name,
                          i.legacy_project_number,
                          gc_error_flag,
                          lc_error_message);

        end;

        ---------------- To check customer exist in oracle -----------------------

        Begin

          IF substr(i.project_template, 0, 8) = 'T, Admin' THEN
            ----Change for V2 version

            lc_error_message := null;

          ELSE
            If i.customer Is Null Then

              i.status_flag   := gc_error_flag;
              i.error_message := i.error_message || ' , ' ||
                                 'Customer name is null';

              lc_error_message := lc_error_message ||
                                  'Customer name is null';
              insert_errors(i.project_name,
                            i.legacy_project_number,
                            gc_error_flag,
                            lc_error_message);

            Else

              Select cust_account_id
                Into ln_customer_id
                From apps.hz_cust_accounts
               Where upper(Trim(Account_number)) = upper(Trim(i.customer))
                 And status = 'A';

              wrtlog('Customer id ' || ln_customer_id);

              IF ln_customer_id is not null then

                SELECT organization_id
                  into ln_owning_org_id
                  FROM hr_operating_units
                 WHERE UPPER(NAME) = UPPER(i.project_ou);

                wrtlog('Customer id not null for organization' ||
                       ln_owning_org_id);

              ELSIF ln_owning_org_id is null THEN

                i.status_flag   := gc_error_flag;
                i.error_message := i.error_message || ' , ' ||
                                   'Organization of customer is not found';

                lc_error_message := lc_error_message ||
                                    'Organization of customer is not found';
                insert_errors(i.project_name,
                              i.legacy_project_number,
                              gc_error_flag,
                              lc_error_message);

              End if;

            end if;

            IF i.customer_bill_to is null THEN

              i.status_flag   := gc_error_flag;
              i.error_message := i.error_message || ' , ' ||
                                 'customer Bill_to is null';

              lc_error_message := lc_error_message ||
                                  'customer Bill_to is null';

              insert_errors(i.project_name,
                            i.legacy_project_number,
                            gc_error_flag,
                            lc_error_message);

            END If;

            IF i.customer_ship_to is null THEN

              i.status_flag   := gc_error_flag;
              i.error_message := i.error_message || ' , ' ||
                                 'customer ship_to is null';

              lc_error_message := lc_error_message ||
                                  'customer ship_to is null';

              insert_errors(i.project_name,
                            i.legacy_project_number,
                            gc_error_flag,
                            lc_error_message);
            END IF;

          End IF; -----------------------IF 'T, Admin'  ----Change for V2 version

          ln_billto_address_id := null;

          IF i.customer_bill_to is not null Then

            OPEN lcu_address_id('BILL_TO',
                                ln_customer_id,
                                ln_owning_org_id);
            FETCH lcu_address_id
              INTO ln_billto_address_id;
            CLOSE lcu_address_id;

          END IF;

          /* IF ln_billto_address_id <> to_number(i.customer_bill_to) THEN



            i.status_flag   := gc_error_flag;
            i.error_message := i.error_message || ' , ' ||
                               'Bill To Address not valid';

            lc_error_message := lc_error_message ||
                                'Bill To Address not valid' ||
                                i.customer_bill_to || '-' ||
                                ln_billto_address_id;
            insert_errors(i.project_name,
                          i.legacy_project_number,
                          gc_error_flag,
                          lc_error_message);
          END IF;*/

          ln_shipto_address_id := null;

          IF i.customer_ship_to is not null THEN

            OPEN lcu_address_id('SHIP_TO',
                                ln_customer_id,
                                ln_owning_org_id);
            FETCH lcu_address_id
              INTO ln_shipto_address_id;
            CLOSE lcu_address_id;

          END IF;

          /* IF ln_shipto_address_id <> to_number(i.customer_ship_to) THEN

            i.status_flag   := gc_error_flag;
            i.error_message := i.error_message || ' , ' ||
                               'Ship To Address not valid';

            lc_error_message := lc_error_message ||
                                ' , Ship To Address not valid' ||
                                i.customer_ship_to || '<>' ||
                                ln_shipto_address_id;
            insert_errors(i.project_name,
                          i.legacy_project_number,
                          gc_error_flag,
                          lc_error_message); --- need to check with dharam

          END IF;*/

        Exception
          WHEN NO_DATA_FOUND THEN

            i.status_flag   := gc_error_flag;
            i.error_message := i.error_message || ' , ' ||
                               'Customer name is not found';

            lc_error_message := lc_error_message ||
                                'Customer name is not found';
            insert_errors(i.project_name,
                          i.legacy_project_number,
                          gc_error_flag,
                          lc_error_message);

          WHEN TOO_MANY_ROWS THEN
            i.status_flag   := gc_error_flag;
            i.error_message := i.error_message || ' , ' ||
                               'Too Many Records Fetched for the Customer Number';

            lc_error_message := lc_error_message ||
                                'Too Many Records Fetched for the Customer Number';
            insert_errors(i.project_name,
                          i.legacy_project_number,
                          gc_error_flag,
                          lc_error_message);

          When Others Then

            i.status_flag   := gc_error_flag;
            i.error_message := i.error_message || ' , ' ||
                               'Customer name is not found';

            lc_error_message := lc_error_message ||
                                'Customer name is not found';
            insert_errors(i.project_name,
                          i.legacy_project_number,
                          gc_error_flag,
                          lc_error_message);

        End;

        ------------------ To check long name is unique ----------------------------------
        Begin

          If i.long_name Is Null Then

            ---**************** Need clarification

            --     lc_error_message := lc_error_message || 'Long name not found';
            --      insert_errors(i.project_name, gc_error_flag, lc_error_message);
            lc_error_message := null;

          Else

            Select long_name
              Into ln_long_name
              From pa_projects_all
             Where long_name = i.long_name;

            If ln_long_name Is Not Null Then

              i.status_flag   := gc_error_flag;
              i.error_message := i.error_message || ' , ' ||
                                 'Long name is not unique';

              lc_error_message := lc_error_message ||
                                  'Long name is not unique';
              insert_errors(i.project_name,
                            i.legacy_project_number,
                            gc_error_flag,
                            lc_error_message);

            End If;

          End If;

        Exception
          When Others Then
            wrtlog('long name is unique');
            lc_error_message := null;

        End;
        --------------------------- To check Project status --------------------------------------

        /*Begin

          If i.project_status Is Null Then

            Select project_system_status_code
              Into ln_project_status
              From pa_project_statuses
             Where upper(project_status_code) =
                   NVL(upper(i.project_status), ln_status_code)
                Or upper(project_status_name) = upper(i.project_status);

          ELSE

            lc_error_message := null;

          End If;

        Exception
          When Others Then
            i.status_flag   := gc_error_flag;
            i.error_message := i.error_message || ' , ' ||
                               'Invalid Project Status';

            lc_error_message := lc_error_message ||
                                ', Invalid Project Status';
            insert_errors(i.project_name,
                          i.legacy_project_number,
                          gc_error_flag,
                          lc_error_message);

        End;*/

        ------------------------- check for project Manager
        ln_effective_start_date := null;
        Begin
          IF i.project_manager IS NULL THEN

            i.status_flag   := gc_error_flag;
            i.error_message := i.error_message || ' , ' ||
                               'Project Manager is NULL';

            lc_error_message := lc_error_message ||
                                ' , Project Manager is NULL';
            insert_errors(i.project_name,
                          i.legacy_project_number,
                          gc_error_flag,
                          lc_error_message);
          ELSE

            SELECT person_id
              into ln_person_id
              FROM per_all_people_f
             WHERE full_name = i.project_manager
               and sysdate between effective_start_date and
                   effective_end_date
               AND person_id IS NOT NULL;

            IF ln_person_id IS NOT NULL THEN

              lc_error_message := null;

              select effective_start_date
                into ln_effective_start_date
                from per_all_people_f
               where sysdate between effective_start_date and
                     effective_end_date
                 and full_name = i.project_manager;

              wrtlog('Project Manager Effective Start Date :-> ' ||
                     to_char(ln_effective_start_date, 'DD-MON-YYYY'));
              wrtlog('Project Start Date :-> ' || i.project_start_date);

              IF ln_effective_start_date > ln_start_date THEN

                wrtlog('Project Start Date :-> ' ||
                       ln_effective_start_date || '>' || ln_start_date);

                i.status_flag   := gc_error_flag;
                i.error_message := i.error_message || ' , ' ||
                                   'Project Manager Start Date > Project Start Date';

                lc_error_message := lc_error_message ||
                                    ' , Project Manager Start Date > Project Start Date';
                insert_errors(i.project_name,
                              i.legacy_project_number,
                              gc_error_flag,
                              lc_error_message);

                /*  ELSE

                ln_effective_start_date :=ln_start_date;
                lc_status_flag          :=gc_validation_flag;*/

              END IF;

              ln_effective_start_date := NULL;

            END IF;

          END IF;

        Exception
          When Others Then

            i.status_flag   := gc_error_flag;
            i.error_message := i.error_message || ' , ' ||
                               ' Project manager is invalid';

            lc_error_message := lc_error_message ||
                                ', Project manager is invalid';
            insert_errors(i.project_name,
                          i.legacy_project_number,
                          gc_error_flag,
                          lc_error_message);

        end;
        ------------------ To check task name is unique--------------

        Begin

          IF i.task_name IS NULL THEN

            i.status_flag   := gc_error_flag;
            i.error_message := i.error_message || ' , ' ||
                               'Task_name or task_number is null';

            lc_error_message := lc_error_message ||
                                ' ,Task_name or task_number is null';
            insert_errors(i.project_name,
                          i.legacy_project_number,
                          gc_error_flag,
                          lc_error_message);
          ELSE

            select task_name
              into ln_task_name
              from pa_tasks
             where task_number = i.task_name;
            --  and project_name =i.project_name;

            select task_number
              into ln_task_number
              from pa_tasks
             where task_number = i.task_number;
            -- and task_name =ln_task_name;

            IF ln_task_name is not null and ln_task_number is not null then

              i.status_flag   := gc_error_flag;
              i.error_message := i.error_message || ' , ' ||
                                 'Task name should be unique';

              lc_error_message := lc_error_message ||
                                  ' ,Task name should be unique';

              insert_errors(i.project_name,
                            i.legacy_project_number,
                            gc_error_flag,
                            lc_error_message);

            End if;
          End if;
        Exception
          When Others Then

            wrtlog(',Task name is unique');
            lc_error_message := null;

        end;

        ------ Task start and end date check--------------------

        Begin

          select distinct start_date, completion_date
            into ln_task_start_date, ln_task_end_date
            from TLT_PA_PROJECTS_CONV_STG
           where upper(trim(project_name)) = upper(trim(i.project_name));

          wrtlog('Task Start Date    :-> ' ||
                 TO_CHAR(ln_task_start_date, 'DD-MON-YYYY'));
          wrtlog('Task Completion Date  :-> ' ||
                 TO_CHAR(ln_task_end_date, 'DD-MON-YYYY'));
          wrtlog('Project Start Date     :-> ' ||
                 TO_CHAR(ln_start_date, 'DD-MON-YYYY'));
          wrtlog('Project End Date :-> ' ||
                 TO_CHAR(ln_completion_date, 'DD-MON-YYYY'));

          IF ln_task_start_date > i.project_start_date and
             ln_start_date is not null and ln_task_start_date is not null THEN

            lc_error_message := null;

          ELSIF ln_start_date IS NULL OR ln_task_start_date IS NULL THEN

            i.status_flag   := gc_error_flag;
            i.error_message := i.error_message || ' , ' ||
                               'Task Start Dates should not be null';

            lc_error_message := lc_error_message ||
                                ' , Task Start Dates should not be null';
            insert_errors(i.project_name,
                          i.legacy_project_number,
                          gc_error_flag,
                          lc_error_message);

          END IF;

          IF ln_completion_date IS NOT NULL AND
             ln_task_end_date IS NOT NULL THEN

            lc_error_message := null;

            IF ln_task_end_date > ln_completion_date THEN

              i.status_flag   := gc_error_flag;
              i.error_message := i.error_message || ' , ' ||
                                 'Task Completion Date > Project End Date';

              lc_error_message := lc_error_message ||
                                  ' , Task Completion Date > Project End Date ';
              insert_errors(i.project_name,
                            i.legacy_project_number,
                            gc_error_flag,
                            lc_error_message);

              wrtlog('task end date is > than project end date' ||
                     ln_completion_date);
            ELSE

              lc_error_message := null;

            END IF;

          ELSIF ln_completion_date is null AND ln_task_end_date IS NULL THEN

            -- insert_errors(i.project_name, gc_error_flag, lc_error_message);
            lc_error_message := null;
            ln_task_end_date := ln_completion_date;

          END IF;

        Exception
          When Others Then

            i.status_flag    := gc_error_flag;
            i.error_message  := i.error_message || ' , ' ||
                                'task date is invalid';
            lc_error_message := lc_error_message ||
                                ', task date is invalid';
            insert_errors(i.project_name,
                          i.legacy_project_number,
                          gc_error_flag,
                          lc_error_message);

        END;

        ----------- Task type --------

        IF i.attribute1 is null then

          lc_error_message := lc_error_message || ' , Task client is null';
          insert_errors(i.project_name,
                        i.legacy_project_number,
                        gc_error_flag,
                        lc_error_message);
        End if;

        IF i.status_flag <> gc_error_flag AND
           i.status_flag = gc_transformation_flag THEN

          i.status_flag   := gc_validation_flag;
          i.error_message := 'Validated';

        END IF;

        -- Update tlt_pa_projects_conv_stg
        BEGIN

          select count(*)
            into ln_count_update
            from tlt_pa_validation_error
           where project_name = i.project_name;

          IF ln_count_update > 0 THEN

            wrtlog('before update-' || ln_start_date);

            Update tlt_pa_projects_conv_stg
               set creation_date    = sysdate,
                   last_update_date = sysdate,
                   customer_Bill_to = ln_billto_address_id,
                   customer_ship_to = ln_shipto_address_id,
                   --     project_start_date = ln_start_date,
                   --     project_end_date   = ln_completion_date,
                   -- Project_status = ln_project_status,
                   request_id    = gn_request_id,
                   status_flag   = gc_error_flag,
                   error_message = i.error_message
             where rowid = i.rowid;

            wrtlog('Staging table update with valid records-' ||
                   gc_error_flag);

          else

            Update tlt_pa_projects_conv_stg
               set creation_date    = sysdate,
                   last_update_date = sysdate,
                   customer_Bill_to = ln_billto_address_id,
                   customer_ship_to = ln_shipto_address_id,
                   --    project_start_date = ln_start_date,
                   --    project_end_date   = ln_completion_date,
                   -- Project_status = ln_project_status,
                   request_id    = gn_request_id,
                   status_flag   = gc_validation_flag,
                   error_message = 'Validated'
             where rowid = i.rowid;

            wrtlog('Staging table update with valid records-' ||
                   gc_validation_flag);

          END IF;

        Exception
          When Others Then
            wrtlog('Error Occured While updaing records -> ' || Sqlerrm);

        END;

        wrtout(i.legacy_project_number || '|' || i.error_message);

      End Loop;

      commit;

    End IF;
    --=============================================
    --Cursor to get count of the validated records
    --=============================================
    ln_valrec_cnt := 0;
    OPEN lcu_valrec_cnt(gc_validation_flag, gn_request_id);
    FETCH lcu_valrec_cnt
      INTO ln_valrec_cnt;
    CLOSE lcu_valrec_cnt;

    wrtout('   Number Of Records Validated       :-> ' || ln_valrec_cnt);
    wrtout('   Number Of Records Failured        :-> ' ||
           (ln_prevalrec_cnt - ln_valrec_cnt));
    --  wrtout('   Failure records ')
    wrtout(RPAD(' ', 80, ' '));
    wrtout('   ------ Procedure validate_data Exit------');
    wrtout(RPAD('*', 80, '*'));

    wrtlog(RPAD(' ', 80, ' '));
    wrtlog('   ------ Procedure validate_data Exit------');
    wrtlog(RPAD('*', 80, '*'));

  Exception
    When Others Then
      apps.fnd_file.put_line(apps.fnd_file.log,
                             'Error Occured In VALIDATION procedure :-> ' ||
                             Sqlerrm);

  End validate_records;

  PROCEDURE create_projects_tasks IS

    ln_cnt1 number;
    -----------COMPOSITE DATA TYPES-----------------
    lr_project_in       apps.pa_project_pub.project_in_rec_type;
    lr_project_out      apps.pa_project_pub.project_out_rec_type;
    lt_key_members      apps.pa_project_pub.project_role_tbl_type;
    lt_class_categories apps.pa_project_pub.class_category_tbl_type;
    lt_task_in          apps.pa_project_pub.task_in_tbl_type;
    lt_tasks_out        apps.pa_project_pub.task_out_tbl_type;
    lr_task_in_rec      apps.pa_project_pub.task_in_rec_type;
    lt_customer_tbl     apps.pa_project_pub.customer_tbl_type;
    --********************************************************
    ln_msg_count          NUMBER;
    lc_msg_data           VARCHAR2(4000);
    lc_return_status      VARCHAR2(10);
    lc_workflow_status    VARCHAR2(300);
    ln_msg_index_out      NUMBER;
    lc_data               VARCHAR2(32000);
    lc_error_message      VARCHAR2(32000);
    ln_key_mem            NUMBER;
    ln_class_code         varchar2(50);
    ln_class_category     varchar2(50);
    ln_class_category1    varchar2(50);
    ln_class_category2    varchar2(50);
    ld_empeff_start_date  DATE;
    ln_product_code       VARCHAR2(50) := 'CONVERSION';
    ln_manager_start_date date;
    ln_manager_end_date   date;
    ln_project_number     number;
    ln_template_id        number;

    ln_task_start_date      date;
    ln_task_completion_date date;
    ln_attribute1           varchar2(50);

    ---Tasks columns

    lc_pm_task_reference           VARCHAR2(250);
    ln_start_date                  DATE;
    ln_completion_date             DATE;
    lc_chargeable_flag             VARCHAR2(300);
    ln_oracle_owning_bu_sl_id      NUMBER;
    ln_cnt                         NUMBER;
    ln_project_id                  NUMBER;
    ln_person_id1                  NUMBER; --------- V4 operating manager logic change
    ln_person_id2                  NUMBER; --------- V4 operating manager logic change
    ln_role_type                   VARCHAR2(100);
    ln_processrec_cnt              number;
    ln_valrec_cnt                  number;
    ln_count                       number;
    ln_customer_id                 number;
    ln_partner_id                  number;
    ln_customer_ship_to            number;
    ln_customer_bill_to            number;
    ln_carryingout_organization_id number;

    ln_task_cnt number;
    ln_resp_id  number := 1013384; -- 1013384

    --==================================================
    --Cursor to get count of the records to be processed
    --==================================================
    CURSOR lcu_valrec_cnt(cp_status_flag VARCHAR2) IS
      SELECT COUNT(1)
        FROM tlt_pa_projects_conv_stg
       WHERE NVL(status_flag, 'X') = cp_status_flag;

    --==============================================
    --Cursor to get count of the  processed records
    --==============================================
    CURSOR lcu_processrec_cnt(cp_status_flag VARCHAR2, cp_request_id NUMBER) IS
      SELECT COUNT(1)
        FROM tlt_pa_projects_conv_stg PAS
       WHERE NVL(PAS.status_flag, 'X') = cp_status_flag
         AND PAS.request_id = cp_request_id;

    CURSOR cur_projects_data(cp_status_flag IN varchar2) IS
      Select rowid,
             trim(project_number) project_number,
             trim(legacy_project_number) legacy_project_number,
             trim(Project_Name) Project_Name,
             trim(Project_Description) Project_Description,
             trim(long_name) long_name,
             trim(Project_Template) Project_Template,
             trim(Project_Type) Project_Type,
             project_start_date,
             project_end_date,
             trim(Project_OU) Project_OU,
             trim(Location) Location,
             trim(IC_Type) IC_Type,
             trim(Capital) Capital,
             trim(Customer) Customer,
             trim(Customer_Bill_To) Customer_Bill_To,
             trim(Customer_ship_to) Customer_ship_to,
             --     trim(product_code) product_code,
             trim(Project_status) Project_status,
             --    trim(organization_name) organization_name,
             trim(Project_manager) Project_manager,
             trim(task_name) task_name,
             trim(task_number) task_number,
             trim(description) description,
             start_date start_date,
             completion_date completion_date,
             trim(attribute1) attribute1,
             trim(attribute2) attribute2,
             trim(attribute3) attribute3,
             trim(project_partner) project_partner,
             trim(project_op_manager) project_op_manager,
             trim(Status_flag) Status_flag,
             trim(Error_message) Error_message
        From tlt_pa_projects_conv_stg a
       where status_flag = 'V';
    --  for update nowait;

    CURSOR cur_class_code(cp_class_category VARCHAR2, cp_class_code VARCHAR2) IS
      SELECT class_category, Class_code
        FROM pa_class_codes
       WHERE UPPER(class_category) = UPPER(cp_class_category) --Client Geographical Segment ,Asset Name, Billing UOM ,Billing Override , Billing Rounding Rules ,Revenue Split
         AND UPPER(class_code) = UPPER(cp_class_code)
         AND end_date_active IS NULL;

    CURSOR cur_Template_tasks(cp_template_id number) /*, cp_project_name varchar2)*/
    IS
      SELECT task_name,
             task_number,
             description,
             attribute1,
             attribute2,
             attribute3,
             start_date,
             completion_date
        FROM pa_tasks
       WHERE PROJECT_ID IN
             (SELECT PROJECT_ID
                FROM Pa_projects_all
               WHERE project_id = cp_template_id);

    /*   UNION ALL
    Select task_name,
           task_number,
           description,
           trim(attribute1) attribute1,
           trim(attribute2) attribute2,
           trim(attribute3) attribute3,
           start_date,
           completion_date
      from tlt_pa_projects_conv_stg
     where status_flag = 'V'
       and project_name like '%' || cp_project_name || '%';*/

    CURSOR cur_project_role IS
      select project_role_type, meaning
        from pa_project_role_types
       where meaning = 'Project Manager'
      union all
      select project_role_type, meaning
        from pa_project_role_types
       where meaning = 'Project Partner/Director'
      union all
      select project_role_type, meaning
        from pa_project_role_types
       where meaning = 'Project Operations Manager';

  begin

    lg_organization_id := null;

    OPEN lcu_valrec_cnt(gc_validation_flag);
    FETCH lcu_valrec_cnt
      INTO ln_valrec_cnt;
    CLOSE lcu_valrec_cnt;

    wrtout('   Number Of Records To Be Processed :-> ' || ln_valrec_cnt);

    wrtlog(RPAD('*', 80, '*'));
    wrtlog('   ------ Procedure CREATE_PROJECT_TASKS ------');
    wrtlog(RPAD(' ', 80, ' '));

    wrtout(RPAD('*', 80, '*'));

    wrtlog('PROFILE - PA_UTILS.GetEmpIdFromUser>>>> ' ||
           apps.PA_UTILS.GetEmpIdFromUser(to_number(apps.fnd_profile.value('USER_ID'))));
    wrtlog(RPAD(' ', 80, ' '));

    IF ln_valrec_cnt > 0 THEN

      FOR i IN cur_projects_data(gc_validation_flag) --(ln_org_id)
       LOOP

        Begin

          Select organization_id
            Into lg_organization_id
            From hr_operating_units
           Where name = i.project_ou;

          --    And business_group_id = lc_bg_name;
          wrtlog('Organization_id-' || i.legacy_project_number);
          wrtlog('Organization_id-' || lg_organization_id);

        Exception
          When Others Then
            wrtlog('Error Occured while checking project template :-> ' ||
                   Sqlerrm);

        End;

        ln_project_id := NULL;
        lt_key_members.DELETE;
        lt_class_categories.DELETE;
        lt_customer_tbl.DELETE;
        lt_task_in.DELETE; --01-MAR-2011
        lt_tasks_out.DELETE;
        lc_error_message := 'Error Message :->';

        ld_empeff_start_date := NULL;

        pa_project_pub.clear_project;

        pa_project_pub.INIT_PROJECT;

        lc_msg_data      := NULL;
        lc_return_status := NULL;

        Begin

          select project_id, completion_date, carrying_out_organization_id
            into ln_template_id,
                 ln_completion_date,
                 ln_carryingout_organization_id
            --from pa.pa_projects_all    --code commented by RXNETHI-ARGANO,17/05/23
            from apps.pa_projects_all    --code added by RXNETHI-ARGANO,17/05/23
           where name = i.project_template;
          -- where name like '%' || i.project_template || '%';

        EXCEPTION
          When Others Then
            wrtlog('Error Occured while checking project template :-> ' ||
                   Sqlerrm);

        End;

        apps.pa_interface_utils_pub.set_global_info(p_api_version_number => 1.0,
                                                    p_responsibility_id  => ln_resp_id, --1013364 ,
                                                    p_user_id            => 393301, --393780,-- 394060,
                                                    p_msg_count          => ln_msg_count,
                                                    p_msg_data           => lc_msg_data,
                                                    p_return_status      => lc_return_status);

        wrtlog('   Track 1');

        lr_project_in.pm_project_reference := i.legacy_project_number; ---changed to legacy_project_no_ebs
        lr_project_in.project_name         := substr(i.Project_name, 0, 25);

        wrtlog('   Track 2');
        lr_project_in.carrying_out_organization_id := ln_carryingout_organization_id;
        wrtlog('   Track 3');
        lr_project_in.created_from_project_id := ln_template_id; --- 5002;--97002;--i.template_id;
        lr_project_in.description             := substr(i.project_description,
                                                        0,
                                                        250); --SUBSTR (i.project_desc,1,250);
        lr_project_in.long_name               := i.long_name;
        lr_project_in.actual_start_date       := i.project_start_date;
        lr_project_in.actual_finish_date      := i.project_end_date;

        wrtlog(' track 3.1');

        lr_project_in.start_date := i.project_start_date; --to_date(i.project_start_date,
        --      'MM/DD/YY'); --'01-JUL-2013';
        lr_project_in.completion_date := i.project_end_date; --To_date(i.project_end_date,
        --       'MM/DD/YY'); --'31-JAN-2014';
        wrtlog(' track 3.2');
        lr_project_in.attribute3 := i.legacy_project_number; --- for storing legacy org_ proj_num

        wrtlog('date normal' || i.project_start_date);
        wrtlog('Canonci-' ||
               fnd_date.date_to_canonical(i.project_start_date));

        --   lr_project_in.start_date := i.project_start_date;
        /*
        to_date(to_char(i.project_start_date,DD-MON-RRRR'),'DD-MON-RRRR');

        wrtlog('  date ' ||
               to_char(to_date(i.project_end_date, 'DD-MON-YYYY'),
                       'DD-MON-YYYY'));

        wrtlog('date print' || i.project_end_date);
        wrtlog('Canonci-' ||
               fnd_date.date_to_canonical(i.project_end_date));

        wrtlog('Can-date' ||
               fnd_date.canonical_to_date(fnd_date.date_to_canonical(i.project_end_date)));*/

        --     lr_project_in.completion_date := i.project_end_date; --- fnd_date.canonical_to_date(fnd_date.date_to_canonical(i.project_end_date));

        ---   lr_project_in.project_status_code          :='APPROVED';-- i.oracle_project_status;--need to check oracle_project_status
        wrtlog('   Track 4');

        -- ln_cnt2 := 1;
        Begin

          Select cust_account_id
            Into ln_customer_id
            From apps.hz_cust_accounts
           Where upper(Trim(Account_number)) = upper(Trim(i.customer))
             And status = 'A';

          Select acct_site.cust_acct_site_id
            into ln_customer_bill_to
            From hz_cust_acct_sites_all acct_site, hz_cust_site_uses_all su
           Where acct_site.cust_acct_site_id = su.cust_acct_site_id
             And nvl(acct_site.status, 'A') = 'A'
             And acct_site.cust_account_id = ln_customer_id --X_Bill_To_Customer_Id
             And nvl(su.status, 'A') = 'A'
             And su.primary_flag = 'Y'
             And su.site_use_code = 'BILL_TO'
             And su.org_id = lg_organization_id;

          Select acct_site.cust_acct_site_id
            into ln_customer_ship_to
            From hz_cust_acct_sites_all acct_site, hz_cust_site_uses_all su
           Where acct_site.cust_acct_site_id = su.cust_acct_site_id
             And nvl(acct_site.status, 'A') = 'A'
             And acct_site.cust_account_id = ln_customer_id --X_Bill_To_Customer_Id
             And nvl(su.status, 'A') = 'A'
             And su.primary_flag = 'Y'
             And su.site_use_code = 'SHIP_TO'
             And su.org_id = lg_organization_id;

          lt_customer_tbl(1).customer_id := ln_customer_id; --24508
          lt_customer_tbl(1).project_relationship_code := 'PRIMARY'; --'Primary'
          lt_customer_tbl(1).inv_rate_type := 'Corporate';
          lt_customer_tbl(1).INV_CURRENCY_CODE := 'USD';
          lt_customer_tbl(1).bill_to_address_id := ln_customer_bill_to;
          lt_customer_tbl(1).ship_to_address_id := ln_customer_ship_to;
          wrtlog(' level 4');
        Exception
          When others then
            wrtlog('Customer fetch is null :-> ' || Sqlerrm);

            ln_customer_bill_to := null;
            ln_customer_ship_to := null;

            wrtlog('Bill_to and Ship_to is null ' || Sqlerrm);

        end;

        Begin

          select person_id
            into ln_person_id1
            from per_all_people_f
           where full_name = i.project_manager
             and sysdate between effective_start_date and
                 effective_end_date;

          select person_id
            into ln_partner_id
            from per_all_people_f
           where full_name = i.project_partner
             and sysdate between effective_start_date and
                 effective_end_date;

          select person_id --------- V4 operating manager logic change
            into ln_person_id2
            from per_all_people_f
           where full_name = i.project_op_manager
             and sysdate between effective_start_date and
                 effective_end_date;

          --  ln_role_type := 'PROJECT MANAGER';

        EXCEPTION
          When Others Then
            wrtlog('Error Occured while checking person_id and manager details :-> ' ||
                   Sqlerrm);
        end;

        wrtlog('   Track 5');

        ln_cnt := 0;

        For k in cur_project_role loop

          IF k.meaning = 'Project Manager' THEN

            lt_key_members(ln_cnt).project_role_type := k.project_role_type;
            lt_key_members(ln_cnt).person_id := ln_person_id1; --------- V4 operating manager logic change

          ELSIF k.meaning = 'Project Partner/Director' THEN

            lt_key_members(ln_cnt).project_role_type := k.project_role_type;
            lt_key_members(ln_cnt).person_id := ln_partner_id;

          ELSIF k.meaning = 'Project Operations Manager' THEN
            lt_key_members(ln_cnt).project_role_type := k.project_role_type;
            lt_key_members(ln_cnt).person_id := ln_person_id2; --------- V4 operating manager logic change

          END IF;

          ln_cnt := ln_cnt + 1;

        end loop;

        wrtlog('   Track 6');

        ---------------------------Added a Change for V2 version-----------------------

        Begin

          IF substr(i.project_template, 0, 8) = 'T, Admin' THEN

            Select class_category
              into ln_class_category1
              From pa_class_codes
             Where class_category = ('TT Indirect Types')
               And upper(class_code) = upper(i.capital)
               And end_date_active Is Null;

            /* IF ln_class_category = 'TT Indirect Cost Stream' THEN

                lt_class_categories(1).class_category := ln_class_category;

            lt_class_categories(1).class_code := ln_class_code;*/

            IF ln_class_category1 = 'TT Indirect Types' THEN

              lt_class_categories(1).class_category := ln_class_category1;

              lt_class_categories(1).class_code := i.capital;

            END IF;

          ELSE

            lt_class_categories(2).class_category := 'TT IC Type';
            lt_class_categories(2).class_code := i.ic_type;

            IF i.location is not null THEN

              Select class_category
                into ln_class_category2
                From pa_class_codes
               Where class_category = ('TT Location')
                 And upper(class_code) = upper(i.location)
                 And end_date_active Is Null;

              lt_class_categories(3).class_category := 'TT Location';
              lt_class_categories(3).class_code := i.location;
            ELSE
              wrtlog('Classification -Location is null');
            END IF;

          END IF;

        Exception
          When others Then

            lt_class_categories(2).class_category := null;
            lt_class_categories(2).class_code := null;

        End;

        ---------------------------Added a Change for V2 version-----------------------
        /*   IF i.ic_type = 'Customer Facing' THEN

          ln_cnt := ln_cnt + 1;

          lt_class_categories(ln_cnt).class_category := i.ic_type; --j.class_category;--
          lt_class_categories(ln_cnt).class_code := i.capital; --j.class_code;

        ELSE

          lt_class_categories(ln_cnt).class_category := i.ic_type;
          lt_class_categories(ln_cnt).class_code := i.capital;

        END IF;*/

        ---   FOR k IN cur_class_code(i.ic_type, i.capital) loop

        --    ln_cnt := ln_cnt + 1;

        --     End loop;

        lc_chargeable_flag        := NULL;
        ln_oracle_owning_bu_sl_id := NULL;
        ln_cnt                    := NVL(ln_cnt1, 0) + 1;
        lc_msg_data               := NULL;
        lc_return_status          := NULL;
        ln_msg_count              := NULL;

        --    lc_pm_task_reference      := TRIM(SUBSTR(j.wbs_level || '-' || xyz_task_ref.NEXTVAL || '-' || j.task_no,1,25));
        --    lc_parent_task_reference  := NULL;

        --  lr_task_in_rec.task_start_date   := i.task_start_date;
        --       lr_task_in_rec.task_completion_date        := '12-JUL-2014';
        --     lr_task_in_rec.chargeable_flag              := 'Y';
        --      lr_task_in_rec.carrying_out_organization_id := lg_organization_id;
        --lr_task_in_rec.pa_project_id                :=  j.project_id;--ln_project_id
        -- --substr(j.wbs_level || '-' || xyz_task_ref.NEXTVAL || '-' || j.task_no,1,25);
        ---      lr_task_in_rec.pm_parent_task_reference     :=  0001;

        -- lr_tasks_in_rec.attribute1                  := 001;
        --          lr_task_in_rec.long_task_name               := i.task_long_name'; ############### need to be checked

        -- NVL(j.task_completion_date,'31-DEC-2024'),--need to check
        --         lr_task_in_rec.billable_flag                := 'Y';--j.oracle_billable, for Overhead Projects NULL
        --             lr_task_in_rec.task_manager_person_id       := ;--j.task_manager_id, 12-Nov-2010

        Begin
          SELECT count(*)
            into ln_count
            FROM pa_tasks
           WHERE PROJECT_ID IN
                 (SELECT PROJECT_ID
                    FROM Pa_projects_all
                   WHERE project_id = ln_template_id);

        Exception
          When others then
            wrtlog('Error Occured while checking Tasks count:-> ' ||
                   Sqlerrm);

            ln_count := 1;

        End;

        ln_count := 0;
        For j in cur_Template_tasks(ln_template_id) /*, i.Project_name)*/
         loop

          Begin

            Select start_date, completion_date, attribute1
              into ln_task_start_date,
                   ln_task_completion_date,
                   ln_attribute1
              from tlt_pa_projects_conv_stg
             where status_flag = 'V'
               and project_name = i.project_name;

          Exception
            when others then
              apps.fnd_file.put_line(apps.fnd_file.log,
                                     'Error Occured In Deriving task dates :-> ' ||
                                     SQLERRM);

          End;

          lr_task_in_rec.pm_task_reference    := j.task_number; --task_number; --- Need to check with Dharam
          lr_task_in_rec.task_name            := j.task_name;
          lr_task_in_rec.pa_task_number       := j.task_number; ----task_number;
          lr_task_in_rec.task_start_date      := ln_task_start_date; --j.start_date; --'01-JUL-2013'; --j.start_date;
          lr_task_in_rec.task_completion_date := ln_task_completion_date; --j.completion_date; --to_char(j.completion_date,'DD-MON-YYYY'); --'31-JAN-2014'; --j.completion_date;
          lr_task_in_rec.task_description     := j.description;
          -- lr_task_in_rec.carrying_out_organization_id := lg_organization_id;
          lr_task_in_rec.tasks_dff  := 'Y';
          lr_task_in_rec.attribute1 := trim(ln_attribute1);
          lr_task_in_rec.attribute2 := trim(j.attribute2);
          lr_task_in_rec.attribute3 := trim(j.attribute3);

          lr_task_in_rec.carrying_out_organization_id := ln_carryingout_organization_id;

          lt_task_in(ln_count) := lr_task_in_rec;

          ln_count := ln_count + 1;
        END LOOP;
        --   apps.fnd_file.put_line(apps.fnd_file.log,
        --                         ' Total Number Of Tasks :-> ' || ln_cnt1);
        --RETURN;

        wrtlog('   Track 8');

        BEGIN
          apps.pa_project_pub.create_project(p_api_version_number => 1.0,
                                             p_commit             => apps.fnd_api.g_false,
                                             p_init_msg_list      => apps.fnd_api.g_true,
                                             p_msg_count          => ln_msg_count,
                                             p_msg_data           => lc_msg_data,
                                             p_return_status      => lc_return_status,
                                             p_workflow_started   => lc_workflow_status,
                                             p_pm_product_code    => ln_product_code,
                                             p_project_in         => lr_project_in,
                                             p_project_out        => lr_project_out,
                                             p_key_members        => lt_key_members,
                                             p_tasks_in           => lt_task_in,
                                             p_tasks_out          => lt_tasks_out,
                                             p_customers_in       => lt_customer_tbl,
                                             p_class_categories   => lt_class_categories);

          wrtlog('   Track 9');

        EXCEPTION
          WHEN OTHERS THEN

            i.status_flag := gc_error_flag;
            wrtlog('   Error Occured In API-Block :-> ' || SQLERRM);
            lc_error_message := lc_error_message || 'EXCEPTION @API> ' ||
                                SUBSTR(SQLERRM, 1, 400);

        END;

        BEGIN

          IF lc_return_status <> 'S' THEN

            i.status_flag := gc_error_flag;

            wrtlog(' Project return status ' || lc_return_status);

            IF ln_msg_count = 1 THEN
              apps.pa_interface_utils_pub.get_messages(p_encoded       => apps.fnd_api.g_false,
                                                       p_msg_index     => 1,
                                                       p_msg_count     => ln_msg_count,
                                                       p_msg_data      => lc_msg_data,
                                                       p_data          => lc_data,
                                                       p_msg_index_out => ln_msg_index_out);

              lc_error_message := lc_error_message || lc_data;

              wrtlog(' API Error Message' || lc_error_message);

            ELSIF ln_msg_count > 1 THEN
              FOR i IN 1 .. ln_msg_count LOOP
                apps.pa_interface_utils_pub.get_messages(p_msg_data      => lc_msg_data,
                                                         p_data          => lc_data,
                                                         p_encoded       => apps.fnd_api.g_false,
                                                         p_msg_count     => i,
                                                         p_msg_index_out => ln_msg_index_out);
                lc_error_message := lc_error_message || lc_data;

                Dbms_Output.put_line(' MSG ' || lc_error_message);

                wrtlog(' API Error Message' || lc_error_message);

              END LOOP;
            END IF;

            wrtlog(' API Error Message :-> ' || lc_error_message ||
                   i.start_date || '---' || i.project_end_date);

            wrtlog(' Terminating the program');

            UPDATE TLT_PA_PROJECTS_CONV_STG
               set status_flag      = gc_error_flag,
                   error_message    = lc_error_message,
                   request_id       = gn_request_id,
                   creation_date    = sysdate,
                   last_update_date = sysdate
             where upper(trim(project_name)) = upper(trim(i.project_name))
               and ROWID = i.rowid;

          ELSE

            wrtlog('   Project Successfully Created');
            wrtlog('   Project ID :-> ' || lr_project_out.pa_project_id);

            ln_project_id     := lr_project_out.pa_project_id;
            ln_project_number := lr_project_out.pa_project_number;

            BEGIN

              IF lc_return_status = 'S' THEN

                UPDATE TLT_PA_PROJECTS_CONV_STG
                   SET status_flag      = DECODE(lc_return_status,
                                                 'S',
                                                 'P',
                                                 lc_return_status),
                       project_number   = to_char(ln_project_number),
                       Error_message    = 'Processed',
                       request_id       = gn_request_id,
                       creation_date    = sysdate,
                       last_update_date = sysdate
                 WHERE ROWID = i.rowid;

              END IF;

            EXCEPTION
              WHEN OTHERS THEN
                apps.fnd_file.put_line(apps.fnd_file.log,
                                       ' Error while updating ' || SQLERRM);

            END;

          END IF;

        EXCEPTION
          WHEN OTHERS THEN
            apps.fnd_file.put_line(apps.fnd_file.log,
                                   'While updating TLT_PA_PROJECTS_CONV_STG fo error ');

        END;

        COMMIT;

      end loop;

    END IF;

    BEGIN
      --=============================================
      --Cursor to get count of the processed records
      ---=============================================
      /* ln_processrec_cnt := null;
      OPEN lcu_processrec_cnt(gc_process_flag, gn_request_id);
      FETCH lcu_processrec_cnt
        INTO ln_processrec_cnt;
      CLOSE lcu_processrec_cnt;*/

      SELECT COUNT(1)
        into ln_processrec_cnt
        FROM tlt_pa_projects_conv_stg PAS
       WHERE NVL(PAS.status_flag, 'X') = gc_process_flag
         AND PAS.request_id = gn_request_id;

      wrtout('   Number Of Records Processed       :-> ' ||
             ln_processrec_cnt);
      wrtout('   Number Of Records Failured        :-> ' ||
             (ln_valrec_cnt - ln_processrec_cnt));
      wrtout(RPAD(' ', 80, ' '));
      wrtout('   ------ Procedure CREATE_PROJECTS Exit------');
      wrtout(RPAD('*', 80, '*'));

      wrtout(RPAD(' ', 80, ' '));

    EXCEPTION
      WHEN OTHERS THEN

        wrtlog('   Error Occured in The Procedure CREATE_PROJECTS');
        wrtlog('   Error Message Is :-> ' || SQLERRM);
        wrtlog('   ------ Procedure CREATE_PROJECTS Exit---------');
        wrtlog(RPAD(' ', 80, ' '));
        wrtlog(RPAD('*', 80, '*'));
    END;

  EXCEPTION
    WHEN NO_data_found THEN

      apps.fnd_file.put_line(apps.fnd_file.log,
                             'Error Occured No Rrecords to fetch:-> ' ||
                             SQLERRM);

    WHEN OTHERS THEN
      apps.fnd_file.put_line(apps.fnd_file.log,
                             'Error Occured In CREATE__PROJECTS_TASKS :-> ' ||
                             SQLERRM);

  end create_projects_tasks;

  PROCEDURE main(errbuf                OUT VARCHAR2,
                 retcode               OUT NUMBER,
                 p_validate_data_flag  IN VARCHAR2,
                 p_create_project_flag IN VARCHAR2) IS

    vl_local_function  VARCHAR2(80) := 'main()';
    vl_error_code_text VARCHAR2(200) := NULL;
    vl_error_msg       VARCHAR2(2000) := NULL;

  BEGIN

    write_report_header;

    IF p_validate_data_flag = 'N' THEN

      wrtlog('Validating the New records in staging table' ||
             vl_local_function);

      validate_records(gc_newrecord_flag);

      wrtlog('validation ends.........');

    ELSIF p_validate_data_flag = 'V' THEN

      wrtlog('Validating the Error records from staging table');

      validate_records(gc_error_flag);

    END IF;

    IF p_create_project_flag = 'Y' THEN

      --=================================
      --Call Procedure to Create Projects
      --=================================
      wrtlog('Processing all validated records from staging table');
      wrtlog('create zone' || vl_local_function);

      create_projects_tasks;

    END IF;

    wrtlog('Program ends.........');

  EXCEPTION
    WHEN OTHERS THEN

      vl_error_code_text := vl_local_function || 'lf' || '^        ' ||
                            vl_error_code_text;
      vl_error_msg       := SQLERRM(SQLCODE) || ' in ' ||
                            vl_error_code_text || '^';
      ROLLBACK;
      retcode := 1;
      raise_application_error(-20001, vl_error_msg);
      wrtlog('Leaving Exception: ' || vl_local_function);
  END main;

END TTEC_PA_PROJECTS_TASKS_PKG;
/
show errors;
/