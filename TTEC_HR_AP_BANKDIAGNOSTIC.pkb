create or replace PACKAGE BODY      ttec_hr_ap_bankdiagnostic
AS
--************************************************************************************--
--*                                                                                  *--
--*     Program Name: tec_hr_ap_bankdiagnostic                                       *--
--*                                                                                  *--
--*     Description:  Print employee bank detail from HR and give                    *--
--*                   diagnostics for why it did not get transfered to AP            *--
--*                                                                                  *--
--*                                                                                  *--
--*     Input/Output Parameters:                                                     *--
--*                                                                                  *--
--*     Tables Accessed:                                                             *--
--*                                                                                  *--
--*     Tables Modified:  None                                                       *--
--*                                                                                  *--
--*                                                                                  *--
--*     Procedures Called:                                                           *--
--*                                                                                  *--
--*                                                                                  *--
--*                                                                                  *--
--*Created By: Wasim Manasfi                                                         *--
--*Date: 06/02/2006                                                                  *--
--*                                                                                  *--                                                                                                               *--
--*Modification Log:                                                                 *--
--*Developer          Date        Description                                        *--
--*---------          ----        -----------                                        *--
--*                                                                                  *--
--*Wasim Manasfi   02/02/10 Created                                                  *--
--* Rajnish        25/10/11  Retrofit the code for R12                               *--
--*MXKEERTHI(ARGANO)  10/05/23           1.0          R12.2 Upgrade Remediation                                                                                *--
--************************************************************************************--
   PROCEDURE check_employee_rec (
      errcode      VARCHAR2,
      errbuff      VARCHAR2,
      v_empl_num   VARCHAR2
   )
   IS
   --     l_error_message               cust.ttec_error_handling.error_message%TYPE;--Commented code by MXKEERTHI-ARGANO, 05/10/2023
     l_error_message               apps.ttec_error_handling.error_message%TYPE;--code added by MXKEERTHI-ARGANO, 05/10/2023

      CURSOR c_vendors (p_empl_num VARCHAR2)
      IS
         SELECT DISTINCT emp.full_name, pv.vendor_name, pv.set_of_books_id,
                         emp.employee_number, emp.email_address,
                         loc.location_code, ppm.amount,
                         NVL (ppm.percentage, 0) percentage, pea.segment1,

                         -- name
                         pea.segment2 checking_account,
                         SUBSTR (pea.segment2, -5, 5) account_number,
                         SUBSTR (pea.segment3, -5,
                                 5) phl_us_ca_account_number,   -- also Spain
                         SUBSTR (pea.segment4, -5, 5) us_routing_number,
                         LPAD (pea.segment7 || pea.segment4,
                               9,
                               '0'
                              ) canada_routing,
                         LPAD (pea.segment1 || pea.segment2,
                               9,
                               '0'
                              ) phl_spn_routing,
                         pea.segment5,                           -- bank_name
                                      pea.segment6,                 -- branch
                                                   pea.segment7,
                                                                -- bank_Numbe
                         pea.segment8, ppm.effective_start_date,
                         ppm.effective_end_date, pvs.org_id,
                         pv.end_date_active vendor_active_date,
                         emp.business_group_id
						   	  --START R12.2 Upgrade Remediation
	  /*
		Commented code by MXKEERTHI-ARGANO, 05/10/2023
                    FROM po_vendors pv,--changed from  po.po_vendors  to  po_vendors
                        po_vendor_sites_all pvs,--changed from  po.po_vendor_sites_all  to  po.po_vendor_sites_all
                         hr.per_all_people_f emp,
                         hr.per_all_assignments_f asg,
                         hr.hr_locations_all loc,
                         hr.pay_external_accounts pea,
                         hr.pay_personal_payment_methods_f ppm
	   */
	  --code Added  by MXKEERTHI-ARGANO, 05/10/2023
                    FROM po_vendors pv,--changed from  po.po_vendors  to  po_vendors
                        po_vendor_sites_all pvs,--changed from  po.po_vendor_sites_all  to  po.po_vendor_sites_all
                         apps.per_all_people_f emp,
                         apps.per_all_assignments_f asg,
                         apps.hr_locations_all loc,
                         apps.pay_external_accounts pea,
                         apps.pay_personal_payment_methods_f ppm
	  --END R12.2.10 Upgrade remediation

                   WHERE emp.person_id = asg.person_id
                     AND pv.vendor_type_lookup_code = 'EMPLOYEE'
                     AND pv.employee_id = emp.person_id
                     AND pv.vendor_id = pvs.vendor_id
                     AND asg.location_id = loc.location_id
                     AND asg.assignment_id = ppm.assignment_id
                     AND pea.external_account_id = ppm.external_account_id
                     AND SYSDATE BETWEEN emp.effective_start_date
                                     AND emp.effective_end_date
                     AND SYSDATE BETWEEN asg.effective_start_date
                                     AND asg.effective_end_date
                     AND SYSDATE BETWEEN ppm.effective_start_date
                                     AND ppm.effective_end_date
                     AND emp.employee_number = p_empl_num
                ORDER BY ppm.effective_start_date;

      v_full_name                   per_all_people_f.full_name%TYPE;
      v_vendor_name                 po_vendors.vendor_name%TYPE;
      v_last_update                 po_vendors.last_update_date%TYPE;
      v_end_date                    po_vendors.end_date_active%TYPE;
      v_org_id                      po_vendor_sites_all.org_id%TYPE;
      v_employee_number             per_all_people_f.employee_number%TYPE;
      v_location                    hr_locations_all.location_code%TYPE;
      v_bank_name                   pay_external_accounts.segment1%TYPE;
      v_account_type                pay_external_accounts.segment2%TYPE;
      v_checking_account            pay_external_accounts.segment2%TYPE;
      v_phl_account_number          pay_external_accounts.segment2%TYPE;
      v_phl_us_ca_account_number    pay_external_accounts.segment3%TYPE;
      v_us_routing_number           pay_external_accounts.segment4%TYPE;
      v_account_number              pay_external_accounts.segment3%TYPE;
      v_canada_routing              pay_external_accounts.segment3%TYPE;
      v_phl_spn_routing             pay_external_accounts.segment4%TYPE;
      v_bank_name_5                 pay_external_accounts.segment5%TYPE;
      v_branch                      pay_external_accounts.segment6%TYPE;
      v_bank_number                 pay_external_accounts.segment7%TYPE;
      v_bank_effective_start_date   pay_personal_payment_methods_f.effective_start_date%TYPE;
      v_bank_effective_end_date     pay_personal_payment_methods_f.effective_end_date%TYPE;
      v_business_group_id           per_all_people_f.business_group_id%TYPE;
      v_row_id                      VARCHAR2 (250);
      v_amount                      VARCHAR2 (50);
      v_percent                     VARCHAR2 (50);
      v_bank_account_uses_id        ap_bank_account_uses_all.bank_account_uses_id%TYPE;
      v_bank_branch_id              ap_bank_branches.bank_branch_id%TYPE;
      v_tmp_branch_id               NUMBER;
      l_tmp_bank_account_id         NUMBER;
      l_tmp_bank_account_uses_id    NUMBER;
      v_empl_exist                  BOOLEAN                           := FALSE;
      l_bank_branch_id              ap_bank_branches.bank_branch_id%TYPE;
      l_bank_account_id             ap_bank_accounts.bank_account_id%TYPE;
      end_of_time                   DATE;
      l_update_vendor_record        NUMBER;
      l_update_bank_account_uses    NUMBER;
      l_tmp1                        VARCHAR (250);
      l_tmp2                        VARCHAR (250);
   BEGIN
      fnd_file.put_line
                  (fnd_file.output,
                      'Teletech -  HR - AP Bank Accounts Diagnosis Report : '
                   || SYSDATE
                  );
      fnd_file.put_line
         (fnd_file.output,
          'For a bank account to be transferred from HR to AP, it must meet minimum requirements'
         );
      fnd_file.put_line
         (fnd_file.output,
          'Following is bank account details for request employee. Missing or incorrect information is marked with * * * '
         );
      fnd_file.new_line (fnd_file.output, 2);
      end_of_time := TO_DATE ('31-DEC-4712');

      FOR lvendor IN c_vendors (v_empl_num)
      LOOP
         v_empl_exist := TRUE;
         v_full_name := NULL;
         v_vendor_name := NULL;
         v_last_update := SYSDATE;
         v_end_date := NULL;
         v_employee_number := NULL;
         v_business_group_id := 0;
         v_checking_account := NULL;
         v_location := NULL;
         v_amount := NULL;
         v_bank_name := NULL;
         v_account_type := NULL;
         v_account_number := NULL;
         v_phl_spn_routing := NULL;
         v_bank_name_5 := NULL;
         v_branch := NULL;
         v_org_id := NULL;
         v_bank_number := NULL;
         v_amount := NULL;
         v_percent := NULL;
         v_canada_routing := NULL;
         v_vendor_name := lvendor.vendor_name;
         v_full_name := lvendor.full_name;
         v_phl_us_ca_account_number := lvendor.phl_us_ca_account_number;
         v_us_routing_number := lvendor.us_routing_number;
         v_canada_routing := lvendor.canada_routing;
         v_bank_effective_end_date :=
                          TO_CHAR (lvendor.effective_end_date, 'DD-MON-RRRR');
         v_bank_effective_start_date :=
                        TO_CHAR (lvendor.effective_start_date, 'DD-MON-RRRR');
         v_canada_routing := lvendor.canada_routing;
         --              pay_external_accounts.segment3%TYPE;
         v_phl_spn_routing := lvendor.phl_spn_routing;
         v_amount := TO_CHAR (lvendor.amount);
         v_percent := TO_CHAR (lvendor.percentage);
         v_business_group_id := lvendor.business_group_id;
         v_checking_account := lvendor.checking_account;
         -- finance has end dates as null, does not put end of time in as end date for financials
         fnd_file.put_line (fnd_file.output,
                            '- - Results for Employee Number: ' || v_empl_num
                           );
         fnd_file.put_line (fnd_file.output, 'Employee Name: ' || v_full_name);
         fnd_file.put_line (fnd_file.output, 'Vendor Name: ' || v_vendor_name);

         -- IF v_business_group_id = 325 OR v_business_group_id = 326 THEN
         IF v_business_group_id = 325
         THEN
            fnd_file.put_line (fnd_file.output,
                               'Bank Routing Number: ' || v_us_routing_number
                              );
         ELSIF v_business_group_id = 326
         THEN
            fnd_file.put_line (fnd_file.output,
                               'Bank Routing Number: ' || v_canada_routing
                              );
         ELSIF v_business_group_id IN (1517, 1804)            -- PHL and Spain
         THEN
            fnd_file.put_line (fnd_file.output,
                               'Bank Routing Number: ' || v_phl_spn_routing
                              );
         END IF;

         -- this is for all US , CAN PHL and SPN
         fnd_file.put_line (fnd_file.output,
                            'Bank Account: ' || v_phl_us_ca_account_number
                           );

         IF v_business_group_id IN (325, 326, 1804)
         THEN                                         -- US CAN Spain, not PHL
            fnd_file.put_line (fnd_file.output,
                               'Deposit to Account Amount: ' || v_amount
                              );

            IF (v_amount IS NOT NULL)
            THEN
               fnd_file.put_line
                  (fnd_file.output,
                   '* * * Deposit to Account Amount MUST be set to NULL (no blank spaces allowed): '
                  );
            END IF;
         END IF;

         IF v_business_group_id IN (325, 326)
         THEN                                       -- US CAn, not PHL nor SPN
            fnd_file.put_line (fnd_file.output, 'Percentage:  ' || v_percent);

            IF (lvendor.percentage < 50)
            THEN
               fnd_file.put_line
                        (fnd_file.output,
                         '* * * Percentage MUST equal to or higher than 50: '
                        );
            END IF;

            fnd_file.put_line (fnd_file.output,
                               'Account Type: ' || v_checking_account
                              );

            IF (v_checking_account != 'C')
            THEN
               fnd_file.put_line (fnd_file.output,
                                  '* * * Account Type MUST be Checking (C).'
                                 );
            END IF;
         END IF;                                     -- end % and account type

         fnd_file.put_line (fnd_file.output,
                            'Start date: ' || v_bank_effective_start_date
                           );
         fnd_file.put_line (fnd_file.output,
                            'End date: ' || v_bank_effective_end_date
                           );

         IF (lvendor.effective_end_date < SYSDATE)
         THEN
            fnd_file.put_line (fnd_file.output,
                                  '* * * Account shows as end dated: '
                               || v_bank_effective_end_date
                              );
         END IF;

         fnd_file.new_line (fnd_file.output, 2);
      END LOOP;                                       -- lvendor IN c_vendorsE

      IF NOT v_empl_exist
      THEN
         fnd_file.put_line
                    (fnd_file.output,
                        'Employee Number '
                     || v_empl_num
                     || ' is not a valid employee Number - Please enter a valid employee number.'
                    );
      END IF;

      NULL;
   END check_employee_rec;
END ttec_hr_ap_bankdiagnostic;
/
show errors;
/