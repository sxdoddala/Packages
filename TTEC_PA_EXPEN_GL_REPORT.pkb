create or replace PACKAGE BODY      ttec_pa_expen_gl_report
AS
   /*=============================================================================
     Desc:  This package is used to Generate report for  Project Expenditure Analysis Report

      Modification History:

     Version    Date       Author               Description
    -----     --------    --------              -------------------------------------------
     1.0     05/16/2016  Amir Aslam             Draft Version
     2.0     05/22/2017  Amir Aslam             Added later for Duplicate
     3.0     12/17/2018  Chandra Shekar Aekula  Added later for extra DFF values
     4.0     01/27/2021  Venkat                 TASK1926750/TASK2053127 - Added credit department parameter and made
             03/15/2021                         Expenditure end date and GL Date(From) parameters as optional.
     1.0     17/MAY/203  RXNETHI-ARGANO         R12.2 Upgrade Remediation
   =============================================================================*/
   v_code          NUMBER;
   v_errm          VARCHAR2 (255);
   v_columns_str   VARCHAR2 (4000);

   PROCEDURE main (
      retcode           OUT      NUMBER,
      errbuf            OUT      VARCHAR2,
      p_gl_from         IN       VARCHAR2,
      p_gl_to           IN       VARCHAR2,
      p_exp_item_from   IN       VARCHAR2,
      p_exp_item_to     IN       VARCHAR2,
      p_location        IN       VARCHAR2,
      p_project_num     IN       VARCHAR2,
      p_exp_type        IN       VARCHAR2,
      p_po_number       IN       VARCHAR2,
      p_dr_dept         IN       VARCHAR2,
      p_cr_dept         IN       VARCHAR2
   )
   AS
      v_header             VARCHAR2 (4000);
      v_stat               NUMBER                                        := 0;
      v_mesg               VARCHAR2 (256);
      v_cur_flag           BOOLEAN                                    := TRUE;
      v_del_file_flag      BOOLEAN                                   := FALSE;
      v_data_exists_flag   BOOLEAN                                    := TRUE;
      v_req_name           apps.per_all_people_f.full_name%TYPE;
      v_term_date          apps.per_periods_of_service.actual_termination_date%TYPE;
      v_pr_num             apps.po_requisition_headers_all.segment1%TYPE;
      v_org_name           apps.hr_all_organization_units.NAME%TYPE;
      v_pr_creation_date   apps.po_requisition_headers_all.creation_date%TYPE;
      v_preparer_name      apps.per_all_people_f.full_name%TYPE;
      v_po_num             VARCHAR2 (150);
      v_quantity_billed    NUMBER;
      v_amount_billed      NUMBER;
      v_po_amt             NUMBER;
      l_print              VARCHAR2 (1);
      l_type               VARCHAR2 (100);
      l_gl_from            DATE;
      l_gl_to              DATE;
      l_exp_item_from      DATE;
      l_exp_item_to        DATE;
      l_project_num        VARCHAR2 (1000);

      CURSOR cur_pa_exp (
         l_gl_from         DATE,
         l_gl_to           DATE,
         l_exp_item_from   DATE,
         l_exp_item_to     DATE,
         l_project_num     VARCHAR
      )
      IS
