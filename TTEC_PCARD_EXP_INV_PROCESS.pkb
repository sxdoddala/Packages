create or replace PACKAGE BODY      TTEC_PCARD_EXP_INV_PROCESS
/*********************************************************************************************************
PROGRAM NAME:   TTEC_PCARD_EXP_INV_PROCESS
DESCRIPTION:    This package processes the P-Card expense payment request type invoices.

INPUT      :    None
OUTPUT     :
CREATED BY:     Pratik Wandhare
DATE:           28-JUL-2016
CALLING FROM   :
----------------
MODIFICATION LOG
----------------
DEVELOPER             DATE          DESCRIPTION
-------------------   ------------  -----------------------------------------
Pratik Wandhare       28-JUL-2016   Initial Version 1.0
Hema C / Anurag K     22-Nov-2017	changes done for p_process_invoice_hold procedure,
									placed credit memo and its payment request invoices on hold.
									Both invoices will be released and processed by concurrent program
									TeleTech Pcard Processing of Invoices and Payments
IXPRAVEEN(ARGANO)  18-july-2023		R12.2 Upgrade Remediation									
*********************************************************************************************************/
AS
PROCEDURE p_purge_records(p_group_id IN VARCHAR2)
AS
v_module VARCHAR2(50):='p_purge_records';
BEGIN

      -- delete records from ap invoice error interface
      DELETE FROM ap_interface_rejections
      WHERE parent_table = 'AP_INVOICES_INTERFACE'
      AND   parent_id IN (SELECT invoice_id
                          FROM ap_invoices_interface
                          WHERE request_id   = p_group_id
                         );
      -- delete records from ap invoice lines error interface
      DELETE FROM ap_interface_rejections
      WHERE parent_table = 'AP_INVOICE_LINES_INTERFACE'
      and parent_id IN (SELECT aili.invoice_line_id
                        FROM ap_invoices_interface aii, ap_invoice_lines_interface aili
                        WHERE aii.invoice_id = aili.invoice_id
                        AND   aii.request_id = p_group_id
                       );

      -- delete records from ap invoice lines interface
      DELETE FROM ap_invoice_lines_interface
      WHERE invoice_id IN (SELECT invoice_id
                           FROM ap_invoices_interface
                           WHERE request_id   =  p_group_id
                          );

      -- delete records from ap invoice interface
      DELETE FROM ap_invoices_interface
      WHERE request_id =  p_group_id;

      COMMIT;

EXCEPTION
      WHEN OTHERS THEN
         ttec_error_logging.process_error (g_application_code,
                                           g_interface,
                                           g_package,
                                           v_module,
                                           g_failure_status,
                                           SQLCODE,
                                           SUBSTR (SQLERRM, 1, 100),
                                           'error purging records for group id - ',
                                           p_group_id
                                          );
END p_purge_records;

