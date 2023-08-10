create or replace PACKAGE BODY      TTEC_RPA_PROJECTS_TASKS_PKG AS
/*== START =======================================================================================================
     Description: Projects and Tasks Conversion for RogenSi OU
    Modification History:
    Version    Date     Author    Description
   -----     --------  --------  ----------------------------------------------
    1.0      02/16/2017  Hema C   Draft version
    2.0      03/16/2017  Hema C   Added BS Client Code DFF, Opportunity Owner and Service Type for tasks
	1.0		02-May-2023	IXPRAVEEN(ARGANO)   	R12.2 Upgrade Remediation
  == END ========================================================================================================*/
  lg_organization_id     number;
  gc_newrecord_flag      varchar2(1) := 'N';
  gc_error_flag          varchar2(1) := 'E';
  gc_validation_flag     varchar2(1) := 'V';
  gc_transformation_flag varchar2(1) := 'N';
  gc_process_flag        varchar2(1) := 'P';
  vgc_program_start_date date := sysdate;
  gn_request_id          number := fnd_global.conc_request_id;
  gn_user_id             number := fnd_global.user_id;
  gn_responsibility_id   number := FND_GLOBAL.RESP_ID;
  gn_respappl_id         number := FND_GLOBAL.RESP_APPL_ID;
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
           LPAD('RogenSi Teletech - Load Project and task details report', 60));
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
      --commit;
  Exception
    When others then
      null;
  End insert_errors;
  PROCEDURE wrtlog(p_buff IN VARCHAR2) IS
    -------------------------------------------------------------------------------
  BEGIN
    fnd_file.put_line(fnd_file.LOG, p_buff);
  END wrtlog;
  ------ Displays Error Messages ------
  Procedure select_error_records IS
  ln_rec_count number;
  Cursor error_count is
  select count(1)
    from tlt_pa_validation_error;
  cursor error_rec is
  select project_name
        ,project_number
        ,error_flag
        ,error_message
    from tlt_pa_validation_error
    ORDER BY project_number,error_message;
  BEGIN
   OPEN error_count;
    FETCH error_count
      INTO ln_rec_count;
    CLOSE error_count;
  IF ln_rec_count > 0 THEN
     wrtlog('*********** Failure Records ************');
     For i In error_rec Loop
       --wrtlog('Inside loop');
       wrtout('project_name :-> ' || i.project_name);
       wrtout('project_number :-> ' || i.project_number);
       wrtout('error_flag :-> ' || i.error_flag);
       wrtout('error_message :-> ' || i.error_message);
       wrtout('                                                            ');
     END Loop;
  ELSE
     wrtout(' No Failure records ');
  END IF;
   Exception
    When Others Then
      apps.fnd_file.put_line(apps.fnd_file.log,
                             'Error Occured In Error Record procedure :-> ' ||
                             Sqlerrm);
  END select_error_records;
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
    ln_count_taskname              number;
    ln_count_tasknumber            number;
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
    l_tn_dup_cnt              number := 0;
    l_status                  varchar2(100);
    l_dup_task                VARCHAR2(30);
    l_cflex_value             VARCHAR2(150);
    l_flex_value1             VARCHAR2(150);
    l_flex_value2             VARCHAR2(150);
    l_meaning                 VARCHAR2(80);
    l_flex_value5             VARCHAR2(150);
    l_flex_value7             VARCHAR2(150);
    l_lookup_code             VARCHAR2(30);
    l_old_task                tlt_rpa_projects_conv_stg.task_name%type := null;
    --l_tn_dup_cnt              NUMBER;
    --==============================================
    --Cursor to get count of the  Validated records
    --==============================================
    CURSOR lcu_valrec_cnt(cp_status_flag VARCHAR2, cp_request_id NUMBER) IS
      SELECT COUNT(1)
        FROM tlt_rpa_projects_conv_stg PAS
       WHERE NVL(PAS.status_flag, 'X') = cp_status_flag
           --AND PAS.legacy_project_number is not null
         AND PAS.request_id = cp_request_id;
    Cursor cur_projects_data(cp_status_flag IN varchar2) Is
      Select rowid,
             trim(record_identifier) record_identifier,
             trim(project_number) project_number,
             trim(substr(Project_Name,1,30)) Project_Name,
             trim(Project_Description) Project_Description,
             trim(long_name) long_name,
             trim(Project_Template) Project_Template,
             trim(Project_Type) Project_Type,
             Project_start_date Project_start_date,
             project_end_date Project_end_date,
             trim(Project_OU) Project_OU,
             trim(Location) Location,
             trim(IC_Type) IC_Type,
             trim(project_category) project_category,
             trim(Capital) Capital,
             trim(Customer) Customer,
             trim(Customer_Bill_To) Customer_Bill_To,
             trim(Customer_ship_to) Customer_ship_to,
             --   trim(product_code) product_code,
             trim(Project_status) Project_status,
             --   trim(organization_name) organization_name,
             trim(Project_manager) Project_manager,
        --     trim(project_partner) project_partner,
        --   trim(project_op_manager) project_op_manager,
        --     trim(opportunity_owner) opportunity_owner,
             trim(attribute4) attribute4,
         --    trim(task_name) task_name,
         --    trim(task_number) task_number,
         --    trim(description) description,
         --    trim(start_date) start_date,
         --    trim(Completion_date) Completion_date,
         --    trim(attribute1) attribute1,
         --    trim(attribute2) attribute2,
         --    trim(attribute3) attribute3,
         --    trim(attribute6) attribute6,
         --    trim(attribute7) attribute7,
         --    trim(attribute8) attribute8,
             trim(legacy_project_number) legacy_project_number,
             trim(Status_flag) Status_flag,
             trim(error_message) error_message
        From tlt_rpa_projects_conv_stg a
       where 1=1
         AND a.legacy_project_number is not null
         and a.status_flag = cp_status_flag
		 and EXISTS
                       (SELECT 1
                          FROM tlt_rpa_projects_conv_stg a1
                         WHERE 1=1
                               -- AND a1.status_flag = a.status_flag
                               AND a.record_identifier = a1.record_identifier
                        )
         for update nowait;
    Cursor cur_tasks_data(cp_proj_number in number,cp_status_flag IN varchar2) Is
      Select rowid,
             trim(record_identifier) record_identifier,
             trim(substr(task_name,1,25)) task_name,
             trim(substr(task_number,1,20)) task_number,
             trim(description) description,
             start_date start_date,
             Completion_date Completion_date,
             trim(substr(service_type_code,1,30)) service_type_code, -- 24-MAR-2017
             trim(attribute1) attribute1,
             trim(attribute2) attribute2,
             trim(attribute3) attribute3,
             trim(attribute6) attribute6,
             trim(attribute7) attribute7,
             trim(attribute8) attribute8,
             trim(Status_flag) Status_flag,
             trim(error_message) error_message
        From tlt_rpa_projects_conv_stg a
       where 1=1
         --and a.legacy_project_number is null
         and a.status_flag = cp_status_flag
         and a.record_identifier = cp_proj_number
     /*   and EXISTS
                       (SELECT 1
                          FROM tlt_rpa_projects_conv_stg a1
                         WHERE 1=1
                              -- AND a1.status_flag = a.status_flag
                               AND a.record_identifier = a1.record_identifier
                        ) */
         for update nowait;
    --==============================================
    --Cursor to get count of the transformed records
    --==============================================
    CURSOR lcu_prevalrec_cnt(cp_status_flag VARCHAR2) IS
      SELECT COUNT(1)
        FROM tlt_rpa_projects_conv_stg PAT
       WHERE NVL(PAT.status_flag, 'X') = cp_status_flag;
    --==============================================
    --Cursor to get address of customers
    --==============================================
    CURSOR lcu_address_id(cp_site_code VARCHAR2, cp_customer_id NUMBER, cp_proj_owning_org_id NUMBER, cp_location VARCHAR2) IS
      Select acct_site.cust_acct_site_id    
		From hz_cust_acct_sites_all acct_site, hz_cust_site_uses_all su, apps.hz_party_sites hp			
       Where acct_site.cust_acct_site_id = su.cust_acct_site_id
         And nvl(acct_site.status, 'A') = 'A'
         And acct_site.cust_account_id = cp_customer_id --X_Bill_To_Customer_Id
         And nvl(su.status, 'A') = 'A'
         And su.primary_flag = 'Y'
		 And acct_site.party_site_id = hp.party_site_id
         And su.site_use_code = cp_site_code
         And su.org_id = cp_proj_owning_org_id
         And UPPER(hp.PARTY_SITE_NUMBER) = upper(trim(cp_location));
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
        l_old_task := null;
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
             Where trim(Name) = substr(i.project_name, 0, 30)
                or segment1 = i.Project_number;
            If ln_project_name Is Not Null Then
              i.status_flag   := gc_error_flag;
              i.error_message := i.error_message || ' , ' ||
                                 '  Project Name already exist';
              lc_error_message := lc_error_message ||
                                  ' , Project Name already exist'||' for project name- '||i.project_name;
              insert_errors(i.project_name,
                            i.legacy_project_number,
                            gc_error_flag,
                            lc_error_message);
            End If;
          End If;
        Exception
          When Others Then
            wrtlog('Project name is unique');
          -- lc_error_message := null;
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
            select project_id
              into ln_template_id
              --from pa.pa_projects_all		 -- Commented code by IXPRAVEEN-ARGANO, 02-May-2023
			  from apps.pa_projects_all		--  code Added by IXPRAVEEN-ARGANO, 02-May-2023
             where name = i.project_template;
            --  where name like '%' || i.project_template || '%';
            IF ln_template_id is null THEN
              i.status_flag   := gc_error_flag;
              i.error_message := i.error_message || ' , ' ||
                                 ' Project Template do not exist in oracle';
              lc_error_message := lc_error_message ||
                                  ' , Project Template do not exist in oracle'||' for project name- '||i.project_name;
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
                                ' , Project Template do not exist in oracle'||' for project name- '||i.project_name;
            insert_errors(i.project_name,
                          i.legacy_project_number,
                          gc_error_flag,
                          lc_error_message);
        END;






        -------------To check project status exist is oracle--------------------
        BEGIN
          If i.project_status Is Null Then
            i.status_flag   := gc_error_flag;
            i.error_message := i.error_message || ' , ' ||
                               ' Project Status is null';
            lc_error_message := lc_error_message ||
                                'Project Status is null';
            insert_errors(i.project_name,
                          i.legacy_project_number,
                          gc_error_flag,
                          lc_error_message);
          ELSE
            SELECT project_status_code
              INTO ln_status_code
              FROM pa_project_statuses
             WHERE UPPER (project_status_name) = UPPER (TRIM (i.project_status))
                AND SYSDATE BETWEEN NVL (start_date_active, SYSDATE)
                                AND NVL (end_date_active, SYSDATE);

            IF ln_status_code is null THEN
              i.status_flag   := gc_error_flag;
              i.error_message := i.error_message || ' , ' ||
                                 ' Invalid Project Status Code ';
              lc_error_message := lc_error_message ||
                                  ' , Invalid Project Status Code'||' for project name- '||i.project_name;
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
                               ' Invalid Project Status Code';
            lc_error_message := lc_error_message ||
                                ' , Invalid Project Status Code'||' for project name- '||i.project_name;
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
                                ' , Project dates should not be null'||' for project name- '||i.project_name;
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
        --    lc_error_message := null;
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
            lc_error_message := lc_error_message || ',Project Type Is NULL'||' for project name- '||i.project_name;
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
                                ' ,Project Type is invalid or null'||' for project name- '||i.project_name;
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
              lc_error_message := lc_error_message || 'IC_TYPE is null'||' for project name- '||i.project_name;
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
              IF ln_class_category is null and
                 ln_class_code is null then
            /*   lc_error_message := null;
              ELSE
              */
                i.status_flag   := gc_error_flag;
                i.error_message := i.error_message || ' , ' ||
                                   'class category and code is not found';
                lc_error_message := lc_error_message ||
                                    'class category and code is not found'||' for project name- '||i.project_name;
                insert_errors(i.project_name,
                              i.legacy_project_number,
                              gc_error_flag,
                              lc_error_message);
              End if;
            --  end if;
              -- Check Project Category --
              IF i.project_category is not null then
              Select class_category, class_code
                into ln_class_category, ln_class_code
                From pa_class_codes
               Where class_category = ('TT Project Category')
                 And upper(class_code) = upper(i.project_category)
                 And end_date_active Is Null;
              IF ln_class_category is null and
                 ln_class_code is null then
            /*   lc_error_message := null;
              ELSE
              */
                i.status_flag   := gc_error_flag;
                i.error_message := i.error_message || ' , ' ||
                                   'class category and code is not found';
                lc_error_message := lc_error_message ||
                                    'class category and code is not found'||' for project name- '||i.project_name;
                insert_errors(i.project_name,
                              i.legacy_project_number,
                              gc_error_flag,
                              lc_error_message);
              End if;
              -- end if;
              IF i.location is not null then
                ----- Change for V3 version
                Select class_category, class_code
                  into ln_class_category, ln_class_code
                  From pa_class_codes
                 Where upper(class_category) = UPPER('TT Location')
                   And upper(class_code) = UPPER(i.location)
                   And end_date_active Is Null;
                   IF ln_class_category is null and
                 ln_class_code is null then
            /*   lc_error_message := null;
              ELSE
              */
                i.status_flag   := gc_error_flag;
                i.error_message := i.error_message || ' , ' ||
                                   'location does not exists';
                lc_error_message := lc_error_message ||
                                    'location does not exists'||' for project name- '||i.project_name;
                insert_errors(i.project_name,
                              i.legacy_project_number,
                              gc_error_flag,
                              lc_error_message);
              END IF;
             ELSE
                wrtlog('location is null');
                lc_error_message := null;
              END If;
			  wrtlog('Project Category is null');
                lc_error_message := null;
  --            End IF;
          end if;
		  end if;
          end if;
        Exception
          When Others Then
            ln_class_category := null;
            ln_class_code     := null;
            i.status_flag   := gc_error_flag;
            i.error_message := i.error_message || ' , ' ||
                               'class category Default value not found';
            lc_error_message := lc_error_message ||
                                'class category Default value not found'||' for project name- '||i.project_name;
            insert_errors(i.project_name,
                          i.legacy_project_number,
                          gc_error_flag,
                          lc_error_message);
        end;
        ---------------- To check customer exist in oracle -----------------------
        Begin
          IF substr(i.project_template, 0, 8) <> 'T, Admin' THEN
            ----Change for V2 version
          /* lc_error_message := null;
          ELSE
          */
            If i.customer Is Null Then
              i.status_flag   := gc_error_flag;
              i.error_message := i.error_message || ' , ' ||
                                 'Customer name is null';
              lc_error_message := lc_error_message ||
                                  'Customer name is null'||' for project name- '||i.project_name;
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
                                    'Organization of customer is not found'||' for project name- '||i.project_name;
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
                                  'customer Bill_to is null'||' for project name- '||i.project_name;
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
                                  'customer ship_to is null'||' for project name- '||i.project_name;
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
                                ln_owning_org_id,
                                i.customer_bill_to);
            FETCH lcu_address_id
              INTO ln_billto_address_id;
            IF lcu_address_id%NOTFOUND THEN
               i.status_flag   := gc_error_flag;
               i.error_message := i.error_message || ' , ' ||
                                  'Customer Bill To location not exists in oracle ';
               lc_error_message := lc_error_message ||
                                   'Customer Bill To location not exists in oracle'||' for project name- '||i.project_name;
               insert_errors(i.project_name,
                             i.legacy_project_number,
                             gc_error_flag,
                             lc_error_message);
            END IF;
            CLOSE lcu_address_id;
          END IF;

          ln_shipto_address_id := null;
          IF i.customer_ship_to is not null THEN
            OPEN lcu_address_id('SHIP_TO',
                                ln_customer_id,
                                ln_owning_org_id,
                                i.customer_ship_to);
            FETCH lcu_address_id
              INTO ln_shipto_address_id;
            IF lcu_address_id%NOTFOUND THEN
               i.status_flag   := gc_error_flag;
               i.error_message := i.error_message || ' , ' ||
                                  'Customer Ship To location not exists in oracle ';
               lc_error_message := lc_error_message ||
                                   'Customer Ship To location not exists in oracle'||' for project name- '||i.project_name;
               insert_errors(i.project_name,
                             i.legacy_project_number,
                             gc_error_flag,
                             lc_error_message);
            END IF;
            CLOSE lcu_address_id;
          END IF;
        EXCEPTION
         WHEN OTHERS THEN
               i.status_flag   := gc_error_flag;
               i.error_message := i.error_message || ' , ' ||
                                  'Customer does not exits ';
               lc_error_message := lc_error_message ||
                                   'Customer does not exits'||' for project name- '||i.project_name;
               insert_errors(i.project_name,
                             i.legacy_project_number,
                             gc_error_flag,
                             lc_error_message);
        End;
        ------------------ To check long name is unique ----------------------------------
        Begin
          If i.long_name Is not Null Then
            Select long_name
              Into ln_long_name
              From pa_projects_all
             Where long_name = i.long_name;
            If ln_long_name Is Not Null Then
              i.status_flag   := gc_error_flag;
              i.error_message := i.error_message || ' , ' ||
                                 'Long name is not unique';
              lc_error_message := lc_error_message ||
                                  'Long name is not unique'||' for project name- '||i.project_name;
              insert_errors(i.project_name,
                            i.legacy_project_number,
                            gc_error_flag,
                            lc_error_message);
            End If;
          End If;
        Exception
          When Others Then
            wrtlog('long name is unique');
          --  lc_error_message := null;
        End;
        ------------------------- check for project Manager
        ln_effective_start_date := null;
        Begin
          IF i.project_manager IS NULL THEN
            i.status_flag   := gc_error_flag;
            i.error_message := i.error_message || ' , ' ||
                               'Project Manager is NULL';
            lc_error_message := lc_error_message ||
                                ' , Project Manager is NULL'||' for project name- '||i.project_name;
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
               and current_emp_or_apl_flag = 'Y'
               AND person_id IS NOT NULL;
            IF ln_person_id IS NOT NULL THEN
             -- lc_error_message := null;
              select effective_start_date
                into ln_effective_start_date
                from per_all_people_f
               where sysdate between effective_start_date and
                     effective_end_date
                 and current_emp_or_apl_flag = 'Y'
                 and full_name = i.project_manager;
              wrtlog('Project Manager Effective Start Date :-> ' ||
                     to_char(ln_effective_start_date, 'DD-MON-YYYY'));
              wrtlog('Project Start Date :-> ' || i.project_start_date);
              IF ln_effective_start_date > ln_start_date THEN
                wrtlog('Project Start Date :-> ' ||
                       ln_effective_start_date || '>' || ln_start_date);

                UPDATE tlt_rpa_projects_conv_stg
                SET project_manager = 'Mendoza, Geraldine'
                    ,long_name = 'Project Manager Start Date > Project Start Date'||' Manager Chenged from - '||i.project_manager
                WHERE CURRENT OF cur_projects_data;

                --i.status_flag   := gc_error_flag;
                i.error_message := i.error_message || ' , ' ||
                                   'Project Manager Start Date > Project Start Date';
                lc_error_message := lc_error_message ||
                                    ' , Project Manager Start Date > Project Start Date'||' Manager Chenged from - '||i.project_manager;
                /*insert_errors(i.project_name,
                              i.legacy_project_number,
                              gc_error_flag,
                              lc_error_message);*/
             --     ELSE
             --   ln_effective_start_date :=ln_start_date;
             --   lc_status_flag          :=gc_validation_flag;
              END IF;
			      ln_effective_start_date := NULL;
            END IF;
          END IF;
        Exception
          When Others Then
             --i.status_flag   := gc_error_flag;
             i.error_message := i.error_message || ' , ' ||
                                ' Project manager is invalid';
             lc_error_message := lc_error_message ||
                                 ', Project manager is invalid'||' Manager Chenged from - '||i.project_manager;

             UPDATE tlt_rpa_projects_conv_stg
             SET project_manager = 'Mendoza, Geraldine'
                ,long_name = 'Project manager is invalid'||' Manager Chenged from - '||i.project_manager
             WHERE CURRENT OF cur_projects_data;

            /*insert_errors(i.project_name,
                          i.legacy_project_number,
                          gc_error_flag,
                          lc_error_message);*/
        end;
        ----------- Balance Sheet Client Code DFF Attribute --------
        BEGIN
          If i.attribute4 Is NOT Null Then
		  Select flex_value
            Into l_cflex_value
            From apps.fnd_flex_values_vl ffvl
           Where flex_value = i.attribute4
             and enabled_flag = 'Y'
             and trunc(sysdate) <= nvl (ffvl.end_date_active,to_date ('31-DEC-4712'))
             and exists (select 1
                           from apps.fnd_flex_value_sets ffvs
                          where ffvs.flex_value_set_id = ffvl.flex_value_set_id
                            and ffvs.flex_value_set_name = 'TELETECH_CLIENT');
            IF l_cflex_value is null THEN
              i.status_flag   := gc_error_flag;
              i.error_message := i.error_message || ' , ' ||
                                 ' Balance Sheet Client Code is not a valid DFF Value';
              lc_error_message := lc_error_message ||
                                  ' , Balance Sheet Client Code is not a valid DFF Value'||' for project name- '||i.project_name;
              insert_errors(i.project_name,
                            i.legacy_project_number,
                            gc_error_flag,
                            lc_error_message);
            ELSE
              lc_error_message := null;
            End If;
               wrtlog('Balance Sheet Client Code is null');
                lc_error_message := null;
          End if;
        Exception
          When others then
            i.status_flag   := gc_error_flag;
            i.error_message := i.error_message || ' , ' ||
                               ' Balance Sheet Client Code is not a valid DFF Value';
            lc_error_message := lc_error_message ||
                                ' , Balance Sheet Client Code is not a valid DFF Value'||' for project name- '||i.project_name;
            insert_errors(i.project_name,
                          i.legacy_project_number,
                          gc_error_flag,
                          lc_error_message);
        END;
        ------------------ To check task name is unique--------------
        For j In cur_tasks_data(i.record_identifier,p_validate_data_flag)
        loop
		j.error_message := Null;
		lc_error_message := null;
        Begin
          l_dup_task := 'N';
          IF j.task_name IS NULL THEN
            j.status_flag   := gc_error_flag;
            j.error_message := j.error_message || ' , ' ||
                               'Task_name is null'||' for task name- '||j.TASK_NAME;
            lc_error_message := lc_error_message ||
                                ' ,Task_name is null'||' for task name- '||j.TASK_NAME;
            insert_errors(i.project_name,
                          i.legacy_project_number,
                          gc_error_flag,
                          lc_error_message);
            ELSE
            ------------------ To check duplicate task name for same project --------------
            /*
            identify_duplicate_tasks(j.record_identifier,j.task_name,l_status);
             wrtlog('l_statu  1232-' || l_status);
              */
             Begin
              select COUNT(TASK_NAME)
               INTO l_tn_dup_cnt
              from tlt_rpa_projects_conv_stg
             where 1=1
             --  and NVL(ERROR_MESSAGE,'ZZ') !='Duplicate Task'
               and TASK_NAME =j.TASK_NAME
               and record_identifier = i.record_identifier;
            Exception when others then
              l_tn_dup_cnt := 0;
            end;
            --   wrtlog('l_tn_dup_cnt  :'||l_tn_dup_cnt);
             IF l_tn_dup_cnt > 1 and l_old_task <> j.TASK_NAME then
               j.status_flag   := gc_error_flag;
               lc_error_message := lc_error_message ||
                                ' ,Duplicate Task Name '||' for task name- '||j.TASK_NAME;
             --DBMS_OUTPUT.PUT_LINE('Duplicate Task : '||i.project_name||','|| i.legacy_project_number||','||i.record_identifier||', '||j.TASK_NAME);
             --dbms_output.put_line('Error flag :' ||gc_error_flag||' , '||lc_error_message);
                insert_errors(i.project_name,
                          i.legacy_project_number,
                          gc_error_flag,
                          lc_error_message);
             END IF;
             l_old_task := j.TASK_NAME;
          End if;
        Exception
          When Others Then
            wrtlog(',Task name should be unique');
          -- lc_error_message := null;
        end;
        ------ Task start and end date check--------------------
        Begin
          wrtlog('Task Start Date    :-> ' ||
                 TO_CHAR(j.start_date, 'DD-MON-YYYY'));
          wrtlog('Task Completion Date  :-> ' ||
                 TO_CHAR(j.completion_date, 'DD-MON-YYYY'));
          wrtlog('Project Start Date     :-> ' ||
                 TO_CHAR(ln_start_date, 'DD-MON-YYYY'));
          wrtlog('Project End Date :-> ' ||
                 TO_CHAR(ln_completion_date, 'DD-MON-YYYY'));
