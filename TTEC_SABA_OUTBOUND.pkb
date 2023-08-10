create or replace PACKAGE BODY      ttec_saba_outbound AS
  /* $Header: TTEC_SABA_OUTBOUND.pkb 1.0 2011/05/23 mdodge ship $ */

  /*== START ================================================================================================*\
     Author: Elango Pandu
       Date: 05/23/2011
  Call From: TeleTech Saba % Outbound concurrent Programs (4 in all)
       Desc: For Saba outbound interface

    Modification History:

   Version    Date     Author   Description (Include Ticket#)
   -------  --------  --------  ------------------------------------------------------------------------------
      1.0   05/23/11  EPandu    R633104 - Initial Version
      1.1   09/27/11  MDodge    R633104 - Correct Terminations cursor to only get most recent period_of_service
                                record.  Additionally include check for Inactive Date when selecting incrementals
                                for Jobs, Locations and Organizations.
      1.2   10/03/11  MDodge    R633104 - (1) Readded insert of termination_date accidentally left commented out
                                (2) Excluded check on Job Dates for Termed / Inactivated Emps
                                (3) Limited Person Type to Emps and Ex-Emps for Termed / Inactivated Emps
                                (4) ttec_is_mgr determined by non-Agent direct reports
                                (5) Correct location status to show Inactive on Inactive Date
                                (6) Add location limitation of attribute2 is not null for incrementals
                                (7) Use the SYSDATE to determine Mgr flag for Active employees, NOT the
                                    effective_start_date of their assignment.
      1.3   04/24/14  CCHAN    REQ0040698 - Updates below need to be done to the Oracle-Saba interface in regards to:
                                                - Column headers of the 4 files (job, person, location and organization)
                                                - Locale information from Person File
                                                - Password value encrypted from Person File -> cancelled marko requested for NULL value
      1.4   05/29/14  CChan    REQ0048267 -  Need to include Webmetro
      1.5   06/04/14  CChan    REQ0049724 -  Need to replace es_MX with es_ES
      1.7   06/26/14  CChan    REQ0052272 -  Need to include Poland employees
	  1.8   08/04/14  Lalitha  HCR - New codes added for VB
      1.9   11/22/14  CChan    INC0787909 -  Adding Exception handling to trap the employee who raise an error with data issue
	  1.0   17/MAY/23 RXNETHI-ARGANO   R12.2 Upgrade Remediation
  \*== END ==================================================================================================*/

  -- Error Constants
  /*
  START R12.2 Upgrade Remediaiton
  code commented by RXNETHI-ARGANO,17/05/23
  g_application_code  cust.ttec_error_handling.application_code%TYPE := 'HR';
  g_interface         cust.ttec_error_handling.INTERFACE%TYPE;  -- Set for each IFace
  g_package           cust.ttec_error_handling.program_name%TYPE     := 'TTEC_SABA_OUTBOUND';
  g_warning_status    cust.ttec_error_handling.status%TYPE           := 'WARNING';
  g_error_status      cust.ttec_error_handling.status%TYPE           := 'ERROR';
  g_failure_status    cust.ttec_error_handling.status%TYPE           := 'FAILURE';

  g_label1            cust.ttec_error_handling.label1%TYPE           := 'Err Location';
  g_label2            cust.ttec_error_handling.label1%TYPE           := 'Emp ID';
  g_label3            cust.ttec_error_handling.label1%TYPE           := 'Emp #';
  g_employee_number   hr.per_all_people_f.EMPLOYEE_NUMBER%TYPE;

  g_saba_emp_data     cust.ttec_kr_emp_master%ROWTYPE;
  */
  --code added by RXNETHI-ARGANO,17/05/23
  g_application_code  apps.ttec_error_handling.application_code%TYPE := 'HR';
  g_interface         apps.ttec_error_handling.INTERFACE%TYPE;  -- Set for each IFace
  g_package           apps.ttec_error_handling.program_name%TYPE     := 'TTEC_SABA_OUTBOUND';
  g_warning_status    apps.ttec_error_handling.status%TYPE           := 'WARNING';
  g_error_status      apps.ttec_error_handling.status%TYPE           := 'ERROR';
  g_failure_status    apps.ttec_error_handling.status%TYPE           := 'FAILURE';

  g_label1            apps.ttec_error_handling.label1%TYPE           := 'Err Location';
  g_label2            apps.ttec_error_handling.label1%TYPE           := 'Emp ID';
  g_label3            apps.ttec_error_handling.label1%TYPE           := 'Emp #';
  g_employee_number   apps.per_all_people_f.EMPLOYEE_NUMBER%TYPE;

  g_saba_emp_data     apps.ttec_kr_emp_master%ROWTYPE;
  --END R12.2 Upgrade Remediation
  g_directory  VARCHAR2( 100 ) := ttec_library.get_directory('CUST_TOP')||'/data/saba';

  -- declare who columns
  g_request_id          NUMBER                  := fnd_global.conc_request_id;
  g_created_by          NUMBER                  := fnd_global.user_id;

    CURSOR c_person IS
      SELECT papf.person_id id
           , papf.person_id person_no
           , CASE
               WHEN UPPER( pasttl.user_status ) LIKE ( '%LEAVE%' ) THEN 'Leave'
               WHEN UPPER( pasttl.user_status ) LIKE ( '%SUSPEND%' ) THEN 'Inactive'
               ELSE 'Active'
             END status
           , paaf.supervisor_id manager_id
           , DECODE( ppt.user_person_type, 'Expatriate', 'Expatriate', 'Employee' ) person_type
           , TO_CHAR( rcnt_dt.date_start, 'YYYY-MM-DD' ) started_on