PROCEDURE p_submit_ppr(        p_checkrun_id          OUT NOCOPY NUMBER
                              ,p_template_id          IN         NUMBER
                              ,p_exp_expo_request_id  IN         NUMBER
                             )
   AS
      v_req_id    NUMBER;
      e_cp_failed  EXCEPTION;
      v_module VARCHAR(50):=' p_submit_ppr';


        v_request_id          NUMBER := 0;
        v_child_req_id        NUMBER := 0;
        v_phase_code          VARCHAR2 (250);

        v_req_details         VARCHAR2 (1000);
        v_req_phase           VARCHAR2 (250);
        v_req_status          VARCHAR2 (250);
        v_req_dev_phase       VARCHAR2 (250);
        v_req_dev_status      VARCHAR2 (250);
        v_req_message         VARCHAR2 (250);
        v_req_return_status   BOOLEAN;
        v_status_code         VARCHAR2(100);


   CURSOR c_ppr_requests(p_request_id IN NUMBER)
   IS
   SELECT /*+ index (fcr1 fnd_concurrent_requests_n3) */
     fcr1.request_id
    FROM apps.fnd_concurrent_requests fcr1
    WHERE 1=1
   START WITH fcr1.request_id = p_request_id
    CONNECT BY PRIOR fcr1.request_id = fcr1.parent_request_id;

   BEGIN

       --Generate checkrun_id
      SELECT ap_inv_selection_criteria_s.NEXTVAL
        INTO p_checkrun_id
        FROM dual;

      -- Insert into ap_inv_selection_criteria_all
      INSERT INTO ap_inv_selection_criteria_all( check_date
                                                ,pay_thru_date
                                                ,hi_payment_priority
                                                ,low_payment_priority
                                                ,pay_only_when_due_flag
                                                ,status
                                                ,zero_amounts_allowed
                                                ,zero_invoices_allowed
                                                ,vendor_id
                                                ,checkrun_id
                                                ,pay_from_date
                                                ,inv_exchange_rate_type
                                                ,exchange_rate_type
                                                ,payment_method_code
                                                ,vendor_type_lookup_code
                                                ,create_instrs_flag
                                                ,payment_profile_id
                                                ,bank_account_id
                                                ,checkrun_name
                                                ,ou_group_option
                                                ,le_group_option
                                                ,currency_group_option
                                                ,pay_group_option
                                                ,last_update_date
                                                ,last_updated_by
                                                ,last_update_login
                                                ,creation_date
                                                ,created_by
                                                ,template_flag
                                                ,template_id
                                                ,payables_review_settings
                                                ,payments_review_settings
                                                ,document_rejection_level_code
                                                ,payment_rejection_level_code
                                                ,party_id
                                                ,request_id
                                                ,payment_document_id
                                                ,transfer_priority
                                                ,settlement_priority
                                                ,attribute_category
                                                ,attribute1
                                                ,attribute2
                                                ,attribute3
                                                ,attribute4
                                                ,attribute5
                                                ,attribute6
                                                ,attribute7
                                                ,attribute8
                                                ,attribute9
                                                ,attribute10
                                                ,attribute11
                                                ,attribute12
                                                ,attribute13
                                                ,attribute14
                                                ,attribute15
                                               )
                                                 SELECT SYSDATE + NVL(addl_payment_days,0)                              --  check_date
                                                       ,SYSDATE + ADDL_PAY_THRU_DAYS                                    --  pay_thru_date
                                                       ,hi_payment_priority                                             --  hi_payment_priority
                                                       ,low_payment_priority                                            --  low_payment_priority
                                                       ,pay_only_when_due_flag                                          --  pay_only_when_due_flag
                                                       ,'UNSTARTED'                                                     --  status
                                                       ,zero_amounts_allowed                                            --  zero_amounts_allowed
                                                       ,zero_inv_allowed_flag                                           --  zero_invoices_allowed
                                                       ,vendor_id                                                       --  vendor_id
                                                       ,p_checkrun_id                                                   --  checkrun_id
                                                       ,sysdate + addl_pay_from_days                                    --  pay_from_date
                                                       ,inv_exchange_rate_type                                          --  inv_exchange_rate_type
                                                       ,payment_exchange_rate_type                                      --  exchange_rate_type
                                                       ,payment_method_code                                             --  payment_method_code
                                                       ,vendor_type_lookup_code                                         --  vendor_type_lookup_code
                                                       ,create_instrs_flag                                              --  create_instrs_flag
                                                       ,payment_profile_id                                              --  payment_profile_id
                                                       ,bank_account_id                                                 --  bank_account_id
                                                       ,template_name ||'-'||to_char(sysdate, 'DD-MON-RRRR HH24:MI:SS') --  checkrun_name
                                                       ,ou_group_option                                                 --  ou_group_option
                                                       ,le_group_option                                                 --  le_group_option
                                                       ,currency_group_option                                           --  currency_group_option
                                                       ,pay_group_option                                                --  pay_group_option
                                                       ,sysdate                                                         --  last_update_date
                                                       ,last_updated_by                                                 --  last_updated_by
                                                       ,last_update_login                                               --  last_update_login
                                                       ,sysdate                                                         --  creation_date
                                                       ,created_by                                                      --  created_by
                                                       ,'Y'                                                             --  template_flag
                                                       ,p_template_id                                                   --  template_id
                                                       ,payables_review_settings                                        --  payables_review_settings
                                                       ,payments_review_settings                                        --  payments_review_settings
                                                       ,document_rejection_level_code                                   --  document_rejection_level_code
                                                       ,payment_rejection_level_code                                    --  payment_rejection_level_code
                                                       ,party_id                                                        --  party_id
                                                       ,p_exp_expo_request_id                                           --  request_id
                                                       ,payment_document_id                                             --  payment_document_id
                                                       ,transfer_priority                                               --  transfer_priority
                                                       ,settlement_priority                                             --  settlement_priority
                                                       ,attribute_category                                              --  attribute_category
                                                       ,attribute1                                                      --  attribute1
                                                       ,attribute2                                                      --  attribute2
                                                       ,attribute3                                                      --  attribute3
                                                       ,attribute4                                                      --  attribute4
                                                       ,attribute5                                                      --  attribute5
                                                       ,attribute6                                                      --  attribute6
                                                       ,attribute7                                                      --  attribute7
                                                       ,attribute8                                                      --  attribute8
                                                       ,attribute9                                                      --  attribute9
                                                       ,attribute10                                                     --  attribute10
                                                       ,attribute11                                                     --  attribute11
                                                       ,attribute12                                                     --  attribute12
                                                       ,attribute13                                                     --  attribute13
                                                       ,attribute14                                                     --  attribute14
                                                       ,attribute15                                                     --  attribute15
                                                   FROM ap_payment_templates
                                                  WHERE template_id = p_template_id;

      -- insert into ap_le_group
      INSERT INTO ap_le_group( legal_entity_id
                              ,checkrun_id
                              ,le_group_id
                              ,creation_date
                              ,created_by
                              ,last_update_date
                              ,last_updated_by
                             )
                               SELECT legal_entity_id        -- legal_entity_id
                                     ,p_checkrun_id          -- checkrun_id
                                     ,ap_le_group_s.NEXTVAL  -- le_group_id
                                     ,SYSDATE                -- creation_date
                                     ,alg.created_by         -- created_by
                                     ,SYSDATE                -- last_update_date
                                     ,alg.last_updated_by    -- last_updated_by
                                 from ap_le_group alg,
                                      ap_payment_templates appt
                                where alg.template_id = p_template_id
                                  and alg.template_id = appt.template_id
                                  and appt.le_group_option = 'SPECIFY';

      -- Insert into ap_currency_group
      INSERT INTO ap_currency_group( currency_code
                                    ,checkrun_id
                                    ,currency_group_id
                                    ,creation_date
                                    ,created_by
                                    ,last_update_date
                                    ,last_updated_by
                                   )
                                    SELECT currency_code               -- currency_code
                                          ,p_checkrun_id               -- checkrun_id
                                          ,ap_currency_group_s.NEXTVAL -- currency_group_id
                                          ,SYSDATE                     -- creation_date
                                          ,acg.created_by              -- created_by
                                          ,SYSDATE                     -- last_update_date
                                          ,acg.last_updated_by         -- last_updated_by
                                      FROM ap_currency_group acg,
                                           ap_payment_templates appt
                                     WHERE acg.template_id = p_template_id
                                       AND acg.template_id = appt.template_id
                                       AND appt.currency_group_option = 'SPECIFY';

      -- Insert into ap_ou_group
      INSERT INTO ap_ou_group ( org_id
                              ,checkrun_id
                              ,ou_group_id
                              ,creation_date
                              ,created_by
                              ,last_update_date
                              ,last_updated_by
                              )
                                   SELECT  org_id                      -- org_id
                                          ,p_checkrun_id               -- checkrun_id
                                          ,ap_ou_group_s.NEXTVAL       -- ou_group_id
                                          ,SYSDATE                     -- creation_date
                                          ,apg.created_by              -- created_by
                                          ,SYSDATE                     -- last_update_date
                                          ,apg.last_updated_by         -- last_updated_by
                                      FROM ap_ou_group apg,
                                           ap_payment_templates appt
                                     WHERE apg.template_id = p_template_id
                                       AND apg.template_id = appt.template_id
                                       AND appt.ou_group_option = 'SPECIFY';


      -- Insert into ap_pay_group
      INSERT INTO ap_pay_group( vendor_pay_group
                               ,checkrun_id
                               ,pay_group_id
                               ,creation_date
                               ,created_by
                               ,last_update_date
                               ,last_updated_by
                              )
                               SELECT vendor_pay_group       -- vendor_pay_group
                                     ,p_checkrun_id          -- checkrun_id
                                     ,ap_pay_group_s.NEXTVAL -- pay_group_id
                                     ,SYSDATE                -- creation_date
                                     ,apg.created_by         -- created_by
                                     ,SYSDATE                -- last_update_date
                                     ,apg.last_updated_by    -- last_updated_by
                                 FROM ap_pay_group apg,
                                      ap_payment_templates appt
                                WHERE apg.template_id = p_template_id
                                  AND apg.template_id = appt.template_id
                                  AND appt.pay_group_option = 'SPECIFY';

      -- Trigger Invoice Select
      v_req_id := fnd_request.submit_request ( application      => 'SQLAP'
                                               ,program          => 'APXPBASL'
                                               ,description      => NULL
                                               ,start_time       => NULL
                                               ,sub_request      => FALSE
                                               ,argument1        => p_checkrun_id
                                               ,argument2        => NULL
                                               ,argument3        => NULL
                                               ,argument4        => NULL
                                               ,argument5        => NULL
                                              );
      COMMIT;


      IF v_req_id = 0 THEN
         RAISE e_cp_failed;
      ELSE

       -- wait for first request to complete
              LOOP

                 v_req_return_status :=
                  Fnd_Concurrent.wait_for_request (v_req_id,
                                                   60,
                                                   0,
                                                   v_req_phase,
                                                   v_req_status,
                                                   v_req_dev_phase,
                                                   v_req_dev_status,
                                                   v_req_message
                                                   );
                  COMMIT;
                  EXIT WHEN UPPER (v_req_phase) = 'COMPLETED'
                       OR UPPER (v_req_status) IN
                                         ('CANCELLED', 'ERROR', 'TERMINATED');
              END LOOP;

           BEGIN
           FOR rec IN c_ppr_requests(v_req_id) LOOP

                     -- wait for child requests to complete
              SELECT status_code
                INTO v_status_code
                 FROM FND_CONCURRENT_REQUESTS
               WHERE request_id=rec.request_id;

             IF v_status_code<>'C' THEN


              LOOP
                 v_req_return_status :=
                  Fnd_Concurrent.wait_for_request (rec.request_id,
                                                   60,
                                                   0,
                                                   v_req_phase,
                                                   v_req_status,
                                                   v_req_dev_phase,
                                                   v_req_dev_status,
                                                   v_req_message
                                                   );
                  COMMIT;
                  EXIT WHEN UPPER (v_req_phase) = 'COMPLETED'
                       OR UPPER (v_req_status) IN
                                         ('CANCELLED', 'ERROR', 'TERMINATED');
              END LOOP;

             END IF;

           END LOOP;
           EXCEPTION WHEN OTHERS THEN
                      ttec_error_logging.process_error (g_application_code,
                                           g_interface,
                                           g_package,
                                           v_module,
                                           g_failure_status,
                                           SQLCODE,
                                           SUBSTR (SQLERRM, 1, 100),
                                           'error while checking request status  ',
                                           p_exp_expo_request_id
                                          );

           END;

      END IF;
   EXCEPTION
      WHEN e_cp_failed THEN
      -- Write exception handling

         ttec_error_logging.process_error (g_application_code,
                                           g_interface,
                                           g_package,
                                           v_module,
                                           g_failure_status,
                                           SQLCODE,
                                           SUBSTR (SQLERRM, 1, 100),
                                           'error while submit of ppr , expense req_id ',
                                           p_exp_expo_request_id
                                          );
      WHEN OTHERS THEN
         ttec_error_logging.process_error (g_application_code,
                                           g_interface,
                                           g_package,
                                           v_module,
                                           g_failure_status,
                                           SQLCODE,
                                           SUBSTR (SQLERRM, 1, 100),
                                           'error for export request - ',
                                           p_exp_expo_request_id
                                          );

   END p_submit_ppr;
 PROCEDURE p_submit_conc_program(p_org_id IN NUMBER, p_conc_name IN VARCHAR2, p_req_id OUT NUMBER )
 IS
 -- This procedure submits invoice validation and create accounting program
   v_module              VARCHAR2(100) := 'SUBMIT_CONC_PROGRAM';

   v_resp_name           VARCHAR2(2000);
   v_short_name          VARCHAR2(100);
   v_user_id             NUMBER := fnd_global.user_id;

   v_request_id          NUMBER := 0;
   v_child_req_id        NUMBER := 0;
   v_phase_code          VARCHAR2 (250);

   v_req_details         VARCHAR2 (1000);
   v_req_phase           VARCHAR2 (250);
   v_req_status          VARCHAR2 (250);
   v_req_dev_phase       VARCHAR2 (250);
   v_req_dev_status      VARCHAR2 (250);
   v_req_message         VARCHAR2 (250);
   v_req_return_status   BOOLEAN;


   v_status_message      VARCHAR2 (500)         := NULL;
   v_name                VARCHAR2(200);
   v_ledger_name         gl_ledgers.NAME%TYPE;
   v_ledger_id           gl_ledgers.LEDGER_ID%TYPE;

  BEGIN

    IF    p_conc_name= 'VALIDATION' THEN
    BEGIN

      -- Submit Invoice Validation program
   v_request_id :=
      fnd_request.submit_request ('SQLAP',   -- Applcaition short name
                                  'APPRVL',  -- Program short name
                                  'Invoice Validation',               -- concurrent program description
                                  SYSDATE,            --  Start time
                                  FALSE,              --  Sub request
                                  argument1        => p_org_id,
                                  argument2        => 'All',
                                  argument3        => '',
                                  argument4        => '',
                                  argument5        => '',
                                  argument6        => '',
                                  argument7        => 'PCARD',
                                  argument8        => '',
                                  argument9        => '',
                                  argument10      =>  'N',
                                  argument11      =>  '1000',
                                  argument12      =>  '',
                                  argument13      =>  'N'
                                  );
        COMMIT;

        IF v_request_id IS NOT NULL
        THEN
             p_req_id :=v_request_id;
               -- Wait for Requests ---
              LOOP
                 v_req_return_status :=
                  Fnd_Concurrent.wait_for_request (v_request_id,
                                                   60,
                                                   0,
                                                   v_req_phase,
                                                   v_req_status,
                                                   v_req_dev_phase,
                                                   v_req_dev_status,
                                                   v_req_message
                                                   );
                  COMMIT;
                  EXIT WHEN UPPER (v_req_phase) = 'COMPLETED'
                       OR UPPER (v_req_status) IN
                                         ('CANCELLED', 'ERROR', 'TERMINATED');
              END LOOP;

        END IF;
    EXCEPTION WHEN OTHERS THEN
                     ttec_error_logging.process_error ( g_application_code,
                                                 g_interface,
                                                 g_package,
                                                 v_module,
                                                 g_failure_status,
                                                 SQLCODE,
                                                    'Error while validation submit'
                                                 || SUBSTR (SQLERRM, 1, 100)
                                                );

    END;

    ELSIF p_conc_name= 'ACCOUNTING' THEN

    BEGIN

    SELECT gl.ledger_id,gl.name
      INTO
       v_ledger_id,v_ledger_name
      FROM hr_operating_units hou,gl_ledgers gl
      WHERE organization_id=p_org_id
       AND hou.set_of_books_id=gl.ledger_id;

    EXCEPTION WHEN OTHERS THEN
                     ttec_error_logging.process_error ( g_application_code,
                                                 g_interface,
                                                 g_package,
                                                 v_module,
                                                 g_failure_status,
                                                 SQLCODE,
                                                    'Error while fetching ledger details'
                                                 || SUBSTR (SQLERRM, 1, 100)
                                                );

    END;

    BEGIN

      v_request_id := fnd_request.submit_request(
                                'GMF',           --  Applcaition short name
                                'GMFAACCP',      --  Program short name
                                '',              --  concurrent program description
                                SYSDATE,         --  Start time
                                FALSE,           --  Sub request
                                ARGUMENT1  =>'200',
                                ARGUMENT2  =>'200',
                                ARGUMENT3  =>'Y',
                                ARGUMENT4  =>TO_CHAR(v_ledger_id),
                                ARGUMENT5  =>'',
                                ARGUMENT6  =>TO_CHAR(SYSDATE, 'YYYY/MM/DD HH24:MI:SS'),
                                ARGUMENT7  =>'Y',
                                ARGUMENT8  =>'Y',
                                ARGUMENT9  =>'F',
                                ARGUMENT10 =>'Y',
                                ARGUMENT11 =>'N',
                                ARGUMENT12 =>'D',
                                ARGUMENT13 =>'Y',
                                ARGUMENT14 =>'Y',
                                ARGUMENT15 =>'Y',
                                ARGUMENT16 =>'',
                                ARGUMENT17 =>'2',
                                ARGUMENT18 =>'N',
                                ARGUMENT19 =>'',
                                ARGUMENT20 =>'',
                                ARGUMENT21 =>'Payables',
                                ARGUMENT22 =>'Payables',
                                ARGUMENT23 =>v_ledger_name,
                                ARGUMENT24 =>'',
                                ARGUMENT25 =>'Yes',
                                ARGUMENT26=>'Final',
                                ARGUMENT27=>'No',
                                ARGUMENT28=>'Detail',
                                ARGUMENT29=>'Yes',
                                ARGUMENT30=>'Yes',
                                ARGUMENT31=>'No',
                                ARGUMENT32=>'',
                                ARGUMENT33=>'',
                                ARGUMENT34=>'',
                                ARGUMENT35=>'',
                                ARGUMENT36=>'',
                                ARGUMENT37=>'',
                                ARGUMENT38=>'',
                                ARGUMENT39=>'',
                                ARGUMENT40=>'N',
                                ARGUMENT41=>'No',
                                ARGUMENT42=>'N',
                                ARGUMENT43=> TO_CHAR(v_user_id),
                                ARGUMENT44=>'N'
                                );
        COMMIT;

        IF v_request_id IS NOT NULL
        THEN
             p_req_id :=v_request_id;
               -- Wait for Requests ---
              LOOP
                 v_req_return_status :=
                  Fnd_Concurrent.wait_for_request (v_request_id,
                                                   60,
                                                   0,
                                                   v_req_phase,
                                                   v_req_status,
                                                   v_req_dev_phase,
                                                   v_req_dev_status,
                                                   v_req_message
                                                   );
                  COMMIT;
                  EXIT WHEN UPPER (v_req_phase) = 'COMPLETED'
                       OR UPPER (v_req_status) IN
                                         ('CANCELLED', 'ERROR', 'TERMINATED');
              END LOOP;

        END IF;


    EXCEPTION WHEN OTHERS THEN
                     ttec_error_logging.process_error ( g_application_code,
                                                 g_interface,
                                                 g_package,
                                                 v_module,
                                                 g_failure_status,
                                                 SQLCODE,
                                                    'Error in submitting create accounting program '
                                                 || SUBSTR (SQLERRM, 1, 100)
                                                );

    END;


    END IF;


    EXCEPTION WHEN OTHERS THEN
              ttec_error_logging.process_error ( g_application_code,
                                                 g_interface,
                                                 g_package,
                                                 v_module,
                                                 g_failure_status,
                                                 SQLCODE,
                                                    'Error in Submit Request - '
                                                 || SUBSTR (SQLERRM, 1, 100)
                                                );
  END p_submit_conc_program;

