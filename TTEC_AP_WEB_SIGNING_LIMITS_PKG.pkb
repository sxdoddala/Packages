set define off;
create or replace PACKAGE BODY      ttec_ap_web_signing_limits_pkg
AS
/* $Header: ttec_ap_web_signing_limits.pkb 1.0 2008/08/01 kbabu $ */
/*== START ================================================================================================*\
  Author:  Kaushik Babu
    Date:  August 01, 2009
    Desc:  This package is for the purpose of creating the Payable Signing Table based
           on the parameter set of books.
  Modification History:

 Mod#  Person         Date     Comments
---------------------------------------------------------------------------
 1.0  Kaushik Babu  01-AUG-08 Created package
 1.1  Kaushik Babu  09-SEP-08 Selected only active manager information before updating signing limits table,
                              Added code to get 1 million for person having actual job name 'Vice Chairman'
                              Fixed code to provide 100k for person having job name 'Operating Committee Mem'
 1.2  Kaushik Babu  22-OCT-08 Before inserting approval amount into table convert the currency value based
                              on business group & local currency from gl_daily_rates table
 1.3  Kaushik Babu  13-NOV-08  Rounded the signing amount value in exchange_value function
 1.4  Kaushik Babu  08-JAN-10 Added logic to get the counts before & after on AP_SIGNING_LIMITS_TABLE
 			      Added logic to provide more errors on the log file.
				  Added few parameter to identify from which responsibility the process is run.
1.0	IXPRAVEEN(ARGANO)  12-May-2023		R12.2 Upgrade Remediation				  
\*== END ==================================================================================================*/
   FUNCTION exchange_value (p_value IN NUMBER, p_to_currency IN VARCHAR2)
      RETURN NUMBER
   IS
      l_value   NUMBER := 0;
   BEGIN
      SELECT   ROUND (p_value * conversion_rate)
          INTO l_value
          --FROM gl.gl_daily_rates			-- Commented code by IXPRAVEEN-ARGANO,12-May-2023
          FROM apps.gl_daily_rates            --  code Added by IXPRAVEEN-ARGANO,   12-May-2023
         WHERE from_currency = 'USD'
           AND to_currency = p_to_currency
           AND conversion_type LIKE 'Spot'
           AND conversion_date = TRUNC (SYSDATE)
      ORDER BY conversion_date DESC;

      RETURN l_value;
   EXCEPTION
      WHEN NO_DATA_FOUND
      THEN
         BEGIN
            SELECT   ROUND (p_value * conversion_rate)
                INTO l_value
                --FROM gl.gl_daily_rates			-- Commented code by IXPRAVEEN-ARGANO,12-May-2023
                FROM apps.gl_daily_rates              --  code Added by IXPRAVEEN-ARGANO,   12-May-2023
               WHERE from_currency = 'USD'
                 AND to_currency = p_to_currency
                 AND conversion_type LIKE 'Spot'
                 AND conversion_date =
                        (SELECT MAX (conversion_date)
                           --FROM gl.gl_daily_rates				-- Commented code by IXPRAVEEN-ARGANO,12-May-2023
                           FROM apps.gl_daily_rates               --  code Added by IXPRAVEEN-ARGANO,   12-May-2023
                          WHERE from_currency = 'USD'
                            AND to_currency = p_to_currency
                            AND conversion_type LIKE 'Spot')
            ORDER BY conversion_date DESC;

            RETURN l_value;
         EXCEPTION
            WHEN OTHERS
            THEN
               RETURN NULL;
         END;
      WHEN OTHERS
      THEN
         RETURN NULL;
   END;
