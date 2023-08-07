create or replace PACKAGE BODY      ttec_arg_rhpro_ond_233_intf
AS
/*--------------------------------------------------------------------
Name:  ttec_arg_rhpro_ond_233_intf     (Package)
Description:   Data extraction - Argentina HR Data for the Payroll Vendor ( RHPro)
              The process is a ondemand interface to generate employee absences/Paid
              Time off element information taken during the period being paid.
              The users run the process every time oncycle or offcycle kronos batch is loaded into oracle
Change History
Changed By        Date        Version       Reason for Change
---------        ----        ---------      -----------------
Kaushik Babu   17-AUG-2010    1.0           Initial Creation For Argentina -- TTSD R 424040
Kaushik Babu   20-DEC-2010    1.1           fix an issue in interfaces 233 and 211
                                            where no elements are coming up in the file for terminated employees
                                            Added a new parameter, so users can run from any date from the past - TTSD 480355
Kaushik Babu   28-DEC-2010    1.2           Fixed code to pick missing element entires for terminated entries - TTSD 489927
Kaushik Babu   19-JAN-2011    1.3           Fixed issue with interface 233 old elements are coming through for terminated employees - TTSD 516216
IXPRAVEEN(ARGANO)  18-july-2023		R12.2 Upgrade Remediation
--------------------------------------------------------------------*/
   g_e_error_hand           cust.ttec_error_handling%ROWTYPE;
   g_e_program_run_status   NUMBER                             := 0;
   g_success_count          NUMBER                             := 0;
   g_error_count            NUMBER                             := 0;
   g_value                  VARCHAR2 (100)                     DEFAULT NULL;

   PROCEDURE print_line (p_data IN VARCHAR2)
   IS
   BEGIN
      fnd_file.put_line (fnd_file.LOG, p_data);
   END;

-- Procedure to get the counts on error and success records
   PROCEDURE print_count (p_success_count IN NUMBER, p_error_count IN NUMBER, p_module IN VARCHAR2)
   IS
   BEGIN
      print_line ('**********************************');
      print_line ('Total Success Records Generated for ' || p_module || ' >>> ' || p_success_count);
      print_line ('Total Error Records Generated for ' || p_module || ' >>> ' || p_error_count);
      print_line ('**********************************');
   END;

   --Procedure to open file to write the records
   PROCEDURE get_file_open (p_filename IN VARCHAR2)
   IS
   BEGIN
      get_dir_name (v_dir_name);
      v_full_file_path := v_dir_name || '/' || p_filename;
      v_output_file := UTL_FILE.fopen (v_dir_name, p_filename, 'w', 32000);
      print_line ('**********************************');
      print_line ('Output file created >>> ' || v_dir_name || '/' || p_filename);
      print_line ('**********************************');
      init_counts;
   END;

-- initialize counts
   PROCEDURE init_counts
   IS
   BEGIN
      g_success_count := 0;
      g_error_count := 0;
      g_value := NULL;
   END;

--initial variables for error messages
   PROCEDURE init_error_msg (p_module_name IN VARCHAR2)
   IS
   BEGIN
      g_e_error_hand := NULL;
      g_e_error_hand.module_name := p_module_name;                                             --'main';
      g_e_error_hand.status := 'FAILURE';
      g_e_error_hand.application_code := 'HR';
      g_e_error_hand.INTERFACE := 'TTECHRARGINTRF';
      g_e_error_hand.program_name := 'TTEC_ARG_RHPro_Init_Data_Intf';
      g_e_error_hand.ERROR_CODE := 0;
   END;