--           , '4712-12-31' terminated_on
           , NULL terminated_on
           , hl.location_code location_id
           --, pj.name || '.' || DECODE(pj.business_group_id, 5054, hl.country, org_loc.country) jobtype_id /* 1.3 */
           , pj.name jobtype_id /* 1.3 */
           , CASE papf.sex
               WHEN 'F' THEN 1
               WHEN 'M' THEN 0
               ELSE 2
             END gender
           , CASE papf.business_group_id
               WHEN 1804 THEN --'local000000000000006' /* 1.3 */
                              'es_ES' /* 1.3 */ /* 1.5 */
               WHEN 1631 THEN --'local000000000000014' /* 1.3 */
                              'pt_BR' /* 1.3 */
               WHEN 1632 THEN --'local000000000000006' /* 1.3 */
                              'es_ES' /* 1.3 */ /* 1.5 */
               WHEN 1633 THEN --'local000000000000006' /* 1.3 */
                              'es_ES' /* 1.3 */ /* 1.5 */
               ELSE --'local000000000000001' /* 1.3 */
                    'en_US' /* 1.3 */
             END locale_id
           , paaf.organization_id company_id
           , SUBSTRB(ttec_library.remove_non_ascii (TRIM(TRANSLATE(papf.first_name,',???~!@#$%^&*()+{}|:"<>?=[]\/"',' ' ))),1,25) fname /* 1.3 */
           , SUBSTRB(ttec_library.remove_non_ascii (TRIM(TRANSLATE(papf.last_name,',???~!@#$%^&*()+{}|:"<>?=[]\/"',' ' ))),1,25) lname /* 1.3 */
           , SUBSTRB(ttec_library.remove_non_ascii (TRIM(TRANSLATE(papf.middle_names,',???~!@#$%^&*()+{}|:"<>?=[]\/"',' ' ))),1,25) mname /* 1.3 */
           , ttec_library.remove_non_ascii(papf.email_address) email /* 1.3 */
          -- , 'welcome' password /* 1.3 */
          -- , '280D44AB1E9F79B5CCE2DD4F58F5FE91F0FBACDAC9F7447DFFC318CEB79F2D02' password     /* 1.3 */
           , '' password /* 1.3 */
           , ttec_promotion_dt( paaf.assignment_id, paaf.effective_start_date ) custom0
           , ( SELECT full_name
                 FROM per_all_people_f
                WHERE person_id = ttech_rt_utils_pk.f_get_executive( papf.person_id )
                  AND TRUNC( SYSDATE ) BETWEEN effective_start_date AND effective_end_date ) custom4
           , CASE
               WHEN paaf.employment_category like 'TTAU%'
                AND UPPER( SUBSTR( paaf.employment_category, 6, 1 ) ) = 'F' THEN
                  'Full-time'
               WHEN paaf.employment_category like 'TTAU%'
                AND UPPER( SUBSTR( paaf.employment_category, 6, 1 ) ) = 'P' THEN
                  'Part-time'
               WHEN papf.business_group_id = 1633
                AND UPPER( SUBSTR( paaf.ass_attribute15, 1, 1 ) ) = 'F' THEN
                 'Full-time'
               WHEN papf.business_group_id = 1633
                AND UPPER( SUBSTR( paaf.ass_attribute15, 1, 1 ) ) = 'P' THEN
                 'Part-time'
               WHEN papf.business_group_id <> 1633
                AND UPPER( SUBSTR( paaf.employment_category, 1, 1 ) ) = 'F' THEN
                 'Full-time'
               WHEN papf.business_group_id <> 1633
                AND UPPER( SUBSTR( paaf.employment_category, 1, 1 ) ) IN ('P','V') THEN --v1.8
                 'Part-time'
             END custom5
           , CASE INSTR(papf.employee_number,'-')
               WHEN 0 THEN papf.employee_number
               ELSE SUBSTR( papf.employee_number, INSTR(papf.employee_number,'-')-1)
             END username
           , SUBSTRB(pj.name,1,255) job_title
           , CASE
               WHEN ttec_is_mgr( papf.person_id, TRUNC(SYSDATE) ) = 'Y' THEN 'TRUE'  -- 1.2 (7) Current Mgr flag
               ELSE 'FALSE'
             END ismanager
           , TRUNC(SYSDATE) asg_date
        FROM apps.per_all_people_f papf
           , apps.per_all_assignments_f paaf
           , apps.per_person_type_usages_f ptu
           , apps.per_person_types ppt
           , apps.hr_locations_all hl
           , apps.per_jobs pj
           , apps.hr_all_organization_units hou
           , apps.hr_locations_all org_loc
           , (SELECT person_id
                   , NVL( adjusted_svc_date, date_start ) date_start
                   , actual_termination_date
                --FROM hr.per_periods_of_service pps  --code commented by RXNETHI-ARGANO,17/05/23
                FROM apps.per_periods_of_service pps  --code added by RXNETHI-ARGANO,17/05/23
               WHERE date_start = (SELECT MAX( pps2.date_start )
                                     FROM apps.per_periods_of_service pps2
                                    WHERE pps2.person_id = pps.person_id
                                      AND pps2.date_start <= TRUNC( SYSDATE ))) rcnt_dt
           , apps.per_assignment_status_types_tl pasttl
       WHERE papf.business_group_id <> 0
         AND TRUNC( SYSDATE ) BETWEEN papf.effective_start_date AND papf.effective_end_date
         AND papf.person_id = paaf.person_id
         AND TRUNC( SYSDATE ) BETWEEN paaf.effective_start_date AND paaf.effective_end_date
         AND paaf.primary_flag = 'Y'
          /* 1.4 Begin */
         AND ( (  paaf.payroll_id is NULL
              AND (    hl.location_code like '%WebMetro%'
                    OR hl.location_code like 'PL-%' /* 1.7 */
                   )
              )
                OR     /* 1.4 End */
               ( paaf.payroll_id NOT IN
               (SELECT ppf.payroll_id
                  FROM pay_payrolls_f ppf
                 WHERE UPPER( ppf.payroll_name ) IN ('PERCEPTA (V76)', 'DIRECT ALLIANCE CORPORATION')
                   AND TRUNC( SYSDATE ) BETWEEN ppf.effective_start_date AND ppf.effective_end_date)))
         AND (    paaf.employment_category LIKE 'TTAU%'
               OR DECODE( papf.business_group_id
                        , 1633, UPPER( SUBSTR( paaf.ass_attribute15, 2, 1 ) )
						, UPPER( SUBSTR( paaf.employment_category, 2, 1 ) ) ) IN('B', 'R') ) --V1.8
         AND ptu.person_id = papf.person_id
         AND TRUNC( SYSDATE ) BETWEEN ptu.effective_start_date AND ptu.effective_end_date
         AND ppt.person_type_id = ptu.person_type_id
         AND ppt.system_person_type LIKE 'EMP%'
         AND paaf.location_id = hl.location_id
         AND hl.location_code NOT LIKE 'USA-Clearw%'
         AND paaf.job_id = pj.job_id
         AND TRUNC( SYSDATE ) BETWEEN pj.date_from AND NVL( pj.date_to, SYSDATE )
         AND 'Y' IN
               (CASE
                  WHEN papf.business_group_id = 1633
                   AND pj.attribute5 = 'G' || '&' || 'A'
                   AND pj.name LIKE 'SAB%' THEN
                    'N'
                  WHEN pj.attribute5 != 'Agent' THEN
                    'Y'
                  ELSE
                    'N'
                END)
         AND hou.organization_id = pj.business_group_id
         AND org_loc.location_id = hou.location_id
         AND papf.person_id = rcnt_dt.person_id
         AND paaf.assignment_status_type_id = pasttl.assignment_status_type_id
         AND pasttl.language = 'US';

    CURSOR c_term_person IS
      SELECT papf.person_id id
           , papf.person_id person_no
           , DECODE( emps.term_date, NULL, 'Inactive', 'Terminated') status
           , paaf.supervisor_id manager_id
           , DECODE( ppt.user_person_type, 'Expatriate', 'Expatriate', 'Employee' ) person_type
           , TO_CHAR( emps.date_start, 'YYYY-MM-DD' ) started_on
           , TO_CHAR( NVL(emps.term_date, paaf.effective_start_date), 'YYYY-MM-DD' ) terminated_on
           , hl.location_code location_id
         --  , pj.name || '.' || DECODE(pj.business_group_id, 5054, hl.country, org_loc.country) jobtype_id /* 1.3 */
           , pj.name   jobtype_id /* 1.3 */
           , CASE papf.sex
               WHEN 'F' THEN 1
               WHEN 'M' THEN 0
               ELSE 2
             END gender
           , CASE papf.business_group_id
               WHEN 1804 THEN --'local000000000000006' /* 1.3 */
                              'es_ES' /* 1.3 */ /* 1.5 */
               WHEN 1631 THEN --'local000000000000014' /* 1.3 */
                              'pt_BR' /* 1.3 */
               WHEN 1632 THEN --'local000000000000006' /* 1.3 */
                              'es_ES' /* 1.3 */ /* 1.5 */
               WHEN 1633 THEN --'local000000000000006' /* 1.3 */
                              'es_ES' /* 1.3 */ /* 1.5 */
               ELSE --'local000000000000001' /* 1.3 */
                    'en_US' /* 1.3 */
             END locale_id
           , paaf.organization_id company_id
           , SUBSTRB(ttec_library.remove_non_ascii (TRIM(TRANSLATE(papf.first_name,',???~!@#$%^&*()+{}|:"<>?=[]\/"',' ' ))),1,25) fname    /* 1.3 */
           , SUBSTRB(ttec_library.remove_non_ascii (TRIM(TRANSLATE(papf.last_name,',???~!@#$%^&*()+{}|:"<>?=[]\/"',' ' ))),1,25) lname     /* 1.3 */
           , SUBSTRB(ttec_library.remove_non_ascii (TRIM(TRANSLATE(papf.middle_names,',???~!@#$%^&*()+{}|:"<>?=[]\/"',' ' ))),1,25) mname  /* 1.3 */
           , ttec_library.remove_non_ascii(papf.email_address) email /* 1.3 */
          -- , 'welcome' password /* 1.3 */
          -- , '280D44AB1E9F79B5CCE2DD4F58F5FE91F0FBACDAC9F7447DFFC318CEB79F2D02' password     /* 1.3 */
           , ''  password /* 1.3 */
           , CASE
               WHEN pj.attribute5 != 'Agent' THEN
                 ttec_promotion_dt( paaf.assignment_id, paaf.effective_start_date )
               ELSE
                 NULL
             END  custom0
           , ( SELECT full_name
                 FROM per_all_people_f
                WHERE person_id = ttech_rt_utils_pk.f_get_executive( papf.person_id )
                  AND emps.asg_date BETWEEN effective_start_date AND effective_end_date ) custom4
           , CASE
               WHEN paaf.employment_category like 'TTAU%'
                AND UPPER( SUBSTR( paaf.employment_category, 6, 1 ) ) = 'F' THEN
                  'Full-time'
               WHEN paaf.employment_category like 'TTAU%'
                AND UPPER( SUBSTR( paaf.employment_category, 6, 1 ) ) = 'P' THEN
                  'Part-time'
               WHEN papf.business_group_id = 1633
                AND UPPER( SUBSTR( paaf.ass_attribute15, 1, 1 ) ) = 'F' THEN
                 'Full-time'
               WHEN papf.business_group_id = 1633
                AND UPPER( SUBSTR( paaf.ass_attribute15, 1, 1 ) ) = 'P' THEN
                 'Part-time'
               WHEN papf.business_group_id <> 1633
                AND UPPER( SUBSTR( paaf.employment_category, 1, 1 ) ) = 'F' THEN
                 'Full-time'
               WHEN papf.business_group_id <> 1633
                AND UPPER( SUBSTR( paaf.employment_category, 1, 1 ) ) in( 'P','V') THEN --V1.8
                 'Part-time'
             END  custom5
           , CASE INSTR(papf.employee_number,'-')
               WHEN 0 THEN papf.employee_number
               ELSE SUBSTR( papf.employee_number, INSTR(papf.employee_number,'-')-1)
             END username
           , SUBSTRB(pj.name,1,255) job_title
           , CASE
               WHEN ttec_is_mgr( papf.person_id, emps.asg_date ) = 'Y' THEN 'TRUE'
               ELSE 'FALSE'
             END ismanager
           , emps.asg_date asg_date
        FROM ( SELECT spob.id id
                    , NVL( adjusted_svc_date, date_start ) date_start
                    , ppos.actual_termination_date term_date
                    -- Assignment effective date: Use term date for terms
                    -- otherwise use TRUNC(sysdate)
                    , CASE SIGN( TRUNC(SYSDATE) - NVL(actual_termination_date, TRUNC(SYSDATE)+1))
                        WHEN 1 THEN actual_termination_date -- Past Termination Date
                        ELSE TRUNC(SYSDATE)                 -- Current / Future or No Term Date
                      END asg_date
                 --FROM cust.ttec_saba_person_out_bk spob  --code commented by RXNETHI-ARGANO,17/05/23
                 FROM apps.ttec_saba_person_out_bk spob    --code added by RXNETHI-ARGANO,17/05/23
                    --, hr.per_periods_of_service ppos  --code commented by RXNETHI-ARGANO,17/05/23 
                    , apps.per_periods_of_service ppos    --code added by RXNETHI-ARGANO,17/05/23
                WHERE spob.id NOT IN ( SELECT spo.id
                                         --FROM cust.ttec_saba_person_out spo ) --code commented by RXNETHI-ARGANO,17/05/23
                                         FROM apps.ttec_saba_person_out spo )   --code added by RXNETHI-ARGANO,17/05/23
                  AND spob.change_flag != 'T'
                  AND ppos.person_id = spob.id
                  -- 1.1 Only get most recent period_of_service record for Termed / Inactive Emps
                  AND date_start = (SELECT MAX( pps2.date_start )
                                     FROM apps.per_periods_of_service pps2
                                    WHERE pps2.person_id = ppos.person_id
                                      AND pps2.date_start <= TRUNC( SYSDATE )) ) emps
           , apps.per_all_people_f papf
           , apps.per_all_assignments_f paaf
           , apps.per_person_type_usages_f ptu
           , apps.per_person_types ppt
           , apps.hr_locations_all hl
           , apps.per_jobs pj
           , apps.hr_all_organization_units hou
           , apps.hr_locations_all org_loc
       WHERE papf.person_id = emps.id
         AND papf.business_group_id <> 0
         AND emps.asg_date BETWEEN papf.effective_start_date AND papf.effective_end_date
         AND papf.person_id = paaf.person_id
         AND emps.asg_date BETWEEN paaf.effective_start_date AND paaf.effective_end_date
         AND paaf.primary_flag = 'Y'
         AND ptu.person_id = papf.person_id
         AND emps.asg_date BETWEEN ptu.effective_start_date AND ptu.effective_end_date
         AND ppt.person_type_id = ptu.person_type_id
         AND ppt.system_person_type LIKE '%EMP%'                      -- 1.2 (3)
         AND paaf.location_id = hl.location_id
         AND paaf.job_id = pj.job_id
         AND hou.organization_id = pj.business_group_id
         AND org_loc.location_id = hou.location_id
         AND papf.person_id = emps.id;

  /*=================================================================================================*\
     Author: Michelle Dodge
       Date: Sep-09-2011
  Call From: TTEC_SABA_OUTBOUND.ttec_person_file
       Desc: This procedure preps the Master and Backup Person tables for this current run
  ====================================================================================================*/
  PROCEDURE truncate_person_tables IS

    --v_module   cust.ttec_error_handling.module_name%TYPE := 'truncate_person_tables';  --code commented by RXNETHI-ARGANO,17/05/23
    v_module   apps.ttec_error_handling.module_name%TYPE := 'truncate_person_tables';    --code added by RXNETHI-ARGANO,17/05/23
    v_loc      NUMBER;

  BEGIN

    --Remove records from the backup table that you are about to process.
    v_loc := 10;
    --DELETE cust.ttec_saba_person_out_bk;   --code commented by RXNETHI-ARGANO,17/05/23
    DELETE apps.ttec_saba_person_out_bk;   --code added by RXNETHI-ARGANO,17/05/23

    --Move records from the master to backup table that you are about to process.
    v_loc := 20;
    --INSERT INTO cust.ttec_saba_person_out_bk    --code commented by RXNETHI-ARGANO,17/05/23
    INSERT INTO apps.ttec_saba_person_out_bk      --code added by RXNETHI-ARGANO,17/05/23
      ( SELECT *
         --FROM cust.ttec_saba_person_out);   --code commented by RXNETHI-ARGANO,17/05/23
         FROM apps.ttec_saba_person_out);     --code added by RXNETHI-ARGANO,17/05/23

    --Delete the master records for the bucket being processed.
    v_loc := 30;
    --DELETE cust.ttec_saba_person_out;     --code commented by RXNETHI-ARGANO,17/05/23
    DELETE apps.ttec_saba_person_out;       --code added by RXNETHI-ARGANO,17/05/23

    COMMIT;

  EXCEPTION
    WHEN OTHERS THEN
      ttec_error_logging.process_error( g_application_code
                                      , g_interface
                                      , g_package
                                      , v_module
                                      , g_failure_status
                                      , SQLCODE
                                      , SQLERRM
                                      , g_label1
                                      , v_loc
                                      );
      RAISE;
  END truncate_person_tables;


  /*=================================================================================================*\
     Author: Michelle Dodge
       Date: Sep-09-2011
  Call From: TTEC_SABA_OUTBOUND.ttec_person_file
       Desc: This procedure will insert both the Active and Inactive records
             into the ttec_saba_person_out table.
  ====================================================================================================*/
  PROCEDURE insert_person_data( p_person_rec   IN c_term_person%ROWTYPE  -- Used by both c_person and c_term_person.  Any changes to cursors could 'break' it.
                              , p_change_flag  IN VARCHAR ) IS

    --v_module   cust.ttec_error_handling.module_name%TYPE := 'insert_person_data';   --code commented by RXNETHI-ARGANO,17/05/23
    v_module   apps.ttec_error_handling.module_name%TYPE := 'insert_person_data';     --code added by RXNETHI-ARGANO,17/05/23
    v_loc             NUMBER;

    --r_saba_person  cust.ttec_saba_person_out%ROWTYPE;  --code commented by RXNETHI-ARGANO,17/05/23
    r_saba_person  apps.ttec_saba_person_out%ROWTYPE;    --code added by RXNETHI-ARGANO,17/05/23

    v_split           ttec_saba_person_out.split%TYPE           := 'TeleTech';
    v_home_domain     ttec_saba_person_out.home_domain%TYPE     := 'TeleTech';
    v_timezone_id     ttec_saba_person_out.timezone_id%TYPE     := 'tzone000000000000007';
    v_security_role0  ttec_saba_person_out.security_role0%TYPE  := 'Report Privileges in world domain';
    v_role_domain0    ttec_saba_person_out.role_domain0%TYPE    := 'world';
    v_change_flag     ttec_saba_person_out.change_flag%TYPE;

    CURSOR c_emp_proj( l_person_id IN NUMBER ) IS
        SELECT clt_cd || '.' || client_desc clt_cd
             , prog_cd || '.' || program_desc prog_cd
             , prj_cd || '.' || project_desc prj_cd
          FROM apps.ttec_emp_proj_asg
         WHERE person_id = l_person_id
           AND p_person_rec.asg_date BETWEEN prj_strt_dt AND NVL( prj_end_dt, SYSDATE )
      ORDER BY proportion DESC
             , prj_strt_dt
             , creation_date;

    emp_proj_rec    c_emp_proj%ROWTYPE;

  BEGIN
    v_loc := 10;

    r_saba_person.id                 := p_person_rec.id;
    r_saba_person.person_no          := p_person_rec.person_no;
    r_saba_person.status             := p_person_rec.status;
    r_saba_person.manager_id         := p_person_rec.manager_id;
    r_saba_person.person_type        := p_person_rec.person_type;
    r_saba_person.started_on         := p_person_rec.started_on;
    r_saba_person.terminated_on      := p_person_rec.terminated_on;  -- 1.2 (1)
    r_saba_person.location_id        := p_person_rec.location_id;
    r_saba_person.jobtype_id         := p_person_rec.jobtype_id;
    r_saba_person.gender             := p_person_rec.gender;
    r_saba_person.locale_id          := p_person_rec.locale_id;
    r_saba_person.company_id         := p_person_rec.company_id;
    r_saba_person.fname              := p_person_rec.fname;
    r_saba_person.lname              := p_person_rec.lname;
    r_saba_person.mname              := p_person_rec.mname;
    r_saba_person.email              := p_person_rec.email;
    r_saba_person.password           := p_person_rec.password;
    r_saba_person.custom0            := p_person_rec.custom0;
    r_saba_person.custom4            := p_person_rec.custom4;
    r_saba_person.custom5            := p_person_rec.custom5;
    r_saba_person.username           := p_person_rec.username;
    r_saba_person.job_title          := p_person_rec.job_title;
    r_saba_person.ismanager          := p_person_rec.ismanager;
    r_saba_person.split              := v_split;
    r_saba_person.home_domain        := v_home_domain;
    r_saba_person.timezone_id        := v_timezone_id;
    r_saba_person.security_role0     := v_security_role0;
    r_saba_person.role_domain0       := v_role_domain0;
    r_saba_person.change_flag        := p_change_flag;
    r_saba_person.create_request_id  := g_request_id;
    r_saba_person.created_by         := g_created_by;
    r_saba_person.last_updated_by    := g_created_by;
    r_saba_person.creation_date      := SYSDATE;
    r_saba_person.last_update_date   := SYSDATE;

    -- Get the first matched employee project record
    v_loc := 20;
    emp_proj_rec   := NULL;

  BEGIN /* 1.9 */
    OPEN c_emp_proj( p_person_rec.id );
    FETCH c_emp_proj INTO emp_proj_rec;
    CLOSE c_emp_proj;
  EXCEPTION /* 1.9 */
    WHEN OTHERS THEN /* 1.9 */
      ttec_error_logging.process_error( g_application_code
                                      , g_interface
                                      , g_package
                                      , v_module
                                      , g_warning_status
                                      , SQLCODE
                                      , SQLERRM
                                      , g_label1
                                      , v_loc
                                      , g_label2
                                      , p_person_rec.id
                                      , 'Emp#'
                                      , p_person_rec.username /* 1.9 */
                                      );
   END; /* 1.9 */

    r_saba_person.custom1            := emp_proj_rec.clt_cd;
    r_saba_person.custom2            := emp_proj_rec.prog_cd;
    r_saba_person.custom3            := emp_proj_rec.prj_cd;

    v_loc := 30;
    INSERT INTO ttec_saba_person_out
    VALUES r_saba_person;

    COMMIT;

  EXCEPTION
    WHEN OTHERS THEN
      ttec_error_logging.process_error( g_application_code
                                      , g_interface
                                      , g_package
                                      , v_module
                                      , g_warning_status
                                      , SQLCODE
                                      , SQLERRM
                                      , g_label1
                                      , v_loc
                                      , g_label2
                                      , p_person_rec.id
                                      );
  END insert_person_data;

  /*=================================================================================================*\
     Author: Michelle Dodge
       Date: Sep-09-2011
  Call From: TTEC_SABA_OUTBOUND.ttec_person_file
       Desc: This procedure will identify Unchanged Emps from prior run and reset Change_Flag to 'N'
  ====================================================================================================*/
  PROCEDURE update_change IS

    --v_module         cust.ttec_error_handling.module_name%TYPE := 'update_change';  --code commented by RXNETHI-ARGANO,17/05/23
    v_module         apps.ttec_error_handling.module_name%TYPE := 'update_change';    --code added by RXNETHI-ARGANO,17/05/23
    v_loc            NUMBER;

    --v_emp_id         cust.ttec_saba_person_out.id%TYPE;  --code commented by RXNETHI-ARGANO,17/05/23
    v_emp_id         apps.ttec_saba_person_out.id%TYPE;    --code added by RXNETHI-ARGANO,17/05/23
    v_owner          all_tables.owner%TYPE                          := 'CUST';
    v_table_name     all_tables.table_name%TYPE       := 'TTEC_SABA_PERSON_OUT';

    -- Dynamic Cursor variables
    v_select         VARCHAR2( 50 );
    v_from           VARCHAR2( 100 );
    v_where          VARCHAR2( 32000 );
    v_col_a          VARCHAR2( 100 );
    v_col_b          VARCHAR2( 100 );
    v_sql            VARCHAR2( 32000 );
    csr_update_emp   sys_refcursor;

    CURSOR csr_tab_columns IS
      SELECT column_name
           , data_type
        FROM all_tab_columns
       WHERE owner = v_owner
         AND table_name = v_table_name
         -- Do NOT compare WHO and Status Flag fields
         AND column_name NOT IN
               ( 'CHANGE_FLAG', 'CREATE_REQUEST_ID'
               , 'CREATION_DATE', 'CREATED_BY', 'LAST_UPDATE_DATE'
               , 'LAST_UPDATED_BY', 'LAST_UPDATE_LOGIN' );

  BEGIN
    v_loc := 10;
    v_select := ' SELECT b.id ';
    --v_from   := ' FROM cust.ttec_saba_person_out a, cust.ttec_saba_person_out_bk b '; --code commented by RXNETHI-ARGANO,17/05/23
    v_from   := ' FROM cust.ttec_saba_person_out a, cust.ttec_saba_person_out_bk b ';   --code added by RXNETHI-ARGANO,17/05/23
    v_where  := ' WHERE a.id = b.id ';

    FOR rec_tab_columns IN csr_tab_columns LOOP
      v_loc := 20;

      IF rec_tab_columns.data_type = 'VARCHAR2' THEN
        v_col_a := ' NVL(a.' || rec_tab_columns.column_name || ', ''*'') ';
        v_col_b := ' NVL(b.' || rec_tab_columns.column_name || ', ''*'') ';
      ELSIF rec_tab_columns.data_type = 'NUMBER' THEN
        v_col_a := ' NVL(a.' || rec_tab_columns.column_name || ', -9999) ';
        v_col_b := ' NVL(b.' || rec_tab_columns.column_name || ', -9999) ';
      ELSE                               -- rec_tab_columns.data_type = 'DATE'
        v_col_a := ' NVL(a.' || rec_tab_columns.column_name || ', ''01-JAN-1000'') ';
        v_col_b := ' NVL(b.' || rec_tab_columns.column_name || ', ''01-JAN-1000'') ';
      END IF;

      v_where := v_where || ' AND ' || v_col_a || ' = ' || v_col_b;
    END LOOP;

    v_loc := 30;

    v_sql := v_select || v_from || v_where;

    -- Output SQL statement to log file for support
    fnd_file.put_line( fnd_file.LOG, 'UPDATE CHANGE: Dynamic SQL Statement' );
    fnd_file.put_line( fnd_file.LOG, '------------------------------------' );
    fnd_file.put_line( fnd_file.LOG, v_sql );
    fnd_file.new_line( fnd_file.LOG, 1 );

    v_loc := 40;

    OPEN csr_update_emp FOR v_sql;
    LOOP
      FETCH csr_update_emp
       INTO v_emp_id;
      EXIT WHEN csr_update_emp%NOTFOUND;

      v_loc := 50;
      --UPDATE cust.ttec_saba_person_out  --code commented by RXNETHI-ARGANO,17/05/23
      UPDATE apps.ttec_saba_person_out    --code added by RXNETHI-ARGANO,17/05/23
         SET change_flag = 'N'
       WHERE id = v_emp_id;
    END LOOP;

    CLOSE csr_update_emp;

    COMMIT;
  EXCEPTION
    WHEN OTHERS THEN
      ttec_error_logging.process_error( g_application_code
                                      , g_interface
                                      , g_package
                                      , v_module
                                      , g_failure_status
                                      , SQLCODE
                                      , SQLERRM
                                      , g_label1
                                      , v_loc
                                      , 'EmpId'
                                      , v_emp_id
                                      );
      RAISE;
  END update_change;


  /*=================================================================================================*\
     Author: Elango Pandu
       Date: Apr-25-2011
  Call From: TTEC_SABA_OUTBOUND.ttec_person_file
       Desc: This function returns Y if this person id is manager else returns 'N'
  ====================================================================================================*/
  FUNCTION ttec_is_mgr( p_person_id   IN NUMBER
                      , p_start_dt    IN DATE )
    RETURN VARCHAR2 IS

    --v_module   cust.ttec_error_handling.module_name%TYPE := 'ttec_is_mgr';  --code commented by RXNETHI-ARGANO,17/05/23
    v_module   apps.ttec_error_handling.module_name%TYPE := 'ttec_is_mgr';    --code added by RXNETHI-ARGANO,17/05/23
    v_loc      NUMBER;

    v_mgr   VARCHAR2( 1 ) := 'N';

    CURSOR c1 IS
      SELECT 'Y'
        FROM per_all_assignments_f paaf
           , apps.per_person_type_usages_f ptu
           , apps.per_person_types ppt
           , per_jobs pj
       WHERE paaf.supervisor_id = p_person_id
         AND paaf.primary_flag = 'Y'
         AND p_start_dt BETWEEN paaf.effective_start_date AND paaf.effective_end_date
         AND ptu.person_id = paaf.person_id
         AND TRUNC( SYSDATE ) BETWEEN ptu.effective_start_date AND ptu.effective_end_date
         AND ppt.person_type_id = ptu.person_type_id
         AND ppt.system_person_type LIKE 'EMP%'
         AND pj.job_id = paaf.job_id
         AND pj.attribute5 != 'Agent';  -- 1.2 (4)

  BEGIN

    v_loc := 10;
    OPEN c1;
    FETCH c1 INTO v_mgr;
    CLOSE c1;

    v_loc := 20;
    IF v_mgr = 'Y' THEN
      v_mgr   := 'Y';
    ELSE
      v_mgr   := 'N';
    END IF;

    RETURN v_mgr;

  EXCEPTION
    WHEN OTHERS THEN
      v_mgr   := 'N';

      ttec_error_logging.process_error( g_application_code
                                      , g_interface
                                      , g_package
                                      , v_module
                                      , g_warning_status
                                      , SQLCODE
                                      , SQLERRM
                                      , g_label1
                                      , v_loc
                                      , 'EmpId'
                                      , p_person_id
                                      );
  END ttec_is_mgr;


  /*=================================================================================================*\
     Author: Elango Pandu
       Date: Apr-25-2011
  Call From: TTEC_SABA_OUTBOUND.ttec_person_file
       Desc: This function returns effective start date from assignment table when emp promoted to G&A from Agent
  ====================================================================================================*/
  FUNCTION ttec_promotion_dt( p_asg_id     IN NUMBER
                            , p_start_dt   IN DATE )
    RETURN VARCHAR2 IS

    --v_module   cust.ttec_error_handling.module_name%TYPE := 'ttec_promotion_dt';  --code commented by RXNETHI-ARGANO,17/05/23
    v_module   apps.ttec_error_handling.module_name%TYPE := 'ttec_promotion_dt';    --code added by RXNETHI-ARGANO,17/05/23
    v_loc      NUMBER;

    v_yes    VARCHAR2( 1 );
    v_date   VARCHAR2( 10 );

    CURSOR c1 IS
        SELECT paaf.assignment_id
             , paaf.job_id
             , paaf.effective_start_date
             , paaf.effective_end_date
          FROM per_all_assignments_f paaf
         WHERE paaf.assignment_id = p_asg_id
           AND paaf.effective_start_date < p_start_dt
      ORDER BY paaf.effective_start_date DESC;

    CURSOR c_agent_job( p_job_id NUMBER ) IS
      SELECT 'Y'
        FROM apps.per_jobs job
       WHERE job.job_id = p_job_id
         AND TRUNC( SYSDATE ) BETWEEN job.date_from AND NVL( job.date_to, SYSDATE )
         AND job.attribute5 = 'Agent';
  BEGIN

    v_loc := 10;
    FOR v1 IN c1 LOOP
      v_yes   := NULL;

      v_loc := 20;
      OPEN c_agent_job( v1.job_id );
      FETCH c_agent_job INTO v_yes;
      CLOSE c_agent_job;

      v_loc := 30;
      IF NVL( v_yes, 'N' ) = 'Y' THEN
        v_date   := TO_CHAR( ( v1.effective_end_date + 1 ), 'YYYY-MM-DD' );
        EXIT;
      END IF;

    END LOOP;

    RETURN v_date;

  EXCEPTION
    WHEN OTHERS THEN
      v_date   := NULL;

      ttec_error_logging.process_error( g_application_code
                                      , g_interface
                                      , g_package
                                      , v_module
                                      , g_warning_status
                                      , SQLCODE
                                      , SQLERRM
                                      , g_label1
                                      , v_loc
                                      , 'Asg ID'
                                      , p_asg_id
                                      );
  END ttec_promotion_dt;


  /*=================================================================================================*\
     Author: Michelle Dodge
       Date: Sep-08-2011
  Call From: 'TeleTech Saba Person Outbound' concurrent program
       Desc: This procedure extracts employee information to interface to Saba tool
  ====================================================================================================*/
  PROCEDURE ttec_person_file( errbuf         OUT VARCHAR2
                            , retcode        OUT NUMBER
                            , p_mode      IN     VARCHAR2 ) IS

    --v_module   cust.ttec_error_handling.module_name%TYPE := 'ttec_person_file';  --code commented by RXNETHI-ARGANO,17/05/23
    v_module   apps.ttec_error_handling.module_name%TYPE := 'ttec_person_file';    --code added by RXNETHI-ARGANO,17/05/23
    v_loc             NUMBER;

    v_change_flag     ttec_saba_person_out.change_flag%TYPE;

    v_cnt           NUMBER := 0;
    v_err           VARCHAR2( 100 );
    v_host          VARCHAR2( 20 );

    v_output_file   UTL_FILE.file_type;
    --v_filename      VARCHAR2( 50 ) := 'employee_' || TO_CHAR( SYSDATE, 'YYYYMMDD_HH24MISS' ) || '.csv'; /* 1.3 */
    v_filename      VARCHAR2( 50 ) := 'int_person_' || TO_CHAR( SYSDATE, 'YYYYMMDD_HH24MISS' ) || '.csv'; /* 1.3 */

    CURSOR c_person_out IS
      SELECT id                         ||'|'||
             person_no                  ||'|'||
             status                     ||'|'||
             manager_id                 ||'|'||
             person_type                ||'|'||
             started_on                 ||'|'||
             terminated_on              ||'|'||
             location_id                ||'|'||
             split                      ||'|'||
             rate                       ||'|'||
             jobtype_id                 ||'|'||
             ss_no                      ||'|'||
             gender                     ||'|'||
             home_domain                ||'|'||
             desired_job_type_id        ||'|'||
             locale_id                  ||'|'||
             timezone_id                ||'|'||
             company_id                 ||'|'||
             title                      ||'|'||
             fname                      ||'|'||
             lname                      ||'|'||
             mname                      ||'|'||
             homephone                  ||'|'||
             workphone                  ||'|'||
             fax                        ||'|'||
             email                      ||'|'||
             password                   ||'|'||
             date_of_birth              ||'|'||
             correspondence_preference1 ||'|'||
             correspondence_preference2 ||'|'||
             correspondence_preference3 ||'|'||
             addr1                      ||'|'||
             addr2                      ||'|'||
             city                       ||'|'||
             state                      ||'|'||
             zip                        ||'|'||
             country                    ||'|'||
             custom0                    ||'|'||
             custom1                    ||'|'||  -- clt_cd
             custom2                    ||'|'||  -- prog_cd
             custom3                    ||'|'||  -- prj_cd
             custom4                    ||'|'||
             custom5                    ||'|'||
             custom6                    ||'|'||
             custom7                    ||'|'||
             custom8                    ||'|'||
             custom9                    ||'|'||
             security_role0             ||'|'||
             role_domain0               ||'|'||
             security_role1             ||'|'||
             role_domain1               ||'|'||
