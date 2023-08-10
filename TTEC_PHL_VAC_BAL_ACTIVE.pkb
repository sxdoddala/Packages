create or replace PACKAGE BODY      ttec_phl_vac_bal_active
AS
-- Program Name:   "PHL Monthly Vacation Balance - Active  Employees"
--
-- Description:
-- Input/Output Parameters:
--
--
--
-- Tables Modified:  N/A
--
--
-- Created By:  Wasim Manasfi
-- Date: Jan 10, 2009
--
-- Modification Log:
-- Developer        Date        Description
-- RXNETHI-ARGANO   17/MAY/23   R12.2 Upgrade Remediation
-- ----------       --------    --------------------------------------------------------------------
   PROCEDURE write_file (
      errcode            VARCHAR2,
      errbuff            VARCHAR2,
      p_end_month   IN   DATE
   )
   IS
-- requirement of file on disk was withdrawn, just commented it out
--
-- Filehandle Variables
      p_filedir         VARCHAR2 (200);
      p_filename        VARCHAR2 (50);
      p_country         VARCHAR2 (10);
      v_bank_file       UTL_FILE.file_type;
-- Declare variables
      l_msg             VARCHAR2 (2000);
      l_stage           VARCHAR2 (400);
      l_element         VARCHAR2 (400);
      l_rec             VARCHAR2 (600);
      l_key             VARCHAR2 (400);
      l_title           VARCHAR2 (200)
         := 'PHL  Monthly Vacation Balance - Active Employees - Pay Period End Date: ';
      l_endofmonth      DATE;
      l_tot_rec_count   NUMBER;
      l_seq             NUMBER;
      l_file_seq        NUMBER;
      l_next_file_seq   NUMBER;
      l_test_flag       VARCHAR2 (4);

-- set directory destination for output file
      CURSOR c_directory_path
      IS
         SELECT    '/d01/ora'
                || DECODE (NAME, 'PROD', 'cle', LOWER (NAME))
                || '/'
                || LOWER (NAME)
                || 'appl/teletech/11.5.0/data/BenefitInterface/'
                                                              directory_path,
                   'TTEC_'
                || 'US'
                || '_Terminated_Vac'
                || TO_CHAR (SYSDATE, '_MMDDYYYY')
                || '.out' file_name
           FROM v$database;

