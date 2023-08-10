create or replace PACKAGE      ttec_taleo_perfo_update
/************************************************************************************
        Program Name: TTEC_PO_TSG_INTERFACE 

        Description:   

        Developed by : 
        Date         :  

       Modification Log
       Name                  Version #    Date            Description
       -----                 --------     -----           -------------
   MXKEERTHI(ARGANO)  17-JUL-2023           1.0          R12.2 Upgrade Remediation
    ****************************************************************************************/
               

IS
   g_header          VARCHAR2 (2000)
      :=    'identifier'
         || '|'
         || 'user_name'
         || '|'
         || 'first_name'
         || '|'
         || 'middle_name'
         || '|'
         || 'last_name'
         || '|'
         || 'employee_id'
         || '|'
         || 'email'
         || '|'
         || 'address_1'
         || '|'
         || 'address_2'
         || '|'
         || 'address_3'
         || '|'
         || 'city'
         || '|'
         || 'state'
         || '|'
         || 'country'
         || '|'
         || 'postal_code'
         || '|'
         || 'picture'
         || '|'
         || 'organization'
         || '|'
         || 'location'
         || '|'
         || 'job_role'
         || '|'
         || 'employee_status'
         || '|'
         || 'status'
         || '|'
         || 'manager_id'
         || '|'
         || 'manager_level';
   v_last_run_date   DATE;

   CURSOR c_rec2_q
   IS
      SELECT DISTINCT papf.employee_number xidentifier,
                      papf.employee_number user_name, papf.first_name,
                      papf.middle_names, papf.last_name,
                      papf.employee_number employee_id,
                      papf.attribute1 personal_email,
                      papf.email_address ttec_email,
                      TO_CHAR (papf.business_group_id) user_group_1,
                      padd.address_line1, padd.address_line2,
                      padd.address_line3, padd.town_or_city, padd.region_2,
                      padd.country, padd.postal_code, NULL AS picture,
                      TO_CHAR (paaf.organization_id) xorganization,
                      TO_CHAR (paaf.location_id) xlocation, NULL AS job_role,
                      'Current' AS employee_status,
                      ppt.system_person_type AS status,

