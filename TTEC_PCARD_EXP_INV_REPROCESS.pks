create or replace PACKAGE      TTEC_PCARD_EXP_INV_REPROCESS AS
/*$Header:   APPS.TTEC_PCARD_EXP_INV_REPROCESS 1.0 25-JUN-2020
== START =======================================================================

         AUTHOR:  Rajesh Koneru
         DATE:  06/25/2020
         PROGRAM NAME:   TTEC_PCARD_EXP_INV_REPROCESS
         DESCRIPTION:    This package re-processes the P-Card expense payment request type invoices.

       Modification History:

      Version    Date          Author      Description (Include Ticket#)
      -----     -------------  --------    ------------------------------------
      1.0        25-JUN-2020   Rajesh        Draft version (TASK1463571)

   == END ======================================================================*/

   g_application_code    cust.ttec_error_handling.application_code%TYPE := 'AP';

   g_interface           cust.ttec_error_handling.INTERFACE%TYPE := 'Pcard Interface';

   g_package             cust.ttec_error_handling.program_name%TYPE  := 'TTEC_PCARD_EXP_INV_PROCESS';

   g_label1              cust.ttec_error_handling.label1%TYPE := 'error processing expense invoices of request id';

   g_failure_status      cust.ttec_error_handling.status%TYPE    := 'FAILURE';


 PROCEDURE process_pcard_exp_inv (ERRBUF out varchar2,
   RETCODE  out varchar2,
   p_start_date IN VARCHAR2,
   p_end_date IN VARCHAR2,
   p_accounting_date IN VARCHAR2);

end TTEC_PCARD_EXP_INV_REPROCESS;