--Project
         SELECT DISTINCT a.project_id,
                         REPLACE (REPLACE (REPLACE (REPLACE (a.NAME,
                                                             CHR (13),
                                                             ''
                                                            ),
                                                    CHR (10),
                                                    ''
                                                   ),
                                           CHR (8),
                                           ''
                                          ),
                                  CHR (9),
                                  ''
                                 ) NAME,
                         a.segment1 project_id_num, b.expenditure_item_id,
                         a.description, b.task_id,
                         REPLACE
                            (REPLACE (REPLACE (REPLACE (c.task_number,
                                                        CHR (13),
                                                        ''
                                                       ),
                                               CHR (10),
                                               ''
                                              ),
                                      CHR (8),
                                      ''
                                     ),
                             CHR (9),
                             ''
                            ) task_number,                   --c.task_number,
                         REPLACE
                            (REPLACE (REPLACE (REPLACE (c.task_name,
                                                        CHR (13),
                                                        ''
                                                       ),
                                               CHR (10),
                                               ''
                                              ),
                                      CHR (8),
                                      ''
                                     ),
                             CHR (9),
                             ''
                            ) task_name,                      -- c.task_name,
                         b.expenditure_type, b.expenditure_item_date,
                         b.expenditure_id, b.quantity, b.accrued_revenue,
                         b.bill_amount, b.burden_cost,
                         b.project_burdened_cost,
                         b.posted_project_burdened_cost,
                         b.posted_projfunc_burdened_cost,
                         b.project_currency_code, b.org_id, gl_date, pa_date,
                         NVL (ppf.employee_number,
                              npw_number) employee_number,
                         full_name, gcc1.segment1 loc_dr,
                         gcc1.segment2 client_dr, gcc1.segment3 dept_dr,
                         gcc1.segment4 account_dr, gcc1.segment5 ic_dr,
                         gcc1.segment6 future_dr, gcc.segment1 loc_cr,
                         gcc.segment2 client_cr, gcc.segment3 dept_cr,
                         gcc.segment4 account_cr, gcc.segment5 ic_cr,
                         gcc.segment6 future_cr, ph.segment1 po_number,
                         pl.line_num, b.acct_currency_code,
                         pcda.acct_burdened_cost, vendor_name
--
                         ,
                         a.attribute1 proj_attr1, a.attribute2 proj_attr2,
                         a.attribute3 proj_attr3, a.attribute4 proj_attr4,
                         a.attribute5 proj_attr5
--
                         , c.attribute1 task_attr1, c.attribute2 task_attr2,
                         c.attribute3 task_attr3, c.attribute4 task_attr4,
                         c.attribute5 task_attr5, c.attribute6 task_attr6,
                         c.attribute7 task_attr7, c.attribute8 task_attr8,
                         c.attribute9 task_attr9,-- added by Chandra
                         c.attribute10 task_attr10,-- added by Chandra
                          (select name from hr_operating_units where organization_id =b.ORG_ID ) Provider_Operating_Unit , -- added by Chandra
                           (select name from hr_operating_units where organization_id =b.RECVR_ORG_ID  )Receiver_Operating_Unit , -- added by Chandra
                         pcda.projfunc_currency_code, pcda.burdened_cost,
                         orig_transaction_reference, orig_exp_txn_reference1
                    /*
					START R12.2 Upgrade Remediation
					code commented by RXNETHI-ARGANO,17/05/23
					FROM pa.pa_projects_all a,
                         pa.pa_expenditure_items_all b,
                         pa.pa_tasks c,
                         apps.pa_expenditures_all pea,
                         apps.per_all_people_f ppf,
                         pa.pa_cost_distribution_lines_all pcda,
					*/
					--code added by RXNETHI-ARGANO,17/05/23
					FROM apps.pa_projects_all a,
                         apps.pa_expenditure_items_all b,
                         apps.pa_tasks c,
                         apps.pa_expenditures_all pea,
                         apps.per_all_people_f ppf,
                         apps.pa_cost_distribution_lines_all pcda,
					--END R12.2 Upgrade Remediation
                         apps.gl_code_combinations gcc,
                         apps.gl_code_combinations gcc1,
                         apps.po_headers_all ph,
                         apps.po_lines_all pl,
                         apps.po_distributions_all pd,
                         apps.po_vendors pv
                   WHERE a.project_id = c.project_id
                     AND b.project_id = a.project_id
                     AND b.task_id = c.task_id
                     AND TRUNC (SYSDATE) BETWEEN NVL
                                                    (ppf.effective_start_date,
                                                     TRUNC (SYSDATE)
                                                    )
                                             AND NVL (ppf.effective_end_date,
                                                      TRUNC (SYSDATE)
                                                     )
                     AND ppf.person_id(+) = pea.incurred_by_person_id
                     AND pea.expenditure_id = b.expenditure_id
                     AND pcda.expenditure_item_id = b.expenditure_item_id
                     AND gcc.code_combination_id(+) =
                                                   pcda.cr_code_combination_id
                     AND gcc1.code_combination_id(+) =
                                                   pcda.dr_code_combination_id
