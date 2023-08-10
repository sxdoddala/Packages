create or replace package      ttec_synch_employee_email AUTHID CURRENT_USER as
---************************************************************************************--
--*                                                                                  *--
--*     Program Name: ttec_synch_emplpoyee email                             *--
--*                                                                                  *--
--*     Description:  Update AP Vendor sites emails for employee-suppliers
--*                   and emails for employees in FND_USERS
--*                                                                                  *--
--*     Input/Output Parameters:                                                     *--
--*                                                                                  *--
--*     Tables Accessed:                                                             *--
--*                                                                                  *--
--*     Tables Modified:         po_vendor_sites_all, fnd_users
--*
--*     Procedures Called:                                                           *--
--*                                                                                  *--
--*                                                                                  *--
--*                                                                                  *--
--* C  reated By: Wasim Manasfi                                                         *--
--* Date: 04/12/2009                                                                  *--
--*
--*                                                                                  *--
--* Modification Log:                                                                 *--
--* Developer          Date        Description                                        *--
--* ---------          ----        -----------                                        *--
--* Wasim Manasfi   04/12/2009  Created                                               *--
--*                                                                                  *--
--* RXNETHI-ARGANO  18/MAY/2023 R12.2 Upgrade Remediaiton
--*                                                                                  *--
--************************************************************************************--

CURSOR ttec_hr_fnd IS
SELECT DISTINCT emp.full_name, fu.user_name,
                         emp.person_id,
                         emp.email_address HR_EMail,
                         fu.email_address User_Email,
                         fu.employee_id
                   FROM fnd_user  fu,
                         /*
						 START R12.2 Upgrade Remediatiom
						 code commented by RXNETHI-ARGANO,18/05/23
						 hr.per_all_people_f emp,
                         hr.per_all_assignments_f asg
						 */
						 --code added by RXNETHI-ARGANO,18/05/23
						 apps.per_all_people_f emp,
                         apps.per_all_assignments_f asg
						 --END R12.2 Upgrade Remediaiton
                  WHERE emp.person_id = asg.person_id
                    AND fu.employee_id = emp.person_id
                   --  AND asg.business_group_id =  325-- v_business_group_id
                     AND SYSDATE BETWEEN emp.effective_start_date
                                     AND emp.effective_end_date
                     AND SYSDATE BETWEEN asg.effective_start_date
                                     AND asg.effective_end_date
                     and UPPER(emp.email_address) != + UPPER(fu.email_address)
                     and emp.email_address IS NOT NULL;


CURSOR ttec_hr_vendor IS
SELECT DISTINCT emp.full_name, pv.vendor_name, pv.vendor_id,
                         pvs.vendor_site_id, pv.employee_id,
                         pv.set_of_books_id, pv.last_update_date,
                         pv.end_date_active, emp.employee_number,
                         emp.email_address HR_EMail,
                         pvs.email_address Vendor_Email,
                         pvs.org_id
                    FROM po_vendors pv,
                         po_vendor_sites_all pvs,
                         /*
						 START R12.2 Upgrade Remediation
						 code commented by RXNETHI-ARGANO,18/05/23
						 hr.per_all_people_f emp,
                         hr.per_all_assignments_f asg
						 */
						 --code added by RXNETHI-ARGANO,18/05/23
						 apps.per_all_people_f emp,
                         apps.per_all_assignments_f asg
						 --END R12.2 Upgrade Remediation
                  WHERE emp.person_id = asg.person_id
                     AND pv.vendor_type_lookup_code = 'EMPLOYEE'
                     AND pv.employee_id = emp.person_id
                     AND pv.vendor_id = pvs.vendor_id
                   --  AND asg.business_group_id =  325-- v_business_group_id
                     AND SYSDATE BETWEEN emp.effective_start_date
                                     AND emp.effective_end_date
                     AND SYSDATE BETWEEN asg.effective_start_date
                                     AND asg.effective_end_date
                     and UPPER(emp.email_address) != + UPPER(pvs.email_address)
                         and emp.email_address IS NOT NULL;



PROCEDURE main (errcode VARCHAR2, errbuff VARCHAR2,
-- p_m_setofbooks      IN   VARCHAR2,
 --     p_m_source          IN   VARCHAR2,
      p_m_email_to_list   IN   VARCHAR2 );


end ttec_synch_employee_email;
/
show errors;
/