/* 1.3 begin */
--             security_role2             ||'|'||
--             role_domain2               ||'|'||
--             security_role3             ||'|'||
--             role_domain3               ||'|'||
--             security_role4             ||'|'||
--             role_domain4               ||'|'||
--             security_role5             ||'|'||
--             role_domain5               ||'|'||
--             security_role6             ||'|'||
--             role_domain6               ||'|'||
--             security_role7             ||'|'||
--             role_domain7               ||'|'||
--             security_role8             ||'|'||
--             role_domain8               ||'|'||
--             security_role9             ||'|'||
--             role_domain9               ||'|'||
/* 1.3 end */
             audience_type0             ||'|'||
             audience_type1             ||'|'||
/* 1.3 begin */
--             audience_type2             ||'|'||
--             audience_type3             ||'|'||
--             audience_type4             ||'|'||
--             audience_type5             ||'|'||
--             audience_type6             ||'|'||
--             audience_type7             ||'|'||
--             audience_type8             ||'|'||
--             audience_type9             ||'|'||
/* 1.3 end */
             username                   ||'|'||
             ethnicity                  ||'|'||
             job_title                  ||'|'||
             suffix                     ||'|'||
             religion                   ||'|'||
             addr3                      ||'|'||
             ismanager AS person
        --FROM cust.ttec_saba_person_out  --code commented by RXNETHI-ARGANO,17/05/23
        FROM apps.ttec_saba_person_out    --code added by RXNETHI-ARGANO,17/05/23
       WHERE change_flag IN ('F','Y','T');  --  Include Terms plus Full File or Incremental Changes

  BEGIN

    v_loc := 10;
    g_interface     := 'Saba Person Out';
    v_output_file   := UTL_FILE.fopen( g_directory, v_filename, 'W' );

    FND_FILE.put_line( FND_FILE.OUTPUT
                     ,    'TeleTech Saba Person Outbound Interface  Mode :  '
                       || p_mode
                       || '   Date : '
                       || TO_CHAR( SYSDATE, 'MM/DD/YYYY HH24:MM' ) );

    UTL_FILE.put_line( v_output_file
                   --  , 'Id|person_no|Status|Manager_id|person_type|started_on|Terminated_On|Location_id|Split|Rate|Jobtype_id|SS_NO|gender|home_domain|desired_job_type_id|locale_id|timezone_id|company_id|title|fname|lname|mname|homephone|workphone|fax|email|password|date_of_birth|correspondence_preference1|correspondence_preference2|correspondence_preference3|addr1|addr2|City|state|zip|country|custom0|custom1|custom2|custom3|custom4|custom5|custom6|custom7|custom8|custom9|security_role0|role_domain0|security_role1|role_domain1|security_role2|role_domain2| security_role3|role_domain3| security_role4|role_domain4| security_role5|role_domain5| security_role6|role_domain6| security_role7|role_domain7| security_role8|role_domain8| security_role9|role_domain9|audience_type0|audience_type1|audience_type2|audience_type3|audience_type4|audience_type5|audience_type6|audience_type7|audience_type8|audience_type9|username|ethnicity|job_title|suffix|religion|addr3|ismanager' ); /* 1.3 */
                     , 'ID|PERSON_NO|STATUS|MANAGER|PERSON_TYPE|HIRED_ON|TERMINATED_ON|LOCATION|SECURITY_DOMAIN|RATE|JOB_TYPE|SS_NO|GENDER|HOME_DOMAIN|DESIRED_JOB_TYPE|LOCALE|TIMEZONE|COMPANY|TITLE|FNAME|LNAME|MNAME|HOMEPHONE|WORKPHONE|FAX|EMAIL|PASSWORD|DATE_OF_BIRTH|CORRESPONDENCE1|CORRESPONDENCE2|CORRESPONDENCE3|ADDR_1|ADDR_2|CITY|STATE|ZIP|COUNTRY|CUSTOM0|CUSTOM1|CUSTOM2|CUSTOM3|CUSTOM4|CUSTOM5|CUSTOM6|CUSTOM7|CUSTOM8|CUSTOM9|SECURITY_ROLE1|DOMAIN1|SECURITY_ROLE2|DOMAIN2|' /* 1.3 */  --SECURITY_ROLE3|DOMAIN3|SECURITY_ROLE4|DOMAIN4|SECURITY_ROLE5|DOMAIN5|SECURITY_ROLE6|DOMAIN6|SECURITY_ROLE7|DOMAIN7|SECURITY_ROLE8|DOMAIN8|SECURITY_ROLE9|DOMAIN9|SECURITY_ROLE10|DOMAIN10|
                        ||'AUDIENCE_TYPE1|AUDIENCE_TYPE2|' /* 1.3 */ --AUDIENCE_TYPE3|AUDIENCE_TYPE4|AUDIENCE_TYPE5|AUDIENCE_TYPE6|AUDIENCE_TYPE7|AUDIENCE_TYPE8|AUDIENCE_TYPE9|AUDIENCE_TYPE10|
                        ||'USERNAME|ETHNICITY|JOB_TITLE|SUFFIX|RELIGION|ADDR_3|IS_MANAGER'); /* 1.3 */


    -- Backup and truncate employee staging table
    v_loc := 20;
    truncate_person_tables;

    -- Process current Active Employees
    v_loc := 30;
    IF p_mode = 'Full File' THEN
      v_change_flag := 'F';
      fnd_file.put_line( fnd_file.LOG, 'Executing Full File Run of Active Employees' );
    ELSE
      -- For incrementals, initialize flag to 'Y' and then reset to 'N' if no mods
      v_change_flag := 'Y';
      fnd_file.put_line( fnd_file.LOG, 'Executing Incremental Run of Active Employees'||g_employee_number  );
    END IF;

    v_loc := 40;
    g_employee_number := 'c_person';
    FOR person_rec IN c_person LOOP
      g_employee_number := person_rec.username;
      insert_person_data( person_rec, v_change_flag );
    END LOOP;

    -- If an incremental run, then compare records and update change_flag
    v_loc := 50;
    IF p_mode = 'Update Mode' THEN
      update_change;
    END IF;

    -- Process Newly Inactive Employees (terms and other reasons)
    v_loc := 60;
    g_employee_number := 'c_term_person';
    FOR person_rec IN c_term_person LOOP
      g_employee_number := person_rec.username;
      v_change_flag := 'T';
      fnd_file.put_line( fnd_file.LOG, 'Executing Run of Newly Inactivated Employees '||g_employee_number );

      insert_person_data( person_rec, v_change_flag );
    END LOOP;

    -- Output New + Changes (change_flag = 'Y') or All Active (change_flag = 'F')
    v_loc := 70;
    FOR person_out_rec IN c_person_out LOOP
      UTL_FILE.put_line( v_output_file
                       , person_out_rec.person );
    END LOOP;

    UTL_FILE.fclose( v_output_file );

  EXCEPTION
    WHEN OTHERS THEN
      v_err   := SUBSTR( SQLERRM, 1, 50 );
      fnd_file.put_line( fnd_file.output, 'ERR' || v_err );
      UTL_FILE.fclose( v_output_file );

      ttec_error_logging.process_error( g_application_code
                                      , g_interface
                                      , g_package
                                      , v_module
                                      , g_failure_status
                                      , SQLCODE
                                      , SQLERRM
                                      , g_label1
                                      , v_loc
                                      , g_label3
                                      , g_employee_number
                                      );
  END ttec_person_file;


  /*=================================================================================================*\
     Author: Elango Pandu
       Date: Apr-25-2011
  Call From: 'TeleTech Saba Location Outbound' concurrent program
       Desc: This procedure extracts HR Location information to interface to Saba tool
  ====================================================================================================*/
  PROCEDURE ttec_location_file( errbuf       OUT VARCHAR2
                              , retcode      OUT NUMBER
                              , p_mode    IN     VARCHAR2 ) IS

    --v_module   cust.ttec_error_handling.module_name%TYPE := 'ttec_location_file';  --code commented by RXNETHI-ARGANO,17/05/23
    v_module   apps.ttec_error_handling.module_name%TYPE := 'ttec_location_file';    --code added by RXNETHI-ARGANO,17/05/23
    v_loc      NUMBER;

    v_cnt           NUMBER := 0;
    v_last_run_dt   DATE;
    v_err           VARCHAR2( 100 );
    v_host          VARCHAR2( 20 );

    v_output_file   UTL_FILE.file_type;
    v_filename      VARCHAR2( 50 ) := 'location_' || TO_CHAR( SYSDATE, 'YYYYMMDD_HH24MISS' ) || '.csv'; /* 1.3 */
    --v_filename      VARCHAR2( 50 ) := 'int_location_' || TO_CHAR( SYSDATE, 'YYYYMMDD_HH24MISS' ) || '.csv'; /* 1.3 */

    CURSOR c_location IS
      SELECT   location_id           ||'|'||                                                                      -- id
               location_id            ||'|'||                                                                  -- loc_no
               NULL                   ||'|'||                                                              -- contact_id
               'TeleTech'             ||'|'||                                                          -- domain / split
               NULL                   ||'|'||                                                                 -- dept_id
               location_code          ||'|'||                                                                 -- locname
               'TRUE'                 ||'|'||                                                                 -- enabled
               'tzone000000000000007' ||'|'||                                                             -- timezone_id
               NULL                   ||'|'||                                                                  -- phone1
               NULL                   ||'|'||                                                                  -- phone2
               NULL                   ||'|'||                                                                     -- fax
               NULL                   ||'|'||                                                                   -- email
               address_line_1         ||'|'||                                                                   -- addr1
               address_line_2         ||'|'||                                                                   -- addr2
               town_or_city           ||'|'||                                                                    -- city
               region_2               ||'|'||                                                                   -- state
               postal_code            ||'|'||                                                                     -- zip
               country                ||'|'||                                                                 -- country
               attribute2             ||'|'||                                                   -- custom0 = GL Location
               NULL                   ||'|'||                                                                 -- custom1
               NULL                   ||'|'||                                                                 -- custom2
               NULL                   ||'|'||                                                                 -- custom3
               NULL                   ||'|'||                                                                 -- custom4
               NULL                   ||'|'||                                                                 -- custom5
               NULL                   ||'|'||                                                                 -- custom6
               NULL                   ||'|'||                                                                 -- custom7
               NULL                   ||'|'||                                                                 -- custom8
               NULL ||'|'|| 'Talent' /* 1.3 */                                                                                            -- custom9
               AS loc
        FROM hr_locations_all
       WHERE attribute2 IS NOT NULL
         AND NVL( inactive_date, '31-DEC-4712' ) > SYSDATE;

    CURSOR c_upd_loc IS
      SELECT location_id id
           , location_id loc_no
           , NULL contact_id
           , 'TeleTech' split
           , NULL dept_id
           , location_code locname
           , CASE
               WHEN NVL( inactive_date, '31-DEC-4712' ) > SYSDATE THEN 'TRUE'  -- 1.2 (5)
               ELSE 'FALSE'
             END
               enabled
           , 'tzone000000000000007' timezone_id
           , NULL phone1
           , NULL phone2
           , NULL fax
           , NULL email
           , address_line_1 addr1
           , address_line_2 addr2
           , town_or_city city
           , region_2 state
           , postal_code zip
           , country country
           , attribute2 custom0
           , NULL custom1
           , NULL custom2
           , NULL custom3
           , NULL custom4
           , NULL custom5
           , NULL custom6
           , NULL custom7
           , NULL custom8
           , NULL custom9
        FROM apps.hr_locations_all
       WHERE attribute2 IS NOT NULL             -- 1.2 (6) Only pull locations with GL Code
         AND (    GREATEST( last_update_date, creation_date ) BETWEEN v_last_run_dt AND SYSDATE
               OR inactive_date BETWEEN v_last_run_dt AND SYSDATE );       -- 1.1 Include Future Dated Inactives

    CURSOR c_last_run IS
      SELECT MAX( actual_start_date )
        FROM fnd_conc_req_summary_v
       WHERE program_short_name = 'TTEC_SABA_LOCATION'
         AND phase_code = 'C'
         AND completion_text = 'Normal completion';
  BEGIN

    v_loc := 10;
    g_interface     := 'Saba Loc Out';
    v_output_file   := UTL_FILE.fopen( g_directory, v_filename, 'W' );

    FND_FILE.put_line( FND_FILE.OUTPUT
                     ,    'TeleTech Saba Location Outbound Interface  Mode :  '
                       || p_mode
                       || '   Date : '
                       || TO_CHAR( SYSDATE, 'MM/DD/YYYY HH24:MM' ) );

    UTL_FILE.put_line(
                       v_output_file
                    -- , 'Id|Loc_no|Contact_id|Split|Dept_id|locname|enabled|timezone_id|phone1|phone2|fax|email|addr1|addr2|city|state|zip|country|custom0|custom1|custom2|custom3|custom4|custom5|custom6|custom7|custom8|custom9' ); /* 1.3 */
                     , 'ID|LOC_NO|CONTACT|DOMAIN|DEPARTMENT|LOC_NAME|ENABLED|TIMEZONE|PHONE1|PHONE2|FAX|EMAIL|ADDR1|ADDR2|CITY|STATE|ZIP|COUNTRY|CUSTOM0|CUSTOM1|CUSTOM2|CUSTOM3|CUSTOM4|CUSTOM5|CUTOM6|CUSTOM7|CUSTOM8|CUSTOM9|LOCATION_TYPE' ); /* 1.3 */


    IF p_mode = 'Full File' THEN

      v_loc := 20;
      FOR c1 IN c_location LOOP
        UTL_FILE.put_line( v_output_file, c1.loc );
      END LOOP;

    ELSE

      v_loc := 30;
      OPEN c_last_run;
      FETCH c_last_run INTO v_last_run_dt;
      CLOSE c_last_run;

      v_loc := 40;
      IF v_last_run_dt IS NOT NULL THEN

        v_loc := 50;
        FOR c1 IN c_upd_loc LOOP
          UTL_FILE.put_line( v_output_file
                           , c1.id          ||'|'||
                             c1.loc_no      ||'|'||
                             c1.contact_id  ||'|'||
                             c1.split       ||'|'||
                             c1.dept_id     ||'|'||
                             c1.locname     ||'|'||
                             c1.enabled     ||'|'||
                             c1.timezone_id ||'|'||
                             c1.phone1      ||'|'||
                             c1.phone2      ||'|'||
                             c1.fax         ||'|'||
                             c1.email       ||'|'||
                             c1.addr1       ||'|'||
                             c1.addr2       ||'|'||
                             c1.city        ||'|'||
                             c1.state       ||'|'||
                             c1.zip         ||'|'||
                             c1.country     ||'|'||
                             c1.custom0     ||'|'||
                             c1.custom1     ||'|'||
                             c1.custom2     ||'|'||
                             c1.custom3     ||'|'||
                             c1.custom4     ||'|'||
                             c1.custom5     ||'|'||
                             c1.custom6     ||'|'||
                             c1.custom7     ||'|'||
                             c1.custom8     ||'|'||
                             c1.custom9     ||'|'||
                             'Talent' );
        END LOOP;

      ELSE

        -- If last run is null then run in full mode
        v_loc := 60;
        FOR c1 IN c_location LOOP
          UTL_FILE.put_line( v_output_file, c1.loc );
        END LOOP;

      END IF;

    END IF;

  EXCEPTION
    WHEN OTHERS THEN
      v_err   := SUBSTR( SQLERRM, 1, 50 );
      fnd_file.put_line( fnd_file.output, 'ERR' || v_err );
      UTL_FILE.fclose( v_output_file );

      ttec_error_logging.process_error( g_application_code
                                      , g_interface
                                      , g_package
                                      , v_module
                                      , g_failure_status
                                      , SQLCODE
                                      , SQLERRM
                                      , g_label1
                                      , v_loc
                                      );
  END ttec_location_file;


  /*=================================================================================================*\
     Author: Elango Pandu
       Date: Apr-25-2011
  Call From: 'TeleTech Saba Job Outbound' concurrent program
       Desc: This procedure extracts HR Job information to interface to Saba tool
  ====================================================================================================*/
  PROCEDURE ttec_job_file( errbuf       OUT VARCHAR2
                         , retcode      OUT NUMBER
                         , p_mode    IN     VARCHAR2 ) IS

    --v_module   cust.ttec_error_handling.module_name%TYPE := 'ttec_job_file';  --code commented by RXNETHI-ARGANO,17/05/23
    v_module   apps.ttec_error_handling.module_name%TYPE := 'ttec_job_file';    --code added by RXNETHI-ARGANO,17/05/23
    v_loc      NUMBER;

    v_cnt           NUMBER := 0;
    v_last_run_dt   DATE;
    v_err           VARCHAR2( 100 );
    v_host          VARCHAR2( 20 );

    v_output_file   UTL_FILE.file_type;
    v_filename      VARCHAR2( 50 ) := 'job_type_' || TO_CHAR( SYSDATE, 'YYYYMMDD_HH24MISS' ) || '.csv'; /* 1.3 */
    --v_filename      VARCHAR2( 50 ) := 'int_job_type_' || TO_CHAR( SYSDATE, 'YYYYMMDD_HH24MISS' ) || '.csv'; /* 1.3 */

    CURSOR c_job IS
      SELECT distinct
             --pj.name ||'.'|| hl.country            ||'|'||     /* 1.3 */                                             --id
             --pj.name ||'.'|| hl.country            ||'|'||     /* 1.3 */                                             --name
             --ttec_library.remove_non_ascii (TRIM(TRANSLATE(pj.name,',???~!@#$%^&*()+{}|:"<>?=[]\/"',' ' ))) ||'|'||    --id       /* 1.3 */
             --ttec_library.remove_non_ascii (TRIM(TRANSLATE(pj.name,',???~!@#$%^&*()+{}|:"<>?=[]\/"',' ' ))) ||'|'||    --name    /* 1.3 */
             pj.name                              ||'|'||     /* 1.3 */                                             --id
             pj.name                              ||'|'||     /* 1.3 */                                             --name
            'TeleTech'                            ||'|'||                                                       --split
             NULL                                  ||'|'||                                                 --description
             pj.attribute6                         ||'|'||                                                     --custom0
             NULL                                  ||'|'||                                                     --custom1
             NULL                                  ||'|'||                                                     --custom2
             NULL                                  ||'|'||                                                     --custom3
             NULL                                  ||'|'||                                                     --custom4
             NULL                                  ||'|'||                                                     --custom5
             NULL                                  ||'|'||                                                     --custom6
             NULL                                  ||'|'||                                                     --custom7
             NULL                                  ||'|'||                                                     --custom8
             --pj.name ||'.'|| hl.country            ||'|'||                                                     --custom9
             ttec_library.remove_non_ascii (TRIM(TRANSLATE(pj.name,',???~!@#$%^&*()+{}|:"<>?=[]\/"',' ' ))) ||'|'|| --custom9
             pj.attribute5                         ||'|'||                                                  --familiy_id
             TO_CHAR( pj.date_from, 'YYYY-MM-DD' ) ||'|'||                                                   --date from
             TO_CHAR( pj.date_to, 'YYYY-MM-DD' )   AS job                                                    -- date to
        FROM per_jobs pj
           , hr_all_organization_units hou
           , hr_locations_all hl
       WHERE pj.business_group_id != 0
         --AND pj.business_group_id != 5054
         AND hou.organization_id = pj.business_group_id
         AND hl.location_id = hou.location_id
         AND pj.attribute5 != 'Agent'
         AND TRUNC( SYSDATE ) BETWEEN pj.date_from AND NVL( pj.date_to, '31-DEC-4712' ) ;             -- Currently Active
