create or replace PACKAGE BODY      ttec_asd_dff_dates_mass_update
AS


   /*== START =================================================================*\
       Author:

         Date:
         Desc:  This package is intended to Load  adj_service_date for given employees for MEX Employees
		       Also this updates dates of Assignment DFF Contract_Start_Date and fecha_de_antiguedad for MEX Employees

       Modification History:

       Mod#  Date        Author      Description (Include Ticket#)
      -----  ----------  ----------  --------------------------------------------
        1.1  1-Aug-2022   Neelofar       Adjusted Service Date Mass Update
		1.0	18-july-2023 IXPRAVEEN(ARGANO)   		R12.2 Upgrade Remediation
   \*== END ===================================================================*/
   PROCEDURE main (
      ERRCODE            VARCHAR2,
      ERRBUFF            VARCHAR2
   )
   IS

   ln_object_version_number number;
   lc_employee_number VARCHAr2(30);
   p_effective_date date;
   p_object_version_number number;
   lb_correction           BOOLEAN;

      o_cagr_grade_def_id           number;          --
      o_cagr_concatenated_segments  varchar2(250);   --
      o_hourly_salaried_warning     boolean;         --
      o_gsp_post_process_warning    varchar2(250);   --


   ld_effective_start_date     DATE;
   ld_effective_end_date       DATE;
   lc_full_name                PER_ALL_PEOPLE_F.FULL_NAME%TYPE;
   ln_comment_id               PER_ALL_PEOPLE_F.COMMENT_ID%TYPE;
   lb_name_combination_warning BOOLEAN;
   lb_assign_payroll_warning   BOOLEAN;
   lb_orig_hire_warning        BOOLEAN;
   lc_dt_ud_mode               VARCHAR2(200) := 'CORRECTION';


    -- Out Variables for Update Employee Assignment API
   -- ----------------------------------------------------------------------------
   ln_soft_coding_keyflex_id       HR_SOFT_CODING_KEYFLEX.SOFT_CODING_KEYFLEX_ID%TYPE;
   lc_concatenated_segments       VARCHAR2(2000);
   l_comment_id                             PER_ALL_ASSIGNMENTS_F.COMMENT_ID%TYPE;
   lb_no_managers_warning        BOOLEAN;

 -- Out Variables for Update Employee Assgment Criteria
 -- -------------------------------------------------------------------------------
 ln_special_ceiling_step_id                    PER_ALL_ASSIGNMENTS_F.SPECIAL_CEILING_STEP_ID%TYPE;
 lc_group_name                                          VARCHAR2(30);
 l_effective_start_date                             PER_ALL_ASSIGNMENTS_F.EFFECTIVE_START_DATE%TYPE;
 l_effective_end_date                              PER_ALL_ASSIGNMENTS_F.EFFECTIVE_END_DATE%TYPE;
 lb_org_now_no_manager_warning   BOOLEAN;
 lb_other_manager_warning                  BOOLEAN;
 lb_spp_delete_warning                          BOOLEAN;
 lc_entries_changed_warning                VARCHAR2(30);
 lb_tax_district_changed_warn             BOOLEAN;

 n number;
 i number;
  L_REC             VARCHAR2 (600);
   L_MSG             VARCHAR2 (2000);
cursor c1 is

  SELECT
    papf.object_version_number,
    papf.person_id,papf.employee_number,paaf.assignment_id,paaf.object_version_number as paaf_object_version_number,
    papf.effective_start_date,paaf.effective_start_date as paaf_effective_start_date,
    t.adjusted_service_date,
    to_char(t.fecha_de_antiguedad,'RRRR/MM/DD') as fecha_de_antiguedad,
    to_char(t.contract_start_date,'RRRR/MM/DD') as contract_start_date
FROM
    --cust.TTEC_ASD_ASG_DFF_DATES_UPLOAD   t,		-- Commented code by IXPRAVEEN-ARGANO,18-july-2023
    apps.TTEC_ASD_ASG_DFF_DATES_UPLOAD   t,		    --  code Added by IXPRAVEEN-ARGANO,   18-july-2023
    per_all_people_f                 papf,
    per_all_assignments_f           paaf