--Version 1.4 <Start>
   PROCEDURE main_proc (
      p_errbuf      IN   VARCHAR2,
      p_errcode     IN   NUMBER,
      p_org_id      IN   NUMBER DEFAULT NULL,
      p_sob_id      IN   NUMBER DEFAULT NULL,
      p_resp_name   IN   VARCHAR2
   )
   IS
      l_value            NUMBER          DEFAULT NULL;
      l_valid            NUMBER          DEFAULT NULL;
      l_signing_amount   NUMBER;
      l_row_id           VARCHAR2 (100);
      l_error_msg        VARCHAR2 (1000) DEFAULT NULL;
      l_flag             VARCHAR2 (100)  DEFAULT NULL;

      CURSOR get_manager_info
      IS
         SELECT DISTINCT papfm.employee_number manager_number,
                         papfm.person_id manager_id,
                         INITCAP (papfm.full_name) manager,
                         pjm.attribute6 job_name, pjm.NAME actual_job_name,
                         pjm.NAME job_actual_name, gsobe.NAME set_of_books,
                         ppte.system_person_type, gcce.segment3 cost_center,
                         gsobe.currency_code,
                         papfm.email_address manager_email_address,
                         p_org_id org_id
                    --                  fnd_profile.VALUE ('ORG_ID') org_id
                    --                  papfe.employee_number employee_number,
                    --                  INITCAP (papfe.full_name) employee_name,
                    --                  papfe.email_address,
         FROM            per_all_people_f papfe,
                         per_all_assignments_f paafe,
                         per_person_types ppte,
                         gl_code_combinations gcce,
                         per_all_assignments_f paafm,
                         per_all_people_f papfm,
                         per_jobs pjm,
                         gl_sets_of_books gsobe,
                         hr_all_organization_units haoue
                   WHERE paafe.person_id = papfe.person_id
                     AND papfe.person_type_id = ppte.person_type_id
                     AND ppte.system_person_type LIKE 'EMP%'
                     AND paafe.primary_flag = 'Y'
                     AND papfe.current_employee_flag = 'Y'
                     AND paafe.default_code_comb_id = gcce.code_combination_id(+)
                     AND paafe.business_group_id = haoue.organization_id(+)
                     AND haoue.business_group_id = haoue.organization_id
                     AND paafe.supervisor_id = papfm.person_id(+)
                     AND papfm.person_id = paafm.person_id(+)
                     AND papfm.current_employee_flag = 'Y'
                     AND paafm.job_id = pjm.job_id(+)
                     AND pjm.date_to IS NULL
                     AND paafe.set_of_books_id = gsobe.set_of_books_id(+)
                     AND gsobe.set_of_books_id = p_sob_id