--              paaf.ass_attribute30 perfornmance_req,
                      papf_sup.employee_number manager_id,
                      papf.attribute30 taleo_id, pj.attribute6 manager_level,
                      papf.original_date_of_hire, ppos.date_start,
                      papf.date_of_birth,
                      TRUNC (papf.last_update_date) person_lastupdate,
                      TRUNC (paaf.last_update_date) assign_lastupdate
                 FROM per_all_people_f papf,
                      per_all_assignments_f paaf,
                      per_addresses padd,
                      per_all_people_f papf_sup,
                      per_jobs pj,
                      per_periods_of_service ppos,
                      per_person_types ppt
                WHERE papf.person_id = paaf.person_id
                  AND papf.person_id = padd.person_id(+)
                  AND paaf.job_id = pj.job_id
                  AND paaf.person_id = ppos.person_id
                  AND paaf.supervisor_id = papf_sup.person_id
                  AND papf.person_type_id = ppt.person_type_id
                  AND paaf.period_of_service_id = ppos.period_of_service_id
                  AND (   ppt.system_person_type LIKE 'EMP%'
                       OR ppt.system_person_type LIKE 'EX_EMP%'
                      )
                  --  AND papf.business_group_id = 325
                  AND paaf.ass_attribute30 = 'Y'
                  AND paaf.primary_flag = 'Y'
                  AND paaf.assignment_type IN ('E', 'C')
                  AND papf.business_group_id = padd.business_group_id
                  AND padd.date_to IS NULL
                  AND padd.primary_flag = 'Y'
                  AND SYSDATE BETWEEN papf.effective_start_date
                                  AND papf.effective_end_date
                  AND SYSDATE BETWEEN paaf.effective_start_date
                                  AND paaf.effective_end_date
                  AND SYSDATE BETWEEN papf_sup.effective_start_date
                                  AND papf_sup.effective_end_date
                  AND (   (papf.last_update_date >= (v_last_run_date)
                          )      -- -1 is there beacuse assignement can change
                       OR (paaf.last_update_date >= (v_last_run_date)
                          )       -- if employee is terminated on previous day
                       OR (padd.last_update_date >= (v_last_run_date)
                          ) -- yet we need to see if attribute 30 been changed
                       OR ppos.actual_termination_date = (v_last_run_date)
                      )
                  AND papf.effective_end_date = TO_DATE ('31-DEC-4712')
                  AND paaf.effective_end_date = TO_DATE ('31-DEC-4712')
             ORDER BY papf.last_name;
           -- subscribed to the pilot               -- subscribed to the pilot

   CURSOR c_req_db
   IS
      SELECT      IDENTIFIER
               || delimit1
               || user_name
               || delimit2
               || first_name
               || delimit3
               || middle_name
               || delimit4
               || last_name
               || delimit5
               || employee_id
               || delimit6
               || email
               || delimit7
               || address_1
               || delimit8
               || address_2
               || delimit9
               || address_3
               || delimit10
               || city
               || delimit11
               || state
               || delimit12
               || country
               || delimit13
               || postal_code
               || delimit14
               || picture
               || delimit15
               || ORGANIZATION
               || delimit16
               || LOCATION
               || delimit17
               || job_role
               || delimit18
               || employee_status
               || delimit19
               || status
               || delimit20
               || manager_id
               || delimit21
               || manager_level l_out
			    --      FROM cust.ttec_taleoperf_empupdate_db  --Commented code by MXKEERTHI-ARGANO,07/17/2023
      FROM apps.ttec_taleoperf_empupdate_db --code added by MXKEERTHI-ARGANO, 07/17/2023
  
    
      ORDER BY last_name;

   CURSOR c_host
   IS
      SELECT SUBSTR (host_name, 1, 10)
        FROM v$instance;

   -- get directory path

   -- set directory destination for output file
   CURSOR c_directory_path (l_conc_req_id NUMBER)
   IS
      SELECT    '/d01/ora'
             || DECODE (NAME, 'PROD', 'cle', LOWER (NAME))
             || '/'
             || LOWER (NAME)
             || 'appl/teletech/11.5.0/data/BenefitInterface/taleo_performance'
                                                               directory_path,
                'TTEC_TALEO_PERFORM_EMPL_UPDATE'
             || '_'
             || TO_CHAR (l_conc_req_id)
             || '.csv' file_name
        FROM v$database;

   CURSOR c_parent_request_id (v_request_id NUMBER)
   IS
      --SELECT parent_request_id --Commented out by C. Chan
      SELECT request_id
        FROM apps.fnd_concurrent_requests
       WHERE request_id = v_request_id;

   CURSOR c_last_run
   IS
      SELECT TRUNC (MAX (actual_start_date))
        FROM fnd_conc_req_summary_v
       WHERE program_short_name = 'TTEC_TALEO_PERFO_UPDATE'
         AND phase_code = 'C'
         AND completion_text = 'Normal completion';

   PROCEDURE print_line (v_data IN VARCHAR2);

   PROCEDURE errvar_null (p_status OUT NUMBER);

   PROCEDURE log_error (
      label1       IN   VARCHAR2,
      reference1   IN   VARCHAR2,
      label2       IN   VARCHAR2,
      reference2   IN   VARCHAR2
   );

   PROCEDURE rec_taleo_c_fill (ggg IN c_rec2_q%ROWTYPE,
                                                       -- record to get match data from query
                                                       l_rec OUT VARCHAR);

   PROCEDURE rec_taleo_c_insert_db;

   PROCEDURE main (
      errcode              VARCHAR2,
      errbuff              VARCHAR2,
      email_to_list   IN   VARCHAR2,
      email_cc_list   IN   VARCHAR2
   );
END ttec_taleo_perfo_update;
/
show errors;
/