--    AND gl_date between to_date('03/01/2016','mm/dd/yyyy') AND to_date('03/31/2016','mm/dd/yyyy')
                     AND ph.po_header_id(+) = pl.po_header_id
                     AND pl.po_line_id(+) = pd.po_line_id
                     AND pd.po_header_id(+) = document_header_id
                     AND pd.po_distribution_id(+) = document_line_number
                     AND pv.vendor_id(+) = b.vendor_id
                     and gcc1.segment3 = nvl(p_dr_dept, gcc1.segment3) --added by Chandra
                     and nvl2(p_cr_dept,gcc.segment3,1) = nvl(p_cr_dept, 1) --added by Venkat as part of 4.0
                     AND TRUNC (gl_date) BETWEEN TRUNC (NVL (l_gl_from,
                                                             gl_date
                                                            )
                                                       )
                                             AND TRUNC (NVL (l_gl_to, gl_date))
                     AND TRUNC (b.expenditure_item_date)
                            BETWEEN TRUNC (NVL (l_exp_item_from,
                                                b.expenditure_item_date
                                               )
                                          )
                                AND TRUNC (NVL (l_exp_item_to,
                                                b.expenditure_item_date
                                               )
                                          )
                     AND p_project_num IS NOT NULL
                     AND a.segment1 IN (
                            SELECT     REGEXP_SUBSTR (p_project_num,
                                                      '[^,]+',
                                                      1,
                                                      LEVEL
                                                     )
                                  FROM DUAL
                            CONNECT BY REGEXP_SUBSTR (p_project_num,
                                                      '[^,]+',
                                                      1,
                                                      LEVEL
                                                     ) IS NOT NULL)
                     AND NVL (pcda.transfer_status_code, 'A') <> 'G'
                                                   --Added later for Duplicate
--    and nvl(a.segment1,'N') IN  nvl( ( select regexp_substr(p_project_num,'[^,]+', 1, level) from dual connect by regexp_substr(p_project_num, '[^,]+', 1, level) is not null ),nvl(a.segment1,'N'))
    --and nvl(ph.segment1,'N') IN  ( select regexp_substr(p_po_number,'[^,]+', 1, level) from dual connect by regexp_substr(p_po_number, '[^,]+', 1, level) is not null )
                     AND b.org_id = NVL (p_location, b.org_id)
                     AND NVL (ph.segment1, 'N') =
                                     NVL (p_po_number, NVL (ph.segment1, 'N'))
                     AND UPPER (b.expenditure_type) =
                            NVL (UPPER (p_exp_type),
                                 UPPER (b.expenditure_type)
                                )
         UNION
--Project
         SELECT DISTINCT a.project_id,
                         REPLACE (REPLACE (REPLACE (REPLACE (a.NAME,
                                                             CHR (13),
                                                             ''
                                                            ),
                                                    CHR (10),
                                                    ''
                                                   ),
                                           CHR (8),
                                           ''
                                          ),
                                  CHR (9),
                                  ''
                                 ) NAME,
                         a.segment1 project_id_num, b.expenditure_item_id,
                         a.description, b.task_id,
                         REPLACE
                            (REPLACE (REPLACE (REPLACE (c.task_number,
                                                        CHR (13),
                                                        ''
                                                       ),
                                               CHR (10),
                                               ''
                                              ),
                                      CHR (8),
                                      ''
                                     ),
                             CHR (9),
                             ''
                            ) task_number,                    --c.task_number,
                         REPLACE
                            (REPLACE (REPLACE (REPLACE (c.task_name,
                                                        CHR (13),
                                                        ''
                                                       ),
                                               CHR (10),
                                               ''
                                              ),
                                      CHR (8),
                                      ''
                                     ),
                             CHR (9),
                             ''
                            ) task_name,                       -- c.task_name,