/*
          IF j.start_date > i.project_start_date and
             ln_start_date is not null and j.start_date is not null THEN
            lc_error_message := null;
          ELSE
          */
          IF ln_start_date IS NULL OR j.start_date IS NULL THEN
            j.status_flag   := gc_error_flag;
            j.error_message := j.error_message || ' , ' ||
                               'Task Start Dates should not be null';
            lc_error_message := lc_error_message ||
                                ' , Task Start Dates should not be null'||' for task name- '||j.TASK_NAME;
            insert_errors(i.project_name,
                          i.legacy_project_number,
                          gc_error_flag,
                          lc_error_message);
          END IF;
          IF ln_completion_date IS NOT NULL AND
             j.completion_date IS NOT NULL THEN
           -- lc_error_message := null;
            IF j.completion_date > ln_completion_date THEN
              j.status_flag   := gc_error_flag;
              j.error_message := j.error_message || ' , ' ||
                                 'Task Completion Date > Project End Date';
              lc_error_message := lc_error_message ||
                                  ' , Task Completion Date > Project End Date '||' for task name- '||j.TASK_NAME;
           /*   insert_errors(i.project_name,
                            i.legacy_project_number,
                            gc_error_flag,
                            lc_error_message);
                         wrtlog('task end date is > than project end date' ||
                     ln_completion_date);
            ELSE
              lc_error_message := null;
              */
            END IF;
          ELSIF ln_completion_date is null AND j.completion_date IS NULL THEN
            -- insert_errors(i.project_name, gc_error_flag, lc_error_message);
        --    lc_error_message := null;
            j.completion_date := ln_completion_date;
          END IF;
        Exception
          When Others Then
            j.status_flag    := gc_error_flag;
            j.error_message  := j.error_message || ' , ' ||
                                'task date is invalid';
            lc_error_message := lc_error_message ||
                                ', task date is invalid for'||' task name- '||j.TASK_NAME;
            insert_errors(i.project_name,
                          i.legacy_project_number,
                          gc_error_flag,
                          lc_error_message);
        END;
        -- Validate Service Type for Tasks
        BEGIN
         IF j.service_type_code IS NULL THEN
            j.status_flag   := gc_error_flag;
            j.error_message := j.error_message || ' , ' ||
                               'Service Type for Tasks is null';
            lc_error_message := lc_error_message ||
                                ' ,Service Type for Tasks is null'||' for task name- '||j.TASK_NAME;
            insert_errors(i.project_name,
                          i.legacy_project_number,
                          gc_error_flag,
                          lc_error_message);
        ELSE
            select flv.lookup_code
              into l_lookup_code
              from fnd_lookup_values_vl flv
             where flv.lookup_type = 'SERVICE TYPE'
               and lookup_code = j.service_type_code
               and trunc (sysdate) between trunc (flv.start_date_active)
                           and nvl (trunc (flv.end_date_active),
                                    to_date ('31-DEC-4712'));
            IF l_lookup_code is null THEN
              j.status_flag   := gc_error_flag;
              j.error_message := j.error_message || ' , ' ||
                                 ' Service Type for Tasks does not exists';
              lc_error_message := lc_error_message ||
                                  ' , Service Type for Tasks does not exists'||' for task name- '||j.TASK_NAME;
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
            j.status_flag   := gc_error_flag;
            j.error_message := j.error_message || ' , ' ||
                               ' Service Type for Tasks does not exists';
            lc_error_message := lc_error_message ||
                                ' , Service Type for Tasks does not exists'||' for task name- '||j.TASK_NAME;
            insert_errors(i.project_name,
                          i.legacy_project_number,
                          gc_error_flag,
                          lc_error_message);
        END;
        ----------- Client DFF Attribute --------
        BEGIN
          If j.attribute1 Is NOT Null Then
            Select flex_value
            Into l_flex_value1
            From apps.fnd_flex_values_vl ffvl
           Where flex_value = j.attribute1
             and enabled_flag = 'Y'
             and trunc(sysdate) <= nvl (ffvl.end_date_active,to_date ('31-DEC-4712'))
             and exists (select 1
                           from apps.fnd_flex_value_sets ffvs
                          where ffvs.flex_value_set_id = ffvl.flex_value_set_id
                            and ffvs.flex_value_set_name = 'TELETECH_CLIENT');
            IF l_flex_value1 is null THEN
              j.status_flag   := gc_error_flag;
              j.error_message := j.error_message || ' , ' ||
                                 ' Client does not exist in DFF Value';
              lc_error_message := lc_error_message ||
                                  ' , Client does not exist in DFF Value'||' for task name- '||j.TASK_NAME;
              insert_errors(i.project_name,
                            i.legacy_project_number,
                            gc_error_flag,
                            lc_error_message);
            ELSE
              lc_error_message := null;
            End If;
            wrtlog('Balance Sheet Client Code is null');
                lc_error_message := null;
          End if;
        Exception
          When others then
            j.status_flag   := gc_error_flag;
            j.error_message := j.error_message || ' , ' ||
                               ' Client does not exist in DFF Value';
            lc_error_message := lc_error_message ||
                                ' , Client does not exist in DFF Value'||' for task name- '||j.TASK_NAME;
            insert_errors(i.project_name,
                          i.legacy_project_number,
                          gc_error_flag,
                          lc_error_message);
        END;
        ----------- Task type --------
        BEGIN
          If j.attribute2 Is Null Then
            j.status_flag   := gc_error_flag;
            j.error_message := j.error_message || ' , ' ||
                               ' Task type is null, it is mandatory field in DFF';
            lc_error_message := lc_error_message ||
                                'Task type is null, it is mandatory field in DFF'||' for task name- '||j.TASK_NAME;
            insert_errors(i.project_name,
                          i.legacy_project_number,
                          gc_error_flag,
                          lc_error_message);
          ELSE
            Select flex_value
            Into l_flex_value2
            From apps.fnd_flex_values_vl ffvl
           Where flex_value = j.attribute2
             and enabled_flag = 'Y'
             and trunc(sysdate) <= nvl (ffvl.end_date_active,to_date ('31-DEC-4712'))
             and exists (select 1
                           from apps.fnd_flex_value_sets ffvs
                          where ffvs.flex_value_set_id = ffvl.flex_value_set_id
                            and ffvs.flex_value_set_name = 'TT Task Type');
            IF l_flex_value2 is null THEN
              j.status_flag   := gc_error_flag;
              j.error_message := j.error_message || ' , ' ||
                                 ' Task Type does not exist in DFF Value';
              lc_error_message := lc_error_message ||
                                  ' , Task Type does not exist in DFF Value'||' for task name- '||j.TASK_NAME;
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
            j.status_flag   := gc_error_flag;
            j.error_message := j.error_message || ' , ' ||
                               ' Task Type does not exist in DFF Value';
            lc_error_message := lc_error_message ||
                                ' , Task Type does not exist in DFF Value'||' for task name- '||j.TASK_NAME;
            insert_errors(i.project_name,
                          i.legacy_project_number,
                          gc_error_flag,
                          lc_error_message);
        END;
 -------------- Hourly POC DFF Attribute ---------------
