create or replace PACKAGE BODY      TTEC_HR_HEALTH_AND_FITNESS
IS
    /* $Header: TTEC_HR_HEALTH_AND_FITNESS.pkb 1.0  06/05/12  damolina ship $ */

    /*== START ================================================================================================*\
         Author: Daniel Molina
           Date: 06/05/2012
      Call From: TeleTech HFIT Job Outbound
    Description: This package generates the Health and Fitness report as an output file of the concurrent program

    Modification History:

    Version    Date     Author      Description (Include Ticket#)
    -------  --------  -----------  ------------------------------------------------------------------------------
        1.0  06/05/12  damolina     REQ#1094721 - Initial version.
		1.0  03/MAY/23  RXNETHI-ARGANO  R12.2 Upgrade Remediation.
    \*== END ==================================================================================================*/

    /* Global Variables */
    g_directory VARCHAR2( 100 ) := ttec_library.get_directory('CUST_TOP')||'/data/HFIT/outbound';

    PROCEDURE main (
         errcode                    VARCHAR2
        ,errbuff                    VARCHAR2
        ,p_business_group_id    IN  NUMBER
    )
    IS

    /************************************************************************************************
     *      PROCEDURE main                                                                          *
     *      Description: This is the main procedure to be called directly from the                  *
     *                   Concurrent Manager.                                                        *

     *                   as an output file of the concurrent program.                               *
     *                                                                                              *
     *      Input/Output Parameters:                                                                *
     *                                   IN: p_business_group_id                                    *
     *                                                                                              *
     ************************************************************************************************/

        /** Declare local variables **/
        v_rec                 VARCHAR2 (10000):= NULL;
        v_header              VARCHAR2 (1000) :=   'Unique ID' -- This is the file header, initialized in the declared section because it is a static value
                                                || '|'
                                                || 'First Name'
                                                || '|'
                                                || 'Last Name'
                                                || '|'
                                                || 'Birthdate'
                                                || '|'
                                                || 'Gender'
                                                || '|'
                                                || 'Addr1'
                                                || '|'
                                                || 'Addr2'
                                                || '|'
                                                || 'City'
                                                || '|'
                                                || 'State'
                                                || '|'
                                                || 'Zip'
                                                || '|'
                                                || 'HmPh'
                                                || '|'
                                                || 'WkPh'
                                                || '|'
                                                || 'Email'
                                                || '|'
                                                || 'Location'
                                                || '|'
                                                || 'SSN'
                                                || '|'
                                                || 'Marital Status'
                                                || '|'
                                                || 'Policy Holder SSN'
                                                || '|'
                                                || 'Plan Name'
                                                || '|'
                                                || 'Plan Description'
                                                || '|'
                                                || 'Plan Start Date'
                                                || '|'
                                                || 'Plan End Date'
                                                || '|'
                                                || 'Employee Hire Date'
                                                || '|'
                                                || 'Employee End Date'
                                                || '|'
                                                || 'Relationship Code'
                                                || '|'
                                                || 'Advising/Coaching';

        v_error_step          VARCHAR2 (1000) := 'Step 1: Create header';
        v_as_of_date          DATE;
        v_business_group_id   INT := p_business_group_id;
        v_output_file         UTL_FILE.file_type;
        v_filename            VARCHAR2( 50 ) := 'teletech_eligibility_hfc_' || TO_CHAR( SYSDATE, 'MMDDYYYY' ) || '.txt';

        /** Declare Cursors **/
        CURSOR c_emps
        IS

        /* Formatted on 6/6/2012 2:49:35 PM (QP5 v5.115.810.9015) */
        SELECT papf.employee_number uniqueID,
               papf.first_name firstName,
               papf.last_name lastName,
               TO_CHAR (papf.date_of_birth, 'MM/DD/YYYY') birthdate,
               papf.sex gender,
               pa.address_line1 addr1,
               pa.address_line2 addr2,
               pa.town_or_city city,
               pa.region_2 state,
               pa.postal_code zip,
               CASE
                  WHEN LENGTH (REGEXP_REPLACE (phones.home_phone, '[^0-9]+', '')) > 0
                  THEN
                     SUBSTR (REGEXP_REPLACE (phones.home_phone, '[^0-9]+', ''),0,3)
                     || '-'
                     || SUBSTR (REGEXP_REPLACE (phones.home_phone, '[^0-9]+', ''),4,3)
                     || '-'
                     || SUBSTR (REGEXP_REPLACE (phones.home_phone, '[^0-9]+', ''),7,4)
                  ELSE
                     ''
               END
                  hmPh,
               CASE
                  WHEN LENGTH (REGEXP_REPLACE (phones.work_phone, '[^0-9]+', '')) > 0
                  THEN
                     SUBSTR (REGEXP_REPLACE (phones.work_phone, '[^0-9]+', ''),0,3)
                     || '-'
                     || SUBSTR (REGEXP_REPLACE (phones.work_phone, '[^0-9]+', ''),4,3)
                     || '-'
                     || SUBSTR (REGEXP_REPLACE (phones.work_phone, '[^0-9]+', ''),7,4)
                  ELSE
                     ''
               END
                  wkPh,
               papf.email_address Email,
               loc.location_code Location,
               REPLACE (papf.national_identifier, '-') SSN,
               fnd_sec.meaning MaritalStatus,
               REPLACE (papf.national_identifier, '-') policyHolderSSN,
               bpf.name planName,
               bof_desc.name planDescription,
               TO_CHAR (MAX (bperf.enrt_cvg_strt_dt), 'MM/DD/YYYY') planStartDate,
               TO_CHAR (MAX (bperf.enrt_cvg_thru_dt), 'MM/DD/YYYY') planEndDate,
               TO_CHAR (ppos.date_start, 'MM/DD/YYYY') employeeHireDate,
               TO_CHAR (ppos.actual_termination_date, 'MM/DD/YYYY')employeeEndDate,
               paaf.assignment_type relationshipCode,
               CASE
                  WHEN (   LENGTH (bpf.name) = 0
                        OR bpf.name IS NULL
                        OR bpf.name = 'Waive Medical Ins')
                  THEN
                     'N'
                  ELSE
                     'Y'
               END
                  advisingCoaching
        /*
		START R12.2 Upgrade Remediation
		--code commented by RXNETHI-ARGANO, 03/MAY/2023
		FROM   hr.per_all_people_f papf,
               hr.per_all_assignments_f paaf,
               hr.hr_locations_all loc,
               hr.per_periods_of_service ppos,
               hr.per_addresses pa,*/
		--code added by RXNETHI-ARGANO, 02/MAY/2023	   
		FROM   apps.per_all_people_f papf,
               apps.per_all_assignments_f paaf,
               apps.hr_locations_all loc,
               apps.per_periods_of_service ppos,
               apps.per_addresses pa,
		--END R12.2 Upgrade Remediation
               (  SELECT   pp.parent_id,
                           MAX (
                              CASE WHEN pp.phone_type = 'H1' THEN pp.phone_number END
                           )
                              home_phone,
                           MAX (
                              CASE WHEN pp.phone_type = 'W1' THEN pp.phone_number END
                           )
                              work_phone
                    --FROM   hr.per_phones pp -- code commented by RXNETHI-ARGANO, 02/MAY/2023
					FROM   apps.per_phones pp
                   WHERE   pp.parent_table = 'PER_ALL_PEOPLE_F'
                           AND pp.phone_type IN ('H1', 'W1')
                GROUP BY   pp.parent_id) phones,
               --hr.per_jobs pj, --code commented by RXNETHI-ARGANO, 02/MAY/2023
               apps.per_jobs pj,
			   apps.ben_prtt_enrt_rslt_f bperf,
               apps.ben_pl_typ_f bptf,
               apps.ben_pl_f bpf,
               apps.ben_oipl_f bof,
               apps.ben_opt_f bof_desc,
               (SELECT
                   flv_marital.meaning,
                   flv_marital.lookup_code flv_mar,
                   fsg.security_group_key
                FROM
                   apps.fnd_security_groups fsg,
                   apps.fnd_lookup_values flv_marital
                WHERE fsg.security_group_key = TO_CHAR(v_business_group_id)
                  AND flv_marital.lookup_type(+) = 'MAR_STATUS'
                  AND flv_marital.security_group_id(+) = fsg.security_group_id
                  AND flv_marital.language(+) = USERENV ('LANG')) fnd_sec,
               (SELECT
                   flv_emp_cat.lookup_code flv_cat
                FROM
                   apps.fnd_security_groups fsg,
                   apps.fnd_lookup_values flv_emp_cat
                WHERE fsg.security_group_key = TO_CHAR(v_business_group_id)
                  AND flv_emp_cat.lookup_type(+) = 'EMP_CAT'
                  AND flv_emp_cat.language(+) = USERENV ('LANG')
                  AND flv_emp_cat.enabled_flag(+) = 'Y'
                  AND flv_emp_cat.security_group_id(+) = fsg.security_group_id) fnd_sec2
        WHERE papf.business_group_id = v_business_group_id
          AND TRUNC (SYSDATE) BETWEEN papf.effective_start_date AND  papf.effective_end_date
          AND papf.current_employee_flag = 'Y'
          AND papf.person_id = paaf.person_id
          AND TRUNC (SYSDATE) BETWEEN paaf.effective_start_date AND  paaf.effective_end_date
          AND paaf.primary_flag = 'Y'
          AND paaf.assignment_type = 'E'
          AND paaf.location_id = loc.location_id(+)
          AND paaf.period_of_service_id = ppos.period_of_service_id
          AND papf.person_id = ppos.person_id
          AND paaf.job_id = pj.job_id(+)
          AND papf.person_id = pa.person_id(+)
          AND pa.primary_flag(+) = 'Y'
          AND pa.date_to(+) IS NULL
          AND phones.parent_id(+) = papf.person_id
          AND papf.person_id = bperf.person_id(+)
          AND TRUNC (SYSDATE) BETWEEN bperf.effective_start_date(+) AND  bperf.effective_end_date(+)
          AND TRUNC (SYSDATE) BETWEEN bperf.enrt_cvg_strt_dt(+) AND  bperf.enrt_cvg_thru_dt(+)
          AND bperf.prtt_enrt_rslt_stat_cd(+) IS NULL
          AND bperf.pl_typ_id(+) = 24 -- Type of benefit: Medical
          AND (bperf.sspndd_flag(+) = 'N'
          AND bperf.rplcs_sspndd_rslt_id(+) IS NULL)
          AND bperf.pl_id = bpf.pl_id(+)
          AND TRUNC (SYSDATE) BETWEEN bpf.effective_start_date(+) AND  bpf.effective_end_date(+)
          AND bperf.pl_typ_id = bptf.pl_typ_id(+)
          AND TRUNC (SYSDATE) BETWEEN bptf.effective_start_date(+) AND  bptf.effective_end_date(+)
          AND bperf.oipl_id = bof.oipl_id(+)
          AND bof.opt_id = bof_desc.opt_id(+)
          AND TRUNC (SYSDATE) BETWEEN bof_desc.effective_start_date(+) AND  bof_desc.effective_end_date(+)
          AND fnd_sec.flv_mar(+)   = papf.marital_status
          AND fnd_sec2.flv_cat(+)  = paaf.employment_category
          AND ( (ppos.actual_termination_date >= TRUNC (SYSDATE)) OR (ppos.actual_termination_date IS NULL))
        GROUP BY
              papf.employee_number,
              papf.first_name,
              papf.last_name,
              TO_CHAR (papf.date_of_birth, 'MM/DD/YYYY'),
              papf.sex,
              pa.address_line1,
              pa.address_line2,
              pa.town_or_city,
              pa.region_2,
              pa.postal_code,
              bpf.pl_id,
              papf.email_address,
              loc.location_code,
              papf.national_identifier,
              fnd_sec.meaning,
              papf.national_identifier,
              phones.home_phone,
              phones.work_phone,
              bpf.name,
              bof_desc.name,
              TO_CHAR (ppos.date_start, 'MM/DD/YYYY'),
              TO_CHAR (ppos.actual_termination_date, 'MM/DD/YYYY'),
              paaf.assignment_type;

   BEGIN


      /** Check and Format Dates **/
      v_as_of_date := TRUNC(SYSDATE);

      /** Log header **/
      apps.fnd_file.put_line (fnd_file.log,'TeleTech HR Report Name: TeleTech Health and Fitness report  - As of: '|| TO_CHAR (v_as_of_date, 'MM/DD/YYYY'));

      /** Create header for the output **/
      v_output_file   := UTL_FILE.fopen( g_directory, v_filename, 'W' );

      UTL_FILE.put_line(v_output_file,v_header);

      v_error_step   := 'Step 2: End create header, entering Loop';

      /** Loop Records **/
      FOR r_emp IN c_emps LOOP

         v_error_step   := 'Step 3: Inside Loop';

          v_rec :=
                   r_emp.uniqueID
                || '|'
                || r_emp.firstName
                || '|'
                || r_emp.lastName
                || '|'
                || r_emp.birthdate
                || '|'
                || r_emp.gender
                || '|'
                || r_emp.addr1
                || '|'
                || r_emp.addr2
                || '|'
                || r_emp.city
                || '|'
                || r_emp.state
                || '|'
                || r_emp.zip
                || '|'
                || r_emp.hmPh
                || '|'
                || r_emp.wkPh
                || '|'
                || r_emp.email
                || '|'
                || r_emp.location
                || '|'
                || r_emp.SSN
                || '|'
                || r_emp.maritalStatus
                || '|'
                || r_emp.policyHolderSSN
                || '|'
                || r_emp.planName
                || '|'
                || r_emp.planDescription
                || '|'
                || r_emp.planStartDate
                || '|'
                || r_emp.planEndDate
                || '|'
                || r_emp.employeeHireDate
                || '|'
                || r_emp.employeeEndDate
                || '|'
                || r_emp.relationshipCode
                || '|'
                || r_emp.advisingCoaching;

         UTL_FILE.put_line(v_output_file,v_rec);

      END LOOP;

      UTL_FILE.fclose( v_output_file );

   EXCEPTION
      WHEN OTHERS
      THEN
         fnd_file.put_line (fnd_file.LOG, 'Operation fails on ' || v_error_step);
         UTL_FILE.fclose( v_output_file );

   END main;
END TTEC_HR_HEALTH_AND_FITNESS;
/
show errors;
/