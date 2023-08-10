create or replace PACKAGE      ttec_taleo_perfo_create
/************************************************************************************
        Program Name: ttec_taleo_perfo_create

        Description:   

        Developed by : 
        Date         :  

       Modification Log
       Name                  Version #    Date            Description
       -----                 --------     -----           -------------
    MXKEERTHI(ARGANO)            1.0      11-Jul-2023      R12.2 Upgrade Remediation
    ****************************************************************************************/
IS
   v_last_run_date   DATE;

   v_empl_num VARCHAR2(30);

   g_header          varchar2 (2000)
      :=    'identifier'
         || '|'
         || 'candidate_synch'
         || '|'
         || 'user_synch'
         || '|'
         || 'user_name'
         || '|'
         || 'password'
         || '|'
         || 'role_collection'
         || '|'
         || 'user_role_1'
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
         || 'force_new_password'
         || '|'
         || 'group_collection'
         || '|'
         || 'user_group_1'
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
         || 'manager_level'
         || '|'
         || 'manager_level2';

   CURSOR c_rec2_q
   IS
    SELECT DISTINCT papf.employee_number xidentifier,
                      papf.employee_number candidate_synch,
                      papf.employee_number user_synch,
                      papf.employee_number user_name, NULL xpassword,
                      'FALSE' role_collection,
                      NULL user_role_1,
                      papf.first_name, papf.middle_names, papf.last_name,
                      papf.employee_number employee_id,
                      papf.attribute1 personal_email,
                      papf.email_address ttec_email,
                      'TRUE' force_new_password, 'FALSE' group_collection,
                      TO_CHAR (papf.business_group_id) user_group_1,
                      padd.address_line1, padd.address_line2,
                      padd.address_line3, padd.town_or_city, padd.region_2,
                      padd.country, padd.postal_code, NULL  AS picture,
                      TO_CHAR (paaf.organization_id) xorganization,
                      TO_CHAR (paaf.location_id) xlocation, NULL  AS job_role,
                      'Current' AS employee_status, 'Active' AS status,
--              paaf.ass_attribute30 perfornmance_req,
                      pj.attribute6 manager_level, papf.attribute30 taleo_id,
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
                  AND  papf.person_id = padd.person_id (+)
                  AND paaf.job_id = pj.job_id
                  AND paaf.person_id = ppos.person_id
                  AND papf.person_type_id = ppt.person_type_id
                  AND paaf.period_of_service_id = ppos.period_of_service_id
                  AND (   ppt.system_person_type LIKE 'EMP%'
                       -- OR ppt.system_person_type LIKE 'EX_EMP%'
                      )
                --  AND papf.business_group_id = 325
                  AND paaf.ass_attribute30 = 'Y'
                  AND paaf.primary_flag = 'Y'
                  AND paaf.assignment_type IN ('E', 'C')
                   and papf.BUSINESS_GROUP_ID= padd.BUSINESS_GROUP_ID
                  AND padd.date_to IS NULL
                  AND padd.primary_flag = 'Y'
                  AND paaf.supervisor_id = papf_sup.person_id(+)
                  AND sysdate BETWEEN papf.effective_start_date
                                          AND papf.effective_end_date
                  AND sysdate BETWEEN papf.effective_start_date
                                          AND papf.effective_end_date
                  AND sysdate BETWEEN papf_sup.effective_start_date
                                          AND papf_sup.effective_end_date
                  AND
                     (   (papf.last_update_date between  v_last_run_date and sysdate)
                     OR (paaf.last_update_date between v_last_run_date and sysdate)
                     OR (padd.last_update_date between v_last_run_date and sysdate)
                      )
             ORDER BY papf.last_name    ;         -- subscribed to the pilot

   CURSOR c_req_db
   IS
      SELECT      IDENTIFIER
               || delimit1
               || candidate_synch
               || delimit2
               || user_synch
               || delimit2_2
               || user_name
               || delimit3
               || PASSWORD
               || delimit4
               || role_collection
               || delimit5
               || user_role_1
               || delimit6
               || first_name
               || delimit7
               || middle_name
               || delimit8
               || last_name
               || delimit9
               || employee_id
               || delimit10
               || email
               || delimit11
               || force_new_password
               || delimit12
               || group_collection
               || delimit13
               || user_group_1
               || delimit14
               || address_1
               || delimit15
               || address_2
               || delimit16
               || address_3
               || delimit17
               || city
               || delimit18
               || state
               || delimit19
               || country
               || delimit20
               || postal_code
               || delimit21
               || picture
               || delimit22
               || ORGANIZATION
               || delimit23
               || LOCATION
               || delimit24
               || job_role
               || delimit25
               || employee_status
               || delimit26
               || status
               || delimit27
               || manager_level
               || delimit28
               || manager_level2  l_out
			   		--FROM cust.ttec_taleoperf_empcreate_db  -- Commented code by MXKEERTHI-ARGANO, 07/11/2023
         FROM apps.ttec_taleoperf_empcreate_db--  code Added by MXKEERTHI-ARGANO, 07/11/2023
 
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
                'TTEC_TALEO_PERFORM_EMPL_CREATE'
             || '_'
             || TO_CHAR (l_conc_req_id)
             || '.csv' file_name
        FROM v$database;

   CURSOR c_last_run
   IS
      SELECT MAX (actual_start_date)
        FROM fnd_conc_req_summary_v
       WHERE program_short_name = 'TTEC_TALEO_PERFO_CREATE'
         AND phase_code = 'C'
         AND completion_text = 'Normal completion';

   CURSOR c_empl_been_sent (v_empl_num VARCHAR2)
   IS
      SELECT empl_num
	  		--     FROM  cust.ttec_taleoPerf_EmpSentToTaleo -- Commented code by MXKEERTHI-ARGANO, 07/11/2023
     FROM  apps.ttec_taleoPerf_EmpSentToTaleo--  code Added by MXKEERTHI-ARGANO, 07/11/2023
   
        where empl_num = v_empl_num
        and Active = 'Y' ;

 CURSOR c_parent_request_id (v_request_id NUMBER)
   IS
      SELECT parent_request_id
        FROM  apps.fnd_concurrent_requests
        where request_id = v_request_id;

  CURSOR taleo_check_usernum_master (v_empl_num VARCHAR2)
   IS
      select distinct user_num
	  		--  from cust.TTEC_TALEO_USERNUM_LOAD_MASTER  -- Commented code by MXKEERTHI-ARGANO, 07/11/2023
              from apps.TTEC_TALEO_USERNUM_LOAD_MASTER--  code Added by MXKEERTHI-ARGANO, 07/11/2023
 
             where user_num = v_empl_num;


   PROCEDURE print_line (v_data IN VARCHAR2);

   PROCEDURE errvar_null (p_status OUT NUMBER);

   PROCEDURE rec_taleo_c_write_to (l_rec IN OUT VARCHAR2);

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
END ttec_taleo_perfo_create;
/
show errors;
/