-- get requireed info for transmission
      CURSOR c_detail_record_op4
      IS
         /*       Report Name: Finance Report US - Active Employees          *
                               *        Created By: Hern�Albanesi                                    *
                               *          Created date: 16-May-2007                                    *
                               *          Updated By:                                                 *
                               *          Updated Date:                                                *
                               */
         SELECT    "Business Group"
                || '|'
                || "Employee Number"
                || '|'
                || "Employee Full Name"
                || '|'
                || TO_CHAR ("Hire Date", 'DD-MON-YYYY')
                || '|'
                || "Location Code"
                || '|'
                || "Location"
                || '|'
                || "Proportion"
                || '|'
                || "Location Override"
                || '|'
                || "Client"
                || '|'
                || "Department"
                || '|'
                || "Department Override"
                || '|'
                || "Assignment Number"
                || '|'
                || "Assignment Status"
                || '|'
                || "Employment Category" a_out,
                "Payrate", "Salary Basis", "Vacation Hours",
                ROUND ("Payrate" * "Vacation Hours" * NVL ("Proportion", 1),
                       2
                      ) "Vacation Dollars",
                "Rate", "JOB", "End Of Month"
           FROM (SELECT DISTINCT 'PHL' "Business Group",
                                 papf.employee_number "Employee Number",
                                 papf.full_name "Employee Full Name",
                                 ppos.date_start "Hire Date",
                                 loc.location_code "Location Code",
                                 loc.attribute2 "Location",
                                 alloc.proportion "Proportion",
                                 asg_cost.segment1 "Location Override",
                                 asg_cost.segment2 "Client",
                                 i_org.segment3 "Department",
                                 asg_cost.segment3 "Department Override",
                                 paaf.assignment_number "Assignment Number",
                                 past.user_status "Assignment Status",
                                 fnd_asg_cat.meaning "Employment Category",
                                 ROUND
                                    (DECODE (ppb.pay_basis,
                                            'MONTHLY', ppp.proposed_salary_n * 12
                                              / 2088,
                                             ppp.proposed_salary_n
                                            ),
                                     2
                                    ) "Payrate",
                                 ppb.pay_basis "Salary Basis",
                                 (SELECT pai.action_information6
                                    FROM apps.pay_action_information pai
                                   WHERE pai.assignment_id =
                                                            paaf.assignment_id
                                     AND pai.action_information_category =
                                                           'EMPLOYEE ACCRUALS'
                                     AND pai.action_information4 = 'Vacation'
                                     AND pai.effective_date =
                                            (SELECT MAX (pai2.effective_date)
                                               FROM apps.pay_action_information pai2
                                              WHERE pai2.assignment_id =
                                                             pai.assignment_id
                                                AND pai2.action_information_category =
                                                           'EMPLOYEE ACCRUALS'
                                                AND pai2.action_information4 =
                                                                    'Vacation'
                                                AND pai2.effective_date <=
                                                                  l_endofmonth
                                                AND pai.action_context_id =
                                                       (SELECT MAX
                                                                  (pai3.action_context_id
                                                                  )
                                                          FROM apps.pay_action_information pai3
                                                         WHERE pai3.assignment_id =
                                                                  pai.assignment_id
                                                           AND pai3.action_information_category =
                                                                  'EMPLOYEE ACCRUALS'
                                                           AND pai3.action_information4 =
                                                                    'Vacation'
                                                           AND pai3.effective_date <=
                                                                  l_endofmonth
                                                           AND pai.action_information_id =
                                                                  (SELECT MAX
                                                                             (pai4.action_information_id
                                                                             )
                                                                     --esta condici�n fue agregada porque la tabla ten�un registro duplicado
                                                                   FROM   apps.pay_action_information pai4
                                                                    WHERE pai4.assignment_id =
                                                                             pai.assignment_id
                                                                      AND pai4.action_information_category =
                                                                             'EMPLOYEE ACCRUALS'
                                                                      AND pai4.action_information4 =
                                                                             'Vacation'
                                                                      AND pai4.effective_date <=
                                                                             l_endofmonth))))
                                                             "Vacation Hours",
                                 NULL "Vacation Dollars",
                                 l_endofmonth "End Of Month", job.NAME "JOB",
                                 (apps.ttec_get_pto_accrual_rate_phl.ttec_get_accrual_rate_vac
                                                          (paaf.assignment_id,
                                                           l_endofmonth
                                                          )
                                 ) "Rate"
                            FROM per_all_people_f papf,
                                 per_all_assignments_f paaf,
                                 hr_locations_all loc,
                                 per_jobs job,
                                 per_assignment_status_types past,
                                 per_pay_proposals ppp,
                                 per_pay_bases ppb,
                                 per_periods_of_service ppos,
                                 (SELECT   pca1.assignment_id,
                                           pca1.cost_allocation_keyflex_id
                                                   cost_allocation_keyflex_id,
                                           proportion
                                      --FROM hr.pay_cost_allocations_f pca1   --code commented by RXNETHI-ARGANO,17/05/23
                                      FROM apps.pay_cost_allocations_f pca1   --code added by RXNETHI-ARGANO,17/05/23
                                     WHERE pca1.effective_end_date =
                                              (SELECT MAX
                                                         (pca2.effective_end_date
                                                         )
                                                 --FROM hr.pay_cost_allocations_f pca2   --code commented by RXNETHI-ARGANO,17/05/23
                                                 FROM apps.pay_cost_allocations_f pca2   --code added by RXNETHI-ARGANO,17/05/23
                                                WHERE pca2.assignment_id =
                                                            pca1.assignment_id)
                                       AND l_endofmonth
                                              BETWEEN pca1.effective_start_date
                                                  AND pca1.effective_end_date
                                  GROUP BY pca1.assignment_id,
                                           pca1.cost_allocation_keyflex_id,
                                           proportion) alloc,
                                 --hr.pay_cost_allocation_keyflex asg_cost,   --code commented by RXNETHI-ARGANO,17/05/23
                                 apps.pay_cost_allocation_keyflex asg_cost,   --code added by RXNETHI-ARGANO,17/05/23
                                 hr_organization_units org,
                                 --hr.pay_cost_allocation_keyflex i_org,      --code commented by RXNETHI-ARGANO,17/05/23
                                 apps.pay_cost_allocation_keyflex i_org,      --code added by RXNETHI-ARGANO,17/05/23
                                 apps.fnd_lookup_values fnd_asg_cat
                           WHERE papf.effective_end_date =
                                    (SELECT MAX (papf2.effective_end_date)
                                       FROM per_all_people_f papf2
                                      WHERE papf.person_id = papf2.person_id
                                        AND l_endofmonth
                                               BETWEEN papf2.effective_start_date
                                                   AND papf2.effective_end_date)
                             AND papf.person_id = paaf.person_id
                             AND paaf.effective_end_date =
                                    (SELECT MAX (paaf_2.effective_end_date)
                                       FROM per_all_assignments_f paaf_2
                                      WHERE paaf_2.person_id = paaf.person_id
                                        AND l_endofmonth
                                               BETWEEN paaf_2.effective_start_date
                                                   AND paaf_2.effective_end_date)
                             AND paaf.location_id = loc.location_id(+)
                             AND paaf.job_id = job.job_id
                             AND ppp.assignment_id(+) = paaf.assignment_id
                             AND ppp.change_date =
                                    (SELECT MAX (ppp2.change_date)
                                       FROM per_pay_proposals ppp2
                                      WHERE ppp2.assignment_id =
                                                             ppp.assignment_id
                                        AND ppp2.change_date <= l_endofmonth)
                             AND ppb.pay_basis_id(+) = paaf.pay_basis_id
                             AND papf.person_id = ppos.person_id
                             AND paaf.period_of_service_id =
                                                     ppos.period_of_service_id
                             AND alloc.assignment_id(+) = paaf.assignment_id
                             AND alloc.cost_allocation_keyflex_id = asg_cost.cost_allocation_keyflex_id(+)
                             AND paaf.assignment_status_type_id = past.assignment_status_type_id(+)
                             AND papf.business_group_id = 1517
                             AND papf.current_employee_flag = 'Y'
                             AND paaf.assignment_status_type_id = 1
                             AND paaf.organization_id = org.organization_id(+)
                             AND i_org.cost_allocation_keyflex_id(+) =
                                                org.cost_allocation_keyflex_id
                             AND fnd_asg_cat.lookup_code(+) =
                                                      paaf.employment_category
                             AND fnd_asg_cat.LANGUAGE(+) = USERENV ('LANG')
                             AND fnd_asg_cat.lookup_type(+) = 'EMP_CAT'
                             AND fnd_asg_cat.security_group_id(+) =
                                    DECODE (paaf.business_group_id,
                                            1517, 22,
                                            2
                                           ));
   BEGIN
      l_stage := 'c_directory_path';
      l_endofmonth := TO_DATE (SYSDATE, 'DD-MON-YYYY');

      -- Fnd_File.put_line(Fnd_File.LOG, '1');
      OPEN c_directory_path;

      FETCH c_directory_path
       INTO p_filedir, p_filename;

      CLOSE c_directory_path;

      -- Fnd_File.put_line(Fnd_File.LOG, '2');
      -- Fnd_File.put_line(Fnd_File.LOG, '3');
      l_stage := 'c_open_file';
      fnd_file.put_line (fnd_file.LOG, '**********************************');
      -- fnd_file.put_line (fnd_file.LOG,
      --                       'Output file created >>> '
      --                    || p_filedir
      --                    || p_filename
      --                   );
      fnd_file.put_line (fnd_file.LOG, '**********************************');
      -- Fnd_File.put_line(Fnd_File.LOG, '4');

      --
      l_tot_rec_count := 0;
      l_endofmonth := p_end_month;    -- TO_DATE (p_end_month, 'DD-MM-YYYY');
      -- Fnd_File.put_line(Fnd_File.LOG, '5');
      l_rec := l_title || p_end_month;
      apps.fnd_file.put_line (apps.fnd_file.output, l_rec);
      l_rec :=
         'Business Group|Employee Number|Employee Full Name|Hire Date|Location Code|Location|Proportion|Location Override|Client|Department|Department Override|Assignment Number|Assignment Status|Employment Category|Payrate|Salary Basis|Vacation Hours|Vacation Dollars|Accrual Rate per Pay Period|Job|End Of Month';
      -- UTL_FILE.put_line (v_bank_file, l_rec);
      apps.fnd_file.put_line (apps.fnd_file.output, l_rec);

      FOR sel IN c_detail_record_op4
      LOOP
         l_rec :=
               sel.a_out
            || '|'
            || TO_CHAR (sel."Payrate")
            || '|'
            || sel."Salary Basis"
            || '|'
            || TO_CHAR (sel."Vacation Hours")
            || '|'
            || TO_CHAR (sel."Vacation Dollars")
            || '|'
            || TO_CHAR (sel."Rate", '99.9999')
            || '|'
            || TO_CHAR (sel."JOB")
            || '|'
            || sel."End Of Month";
         -- UTL_FILE.put_line (v_bank_file, l_rec);
         apps.fnd_file.put_line (apps.fnd_file.output, l_rec);
         l_tot_rec_count := l_tot_rec_count + 1;
      -- Fnd_File.put_line(Fnd_File.LOG, '8');
      END LOOP;                                                      /* pay */
