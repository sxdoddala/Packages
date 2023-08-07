create or replace PACKAGE BODY      tt_834_vision_service_plan IS
   /* $Header: tt_834_vision_service_plan.pkb  ship $ */

   /*== START ================================================================================================*\
      Author: Developer
        Date: MM/DD/YYYY
   Call From:
        Desc:

     Modification History:

    Version    Date     Author   Description (Include Ticket#)
    -------  --------  --------  ------------------------------------------------------------------------------
        1.0  MM/DD/YY  Unknown   Initial Version.
        1.1 10/11/2011 J. Keener    Added code to pull PT VSP as well
        1.2 03/13/2013 C. Chan   Commented out copy file
		1.3 12/06/2019 Hari Varma   Added fnd_lookup_values_vl to pull plan names		
   \*== END ==================================================================================================*/

  ------------------------------------------------------------------------------
  -- Convience Procedure - Log Message
  ------------------------------------------------------------------------------
  PROCEDURE info
  (
    p_message        IN VARCHAR2,
    p_copy_to_output IN BOOLEAN DEFAULT FALSE
  ) IS
  BEGIN
    tt_log.info(p_message          => p_message,
                p_copy_to_output   => p_copy_to_output,
                p_additional_depth => 1);
  END info;

  ------------------------------------------------------------------------------
  -- Convience Procedure - Log Message
  ------------------------------------------------------------------------------
  PROCEDURE warn
  (
    p_message        IN VARCHAR2,
    p_copy_to_output IN BOOLEAN DEFAULT FALSE
  ) IS
  BEGIN
    tt_log.warn(p_message          => p_message,
                p_copy_to_output   => p_copy_to_output,
                p_additional_depth => 1);
  END warn;

  ------------------------------------------------------------------------------
  -- Initialze HR Locations DFF
  ------------------------------------------------------------------------------
  FUNCTION get_hr_locations_att2_dff RETURN tt_log.r_descriptive_flexfield IS
  BEGIN
    RETURN tt_log.get_descriptive_flexfield(p_application_short_name     => 'PER',
                                            p_descriptive_flexfield_name => 'HR_LOCATIONS',
                                            p_application_column_name    => 'ATTRIBUTE12',
                                            p_navigation_path            => 'US Super HRMS Manager: Work Structures -> Location');
  EXCEPTION
    WHEN OTHERS THEN
      tt_log.raise_contextual_exception(p_sqlcode   => SQLCODE,
                                        p_sqlerrm   => SQLERRM,
                                        p_backtrace => dbms_utility.format_error_backtrace,
                                        p_context   => 'Initializing Location Code DFF');
  END get_hr_locations_att2_dff;

  ------------------------------------------------------------------------------
  -- Initialze Email AOL Lookup Type
  ------------------------------------------------------------------------------
  FUNCTION get_email_aol_lookup_type RETURN tt_log.r_aol_lookup_type IS
  BEGIN
    RETURN tt_log.get_aol_lookup_type(p_application_short_name      => 'PER',
                                      p_view_application_short_name => 'AU',
                                      p_lookup_type                 => 'TT_834_VSP_EMAIL_LIST',
                                      p_navigation_path             => 'US Super HRMS Manager: Other Definitions -> Lookup Tables');
  EXCEPTION
    WHEN OTHERS THEN
      tt_log.raise_contextual_exception(p_sqlcode   => SQLCODE,
                                        p_sqlerrm   => SQLERRM,
                                        p_backtrace => dbms_utility.format_error_backtrace,
                                        p_context   => 'Initializing Email List Lookup');
  END get_email_aol_lookup_type;

  ------------------------------------------------------------------------------
  -- Create File
  ------------------------------------------------------------------------------
  PROCEDURE format_file
  (
    p_params834        IN OUT tt_834_formatter.params834,
    p_output_directory IN VARCHAR2,
    p_output_filename  IN VARCHAR2
  ) IS
    l_employee                     tt_834_formatter.employee_cursor%ROWTYPE;
    l_dependent                    tt_834_formatter.dependent_cursor%ROWTYPE;
    l_insured                      tt_834_formatter.insured_record;
    l_employee_success_count       NUMBER := 0;
    l_employee_error_count         NUMBER := 0;
    l_dependent_success_count      NUMBER := 0;
    l_dependent_error_count        NUMBER := 0;
    l_ins02_individual_rel_dff     tt_log.r_descriptive_flexfield;
    l_hd05_coverage_level_code_dff tt_log.r_descriptive_flexfield;
    l_hr_locations_att2_dff        tt_log.r_descriptive_flexfield;
    l_ins08_emp_status_code        tt_file_metadata.t_field;
    l_dependent_is_spouse          BOOLEAN := FALSE;
    l_dependent_count              NUMBER := 0;
    l_dependent_is_full_time_stdnt BOOLEAN := FALSE;
    l_ins09_student_status_code    tt_file_metadata.t_field;

      cursor c_vsp_plan
  is
   /* select 'Vision Ins' plan_name from dual
union                                                                                          --1.1
select 'Vision Ins PT' plan_name from dual; */

 select description plan_name from apps.fnd_lookup_values_vl
     where lookup_type='TTEC_834_VSP_PLAN_CODE' ;

  BEGIN
    -- INS02 Individual Relationship Code
    l_ins02_individual_rel_dff := tt_834_formatter.get_ins02_individual_rel_dff;

    -- HD05 Coverage Level Code
    l_hd05_coverage_level_code_dff := tt_834_formatter.get_hd05_coverage_level_dff;

    -- Location Code for REF*DX record
    l_hr_locations_att2_dff := get_hr_locations_att2_dff;

    tt_file_metadata.file_open_for_write(p_directory   => p_output_directory,
                                         p_filename    => p_output_filename,
                                         p_file_handle => p_params834.file_handle);

    tt_834_formatter.write_file_header_records(p_params834 => p_params834);

    tt_834_formatter.write_trans_header_records(p_params834 => p_params834);
    for r_vsp_plan in c_vsp_plan

    loop
   -- fnd_file.put_line(fnd_file.log,'plan_name ' || r_vsp_plan.plan_name );
    OPEN tt_834_formatter.employee_cursor(p_trunc_effective_date => p_params834.trunc_effective_date,
                                          p_plan_name_like       => r_vsp_plan.plan_name);
    LOOP
      FETCH tt_834_formatter.employee_cursor
        INTO l_employee;

      EXIT WHEN tt_834_formatter.employee_cursor%NOTFOUND;

      BEGIN

        IF l_employee.emp_current_employee_flag = 'Y'
        THEN
          tt_log.assert(p_condition          => l_employee.emp_full_part_flag IS
                                                NOT NULL,
                        p_neg_condition_text => 'Full/Part Time Flag (Employement Category) IS NULL');
          CASE l_employee.emp_full_part_flag
            WHEN 'F' THEN
              l_ins08_emp_status_code := tt_834_metadata.ins08_ft_full_time;
            WHEN 'P' THEN
              l_ins08_emp_status_code := tt_834_metadata.ins08_pt_part_time;
            WHEN 'V' THEN
              l_ins08_emp_status_code := tt_834_metadata.ins08_pt_part_time; -- 1.1
          END CASE;ELSE
          l_ins08_emp_status_code := tt_834_metadata.ins08_te_terminated;
        END IF;

        tt_log.assert(p_condition          => l_employee.emp_vsp_location IS
                                              NOT NULL,
                      p_neg_condition_text => l_hr_locations_att2_dff.end_user_column_name ||
                                              ' IS NULL',
                      p_context            => 'for Location ' ||
                                              tt_log.show_value(l_employee.location_code) ||
                                              ' (location_id=' ||
                                              tt_log.show_value(p_value                    => l_employee.location_id,
                                                                p_alternate_text_when_null => NULL) || ')');

        tt_log.assert(p_condition          => l_employee.opt_coverage_level_code IS
                                              NOT NULL,
                      p_neg_condition_text => l_hd05_coverage_level_code_dff.end_user_column_name ||
                                              ' IS NULL',
                      p_context            => 'for Benefit Option ' ||
                                              tt_log.show_value(l_employee.opt_name));

        IF l_employee.emp_sex IS NULL
        THEN
          warn('Sex IS Unknown (NULL) for Employee Number ' ||
               tt_log.show_value(l_employee.emp_number) || ' (' ||
               tt_log.show_value(l_employee.emp_last_name) || ', ' ||
               tt_log.show_value(l_employee.emp_first_name) || ')',
               TRUE);
        END IF;

        OPEN tt_834_formatter.dependent_cursor(p_trunc_effective_date => p_params834.trunc_effective_date,
                                               p_emp_rslt_id          => l_employee.emp_rslt_id,
                                               p_emp_term_date        => l_employee.emp_actual_term_date,
                                               p_emp_ssn              => l_insured.emp_ssn);

        l_dependent_count := 0;

        LOOP
          FETCH tt_834_formatter.dependent_cursor
            INTO l_dependent;

          EXIT WHEN tt_834_formatter.dependent_cursor%NOTFOUND;

          BEGIN

            l_dependent_count := l_dependent_count + 1;

          END;

        END LOOP;

        CLOSE tt_834_formatter.dependent_cursor;

        OPEN tt_834_formatter.dependent_cursor(p_trunc_effective_date => p_params834.trunc_effective_date,
                                               p_emp_rslt_id          => l_employee.emp_rslt_id,
                                               p_emp_term_date        => l_employee.emp_actual_term_date,
                                               p_emp_ssn              => l_insured.emp_ssn);

        l_dependent_is_spouse          := FALSE;


        LOOP

          FETCH tt_834_formatter.dependent_cursor
            INTO l_dependent;

          EXIT WHEN tt_834_formatter.dependent_cursor%NOTFOUND;

          BEGIN

            tt_log.assert(p_condition          => l_dependent.dep_ins02_individual_rel_code IS
                                                  NOT NULL,
                          p_neg_condition_text => 'Dependent ' ||
                                                  tt_log.show_value(l_ins02_individual_rel_dff.end_user_column_name) ||
                                                  ' IS NULL',
                          p_context            => 'for Contact Type ' ||
                                                  tt_log.show_value(l_dependent.dep_contact_type));

            IF l_dependent.dep_ins02_individual_rel_code !=
               tt_834_formatter.c_contact_dff_00_exclude
            THEN

              tt_log.assert(p_condition          => l_dependent.dep_first_name IS
                                                    NOT NULL,
                            p_neg_condition_text => 'Dependent First Name IS NULL');
              tt_log.assert(p_condition          => l_dependent.dep_last_name IS
                                                    NOT NULL,
                            p_neg_condition_text => 'Dependent Last Name IS NULL');
              tt_log.assert(p_condition          => l_dependent.dep_dob IS
                                                    NOT NULL,
                            p_neg_condition_text => 'Dependent Date of Birth IS NULL');
              tt_log.assert(p_condition          => l_dependent.dep_cvg_start_date IS
                                                    NOT NULL,
                            p_neg_condition_text => 'Dependent Coverage Start Date IS NULL');



              IF l_dependent.dep_contact_type = 'S'
                 AND l_dependent_count = 1
              THEN
                l_dependent_is_spouse := TRUE;
              END IF;

            END IF;

          EXCEPTION
            WHEN OTHERS THEN
              l_dependent_error_count := l_dependent_error_count + 1;

              tt_log.output_error(p_sqlcode => SQLCODE,
                                  p_sqlerrm => SQLERRM,
                                  p_message => 'for Dependent ' ||
                                               tt_log.show_value(l_dependent.dep_last_name) || ', ' ||
                                               tt_log.show_value(l_dependent.dep_first_name) ||
                                               ' for Employee Number ' ||
                                               tt_log.show_value(l_employee.emp_number) || ' (' ||
                                               tt_log.show_value(l_employee.emp_last_name) || ', ' ||
                                               tt_log.show_value(l_employee.emp_first_name) || ')');
              tt_log.log_contextual_exception(p_log_level => tt_log.c_log_level_error,
                                              p_sqlcode   => SQLCODE,
                                              p_sqlerrm   => SQLERRM,
                                              p_backtrace => dbms_utility.format_error_backtrace,
                                              p_context   => 'while processing ' ||
                                                             tt_834_formatter.describe_dependent(l_dependent));
          END;

        END LOOP;

        CLOSE tt_834_formatter.dependent_cursor;
     --fnd_file.put_line(fnd_file.log,'l_employee.emp_vsp_location ' || l_employee.emp_vsp_location );
        l_insured.loop2000_1st_ref_qualifier  := tt_834_metadata.ref01_0f_subscr_number_qual;
        l_insured.loop2000_1st_ref_identifier := l_employee.emp_ssn;
        l_insured.loop2000_2nd_ref_qualifier  := tt_834_metadata.ref01_dx_depart_agency_number;
        l_insured.loop2000_2nd_ref_identifier := l_employee.emp_vsp_location;
        l_insured.loop2000_3rd_ref_qualifier  := NULL;
        l_insured.loop2000_3rd_ref_identifier := NULL;
        l_insured.loop2000_4th_ref_qualifier  := NULL;
        l_insured.loop2000_4th_ref_identifier := NULL;

       -- fnd_file.put_line(fnd_file.log,'loop2000_1st_ref_identifier ' || l_insured.loop2000_1st_ref_identifier );
       -- fnd_file.put_line(fnd_file.log,'loop2000_2nd_ref_identifier ' || l_insured.loop2000_2nd_ref_identifier );
        IF l_dependent_is_spouse
        THEN
          info('Dependent record changed to Employee and Spouse for Employee Number ' ||
               tt_log.show_value(l_employee.emp_number) || ' (' ||
               tt_log.show_value(l_employee.emp_last_name) || ', ' ||
               tt_log.show_value(l_employee.emp_first_name) || ')');
          l_insured.hd05_coverage_level_code := c_hd05_spouse_cov_level_code;
        ELSE
          l_insured.hd05_coverage_level_code := l_employee.opt_coverage_level_code;
        END IF;
        l_insured.emp_person_id             := l_employee.emp_person_id;
        l_insured.emp_ssn                   := l_employee.emp_ssn;
        l_insured.emp_number                := l_employee.emp_number;
        l_insured.emp_addr_line1            := l_employee.emp_addr_line1;
        l_insured.emp_addr_line2            := l_employee.emp_addr_line2;
        l_insured.emp_city                  := l_employee.emp_city;
        l_insured.emp_state                 := l_employee.emp_state;
        l_insured.emp_zip_code              := l_employee.emp_zip_code;
        l_insured.emp_actual_term_date      := l_employee.emp_actual_term_date;
        l_insured.ins01_yes_no_condition    := tt_834_metadata.ins01_y_subscriber;
        l_insured.ins02_individual_rel_code := tt_834_metadata.ins02_18_self;
        l_insured.ins08_emp_status_code     := l_ins08_emp_status_code;
        l_insured.ins09_student_status_code := NULL;
        l_insured.insured_person_id         := l_employee.emp_person_id;
        l_insured.insured_ssn               := l_employee.emp_ssn;
        l_insured.insured_first_name        := l_employee.emp_first_name;
        l_insured.insured_middle_names      := l_employee.emp_middle_names;
        l_insured.insured_last_name         := l_employee.emp_last_name;
        l_insured.insured_suffix            := l_employee.emp_suffix;
        l_insured.insured_sex               := l_employee.emp_sex;
        l_insured.insured_dob               := l_employee.emp_dob;
        l_insured.insured_cvg_start_date    := l_employee.emp_cvg_start_date;
        l_insured.insured_cvg_end_date      := l_employee.emp_cvg_end_date;

        tt_834_formatter.write_insured_record(p_params834 => p_params834,
                                              p_insured   => l_insured);
        l_employee_success_count := l_employee_success_count + 1;

        OPEN tt_834_formatter.dependent_cursor(p_trunc_effective_date => p_params834.trunc_effective_date,
                                               p_emp_rslt_id          => l_employee.emp_rslt_id,
                                               p_emp_term_date        => l_employee.emp_actual_term_date,
                                               p_emp_ssn              => l_insured.emp_ssn);
        LOOP
          FETCH tt_834_formatter.dependent_cursor
            INTO l_dependent;

          EXIT WHEN tt_834_formatter.dependent_cursor%NOTFOUND;

          BEGIN

            tt_log.assert(p_condition          => l_dependent.dep_ins02_individual_rel_code IS
                                                  NOT NULL,
                          p_neg_condition_text => 'Dependent ' ||
                                                  tt_log.show_value(l_ins02_individual_rel_dff.end_user_column_name) ||
                                                  ' IS NULL',
                          p_context            => 'for Contact Type ' ||
                                                  tt_log.show_value(l_dependent.dep_contact_type));

            IF l_dependent.dep_ins02_individual_rel_code !=
               tt_834_formatter.c_contact_dff_00_exclude
            THEN
              tt_log.assert(p_condition          => l_dependent.dep_first_name IS
                                                    NOT NULL,
                            p_neg_condition_text => 'Dependent First Name IS NULL');
              tt_log.assert(p_condition          => l_dependent.dep_last_name IS
                                                    NOT NULL,
                            p_neg_condition_text => 'Dependent Last Name IS NULL');
              tt_log.assert(p_condition          => l_dependent.dep_dob IS
                                                    NOT NULL,
                            p_neg_condition_text => 'Dependent Date of Birth IS NULL');
              tt_log.assert(p_condition          => l_dependent.dep_cvg_start_date IS
                                                    NOT NULL,
                            p_neg_condition_text => 'Dependent Coverage Start Date IS NULL');

              /*
                IF l_dependent.dep_ssn IS NOT NULL
                THEN
                  warn('Dependent SSN IS NULL for ' || tt_log.show_value(l_dependent.dep_last_name) || ', ' ||
                       tt_log.show_value(l_dependent.dep_first_name) || ' for Employee Number ' ||
                       tt_log.show_value(l_employee.emp_number) || ' (' || tt_log.show_value(l_employee.emp_last_name) || ', ' ||
                       tt_log.show_value(l_employee.emp_first_name) || ')', TRUE);
                END IF;
              */

              IF l_dependent.dep_sex IS NULL
              THEN
                warn('Sex IS NULL for Dependent ' ||
                     tt_log.show_value(l_dependent.dep_last_name) || ', ' ||
                     tt_log.show_value(l_dependent.dep_first_name) ||
                     ' for Employee Number ' ||
                     tt_log.show_value(l_employee.emp_number) || ' (' ||
                     tt_log.show_value(l_employee.emp_last_name) || ', ' ||
                     tt_log.show_value(l_employee.emp_first_name) || ')',
                     TRUE);
              END IF;

              l_insured.hd05_coverage_level_code  := NULL;
              l_insured.ins01_yes_no_condition    := tt_834_metadata.ins01_n_dependent;
              l_insured.ins02_individual_rel_code := l_dependent.dep_ins02_individual_rel_code;
              l_insured.ins08_emp_status_code     := NULL;

              IF l_dependent.dep_ins09_student_status_code = 'F'
                 AND l_dependent.dep_ins02_individual_rel_code != 'S'
              THEN
                IF TRUNC(MONTHS_BETWEEN(p_params834.trunc_effective_date, l_dependent.dep_dob) / 12) BETWEEN 19 AND 24
                THEN
                  l_dependent_is_full_time_stdnt := TRUE;
                ELSE
                  l_dependent_is_full_time_stdnt := FALSE;
                END IF;
              ELSE
                l_dependent_is_full_time_stdnt := FALSE;
              END IF;

              IF l_dependent_is_full_time_stdnt
              THEN
                info('Full Time Student Code Set for Dependent ' ||
                     tt_log.show_value(l_dependent.dep_last_name) || ', ' ||
                     tt_log.show_value(l_dependent.dep_first_name) ||
                     ' for Employee Number ' ||
                     tt_log.show_value(l_employee.emp_number) || ' (' ||
                     tt_log.show_value(l_employee.emp_last_name) || ', ' ||
                     tt_log.show_value(l_employee.emp_first_name) || ')');
                l_ins09_student_status_code := 'F';
              ELSE
                IF
                  l_dependent.dep_ins09_student_status_code = 'F'
                THEN
                  l_ins09_student_status_code := 'N';
                ELSE
                  l_ins09_student_status_code := l_dependent.dep_ins09_student_status_code;
                END IF;
              END IF;
              l_insured.ins09_student_status_code := l_ins09_student_status_code;
              l_insured.insured_person_id      := l_dependent.dep_person_id;
              l_insured.insured_ssn            := l_dependent.dep_ssn;
              l_insured.insured_first_name     := l_dependent.dep_first_name;
              l_insured.insured_middle_names   := l_dependent.dep_middle_names;
              l_insured.insured_last_name      := l_dependent.dep_last_name;
              l_insured.insured_suffix         := l_dependent.dep_suffix;
              l_insured.insured_sex            := l_dependent.dep_sex;
              l_insured.insured_dob            := l_dependent.dep_dob;
              l_insured.insured_cvg_start_date := l_dependent.dep_cvg_start_date;
              l_insured.insured_cvg_end_date   := l_dependent.dep_cvg_end_date;

              tt_834_formatter.write_insured_record(p_params834 => p_params834,
                                                    p_insured   => l_insured);
              l_dependent_success_count := l_dependent_success_count + 1;
            END IF;

          EXCEPTION
            WHEN OTHERS THEN
              l_dependent_error_count := l_dependent_error_count + 1;

              tt_log.output_error(p_sqlcode => SQLCODE,
                                  p_sqlerrm => SQLERRM,
                                  p_message => 'for Dependent ' ||
                                               tt_log.show_value(l_dependent.dep_last_name) || ', ' ||
                                               tt_log.show_value(l_dependent.dep_first_name) ||
                                               ' for Employee Number ' ||
                                               tt_log.show_value(l_employee.emp_number) || ' (' ||
                                               tt_log.show_value(l_employee.emp_last_name) || ', ' ||
                                               tt_log.show_value(l_employee.emp_first_name) || ')');
              tt_log.log_contextual_exception(p_log_level => tt_log.c_log_level_error,
                                              p_sqlcode   => SQLCODE,
                                              p_sqlerrm   => SQLERRM,
                                              p_backtrace => dbms_utility.format_error_backtrace,
                                              p_context   => 'while processing ' ||
                                                             tt_834_formatter.describe_dependent(l_dependent));
          END;

        END LOOP;

        CLOSE tt_834_formatter.dependent_cursor;

      EXCEPTION
        WHEN OTHERS THEN
          l_employee_error_count := l_employee_error_count + 1;

          -- Close any open cursors
          IF tt_834_formatter.dependent_cursor%ISOPEN
          THEN
            BEGIN
              CLOSE tt_834_formatter.dependent_cursor;
            EXCEPTION
              WHEN OTHERS THEN
                NULL; -- ignore
            END;
          END IF;

          tt_log.output_error(p_sqlcode => SQLCODE,
                              p_sqlerrm => SQLERRM,
                              p_message => 'for Employee Number ' ||
                                           tt_log.show_value(l_employee.emp_number) || ' (' ||
                                           tt_log.show_value(l_employee.emp_last_name) || ', ' ||
                                           tt_log.show_value(l_employee.emp_first_name) || ')');
          tt_log.log_contextual_exception(p_log_level => tt_log.c_log_level_error,
                                          p_sqlcode   => SQLCODE,
                                          p_sqlerrm   => SQLERRM,
                                          p_backtrace => dbms_utility.format_error_backtrace,
                                          p_context   => 'while processing ' ||
                                                         tt_834_formatter.describe_employee(l_employee));
      END;
    END LOOP;

    CLOSE tt_834_formatter.employee_cursor;

      END LOOP;  --1.1

    tt_834_formatter.write_trans_footer_records(p_params834 => p_params834);

    tt_834_formatter.write_file_footer_records(p_params834 => p_params834);

    tt_file_metadata.file_close(p_file_handle       => p_params834.file_handle,
                                p_ignore_exceptions => FALSE);

    ------------------------------------------------------------------------------
    -- Summarize results
    ------------------------------------------------------------------------------
    tt_log.output(p_message => tt_log.show_value(l_employee_success_count) ||
                               ' employee record(s) processed successfully.');
    tt_log.output(p_message => tt_log.show_value(l_dependent_success_count) ||
                               ' dependent record(s) processed successfully.');

    -- Raise exception if any insured records caused an error
    tt_log.assert(p_condition          => l_employee_error_count = 0,
                  p_neg_condition_text => tt_log.show_value(l_employee_error_count) ||
                                          ' employee record(s) had errors');
    tt_log.assert(p_condition          => l_dependent_error_count = 0,
                  p_neg_condition_text => tt_log.show_value(l_dependent_error_count) ||
                                          ' dependent record(s) had errors');
  EXCEPTION
    WHEN OTHERS THEN

      -- Close any open cursors
      IF tt_834_formatter.employee_cursor%ISOPEN
      THEN
        BEGIN
          CLOSE tt_834_formatter.employee_cursor;
        EXCEPTION
          WHEN OTHERS THEN
            NULL; -- ignore
        END;
      END IF;

      -- Release file handle if file left open
      tt_file_metadata.file_close(p_file_handle       => p_params834.file_handle,
                                  p_ignore_exceptions => TRUE);

      tt_log.raise_contextual_exception(p_sqlcode   => SQLCODE,
                                        p_sqlerrm   => SQLERRM,
                                        p_backtrace => dbms_utility.format_error_backtrace,
                                        p_context   => 'while extracting data and formatting file');
  END format_file;

  ------------------------------------------------------------------------------
  -- Create VSP File
  ------------------------------------------------------------------------------
  PROCEDURE generate_file
  (
    p_errbuf                   OUT VARCHAR2,
    p_retcode                  OUT tt_log.t_retcode,
    p_test_prod                IN VARCHAR2,
    p_effective_date           IN VARCHAR2,
    p_initial_output_directory IN VARCHAR2,
    p_initial_output_filename  IN VARCHAR2,
    p_copy_to_directory        IN VARCHAR2,
    p_copy_to_filename         IN VARCHAR2,
    p_log_level_code           IN tt_log.t_log_level_code
  ) IS
    l_params834               tt_834_formatter.params834;
    l_extract_time            DATE := SYSDATE;
    l_trunc_effective_date    DATE;
    l_task                    tt_log.t_task;
    l_email_aol_lookup_type   tt_log.r_aol_lookup_type;
    l_initial_output_filename tt_log.t_file_location;
    l_copy_to_filename        tt_log.t_file_location;
  BEGIN

    -- Required initialization
    tt_log.g_retcode := tt_log.c_retcode_success;

    -- Set Log Level
    tt_log.set_log_level(p_log_level_code => p_log_level_code);

    -- Print program name at the top of the concurrent output
    tt_log.output(p_message => c_program_name || chr(10) ||
                               rpad('=', length(c_program_name), '='));

    ------------------------------------------------------------------------------
    -- Customize 834 metadata
    --
    -- Note: CUST.TT_834_METADATA has the SERIALLY_REUSABLE PRAGMA
    -- so that our changes here are reset before the next PL/SQL call,
    -- e.g. when GENERATE_FILE() is called for a different benefit provider
    ------------------------------------------------------------------------------

    -- intitialize to default metadata
    tt_834_metadata.configure(p_sub_field_delimiter => c_isa16_component_separator);

    -- customize metadata
    tt_834_metadata.nm109_2100a_def.charset := c_digits_only;
    tt_834_metadata.nm109_2100b_def.charset := c_digits_only;
    tt_834_metadata.ref02_def_hash(tt_834_metadata.ref01_0f_subscr_number_qual).charset := c_digits_only;
    tt_834_metadata.n403_def.charset := c_digits_only;

    ------------------------------------------------------------------------------
    -- Get Email Distribution List Configuration
    ------------------------------------------------------------------------------
    l_email_aol_lookup_type := get_email_aol_lookup_type;

    ------------------------------------------------------------------------------
    -- Display raw input paramters
    ------------------------------------------------------------------------------
    info(chr(10) || 'Report Parameters:', TRUE);
    info('  p_test_prod                = ' ||
         tt_log.show_value(p_test_prod),
         TRUE);
    info('  p_effective_date           = ' ||
         tt_log.show_value(p_effective_date),
         TRUE);
    info('  p_initial_output_directory = ' ||
         tt_log.show_value(p_initial_output_directory),
         TRUE);
    info('  p_initial_output_filename  = ' ||
         tt_log.show_value(p_initial_output_filename),
         TRUE);
    info('  p_copy_to_directory        = ' ||
         tt_log.show_value(p_copy_to_directory),
         TRUE);
    info('  p_copy_to_filename         = ' ||
         tt_log.show_value(p_copy_to_filename),
         TRUE);
    info('  p_log_level_code           = ' ||
         tt_log.show_value(p_log_level_code),
         TRUE);

    ------------------------------------------------------------------------------
    -- Parse input paramters
    ------------------------------------------------------------------------------

    -- Check P_TEST_PROD
    tt_log.assert(p_condition          => p_test_prod = c_mode_test OR
                                          p_test_prod = c_mode_prod,
                  p_neg_condition_text => 'parameter p_test_prod is not one of: ' ||
                                          tt_log.show_value(c_mode_test) || ', ' ||
                                          tt_log.show_value(c_mode_prod),
                  p_context            => 'because p_test_prod = ' ||
                                          tt_log.show_value(p_test_prod));

    -- Check/Parse P_EFFECTIVE_DATE
    /* 1.2
    tt_log.assert(p_condition          => p_effective_date IS NOT NULL,
                  p_neg_condition_text => 'parameter p_effective_date IS NULL');
    l_trunc_effective_date := trunc(fnd_date.canonical_to_date(p_effective_date));
    */

    /* 1.2  Begin */
    IF p_effective_date = 'DD-MON-RRRR' THEN
     l_trunc_effective_date := to_char(sysdate,'DD-MON-RRRR');
    ELSE
     l_trunc_effective_date := p_effective_date;
    END IF;

    /* 1.2  End */

    -- Check/Parse Directories
    tt_log.assert(p_condition          => p_initial_output_directory IS
                                          NOT NULL,
                  p_neg_condition_text => 'parameter p_initial_output_directory IS NULL');
    tt_log.assert(p_condition          => p_initial_output_filename IS
                                          NOT NULL,
                  p_neg_condition_text => 'parameter p_initial_output_filename IS NULL');
    tt_log.assert(p_condition          => p_copy_to_directory IS NOT NULL,
                  p_neg_condition_text => 'parameter p_copy_to_directory IS NULL');
    tt_log.assert(p_condition          => p_copy_to_filename IS NOT NULL,
                  p_neg_condition_text => 'parameter p_copy_to_filename IS NULL');
    l_initial_output_filename := tt_log.replace_date_format_mask(p_filename => p_initial_output_filename,
                                                                 p_date     => l_extract_time);
    l_copy_to_filename        := tt_log.replace_date_format_mask(p_filename => p_copy_to_filename,
                                                                 p_date     => l_extract_time);

    -- Check P_LOG_LEVEL_CODE
    tt_log.assert(p_condition          => p_log_level_code IS NOT NULL,
                  p_neg_condition_text => 'parameter p_log_level_code IS NULL');

    ------------------------------------------------------------------------------
    -- Display parsed paramters
    ------------------------------------------------------------------------------
    info(chr(10) || 'Effective Parameters:', TRUE);
    info('  Extract Time / Current Time = ' ||
         tt_log.show_value(l_extract_time),
         TRUE);
    info('  Effectitve Date for Extract = ' ||
         tt_log.show_value(l_trunc_effective_date),
         TRUE);
    info('  Initial Output Directory    = ' ||
         tt_log.show_value(tt_log.filename_logical_to_physical(p_initial_output_directory)),
         TRUE);
    info('  Initial Output Filename     = ' ||
         tt_log.show_value(l_initial_output_filename),
         TRUE);
    info('  Copy To Directory           = ' ||
         tt_log.show_value(tt_log.filename_logical_to_physical(p_copy_to_directory)),
         TRUE);
    info('  Copy To Filename            = ' ||
         tt_log.show_value(l_copy_to_filename),
         TRUE);
    info('  Security Group              = ' ||
         tt_log.show_value(tt_log.get_security_group_name(fnd_global.security_group_id)),
         TRUE);

    tt_log.assert(p_condition          => l_extract_time IS NOT NULL,
                  p_neg_condition_text => 'l_extract_time IS NULL');
    tt_log.assert(p_condition          => l_trunc_effective_date IS
                                          NOT NULL,
                  p_neg_condition_text => 'l_effective_date IS NULL');

    ------------------------------------------------------------------------------
    -- Setup 834 parameters
    ------------------------------------------------------------------------------
    l_params834.trunc_effective_date         := l_trunc_effective_date;
    l_params834.extract_time                 := l_extract_time;
    l_params834.isa05_sender_id_qual         := c_isa05_sender_id_qual;
    l_params834.isa06_sender_id              := c_isa06_sender_id;
    l_params834.isa07_receiver_id_qual       := c_isa07_receiver_id_qual;
    l_params834.isa08_receiver_id            := c_isa08_receiver_id;
    l_params834.isa11_xchange_control_id     := c_isa11_xchange_control_id;
    l_params834.isa12_xhange_control_version := c_isa12_xhange_control_verion;
    l_params834.isa15_usage_indicator        := c_isa15_usage_indicator;
    l_params834.isa16_component_sep          := c_isa16_component_separator;
    l_params834.gs02_sender_code             := c_gs02_sender_code;
    l_params834.gs03_receiver_code           := c_gs03_receiver_code;
    l_params834.gs07_resp_agency_code        := c_gs07_resp_agency_code;
    l_params834.gs08_version_code            := c_gs08_version_code;
    l_params834.ref02_master_policy_number   := c_ref02_master_policy_number;
    l_params834.n102_1000a_plan_name         := c_n102_1000a_plan_name;
    l_params834.n103_1000a_identifier_code   := c_n103_1000a_identifier_code;
    l_params834.n104_1000a_identifier        := c_n104_1000a_identifier;
    l_params834.n102_1000b_plan_name         := c_n102_1000b_plan_name;
    l_params834.n103_1000b_identifier_code   := c_n103_1000b_identifier_code;
    l_params834.n104_1000b_identifier        := c_n104_1000b_identifier;
    l_params834.hd03_insurance_line_code     := c_hd03_insurance_line_code;

    ------------------------------------------------------------------------------
    -- Actual File Generation
    ------------------------------------------------------------------------------
    l_task := tt_log.start_task(p_log_level      => tt_log.c_log_level_info,
                                p_task_name      => 'File Generation',
                                p_copy_to_output => TRUE);

    format_file(p_params834        => l_params834,
                p_output_directory => p_initial_output_directory,
                p_output_filename  => l_initial_output_filename);

    tt_log.stop_task(p_sqlcode => SQLCODE,
                     p_sqlerrm => SQLERRM,
                     p_task    => l_task);
