create or replace PACKAGE      TTEC_PCARD_INV_PAY_PROCESS
/*****************************************************************************************************************************************
  PROGRAM NAME:   TTEC_PCARD_INV_PAY_PROCESS (TeleTech Pcard Processing of Invoices and Payments)
  DESCRIPTION:    This Package will release holds on Payment Request and CM. Validate, Account invoices and submit Payment Process Request
				  using PCARD NO PAY template(hold's placed by TTEC_PCARD_EXP_INV_PROCESS package).

  MODIFICATION LOG
  ----------------
  DEVELOPER             DATE          DESCRIPTION
  -------------------   ------------  -----------------------------------------
  Hema C / Anurag K  	22-Nov-2017   Initial Version 1.0
  RXNETHI-ARGANO        17-JUL-2023   R12.2 Upgrade Remediation ****************************************************************************************************************************************/
AS

   /*
   START R12.2 Upgrade Remediaiton
   code commented by RXNETHI-ARGANO,17/07/23
   g_application_code    cust.ttec_error_handling.application_code%TYPE := 'AP';

   g_interface           cust.ttec_error_handling.INTERFACE%TYPE := 'Pcard Interface';

   g_package             cust.ttec_error_handling.program_name%TYPE  := 'TTEC_PCARD_INV_PAY_PROCESS';

   g_label1              cust.ttec_error_handling.label1%TYPE := 'error processing expense invoices of request id';

   g_failure_status      cust.ttec_error_handling.status%TYPE    := 'FAILURE';
   */
   --code added by RXNETHI-ARGANO,17/07/23
   g_application_code    apps.ttec_error_handling.application_code%TYPE := 'AP';

   g_interface           apps.ttec_error_handling.INTERFACE%TYPE := 'Pcard Interface';

   g_package             apps.ttec_error_handling.program_name%TYPE  := 'TTEC_PCARD_INV_PAY_PROCESS';

   g_label1              apps.ttec_error_handling.label1%TYPE := 'error processing expense invoices of request id';

   g_failure_status      apps.ttec_error_handling.status%TYPE    := 'FAILURE';
   --END R12.2 Upgrade Remediation

PROCEDURE main(errbuf OUT VARCHAR2, retcode OUT NUMBER, p_org_id IN NUMBER);

PROCEDURE process_pcard_ppr (p_org_id IN NUMBER);

PROCEDURE pcard_unprocess_notif (lv_invoice_list IN VARCHAR2);

FUNCTION ttec_send_email(p_email_to   VARCHAR2,
                               p_email_from VARCHAR2,
                               p_file_name  VARCHAR2,
                               p_subject    VARCHAR2,
                               p_body       VARCHAR2)
      RETURN NUMBER;

END TTEC_PCARD_INV_PAY_PROCESS;
/
show errors;
/