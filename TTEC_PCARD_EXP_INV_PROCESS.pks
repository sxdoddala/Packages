create or replace PACKAGE      TTEC_PCARD_EXP_INV_PROCESS AS
  /********************************************************************************
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
  Pratik Wandhare   28-Jul-2016   Initial Version 1.0
  IXPRAVEEN(ARGANO)  18-july-2023		R12.2 Upgrade Remediation
  ********************************************************************************/
  --START R12.2 Upgrade Remediation

   /*g_application_code    cust.ttec_error_handling.application_code%TYPE := 'AP';

   g_interface           cust.ttec_error_handling.INTERFACE%TYPE := 'Pcard Interface';

   g_package             cust.ttec_error_handling.program_name%TYPE  := 'TTEC_PCARD_EXP_INV_PROCESS';

   g_label1              cust.ttec_error_handling.label1%TYPE := 'error processing expense invoices of request id';

   g_failure_status      cust.ttec_error_handling.status%TYPE    := 'FAILURE';*/
   g_application_code    apps.ttec_error_handling.application_code%TYPE := 'AP';

   g_interface           apps.ttec_error_handling.INTERFACE%TYPE := 'Pcard Interface';

   g_package             apps.ttec_error_handling.program_name%TYPE  := 'TTEC_PCARD_EXP_INV_PROCESS';

   g_label1              apps.ttec_error_handling.label1%TYPE := 'error processing expense invoices of request id';

   g_failure_status      apps.ttec_error_handling.status%TYPE    := 'FAILURE';
   --END R12.2.12 Upgrade remediation

PROCEDURE process_pcard_exp_inv(
    p_request_id IN NUMBER
);

end TTEC_PCARD_EXP_INV_PROCESS;
/
show errors;
/