/* 1.2
    ------------------------------------------------------------------------------
    -- Copy file to new location for encryption and transmission
    ------------------------------------------------------------------------------
    IF tt_log.g_retcode >= tt_log.c_retcode_failure
    THEN
      warn('File will NOT be copied becuase of previous errors', TRUE);
    ELSE
      tt_file_metadata.file_copy_as_needed(p_src_directory  => p_initial_output_directory,
                                           p_src_filename   => l_initial_output_filename,
                                           p_dest_directory => p_copy_to_directory,
                                           p_dest_filename  => l_copy_to_filename);
    END IF;
*/

    ------------------------------------------------------------------------------
    -- Successful Completion
    ------------------------------------------------------------------------------

    -- Send email indicating the success
    tt_log.email_completion_status(p_sqlcode                 => SQLCODE,
                                   p_sqlerrm                 => SQLERRM,
                                   p_program_name            => c_program_name,
                                   p_copy_messages_to_output => TRUE,
                                   p_email_aol_lookup_type   => l_email_aol_lookup_type);

    -- report SUCCESS back to concurrent manager
    tt_log.set_conc_manager_return_values(p_sqlcode      => SQLCODE,
                                          p_sqlerrm      => SQLERRM,
                                          p_program_name => c_program_name,
                                          p_errbuf       => p_errbuf,
                                          p_retcode      => p_retcode);

  EXCEPTION
    WHEN OTHERS THEN

      ------------------------------------------------------------------------------
      -- Unexpected Failure
      ------------------------------------------------------------------------------

      -- Print a human readable error to the "output" and more detail to the log
      tt_log.output_error(p_sqlcode => SQLCODE,
                          p_sqlerrm => SQLERRM,
                          p_message => 'during file generation');
      tt_log.log_contextual_exception(p_log_level => tt_log.c_log_level_fatal,
                                      p_sqlcode   => SQLCODE,
                                      p_sqlerrm   => SQLERRM,
                                      p_backtrace => dbms_utility.format_error_backtrace,
                                      p_context   => 'during file generation');

      -- Stop the task if not already stopped
      tt_log.stop_task(p_sqlcode => SQLCODE,
                       p_sqlerrm => SQLERRM,
                       p_task    => l_task);

      -- Send email indicating the FAILURE
      tt_log.email_completion_status(p_sqlcode                 => SQLCODE,
                                     p_sqlerrm                 => SQLERRM,
                                     p_program_name            => c_program_name,
                                     p_copy_messages_to_output => TRUE,
                                     p_email_aol_lookup_type   => l_email_aol_lookup_type);

      -- report FAILURE back to concurrent manager
      tt_log.set_conc_manager_return_values(p_sqlcode      => SQLCODE,
                                            p_sqlerrm      => SQLERRM,
                                            p_program_name => c_program_name,
                                            p_errbuf       => p_errbuf,
                                            p_retcode      => p_retcode);

  END generate_file;

------------------------------------------------------------------------------
-- Initialize Package State
------------------------------------------------------------------------------
BEGIN
  info('Package Initialized');
EXCEPTION
  WHEN OTHERS THEN
    tt_log.raise_contextual_exception(p_sqlcode   => SQLCODE,
                                      p_sqlerrm   => SQLERRM,
                                      p_backtrace => dbms_utility.format_error_backtrace,
                                      p_context   => 'during package initialization');
END tt_834_vision_service_plan;
/
show errors;
/