PROCEDURE  p_process_invoice_hold(p_org_id IN NUMBER,p_request_id IN NUMBER,p_flag IN VARCHAR2)
IS
-- This procedure puts payment request type invoices on hold/release
v_module VARCHAR2(2000):='p_process_invoice_hold';
v_on_hold VARCHAR2(10);
--i_inv_id1 NUMBER;

CURSOR c_hld_inv(p_org_id IN NUMBER,p_request_id IN NUMBER)
IS
   	     SELECT exph.request_id,exph.report_header_id,ai.reference_key1,ai.INVOICE_ID, ai.invoice_num
           FROM apps.ap_expense_report_headers_all exph,
                apps.ap_invoices_all ai
          WHERE exph.request_id = p_request_id ---67642952, 67590971
            AND exph.org_id=p_org_id
            AND UPPER (ai.invoice_type_lookup_code) in ('PAYMENT REQUEST','CREDIT')
            and upper(ai.source) = upper('SelfService')
            and upper(PAY_GROUP_LOOKUP_CODE) = upper('PCARD')
            and ai.payment_status_flag = 'N'
            and ai.invoice_num like 'PC%'
            and exph.org_id = ai.org_id
            and exph.report_header_id = ai.reference_key1
            AND ai.product_table = 'AP_EXPENSE_REPORT_HEADERS_ALL';