BEGIN
          If j.attribute3 Is NOT Null Then
            select meaning
              into l_meaning
              from apps.FND_LOOKUPS
             where lookup_code = j.attribute3
               and enabled_flag = 'Y'
               and LOOKUP_TYPE = 'YES_NO';
            IF l_meaning is null THEN
              j.status_flag   := gc_error_flag;
              j.error_message := j.error_message || ' , ' ||
                                 ' Hourly POC is null, it should be Yes or No';
              lc_error_message := lc_error_message ||
                                  ' , Hourly POC is null, it should be Yes or No'||' for task name- '||j.TASK_NAME;
              insert_errors(i.project_name,
                            i.legacy_project_number,
                            gc_error_flag,
                            lc_error_message);
            ELSE
              lc_error_message := null;
            End If;
                wrtlog('Hourly POC is null');
                lc_error_message := null;
          End if;
        Exception
          When others then
            j.status_flag   := gc_error_flag;
            j.error_message := j.error_message || ' , ' ||
                               ' Hourly POC do not exist in DFF Value';
            lc_error_message := lc_error_message ||
                                ' , Hourly POC do not exist in DFF Value'||' for task name- '||j.TASK_NAME;
            insert_errors(i.project_name,
                          i.legacy_project_number,
                          gc_error_flag,
                          lc_error_message);
        END;
        ------------ Delivery Status DFF (Attribute7) Validation ----------------
        BEGIN
          If j.attribute7 Is NOT Null Then
            Select flex_value
            Into l_flex_value7
            From apps.fnd_flex_values_vl ffvl
           Where flex_value = j.attribute7
             and enabled_flag = 'Y'
             and trunc(sysdate) <= nvl (ffvl.end_date_active,to_date ('31-DEC-4712'))
             and exists (select 1
                           from apps.fnd_flex_value_sets ffvs
                          where ffvs.flex_value_set_id = ffvl.flex_value_set_id
                            and ffvs.flex_value_set_name = 'TT Task Status');
            IF l_flex_value7 is null THEN
              j.status_flag   := gc_error_flag;
              j.error_message := j.error_message || ' , ' ||
                                 ' Delivery Status does not exist in DFF Value';
              lc_error_message := lc_error_message ||
                                  ' , Delivery Status does not exist in DFF Value'||' for task name- '||j.TASK_NAME;
               insert_errors(i.project_name,
                            i.legacy_project_number,
                            gc_error_flag,
                            lc_error_message);
            ELSE
              lc_error_message := null;
            End If;
                wrtlog('Delivery Status is null');
                lc_error_message := null;
          End if;
        Exception
          When others then
            j.status_flag   := gc_error_flag;
            j.error_message := j.error_message || ' , ' ||
                               ' Delivery Status does not exist';
            lc_error_message := lc_error_message ||
                                ' , Delivery Status does not exist'||' for task name- '||j.TASK_NAME;
            insert_errors(i.project_name,
                          i.legacy_project_number,
                          gc_error_flag,
                          lc_error_message);
        END;
        IF j.status_flag <> gc_error_flag AND
           j.status_flag = gc_transformation_flag THEN
          j.status_flag   := gc_validation_flag;
          j.error_message := 'Validated';
        END IF;
       end loop;
        --DBMS_OUTPUT.PUT_LINE ( 'gc_error_flag = ' || gc_error_flag );
        --DBMS_OUTPUT.PUT_LINE ( 'lc_error_message = ' || lc_error_message );
    /*    insert_errors(i.project_name,
                        i.legacy_project_number,
                        gc_error_flag,
                        lc_error_message);
    */
        -- Update tlt_rpa_projects_conv_stg
        BEGIN
          select count(*)
            into ln_count_update
            from tlt_pa_validation_error
           where project_name = i.project_name;
          IF ln_count_update > 0 THEN
            wrtlog('before update-' || ln_start_date);
            Update tlt_rpa_projects_conv_stg
               set creation_date    = sysdate,
                   last_update_date = sysdate,
                   --customer_Bill_to = customer_Bill_to||'###'||ln_billto_address_id,
                   --customer_ship_to = customer_ship_to||'###'||ln_shipto_address_id,
                   --     project_start_date = ln_start_date,
                   --     project_end_date   = ln_completion_date,
                   -- Project_status = ln_project_status,
                   request_id    = gn_request_id,
                   status_flag   = gc_error_flag,
                   error_message = lc_error_message --i.error_message
             where 1=1 --rowid = i.rowid;
             AND RECORD_IDENTIFIER = i.RECORD_IDENTIFIER;
            wrtlog('Staging table update with valid records-' ||
                   gc_error_flag);
          else
            Update tlt_rpa_projects_conv_stg
               set creation_date    = sysdate,
                   last_update_date = sysdate,
                   --customer_Bill_to = customer_Bill_to||'###'||ln_billto_address_id,
                   --customer_ship_to = customer_ship_to||'###'||ln_shipto_address_id,
                   --    project_start_date = ln_start_date,
                   --    project_end_date   = ln_completion_date,
                   -- Project_status = ln_project_status,
                   request_id    = gn_request_id,
                   status_flag   = gc_validation_flag,
                   error_message = 'Validated '||lc_error_message
             where 1=1 --rowid = i.rowid;
             AND RECORD_IDENTIFIER = i.RECORD_IDENTIFIER;
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

  PROCEDURE ttec_create_project (p_api_version_number  IN NUMBER
                                                     ,p_commit IN  VARCHAR2  := FND_API.G_FALSE
													 ,p_init_msg_list IN  VARCHAR2  := FND_API.G_FALSE
													 ,ln_msg_count OUT NOCOPY  NUMBER
													 ,lc_msg_data OUT NOCOPY VARCHAR2
													 ,lc_return_status OUT NOCOPY  VARCHAR2
													 ,lc_workflow_status OUT  NOCOPY VARCHAR2
													 ,ln_product_code IN  VARCHAR2
													 ,lr_project_in IN  apps.pa_project_pub.project_in_rec_type
													 ,lr_project_out OUT NOCOPY  apps.pa_project_pub.project_out_rec_type
													 ,lt_key_members IN  apps.pa_project_pub.project_role_tbl_type
													 ,lt_task_in IN  apps.pa_project_pub.task_in_tbl_type
													 ,lt_tasks_out OUT NOCOPY  apps.pa_project_pub.task_out_tbl_type
													 ,lt_customer_tbl IN  apps.pa_project_pub.customer_tbl_type
													 ,lt_class_categories IN  apps.pa_project_pub.class_category_tbl_type
													 ,p_status_flag OUT VARCHAR2
													 ,p_rec_identifier NUMBER
													 ) IS