/*      UNION
      -- International Business Group
      SELECT --pj.name ||'.'|| hl.country            ||'|'||                                                          --id
             --pj.name ||'.'|| hl.country            ||'|'||                                                        --name
             pj.name            ||'|'||                                                          --id
             pj.name            ||'|'||                                                        --name

             'TeleTech'                            ||'|'||                                                       --split
             NULL                                  ||'|'||                                                 --description
             pj.attribute6                         ||'|'||                                                     --custom0
             NULL                                  ||'|'||                                                     --custom1
             NULL                                  ||'|'||                                                     --custom2
             NULL                                  ||'|'||                                                     --custom3
             NULL                                  ||'|'||                                                     --custom4
             NULL                                  ||'|'||                                                     --custom5
             NULL                                  ||'|'||                                                     --custom6
             NULL                                  ||'|'||                                                     --custom7
             NULL                                  ||'|'||                                                     --custom8
             --pj.name ||'.'|| hl.country            ||'|'||                                                     --custom9
             pj.name             ||'|'||                                                     --custom9
             pj.attribute5                         ||'|'||                                                  --familiy_id
             TO_CHAR( pj.date_from, 'YYYY-MM-DD' ) ||'|'||                                                   --date from
             TO_CHAR( pj.date_to, 'YYYY-MM-DD' )   AS job                                                     -- date to
        FROM per_jobs pj
           , apps.per_org_structure_versions pvr
           , apps.per_org_structure_elements pose
           , apps.hr_all_organization_units hou
           , apps.hr_locations hl
       WHERE pj.business_group_id = 5054
         AND pj.attribute5 != 'Agent'
         AND TRUNC( SYSDATE ) BETWEEN pj.date_from AND NVL( pj.date_to, '31-DEC-4712' )              -- Currently Active
         AND pvr.business_group_id = pj.business_group_id
         AND (TRUNC(SYSDATE) >= pvr.date_from)
         AND (TRUNC(SYSDATE) <= pvr.date_to OR pvr.date_to IS NULL)
         AND pose.org_structure_version_id = pvr.org_structure_version_id
         AND pose.organization_id_parent = pvr.business_group_id
         AND hou.organization_id = pose.organization_id_child
         AND hl.location_id = hou.location_id
         AND hl.country IS NOT NULL
         AND hl.country NOT IN
               ( SELECT hl1.country
                   FROM hr_all_organization_units hou1
                      , hr_locations hl1
                  WHERE hou1.business_group_id = hou1.organization_id
                    AND hou1.business_group_id != 5054
                    AND hl1.location_id = hou1.location_id );
*/

    CURSOR c_upd_job IS
      SELECT distinct
             --pj.name ||'.'|| hl.country            ||'|'||     /* 1.3 */                                             --id
             --pj.name ||'.'|| hl.country            ||'|'||     /* 1.3 */                                             --name