-- procedure to log errors in TTEC_ERROR_HANDLING table
   PROCEDURE log_error (
      p_label1       IN   VARCHAR2,
      p_reference1   IN   VARCHAR2,
      p_label2       IN   VARCHAR2,
      p_reference2   IN   VARCHAR2
   )
   IS
   BEGIN
      -- not in this routine g_e_error_hand.module_name := 'log_error'

      -- g_e_error_hand := NULL;
      g_e_error_hand.ERROR_CODE := TO_CHAR (SQLCODE);
      g_e_error_hand.error_message := SUBSTR (SQLERRM, 1, 240);
      --cust.ttec_process_error (g_e_error_hand.application_code,		-- Commented code by IXPRAVEEN-ARGANO,18-july-2023
      apps.ttec_process_error (g_e_error_hand.application_code,         --  code Added by IXPRAVEEN-ARGANO,   18-july-2023
                               g_e_error_hand.INTERFACE,
                               g_e_error_hand.program_name,
                               g_e_error_hand.module_name,
                               g_e_error_hand.status,
                               g_e_error_hand.ERROR_CODE,
                               g_e_error_hand.error_message,
                               p_label1,
                               p_reference1,
                               p_label2,
                               p_reference2,
                               g_e_error_hand.label3,
                               g_e_error_hand.reference3,
                               g_e_error_hand.label4,
                               g_e_error_hand.reference4,
                               g_e_error_hand.label5,
                               g_e_error_hand.reference5,
                               g_e_error_hand.label6,
                               g_e_error_hand.reference6,
                               g_e_error_hand.label7,
                               g_e_error_hand.reference7,
                               g_e_error_hand.label8,
                               g_e_error_hand.reference8,
                               g_e_error_hand.label9,
                               g_e_error_hand.reference9,
                               g_e_error_hand.label10,
                               g_e_error_hand.reference10,
                               g_e_error_hand.label11,
                               g_e_error_hand.reference11,
                               g_e_error_hand.label12,
                               g_e_error_hand.reference12,
                               g_e_error_hand.label13,
                               g_e_error_hand.reference13,
                               g_e_error_hand.label14,
                               g_e_error_hand.reference14,
                               g_e_error_hand.label15,
                               g_e_error_hand.reference15
                              );
   EXCEPTION
      WHEN OTHERS
      THEN
         -- log_error ('Routine', e_module_name, 'Error Message', SUBSTR (SQLERRM, 1, 80) );
         print_line ('Error in module: ' || g_e_error_hand.module_name);
         print_line ('Failed  with Error ' || TO_CHAR (SQLCODE) || '|' || SUBSTR (SQLERRM, 1, 64));
         g_e_program_run_status := 1;
   END;

   PROCEDURE get_host_name (p_host_name OUT VARCHAR2)
   IS
   BEGIN
      OPEN c_host;

      FETCH c_host
       INTO p_host_name;

      CLOSE c_host;
   EXCEPTION
      WHEN OTHERS
      THEN
         log_error ('SQLCODE', TO_CHAR (SQLCODE), 'Error Message', SUBSTR (SQLERRM, 1, 64));
         print_line ('Error in module: ' || g_e_error_hand.module_name);
         print_line ('Failed  with Error ' || TO_CHAR (SQLCODE) || '|' || SUBSTR (SQLERRM, 1, 64));
   END;

-- procedure to initialize the directory path in oracle to generate the data
   PROCEDURE get_dir_name (p_dir_name OUT VARCHAR2)
   IS
   BEGIN
      OPEN c_directory_path;

      FETCH c_directory_path
       INTO p_dir_name;

      CLOSE c_directory_path;
   EXCEPTION
      WHEN OTHERS
      THEN
         log_error ('SQLCODE', TO_CHAR (SQLCODE), 'Error Message', SUBSTR (SQLERRM, 1, 64));
         print_line ('Error in module: ' || g_e_error_hand.module_name);
         print_line ('Failed  with Error ' || TO_CHAR (SQLCODE) || '|' || SUBSTR (SQLERRM, 1, 64));
   END;

-- Function to remove special characters on the data file
   FUNCTION cvt_char (p_text VARCHAR2)
      RETURN VARCHAR2
   AS
      v_text   VARCHAR2 (150);
   BEGIN
      SELECT REPLACE (TRANSLATE (CONVERT (p_text, 'WE8ISO8859P1', 'UTF8'), '&:;'''',"´¨%^¿?#', '&'),
                      '&',
                      ''
                     )                                                                      --Version 1.1
        INTO v_text
        FROM DUAL;

      RETURN (v_text);
   EXCEPTION
      WHEN OTHERS
      THEN
         v_text := p_text;                                                                 --Version 1.1
         RETURN (v_text);
   END;

--The 233-Importación de Licencias (Absences-Paid Time Off) interface will feed RHPro with absences/Paid Time off taken during the period being paid.
   PROCEDURE init_233_intf (p_file_name IN VARCHAR2, p_business_group_id IN NUMBER, p_cut_off_date DATE)
   -- Version 1.1
   IS
      CURSOR c_emp_active                                                                 -- Version 1.1
      IS
         SELECT ppos.person_id,
                TRUNC (NVL (ppos.actual_termination_date, SYSDATE)) actual_termination_date
           FROM per_periods_of_service ppos
          WHERE (   (    TRUNC (ppos.last_update_date) BETWEEN p_cut_off_date AND TRUNC (SYSDATE)
                     AND ppos.actual_termination_date IS NOT NULL
                    )
                 OR (    ppos.actual_termination_date IS NULL
                     AND ppos.person_id IN (
                            SELECT person_id
                              FROM per_all_people_f papf
                             WHERE SYSDATE BETWEEN papf.effective_start_date AND papf.effective_end_date
                               AND papf.current_employee_flag = 'Y')
                    )
                )
            AND ppos.business_group_id = p_business_group_id
         UNION          --Version 1.2  <Added new query to pick terminated employee element entries updated>
         SELECT DISTINCT ppos.person_id,
                         TRUNC (NVL (ppos.actual_termination_date, SYSDATE)) actual_termination_date
                    FROM per_all_assignments_f paf,
                         per_periods_of_service ppos,
                         pay_element_entries_f pee
                   WHERE paf.business_group_id = p_business_group_id
                     AND paf.primary_flag = 'Y'
                     AND pee.assignment_id = paf.assignment_id
                     AND paf.person_id = ppos.person_id
                     AND ppos.actual_termination_date IS NOT NULL
                     AND paf.period_of_service_id = ppos.period_of_service_id
                     AND ppos.actual_termination_date BETWEEN paf.effective_start_date
                                                          AND NVL (paf.effective_end_date,
                                                                   TRUNC (SYSDATE)
                                                                  )
                     AND (   TRUNC (pee.creation_date) BETWEEN p_cut_off_date AND TRUNC (SYSDATE)
                          OR TRUNC (pee.last_update_date) BETWEEN p_cut_off_date AND TRUNC (SYSDATE)
                         );

      CURSOR c_233_intf (p_person_id NUMBER, p_actual_termination_date DATE)               -- Version 1.1
      IS
         -- Query to generate absence element entries data for active employee
         SELECT   papfe.employee_number "Legajo", pet.element_name, pet.attribute4 "Tipo de Licencia",
                  NVL (TO_CHAR (TO_DATE (peevf.screen_entry_value, 'YYYY/MM/DD HH24:MI:SS'),
                                'DD/MM/YYYY'),
                       'N/A'
                      ) "Fecha Desde",
                  'Si' "Día Completo", '' "Hora Desde", '' "Hora Hasta", '' "Cantidad de Horas",
                  'Aprobada' "Estado"
             FROM per_all_people_f papfe,
                  per_all_assignments_f paf,
                  per_periods_of_service ppos,
                  pay_element_types_f pet,
                  pay_element_entries_f pee,
                  pay_input_values_f pivf,
                  pay_element_entry_values_f peevf
            WHERE papfe.business_group_id = p_business_group_id
              AND papfe.person_id = paf.person_id
              AND paf.primary_flag = 'Y'
              AND pet.element_type_id = pee.element_type_id
              AND pee.assignment_id = paf.assignment_id
              AND pivf.element_type_id = pet.element_type_id
              AND pee.element_entry_id = peevf.element_entry_id
              AND pivf.input_value_id = peevf.input_value_id
              AND pivf.display_sequence = '3'
              AND pet.attribute4 IS NOT NULL
              AND paf.person_id = ppos.person_id
              AND papfe.person_id = p_person_id
              AND paf.period_of_service_id = ppos.period_of_service_id
              AND p_actual_termination_date BETWEEN pet.effective_start_date AND pet.effective_end_date
              AND p_actual_termination_date BETWEEN pee.effective_start_date AND pee.effective_end_date
              AND p_actual_termination_date BETWEEN paf.effective_start_date AND paf.effective_end_date
              AND p_actual_termination_date BETWEEN pivf.effective_start_date AND pivf.effective_end_date
              AND p_actual_termination_date BETWEEN peevf.effective_start_date AND peevf.effective_end_date
              AND p_actual_termination_date BETWEEN papfe.effective_start_date AND papfe.effective_end_date
              AND ppos.actual_termination_date IS NULL          --Version 1.3
         UNION
         -- Query to generate employee absence element entries whose records have been updated or created between the run dates.
         SELECT   papfe.employee_number "Legajo", pet.element_name, pet.attribute4 "Tipo de Licencia",
                  NVL (TO_CHAR (TO_DATE (peevf.screen_entry_value, 'YYYY/MM/DD HH24:MI:SS'),
                                'DD/MM/YYYY'),
                       'N/A'
                      ) "Fecha Desde",
                  'Si' "Día Completo", '' "Hora Desde", '' "Hora Hasta", '' "Cantidad de Horas",
                  'Aprobada' "Estado"
             FROM per_all_people_f papfe,
                  per_all_assignments_f paf,
                  per_periods_of_service ppos,
                  pay_element_types_f pet,
                  pay_element_entries_f pee,
                  pay_input_values_f pivf,
                  pay_element_entry_values_f peevf
            WHERE papfe.business_group_id = p_business_group_id
              AND papfe.person_id = paf.person_id
              AND paf.primary_flag = 'Y'
              AND pet.element_type_id = pee.element_type_id
              AND pee.assignment_id = paf.assignment_id
              AND pivf.element_type_id = pet.element_type_id
              AND pee.element_entry_id = peevf.element_entry_id
              AND pivf.input_value_id = peevf.input_value_id
              AND pivf.display_sequence = '3'
              AND pet.attribute4 IS NOT NULL
              AND paf.person_id = ppos.person_id
              AND papfe.person_id = p_person_id
              AND paf.period_of_service_id = ppos.period_of_service_id
              AND p_actual_termination_date BETWEEN paf.effective_start_date AND paf.effective_end_date
              AND p_actual_termination_date BETWEEN papfe.effective_start_date AND papfe.effective_end_date
              AND (   TRUNC (pee.creation_date) BETWEEN p_cut_off_date AND TRUNC (SYSDATE)
                   OR TRUNC (pee.last_update_date) BETWEEN p_cut_off_date AND TRUNC (SYSDATE)
                  )
         ORDER BY 1;

      l_actual_completion_date   DATE DEFAULT NULL;
   BEGIN
      g_e_error_hand.module_name := 'init_233_intf';
      init_error_msg (g_e_error_hand.module_name);
      get_file_open (p_file_name);
      fnd_file.put_line (fnd_file.output, 'FILE_NAME -' || p_file_name);

        -- Version 1.1 <Start>
            /*BEGIN
               l_actual_completion_date := NULL;

      --- Query below retrieves last run date when the process was run successfully
               SELECT   NVL (MAX (TO_DATE (r.actual_completion_date)), TRUNC (SYSDATE - 1))
                   INTO l_actual_completion_date
                   FROM applsys.fnd_concurrent_requests r,
                        applsys.fnd_concurrent_programs p,
                        applsys.fnd_concurrent_programs_tl pt
                  WHERE r.concurrent_program_id = p.concurrent_program_id
                    AND p.concurrent_program_name = 'TTEC_ARG_RHPRO_OND_233_INTF'
                    AND p.concurrent_program_id = pt.concurrent_program_id
                    AND status_code = 'C'
                    AND pt.LANGUAGE = 'US'
               ORDER BY p.concurrent_program_name, r.actual_start_date DESC;
            EXCEPTION
               WHEN OTHERS
               THEN
                  l_actual_completion_date := TRUNC (SYSDATE - 1);
            END;

            fnd_file.put_line (fnd_file.output, 'Actual_Completion_Date -' || l_actual_completion_date);*/
            -- Version 1.1 <End>
      FOR r_emp_active IN c_emp_active
      LOOP
         FOR r_233_intf IN c_233_intf (r_emp_active.person_id, r_emp_active.actual_termination_date)
         LOOP
            fnd_file.put_line (fnd_file.output, 'START Employee No -' || r_233_intf."Legajo");

            BEGIN
               v_rec := NULL;
               v_rec :=
                     cvt_char (r_233_intf."Legajo")
                  || ';'
                  || cvt_char (r_233_intf."Tipo de Licencia")
                  || ';'
                  || r_233_intf."Fecha Desde"
                  || ';'
                  || r_233_intf."Fecha Desde"
                  || ';'
                  || r_233_intf."Día Completo"
                  || ';'
                  || r_233_intf."Hora Desde"
                  || ';'
                  || r_233_intf."Hora Hasta"
                  || ';'
                  || r_233_intf."Cantidad de Horas"
                  || ';'
                  || r_233_intf."Estado";
               UTL_FILE.put_line (v_output_file, v_rec);
               g_success_count := g_success_count + 1;
            END;

            fnd_file.put_line (fnd_file.output, 'END Employee No -' || r_233_intf."Legajo");
         END LOOP;
      END LOOP;

      print_count (g_success_count, g_error_count, g_e_error_hand.module_name);
      UTL_FILE.fclose (v_output_file);
   EXCEPTION
      WHEN UTL_FILE.invalid_operation
      THEN
         g_error_count := g_error_count + 1;
         print_count (g_success_count, g_error_count, g_e_error_hand.module_name);
         UTL_FILE.fclose (v_output_file);
         log_error ('SQLCODE', TO_CHAR (SQLCODE), 'Error Message', SUBSTR (SQLERRM, 1, 64));
         raise_application_error (-20051, v_full_file_path || ':  Invalid Operation');
         print_line ('Error in module: ' || g_e_error_hand.module_name);
         g_e_program_run_status := 1;
      WHEN UTL_FILE.invalid_filehandle
      THEN
         g_error_count := g_error_count + 1;
         print_count (g_success_count, g_error_count, g_e_error_hand.module_name);
         UTL_FILE.fclose (v_output_file);
         log_error ('SQLCODE', TO_CHAR (SQLCODE), 'Error Message', SUBSTR (SQLERRM, 1, 64));
         raise_application_error (-20052, v_full_file_path || ':  Invalid File Handle');
         print_line ('Error in module: ' || g_e_error_hand.module_name);
         g_e_program_run_status := 1;
      WHEN UTL_FILE.read_error
      THEN
         g_error_count := g_error_count + 1;
         print_count (g_success_count, g_error_count, g_e_error_hand.module_name);
         UTL_FILE.fclose (v_output_file);
         log_error ('SQLCODE', TO_CHAR (SQLCODE), 'Error Message', SUBSTR (SQLERRM, 1, 64));
         raise_application_error (-20053, v_full_file_path || ':  Read Error');
         print_line ('Error in module: ' || g_e_error_hand.module_name);
         g_e_program_run_status := 1;
      WHEN UTL_FILE.invalid_path
      THEN
         g_error_count := g_error_count + 1;
         print_count (g_success_count, g_error_count, g_e_error_hand.module_name);
         UTL_FILE.fclose (v_output_file);
         log_error ('SQLCODE', TO_CHAR (SQLCODE), 'Error Message', SUBSTR (SQLERRM, 1, 64));
         raise_application_error (-20054, v_dir_name || ':  Invalid Path');
         print_line ('Error in module: ' || g_e_error_hand.module_name);
         g_e_program_run_status := 1;
      WHEN UTL_FILE.invalid_mode
      THEN
         g_error_count := g_error_count + 1;
         print_count (g_success_count, g_error_count, g_e_error_hand.module_name);
         UTL_FILE.fclose (v_output_file);
         log_error ('SQLCODE', TO_CHAR (SQLCODE), 'Error Message', SUBSTR (SQLERRM, 1, 64));
         raise_application_error (-20055, v_full_file_path || ':  Invalid Mode');
         print_line ('Error in module: ' || g_e_error_hand.module_name);
         g_e_program_run_status := 1;
      WHEN UTL_FILE.write_error
      THEN
         g_error_count := g_error_count + 1;
         print_count (g_success_count, g_error_count, g_e_error_hand.module_name);
         UTL_FILE.fclose (v_output_file);
         log_error ('SQLCODE', TO_CHAR (SQLCODE), 'Error Message', SUBSTR (SQLERRM, 1, 64));
         raise_application_error (-20056, v_full_file_path || ':  Write Error');
         print_line ('Error in module: ' || g_e_error_hand.module_name);
         g_e_program_run_status := 1;
      WHEN UTL_FILE.internal_error
      THEN
         g_error_count := g_error_count + 1;
         print_count (g_success_count, g_error_count, g_e_error_hand.module_name);
         UTL_FILE.fclose (v_output_file);
         log_error ('SQLCODE', TO_CHAR (SQLCODE), 'Error Message', SUBSTR (SQLERRM, 1, 64));
         raise_application_error (-20057, v_full_file_path || ':  Internal Error');
         print_line ('Error in module: ' || g_e_error_hand.module_name);
         g_e_program_run_status := 1;
      WHEN UTL_FILE.invalid_maxlinesize
      THEN
         g_error_count := g_error_count + 1;
         print_count (g_success_count, g_error_count, g_e_error_hand.module_name);
         UTL_FILE.fclose (v_output_file);
         log_error ('SQLCODE', TO_CHAR (SQLCODE), 'Error Message', SUBSTR (SQLERRM, 1, 64));
         raise_application_error (-20058, v_full_file_path || ':  Maxlinesize Error');
         print_line ('Error in module: ' || g_e_error_hand.module_name);
         g_e_program_run_status := 1;
      WHEN NO_DATA_FOUND
      THEN
         g_error_count := g_error_count + 1;
         print_count (g_success_count, g_error_count, g_e_error_hand.module_name);
         UTL_FILE.fclose (v_output_file);
         log_error ('SQLCODE', TO_CHAR (SQLCODE), 'Error Message', SUBSTR (SQLERRM, 1, 64));
         print_line ('Error in module: ' || g_e_error_hand.module_name);
         v_msg := SQLERRM;
         raise_application_error (-20003, 'Exception NO_DATA_FOUND in init_233_intf' || v_msg);
         g_e_program_run_status := 1;
      WHEN OTHERS
      THEN
         g_error_count := g_error_count + 1;
         print_count (g_success_count, g_error_count, g_e_error_hand.module_name);
         UTL_FILE.fclose (v_output_file);
         log_error ('SQLCODE', TO_CHAR (SQLCODE), 'Error Message', SUBSTR (SQLERRM, 1, 64));
         print_line ('Error in module: ' || g_e_error_hand.module_name);
         v_msg := SQLERRM;
         raise_application_error (-20003, 'Exception OTHERS in init_233_intf' || v_msg);
         g_e_program_run_status := 1;
   END;

   PROCEDURE initial_main (
      errcode               OUT      VARCHAR2,
      errbuff               OUT      VARCHAR2,
      p_business_group_id   IN       NUMBER,
      p_previous_run_date   IN       VARCHAR2
   )
   IS
      l_cut_off_date   DATE;                                                              -- Version 1.1
   BEGIN
      init_error_msg ('Main');
      l_cut_off_date := TO_DATE (p_previous_run_date, 'YYYY/MM/DD HH24:MI:SS');
      init_233_intf (TO_CHAR (SYSDATE, 'YYYYMMDDHHMISS') || '_0233.txt',
                     p_business_group_id,
                     l_cut_off_date                                                        -- Version 1.1
                    );
   END;
END ttec_arg_rhpro_ond_233_intf;
/
show errors;
/