PRAGMA AUTONOMOUS_TRANSACTION;
lc_error_message   Varchar2(32000) := 'ERROR MSG:';
lc_data               VARCHAR2(32000);
ln_msg_index_out      NUMBER;
LN_PROJECT_ID NUMBER;
LN_PROJECT_NUMBER VARCHAr2(100);
begin
        pa_project_pub.clear_project;
        pa_project_pub.INIT_PROJECT;
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
            p_status_flag := gc_error_flag;
            wrtlog('   Error Occured In API-Block :-> ' || SQLERRM);
            lc_error_message := lc_error_message || 'EXCEPTION @API> ' ||
                                SUBSTR(SQLERRM, 1, 400);
--        NULL;
        END;
        BEGIN
          IF lc_return_status <> 'S' THEN
            p_status_flag := gc_error_flag;
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
            /*wrtlog(' API Error Message :-> ' || lc_error_message ||
                   i.project_start_date || '---' || i.project_end_date);*/
            wrtlog(' Terminating the program');
            UPDATE tlt_rpa_projects_conv_stg
               set status_flag      = gc_error_flag,
                   error_message    = lc_error_message,
                   request_id       = gn_request_id,
                   creation_date    = sysdate,
                   last_update_date = sysdate
             where 1=1 --upper(trim(project_name)) = upper(trim(i.project_name))
               and RECORD_IDENTIFIER =p_rec_identifier;--and ROWID = i.rowid;
          ELSE
            wrtlog('   Project Successfully Created');
            wrtlog('   Project ID :-> ' || lr_project_out.pa_project_id);
            ln_project_id     := lr_project_out.pa_project_id;
            ln_project_number := lr_project_out.pa_project_number;
            BEGIN
              IF lc_return_status = 'S' THEN
                UPDATE tlt_rpa_projects_conv_stg
                   SET status_flag      = DECODE(lc_return_status,
                                                 'S',
                                                 'P',
                                                 lc_return_status),
                       project_number   = to_char(ln_project_number),
                       Error_message    = 'Processed',
                       request_id       = gn_request_id,
                       creation_date    = sysdate,
                       last_update_date = sysdate
                 WHERE 1=1 --ROWID = i.rowid;
               and RECORD_IDENTIFIER =p_rec_identifier;
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
                                   'While updating TLT_RPA_PROJECTS_CONV_STG fo error ');
        END;
        COMMIT;
