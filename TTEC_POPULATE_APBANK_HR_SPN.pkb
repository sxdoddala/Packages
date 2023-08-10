create or replace PACKAGE BODY ttec_populate_apbank_hr_spn
AS
--************************************************************************************--
--*                                                                                  *--
--*     Program Name: TTEC_POPULATE_APBANK_HR_SPN                                        *--
--*                                                                                  *--
--*     Description:  Update AP Vendor Banking information from HR
--*                   employee bank info.
--*                   Update those vendors that are employees only
--*                                                                              	   *--
--*                                                                                  *--
--*     Input/Output Parameters:                                                     *--
--*                                                                                  *--
--*     Tables Accessed:                                                             *--
--*                                                                                  *--
--*     Tables Modified:  			po_vendor_sites_all directly
--*                             others through 		API               	 		      *--
--*
--*     Procedures Called:                                                           *--
--*                                               									*--
--*                                                             					*--
--*                                                                                  *--
--*Created By: Wasim Manasfi                                                         *--
--*Date: 06/02/2006                                                           		 *--
--*
--*                 		 														*--
--*Modification Log:                                                           		*--
--*Developer    		 Date        Description                                     *--
--*---------    		 ----        -----------                                       *--

--*Wasim Manasfi   06/02/2006  Created                                              *--
--*  Rajnish kumar  12/16/2011  retrofitted for r12                                                                                *--
--*  RXNETHI-ARGANO  05/MAY/23   R12.2 Upgrade Remediation                          *--
--*
--*                                                                                  *--
--************************************************************************************--
-- Filehandle Variables
   PROCEDURE  populate_ap_banks_spn (
      errcode               VARCHAR2,
      errbuff               VARCHAR2,
      v_business_group_id   NUMBER,
      v_date_trans          VARCHAR2,
      v_date_trans2         VARCHAR2
   )
   IS
      --l_error_message               cust.ttec_error_handling.error_message%TYPE;    --code commented by RXNETHI-ARGANO,05/05/23
      l_error_message               apps.ttec_error_handling.error_message%TYPE;      --code added by RXNETHI-ARGANO,05/05/23

      CURSOR c_vendors
      IS
         SELECT DISTINCT emp.full_name, pv.vendor_name, pv.vendor_id,
                         pvs.vendor_site_id, pv.employee_id, pv.party_id,
                         pvs.party_site_id, pv.set_of_books_id,
                         pv.last_update_date, pv.end_date_active,
                         emp.employee_number, emp.email_address,
                         loc.location_code, ppm.amount, pea.segment1,
                         pea.segment2, pea.segment3,
                                                    pea.segment4,


                         pea.segment5,
                                      pea.segment6,
                                                   pea.segment7,

                         -- bank_Numbe
                         pea.segment8, ppm.effective_start_date,
                         ppm.effective_end_date, pvs.org_id
                    FROM po_vendors pv,
                         po_vendor_sites pvs,
                         /*
						 START R12.2 Upgrade Remediation
						 code commented by RXNETHI-ARGANO, 05/05/23
						 hr.per_all_people_f emp,
                         hr.per_all_assignments_f asg,
                         hr.hr_locations_all loc,
                         hr.pay_external_accounts pea,
                         hr.pay_personal_payment_methods_f ppm*/
						 --code added by RXNETHI-ARGANO, 05/05/23
						 apps.per_all_people_f emp,
                         apps.per_all_assignments_f asg,
                         apps.hr_locations_all loc,
                         apps.pay_external_accounts pea,
                         apps.pay_personal_payment_methods_f ppm
						 --END R12.2 Upgrade Remediation
                   WHERE emp.person_id = asg.person_id
                     --AND pv.vendor_type_lookup_code = 'EMPLOYEE'
                     AND pv.employee_id = emp.person_id
                     AND pv.vendor_id = pvs.vendor_id
                     AND asg.location_id = loc.location_id
                     AND asg.assignment_id = ppm.assignment_id
                     AND pea.external_account_id = ppm.external_account_id
                     AND ppm.business_group_id = v_business_group_id
                    -- AND pea.segment2 = 'C'
                    -- AND ppm.percentage >= 50
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
 v_branch_num 									pay_external_accounts.segment6%TYPE;
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
      l_return_status               VARCHAR2 (1000);
      l_msg_count                   NUMBER;
      l_msg_data                    VARCHAR2 (4000);
      l_response_rec                iby_fndcpt_common_pub.result_rec_type;
      payeecontext_rec_type         iby_disbursement_setup_pub.payeecontext_rec_type;
	  l_ext_bank_rec              IBY_EXT_BANKACCT_PUB.ExtBank_rec_type;
      l_assign_id                   NUMBER;
   BEGIN
      fnd_file.put_line
           (fnd_file.output,
               'Teletech -  Assign HR Bank Accounts to Vendors  Report Date:'
            || SYSDATE
           );
      fnd_file.new_line (fnd_file.output, 2);
      end_of_time := TO_DATE ('31-DEC-4712');


      FOR lvendor IN c_vendors
      LOOP
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
      	 v_branch_num := NULL;



         v_bank_effective_start_date := SYSDATE;
         v_bank_effective_end_date := end_of_time;
         v_full_name := lvendor.full_name;
         v_vendor_name := lvendor.vendor_name;
         v_vendor_id := lvendor.vendor_id;
         v_vendor_site_id := lvendor.vendor_site_id;
         v_employee_id := lvendor.employee_id;
         v_set_of_books_id := lvendor.set_of_books_id;
         v_last_update := lvendor.last_update_date;
         v_end_date := lvendor.end_date_active;
         v_employee_number := lvendor.employee_number;
         v_email_address := lvendor.email_address;
         v_location := lvendor.location_code;
         v_amount := lvendor.amount;
         v_bank_name := v_full_name;
         v_account_type := NULL ; -- in US we store lvendor.segment2;
         v_account_number := lvendor.segment3;
         v_routing_number := lvendor.segment1 || lvendor.segment2;          -- in US use segment 4
         v_bank_name_5 := lvendor.segment1;    					-- in US use segment 5
         v_branch_num   := lvendor.segment2;
         v_branch := lvendor.segment2 ; 								-- US we used lvendor.segment6;
         -- v_bank_number := lvendor.segment7;
         v_bank_number := lvendor.segment1;
         v_bank_effective_start_date := lvendor.effective_start_date;
         v_bank_effective_end_date := lvendor.effective_end_date;
         v_org_id := lvendor.org_id;
         l_update_vendor_record := 0;
         l_update_bank_account_uses := 0;

         BEGIN
            SELECT DISTINCT branch_party_id
                       INTO v_tmp_branch_id
                       FROM ce_bank_branches_v
                      WHERE bank_number = v_branch_num
                        AND bank_name = v_bank_name
                        AND bank_branch_name = v_bank_name_5
                        AND end_date IS NULL
                        AND ROWNUM < 2;
         EXCEPTION
            WHEN OTHERS
            THEN
               v_tmp_branch_id := 0;
         END;

         fnd_file.put_line (fnd_file.output,
                               '- - Processing vendor  Employee Number '
                            || v_employee_number
                            || v_vendor_name
                            || ' Bank Name '
                            || v_bank_name
                            || ' Bank Number '
                            || v_bank_number
                            || ' Routing Number '
                            || SUBSTR (v_routing_number, -4, 4)
                            || ' Account Number '
                            || SUBSTR (v_account_number, -4, 4)
                           );
         fnd_file.new_line (fnd_file.output, 2);

         -- is this new record, if there is no branch defined then there is no banking info defined at all
         IF v_tmp_branch_id = 0
         THEN
            BEGIN
               SELECT DISTINCT bank_party_id
                          INTO l_bank_id
                          FROM ce_bank_branches_v
                         -- new view in r12  to get the bank  the  bank branch info
               WHERE           bank_name = v_bank_name
                           AND bank_home_country = 'ES'
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
                  l_ext_bank_rec.bank_name :=v_bank_name;
 l_ext_bank_rec.country_code :='ES';



