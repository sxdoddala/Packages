create or replace PACKAGE BODY      TTEC_LOCATION_UPD_PKG
AS

 /************************************************************************************
        Program Name: TTEC_LOCATION_UPD_PKG 

        Description:   

        Developed by : 
        Date         :  

       Modification Log
       Name                  Version #    Date            Description
       -----                 --------     -----           -------------
    RXNETHI-ARGANO            1.0      17-May-2023      R12.2 Upgrade Remediation
    ****************************************************************************************/
  /*
   REM Description: This package is to update Location in Assignment/Costing/POI form
   REM Program:     TTEC Location Change Mass Update
   REM Parameter:   Business Group Id
   REM ===========================================================================SOFT==========================================
   REM Task       History                 Performed by             REFERENCE                      VENDOR
   REM Created    04-Sep-2018             Manish Chauhan                                          Initial Creation
   REM Modified
   REM =====================================================================================================================
   */
   /*************************************************************************************************************
    -- PROCEDURE print_output
    -- Author: Manish Chauhan
    -- Date:  19-DEC-2018
    -- Parameters: iv_data --> Text to be printed out in the output file.
    -- Description: This procedure standardizes concurrent program output calls.
    **************************************************************************************************************/
    PROCEDURE print_output (iv_data in varchar2)
    IS
    begin
      Fnd_File.put_line (Fnd_File.output, iv_data);

    end;   -- print_line

    /*************************************************************************************************************
    -- PROCEDURE print_log
    -- Author: Manish Chauhan
    -- Date:  19-DEC-2018
    -- Parameters: iv_data --> Text to be printed out in the log file.
    -- Description: This procedure standardizes concurrent program output calls.
    **************************************************************************************************************/
    PROCEDURE print_log (iv_data in varchar2)
    IS
    begin
      Fnd_File.put_line (Fnd_File.log, iv_data);

    end;   -- print_line
    /*************************************************************************************************************
    -- PROCEDURE Main
    -- Author: Manish Chauhan
    -- Date:  10-JAN-2018
    -- Parameters: Business_group_id
    -- Description: This is Main procedure.
    **************************************************************************************************************/
  PROCEDURE Main(errbuf OUT VARCHAR2,retcode OUT NUMBER,p_business_group_id IN NUMBER)
    AS
    v_employee_number                  Number;
    l_assignment_id                    Number;
    l_location_id                      Number;
    l_update_mode                      VARCHAR2 (100);
    ln_special_ceiling_step_id         PER_ALL_ASSIGNMENTS_F.SPECIAL_CEILING_STEP_ID%TYPE;
    lc_group_name                      VARCHAR2(30);
    ld_effective_start_date            PER_ALL_ASSIGNMENTS_F.EFFECTIVE_START_DATE%TYPE;
    ld_effective_end_date              PER_ALL_ASSIGNMENTS_F.EFFECTIVE_END_DATE%TYPE;
    lb_org_now_no_manager_warning      BOOLEAN;
    lb_other_manager_warning           BOOLEAN;
    lb_spp_delete_warning              BOOLEAN;
    lc_entries_changed_warning         VARCHAR2(30);
    lb_tax_district_changed_warn       BOOLEAN;
    ln_people_group_id                 PER_ALL_ASSIGNMENTS_F.people_group_id%TYPE;   --Number :=306;  --
    ln_object_number                   Number;
    l_object_version_no                Number;
    v_location_code                    VARCHAR2 (100);
   -- l_new_loc_code                     VARCHAR2 (100);
    l_new_loc_id                       Number;
    l_business_group_id                Number;
   -- l_old_location                     VARCHAR2 (200);
    l_new_location                     VARCHAR2 (200);
    l_total_count            Number:= 0;
    l_error_count            Number:= 0;
    l_updated_count          Number:= 0;
    l_employee_number        apps.per_all_people_f.employee_number%TYPE;
   -- l_old_location          hr_locations_all.location_code%TYPE;
    l_effective_start_date   date;
    l_old_location           hr_locations_all.location_code%TYPE;
    l_new_requested_loc           hr_locations_all.location_code%TYPE;
    tab                 VARCHAR2(10) DEFAULT '    ';
    v_emp_no            Number;
    v_location          VARCHAR2(100);
    v_date              Date;
    v_status            VARCHAR2(10);
    v_old_location      VARCHAR2(100);
    l_assignment_flag                   varchar2(10);
    l_costing_flag                      varchar2(10);
    l_expense_flag                      varchar2(10);
    ln_employee_number                   apps.per_all_people_f.employee_number%TYPE;  --Y
    ld_employee_number                   apps.per_all_people_f.employee_number%TYPE;
    l_cost_segment1                     gl_code_combinations.segment1%TYPE;
      l_cost_segment2                     gl_code_combinations.segment2%TYPE;
      l_cost_segment3                     gl_code_combinations.segment3%TYPE;
    l_new_upd_loc                      VARCHAR2(100);
    l_new_attribute2                   gl_code_combinations.segment2%TYPE;
    l_old_segment2                     gl_code_combinations.segment2%TYPE;
    l_new_segment1                     gl_code_combinations.segment2%TYPE;
    l_cc_segment1                      gl_code_combinations.segment1%type;
    l_cc_segment2                      gl_code_combinations.segment2%type;
    l_cc_segment3                      gl_code_combinations.segment3%type;
    l_cc_segment4                      gl_code_combinations.segment4%type;
    l_cc_segment5                      gl_code_combinations.segment5%type;
    l_cc_segment6                      gl_code_combinations.segment6%type;
    l_old_expense_acc                  gl_code_combinations_kfv.concatenated_segments%type;
    l_new_expense_acc                  gl_code_combinations_kfv.concatenated_segments%type;
    l_ccid_ovn                         number;
   -- l_concatenated_segments            hr_soft_coding_keyflex.concatenated_segments%type;
    l_soft_coding_keyflex_id           hr_soft_coding_keyflex.soft_coding_keyflex_id%type;
    l_err_Status                        varchar2(10);
    l_err_msg                           varchar2(280);
    l_p_ccid                            varchar2(100);
    l_concatenated_segments              hr_soft_coding_keyflex.concatenated_segments%type;
   -- l_soft_coding_keyflex_id             hr_soft_coding_keyflex.soft_coding_keyflex_id%type;
    l_comment_id                        per_all_assignments_f.comment_id%type;
    l_no_managers_warning               boolean;
    l_other_manager_warning             boolean;
    l_cagr_grade_def_id                 number;
    l_cagr_concatenated_segments        varchar2(280);
    l_hourly_salaried_warning           boolean;
    l_gsp_post_process_warning          varchar2(280); --
    lc_effective_start_date             per_all_assignments_f.effective_start_date%type;
    lc_effective_end_date                per_all_assignments_f.effective_end_date%type;
   -- v_emp_no                           number;
    v_new_loc                          varchar2(100);
    v_date                             date;
    v_status                           varchar2(10);
    v_old_loc                         varchar2(100);
    v_old_cost                         varchar2(100);
    v_new_cost                         varchar2(100);
    v_old_exp                          varchar2(100);
    v_new_exp                          varchar2(100);
     l_cost_allocation_id              number;
    l_cost_OVN                         number;
    l_proportion                       number;
    l_cost_allocation_keyflex_id       pay_cost_allocation_keyflex.cost_allocation_keyflex_id%type;
    l_cost_obj_version_number          number;
    l_cost_effective_start_date        date;
    l_cost_effective_end_date          date;
    l_combination_name                 varchar2(100);
    l_max_effective_date               date;
    l_old_costing                      varchar2(240);
    l_new_costing                      varchar2(240);
    l_old_attribute2                   number;
    l_ccid                            varchar2(240);
    Assignment_flag                     varchar2(10);
    Costing_flag                       varchar2(10);
    Expense_Flag                        varchar2(10);



     Assignment_Form     Exception;
     Costing_Form        Exception;
     Expense_Form        Exception;
     Emp_Termed          Exception;
     Future_Date         Exception;

    --cursor to get data from custom table
     CURSOR C1
     IS
     SELECT *
     FROM TTEC_CUST_LOCATION_UPD;

    -- cursor to get assignment id and current location
     cursor C2  ( C_EMP_NO in number,
                  C_BG_ID  in number,
                  C_EFFECTIVE_DATE in date )
     IS
         select  papf.employee_number,
             paaf.assignment_id,paaf.people_group_id,
             paaf.default_code_comb_id,
             hla.location_code,
            -- hla.attribute2,
             paaf.object_version_number,
             paaf.effective_start_date,
             gcc.concatenated_segments  old_expense_acc
       from
             per_all_people_f papf,
             per_all_assignments_f paaf,
             hr_locations_all hla,
             apps.gl_code_combinations_kfv gcc
      where 1=1
            and papf.employee_number=C_EMP_NO
            and papf.business_group_id=C_BG_ID
            and C_EFFECTIVE_DATE between papf.effective_start_date and papf.effective_end_date   --C_EFFECTIVE_DATE
            and C_EFFECTIVE_DATE between paaf.effective_start_date and paaf.effective_end_date    --C_EFFECTIVE_DATE
            and papf.person_id=paaf.person_id
            and paaf.location_id= hla.location_id(+)
            and paaf.default_code_comb_id = gcc.code_combination_id;

     --cursor to get costing details
     cursor C3 (C_Assignment in number)
     IS
     select pcaf.cost_allocation_id ,
            pcaf.cost_allocation_keyflex_id ,
            pcaf.object_version_number ,
            pcaf.proportion,
            pcak.segment1,
            pcak.segment2,
            pcak.segment3
      from
           /*
		   START R12.2 Upgrade Remediation
		   code cmmented by RXNETHI-ARGANO,17/05/23
		   hr.pay_cost_allocations_f pcaf,
           hr.pay_cost_allocation_keyflex pcak
           */
		   --code added by RXNETHI-ARGANO,17/05/23
		   apps.pay_cost_allocations_f pcaf,
           apps.pay_cost_allocation_keyflex pcak
		   --END R12.2 Upgrade Remediation
	 where  1=1
            and pcaf.assignment_id = C_Assignment
            and pcaf.cost_allocation_keyflex_id = pcak.cost_allocation_keyflex_id
            and l_effective_start_date between pcaf.effective_start_date and pcaf.effective_end_date;

  BEGIN

       --deleting data from custom table on every run
       DELETE FROM TTEC_CUST_LOCATION_UPD;
       COMMIT;

        BEGIN
               --inserting data in custom table from external table
                insert into apps.ttec_cust_location_upd
                                       ( Employee_Number,
                                         Effective_Start_date,
                                         Requested_Location
                                         )
                select    Employee_Number,
                          Effective_Start_date,
                          Location
                from      APPS.TTEC_EXT_LOCATION_UPD;

                commit;
                exception
                when others then
                  print_log('error 10: while inserting records into custom table . error message - '
                                          ||substr(sqlerrm,1,100));

        END ;

     -- writing to log output
      print_log('TTEC Location Mass Update Program Startes' );
      print_log('===========================================================' );
      -- Writing to Output
      print_output( 'Status   :');
      print_output( '=========================================================' );
      print_output('Employee Number|Old Location|New Location|Old Costing|New Costing|Old Expense Acc|New Expense Acc|Status');

         --cursor for loop
        FOR REC IN C1
        LOOP
                      print_log('--------------------------------------------------');
                      print_log('#Emp: '|| REC.Employee_number);

                    -- print_log('Inside C1');

                     l_new_loc_id     := null;
                   --  l_new_org_id       := null;
                     l_assignment_flag  := 'N';
                     l_costing_flag     := 'N';
                     l_expense_flag     := 'N';

                      l_employee_number       :=REC.Employee_number;
                      l_new_location          :=REC.Requested_location;
                      l_effective_start_date  :=REC.effective_Start_date;
                      l_business_group_id     :=p_business_group_id;

            --cursor2: to get assignment id/old location/old costing/old expense acc
            for REC1 in C2 (C_EMP_NO         => l_employee_number,
                            C_BG_ID          => l_business_group_id,
                            C_EFFECTIVE_DATE => l_effective_start_date)
            loop

               -- print_log('Inside C2');

                l_assignment_id      := REC1.assignment_id;
                l_old_location       := REC1.Location_code ;
                --l_old_attribute2     := REC1.attribute2;
                l_object_version_no  := REC1.object_version_number;
                l_old_expense_acc    := REC1.old_expense_acc;
                ld_employee_number   := null;
                ln_employee_number   := null;

                 --updating old details in custom table
                    begin
                        update APPS.TTEC_CUST_LOCATION_UPD
                           set Old_location=l_old_location,
                               old_expense_acc=l_old_expense_acc
                         where Employee_Number=l_employee_number;
                         commit;
                    end;

                  ---checking: Active/Inactive employee
                  Begin
                       --  print_log('Inside Active/Inactive');
                      select  papf.employee_number
                        into  ln_employee_number
                        from  per_all_people_f papf,
                              per_all_assignments_f paaf ,
                              per_periods_of_service pps
                       where  1=1
                              and papf.person_id=paaf.person_id
                              and papf.employee_number = l_employee_number --REC.Employee_number
                              and papf.current_employee_flag='Y'
                              and papf.person_id = pps.person_id
                              and pps.actual_termination_date IS NULL
                              and l_effective_start_date between papf.effective_start_date and papf.effective_end_date
                              and l_effective_start_date between paaf.effective_start_date and paaf.effective_end_date;

                        exception
                        when no_data_found then
                        print_log('Employee is Terminated');
                   end;

                    ld_employee_number := NVL(ln_employee_number,NULL);

                Begin
                    --Raise exception if emp is terminated
                     if ld_employee_number IS NULL
                     then
                        -- print_log('Raise exception if emp is terminated');
                         Raise Emp_Termed;
                     end if;

                          -- checking If any future dated changes in assignment
                begin
                    select max(effective_start_date)
                    into l_max_effective_date
                    from per_all_assignments_f
                    where 1=1
                    and assignment_id=l_assignment_id;

                        --Raise exception if any future date changes
                        If ( l_max_effective_date > l_effective_start_date )
                        then
                            Raise Future_Date;
                        end if;



                   if C2%notfound
                   then
                   print_log('Unable to find Assignment id and old employee details for #Emp: '||l_employee_number);
                   end if;


                            ---Fetching New location details
                           Begin
                                    Select location_code,location_id,attribute2
                                    into   l_new_requested_loc,l_new_loc_id,l_new_attribute2
                                    From   hr_locations_all
                                    where  1=1
                                    and   location_code=l_new_location
                                    and   inactive_date IS NULL;
                             EXCEPTION
                             WHEN OTHERS THEN
                             print_log('ERROR: UNABLE TO FIND NEW LOCATION DETAIL'||SUBSTR(SQLERRM,1,100));
                          END;


                       ln_people_group_id := NVL(REC1.people_group_id,NULL);

                         Begin

                       -- API: Update Employee Location
                           -- ---------------------------------------------
                         hr_assignment_api.update_emp_asg_criteria
                                                      ( -- Input data elements
                                                          -- ------------------------------
                                                           p_effective_date            => l_effective_start_date,
                                                           p_datetrack_update_mode     => 'UPDATE',
                                                           p_assignment_id             => l_assignment_id,
                                                           p_location_id               => l_new_loc_id,
                                                           p_validate                  => FALSE,
                                                           p_called_from_mass_update   => FALSE,
                                                           p_object_version_number     => l_object_version_no,
                                                      -- Output data elements
                                                         -- -------------------------------
                                                            p_people_group_id            => ln_people_group_id,
                                                          --  p_object_version_number      => ln_object_number,
                                                            p_special_ceiling_step_id    => ln_special_ceiling_step_id,
                                                            p_group_name                 => lc_group_name,
                                                            p_effective_start_date       => ld_effective_start_date,
                                                             p_effective_end_date        => ld_effective_end_date,
                                                            p_org_now_no_manager_warning => lb_org_now_no_manager_warning,
                                                            p_other_manager_warning      => lb_other_manager_warning,
                                                            p_spp_delete_warning         => lb_spp_delete_warning,
                                                            p_entries_changed_warning    => lc_entries_changed_warning,
                                                            p_tax_district_changed_warning     => lb_tax_district_changed_warn
                                                       );
                                                      l_assignment_flag := 'Y';

                                                       begin
                                                          select location_code
                                                            into l_new_upd_loc
                                                          from   per_all_assignments_f paaf,
                                                                 hr_locations_all hal
                                                           where 1=1
                                                             and paaf.assignment_id= l_assignment_id
                                                             and paaf.location_id = hal.location_id
                                                             and l_effective_start_date between paaf.effective_start_date
                                                                                        and effective_end_date;
                                                        end;

                                                            print_log('New Location updated in Assignment form');
                                                            print_log('old Location: '|| l_old_Location);
                                                            print_log('New Location: '|| l_new_upd_loc);

                                          EXCEPTION
                                          WHEN OTHERS THEN
                                           print_log('API error: while updating Location in Assignment form -'
                                                             ||substr(sqlerrm,1,1000));

                                           l_assignment_flag := 'N';

                                  End;

                Begin

                     If ( l_assignment_flag != 'Y' )
                     then
                         raise Assignment_form;
                     else
                            -- print_log('Proceeding for Costing Update');

                       for REC2 IN C3 (C_Assignment => l_assignment_id)
                       loop

                                 l_old_costing := REC2.segment1||'.'||REC2.segment2||'.'||REC2.segment3;

                                -- l_old_segment2 := REC2.segment2;

                                  --checking: if dept present in costing form
                       if REC2.segment1 is not null
                       then
                             l_new_segment1  := l_new_attribute2;
                             l_cost_obj_version_number := REC2.object_version_number;

                        -- API: to update costing details
                         l_cost_allocation_keyflex_id := NULL;
                        begin
                            pay_cost_allocation_api.update_cost_allocation
                                 ( p_validate                    =>  false,
                                   p_effective_date              =>  l_effective_start_date,
                                   p_datetrack_update_mode       =>  'UPDATE',
                                   p_cost_allocation_id          =>  REC2.cost_allocation_id,
                                   p_proportion                  =>  REC2.proportion,
                                   p_segment1                    =>  l_new_segment1,
                                   --p_segment2                    =>  REC2.segment2,
                                  -- p_segment3                    =>  l_new_segment2,
                                 -- In / Out
                                   p_cost_allocation_keyflex_id  =>  l_cost_allocation_keyflex_id,
                                   p_object_version_number       =>  l_cost_obj_version_number,
                                 -- Out
                                   p_effective_start_date        =>  l_cost_effective_start_date,
                                   p_effective_end_date          =>  l_cost_effective_end_date,
                                   p_combination_name            =>  l_combination_name
                                 );

                                   l_costing_flag := 'Y';



                                        begin
                                           Select pcak.segment1,pcak.segment2, pcak.segment3
                                           into l_cost_segment1,l_cost_segment2,l_cost_segment3
                                           --From HR.PAY_COST_ALLOCATION_KEYFLEX pcak   --code commented by RXNETHI-ARGANO,17/05/23
                                           From APPS.PAY_COST_ALLOCATION_KEYFLEX pcak   --code added by RXNETHI-ARGANO,17/05/23
                                           where  1=1
                                           and pcak.cost_allocation_keyflex_id = l_cost_allocation_keyflex_id;

                                          l_new_costing := l_cost_segment1||'.'||l_cost_segment2||'.'||l_cost_segment3;

                                        end;

                                          print_log('New Location updated in costing form');
                                          print_log('Old Costing: '|| l_old_costing);
                                          print_log('New Costing: '|| l_new_costing);


                                     exception
                                         when others then
                                         Rollback;
                                            print_log('api error: while updating location in costing form - '||substr(sqlerrm,1,1000));

                                            l_costing_flag := 'N';

                                  end;
                              else
                                            print_log('No location code present in costing form- No Need to Update ');
                                            l_costing_flag := 'Y';
                          end if;
                      end loop;

                Begin
                         if (l_costing_flag !='Y' )
                         then
                             raise Costing_Form;
                          else
                               ----------------for Purchase Order Information Update----------

            --   print_log('Proceeding for POI Update');

                   Begin
                       begin
                            select gcc.concatenated_segments,gcc.segment1,gcc.segment2,gcc.segment3,gcc.segment4,gcc.segment5,gcc.segment6,
                                 paaf.object_version_number
                            into l_old_expense_acc,l_cc_segment1,l_cc_segment2,l_cc_segment3,l_cc_segment4,l_cc_segment5,l_cc_segment6,
                                 l_ccid_ovn
                            from per_all_assignments_f paaf,
                                 apps.gl_code_combinations_kfv  gcc
                            where 1=1
                            and paaf.assignment_id=l_assignment_id
                            and paaf.default_code_comb_id = gcc.code_combination_id
                            and l_effective_start_date between paaf.effective_start_date and paaf.effective_end_date;

                           exception
                           when others then
                                 print_log('error: while finding POI details '||SQLERRM);
                       end;


                    --checking: if existing expense account is null
                    if l_old_expense_acc is not null
                    then
                        l_cc_Segment1 := l_new_attribute2;

                       --calling package: TTEC_GL_CCID_CREATION_PKG'
                       TTEC_GL_CCID_CREATION_PKG.ttec_ccid_cre
                        (l_err_Status,l_err_msg,l_p_ccid,l_cc_segment1,l_cc_segment2,l_cc_segment3,l_cc_segment4,
                        l_cc_segment5,l_cc_segment6);


                       l_ccid := l_p_ccid;
                       l_soft_coding_keyflex_id := NULL;

                   if l_ccid is not null
                   then
                         Begin
                            Hr_Assignment_Api.update_emp_asg
                                (
                            p_validate                      => False,
                            p_effective_date                => l_effective_start_date,
                            p_datetrack_update_mode         => 'CORRECTION',
                           -- p_change_reason                 => l_reason,
                            p_assignment_id                 => l_assignment_id,
                            p_object_version_number         => l_ccid_ovn,
                            P_default_code_comb_id          => l_ccid,
                            --output
                            p_concatenated_segments         => l_concatenated_segments,
                            p_soft_coding_keyflex_id        => l_soft_coding_keyflex_id,
                            p_comment_id                    => l_comment_id,
                            p_effective_start_date          => lc_effective_start_date,
                            p_effective_end_date            => lc_effective_end_date,
                            p_no_managers_warning           => l_no_managers_warning,
                            p_other_manager_warning         => l_other_manager_warning,
                            p_cagr_grade_def_id             => l_cagr_grade_def_id,
                            p_cagr_concatenated_segments    => l_cagr_concatenated_segments,
                            p_hourly_salaried_warning       => l_hourly_salaried_warning,
                            p_gsp_post_process_warning      => l_gsp_post_process_warning
                            );
                           --commit;
                            l_expense_flag := 'Y';

                              begin
                                 select gcc.concatenated_segments  --gcc.segment1,gcc.segment2,gcc.segment3,gcc.segment4,gcc.segment5,gcc.segment6
                                 into l_new_expense_acc  --,l_upd_segment1,l_upd_segment2,l_upd_segment3,l_upd_segment4,l_upd_segment5,l_upd_segment6
                                 from apps.gl_code_combinations_kfv  gcc
                                 where 1=1
                                 and  gcc.code_combination_id = l_ccid ;
                               end;

                                 print_log('New Location Updated in POI form ');
                                 print_log('Old Expense Acc: '|| l_old_expense_acc);
                                 print_log('New Expense Acc: '|| l_new_expense_acc);



                                 --l_new_expense_acc:= l_upd_segment1||'.'||l_upd_segment2||'.'||l_upd_segment3||'.'||l_upd_segment4||'.'
                                               -- ||l_upd_segment5||'.'||l_upd_segment6 ;

                                -- fnd_file.put_line(fnd_file.log,'New Updated CCID: '|| l_conc_segs);

                                   Update APPS.TTEC_CUST_LOCATION_UPD
                                      Set Status ='Success',
                                          old_location = l_old_location,New_location= l_new_upd_loc,
                                          old_costing = l_old_costing,new_costing = NVL(l_new_costing,l_old_costing),
                                          old_expense_acc = l_old_expense_acc, new_expense_acc = l_new_expense_acc
                                        --,  Assignment_flag ='Y',Costing_flag='Y',Expense_Flag= 'Y' --new_exp
                                    where Employee_Number = l_employee_number;
                                   commit;

                              exception
                              when others then
                              Rollback;
                                    print_log('API ERROR: While updating CCID in POI form - '||substr(sqlerrm,1,1000));
                                    l_expense_flag := 'N';
                     end;
                  else
                         print_log('Generated CCID is null for #Emp: '|| l_employee_number || l_err_msg);
                         Rollback;
                          raise Expense_Form;
                          l_expense_flag := 'N';

                  end if;
               else
                    print_log('Emp does not have any code combination in POI ');
                    l_expense_flag :='Y';
                             Update APPS.TTEC_CUST_LOCATION_UPD
                              Set Status ='Success',
                                          old_location = l_old_location,New_location= l_new_upd_loc,
                                          old_costing = l_old_costing,new_costing = NVL(l_new_costing,l_old_costing),
                                          old_expense_acc = l_old_expense_acc, new_expense_acc = NVL(l_new_expense_acc,l_old_expense_acc)
                                         -- Assignment_flag ='Y',Costing_flag='Y',Expense_Flag= 'Y' --new_exp
                              where Employee_Number = l_employee_number;
                              commit;
             end if;

            if l_expense_flag != 'Y'
            then
                raise expense_form;
            end if;

                    Exception
                    when expense_form then
                   -- print_log('inside expense_Form exception');
                        for Expense IN C3 ( C_Assignment => l_assignment_id)
                        loop
                            l_old_costing := Expense.segment1||'.'||Expense.segment2||'.'||Expense.segment3;

                                update APPS.TTEC_CUST_LOCATION_UPD
                                Set        new_location = l_old_location,
                                           old_costing = l_old_costing ,new_costing = l_old_costing,
                                           new_expense_acc = l_old_expense_acc,
                                           Status ='FAIL',
                                           REASON='API Error: While updating CCID in POI form'
                                         --  Assignment_flag='N',Costing_Flag='N',Expense_Flag= 'N'
                                where      Employee_Number = l_employee_number;
                                commit;
                        end loop;
            end;   --expense end
            end if; --costing end if

                    Exception
                    when Costing_Form Then
                   -- print_log('Error: while Updating Location in Assignment Form ');

                        for Costing IN C3 ( C_Assignment => l_assignment_id)
                        loop
                            l_old_costing := Costing.segment1||'.'||Costing.segment2||'.'||Costing.segment3;

                               update APPS.TTEC_CUST_LOCATION_UPD
                               Set    new_location = l_old_location,
                                   old_costing = l_old_costing,new_costing = l_old_costing,
                                   New_expense_acc = l_old_expense_acc,
                                   Status = 'FAIL',
                                   reason='api error: while updating location in costing form'
                                  -- Assignment_flag='N',Costing_flag ='N',Expense_flag='N'
                                where Employee_Number = l_employee_number;
                                commit;
                        end loop;
            end; --costing end

            end if;   --Assignment if end;
                        Exception
                        When Assignment_Form Then
                        --print_log('Error: while updating Location in Assignment form'|| substr(sqlerrm,1,1000);

                            for Assignment IN C3 ( C_Assignment => l_assignment_id)
                            loop
                                 l_old_costing := Assignment.segment1||'.'||Assignment.segment2||'.'||Assignment.segment3;

                                update APPS.TTEC_CUST_LOCATION_UPD
                                Set    new_location = l_old_location,
                                       Old_costing=l_old_costing, New_costing = l_old_costing,
                                       New_expense_acc = l_old_expense_acc,
                                       Status = 'FAIL',
                                      -- Assignment_flag ='N',Costing_flag='N',Expense_Flag='N',
                                       reason='API Error: While updating location in Assignment form'
                                where employee_number = l_employee_number;
                                commit;
                            end loop;
            end;   --Assignment end

                        exception
                        when Future_date then
                         print_log('Emp Have Future Dated Changes');

                            for Future IN C3 ( C_Assignment => l_assignment_id)
                            loop
                                 l_old_costing := Future.segment1||'.'||Future.segment2||'.'||Future.segment3;

                                Update APPS.TTEC_CUST_LOCATION_UPD
                                Set    Status = 'FUTURE DATED CHANGES',
                                       New_location = l_old_location,
                                       Old_Costing=l_old_costing,New_costing = l_old_costing,
                                       New_expense_acc = l_old_expense_acc
                                      -- Assignment_Flag='N',Costing_Flag='N',Expense_flag='N'
                                where  Employee_Number = l_employee_number;
                                commit;
                                -- print_log('Future:data updated in custom table');
                            end loop;
            end; --future date end

                        Exception
                        When Emp_Termed then
                         print_log('Emp is Terminated');

                            For Termed IN C3 ( C_Assignment => l_assignment_id)
                            loop
                                  l_old_costing := Termed.segment1||'.'||Termed.segment2||'.'||Termed.segment3;

                                 update APPS.TTEC_CUST_LOCATION_UPD
                                 Set    Status ='TERMED',
                                        New_Location = l_old_Location,
                                        Old_Costing=l_old_costing,New_costing = l_old_costing,
                                        New_expense_acc = l_old_expense_acc
                                       -- Assignment_Flag='N',Costing_Flag='N',Expense_flag='N'
                                 where Employee_Number = l_employee_number;
                                 commit;
                                 -- print_log('termed data updated in custom table');
            end loop;
        End;
        End Loop; --C2
        End Loop;  --C1


              ---Printing output
              begin
                    for T2 IN C1
                    loop
                       v_emp_no    :=T2.employee_number;
                       v_new_loc   :=T2.new_location;
                       v_old_loc   :=T2.old_location;
                       v_old_cost  :=T2.old_costing;
                       v_new_cost  :=T2.new_costing;
                       v_old_exp   :=T2.old_expense_acc;
                       v_new_exp   :=T2.new_expense_acc;

                       print_output(v_emp_no||'|'||v_old_loc||'|'||v_new_loc||'|'||v_old_cost||'|'||
                                    v_new_cost||'|'||v_old_exp||'|'||v_new_exp||'|'||T2.Status);
                    end loop;

                      exception
                      when others then
                      print_log('error while printing output' );
              end;

   END;
END TTEC_LOCATION_UPD_PKG;
/
show errors;
/