end ttec_create_project;

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
	ln_class_category3    varchar2(50);
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
    ln_person_id3                  NUMBER; --------- V4 opportunity owner logic change
    ln_role_type                   VARCHAR2(100);
    ln_processrec_cnt              number;
    ln_valrec_cnt                  number;
    ln_count                       number;
    ln_customer_id                 number;
    ln_partner_id                  number;
    ln_customer_ship_to            number;
    ln_customer_bill_to            number;
    ln_carryingout_organization_id number;
    --l_date_mask                    VARCHAR2(150);
    ln_status_code                 VARCHAR2(50);
    ln_task_cnt number;
    --ln_resp_id  number := 1013384; -- 1013384
    --==================================================
    --Cursor to get count of the records to be processed
    --==================================================
      CURSOR lcu_valrec_cnt(cp_status_flag VARCHAR2) IS
      SELECT COUNT(1)
        FROM tlt_rpa_projects_conv_stg PAS
       WHERE NVL(PAS.status_flag, 'X') = cp_status_flag;
    --==============================================
    --Cursor to get count of the  processed records
    --==============================================
      CURSOR lcu_processrec_cnt(cp_status_flag VARCHAR2, cp_request_id NUMBER) IS
      SELECT COUNT(1)
        FROM tlt_rpa_projects_conv_stg PAS
       WHERE NVL(PAS.status_flag, 'X') = cp_status_flag
         AND PAS.request_id = cp_request_id;
       Cursor cur_projects_data(cp_status_flag IN varchar2) Is
      Select rowid,
             trim(record_identifier) record_identifier,
             trim(project_number) project_number,
             trim(substr(Project_Name,1,30)) Project_Name,
             trim(Project_Description) Project_Description,
             trim(long_name) long_name,
             trim(Project_Template) Project_Template,
             trim(Project_Type) Project_Type,
             Project_start_date Project_start_date,
             project_end_date Project_end_date,
             trim(Project_OU) Project_OU,
             trim(Location) Location,
             trim(IC_Type) IC_Type,
             trim(project_category) project_category,
             trim(Capital) Capital,
             trim(Customer) Customer,
             trim(Customer_Bill_To) Customer_Bill_To,
             trim(Customer_ship_to) Customer_ship_to,
             --   trim(product_code) product_code,
             trim(Project_status) Project_status,
             --   trim(organization_name) organization_name,
             trim(Project_manager) Project_manager,
             trim(project_partner) project_partner,
             trim(project_op_manager) project_op_manager,
             trim(opportunity_owner) opportunity_owner, -- 24-MAR-2017
             trim(attribute4) attribute4, -- 24-MAR-2017
         --    trim(task_name) task_name,
         --    trim(task_number) task_number,
         --    trim(description) description,
         --    trim(start_date) start_date,
         --    trim(Completion_date) Completion_date,
         --    trim(attribute1) attribute1,
         --    trim(attribute2) attribute2,
         --    trim(attribute3) attribute3,
         --    trim(attribute6) attribute6,
         --    trim(attribute7) attribute7,
         --    trim(attribute8) attribute8,
             trim(legacy_project_number) legacy_project_number,
             trim(Status_flag) Status_flag,
             trim(error_message) error_message
        From tlt_rpa_projects_conv_stg a
       where 1=1
         and a.legacy_project_number is not null
         and status_flag = 'V'
         and EXISTS
                       (SELECT 1
                          FROM tlt_rpa_projects_conv_stg a1
                         WHERE 1=1
                           AND a.record_identifier = a1.record_identifier
                        );
    --  for update nowait;
    Cursor cur_tasks_data(cp_proj_number in number) Is -- , cp_status_flag IN varchar2
      Select rowid,
             trim(record_identifier) record_identifier,
             trim(substr(task_name,1,25)) task_name,
             trim(substr(task_number,1,20)) task_number,
             trim(description) description,
             start_date start_date,
             Completion_date Completion_date,
             trim(substr(service_type_code,1,30)) service_type_code, -- 24-MAR-2017
             trim(attribute1) attribute1,
             trim(attribute2) attribute2,
             trim(attribute3) attribute3,
             trim(attribute6) attribute6,
             trim(attribute7) attribute7,
             trim(attribute8) attribute8,
             trim(Status_flag) Status_flag,
             trim(error_message) error_message
        From tlt_rpa_projects_conv_stg a
       where 1=1
         --and a.legacy_project_number is not null
         and status_flag = 'V'
         and a.record_identifier = cp_proj_number;
        /* and EXISTS
                       (SELECT 1
                          FROM tlt_rpa_projects_conv_stg a1
                         WHERE 1=1
                           AND a.record_identifier = a1.record_identifier
                        ); */
    CURSOR cur_class_code(cp_class_category VARCHAR2, cp_class_code VARCHAR2) IS
      SELECT class_category, Class_code
        FROM pa_class_codes
       WHERE UPPER(class_category) = UPPER(cp_class_category)
         AND UPPER(class_code) = UPPER(cp_class_code)
         AND end_date_active IS NULL;
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
       where meaning = 'Project Operations Manager'
      union all
       select project_role_type, meaning
        from pa_project_role_types
       where meaning = 'Opportunity Owner';
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
		apps.fnd_global.apps_initialize(gn_user_id,
                                        gn_responsibility_id,
                                        gn_respappl_id);
		wrtlog('   gn_responsibility_id '||gn_responsibility_id);
		wrtlog('   gn_user_id '||gn_user_id);
		wrtlog('   gn_respappl_id '||gn_respappl_id);
		apps.pa_interface_utils_pub.set_global_info(p_api_version_number => 1.0,
                                                    p_responsibility_id  => gn_responsibility_id, --1013364 ,
                                                    p_user_id            => gn_user_id, --393780,-- 394060,
                                                    p_msg_count          => ln_msg_count,
                                                    p_msg_data           => lc_msg_data,
                                                    p_return_status      => lc_return_status);
		wrtlog('   lc_return_status '||lc_return_status);
        ln_project_id := NULL;
        lt_key_members.DELETE;
        lt_class_categories.DELETE;
        lt_customer_tbl.DELETE;
        lt_task_in.DELETE;
        lt_tasks_out.DELETE;
        lc_error_message := 'Error Message :->';
        ld_empeff_start_date := NULL;
    --    pa_project_pub.clear_project;
    --    pa_project_pub.INIT_PROJECT;
        lc_msg_data      := NULL;
        lc_return_status := NULL;
        Begin
          select project_id, completion_date, carrying_out_organization_id
            into ln_template_id,
                 ln_completion_date,
                 ln_carryingout_organization_id
            --from pa.pa_projects_all							-- Commented code by IXPRAVEEN-ARGANO, 02-May-2023
			 from apps.pa_projects_all							--  code Added by IXPRAVEEN-ARGANO, 02-May-2023
           where name = i.project_template;
          -- where name like '%' || i.project_template || '%';
        EXCEPTION
          When Others Then
            wrtlog('Error Occured while checking project template :-> ' ||
                   Sqlerrm);
        End;






        -------------To check project status exist is oracle--------------------
        ln_status_code := NULL;
        BEGIN
          If i.project_status Is Null Then
            i.status_flag   := gc_error_flag;
            i.error_message := i.error_message || ' , ' ||
                               ' Project Status is null';
            lc_error_message := lc_error_message ||
                                'Project Status is null';
            insert_errors(i.project_name,
                          i.legacy_project_number,
                          gc_error_flag,
                          lc_error_message);
          ELSE
            SELECT project_status_code
              INTO ln_status_code
              FROM pa_project_statuses
             WHERE UPPER (project_status_name) = UPPER (TRIM (i.project_status))
                AND SYSDATE BETWEEN NVL (start_date_active, SYSDATE)
                                AND NVL (end_date_active, SYSDATE);

            IF ln_status_code is null THEN
              i.status_flag   := gc_error_flag;
              i.error_message := i.error_message || ' , ' ||
                                 ' Invalid Project Status Code ';
              lc_error_message := lc_error_message ||
                                  ' , Invalid Project Status Code'||' for project name- '||i.project_name;
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
                               ' Invalid Project Status Code';
            lc_error_message := lc_error_message ||
                                ' , Invalid Project Status Code'||' for project name- '||i.project_name;
            insert_errors(i.project_name,
                          i.legacy_project_number,
                          gc_error_flag,
                          lc_error_message);
        END;














        wrtlog('   Track 1');
        lr_project_in.pm_project_reference := substr(i.legacy_project_number, 0,25); ---changed to legacy_project_no_ebs
		wrtlog('   legacy_project_number '|| i.legacy_project_number);
        lr_project_in.project_status_code := ln_status_code; ---changed to ln_status_code
		wrtlog('   Project Status Code '|| ln_status_code);
      wrtlog('   Project Status Code in file '|| i.project_status);
        lr_project_in.project_name         := substr(i.Project_name, 0, 30);
		wrtlog('   Project_name '|| i.Project_name);
        wrtlog('   Track 2');
        lr_project_in.carrying_out_organization_id := ln_carryingout_organization_id;
		wrtlog('   ln_carryingout_organization_id '|| ln_carryingout_organization_id);
        wrtlog('   Track 3');
        lr_project_in.created_from_project_id := ln_template_id; --- 5002;--97002;--i.template_id;
        wrtlog('   created_from_project_id '|| ln_template_id);
		lr_project_in.description             := substr(i.project_description,
                                                        0,
                                                        250); --SUBSTR (i.project_desc,1,250);
        wrtlog('   project_description '|| i.project_description);
        lr_project_in.long_name               := NULL;
