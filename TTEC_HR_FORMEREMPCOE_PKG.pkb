create or replace PACKAGE BODY        ttec_hr_formerempcoe_pkg
AS
/*========================================================================================
    Desc:    This package will help to retrieve Former EE COE (Certificate Of an Employee)
    Creator: Hari Varma
    Module : HRMS
    Date:    10/09/2019
    Version: 1.0
    Version: 1.1    Added l_actual_termination_date

07/11/2022   2.0    Venkat Kollai   Added three new elements to calculate allowance.
									Removed period after Miss word.
									Added Last_Name in main procedure.
                                    Changed the word to Ms. to all female employees.
1.0  05/15/2023     MXKEERTHI(ARGANO)             R12.2 Upgrade Remediation									
==========================================================================================*/

   gn_responsibility_id   NUMBER         := fnd_global.resp_id;
   gn_respappl_id         NUMBER         := fnd_global.resp_appl_id;
   gn_user_id             NUMBER         := fnd_global.user_id;

   PROCEDURE main (
      errbuf                OUT      VARCHAR2,
      retcode               OUT      NUMBER,
      p_person_id           IN       NUMBER,
      p_signatory           IN       VARCHAR2
   )
   IS
      CURSOR c1
      IS
    SELECT DISTINCT employee_number,
                         TO_CHAR (SYSDATE, 'fmMonth DD, YYYY') report_date,
                         INITCAP (   papf.first_name
                                  || ' '
                                  || papf.middle_names
                                  || ' '
                                  || papf.last_name
                                 )                             full_name,
                         TO_CHAR (pps.date_start,
                                  'fmMonth DD, YYYY'
                                 )                            start_date,
                         TO_CHAR (pps.actual_termination_date,
                                  'fmMonth DD, YYYY'
                                 )                             end_date,
                         SUBSTR (pj.NAME, INSTR (pj.NAME, '.') + 1) job_name,
                        DECODE (papf.sex,
                                 'M', 'Mr.',
                                 'F', 'Ms.',                              --2.0 - Begin
								 /*'F', DECODE (papf.marital_status,
                                              'S', 'Miss',
                                              'M', 'Mrs.',
                                              'D', 'Ms.',
                                              'W', 'Ms.'
                                             ),*/                         --2.0 - End
                                 ''
                                ) employee_title,
						 INITCAP (papf.last_name) last_name,              --2.0
                         (SELECT flv.meaning
                            FROM fnd_lookup_values_vl flv
                           WHERE flv.meaning =p_signatory
                             AND flv.enabled_flag = 'Y'
                             AND TRUNC (SYSDATE)
                                    BETWEEN TRUNC (flv.start_date_active)
                                        AND NVL (TRUNC (flv.end_date_active),
                                                 TO_DATE ('31-DEC-4712')
                                                ))          sig_name,
                         (SELECT flv.description
                            FROM fnd_lookup_values_vl flv
                           WHERE flv.meaning =p_signatory
                             AND flv.enabled_flag = 'Y'
                             AND TRUNC (SYSDATE)
                                    BETWEEN TRUNC (flv.start_date_active)
                                        AND NVL (TRUNC (flv.end_date_active),
                                                 TO_DATE ('31-DEC-4712')
                                                ))             sig_desc
                    FROM per_all_people_f papf,
                         per_periods_of_service pps,
                         per_all_assignments_f paaf,
                         per_jobs pj
                   WHERE papf.business_group_id = 1517
                     AND papf.person_id = p_person_id
                     AND papf.person_id = pps.person_id
                     AND papf.person_id = paaf.person_id
                     AND paaf.job_id = pj.job_id
                     AND pps.actual_termination_date is not null
					 AND pps.actual_termination_date =
                                      (SELECT MAX (pps1.actual_termination_date)
                                         FROM apps.per_periods_of_service pps1
                                        WHERE pps1.person_id = pps.person_id)
                     AND TRUNC (SYSDATE) BETWEEN papf.effective_start_date
                                             AND papf.effective_end_date
                    and paaf.effective_start_date = (select max(paaf1.effective_start_date)
                                             from per_all_assignments_f paaf1
                                             where paaf1.person_id=paaf.person_id
                                             And paaf1.effective_start_date<=trunc(sysdate));
   BEGIN
      display_message ('output', '<?xml version="1.0" encoding="UTF-8"?>');
      display_message ('output', '<TTEC_HREMPCOE>');
      display_message ('output', '<G_REPORT>');

      FOR c1_rec IN c1
      LOOP
         display_message ('output', '<G_EMP_AUDIT>');
         display_message ('output',
                             '<report_date>'
                          || '<![CDATA['
                          || c1_rec.report_date
                          || ']]>'
                          || '</report_date> '
                         );
         display_message ('output',
                             '<full_name>'
                          || '<![CDATA['
                          || c1_rec.full_name
                          || ']]>'
                          || '</full_name> '
                         );
         display_message ('output',
                             '<employee_number>'
                          || c1_rec.employee_number
                          || '</employee_number>'
                         );
         display_message ('output',
                             '<start_date>'
                          || '<![CDATA['
                          || c1_rec.start_date
                          || ']]>'
                          || '</start_date> '
                         );
		 display_message ('output',
                             '<end_date>'
                          || '<![CDATA['
                          || c1_rec.end_date
                          || ']]>'
                          || '</end_date> '
                         );
         display_message ('output',
                             '<job_name>'
                          || '<![CDATA['
                          || c1_rec.job_name
                          || ']]>'
                          || '</job_name> '
                         );
         display_message ('output',
                             '<employee_title>'
                          || '<![CDATA['
                          || c1_rec.employee_title
                          || ']]>'
                          || '</employee_title>'
                         );
		 display_message ('output',                                    --2.0
                             '<last_name>'
                          || '<![CDATA['
                          || c1_rec.last_name
                          || ']]>'
                          || '</last_name> '
                         );
         display_message ('output',
                             '<sig_name>'
                          || '<![CDATA['
                          || c1_rec.sig_name
                          || ']]>'
                          || '</sig_name> '
                         );
         display_message ('output',
                             '<sig_desc>'
                          || '<![CDATA['
                          || c1_rec.sig_desc
                          || ']]>'
                          || '</sig_desc> '
                         );

         display_message ('output', '</G_EMP_AUDIT>');
      END LOOP;

      display_message ('output', '</G_REPORT>');
      display_message ('output', '</TTEC_HREMPCOE>');
   EXCEPTION
      WHEN OTHERS
      THEN
         display_message ('LOG', SQLERRM);
   --retcode := 2;
   END main;


