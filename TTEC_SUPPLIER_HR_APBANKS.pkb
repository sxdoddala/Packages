create or replace PACKAGE BODY ttec_supplier_hr_apbanks
AS
--************************************************************************************--
--*                                                                                  *--
--*     Program Name: ttec_supplier_hr_apbanks Report
--*
--                                                                                   *--
--*                                                                                  *--
--*     Description:  Report AP Vendor Banking information for employees HR
--*                   employee bank info.
--*
--*                                                                              	   *--
--*                                                                                  *--
--*     Input/Output Parameters:                                                     *--
--*                                                                                  *--
--*     Tables Accessed:                                                             *--
--*                                                                                  *--
--*     Tables Modified:  			                                    	 							 *--
--*                                                                                  *--
--*     Procedures Called:                                                           *--
--*                                               																	 *--
--*                                                             										 *--
--*                                                                                  *--
--*Created By: Wasim Manasfi                                                         *--
--*Date: 06/02/2006                                                           		   *--
--*
--*                 		 																														 *--
--*Modification Log:                                                           		   *--
--*Developer    		 Date        Description                                         *--
--*---------    		 ----        -----------                                         *--

--*Wasim Manasfi   06/02/2006  Created                                               *--
--*RXNETHI-ARGANO  11/05/2023  R12.2 Upgrade Remediation                                                                               *--
--*
--*                                                                                  *--
--************************************************************************************--
-- Filehandle Variables
--
   PROCEDURE report_hr_ap_banks (errcode VARCHAR2, errbuff VARCHAR2,  v_business_group_id  number)
   IS
      --l_error_message               cust.ttec_error_handling.error_message%TYPE; --code commented by RXNETHI-ARGANO,11/05/23
	  l_error_message               apps.ttec_error_handling.error_message%TYPE; --code added by RXNETHI-ARGANO,11/05/23

      CURSOR c_vendors
      IS
      SELECT DISTINCT
        emp.employee_number  ,
	   		emp.full_name        ,
	   		emp.last_name,
				emp.email_address    hr_email ,
				pv.segment1          vendor_num ,
				pv.vendor_name       vendor_name,
        pvs.vendor_site_code vendor_site,
        pv.set_of_books_id   set_of_books,
				pv.last_update_date  vendor_last_update,
        pv.end_date_active   vendor_end_active_date,
        loc.location_code    location_code,
        pea.segment1, --  Hr_bank_name,
        pea.segment4, --  Hr_bank_number,
				pea.segment3, --  Hr_Bank_account_num,
        pea.segment2, --  Hr_account_type,
        pea.segment5, --  Hr_bank_name2,
        pea.segment6, --  Hr_tbd6,
        pea.segment7, --  Hr_tbd7,
        pea.segment8, --  Hr_tbd8,
				ppm.effective_start_date Hr_payment_start_active,
        ppm.effective_end_date   Hr_payemnt_end_active,
				abb.bank_name Ap_Branch_bank_name,
				abb.bank_num  Ap_bank_number,
  			aba.bank_account_num  Ap_bank_account_num,
				aba.bank_account_name ap_bank_account_name ,
				pvs.email_address  Ap_vendor_site_email_address
     FROM po_vendors pv,
          po_vendor_sites_all pvs,
          /*
		  START R12.2 Upgrade Remediation
		  code commmented by RXNETHI-ARGANO,11/05/23
		  hr.per_all_people_f emp,
          hr.per_all_assignments_f asg,
          hr.hr_locations_all loc,
          hr.pay_external_accounts pea,
          hr.pay_personal_payment_methods_f ppm,
			 	  ap.ap_bank_account_uses_all abu,
					ap.ap_bank_accounts_all    aba,
					ap.ap_bank_branches        abb 
					*/
		  --code added by RXNETHI-ARGANO,11/05/23
		  apps.per_all_people_f emp,
          apps.per_all_assignments_f asg,
          apps.hr_locations_all loc,
          apps.pay_external_accounts pea,
          apps.pay_personal_payment_methods_f ppm,
			 	  apps.ap_bank_account_uses_all abu,
					apps.ap_bank_accounts_all    aba,
					apps.ap_bank_branches        abb
         --END R12.2 Upgrade Remediation					
     WHERE emp.person_id = asg.person_id
       AND pv.vendor_type_lookup_code = 'EMPLOYEE'
       AND pv.employee_id = emp.person_id
       AND pv.vendor_id = pvs.vendor_id
       AND asg.location_id = loc.location_id
       AND asg.assignment_id = ppm.assignment_id
       AND pea.external_account_id = ppm.external_account_id
       AND ppm.business_group_id =  v_business_group_id
			 AND aba.bank_account_id = abu.external_bank_account_id
			 AND abu.vendor_id = pv.vendor_id
			 AND abu.vendor_site_id = pvs.vendor_site_id
			 AND aba.bank_branch_id = abb.bank_branch_id
       AND pea.segment2 = 'C'
       AND ppm.percentage >= 50
       AND ppm.amount IS NULL
			 AND abu.end_date is NULL
       AND SYSDATE BETWEEN emp.effective_start_date
       AND emp.effective_end_date
       AND SYSDATE BETWEEN asg.effective_start_date
       AND asg.effective_end_date
       AND sysdate between ppm.effective_start_date
			 AND ppm.effective_end_date
       AND (   pv.end_date_active IS NULL
            OR pv.end_date_active >= SYSDATE   )
       order by emp.last_name;



      v_full_name                   per_all_people_f.full_name%TYPE;
      v_vendor_name                 po_vendors.vendor_name%TYPE;
      v_vendor_id                   po_vendors.vendor_id%TYPE;
      v_vendor_site_id              po_vendor_sites_all.vendor_site_id%TYPE;
      v_employee_id                 po_vendors.employee_id%TYPE;
      v_set_of_books_id             po_vendors.set_of_books_id%TYPE;
      v_last_update                 po_vendors.last_update_date%TYPE;
      v_end_date                    po_vendors.end_date_active%TYPE;
      v_employee_number             per_all_people_f.employee_number%TYPE;
      v_emp_email_address               per_all_people_f.email_address%TYPE;
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
      /*
	  START R12.2 Upgrade Remediation
	  code commented by RXNETHI-ARGANO,11/05/23
	  v_vendor_bank_name                     ap.ap_bank_branches.bank_name%TYPE; --   Ap_Branch_bank_name,
			v_vendor_bank_num      			ap.ap_bank_branches.bank_num%TYPE; --  Ap_bank_number,
  		v_vendor_account_num    ap.ap_bank_accounts_all.bank_account_num%TYPE;  --  Ap_bank_account_num,
		*/
	  --code added by RXNETHI-ARGANO,11/05/23
	  v_vendor_bank_name                     apps.ap_bank_branches.bank_name%TYPE; --   Ap_Branch_bank_name,
			v_vendor_bank_num      			apps.ap_bank_branches.bank_num%TYPE; --  Ap_bank_number,
  		v_vendor_account_num    apps.ap_bank_accounts_all.bank_account_num%TYPE;  --  Ap_bank_account_num,
     -- END R12.2 Upgrade Remediation
      l_tmp_bank_account_id         NUMBER;
      l_tmp_bank_account_uses_id    NUMBER;
      l_bank_branch_id              ap_bank_branches.bank_branch_id%TYPE;
      l_bank_account_id             ap_bank_accounts.bank_account_id%TYPE;
      end_of_time                   DATE;
      l_update_vendor_record        NUMBER;
      l_update_bank_account_uses    NUMBER;
      l_tmp1                        VARCHAR(250);
      l_tmp2                        VARCHAR(250);
      v_Hr_payment_start_active     date;
      v_Hr_payemnt_end_active       date;
			/*
			START R12.2 Upgrade Remediation
			code commented by RXNETHI-ARGANO,11/05/23
			v_Ap_Branch_bank_name         ap.ap_bank_branches.bank_name%TYPE;
			v_Ap_bank_number						  ap.ap_bank_branches.bank_num%TYPE;
  		v_Ap_bank_account_num 				ap.ap_bank_accounts_all.bank_account_num%TYPE;
			v_ap_bank_account_name				ap.ap_bank_accounts_all.bank_account_name%TYPE;
			*/
			--code added by RXNETHI-ARGANO,11/05/23
			v_Ap_Branch_bank_name         apps.ap_bank_branches.bank_name%TYPE;
			v_Ap_bank_number						  apps.ap_bank_branches.bank_num%TYPE;
  		v_Ap_bank_account_num 				apps.ap_bank_accounts_all.bank_account_num%TYPE;
			v_ap_bank_account_name				apps.ap_bank_accounts_all.bank_account_name%TYPE;
			--END R12.2 Upgrade Remediation
			v_Ap_vendor_site_email_address  po_vendor_sites_all.email_address%TYPE;


   BEGIN
      fnd_file.put_line (fnd_file.output,
                            'Teletech -  Employee HR and Supplier Bank Accounts Report: ' || SYSDATE );
      fnd_file.new_line (fnd_file.output, 2);
                  fnd_file.put_line
                     (fnd_file.output,
                      'Employee Number'  			|| '|' ||
                      'Employee Name'     		|| '|' ||
                      'Vendor Name'       		|| '|' ||
                      'HR Bank Name'      		|| '|' ||
                      'HR Bank Number'	  		|| '|' ||
                      'HR Account Number' 		|| '|' ||
                      'HR Bank Name - 2'      || '|' ||
                      'HR Branch Name'        || '|' ||
                      'Venodr Bank Name'  		|| '|' ||
                      'Vendor Bank Number'    || '|' ||
                      'Vendor Account Number' || '|' ||
                      'Vendor Bank Name - 2'  || '|' ||
                      'Vendor Branch Name'    || '|' ||
                      'Employee Email'    		|| '|' ||
                      'Vendor Email');
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
         v_emp_email_address := NULL;
         v_location := NULL;
         v_amount := NULL;
         v_bank_name := NULL;
         v_account_type := NULL;
         v_account_number := NULL;
         v_routing_number := NULL;
         v_bank_name_5 := NULL;
         v_branch := NULL;
         v_bank_number := NULL;
         v_bank_effective_start_date := SYSDATE;
      --    v_bank_effective_end_date := end_of_time;

         v_full_name := lvendor.full_name;
         v_vendor_name := lvendor.vendor_name;
      --   v_vendor_id := lvendor.vendor_id;
      --   v_vendor_site_id := lvendor.vendor_site_id;
      --   v_employee_id := lvendor.employee_id;
         v_set_of_books_id := lvendor.set_of_books;
         v_last_update := lvendor.vendor_last_update;
         v_end_date := lvendor.vendor_end_active_date;
         v_employee_number := lvendor.employee_number;
         v_emp_email_address := lvendor.hr_email;
         v_location := lvendor.location_code;
        -- v_amount := lvendor.amount;
         v_bank_name := lvendor.segment1;
         v_account_type := lvendor.segment2;
         v_account_number := substr (lvendor.segment3,-4, 4);
         v_routing_number := substr (lvendor.segment4,-4, 4);
         v_bank_name_5 := lvendor.segment5;
         v_branch := lvendor.segment6;
         v_bank_number := lvendor.segment7;
         v_Hr_payment_start_active := lvendor.hr_payment_start_active;
         v_Hr_payemnt_end_active := lvendor.Hr_payemnt_end_active;
        v_Ap_Branch_bank_name := lvendor.Ap_Branch_bank_name;
        v_Ap_bank_number := substr (lvendor.Ap_bank_number, -4, 4);
        v_Ap_bank_account_num := substr (lvendor.Ap_bank_account_num, -4, 4);
        v_ap_bank_account_name := lvendor.ap_bank_account_name;
        v_Ap_vendor_site_email_address := lvendor.Ap_vendor_site_email_address;


         -- finance has end dates as null, does not put end of time in as end date for financials
         BEGIN







               fnd_file.put_line
                     (fnd_file.output,
                      v_employee_number 			|| '|' ||
                      v_full_name 						|| '|' ||
         							v_vendor_name 					|| '|' ||
							        v_bank_name 						|| '|' ||
         							v_routing_number 				|| '|' ||      -- bank number
         							v_account_number 				|| '|' ||      -- bank account
         							v_bank_name_5 					|| '|' ||      -- branch name
         							v_branch 								|| '|' ||      -- lvendor.segment6;
         							v_ap_bank_account_name 	|| '|' ||
         							v_Ap_bank_number 				|| '|' ||
        							v_Ap_bank_account_num 	|| '|' ||
        							v_bank_number 					|| '|' ||			 -- lvendor.segment7;
        							v_Ap_Branch_bank_name   || '|' ||
        							v_emp_email_address			|| '|' ||
        							v_Ap_vendor_site_email_address
        						);


            fnd_file.new_line (fnd_file.output, 2);
          EXCEPTION
             WHEN NO_DATA_FOUND THEN

              fnd_file.put_line (fnd_file.output, 'No data for vendors who are employees are found');
              NULL;

         end;
      END LOOP;      -- lvendor IN c_vendors
      -- commit;
      NULL;
   END report_hr_ap_banks;
END ttec_supplier_hr_apbanks;
/
show errors;
/