create or replace PACKAGE BODY      ttec_hr_convercent_intf
IS
/*---------------------------------------------------------------------------------------
  Objective    : Interface to extract data for all G employees to send to Convercent Vendor
 Package spec :TTEC_HR_CONVERCENT_INTF
 Parameters:

   MODIFICATION HISTORY
   Person               Version  Date        Comments
   ------------------------------------------------
   Kaushik Babu         1.0      7/4/2014  New package for sending on going employee data to Convercent Vendor
   Kaushik Babu         1.1      10/17/2014  Code change with respect to format and removing duplicate records TASK0087904
   Kaushik Babu         1.2      10/20/2014  Fixed code to generate bad file with no email address and also same email address with multiple records
   Kaushik Babu         1.3      12/2/2014   Fixed code to ignore agents by adding more logic into the query.
   Kaushik Babu         1.4      12/18/2014  Fixed spacing issue on the header and also added logic to check if @ is available on the email address
                                                if not send to bad file. - INC0893154
   Amir Aslam          2.0       08/04/2015  changes for Re hosting Project
IXPRAVEEN(ARGANO)		1.0		04/05/2023 R12.2 Upgrade Remediation
*== END ==================================================================================================*/
   FUNCTION cvt_char (p_text VARCHAR2)
      RETURN VARCHAR2
   AS
      v_text   VARCHAR2 (150);
   BEGIN
      SELECT REPLACE (TRANSLATE (CONVERT (p_text, 'WE8ISO8859P1', 'UTF8'),
                                 '&:;'''',"��%^�?#',
                                 '&'
                                ),
                      '&',
                      ''
                     )
        INTO v_text
        FROM DUAL;

      RETURN (v_text);
   EXCEPTION
      WHEN OTHERS
      THEN
         v_text := p_text;
         RETURN (v_text);
   END;

   PROCEDURE main_proc (
      errbuf               OUT      VARCHAR2,
      retcode              OUT      NUMBER,
      p_output_directory   IN       VARCHAR2
   )
   IS
      CURSOR c_ttec_org
      IS
         SELECT DISTINCT    b.segment3
                         || ' '
                         || c.business_group_id
                         || ' '
                         || a.organization_id department_id,
                         'TRUE' isactive,
                         a.NAME || ' ' || c.NAME department_name,
                         '' description, '' notes
                    FROM apps.hr_organization_units a,
                         apps.pay_cost_allocation_keyflex b,
                         per_business_groups c
                   WHERE a.cost_allocation_keyflex_id IS NOT NULL
                     AND a.business_group_id = c.business_group_id
                     AND a.cost_allocation_keyflex_id =
                                                  b.cost_allocation_keyflex_id
                     AND TRUNC (SYSDATE) BETWEEN a.date_from
                                             AND NVL (a.date_to,
                                                      TRUNC (SYSDATE)
                                                     )
                     AND c.business_group_id <> 0
                     AND b.segment3 IS NOT NULL
                ORDER BY 1;

      CURSOR c_emp_info
      IS
         SELECT DISTINCT papf.first_name, papf.last_name, papf.email_address,
                         hla.attribute2 || ' ' || hla.location_id location_id,
                            pcak_org.segment3
                         || ' '
                         || pbg.business_group_id
                         || ' '
                         || haou.organization_id department_id,
                         papf.employee_number, '' telephone, 'TRUE' isactive,
                         job.attribute20 salary_grade,
                         papf.email_address username,
                         DECODE (papf.email_address, '', 'N', 'Y') hasemail,
                         sup.employee_number supervisoremployeeid,
                         DECODE (ftt.territory_code,
                                 'BR', 'PORTUGUESE',
                                 'BG', 'BULGARIAN',
                                 'MX', 'SPANISH',
                                 'ENGLISH'
                                ) lang,
                         sup.first_name sup_first_name,
                         sup.last_name sup_last_name, job.NAME job_name,
                         job.attribute5 ga_agent,
                         job.attribute6 manager_level,
                         hla.location_code location_name,
                         haou.NAME department_name,
                         ftt.territory_short_name country, ftt.territory_code,
                         pbg.NAME
				--START R12.2 Upgrade Remediation		 
                /*    FROM hr.per_all_people_f papf,
                         hr.per_all_assignments_f paaf,					 -- Commented code by IXPRAVEEN-ARGANO,05-May-2023
                         hr.per_all_people_f sup,
                         hr.hr_locations_all hla,
                         hr.pay_cost_allocation_keyflex pcak_org,
                         hr.hr_all_organization_units haou,
                         hr.per_jobs job,
                         cust.ttec_emp_proj_asg tepa,
                         per_business_groups pbg,
                         applsys.fnd_territories_tl ftt,
                         apps.gl_ledgers glg*/
					FROM apps.per_all_people_f papf,					--  code Added by IXPRAVEEN-ARGANO,05-May-2023
                         apps.per_all_assignments_f paaf,
                         apps.per_all_people_f sup,
                         apps.hr_locations_all hla,
                         apps.pay_cost_allocation_keyflex pcak_org,
                         apps.hr_all_organization_units haou,
                         apps.per_jobs job,
                         apps.ttec_emp_proj_asg tepa,
                         per_business_groups pbg,
                         apps.fnd_territories_tl ftt,
                         apps.gl_ledgers glg	 
						--END R12.2.10 Upgrade remediation 
                   WHERE papf.business_group_id <> 0
                     AND papf.person_id = paaf.person_id
                     AND papf.current_employee_flag = 'Y'
                     AND paaf.assignment_type = 'E'
                     AND paaf.primary_flag = 'Y'
                     --AND papf.employee_number = '3084045'
                     AND UPPER (job.attribute20) <> 'AG'
                     AND UPPER (job.attribute10) NOT LIKE '%TEMP%'
                     AND ftt.territory_code(+) = hla.country
                     AND ftt.LANGUAGE(+) = USERENV ('LANG')
                     AND paaf.location_id = hla.location_id(+)
                     AND paaf.job_id = job.job_id(+)
                     AND papf.business_group_id = pbg.business_group_id
                     AND paaf.organization_id = haou.organization_id(+)
                     AND paaf.supervisor_id = sup.person_id(+)
                     AND haou.cost_allocation_keyflex_id = pcak_org.cost_allocation_keyflex_id(+)
                     AND papf.person_id = tepa.person_id(+)
                     AND paaf.set_of_books_id = glg.ledger_id(+)
                     AND papf.business_group_id <> 0
                     AND NVL (glg.NAME, 'TTEC') NOT LIKE ('%PERCEPTA%')
                     AND NVL (UPPER (job.attribute5), 'AGENT') NOT IN
                                                            ('AGENT', 'EXEC')
--                     AND papf.email_address IS NOT NULL
                     AND ftt.territory_code NOT IN ('ES', 'GH', 'AR')
                     AND TRUNC (SYSDATE) BETWEEN paaf.effective_start_date
                                             AND paaf.effective_end_date
                     AND TRUNC (SYSDATE) BETWEEN tepa.prj_strt_dt(+) AND tepa.prj_end_dt(+)
                     AND TRUNC (SYSDATE) BETWEEN papf.effective_start_date
                                             AND papf.effective_end_date
                     AND TRUNC (SYSDATE) BETWEEN sup.effective_start_date(+) AND sup.effective_end_date(+)
                ORDER BY 6;

      CURSOR c_ttec_loc
      IS
         SELECT   a.location_code location_name,
                  attribute2 || ' ' || location_id location_id
             FROM apps.hr_locations_all a
            WHERE a.inactive_date IS NULL AND attribute2 IS NOT NULL
         ORDER BY 2;

      CURSOR c_ttec_group
      IS
         SELECT DISTINCT group_name
                    FROM (SELECT    DECODE (ftt.territory_code,
                                            'BR', 'PORTUGUESE',
                                            'BG', 'BULGARIAN',
                                            'MX', 'SPANISH',
                                            'ENGLISH'
                                           )
                                 || ' '
                                 || DECODE (pjb.attribute20,
                                            'P2', 'SHORT',
                                            'P1', 'SHORT',
                                            'M2', 'SHORT',
                                            'M1', 'SHORT',
                                            'S4', 'SHORT',
                                            'S3', 'SHORT',
                                            'S2', 'SHORT',
                                            'S1', 'SHORT',
                                            'LONG'
                                           ) group_name
                         --   FROM applsys.fnd_territories_tl ftt, per_jobs pjb) DUAL			-- Commented code by IXPRAVEEN-ARGANO,05-May-2023
							FROM apps.fnd_territories_tl ftt, per_jobs pjb) DUAL				--  code Added by IXPRAVEEN-ARGANO,05-May-2023
                ORDER BY 1;

      v_text         VARCHAR (32765)    DEFAULT NULL;
      v_file_name    VARCHAR2 (200)     DEFAULT NULL;
      v_file_type    UTL_FILE.file_type;
      v_file_name1   VARCHAR2 (200)     DEFAULT NULL;
      v_file_type1   UTL_FILE.file_type;
      v_file_name2   VARCHAR2 (200)     DEFAULT NULL;
      v_file_type2   UTL_FILE.file_type;
      v_file_name3   VARCHAR2 (200)     DEFAULT NULL;
      v_file_type3   UTL_FILE.file_type;
      v_course       VARCHAR2 (10)      DEFAULT NULL;
      v_count        NUMBER             DEFAULT 0;
   BEGIN
      BEGIN
        -- -- Changes for Version 2.0
         SELECT    'Tele_'
                || DECODE (host_name, ttec_library.XX_TTEC_PROD_HOST_NAME, 'PROD', 'TEST')
                || '_Department_'
                || TO_CHAR (SYSDATE, 'YYYYMMDD')
                || '.csv',
                   'Tele_'
                || DECODE (host_name, ttec_library.XX_TTEC_PROD_HOST_NAME, 'PROD', 'TEST')
                || '_Account_Person_'
                || TO_CHAR (SYSDATE, 'YYYYMMDD')
                || '.csv',
                   'Tele_'
                || DECODE (host_name, ttec_library.XX_TTEC_PROD_HOST_NAME, 'PROD', 'TEST')
                || '_Location_'
                || TO_CHAR (SYSDATE, 'YYYYMMDD')
                || '.csv',
                   'Tele_'
                || DECODE (host_name, ttec_library.XX_TTEC_PROD_HOST_NAME, 'PROD', 'TEST')
                || '_Group_'
                || TO_CHAR (SYSDATE, 'YYYYMMDD')
                || '.csv'
           INTO v_file_name,
                v_file_name1,
                v_file_name2,
                v_file_name3
           FROM v$instance;
           -- -- Commented for Version 2.0
/*         SELECT    'Tele_'
                || DECODE (host_name, 'den-erp046', 'PROD', 'TEST')
                || '_Department_'
                || TO_CHAR (SYSDATE, 'YYYYMMDD')
                || '.csv',
                   'Tele_'
                || DECODE (host_name, 'den-erp046', 'PROD', 'TEST')
                || '_Account_Person_'
                || TO_CHAR (SYSDATE, 'YYYYMMDD')
                || '.csv',
                   'Tele_'
                || DECODE (host_name, 'den-erp046', 'PROD', 'TEST')
                || '_Location_'
                || TO_CHAR (SYSDATE, 'YYYYMMDD')
                || '.csv',
                   'Tele_'
                || DECODE (host_name, 'den-erp046', 'PROD', 'TEST')
                || '_Group_'
                || TO_CHAR (SYSDATE, 'YYYYMMDD')
                || '.csv'
           INTO v_file_name,
                v_file_name1,
                v_file_name2,
                v_file_name3
           FROM v$instance;
*/
      EXCEPTION
         WHEN OTHERS
         THEN
            v_file_name := NULL;
            v_file_name1 := NULL;
            v_file_name2 := NULL;
      END;

      v_file_type :=
                  UTL_FILE.fopen (p_output_directory, v_file_name, 'w', 32765);
      v_file_type1 :=
                 UTL_FILE.fopen (p_output_directory, v_file_name1, 'w', 32765);
      v_file_type2 :=
                 UTL_FILE.fopen (p_output_directory, v_file_name2, 'w', 32765);
      v_file_type3 :=
                 UTL_FILE.fopen (p_output_directory, v_file_name3, 'w', 32765);

      BEGIN
         v_text := NULL;
         v_text :=
               'DepartmentId'
            || ','
            || 'IsActive'
            || ','
            || 'DepartmentName'
            || ','
            || 'Description'
            || ','
            || 'Notes';
         UTL_FILE.put_line (v_file_type, v_text);
      END;

      FOR r_ttec_org IN c_ttec_org
      LOOP
         BEGIN
            v_text := NULL;
            v_text :=
                  r_ttec_org.department_id
               || ','
               || r_ttec_org.isactive
               || ','
               || ttec_library.remove_non_ascii
                                         (cvt_char (r_ttec_org.department_name)
                                         )
               || ','
               || r_ttec_org.description
               || ','
               || ' ';
            UTL_FILE.put_line (v_file_type, v_text);
         END;
      END LOOP;

      BEGIN
         v_text := NULL;
         v_text :=
               'FirstName'
            || ','
            || 'LastName'
            || ','
            || 'Email'
            || ','
            || 'LocationId'
            || ','
            || 'DepartmentId'
            || ','
            || 'EmployeeId'
            || ','
            || 'Telephone'
            || ','
            || 'IsActive'
            || ','
            || 'GroupName'
            || ','
            || 'UserName';
         UTL_FILE.put_line (v_file_type1, v_text);
         fnd_file.put_line (fnd_file.output, v_text);
      END;

      FOR r_emp_rec IN c_emp_info
      LOOP
         BEGIN
            v_text := NULL;
            v_course := NULL;

            IF r_emp_rec.salary_grade IN
                            ('P2', 'P1', 'M2', 'M1', 'S4', 'S3', 'S2', 'S1')
            THEN
               v_course := 'SHORT';
            ELSE
               v_course := 'LONG';
            END IF;

            IF r_emp_rec.email_address IS NOT NULL
            THEN
               BEGIN
                  v_count := 0;

                  SELECT COUNT (*)
                    INTO v_count
                    FROM per_all_people_f a,
                         per_all_assignments_f b,
                         per_jobs c
                   WHERE a.email_address = r_emp_rec.email_address
                     AND a.person_id = b.person_id
                     AND b.assignment_type = 'E'
                     AND b.primary_flag = 'Y'
                     AND b.job_id = c.job_id
                     AND NVL (UPPER (c.attribute5), 'AGENT') NOT IN
                                                            ('AGENT', 'EXEC')
                     AND TRUNC (SYSDATE) BETWEEN a.effective_start_date
                                             AND a.effective_end_date
                     AND TRUNC (SYSDATE) BETWEEN b.effective_start_date
                                             AND b.effective_end_date
                     AND current_employee_flag = 'Y'
                     AND a.business_group_id <> 0;
               EXCEPTION
                  WHEN OTHERS
                  THEN
                     v_count := 2;
               END;
            END IF;

            IF    r_emp_rec.email_address IS NULL
               OR v_count > 1
               OR INSTR (r_emp_rec.email_address, '@') = 0
            THEN
               v_text :=
                     ttec_library.remove_non_ascii
                                              (cvt_char (r_emp_rec.first_name)
                                              )
                  || ','
                  || ttec_library.remove_non_ascii
                                                (cvt_char (r_emp_rec.last_name)
                                                )
                  || ','
                  || r_emp_rec.email_address
                  || ','
                  || r_emp_rec.location_id
                  || ','
                  || r_emp_rec.department_id
                  || ','
                  || r_emp_rec.employee_number
                  || ','
                  || r_emp_rec.telephone
                  || ','
                  || r_emp_rec.isactive
                  || ','
                  || (r_emp_rec.lang || ' ' || v_course)
                  || ','
                  || r_emp_rec.email_address;
               fnd_file.put_line (fnd_file.output, v_text);
            ELSIF v_count = 1
            THEN
               v_text :=
                     ttec_library.remove_non_ascii
                                              (cvt_char (r_emp_rec.first_name)
                                              )
                  || ','
                  || ttec_library.remove_non_ascii
                                                (cvt_char (r_emp_rec.last_name)
                                                )
                  || ','
                  || r_emp_rec.email_address
                  || ','
                  || r_emp_rec.location_id
                  || ','
                  || r_emp_rec.department_id
                  || ','
                  || r_emp_rec.employee_number
                  || ','
                  || r_emp_rec.telephone
                  || ','
                  || r_emp_rec.isactive
                  || ','
                  || (r_emp_rec.lang || ' ' || v_course)
                  || ','
                  || r_emp_rec.email_address;
               UTL_FILE.put_line (v_file_type1, v_text);
            END IF;
         END;
      END LOOP;

      BEGIN
         v_text := NULL;
         v_text :=
               'Location ID'
            || ','
            || 'LocationName'
            || ','
            || 'Description'
            || ','
            || 'IsActive';
         UTL_FILE.put_line (v_file_type2, v_text);
      END;

      FOR r_ttec_loc IN c_ttec_loc
      LOOP
         BEGIN
            v_text := NULL;
            v_text :=
                  r_ttec_loc.location_id
               || ','
               || ttec_library.remove_non_ascii
                                           (cvt_char (r_ttec_loc.location_name)
                                           )
               || ','
               || ttec_library.remove_non_ascii
                                           (cvt_char (r_ttec_loc.location_name)
                                           )
               || ','
               || 'TRUE';
            UTL_FILE.put_line (v_file_type2, v_text);
         END;
      END LOOP;

      BEGIN
         v_text := NULL;
         v_text := 'Name' || ',' || 'Description';
         UTL_FILE.put_line (v_file_type3, v_text);
      END;

      FOR r_ttec_group IN c_ttec_group
      LOOP
         BEGIN
            v_text := NULL;
            v_text :=
                    r_ttec_group.group_name || ',' || r_ttec_group.group_name;
            UTL_FILE.put_line (v_file_type3, v_text);
         END;
      END LOOP;

      UTL_FILE.fclose (v_file_type);
      UTL_FILE.fclose (v_file_type1);
      UTL_FILE.fclose (v_file_type2);
      UTL_FILE.fclose (v_file_type3);
   EXCEPTION
      WHEN OTHERS
      THEN
         UTL_FILE.fclose (v_file_type);
         UTL_FILE.fclose (v_file_type1);
         UTL_FILE.fclose (v_file_type2);
         UTL_FILE.fclose (v_file_type3);
         fnd_file.put_line (fnd_file.LOG,
                            'Error out of main loop main_proc -' || SQLERRM
                           );
   END main_proc;
END ttec_hr_convercent_intf;
/
show errors;
/