--             ttec_library.remove_non_ascii (TRIM(TRANSLATE(pj.name,',???~!@#$%^&*()+{}|:"<>?=[]\/"',' ' ))) ||'|'||    --id       /* 1.3 */
--             ttec_library.remove_non_ascii (TRIM(TRANSLATE(pj.name,',???~!@#$%^&*()+{}|:"<>?=[]\/"',' ' ))) ||'|'||    --name    /* 1.3 */
             pj.name                              ||'|'||     /* 1.3 */                                             --id
             pj.name                              ||'|'||     /* 1.3 */                                             --name
             'TeleTech'                            ||'|'||                                                       --split
             NULL                                  ||'|'||                                                 --description
             pj.attribute6                         ||'|'||                                                     --custom0
             NULL                                  ||'|'||                                                     --custom1
             NULL                                  ||'|'||                                                     --custom2
             NULL                                  ||'|'||                                                     --custom3
             NULL                                  ||'|'||                                                     --custom4
             NULL                                  ||'|'||                                                     --custom5
             NULL                                  ||'|'||                                                     --custom6
             NULL                                  ||'|'||                                                     --custom7
             NULL                                  ||'|'||                                                     --custom8
             --pj.name ||'.'|| hl.country            ||'|'||                                                     --custom9
             pj.name             ||'|'||                                                     --custom9
             pj.attribute5                         ||'|'||                                                  --familiy_id
             TO_CHAR( pj.date_from, 'YYYY-MM-DD' ) ||'|'||                                                   --date from
             TO_CHAR( pj.date_to, 'YYYY-MM-DD' )   AS job                                                      -- date to
        FROM per_jobs pj
           , hr_all_organization_units hou
           , hr_locations_all hl
       WHERE pj.business_group_id != 0
         AND pj.business_group_id != 5054
         AND hou.organization_id = pj.business_group_id
         AND hl.location_id = hou.location_id
         AND pj.attribute5 != 'Agent'
         AND (    GREATEST( pj.last_update_date, pj.creation_date ) BETWEEN v_last_run_dt AND SYSDATE       -- Latest changes
               OR pj.date_from BETWEEN v_last_run_dt AND SYSDATE                                      -- 1.1 Include Future Dated starts
               OR pj.date_to   BETWEEN v_last_run_dt AND SYSDATE ) ;                                   -- 1.1 Include Future Dated terms
