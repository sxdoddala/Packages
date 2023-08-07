create or replace PACKAGE BODY      ttec_arg_rhpro_ong_data_intf
AS
/*--------------------------------------------------------------------

Name:  ttec_arg_rhpro_ong_data_intf      (Package)
Description:   Data extraction - Argentina HR Data for the Payroll Vendor ( RHPro)
              The process is a daily interface to generate files on daily basis for new,
              updates, terms for all the employees in the system. Its run daily at the
              end of day for the daily updates.
Change History
Changed By        Date        Version       Reason for Change
---------        ----        ---------      -----------------
Kaushik Babu   17-AUG-2010    1.0           Initial Creation For Argentina -- TTSD R 424040
Kaushik Babu   09-DEC-2010    1.1           Fix for Special Character issue - TTSD R 466777
Kaushik Babu   16-DEC-2010    1.2           Fix Daily interface issues on all interfaces for future dated employee records to appear on the file - TTSD 476057
                                            Changed p_current_run_date on to GREATEST(p_current_run_date, ppos.date_start)
Kaushik Babu   10-JAN-2011    1.3           Fix Daily interface issue on 605 interface for not bringing terminated employee termed on last day of the month. TTSD 503945.
Kaushik Babu   11-JAN-2011    1.4           To pick employee who has changes on the client on client project form for 630 interface - TTSD 509806
                                            To pick employee who has changes on the costing on costing form for 317 interface - TTSD 509806
                                            Location, client department data for future changes on the employee records was not appearing and its fixed on 630 interface - TTSD 509806
Kaushik Babu   01-MAR-2011    1.5           Fixed code to send future-dated movements for bank account, contract, and address on 605 Interface TTSD 516259
Kaushik Babu   03-JUN-2011    1.6           a. Fixed code to get the latest supervisor on a 605 interface
                                            b. Fixed code to get the latest account details on a 605 interface
Kaushik Babu   25-AUG-2011    1.7           Fixed code to select extra information changes on 630 interface that happend on the future
                                            assignment records TTSD I 865747
IXPRAVEEN(ARGANO) 08-May-2023  1.0	        R12.2 Upgrade Remediation											
--------------------------------------------------------------------*/
   --g_e_error_hand           cust.ttec_error_handling%ROWTYPE;			-- Commented code by IXPRAVEEN-ARGANO,08-May-2023
   g_e_error_hand           apps.ttec_error_handling%ROWTYPE;			-- code Added by IXPRAVEEN-ARGANO,08-May-2023
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
      cust.ttec_process_error (g_e_error_hand.application_code,
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
      SELECT REPLACE (TRANSLATE (CONVERT (p_text || '  ', 'WE8ISO8859P1', 'UTF8'),
                                 '&:;'''',"´¨%^¿?#°',
                                 '&'
                                ),
                      '&',
                      ''
                     )                                                                      --Version 1.1
        INTO v_text
        FROM DUAL;

      RETURN (v_text);
   EXCEPTION
      WHEN OTHERS
      THEN
         v_text := p_text || '  ';                                                         --Version 1.1
         RETURN (v_text);
   END;

   --Function to generate PTO net accruals for every employee till the End of year.
   FUNCTION get_net_accrual (
      p_assignment_id       IN   NUMBER,
      p_plan_id             IN   NUMBER,
      p_payroll_id          IN   NUMBER,
      p_business_group_id   IN   NUMBER,
      p_calculation_date    IN   DATE
   )
      RETURN NUMBER
   AS
      l_accrual            NUMBER;
      l_other              NUMBER;
      l_carryover          NUMBER;
      l_start_date         DATE;
      l_end_date           DATE;
      l_accrual_end_date   DATE;
      l_entitlement        VARCHAR (20);
   BEGIN
      per_accrual_calc_functions.get_net_accrual (p_assignment_id               => p_assignment_id,
                                                  p_plan_id                     => p_plan_id,
                                                  p_payroll_id                  => p_payroll_id,
                                                  p_business_group_id           => p_business_group_id,
                                                  p_assignment_action_id        => -1,
                                                  p_calculation_date            => p_calculation_date,
                                                  p_accrual_start_date          => NULL,
                                                  p_accrual_latest_balance      => NULL,
                                                  p_start_date                  => l_start_date,
                                                  p_end_date                    => l_end_date,
                                                  p_accrual_end_date            => l_accrual_end_date,
                                                  p_accrual                     => l_accrual,
                                                  p_net_entitlement             => l_entitlement
                                                 );
      RETURN TO_NUMBER (l_accrual);
   EXCEPTION
      WHEN OTHERS
      THEN
         RETURN NULL;
   END;

   --The 605-Importación Empleados (Employees) interface will be run on a daily basis and will feed RHPro with all employee
   -- information for New Hires, Rehires, Updates, and Terminations
   PROCEDURE init_605_intf (
      p_file_name           IN   VARCHAR2,
      p_business_group_id        NUMBER,
      p_cut_off_date             DATE,
      p_current_run_date         DATE
   )
   IS
      CURSOR c_qry_record
      IS
         SELECT   person_id
             FROM (SELECT DISTINCT papfe.person_id
                              FROM apps.per_all_people_f papfe
                             WHERE papfe.business_group_id = p_business_group_id
                               AND (   TRUNC (papfe.creation_date) BETWEEN p_cut_off_date
                                                                       AND p_current_run_date
                                    OR TRUNC (papfe.last_update_date) BETWEEN p_cut_off_date
                                                                          AND p_current_run_date
                                   )
                   UNION
                   SELECT DISTINCT paafe.person_id
                              FROM apps.per_all_assignments_f paafe
                             WHERE paafe.business_group_id = p_business_group_id
                               AND (   TRUNC (paafe.creation_date) BETWEEN p_cut_off_date
                                                                       AND p_current_run_date
                                    OR TRUNC (paafe.last_update_date) BETWEEN p_cut_off_date
                                                                          AND p_current_run_date
                                   )
                   UNION
                   SELECT DISTINCT paaf.person_id
                              FROM apps.pay_personal_payment_methods_f pppmf, per_all_assignments_f paaf
                             WHERE pppmf.business_group_id = p_business_group_id
                               AND pppmf.external_account_id IS NOT NULL
                               AND paaf.primary_flag = 'Y'
                               AND paaf.assignment_id = pppmf.assignment_id
                               AND (   TRUNC (pppmf.creation_date) BETWEEN p_cut_off_date
                                                                       AND p_current_run_date
                                    OR TRUNC (pppmf.last_update_date) BETWEEN p_cut_off_date
                                                                          AND p_current_run_date
                                   )
                               AND (   p_cut_off_date BETWEEN paaf.effective_start_date
                                                          AND paaf.effective_end_date
                                    OR paaf.effective_start_date BETWEEN p_cut_off_date
                                                                     AND p_current_run_date
                                    OR paaf.effective_end_date BETWEEN p_cut_off_date AND p_current_run_date
                                   )
                   UNION
                   SELECT DISTINCT paaf.person_id
                              FROM apps.pay_personal_payment_methods_f pppmf,
                                   pay_external_accounts pea,
                                   per_all_assignments_f paaf
                             WHERE pppmf.business_group_id = p_business_group_id
                               AND paaf.assignment_id = pppmf.assignment_id
                               AND paaf.primary_flag = 'Y'
                               AND pppmf.external_account_id IS NOT NULL
                               AND pea.external_account_id = pppmf.external_account_id
                               AND (   p_cut_off_date BETWEEN paaf.effective_start_date
                                                          AND paaf.effective_end_date
                                    OR paaf.effective_start_date BETWEEN p_cut_off_date
                                                                     AND p_current_run_date
                                    OR paaf.effective_end_date BETWEEN p_cut_off_date AND p_current_run_date
                                   )
                               AND (   p_cut_off_date BETWEEN pppmf.effective_start_date
                                                          AND pppmf.effective_end_date
                                    OR pppmf.effective_start_date BETWEEN p_cut_off_date
                                                                      AND p_current_run_date
                                    OR pppmf.effective_end_date BETWEEN p_cut_off_date AND p_current_run_date
                                   )
                               AND (   TRUNC (pea.creation_date) BETWEEN p_cut_off_date
                                                                     AND p_current_run_date
                                    OR TRUNC (pea.last_update_date) BETWEEN p_cut_off_date
                                                                        AND p_current_run_date
                                   )
                   UNION
                   SELECT DISTINCT pcf.person_id
                              FROM apps.per_contracts_f pcf
                             WHERE pcf.business_group_id = p_business_group_id
                               AND (   TRUNC (pcf.creation_date) BETWEEN p_cut_off_date
                                                                     AND p_current_run_date
                                    OR TRUNC (pcf.last_update_date) BETWEEN p_cut_off_date
                                                                        AND p_current_run_date
                                   )
                   UNION
                   SELECT DISTINCT pad.person_id
                              FROM apps.per_addresses pad
                             WHERE pad.business_group_id = p_business_group_id
                               AND (   TRUNC (pad.creation_date) BETWEEN p_cut_off_date
                                                                     AND p_current_run_date
                                    OR TRUNC (pad.last_update_date) BETWEEN p_cut_off_date
                                                                        AND p_current_run_date
                                   )) DUAL
            WHERE person_id IS NOT NULL
         ORDER BY 1;

      CURSOR c_qry_exemp_emp (p_person_id NUMBER)
      IS
         SELECT   MAX (date_start) date_start,
                  MAX (NVL (actual_termination_date, GREATEST (p_current_run_date, date_start))
                      ) actual_termination_date,
                  person_id, MAX (actual_termination_date) term_date                       -- Version 1.2
             FROM per_periods_of_service ppos
            WHERE person_id = p_person_id
              AND business_group_id = p_business_group_id
              AND (   (    TRUNC (ppos.last_update_date) BETWEEN p_cut_off_date AND p_current_run_date
                       AND ppos.actual_termination_date IS NOT NULL
                      )
                   OR (    ppos.actual_termination_date IS NULL
                       AND ppos.person_id IN (SELECT DISTINCT person_id
                                                         FROM per_all_people_f papf
--                               WHERE p_current_run_date BETWEEN papf.effective_start_date         -- Version 1.2
--                                                            AND papf.effective_end_date
                                              WHERE           papf.current_employee_flag = 'Y')
                      )
                  )
         GROUP BY person_id;

      --Query to get the interface information for the updated record
      CURSOR c_605_upd (p_person_id NUMBER)
      IS
         SELECT DISTINCT papfe.employee_number "Numero de empleado", papfe.last_name "Apellido",
                         ppt.user_person_type, papfe.first_name || ' ' || papfe.middle_names "Nombres",
                         papfe.date_of_birth "F.Nacim",
                         NVL (ftl.territory_short_name, 'Sin Datos') "Pais de Nacimiento",
                         'N/A' "Fec.Ingreso al Pais", NVL (flvn.meaning, 'Sin Datos') "Nacionalidad",
                         NVL (flvm.meaning, 'Soltero') "Est.Civil", papfe.sex "Sexo",
                         CASE
                            WHEN papfe.start_date = ppos.date_start
                               THEN NVL (papfe.original_date_of_hire,
                                         (SELECT   MAX (ppos2.date_start)
                                              FROM per_periods_of_service ppos2
                                             WHERE ppos.person_id = ppos2.person_id
                                          GROUP BY ppos.person_id)
                                        )
                            ELSE (SELECT   MAX (ppos2.date_start)
                                      FROM per_periods_of_service ppos2
                                     WHERE ppos.person_id = ppos2.person_id
                                  GROUP BY ppos.person_id)
                         END "Fec de Alta",
                         'N/A' "Estudia", 'N/A' "Nivel de Estudio",
                         NVL (hfal.alternate_code, 'DNI') "Tipo Documento",
                         papfe.national_identifier "Nro. Documento",
                            SUBSTR (papfe.attribute7, 1, 2)
                         || '-'
                         || SUBSTR (papfe.attribute7, 3, 8)
                         || '-'
                         || SUBSTR (papfe.attribute7, 11, 1) "CUIL/RUT",
                         DECODE (ppt.system_person_type,
                                 'EX_EMP', 'N/A',
                                 NVL (pad.address_line1, 'N/A')
                                ) "Calle",
                         DECODE (ppt.system_person_type,
                                 'EX_EMP', 'N/A',
                                 NVL (pad.address_line2, 'N/A')
                                ) "Nro.",
                         DECODE (ppt.system_person_type,
                                 'EX_EMP', 'N/A',
                                 NVL (pad.address_line3, 'N/A')
                                ) "Piso",
                         DECODE (ppt.system_person_type,
                                 'EX_EMP', 'N/A',
                                 NVL (pad.add_information14, 'N/A')
                                ) "Depto",
                         'N/A' "Torre", 'N/A' "Manzana",
                         DECODE (ppt.system_person_type,
                                 'EX_EMP', 'N/A',
                                 NVL (pad.postal_code, 'N/A')
                                ) "Cpostal",
                         'N/A' "Entre Calles",
                         DECODE (ppt.system_person_type,
                                 'EX_EMP', 'N/A',
                                 NVL (pad.add_information17, 'N/A')
                                ) "Barrio",
                         DECODE (ppt.system_person_type,
                                 'EX_EMP', 'N/A',
                                 NVL (pad.add_information16, 'N/A')
                                ) "Localidad",
                         DECODE (ppt.system_person_type,
                                 'EX_EMP', 'N/A',
                                 NVL (pad.add_information15, 'N/A')
                                ) "Partido",
                         (CASE
                             WHEN ppt.system_person_type = 'EX_EMP'
                                THEN 'N/A'
                             WHEN hlc.attribute2 IS NOT NULL
                                THEN NVL ((SELECT lugar.alternate_code
                                             FROM apps.hr_fr_alternate_lookups lugar
                                            WHERE lugar.lookup_code = hlc.attribute2
                                              AND lugar.lookup_type = 'RHPRO_ARG_ZONA'
                                              AND lugar.function_type = 'Zona SIJP'
                                              AND p_current_run_date BETWEEN lugar.effective_start_date
                                                                         AND lugar.effective_end_date),
                                          (SELECT lugar.alternate_code
                                             FROM apps.hr_fr_alternate_lookups lugar
                                            WHERE UPPER (lugar.lookup_code) = 'OTHER'
                                              AND lugar.lookup_type = 'RHPRO_ARG_ZONA'
                                              AND lugar.function_type = 'Zona SIJP'
                                              AND p_current_run_date BETWEEN lugar.effective_start_date
                                                                         AND lugar.effective_end_date)
                                         )
                             ELSE (SELECT lugar.alternate_code
                                     FROM apps.hr_fr_alternate_lookups lugar
                                    WHERE UPPER (lugar.lookup_code) = 'OTHER'
                                      AND lugar.lookup_type = 'RHPRO_ARG_ZONA'
                                      AND lugar.function_type = 'Zona SIJP'
                                      AND p_current_run_date BETWEEN lugar.effective_start_date
                                                                 AND lugar.effective_end_date)
                          END
                         ) "Zona",                                   --Area code for government reporting
                         DECODE (ppt.system_person_type,
                                 'EX_EMP', 'N/A',
                                 NVL (flvsp.description, 'Sin Datos')
                                ) "Provincia",
                         DECODE (ppt.system_person_type,
                                 'EX_EMP', 'N/A',
                                 NVL (flvcc.meaning, 'Argentina')
                                ) "País",                                          --country of residence
                         'N/A' "Telefono Particular", 'N/A' "Telefono Laboral", 'N/A' "Telefono Celular",
                         'N/A' "E-mail", 'N/A' "Sucursal", 'N/A' "Sector", 'N/A' "Convenio",
                         'N/A' "Categoria", 'N/A' "puesto", 'N/A' "Gerencia", 'N/A' "Departamento",
                         'N/A' "Direccion",
                         (CASE
                             WHEN ppt.system_person_type = 'EX_EMP'
                                THEN 'N/A'
                             ELSE (SELECT alternate_code
                                     FROM hr_fr_alternate_lookups
                                    WHERE lookup_code = 'JUB'
                                      AND lookup_type = 'RHPRO_ARG_DEFAULTS'
                                      AND function_type = 'Default Value'
                                      AND p_current_run_date BETWEEN effective_start_date
                                                                 AND effective_end_date)
                          END
                         ) "Caja de Jubilacion AFJP",
                         (CASE
                             WHEN ppt.system_person_type = 'EX_EMP'
                                THEN 'N/A'
                             ELSE (SELECT alternate_code
                                     FROM hr_fr_alternate_lookups
                                    WHERE lookup_code = 'SIN'
                                      AND lookup_type = 'RHPRO_ARG_DEFAULTS'
                                      AND function_type = 'Default Value'
                                      AND p_current_run_date BETWEEN effective_start_date
                                                                 AND effective_end_date)
                          END
                         ) "Sindicato",
                         'N/A' "Obra Social Ley", 'N/A' "Plan OS Ley", 'N/A' "Obra Social Elegida",
                         'N/A' "Plan OS Elegida",
                         DECODE (ppt.system_person_type,
                                 'EX_EMP', 'N/A',
                                 NVL (pcflv.meaning, 'N/A')
                                ) "Contrato",
                         'N/A' "Fecha de Vto. Contrato",
                         (CASE
                             WHEN ppt.system_person_type = 'EX_EMP'
                                THEN 'N/A'
                             WHEN hlc.attribute2 IS NOT NULL
                                THEN NVL ((SELECT lugar.alternate_code
                                             FROM apps.hr_fr_alternate_lookups lugar
                                            WHERE lugar.lookup_code = hlc.attribute2
                                              AND lugar.lookup_type = 'RHPRO_ARG_ZONA'
                                              AND lugar.function_type = 'Lugar de Pago'
                                              AND p_current_run_date BETWEEN lugar.effective_start_date
                                                                         AND lugar.effective_end_date),
                                          (SELECT lugar.alternate_code
                                             FROM apps.hr_fr_alternate_lookups lugar
                                            WHERE UPPER (lugar.lookup_code) = 'OTHER'
                                              AND lugar.lookup_type = 'RHPRO_ARG_ZONA'
                                              AND lugar.function_type = 'Lugar de Pago'
                                              AND p_current_run_date BETWEEN lugar.effective_start_date
                                                                         AND lugar.effective_end_date)
                                         )
                             ELSE (SELECT lugar.alternate_code
                                     FROM apps.hr_fr_alternate_lookups lugar
                                    WHERE UPPER (lugar.lookup_code) = 'OTHER'
                                      AND lugar.lookup_type = 'RHPRO_ARG_ZONA'
                                      AND lugar.function_type = 'Lugar de Pago'
                                      AND p_current_run_date BETWEEN lugar.effective_start_date
                                                                 AND lugar.effective_end_date)
                          END
                         ) "Lugar de Pago",
                         'N/A' "Regimen Horario",
                         (CASE
                             WHEN ppt.system_person_type = 'EX_EMP'
                                THEN 'N/A'
                             ELSE (SELECT alternate_code
                                     FROM hr_fr_alternate_lookups
                                    WHERE lookup_code = 'LIQ'
                                      AND lookup_type = 'RHPRO_ARG_DEFAULTS'
                                      AND function_type = 'Default Value'
                                      AND p_current_run_date BETWEEN effective_start_date
                                                                 AND effective_end_date)
                          END
                         ) "Forma de Liquidacion",
                         DECODE (ppt.system_person_type,
                                 'EX_EMP', 'N/A',
                                 NVL (ffvtpat.description, 'N/A')
                                ) "Forma de Pago",
                         DECODE (ppt.system_person_type,
                                 'EX_EMP', 'N/A',
                                 NVL (ffvtpab.description, 'N/A')
                                ) "Banco Pago",
                         DECODE (ppt.system_person_type,
                                 'EX_EMP', 'N/A',
                                 NVL (pea.segment4, 'N/A')
                                ) "Nro. Cuenta",
                         'N/A' "Nro. CBU",
                         DECODE (ppt.system_person_type,
                                 'EX_EMP', 'N/A',
                                 NVL (pea.segment2, 'N/A')
                                ) "Sucursal Banco",
                         (CASE
                             WHEN ppt.system_person_type = 'EX_EMP'
                                THEN 'N/A'
                             ELSE (SELECT alternate_code
                                     FROM hr_fr_alternate_lookups
                                    WHERE lookup_code = 'CTA'
                                      AND lookup_type = 'RHPRO_ARG_DEFAULTS'
                                      AND function_type = 'Default Value'
                                      AND p_current_run_date BETWEEN effective_start_date
                                                                 AND effective_end_date)
                          END
                         ) "Cta. Acreditacion Empresa",
                         (CASE
                             WHEN ppt.system_person_type = 'EX_EMP'
                                THEN 'N/A'
                             ELSE (SELECT alternate_code
                                     FROM hr_fr_alternate_lookups
                                    WHERE lookup_code = 'ACT'
                                      AND lookup_type = 'RHPRO_ARG_DEFAULTS'
                                      AND function_type = 'Default Value'
                                      AND p_current_run_date BETWEEN effective_start_date
                                                                 AND effective_end_date)
                          END
                         ) "Actividad SIJP",
                         (CASE
                             WHEN ppt.system_person_type = 'EX_EMP'
                                THEN 'N/A'
                             ELSE (SELECT alternate_code
                                     FROM hr_fr_alternate_lookups
                                    WHERE lookup_code = 'CON'
                                      AND lookup_type = 'RHPRO_ARG_DEFAULTS'
                                      AND function_type = 'Default Value'
                                      AND p_current_run_date BETWEEN effective_start_date
                                                                 AND effective_end_date)
                          END
                         ) "Condicion SIJP",
                         (CASE
                             WHEN ppt.system_person_type = 'EX_EMP'
                                THEN 'N/A'
                             ELSE (SELECT alternate_code
                                     FROM hr_fr_alternate_lookups
                                    WHERE lookup_code = 'SIT'
                                      AND lookup_type = 'RHPRO_ARG_DEFAULTS'
                                      AND function_type = 'Default Value'
                                      AND p_current_run_date BETWEEN effective_start_date
                                                                 AND effective_end_date)
                          END
                         ) "Sit.de Revista SIJP",
                         (CASE
                             WHEN ppt.system_person_type = 'EX_EMP'
                                THEN 'N/A'
                             ELSE (SELECT alternate_code
                                     FROM hr_fr_alternate_lookups
                                    WHERE lookup_code = 'ART'
                                      AND lookup_type = 'RHPRO_ARG_DEFAULTS'
                                      AND function_type = 'Default Value'
                                      AND p_current_run_date BETWEEN effective_start_date
                                                                 AND effective_end_date)
                          END
                         ) "ART",
                         DECODE (ppt.system_person_type,
                                 'EX_EMP', 'Inactivo',
                                 'Activo'
                                ) "Estado del Empleado",
                         'N/A' "Causa de Baja", 'N/A' "Fecha de Baja",
                         (CASE
                             WHEN ppt.system_person_type = 'EX_EMP'
                                THEN 'N/A'
                             ELSE (SELECT alternate_code
                                     FROM hr_fr_alternate_lookups
                                    WHERE lookup_code = 'EMP'
                                      AND lookup_type = 'RHPRO_ARG_DEFAULTS'
                                      AND function_type = 'Default Value'
                                      AND p_current_run_date BETWEEN effective_start_date
                                                                 AND effective_end_date)
                          END
                         ) "Empresa",                                                      -- Version 1.2
                         'N/A' "Remuneracion",
                         (CASE
                             WHEN ppt.system_person_type = 'EX_EMP'
                                THEN 'N/A'
                             ELSE (SELECT alternate_code
                                     FROM hr_fr_alternate_lookups
                                    WHERE lookup_code = 'MOD'
                                      AND lookup_type = 'RHPRO_ARG_DEFAULTS'
                                      AND function_type = 'Default Value'
                                      AND p_current_run_date BETWEEN effective_start_date
                                                                 AND effective_end_date)
                          END
                         ) "Modelo Organizacional",                                        -- Version 1.2
                         DECODE (papfe2.business_group_id,
                                 1632, papfe2.employee_number,
                                 'N/A'
                                ) "Reporta_a (Empleado)",                                  -- Version 1.2
                         'N/A' "Grupo de seguridad", ppt.system_person_type, paafe.assignment_id,
                         papfe.person_id
                    FROM per_all_people_f papfe,
                         per_person_type_usages_f pptuf,
                         per_person_types ppt,
                         per_all_assignments_f paafe,
                         per_periods_of_service ppos,
                         apps.fnd_territories_tl ftl,
                         apps.fnd_lookup_values flvn,
                         apps.fnd_lookup_values flvm,
                         apps.hr_fr_alternate_lookups hfal,
                         apps.per_addresses pad,
                         apps.fnd_lookup_values flvsp,
                         apps.fnd_lookup_values flvcc,
                         apps.hr_locations hlc,
                         per_contracts_f pcf,
                         apps.fnd_lookup_values pcflv,
                         apps.fnd_flex_values ffvpat,
                         apps.fnd_flex_values_tl ffvtpat,
                         apps.pay_personal_payment_methods_f pppmf,
                         apps.pay_external_accounts pea,
                         apps.fnd_flex_values ffvpab,
                         apps.fnd_flex_values_tl ffvtpab,
                         apps.per_all_people_f papfe2
                   WHERE papfe.business_group_id = p_business_group_id
                     AND paafe.person_id = papfe.person_id
                     AND paafe.primary_flag = 'Y'
                     AND papfe.person_id = p_person_id
                     AND papfe.person_id = ppos.person_id
                     AND pptuf.person_id = papfe.person_id
                     AND ppt.person_type_id = pptuf.person_type_id
                     AND UPPER (ppt.user_person_type) IN ('EMPLOYEE')
                     AND ppos.period_of_service_id = paafe.period_of_service_id
                     AND papfe.employee_number IS NOT NULL
                     AND papfe.country_of_birth = ftl.territory_code(+)
                     AND ftl.LANGUAGE(+) = 'ESA'
                     AND papfe.nationality = flvn.lookup_code(+)
                     AND flvn.lookup_type(+) = 'NATIONALITY'
                     AND flvn.LANGUAGE(+) = 'ESA'
                     AND flvn.security_group_id(+) = '24'
                     AND flvn.enabled_flag(+) = 'Y'
                     AND papfe.marital_status = flvm.lookup_code(+)
                     AND flvm.lookup_type(+) = 'MAR_STATUS'
                     AND flvm.LANGUAGE(+) = 'ESA'
                     AND flvm.security_group_id(+) = '24'
                     AND flvm.enabled_flag(+) = 'Y'
                     AND papfe.attribute6 = hfal.lookup_code(+)
                     AND hfal.lookup_type(+) = 'RHPRO_ARG_ID_TYPE'
                     AND hfal.function_type(+) = 'ID Type'
                     AND papfe.person_id = pad.person_id(+)
                     AND pad.region_1 = flvsp.lookup_code(+)
                     AND flvsp.lookup_type(+) = 'JLZZ_STATE_PROVINCE'
                     AND flvsp.LANGUAGE(+) = 'ESA'
                     AND flvsp.enabled_flag(+) = 'Y'
                     AND pad.country = flvcc.lookup_code(+)
                     AND flvcc.lookup_type(+) = 'JEES_EURO_COUNTRY_CODES'
                     AND flvcc.LANGUAGE(+) = 'ESA'
                     AND flvcc.enabled_flag(+) = 'Y'
                     AND paafe.location_id = hlc.location_id(+)
                     AND pcf.person_id(+) = paafe.person_id
                     AND pcflv.lookup_code(+) = pcf.TYPE
                     AND pcflv.lookup_type(+) = 'CONTRACT_TYPE'
                     AND pcflv.LANGUAGE(+) = 'ESA'
                     AND pppmf.assignment_id(+) = paafe.assignment_id
                     AND pea.external_account_id(+) = pppmf.external_account_id
                     AND pppmf.external_account_id(+) IS NOT NULL
                     AND ffvpat.flex_value_set_id(+) = '1010073'
                     AND ffvpat.flex_value_id = ffvtpat.flex_value_id(+)
                     AND ffvpat.flex_value(+) = pea.segment3
                     AND ffvtpat.LANGUAGE(+) = 'ESA'
                     AND ffvpab.flex_value_set_id(+) = '1010052'
                     AND ffvpab.flex_value_id = ffvtpab.flex_value_id(+)
                     AND ffvpab.flex_value(+) = pea.segment1
                     AND ffvtpab.LANGUAGE(+) = 'ESA'
                     AND paafe.supervisor_id = papfe2.person_id(+)
                     AND papfe2.current_employee_flag = 'Y'
                     AND p_current_run_date BETWEEN papfe2.effective_start_date(+) AND papfe2.effective_end_date(+)
                     AND p_current_run_date BETWEEN pppmf.effective_start_date(+) AND pppmf.effective_end_date(+)
                     AND p_current_run_date BETWEEN pcf.effective_start_date(+) AND pcf.effective_end_date(+)
                     AND p_current_run_date BETWEEN hfal.effective_start_date(+) AND hfal.effective_end_date(+)
                     AND p_current_run_date BETWEEN paafe.effective_start_date AND paafe.effective_end_date
                     AND p_current_run_date BETWEEN papfe.effective_start_date AND papfe.effective_end_date
                     AND p_current_run_date BETWEEN pptuf.effective_start_date AND pptuf.effective_end_date
                     AND p_current_run_date BETWEEN pad.date_from(+) AND NVL (pad.date_to(+),
                                                                              p_current_run_date)
                     AND p_current_run_date BETWEEN ppos.date_start
                                                AND NVL (ppos.actual_termination_date,
                                                         p_current_run_date)
                ORDER BY 1;

      --Query to get the interface information for the new and teminated record
      CURSOR c_605_new_term (p_person_id NUMBER, p_actual_termination_date DATE)
      IS
         SELECT *
           FROM (SELECT DISTINCT papfe.employee_number "Numero de empleado", papfe.last_name "Apellido",
                                 ppt.user_person_type,
                                 papfe.first_name || ' ' || papfe.middle_names "Nombres",
                                 papfe.date_of_birth "F.Nacim",
                                 NVL (ftl.territory_short_name, 'Sin Datos') "Pais de Nacimiento",
                                 'N/A' "Fec.Ingreso al Pais",
                                 NVL (flvn.meaning, 'Sin Datos') "Nacionalidad",
                                 NVL (flvm.meaning, 'Soltero') "Est.Civil", papfe.sex "Sexo",
                                 CASE
                                    WHEN papfe.start_date = ppos.date_start
                                       THEN NVL (papfe.original_date_of_hire,
                                                 (SELECT   MAX (ppos2.date_start)
                                                      FROM per_periods_of_service ppos2
                                                     WHERE ppos.person_id = ppos2.person_id
                                                  GROUP BY ppos.person_id)
                                                )
                                    ELSE (SELECT   MAX (ppos2.date_start)
                                              FROM per_periods_of_service ppos2
                                             WHERE ppos.person_id = ppos2.person_id
                                          GROUP BY ppos.person_id)
                                 END "Fec de Alta",
                                 'N/A' "Estudia", 'N/A' "Nivel de Estudio",
                                 NVL (hfal.alternate_code, 'DNI') "Tipo Documento",
                                 papfe.national_identifier "Nro. Documento",
                                    SUBSTR (papfe.attribute7, 1, 2)
                                 || '-'
                                 || SUBSTR (papfe.attribute7, 3, 8)
                                 || '-'
                                 || SUBSTR (papfe.attribute7, 11, 1) "CUIL/RUT",
                                 DECODE (ppt.system_person_type,
                                         'EX_EMP', 'N/A',
                                         NVL (pad.address_line1, 'N/A')
                                        ) "Calle",
                                 DECODE (ppt.system_person_type,
                                         'EX_EMP', 'N/A',
                                         NVL (pad.address_line2, 'N/A')
                                        ) "Nro.",
                                 DECODE (ppt.system_person_type,
                                         'EX_EMP', 'N/A',
                                         NVL (pad.address_line3, 'N/A')
                                        ) "Piso",
                                 DECODE (ppt.system_person_type,
                                         'EX_EMP', 'N/A',
                                         NVL (pad.add_information14, 'N/A')
                                        ) "Depto",
                                 'N/A' "Torre", 'N/A' "Manzana",
                                 DECODE (ppt.system_person_type,
                                         'EX_EMP', 'N/A',
                                         NVL (pad.postal_code, 'N/A')
                                        ) "Cpostal",
                                 'N/A' "Entre Calles",
                                 DECODE (ppt.system_person_type,
                                         'EX_EMP', 'N/A',
                                         NVL (pad.add_information17, 'N/A')
                                        ) "Barrio",
                                 DECODE (ppt.system_person_type,
                                         'EX_EMP', 'N/A',
                                         NVL (pad.add_information16, 'N/A')
                                        ) "Localidad",
                                 DECODE (ppt.system_person_type,
                                         'EX_EMP', 'N/A',
                                         NVL (pad.add_information15, 'N/A')
                                        ) "Partido",
                                 (CASE
                                     WHEN ppt.system_person_type = 'EX_EMP'
                                        THEN 'N/A'
                                     WHEN hlc.attribute2 IS NOT NULL
                                        THEN NVL
                                               ((SELECT lugar.alternate_code
                                                   FROM apps.hr_fr_alternate_lookups lugar
                                                  WHERE lugar.lookup_code = hlc.attribute2
                                                    AND lugar.lookup_type = 'RHPRO_ARG_ZONA'
                                                    AND lugar.function_type = 'Zona SIJP'
                                                    AND p_current_run_date
                                                           BETWEEN lugar.effective_start_date
                                                               AND lugar.effective_end_date),
                                                (SELECT lugar.alternate_code
                                                   FROM apps.hr_fr_alternate_lookups lugar
                                                  WHERE UPPER (lugar.lookup_code) = 'OTHER'
                                                    AND lugar.lookup_type = 'RHPRO_ARG_ZONA'
                                                    AND lugar.function_type = 'Zona SIJP'
                                                    AND p_current_run_date
                                                           BETWEEN lugar.effective_start_date
                                                               AND lugar.effective_end_date)
                                               )
                                     ELSE (SELECT lugar.alternate_code
                                             FROM apps.hr_fr_alternate_lookups lugar
                                            WHERE UPPER (lugar.lookup_code) = 'OTHER'
                                              AND lugar.lookup_type = 'RHPRO_ARG_ZONA'
                                              AND lugar.function_type = 'Zona SIJP'
                                              AND p_current_run_date BETWEEN lugar.effective_start_date
                                                                         AND lugar.effective_end_date)
                                  END
                                 ) "Zona",
                                 DECODE (ppt.system_person_type,
                                         'EX_EMP', 'N/A',
                                         NVL (flvsp.description, 'Sin Datos')
                                        ) "Provincia",
                                 DECODE (ppt.system_person_type,
                                         'EX_EMP', 'N/A',
                                         NVL (flvcc.meaning, 'Argentina')
                                        ) "País",
                                 'N/A' "Telefono Particular", 'N/A' "Telefono Laboral",
                                 'N/A' "Telefono Celular", 'N/A' "E-mail",
                                 DECODE (ppt.system_person_type,
                                         'EX_EMP', 'N/A',
                                         NVL (hlc.location_code, 'N/A')
                                        ) "Sucursal",
                                 DECODE (ppt.system_person_type,
                                         'EX_EMP', 'N/A',
                                         NVL (   tempa.clt_cd
                                              || ' '
                                              || DECODE (tempa.clt_cd,
                                                         '4001', 'ORANGE - IB CUSTOMER CARE',
                                                         tempa.client_desc
                                                        ),
                                              'N/A'
                                             )
                                        ) "Sector",
                                 DECODE (ppt.system_person_type,
                                         'EX_EMP', 'N/A',
                                         NVL (ffvt.description, 'N/A')
                                        ) "Convenio",
                                 DECODE
                                     (ppt.system_person_type,
                                      'EX_EMP', 'N/A',
                                      CASE
                                         WHEN paafe.ass_attribute11 = '13075'
                                            THEN NVL (flvcat.meaning, 'N/A')
                                         ELSE 'Fuera de Convenio'
                                      END
                                     ) "Categoria",
                                 DECODE
                                    (ppt.system_person_type,
                                     'EX_EMP', 'N/A',
                                     CASE
                                        WHEN paafe.ass_attribute11 = '13075'
                                           THEN NVL (paafe.ass_attribute15,
                                                     NVL (pj.attribute15, pjd.segment2)
                                                    )
                                        ELSE pjd.segment2
                                     END
                                    ) "puesto",
                                 DECODE (ppt.system_person_type,
                                         'EX_EMP', 'N/A',
                                         NVL (pj.attribute14, 'N/A')
                                        ) "Gerencia",
                                 DECODE (ppt.system_person_type,
                                         'EX_EMP', 'N/A',
                                         NVL (haou.NAME, 'N/A')
                                        ) "Departamento",
                                 'N/A' "Direccion",
                                 (CASE
                                     WHEN ppt.system_person_type = 'EX_EMP'
                                        THEN 'N/A'
                                     ELSE (SELECT alternate_code
                                             FROM hr_fr_alternate_lookups
                                            WHERE lookup_code = 'JUB'
                                              AND lookup_type = 'RHPRO_ARG_DEFAULTS'
                                              AND function_type = 'Default Value'
                                              AND p_current_run_date BETWEEN effective_start_date
                                                                         AND effective_end_date)
                                  END
                                 ) "Caja de Jubilacion AFJP",
                                 (CASE
                                     WHEN ppt.system_person_type = 'EX_EMP'
                                        THEN 'N/A'
                                     ELSE (SELECT alternate_code
                                             FROM hr_fr_alternate_lookups
                                            WHERE lookup_code = 'SIN'
                                              AND lookup_type = 'RHPRO_ARG_DEFAULTS'
                                              AND function_type = 'Default Value'
                                              AND p_current_run_date BETWEEN effective_start_date
                                                                         AND effective_end_date)
                                  END
                                 ) "Sindicato",
                                 DECODE (ppt.system_person_type,
                                         'EX_EMP', 'N/A',
                                         NVL (pei.pei_information1, 'N/A')
                                        ) "Obra Social Ley",
                                 'N/A' "Plan OS Ley",
                                 DECODE (ppt.system_person_type,
                                         'EX_EMP', 'N/A',
                                         NVL (pei.pei_information1, 'N/A')
                                        ) "Obra Social Elegida",
                                 'N/A' "Plan OS Elegida",
                                 DECODE (ppt.system_person_type,
                                         'EX_EMP', 'N/A',
                                         NVL (pcflv.meaning, 'N/A')
                                        ) "Contrato",
                                 'N/A' "Fecha de Vto. Contrato",
                                 (CASE
                                     WHEN ppt.system_person_type = 'EX_EMP'
                                        THEN 'N/A'
                                     WHEN hlc.attribute2 IS NOT NULL
                                        THEN NVL
                                               ((SELECT lugar.alternate_code
                                                   FROM apps.hr_fr_alternate_lookups lugar
                                                  WHERE lugar.lookup_code = hlc.attribute2
                                                    AND lugar.lookup_type = 'RHPRO_ARG_ZONA'
                                                    AND lugar.function_type = 'Lugar de Pago'
                                                    AND p_current_run_date
                                                           BETWEEN lugar.effective_start_date
                                                               AND lugar.effective_end_date),
                                                (SELECT lugar.alternate_code
                                                   FROM apps.hr_fr_alternate_lookups lugar
                                                  WHERE UPPER (lugar.lookup_code) = 'OTHER'
                                                    AND lugar.lookup_type = 'RHPRO_ARG_ZONA'
                                                    AND lugar.function_type = 'Lugar de Pago'
                                                    AND p_current_run_date
                                                           BETWEEN lugar.effective_start_date
                                                               AND lugar.effective_end_date)
                                               )
                                     ELSE (SELECT lugar.alternate_code
                                             FROM apps.hr_fr_alternate_lookups lugar
                                            WHERE UPPER (lugar.lookup_code) = 'OTHER'
                                              AND lugar.lookup_type = 'RHPRO_ARG_ZONA'
                                              AND lugar.function_type = 'Lugar de Pago'
                                              AND p_current_run_date BETWEEN lugar.effective_start_date
                                                                         AND lugar.effective_end_date)
                                  END
                                 ) "Lugar de Pago",
                                 DECODE (ppt.system_person_type,
                                         'EX_EMP', 'N/A',
                                         NVL (flvecat.meaning, 'N/A')
                                        ) "Regimen Horario",
                                 (CASE
                                     WHEN ppt.system_person_type = 'EX_EMP'
                                        THEN 'N/A'
                                     ELSE (SELECT alternate_code
                                             FROM hr_fr_alternate_lookups
                                            WHERE lookup_code = 'LIQ'
                                              AND lookup_type = 'RHPRO_ARG_DEFAULTS'
                                              AND function_type = 'Default Value'
                                              AND p_current_run_date BETWEEN effective_start_date
                                                                         AND effective_end_date)
                                  END
                                 ) "Forma de Liquidacion",
                                 DECODE (ppt.system_person_type,
                                         'EX_EMP', 'N/A',
                                         NVL (ffvtpat.description, 'N/A')
                                        ) "Forma de Pago",
                                 DECODE (ppt.system_person_type,
                                         'EX_EMP', 'N/A',
                                         NVL (ffvtpab.description, 'N/A')
                                        ) "Banco Pago",
                                 DECODE (ppt.system_person_type,
                                         'EX_EMP', 'N/A',
                                         NVL (pea.segment4, 'N/A')
                                        ) "Nro. Cuenta",
                                 'N/A' "Nro. CBU",
                                 DECODE (ppt.system_person_type,
                                         'EX_EMP', 'N/A',
                                         NVL (pea.segment2, 'N/A')
                                        ) "Sucursal Banco",
                                 (CASE
                                     WHEN ppt.system_person_type = 'EX_EMP'
                                        THEN 'N/A'
                                     ELSE (SELECT alternate_code
                                             FROM hr_fr_alternate_lookups
                                            WHERE lookup_code = 'CTA'
                                              AND lookup_type = 'RHPRO_ARG_DEFAULTS'
                                              AND function_type = 'Default Value'
                                              AND p_current_run_date BETWEEN effective_start_date
                                                                         AND effective_end_date)
                                  END
                                 ) "Cta. Acreditacion Empresa",
                                 (CASE
                                     WHEN ppt.system_person_type = 'EX_EMP'
                                        THEN 'N/A'
                                     ELSE (SELECT alternate_code
                                             FROM hr_fr_alternate_lookups
                                            WHERE lookup_code = 'ACT'
                                              AND lookup_type = 'RHPRO_ARG_DEFAULTS'
                                              AND function_type = 'Default Value'
                                              AND p_current_run_date BETWEEN effective_start_date
                                                                         AND effective_end_date)
                                  END
                                 ) "Actividad SIJP",
                                 (CASE
                                     WHEN ppt.system_person_type = 'EX_EMP'
                                        THEN 'N/A'
                                     ELSE (SELECT alternate_code
                                             FROM hr_fr_alternate_lookups
                                            WHERE lookup_code = 'CON'
                                              AND lookup_type = 'RHPRO_ARG_DEFAULTS'
                                              AND function_type = 'Default Value'
                                              AND p_current_run_date BETWEEN effective_start_date
                                                                         AND effective_end_date)
                                  END
                                 ) "Condicion SIJP",
                                 (CASE
                                     WHEN ppt.system_person_type = 'EX_EMP'
                                        THEN 'N/A'
                                     ELSE (SELECT alternate_code
                                             FROM hr_fr_alternate_lookups
                                            WHERE lookup_code = 'SIT'
                                              AND lookup_type = 'RHPRO_ARG_DEFAULTS'
                                              AND function_type = 'Default Value'
                                              AND p_current_run_date BETWEEN effective_start_date
                                                                         AND effective_end_date)
                                  END
                                 ) "Sit.de Revista SIJP",
                                 (CASE
                                     WHEN ppt.system_person_type = 'EX_EMP'
                                        THEN 'N/A'
                                     ELSE (SELECT alternate_code
                                             FROM hr_fr_alternate_lookups
                                            WHERE lookup_code = 'ART'
                                              AND lookup_type = 'RHPRO_ARG_DEFAULTS'
                                              AND function_type = 'Default Value'
                                              AND p_current_run_date BETWEEN effective_start_date
                                                                         AND effective_end_date)
                                  END
                                 ) "ART",
                                 DECODE (ppt.system_person_type,
                                         'EX_EMP', 'Inactivo',
                                         'Activo'
                                        ) "Estado del Empleado",
                                 DECODE (ppt.system_person_type,
                                         'EX_EMP', NVL (SUBSTR (ppos.attribute12, 1, 60), 'Sin Datos'),
                                         'N/A'
                                        ) "Causa de Baja",
                                 DECODE
                                      (ppt.system_person_type,
                                       'EX_EMP', TO_CHAR (NVL (TO_DATE (ppos.attribute1,
                                                                        'YYYY/MM/DD HH24:MI:SS'
                                                                       ),
                                                               ppos.actual_termination_date
                                                              ),
                                                          'DD/MM/YYYY'
                                                         ),
                                       'N/A'
                                      ) "Fecha de Baja",
                                 (CASE
                                     WHEN ppt.system_person_type = 'EX_EMP'
                                        THEN 'N/A'
                                     ELSE (SELECT alternate_code
                                             FROM hr_fr_alternate_lookups
                                            WHERE lookup_code = 'EMP'
                                              AND lookup_type = 'RHPRO_ARG_DEFAULTS'
                                              AND function_type = 'Default Value'
                                              AND p_current_run_date BETWEEN effective_start_date
                                                                         AND effective_end_date)
                                  END
                                 ) "Empresa",
                                 'N/A' "Remuneracion",
                                 (CASE
                                     WHEN ppt.system_person_type = 'EX_EMP'
                                        THEN 'N/A'
                                     ELSE (SELECT alternate_code
                                             FROM hr_fr_alternate_lookups
                                            WHERE lookup_code = 'MOD'
                                              AND lookup_type = 'RHPRO_ARG_DEFAULTS'
                                              AND function_type = 'Default Value'
                                              AND p_current_run_date BETWEEN effective_start_date
                                                                         AND effective_end_date)
                                  END
                                 ) "Modelo Organizacional",
                                 DECODE (ppt.system_person_type,
                                         'EX_EMP', 'N/A',
                                         DECODE (papfe2.business_group_id,
                                                 1632, papfe2.employee_number,
                                                 'N/A'
                                                )
                                        ) "Reporta_a (Empleado)",
                                 'N/A' "Grupo de seguridad", paafe.assignment_id, ppt.system_person_type,
                                 TO_DATE (pei.pei_information2,
                                          'YYYY/MM/DD HH24:MI:SS') pei_information2, papfe.person_id
                            FROM per_all_people_f papfe,
                                 per_person_type_usages_f pptuf,
                                 per_person_types ppt,
                                 per_all_assignments_f paafe,
                                 per_periods_of_service ppos,
                                 apps.fnd_territories_tl ftl,
                                 apps.fnd_lookup_values flvn,
                                 apps.fnd_lookup_values flvm,
                                 apps.hr_fr_alternate_lookups hfal,
                                 apps.per_addresses pad,
                                 apps.fnd_lookup_values flvsp,
                                 apps.fnd_lookup_values flvcc,
                                 apps.hr_locations hlc,
                                 --cust.ttec_emp_proj_asg tempa,	-- Commented code by IXPRAVEEN-ARGANO,08-May-2023
								 apps.ttec_emp_proj_asg tempa,		--  code Added by IXPRAVEEN-ARGANO,08-May-2023
                                 apps.fnd_flex_values ffv,
                                 apps.fnd_flex_values_tl ffvt,
                                 apps.fnd_lookup_values flvcat,
                                 per_jobs pj,
                                 per_job_definitions pjd,
                                 hr_all_organization_units haou,
                                 per_people_extra_info pei,
                                 per_contracts_f pcf,
                                 apps.fnd_lookup_values pcflv,
                                 apps.fnd_lookup_values flvecat,
                                 apps.fnd_flex_values ffvpat,
                                 apps.fnd_flex_values_tl ffvtpat,
                                 apps.pay_personal_payment_methods_f pppmf,
                                 apps.pay_external_accounts pea,
                                 apps.fnd_flex_values ffvpab,
                                 apps.fnd_flex_values_tl ffvtpab,
                                 apps.per_all_people_f papfe2
                           WHERE papfe.business_group_id = p_business_group_id
                             AND paafe.person_id = papfe.person_id
                             AND paafe.primary_flag = 'Y'
                             AND papfe.person_id = p_person_id
                             AND paafe.person_id = ppos.person_id
                             AND pptuf.person_id = papfe.person_id
                             AND ppt.person_type_id = pptuf.person_type_id
                             AND UPPER (ppt.user_person_type) IN ('EMPLOYEE', 'EXTERNAL', 'EX-EMPLOYEE')
                             AND ppos.period_of_service_id = paafe.period_of_service_id
                             AND papfe.employee_number IS NOT NULL
                             AND papfe.country_of_birth = ftl.territory_code(+)
                             AND ftl.LANGUAGE(+) = 'ESA'
                             AND papfe.nationality = flvn.lookup_code(+)
                             AND flvn.lookup_type(+) = 'NATIONALITY'
                             AND flvn.LANGUAGE(+) = 'ESA'
                             AND flvn.security_group_id(+) = '24'
                             AND flvn.enabled_flag(+) = 'Y'
                             AND papfe.marital_status = flvm.lookup_code(+)
                             AND flvm.lookup_type(+) = 'MAR_STATUS'
                             AND flvm.LANGUAGE(+) = 'ESA'
                             AND flvm.security_group_id(+) = '24'
                             AND flvm.enabled_flag(+) = 'Y'
                             AND papfe.attribute6 = hfal.lookup_code(+)
                             AND hfal.lookup_type(+) = 'RHPRO_ARG_ID_TYPE'
                             AND hfal.function_type(+) = 'ID Type'
                             AND papfe.person_id = pad.person_id(+)
                             AND pad.region_1 = flvsp.lookup_code(+)
                             AND flvsp.lookup_type(+) = 'JLZZ_STATE_PROVINCE'
                             AND flvsp.LANGUAGE(+) = 'ESA'
                             AND flvsp.enabled_flag(+) = 'Y'
                             AND pad.country = flvcc.lookup_code(+)
                             AND flvcc.lookup_type(+) = 'JEES_EURO_COUNTRY_CODES'
                             AND flvcc.LANGUAGE(+) = 'ESA'
                             AND flvcc.enabled_flag(+) = 'Y'
                             AND paafe.location_id = hlc.location_id(+)
                             AND tempa.person_id(+) = papfe.person_id
                             AND ffv.flex_value_id = ffvt.flex_value_id(+)
                             AND paafe.ass_attribute11 = ffv.flex_value(+)
                             AND ffv.flex_value_set_id(+) = '1010056'
                             AND ffvt.LANGUAGE(+) = 'ESA'
                             AND paafe.bargaining_unit_code = flvcat.lookup_code(+)
                             AND flvcat.lookup_type(+) = 'BARGAINING_UNIT_CODE'
                             AND flvcat.LANGUAGE(+) = 'ESA'
                             AND flvcat.enabled_flag(+) = 'Y'
                             AND paafe.job_id = pj.job_id(+)
                             AND pj.job_definition_id = pjd.job_definition_id(+)
                             AND paafe.organization_id = haou.organization_id
                             AND pei.person_id(+) = papfe.person_id
                             AND pei.pei_information_category(+) = 'TTEC_ARG_ENTITIES'
                             AND pcf.person_id(+) = paafe.person_id
                             AND pcflv.lookup_code(+) = pcf.TYPE
                             AND pcflv.lookup_type(+) = 'CONTRACT_TYPE'
                             AND pcflv.LANGUAGE(+) = 'ESA'
                             AND paafe.employment_category = flvecat.lookup_code(+)
                             AND flvecat.lookup_type(+) = 'EMP_CAT'
                             AND flvecat.LANGUAGE(+) = 'ESA'
                             AND flvecat.security_group_id(+) = '24'
                             AND flvecat.enabled_flag(+) = 'Y'
                             AND pppmf.assignment_id(+) = paafe.assignment_id
                             AND pea.external_account_id(+) = pppmf.external_account_id
                             AND pppmf.external_account_id(+) IS NOT NULL
                             AND ffvpat.flex_value_set_id(+) = '1010073'
                             AND ffvpat.flex_value_id = ffvtpat.flex_value_id(+)
                             AND ffvpat.flex_value(+) = pea.segment3
                             AND ffvtpat.LANGUAGE(+) = 'ESA'
                             AND ffvpab.flex_value_set_id(+) = '1010052'
                             AND ffvpab.flex_value_id = ffvtpab.flex_value_id(+)
                             AND ffvpab.flex_value(+) = pea.segment1
                             AND ffvtpat.LANGUAGE(+) = 'ESA'
                             AND paafe.supervisor_id = papfe2.person_id(+)                 -- Version 1.2
                             AND p_actual_termination_date BETWEEN pppmf.effective_start_date(+) AND pppmf.effective_end_date(+)
                             AND p_actual_termination_date BETWEEN pcf.effective_start_date(+) AND pcf.effective_end_date(+)
                             AND p_actual_termination_date BETWEEN TO_DATE (pei.pei_information2(+),
                                                                            'YYYY/MM/DD HH24:MI:SS')
                                                               AND NVL (TO_DATE (pei.pei_information3(+),
                                                                                 'YYYY/MM/DD HH24:MI:SS'
                                                                                ),
                                                                        p_actual_termination_date
                                                                       -- Version 1.2
                                                                       )
                             AND p_actual_termination_date BETWEEN haou.date_from
                                                               AND NVL (haou.date_to,
                                                                        p_actual_termination_date
                                                                       -- Version 1.2
                                                                       )
                             AND p_actual_termination_date BETWEEN tempa.prj_strt_dt(+) AND tempa.prj_end_dt(+)
                             AND p_actual_termination_date BETWEEN hfal.effective_start_date(+) AND hfal.effective_end_date(+)
                             AND p_actual_termination_date BETWEEN pad.date_from(+)
                                                               AND NVL (pad.date_to(+),
                                                                        p_actual_termination_date)
                             AND p_actual_termination_date BETWEEN ppos.date_start
                                                               AND NVL (ppos.actual_termination_date,
                                                                        p_actual_termination_date
                                                                       )
                             AND p_actual_termination_date BETWEEN paafe.effective_start_date
                                                               -- Version 1.3
                                                           AND paafe.effective_end_date
                             AND p_actual_termination_date + 1 BETWEEN papfe.effective_start_date
                                                                   AND papfe.effective_end_date
                             AND p_actual_termination_date + 1 BETWEEN pptuf.effective_start_date
                                                                   AND pptuf.effective_end_date
                             AND p_actual_termination_date BETWEEN papfe2.effective_start_date(+) AND papfe2.effective_end_date(+)
                        -- Version 1.2
                 ORDER BY        1, pei_information2 DESC) DUAL
          WHERE ROWNUM = 1;

      v_asgn_costs        ttec_assign_costing_rules.asgncosttable;
      v_return_msg        VARCHAR2 (240);
      v_status            BOOLEAN;
      v_string            VARCHAR2 (240);
      v_add_ln1           per_addresses.address_line1%TYPE        DEFAULT NULL;
      v_add_ln2           per_addresses.address_line2%TYPE        DEFAULT NULL;
      v_add_ln3           per_addresses.address_line3%TYPE        DEFAULT NULL;
      v_add_info14        per_addresses.add_information14%TYPE    DEFAULT NULL;
      v_add_info15        per_addresses.add_information15%TYPE    DEFAULT NULL;
      v_add_info16        per_addresses.add_information16%TYPE    DEFAULT NULL;
      v_add_info17        per_addresses.add_information17%TYPE    DEFAULT NULL;
      v_postal_code       per_addresses.postal_code%TYPE          DEFAULT NULL;
      v_contract_type     fnd_lookup_values.meaning%TYPE          DEFAULT NULL;
      v_acc_type          fnd_flex_values_tl.description%TYPE     DEFAULT NULL;
      v_acc_bank          fnd_flex_values_tl.description%TYPE     DEFAULT NULL;
      v_acc_no            pay_external_accounts.segment4%TYPE     DEFAULT NULL;
      v_cbu               VARCHAR2 (100)                          DEFAULT NULL;
      v_acc_bank_branch   pay_external_accounts.segment2%TYPE     DEFAULT NULL;
      v_supervisor        per_all_people_f.employee_number%TYPE   DEFAULT NULL;
   BEGIN
      g_e_error_hand.module_name := 'init_605_intf';
      init_error_msg (g_e_error_hand.module_name);
      get_file_open (p_file_name);
      fnd_file.put_line (fnd_file.output, 'FILE_NAME -' || p_file_name);

      FOR r_qry_record IN c_qry_record
      LOOP
         FOR r_qry_exemp_emp IN c_qry_exemp_emp (r_qry_record.person_id)
         LOOP
            IF     (r_qry_exemp_emp.date_start NOT BETWEEN p_cut_off_date AND p_current_run_date)
               AND (r_qry_exemp_emp.actual_termination_date = p_current_run_date)
               AND (r_qry_exemp_emp.term_date IS NULL)                                     -- Version 1.2
            THEN
               FOR r_605_qry IN c_605_upd (r_qry_exemp_emp.person_id)
               LOOP
                  fnd_file.put_line (fnd_file.output,
                                        'START - 605 - Update on Employee_number - '
                                     || r_605_qry."Numero de empleado"
                                    );

                  BEGIN
                     v_string := NULL;
                     v_return_msg := NULL;
                     v_status := NULL;

                     IF r_605_qry.system_person_type <> 'EX_EMP'
                     THEN
                        ttec_assign_costing_rules.build_cost_accts
                                                            (p_assignment_id      => r_605_qry.assignment_id,
                                                             p_asgn_costs         => v_asgn_costs,
                                                             p_return_msg         => v_return_msg,
                                                             p_status             => v_status
                                                            );

                        FOR i IN 1 .. v_asgn_costs.COUNT
                        LOOP
                           v_string :=
                              (   v_asgn_costs (1).LOCATION
                               || v_asgn_costs (1).client
                               || v_asgn_costs (1).department
                               || '$'
                               || v_asgn_costs (1).LOCATION
                               || v_asgn_costs (1).client
                               || v_asgn_costs (1).department
                              );
                        END LOOP;
                     ELSE
                        v_string := 'N/A';
                     END IF;
                  EXCEPTION
                     WHEN OTHERS
                     THEN
                        v_string := 'N/A';
                  END;

                  -- Version 1.5 <Start>
                  BEGIN
                     IF r_605_qry.system_person_type = 'EX_EMP'
                     THEN
                        v_add_ln1 := r_605_qry."Calle";
                        v_add_ln2 := r_605_qry."Nro.";
                        v_add_ln3 := r_605_qry."Piso";
                        v_add_info14 := r_605_qry."Depto";
                        v_postal_code := r_605_qry."Cpostal";
                        v_add_info17 := r_605_qry."Barrio";
                        v_add_info16 := r_605_qry."Localidad";
                        v_add_info15 := r_605_qry."Partido";
                     ELSE
                        BEGIN
                           SELECT NVL (address_line1, 'N/A'), NVL (address_line2, 'N/A'),
                                  NVL (address_line3, 'N/A'), NVL (add_information14, 'N/A'),
                                  NVL (postal_code, 'N/A'), NVL (add_information17, 'N/A'),
                                  NVL (add_information16, 'N/A'), NVL (add_information15, 'N/A')
                             INTO v_add_ln1, v_add_ln2,
                                  v_add_ln3, v_add_info14,
                                  v_postal_code, v_add_info17,
                                  v_add_info16, v_add_info15
                             FROM per_addresses
                            WHERE address_id =
                                     (SELECT MAX (address_id)
                                        FROM per_addresses
                                       WHERE person_id = r_605_qry.person_id
                                         AND business_group_id = p_business_group_id);
                        EXCEPTION
                           WHEN NO_DATA_FOUND
                           THEN
                              v_add_ln1 := r_605_qry."Calle";
                              v_add_ln2 := r_605_qry."Nro.";
                              v_add_ln3 := r_605_qry."Piso";
                              v_add_info14 := r_605_qry."Depto";
                              v_postal_code := r_605_qry."Cpostal";
                              v_add_info17 := r_605_qry."Barrio";
                              v_add_info16 := r_605_qry."Localidad";
                              v_add_info15 := r_605_qry."Partido";
                           WHEN OTHERS
                           THEN
                              v_add_ln1 := r_605_qry."Calle";
                              v_add_ln2 := r_605_qry."Nro.";
                              v_add_ln3 := r_605_qry."Piso";
                              v_add_info14 := r_605_qry."Depto";
                              v_postal_code := r_605_qry."Cpostal";
                              v_add_info17 := r_605_qry."Barrio";
                              v_add_info16 := r_605_qry."Localidad";
                              v_add_info15 := r_605_qry."Partido";
                        END;
                     END IF;
                  END;

                  BEGIN
                     IF r_605_qry.system_person_type = 'EX_EMP'
                     THEN
                        v_contract_type := r_605_qry."Contrato";
                     ELSE
                        BEGIN
                           SELECT NVL (pcflv.meaning, 'N/A')
                             INTO v_contract_type
                             FROM per_contracts_f pcf, fnd_lookup_values pcflv
                            WHERE pcf.effective_start_date =
                                     (SELECT MAX (pcf1.effective_start_date)
                                        FROM per_contracts_f pcf1
                                       WHERE pcf1.person_id = r_605_qry.person_id
                                         AND pcf1.contract_id =
                                                (SELECT MAX (contract_id)
                                                   FROM per_contracts_f
                                                  WHERE person_id = r_605_qry.person_id
                                                    AND business_group_id = p_business_group_id)
                                         AND pcf1.business_group_id = p_business_group_id)
                              AND pcflv.lookup_code = pcf.TYPE
                              AND pcflv.lookup_type = 'CONTRACT_TYPE'
                              AND pcflv.LANGUAGE = 'ESA';
                        EXCEPTION
                           WHEN NO_DATA_FOUND
                           THEN
                              v_contract_type := r_605_qry."Contrato";
                           WHEN OTHERS
                           THEN
                              v_contract_type := r_605_qry."Contrato";
                        END;
                     END IF;
                  END;

                  BEGIN
                     IF r_605_qry.system_person_type = 'EX_EMP'
                     THEN
                        v_acc_type := r_605_qry."Forma de Pago";
                        v_acc_bank := r_605_qry."Banco Pago";
                        v_acc_no := r_605_qry."Nro. Cuenta";
                        v_cbu := r_605_qry."Nro. CBU";
                        v_acc_bank_branch := r_605_qry."Sucursal Banco";
                     ELSE
                        BEGIN
                           SELECT NVL (ffvtpat.description, 'N/A') "Forma de Pago",
                                  NVL (ffvtpab.description, 'N/A') "Banco Pago",
                                  NVL (pea.segment4, 'N/A') "Nro. Cuenta", 'N/A' "Nro. CBU",
                                  NVL (pea.segment2, 'N/A') "Sucursal Banco"
                             INTO v_acc_type,
                                  v_acc_bank,
                                  v_acc_no, v_cbu,
                                  v_acc_bank_branch
                             FROM apps.fnd_flex_values ffvpat,
                                  apps.fnd_flex_values_tl ffvtpat,
                                  apps.pay_personal_payment_methods_f pppmf,
                                  apps.pay_external_accounts pea,
                                  apps.fnd_flex_values ffvpab,
                                  apps.fnd_flex_values_tl ffvtpab
                            WHERE pppmf.assignment_id = r_605_qry.assignment_id
                              AND pea.external_account_id = pppmf.external_account_id
                              AND TRUNC (pppmf.effective_end_date) =                           -- 1.6 (b)
                                     (SELECT MAX (TRUNC (pppmf1.effective_end_date))           -- 1.6 (b)
                                        FROM apps.pay_personal_payment_methods_f pppmf1
                                       WHERE pppmf1.assignment_id = r_605_qry.assignment_id
                                         AND pppmf1.business_group_id = p_business_group_id
                                         AND pppmf1.external_account_id IS NOT NULL)
                              AND ffvpat.flex_value_set_id(+) = '1010073'
                              AND ffvpat.flex_value_id = ffvtpat.flex_value_id(+)
                              AND ffvpat.flex_value(+) = pea.segment3
                              AND ffvtpat.LANGUAGE(+) = 'ESA'
                              AND ffvpab.flex_value_set_id(+) = '1010052'
                              AND ffvpab.flex_value_id = ffvtpab.flex_value_id(+)
                              AND ffvpab.flex_value(+) = pea.segment1
                              AND ffvtpab.LANGUAGE(+) = 'ESA';
                        EXCEPTION
                           WHEN NO_DATA_FOUND
                           THEN
                              v_acc_type := r_605_qry."Forma de Pago";
                              v_acc_bank := r_605_qry."Banco Pago";
                              v_acc_no := r_605_qry."Nro. Cuenta";
                              v_cbu := r_605_qry."Nro. CBU";
                              v_acc_bank_branch := r_605_qry."Sucursal Banco";
                           WHEN OTHERS
                           THEN
                              v_acc_type := r_605_qry."Forma de Pago";
                              v_acc_bank := r_605_qry."Banco Pago";
                              v_acc_no := r_605_qry."Nro. Cuenta";
                              v_cbu := r_605_qry."Nro. CBU";
                              v_acc_bank_branch := r_605_qry."Sucursal Banco";
                        END;
                     END IF;
                  END;

                  -- Version 1.5 <End>

                  -- Version 1.6(a) /,starts>
                  BEGIN
                     SELECT DISTINCT DECODE (papfe2.business_group_id,
                                             1632, papfe2.employee_number,
                                             'N/A'
                                            )
                                INTO v_supervisor
                                FROM per_all_people_f papfe,
                                     per_all_assignments_f paafe,
                                     per_all_people_f papfe2
                               WHERE papfe.person_id = paafe.person_id
                                 AND paafe.supervisor_id = papfe2.person_id
                                 AND paafe.person_id = r_605_qry.person_id
                                 AND papfe2.employee_number IS NOT NULL
                                 AND papfe.business_group_id = p_business_group_id
                                 AND TRUNC (paafe.effective_end_date) =
                                                               (SELECT MAX (TRUNC (effective_end_date))
                                                                  FROM per_all_assignments_f
                                                                 WHERE person_id = r_605_qry.person_id);
                  EXCEPTION
                     WHEN NO_DATA_FOUND
                     THEN
                        v_supervisor := r_605_qry."Reporta_a (Empleado)";
                     WHEN OTHERS
                     THEN
                        v_supervisor := r_605_qry."Reporta_a (Empleado)";
                  END;

                  -- Version 1.6(a) /,Ends>
                  v_rec := NULL;
                  v_rec :=
                        r_605_qry."Numero de empleado"
                     || ';'
                     || cvt_char (r_605_qry."Apellido")
                     || ';'
                     || cvt_char (r_605_qry."Nombres")
                     || ';'
                     || TO_CHAR (r_605_qry."F.Nacim", 'DD/MM/YYYY')
                     || ';'
                     || cvt_char (r_605_qry."Pais de Nacimiento")
                     || ';'
                     || cvt_char (r_605_qry."Nacionalidad")
                     || ';'
                     || cvt_char (r_605_qry."Fec.Ingreso al Pais")
                     || ';'
                     || cvt_char (r_605_qry."Est.Civil")
                     || ';'
                     || cvt_char (r_605_qry."Sexo")
                     || ';'
                     || TO_CHAR (r_605_qry."Fec de Alta", 'DD/MM/YYYY')
                     || ';'
                     || cvt_char (r_605_qry."Estudia")
                     || ';'
                     || cvt_char (r_605_qry."Nivel de Estudio")
                     || ';'
                     || cvt_char (r_605_qry."Tipo Documento")
                     || ';'
                     || cvt_char (r_605_qry."Nro. Documento")
                     || ';'
                     || cvt_char (r_605_qry."CUIL/RUT")
                     || ';'
                     || cvt_char (v_add_ln1)                                               -- Version 1.5
                     || ';'
                     || cvt_char (v_add_ln2)                                               -- Version 1.5
                     || ';'
                     || cvt_char (v_add_ln3)                                               -- Version 1.5
                     || ';'
                     || cvt_char (v_add_info14)                                            -- Version 1.5
                     || ';'
                     || cvt_char (r_605_qry."Torre")
                     || ';'
                     || cvt_char (r_605_qry."Manzana")
                     || ';'
                     || v_postal_code                                                      -- Version 1.5
                     || ';'
                     || cvt_char (r_605_qry."Entre Calles")
                     || ';'
                     || cvt_char (v_add_info17)                                            -- Version 1.5
                     || ';'
                     || cvt_char (v_add_info16)                                            -- Version 1.5
                     || ';'
                     || cvt_char (v_add_info15)                                            -- Version 1.5
                     || ';'
                     || cvt_char (r_605_qry."Zona")
                     || ';'
                     || cvt_char (r_605_qry."Provincia")
                     || ';'
                     || cvt_char (r_605_qry."País")
                     || ';'
                     || cvt_char (r_605_qry."Telefono Particular")
                     || ';'
                     || cvt_char (r_605_qry."Telefono Laboral")
                     || ';'
                     || cvt_char (r_605_qry."Telefono Celular")
                     || ';'
                     || cvt_char (r_605_qry."E-mail")
                     || ';'
                     || cvt_char (r_605_qry."Sucursal")
                     || ';'
                     || cvt_char (r_605_qry."Sector")
                     || ';'
                     || cvt_char (r_605_qry."Convenio")
                     || ';'
                     || cvt_char (r_605_qry."Categoria")
                     || ';'
                     || cvt_char (r_605_qry."puesto")
                     || ';'
                     || v_string
                     || ';'
                     || cvt_char (r_605_qry."Gerencia")
                     || ';'
                     || cvt_char (r_605_qry."Departamento")
                     || ';'
                     || cvt_char (r_605_qry."Direccion")
                     || ';'
                     || cvt_char (r_605_qry."Caja de Jubilacion AFJP")
                     || ';'
                     || cvt_char (r_605_qry."Sindicato")
                     || ';'
                     || r_605_qry."Obra Social Ley"
                     || ';'
                     || cvt_char (r_605_qry."Plan OS Ley")
                     || ';'
                     || r_605_qry."Obra Social Elegida"
                     || ';'
                     || cvt_char (r_605_qry."Plan OS Elegida")
                     || ';'
                     || cvt_char (v_contract_type)                                         -- Version 1.5
                     || ';'
                     || r_605_qry."Fecha de Vto. Contrato"
                     || ';'
                     || cvt_char (r_605_qry."Lugar de Pago")
                     || ';'
                     || cvt_char (r_605_qry."Regimen Horario")
                     || ';'
                     || cvt_char (r_605_qry."Forma de Liquidacion")
                     || ';'
                     || cvt_char (v_acc_type)                                              -- Version 1.5
                     || ';'
                     || cvt_char (v_acc_bank)                                              -- Version 1.5
                     || ';'
                     || v_acc_no                                                           -- Version 1.5
                     || ';'
                     || cvt_char (v_cbu)                                                   -- Version 1.5
                     || ';'
                     || cvt_char (v_acc_bank_branch)                                       -- Version 1.5
                     || ';'
                     || r_605_qry."Cta. Acreditacion Empresa"
                     || ';'
                     || cvt_char (r_605_qry."Actividad SIJP")
                     || ';'
                     || cvt_char (r_605_qry."Condicion SIJP")
                     || ';'
                     || cvt_char (r_605_qry."Sit.de Revista SIJP")
                     || ';'
                     || cvt_char (r_605_qry."ART")
                     || ';'
                     || r_605_qry."Estado del Empleado"
                     || ';'
                     || cvt_char (r_605_qry."Causa de Baja")
                     || ';'
                     || r_605_qry."Fecha de Baja"
                     || ';'
                     || cvt_char (r_605_qry."Empresa")
                     || ';'
                     || r_605_qry."Remuneracion"
                     || ';'
                     || cvt_char (r_605_qry."Modelo Organizacional")
                     || ';'
                     || v_supervisor                                                    -- Version 1.6(a)
                     || ';'
                     || cvt_char (r_605_qry."Grupo de seguridad");
                  v_rec := REPLACE (v_rec, '  ;', ';');                                     --Version 1.1
                  UTL_FILE.put_line (v_output_file, v_rec);
                  g_success_count := g_success_count + 1;
                  fnd_file.put_line (fnd_file.output,
                                        'END - 605 - Update on Employee_number - '
                                     || r_605_qry."Numero de empleado"
                                    );
               END LOOP;
            ELSIF    (    (r_qry_exemp_emp.date_start BETWEEN p_cut_off_date AND p_current_run_date)
                      AND (r_qry_exemp_emp.actual_termination_date = p_current_run_date)
                     )
                  OR ((   (    r_qry_exemp_emp.actual_termination_date IS NOT NULL
                           AND r_qry_exemp_emp.actual_termination_date <> p_current_run_date
                          )
                       OR r_qry_exemp_emp.term_date IS NOT NULL
                      )                                                                    -- Version 1.2
                     )
            THEN
               FOR r_605_new_term IN c_605_new_term (r_qry_exemp_emp.person_id,
                                                     r_qry_exemp_emp.actual_termination_date
                                                    )
               LOOP
                  BEGIN
                     fnd_file.put_line (fnd_file.output,
                                           'START - 605 - Term on Employee_number - '
                                        || r_605_new_term."Numero de empleado"
                                       );
                     v_string := NULL;
                     v_return_msg := NULL;
                     v_status := NULL;

                     IF r_605_new_term.system_person_type <> 'EX_EMP'
                     THEN
                        ttec_assign_costing_rules.build_cost_accts
                                                       (p_assignment_id      => r_605_new_term.assignment_id,
                                                        p_asgn_costs         => v_asgn_costs,
                                                        p_return_msg         => v_return_msg,
                                                        p_status             => v_status
                                                       );

                        FOR i IN 1 .. v_asgn_costs.COUNT
                        LOOP
                           v_string :=
                              (   v_asgn_costs (1).LOCATION
                               || v_asgn_costs (1).client
                               || v_asgn_costs (1).department
                               || '$'
                               || v_asgn_costs (1).LOCATION
                               || v_asgn_costs (1).client
                               || v_asgn_costs (1).department
                              );
                        END LOOP;
                     ELSE
                        v_string := 'N/A';
                     END IF;
                  EXCEPTION
                     WHEN OTHERS
                     THEN
                        v_string := 'N/A';
                  END;

                  v_rec := NULL;
                  v_rec :=
                        r_605_new_term."Numero de empleado"
                     || ';'
                     || cvt_char (r_605_new_term."Apellido")
                     || ';'
                     || cvt_char (r_605_new_term."Nombres")
                     || ';'
                     || TO_CHAR (r_605_new_term."F.Nacim", 'DD/MM/YYYY')
                     || ';'
                     || cvt_char (r_605_new_term."Pais de Nacimiento")
                     || ';'
                     || cvt_char (r_605_new_term."Nacionalidad")
                     || ';'
                     || cvt_char (r_605_new_term."Fec.Ingreso al Pais")
                     || ';'
                     || cvt_char (r_605_new_term."Est.Civil")
                     || ';'
                     || cvt_char (r_605_new_term."Sexo")
                     || ';'
                     || TO_CHAR (r_605_new_term."Fec de Alta", 'DD/MM/YYYY')
                     || ';'
                     || cvt_char (r_605_new_term."Estudia")
                     || ';'
                     || cvt_char (r_605_new_term."Nivel de Estudio")
                     || ';'
                     || cvt_char (r_605_new_term."Tipo Documento")
                     || ';'
                     || cvt_char (r_605_new_term."Nro. Documento")
                     || ';'
                     || cvt_char (r_605_new_term."CUIL/RUT")
                     || ';'
                     || cvt_char (r_605_new_term."Calle")
                     || ';'
                     || cvt_char (r_605_new_term."Nro.")
                     || ';'
                     || cvt_char (r_605_new_term."Piso")
                     || ';'
                     || cvt_char (r_605_new_term."Depto")
                     || ';'
                     || cvt_char (r_605_new_term."Torre")
                     || ';'
                     || cvt_char (r_605_new_term."Manzana")
                     || ';'
                     || r_605_new_term."Cpostal"
                     || ';'
                     || cvt_char (r_605_new_term."Entre Calles")
                     || ';'
                     || cvt_char (r_605_new_term."Barrio")
                     || ';'
                     || cvt_char (r_605_new_term."Localidad")
                     || ';'
                     || cvt_char (r_605_new_term."Partido")
                     || ';'
                     || cvt_char (r_605_new_term."Zona")
                     || ';'
                     || cvt_char (r_605_new_term."Provincia")
                     || ';'
                     || cvt_char (r_605_new_term."País")
                     || ';'
                     || cvt_char (r_605_new_term."Telefono Particular")
                     || ';'
                     || cvt_char (r_605_new_term."Telefono Laboral")
                     || ';'
                     || cvt_char (r_605_new_term."Telefono Celular")
                     || ';'
                     || cvt_char (r_605_new_term."E-mail")
                     || ';'
                     || cvt_char (r_605_new_term."Sucursal")
                     || ';'
                     || cvt_char (r_605_new_term."Sector")
                     || ';'
                     || cvt_char (r_605_new_term."Convenio")
                     || ';'
                     || cvt_char (r_605_new_term."Categoria")
                     || ';'
                     || cvt_char (r_605_new_term."puesto")
                     || ';'
                     || v_string
                     || ';'
                     || cvt_char (r_605_new_term."Gerencia")
                     || ';'
                     || cvt_char (r_605_new_term."Departamento")
                     || ';'
                     || cvt_char (r_605_new_term."Direccion")
                     || ';'
                     || cvt_char (r_605_new_term."Caja de Jubilacion AFJP")
                     || ';'
                     || cvt_char (r_605_new_term."Sindicato")
                     || ';'
                     || r_605_new_term."Obra Social Ley"
                     || ';'
                     || cvt_char (r_605_new_term."Plan OS Ley")
                     || ';'
                     || r_605_new_term."Obra Social Elegida"
                     || ';'
                     || cvt_char (r_605_new_term."Plan OS Elegida")
                     || ';'
                     || cvt_char (r_605_new_term."Contrato")
                     || ';'
                     || r_605_new_term."Fecha de Vto. Contrato"
                     || ';'
                     || cvt_char (r_605_new_term."Lugar de Pago")
                     || ';'
                     || cvt_char (r_605_new_term."Regimen Horario")
                     || ';'
                     || cvt_char (r_605_new_term."Forma de Liquidacion")
                     || ';'
                     || cvt_char (r_605_new_term."Forma de Pago")
                     || ';'
                     || cvt_char (r_605_new_term."Banco Pago")
                     || ';'
                     || r_605_new_term."Nro. Cuenta"
                     || ';'
                     || cvt_char (r_605_new_term."Nro. CBU")
                     || ';'
                     || r_605_new_term."Sucursal Banco"
                     || ';'
                     || r_605_new_term."Cta. Acreditacion Empresa"
                     || ';'
                     || cvt_char (r_605_new_term."Actividad SIJP")
                     || ';'
                     || cvt_char (r_605_new_term."Condicion SIJP")
                     || ';'
                     || cvt_char (r_605_new_term."Sit.de Revista SIJP")
                     || ';'
                     || cvt_char (r_605_new_term."ART")
                     || ';'
                     || r_605_new_term."Estado del Empleado"
                     || ';'
                     || cvt_char (r_605_new_term."Causa de Baja")
                     || ';'
                     || r_605_new_term."Fecha de Baja"
                     || ';'
                     || cvt_char (r_605_new_term."Empresa")
                     || ';'
                     || r_605_new_term."Remuneracion"
                     || ';'
                     || cvt_char (r_605_new_term."Modelo Organizacional")
                     || ';'
                     || r_605_new_term."Reporta_a (Empleado)"
                     || ';'
                     || cvt_char (r_605_new_term."Grupo de seguridad");
                  v_rec := REPLACE (v_rec, '  ;', ';');                                     --Version 1.1
                  UTL_FILE.put_line (v_output_file, v_rec);
                  g_success_count := g_success_count + 1;
                  fnd_file.put_line (fnd_file.output,
                                        'END - 605 - Term on Employee_number - '
                                     || r_605_new_term."Numero de empleado"
                                    );
               END LOOP;
            END IF;
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
         raise_application_error (-20003, 'Exception NODATAFOUND in init_605_intf' || v_msg);
         g_e_program_run_status := 1;
      WHEN OTHERS
      THEN
         g_error_count := g_error_count + 1;
         print_count (g_success_count, g_error_count, g_e_error_hand.module_name);
         UTL_FILE.fclose (v_output_file);
         log_error ('SQLCODE', TO_CHAR (SQLCODE), 'Error Message', SUBSTR (SQLERRM, 1, 64));
         print_line ('Error in module: ' || g_e_error_hand.module_name);
         v_msg := SQLERRM;
         raise_application_error (-20003, 'Exception OTHERS in init_605_intf' || v_msg);
         g_e_program_run_status := 1;
   END;

--The 640 Importación de fases (Periods of Service):  interface will be used for inactive employees and for NCNS terminations.
   PROCEDURE init_640_intf (
      p_file_name           IN   VARCHAR2,
      p_business_group_id        NUMBER,
      p_cut_off_date             DATE,
      p_current_run_date         DATE
   )
   IS
      CURSOR c_640_qry
      IS
         SELECT DISTINCT papfe.employee_number "Legajo",
                         NVL (SUBSTR (ppos.attribute12, 1, 60), 'Sin Datos') "Causa",
                         CASE
                            WHEN papfe.start_date = ppos.date_start
                               THEN NVL (papfe.original_date_of_hire, ppos.date_start)
                            ELSE ppos.date_start
                         END "Fecha de Alta",
                         NVL (TO_DATE (ppos.attribute1, 'YYYY/MM/DD HH24:MI:SS'),
                              ppos.actual_termination_date
                             ) "Fecha de Baja",
                         'Inactivo' "Estado", 'N/A' "Antig. p/Sueldo", 'No' "Antig. p/Vacaciones",
                         'No' "Antig. p/Indemnización", 'No' "Antig. p/Real",
                         'No' "Fecha de alta reconocida"
                    FROM per_all_people_f papfe,
                         per_person_type_usages_f pptuf,
                         per_person_types ppt,
                         per_all_assignments_f paafe,
                         per_periods_of_service ppos
                   WHERE papfe.business_group_id = p_business_group_id
                     AND paafe.person_id = papfe.person_id
                     AND paafe.person_id = ppos.person_id
                     AND pptuf.person_id = papfe.person_id
                     AND ppt.person_type_id = pptuf.person_type_id
                     AND UPPER (ppt.user_person_type) LIKE ('EX%')
                     AND ppos.period_of_service_id = paafe.period_of_service_id
                     AND ppos.actual_termination_date BETWEEN paafe.effective_start_date
                                                          AND paafe.effective_end_date
                     AND ppos.actual_termination_date + 1 BETWEEN papfe.effective_start_date
                                                              AND papfe.effective_end_date
                     AND ppos.actual_termination_date + 1 BETWEEN pptuf.effective_start_date
                                                              AND pptuf.effective_end_date
                     AND ppos.actual_termination_date IS NOT NULL
                     AND (   TRUNC (ppos.creation_date) BETWEEN p_cut_off_date AND p_current_run_date
                          OR TRUNC (ppos.last_update_date) BETWEEN p_cut_off_date AND p_current_run_date
                         )
                     AND ppos.attribute12 = 'No Inicia Relacion Laboral'
                ORDER BY 1, 3;
   BEGIN
      g_e_error_hand.module_name := 'init_640_intf';
      init_error_msg (g_e_error_hand.module_name);
      get_file_open (p_file_name);
      fnd_file.put_line (fnd_file.output, 'FILE_NAME -' || p_file_name);

      FOR r_640_qry IN c_640_qry
      LOOP
         fnd_file.put_line (fnd_file.output, 'START - 640 - Employee_number - ' || r_640_qry."Legajo");
         v_rec := NULL;
         v_rec :=
               cvt_char (r_640_qry."Legajo")
            || ';'
            || cvt_char (r_640_qry."Causa")
            || ';'
            || TO_CHAR (r_640_qry."Fecha de Alta", 'DD/MM/YYYY')
            || ';'
            || TO_CHAR (r_640_qry."Fecha de Baja", 'DD/MM/YYYY')
            || ';'
            || r_640_qry."Estado"
            || ';'
            || r_640_qry."Antig. p/Sueldo"
            || ';'
            || r_640_qry."Antig. p/Vacaciones"
            || ';'
            || r_640_qry."Antig. p/Indemnización"
            || ';'
            || r_640_qry."Antig. p/Real"
            || ';'
            || r_640_qry."Fecha de alta reconocida";
         v_rec := REPLACE (v_rec, '  ;', ';');                                              --Version 1.1
         UTL_FILE.put_line (v_output_file, v_rec);
         g_success_count := g_success_count + 1;
         fnd_file.put_line (fnd_file.output, 'END - 640 - Employee_number - ' || r_640_qry."Legajo");
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
         raise_application_error (-20003, 'Exception NODATAFOUND in init_640_intf' || v_msg);
         g_e_program_run_status := 1;
      WHEN OTHERS
      THEN
         g_error_count := g_error_count + 1;
         print_count (g_success_count, g_error_count, g_e_error_hand.module_name);
         UTL_FILE.fclose (v_output_file);
         log_error ('SQLCODE', TO_CHAR (SQLCODE), 'Error Message', SUBSTR (SQLERRM, 1, 64));
         print_line ('Error in module: ' || g_e_error_hand.module_name);
         v_msg := SQLERRM;
         raise_application_error (-20003, 'Exception OTHERS in init_640_intf' || v_msg);
         g_e_program_run_status := 1;
   END;

--The 262-Importación de Dias Correspondientes (Projected Vacation Days) interface will feed RHPro with all employee vacations information
--that will be used for New Hires and Rehires. It should be also sent after running the annual Carry Over process
   PROCEDURE init_262_intf (
      p_file_name           IN   VARCHAR2,
      p_business_group_id        NUMBER,
      p_cut_off_date             DATE,
      p_current_run_date         DATE
   )
   IS
      CURSOR c_262_intf
      IS
         SELECT DISTINCT papfe.employee_number "Legajo", TO_CHAR (p_current_run_date, 'YYYY') "Año",
                         '1' "Tipo Vacacion",
                         get_net_accrual
                                   (paf.assignment_id,
                                    pap.accrual_plan_id,
                                    paf.payroll_id,
                                    paf.business_group_id,
                                    LAST_DAY (ADD_MONTHS (TRUNC (p_current_run_date, 'YYYY'), 11))
                                   ) "Cantidad de dias"
                    FROM per_all_people_f papfe,
                         per_all_assignments_f paf,
                         per_periods_of_service ppos,
                         pay_accrual_plans pap,
                         pay_element_types_f pet,
                         pay_element_entries_f pee
                   WHERE papfe.business_group_id = p_business_group_id
                     AND papfe.person_id = paf.person_id
                     AND papfe.current_employee_flag = 'Y'
                     AND paf.primary_flag = 'Y'
                     AND paf.period_of_service_id = ppos.period_of_service_id
                     AND paf.person_id = ppos.person_id
                     AND pee.assignment_id = paf.assignment_id
                     AND pet.element_type_id = pee.element_type_id
                     AND pap.accrual_plan_element_type_id = pet.element_type_id
                     AND pap.accrual_plan_id = 298
                     AND GREATEST (p_current_run_date, ppos.date_start) BETWEEN pet.effective_start_date
                                                                            --Version 1.2
                                                                        AND pet.effective_end_date
                     AND GREATEST (p_current_run_date, ppos.date_start) BETWEEN pee.effective_start_date
                                                                            --Version 1.2
                                                                        AND pee.effective_end_date
                     AND GREATEST (p_current_run_date, ppos.date_start) BETWEEN paf.effective_start_date
                                                                            AND paf.effective_end_date
                     AND GREATEST (p_current_run_date, ppos.date_start) BETWEEN papfe.effective_start_date
                                                                            --Version 1.2
                                                                        AND papfe.effective_end_date
                     AND (   TRUNC (ppos.creation_date) BETWEEN p_cut_off_date
                                                            AND GREATEST (p_current_run_date,
                                                                          --Version 1.2
                                                                          ppos.date_start
                                                                         )
                          OR TRUNC (ppos.last_update_date) BETWEEN p_cut_off_date
                                                               AND GREATEST (p_current_run_date,
                                                                             --Version 1.2
                                                                             ppos.date_start
                                                                            )
                          OR ppos.date_start BETWEEN p_cut_off_date
                                                 AND GREATEST (p_current_run_date, ppos.date_start)
                         --Version 1.2
                         )
                     AND ppos.actual_termination_date IS NULL
                ORDER BY 1;
   BEGIN
      g_e_error_hand.module_name := 'init_262_intf';
      init_error_msg (g_e_error_hand.module_name);
      get_file_open (p_file_name);
      fnd_file.put_line (fnd_file.output, 'FILE_NAME -' || p_file_name);

      FOR r_262_intf IN c_262_intf
      LOOP
         fnd_file.put_line (fnd_file.output, 'START - 262 - Employee_number - ' || r_262_intf."Legajo");
         v_rec := NULL;
         v_rec :=
               cvt_char (r_262_intf."Legajo")
            || ';'
            || r_262_intf."Año"
            || ';'
            || r_262_intf."Tipo Vacacion"
            || ';'
            || r_262_intf."Cantidad de dias";
         v_rec := REPLACE (v_rec, '  ;', ';');                                              --Version 1.1
         UTL_FILE.put_line (v_output_file, v_rec);
         g_success_count := g_success_count + 1;
         fnd_file.put_line (fnd_file.output, 'END - 262 - Employee_number - ' || r_262_intf."Legajo");
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
         raise_application_error (-20003, 'Exception NO_DATA_FOUND in init_262_intf' || v_msg);
         g_e_program_run_status := 1;
      WHEN OTHERS
      THEN
         g_error_count := g_error_count + 1;
         print_count (g_success_count, g_error_count, g_e_error_hand.module_name);
         UTL_FILE.fclose (v_output_file);
         log_error ('SQLCODE', TO_CHAR (SQLCODE), 'Error Message', SUBSTR (SQLERRM, 1, 64));
         print_line ('Error in module: ' || g_e_error_hand.module_name);
         v_msg := SQLERRM;
         raise_application_error (-20003, 'Exception OTHERS in init_262_intf' || v_msg);
         g_e_program_run_status := 1;
   END;

--The 317-Distribución Contable (Costing) interface will feed RHPro with employee Cost Center information which will be used
--for New Hires, Rehires and updates
   PROCEDURE init_317_intf (
      p_file_name           IN   VARCHAR2,
      p_business_group_id        NUMBER,
      p_cut_off_date             DATE,
      p_current_run_date         DATE
   )
   IS
      CURSOR c_317_intf
      IS
         SELECT   *
             FROM (SELECT DISTINCT papfe.employee_number "Legajo", paafe.assignment_id
			 --START R12.2 Upgrade Remediation
                              /*FROM hr.per_all_assignments_f paafe,				-- Commented code by IXPRAVEEN-ARGANO,08-May-2023
                                   hr.per_all_people_f papfe,
                                   hr.per_periods_of_service ppos,
                                   hr.pay_cost_allocations_f pcaf*/
							  FROM apps.per_all_assignments_f paafe,					--  code Added by IXPRAVEEN-ARGANO,08-May-2023
                                   apps.per_all_people_f papfe,
                                   apps.per_periods_of_service ppos,
                                   apps.pay_cost_allocations_f pcaf	 
				--END R12.2.10 Upgrade remediation				   
                             WHERE paafe.person_id = papfe.person_id
                               AND paafe.person_id = ppos.person_id
                               AND paafe.primary_flag = 'Y'
                               AND papfe.current_employee_flag = 'Y'
                               AND papfe.business_group_id = p_business_group_id
                               AND paafe.assignment_id = pcaf.assignment_id
                               AND (   p_cut_off_date BETWEEN paafe.effective_start_date
                                                          AND paafe.effective_end_date
                                    OR paafe.effective_start_date BETWEEN p_cut_off_date
                                                                      AND GREATEST (p_current_run_date,
                                                                                    ppos.date_start
                                                                                   )
                                    OR paafe.effective_end_date BETWEEN p_cut_off_date
                                                                    AND GREATEST (p_current_run_date,
                                                                                  ppos.date_start
                                                                                 )
                                   )
                               AND (   p_cut_off_date BETWEEN papfe.effective_start_date
                                                          AND papfe.effective_end_date
                                    OR papfe.effective_start_date BETWEEN p_cut_off_date
                                                                      AND GREATEST (p_current_run_date,
                                                                                    ppos.date_start
                                                                                   )
                                    OR papfe.effective_end_date BETWEEN p_cut_off_date
                                                                    AND GREATEST (p_current_run_date,
                                                                                  ppos.date_start
                                                                                 )
                                   )
                               AND (   TRUNC (pcaf.creation_date) BETWEEN p_cut_off_date
                                                                      AND GREATEST (p_current_run_date,
                                                                                    ppos.date_start
                                                                                   )
                                    OR TRUNC (pcaf.last_update_date) BETWEEN p_cut_off_date
                                                                         AND GREATEST
                                                                                     (p_current_run_date,
                                                                                      ppos.date_start
                                                                                     )
                                    OR pcaf.effective_start_date >=
                                                           GREATEST (p_current_run_date, ppos.date_start)
                                   --Version 1.2
                                   )
                               AND ppos.actual_termination_date IS NULL
                   UNION
                   -- Version 1.4 <start>
                   SELECT DISTINCT papfe.employee_number "Legajo", paafe.assignment_id
				   --START R12.2 Upgrade Remediation
                              /*FROM hr.per_all_assignments_f paafe,			-- Commented code by IXPRAVEEN-ARGANO,08-May-2023
                                   hr.per_all_people_f papfe,
                                   hr.per_periods_of_service pps*/
							  FROM apps.per_all_assignments_f paafe,			--  code Added by IXPRAVEEN-ARGANO,08-May-2023
                                   apps.per_all_people_f papfe,
                                   apps.per_periods_of_service pps	
					--END R12.2.10 Upgrade remediation					
                             WHERE paafe.person_id = papfe.person_id
                               AND paafe.person_id = pps.person_id
                               AND paafe.primary_flag = 'Y'
                               AND papfe.current_employee_flag = 'Y'
                               AND papfe.business_group_id = p_business_group_id
                               AND (   p_cut_off_date BETWEEN papfe.effective_start_date
                                                          AND papfe.effective_end_date
                                    OR papfe.effective_start_date BETWEEN p_cut_off_date
                                                                      AND GREATEST (p_current_run_date,
                                                                                    pps.date_start
                                                                                   )
                                    OR papfe.effective_end_date BETWEEN p_cut_off_date
                                                                    AND GREATEST (p_current_run_date,
                                                                                  pps.date_start
                                                                                 )
                                   )
                               AND (   TRUNC (paafe.creation_date) BETWEEN p_cut_off_date
                                                                       AND GREATEST (p_current_run_date,
                                                                                     pps.date_start
                                                                                    )
                                    OR TRUNC (paafe.last_update_date) BETWEEN p_cut_off_date
                                                                          AND GREATEST
                                                                                     (p_current_run_date,
                                                                                      pps.date_start
                                                                                     )
                                   )
                               AND pps.actual_termination_date IS NULL
                                                                      -- Version 1.4 <end>
                  ) DUAL
         ORDER BY "Legajo";

      v_asgn_costs   ttec_assign_costing_rules.asgncosttable;
      v_return_msg   VARCHAR2 (240);
      v_status       BOOLEAN;
   BEGIN
      g_e_error_hand.module_name := 'init_317_intf';
      init_error_msg (g_e_error_hand.module_name);
      get_file_open (p_file_name);
      fnd_file.put_line (fnd_file.output, 'FILE_NAME -' || p_file_name);

      FOR r_317_intf IN c_317_intf
      LOOP
         fnd_file.put_line (fnd_file.output, 'START - 317 - Employee_number -' || r_317_intf."Legajo");
         v_return_msg := NULL;
         v_status := NULL;
         ttec_assign_costing_rules.build_cost_accts (p_assignment_id      => r_317_intf.assignment_id,
                                                     p_asgn_costs         => v_asgn_costs,
                                                     p_return_msg         => v_return_msg,
                                                     p_status             => v_status
                                                    );

         FOR i IN 1 .. v_asgn_costs.COUNT
         LOOP
            v_rec := NULL;
            v_rec :=
                  r_317_intf."Legajo"
               || ';'
               || '1'
               || ';'
               || 'Centros de Costo'
               || ';'
               || (v_asgn_costs (i).LOCATION || v_asgn_costs (i).client || v_asgn_costs (i).department)
               || ';'
               || ''
               || ';'
               || ''
               || ';'
               || ''
               || ';'
               || ''
               || ';'
               || v_asgn_costs (i).proportion * 100;
            v_rec := REPLACE (v_rec, '  ;', ';');                                           --Version 1.1
            UTL_FILE.put_line (v_output_file, v_rec);
            g_success_count := g_success_count + 1;
         END LOOP;

         fnd_file.put_line (fnd_file.output, 'END - 317 - Employee_number -' || r_317_intf."Legajo");
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
         raise_application_error (-20003, 'Exception NO_DATA_FOUND in init_317_intf' || v_msg);
         g_e_program_run_status := 1;
      WHEN OTHERS
      THEN
         g_error_count := g_error_count + 1;
         print_count (g_success_count, g_error_count, g_e_error_hand.module_name);
         UTL_FILE.fclose (v_output_file);
         log_error ('SQLCODE', TO_CHAR (SQLCODE), 'Error Message', SUBSTR (SQLERRM, 1, 64));
         print_line ('Error in module: ' || g_e_error_hand.module_name);
         v_msg := SQLERRM;
         raise_application_error (-20003, 'Exception OTHERS in init_317_intf' || v_msg);
         g_e_program_run_status := 1;
   END;

--The 602-Importación de Familiares (Contacts) interface is used to feed RHPro with all employees' contact information.
--It will be used when contact information is added or updated.
   PROCEDURE init_602_intf (
      p_file_name           IN   VARCHAR2,
      p_business_group_id        NUMBER,
      p_cut_off_date             DATE,
      p_current_run_date         DATE
   )
   IS
      CURSOR c_602_intf
      IS
         SELECT DISTINCT papfe.employee_number "Leg.del empleado asociado", depn.last_name "Apellido",
                         depn.first_name || ' ' || depn.middle_names "Nombres",
                         depn.date_of_birth "Fecha de Nacimiento", 'N/A' "País de Nacimiento",
                         NVL (depn.attribute8, 'Argentina') "Nacionalidad",
                         NVL (depn.attribute9, 'Soltero') "Est.Civil", depn.sex "Sexo",
                         relt.meaning "Parentesco", 'N/A' "Incapacitado", 'N/A' "Estudia",
                         'N/A' "Nivel de Estudio", NVL (hfal.alternate_code, 'DNI') "Tipo Documento",
                         depn.national_identifier "Nro. Documento", 'N/A' "Calle", 'N/A' "Nro.",
                         'N/A' "Piso", 'N/A' "Depto.", 'N/A' "Torre", 'N/A' "Manzana", 'N/A' "Cpostal",
                         'N/A' "Entre Calles", 'N/A' "Barrio", 'N/A' "Localidad", 'N/A' "Partido",
                         'N/A' "Zona", 'N/A' "Provincia", 'N/A' "País", 'N/A' "Telefono",
                         'N/A' "Obra Social", 'N/A' "Plan OS", 'N/A' "Avisar ante Emergencia",
                         'N/A' "Paga Salario Familiar", 'NO' "Ganancias",
                         'N/A' "Fecha de Inicio Vinculo", 'N/A' "Fecha vencimiento vinculo",
                         'N/A' "Item DDJJ", 'N/A' "Año DDJJ", 'N/A' "New1", 'N/A' "New2"
                    FROM per_all_people_f depn,
                         per_all_people_f papfe,
                         per_contact_relationships rel,
                         per_person_type_usages_f pptuf,
                         per_person_types ppt,
                         apps.fnd_lookup_values relt,
                         apps.fnd_flex_values_vl ffvv,
                         apps.hr_fr_alternate_lookups hfal
                   WHERE rel.person_id = papfe.person_id(+)
                     AND rel.contact_person_id(+) = depn.person_id
                     AND depn.person_id = pptuf.person_id
                     AND rel.personal_flag = 'Y'
                     AND pptuf.person_type_id = ppt.person_type_id
                     AND papfe.business_group_id = p_business_group_id
                     AND depn.attribute6 = hfal.lookup_code(+)
                     AND hfal.lookup_type(+) = 'RHPRO_ARG_ID_TYPE'
                     AND hfal.function_type(+) = 'ID Type'
                     AND p_current_run_date BETWEEN hfal.effective_start_date(+) AND hfal.effective_end_date(+)
                     AND (   p_cut_off_date BETWEEN papfe.effective_start_date AND papfe.effective_end_date
                          OR papfe.effective_start_date BETWEEN p_cut_off_date
                                                            AND GREATEST (p_current_run_date,
                                                                          rel.date_start
                                                                         )
                          OR papfe.effective_end_date BETWEEN p_cut_off_date
                                                          AND GREATEST (p_current_run_date,
                                                                        rel.date_start
                                                                       )
                         )
                     AND (   p_cut_off_date BETWEEN pptuf.effective_start_date AND pptuf.effective_end_date
                          OR pptuf.effective_start_date BETWEEN p_cut_off_date
                                                            AND GREATEST (p_current_run_date,
                                                                          rel.date_start
                                                                         )
                          OR pptuf.effective_end_date BETWEEN p_cut_off_date
                                                          AND GREATEST (p_current_run_date,
                                                                        rel.date_start
                                                                       )
                         )
                     AND (   TRUNC (depn.creation_date) BETWEEN p_cut_off_date
                                                            AND GREATEST (p_current_run_date,
                                                                          --Version 1.2
                                                                          rel.date_start
                                                                         )
                          OR TRUNC (depn.last_update_date) BETWEEN p_cut_off_date
                                                               AND GREATEST (p_current_run_date,
                                                                             --Version 1.2
                                                                             rel.date_start
                                                                            )
                         )
                     AND depn.business_group_id = papfe.business_group_id
                     AND papfe.business_group_id = rel.business_group_id
                     AND rel.business_group_id = ppt.business_group_id
                     AND rel.contact_type = relt.lookup_code
                     AND relt.lookup_type = 'CONTACT'
                     AND relt.LANGUAGE(+) = 'ESA'
                     AND relt.security_group_id(+) = 24
                     AND UPPER (ppt.user_person_type) IN ('CONTACT')
                     AND rel.contact_type <> 'EMRG'
                     AND rel.cont_attribute3 = ffvv.flex_value(+)
                     AND ffvv.flex_value_set_id(+) = '1015847'
                     AND depn.national_identifier IS NOT NULL
                     AND papfe.employee_number IS NOT NULL
                ORDER BY 1;

      v_return_msg   VARCHAR2 (240);
      v_status       BOOLEAN;
   BEGIN
      g_e_error_hand.module_name := 'init_602_intf';
      init_error_msg (g_e_error_hand.module_name);
      get_file_open (p_file_name);
      fnd_file.put_line (fnd_file.output, 'FILE_NAME -' || p_file_name);

      FOR r_602_intf IN c_602_intf
      LOOP
         fnd_file.put_line (fnd_file.output,
                            'START - 602 - Employee_number -' || r_602_intf."Leg.del empleado asociado"
                           );
         v_rec := NULL;
         v_rec :=
               cvt_char (r_602_intf."Leg.del empleado asociado")
            || ';'
            || cvt_char (r_602_intf."Apellido")
            || ';'
            || cvt_char (r_602_intf."Nombres")
            || ';'
            || TO_CHAR (r_602_intf."Fecha de Nacimiento", 'DD/MM/YYYY')
            || ';'
            || cvt_char (r_602_intf."País de Nacimiento")
            || ';'
            || cvt_char (r_602_intf."Nacionalidad")
            || ';'
            || cvt_char (r_602_intf."Est.Civil")
            || ';'
            || cvt_char (r_602_intf."Sexo")
            || ';'
            || cvt_char (r_602_intf."Parentesco")
            || ';'
            || r_602_intf."Incapacitado"
            || ';'
            || r_602_intf."Estudia"
            || ';'
            || cvt_char (r_602_intf."Nivel de Estudio")
            || ';'
            || cvt_char (r_602_intf."Tipo Documento")
            || ';'
            || cvt_char (r_602_intf."Nro. Documento")
            || ';'
            || r_602_intf."Calle"
            || ';'
            || r_602_intf."Nro."
            || ';'
            || r_602_intf."Piso"
            || ';'
            || r_602_intf."Depto."
            || ';'
            || r_602_intf."Torre"
            || ';'
            || r_602_intf."Manzana"
            || ';'
            || r_602_intf."Cpostal"
            || ';'
            || r_602_intf."Entre Calles"
            || ';'
            || r_602_intf."Barrio"
            || ';'
            || r_602_intf."Localidad"
            || ';'
            || r_602_intf."Partido"
            || ';'
            || r_602_intf."Zona"
            || ';'
            || r_602_intf."Provincia"
            || ';'
            || r_602_intf."País"
            || ';'
            || r_602_intf."Telefono"
            || ';'
            || r_602_intf."Obra Social"
            || ';'
            || r_602_intf."Plan OS"
            || ';'
            || r_602_intf."Avisar ante Emergencia"
            || ';'
            || r_602_intf."Paga Salario Familiar"
            || ';'
            || r_602_intf."Ganancias"
            || ';'
            || r_602_intf."Fecha de Inicio Vinculo"
            || ';'
            || r_602_intf."Fecha vencimiento vinculo"
            || ';'
            || r_602_intf."Item DDJJ"
            || ';'
            || r_602_intf."Año DDJJ"
            || ';'
            || r_602_intf."New1"
            || ';'
            || r_602_intf."New2";
         v_rec := REPLACE (v_rec, '  ;', ';');                                              --Version 1.1
         UTL_FILE.put_line (v_output_file, v_rec);
         g_success_count := g_success_count + 1;
         fnd_file.put_line (fnd_file.output,
                            'END - 602 - Employee_number -' || r_602_intf."Leg.del empleado asociado"
                           );
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
         raise_application_error (-20003, 'Exception NO_DATA_FOUND in init_602_intf' || v_msg);
         g_e_program_run_status := 1;
      WHEN OTHERS
      THEN
         g_error_count := g_error_count + 1;
         print_count (g_success_count, g_error_count, g_e_error_hand.module_name);
         UTL_FILE.fclose (v_output_file);
         log_error ('SQLCODE', TO_CHAR (SQLCODE), 'Error Message', SUBSTR (SQLERRM, 1, 64));
         print_line ('Error in module: ' || g_e_error_hand.module_name);
         v_msg := SQLERRM;
         raise_application_error (-20003, 'Exception OTHERS in init_602_intf' || v_msg);
         g_e_program_run_status := 1;
   END;

--The 211-Importación de Novedades (Exceptions-Payroll News) interface is used to feed RHPro with all updated salary information for each employee.
   PROCEDURE init_211s_intf (
      p_file_name           IN   VARCHAR2,
      p_business_group_id        NUMBER,
      p_cut_off_date             DATE,
      p_current_run_date         DATE
   )
   IS
      CURSOR c_211s_intf
      IS
         SELECT DISTINCT pap.employee_number "Legajo", '01000' "Concepto", '1' "parametro",
                         ppp.proposed_salary_n "Monto",
                         TO_CHAR (TRUNC (GREATEST (p_current_run_date, ppp.change_date), 'MON'),
                                  'DD/MM/YYYY'
                                 ) "Fecha Desde",
                         TO_CHAR (LAST_DAY (GREATEST (p_current_run_date, ppp.change_date)),
                                  'DD/MM/YYYY'
                                 ) "Fecha Hasta",
                         'N/A' "Marca Retroactividad", 'N/A' "Periodo Desde", 'N/A' "Periodo Hasta"
                   --START R12.2 Upgrade Remediation
				   /*FROM hr.per_all_assignments_f paa,				-- Commented code by IXPRAVEEN-ARGANO,08-May-2023
                         hr.per_all_people_f pap,
                         hr.per_periods_of_service pps,
                         hr.per_pay_proposals ppp*/
					FROM apps.per_all_assignments_f paa,			--  code Added by IXPRAVEEN-ARGANO,08-May-2023
                         apps.per_all_people_f pap,
                         apps.per_periods_of_service pps,
                         apps.per_pay_proposals ppp	 
					--END R12.2.10 Upgrade remediation	 
                   WHERE paa.person_id = pap.person_id
                     AND paa.person_id = pps.person_id
                     AND paa.primary_flag = 'Y'
                     AND pap.current_employee_flag = 'Y'
                     AND pap.business_group_id = p_business_group_id
                     AND paa.assignment_id = ppp.assignment_id
                     AND paa.period_of_service_id = pps.period_of_service_id
                     AND (   p_cut_off_date BETWEEN pap.effective_start_date AND pap.effective_end_date
                          OR pap.effective_start_date BETWEEN p_cut_off_date
                                                          AND GREATEST (p_current_run_date,
                                                                        pps.date_start
                                                                       )
                          OR pap.effective_end_date BETWEEN p_cut_off_date
                                                        AND GREATEST (p_current_run_date, pps.date_start)
                         )
                     AND (   p_cut_off_date BETWEEN paa.effective_start_date AND paa.effective_end_date
                          OR paa.effective_start_date BETWEEN p_cut_off_date
                                                          AND GREATEST (p_current_run_date,
                                                                        pps.date_start
                                                                       )
                          OR paa.effective_end_date BETWEEN p_cut_off_date
                                                        AND GREATEST (p_current_run_date, pps.date_start)
                         )
                     AND (   TRUNC (ppp.creation_date) BETWEEN p_cut_off_date
                                                           AND GREATEST (p_current_run_date,
                                                                         pps.date_start
                                                                        )
                          OR TRUNC (ppp.last_update_date) BETWEEN p_cut_off_date
                                                              AND GREATEST (p_current_run_date,
                                                                            pps.date_start
                                                                           )
                         )
                     --Version 1.2
                     AND (   p_cut_off_date BETWEEN ppp.change_date AND ppp.date_to
                          OR ppp.change_date BETWEEN p_cut_off_date
                                                 AND GREATEST (p_current_run_date, pps.date_start)
                          OR ppp.date_to BETWEEN p_cut_off_date
                                             AND GREATEST (p_current_run_date, pps.date_start)
                         )
                     AND pps.actual_termination_date IS NULL
                     AND TO_CHAR (date_to, 'YYYY') = '4712'
                ORDER BY pap.employee_number;
   BEGIN
      g_e_error_hand.module_name := 'init_211s_intf';
      init_error_msg (g_e_error_hand.module_name);
      get_file_open (p_file_name);
      fnd_file.put_line (fnd_file.output, 'FILE_NAME -' || p_file_name);

      FOR r_211s_intf IN c_211s_intf
      LOOP
         fnd_file.put_line (fnd_file.output, 'START - 211s - Employee_number -' || r_211s_intf."Legajo");
         v_rec := NULL;
         v_rec :=
               cvt_char (r_211s_intf."Legajo")
            || ';'
            || cvt_char (r_211s_intf."Concepto")
            || ';'
            || r_211s_intf."parametro"
            || ';'
            || ROUND (r_211s_intf."Monto", 2)
            || ';'
            || r_211s_intf."Fecha Desde"
            || ';'
            || r_211s_intf."Fecha Hasta"
            || ';'
            || r_211s_intf."Marca Retroactividad"
            || ';'
            || r_211s_intf."Periodo Desde"
            || ';'
            || r_211s_intf."Periodo Hasta";
         v_rec := REPLACE (v_rec, '  ;', ';');                                              --Version 1.1
         UTL_FILE.put_line (v_output_file, v_rec);
         g_success_count := g_success_count + 1;
         fnd_file.put_line (fnd_file.output, 'START - 211s - Employee_number -' || r_211s_intf."Legajo");
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
         raise_application_error (-20003, 'Exception NO_DATA_FOUND in init_211s_intf' || v_msg);
         g_e_program_run_status := 1;
      WHEN OTHERS
      THEN
         g_error_count := g_error_count + 1;
         print_count (g_success_count, g_error_count, g_e_error_hand.module_name);
         UTL_FILE.fclose (v_output_file);
         log_error ('SQLCODE', TO_CHAR (SQLCODE), 'Error Message', SUBSTR (SQLERRM, 1, 64));
         print_line ('Error in module: ' || g_e_error_hand.module_name);
         v_msg := SQLERRM;
         raise_application_error (-20003, 'Exception OTHERS in init_211s_intf' || v_msg);
         g_e_program_run_status := 1;
   END;

-- The 630-Importación de Histórico de Estructuras (Assignment ) interface will be run on a daily basis and will feed
-- RHPro with changes in structures associated to the employee.
   PROCEDURE init_630_intf (
      p_file_name           IN   VARCHAR2,
      p_business_group_id        NUMBER,
      p_cut_off_date             DATE,
      p_current_run_date         DATE
   )
   IS
      CURSOR c_630_intf
      IS
         SELECT   *
             FROM (SELECT DISTINCT pap.employee_number "Legajo", paa.assignment_id, pap.person_id,
                                   TO_CHAR (paa.effective_start_date, 'DD/MM/YYYY') effective_start_date,
                                   'N/A' effective_end_date,
                                   TRUNC (paa.effective_start_date) effective_date,
                                   NVL (paa.ass_attribute14, 'N/A') ass_attribute14, paa.normal_hours
                              --START R12.2 Upgrade Remediation
							  /*FROM hr.per_all_assignments_f paa,				-- Commented code by IXPRAVEEN-ARGANO,08-May-2023
                                   hr.per_all_people_f pap,
                                   hr.per_periods_of_service pps,
                                   hr.per_people_extra_info pei*/
							  FROM apps.per_all_assignments_f paa,				--  code Added by IXPRAVEEN-ARGANO,08-May-2023
                                   apps.per_all_people_f pap,
                                   apps.per_periods_of_service pps,
                                   apps.per_people_extra_info pei	
							--END R12.2.10 Upgrade remediation			
                             WHERE paa.person_id = pap.person_id
                               AND paa.person_id = pps.person_id
                               AND pap.person_id = pei.person_id
                               AND paa.primary_flag = 'Y'
                               AND pap.current_employee_flag = 'Y'
                               AND pei.pei_information_category = 'TTEC_ARG_ENTITIES'
                               AND pap.business_group_id = p_business_group_id
                               AND (   p_cut_off_date BETWEEN pap.effective_start_date
                                                          AND pap.effective_end_date
                                    OR pap.effective_start_date BETWEEN p_cut_off_date
                                                                    AND GREATEST (p_current_run_date,
                                                                                  pps.date_start
                                                                                 )
                                    OR pap.effective_end_date BETWEEN p_cut_off_date
                                                                  AND GREATEST (p_current_run_date,
                                                                                pps.date_start
                                                                               )
                                   )
                               AND (p_cut_off_date BETWEEN paa.effective_start_date
                                                       AND paa.effective_end_date
--                                    OR paa.effective_start_date BETWEEN p_cut_off_date                    -- Version 1.7
--                                                                    AND GREATEST (p_current_run_date,
--                                                                                  pps.date_start
--                                                                                 )
--                                    OR paa.effective_end_date BETWEEN p_cut_off_date
--                                                                  AND GREATEST (p_current_run_date,
--                                                                                pps.date_start
--                                                                               )
                                   )
                               AND (   TRUNC (pei.creation_date) BETWEEN p_cut_off_date
                                                                     AND GREATEST (p_current_run_date,
                                                                                   pps.date_start
                                                                                  )
                                    OR TRUNC (pei.last_update_date) BETWEEN p_cut_off_date
                                                                        AND GREATEST (p_current_run_date,
                                                                                      pps.date_start
                                                                                     )
                                   )
                               AND pps.actual_termination_date IS NULL
                   --  AND TO_CHAR (paa.effective_end_date, 'YYYY') = '4712'        --Version 1.7
                   UNION
                   SELECT DISTINCT pap.employee_number "Legajo", paa.assignment_id, pap.person_id,
                                   TO_CHAR (paa.effective_start_date, 'DD/MM/YYYY') effective_start_date,
                                   'N/A' effective_end_date,
                                   TRUNC (paa.effective_start_date) effective_date,
                                   NVL (paa.ass_attribute14, 'N/A') ass_attribute14, paa.normal_hours
                              --START R12.2 Upgrade Remediation
							  /*FROM hr.per_all_assignments_f paa,		-- Commented code by IXPRAVEEN-ARGANO,08-May-2023
                                   hr.per_all_people_f pap,
                                   hr.per_periods_of_service pps*/
							  FROM apps.per_all_assignments_f paa,		--  code Added by IXPRAVEEN-ARGANO,08-May-2023
                                   apps.per_all_people_f pap,
                                   apps.per_periods_of_service pps	
							--END R12.2.10 Upgrade remediation		
                             WHERE paa.person_id = pap.person_id
                               AND paa.person_id = pps.person_id
                               AND paa.primary_flag = 'Y'
                               AND pap.current_employee_flag = 'Y'
                               AND pap.business_group_id = p_business_group_id
                               AND (   p_cut_off_date BETWEEN pap.effective_start_date
                                                          AND pap.effective_end_date
                                    OR pap.effective_start_date BETWEEN p_cut_off_date
                                                                    AND GREATEST (p_current_run_date,
                                                                                  pps.date_start
                                                                                 )
                                    OR pap.effective_end_date BETWEEN p_cut_off_date
                                                                  AND GREATEST (p_current_run_date,
                                                                                pps.date_start
                                                                               )
                                   )
                               AND (   TRUNC (paa.creation_date) BETWEEN p_cut_off_date
                                                                     AND GREATEST (p_current_run_date,
                                                                                   pps.date_start
                                                                                  )
                                    OR TRUNC (paa.last_update_date) BETWEEN p_cut_off_date
                                                                        AND GREATEST (p_current_run_date,
                                                                                      pps.date_start
                                                                                     )
                                   )
                               AND pps.actual_termination_date IS NULL
                               AND TO_CHAR (paa.effective_end_date, 'YYYY') = '4712'
                   UNION                                                           -- Version 1.4 <start>
                   SELECT DISTINCT pap.employee_number "Legajo", paa.assignment_id, pap.person_id,
                                   TO_CHAR (paa.effective_start_date, 'DD/MM/YYYY') effective_start_date,
                                   'N/A' effective_end_date,
                                   TRUNC (paa.effective_start_date) effective_date,
                                   NVL (paa.ass_attribute14, 'N/A') ass_attribute14, paa.normal_hours
                             --START R12.2 Upgrade Remediation
							 /*FROM hr.per_all_assignments_f paa,			-- Commented code by IXPRAVEEN-ARGANO,08-May-2023
                                   hr.per_all_people_f pap,
                                   hr.per_periods_of_service pps,
                                   cust.ttec_emp_proj_asg tepa*/
							  FROM apps.per_all_assignments_f paa,			--  code Added by IXPRAVEEN-ARGANO,08-May-2023
                                   apps.per_all_people_f pap,
                                   apps.per_periods_of_service pps,
                                   apps.ttec_emp_proj_asg tepa	
							--END R12.2.10 Upgrade remediation		
                             WHERE paa.person_id = pap.person_id
                               AND paa.person_id = pps.person_id
                               AND paa.primary_flag = 'Y'
                               AND pap.current_employee_flag = 'Y'
                               AND paa.person_id = tepa.person_id
                               AND pap.business_group_id = p_business_group_id
                               AND (   p_cut_off_date BETWEEN pap.effective_start_date
                                                          AND pap.effective_end_date
                                    OR pap.effective_start_date BETWEEN p_cut_off_date
                                                                    AND GREATEST (p_current_run_date,
                                                                                  pps.date_start
                                                                                 )
                                    OR pap.effective_end_date BETWEEN p_cut_off_date
                                                                  AND GREATEST (p_current_run_date,
                                                                                pps.date_start
                                                                               )
                                   )
                               AND (p_cut_off_date BETWEEN paa.effective_start_date
                                                       AND paa.effective_end_date
--                                    OR paa.effective_start_date BETWEEN p_cut_off_date                    -- Version 1.7
--                                                                    AND GREATEST (p_current_run_date,
--                                                                                  pps.date_start
--                                                                                 )
--                                    OR paa.effective_end_date BETWEEN p_cut_off_date
--                                                                  AND GREATEST (p_current_run_date,
--                                                                                pps.date_start
--                                                                               )
                                   )
                               AND (   TRUNC (tepa.creation_date) BETWEEN p_cut_off_date
                                                                      AND GREATEST (p_current_run_date,
                                                                                    pps.date_start
                                                                                   )
                                    OR TRUNC (tepa.last_update_date) BETWEEN p_cut_off_date
                                                                         AND GREATEST
                                                                                     (p_current_run_date,
                                                                                      pps.date_start
                                                                                     )
                                   )
                               AND pps.actual_termination_date IS NULL
                                                                      -- AND TO_CHAR (paa.effective_end_date, 'YYYY') = '4712'  -- Version 1.7
                                                                                                                            -- Version 1.4 <End>
                  ) DUAL
         ORDER BY "Legajo";

      CURSOR c_payroll_name (p_assign_id NUMBER, p_effective_date DATE)                    -- Version 1.4
      IS
         SELECT DISTINCT ppf.payroll_name
		 --START R12.2 Upgrade Remediation
                    /*FROM hr.per_all_assignments_f paa,		-- Commented code by IXPRAVEEN-ARGANO,08-May-2023
                         hr.per_all_people_f pap,
                         hr.per_periods_of_service pps,
                         pay_payrolls_f ppf*/
					FROM apps.per_all_assignments_f paa,		--  code Added by IXPRAVEEN-ARGANO,08-May-2023
                         apps.per_all_people_f pap,
                         apps.per_periods_of_service pps,
                         pay_payrolls_f ppf	 				 
			 --END R12.2.10 Upgrade remediation		 
                   WHERE paa.person_id = pap.person_id
                     AND paa.person_id = pps.person_id
                     AND paa.payroll_id = ppf.payroll_id
                     AND paa.assignment_id = p_assign_id
                     AND paa.primary_flag = 'Y'
                     AND pap.current_employee_flag = 'Y'
                     AND GREATEST (p_effective_date, pps.date_start) BETWEEN ppf.effective_start_date
                                                                         --Version 1.2
                                                                     AND ppf.effective_end_date
                     AND GREATEST (p_effective_date, pps.date_start) BETWEEN pap.effective_start_date
                                                                         --Version 1.2
                                                                     AND pap.effective_end_date
                     AND GREATEST (p_effective_date, pps.date_start) BETWEEN paa.effective_start_date
                                                                         --Version 1.2
                                                                     AND paa.effective_end_date
                     AND pps.actual_termination_date IS NULL;

      CURSOR c_supervisor (p_assign_id NUMBER, p_effective_date DATE)                      -- Version 1.4
      IS
         SELECT DISTINCT DECODE (papfe2.business_group_id,
                                 1632, papfe2.employee_number,
                                 'N/A'
                                ) "Nro legajo Super"
                    FROM per_all_assignments_f paafe,
                         per_all_people_f papfe,
                         per_periods_of_service ppos,
                         per_all_people_f papfe2,
                         per_all_assignments_f paafe2,
                         per_person_type_usages_f pptuf,
                         per_person_types ppt,
                         per_person_type_usages_f pptuf2,
                         per_person_types ppt2,
                         per_periods_of_service ppos2
                   WHERE papfe.employee_number IS NOT NULL
                     AND paafe.person_id = papfe.person_id
                     AND paafe.assignment_id = p_assign_id
                     AND paafe.person_id = ppos.person_id
                     AND papfe.person_id = pptuf.person_id
                     AND paafe.primary_flag = 'Y'
                     AND papfe2.current_employee_flag = 'Y'
                     AND pptuf.person_type_id = ppt.person_type_id
                     AND UPPER (ppt.user_person_type) IN ('EMPLOYEE', 'EXTERNAL')
                     AND papfe.business_group_id = paafe.business_group_id
                     AND paafe.business_group_id = ppos.business_group_id
                     AND papfe.business_group_id = ppt.business_group_id
                     AND ppos.period_of_service_id = paafe.period_of_service_id
                     AND papfe2.person_id = paafe.supervisor_id
                     AND paafe2.person_id = papfe2.person_id
                     AND papfe2.person_id = pptuf2.person_id
                     AND paafe2.person_id = ppos2.person_id
                     AND paafe2.primary_flag = 'Y'
                     AND papfe2.current_employee_flag = 'Y'
                     AND pptuf2.person_type_id = ppt2.person_type_id
                     AND papfe2.person_type_id = ppt2.person_type_id
                     AND ppos2.period_of_service_id = paafe2.period_of_service_id
                     AND UPPER (ppt2.user_person_type) IN ('EMPLOYEE', 'EXTERNAL')
                     AND ppos.actual_termination_date IS NULL
                     AND ppos2.actual_termination_date IS NULL
                     AND GREATEST (p_effective_date, ppos.date_start) BETWEEN paafe.effective_start_date
                                                                          --Version 1.2
                                                                      AND paafe.effective_end_date
                     AND GREATEST (p_effective_date, ppos.date_start) BETWEEN papfe.effective_start_date
                                                                          --Version 1.2
                                                                      AND papfe.effective_end_date
                     AND GREATEST (p_effective_date, ppos.date_start) BETWEEN pptuf.effective_start_date
                                                                          --Version 1.2
                                                                      AND pptuf.effective_end_date
                     AND p_effective_date BETWEEN paafe2.effective_start_date AND paafe2.effective_end_date
                     AND p_effective_date BETWEEN papfe2.effective_start_date AND papfe2.effective_end_date
                     AND p_effective_date BETWEEN pptuf2.effective_start_date AND pptuf2.effective_end_date;

      CURSOR c_altcode
      IS
         SELECT alternate_code
           FROM hr_fr_alternate_lookups
          WHERE lookup_code = 'INC'
            AND lookup_type = 'RHPRO_ARG_DEFAULTS'
            AND function_type = 'Default Value'
            AND p_current_run_date BETWEEN effective_start_date AND effective_end_date;

      CURSOR c_lifeinscode
      IS
         SELECT alternate_code
           FROM hr_fr_alternate_lookups
          WHERE lookup_code = 'SEG'
            AND lookup_type = 'RHPRO_ARG_DEFAULTS'
            AND function_type = 'Default Value'
            AND p_current_run_date BETWEEN effective_start_date AND effective_end_date;

      CURSOR c_loccode (p_assign_id NUMBER, p_effective_date DATE)                         -- Version 1.4
      IS
         SELECT DISTINCT hla.location_code
                    --START R12.2 Upgrade Remediation
					/*FROM hr.per_all_assignments_f paa,			 -- Commented code by IXPRAVEEN-ARGANO,08-May-2023
                         hr.per_all_people_f pap,
                         hr.per_periods_of_service pps,
                         hr_locations_all hla*/
					FROM apps.per_all_assignments_f paa,			--  code Added by IXPRAVEEN-ARGANO,08-May-2023
                         apps.per_all_people_f pap,
                         apps.per_periods_of_service pps,
                         hr_locations_all hla	
					--END R12.2.10 Upgrade remediation		
                   WHERE paa.person_id = pap.person_id
                     AND paa.person_id = pps.person_id
                     AND paa.primary_flag = 'Y'
                     AND pap.current_employee_flag = 'Y'
                     AND paa.location_id = hla.location_id
                     AND paa.assignment_id = p_assign_id
                     AND GREATEST (p_effective_date, pps.date_start) BETWEEN pap.effective_start_date
                                                                         AND pap.effective_end_date
                     AND GREATEST (p_effective_date, pps.date_start) BETWEEN paa.effective_start_date
                                                                         AND paa.effective_end_date
                     AND NVL (hla.inactive_date, GREATEST (p_effective_date, pps.date_start)) >=
                                                              GREATEST (p_effective_date, pps.date_start)
                     AND pps.actual_termination_date IS NULL;

      CURSOR c_cltcode (p_assign_id NUMBER, p_effective_date DATE)                         -- Version 1.4
      IS
         SELECT DISTINCT    tepa.clt_cd
                         || ' '
                         || DECODE (tepa.clt_cd, '4001', 'ORANGE - IB CUSTOMER CARE', tepa.client_desc)
                                                                                                "Sector",
                         tepa.prj_strt_dt, 'N/A' prj_end_dt
                   --START R12.2 Upgrade Remediation
				   /*FROM hr.per_all_assignments_f paa,			-- Commented code by IXPRAVEEN-ARGANO,08-May-2023
                         hr.per_all_people_f pap,
                         hr.per_periods_of_service pps,
                         cust.ttec_emp_proj_asg tepa*/
					FROM apps.per_all_assignments_f paa,		--  code Added by IXPRAVEEN-ARGANO,08-May-2023
                         apps.per_all_people_f pap,
                         apps.per_periods_of_service pps,
                         apps.ttec_emp_proj_asg tepa
					--END R12.2.10 Upgrade remediation		
                   WHERE paa.person_id = pap.person_id
                     AND paa.person_id = pps.person_id
                     AND paa.primary_flag = 'Y'
                     AND pap.current_employee_flag = 'Y'
                     AND paa.assignment_id = p_assign_id
                     AND paa.person_id = tepa.person_id
                     AND GREATEST (p_effective_date, pps.date_start) BETWEEN pap.effective_start_date
                                                                         --Version 1.2
                                                                     AND pap.effective_end_date
                     AND GREATEST (p_effective_date, pps.date_start) BETWEEN paa.effective_start_date
                                                                         --Version 1.2
                                                                     AND paa.effective_end_date
                     AND TRUNC (tepa.prj_strt_dt) = (SELECT   MAX (TRUNC (tepa1.prj_strt_dt))
                                                         -- Version 1.4
                                                     --FROM     cust.ttec_emp_proj_asg tepa1			-- Commented code by IXPRAVEEN-ARGANO,08-May-2023
													 FROM     apps.ttec_emp_proj_asg tepa1			--  code Added by IXPRAVEEN-ARGANO,08-May-2023
                                                        WHERE tepa1.person_id(+) = pap.person_id
                                                     GROUP BY 1)
--                     AND GREATEST (p_effective_date, pps.date_start) BETWEEN tepa.prj_strt_dt
--                                                                         AND NVL
--                                                                               (tepa.prj_end_dt,
--                                                                                GREATEST
--                                                                                       (p_effective_date,
--                                                                                        pps.date_start
--                                                                                       )
--                                                                               )
                     AND pps.actual_termination_date IS NULL;

      CURSOR c_categoria (p_assign_id NUMBER, p_effective_date DATE)                       -- Version 1.4
      IS
         SELECT CASE
                   WHEN paa.ass_attribute11 = '13075'
                      THEN NVL (flv.meaning, 'N/A')
                   ELSE 'Fuera de Convenio'
                END "Categoria"
				--START R12.2 Upgrade Remediation
           /*FROM hr.per_all_assignments_f paa,		-- Commented code by IXPRAVEEN-ARGANO,08-May-2023
                hr.per_all_people_f pap,
                hr.per_periods_of_service pps,
                apps.fnd_lookup_values flv*/
		   FROM apps.per_all_assignments_f paa,		--  code Added by IXPRAVEEN-ARGANO,08-May-2023
                apps.per_all_people_f pap,
                apps.per_periods_of_service pps,
                apps.fnd_lookup_values flv	
					--END R12.2.10 Upgrade remediation
          WHERE paa.person_id = pap.person_id
            AND paa.person_id = pps.person_id
            AND paa.primary_flag = 'Y'
            AND pap.current_employee_flag = 'Y'
            AND paa.bargaining_unit_code = flv.lookup_code(+)
            AND flv.lookup_type(+) = 'BARGAINING_UNIT_CODE'
            AND flv.LANGUAGE(+) = 'ESA'
            AND flv.enabled_flag(+) = 'Y'
            AND paa.assignment_id = p_assign_id
            AND GREATEST (p_effective_date, pps.date_start) BETWEEN pap.effective_start_date
                                                                --Version 1.2
                                                            AND pap.effective_end_date
            AND GREATEST (p_effective_date, pps.date_start) BETWEEN paa.effective_start_date
                                                                AND paa.effective_end_date
            AND pps.actual_termination_date IS NULL;

      CURSOR c_convenio (p_assign_id NUMBER, p_effective_date DATE)                        -- Version 1.4
      IS
         SELECT DISTINCT ffvt.description
                   --START R12.2 Upgrade Remediation
				   /*FROM hr.per_all_assignments_f paa,		-- Commented code by IXPRAVEEN-ARGANO,08-May-2023
                         hr.per_all_people_f pap,
                         hr.per_periods_of_service pps,
                         apps.fnd_flex_values ffv,
                         apps.fnd_flex_values_tl ffvt*/
					FROM apps.per_all_assignments_f paa,		--  code Added by IXPRAVEEN-ARGANO,08-May-2023
                         apps.per_all_people_f pap,
                         apps.per_periods_of_service pps,
                         apps.fnd_flex_values ffv,
                         apps.fnd_flex_values_tl ffvt
							--END R12.2.10 Upgrade remediation
                   WHERE paa.person_id = pap.person_id
                     AND paa.person_id = pps.person_id
                     AND paa.primary_flag = 'Y'
                     AND pap.current_employee_flag = 'Y'
                     AND ffv.flex_value_id = ffvt.flex_value_id
                     AND paa.ass_attribute11 = ffv.flex_value
                     AND ffv.flex_value_set_id = '1010056'
                     AND paa.assignment_id = p_assign_id
                     AND ffvt.LANGUAGE = 'ESA'
                     AND GREATEST (p_effective_date, pps.date_start) BETWEEN pap.effective_start_date
                                                                         --Version 1.2
                                                                     AND pap.effective_end_date
                     AND GREATEST (p_effective_date, pps.date_start) BETWEEN paa.effective_start_date
                                                                         AND paa.effective_end_date
                     AND pps.actual_termination_date IS NULL;

      CURSOR c_job (p_assign_id NUMBER, p_effective_date DATE)                             -- Version 1.4
      IS
         SELECT CASE
                   WHEN paa.ass_attribute11 = '13075'
                      THEN NVL (paa.ass_attribute15, NVL (pj.attribute15, pjd.segment2))
                   ELSE pjd.segment2
                END "puesto",
                pj.attribute14 "Gerencia"
           --START R12.2 Upgrade Remediation
		   /*FROM hr.per_all_assignments_f paa,				-- Commented code by IXPRAVEEN-ARGANO,08-May-2023
                hr.per_all_people_f pap,
                hr.per_periods_of_service pps,
                per_jobs pj,
                per_job_definitions pjd*/
		   FROM apps.per_all_assignments_f paa,				--  code Added by IXPRAVEEN-ARGANO,08-May-2023
                apps.per_all_people_f pap,
                apps.per_periods_of_service pps,
                per_jobs pj,
                per_job_definitions pjd	
			--END R12.2.10 Upgrade remediation		
          WHERE paa.person_id = pap.person_id
            AND paa.person_id = pps.person_id
            AND paa.primary_flag = 'Y'
            AND pap.current_employee_flag = 'Y'
            AND paa.job_id = pj.job_id
            AND paa.assignment_id = p_assign_id
            AND pj.job_definition_id = pjd.job_definition_id
            AND GREATEST (p_effective_date, pps.date_start) BETWEEN pap.effective_start_date
                                                                AND pap.effective_end_date
            AND GREATEST (p_effective_date, pps.date_start) BETWEEN paa.effective_start_date
                                                                AND paa.effective_end_date
            AND pps.actual_termination_date IS NULL;

      CURSOR c_dept (p_assign_id NUMBER, p_effective_date DATE)                            -- Version 1.4
      IS
         SELECT DISTINCT haou.NAME
                   --START R12.2 Upgrade Remediation
				   /*FROM hr.per_all_assignments_f paa,					-- Commented code by IXPRAVEEN-ARGANO,08-May-2023
                         hr.per_all_people_f pap,
                         hr.per_periods_of_service pps,
                         hr_all_organization_units haou*/
					FROM apps.per_all_assignments_f paa,				--  code Added by IXPRAVEEN-ARGANO,08-May-2023
                         apps.per_all_people_f pap,
                         apps.per_periods_of_service pps,
                         hr_all_organization_units haou	
					--END R12.2.10 Upgrade remediation		
                   WHERE paa.person_id = pap.person_id
                     AND paa.person_id = pps.person_id
                     AND paa.primary_flag = 'Y'
                     AND pap.current_employee_flag = 'Y'
                     AND paa.organization_id = haou.organization_id
                     AND paa.assignment_id = p_assign_id
                     AND GREATEST (p_effective_date, pps.date_start) BETWEEN haou.date_from
                                                                         AND NVL
                                                                               (haou.date_to,
                                                                                GREATEST
                                                                                       (p_effective_date,
                                                                                        pps.date_start
                                                                                       )
                                                                               )
                     AND GREATEST (p_effective_date, pps.date_start) BETWEEN pap.effective_start_date
                                                                         AND pap.effective_end_date
                     AND GREATEST (p_effective_date, pps.date_start) BETWEEN paa.effective_start_date
                                                                         AND paa.effective_end_date
                     AND pps.actual_termination_date IS NULL;

      CURSOR c_obra_social (p_assign_id NUMBER, p_effective_date DATE)                     -- Version 1.4
      IS
         SELECT DISTINCT pei.pei_information1 "Obra Social Ley",
                         TO_DATE (pei.pei_information2, 'YYYY/MM/DD HH24:MI:SS') strt_dt, 'N/A' end_dt
                  --START R12.2 Upgrade Remediation
				  /*FROM hr.per_all_assignments_f paa,				-- Commented code by IXPRAVEEN-ARGANO,08-May-2023
                         hr.per_all_people_f pap,
                         hr.per_periods_of_service pps,
                         per_people_extra_info pei*/
					FROM apps.per_all_assignments_f paa,			--  code Added by IXPRAVEEN-ARGANO,08-May-2023
                         apps.per_all_people_f pap,
                         apps.per_periods_of_service pps,
                         per_people_extra_info pei	 
				 --END R12.2.10 Upgrade remediation		 
                   WHERE paa.person_id = pap.person_id
                     AND paa.person_id = pps.person_id
                     AND paa.assignment_id = p_assign_id
                     AND paa.primary_flag = 'Y'
                     AND pap.current_employee_flag = 'Y'
                     AND pei.person_id(+) = pap.person_id
                     AND pei.pei_information_category(+) = 'TTEC_ARG_ENTITIES'
                     AND GREATEST (p_effective_date, pps.date_start) BETWEEN pap.effective_start_date
                                                                         AND pap.effective_end_date
                     AND GREATEST (p_effective_date, pps.date_start) BETWEEN paa.effective_start_date
                                                                         AND paa.effective_end_date
                     AND TO_DATE (pei.pei_information2, 'YYYY/MM/DD HH24:MI:SS') =
                                 (SELECT   MAX (TO_DATE (pei2.pei_information2, 'YYYY/MM/DD HH24:MI:SS'))
                                      FROM per_people_extra_info pei2
                                     WHERE pei2.person_id(+) = pap.person_id
                                           AND pei2.pei_information_category(+) = 'TTEC_ARG_ENTITIES'
                                  GROUP BY 1)
--                     AND (GREATEST (p_current_run_date, pps.date_start)
--                            BETWEEN TO_DATE (pei.pei_information2, 'YYYY/MM/DD HH24:MI:SS')
--                                AND NVL (TO_DATE (pei.pei_information3, 'YYYY/MM/DD HH24:MI:SS'),
--                                         GREATEST (p_current_run_date, pps.date_start)
--                                        )
                     AND pps.actual_termination_date IS NULL;
   BEGIN
      g_e_error_hand.module_name := 'init_630_intf';
      init_error_msg (g_e_error_hand.module_name);
      get_file_open (p_file_name);
      fnd_file.put_line (fnd_file.output, 'FILE_NAME -' || p_file_name);

      FOR r_630_intf IN c_630_intf
      LOOP
         BEGIN
            fnd_file.put_line (fnd_file.output,
                               'START - 630 - Assignment_id -' || r_630_intf.assignment_id
                              );

            BEGIN
               v_rec := NULL;
               v_rec :=
                     cvt_char ('Carga Horaria Diaria')
                  || ';'
                  || cvt_char (r_630_intf."Legajo")
                  || ';'
                  || cvt_char (r_630_intf.ass_attribute14)
                  || ';'
                  || r_630_intf.effective_start_date
                  || ';'
                  || r_630_intf.effective_end_date;
               v_rec := REPLACE (v_rec, '  ;', ';');                                        --Version 1.1
               UTL_FILE.put_line (v_output_file, v_rec);
               g_success_count := g_success_count + 1;
            END;

            BEGIN
               v_rec := NULL;
               v_rec :=
                     'Carga Hor. Semanal'
                  || ';'
                  || cvt_char (r_630_intf."Legajo")
                  || ';'
                  || r_630_intf.normal_hours
                  || ';'
                  || r_630_intf.effective_start_date
                  || ';'
                  || r_630_intf.effective_end_date;
               v_rec := REPLACE (v_rec, '  ;', ';');                                        --Version 1.1
               UTL_FILE.put_line (v_output_file, v_rec);
               g_success_count := g_success_count + 1;
            END;

            FOR r_payroll_name IN c_payroll_name (r_630_intf.assignment_id, r_630_intf.effective_date)
            -- Version 1.4
            LOOP
               BEGIN
                  v_rec := NULL;
                  v_rec :=
                        'Confidencialidad'
                     || ';'
                     || cvt_char (r_630_intf."Legajo")
                     || ';'
                     || cvt_char (r_payroll_name.payroll_name)
                     || ';'
                     || r_630_intf.effective_start_date
                     || ';'
                     || r_630_intf.effective_end_date;
                  v_rec := REPLACE (v_rec, '  ;', ';');                                     --Version 1.1
                  UTL_FILE.put_line (v_output_file, v_rec);
                  g_success_count := g_success_count + 1;
               END;
            END LOOP;

            FOR r_supervisor IN c_supervisor (r_630_intf.assignment_id, r_630_intf.effective_date)
            -- Version 1.4
            LOOP
               BEGIN
                  v_rec := NULL;
                  v_rec :=
                        'Distribucion Recibo'
                     || ';'
                     || cvt_char (r_630_intf."Legajo")
                     || ';'
                     || cvt_char (r_supervisor."Nro legajo Super")
                     || ';'
                     || r_630_intf.effective_start_date
                     || ';'
                     || r_630_intf.effective_end_date;
                  v_rec := REPLACE (v_rec, '  ;', ';');                                     --Version 1.1
                  UTL_FILE.put_line (v_output_file, v_rec);
                  g_success_count := g_success_count + 1;
               END;
            END LOOP;

            FOR r_altcode IN c_altcode
            LOOP
               BEGIN
                  v_rec := NULL;
                  v_rec :=
                        'Siniestro SIJP'
                     || ';'
                     || cvt_char (r_630_intf."Legajo")
                     || ';'
                     || cvt_char (r_altcode.alternate_code)
                     || ';'
                     || r_630_intf.effective_start_date
                     || ';'
                     || r_630_intf.effective_end_date;
                  v_rec := REPLACE (v_rec, '  ;', ';');                                     --Version 1.1
                  UTL_FILE.put_line (v_output_file, v_rec);
                  g_success_count := g_success_count + 1;
               END;
            END LOOP;

            FOR r_lifeinscode IN c_lifeinscode
            LOOP
               BEGIN
                  v_rec := NULL;
                  v_rec :=
                        'Seguro de Vida'
                     || ';'
                     || cvt_char (r_630_intf."Legajo")
                     || ';'
                     || cvt_char (r_lifeinscode.alternate_code)
                     || ';'
                     || r_630_intf.effective_start_date
                     || ';'
                     || r_630_intf.effective_end_date;
                  v_rec := REPLACE (v_rec, '  ;', ';');                                     --Version 1.1
                  UTL_FILE.put_line (v_output_file, v_rec);
                  g_success_count := g_success_count + 1;
               END;
            END LOOP;

            FOR r_loccode IN c_loccode (r_630_intf.assignment_id, r_630_intf.effective_date)
            -- Version 1.4
            LOOP
               BEGIN
                  v_rec := NULL;
                  v_rec :=
                        'Sucursal'
                     || ';'
                     || cvt_char (r_630_intf."Legajo")
                     || ';'
                     || cvt_char (r_loccode.location_code)
                     || ';'
                     || r_630_intf.effective_start_date
                     || ';'
                     || r_630_intf.effective_end_date;
                  v_rec := REPLACE (v_rec, '  ;', ';');                                     --Version 1.1
                  UTL_FILE.put_line (v_output_file, v_rec);
                  g_success_count := g_success_count + 1;
               END;
            END LOOP;

            FOR r_cltcode IN c_cltcode (r_630_intf.assignment_id, r_630_intf.effective_date)
            -- Version 1.4
            LOOP
               BEGIN
                  v_rec := NULL;
                  v_rec :=
                        'Sector'
                     || ';'
                     || cvt_char (r_630_intf."Legajo")
                     || ';'
                     || cvt_char (r_cltcode."Sector")
                     || ';'
                     || TO_CHAR (r_cltcode.prj_strt_dt, 'DD/MM/YYYY')
                     || ';'
                     || r_cltcode.prj_end_dt;
                  v_rec := REPLACE (v_rec, '  ;', ';');                                     --Version 1.1
                  UTL_FILE.put_line (v_output_file, v_rec);
                  g_success_count := g_success_count + 1;
               END;
            END LOOP;

            FOR r_convenio IN c_convenio (r_630_intf.assignment_id, r_630_intf.effective_date)
            -- Version 1.4
            LOOP
               BEGIN
                  v_rec := NULL;
                  v_rec :=
                        'Convenio'
                     || ';'
                     || cvt_char (r_630_intf."Legajo")
                     || ';'
                     || cvt_char (r_convenio.description)
                     || ';'
                     || r_630_intf.effective_start_date
                     || ';'
                     || r_630_intf.effective_end_date;
                  v_rec := REPLACE (v_rec, '  ;', ';');                                     --Version 1.1
                  UTL_FILE.put_line (v_output_file, v_rec);
                  g_success_count := g_success_count + 1;
               END;
            END LOOP;

            FOR r_categoria IN c_categoria (r_630_intf.assignment_id, r_630_intf.effective_date)
            -- Version 1.4
            LOOP
               BEGIN
                  v_rec := NULL;
                  v_rec :=
                        'Categoria'
                     || ';'
                     || cvt_char (r_630_intf."Legajo")
                     || ';'
                     || cvt_char (r_categoria."Categoria")
                     || ';'
                     || r_630_intf.effective_start_date
                     || ';'
                     || r_630_intf.effective_end_date;
                  v_rec := REPLACE (v_rec, '  ;', ';');                                     --Version 1.1
                  UTL_FILE.put_line (v_output_file, v_rec);
                  g_success_count := g_success_count + 1;
               END;
            END LOOP;

            FOR r_job IN c_job (r_630_intf.assignment_id, r_630_intf.effective_date)       -- Version 1.4
            LOOP
               BEGIN
                  v_rec := NULL;
                  v_rec :=
                        'Puesto'
                     || ';'
                     || cvt_char (r_630_intf."Legajo")
                     || ';'
                     || cvt_char (r_job."puesto")
                     || ';'
                     || r_630_intf.effective_start_date
                     || ';'
                     || r_630_intf.effective_end_date;
                  v_rec := REPLACE (v_rec, '  ;', ';');                                     --Version 1.1
                  UTL_FILE.put_line (v_output_file, v_rec);
                  g_success_count := g_success_count + 1;
               END;

               BEGIN
                  v_rec := NULL;
                  v_rec :=
                        'Gerencia'
                     || ';'
                     || cvt_char (r_630_intf."Legajo")
                     || ';'
                     || cvt_char (r_job."Gerencia")
                     || ';'
                     || r_630_intf.effective_start_date
                     || ';'
                     || r_630_intf.effective_end_date;
                  v_rec := REPLACE (v_rec, '  ;', ';');                                     --Version 1.1
                  UTL_FILE.put_line (v_output_file, v_rec);
                  g_success_count := g_success_count + 1;
               END;
            END LOOP;

            FOR r_dept IN c_dept (r_630_intf.assignment_id, r_630_intf.effective_date)     -- Version 1.4
            LOOP
               BEGIN
                  v_rec := NULL;
                  v_rec :=
                        'Departamento'
                     || ';'
                     || cvt_char (r_630_intf."Legajo")
                     || ';'
                     || cvt_char (r_dept.NAME)
                     || ';'
                     || r_630_intf.effective_start_date
                     || ';'
                     || r_630_intf.effective_end_date;
                  v_rec := REPLACE (v_rec, '  ;', ';');                                     --Version 1.1
                  UTL_FILE.put_line (v_output_file, v_rec);
                  g_success_count := g_success_count + 1;
               END;
            END LOOP;

            FOR r_obra_social IN c_obra_social (r_630_intf.assignment_id, r_630_intf.effective_date)
            -- Version 1.4
            LOOP
               BEGIN
                  v_rec := NULL;
                  v_rec :=
                        'Obra Social Ley'
                     || ';'
                     || cvt_char (r_630_intf."Legajo")
                     || ';'
                     || cvt_char (r_obra_social."Obra Social Ley")
                     || ';'
                     || TO_CHAR (r_obra_social.strt_dt, 'DD/MM/YYYY')
                     || ';'
                     || r_obra_social.end_dt;
                  v_rec := REPLACE (v_rec, '  ;', ';');                                     --Version 1.1
                  UTL_FILE.put_line (v_output_file, v_rec);
                  g_success_count := g_success_count + 1;
               END;

               BEGIN
                  v_rec := NULL;
                  v_rec :=
                        'Obra Social Elegida'
                     || ';'
                     || cvt_char (r_630_intf."Legajo")
                     || ';'
                     || cvt_char (r_obra_social."Obra Social Ley")
                     || ';'
                     || TO_CHAR (r_obra_social.strt_dt, 'DD/MM/YYYY')
                     || ';'
                     || r_obra_social.end_dt;
                  v_rec := REPLACE (v_rec, '  ;', ';');                                     --Version 1.1
                  UTL_FILE.put_line (v_output_file, v_rec);
                  g_success_count := g_success_count + 1;
               END;
            END LOOP;

            fnd_file.put_line (fnd_file.output,
                               'END - 630 - Assignment_id -' || r_630_intf.assignment_id);
         END;
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
         raise_application_error (-20003, 'Exception NO_DATA_FOUND in init_630_intf' || v_msg);
         g_e_program_run_status := 1;
      WHEN OTHERS
      THEN
         g_error_count := g_error_count + 1;
         print_count (g_success_count, g_error_count, g_e_error_hand.module_name);
         UTL_FILE.fclose (v_output_file);
         log_error ('SQLCODE', TO_CHAR (SQLCODE), 'Error Message', SUBSTR (SQLERRM, 1, 64));
         print_line ('Error in module: ' || g_e_error_hand.module_name);
         v_msg := SQLERRM;
         raise_application_error (-20003, 'Exception OTHERS in init_630_intf' || v_msg);
         g_e_program_run_status := 1;
   END;

-- Main proedure to execute all the other interface procedures
   PROCEDURE initial_main (
      errcode               OUT      VARCHAR2,
      errbuff               OUT      VARCHAR2,
      p_business_group_id   IN       NUMBER,
      p_previous_run_date   IN       VARCHAR2,
      p_current_run_date    IN       VARCHAR2
   )
   IS
      l_cut_off_date       DATE;
      l_current_run_date   DATE;
   BEGIN
      init_error_msg ('Main');
      l_cut_off_date := TO_DATE (p_previous_run_date, 'YYYY/MM/DD HH24:MI:SS');
      l_current_run_date := TO_DATE (p_current_run_date, 'YYYY/MM/DD HH24:MI:SS');
      -- the seconds on each interface is been hardcoded because RHPro process load the file in a sequence.
      init_605_intf (TO_CHAR (SYSDATE, 'YYYYMMDD') || '113100' || '_0605.txt',
                     p_business_group_id,
                     l_cut_off_date,
                     l_current_run_date
                    );
      init_630_intf (TO_CHAR (SYSDATE, 'YYYYMMDD') || '113105' || '_0630.txt',
                     p_business_group_id,
                     l_cut_off_date,
                     l_current_run_date
                    );
      init_640_intf (TO_CHAR (SYSDATE, 'YYYYMMDD') || '113110' || '_0640.txt',
                     p_business_group_id,
                     l_cut_off_date,
                     l_current_run_date
                    );
      init_211s_intf (TO_CHAR (SYSDATE, 'YYYYMMDD') || '113115' || '_0211.txt',
                      p_business_group_id,
                      l_cut_off_date,
                      l_current_run_date
                     );
      init_262_intf (TO_CHAR (SYSDATE, 'YYYYMMDD') || '113120' || '_0262.txt',
                     p_business_group_id,
                     l_cut_off_date,
                     l_current_run_date
                    );
      init_317_intf (TO_CHAR (SYSDATE, 'YYYYMMDD') || '113125' || '_0317.txt',
                     p_business_group_id,
                     l_cut_off_date,
                     l_current_run_date
                    );
      init_602_intf (TO_CHAR (SYSDATE, 'YYYYMMDD') || '113130' || '_0602.txt',
                     p_business_group_id,
                     l_cut_off_date,
                     l_current_run_date
                    );
   END;
END ttec_arg_rhpro_ong_data_intf;
/
show errors;
/