BEGIN

   IF  p_flag='H' THEN -- invoices to put on hold


     BEGIN
        FOR rec in c_hld_inv(p_org_id,p_request_id)
         LOOP
		 v_on_hold:= 'Y';

	BEGIN
           SELECT 'N'
            INTO v_on_hold
            FROM ap_invoices_all aia
            WHERE
            aia.invoice_id=rec.invoice_id
            AND NOT EXISTS (
              SELECT 1 FROM AP_HOLDS_ALL aph
                WHERE aph.invoice_id=aia.invoice_id
                AND aph.HOLD_LOOKUP_CODE='PCARD_INV_HOLD'
				AND aph.release_lookup_code is null
                          ) ;

           EXCEPTION WHEN NO_DATA_FOUND THEN
            NULL ;
			WHEN OTHERS THEN
              ttec_error_logging.process_error ( g_application_code,
                                                 g_interface,
                                                 g_package,
                                                 v_module,
                                                 g_failure_status,
                                                 SQLCODE,
                                                    'Error in Submit Request - '
                                                 || SUBSTR (SQLERRM, 1, 100)
                                                );
           END;

         IF v_on_hold='N' THEN
          ap_holds_pkg.insert_single_hold(rec.invoice_id,
                                       'PCARD_INV_HOLD',
                                       'INVOICE HOLD REASON',
                                        'Credit/Expense Report type invoice not generated',
                                        NULL,
                                       'p_process_invoice_hold'
                                       );
         END IF;
       END LOOP;

	   EXCEPTION WHEN OTHERS THEN
                       ttec_error_logging.process_error (g_application_code,
                                                 g_interface,
                                                 g_package,
                                                 v_module,
                                                 g_failure_status,
                                                 SQLCODE,
                                                    'Error in putting invoice hold '
                                                 || SUBSTR (SQLERRM, 1, 100)
                                                );

     END;

   END IF;

EXCEPTION WHEN OTHERS THEN
               ttec_error_logging.process_error (g_application_code,
                                                 g_interface,
                                                 g_package,
                                                 v_module,
                                                 g_failure_status,
                                                 SQLCODE,
                                                  'ERROR - '
                                                 || SUBSTR (SQLERRM, 1, 100)
                                                );


