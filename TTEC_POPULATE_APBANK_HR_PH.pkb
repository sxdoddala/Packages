create or replace PACKAGE BODY      ttec_populate_apbank_hr_ph
AS
--************************************************************************************--
--*                                                                                  *--
--*     Program Name: TTEC_POPULATE_APBANK_HR_PH                                          *--
--*                                                                                  *--
--*     Description:  Update AP Vendor Banking information from HR
--*                   employee bank info.
--*                   Update those vendors that are employees only
--*                                                                                  *--
--*                                                                                  *--
--*     Input/Output Parameters:                                                     *--
--*                                                                                  *--
--*     Tables Accessed:                                                             *--
--*                                                                                  *--
--*     Tables Modified:              po_vendor_sites_all directly
--*                             others through         API                           *--
--*
--*     Procedures Called:                                                           *--
--*                                                                                  *--
--*                                                                                  *--
--*                                                                                  *--
--*Created By: Wasim Manasfi                                                         *--
--*Date: 06/02/2006                                                                  *--
--*
--*                                                                                  *--
--*Modification Log:                                                                 *--
---*Developer     version        Date        Description                             *--
--*---------     --------     ----        -----------                                 *--
--*										      *--
--*Wasim Manasfi   1.0        06/02/2006  Created                                     *--
--*Kaushik         1.1        07/11/2013  Rewrite as per R12 standard - TTSD R 2583481 *--
-- *Chchan         2.0        09/17/2018  Adding Banco de Oro for MOTIF PHILIPPINES
-- RXNETHI-ARGANO  1.0        11/MAY/2023 R12.2 Upgrade Remediation
--************************************************************************************--
-- Filehandle Variables
   PROCEDURE populate_ap_banks (
      errcode               VARCHAR2,
      errbuff               VARCHAR2,
      v_business_group_id   NUMBER,
      v_date_trans          VARCHAR2,
      v_date_trans2         VARCHAR2
   )
   IS
      --l_error_message               cust.ttec_error_handling.error_message%TYPE; --code commented by RXNETHI-ARGANO,11/05/23
	  l_error_message               apps.ttec_error_handling.error_message%TYPE; --code added by RXNETHI-ARGANO,11/05/23

      CURSOR c_vendors
      IS
         SELECT   loc.ATTRIBUTE7 payroll,/* 2.0 */
                  emp.full_name, emp.employee_number, emp.email_address,
                  pv.vendor_name, pv.vendor_id, pv.employee_id, pv.party_id,
                  pvs.party_site_id, asg.set_of_books_id,
                  pv.last_update_date, pv.end_date_active, pvs.org_id,
                  loc.location_code,
                  MAX (pea.external_account_id) external_account_id
             /*
			 START R12.2 Upgrade Remediation
			 code commented by RXNETHI-ARGANO,11/05/23
			 FROM ap.ap_suppliers pv,
                  ap.ap_supplier_sites_all pvs,
                  hr.per_all_people_f emp,
                  hr.per_all_assignments_f asg,
                  hr.hr_locations_all loc,
                  hr.pay_personal_payment_methods_f ppm,
                  hr.pay_external_accounts pea,
                  */
				  --code commented by RXNETHI-ARGANO,11/05/23
		     FROM apps.ap_suppliers pv,
                  apps.ap_supplier_sites_all pvs,
                  apps.per_all_people_f emp,
                  apps.per_all_assignments_f asg,
                  apps.hr_locations_all loc,
                  apps.pay_personal_payment_methods_f ppm,
                  apps.pay_external_accounts pea,
				  --END R12.2 Upgrade Remediation
				  apps.hr_operating_units hou
            WHERE pv.vendor_type_lookup_code = 'EMPLOYEE'
              AND pv.vendor_id = pvs.vendor_id
             -- AND pv.segment1 = '58798'
              --AND emp.employee_number = '2190313' --'2092914'
              AND pv.employee_id = emp.person_id
              AND asg.location_id = loc.location_id
              AND emp.person_id = asg.person_id
              AND emp.business_group_id = v_business_group_id
              AND ppm.amount IS NULL
              --     AND pea.segment2 = 'C'                                   -- v1.3
              AND NVL (ppm.percentage, 100) =
                     (SELECT MAX (NVL (percentage, 100))
                        --FROM hr.pay_personal_payment_methods_f a,  --code commented by RXNETHI-ARGANO,11/05/23
                        --     hr.pay_external_accounts b            --code commented by RXNETHI-ARGANO,11/05/23
						FROM apps.pay_personal_payment_methods_f a,  --code added by RXNETHI-ARGANO,11/05/23
                             apps.pay_external_accounts b            --code addted by RXNETHI-ARGANO,11/05/23
                       WHERE a.assignment_id = ppm.assignment_id
                         AND a.external_account_id = b.external_account_id
                         AND a.amount IS NULL
                         --         AND b.segment2 = 'C'
                         AND TRUNC (SYSDATE) BETWEEN a.effective_start_date
                                                 AND a.effective_end_date)
              AND pea.segment2 IS NOT NULL
              AND pvs.inactive_date IS NULL
              AND hou.organization_id = pvs.org_id
              AND asg.set_of_books_id = hou.set_of_books_id
              AND hou.business_group_id = emp.business_group_id
              AND asg.assignment_id = ppm.assignment_id(+)
              AND ppm.external_account_id = pea.external_account_id(+)
              AND TRUNC (SYSDATE) BETWEEN asg.effective_start_date
                                      AND asg.effective_end_date
              AND TRUNC (SYSDATE) BETWEEN emp.effective_start_date
                                      AND emp.effective_end_date
              AND TRUNC (SYSDATE) BETWEEN ppm.effective_start_date(+) AND ppm.effective_end_date(+)
              AND (   pv.end_date_active IS NULL
                   OR TRUNC (pv.end_date_active) >= TRUNC (SYSDATE)
                  )
              AND (   pea.last_update_date >= TRUNC (SYSDATE) - v_date_trans
                   OR (pv.creation_date >= TRUNC (SYSDATE) - v_date_trans2)
                  )
         GROUP BY loc.ATTRIBUTE7, /* 2.0 */
                  emp.full_name,
                  emp.employee_number,
                  emp.email_address,
                  pv.vendor_name,
                  pv.vendor_id,
                  pv.employee_id,
                  pv.party_id,
                  pvs.party_site_id,
                  asg.set_of_books_id,
                  pv.last_update_date,
                  pv.end_date_active,
                  pvs.org_id,
                  loc.location_code
         ORDER BY emp.employee_number DESC;

      CURSOR c_bnk_dtl (p_external_account_id NUMBER)
      IS
         SELECT ppm.amount, pea.segment1,                         -- bank name
                                         pea.segment2,
                                                      -- Account_number
                                                      pea.segment3,

                -- bank_branch
                pea.segment4,                                   -- branch_code
                             pea.segment5,                     -- Account_type
                                          pea.segment6,        -- Account Name
                                                       pea.segment7,

                -- bank_Number
                pea.segment8, ppm.percentage
           --FROM hr.pay_personal_payment_methods_f ppm,  --code commented by RXNETHI-ARGANO,11/05/23
           --     hr.pay_external_accounts pea            --code commented by RXNETHI-ARGANO,11/05/23
		   FROM apps.pay_personal_payment_methods_f ppm,  --code added by RXNETHI-ARGANO,11/05/23
                apps.pay_external_accounts pea            --code added by RXNETHI-ARGANO,11/05/23
          WHERE ppm.external_account_id = pea.external_account_id
            --AND pea.segment2 = 'C'
            AND pea.external_account_id = p_external_account_id
            AND TRUNC (SYSDATE) BETWEEN ppm.effective_start_date
                                    AND ppm.effective_end_date;

      v_full_name                   per_all_people_f.full_name%TYPE;
      v_vendor_name                 po_vendors.vendor_name%TYPE;
      v_vendor_id                   po_vendors.vendor_id%TYPE;
      v_vendor_site_id              po_vendor_sites_all.vendor_site_id%TYPE;
      v_employee_id                 po_vendors.employee_id%TYPE;
      v_set_of_books_id             po_vendors.set_of_books_id%TYPE;
      v_last_update                 po_vendors.last_update_date%TYPE;
      v_end_date                    po_vendors.end_date_active%TYPE;
      v_org_id                      po_vendor_sites_all.org_id%TYPE;
      v_employee_number             per_all_people_f.employee_number%TYPE;
      v_email_address               per_all_people_f.email_address%TYPE;
      v_location                    hr_locations_all.location_code%TYPE;
      v_amount                      pay_personal_payment_methods_f.amount%TYPE;
      v_bank_name                   pay_external_accounts.segment1%TYPE;
      v_account_type                pay_external_accounts.segment2%TYPE;
      v_account_number              pay_external_accounts.segment3%TYPE;
      v_routing_number              pay_external_accounts.segment4%TYPE;
      v_bank_name_5                 pay_external_accounts.segment5%TYPE;
      v_branch                      pay_external_accounts.segment6%TYPE;
      v_bank_number                 pay_external_accounts.segment7%TYPE;
      v_bank_effective_start_date   pay_personal_payment_methods_f.effective_start_date%TYPE;
      v_bank_effective_end_date     pay_personal_payment_methods_f.effective_end_date%TYPE;
      v_row_id                      VARCHAR2 (250);
      v_bank_account_uses_id        ap_bank_account_uses_all.bank_account_uses_id%TYPE;
      v_bank_branch_id              ap_bank_branches.bank_branch_id%TYPE;
      v_tmp_branch_id               NUMBER;
      l_tmp_bank_account_id         NUMBER;
      l_tmp_bank_account_uses_id    NUMBER;
      end_of_time                   DATE;
      l_update_vendor_record        NUMBER;
      l_update_bank_account_uses    NUMBER;
      l_tmp1                        VARCHAR (250);
      l_tmp2                        VARCHAR (250);
      l_bank_id                     hz_parties.party_id%TYPE;
      l_assignment_attribs          iby_fndcpt_setup_pub.pmtinstrassignment_rec_type;
      l_ext_bank_act_rec            iby_ext_bankacct_pub.extbankacct_rec_type;
      l_bank_account_id             iby_ext_bank_accounts.ext_bank_account_id%TYPE;
      l_branch_id                   hz_parties.party_id%TYPE;
      l_ext_bank_branch_rec         iby_ext_bankacct_pub.extbankbranch_rec_type;
      l_ext_bank_rec                iby_ext_bankacct_pub.extbank_rec_type;
      l_return_status               VARCHAR2 (1000);
      l_msg_count                   NUMBER;
      l_msg_data                    VARCHAR2 (4000);
      l_response_rec                iby_fndcpt_common_pub.result_rec_type;
      payeecontext_rec_type         iby_disbursement_setup_pub.payeecontext_rec_type;
      l_assign_id                   NUMBER;
      l_site_exists                 VARCHAR2 (1)                  DEFAULT NULL;
      l_acct_num                    pay_external_accounts.segment3%TYPE
                                                                  DEFAULT NULL;
      l_ext_payee_id                iby_external_payees_all.ext_payee_id%TYPE
                                                                  DEFAULT NULL;
      l_cnt                         NUMBER                           DEFAULT 0;
      l_version_num                 iby_ext_bank_accounts.object_version_number%TYPE
                                                                  DEFAULT NULL;
      l_curr_bnk_id                 hz_parties.party_id%TYPE      DEFAULT NULL;
      l_curr_brch_id                hz_parties.party_id%TYPE      DEFAULT NULL;
      l_pay_method_code             iby_external_payees_all.default_payment_method_code%TYPE
                                                                  DEFAULT NULL;
      extpayee_tab_type             iby_disbursement_setup_pub.external_payee_tab_type;
      extpayee_id_tab_type          iby_disbursement_setup_pub.ext_payee_id_tab_type;
      extpayee_upd_tab_type         iby_disbursement_setup_pub.ext_payee_update_tab_type;
      l_exclusive_pay_flag          iby_external_payees_all.exclusive_payment_flag%TYPE
                                                                  DEFAULT NULL;
      l_count                       NUMBER                        DEFAULT NULL;
      v_actual_bnk_name             pay_external_accounts.segment1%TYPE;
      v_bnk_branch_name             ce_bank_branches_v.BANK_BRANCH_NAME%TYPE; /* 2.0 */
      v_bnk_branch_type             ce_bank_branches_v.BANK_BRANCH_TYPE%TYPE; /* 2.0 */
      v_bnk_branch_number           ce_bank_branches_v.BRANCH_NUMBER%TYPE; /* 2.0 */
      v_bnk_home_country            ce_bank_branches_v.BANK_HOME_COUNTRY%TYPE; /* 2.0 */
   BEGIN
      l_cnt := 0;
      fnd_file.put_line
         (fnd_file.output,
             'Teletech -  Assign HR Bank Accounts to Vendors For PH Business Group - Report Date:'
          || SYSDATE
         );
      end_of_time := TO_DATE ('31-DEC-4712');

      FOR lvendor IN c_vendors
      LOOP
         FOR l_bnk_dtl IN c_bnk_dtl (lvendor.external_account_id)
         LOOP
            l_version_num := NULL;
            v_full_name := NULL;
            v_vendor_name := NULL;
            v_vendor_id := NULL;
            v_vendor_site_id := NULL;
            v_employee_id := NULL;
            v_set_of_books_id := NULL;
            v_last_update := SYSDATE;
            v_end_date := NULL;
            v_employee_number := NULL;
            v_email_address := NULL;
            v_location := NULL;
            v_amount := NULL;
            v_bank_name := NULL;
            v_account_type := NULL;
            v_account_number := NULL;
            v_routing_number := NULL;
            v_bank_name_5 := NULL;
            v_branch := NULL;
            v_org_id := NULL;
            v_bank_number := NULL;
            l_pay_method_code := NULL;
            v_bank_effective_start_date := SYSDATE;
            v_bank_effective_end_date := end_of_time;
            v_full_name := lvendor.full_name;
            v_vendor_name := lvendor.vendor_name;
            v_vendor_id := lvendor.vendor_id;
            --       v_vendor_site_id := lvendor.vendor_site_id;
            v_employee_id := lvendor.employee_id;
            v_set_of_books_id := lvendor.set_of_books_id;
            v_last_update := lvendor.last_update_date;
            v_end_date := lvendor.end_date_active;
            v_employee_number := lvendor.employee_number;
            v_email_address := lvendor.email_address;
            v_location := lvendor.location_code;
            v_amount := l_bnk_dtl.amount;
            --v_actual_bnk_name := 'BANK OF THE PHILIPPINE ISLANDS'; /* 2.0 */
            /* 2.0  Begin */
            IF lvendor.payroll = 'MOTIF PHILIPPINES' THEN

               v_actual_bnk_name   := 'BANCO DE ORO';
               v_bnk_branch_number := '010530667';
               v_bnk_branch_name   := 'PASEO DE ROXAS';
               v_bnk_branch_type   := 'ABA';
               v_bnk_home_country  := 'PH';

            ELSE

               v_actual_bnk_name   := 'BANK OF THE PHILIPPINE ISLANDS';
               v_bnk_branch_number := '010040018';
               v_bnk_branch_name   := 'TELEPHBRANCH' || '010040018';
               v_bnk_branch_type   := 'OTHER';
               v_bnk_home_country  := 'PH';

            END IF;
            /* 2.0  End */
            v_bank_name := l_bnk_dtl.segment1;
            v_account_type := l_bnk_dtl.segment5;
            v_account_number := l_bnk_dtl.segment2;
            --v_routing_number := NULL;
            --v_bank_name_5 := lvendor.vendor_name;
            v_branch := l_bnk_dtl.segment3;
            --v_bank_number := l_bnk_dtl.segment7;
            v_org_id := lvendor.org_id;
            l_update_vendor_record := 0;
            l_update_bank_account_uses := 0;
            l_bank_id := NULL;
            l_acct_num := NULL;
            l_ext_payee_id := NULL;
            fnd_file.put_line
                            (fnd_file.output,
                                '- - Started processing for employee number '
                             || v_employee_number
                            );

            BEGIN
               l_site_exists := NULL;
               v_vendor_site_id := NULL;

               SELECT 'Y', vendor_site_id
                 INTO l_site_exists, v_vendor_site_id
                 --FROM ap.ap_supplier_sites_all --code commented by RXNETHI-ARGANO,11/05/23
				 FROM apps.ap_supplier_sites_all --code added by RXNETHI-ARGANO,11/05/23
                WHERE vendor_id = v_vendor_id
                  AND vendor_site_code = 'OFFICE'
                  --AND payment_method_lookup_code = 'EFT'
                  AND org_id = v_org_id;

               fnd_file.put_line (fnd_file.output,
                                     'OFFICE SITE CODE EXISTS -'
                                  || v_full_name
                                  || '-'
                                  || v_vendor_site_id
                                 );
            EXCEPTION
               WHEN NO_DATA_FOUND
               THEN
                  l_site_exists := 'N';
                  v_vendor_site_id := NULL;
                  fnd_file.put_line (fnd_file.LOG,
                                        'OFFICE SITE CODE NOT EXISTS -'
                                     || v_full_name
                                     || '-'
                                     || v_vendor_site_id
                                    );
               WHEN OTHERS
               THEN
                  l_site_exists := 'N';
                  v_vendor_site_id := NULL;
                  fnd_file.put_line (fnd_file.LOG,
                                        'OFFICE SITE CODE NOT EXISTS -'
                                     || v_full_name
                                     || '-'
                                     || v_vendor_site_id
                                    );
            END;

            IF (v_vendor_site_id IS NOT NULL OR l_site_exists = 'Y')
            THEN
               fnd_file.put_line (fnd_file.output,
                                  'l_site_exists -' || l_site_exists
                                 );

               BEGIN
                  fnd_file.put_line (fnd_file.output,
                                        'Bank & Branch Checking'
                                     || l_bnk_dtl.segment1
                                     || '-'
                                     || lvendor.vendor_name
                                    );

                  SELECT DISTINCT branch_party_id, bank_number, bank_name,
                                  bank_branch_name, bank_party_id
                             INTO l_branch_id, v_routing_number, v_bank_name,
                                  v_bank_name_5, l_bank_id
                             FROM ce_bank_branches_v
                            WHERE bank_branch_type  = v_bnk_branch_type   /* 2.0 */--''ABA' --'OTHER'
                              AND UPPER (bank_name) = v_actual_bnk_name   /* 2.0 */
                              AND branch_number     = v_bnk_branch_number /* 2.0 */--'010530667' --'010040018'
                              AND bank_home_country = v_bnk_home_country  /* 2.0 */--'PH'
                              AND bank_branch_name  = v_bnk_branch_name   /* 2.0 */--'PASEO DE ROXAS' --'TELEPHBRANCH' || '010040018'
                              --AND bank_number IS NOT NULL /* 2.0 */
                              AND end_date IS NULL
                              AND ROWNUM < 2;

                  fnd_file.put_line (fnd_file.output,
                                        'Bank & Branch Exists'
                                     || l_branch_id
                                     || '-'
                                     || l_bank_id
                                    );
               EXCEPTION
                  WHEN NO_DATA_FOUND
                  THEN
                     BEGIN
                        BEGIN
                           fnd_file.put_line (fnd_file.output,
                                              'Bank Checking'
                                             );

                           SELECT DISTINCT bank_party_id, bank_name,
                                           bank_number
                                      INTO l_bank_id, v_bank_name,
                                           v_routing_number
                                      FROM ce_banks_v
                                     WHERE home_country = 'PH'
                                       AND bank_number IS NOT NULL
                                       AND UPPER (bank_name) =
                                                     UPPER (v_actual_bnk_name)
                                       AND end_date IS NULL;

                           fnd_file.put_line (fnd_file.output,
                                                 'Bank Party ID Exists -'
                                              || l_bank_id
                                             );
                        EXCEPTION
                           WHEN NO_DATA_FOUND
                           THEN
                              BEGIN
                                 /*fnd_file.put_line (fnd_file.output,
                                                    'Creating Bank'
                                                   );*/
                                 mo_global.init ('SQLAP');
                                 mo_global.set_policy_context ('S', v_org_id);
                                 l_ext_bank_rec.bank_name := v_actual_bnk_name;
                                 l_ext_bank_rec.country_code := 'PH';
                                 l_ext_bank_rec.institution_type := 'BANK';
                                 l_ext_bank_rec.bank_number := NULL;
                                 -- l_ext_bank_rec.object_version_number := 1;
                                 iby_ext_bankacct_pub.create_ext_bank
                                          (p_api_version        => 1.0,
                                           p_init_msg_list      => fnd_api.g_true,
                                           p_ext_bank_rec       => l_ext_bank_rec,
                                           x_bank_id            => l_bank_id,
                                           x_return_status      => l_return_status,
                                           x_msg_count          => l_msg_count,
                                           x_msg_data           => l_msg_data,
                                           x_response           => l_response_rec
                                          );
                                 COMMIT;
                                 fnd_file.put_line
                                                 (fnd_file.output,
                                                     'Bank Party ID Created -'
                                                  || l_bank_id
                                                  || '-'
                                                  || l_msg_data
                                                  || '-'
                                                  || l_return_status
                                                 );
                              EXCEPTION
                                 WHEN OTHERS
                                 THEN
                                    fnd_file.put_line
                                       (fnd_file.output,
                                           'Error in IBY_EXT_BANKACCT_PUB.create_ext_bank - Bank Name'
                                        || v_bank_name
                                        || '-'
                                        || SQLERRM
                                       );
                              END;
                           WHEN OTHERS
                           THEN
                              l_bank_id := NULL;
                              fnd_file.put_line
                                 (fnd_file.output,
                                     'Query failed to pull bank name from bank table'
                                  || v_bank_name
                                  || '-'
                                  || SQLERRM
                                 );
                        END;

                        IF l_bank_id IS NOT NULL
                        THEN
                           BEGIN
                              fnd_file.put_line (fnd_file.output,
                                                 'Creating Branch'
                                                );
                              l_ext_bank_branch_rec.bank_party_id := l_bank_id;
                              /* 2.0 Begin */