-------------------------------------------------------------------------------------------------------------------------
      -- UTL_FILE.fclose (v_bank_file);
   -- Fnd_File.put_line(Fnd_File.LOG, '10');
   EXCEPTION
      WHEN UTL_FILE.invalid_operation
      THEN
         -- UTL_FILE.fclose (v_bank_file);
         raise_application_error (-20051,
                                  p_filename || ':  Invalid Operation'
                                 );
         ROLLBACK;
      WHEN UTL_FILE.invalid_filehandle
      THEN
         -- UTL_FILE.fclose (v_bank_file);
         raise_application_error (-20052,
                                  p_filename || ':  Invalid File Handle'
                                 );
         ROLLBACK;
      WHEN UTL_FILE.read_error
      THEN
         -- UTL_FILE.fclose (v_bank_file);
         raise_application_error (-20053, p_filename || ':  Read Error');
         ROLLBACK;
      WHEN UTL_FILE.invalid_path
      THEN
         -- UTL_FILE.fclose (v_bank_file);
         raise_application_error (-20054, p_filedir || ':  Invalid Path');
         ROLLBACK;
      WHEN UTL_FILE.invalid_mode
      THEN
         -- UTL_FILE.fclose (v_bank_file);
         raise_application_error (-20055, p_filename || ':  Invalid Mode');
         ROLLBACK;
      WHEN UTL_FILE.write_error
      THEN
         -- UTL_FILE.fclose (v_bank_file);
         raise_application_error (-20056, p_filename || ':  Write Error');
         ROLLBACK;
      WHEN UTL_FILE.internal_error
      THEN
         -- UTL_FILE.fclose (v_bank_file);
         raise_application_error (-20057, p_filename || ':  Internal Error');
         ROLLBACK;
      WHEN UTL_FILE.invalid_maxlinesize
      THEN
         -- UTL_FILE.fclose (v_bank_file);
         raise_application_error (-20058,
                                  p_filename || ':  Maxlinesize Error'
                                 );
         ROLLBACK;
      WHEN OTHERS
      THEN
         -- UTL_FILE.fclose (v_bank_file);
         DBMS_OUTPUT.put_line ('Operation fails on ' || l_stage);
         l_msg := SQLERRM;
         raise_application_error (-20003, 'Exception OTHER : ' || l_msg);
         ROLLBACK;
   END write_file;
END ttec_phl_vac_bal_active;
/
show errors;
/