WHERE
    papf.employee_number = t.employee_number
    and papf.person_id=paaf.person_id
    AND sysdate+30 BETWEEN papf.effective_start_date AND papf.effective_end_date
     AND sysdate+30 BETWEEN paaf.effective_start_date AND paaf.effective_end_date
AND papf.current_employee_flag = 'Y';

 begin
  n := 0;
    i:= 0;
 for rec in c1 loop
 begin
      hr_person_api.update_person(-- Input data elements --------------------------------
                                p_person_id               => rec.person_id,
                                p_effective_date          => rec.effective_start_date,--sysdate, --TO_DATE('12-JUN-2011'),
                                p_datetrack_update_mode   => 'CORRECTION',
                                p_adjusted_svc_date       => rec.adjusted_service_date,
                               -- Output data elements
                               p_employee_number          =>rec.employee_number,
                               p_object_version_number    => rec.object_version_number,
                               p_effective_start_date     => ld_effective_start_date,
                               p_effective_end_date       => ld_effective_end_date,
                               p_full_name                => lc_full_name,
                               p_comment_id               => l_comment_id,
                               p_name_combination_warning => lb_name_combination_warning,
                               p_assign_payroll_warning   => lb_assign_payroll_warning,
                               p_orig_hire_warning        => lb_orig_hire_warning);
                               n := n + 1;
   Fnd_File.put_line(Fnd_File.output,'employee_number'||rec.employee_number);
   Fnd_File.put_line(Fnd_File.output,'adjusted_service_date'||rec.adjusted_service_date);

 EXCEPTION
         WHEN OTHERS THEN
              dbms_output.put_line('Exception in reteiving the employee :'
                                     || ' Error Message:'
                                     || sqlerrm);
                    i := i + 1;
                    -- raise_application_error(-20001,'An error was encountered - '||SQLCODE||' -ERROR- '||SQLERRM);
					 dbms_output.put_line('Exception in create API - '||SQLERRM||rec.employee_number);
                       Fnd_File.put_line(Fnd_File.LOG, 'Exception in update person API - '||SQLERRM||'-'||rec.employee_number);
                    END;


        BEGIN


       hr_assignment_api.update_us_emp_asg
                       (p_validate                    => FALSE,
                        p_effective_date              => rec.paaf_effective_start_date,
                        p_datetrack_update_mode       => 'CORRECTION',
                        p_assignment_id               => rec.assignment_id,
                        p_object_version_number       => rec.paaf_object_version_number, -- l_object_version_number,     --
                        p_ass_attribute_category      => 1633 , -- 5054 , --l_asg_category,
                        p_ass_attribute10              =>rec.fecha_de_antiguedad,
                        p_ass_attribute14              => rec.contract_start_date,
                            --*** API OUT PARAMETERS ***--
                        p_concatenated_segments       => lc_concatenated_segments,
                        p_soft_coding_keyflex_id      => ln_soft_coding_keyflex_id,
                        p_comment_id                  => ln_comment_id,
                        p_effective_start_date        => l_effective_start_date,
                        p_effective_end_date          => l_effective_end_date,
                        p_no_managers_warning         => lb_no_managers_warning,
                        p_other_manager_warning       => lb_other_manager_warning
                       );
          --==========================
          Fnd_File.put_line(Fnd_File.output,'fecha_de_antiguedad'||rec.fecha_de_antiguedad);
          Fnd_File.put_line(Fnd_File.output,'contract_start_date'||rec.contract_start_date);

  EXCEPTION
         WHEN OTHERS THEN
                   null;
                     --raise_application_error(-20001,'An error was encountered - '||SQLCODE||' -ERROR- '||SQLERRM);
					 dbms_output.put_line('Exception in Assignment API - '||SQLERRM||rec.employee_number);
                        Fnd_File.put_line(Fnd_File.LOG, 'Exception in update_us_emp_asg API - '||SQLERRM||'-'||rec.employee_number);
                       END;
                     dbms_output.put_line('Total rows = ' || n);


    END LOOP;
     --Fnd_File.put_line(Fnd_File.LOG, 'Updated Dates successfully for employees: = ' || n);
     --Fnd_File.put_line(Fnd_File.LOG, 'Failed Records Count: = ' || i);

commit;


        END main;




END ttec_asd_dff_dates_mass_update;
/
show errors;
/