IBY_EXT_BANKACCT_PUB.create_ext_bank
(p_api_version => 1.0
,p_init_msg_list => FND_API.G_TRUE
,p_ext_bank_rec => l_ext_bank_rec
,x_bank_id => l_bank_id
,x_return_status => l_return_status
,x_msg_count => l_msg_count
,x_msg_data => l_msg_data
,x_response => l_response_rec
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
               l_ext_bank_branch_rec.branch_name := v_bank_name_5;
               l_ext_bank_branch_rec.branch_type := 'OTHER';
               l_ext_bank_branch_rec.branch_number := v_branch_num;
               l_ext_bank_branch_rec.description := v_full_name;
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

            IF l_branch_id IS NOT NULL        -- successful creation of branch
            THEN
               COMMIT;

-- need to commit this to move on to create the bank account, if no branch then no account
               BEGIN
                  l_ext_bank_act_rec.acct_owner_party_id := lvendor.party_id;
                  l_ext_bank_act_rec.country_code := 'ES';
                  l_ext_bank_act_rec.branch_id := l_branch_id;
                  l_ext_bank_act_rec.bank_id := l_bank_id;
                  l_ext_bank_act_rec.bank_account_num := v_account_number;
                  l_ext_bank_act_rec.currency := 'EUR';
                  l_ext_bank_act_rec.acct_type := 'CHECKING';
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
               END IF;                        -- l_bank_account_id IS NOT NULL
            END IF;
         ELSE
-- Bank Branch exist since this is not a new branch  then see if bank account is there
            l_branch_id := v_tmp_branch_id;

            -- there is a branch number, then check if there is a bank number
            BEGIN
               -- check if account number exists
               SELECT ext_bank_account_id
                 INTO l_tmp_bank_account_id
                 FROM iby_ext_bank_accounts
                -- new table for external bank accounts
               WHERE  branch_id = l_branch_id
                  AND bank_account_num = v_account_number
                  AND bank_account_name = v_bank_name;
            EXCEPTION
               WHEN TOO_MANY_ROWS
               THEN
                  l_tmp_bank_account_id := -1;
                  fnd_file.put_line
                              (fnd_file.output,
                                  '- - - - Too many Bank Accounts Found for '
                               || ' Bank Name '
                               || v_bank_name
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
            -- set it to insert a new bank account use at party site all
            END IF;                           -- l_bank_account_id IS NOT NULL

            l_bank_account_id := l_tmp_bank_account_id;

            -- there is no bank account, so add one, if there is a bank account defined do NOTHING
            IF l_tmp_bank_account_id = 0
            THEN
               BEGIN
                  l_ext_bank_act_rec.acct_owner_party_id := lvendor.party_id;
                  l_ext_bank_act_rec.country_code := 'ES';
                  l_ext_bank_act_rec.branch_id := l_branch_id;
                  l_ext_bank_act_rec.bank_id := l_bank_id;
                  l_ext_bank_act_rec.bank_account_num := v_account_number;
                  l_ext_bank_act_rec.currency := 'EUR';
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
                         'Bank Name'
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
         -- in any case, regardless of new or existing update the bank account uses
         END IF;                          -- this is end of bank account exist

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
            END;

            -- vendor has an old bank account uses  - end date it and make it not primary
            IF l_tmp_bank_account_uses_id > 0
            THEN
               -- ok there exists a bank account uses all - end date it to keep it for records
               BEGIN
                  -- new table to update the bank account use info at supplier site level
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
               payeecontext_rec_type.party_site_id := lvendor.party_site_id;
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

            fnd_file.new_line (fnd_file.output, 2);
         END IF;                             -- l_update_bank_account_uses > 0

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
                  NULL;
            END;
         END IF;

         COMMIT;
         fnd_file.put_line (fnd_file.output,
                               '- - Completed processing for employee number '
                            || v_employee_number
                           );
         fnd_file.new_line (fnd_file.output, 2);
      END LOOP;                                        -- lvendor IN c_vendors

      COMMIT;
      NULL;
   END populate_ap_banks_spn;
END ttec_populate_apbank_hr_spn;
/
show errors;
/