/*
      UNION
      -- South Africa
      SELECT --pj.name ||'.'|| hl.country            ||'|'||                                                          --id
             --pj.name ||'.'|| hl.country            ||'|'||                                                        --name
             pj.name             ||'|'||                                                          --id
             pj.name             ||'|'||                                                        --name
             'TeleTech'                            ||'|'||                                                       --split
             NULL                                  ||'|'||                                                 --description
             pj.attribute6                         ||'|'||                                                     --custom0
             NULL                                  ||'|'||                                                     --custom1
             NULL                                  ||'|'||                                                     --custom2
             NULL                                  ||'|'||                                                     --custom3
             NULL                                  ||'|'||                                                     --custom4
             NULL                                  ||'|'||                                                     --custom5
             NULL                                  ||'|'||                                                     --custom6
             NULL                                  ||'|'||                                                     --custom7
             NULL                                  ||'|'||                                                     --custom8
             --pj.name ||'.'|| hl.country            ||'|'||                                                     --custom9
             pj.name             ||'|'||                                                     --custom9
             pj.attribute5                         ||'|'||                                                  --familiy_id
             TO_CHAR( pj.date_from, 'YYYY-MM-DD' ) ||'|'||                                                   --date from
             TO_CHAR( pj.date_to, 'YYYY-MM-DD' )   AS job                                                     -- date to
        FROM per_jobs pj
           , apps.per_org_structure_versions pvr
           , apps.per_org_structure_elements pose
           , apps.hr_all_organization_units hou
           , apps.hr_locations hl
       WHERE pj.business_group_id = 5054
         AND pj.attribute5 != 'Agent'
         AND pvr.business_group_id = pj.business_group_id
--         AND (TRUNC(SYSDATE) >= pvr.date_from)
--         AND (TRUNC(SYSDATE) <= pvr.date_to OR pvr.date_to IS NULL)
         AND pose.org_structure_version_id = pvr.org_structure_version_id
         AND pose.organization_id_parent = pvr.business_group_id
         AND hou.organization_id = pose.organization_id_child
         AND hl.location_id = hou.location_id
         AND hl.country IS NOT NULL
         AND hl.country NOT IN
               ( SELECT hl1.country
                   FROM hr_all_organization_units hou1
                      , hr_locations hl1
                  WHERE hou1.business_group_id = hou1.organization_id
                    AND hou1.business_group_id != 5054
                    AND hl1.location_id = hou1.location_id )
         AND (    GREATEST( pj.last_update_date, pj.creation_date ) BETWEEN v_last_run_dt AND SYSDATE       -- Latest changes
               OR pj.date_from BETWEEN v_last_run_dt AND SYSDATE                                      -- 1.1 Include Future Dated starts
               OR pj.date_to   BETWEEN v_last_run_dt AND SYSDATE );                                   -- 1.1 Include Future Dated terms
*/

    CURSOR c_last_run IS
      SELECT MAX( actual_start_date )
        FROM fnd_conc_req_summary_v
       WHERE program_short_name = 'TTEC_SABA_JOB'
         AND phase_code = 'C'
         AND completion_text = 'Normal completion';

  BEGIN

    v_loc := 10;
    g_interface     := 'Saba Job Out';
    v_output_file   := UTL_FILE.fopen( g_directory, v_filename, 'W' );

    FND_FILE.put_line( FND_FILE.OUTPUT
                     ,    'TeleTech Saba Job Outbound Interface  Mode :  '
                       || p_mode
                       || '   Date : '
                       || TO_CHAR( SYSDATE, 'MM/DD/YYYY HH24:MM' ) );
    UTL_FILE.put_line(
                       v_output_file
                   --  , 'Id|name|split|description|custom0|custom1|custom2|custom3|custom4|custom5|custom6|custom7|custom8|custom9|family_id|start_date|end_date' ); /* 1.3 */
                     , 'ID|NAME|DOMAIN|DESCRIPTION|CUSTOM0|CUSTOM1|CUSTOM2|CUSTOM3|CUSTOM4|CUSTOM5|CUSTOM6|CUSTOM7|CUSTOM8|CUSTOM9|JOB_FAMILY|START_DATE|END_DATE' ); /* 1.3 */


    IF p_mode = 'Full File' THEN

      v_loc := 20;
      FOR c1 IN c_job LOOP
        UTL_FILE.put_line( v_output_file, c1.job );
      END LOOP;

    ELSE

      v_loc := 30;
      OPEN c_last_run;
      FETCH c_last_run INTO v_last_run_dt;
      CLOSE c_last_run;

      v_loc := 40;
      IF v_last_run_dt IS NOT NULL THEN

        v_loc := 50;
        FOR c1 IN c_upd_job LOOP
          UTL_FILE.put_line( v_output_file, c1.job );
        END LOOP;

      ELSE

        -- If last run is null then run in full mode
        v_loc := 60;
        FOR c1 IN c_job LOOP
          UTL_FILE.put_line( v_output_file, c1.job );
        END LOOP;

      END IF;

    END IF;

  EXCEPTION
    WHEN OTHERS THEN
      v_err   := SUBSTR( SQLERRM, 1, 50 );
      fnd_file.put_line( fnd_file.output, 'ERR' || v_err );
      UTL_FILE.fclose( v_output_file );

      ttec_error_logging.process_error( g_application_code
                                      , g_interface
                                      , g_package
                                      , v_module
                                      , g_failure_status
                                      , SQLCODE
                                      , SQLERRM
                                      , g_label1
                                      , v_loc
                                      );
  END ttec_job_file;

  /*=================================================================================================*\
     Author: Elango Pandu
       Date: Apr-25-2011
  Call From: 'TeleTech Saba Organization Outbound' concurrent program
       Desc: This procedure extracts HR Organization Hierarchy information to interface to Saba tool
  ====================================================================================================*/
  PROCEDURE ttec_org_file( errbuf       OUT VARCHAR2
                         , retcode      OUT NUMBER
                         , p_mode    IN     VARCHAR2 ) AS

    --v_module   cust.ttec_error_handling.module_name%TYPE := 'ttec_org_file';  --code commented by RXNETHI-ARGANO,17/05/23
    v_module   apps.ttec_error_handling.module_name%TYPE := 'ttec_org_file';    --code added by RXNETHI-ARGANO,17/05/23
    v_loc      NUMBER;

    v_cnt           NUMBER := 0;
    v_last_run_dt   DATE;
    v_err           VARCHAR2( 100 );
    v_root_org_id   NUMBER;

    --v_filename      VARCHAR2( 50 ) := 'organization_' || TO_CHAR( SYSDATE, 'YYYYMMDD_HH24MISS' ) || '.csv'; /* 1.3 */
    v_filename      VARCHAR2( 50 ) := 'int_organization_' || TO_CHAR( SYSDATE, 'YYYYMMDD_HH24MISS' ) || '.csv'; /* 1.3 */
    v_output_file   UTL_FILE.file_type;

    CURSOR c_root_org IS
      SELECT UNIQUE pose.organization_id_parent root_org
        FROM apps.per_organization_structures pos
           , apps.per_org_structure_versions povr
           , apps.per_org_structure_elements pose
       WHERE pos.name = 'Global Hierarchy'
         AND povr.organization_structure_id = pos.organization_structure_id
         AND TRUNC( SYSDATE ) BETWEEN povr.date_from AND NVL( povr.date_to, TRUNC( SYSDATE ) )
         AND pose.org_structure_version_id = povr.org_structure_version_id
         AND NOT EXISTS
               (SELECT 'X'
                  FROM apps.per_org_structure_elements pose2
                 WHERE pose2.org_structure_version_id = povr.org_structure_version_id
                   AND pose2.organization_id_child = pose.organization_id_parent);

    CURSOR c_org_hier IS
          SELECT /*+ NO_CONNECT_BY_FILTERING */
                 LEVEL
               , pose.organization_id_child  ||'|'||                                                               -- id
                 pose.organization_id_child  ||'|'||                                                           -- number
                 'TeleTech'                  ||'|'||                                                   -- domain / split
                 NULL                        ||'|'||                                                       -- contact_id
                 pose.organization_id_parent ||'|'||                                                        -- parent_id
                 NULL                        ||'|'||                                                       -- web_server
                 NULL                        ||'|'||                                                            -- aa_id
                 hou.name||'.'||hl.country   ||'|'||    /* 1.3 */                                            -- name
              --   SUBSTR(ttec_library.remove_non_ascii (TRIM(TRANSLATE(hou.name,',???~!@#$%^&*()+{}|:"<>?=[]\/"',' ' ))),1,47)||'.'||hl.country   ||'|'|| /* 1.3 */                                    -- name
              --   'crncy000000000000167'      ||'|'||  /* 1.3 */                                              -- currency_id
                 'USD'                       ||'|'||   /* 1.3 */                                               -- currency_id
                 NULL                        ||'|'||                                                           -- phone1
                 NULL                        ||'|'||                                                           -- phone2
                 NULL                        ||'|'||                                                              -- fax
                 NULL                        ||'|'||                                                            -- email
                 NULL                        ||'|'||                                                            -- addr1
                 NULL                        ||'|'||                                                            -- addr2
                 NULL                        ||'|'||                                                             -- city
                 NULL                        ||'|'||                                                            -- state
                 NULL                        ||'|'||                                                              -- zip
                 NULL                        ||'|'||                                                          -- country
                 NULL                        ||'|'||                                                          -- custom0
                 NULL                        ||'|'||                                                          -- custom1
                 NULL                        ||'|'||                                                          -- custom2
                 NULL                        ||'|'||                                                          -- custom3
                 NULL                        ||'|'||                                                          -- custom4
                 NULL                        ||'|'||                                                          -- custom5
                 NULL                        ||'|'||                                                          -- custom6
                 NULL                        ||'|'||                                                          -- custom7
                 NULL                        ||'|'||                                                          -- custom8
                 NULL                        ||'|'||                                                          -- custom9
                 pcak.segment3               ||'|'||                                                       -- account_no
                 NULL                        AS org                                                       -- description
            FROM apps.per_organization_structures pos
               , apps.per_org_structure_versions povr
               , apps.per_org_structure_elements pose
               , apps.hr_all_organization_units hou
               , pay_cost_allocation_keyflex pcak
               , apps.hr_all_organization_units bg_org
               , apps.hr_locations_all hl
           WHERE pos.name = 'Global Hierarchy'
             AND povr.organization_structure_id = pos.organization_structure_id
             AND TRUNC( SYSDATE ) BETWEEN povr.date_from AND NVL( povr.date_to, TRUNC( SYSDATE ) )
             AND pose.org_structure_version_id = povr.org_structure_version_id
             AND hou.organization_id = pose.organization_id_child
             AND pcak.cost_allocation_keyflex_id(+) = hou.cost_allocation_keyflex_id
             AND bg_org.organization_id = hou.business_group_id
             AND hl.location_id = bg_org.location_id
          START WITH pose.organization_id_parent = v_root_org_id
          CONNECT BY NOCYCLE PRIOR pose.organization_id_child = pose.organization_id_parent
                     AND pos.name = 'Global Hierarchy'
                     AND TRUNC( SYSDATE ) BETWEEN povr.date_from AND NVL( povr.date_to, TRUNC( SYSDATE ) )
          UNION
          SELECT 0
               , hou.organization_id         ||'|'||                                                               -- id
                 hou.organization_id         ||'|'||                                                           -- number
                 'TeleTech'                  ||'|'||                                                   -- domain / split
                 NULL                        ||'|'||                                                       -- contact_id
                 'root'                      ||'|'||                                                        -- parent_id
                 NULL                        ||'|'||                                                       -- web_server
                 NULL                        ||'|'||                                                            -- aa_id
                 --hou.name||'.'||hl.country   ||'|'||    /* 1.3 */                                            -- name
                 SUBSTR(hou.name,1,47)||'.'||hl.country   ||'|'|| /* 1.3 */                                    -- name              --   'crncy000000000000167'      ||'|'||  /* 1.3 */                                              -- currency_id
                 'USD'                       ||'|'||   /* 1.3 */                                               -- currency_id
                 NULL                        ||'|'||                                                           -- phone1
                 NULL                        ||'|'||                                                           -- phone2
                 NULL                        ||'|'||                                                              -- fax
                 NULL                        ||'|'||                                                            -- email
                 NULL                        ||'|'||                                                            -- addr1
                 NULL                        ||'|'||                                                            -- addr2
                 NULL                        ||'|'||                                                             -- city
                 NULL                        ||'|'||                                                            -- state
                 NULL                        ||'|'||                                                              -- zip
                 NULL                        ||'|'||                                                          -- country
                 NULL                        ||'|'||                                                          -- custom0
                 NULL                        ||'|'||                                                          -- custom1
                 NULL                        ||'|'||                                                          -- custom2
                 NULL                        ||'|'||                                                          -- custom3
                 NULL                        ||'|'||                                                          -- custom4
                 NULL                        ||'|'||                                                          -- custom5
                 NULL                        ||'|'||                                                          -- custom6
                 NULL                        ||'|'||                                                          -- custom7
                 NULL                        ||'|'||                                                          -- custom8
                 NULL                        ||'|'||                                                          -- custom9
                 pcak.segment3               ||'|'||                                                       -- account_no
                 NULL                        AS org                                                       -- description
            FROM apps.hr_all_organization_units hou
               , pay_cost_allocation_keyflex pcak
               , apps.hr_all_organization_units bg_org
               , apps.hr_locations_all hl
           WHERE --hou.organization_id = v_root_org_id /* 1.3 */
                 pcak.cost_allocation_keyflex_id(+) = hou.cost_allocation_keyflex_id
             AND bg_org.organization_id = hou.business_group_id
             AND hl.location_id = bg_org.location_id
          ORDER BY 1;

    CURSOR c_upd_org_hier IS
          SELECT                                                                          /*+ NO_CONNECT_BY_FILTERING */
                LEVEL
               , pose.organization_id_child  ||'|'||                                                               -- id
                 pose.organization_id_child  ||'|'||                                                           -- number
                 'TeleTech'                  ||'|'||                                                   -- domain / split
                 NULL                        ||'|'||                                                       -- contact_id
                 pose.organization_id_parent ||'|'||                                                        -- parent_id
                 NULL                        ||'|'||                                                       -- web_server
                 NULL                        ||'|'||                                                            -- aa_id
         --hou.name||'.'||hl.country   ||'|'||    /* 1.3 */                                            -- name
                 SUBSTR(hou.name,1,47)||'.'||hl.country   ||'|'|| /* 1.3 */                                    -- name
                      --   'crncy000000000000167'      ||'|'||  /* 1.3 */                                              -- currency_id
                 'USD'                       ||'|'||   /* 1.3 */                                               -- currency_id
                 NULL                        ||'|'||                                                           -- phone1
                 NULL                        ||'|'||                                                           -- phone2
                 NULL                        ||'|'||                                                              -- fax
                 NULL                        ||'|'||                                                            -- email
                 NULL                        ||'|'||                                                            -- addr1
                 NULL                        ||'|'||                                                            -- addr2
                 NULL                        ||'|'||                                                             -- city
                 NULL                        ||'|'||                                                            -- state
                 NULL                        ||'|'||                                                              -- zip
                 NULL                        ||'|'||                                                          -- country
                 NULL                        ||'|'||                                                          -- custom0
                 NULL                        ||'|'||                                                          -- custom1
                 NULL                        ||'|'||                                                          -- custom2
                 NULL                        ||'|'||                                                          -- custom3
                 NULL                        ||'|'||                                                          -- custom4
                 NULL                        ||'|'||                                                          -- custom5
                 NULL                        ||'|'||                                                          -- custom6
                 NULL                        ||'|'||                                                          -- custom7
                 NULL                        ||'|'||                                                          -- custom8
                 NULL                        ||'|'||                                                          -- custom9
                 pcak.segment3               ||'|'||                                                       -- account_no
                 NULL                        AS org                                                       -- description
            FROM apps.per_organization_structures pos
               , apps.per_org_structure_versions povr
               , apps.per_org_structure_elements pose
               , apps.hr_all_organization_units hou
               , pay_cost_allocation_keyflex pcak
               , apps.hr_all_organization_units bg_org
               , apps.hr_locations_all hl
           WHERE pos.name = 'Global Hierarchy'
             AND povr.organization_structure_id = pos.organization_structure_id
             AND TRUNC( SYSDATE ) BETWEEN povr.date_from AND NVL( povr.date_to, TRUNC( SYSDATE ) )
             AND pose.org_structure_version_id = povr.org_structure_version_id
             AND hou.organization_id = pose.organization_id_child
             AND pcak.cost_allocation_keyflex_id(+) = hou.cost_allocation_keyflex_id
             AND bg_org.organization_id = hou.business_group_id
             AND hl.location_id = bg_org.location_id
             AND (    GREATEST( hou.last_update_date, hou.creation_date ) BETWEEN v_last_run_dt AND SYSDATE
                   OR GREATEST( pose.last_update_date, pose.creation_date ) BETWEEN v_last_run_dt AND SYSDATE
                   OR GREATEST( pcak.last_update_date, pcak.creation_date ) BETWEEN v_last_run_dt AND SYSDATE
                   OR hou.date_from BETWEEN v_last_run_dt AND SYSDATE                                      -- 1.1 Include Future Dated starts
                   OR hou.date_to   BETWEEN v_last_run_dt AND SYSDATE )                                    -- 1.1 Include Future Dated terms
          START WITH pose.organization_id_parent = v_root_org_id
          CONNECT BY NOCYCLE PRIOR pose.organization_id_child = pose.organization_id_parent
                     AND pos.name = 'Global Hierarchy'
                     AND TRUNC( SYSDATE ) BETWEEN povr.date_from AND NVL( povr.date_to, TRUNC( SYSDATE ) )
          UNION
          SELECT 0
               , hou.organization_id         ||'|'||                                                               -- id
                 hou.organization_id         ||'|'||                                                           -- number
                 'TeleTech'                  ||'|'||                                                   -- domain / split
                 NULL                        ||'|'||                                                       -- contact_id
                 'root'                      ||'|'||                                                        -- parent_id
                 NULL                        ||'|'||                                                       -- web_server
                 NULL                        ||'|'||                                                            -- aa_id
                 --hou.name||'.'||hl.country   ||'|'||    /* 1.3 */                                            -- name
                 SUBSTR(hou.name,1,47)||'.'||hl.country   ||'|'|| /* 1.3 */                                    -- name              --   'crncy000000000000167'      ||'|'||  /* 1.3 */                                              -- currency_id
                 'USD'                       ||'|'||   /* 1.3 */                                               -- currency_id
                 NULL                        ||'|'||                                                           -- phone1
                 NULL                        ||'|'||                                                           -- phone2
                 NULL                        ||'|'||                                                              -- fax
                 NULL                        ||'|'||                                                            -- email
                 NULL                        ||'|'||                                                            -- addr1
                 NULL                        ||'|'||                                                            -- addr2
                 NULL                        ||'|'||                                                             -- city
                 NULL                        ||'|'||                                                            -- state
                 NULL                        ||'|'||                                                              -- zip
                 NULL                        ||'|'||                                                          -- country
                 NULL                        ||'|'||                                                          -- custom0
                 NULL                        ||'|'||                                                          -- custom1
                 NULL                        ||'|'||                                                          -- custom2
                 NULL                        ||'|'||                                                          -- custom3
                 NULL                        ||'|'||                                                          -- custom4
                 NULL                        ||'|'||                                                          -- custom5
                 NULL                        ||'|'||                                                          -- custom6
                 NULL                        ||'|'||                                                          -- custom7
                 NULL                        ||'|'||                                                          -- custom8
                 NULL                        ||'|'||                                                          -- custom9
                 pcak.segment3               ||'|'||                                                       -- account_no
                 NULL                        AS org                                                       -- description
            FROM apps.hr_all_organization_units hou
               , pay_cost_allocation_keyflex pcak
               , apps.hr_all_organization_units bg_org
               , apps.hr_locations_all hl
           WHERE hou.organization_id = v_root_org_id
             AND pcak.cost_allocation_keyflex_id(+) = hou.cost_allocation_keyflex_id
             AND bg_org.organization_id = hou.business_group_id
             AND hl.location_id = bg_org.location_id
             AND (    GREATEST( hou.last_update_date, hou.creation_date ) BETWEEN v_last_run_dt AND SYSDATE
                   OR GREATEST( pcak.last_update_date, pcak.creation_date ) BETWEEN v_last_run_dt AND SYSDATE
                   OR hou.date_from BETWEEN v_last_run_dt AND SYSDATE                                      -- 1.1 Include Future Dated starts
                   OR hou.date_to   BETWEEN v_last_run_dt AND SYSDATE )                                    -- 1.1 Include Future Dated terms
          ORDER BY 1;

    CURSOR c_last_run IS
      SELECT MAX( actual_start_date )
        FROM fnd_conc_req_summary_v
       WHERE program_short_name = 'TTEC_SABA_ORG'
         AND phase_code = 'C'
         AND completion_text = 'Normal completion';
  BEGIN

    v_loc := 10;
    g_interface     := 'Saba Org Out';
    v_output_file   := UTL_FILE.fopen( g_directory, v_filename, 'W' );

    FND_FILE.put_line( FND_FILE.OUTPUT
                     ,    'TeleTech Saba Organization Outbound Interface  Mode :  '
                       || p_mode
                       || '   Date : '
                       || TO_CHAR( SYSDATE, 'MM/DD/YYYY HH24:MM' ) );
    UTL_FILE.put_line(
                       v_output_file
                  --   , 'Id|Number|split|contact_id|parent_id|web_server|aa_id|name|currency_id|phone1|phone2|fax|email|addr1|addr2|city|state|zip|country|custom0|custom1|custom2|custom3|custom4|custom5|custom6|custom7|custom8|custom9|account_no|description' ); /* 1.3 */
                     , 'ID|NAME|SPLIT|CONTACT|PARENT_ORG|WEB_SERVER|SECONDARY_CONTACT|NAME2|DEFAULT_CURRENCY|PHONE1|PHONE2|FAX|EMAIL|ADDR1|ADDR2|CITY|STATE|ZIP|COUNTRY|CUSTOM0|CUSTOM1|CUSTOM2|CUSTOM3|CUSTOM4|CUSTOM5|CUSTOM6|CUSTOM7|CUSTOM8|CUSTOM9|ACCOUNT_NO|DESCRIPTION' ); /* 1.3 */


    -- Get Root Org for 'Global Hierarchy'
    v_loc := 20;
    OPEN c_root_org;
    FETCH c_root_org INTO v_root_org_id;
    CLOSE c_root_org;

    IF p_mode = 'Full File' THEN

      v_loc := 30;
      FOR c1 IN c_org_hier LOOP
        UTL_FILE.put_line( v_output_file, c1.org );
      END LOOP;

    ELSE

      v_loc := 40;
      OPEN c_last_run;
      FETCH c_last_run INTO v_last_run_dt;
      CLOSE c_last_run;

      v_loc := 50;
      IF v_last_run_dt IS NOT NULL THEN

        v_loc := 60;
        FOR c1 IN c_upd_org_hier LOOP
          UTL_FILE.put_line( v_output_file, c1.org );
        END LOOP;

      ELSE

        -- If last run is null then run in full mode
        v_loc := 70;
        FOR c1 IN c_org_hier LOOP
          UTL_FILE.put_line( v_output_file, c1.org );
        END LOOP;

      END IF;

    END IF;

  EXCEPTION
    WHEN OTHERS THEN
      v_err   := SUBSTR( SQLERRM, 1, 50 );
      fnd_file.put_line( fnd_file.output, 'ERR' || v_err );
      UTL_FILE.fclose( v_output_file );

      ttec_error_logging.process_error( g_application_code
                                      , g_interface
                                      , g_package
                                      , v_module
                                      , g_failure_status
                                      , SQLCODE
                                      , SQLERRM
                                      , g_label1
                                      , v_loc
                                      );
  END ttec_org_file;

END ttec_saba_outbound;
/
show errors;
/