--                                        fnd_profile.VALUE ('GL_SET_OF_BKS_ID')
              --AND PAAFM.PERSON_ID = 300403
                     AND papfe.employee_number <> 3012468
                     AND SYSDATE BETWEEN papfe.effective_start_date
                                     AND papfe.effective_end_date
                     AND SYSDATE BETWEEN paafe.effective_start_date
                                     AND paafe.effective_end_date
                     AND SYSDATE BETWEEN papfm.effective_start_date(+) AND papfm.effective_end_date(+)
                     AND SYSDATE BETWEEN paafm.effective_start_date(+) AND paafm.effective_end_date(+)
                ORDER BY gsobe.NAME, papfm.employee_number DESC;

      CURSOR c_cnt_sign_tab
      IS
         SELECT   COUNT (*) cnt, org_id
             FROM apps.ap_web_signing_limits_all
            WHERE org_id = p_org_id
         GROUP BY org_id
         ORDER BY org_id;
   BEGIN
      FOR c_cnt_sign_rec IN c_cnt_sign_tab
      LOOP
         fnd_file.put_line (fnd_file.output,
                               'COUNTS IN TABLE FOR ORG_ID - '
                            || c_cnt_sign_rec.org_id
                            || ' BEFORE DELETION - '
                            || c_cnt_sign_rec.cnt
                           );
      END LOOP;

      BEGIN
         SELECT 1
           INTO l_value
           FROM apps.hr_operating_units
          WHERE organization_id = p_org_id AND set_of_books_id = p_sob_id;
      EXCEPTION
         WHEN OTHERS
         THEN
            l_error_msg :=
               'THE PROFILES FOR ORG_ID & SOBID ARE NOT SET PROPERLY AT RESP LEVEL - ';
            RAISE;
      END;

      IF l_value IS NOT NULL
      THEN
         DELETE FROM ap_web_signing_limits_all
               WHERE org_id = p_org_id AND document_type LIKE 'APEXP';

         FOR get_manager_ext IN get_manager_info
         LOOP
            BEGIN
               l_flag := NULL;
               l_error_msg := NULL;

               IF get_manager_ext.manager_id IS NULL
               THEN
                  l_flag := l_flag || '100' || '|';
                  l_error_msg :=
                             l_error_msg || 'Manager Information is missing ';
               END IF;

               IF (   get_manager_ext.cost_center IS NULL
                   OR get_manager_ext.cost_center = '000'
                  )
               THEN
                  l_flag := l_flag || '101' || '|';
                  l_error_msg :=
                        l_error_msg
                     || ' | '
                     || 'Cost Center Information is not valid - '
                     || get_manager_ext.cost_center;
               END IF;
		--Version 1.4 <Start>
               --            IF get_manager_ext.email_address IS NULL
               --            THEN
               --               l_flag := l_flag || '102' || '|';
               --               l_error_msg :=
               --                  l_error_msg || ' | ' || 'Employee Email Address is missing';
               --            END IF;
               --Version 1.4 <End>
               IF get_manager_ext.set_of_books IS NULL
               THEN
                  l_flag := l_flag || '103' || '|';
                  l_error_msg :=
                     l_error_msg || ' | '
                     || 'Employee Set of Books is missing';
               END IF;

               IF get_manager_ext.job_name IS NULL
               THEN
                  l_flag := l_flag || '104' || '|';
                  l_error_msg :=
                        l_error_msg
                     || ' | '
                     || 'Manager Job Information is missing';
               END IF;
		--Version 1.4 <Start>
               --            IF get_manager_ext.manager_email_address IS NULL
               --            THEN
               --               l_flag := l_flag || '105' || '|';
               --               l_error_msg :=
               --                     l_error_msg
               --                  || ' | '
               --                  || 'Manager email address is missing for Manager Number'
               --                  || '-'
               --                  || get_manager_ext.manager_number;
               --            END IF;
               --Version 1.4 <End>
               IF l_flag IS NULL
               THEN
                  BEGIN
                     l_value := NULL;

                     SELECT 1
                       INTO l_value
                       FROM ap_web_signing_limits_all
                      WHERE employee_id = get_manager_ext.manager_id
                        AND document_type = 'APEXP'
                        AND cost_center = get_manager_ext.cost_center
                        AND org_id = get_manager_ext.org_id;
                  EXCEPTION
                     WHEN NO_DATA_FOUND
                     THEN
                        IF (   UPPER (get_manager_ext.job_name) LIKE
                                                              UPPER ('%Vice%')
                            OR UPPER (get_manager_ext.job_name) LIKE
                                                     UPPER ('Operating%Comm%')
                           )
                        THEN
                           l_signing_amount :=
                              NVL
                                 (exchange_value
                                                (100000,
                                                 get_manager_ext.currency_code
                                                ),
                                  100000
                                 );
                        ELSIF UPPER (get_manager_ext.job_name) LIKE
                                                          UPPER ('%Director%')
                        THEN
                           l_signing_amount :=
                              NVL
                                 (exchange_value
                                                (25000,
                                                 get_manager_ext.currency_code
                                                ),
                                  25000
                                 );
                        ELSIF    UPPER (get_manager_ext.job_name) LIKE
                                                              UPPER ('Chief%')
                              OR UPPER (get_manager_ext.actual_job_name) LIKE
                                                     UPPER ('%Vice%Chairman%')
                        THEN
                           l_signing_amount :=
                              NVL
                                 (exchange_value
                                                (1000000,
                                                 get_manager_ext.currency_code
                                                ),
                                  1000000
                                 );
                        ELSE
                           l_signing_amount :=
                              NVL
                                 (exchange_value
                                                (10000,
                                                 get_manager_ext.currency_code
                                                ),
                                  10000
                                 );
                        END IF;

                        ap_web_signing_limits_pkg.insert_row
                                (x_rowid                  => l_row_id,
                                 x_document_type          => 'APEXP',
                                 x_employee_id            => get_manager_ext.manager_id,
                                 x_cost_center            => get_manager_ext.cost_center,
                                 x_signing_limit          => l_signing_amount,
                                 x_last_update_date       => SYSDATE,
                                 x_last_updated_by        => fnd_global.user_id,
                                 x_last_update_login      => fnd_global.login_id,
                                 x_creation_date          => SYSDATE,
                                 x_created_by             => fnd_global.user_id,
                                 x_org_id                 => get_manager_ext.org_id
                                );
                     WHEN OTHERS
                     THEN
                        l_flag := l_flag || '106' || '|';
                        l_error_msg :=
                              l_error_msg
                           || ' | '
                           || 'Manager Record Not Created Sucessfully (Signing Limits Table) for Manager Number: '
                           || get_manager_ext.manager_number
                           || '-'
                           || get_manager_ext.cost_center;
                  END;

                  BEGIN
                     l_valid := NULL;

                     SELECT 1
                       INTO l_valid
                       FROM ap_web_signing_limits_all a, per_all_people_f b
                      WHERE a.employee_id = b.person_id
                        AND b.person_id = 121938
                        AND SYSDATE BETWEEN b.effective_start_date
                                        AND b.effective_end_date
                        AND a.document_type = 'APEXP'
                        AND a.cost_center = get_manager_ext.cost_center
                        AND a.org_id = get_manager_ext.org_id;
                  EXCEPTION
                     WHEN NO_DATA_FOUND
                     THEN
                        ap_web_signing_limits_pkg.insert_row
                           (x_rowid                  => l_row_id,
                            x_document_type          => 'APEXP',
                            x_employee_id            => 121938,
                            x_cost_center            => get_manager_ext.cost_center,
                            x_signing_limit          => NVL
                                                           (exchange_value
                                                               (1000000,
                                                                get_manager_ext.currency_code
                                                               ),
                                                            1000000
                                                           ),
                            x_last_update_date       => SYSDATE,
                            x_last_updated_by        => fnd_global.user_id,
                            x_last_update_login      => fnd_global.login_id,
                            x_creation_date          => SYSDATE,
                            x_created_by             => fnd_global.user_id,
                            x_org_id                 => get_manager_ext.org_id
                           );
                     WHEN OTHERS
                     THEN
                        l_flag := l_flag || '107' || '|';
                        l_error_msg :=
                              l_error_msg
                           || ' | '
                           || 'Manager Record Not Created Sucessfully (Signing Limits Table): '
                           || 121938
                           || '-'
                           || get_manager_ext.cost_center;
                  END;
               END IF;

               IF l_flag IS NOT NULL
               THEN
                  fnd_file.put_line
                     (fnd_file.LOG,
                         'One of the Employee having config issue under the Manager - '
                      || get_manager_ext.manager_number
                      || '|'
                      || l_error_msg
                     );
               END IF;
            END;
         END LOOP;

         FOR c_cnt_sign_rec IN c_cnt_sign_tab
         LOOP
            fnd_file.put_line (fnd_file.output,
                                  'COUNTS IN TABLE FOR ORG_ID - '
                               || c_cnt_sign_rec.org_id
                               || ' AFTER PROG RUN SUCCESSFULLY - '
                               || c_cnt_sign_rec.cnt
                              );
         END LOOP;
      END IF;

      COMMIT;
   EXCEPTION
      WHEN OTHERS
      THEN
         ROLLBACK;

         FOR c_cnt_sign_rec IN c_cnt_sign_tab
         LOOP
            fnd_file.put_line (fnd_file.output,
                                  'COUNTS IN TABLE FOR ORG_ID - '
                               || c_cnt_sign_rec.org_id
                               || ' AFTER PROG ERRORED - '
                               || c_cnt_sign_rec.cnt
                              );
         END LOOP;

         raise_application_error (-20101,
                                     l_error_msg
                                  || ' Failed in main_proc '
                                  || SQLERRM
                                 );
   END main_proc;
   --Version 1.4 <End>
END ttec_ap_web_signing_limits_pkg;
/
show errors;
/