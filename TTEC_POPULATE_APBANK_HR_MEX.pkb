create or replace PACKAGE BODY ttec_populate_apbank_hr_mex
AS
--************************************************************************************--
--*                                                                                  *--
--*     Program Name: TTEC_POPULATE_APBANK_HR_MEX                                    *--
--*                                                                                  *--
--*     Description:  Update AP Vendor Banking information from HR                   *--
--*                   employee bank info.                                            *--
--*                   Update those vendors that are employees only                   *--
--*                                                                                  *--
--*                                                                                  *--
--*     Input/Output Parameters:                                                     *--
--*                                                                                  *--
--*     Tables Accessed:                                                             *--
--*                                                                                  *--
--*     Tables Modified:        po_vendor_sites_all directly                         *--
--*                             others through API                                   *--
--*                                                                                  *--
--*     Procedures Called:                                                           *--
--*                                                                                  *--
--*                                                                                  *--
--* Created By: Michelle Dodge (based of CAN code by Wasim Manasfi                   *--
--* Date: 09/26/2007                                                                 *--
--*                                                                                  *--
--*                                                                                  *--
--* Modification Log:                                                                *--
--* Developer         Date      Description                                          *--
--* ----------------  --------  -----------------------------------------------      *--
--* Michelle Dodge    09/26/07     Created                                           *--
--* Rajnish kumar    12/19/11    Retrofitted for R12                                *--
--* RXNETHI-ARGANO   05/11/23   R12.2 Upgrade Remediation                                                                                 *--
--*                                                                                  *--
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
      CURSOR c_vendors
      IS
         SELECT DISTINCT emp.full_name, pv.vendor_name, pv.vendor_id,
                         pvs.vendor_site_id, pv.party_id, pvs.party_site_id,
                         emp.employee_number, emp.email_address,
                         loc.location_code, pea.segment1,        -- Bank Name
                                                         pea.segment2,
                                                                    -- Branch
                         pea.segment3,                      -- Account Number
                                      pea.segment4,           -- Account Type
                                                   pea.segment5,     -- CLABE
                         pea.segment6, pea.segment7, pea.segment8,
                         ppm.effective_end_date, pvs.org_id
                    FROM po_vendors pv,
                         po_vendor_sites_all pvs,
                         /*
						 START R12.2 Upgrade Remediation
						 code commented by RXNETHI-ARGANO,111/05/23
						 hr.per_all_people_f emp,
                         hr.per_all_assignments_f asg,
                         hr.hr_locations_all loc,
                         hr.pay_external_accounts pea,
                         hr.pay_personal_payment_methods_f ppm
						 */
						 --code added by RXNETHI-ARGANO,11/05/23
						 apps.per_all_people_f emp,
                         apps.per_all_assignments_f asg,
                         apps.hr_locations_all loc,
                         apps.pay_external_accounts pea,
                         apps.pay_personal_payment_methods_f ppm
						 --END r12.2 uPGRADE rEMEDIATION
                   WHERE emp.person_id = asg.person_id
                     AND pv.vendor_type_lookup_code = 'EMPLOYEE'
                     AND pv.employee_id = emp.person_id
                     AND pv.vendor_id = pvs.vendor_id
                     AND asg.location_id = loc.location_id
                     AND asg.assignment_id = ppm.assignment_id
                     AND pea.external_account_id = ppm.external_account_id
                     AND ppm.business_group_id = v_business_group_id
                     AND pea.segment4 IN ('CHECK', 'DEBIT')
                     AND ppm.percentage >= 50
                     AND ppm.amount IS NULL
                     AND SYSDATE BETWEEN emp.effective_start_date
                                     AND emp.effective_end_date
                     AND SYSDATE BETWEEN asg.effective_start_date
                                     AND asg.effective_end_date
                     AND SYSDATE BETWEEN ppm.effective_start_date
                                     AND ppm.effective_end_date
                     AND (   pv.end_date_active IS NULL
                          OR pv.end_date_active >= SYSDATE
                         )
                     AND (   pea.last_update_date >=
                                                TRUNC (SYSDATE - v_date_trans)
                          OR (pv.creation_date >=
                                               TRUNC (SYSDATE - v_date_trans2)
                             )
                         );

      v_full_name                  per_all_people_f.full_name%TYPE;
      v_vendor_name                po_vendors.vendor_name%TYPE;
      v_vendor_id                  po_vendors.vendor_id%TYPE;
      v_vendor_site_id             po_vendor_sites_all.vendor_site_id%TYPE;
      v_org_id                     po_vendor_sites_all.org_id%TYPE;
      v_employee_number            per_all_people_f.employee_number%TYPE;
      v_email_address              per_all_people_f.email_address%TYPE;
      v_location                   hr_locations_all.location_code%TYPE;
      v_bank_name                  pay_external_accounts.segment1%TYPE;
      v_branch_name                pay_external_accounts.segment2%TYPE;
      v_account_name               ap_bank_accounts_all.bank_account_name%TYPE;
      v_account_number             pay_external_accounts.segment3%TYPE;
      v_account_type               pay_external_accounts.segment4%TYPE;
      v_routing_number             pay_external_accounts.segment5%TYPE;
      v_bank_number                pay_external_accounts.segment7%TYPE;
----      v_bank_name_5                 pay_external_accounts.segment5%TYPE;
      v_row_id                     VARCHAR2 (250);
      v_bank_account_uses_id       ap_bank_account_uses_all.bank_account_uses_id%TYPE;
      v_tmp_branch_id              NUMBER;
      l_tmp_bank_account_id        NUMBER;
      l_tmp_bank_account_uses_id   NUMBER;
      l_bank_account_id            iby_ext_bank_accounts.ext_bank_account_id%TYPE;
      l_old_bank_account_id        iby_ext_bank_accounts.ext_bank_account_id%TYPE;
      l_update_vendor_record       NUMBER;
      l_update_bank_account_uses   NUMBER;
      l_bank_id                    hz_parties.party_id%TYPE;
      l_assignment_attribs         iby_fndcpt_setup_pub.pmtinstrassignment_rec_type;
      l_ext_bank_act_rec           iby_ext_bankacct_pub.extbankacct_rec_type;
      l_branch_id                  hz_parties.party_id%TYPE;
      l_ext_bank_branch_rec        iby_ext_bankacct_pub.extbankbranch_rec_type;
      l_return_status              VARCHAR2 (1000);
      l_msg_count                  NUMBER;
      l_msg_data                   VARCHAR2 (4000);
      l_response_rec               iby_fndcpt_common_pub.result_rec_type;
      payeecontext_rec_type        iby_disbursement_setup_pub.payeecontext_rec_type;
      l_ext_bank_rec               iby_ext_bankacct_pub.extbank_rec_type;
      l_assign_id                  NUMBER;
   BEGIN
      fnd_file.put_line
            (fnd_file.output,
                'Teletech -  Assign HR Bank Accounts to Vendors Report Date:'
             || SYSDATE
            );
      fnd_file.new_line (fnd_file.output, 1);

      FOR lvendor IN c_vendors
      LOOP
         v_full_name := NULL;
         v_vendor_name := NULL;
         v_vendor_id := NULL;
         v_vendor_site_id := NULL;
         v_employee_number := NULL;
         v_email_address := NULL;
         v_location := NULL;
         v_bank_name := NULL;
         v_branch_name := NULL;
         v_account_number := NULL;
         v_account_name := NULL;
         v_account_type := NULL;
         v_routing_number := NULL;
         v_bank_number := NULL;
         v_org_id := NULL;
         v_full_name := lvendor.full_name;
         v_vendor_name := lvendor.vendor_name;
         v_vendor_id := lvendor.vendor_id;
         v_vendor_site_id := lvendor.vendor_site_id;
         v_employee_number := lvendor.employee_number;
         v_email_address := lvendor.email_address;
         v_location := lvendor.location_code;
         v_bank_name := lvendor.segment1;
         v_branch_name := lvendor.segment2;
         v_account_number := lvendor.segment5;
                                   -- Pass in the full CLABE as the Account #
         v_account_name := UPPER (lvendor.full_name);
         v_account_type := lvendor.segment4;
         v_routing_number := lvendor.segment5;
         v_bank_number := SUBSTR (lvendor.segment5, 1, 6);
         v_org_id := lvendor.org_id;
         l_update_vendor_record := 0;
         l_update_bank_account_uses := 0;
         l_old_bank_account_id := 0;

         -- finance has end dates as null, does not put end of time in as end date for financials
         BEGIN
            SELECT DISTINCT branch_party_id
                       INTO v_tmp_branch_id
                       FROM ce_bank_branches_v
                      WHERE bank_name = v_bank_name
                        AND bank_branch_name = v_branch_name
                        AND end_date IS NULL
                        AND ROWNUM < 2;
         EXCEPTION
            WHEN OTHERS
            THEN
               v_tmp_branch_id := 0;
         END;

         IF v_tmp_branch_id = 0
         THEN
            fnd_file.put_line (fnd_file.output,
                               '-- Processing vendor ' || v_vendor_name
                              );
            fnd_file.put_line (fnd_file.output,
                               '     Employee Number ' || v_employee_number
                              );
            fnd_file.put_line (fnd_file.output,
                               '     Bank Name ' || v_bank_name
                              );
            fnd_file.put_line (fnd_file.output,
                               '     Branch Number ' || v_branch_name
                              );
            fnd_file.put_line (fnd_file.output,
                                  '     Account Number '
                               || SUBSTR (v_account_number, -4, 4)
                              );
            fnd_file.new_line (fnd_file.output, 1);

            -- is this new record, if there is no branch defined then there is no banking info defined at all
            IF v_tmp_branch_id = 0
            THEN
               BEGIN
                  SELECT DISTINCT bank_party_id
                             INTO l_bank_id
                             FROM ce_bank_branches_v
                            -- new view in r12  to get the bank  the  bank branch info
                  WHERE           bank_name = v_bank_name
                              AND bank_home_country = 'MX'
                              AND end_date IS NULL
                              AND ROWNUM < 2;
               EXCEPTION
                  WHEN OTHERS
                  THEN
                     l_bank_id := 0;
                     fnd_file.put_line (fnd_file.output,
                                           'NO Bank  exist with the name'
                                        || v_bank_name
                                       );
               END;

               BEGIN
                  mo_global.init ('SQLAP');
                  mo_global.set_policy_context ('S', lvendor.org_id);

                  IF l_bank_id = 0
                  THEN
                     BEGIN
                        l_ext_bank_rec.bank_name := v_bank_name;
                        l_ext_bank_rec.country_code := 'ES';
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
                     EXCEPTION
                        WHEN OTHERS
                        THEN
                           fnd_file.put_line
                              (fnd_file.output,
                                  'Error in IBY_EXT_BANKACCT_PUB.create_ext_bank - Bank Name'
                               || v_bank_name
                              );
                           fnd_file.put_line (fnd_file.output,
                                                 ' Message: '
                                              || SUBSTR (l_msg_data, 1, 240)
                                             );
                           fnd_file.new_line (fnd_file.output, 2);
                           NULL;
                     END;
                  END IF;

                  l_ext_bank_branch_rec.bank_party_id := l_bank_id;
                  l_ext_bank_branch_rec.branch_name := v_branch_name;
                  l_ext_bank_branch_rec.branch_type := 'OTHER';
                  l_ext_bank_branch_rec.branch_number := v_bank_number;
                  l_ext_bank_branch_rec.description := v_branch_name;
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
                  fnd_file.put_line
                          (fnd_file.output,
                              v_bank_name
                           || ' Routing Number '
                           || v_routing_number
                           || ' Message: from oracle api for creating branch '
                           || l_msg_data
                          );
               EXCEPTION
                  WHEN OTHERS
                  THEN
                     fnd_file.put_line
                        (fnd_file.output,
                            'Error in IBY_EXT_BANKACCT_PUB.create_ext_bank_branch'
                         || v_bank_name
                         || ' Routing Number '
                         || v_routing_number
                        );
                     fnd_file.put_line (fnd_file.output,
                                        ' Message: ' || l_msg_data
                                       );
                     fnd_file.new_line (fnd_file.output, 2);
                     NULL;
               END;

               IF l_branch_id IS NOT NULL     -- successful creation of branch
               THEN
                  COMMIT;

                  BEGIN
                     l_ext_bank_act_rec.acct_owner_party_id :=
                                                             lvendor.party_id;
                     l_ext_bank_act_rec.country_code := 'MX';
                     l_ext_bank_act_rec.branch_id := l_branch_id;
                     l_ext_bank_act_rec.bank_id := l_bank_id;
                     l_ext_bank_act_rec.bank_account_num := v_account_number;
                     l_ext_bank_act_rec.bank_account_name := v_account_name;
                     l_ext_bank_act_rec.currency := 'MXN';
                     l_ext_bank_act_rec.acct_type := 'CHECKING';
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
                     fnd_file.put_line
                        (fnd_file.output,
                            v_bank_name
                         || ' Account Number '
                         || v_account_number
                         || ' Message from oracle api for bank account creation '
                         || SUBSTR (l_msg_data, 1, 240)
                        );
                     fnd_file.new_line (fnd_file.output, 2);
                     NULL;
                  EXCEPTION
                     WHEN OTHERS
                     THEN
                        fnd_file.put_line
                           (fnd_file.output,
                               'Error in IBY_EXT_BANKACCT_PUB.CREATE_EXT_BANK_ACCT - Bank Name'
                            || v_bank_name
                            || ' Account Number '
                            || v_account_number
                           );
                        fnd_file.put_line (fnd_file.output,
                                              ' Message: '
                                           || SUBSTR (l_msg_data, 1, 240)
                                          );
                        fnd_file.new_line (fnd_file.output, 2);
                        NULL;
                  END;

                  -- just check you got something here, just to make 100% sure you got a valid account number created
                  IF l_bank_account_id IS NOT NULL
                  THEN
                     l_update_bank_account_uses := 1;
                           --  set it to insert a new bank account useses all
                  END IF;                     -- l_bank_account_id IS NOT NULL
               END IF;
            ELSE
-- Bank Branch exist since this is not a new branch  then see if bank account is there
               l_branch_id := v_tmp_branch_id;

               -- there is a branch number, then check if there is a bank account number
               BEGIN
                  -- check if account number exists
                  SELECT ext_bank_account_id
                    INTO l_tmp_bank_account_id
                    FROM iby_ext_bank_accounts
                   -- new table for external bank accounts
                  WHERE  branch_id = l_branch_id
                     AND bank_account_num = v_account_number
                     AND bank_account_name = v_account_name
                     AND end_date IS NULL;
               EXCEPTION
                  WHEN TOO_MANY_ROWS
                  THEN
                     l_tmp_bank_account_id := -1;
                     fnd_file.put_line
                              (fnd_file.output,
                                  '- - - - Too many Bank Accounts Found for '
                               || ' Account Name '
                               || v_account_name
                               || ' Account Number '
                               || SUBSTR (v_account_number, -4, 4)
                              );
                  WHEN OTHERS
                  THEN
                     l_tmp_bank_account_id := 0;
               END;

               -- just check you got something here, just to make 100% sure you got a valid account number created
               IF l_tmp_bank_account_id IS NOT NULL
               THEN
                  l_update_bank_account_uses := 1;
                            -- set it to insert a new bank account useses all
               END IF;                        -- l_bank_account_id IS NOT NULL

               -- leave bank accounts "active" and do not end date them,
               -- they may be used by AP or AR -- OKed by AP Manager
               -- also more than one vendor can receive $ on same bank account
               l_bank_account_id := l_tmp_bank_account_id;

               -- there is no bank account, so add one, if there is a bank account defined do NOTHING
               IF l_tmp_bank_account_id = 0
               THEN
                  BEGIN
                     l_ext_bank_act_rec.acct_owner_party_id :=
                                                             lvendor.party_id;
                     l_ext_bank_act_rec.country_code := 'MX';
                     l_ext_bank_act_rec.branch_id := l_branch_id;
                     l_ext_bank_act_rec.bank_id := l_bank_id;
                     l_ext_bank_act_rec.bank_account_num := v_account_number;
                     l_ext_bank_act_rec.bank_account_name := v_account_name;
                     l_ext_bank_act_rec.currency := 'MXN';
                     l_ext_bank_act_rec.acct_type := 'CHECKING';
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
                     fnd_file.put_line
                        (fnd_file.output,
                            v_bank_name
                         || ' Account Number '
                         || v_account_number
                         || ' Message from oracle api for bank account creation '
                         || SUBSTR (l_msg_data, 1, 240)
                        );
                     fnd_file.new_line (fnd_file.output, 2);
                     NULL;
                  EXCEPTION
                     WHEN OTHERS
                     THEN
                        fnd_file.put_line
                           (fnd_file.output,
                               'Error in IBY_EXT_BANKACCT_PUB.CREATE_EXT_BANK_ACCT - Bank Name'
                            || v_bank_name
                            || ' Account Number '
                            || v_account_number
                           );
                        fnd_file.put_line (fnd_file.output,
                                              ' Message: '
                                           || SUBSTR (l_msg_data, 1, 240)
                                          );
                        fnd_file.new_line (fnd_file.output, 2);
                        NULL;
                  END;
               END IF;
            END IF;                       -- this is end of bank account exist

            -- see if this vendor/vendor site combo has an account assigned to it
            IF l_update_bank_account_uses > 0
            THEN
               BEGIN
                  SELECT instr_assignment_id
                    INTO l_tmp_bank_account_uses_id
                    FROM iby_payee_assigned_bankacct_v
                   -- new view to get the bank account info at supplier site level
                  WHERE  supplier_site_id = v_vendor_site_id
                     AND order_of_preference = 1
                     AND end_date IS NULL;
               EXCEPTION
                  WHEN OTHERS
                  THEN
                     l_tmp_bank_account_uses_id := 0;
                     l_old_bank_account_id := 0;
               END;

               -- Do not duplicate enter the same bank account use.
               IF l_bank_account_id != l_old_bank_account_id
               THEN
                  -- vendor has an old bank account uses  - end date it and make it not primary
                  BEGIN
                     UPDATE iby_pmt_instr_uses_all
                        SET end_date = SYSDATE,
                            last_update_date = SYSDATE,
                            last_updated_by = 4,
                            order_of_preference = order_of_preference + 1
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
                           );
                        fnd_file.put_line (fnd_file.output,
                                              ' Error Code: '
                                           || TO_CHAR (SQLCODE)
                                           || ' Message: '
                                           || SUBSTR (SQLERRM, 1, 240)
                                          );
                        fnd_file.new_line (fnd_file.output, 2);
                        NULL;
                  END;

                  COMMIT;
               END IF;

               -- Now all is clear to insert new bank account records
               v_bank_account_uses_id := NULL;

               BEGIN
                  payeecontext_rec_type.party_id := lvendor.party_id;
                  payeecontext_rec_type.party_site_id :=
                                                        lvendor.party_site_id;
                  payeecontext_rec_type.org_id := lvendor.org_id;
                  payeecontext_rec_type.supplier_site_id :=
                                                       lvendor.vendor_site_id;
                  payeecontext_rec_type.payment_function := 'PAYABLES_DISB';
                  payeecontext_rec_type.org_type := 'OPERATING_UNIT';
                  l_assignment_attribs.assignment_id := NULL;
                  l_assignment_attribs.instrument.instrument_type :=
                                                                'BANKACCOUNT';
                  l_assignment_attribs.instrument.instrument_id :=
                                                            l_bank_account_id;
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
                      || 'Bank Account ID '
                      || TO_CHAR (l_bank_account_id)
                      || 'l_assign_id'
                      || l_assign_id
                      || ' Message from oracle api for payment use assignment '
                      || SUBSTR (l_msg_data, 1, 240)
                     );
                  fnd_file.new_line (fnd_file.output, 2);
                  COMMIT;
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
                         || 'l_assign_id'
                         || l_assign_id
                         || TO_CHAR (l_bank_account_id)
                        );
                     fnd_file.put_line (fnd_file.output,
                                           ' Message: '
                                        || SUBSTR (l_msg_data, 1, 240)
                                       );
                     fnd_file.new_line (fnd_file.output, 2);
                     NULL;
               END;
            END IF;              -- l_bank_account_id != l_old_bank_account_id
--            fnd_file.new_line (fnd_file.output, 2);
         END IF;

         -- if there was an update then update the vendor pay method
         IF l_update_vendor_record = 1
         THEN
            BEGIN
               UPDATE po_vendor_sites_all
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
                      || ' Vendor Site Id '
                      || v_vendor_site_id
                      || 'Email Address '
                      || v_email_address
                     );
                  fnd_file.put_line (fnd_file.output,
                                        ' Error Code: '
                                     || TO_CHAR (SQLCODE)
                                     || ' Message: '
                                     || SUBSTR (SQLERRM, 1, 240)
                                    );
            END;
         END IF;

         COMMIT;
         fnd_file.put_line (fnd_file.output,
                               '-- Completed processing for employee number '
                            || v_employee_number
                           );
         fnd_file.new_line (fnd_file.output, 1);
      END LOOP;                                        -- lvendor IN c_vendors

      COMMIT;
      fnd_file.put_line (fnd_file.output, 'Completed Processing');
   END populate_ap_banks;
END ttec_populate_apbank_hr_mex;
/
show errors;
/