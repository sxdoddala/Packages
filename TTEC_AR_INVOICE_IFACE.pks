create or replace PACKAGE      ttec_ar_invoice_iface AUTHID CURRENT_USER
AS
/* $Header: TTEC_AR_INVOICE_IFACE.pks 1.0 2010/06/07 mdodge ship $ */

   /*== START ================================================================================================*\
      Author: Michelle Dodge
        Date: 06/07/2010
   Call From: 'TeleTech AR Invoice Interface' & 'TeleTech AR Invoice Interface File Load'
        Desc: This package containes all PL/SQL code necessary for the 'TeleTech AR Excel Upload to AutoInvoice
              Interface Tables' customization.

              The build_org_dir function is called by the 'TeleTech AR Invoice Interface File Load' CP to build
              the Org Directory name (used on Unix and Maple for placing the files) from the input Organization ID.

              The conc_mgr_wrapper procedure is called by the 'TeleTech AR Invoice Interface' CP.  It is mainly
              responsibility for creating the process report and log and returning the final status to the
              concurrent manager. It calls the main procedure to process the data loaded into the staging tables
              into the Interface tables.

     Modification History:

    Version    Date     Author   Description (Include Ticket#)
    -------  --------  --------  ------------------------------------------------------------------------------
        1.0  06/07/10  MDodge    R192314 - AR AutoInvoice for Excel Invoices - Initial Version
        1.1  07/16/14  Kbabu     TASK0062034 - Added new parameter Transaction source and also removed default values for transaction source and transaction type
        2.5  01/05/16  CHCHAN    2016 AR Invoice Interface Enhancement -  Add new parameter called -Change Receivable Account Client Code
                                                                          with default value 'No'
        2.7  08/08/17  CHCHAN    2017 AR Invoice Interface Enhancement -  Adding BUSINESS_NAME, REFERENCE1 and REFERENCE2 (Condor Add on)
        2.8  08/21/17  CHCHAN                                          - Adding GL Location Override on Receivales Account
		1.0  04/05/23  RXNETHI-ARGANO    R12.2 Upgrade Remediation
   \*== END ==================================================================================================*/

   -- Error Constants
   /*
   START R12.2 Upgrade Remediation
   code commented by RXNETHI-ARGANO,04/05/23
   g_application_code   cust.ttec_error_handling.application_code%TYPE
                                                                      := 'AR';
   g_interface          cust.ttec_error_handling.INTERFACE%TYPE
                                                            := 'AR Inv Iface';
   g_package            cust.ttec_error_handling.program_name%TYPE
                                                   := 'TTEC_AR_INVOICE_IFACE';
   g_warning_status     cust.ttec_error_handling.status%TYPE     := 'WARNING';
   g_error_status       cust.ttec_error_handling.status%TYPE       := 'ERROR';
   g_failure_status     cust.ttec_error_handling.status%TYPE     := 'FAILURE';
   g_gl_clt_override    varchar2(01) := '';
   g_gl_loc_override    ar.ra_interface_distributions_all.SEGMENT1%Type := ''; /* 2.8*/
--   */
   --code added by RXNETHI-ARGANO,04/05/23
   g_application_code   apps.ttec_error_handling.application_code%TYPE
                                                                      := 'AR';
   g_interface          apps.ttec_error_handling.INTERFACE%TYPE
                                                            := 'AR Inv Iface';
   g_package            apps.ttec_error_handling.program_name%TYPE
                                                   := 'TTEC_AR_INVOICE_IFACE';
   g_warning_status     apps.ttec_error_handling.status%TYPE     := 'WARNING';
   g_error_status       apps.ttec_error_handling.status%TYPE       := 'ERROR';
   g_failure_status     apps.ttec_error_handling.status%TYPE     := 'FAILURE';
   g_gl_clt_override    varchar2(01) := '';
   g_gl_loc_override    apps.ra_interface_distributions_all.SEGMENT1%Type := ''; /* 2.8*/
   --END R12.2 Upgrade Remediation
   

--
-- FUNCTION build_org_dir
--
-- Description: This function is called by the 'TeleTech AR Invoice Interface File Load' CP to build the Org
--              Directory name (used on Unix and Maple for placing the files) from the input Organization ID.
--
-- Arguments:
--   IN:      p_org_id     - Organization ID to build the Unix friendly Directory name
--   RETURN:  Organization Directory Name - used in file processing
--
   FUNCTION build_org_dir (p_org_id IN NUMBER)
      RETURN VARCHAR2;

--
-- PROCEDURE main
--
-- Description: This is the primary procedure for processing the data loaded into the staging tables and
--              inserting it into the Interface tables.
--
-- Arguments:
--   IN:      p_gl_date    - GL Date to use in creating new Interface Records
--
   PROCEDURE main (p_gl_date IN DATE,
                   p_batch_source_id IN VARCHAR2,
                   p_change_rec_acct_client_code IN VARCHAR2, --2.5
                   p_override_gl_loc IN VARCHAR2 --2.8
   );		-- 1.1

--
-- PROCEDURE conc_mgr_wrapper
--
-- Description: This is the front end process called by the Concurrent Manager.  It is responsible
--              for producing the Output and Log Files along with returning the final process status.
--              It calls the Main process to perform the actual data processing.
--
-- Arguments:
--   IN:      errbuf       - Standard Output parameter required for Concurrent Requests
--            retcode      - Standard Output parameter required for Concurrent Requests
--            p_gl_date    - GL Date to use in creating new Interface Records
--
   PROCEDURE conc_mgr_wrapper (
      errbuf              OUT      VARCHAR2,
      retcode             OUT      NUMBER,
      p_gl_date           IN       DATE,
      p_batch_source_id   IN       VARCHAR2,			-- 1.1
      p_change_rec_acct_client_code IN VARCHAR2, --2.5
      p_override_gl_loc IN VARCHAR2 --2.8
   );
END ttec_ar_invoice_iface;
/
show errors;
/