--                              l_ext_bank_branch_rec.branch_name := 'TELEPHBRANCH' || '010040018';
--                              l_ext_bank_branch_rec.branch_type := 'OTHER';
--                              l_ext_bank_branch_rec.branch_number := '010040018';
                              l_ext_bank_branch_rec.branch_name   := v_bnk_branch_name;
                              l_ext_bank_branch_rec.branch_type   := v_bnk_branch_type;
                              l_ext_bank_branch_rec.branch_number := v_bnk_branch_number;
                              /* 2.0 End */
                              --l_ext_bank_branch_rec.description := 'EMPLOYEE BANK INFO';
                              --new api to create bank branch
                              iby_ext_bankacct_pub.create_ext_bank_branch
                                 (p_api_version              => 1.0,
                                  p_init_msg_list            => fnd_api.g_true,
                                  p_ext_bank_branch_rec      => l_ext_bank_branch_rec,
                                  x_branch_id                => l_branch_id,
                                  x_return_status            => l_return_status,
                                  x_msg_count                => l_msg_count,
                                  x_msg_data                 => l_msg_data,
                                  x_response                 => l_response_rec
                                 );
                              COMMIT;
                              fnd_file.put_line
                                               (fnd_file.output,
                                                   'Branch Party ID Created -'
                                                || l_branch_id
                                                || '-'
                                                || l_msg_data
                                                || '-'
                                                || l_return_status
                                               );
                           EXCEPTION
                              WHEN OTHERS
                              THEN
                                 fnd_file.put_line
                                    (fnd_file.output,
                                        'Error in IBY_EXT_BANKACCT_PUB.create_ext_bank_branch - Branch Name'
                                     || v_bank_name_5
                                     || SQLERRM
                                    );
                           END;
                        END IF;
                     END;
                  WHEN OTHERS
                  THEN
                     l_branch_id := NULL;
                     fnd_file.put_line
                        (fnd_file.output,
                            'query failed pulling branch name from branch table'
                         || v_bank_name_5
                         || SQLERRM
                        );
               END;

               IF l_bank_id IS NOT NULL AND l_branch_id IS NOT NULL
               THEN
                  BEGIN
                     SELECT DISTINCT bank_number, bank_name,
                                     bank_branch_name
                                INTO v_bank_number, v_bank_name,
                                     v_bank_name_5
                                FROM ce_bank_branches_v
                               WHERE bank_party_id = l_bank_id
                                 AND branch_party_id = l_branch_id;

                     fnd_file.put_line
                                  (fnd_file.output,
                                      'Bank & Branch Details are available - '
                                   || v_employee_number
                                   || '-'
                                   || v_vendor_name
                                   || ' Bank Name - '
                                   || v_bank_name
                                   || ' Bank Number - '
                                   || v_bank_number
                                   || ' Branch Name - '
                                   || v_bank_name_5
                                   || ' Account Number - '
                                   || SUBSTR (v_account_number, -4, 4)
                                  );
                  EXCEPTION
                     WHEN NO_DATA_FOUND
                     THEN
                        fnd_file.put_line
                           (fnd_file.output,
                               'No query failed pulling Bank & Branch Information'
                            || l_bank_id
                            || '-'
                            || l_branch_id
                            || '-'
                            || SQLERRM
                           );
                     WHEN TOO_MANY_ROWS
                     THEN
                        fnd_file.put_line
                           (fnd_file.output,
                               'Too query failed pulling Bank & Branch Information'
                            || l_bank_id
                            || '-'
                            || l_branch_id
                            || '-'
                            || SQLERRM
                           );
                     WHEN OTHERS
                     THEN
                        fnd_file.put_line
                           (fnd_file.output,
                               'Others query failed pulling Bank & Branch Information'
                            || l_bank_id
                            || '-'
                            || l_branch_id
                            || '-'
                            || SQLERRM
                           );
                  END;

                  BEGIN
                     l_bank_account_id := NULL;
                     l_version_num := NULL;
                     l_curr_bnk_id := NULL;
                     l_curr_brch_id := NULL;
                     l_count := NULL;

                     -- V 1.3 (start)
                     SELECT DISTINCT COUNT (*)
                                INTO l_count
                                FROM iby_ext_bank_accounts
                               WHERE bank_account_num = l_bnk_dtl.segment2
                                 AND country_code = 'PH';

                     IF l_count > 1
                     THEN
                        SELECT DISTINCT ext_bank_account_id,
                                        object_version_number, bank_id,
                                        branch_id
                                   INTO l_bank_account_id,
                                        l_version_num, l_curr_bnk_id,
                                        l_curr_brch_id
                                   FROM iby_ext_bank_accounts
                                  WHERE bank_account_num = l_bnk_dtl.segment2
                                    AND ext_bank_account_id =
                                           (SELECT MAX (ext_bank_account_id)
                                              FROM iby_ext_bank_accounts
                                             WHERE bank_account_num =
                                                            l_bnk_dtl.segment2
                                               AND country_code = 'PH')
                                    AND country_code = 'PH';

                        fnd_file.put_line (fnd_file.output,
                                              'Getting ACC to be updated -'
                                           || l_bank_account_id
                                           || '-'
                                           || l_count
                                           || '-'
                                           || l_curr_bnk_id
                                           || '-'
                                           || l_curr_brch_id
                                          );
                     ELSIF l_count IN (1, 0)
                     THEN
                        SELECT DISTINCT ext_bank_account_id,
                                        object_version_number, bank_id,
                                        branch_id
                                   INTO l_bank_account_id,
                                        l_version_num, l_curr_bnk_id,
                                        l_curr_brch_id
                                   FROM iby_ext_bank_accounts
                                  WHERE bank_account_num = l_bnk_dtl.segment2
                                    AND country_code = 'PH';

                        fnd_file.put_line (fnd_file.output,
                                              'Getting ACC to be updated -'
                                           || l_bank_account_id
                                           || '-'
                                           || l_count
                                           || '-'
                                           || l_curr_bnk_id
                                           || '-'
                                           || l_curr_brch_id
                                          );
                     END IF;

                     -- V 1.3 (end)
                      --AND bank_id = l_bank_id
                      --AND branch_id = l_branch_id
                      --AND UPPER (bank_account_type) = 'CHECKING'
                      --AND currency_code = 'USD';
                     IF     NVL (l_curr_bnk_id, 0000) <> l_bank_id
                        AND NVL (l_curr_brch_id, 0000) <> l_branch_id
                     THEN
                        l_ext_bank_act_rec.bank_account_id :=
                                                            l_bank_account_id;
                        l_ext_bank_act_rec.acct_owner_party_id :=
                                                             lvendor.party_id;
                        l_ext_bank_act_rec.country_code := 'PH';
                        l_ext_bank_act_rec.branch_id := l_branch_id;
                        l_ext_bank_act_rec.bank_id := l_bank_id;
                        l_ext_bank_act_rec.bank_account_num :=
                                                           l_bnk_dtl.segment2;
                        l_ext_bank_act_rec.currency := 'PHP';
                        --l_ext_bank_act_rec.acct_type := 'CHECKING';
                        l_ext_bank_act_rec.bank_account_name :=
                                                          lvendor.vendor_name;
                        l_ext_bank_act_rec.object_version_number :=
                                                                l_version_num;
                        --new api to update bank  account
                        iby_ext_bankacct_pub.update_ext_bank_acct
                                  (p_api_version            => 1.0,
                                   p_init_msg_list          => fnd_api.g_false,
                                   p_ext_bank_acct_rec      => l_ext_bank_act_rec,
                                   x_return_status          => l_return_status,
                                   x_msg_count              => l_msg_count,
                                   x_msg_data               => l_msg_data,
                                   x_response               => l_response_rec
                                  );
                        COMMIT;
                        fnd_file.put_line (fnd_file.output,
                                              'Updating Bank Account Id -'
                                           || l_bank_account_id
                                           || '-'
                                           || l_return_status
                                           || '-'
                                           || SUBSTR (l_msg_data, 1, 240)
                                          );
                     END IF;
                  EXCEPTION
                     WHEN NO_DATA_FOUND
                     THEN
                        BEGIN
                           l_ext_bank_act_rec.acct_owner_party_id :=
                                                             lvendor.party_id;
                           l_ext_bank_act_rec.country_code := 'PH';
                           l_ext_bank_act_rec.branch_id := l_branch_id;
                           l_ext_bank_act_rec.bank_id := l_bank_id;
                           l_ext_bank_act_rec.bank_account_num :=
                                                             v_account_number;
                           l_ext_bank_act_rec.currency := 'PHP';
                           --l_ext_bank_act_rec.acct_type := 'CHECKING';
                           l_ext_bank_act_rec.bank_account_name :=
                                                          lvendor.vendor_name;
                           --new api to create bank  account
                           iby_ext_bankacct_pub.create_ext_bank_acct
                                  (p_api_version            => 1.0,
                                   p_init_msg_list          => fnd_api.g_false,
                                   p_ext_bank_acct_rec      => l_ext_bank_act_rec,
                                   x_acct_id                => l_bank_account_id,
                                   x_return_status          => l_return_status,
                                   x_msg_count              => l_msg_count,
                                   x_msg_data               => l_msg_data,
                                   x_response               => l_response_rec
                                  );
                           COMMIT;
                           fnd_file.put_line
                              (fnd_file.output,
                                  'Creating Bank Account Id -'
                               || l_bank_account_id
                               || ' - '
                               || v_bank_name
                               || ' Account Number '
                               || v_account_number
                               || ' Message from oracle api for bank account creation '
                               || SUBSTR (l_msg_data, 1, 240)
                              );
                        EXCEPTION
                           WHEN OTHERS
                           THEN
                              fnd_file.put_line
                                 (fnd_file.output,
                                     'Error in IBY_EXT_BANKACCT_PUB.CREATE_EXT_BANK_ACCT - Bank Name -'
                                  || v_bank_name
                                  || ' Account Number - '
                                  || v_account_number
                                  || '-'
                                  || ' Message: '
                                  || SUBSTR (l_msg_data, 1, 240)
                                  || '-'
                                  || SQLERRM
                                 );
                        END;
                     WHEN TOO_MANY_ROWS
                     THEN
                        l_bank_account_id := NULL;
                        fnd_file.put_line
                           (fnd_file.output,
                               'Query pulling too many Accounts info from Bank Account table'
                            || v_account_number
                            || '-'
                            || SQLERRM
                           );
                     WHEN OTHERS
                     THEN
                        l_bank_account_id := NULL;
                        fnd_file.put_line
                           (fnd_file.output,
                               'Query failed pulling Account info from Bank Account table'
                            || v_account_number
                            || '-'
                            || SQLERRM
                           );
                  END;
               END IF;

               IF l_bank_account_id IS NOT NULL
               THEN
                  BEGIN
                     l_ext_payee_id := NULL;
                     l_pay_method_code := NULL;
                     l_exclusive_pay_flag := NULL;

                     SELECT ext_payee_id, default_payment_method_code,
                            exclusive_payment_flag
                       INTO l_ext_payee_id, l_pay_method_code,
                            l_exclusive_pay_flag
                       FROM iby_external_payees_all
                      WHERE payee_party_id = lvendor.party_id
                        AND supplier_site_id = v_vendor_site_id
                        --AND default_payment_method_code = 'EFT'
                        AND org_id = v_org_id;

                     fnd_file.put_line (fnd_file.output,
                                           'l_ext_payee_id -'
                                        || l_ext_payee_id
                                        || '-'
                                        || 'payment_method_code -'
                                        || l_pay_method_code
                                       );
                  EXCEPTION
                     WHEN OTHERS
                     THEN
                        fnd_file.put_line
                           (fnd_file.output,
                               'Supplier site link is broken in iby_external_payees_all table -'
                            || lvendor.party_id
                            || '-'
                            || v_vendor_site_id
                            || '-'
                            || v_org_id
                           );
                  END;

                  IF l_ext_payee_id IS NOT NULL
                  THEN
                     BEGIN
                        -- V 1.3 (start)
                        BEGIN
                           extpayee_tab_type (1).payee_party_id :=
                                                             lvendor.party_id;
                           extpayee_tab_type (1).payment_function :=
                                                              'PAYABLES_DISB';
                           extpayee_tab_type (1).exclusive_pay_flag :=
                                                         l_exclusive_pay_flag;
                           extpayee_tab_type (1).default_pmt_method := 'EFT';
                           extpayee_tab_type (1).remit_advice_delivery_method :=
                                                                      'EMAIL';
                           extpayee_tab_type (1).remit_advice_email :=
                                                              v_email_address;
                           extpayee_tab_type (1).supplier_site_id :=
                                                             v_vendor_site_id;
                           extpayee_tab_type (1).payer_org_id := v_org_id;
                           extpayee_tab_type (1).payer_org_type :=
                                                             'OPERATING_UNIT';
                           extpayee_id_tab_type (1).ext_payee_id :=
                                                               l_ext_payee_id;
                           iby_disbursement_setup_pub.update_external_payee
                              (p_api_version               => 1.0,
                               p_init_msg_list             => fnd_api.g_false,
                               p_ext_payee_tab             => extpayee_tab_type,
                               p_ext_payee_id_tab          => extpayee_id_tab_type,
                               x_return_status             => l_return_status,
                               x_msg_count                 => l_msg_count,
                               x_msg_data                  => l_msg_data,
                               x_ext_payee_status_tab      => extpayee_upd_tab_type
                              );

                           UPDATE iby_external_payees_all
                              SET remit_advice_delivery_method = 'EMAIL'
                            WHERE ext_payee_id = l_ext_payee_id;

                           fnd_file.put_line
                              (fnd_file.output,
                                  'status - '
                               || extpayee_upd_tab_type (1).payee_update_status
                               || '-'
                               || extpayee_upd_tab_type (1).payee_update_msg
                              );
                        EXCEPTION
                           WHEN OTHERS
                           THEN
                              fnd_file.put_line
                                 (fnd_file.output,
                                     'status others- '
                                  || extpayee_upd_tab_type (1).payee_update_status
                                  || '-'
                                  || extpayee_upd_tab_type (1).payee_update_msg
                                 );
                        END;

                        -- V 1.3 (start)
                        BEGIN
                           l_acct_num := NULL;
                           l_tmp_bank_account_uses_id := NULL;

                           SELECT instr_assignment_id, account_number
                             INTO l_tmp_bank_account_uses_id, l_acct_num
                             FROM iby_payee_assigned_bankacct_v
                            WHERE supplier_site_id = v_vendor_site_id
                              AND party_id = lvendor.party_id
                              AND order_of_preference = 1
                              AND org_id = v_org_id
                              AND end_date IS NULL;

                           fnd_file.put_line
                                            (fnd_file.output,
                                                'l_tmp_bank_account_uses_id -'
                                             || l_tmp_bank_account_uses_id
                                            );
                        EXCEPTION
                           WHEN NO_DATA_FOUND
                           THEN
                              l_tmp_bank_account_uses_id := 0;
                           WHEN OTHERS
                           THEN
                              fnd_file.put_line
                                 (fnd_file.output,
                                     'Query record from iby_payee_assigned_bankacct_v view failed -'
                                  || lvendor.party_id
                                  || '-'
                                  || v_vendor_site_id
                                  || '-'
                                  || v_org_id
                                 );
                        END;

                        IF (   l_tmp_bank_account_uses_id = 0
                            OR l_acct_num <> v_account_number
                           )
                        THEN
                           IF (    l_acct_num <> v_account_number
                               AND l_tmp_bank_account_uses_id <> 0
                              )
                           THEN
                              BEGIN
                                 -- new table to update the bank account use info at supplier site level
                                 UPDATE iby_pmt_instr_uses_all
                                    SET end_date = SYSDATE,
                                        last_update_date = SYSDATE,
                                        last_updated_by = fnd_global.user_id,
                                        order_of_preference =
                                                       order_of_preference + 1
                                  WHERE instrument_payment_use_id =
                                                    l_tmp_bank_account_uses_id;
                              EXCEPTION
                                 WHEN OTHERS
                                 THEN
                                    fnd_file.put_line
                                       (fnd_file.output,
                                           'Error in updating table iby_pmt_instr_uses_all - Bank Name'
                                        || v_bank_name
                                        || ' Account Number '
                                        || v_account_number
                                        || 'instrument_payment_use_id '
                                        || TO_CHAR (l_tmp_bank_account_uses_id)
                                        || '-'
                                        || SUBSTR (SQLERRM, 1, 240)
                                       );
                              END;
                           END IF;

                           payeecontext_rec_type.party_id := lvendor.party_id;
                           payeecontext_rec_type.party_site_id :=
                                                         lvendor.party_site_id;
                           payeecontext_rec_type.org_id := lvendor.org_id;
                           payeecontext_rec_type.supplier_site_id :=
                                                              v_vendor_site_id;
                           payeecontext_rec_type.payment_function :=
                                                               'PAYABLES_DISB';
                           payeecontext_rec_type.org_type := 'OPERATING_UNIT';
                           l_assignment_attribs.assignment_id := NULL;
                           l_assignment_attribs.instrument.instrument_type :=
                                                                 'BANKACCOUNT';
                           l_assignment_attribs.instrument.instrument_id :=
                                                             l_bank_account_id;
                           -- l_assignment_attribs.ext_pmt_party_id := l_ext_payee_id;
                           l_assignment_attribs.priority := 1;
                           l_assignment_attribs.start_date := SYSDATE;
                           l_assignment_attribs.end_date := NULL;
                           -- new api to  set bank account use at supplier site level
                           iby_disbursement_setup_pub.set_payee_instr_assignment
                                (p_api_version             => 1.0,
                                 p_init_msg_list           => fnd_api.g_false,
                                 p_commit                  => fnd_api.g_true,
                                 x_return_status           => l_return_status,
                                 x_msg_count               => l_msg_count,
                                 x_msg_data                => l_msg_data,
                                 p_payee                   => payeecontext_rec_type,
                                 p_assignment_attribs      => l_assignment_attribs,
                                 x_assign_id               => l_assign_id,
                                 x_response                => l_response_rec
                                );
                           fnd_file.put_line
                              (fnd_file.output,
                                  v_bank_name
                               || ' Account Number '
                               || v_account_number
                               || 'Bank Account ID - External Payee id'
                               || l_bank_account_id
                               || '-'
                               || l_ext_payee_id
                               || 'l_assign_id'
                               || l_assign_id
                               || ' Message '
                               || SUBSTR (l_msg_data, 1, 240)
                              );
                           COMMIT;
                        END IF;

                        l_cnt := l_cnt + 1;
                     EXCEPTION
                        WHEN OTHERS
                        THEN
                           fnd_file.put_line
                              (fnd_file.output,
                                  'Error in iby_disbursement_setup_pub.Set_Payee_Instr_Assignment - Bank Name'
                               || v_bank_name
                               || ' Account Number '
                               || v_account_number
                               || 'Bank Account ID '
                               || TO_CHAR (l_bank_account_id)
                               || 'l_assign_id -'
                               || l_assign_id
                               || '-'
                               || SUBSTR (l_msg_data, 1, 240)
                              );
                     END;
                  END IF;
               END IF;

               BEGIN
                  SELECT 1
                    INTO l_update_vendor_record
                    FROM iby_payee_assigned_bankacct_v
                   WHERE supplier_site_id = v_vendor_site_id
                     AND party_id = lvendor.party_id
                     AND order_of_preference = 1
                     AND org_id = v_org_id
                     AND account_number = l_acct_num
                     AND end_date IS NULL;
               EXCEPTION
                  WHEN OTHERS
                  THEN
                     l_update_vendor_record := 0;
               END;

               IF l_update_vendor_record = 1
               THEN
                  BEGIN
                     UPDATE ap_supplier_sites_all
                        SET payment_method_lookup_code = 'EFT',
                            email_address = v_email_address,
                            remittance_email = v_email_address
                      WHERE vendor_id = v_vendor_id
                        AND vendor_site_id = v_vendor_site_id;
                  EXCEPTION
                     WHEN OTHERS
                     THEN
                        fnd_file.put_line
                           (fnd_file.output,
                               'Error in updating table po_vendor_sites_all - vendor_id'
                            || v_vendor_id
                            || ' Vendor Site Id - '
                            || v_vendor_site_id
                            || 'Email Address -'
                            || v_email_address
                            || '-'
                            || SQLERRM
                           );
                  END;
               END IF;
            END IF;

            COMMIT;
            fnd_file.put_line
                           (fnd_file.output,
                               '- - Completed processing for employee number '
                            || v_employee_number
                           );
         END LOOP;
      END LOOP;                                        -- lvendor IN c_vendors

      fnd_file.put_line (fnd_file.LOG, 'Successful Count -' || l_cnt);
      COMMIT;
   END populate_ap_banks;
END ttec_populate_apbank_hr_ph;
/
show errors;
/