--     c.task_number,
--     c.task_name,
                         b.expenditure_type, b.expenditure_item_date,
                         b.expenditure_id, b.quantity, b.accrued_revenue,
                         b.bill_amount, b.burden_cost,
                         b.project_burdened_cost,
                         b.posted_project_burdened_cost,
                         b.posted_projfunc_burdened_cost,
                         b.project_currency_code, b.org_id, gl_date, pa_date,
                         NVL (ppf.employee_number,
                              npw_number) employee_number, full_name,
                         gcc1.segment1 loc_dr, gcc1.segment2 client_dr,
                         gcc1.segment3 dept_dr, gcc1.segment4 account_dr,
                         gcc1.segment5 ic_dr, gcc1.segment6 future_dr,
                         gcc.segment1 loc_cr, gcc.segment2 client_cr,
                         gcc.segment3 dept_cr, gcc.segment4 account_cr,
                         gcc.segment5 ic_cr, gcc.segment6 future_cr,
                         ph.segment1 po_number, pl.line_num,
                         b.acct_currency_code, pcda.acct_burdened_cost,
                         vendor_name
--
                         , a.attribute1 proj_attr1, a.attribute2 proj_attr2,
                         a.attribute3 proj_attr3, a.attribute4 proj_attr4,
                         a.attribute5 proj_attr5
--
                         , c.attribute1 task_attr1, c.attribute2 task_attr2,
                         c.attribute3 task_attr3, c.attribute4 task_attr4,
                         c.attribute5 task_attr5, c.attribute6 task_attr6,
                         c.attribute7 task_attr7, c.attribute8 task_attr8,
                         c.attribute9 task_attr9,-- added by Chandra
                         c.attribute10 task_attr10,-- added by Chandra
                         (select name from hr_operating_units where organization_id =b.ORG_ID ) Provider_Operating_Unit , -- added by Chandra
                           (select name from hr_operating_units where organization_id =b.RECVR_ORG_ID  )Receiver_Operating_Unit , -- added by Chandra
                         pcda.projfunc_currency_code, pcda.burdened_cost,
                         orig_transaction_reference, orig_exp_txn_reference1
                    /*
					START R12.2 Upgrade Remediation
					code commented by RXNETHI-ARGANO,17/05/23
					FROM pa.pa_projects_all a,
                         pa.pa_expenditure_items_all b,
                         pa.pa_tasks c,
                         apps.pa_expenditures_all pea,
                         apps.per_all_people_f ppf,
                         pa.pa_cost_distribution_lines_all pcda,
					*/
					--code added by RXNETHI-ARGANO,17/05/23
					FROM apps.pa_projects_all a,
                         apps.pa_expenditure_items_all b,
                         apps.pa_tasks c,
                         apps.pa_expenditures_all pea,
                         apps.per_all_people_f ppf,
                         apps.pa_cost_distribution_lines_all pcda,
					--END R12.2 Upgrade Remediation
                         apps.gl_code_combinations gcc,
                         apps.gl_code_combinations gcc1,
                         apps.po_headers_all ph,
                         apps.po_lines_all pl,
                         apps.po_distributions_all pd,
                         apps.po_vendors pv
                   WHERE a.project_id = c.project_id
                     AND b.project_id = a.project_id
                     AND b.task_id = c.task_id
                     AND TRUNC (SYSDATE) BETWEEN NVL
                                                    (ppf.effective_start_date,
                                                     TRUNC (SYSDATE)
                                                    )
                                             AND NVL (ppf.effective_end_date,
                                                      TRUNC (SYSDATE)
                                                     )
                     AND ppf.person_id(+) = pea.incurred_by_person_id
                     AND pea.expenditure_id = b.expenditure_id
                     AND pcda.expenditure_item_id = b.expenditure_item_id
                     AND gcc1.segment3 = nvl(p_dr_dept, gcc1.segment3) --added by Chandra
                     and nvl2(p_cr_dept,gcc.segment3,1) = nvl(p_cr_dept, 1) -- Added by Venkat as part of 4.0
                     AND gcc.code_combination_id(+) =
                                                   pcda.cr_code_combination_id
                     AND gcc1.code_combination_id(+) =
                                                   pcda.dr_code_combination_id
                     AND NVL (pcda.transfer_status_code, 'A') <> 'G'
                                                   --Added later for Duplicate
