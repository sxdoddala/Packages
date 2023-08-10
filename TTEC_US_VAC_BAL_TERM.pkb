create or replace PACKAGE BODY      ttec_us_vac_bal_term
AS
   PROCEDURE write_file (errcode          VARCHAR2,
                         errbuff          VARCHAR2,
                         p_end_month   IN DATE)
   IS
      --  Program to write run vacation balance for termed employees
      --    Wasim Manasfi   June 2007
      -- requirement of file on disk was withdrawn, just commented it out
      --v1.1 Wasim Manasfi   7March2011   removed APPS.TTEC_Get_vacation_accrual_rate.ttec_get_accrual_rate outside of the query
      --v1.2 Hari Varma      20Jan2020    Added State Column
	  --v1.0 RXNETH-ARGANO   16May2023    RXNETH-ARGANO,16/05/23

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
         := 'US Monthly Vacation Balance - Termed Employees - Pay Period End Date: ';
      l_endofmonth      DATE;
      l_tot_rec_count   NUMBER;
      l_seq             NUMBER;
      l_file_seq        NUMBER;
      l_next_file_seq   NUMBER;
      l_test_flag       VARCHAR2 (4);
      l_program         ap_card_programs_all.card_program_name%TYPE;
      l_RATE            NUMBER;                                        -- v1.1

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
                || '.out'
                   file_name
           FROM v$database;

      -- get requireed info for transmission
      CURSOR c_detail_record_op4
      IS
         /*       Report Name: Finance Report US - Active Employees          *
                        *        Created By: Hern?Albanesi                        *
                        *      Created date: 16-May-2007                         *
                        *      Updated By:                                    *
                        *      Updated Date:                                  *
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
                || "Employment Category"
                   a_out,
                "Payrate",
                "Salary Basis",
                "Vacation Hours",
                ROUND ("Payrate" * "Vacation Hours" * NVL ("Proportion", 1),
                       2)
                   "Vacation Dollars",
                "Job",
                -- v 1.1      "Rate",
                "End Of Month",
                "Termination Date",
                "Assignment_id"                                       -- v 1.1
				,"State"                                              -- v 1.2
           FROM (SELECT DISTINCT
                        'US' "Business Group",
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
                        ROUND (
                           DECODE (ppb.pay_basis,
                                   'ANNUAL', ppp.proposed_salary_n / 2080,
                                   ppp.proposed_salary_n),
                           2)
                           "Payrate",
                        ppb.pay_basis "Salary Basis",
                        tt_hr.get_accrual (paaf.assignment_id,
                                           paaf.payroll_id,
                                           papf.business_group_id,
                                           'V',
                                           l_endofmonth)
                           "Vacation Hours",
                        NULL "Vacation Dollars",
                        job.name "Job",
                        --     v 1.1   (APPS.TTEC_Get_vacation_accrual_rate.ttec_get_accrual_rate(paaf.assignment_id, l_endofmonth)*80) "Rate",
                        l_endofmonth "End Of Month",
                        ppos.actual_termination_date "Termination Date",
                        PAAF.ASSIGNMENT_ID "Assignment_id"            -- v 1.1
						,decode ( paypf.payroll_name, 'At Home', pa.region_2, loc.region_2) "State"  -- v 1.2
                   FROM per_all_people_f papf,
                        per_all_assignments_f paaf,
                        hr_locations_all loc,
                        per_jobs job,
                        per_assignment_status_types past,
                        per_pay_proposals ppp,
                        per_pay_bases ppb,
                        per_periods_of_service ppos,
                        (  SELECT pca1.assignment_id,
                                  pca1.cost_allocation_keyflex_id
                                     cost_allocation_keyflex_id,
                                  proportion
                             --FROM hr.pay_cost_allocations_f pca1  --code commented by RXNETH-ARGANO,16/05/23
                             FROM apps.pay_cost_allocations_f pca1  --code added by RXNETH-ARGANO,16/05/23
                            WHERE pca1.effective_end_date =
                                     (SELECT MAX (pca2.effective_end_date)
                                        --FROM hr.pay_cost_allocations_f pca2  --code commented by RXNETH-ARGANO,16/05/23
                                        FROM apps.pay_cost_allocations_f pca2  --code added by RXNETH-ARGANO,16/05/23
                                       WHERE pca2.assignment_id =
                                                pca1.assignment_id)
                         GROUP BY pca1.assignment_id,
                                  pca1.cost_allocation_keyflex_id,
                                  proportion) alloc,
                        --hr.pay_cost_allocation_keyflex asg_cost,  --code commented by RXNETH-ARGANO,16/05/23
                        apps.pay_cost_allocation_keyflex asg_cost,  --code added by RXNETH-ARGANO,16/05/23
                        hr_organization_units org,
                        --hr.pay_cost_allocation_keyflex i_org,    --code commented by RXNETH-ARGANO,16/05/23
                        apps.pay_cost_allocation_keyflex i_org,    --code added by RXNETH-ARGANO,16/05/23
                        apps.fnd_lookup_values fnd_asg_cat,
						/*
						START R12.2 Upgrade Remediation
						code commented by RXNETH-ARGANO,16/05/23
						hr.pay_all_payrolls_f paypf,         -- v 1.2
						hr.per_addresses pa                  -- v 1.2
						*/
                        --code added by RXNETH-ARGANO,16/05/23
						apps.pay_all_payrolls_f paypf,         -- v 1.2
						apps.per_addresses pa                  -- v 1.2
						--END R12.2 Upgrade Remediation
				  WHERE papf.effective_end_date =
                           (SELECT MAX (papf2.effective_end_date)
                              FROM per_all_people_f papf2
                             WHERE papf.person_id = papf2.person_id
                                   AND l_endofmonth BETWEEN papf2.effective_start_date
                                                        AND papf2.effective_end_date)
                        AND papf.person_id = paaf.person_id
                        AND paaf.effective_end_date =
                               (SELECT MAX (paaf_2.effective_end_date)
                                  FROM per_all_assignments_f paaf_2
                                 WHERE paaf_2.person_id = paaf.person_id
                                       AND l_endofmonth BETWEEN paaf_2.effective_start_date
                                                        AND paaf_2.effective_end_date --added by Vaisakh on 06-Jan-2020
                                       /*AND paaf_2.effective_end_date <
                                              l_endofmonth*/                         --commented by Vaisakh on 06-Jan-2020
											  )
                        AND paaf.location_id = loc.location_id(+)
                        AND paaf.job_id = job.JOB_ID
                        AND ppp.assignment_id(+) = paaf.assignment_id
                        AND ppp.change_date =
                               (SELECT MAX (ppp2.change_date)
                                  FROM per_pay_proposals ppp2
                                 WHERE ppp2.assignment_id = ppp.assignment_id
                                       AND ppp2.change_date <= l_endofmonth)
                        AND ppb.pay_basis_id(+) = paaf.pay_basis_id
                        AND papf.person_id = ppos.person_id
                        AND paaf.period_of_service_id =
                               ppos.period_of_service_id
                        AND ppos.actual_termination_date <= l_endofmonth
                        AND alloc.assignment_id(+) = paaf.assignment_id
                        AND alloc.cost_allocation_keyflex_id =
                               asg_cost.cost_allocation_keyflex_id(+)
                        AND paaf.assignment_status_type_id =
                               past.assignment_status_type_id(+)
                        AND papf.business_group_id = 325
                        AND papf.current_employee_flag IS NULL
                        AND paaf.assignment_status_type_id IN (145, 150, 3)
                        AND ppos.final_process_date IS NOT NULL
                        AND paaf.organization_id = org.organization_id(+)
						and paypf.payroll_id=paaf.payroll_id
						and papf.person_id=pa.person_id
						and pa.primary_flag='Y'
						AND l_endofmonth BETWEEN paypf.effective_start_date and paypf.effective_end_date
						AND l_endofmonth BETWEEN pa.date_from AND
                                         NVL(pa.date_to, l_endofmonth)
                        AND i_org.cost_allocation_keyflex_id(+) =
                               org.cost_allocation_keyflex_id
                        AND fnd_asg_cat.lookup_code(+) =
                               paaf.employment_category
                        AND fnd_asg_cat.LANGUAGE(+) = USERENV ('LANG')
                        AND fnd_asg_cat.lookup_type(+) = 'EMP_CAT'
                        AND fnd_asg_cat.security_group_id(+) =
                               DECODE (paaf.business_group_id,
                                       325, 2,
                                       326, 3,
                                       1517, 22,
                                       1631, 23,
                                       1633, 25,
                                       2))
          WHERE "Vacation Dollars" <> 0 OR "Vacation Hours" <> 0;
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
      --  v_bank_file := UTL_FILE.fopen (p_filedir, p_filename, 'w');
      fnd_file.put_line (fnd_file.LOG, '**********************************');
      --   fnd_file.put_line (fnd_file.LOG,
      --                         'Output file created >>> '
      --                      || p_filedir
      --                      || p_filename
      --                     );
      fnd_file.put_line (fnd_file.LOG, '**********************************');
      -- Fnd_File.put_line(Fnd_File.LOG, '4');

      --
      l_tot_rec_count := 0;
      l_endofmonth := p_end_month;     -- TO_DATE (p_end_month, 'DD-MM-YYYY');
      -- Fnd_File.put_line(Fnd_File.LOG, '5');
      l_rec := l_title || p_end_month;
      apps.fnd_file.put_line (apps.fnd_file.output, l_rec);
      l_rec :=
         'Business Group|Employee Number|Employee Full Name|Hire Date|Location Code|Location|Proportion|Location Override|Client|Department|Department Override|Assignment Number|Assignment Status|Employment Category|Payrate|Salary Basis|Vacation Hours|Vacation Dollars|Accrual Rate per Pay Period|Job|End Of Month|Termination Date|State';
      --     UTL_FILE.put_line (v_bank_file, l_rec);
      apps.fnd_file.put_line (apps.fnd_file.output, l_rec);

      FOR sel IN c_detail_record_op4
      LOOP
         BEGIN
            l_RATE :=
               APPS.TTEC_Get_vacation_accrual_rate.ttec_get_accrual_rate (
                  sel."Assignment_id",
                  l_endofmonth)
               * 80;
         EXCEPTION
            WHEN OTHERS
            THEN
               L_RATE := 0;
               APPS.FND_FILE.PUT_LINE (
                  APPS.FND_FILE.LOG,
                  'Errored in getting rate for Assignment '
                  || TO_CHAR (SEL."Assignment_id"));
         END;

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
            || TO_CHAR (l_rate, '99.9999')
            || '|'
            || TO_CHAR (sel."Job")
            || '|'
            || sel."End Of Month"
            || '|'
            || TO_CHAR (sel."Termination Date", 'DD-MON-YYYY')
			|| '|'
			|| sel."State";

         --      UTL_FILE.put_line (v_bank_file, l_rec);
         apps.fnd_file.put_line (apps.fnd_file.output, l_rec);
         l_tot_rec_count := l_tot_rec_count + 1;
      -- Fnd_File.put_line(Fnd_File.LOG, '8');
      END LOOP;                                                      /* pay */
   -------------------------------------------------------------------------------------------------------------------------
   --   UTL_FILE.fclose (v_bank_file);
   -- Fnd_File.put_line(Fnd_File.LOG, '10');
   EXCEPTION
      WHEN UTL_FILE.invalid_operation
      THEN
         --    UTL_FILE.fclose (v_bank_file);
         raise_application_error (-20051,
                                  p_filename || ':  Invalid Operation');
         ROLLBACK;
      WHEN UTL_FILE.invalid_filehandle
      THEN
         --    UTL_FILE.fclose (v_bank_file);
         raise_application_error (-20052,
                                  p_filename || ':  Invalid File Handle');
         ROLLBACK;
      WHEN UTL_FILE.read_error
      THEN
         --  UTL_FILE.fclose (v_bank_file);
         raise_application_error (-20053, p_filename || ':  Read Error');
         ROLLBACK;
      WHEN UTL_FILE.invalid_path
      THEN
         --    UTL_FILE.fclose (v_bank_file);
         raise_application_error (-20054, p_filedir || ':  Invalid Path');
         ROLLBACK;
      WHEN UTL_FILE.invalid_mode
      THEN
         -- UTL_FILE.fclose (v_bank_file);
         raise_application_error (-20055, p_filename || ':  Invalid Mode');
         ROLLBACK;
      WHEN UTL_FILE.write_error
      THEN
         --   UTL_FILE.fclose (v_bank_file);
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
                                  p_filename || ':  Maxlinesize Error');
         ROLLBACK;
      WHEN OTHERS
      THEN
         -- UTL_FILE.fclose (v_bank_file);
         DBMS_OUTPUT.put_line ('Operation fails on ' || l_stage);
         l_msg := SQLERRM;
         raise_application_error (-20003,
                                  'Exception OTHERS Error: ' || l_msg);
         ROLLBACK;
   END write_file;
END ttec_us_vac_bal_term;
/
show errors;
/