PROCEDURE main1 (
      errbuf                OUT      VARCHAR2,
      retcode               OUT      NUMBER,
      p_person_id           IN       NUMBER,
      p_signatory           IN       VARCHAR2
   )
   IS
   l_actual_termination_date  DATE;           --- 1.1

      CURSOR c2(l_actual_termination_date IN DATE)
      IS
         SELECT DISTINCT employee_number,
                         TO_CHAR (SYSDATE, 'fmMonth DD, YYYY') report_date,
                         INITCAP (   ppf.first_name
                                  || ' '
                                  || ppf.middle_names
                                  || ' '
                                  || ppf.last_name
                                 ) full_name,
                         TO_CHAR (ppos.date_start,
                                  'fmMonth DD, YYYY'
                                 )                            start_date,
                         TO_CHAR (ppos.actual_termination_date,
                                  'fmMonth DD, YYYY'
                                 )                             end_date,
                         SUBSTR (pjb.NAME, INSTR (pjb.NAME, '.') + 1)
                                                                    job_name,
                         (SELECT flv.meaning
                            FROM fnd_lookup_values_vl flv
                           WHERE flv.meaning =p_signatory
                             AND flv.enabled_flag = 'Y'
                             AND TRUNC (SYSDATE)
                                    BETWEEN TRUNC (flv.start_date_active)
                                        AND NVL (TRUNC (flv.end_date_active),
                                                 TO_DATE ('31-DEC-4712')
                                                )) sig_name,
                         (SELECT flv.description
                            FROM fnd_lookup_values_vl flv
                           WHERE flv.meaning =p_signatory
                             AND flv.enabled_flag = 'Y'
                             AND TRUNC (SYSDATE)
                                    BETWEEN TRUNC (flv.start_date_active)
                                        AND NVL (TRUNC (flv.end_date_active),
                                                 TO_DATE ('31-DEC-4712')
                                                )) sig_desc,
                         DECODE (ppf.sex,
                                 'M', 'Mr.',
                                 'F', 'Ms.',                              --2.0 - Begin
								 /*'F', DECODE (papf.marital_status,
                                              'S', 'Miss',
                                              'M', 'Mrs.',
                                              'D', 'Ms.',
                                              'W', 'Ms.'
                                             ),*/                         --2.0 - End
                                 ''
                                ) employee_title,
                         INITCAP (ppf.last_name) last_name,
                            DECODE
                            (ppb.pay_basis,
                            'MONTHLY', ROUND((ppb.pay_annualization_factor * ppps.proposed_salary_n)/ 12 ,2 ) * 13,
                            'DAILY', NVL(ROUND((ppb.pay_annualization_factor * ppps.proposed_salary_n)/ 12 ,2 ),0)
                              * 26
                              * 14.75,
                             'HOURLY', ROUND((ppb.pay_annualization_factor * ppps.proposed_salary_n)/ 12 ,2 )
                             * 2088,
                             10
                            )
                            salary,
                           Nvl(b.allow1 ,0)
                         +   NVL
                                (xxph_hrms_generic_lib_pkg.get_run_result_value
                                                           (paa.assignment_id,
                                                            ppa.date_earned,
                                                            ppa.date_earned,
                                                            'Rice Subsidy 2',
                                                            'Pay Value'
                                                           ),
                                 0
                                )
                           * 24
                         +   NVL
                                (xxph_hrms_generic_lib_pkg.get_run_result_value
                                          (paa.assignment_id,
                                           ppa.date_earned,
                                           ppa.date_earned,
                                           'Transportation Allowance Taxable',
                                           'Pay Value'
                                          ),
                                 0
                                )
                           * 24 ALLOW,
                         paf.assignment_id, ppa.effective_date
                    FROM per_all_people_f ppf,
                         per_all_assignments_f paf,
                         per_pay_bases ppb,
						 --  hr.per_pay_proposals ppps,  --Commented code by MXKEERTHI-ARGANO, 05/17/2023
                         apps.per_pay_proposals ppps,   --code added by MXKEERTHI-ARGANO, 05/17/2023
                        apps.hr_all_organization_units org,
                         apps.hr_all_organization_units co,
                         per_jobs pjb,
                         per_periods_of_service ppos,
                         pay_assignment_actions paa,
                         pay_payroll_actions ppa,

                         (SELECT   SUM (c.screen_entry_value) * 12 allow1,
                                   a.assignment_id
                              FROM pay_element_entries_f a,
                                   pay_element_types_f b,
                                   pay_element_entry_values_f c
                             WHERE
                                   a.element_type_id = b.element_type_id
                               AND b.element_name IN
                                      ('Client Premium Allowance',
                                       'Language Allowance',
                                       'Living_Miscellaneous Allowance',
                                       'Location Premium Allowance Taxable 2',
                                       'Location Premium Taxable',
                                       'Meal Allowance 2 NonTax',
                                       'Meal Allowance 2 Taxable',
                                       'Meal Allowance NonTax',
                                       'Meal Allowance Taxable',
                                       'Phone Allowance', 'Rice Subsidy',
                                       'Rice Subsidy 2',
                                       'Skills Premium Allowance Taxable 2',
                                       'Skills Premium Taxable',
                                       'Transportation Allowance NonTax',
                                       'Transportation Allowance Taxable',
                                       'Laundry Allowance',
                                       'Clothing Allowance',
									   'Telecommuting Incentive NonTax',        --2.0
									   'Level Premium Pay',                     --2.0
									   'Integration Premium',                   --2.0
                                       'Travel Allowance')
                               AND a.element_entry_id = c.element_entry_id
                               AND c.screen_entry_value IS NOT NULL
                             /*  and a.effective_start_date = (select max(a1.effective_start_date)
                                                             from pay_element_entries_f a1
                                                             where a1.element_entry_id=a.element_entry_id)
                              and b.effective_start_date = (select max(b1.effective_start_date)
                                                           from pay_element_types_f b1
                                                           where b1.element_type_id = b.element_type_id)
                             and c.effective_start_date =(select max(c1.effective_start_date)
                                                           from pay_element_entry_values_f c1
                                                           where c1.ELEMENT_ENTRY_VALUE_ID = c.ELEMENT_ENTRY_VALUE_ID) */
                                    and l_actual_termination_date between a.effective_start_date and a.effective_end_date
                                    and l_actual_termination_date between b.effective_start_date and b.effective_end_date
                                    and l_actual_termination_date between c.effective_start_date and c.effective_end_date
                          GROUP BY a.assignment_id) b
                   WHERE ppf.person_id = paf.person_id
                     AND b.assignment_id(+) = paf.assignment_id
                     AND paf.pay_basis_id = ppb.pay_basis_id
                     AND paf.job_id = pjb.job_id
                     AND paf.business_group_id = 1517
                     and paf.assignment_id=ppps.assignment_id
					 -- and ppps.change_date =(select max(x.change_date) from hr.per_pay_proposals x   --Commented code by MXKEERTHI-ARGANO, 05/17/2023
                             and ppps.change_date =(select max(x.change_date) from apps.per_pay_proposals x--code added by MXKEERTHI-ARGANO, 05/17/2023
                                                  where paf.assignment_id=x.assignment_id
                                                    AND (x.change_date)<=trunc(sysdate))
                     AND SYSDATE BETWEEN ppf.effective_start_date
                                     AND ppf.effective_end_date
                    and paf.effective_start_date = (select max(paaf1.effective_start_date)
                                             from per_all_assignments_f paaf1
                                             where paaf1.person_id=paf.person_id
                                             and paaf1.effective_start_date<= trunc(sysdate))
                     AND ppf.person_id = p_person_id
                     AND paf.assignment_id = paa.assignment_id
                     and paf.person_id=ppos.person_id
                     AND ppos.actual_termination_date is not null
					 AND ppos.actual_termination_date =
                                      (SELECT MAX (pps1.actual_termination_date)
                                         FROM apps.per_periods_of_service pps1
                                        WHERE pps1.person_id = ppos.person_id)
                     AND paa.payroll_action_id = ppa.payroll_action_id
                     AND ppa.date_earned =
                            (SELECT MAX (ppa1.date_earned)
                               FROM pay_assignment_actions paa1,
                                    pay_payroll_actions ppa1,
                                    per_all_assignments_f paf1
                              WHERE paf1.assignment_id = paa1.assignment_id
                                AND paf1.assignment_id = paf.assignment_id
                                AND paa1.payroll_action_id =
                                                        ppa1.payroll_action_id
                                and paf1.effective_start_date = (select  max(paf2.effective_start_date)
                                               from per_all_assignments_f paf2
                                               where paf2.person_id=paf.person_id
                                               and paf2.effective_start_date<=trunc(sysdate))
                                AND ppa1.action_type IN ('Q', 'R', 'BEE'))
                     AND paf.organization_id = org.organization_id(+)
                     AND org.business_group_id = co.organization_id(+)
                     AND ppa.action_type IN ('Q', 'R', 'BEE')
         ORDER BY        effective_date;

   BEGIN
         BEGIN
         select
          ppos.actual_termination_date
          into l_actual_termination_date
        from
       PER_ALL_PEOPLE_F papf, PER_PERIODS_OF_SERVICE ppos
       where papf.person_id=ppos.person_id
       and  papf.person_id = p_person_id
       and ppos.actual_termination_date = (SELECT MAX (pps1.actual_termination_date) FROM apps.per_periods_of_service pps1
       WHERE pps1.person_id = ppos.person_id
       and actual_termination_date is not null)
       and trunc(sysdate) between papf.effective_start_date and papf.effective_end_date
       and papf.business_group_id = 1517;
     END;

      apps.fnd_global.apps_initialize (gn_user_id,
                                       gn_responsibility_id,
                                       gn_respappl_id
                                      );
      wrtlog ('   gn_responsibility_id ' || gn_responsibility_id);
      wrtlog ('   gn_user_id ' || gn_user_id);
      wrtlog ('   gn_respappl_id ' || gn_respappl_id);
      display_message ('output', '<?xml version="1.0" encoding="UTF-8"?>');
      display_message ('output', '<TTEC_HREMPCOE>');
      display_message ('output', '<G_REPORT>');

      FOR c2_rec IN c2 (l_actual_termination_date)
      LOOP
         display_message ('output', '<G_EMP_AUDIT>');
         display_message ('output',
                             '<report_date>'
                          || '<![CDATA['
                          || c2_rec.report_date
                          || ']]>'
                          || '</report_date> '
                         );
         display_message ('output',
                             '<full_name>'
                          || '<![CDATA['
                          || c2_rec.full_name
                          || ']]>'
                          || '</full_name> '
                         );
         display_message ('output',
                             '<employee_number>'
                          || c2_rec.employee_number
                          || '</employee_number>'
                         );
         display_message ('output',
                             '<start_date>'
                          || '<![CDATA['
                          || c2_rec.start_date
                          || ']]>'
                          || '</start_date> '
                         );
          display_message ('output',
                             '<end_date>'
                          || '<![CDATA['
                          || c2_rec.end_date
                          || ']]>'
                          || '</end_date> '
                         );
         display_message ('output',
                             '<job_name>'
                          || '<![CDATA['
                          || c2_rec.job_name
                          || ']]>'
                          || '</job_name> '
                         );
         display_message ('output',
                             '<sig_name>'
                          || '<![CDATA['
                          || c2_rec.sig_name
                          || ']]>'
                          || '</sig_name> '
                         );
         display_message ('output',
                             '<sig_desc>'
                          || '<![CDATA['
                          || c2_rec.sig_desc
                          || ']]>'
                          || '</sig_desc> '
                         );
         display_message ('output',
                             '<employee_title>'
                          || '<![CDATA['
                          || c2_rec.employee_title
                          || ']]>'
                          || '</employee_title> '
                         );
         display_message ('output',
                             '<last_name>'
                          || '<![CDATA['
                          || c2_rec.last_name
                          || ']]>'
                          || '</last_name> '
                         );
         display_message ('output',
                             '<salary>'
                          || '<![CDATA['
                          || c2_rec.salary
                          || ']]>'
                          || '</salary> '
                         );
         display_message ('output',
                             '<allow>'
                          || '<![CDATA['
                          || c2_rec.ALLOW
                          || ']]>'
                          || '</allow> '
                         );
         display_message ('output', '</G_EMP_AUDIT>');
      END LOOP;

      display_message ('output', '</G_REPORT>');
      display_message ('output', '</TTEC_HREMPCOE>');
   EXCEPTION
      WHEN OTHERS
      THEN
         display_message ('LOG', SQLERRM);
   --retcode := 2;
   END main1;

--    ----------------------------------------------------------------------------
--    PROCEDURE TO DISPLAY OUTPUT OR LOG MESSAGE.
--    ----------------------------------------------------------------------------
   PROCEDURE display_message (p_mode IN VARCHAR2, p_msg IN VARCHAR2)
   IS
   BEGIN
      IF UPPER (p_mode) = 'LOG'
      THEN
         fnd_file.put_line (fnd_file.LOG, p_msg);
-- to_char( to_date('31/12/'||to_char(p_year),'DD/MM/RRRR'),'HH24:MI:SS')||' '||p_msg);
      ELSIF UPPER (p_mode) = 'OUTPUT'
      THEN
         fnd_file.put_line (fnd_file.output, p_msg);
      END IF;

      DBMS_OUTPUT.put_line (p_msg);
   END display_message;

   PROCEDURE wrtlog (p_buff IN VARCHAR2)
   IS
-------------------------------------------------------------------------------
   BEGIN
      fnd_file.put_line (fnd_file.LOG, p_buff);
   END wrtlog;

END ttec_hr_formerempcoe_pkg;
/
show errors;
/