--        wrtlog('   long_name '|| i.long_name);
		lr_project_in.actual_start_date       := i.project_start_date;
		wrtlog('   actual_start_date '|| i.project_start_date);
        lr_project_in.actual_finish_date      := i.project_end_date;
		wrtlog('   actual_finish_date '|| i.project_end_date);
        wrtlog(' track 3.1');
        lr_project_in.start_date := i.project_start_date;
        wrtlog('   start_date '|| i.project_start_date);
		lr_project_in.completion_date := i.project_end_date;
        wrtlog('   completion_date '|| i.project_end_date);
		wrtlog(' track 3.2');
        lr_project_in.attribute_category := 'Global Data Elements';
		wrtlog('   attribute_category ');
        lr_project_in.attribute4 := i.attribute4; --- for storing legacy org_ proj_num
        wrtlog('   i.attribute4 '|| i.attribute4);
		--lr_project_in.attribute3 := i.legacy_project_number; --- for storing legacy org_ proj_num
        wrtlog('date normal' || i.project_start_date);
        wrtlog('Canonci-' ||
               fnd_date.date_to_canonical(i.project_start_date));
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
            From hz_cust_acct_sites_all acct_site, hz_cust_site_uses_all su ,apps.hz_party_sites hp
           Where acct_site.cust_acct_site_id = su.cust_acct_site_id
             And nvl(acct_site.status, 'A') = 'A'
             And acct_site.cust_account_id = ln_customer_id --X_Bill_To_Customer_Id
             And nvl(su.status, 'A') = 'A'
             And su.primary_flag = 'Y'
			 And acct_site.party_site_id = hp.party_site_id
             And su.site_use_code = 'BILL_TO'
             And su.org_id = lg_organization_id
             And UPPER(hp.PARTY_SITE_NUMBER) = UPPER(TRIM(i.customer_bill_to));

          Select acct_site.cust_acct_site_id
            into ln_customer_ship_to
            From hz_cust_acct_sites_all acct_site, hz_cust_site_uses_all su ,apps.hz_party_sites hp
           Where acct_site.cust_acct_site_id = su.cust_acct_site_id
             And nvl(acct_site.status, 'A') = 'A'
             And acct_site.cust_account_id = ln_customer_id --X_Bill_To_Customer_Id
             And nvl(su.status, 'A') = 'A'
             And su.primary_flag = 'Y'
			 And acct_site.party_site_id = hp.party_site_id
             And su.site_use_code = 'SHIP_TO'
             And su.org_id = lg_organization_id
             And UPPER(hp.PARTY_SITE_NUMBER) = UPPER(TRIM(i.customer_ship_to));

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
    /*    ln_person_id1:= 0;
        ln_partner_id:= 0;
        ln_person_id2:= 0;
        ln_person_id3:= 0;
     */
         BEGIN
            if i.project_manager is not null then
               select person_id
                 into ln_person_id1
                 from per_all_people_f
                where full_name = i.project_manager
                  and sysdate between effective_start_date AND effective_end_date
                  and current_emp_or_apl_flag = 'Y';
                  DBMS_OUTPUT.PUT_LINE('project_manager : '||','||ln_person_id1);
                  wrtlog(' project_manager :-> ' || ln_person_id1);
            end if;
         EXCEPTION
            When Others Then
               wrtlog('Error Occured while checking person_id and project_manager :-> ' || Sqlerrm);
               DBMS_OUTPUT.PUT_LINE('stuck in exception : ');
               DBMS_OUTPUT.PUT_LINE('Error Occured while checking person_id and project_manager :-> ' ||Sqlerrm);
         end;
         begin
             if i.project_partner is not null then
                   select person_id
                     into ln_partner_id
                     from per_all_people_f
                    where full_name = i.project_partner
                      and sysdate between effective_start_date and
                          effective_end_date
                      and current_emp_or_apl_flag = 'Y';
                 DBMS_OUTPUT.PUT_LINE('project_partner : '||','||ln_partner_id);
                 wrtlog(' project_partner :-> ' || ln_partner_id);
             end if;
         EXCEPTION
            When Others Then
               wrtlog('Error Occured while checking person_id and project_partner :-> ' || Sqlerrm);
               DBMS_OUTPUT.PUT_LINE('stuck in exception : ');
               DBMS_OUTPUT.PUT_LINE('Error Occured while checking person_id and project_partner :-> ' ||Sqlerrm);
               wrtlog('project_partner changed to Mendoza, Geraldine');

              select person_id --------- V4 operating manager logic change
               into ln_partner_id
               from per_all_people_f
              where full_name = 'Mendoza, Geraldine'
                and sysdate between effective_start_date and
                    effective_end_date
                and current_emp_or_apl_flag = 'Y';
         end;
         begin
             if     i.project_op_manager is not null then
                   select person_id --------- V4 operating manager logic change
                     into ln_person_id2
                     from per_all_people_f
                    where full_name = i.project_op_manager
                      and sysdate between effective_start_date and
                          effective_end_date
                      and current_emp_or_apl_flag = 'Y';
                  DBMS_OUTPUT.PUT_LINE('project_op_manager : '||','||ln_person_id2);
                  wrtlog(' project_partner :-> ' || ln_person_id2);
             end if;
         EXCEPTION
            When Others Then
               wrtlog('Error Occured while checking person_id and project_op_manager :-> ' || Sqlerrm);
               DBMS_OUTPUT.PUT_LINE('stuck in exception : ');
               DBMS_OUTPUT.PUT_LINE('Error Occured while checking person_id and project_op_manager :-> ' ||Sqlerrm);
               wrtlog('project_op_manager changed to Mendoza, Geraldine');

              select person_id --------- V4 operating manager logic change
               into ln_person_id2
               from per_all_people_f
              where full_name = 'Mendoza, Geraldine'
                and sysdate between effective_start_date and
                    effective_end_date
                and current_emp_or_apl_flag = 'Y';

         end;
         BEGIN
             if i.opportunity_owner is not null then
                   select person_id --------- V4 opportunity owner logic change
                     into ln_person_id3
                     from per_all_people_f
                    where full_name = i.opportunity_owner
                      and sysdate between effective_start_date and
                          effective_end_date
                      and current_emp_or_apl_flag = 'Y';
                   DBMS_OUTPUT.PUT_LINE('opportunity_owner : '||','||i.opportunity_owner||','||ln_person_id3);
                   wrtlog(' opportunity_owner :-> ' || ln_person_id3);
            end if;
         EXCEPTION
            When Others Then
               wrtlog('Error Occured while checking person_id and opportunity_owner :-> ' || Sqlerrm);
               DBMS_OUTPUT.PUT_LINE('stuck in exception : ');
               DBMS_OUTPUT.PUT_LINE('Error Occured while checking person_id and opportunity_owner :-> ' ||Sqlerrm);
               wrtlog('opportunity_owner changed to Mendoza, Geraldine');

              select person_id --------- V4 operating manager logic change
               into ln_person_id3
               from per_all_people_f
              where full_name = 'Mendoza, Geraldine'
                and sysdate between effective_start_date and
                    effective_end_date
                and current_emp_or_apl_flag = 'Y';
         end;
          --  ln_role_type := 'PROJECT MANAGER';
        EXCEPTION
          When Others Then
            wrtlog('Error Occured while checking person_id and manager details :-> ' ||
                   Sqlerrm);
            DBMS_OUTPUT.PUT_LINE('stuck in exception : ');
            DBMS_OUTPUT.PUT_LINE('Error Occured while checking person_id and manager details :-> ' ||
                   Sqlerrm);
        end;
        wrtlog('   Track 5');
        ln_cnt := 0;
        For k in cur_project_role LOOP
        ln_cnt := ln_cnt + 1;
          IF k.meaning = 'Project Manager' and ln_person_id1 is not null THEN
            lt_key_members(ln_cnt).project_role_type := k.project_role_type;
            lt_key_members(ln_cnt).person_id := ln_person_id1; --------- V4 operating manager logic change
          DBMS_OUTPUT.PUT_LINE('k_project_role_type : '||','||k.project_role_type);
          DBMS_OUTPUT.PUT_LINE('ln_person_id1 : '||','||ln_person_id1);
          wrtlog(' k_project_role_type ln_person_id1 :-> ' || k.project_role_type || ln_person_id1);
          END IF;
          IF k.meaning = 'Project Partner/Director' and ln_partner_id is not null THEN
            lt_key_members(ln_cnt).project_role_type := k.project_role_type;
            lt_key_members(ln_cnt).person_id := ln_partner_id;
          DBMS_OUTPUT.PUT_LINE('k_project_role_type : '||','||k.project_role_type);
          DBMS_OUTPUT.PUT_LINE('ln_partner_id : '||','||ln_partner_id);
          wrtlog(' k_project_role_type ln_partner_id :-> ' || k.project_role_type || ln_partner_id);
          END IF;
          IF k.meaning = 'Project Operations Manager' and ln_person_id2 is not null THEN
            lt_key_members(ln_cnt).project_role_type := k.project_role_type;
            lt_key_members(ln_cnt).person_id := ln_person_id2; --------- V4 operating manager logic change
          DBMS_OUTPUT.PUT_LINE('k_project_role_type : '||','||k.project_role_type);
          DBMS_OUTPUT.PUT_LINE('ln_person_id2 : '||','||ln_person_id2);
          wrtlog(' k_project_role_type ln_person_id2:-> ' || k.project_role_type || ln_person_id2);
         END IF;
          IF k.meaning = 'Opportunity Owner' and ln_person_id3 is not null THEN
            lt_key_members(ln_cnt).project_role_type := k.project_role_type;
            lt_key_members(ln_cnt).person_id := ln_person_id3; --------- V4 operating manager logic change
          DBMS_OUTPUT.PUT_LINE('k_project_role_type : '||','||k.project_role_type);
          DBMS_OUTPUT.PUT_LINE('ln_person_id3 : '||','||ln_person_id3);
          wrtlog(' k_project_role_type :-> ' || k.project_role_type || ln_person_id3);
          DBMS_OUTPUT.PUT_LINE('i.opportunity_owner ln_person_id3: '||','||i.opportunity_owner);
          END IF;

         -- wrtlog(' k_project_role_type :-> ' || k.project_role_type || ln_person_id3);
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
		   IF i.project_category is not null then
		    lt_class_categories(3).class_category := 'TT Project Category';
            lt_class_categories(3).class_code := i.project_category;
			ELSE
              wrtlog('Classification -Project Category is null');
		   END IF;
		   IF i.location is not null THEN
              Select class_category
                into ln_class_category2
                From pa_class_codes
               Where class_category = ('TT Location')
                 And upper(class_code) = upper(i.location)
                 And end_date_active Is Null;
              lt_class_categories(4).class_category := 'TT Location';
              lt_class_categories(4).class_code := i.location;
            ELSE
              wrtlog('Classification -Location is null');
            END IF;
          END IF;
        Exception
          When others Then
            lt_class_categories(5).class_category := null;
            lt_class_categories(5).class_code := null;
		--	lt_class_categories(5).code_percentage := NULL;
        End;
        lc_chargeable_flag        := NULL;
        ln_oracle_owning_bu_sl_id := NULL;
        ln_cnt                    := NVL(ln_cnt1, 0) + 1;
        lc_msg_data               := NULL;
        lc_return_status          := NULL;
        ln_msg_count              := NULL;
        ln_count := 0;
        --l_date_mask := TO_DATE(SYSDATE,'RRRR/MM/DD HH24:MI:SS');
        For j in cur_tasks_data(i.record_identifier) /*, i.Project_name)*/ -- , gc_validation_flag
         loop
		  ln_count := ln_count + 1;
          --l_date_mask := TO_CHAR(TO_DATE(j.attribute7,'RRRR/MM/DD'));
		  lr_task_in_rec := NULL;
          lr_task_in_rec.pm_task_reference    := trim(j.task_number); --'Analytics Labor'; --j.task_number; --task_number;
		  wrtlog(' j.pm_task_reference :-> ' || j.task_number);
          lr_task_in_rec.task_name            := trim(j.task_name);
		  wrtlog(' j.task_name :-> ' || j.task_name);
          lr_task_in_rec.pa_task_number       := trim(j.task_number); ----task_number;
          wrtlog(' j.task_number :-> ' || j.task_number);
		  lr_task_in_rec.task_description     := trim(j.description);
		  wrtlog(' j.description :-> ' || j.description);
		  lr_task_in_rec.task_start_date      := j.start_date;
		  wrtlog(' j.start_date :-> ' || j.start_date);
          lr_task_in_rec.task_completion_date := j.Completion_date;
          wrtlog(' j.Completion_date :-> ' || j.Completion_date);
	      lr_task_in_rec.PM_PARENT_TASK_REFERENCE := null;

        wrtlog(' chargeable_flag :-> ' || 'Y');
         lr_task_in_rec.chargeable_flag := 'Y';
         wrtlog(' chargeable_flag :-> ' || 'Y');
         lr_task_in_rec.billable_flag := 'Y';

         lr_task_in_rec.carrying_out_organization_id := ln_carryingout_organization_id;
		  wrtlog(' ln_carryingout_organization_id :-> ' || ln_carryingout_organization_id);
		  lr_task_in_rec.service_type_code    := trim(j.service_type_code); -- '24-MAR-2017' Service type for tasks
		  wrtlog(' j.service_type_code :-> ' || j.service_type_code);

	--	   lr_task_in_rec.actual_start_date := j.start_date;
	--	  wrtlog(' j.actual_start_date :-> ' || j.start_date);
    --      lr_task_in_rec.actual_finish_date := j.Completion_date;
    --      wrtlog(' j.actual_finish_date :-> ' || j.Completion_date);


          -- lr_task_in_rec.carrying_out_organization_id := lg_organization_id;
          -- lr_task_in_rec.tasks_dff  := 'N';

          lr_task_in_rec.tasks_dff  := 'Y';
		  wrtlog(' j.tasks_dff :-> ');
          lr_task_in_rec.attribute_category := null;
		  wrtlog(' j.attribute_category :-> ');
          lr_task_in_rec.attribute1 := trim(j.attribute1);
		  wrtlog(' j.attribute1 :-> ' || j.attribute1);
          lr_task_in_rec.attribute2 := trim(j.attribute2);
		  wrtlog(' j.attribute2 :-> ' || j.attribute2);
          lr_task_in_rec.attribute3 := trim(j.attribute3);
		  wrtlog(' j.attribute3 :-> ' || j.attribute3);
          lr_task_in_rec.attribute6 := trim(j.attribute6);
		  wrtlog(' j.attribute6 :-> ' || j.attribute6);
          lr_task_in_rec.attribute7 := trim(j.attribute7);  --fnd_date.canonical_to_date(j.attribute7);    --to_char(CAST(a.ATTRIBUTE7 AS DATE),'DD-MON-RRRR'); -- trim(to_char(to_date(j.attribute7,'DD-MON-YYYY')))
		  wrtlog(' j.attribute7 :-> ' || j.attribute7);
          lr_task_in_rec.attribute8 := trim(j.attribute8);
		  wrtlog(' j.attribute8 :-> ' || j.attribute8);

		  lt_task_in(ln_count) := lr_task_in_rec;

        END LOOP;
        --   apps.fnd_file.put_line(apps.fnd_file.log,
        --                         ' Total Number Of Tasks :-> ' || ln_cnt1);
        --RETURN;
        wrtlog('   Track 8');

		ttec_create_project('1.0'
		                   ,FND_API.G_FALSE
						   ,FND_API.G_FALSE
						   ,ln_msg_count
						   ,lc_msg_data
						   ,lc_return_status
						   ,lc_workflow_status
						   ,ln_product_code
						   ,lr_project_in
						   ,lr_project_out
						   ,lt_key_members
						   ,lt_task_in
						   ,lt_tasks_out
						   ,lt_customer_tbl
						   ,lt_class_categories
						   ,i.status_flag
						   ,i.record_identifier
						  );

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
        FROM tlt_rpa_projects_conv_stg PAS
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
                             'Error Occured In CREATE_PROJECTS_TASKS :-> ' ||
                             SQLERRM);
  end create_projects_tasks;



  -- Function to create the sequence for project identifier
  FUNCTION pa_pt_header_seq_fun (p_rec_type VARCHAR2)
  RETURN NUMBER
  IS
  l_rec_type NUMBER;
  BEGIN
  IF p_rec_type IS NOT NULL
  THEN
  SELECT xxttec_pa_pt_imp_seq.NEXTVAL into l_rec_type from dual;
  ELSE
  SELECT xxttec_pa_pt_imp_seq.CURRVAL into l_rec_type from dual;
  END IF;
  RETURN l_rec_type;
  END pa_pt_header_seq_fun;
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
      --
      validate_records(gc_newrecord_flag);
      wrtlog('validation ends.........');
    ELSIF p_validate_data_flag = 'V' THEN
      wrtlog('Validating the Error records from staging table');
     --  validate_records(gc_error_flag);
      select_error_records;
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
END TTEC_RPA_PROJECTS_TASKS_PKG;
/
show errors;
/