END p_process_invoice_hold;


   PROCEDURE process_pcard_exp_inv (p_request_id IN NUMBER)
   IS
      v_invoice_id             NUMBER;
      v_inv_count              NUMBER;
      p_batch_error_flag       VARCHAR2 (100);
      p_invoices_fetched       NUMBER;
      p_invoices_created       NUMBER;
      p_total_invoice_amount   NUMBER;
      p_print_batch            VARCHAR2 (100);
      p_debug_switch           VARCHAR2 (1)    := 'N';
      p_calling_sequence       VARCHAR2 (30)   := 'process_p_card_exp_inv';
      p_source                 VARCHAR2 (100)  := 'SelfService';
      v_org_id                 NUMBER;
      p_group_id               VARCHAR2 (1000)
                                           := CAST (p_request_id AS VARCHAR2);
      e_batch_failure          EXCEPTION;
      v_err_msg                VARCHAR2 (1000);
      v_module                 VARCHAR2 (30)   := 'process_p_card_exp_inv';
      v_loc                    VARCHAR2 (250)
                                           := CAST (p_request_id AS VARCHAR2);
      p_req_id                 NUMBER;

      v_template_id            NUMBER;
      p_exp_expo_request_id    NUMBER :=p_request_id ;
      p_checkrun_id            NUMBER;

      v_inv_rej_cnt            NUMBER;
      v_inv_vld                VARCHAR2(10);

      v_approval_status        VARCHAR(20);
      v_approval_flag          VARCHAR(1) :='Y';
      v_ou_name                VARCHAR2(100);


      CURSOR c_pcard_pmt_req_inv (l_request_id IN NUMBER)
      IS
         SELECT ai.*
           FROM ap_expense_report_headers_all exph,
                ap_invoices_all ai,
                ap_expense_reports_all expr,
                fnd_lookup_values flv
          WHERE exph.request_id = l_request_id
            AND exph.invoice_num = ai.invoice_num
            AND UPPER (ai.invoice_type_lookup_code) = 'PAYMENT REQUEST'
            AND expr.expense_report_id = exph.expense_report_id
            AND UPPER(expr.report_type)=flv.lookup_code
            AND flv.lookup_type='TTEC_PCARD_TEMPLATE_MAP'
            AND flv.language='US'
            AND flv.enabled_flag='Y';


      CURSOR c_pcard_exp_inv_lines (p_invoice_id IN NUMBER, p_org_id IN NUMBER)
      IS
         SELECT *
           FROM ap_invoice_lines_all
          WHERE invoice_id = p_invoice_id AND org_id = p_org_id;

      CURSOR c_inv_vld_chk(p_request_id IN NUMBER,p_org_id IN NUMBER)
      IS
             SELECT *
              FROM ap_invoices_all aia1
                 WHERE EXISTS (
                               SELECT 1
                              FROM ap_expense_report_headers_all exph,
                                   ap_invoices_all aia2,
                                   ap_expense_reports_all expr,
                                   fnd_lookup_values flv
                                 WHERE  exph.request_id = p_request_id
                                  AND exph.invoice_num = aia2.invoice_num
                                  AND UPPER (aia2.invoice_type_lookup_code) = 'PAYMENT REQUEST'
                                  AND expr.expense_report_id = exph.expense_report_id
                                                 AND UPPER (expr.report_type) = flv.lookup_code
                                                 AND flv.lookup_type = 'TTEC_PCARD_TEMPLATE_MAP'
                                                 AND flv.LANGUAGE = 'US'
                                                 AND flv.enabled_flag = 'Y'
                                  AND aia2.reference_key1 = aia1.reference_key1)
                 AND UPPER (pay_group_lookup_code) = 'PCARD';

      CURSOR c_inv_process_org(p_request_id IN NUMBER)
        IS
          SELECT distinct ai.org_id
           FROM ap_expense_report_headers_all exph,
                ap_invoices_all ai,
                ap_expense_reports_all expr,
                fnd_lookup_values flv
          WHERE exph.request_id = p_request_id
            AND exph.invoice_num = ai.invoice_num
            AND UPPER (ai.invoice_type_lookup_code) = 'PAYMENT REQUEST'
            AND expr.expense_report_id = exph.expense_report_id
            AND UPPER(expr.report_type)=flv.lookup_code
            AND flv.lookup_type='TTEC_PCARD_TEMPLATE_MAP'
            AND flv.language='US'
            AND flv.enabled_flag='Y';  -- pcard payment request invoices processed OU's

   BEGIN
      SELECT fnd_global.org_id -- to get org_id
        INTO v_org_id
        FROM DUAL;

      /* -------------------------------------------------------------------
      fetch the payment request type invoices processed by export process,
      to update pay group lookup code
      -----------------------------------------------------------------------*/
      FOR rec IN c_pcard_pmt_req_inv (p_request_id)
      LOOP
         BEGIN
            IF rec.pay_group_lookup_code <> 'PCARD'
            THEN

               UPDATE ap_invoices_all
                  SET pay_group_lookup_code = 'PCARD'
                WHERE invoice_num = rec.invoice_num
                  AND org_id = rec.org_id
                  AND invoice_type_lookup_code = rec.invoice_type_lookup_code;

               COMMIT;
            END IF;
         EXCEPTION
            WHEN OTHERS
            THEN
               ttec_error_logging.process_error (g_application_code,
                                                 g_interface,
                                                 g_package,
                                                 v_module,
                                                 g_failure_status,
                                                 SQLCODE,
                                                    'In Pay group update - '
                                                 || SUBSTR (SQLERRM, 1, 100),
                                                 g_label1,
                                                 v_loc
                                                );
         END;


         /* ---------------------------------------------------------------------
            START : populate ap interface tables to generate credit/expense report type invoices and standard/mixed type invoices
            for payment request expenses
            ----------------------------------------------------------------------*/
       FOR i in 1..2
       LOOP  --  1 - credit/expense report case,2 - standard/mixed type invoices case

          IF i=2 AND SIGN (rec.invoice_amount)= -1 THEN -- This condition is added to restrict creation of MIXED type invoices per change
          EXIT;

          END IF;

          BEGIN

             SELECT ap_invoices_interface_s.NEXTVAL  -- fetching invoice_id for respective invoice type
                     INTO v_invoice_id
                    FROM DUAL;

            INSERT INTO ap_invoices_interface
                        (invoice_id,
                         invoice_num,
                         invoice_type_lookup_code,
                         invoice_date,
                         vendor_id,
                         vendor_site_id,
                         invoice_amount,
                         invoice_currency_code,
                         exchange_rate,
                         exchange_rate_type,
                         exchange_date,
                         terms_id,
                         description,
                         awt_group_id,
                         last_update_date,
                         last_updated_by,
                         last_update_login,
                         creation_date,
                         created_by,
                         attribute_category,
                         attribute1,
                         attribute2,
                         attribute3,
                         attribute4,
                         attribute5,
                         attribute6,
                         attribute7,
                         attribute8,
                         attribute9,
                         attribute10,
                         attribute11,
                         attribute12,
                         attribute13,
                         attribute14,
                         attribute15,
                         global_attribute_category,
                         global_attribute1,
                         global_attribute2,
                         global_attribute3,
                         global_attribute4,
                         global_attribute5,
                         global_attribute6,
                         global_attribute7,
                         global_attribute8,
                         global_attribute9,
                         global_attribute10,
                         global_attribute11,
                         global_attribute12,
                         global_attribute13,
                         global_attribute14,
                         global_attribute15,
                         global_attribute16,
                         global_attribute17,
                         global_attribute18,
                         global_attribute19,
                         global_attribute20,
                         SOURCE,
                         GROUP_ID,
                         payment_method_lookup_code,
                         pay_group_lookup_code,
                         gl_date,
                         accts_pay_code_combination_id,
                         ussgl_transaction_code,
                         exclusive_payment_flag,
                         org_id,
                         amount_applicable_to_discount,
                         payment_cross_rate_type,
                         payment_cross_rate_date,
                         payment_cross_rate,
                         payment_currency_code,
                         terms_date,
                         requester_id,
                         application_id,
                         product_table,
                         reference_key1,
                         reference_key2,
                         reference_key3,
                         reference_key4,
                         reference_key5,
                         tax_related_invoice_id,
                         document_sub_type,
                         supplier_tax_invoice_number,
                         supplier_tax_invoice_date,
                         supplier_tax_exchange_rate,
                         tax_invoice_recording_date,
                         tax_invoice_internal_seq,
                         legal_entity_id,
                         reference_1,
                         reference_2,
                         bank_charge_bearer,
                         remittance_message1,
                         remittance_message2,
                         remittance_message3,
                         unique_remittance_identifier,
                         uri_check_digit,
                         settlement_priority,
                         payment_reason_code,
                         payment_reason_comments,
                         payment_method_code,
                         delivery_channel_code,
                         paid_on_behalf_employee_id,
                         cust_registration_code,
                         cust_registration_number,
                         party_id,
                         party_site_id,
                         payment_function,
                         port_of_entry_code,
                         external_bank_account_id,
                         pay_awt_group_id,
                         original_invoice_amount,
                         dispute_reason,
                         remit_to_supplier_name,
                         remit_to_supplier_id,
                         remit_to_supplier_site,
                         remit_to_supplier_site_id,
                         relationship_id
                        )
                 VALUES (v_invoice_id,
                         DECODE(i,1,SUBSTR (rec.invoice_num,
                                    1,
                                    INSTR (rec.invoice_num, '.', 1, 1)
                                   )
                         || '2',
                         2,SUBSTR (rec.invoice_num,
                                    1,
                                    INSTR (rec.invoice_num, '.', 1, 1)
                                   )
                         || '3'), -- 1 - credit/expense report, 2- standard/mixed
                         DECODE( i,1,(DECODE (SIGN (rec.invoice_amount),
                                 -1, 'EXPENSE REPORT',
                                 'CREDIT'
                                )),
                                 2,(DECODE (SIGN (rec.invoice_amount),
                                 -1, 'MIXED',
                                 'STANDARD'
                                ))),  -- 1 - credit/expense report, 2- standard/mixed
                         rec.invoice_date,
                         rec.vendor_id,
                         rec.vendor_site_id,
                         DECODE(i,1,rec.invoice_amount * (-1),
                         2,rec.invoice_amount), -- 1- offset,2- same type,
                         rec.invoice_currency_code,
                         rec.exchange_rate,
                         rec.exchange_rate_type,
                         rec.exchange_date,
                         rec.terms_id,
                         rec.description,
                         rec.awt_group_id,
                         SYSDATE,
                         rec.last_updated_by,
                         rec.last_update_login,
                         SYSDATE,
                         rec.created_by,
                         rec.attribute_category,
                         rec.attribute1,
                         rec.attribute2,
                         rec.attribute3,
                         rec.attribute4,
                         rec.attribute5,
                         rec.attribute6,
                         rec.attribute7,
                         rec.attribute8,
                         rec.attribute9,
                         rec.attribute10,
                         rec.attribute11,
                         rec.attribute12,
                         rec.attribute13,
                         rec.attribute14,
                         rec.attribute15,
                         rec.global_attribute_category,
                         rec.global_attribute1,
                         rec.global_attribute2,
                         rec.global_attribute3,
                         rec.global_attribute4,
                         rec.global_attribute5,
                         rec.global_attribute6,
                         rec.global_attribute7,
                         rec.global_attribute8,
                         rec.global_attribute9,
                         rec.global_attribute10,
                         rec.global_attribute11,
                         rec.global_attribute12,
                         rec.global_attribute13,
                         rec.global_attribute14,
                         rec.global_attribute15,
                         rec.global_attribute16,
                         rec.global_attribute17,
                         rec.global_attribute18,
                         rec.global_attribute19,
                         rec.global_attribute20,
                         rec.SOURCE,
                         p_group_id,
                         rec.payment_method_lookup_code,
                          DECODE (i,1,'PCARD',
                                    2,'PCARD-PREPAY'), -- 1- credit/expense report, 2- standard/mixed
                         rec.gl_date,
                         rec.accts_pay_code_combination_id,
                         rec.ussgl_transaction_code,
                         rec.exclusive_payment_flag,
                         rec.org_id,
                         DECODE(i,1,rec.amount_applicable_to_discount * (-1),
                                  2, rec.amount_applicable_to_discount
                                ),  -- 1- offset,2- same type
                         rec.payment_cross_rate_type,
                         rec.payment_cross_rate_date,
                         rec.payment_cross_rate,
                         rec.payment_currency_code,
                         rec.terms_date,
                         rec.requester_id,
                         rec.application_id,
                         rec.product_table,
                         rec.reference_key1,
                         rec.reference_key2,
                         rec.reference_key3,
                         rec.reference_key4,
                         rec.reference_key5,
                         rec.tax_related_invoice_id,
                         rec.document_sub_type,
                         rec.supplier_tax_invoice_number,
                         rec.supplier_tax_invoice_date,
                         rec.supplier_tax_exchange_rate,
                         rec.tax_invoice_recording_date,
                         rec.tax_invoice_internal_seq,
                         rec.legal_entity_id,
                         rec.reference_1,
                         rec.reference_2,
                         rec.bank_charge_bearer,
                         rec.remittance_message1,
                         rec.remittance_message2,
                         rec.remittance_message3,
                         rec.unique_remittance_identifier,
                         rec.uri_check_digit,
                         rec.settlement_priority,
                         rec.payment_reason_code,
                         rec.payment_reason_comments,
                         rec.payment_method_code,
                         rec.delivery_channel_code,
                         rec.paid_on_behalf_employee_id,
                         rec.cust_registration_code,
                         rec.cust_registration_number,
                         rec.party_id,
                         rec.party_site_id,
                         rec.payment_function,
                         rec.port_of_entry_code,
                         rec.external_bank_account_id,
                         rec.pay_awt_group_id,
                         rec.original_invoice_amount,
                         rec.dispute_reason,
                         rec.remit_to_supplier_name,
                         rec.remit_to_supplier_id,
                         rec.remit_to_supplier_site,
                         rec.remit_to_supplier_site_id,
                         rec.relationship_id
                        );

            FOR expl IN c_pcard_exp_inv_lines (rec.invoice_id, rec.org_id)
            LOOP

               INSERT INTO ap_invoice_lines_interface
                           (invoice_id,
                            invoice_line_id,
                            line_number,
                            line_type_lookup_code,
                            line_group_number,
                            amount,
                            accounting_date,
                            description,
                            final_match_flag,
                            po_header_id,
                            po_line_id,
                            po_line_location_id,
                            po_distribution_id,
                            inventory_item_id,
                            item_description,
                            quantity_invoiced,
                            unit_price,
                            distribution_set_id,
                            awt_group_id,
                            last_updated_by,
                            last_update_date,
                            last_update_login,
                            created_by,
                            creation_date,
                            attribute_category,
                            attribute1,
                            attribute2,
                            attribute3,
                            attribute4,
                            attribute5,
                            attribute6,
                            attribute7,
                            attribute8,
                            attribute9,
                            attribute10,
                            attribute11,
                            attribute12,
                            attribute13,
                            attribute14,
                            attribute15,
                            global_attribute_category,
                            global_attribute1,
                            global_attribute2,
                            global_attribute3,
                            global_attribute4,
                            global_attribute5,
                            global_attribute6,
                            global_attribute7,
                            global_attribute8,
                            global_attribute9,
                            global_attribute10,
                            global_attribute11,
                            global_attribute12,
                            global_attribute13,
                            global_attribute14,
                            global_attribute15,
                            global_attribute16,
                            global_attribute17,
                            global_attribute18,
                            global_attribute19,
                            global_attribute20,
                            balancing_segment,
                            cost_center_segment,
                            account_segment,
                            project_id,
                            task_id,
                            expenditure_type,
                            expenditure_item_date,
                            expenditure_organization_id,
                            pa_quantity,
                            ussgl_transaction_code,
                            stat_amount,
                            type_1099,
                            income_tax_region,
                            assets_tracking_flag,
                            org_id,
                            pa_cc_ar_invoice_id,
                            pa_cc_ar_invoice_line_num,
                            reference_1,
                            reference_2,
                            pa_cc_processed_code,
                            tax_code_id,
                            credit_card_trx_id,
                            award_id,
                            serial_number,
                            manufacturer,
                            model_number,
                            warranty_number,
                            def_acctg_start_date,
                            def_acctg_end_date,
                            def_acctg_number_of_periods,
                            def_acctg_period_type,
                            asset_category_id,
                            requester_id,
                            application_id,
                            product_table,
                            reference_key1,
                            reference_key2,
                            reference_key3,
                            reference_key4,
                            reference_key5,
                            purchasing_category_id,
                            cost_factor_id,
                            control_amount,
                            assessable_value,
                            default_dist_ccid,
                            primary_intended_use,
                            ship_to_location_id,
                            product_type,
                            product_category,
                            product_fisc_classification,
                            user_defined_fisc_class,
                            tax,
                            tax_jurisdiction_code,
                            tax_status_code,
                            tax_rate_id,
                            tax_rate_code,
                            tax_rate,
                            source_application_id,
                            source_trx_id,
                            source_line_id,
                            source_trx_level_type,
                            tax_classification_code,
                            cc_reversal_flag,
                            company_prepaid_invoice_id,
                            expense_group,
                            justification,
                            merchant_document_number,
                            merchant_name,
                            merchant_reference,
                            merchant_taxpayer_id,
                            merchant_tax_reg_number,
                            receipt_conversion_rate,
                            receipt_currency_amount,
                            receipt_currency_code,
                            country_of_supply,
                            pay_awt_group_id,
                            dist_code_combination_id
                           )
                    VALUES (v_invoice_id,
                            ap_invoice_lines_interface_s.NEXTVAL,
                            expl.line_number,
                            expl.line_type_lookup_code,
                            expl.line_group_number,
                            DECODE(i,1,expl.amount * (-1),
                                                               2,expl.amount), -- 1- credit/expense report, 2- standard/mixed
                            expl.accounting_date,
                            expl.description,
                            expl.final_match_flag,
                            expl.po_header_id,
                            expl.po_line_id,
                            expl.po_line_location_id,
                            expl.po_distribution_id,
                            expl.inventory_item_id,
                            expl.item_description,
                            expl.quantity_invoiced,
                            expl.unit_price,
                            expl.distribution_set_id,
                            expl.awt_group_id,
                            expl.last_updated_by,
                            SYSDATE,
                            expl.last_update_login,
                            expl.created_by,
                            SYSDATE,
                            expl.attribute_category,
                            expl.attribute1,
                            expl.attribute2,
                            expl.attribute3,
                            expl.attribute4,
                            expl.attribute5,
                            expl.attribute6,
                            expl.attribute7,
                            expl.attribute8,
                            expl.attribute9,
                            expl.attribute10,
                            expl.attribute11,
                            expl.attribute12,
                            expl.attribute13,
                            expl.attribute14,
                            expl.attribute15,
                            expl.global_attribute_category,
                            expl.global_attribute1,
                            expl.global_attribute2,
                            expl.global_attribute3,
                            expl.global_attribute4,
                            expl.global_attribute5,
                            expl.global_attribute6,
                            expl.global_attribute7,
                            expl.global_attribute8,
                            expl.global_attribute9,
                            expl.global_attribute10,
                            expl.global_attribute11,
                            expl.global_attribute12,
                            expl.global_attribute13,
                            expl.global_attribute14,
                            expl.global_attribute15,
                            expl.global_attribute16,
                            expl.global_attribute17,
                            expl.global_attribute18,
                            expl.global_attribute19,
                            expl.global_attribute20,
                            expl.balancing_segment,
                            expl.cost_center_segment,
                            expl.account_segment,
                            expl.project_id,
                            expl.task_id,
                            expl.expenditure_type,
                            expl.expenditure_item_date,
                            expl.expenditure_organization_id,
                            expl.pa_quantity,
                            expl.ussgl_transaction_code,
                            expl.stat_amount,
                            expl.type_1099,
                            expl.income_tax_region,
                            expl.assets_tracking_flag,
                            expl.org_id,
                            expl.pa_cc_ar_invoice_id,
                            expl.pa_cc_ar_invoice_line_num,
                            expl.reference_1,
                            expl.reference_2,
                            expl.pa_cc_processed_code,
                            expl.tax_code_id,
                            expl.credit_card_trx_id,
                            expl.award_id,
                            expl.serial_number,
                            expl.manufacturer,
                            expl.model_number,
                            expl.warranty_number,
                            expl.def_acctg_start_date,
                            expl.def_acctg_end_date,
                            expl.def_acctg_number_of_periods,
                            expl.def_acctg_period_type,
                            expl.asset_category_id,
                            expl.requester_id,
                            expl.application_id,
                            expl.product_table,
                            expl.reference_key1,
                            expl.reference_key2,
                            expl.reference_key3,
                            expl.reference_key4,
                            expl.reference_key5,
                            expl.purchasing_category_id,
                            expl.cost_factor_id,
                            expl.control_amount,
                            expl.assessable_value,
                            expl.default_dist_ccid,
                            expl.primary_intended_use,
                            expl.ship_to_location_id,
                            expl.product_type,
                            expl.product_category,
                            expl.product_fisc_classification,
                            expl.user_defined_fisc_class,
                            expl.tax,
                            expl.tax_jurisdiction_code,
                            expl.tax_status_code,
                            expl.tax_rate_id,
                            expl.tax_rate_code,
                            expl.tax_rate,
                            expl.source_application_id,
                            expl.source_trx_id,
                            expl.source_line_id,
                            expl.source_trx_level_type,
                            expl.tax_classification_code,
                            expl.cc_reversal_flag,
                            expl.company_prepaid_invoice_id,
                            expl.expense_group,
                            expl.justification,
                            expl.merchant_document_number,
                            expl.merchant_name,
                            expl.merchant_reference,
                            expl.merchant_taxpayer_id,
                            expl.merchant_tax_reg_number,
                            expl.receipt_conversion_rate,
                            expl.receipt_currency_amount,
                            expl.receipt_currency_code,
                            expl.country_of_supply,
                            expl.pay_awt_group_id,
                            expl.default_dist_ccid
                           );
            END LOOP;



            COMMIT;

             EXCEPTION
            WHEN OTHERS
            THEN

               ttec_error_logging.process_error (g_application_code,
                                                 g_interface,
                                                 g_package,
                                                 v_module,
                                                 g_failure_status,
                                                 SQLCODE,
                                                 SUBSTR (SQLERRM, 1, 100),
                                                 'ERROR INSERT AP INTERFACE - INVOICE NUM',
                                                 rec.invoice_num
                                                );


               END;
         END LOOP;
      END LOOP;




      /* ---------------------------------------------------------------------
          END : populate ap interface tables to generate credit/expense report type invoices and standard/mixed type invoices
                for payment request expenses
         ----------------------------------------------------------------------*/



      /* ---Call Payables Open Interface Import to process all the invoices for group_id
      --------------------------------------*/
      BEGIN
         SELECT COUNT (*)
           INTO v_inv_count
           FROM ap_invoices_interface
          WHERE GROUP_ID = p_group_id;

         IF v_inv_count > 0
         THEN

            IF (NOT ap_import_invoices_pkg.import_invoices
                                                      (TO_CHAR (''),
                                                       TO_CHAR (''),
                                                       TO_CHAR (''),
                                                       TO_CHAR (''),
                                                       99999999,
                                                       p_source,
                                                       p_group_id,
                                                       p_request_id,
                                                       p_debug_switch,
                                                       TO_CHAR (''),
                                                       p_batch_error_flag,
                                                       p_invoices_fetched,
                                                       p_invoices_created,
                                                       p_total_invoice_amount,
                                                       p_print_batch,
                                                       p_calling_sequence
                                                      )
               )
            THEN
               RAISE e_batch_failure;
            END IF;
         END IF;
      EXCEPTION
         WHEN e_batch_failure
         THEN
            ttec_error_logging.process_error
                   (g_application_code,
                    g_interface,
                    g_package,
                    v_module,
                    g_failure_status,
                    SQLCODE,
                    'Call to AP_IMPORT_INVOICES_PKG.IMPORT_INVOICES failed.',
                    g_label1,
                    v_loc
                   );
         WHEN OTHERS
         THEN
            ttec_error_logging.process_error (g_application_code,
                                              g_interface,
                                              g_package,
                                              v_module,
                                              g_failure_status,
                                              SQLCODE,
                                              SUBSTR (SQLERRM, 1, 100),
                                              g_label1,
                                              v_loc
                                             );
      END;

                    --  start : submit fallout report
              --  end :  submit fallout report

     FOR rec in c_inv_process_org(p_request_id) LOOP
      -- start: fetching payment request invoices for which credit/expense report invoices not generated.
        BEGIN

       /*   SELECT COUNT(invoice_id)
            INTO v_inv_rej_cnt
           FROM AP_INVOICES_INTERFACE
           WHERE group_id=p_group_id
            AND org_id=rec.org_id
			and invoice_type_lookup_code in ('PAYMENT REQUEST','CREDIT')
			and invoice_num not like 'PCP%'
			--AND status = 'REJECTED';
            --AND status in ('REJECTED','PROCESSED');
		*/
        -- IF v_inv_rej_cnt>0 THEN

        p_process_invoice_hold(rec.org_id,p_request_id,'H');

        --END IF;


        EXCEPTION WHEN OTHERS THEN
                       ttec_error_logging.process_error (g_application_code,
                                              g_interface,
                                              g_package,
                                              v_module,
                                              g_failure_status,
                                              SQLCODE,
                                              'error calling process invoice hold'||SUBSTR (SQLERRM, 1, 100),
                                              g_label1,
                                              v_loc
                                             );

        END;

      -- end : feteching paymene request invoices for which credit/expene report invoices not generated.

         -- Start:Run Invoice Validation Program
          p_submit_conc_program(rec.org_id,'VALIDATION',p_req_id);
         -- End : Run Invoice Validation Program

         -- Start: Run Create Accounting Program
          p_submit_conc_program(rec.org_id,'ACCOUNTING',p_req_id);
         -- End : Run Create Accounting Program

         -- Start : Run Payment Batch Process

   /*    BEGIN

         BEGIN

                FOR chk IN c_inv_vld_chk(p_request_id,rec.org_id) LOOP

                  SELECT APPS.AP_INVOICES_PKG.GET_APPROVAL_STATUS
                               (
                                   aia.INVOICE_ID
                                  ,aia.INVOICE_AMOUNT
                                  ,aia.PAYMENT_STATUS_FLAG
                                  ,aia.INVOICE_TYPE_LOOKUP_CODE
                               )
                           INTO v_approval_status
                              FROM   ap_invoices_all aia
                            WHERE  invoice_num = chk.invoice_num
                               AND org_id=rec.org_id
                               AND UPPER (pay_group_lookup_code) = 'PCARD';

                        IF v_approval_status<>'APPROVED'
                        THEN
                            v_approval_flag:='N';
                         EXIT;
                        END IF;

                END LOOP;

         EXCEPTION WHEN OTHERS THEN
                  ttec_error_logging.process_error (g_application_code,
                                                    g_interface,
                                                    g_package,
                                                    v_module,
                                                    g_failure_status,
                                                    SQLCODE,
                                                    SUBSTR (SQLERRM, 1, 100),
                                                   'error retrieving approval status',
                                                   'in processing invoices of export request - '||p_request_id
                                                   );
                            v_approval_flag:='N';

         END;

        IF v_approval_flag='Y' THEN

             SELECT apt.template_id
                INTO v_template_id
              FROM ap_payment_templates apt, ap_ou_group aptou
                WHERE template_name LIKE '%-PCARD-%'
                  AND inactive_date IS NULL
                  AND ou_group_option = 'SPECIFY'
                  AND apt.template_id = aptou.template_id
                  AND apt.template_type = 'PCARD'
                  AND aptou.org_id = rec.org_id;

        p_submit_ppr( p_checkrun_id ,v_template_id ,p_exp_expo_request_id );

        END IF;

       EXCEPTION WHEN OTHERS THEN
         ttec_error_logging.process_error (g_application_code,
                                           g_interface,
                                           g_package,
                                           v_module,
                                           g_failure_status,
                                           SQLCODE,
                                           SUBSTR (SQLERRM, 1, 100),
                                           'error while call to PPR proc',
                                           'peocessing for expense requst_id '||p_request_id
                                          );


       END;

       -- End : Run Payment Batch Process
*/
     END LOOP;


	  -- start : purge records from interface
                 p_purge_records(p_group_id);
      -- end :  purge records from interface

   EXCEPTION
      WHEN OTHERS
      THEN
         ttec_error_logging.process_error (g_application_code,
                                           g_interface,
                                           g_package,
                                           v_module,
                                           g_failure_status,
                                           SQLCODE,
                                           SUBSTR (SQLERRM, 1, 100),
                                           g_label1,
                                           v_loc
                                          );
   END process_pcard_exp_inv;
END ttec_pcard_exp_inv_process;
/
show errors;
/