--    AND gl_date between to_date('03/01/2016','mm/dd/yyyy') AND to_date('03/31/2016','mm/dd/yyyy')
                     AND ph.po_header_id(+) = pl.po_header_id
                     AND pl.po_line_id(+) = pd.po_line_id
                     AND pd.po_header_id(+) = document_header_id
                     AND pd.po_distribution_id(+) = document_line_number
                     AND pv.vendor_id(+) = b.vendor_id
                     AND TRUNC (gl_date) BETWEEN TRUNC (NVL (l_gl_from,
                                                             gl_date
                                                            )
                                                       )
                                             AND TRUNC (NVL (l_gl_to, gl_date))
                     AND TRUNC (b.expenditure_item_date)
                            BETWEEN TRUNC (NVL (l_exp_item_from,
                                                b.expenditure_item_date
                                               )
                                          )
                                AND TRUNC (NVL (l_exp_item_to,
                                                b.expenditure_item_date
                                               )
                                          )
                     AND p_project_num IS NULL
--    and a.segment1 IN nvl( ( select regexp_substr(p_project_num,'[^,]+', 1, level) from dual connect by regexp_substr(p_project_num, '[^,]+', 1, level) is not null ),a.segment1)
                     AND b.org_id = NVL (p_location, b.org_id)
                     AND NVL (ph.segment1, 'N') =
                                     NVL (p_po_number, NVL (ph.segment1, 'N'))
                     AND UPPER (b.expenditure_type) =
                            NVL (UPPER (p_exp_type),
                                 UPPER (b.expenditure_type)
                                )
                ORDER BY project_id DESC;
   BEGIN
      fnd_file.put_line (fnd_file.LOG,
                         '********    Parameter Input is  ********    '
                        );
      fnd_file.put_line (fnd_file.LOG, 'The gl_from is       ' || p_gl_from);
      fnd_file.put_line (fnd_file.LOG, 'The gl_to is         ' || p_gl_to);
      fnd_file.put_line (fnd_file.LOG,
                         'The exp_item_from is ' || p_exp_item_from
                        );
      fnd_file.put_line (fnd_file.LOG,
                         'The exp_item_to is   ' || p_exp_item_to
                        );
      fnd_file.put_line (fnd_file.LOG,
                         'Project Number is    ' || p_project_num
                        );
      fnd_file.put_line (fnd_file.LOG, 'Location is          ' || p_location);
      fnd_file.put_line (fnd_file.LOG, 'Expen Type is        ' || p_exp_type);
      fnd_file.put_line (fnd_file.LOG, 'po_number is         ' || p_po_number);
      fnd_file.put_line (fnd_file.LOG,
                         '********                        ********    '
                        );

      IF     p_gl_from IS NULL
         AND p_gl_to IS NULL
         AND p_exp_item_from IS NULL
         AND p_exp_item_to IS NULL
         AND p_location IS NULL
         AND p_project_num IS NULL
         AND p_exp_type IS NULL
         AND p_po_number IS NULL
		 AND p_dr_dept IS NULL		-- Added by Venkat as part of 4.0
		 AND p_cr_dept IS NULL		-- Added by Venkat as part of 4.0
      THEN
         v_stat := 1;
         fnd_file.put_line
                     (fnd_file.LOG,
                      'VADATION ERROR *** Please Enter Atleast One Parameter'
                     );
      END IF;

      /*IF p_gl_from IS NOT NULL AND p_gl_to IS NULL
      THEN
         v_stat := 1;
         fnd_file.put_line (fnd_file.LOG,
                            'VADATION ERROR *** Please Enter Both GL period'
                           );
      END IF;

      IF p_gl_to IS NOT NULL AND p_gl_from IS NULL
      THEN
         v_stat := 1;
         fnd_file.put_line (fnd_file.LOG,
                            'VADATION ERROR *** Please Enter Both GL period'
                           );
      END IF;

      IF p_exp_item_from IS NOT NULL AND p_exp_item_to IS NULL
      THEN
         v_stat := 1;
         fnd_file.put_line
                   (fnd_file.LOG,
                    'VADATION ERROR *** Please Enter Both Expenditure Period'
                   );
      END IF;

      IF p_exp_item_to IS NOT NULL AND p_exp_item_from IS NULL
      THEN
         fnd_file.put_line
                   (fnd_file.LOG,
                    'VADATION ERROR *** Please Enter Both Expenditure Period'
                   );
         v_stat := 1;
      END IF; */ -- Commented by Venkat as part of 4.0

	  IF p_exp_item_from IS NULL AND p_gl_from IS NULL
      THEN
         fnd_file.put_line
                   (fnd_file.LOG,
                    'VADATION ERROR *** Please Enter Either Expenditure Start Date or GL Date(From)'
                   );
         v_stat := 1;
      END IF;				-- Added by Venkat as part of 4.0

      BEGIN
         --v_header := 'ABC';
         --v_header := 'project_id|Project Number |Project Number|expenditure_item_id|description|task id|task_number|task_Name |Expenditure_Type| Expenditure_item_date|expenditure_id|quantity| accrued_revenue| bill_amount | burden Cost |  project_currency_code | project_burdened_cost | acct_currency_code | acct_burdened_cost  | org_id | gl_date  | pa_date | employee_number | full_name  | "loc_dr" | "client_dr" | "dept_dr" | "account_dr" | "ic_dr" | "future_dr" | "loc_cr" | "client_cr" | "dept_cr" | "account_cr"|"ic_cr"|"future_cr"|"po_number"|"line_num"|"vendor_name" ';
         --v_header := 'project_id|Project Number |Project Number|expenditure_item_id|task id|task_number|task_Name |Expenditure_Type| Expenditure_item_date|expenditure_id|quantity| accrued_revenue| bill_amount | burden Cost |  project_currency_code | project_burdened_cost | acct_currency_code | acct_burdened_cost  | org_id | gl_date  | pa_date | employee_number | full_name  | "loc_dr" | "client_dr" | "dept_dr" | "account_dr" | "ic_dr" | "future_dr" | "loc_cr" | "client_cr" | "dept_cr" | "account_cr"|"ic_cr"|"future_cr"|po_number|line_num | vendor_name | TaskClientCode | Task_Type | Task_POC | Task_Time_category | Project_SFDC_Clinent_name    | Project_BS_ClientCode | Project_Proj_Margin | TaskLevelAtt5 | TaskLevelAtt6 | TaskLevelAtt7 | Project_Func_Currency | Proj_Func_Burdened_Cost  | Orig_Transaction_Reference  |  "Orig_Transaction_Reference1" ';
         -- v_header := 'project_id|Project Number |Project Number|expenditure_item_id|task id|task_number|task_Name |Expenditure_Type| Expenditure_item_date|expenditure_id|quantity| accrued_revenue| bill_amount | burden Cost |  project_currency_code | project_burdened_cost | acct_currency_code | acct_burdened_cost  | org_id | gl_date  | pa_date | employee_number | full_name  | "loc_dr" | "client_dr" | "dept_dr" | "account_dr" | "ic_dr" | "future_dr" | "loc_cr" | "client_cr" | "dept_cr" | "account_cr"|"ic_cr"|"future_cr"|"po_number"|"line_num"|"vendor_name"| TaskClientCode | Task_Type | Task_POC | Task_Time_category | Project_SFDC_Clinent_name    | Project_BS_ClientCode | Project_Proj_Margin | TaskLevelAtt5 | TaskLevelAtt6 | TaskLevelAtt7 | Project_Func_Currency | Proj_Func_Burdened_Cost  | Orig_Transaction_Reference  |  "Orig_Transaction_Reference1" ';
         --v_header := 'project_id|Project Name |Project Number|Trans_id|task id|task_number|task_Name |Expenditure_Type| Expenditure_item_date|expenditure_id|quantity| accrued_revenue| bill_amount |  project_currency_code | project_burdened_cost   | Project_Func_Currency | Proj_Func_Burdened_Cost   | acct_currency_code | acct_burdened_cost  | org_id | gl_date  | pa_date | employee_number | full_name  | "loc_dr" | "client_dr" | "dept_dr" | "account_dr" | "ic_dr" | "future_dr" | "loc_cr" | "client_cr" | "dept_cr" | "account_cr"|"ic_cr"|"future_cr"|"po_number"|"line_num"|"vendor_name"| TaskClientCode | Task_Type | Task_POC | Task_Time_category | Project_SFDC_Clinent_name    | Project_Proj_Margin | Project_BS_ClientCode  | TaskLevelAtt5 | TaskLevelAtt6 | TaskLevelAtt7| Orig_Transaction_Reference  |  "Orig_Transaction_Reference1" '; --Commented by Chandra
         v_header :=
            'project_id|Project Name |Project Number|Trans_id|task id|task_number|task_Name |Expenditure_Type| Expenditure_item_date|expenditure_id|Receiver_Operating_Unit|Provider_Operating_Unit|quantity| accrued_revenue| bill_amount |  project_currency_code | project_burdened_cost   | Project_Func_Currency | Proj_Func_Burdened_Cost   | acct_currency_code | acct_burdened_cost  | org_id | gl_date  | pa_date | employee_number | full_name  | "loc_dr" | "client_dr" | "dept_dr" | "account_dr" | "ic_dr" | "future_dr" | "loc_cr" | "client_cr" | "dept_cr" | "account_cr"|"ic_cr"|"future_cr"|"po_number"|"line_num"|"vendor_name"| TaskClientCode | Task_Type | Task_POC | Task_Time_category | Project_SFDC_Clinent_name    | Project_Proj_Margin | Project_BS_ClientCode  | TaskLevelAtt5 | TaskLevelAtt6 | TaskLevelAtt7 |Revenue_Recognition_Method |Billable | Orig_Transaction_Reference  |  "Orig_Transaction_Reference1" ';

         fnd_file.put_line (fnd_file.output, v_header);
      EXCEPTION
         WHEN OTHERS
         THEN
            v_stat := 1;
            v_code := SQLCODE;
            v_errm := SUBSTR (SQLERRM, 1, 255);
            fnd_file.put_line (fnd_file.LOG,
                                  'Exception in writing header to file '
                               || v_code
                               || ':'
                               || v_errm
                              );
      END;

      l_gl_from := TO_DATE (p_gl_from, 'YYYY/MM/DD HH24:MI:SS');
      l_gl_to := TO_DATE (p_gl_to, 'YYYY/MM/DD HH24:MI:SS');
      l_exp_item_from := TO_DATE (p_exp_item_from, 'YYYY/MM/DD HH24:MI:SS');
      l_exp_item_to := TO_DATE (p_exp_item_to, 'YYYY/MM/DD HH24:MI:SS');

      --l_project_num   := p_project_num;
      --l_project_num   := '"1320","1244"';
      --l_project_num   := '''1320'',''1244'''
      IF v_stat = 0
      THEN
         BEGIN
            FOR cur_pa_exp_rec IN cur_pa_exp (l_gl_from,
                                              l_gl_to,
                                              l_exp_item_from,
                                              l_exp_item_to,
                                              l_project_num
                                             )
            LOOP
               l_type := NULL;
               -- Get the Type find out
               v_columns_str := NULL;
               --v_columns_str := cur_pa_exp_rec.PROJECT_ID    || '|' ||  '"' || cur_pa_exp_rec.NAME  || '"' || '|' ||  cur_pa_exp_rec.PROJECT_ID_NUM || '|' ||  cur_pa_exp_rec.EXPENDITURE_ITEM_ID
               --v_columns_str := cur_pa_exp_rec.PROJECT_ID    || '|' ||  '' || cur_pa_exp_rec.NAME   || '' || '|' ||  cur_pa_exp_rec.PROJECT_ID_NUM || '|' ||  cur_pa_exp_rec.EXPENDITURE_ITEM_ID
               v_columns_str :=
                     cur_pa_exp_rec.project_id
                  || '|'
                  || cur_pa_exp_rec.NAME
                  || '|'
                  || cur_pa_exp_rec.project_id_num
                  || '|'
                  || cur_pa_exp_rec.expenditure_item_id
                  -- || '|' ||  'cur_pa_exp_rec.DESCRIPTION'
                  || '|'
                  || cur_pa_exp_rec.task_id
                  || '|'
                  || ''
                  || cur_pa_exp_rec.task_number
                  || ''
                  || '|'
                  || ''
                  || cur_pa_exp_rec.task_name
                  || ''
                  || '|'
                  || cur_pa_exp_rec.expenditure_type
                  || '|'
                  || cur_pa_exp_rec.expenditure_item_date
                  || '|'
                  || cur_pa_exp_rec.expenditure_id
                  || '|'
                  || cur_pa_exp_rec.Receiver_Operating_Unit
                  || '|'
                  || cur_pa_exp_rec.Provider_Operating_Unit
                  || '|'
                  || cur_pa_exp_rec.quantity
                  || '|'
                  || cur_pa_exp_rec.accrued_revenue
                  || '|'
                  || cur_pa_exp_rec.bill_amount
                  || '|'
                  || cur_pa_exp_rec.project_currency_code
                  || '|'
                  || cur_pa_exp_rec.project_burdened_cost
                  || '|'
                  || cur_pa_exp_rec.projfunc_currency_code
                  || '|'
                  || cur_pa_exp_rec.burdened_cost
                  || '|'
                  || cur_pa_exp_rec.acct_currency_code
                  || '|'
                  || cur_pa_exp_rec.acct_burdened_cost
                  || '|'
                  || cur_pa_exp_rec.org_id
                  || '|'
                  || cur_pa_exp_rec.gl_date
                  || '|'
                  || cur_pa_exp_rec.pa_date
                  || '|'
                  || cur_pa_exp_rec.employee_number
                  || '|'
                  || cur_pa_exp_rec.full_name
                  || '|'
                  || cur_pa_exp_rec.loc_dr
                  || '|'
                  || cur_pa_exp_rec.client_dr
                  || '|'
                  || cur_pa_exp_rec.dept_dr
                  || '|'
                  || cur_pa_exp_rec.account_dr
                  || '|'
                  || cur_pa_exp_rec.ic_dr
                  || '|'
                  || cur_pa_exp_rec.future_dr
                  || '|'
                  || cur_pa_exp_rec.loc_cr
                  || '|'
                  || cur_pa_exp_rec.client_cr
                  || '|'
                  || cur_pa_exp_rec.dept_cr
                  || '|'
                  || cur_pa_exp_rec.account_cr
                  || '|'
                  || cur_pa_exp_rec.ic_cr
                  || '|'
                  || cur_pa_exp_rec.future_cr
                  || '|'
                  || cur_pa_exp_rec.po_number
                  || '|'
                  || cur_pa_exp_rec.line_num
                  || '|'
                  || cur_pa_exp_rec.vendor_name
                  --
                  || '|'
                  || cur_pa_exp_rec.task_attr1
                  || '|'
                  || cur_pa_exp_rec.task_attr2
                  || '|'
                  || cur_pa_exp_rec.task_attr3
                  || '|'
                  || cur_pa_exp_rec.task_attr5
                  || '|'
                  || cur_pa_exp_rec.proj_attr1
                  || '|'
                  || cur_pa_exp_rec.proj_attr3
                  || '|'
                  || cur_pa_exp_rec.proj_attr4
                  || '|'
                  || cur_pa_exp_rec.task_attr6
                  || '|'
                  || cur_pa_exp_rec.task_attr7
                  || '|'
                  || cur_pa_exp_rec.task_attr8
                  || '|'
                  || cur_pa_exp_rec.task_attr9 --Added by Chandra
                  || '|'
                  || cur_pa_exp_rec.task_attr10 --Added by Chandra
                  || '|'
                  || cur_pa_exp_rec.orig_transaction_reference
                  || '|'
                  || cur_pa_exp_rec.orig_exp_txn_reference1;
               --FND_FILE.PUT_LINE(FND_FILE.LOG,'Before writing to the OUTPUT FILE ');
               fnd_file.put_line (fnd_file.output, v_columns_str);
               v_cur_flag := FALSE;
            END LOOP;
         EXCEPTION
            WHEN OTHERS
            THEN
               v_stat := 1;
               v_code := SQLCODE;
               v_errm := SUBSTR (SQLERRM, 1, 255);
               fnd_file.put_line (fnd_file.LOG,
                                     'Exception in writing to file '
                                  || v_code
                                  || ':'
                                  || v_errm
                                 );
         END;
      END IF;
   EXCEPTION
      WHEN OTHERS
      THEN
         v_code := SQLCODE;
         v_errm := SUBSTR (SQLERRM, 1, 255);
         fnd_file.put_line (fnd_file.LOG,
                               'Exception in closing file : '
                            || v_code
                            || ':'
                            || v_errm
                           );
   END main;
END ttec_pa_expen_gl_report;
/
show errors;
/