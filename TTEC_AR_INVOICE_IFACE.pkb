create or replace PACKAGE BODY      ttec_ar_invoice_iface
AS
/* $Header: TTEC_AR_INVOICE_IFACE.pkb 1.0 2010/06/07 mdodge ship $ */

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

     SPECIAL CONSIDERATIONS: This package contains special characters.  Please set
             NLS_LANG=AMERICAN_AMERICA.WE8ISO8859P1 prior to compiling in Unix.

     Modification History:

    Version    Date     Author   Description (Include Ticket#)
    -------  --------  --------  ------------------------------------------------------------------------------
        1.0  06/07/10  MDodge    R192314 - AR AutoInvoice for Excel Invoices - Initial Version
        2.0  10/18/10  JMASTERS  R317845 - Need to add Credit Memo's to the newly developed TeleTech AR Excel
                                           Import into AutoInvoice process
        2.1  10/29/10  MDodge    R317845 - 1. Added error handling to deal with fatal error on main cursor (bad data)
                                           2. Added error handling to deal with bad trx_date format
        2.2  11/17/10  MDodge    R317845 - Added valid_hdr and valid_line functions to validate loaded values for
                                           size, type or format violations.  Errors should occur within this process
                                           rather than the SQL*Loader process as they are easier to report and
                                           resolve.
        2.3  12/28/10  MDodge    I489218 - LPAD Line Numbers in INTERFACE_LINE_ATTRIBUTE2 with 0's to 3 digits to
                                           force proper line ordering (alphabetic) with the Ordering Rules.
        2.4  07/16/14  Kbabu     TASK0062034 - Added new parameter Transaction source and also removed default values
                                    for transaction source and transaction type
        2.5  01/05/16  CHCHAN    2016 AR Invoice Interface Enhancement -  Add new parameter called -Change Receivable Account Client Code
                                                                          with default value 'No'
        2.6  08/03/16  CHCHAN    2016 AR Invoice Interface Enhancement -  Adding REASON_CODE and TRANSLATED_DESCRIPTION

        2.7  08/08/17  CHCHAN    2017 AR Invoice Interface Enhancement -  Adding BUSINESS_NAME, REFERENCE1 and REFERENCE2 (Condor Add on)
        2.8  08/21/17  CHCHAN                                          - Adding GL Location Override on Receivales Account
        3.0  12/08/18  CHCHAN    Adding Service Now Ticket NO
        3.1  01/28/19  CHCHAN    Adding Period Average Rate of prvious month of the GL_DATE for Motif India -> 48618 and Motif PHL ORG-> 48458
        3.2  02/13/19  CHCHAN    changing the requirement to obtain Period Average Rate of prvious month of the TRX_DATE instead of GL_DATE for Motif India -> 48618 and Motif PHL ORG-> 48458
        3.3  02/18/19  CCHAN     Changing the requirement to obtain Period Average Rate of the period month the Invoice Date(TRX DATE)
        3.4  05/01/19  CTS       TASK1035166 - Changing the requirement to obtain Period Average Rate of the period month from the Serice Date value
        3.5  05/01/19  CTS       TASK1035166  - Added Active status condition for deriving client info get_client_info
        3.6  05/01/19  CTS       INC4952647   - added 5 digit for interface_line_attribute2 value (chnaged from 3 to 5 digit)
        1.0  05/MAY/23  RXNETHI-ARGANO R12.2 Upgrade Remediation
   \*== END ==================================================================================================================================*/

   -- Process Globals
   g_gl_date           DATE;
   g_client_id         NUMBER;
   g_site_id           NUMBER;
   g_rec_segment1      ra_interface_distributions_all.segment1%TYPE   := '';
   g_rec_segment2      ra_interface_distributions_all.segment2%TYPE   := '';
   g_rec_segment3      ra_interface_distributions_all.segment3%TYPE   := '';
   g_rec_segment4      ra_interface_distributions_all.segment4%TYPE   := '';
   g_rec_segment5      ra_interface_distributions_all.segment5%TYPE   := '';
   g_rec_segment6      ra_interface_distributions_all.segment6%TYPE   := '';
   -- Error Constants
   --g_label1            cust.ttec_error_handling.label1%TYPE := 'Err Location';    --code commented by RXNETHI-ARGANO,05/05/23
   g_label1            apps.ttec_error_handling.label1%TYPE := 'Err Location';      --code added by RXNETHI-ARGANO,05/05/23
   g_keep_days         NUMBER                                         := 7;
                                     -- Number of days to keep error logging.
   -- Process FAILURE variables
   g_fail_flag         BOOLEAN                                       := FALSE;
   g_fail_msg          VARCHAR2 (240);
   g_return_msg        VARCHAR2 (240)                                 := '';
   /* 3.3 */
   g_return_code       NUMBER                                         := 0;
   /* 3.3 */
   g_purge_days        NUMBER                                         := 30;
                                       -- Number of days to keep Staging data
   -- declare who columns
   g_request_id        NUMBER                   := fnd_global.conc_request_id;
   g_created_by        NUMBER                           := fnd_global.user_id;
   -- Global Count Variables for logging information
   g_invs_processed    NUMBER                                         := 0;
   g_lines_processed   NUMBER                                         := 0;
   g_lines_skipped     NUMBER                                         := 0;
   g_invs_errored      NUMBER                                         := 0;
   g_lines_errored     NUMBER                                         := 0;
   -- Working File System Filenames
   g_hdr_filename      VARCHAR2 (50)           := 'ttec_ar_inv_iface_hdr.txt';
   g_dtl_filename      VARCHAR2 (50)           := 'ttec_ar_inv_iface_dtl.txt';

   CURSOR c_ar_inv_hdr
   IS
      SELECT *                                                      /* 2.0 */
        FROM ttec_ar_inv_hdr_import_stg
       WHERE status = 'NEW';

   CURSOR c_ar_inv_line (p_hdr_id NUMBER)
   IS
      SELECT *
        FROM ttec_ar_inv_line_import_stg
       WHERE inv_hdr_id = p_hdr_id AND status = 'NEW';

/*********************************************************
**  Private Procedures and Functions
*********************************************************/
-- PROCEDURE valid_length         /* 2.2 */
--    Description: This function will validate if the field value is within the length
--                 restriction. It will return a FALSE if the length is too long,
--                 otherwise it will return TRUE.
   FUNCTION valid_length (
      p_hdr_rec    IN   c_ar_inv_hdr%ROWTYPE,
      p_line_rec   IN   c_ar_inv_line%ROWTYPE,
      p_field      IN   VARCHAR2,
      p_label      IN   VARCHAR2,
      p_length     IN   NUMBER
   )
      RETURN BOOLEAN
   IS
      --v_module   cust.ttec_error_handling.module_name%TYPE  := 'valid_length';    --code commented by RXNETHI-ARGANO,05/05/23
      v_module   apps.ttec_error_handling.module_name%TYPE  := 'valid_length';      --code added by RXNETHI-ARGANO,05/05/23
      v_loc      NUMBER;
   BEGIN
      v_loc := 10;

      IF LENGTHB (p_field) > p_length
      THEN
         v_loc := 20;
         ttec_error_logging.process_error (g_application_code,
                                           g_interface,
                                           g_package,
                                           v_module,
                                           g_warning_status,
                                           NULL,
                                              p_label
                                           || ' cannot exceed '
                                           || p_length
                                           || ' characters in length',
                                           'Org ID',
                                           p_hdr_rec.org_id,
                                           'FileName',
                                           p_hdr_rec.file_name,
                                           'Inv #',
                                           p_hdr_rec.trx_number,
                                           'Line #',
                                           p_line_rec.line_number,
                                           p_label,
                                           SUBSTRB (p_field, 1, 250)
                                          );
         RETURN FALSE;
      ELSE
         RETURN TRUE;
      END IF;
   EXCEPTION
      WHEN OTHERS
      THEN
         ttec_error_logging.process_error (g_application_code,
                                           g_interface,
                                           g_package,
                                           v_module,
                                           g_warning_status,
                                           SQLCODE,
                                           SQLERRM,
                                           g_label1,
                                           v_loc,
                                           'Org ID',
                                           p_hdr_rec.org_id,
                                           'FileName',
                                           p_hdr_rec.file_name,
                                           'Inv #',
                                           p_hdr_rec.trx_number,
                                           'Line #',
                                           p_line_rec.line_number
                                          );
         RETURN FALSE;
   END valid_length;

-- PROCEDURE valid_number         /* 2.2 */
--    Description: This function will validate if the field value is a numeric.
--                 It will return a TRUE if it is, otherwise a FALSE.
   FUNCTION valid_number (
      p_hdr_rec    IN   c_ar_inv_hdr%ROWTYPE,
      p_line_rec   IN   c_ar_inv_line%ROWTYPE,
      p_field      IN   VARCHAR2,
      p_label      IN   VARCHAR2
   )
      RETURN BOOLEAN
   IS
      --v_module   cust.ttec_error_handling.module_name%TYPE  := 'valid_number'; --code commented by RXNETHI-ARGANO,05/05/23
	  v_module   apps.ttec_error_handling.module_name%TYPE  := 'valid_number'; --code added by RXNETHI-ARGANO,05/05/23
      v_loc      NUMBER;
      v_number   NUMBER;
   BEGIN
      v_loc := 10;

      BEGIN
         v_number := p_field;
         RETURN TRUE;
      EXCEPTION
         WHEN OTHERS
         THEN
            ttec_error_logging.process_error (g_application_code,
                                              g_interface,
                                              g_package,
                                              v_module,
                                              g_warning_status,
                                              NULL,
                                                 p_label
                                              || ' must be a Numeric value',
                                              'Org ID',
                                              p_hdr_rec.org_id,
                                              'FileName',
                                              p_hdr_rec.file_name,
                                              'Inv #',
                                              p_hdr_rec.trx_number,
                                              'Line #',
                                              p_line_rec.line_number,
                                              p_label,
                                              SUBSTRB (p_field, 1, 250)
                                             );
            RETURN FALSE;
      END;
   EXCEPTION
      WHEN OTHERS
      THEN
         ttec_error_logging.process_error (g_application_code,
                                           g_interface,
                                           g_package,
                                           v_module,
                                           g_warning_status,
                                           SQLCODE,
                                           SQLERRM,
                                           g_label1,
                                           v_loc,
                                           'Org ID',
                                           p_hdr_rec.org_id,
                                           'FileName',
                                           p_hdr_rec.file_name,
                                           'Inv #',
                                           p_hdr_rec.trx_number,
                                           'Line #',
                                           p_line_rec.line_number
                                          );
         RETURN FALSE;
   END valid_number;

-- PROCEDURE valid_hdr         /* 2.2 */
--    Description: This function will validate the size, type and format of the loaded
--                 HDR data.  It will return a TRUE if no errors with the input data,
--                 otherwise it will return FALSE.
   FUNCTION valid_hdr (p_hdr_rec IN OUT c_ar_inv_hdr%ROWTYPE)
      RETURN BOOLEAN
   IS
      --v_module   cust.ttec_error_handling.module_name%TYPE   := 'valid_hdr'; --code commented by RXNETHI-ARGANO,05/05/23
	  v_module   apps.ttec_error_handling.module_name%TYPE   := 'valid_hdr'; --code added by RXNETHI-ARGANO,05/05/23
      v_loc      NUMBER;
      v_valid    BOOLEAN                                     := TRUE;
   -- Assume TRUE until error found
   BEGIN
      v_loc := 10;

      -- Validate trx_date is in correct format.
      BEGIN
         p_hdr_rec.trx_date := TO_DATE (p_hdr_rec.trx_date, 'MM/DD/YYYY');
      EXCEPTION
         WHEN OTHERS
         THEN
            ttec_error_logging.process_error
               (g_application_code,
                g_interface,
                g_package,
                v_module,
                g_warning_status,
                NULL,
                'Invoice date format is incorrect.  Should be ''MM/DD/YYYY''',
                g_label1,
                v_loc,
                'Org ID',
                p_hdr_rec.org_id,
                'FileName',
                p_hdr_rec.file_name,
                'Inv #',
                p_hdr_rec.trx_number,
                'Inv Date',
                p_hdr_rec.trx_date
               );
            v_valid := FALSE;
      END;

      v_loc := 15;

      -- Validate service_date is in correct format.
      BEGIN
         p_hdr_rec.service_date :=
                               TO_DATE (p_hdr_rec.service_date, 'MM/DD/YYYY');
      EXCEPTION
         WHEN OTHERS
         THEN
            ttec_error_logging.process_error
               (g_application_code,
                g_interface,
                g_package,
                v_module,
                g_warning_status,
                NULL,
                'Service date format is incorrect.  Should be ''MM/DD/YYYY''',
                g_label1,
                v_loc,
                'Org ID',
                p_hdr_rec.org_id,
                'FileName',
                p_hdr_rec.file_name,
                'Inv #',
                p_hdr_rec.trx_number,
                'Service Date',
                p_hdr_rec.service_date
               );
            v_valid := FALSE;
      END;

      v_loc := 20;

      -- Validate that exchange_rate is a Numeric
      IF NOT valid_number (p_hdr_rec,
                           NULL,
                           p_hdr_rec.exchange_rate,
                           'Exchange Rate'
                          )
      THEN
         v_valid := FALSE;
      END IF;

      v_loc := 30;

      -- Validate Size Limitations on remaining HDR fields
      IF NOT valid_length (p_hdr_rec,
                           NULL,
                           p_hdr_rec.trx_number,
                           'Invoice Number',
                           20
                          )
      THEN
         v_valid := FALSE;
      END IF;

      IF NOT valid_length (p_hdr_rec,
                           NULL,
                           p_hdr_rec.currency_code,
                           'Currency Code',
                           15
                          )
      THEN
         v_valid := FALSE;
      END IF;

      IF NOT valid_length (p_hdr_rec,
                           NULL,
                           p_hdr_rec.term_name,
                           'Term Name',
                           15
                          )
      THEN
         v_valid := FALSE;
      END IF;

      IF NOT valid_length (p_hdr_rec,
                           NULL,
                           p_hdr_rec.purchase_order,
                           'Purchase Order',
                           50
                          )
      THEN
         v_valid := FALSE;
      END IF;

      IF NOT valid_length (p_hdr_rec,
                           NULL,
                           p_hdr_rec.comments,
                           'Comments',
                           240
                          )
      THEN
         v_valid := FALSE;
      END IF;

      RETURN v_valid;
   EXCEPTION
      WHEN OTHERS
      THEN
         ttec_error_logging.process_error (g_application_code,
                                           g_interface,
                                           g_package,
                                           v_module,
                                           g_warning_status,
                                           SQLCODE,
                                           SQLERRM,
                                           g_label1,
                                           v_loc,
                                           'Org ID',
                                           p_hdr_rec.org_id,
                                           'FileName',
                                           p_hdr_rec.file_name,
                                           'Inv #',
                                           p_hdr_rec.trx_number
                                          );
         RETURN FALSE;
   END valid_hdr;

-- PROCEDURE valid_line        /* 2.2 */
--    Description: This function will validate the size, type and format of the loaded
--                 LINE data.  It will return a TRUE if no errors with the input data,
--                 otherwise it will return FALSE.
   FUNCTION valid_line (
      p_hdr_rec    IN       c_ar_inv_hdr%ROWTYPE,
      p_line_rec   IN OUT   c_ar_inv_line%ROWTYPE
   )
      RETURN BOOLEAN
   IS
      --v_module   cust.ttec_error_handling.module_name%TYPE   := 'valid_line'; --code commented by RXNETHI-ARGANO,05/05/23
	  v_module   apps.ttec_error_handling.module_name%TYPE   := 'valid_line'; --code added by RXNETHI-ARGANO,05/05/23
      v_loc      NUMBER;
      v_valid    BOOLEAN                                     := TRUE;
   -- Assume TRUE until error found
   BEGIN
      v_loc := 10;

      -- Validate Numeric field are correct type
      IF NOT valid_number (p_hdr_rec,
                           p_line_rec,
                           p_line_rec.line_number,
                           'Line Number'
                          )
      THEN
         v_valid := FALSE;
      END IF;

      IF NOT valid_number (p_hdr_rec,
                           p_line_rec,
                           p_line_rec.quantity,
                           'Quantity'
                          )
      THEN
         v_valid := FALSE;
      END IF;

      IF NOT valid_number (p_hdr_rec,
                           p_line_rec,
                           p_line_rec.unit_selling_price,
                           'Unit Selling Price'
                          )
      THEN
         v_valid := FALSE;
      END IF;

      IF NOT valid_number (p_hdr_rec,
                           p_line_rec,
                           p_line_rec.debit_amount,
                           'Debit Amount'
                          )
      THEN
         v_valid := FALSE;
      END IF;

      IF NOT valid_number (p_hdr_rec,
                           p_line_rec,
                           p_line_rec.credit_amount,
                           'Credit Amount'
                          )
      THEN
         v_valid := FALSE;
      END IF;

      v_loc := 20;

      -- Validate Size Limitations on remaining HDR fields
      IF NOT valid_length (p_hdr_rec,
                           p_line_rec,
                           p_line_rec.line_description,
                           'Line Description',
                           240
                          )
      THEN
         v_valid := FALSE;
      END IF;

      IF NOT valid_length (p_hdr_rec,
                           p_line_rec,
                           p_line_rec.tax_code,
                           'Tax Code',
                           50
                          )
      THEN
         v_valid := FALSE;
      END IF;

      IF NOT valid_length (p_hdr_rec,
                           p_line_rec,
                           p_line_rec.LOCATION,
                           'Location',
                           5
                          )
      THEN
         v_valid := FALSE;
      END IF;

      IF NOT valid_length (p_hdr_rec,
                           p_line_rec,
                           p_line_rec.client,
                           'Client',
                           4
                          )
      THEN
         v_valid := FALSE;
      END IF;

      IF NOT valid_length (p_hdr_rec,
                           p_line_rec,
                           p_line_rec.department,
                           'Department',
                           3
                          )
      THEN
         v_valid := FALSE;
      END IF;

      IF NOT valid_length (p_hdr_rec,
                           p_line_rec,
                           p_line_rec.ACCOUNT,
                           'Account',
                           4
                          )
      THEN
         v_valid := FALSE;
      END IF;

      IF NOT valid_length (p_hdr_rec,
                           p_line_rec,
                           p_line_rec.gcc_future1,
                           'GCC Future 1',
                           5
                          )
      THEN
         v_valid := FALSE;
      END IF;

      IF NOT valid_length (p_hdr_rec,
                           p_line_rec,
                           p_line_rec.gcc_future2,
                           'GCC Future 2',
                           4
                          )
      THEN
         v_valid := FALSE;
      END IF;

      RETURN v_valid;
   EXCEPTION
      WHEN OTHERS
      THEN
         ttec_error_logging.process_error (g_application_code,
                                           g_interface,
                                           g_package,
                                           v_module,
                                           g_warning_status,
                                           SQLCODE,
                                           SQLERRM,
                                           g_label1,
                                           v_loc,
                                           'Org ID',
                                           p_hdr_rec.org_id,
                                           'FileName',
                                           p_hdr_rec.file_name,
                                           'Inv #',
                                           p_hdr_rec.trx_number,
                                           'Line #',
                                           p_line_rec.line_number
                                          );
         RETURN FALSE;
   END valid_line;

-- PROCEDURE get_client_info
--    Description: This procedure is used to identify the client_id and site_id for
--                 the client_number and site_number provided in the Excel spreadsheet.
   PROCEDURE get_client_info (
      p_hdr_rec     IN       c_ar_inv_hdr%ROWTYPE,
      p_client_id   OUT      NUMBER,
      p_site_id     OUT      NUMBER
   )
   IS
      --v_module   cust.ttec_error_handling.module_name%TYPE
      --                                                   := 'get_client_info'; --code commented by RXNETHI-ARGANO, 05/05/23
      v_module   apps.ttec_error_handling.module_name%TYPE
                                                       := 'get_client_info'; --code added by RXNETHI-ARGANO, 05/05/23
	  v_loc      NUMBER;
   BEGIN
      v_loc := 10;

      SELECT ca.cust_account_id, cas.cust_acct_site_id
        INTO p_client_id, p_site_id
        FROM hz_cust_accounts ca,
             hz_cust_acct_sites_all cas,
             hz_cust_site_uses_all csu
       WHERE ca.account_number = p_hdr_rec.client_number
         AND cas.cust_account_id = ca.cust_account_id
         AND cas.org_id = p_hdr_rec.org_id
         AND csu.cust_acct_site_id = cas.cust_acct_site_id
         AND csu.LOCATION = p_hdr_rec.site_number
         AND csu.site_use_code = 'BILL_TO'
         AND csu.status = 'A';         --3.5 by CSAEKULA  for task TASK1035166
   EXCEPTION
      WHEN OTHERS
      THEN
         ttec_error_logging.process_error (g_application_code,
                                           g_interface,
                                           g_package,
                                           v_module,
                                           g_warning_status,
                                           SQLCODE,
                                           SQLERRM,
                                           g_label1,
                                           v_loc,
                                           'Org ID',
                                           p_hdr_rec.org_id,
                                           'FileName',
                                           p_hdr_rec.file_name,
                                           'Client #',
                                           p_hdr_rec.client_number,
                                           'Site #',
                                           p_hdr_rec.site_number
                                          );
         RAISE;
   END get_client_info;

   PROCEDURE insert_receivable_acct_client (p_hdr_rec IN c_ar_inv_hdr%ROWTYPE)
   IS
      --v_module              cust.ttec_error_handling.module_name%TYPE
        --                                   := 'insert_receivable_acct_client';--code commented by RXNETHI-ARGANO, 05/05/23
	  v_module              apps.ttec_error_handling.module_name%TYPE
                                         := 'insert_receivable_acct_client';--code added by RXNETHI-ARGANO, 05/05/23
      v_loc                 NUMBER;
      c_account_class       ra_interface_distributions_all.account_class%TYPE
                                                                     := 'REC';
      c_percent             ra_interface_distributions_all.PERCENT%TYPE
                                                                       := 100;
      v_interface_context   ra_interface_lines_all.interface_line_context%TYPE
                                                                      := NULL;
      v_line_number         ra_interface_lines_all.line_number%TYPE   := NULL;
   BEGIN
      v_loc := 10;

      SELECT gcc.segment1, gcc.segment2, gcc.segment3, gcc.segment4,
             gcc.segment5, gcc.segment6
        INTO g_rec_segment1, g_rec_segment2, g_rec_segment3, g_rec_segment4,
             g_rec_segment5, g_rec_segment6
        --FROM ar.ra_cust_trx_types_all rctta, gl.gl_code_combinations gcc --code commented by RXNETHI-ARGANO, 05/05/23
		FROM apps.ra_cust_trx_types_all rctta, apps.gl_code_combinations gcc --code added by RXNETHI-ARGANO, 05/05/23
       WHERE gcc.code_combination_id = rctta.gl_id_rec
         AND rctta.org_id = p_hdr_rec.org_id
         AND rctta.TYPE = 'INV'
         AND rctta.NAME = 'EXCEL INV'
         AND rctta.description = 'Excel Import'
         AND TRUNC (SYSDATE) BETWEEN rctta.start_date
                                 AND NVL (rctta.end_date, '31-DEC-4712');

      IF g_gl_clt_override = 'Y'
      THEN                                                           /* 2.8 */
         SELECT   client, line_number
             INTO g_rec_segment2, v_line_number
             FROM ttec_ar_inv_line_import_stg
            WHERE inv_hdr_id = p_hdr_rec.inv_hdr_id
                                                   -- AND status = 'NEW'
                  AND ROWNUM < 2
         ORDER BY line_number;

         fnd_file.put_line (fnd_file.LOG, '===============================');
         fnd_file.put_line (fnd_file.LOG, 'Override Client Account');
         fnd_file.put_line (fnd_file.LOG, '===============================');
         fnd_file.put_line (fnd_file.LOG,
                            'g_rec_segment2...:' || g_rec_segment2
                           );
      END IF;                                                        /* 2.8 */

      IF g_gl_loc_override IS NOT NULL
      THEN
         fnd_file.put_line (fnd_file.LOG, '===============================');
         fnd_file.put_line (fnd_file.LOG, 'Override Location Account');
         fnd_file.put_line (fnd_file.LOG, '===============================');
         fnd_file.put_line (fnd_file.LOG,
                            'g_gl_loc_override...:' || g_gl_loc_override
                           );
      END IF;

      IF p_hdr_rec.trx_number IS NULL
      THEN
         v_interface_context := 'EXCEL INV';
      ELSE
         v_interface_context := 'EXCEL';
      END IF;

      v_loc := 75;
      fnd_file.put_line (fnd_file.LOG, '===============================');
      fnd_file.put_line (fnd_file.LOG, 'insert_receivable_acct_client:');
      fnd_file.put_line (fnd_file.LOG, '===============================');
      fnd_file.put_line (fnd_file.LOG,
                         'v_interface_context...:' || v_interface_context
                        );
      fnd_file.put_line (fnd_file.LOG,
                         '     g_rec_segment1...:' || g_rec_segment1
                        );
      fnd_file.put_line (fnd_file.LOG,
                         '     g_rec_segment2...:' || g_rec_segment2
                        );
      fnd_file.put_line (fnd_file.LOG,
                         '     g_rec_segment3...:' || g_rec_segment3
                        );
      fnd_file.put_line (fnd_file.LOG,
                         '     g_rec_segment4...:' || g_rec_segment4
                        );
      fnd_file.put_line (fnd_file.LOG,
                         '     g_rec_segment5...:' || g_rec_segment5
                        );
      fnd_file.put_line (fnd_file.LOG,
                         '     g_rec_segment6...:' || g_rec_segment6
                        );

      INSERT INTO ra_interface_distributions_all
                  (interface_line_context, interface_line_attribute1,
                   interface_line_attribute2, org_id,
                   account_class,
--                   amount, Will be calculated by Master Auto Invoice
                                 PERCENT,
                   segment1, segment2,
                   segment3, segment4, segment5,
                   segment6
                  )
           VALUES (v_interface_context,                              /* 2.0 */
                                       p_hdr_rec.trx_number,
                   LPAD (v_line_number, 5, '0'),           /* 2.3 */  /* 3.6*/
                                                p_hdr_rec.org_id,
                   c_account_class,
--                   NVL(p_hdr_rec.CREDIT_AMOUNT,0) - NVL(p_hdr_rec.DEBIT_AMOUNT,0),
                                   c_percent,
                   NVL (g_gl_loc_override, g_rec_segment1),
                                                           /* 2.8 */ --<<insert_receivable_acct_client
                                                           g_rec_segment2,
                   g_rec_segment3, g_rec_segment4, g_rec_segment5,
                   g_rec_segment6
                  );
   EXCEPTION
      WHEN OTHERS
      THEN
         fnd_file.put_line
               (fnd_file.LOG,
                '==========================================================='
               );
         fnd_file.put_line
                   (fnd_file.LOG,
                    ' EXCEPTION ON INSERT INTO ra_interface_distributions_all'
                   );
         fnd_file.put_line
                  (fnd_file.LOG,
                   '========================================================='
                  );
         fnd_file.put_line (fnd_file.LOG, 'SQLERRM...:' || SQLERRM);
         ttec_error_logging.process_error (g_application_code,
                                           g_interface,
                                           g_package,
                                           v_module,
                                           g_warning_status,
                                           SQLCODE,
                                           SQLERRM,
                                           g_label1,
                                           v_loc,
                                           'Org ID',
                                           p_hdr_rec.org_id,
                                           'FileName',
                                           p_hdr_rec.file_name,
                                           'Client #',
                                           p_hdr_rec.client_number,
                                           'Site #',
                                           p_hdr_rec.site_number
                                          );
         RAISE;
   END insert_receivable_acct_client;

   PROCEDURE insert_line (
      p_hdr_rec         IN   c_ar_inv_hdr%ROWTYPE,
      p_line_rec        IN   c_ar_inv_line%ROWTYPE,
      p_batch_source    IN   VARCHAR2,
      p_cust_trx_type   IN   VARCHAR2
   )
   IS
      --v_module              cust.ttec_error_handling.module_name%TYPE
      --                                                       := 'insert_line';--code commented by RXNETHI-ARGANO,05/05/23
	  v_module              apps.ttec_error_handling.module_name%TYPE
                                                             := 'insert_line';--code added by RXNETHI-ARGANO,05/05/23
      v_loc                 NUMBER;
      v_conversion_rate     ra_interface_lines_all.conversion_rate%TYPE;
      c_conversion_type     ra_interface_lines_all.conversion_type%TYPE
                                                                    := 'Spot';
      v_conversion_type     ra_interface_lines_all.conversion_type%TYPE;
      /* 3.1 */
      v_conversion_name     fnd_lookup_values.description%TYPE          := '';
      /* 3.1 */
      v_conversion_date     ra_interface_lines_all.conversion_date%TYPE;
      /* 3.1 */
      v_currency_code       ra_interface_lines_all.currency_code%TYPE;
      /* 3.1 */
      v_error_msg           ttec_error_handling.error_message%TYPE;
      e_memo_line_err       EXCEPTION;
      e_service_date_err    EXCEPTION;
      c_hdr_attr_category   ra_interface_lines_all.header_attribute_category%TYPE
                                                                   := 'Excel';
      c_account_class       ra_interface_distributions_all.account_class%TYPE
                                                                     := 'REV';
      c_percent             ra_interface_distributions_all.PERCENT%TYPE
                                                                       := 100;
      v_interface_context   ra_interface_lines_all.interface_line_context%TYPE
                                                                      := NULL;
      v_trx_date            DATE                                      := NULL;
      v_exists              VARCHAR (1);
   /* 3.2 */
   BEGIN
      v_interface_context := NULL;
      v_loc := 10;
      -- Determine Conversion Rate values
--      IF p_hdr_rec.currency_code = 'USD'
--      THEN
--         v_conversion_rate := 1;
--         c_conversion_type := 'User';
--      ELSE
--         v_conversion_rate := p_hdr_rec.exchange_rate;
--      END IF;
      v_currency_code := '';
      fnd_file.put_line (fnd_file.LOG, 'In Insert Line 1');

      BEGIN
         SELECT gll.currency_code
           INTO v_currency_code
           FROM hr_operating_units hou, apps.gl_ledgers gll
          WHERE hou.set_of_books_id = gll.ledger_id
            AND hou.organization_id = p_hdr_rec.org_id;
      EXCEPTION
         WHEN OTHERS
         THEN
            v_currency_code := p_hdr_rec.currency_code;             /* 3.1 */
      END;

      /* 3.1 Begin */
      IF v_currency_code != p_hdr_rec.currency_code
      THEN
         fnd_file.put_line (fnd_file.LOG, 'In Insert Line 2');

         /* 4.0
                   BEGIN


                          c_conversion_type := '1021';

                          v_trx_date := TO_DATE (p_hdr_rec.trx_date, 'DD-MON-RR');

                          SELECT TAG , DESCRIPTION
                            INTO v_conversion_type, v_conversion_name
                            FROM fnd_lookup_values flv
                           WHERE flv.lookup_type = 'TTEC_AR_INV_INTF_ENABLE_XCHGRT'
                             AND flv.LANGUAGE = 'US'
                             AND flv.enabled_flag = 'Y'
                             AND TO_NUMBER(flv.LOOKUP_CODE) = p_hdr_rec.org_id
                             --AND g_gl_date BETWEEN flv.start_date_active AND NVL (flv.end_date_active, '31-DEC-4712');
                             AND v_trx_date BETWEEN flv.start_date_active AND NVL (flv.end_date_active, '31-DEC-4712'); /* 3.2 */

         /* 4.0            EXCEPTION
                        WHEN OTHERS
                        THEN
                            v_error_msg := 'Lookup type TTEC_AR_INV_INTF_ENABLE_XCHGRT is not defined for this ORG ID -> '||p_hdr_rec.org_id;
                            g_fail_flag := TRUE;
                            g_return_msg := v_error_msg;
                            g_return_code := 1;
                            fnd_file.new_line (fnd_file.output, 1);
                            fnd_file.put_line (fnd_file.output,'Program ABORT due to '||g_return_msg);
                            fnd_file.new_line (fnd_file.output, 1);
                            fnd_file.new_line (fnd_file.log, 1);
                            fnd_file.put_line (fnd_file.log,'Program ABORT due to '||g_return_msg);
                            fnd_file.new_line (fnd_file.log, 1);
                            RAISE;
                    END;

                    BEGIN

                        select conversion_date, NULL, conversion_type
                          into v_conversion_date, v_conversion_rate, c_conversion_type
                        from gl.gl_daily_rates
                        where conversion_type = v_conversion_type -- Period Average Rate or Spot
                        --and conversion_date = LAST_DAY(TRUNC(TRUNC(g_gl_date , 'Month')-1 , 'Month')) -- Period Average Rate of previous month of the GL_DATE
                        --and conversion_date = LAST_DAY(TRUNC(TRUNC(v_trx_date , 'Month')-1 , 'Month')) -- Period Average Rate of previous month of the TRX_DATE /* 3.2 */
            /* 4.0            and conversion_date = LAST_DAY(TRUNC(TRUNC(v_trx_date , 'Month') , 'Month')) -- Period Average Rate of the Invoice Date(TRX_DATE) /* 3.3 */
              /* 4.0          and FROM_CURRENCY = p_hdr_rec.currency_code
                        and TO_CURRENCY   = v_currency_code;

                    EXCEPTION
                        WHEN NO_DATA_FOUND
                        THEN
                           v_error_msg := v_conversion_name||' does not exist for the Invoice Date '||v_trx_date||' for '||p_hdr_rec.currency_code||' to '||v_currency_code;
                            g_fail_flag := TRUE;
                            g_return_msg := v_error_msg;
                            g_return_code := 1;
                            fnd_file.new_line (fnd_file.output, 1);
                            fnd_file.put_line (fnd_file.output,'Program ABORT due to '||g_return_msg);
                            fnd_file.new_line (fnd_file.output, 1);
                            fnd_file.new_line (fnd_file.log, 1);
                            fnd_file.put_line (fnd_file.log,'Program ABORT due to '||g_return_msg);
                            fnd_file.new_line (fnd_file.log, 1);
                            RAISE;
                        WHEN OTHERS
                        THEN

                            v_error_msg := SQLCODE || ': ' || SQLERRM;
                            g_fail_flag := TRUE;
                            g_return_msg:= v_error_msg;
                            g_return_code := 1;
                            fnd_file.new_line (fnd_file.output, 1);
                            fnd_file.put_line (fnd_file.output,'Program ABORT due to '||g_return_msg);
                            fnd_file.new_line (fnd_file.output, 1);
                            RAISE;
                    END;





         /* 3.1  End */

         /* End 4.0 */

         /* Begin 4.1 */
         BEGIN
            fnd_file.put_line (fnd_file.LOG, 'In Insert Line 2.1');
            -- v_trx_date := TO_DATE (p_hdr_rec.trx_date, 'MM/DD/YYYY');
            v_trx_date := TO_DATE (p_hdr_rec.trx_date, 'DD-MON-RR');
            fnd_file.put_line (fnd_file.LOG, 'In Insert Line 2.2');

            IF p_hdr_rec.service_date IS NOT NULL
            THEN
               fnd_file.put_line (fnd_file.LOG, 'In Insert Line 2.3');
               c_conversion_type := '1021';
               v_conversion_rate := NULL;
               v_conversion_date :=
                                TO_DATE (p_hdr_rec.service_date, 'DD-MON-RR');
               fnd_file.put_line (fnd_file.LOG,
                                  'In Insert Line 2.4 ' || v_conversion_date
                                 );

               BEGIN
                  SELECT 'Y'
                    INTO v_exists
                    --FROM gl.gl_daily_rates --code commented by RXNETHI-ARGANO,05/05/23
					FROM apps.gl_daily_rates --code added by RXNETHI-ARGANO,05/05/23
                   WHERE conversion_type = c_conversion_type
                     AND from_currency = p_hdr_rec.currency_code
                     AND conversion_date = v_conversion_date
                     AND to_currency = v_currency_code;

                  fnd_file.put_line (fnd_file.LOG,
                                     'In Insert Line 2.5 '
                                     || v_conversion_date
                                    );
               EXCEPTION
                  WHEN NO_DATA_FOUND
                  THEN
                     v_error_msg :=
                           ' Conversion Rate does not exist for the Service Date '
                        || v_conversion_date
                        || ' for '
                        || p_hdr_rec.currency_code
                        || ' to '
                        || v_currency_code;
                     g_fail_flag := TRUE;
                     g_return_msg := v_error_msg;
                     g_return_code := 1;
                     fnd_file.new_line (fnd_file.output, 1);
                     fnd_file.put_line (fnd_file.output,
                                        'Program ABORT due to '
                                        || g_return_msg
                                       );
                     fnd_file.new_line (fnd_file.output, 1);
                     fnd_file.new_line (fnd_file.LOG, 1);
                     fnd_file.put_line (fnd_file.LOG,
                                        'Program ABORT due to '
                                        || g_return_msg
                                       );
                     fnd_file.new_line (fnd_file.LOG, 1);
                     RAISE;
               END;
            ELSE
               RAISE e_service_date_err;
            END IF;
         EXCEPTION
            WHEN e_service_date_err
            THEN
               v_error_msg :=
                  'Service date for cross currency transaction should not have null value ';
               g_fail_flag := TRUE;
               g_return_msg := v_error_msg;
               g_return_code := 1;
               fnd_file.new_line (fnd_file.output, 1);
               fnd_file.put_line (fnd_file.output,
                                  'Program ABORT due to ' || g_return_msg
                                 );
               fnd_file.new_line (fnd_file.output, 1);
               fnd_file.new_line (fnd_file.LOG, 1);
               fnd_file.put_line (fnd_file.LOG,
                                  'Program ABORT due to ' || g_return_msg
                                 );
               fnd_file.new_line (fnd_file.LOG, 1);
               RAISE;
            WHEN OTHERS
            THEN
               v_error_msg := SQLCODE || ': ' || SQLERRM;
               g_fail_flag := TRUE;
               g_return_msg := v_error_msg;
               g_return_code := 1;
               fnd_file.new_line (fnd_file.output, 1);
               fnd_file.put_line (fnd_file.output,
                                  'Program ABORT due to ' || g_return_msg
                                 );
               fnd_file.new_line (fnd_file.output, 1);
               RAISE;
         END;
      /* 4.1  End */
      ELSE
         IF p_hdr_rec.currency_code = 'USD'
         THEN
            v_conversion_rate := 1;
            c_conversion_type := 'User';
         ELSE
            v_conversion_rate := p_hdr_rec.exchange_rate;
         END IF;

         /* added service date validation for all currencies*/
         BEGIN
            IF p_hdr_rec.service_date IS NULL
            THEN
               RAISE e_service_date_err;
            END IF;
         EXCEPTION
            WHEN e_service_date_err
            THEN
               v_error_msg := 'Service date should not have null value ';
               g_fail_flag := TRUE;
               g_return_msg := v_error_msg;
               g_return_code := 1;
               fnd_file.new_line (fnd_file.output, 1);
               fnd_file.put_line (fnd_file.output,
                                  'Program ABORT due to ' || g_return_msg
                                 );
               fnd_file.new_line (fnd_file.output, 1);
               fnd_file.new_line (fnd_file.LOG, 1);
               fnd_file.put_line (fnd_file.LOG,
                                  'Program ABORT due to ' || g_return_msg
                                 );
               fnd_file.new_line (fnd_file.LOG, 1);
               RAISE;
            WHEN OTHERS
            THEN
               v_error_msg := SQLCODE || ': ' || SQLERRM;
               g_fail_flag := TRUE;
               g_return_msg := v_error_msg;
               g_return_code := 1;
               fnd_file.new_line (fnd_file.output, 1);
               fnd_file.put_line (fnd_file.output,
                                  'Program ABORT due to ' || g_return_msg
                                 );
               fnd_file.new_line (fnd_file.output, 1);
               RAISE;
         END;
        /* added service date validation for all currencies*/

         v_currency_code := p_hdr_rec.currency_code;                 /* 3.1 */
         v_conversion_date := p_hdr_rec.trx_date;                    /* 3.1 */
      END IF;

      fnd_file.put_line (fnd_file.LOG,
                         '=============RESULTS======================'
                        );
      fnd_file.put_line (fnd_file.LOG,
                         '   v_currency_code.....:' || v_currency_code
                        );
      fnd_file.put_line (fnd_file.LOG,
                         '   v_conversion_date...:' || v_conversion_date
                        );
      fnd_file.put_line (fnd_file.LOG,
                         '   v_conversion_rate...:' || v_conversion_rate
                        );
      fnd_file.put_line (fnd_file.LOG,
                         '   c_conversion_type...:' || c_conversion_type
                        );
      fnd_file.put_line (fnd_file.LOG,
                         '==========================================='
                        );
      v_loc := 15;

      IF p_hdr_rec.trx_number IS NULL
      THEN
         v_interface_context := 'EXCEL INV';
      ELSE
         v_interface_context := 'EXCEL';
      END IF;

      INSERT INTO ra_interface_lines_all
                  (interface_line_context, interface_line_attribute1,
                   interface_line_attribute2, batch_source_name,
                   line_type, description,
                   currency_code,
                   amount,
                   cust_trx_type_name, term_name,
                   orig_system_batch_name, orig_system_bill_customer_id,
                   orig_system_bill_address_id, conversion_type,
                   conversion_rate, conversion_date, trx_date,
                   gl_date, trx_number, quantity,
                   unit_selling_price, tax_code,
                   purchase_order,
                   attribute2,
                   header_attribute_category, header_attribute1,
                   header_attribute8,                                /* 3.0 */
                   header_attribute9,                                /*4.0  */
                   comments, org_id, original_gl_date,
                   reason_code, reason_code_meaning,
                   translated_description                            /* 2.6 */
                                         ,
                   attribute3                                        /* 2.7 */
                             ,
                   attribute4                                        /* 2.7 */
                             ,
                   attribute5                                        /* 2.7 */
                  )
           VALUES (v_interface_context                               /* 2.0 */
                                      , p_hdr_rec.trx_number,
                   LPAD (p_line_rec.line_number, 5, '0'),  /* 2.3 */ /* 3.6 */
                                                         p_batch_source,
                                                                       /*2.4*/
                   --p_hdr_rec.batch_source_name                       /* 2.0 */
                   p_line_rec.line_type, p_line_rec.line_description,
                   p_hdr_rec.currency_code,
                   NVL (p_line_rec.debit_amount, p_line_rec.credit_amount),
                   --p_hdr_rec.transaction_type                        /* 2.0 */
                   p_cust_trx_type,                                    /*2.4*/
                                   p_hdr_rec.term_name,
                   SUBSTR (p_hdr_rec.file_name, 1, 40), g_client_id,
                   g_site_id, c_conversion_type,
                   v_conversion_rate,
                                     --p_hdr_rec.trx_date, /* 3.1 */
                                     v_conversion_date,              /* 3.1 */
                                                       p_hdr_rec.trx_date,
                   g_gl_date, p_hdr_rec.trx_number, p_line_rec.quantity,
                   p_line_rec.unit_selling_price, p_line_rec.tax_code,
                   p_hdr_rec.purchase_order,
                   SUBSTR (p_line_rec.item_category, 1, 150),
                   c_hdr_attr_category, p_hdr_rec.trx_number,
                   p_hdr_rec.ttec_ticket,                            /* 3.0 */
                   TO_CHAR(TO_DATE (p_hdr_rec.service_date, 'DD-MON-RRRR'),'DD-MON-YYYY'),   /* 4.0  */
                   p_hdr_rec.comments, p_hdr_rec.org_id, g_gl_date,
                   p_line_rec.reason_code, p_line_rec.reason_code_meaning,
                   p_line_rec.translated_desc                        /* 2.6 */
                                             ,
                   p_line_rec.business_name                          /* 2.7 */
                                           ,
                   p_line_rec.reference1                             /* 2.7 */
                                        ,
                   p_line_rec.reference2                             /* 2.7 */
                  );

      v_loc := 20;
      fnd_file.put_line (fnd_file.LOG,
                         '==========================================='
                        );
      fnd_file.put_line (fnd_file.LOG, '>>>>>>Revenue <<<<<<<<<<<<<<<');
      fnd_file.put_line (fnd_file.LOG,
                         'INSERT INTO ra_interface_distributions_all'
                        );
      fnd_file.put_line (fnd_file.LOG,
                         '==========================================='
                        );
      fnd_file.put_line (fnd_file.LOG,
                         '   v_interface_context...:' || v_interface_context
                        );
      fnd_file.put_line (fnd_file.LOG,
                         '   p_line_rec.LOCATION...:' || p_line_rec.LOCATION
                        );
      fnd_file.put_line (fnd_file.LOG,
                         '     p_line_rec.client...:' || p_line_rec.client
                        );
      fnd_file.put_line (fnd_file.LOG,
                         ' p_line_rec.department...:' || p_line_rec.department
                        );
      fnd_file.put_line (fnd_file.LOG,
                         '    p_line_rec.ACCOUNT...:' || p_line_rec.ACCOUNT
                        );
      fnd_file.put_line (fnd_file.LOG,
                         'p_line_rec.gcc_future1...:'
                         || p_line_rec.gcc_future1
                        );
      fnd_file.put_line (fnd_file.LOG,
                         'p_line_rec.gcc_future2...:'
                         || p_line_rec.gcc_future2
                        );

      INSERT INTO ra_interface_distributions_all
                  (interface_line_context, interface_line_attribute1,
                   interface_line_attribute2,
                   org_id, account_class, PERCENT,
                   segment1, segment2,
                   segment3, segment4,
                   segment5, segment6
                  )
           VALUES (v_interface_context                               /* 2.0 */
                                      , p_hdr_rec.trx_number,
                   LPAD (p_line_rec.line_number, 5, '0')    /* 2.3 */ /* 3.6*/
                                                        ,
                   p_hdr_rec.org_id, c_account_class, c_percent,
                   -- NVL(g_gl_loc_override,p_line_rec.LOCATION), /* 2.8 */
                   p_line_rec.LOCATION,      -- Should not override on Revenue
                                       p_line_rec.client,
                   p_line_rec.department, p_line_rec.ACCOUNT,
                   p_line_rec.gcc_future1, p_line_rec.gcc_future2
                  );
   EXCEPTION
      WHEN OTHERS
      THEN
         ttec_error_logging.process_error (g_application_code,
                                           g_interface,
                                           g_package,
                                           v_module,
                                           g_warning_status,
                                           SQLCODE,
                                           SQLERRM,
                                           g_label1,
                                           v_loc,
                                           'Org ID',
                                           p_hdr_rec.org_id,
                                           'FileName',
                                           p_hdr_rec.file_name,
                                           'Inv #',
                                           p_hdr_rec.trx_number,
                                           'Line #',
                                           p_line_rec.line_number
                                          );
         RAISE;
   END;

   PROCEDURE insert_tax (
      p_hdr_rec         IN   c_ar_inv_hdr%ROWTYPE,
      p_line_rec        IN   c_ar_inv_line%ROWTYPE,
      p_batch_source    IN   VARCHAR2,                                  -- 2.4
      p_cust_trx_type   IN   VARCHAR2                                   -- 2.4
   )
   IS
      --v_module                 cust.ttec_error_handling.module_name%TYPE     --code commented by RXNETHI-ARGANO,05/05/23
      v_module                 apps.ttec_error_handling.module_name%TYPE       --code added by RXNETHI-ARGANO,05/05/23
                                                              := 'insert_tax';
      v_loc                    NUMBER;
      v_location               VARCHAR2 (5);
      v_client                 VARCHAR2 (5);
      v_department             VARCHAR2 (5);
      v_account                VARCHAR2 (5);
      v_gcc_future1            VARCHAR2 (5);
      v_gcc_future2            VARCHAR2 (5);
      v_rev_ccid               NUMBER;
      v_tax_code               ra_interface_lines_all.tax_code%TYPE;
      c_memo_line_name         ra_interface_lines_all.memo_line_name%TYPE
                                                           := 'Tax Memo Line';
      c_hdr_context            ra_interface_lines_all.header_attribute_category%TYPE
                                                                   := 'Excel';
      v_conversion_rate        ra_interface_lines_all.conversion_rate%TYPE;
      c_conversion_type        ra_interface_lines_all.conversion_type%TYPE
                                                                    := 'Spot';
      v_conversion_type        ra_interface_lines_all.conversion_type%TYPE;
      /* 3.1 */
      v_conversion_name        fnd_lookup_values.description%TYPE       := '';
      /* 3.1 */
      v_conversion_date        ra_interface_lines_all.conversion_date%TYPE;
      /* 3.1 */
      v_currency_code          ra_interface_lines_all.currency_code%TYPE;
      /* 3.1 */
      c_dummy_line_type        ra_interface_lines_all.line_type%TYPE
                                                                    := 'LINE';
      c_dummy_description      ra_interface_lines_all.description%TYPE
                                                        := 'Invoice Tax Line';
      c_tax_line_type          ra_interface_lines_all.line_type%TYPE := 'TAX';
      c_tax_description        ra_interface_lines_all.description%TYPE
                                                                     := 'Tax';
      c_account_class          ra_interface_distributions_all.account_class%TYPE
                                                                     := 'REV';
      c_percent                ra_interface_distributions_all.PERCENT%TYPE
                                                                       := 100;
      v_error_msg              ttec_error_handling.error_message%TYPE;
      e_memo_line_err          EXCEPTION;
      e_service_date_err_tax   EXCEPTION;
      v_interface_context      ra_interface_lines_all.interface_line_context%TYPE
                                                                      := NULL;
      v_trx_date               DATE                                   := NULL;
      v_exists                 VARCHAR (1);
   /* 3.2 */
   BEGIN
      v_loc := 10;
      v_interface_context := NULL;
      -- Determine Conversion Rate values
      v_currency_code := '';

      BEGIN
         SELECT gll.currency_code
           INTO v_currency_code
           FROM hr_operating_units hou, apps.gl_ledgers gll
          WHERE hou.set_of_books_id = gll.ledger_id
            AND hou.organization_id = p_hdr_rec.org_id;
      EXCEPTION
         WHEN OTHERS
         THEN
            v_currency_code := p_hdr_rec.currency_code;             /* 3.1 */
      END;

      /* 3.1 Begin */
      IF v_currency_code != p_hdr_rec.currency_code
      THEN
--         BEGIN
--
--            c_conversion_type := '1021';
--            v_trx_date := TO_DATE (p_hdr_rec.trx_date, 'DD-MON-RR');

         --            SELECT tag, description
--              INTO v_conversion_type, v_conversion_name
--              FROM fnd_lookup_values flv
--             WHERE flv.lookup_type = 'TTEC_AR_INV_INTF_ENABLE_XCHGRT'
--               AND flv.LANGUAGE = 'US'
--               AND flv.enabled_flag = 'Y'
--               AND TO_NUMBER (flv.lookup_code) = p_hdr_rec.org_id
--               --AND g_gl_date BETWEEN flv.start_date_active AND NVL (flv.end_date_active, '31-DEC-4712');
--               AND v_trx_date BETWEEN flv.start_date_active
--                                  AND NVL (flv.end_date_active, '31-DEC-4712');
--         /* 3.2 */
--         EXCEPTION
--            WHEN OTHERS
--            THEN
--               v_error_msg :=
--                     'Lookup type TTEC_AR_INV_INTF_ENABLE_XCHGRT is not defined for this ORG ID -> '
--                  || p_hdr_rec.org_id;
--               g_fail_flag := TRUE;
--               g_return_msg := v_error_msg;
--               g_return_code := 1;
--               fnd_file.new_line (fnd_file.output, 1);
--               fnd_file.put_line (fnd_file.output,
--                                  'Program ABORT due to ' || g_return_msg
--                                 );
--               fnd_file.new_line (fnd_file.output, 1);
--               fnd_file.new_line (fnd_file.LOG, 1);
--               fnd_file.put_line (fnd_file.LOG,
--                                  'Program ABORT due to ' || g_return_msg
--                                 );
--               fnd_file.new_line (fnd_file.LOG, 1);
--               RAISE;
--         END;

         --         BEGIN
--            SELECT conversion_date, NULL, conversion_type
--              INTO v_conversion_date, v_conversion_rate, c_conversion_type
--              FROM gl.gl_daily_rates
--             WHERE conversion_type = v_conversion_type
--                                                -- Period Average Rate or Spot
--               --and conversion_date = LAST_DAY(TRUNC(TRUNC(g_gl_date , 'Month')-1 , 'Month')) -- Period Average Rate of previous month of the GL_DATE
--               --and conversion_date = LAST_DAY(TRUNC(TRUNC(v_trx_date , 'Month')-1 , 'Month')) -- Period Average Rate of previous month of the TRX_DATE /* 3.2 */
--               AND conversion_date =
--                       LAST_DAY (TRUNC (TRUNC (v_trx_date, 'Month'), 'Month'))
--               -- Period Average Rate of the Invoice Date(TRX_DATE) /* 3.3 */
--               AND from_currency = p_hdr_rec.currency_code
--               AND to_currency = v_currency_code;
--         EXCEPTION
--            WHEN NO_DATA_FOUND
--            THEN
--               v_error_msg :=
--                     v_conversion_name
--                  || ' does not exist for the Invoice Date '
--                  || v_trx_date
--                  || ' for '
--                  || p_hdr_rec.currency_code
--                  || ' to '
--                  || v_currency_code;
--               g_fail_flag := TRUE;
--               g_return_msg := v_error_msg;
--               g_return_code := 1;
--               fnd_file.new_line (fnd_file.output, 1);
--               fnd_file.put_line (fnd_file.output,
--                                  'Program ABORT due to ' || g_return_msg
--                                 );
--               fnd_file.new_line (fnd_file.output, 1);
--               fnd_file.new_line (fnd_file.LOG, 1);
--               fnd_file.put_line (fnd_file.LOG,
--                                  'Program ABORT due to ' || g_return_msg
--                                 );
--               fnd_file.new_line (fnd_file.LOG, 1);
--               RAISE;
--            WHEN OTHERS
--            THEN
--               v_error_msg := SQLCODE || ': ' || SQLERRM;
--               g_fail_flag := TRUE;
--               g_return_msg := v_error_msg;
--               g_return_code := 1;
--               fnd_file.new_line (fnd_file.output, 1);
--               fnd_file.put_line (fnd_file.output,
--                                  'Program ABORT due to ' || g_return_msg
--                                 );
--               fnd_file.new_line (fnd_file.output, 1);
--               RAISE;
--         END;
--
         BEGIN
            -- v_trx_date := TO_DATE (p_hdr_rec.trx_date, 'MM/DD/YYYY');
            v_trx_date := TO_DATE (p_hdr_rec.trx_date, 'DD-MON-RR');

            IF p_hdr_rec.service_date IS NOT NULL
            --3.5  Changes for TASK1035166
            THEN
               c_conversion_type := '1021';
               v_conversion_rate := NULL;
               v_conversion_date :=
                                TO_DATE (p_hdr_rec.service_date, 'DD-MON-RR');

               BEGIN
                  SELECT 'Y'
                    INTO v_exists
                    --FROM gl.gl_daily_rates --code commented by RXNETHI-ARGANO, 05/05/23
					FROM apps.gl_daily_rates --code added by RXNETHI-ARGANO, 05/05/23
                   WHERE conversion_type = c_conversion_type
                     AND from_currency = p_hdr_rec.currency_code
                     AND conversion_date = v_conversion_date
                     AND to_currency = v_currency_code;

                  fnd_file.put_line (fnd_file.LOG,
                                     'In Insert Line 2.5 '
                                     || v_conversion_date
                                    );
               EXCEPTION
                  WHEN NO_DATA_FOUND
                  THEN
                     v_error_msg :=
                           ' Conversion Rate does not exist for the Service Date '
                        || v_conversion_date
                        || ' for '
                        || p_hdr_rec.currency_code
                        || ' to '
                        || v_currency_code;
                     g_fail_flag := TRUE;
                     g_return_msg := v_error_msg;
                     g_return_code := 1;
                     fnd_file.new_line (fnd_file.output, 1);
                     fnd_file.put_line (fnd_file.output,
                                        'Program ABORT due to '
                                        || g_return_msg
                                       );
                     fnd_file.new_line (fnd_file.output, 1);
                     fnd_file.new_line (fnd_file.LOG, 1);
                     fnd_file.put_line (fnd_file.LOG,
                                        'Program ABORT due to '
                                        || g_return_msg
                                       );
                     fnd_file.new_line (fnd_file.LOG, 1);
                     RAISE;
               END;
            ELSE
               RAISE e_service_date_err_tax;
            END IF;
         EXCEPTION
            WHEN e_service_date_err_tax
            THEN
               v_error_msg :=
                  'Service date for cross currency transaction should not have null value ';
               g_fail_flag := TRUE;
               g_return_msg := v_error_msg;
               g_return_code := 1;
               fnd_file.new_line (fnd_file.output, 1);
               fnd_file.put_line (fnd_file.output,
                                  'Program ABORT due to ' || g_return_msg
                                 );
               fnd_file.new_line (fnd_file.output, 1);
               fnd_file.new_line (fnd_file.LOG, 1);
               fnd_file.put_line (fnd_file.LOG,
                                  'Program ABORT due to ' || g_return_msg
                                 );
               fnd_file.new_line (fnd_file.LOG, 1);
               RAISE;
            WHEN OTHERS
            THEN
               v_error_msg := SQLCODE || ': ' || SQLERRM;
               g_fail_flag := TRUE;
               g_return_msg := v_error_msg;
               g_return_code := 1;
               fnd_file.new_line (fnd_file.output, 1);
               fnd_file.put_line (fnd_file.output,
                                  'Program ABORT due to ' || g_return_msg
                                 );
               fnd_file.new_line (fnd_file.output, 1);
               RAISE;
         END;
      /* 3.1  End */
      ELSE
         IF p_hdr_rec.currency_code = 'USD'
         THEN
            v_conversion_rate := 1;
         ELSE
            v_conversion_rate := p_hdr_rec.exchange_rate;
         END IF;

         v_currency_code := p_hdr_rec.currency_code;                 /* 3.1 */
         v_conversion_date := p_hdr_rec.trx_date;                    /* 3.1 */
      END IF;

      fnd_file.put_line (fnd_file.LOG,
                         '=============RESULTS======================'
                        );
      fnd_file.put_line (fnd_file.LOG,
                         '   v_currency_code.....:' || v_currency_code
                        );
      fnd_file.put_line (fnd_file.LOG,
                         '   v_conversion_date...:' || v_conversion_date
                        );
      fnd_file.put_line (fnd_file.LOG,
                         '   v_conversion_rate...:' || v_conversion_rate
                        );
      fnd_file.put_line (fnd_file.LOG,
                         '   c_conversion_type...:' || c_conversion_type
                        );
      fnd_file.put_line (fnd_file.LOG,
                         '==========================================='
                        );

      IF p_hdr_rec.trx_number IS NULL
      THEN
         v_interface_context := 'EXCEL INV';
      ELSE
         v_interface_context := 'EXCEL';
      END IF;

      v_loc := 15;

      -- Get the Tax_Code and Revenue Acct from the setup Memo Line
      BEGIN
         SELECT b.tax_code, b.gl_id_rev
           INTO v_tax_code, v_rev_ccid
           FROM ar_memo_lines_all_tl t, ar_memo_lines_all_b b
          WHERE b.memo_line_id = t.memo_line_id
            AND b.org_id = t.org_id
            AND b.org_id = p_hdr_rec.org_id
            AND t.LANGUAGE = 'US'
            AND t.NAME = c_memo_line_name;

         IF v_tax_code IS NULL
         THEN
            v_error_msg := 'Tax Code is not set on Memo Line for Org';
            RAISE e_memo_line_err;
         END IF;

         IF v_rev_ccid IS NULL
         THEN
            v_error_msg := 'Revenue Acct is not set on Memo Line for Org';
            RAISE e_memo_line_err;
         END IF;

         SELECT segment1, segment2, segment3, segment4, segment5,
                segment6
           INTO v_location, v_client, v_department, v_account, v_gcc_future1,
                v_gcc_future2
           --FROM gl.gl_code_combinations --code commented by RXNETHI-ARGANO, 05/05/23
		   FROM apps.gl_code_combinations --code added by RXNETHI-ARGANO, 05/05/23
          WHERE code_combination_id = v_rev_ccid;
      EXCEPTION
         WHEN OTHERS
         THEN
            v_error_msg := 'Memo Line does not exist for Org';
            RAISE e_memo_line_err;
      END;

      -- Create Dummy Line to Link the Tax Line to
      INSERT INTO ra_interface_lines_all
                  (interface_line_context, interface_line_attribute1,
                   interface_line_attribute2, batch_source_name, line_type,
                   description, currency_code,
                   cust_trx_type_name, term_name,
                   orig_system_batch_name, orig_system_bill_customer_id,
                   orig_system_bill_address_id, conversion_type,
                   conversion_rate, conversion_date, trx_date,
                   gl_date, trx_number, purchase_order,
                   header_attribute_category, header_attribute1, comments,
                   org_id, original_gl_date
--    , memo_line_name
      ,            quantity, unit_selling_price,
                   amount, reason_code, reason_code_meaning,
                   translated_description                            /* 2.6 */
                                         ,
                   attribute3                                        /* 2.7 */
                             ,
                   attribute4                                        /* 2.7 */
                             ,
                   attribute5                                        /* 2.7 */
                  )
           VALUES (v_interface_context                               /* 2.0 */
                                      , p_hdr_rec.trx_number,
                   c_dummy_description,
                                       --p_hdr_rec.batch_source_name                       /* 2.0 */
                                       p_batch_source,                 /*2.4*/
                                                      c_dummy_line_type,
                   c_dummy_description, p_hdr_rec.currency_code,
                   --p_hdr_rec.transaction_type                        /* 2.0 */
                   p_cust_trx_type,                                    /*2.4*/
                                   p_hdr_rec.term_name,
                   SUBSTR (p_hdr_rec.file_name, 1, 40), g_client_id,
                   g_site_id, c_conversion_type,
                   v_conversion_rate,
                                     --p_hdr_rec.trx_date, /* 3.1 */
                                     v_conversion_date,              /* 3.1 */
                                                       p_hdr_rec.trx_date,
                   g_gl_date, p_hdr_rec.trx_number, p_hdr_rec.purchase_order,
                   c_hdr_context, p_hdr_rec.trx_number, p_hdr_rec.comments,
                   p_hdr_rec.org_id, g_gl_date
--    , c_memo_line_name
      ,            0, 0,
                   0, p_line_rec.reason_code, p_line_rec.reason_code_meaning,
                   p_line_rec.translated_desc                        /* 2.6 */
                                             ,
                   p_line_rec.business_name                          /* 2.7 */
                                           ,
                   p_line_rec.reference1                             /* 2.7 */
                                        ,
                   p_line_rec.reference2                             /* 2.7 */
                  );

      v_loc := 20;

      -- Create Tax Line
      INSERT INTO ra_interface_lines_all
                  (link_to_line_context, link_to_line_attribute1,
                   link_to_line_attribute2,
                   interface_line_context,
                   interface_line_attribute1, interface_line_attribute2,
                   batch_source_name, line_type, description,
                   currency_code,
                   amount,
                   cust_trx_type_name, orig_system_batch_name,
                   conversion_type, conversion_rate, conversion_date,
                   tax_code, org_id, original_gl_date,
                   reason_code, reason_code_meaning,
                   translated_description                            /* 2.6 */
                                         ,
                   attribute3                                        /* 2.7 */
                             ,
                   attribute4                                        /* 2.7 */
                             ,
                   attribute5                                        /* 2.7 */
                  )
           VALUES (v_interface_context                               /* 2.0 */
                                      , p_hdr_rec.trx_number,
                   c_dummy_description,
                   p_hdr_rec.interface_line_context /* 2.0 */,
                   p_hdr_rec.trx_number, c_tax_description,
                   --p_hdr_rec.batch_source_name                       /* 2.0 */
                   p_batch_source,                                     /*2.4*/
                                  c_tax_line_type, c_tax_description,
                   p_hdr_rec.currency_code,
                   NVL (p_line_rec.debit_amount, p_line_rec.credit_amount),
                   --p_hdr_rec.transaction_type                        /* 2.0 */
                   p_cust_trx_type,                                    /*2.4*/
                                   SUBSTR (p_hdr_rec.file_name, 1, 40),
                   c_conversion_type, v_conversion_rate, p_hdr_rec.trx_date,
                   v_tax_code, p_hdr_rec.org_id, g_gl_date,
                   p_line_rec.reason_code, p_line_rec.reason_code_meaning,
                   p_line_rec.translated_desc                        /* 2.6 */
                                             ,
                   p_line_rec.business_name                          /* 2.7 */
                                           ,
                   p_line_rec.reference1                             /* 2.7 */
                                        ,
                   p_line_rec.reference2                             /* 2.7 */
                  );

      v_loc := 30;
      fnd_file.put_line (fnd_file.LOG,
                         '==========================================='
                        );
      fnd_file.put_line (fnd_file.LOG,
                         '>>>>>>Create Tax Line<<<<<<<<<<<<<<<<');
      fnd_file.put_line (fnd_file.LOG,
                         'INSERT INTO ra_interface_distributions_all'
                        );
      fnd_file.put_line (fnd_file.LOG,
                         '==========================================='
                        );
      fnd_file.put_line (fnd_file.LOG,
                         '   v_interface_context...:' || v_interface_context
                        );
      fnd_file.put_line (fnd_file.LOG,
                         '            v_location...:' || v_location
                        );
      fnd_file.put_line (fnd_file.LOG,
                         '              v_client...:' || v_client
                        );
      fnd_file.put_line (fnd_file.LOG,
                         '          v_department...:' || v_department
                        );
      fnd_file.put_line (fnd_file.LOG,
                         '             v_account...:' || v_account
                        );
      fnd_file.put_line (fnd_file.LOG,
                         '         v_gcc_future1...:' || v_gcc_future1
                        );
      fnd_file.put_line (fnd_file.LOG,
                         '         v_gcc_future2...:' || v_gcc_future2
                        );

      -- Create Distribution for Tax Line
      INSERT INTO ra_interface_distributions_all
                  (interface_line_context, interface_line_attribute1,
                   interface_line_attribute2, org_id, account_class,
                   PERCENT, segment1, segment2, segment3, segment4,
                   segment5, segment6
                  )
           VALUES (v_interface_context                               /* 2.0 */
                                      , p_hdr_rec.trx_number,
                   c_dummy_description, p_hdr_rec.org_id, c_account_class,
                   c_percent,
                             --NVL(g_gl_loc_override,v_location), /* 2.8 */
                             v_location,         -- Should not override on TAX
                                        v_client, v_department, v_account,
                   v_gcc_future1, v_gcc_future2
                  );
   EXCEPTION
      WHEN e_memo_line_err
      THEN
         ttec_error_logging.process_error (g_application_code,
                                           g_interface,
                                           g_package,
                                           v_module,
                                           g_warning_status,
                                           SQLCODE,
                                           v_error_msg,
                                           g_label1,
                                           v_loc,
                                           'Memo Line Name',
                                           c_memo_line_name,
                                           'Org ID',
                                           p_hdr_rec.org_id,
                                           'FileName',
                                           p_hdr_rec.file_name,
                                           'Inv #',
                                           p_hdr_rec.trx_number,
                                           'Line #',
                                           p_line_rec.line_number
                                          );
         RAISE;
      WHEN OTHERS
      THEN
         ttec_error_logging.process_error (g_application_code,
                                           g_interface,
                                           g_package,
                                           v_module,
                                           g_warning_status,
                                           SQLCODE,
                                           SQLERRM,
                                           g_label1,
                                           v_loc,
                                           'Memo Line Name',
                                           c_memo_line_name,
                                           'Org ID',
                                           p_hdr_rec.org_id,
                                           'FileName',
                                           p_hdr_rec.file_name,
                                           'Inv #',
                                           p_hdr_rec.trx_number,
                                           'Line #',
                                           p_line_rec.line_number
                                          );
         RAISE;
   END;

/*********************************************************
**  Public Functions and Procedures
*********************************************************/

   -- FUNCTION build_org_dir
--   Description: This function is called by the 'TeleTech AR Invoice Interface File Load' CP to build the Org
--                Directory name (used on Unix and Maple for placing the files) from the input Organization ID.
   FUNCTION build_org_dir (p_org_id IN NUMBER)
      RETURN VARCHAR2
   IS
      --v_module    cust.ttec_error_handling.module_name%TYPE
      --                                                     := 'build_org_dir';--code commented by RXNETHI-ARGANO,05/05/23
	  v_module    apps.ttec_error_handling.module_name%TYPE
                                                           := 'build_org_dir';--code added by RXNETHI-ARGANO,05/05/23
      v_loc       NUMBER;
      v_org_dir   VARCHAR2 (240);
   BEGIN
      v_loc := 10;

      SELECT TRANSLATE (REPLACE (REPLACE (UPPER (NAME), '@HOME', 'ATHOME'),
                                 ' - ',
                                 '_'
                                ),

                        --'AAA?A?CEEEEIIII?OOO?OUUUUY@_- .,/\??"?',
                        'ÀÁÂÃÄÅÇÈÉÊËÌÍÎÏÑÒÓÔÕÖÙÚÛÜÝ@_- .,/\ºª"°',
                        'AAAAAACEEEEIIIINOOOOOUUUUYA___'
                       ) org_dir
        INTO v_org_dir
        FROM hr_operating_units
       WHERE organization_id = p_org_id;

      RETURN v_org_dir;
   EXCEPTION
      WHEN OTHERS
      THEN
         ttec_error_logging.process_error (g_application_code,
                                           g_interface,
                                           g_package,
                                           v_module,
                                           g_failure_status,
                                           SQLCODE,
                                           SQLERRM,
                                           g_label1,
                                           v_loc,
                                           'Org ID',
                                           p_org_id
                                          );
   END build_org_dir;

/************************************************************************************/
/*                               MAIN PROGRAM PROCEDURE                             */
/************************************************************************************/
--   Description: This is the primary procedure for processing the data loaded into the staging tables and
--              inserting it into the Interface tables.
   PROCEDURE main (
      p_gl_date                       IN   DATE,
      p_batch_source_id               IN   VARCHAR2,
      p_change_rec_acct_client_code   IN   VARCHAR2,                     --2.5
      p_override_gl_loc               IN   VARCHAR2                      --2.7
   )
   IS
      --v_module          cust.ttec_error_handling.module_name%TYPE   := 'main';    --code commented by RXNETHI-ARGANO,05/05/23
      v_module          apps.ttec_error_handling.module_name%TYPE   := 'main';      --code added by RXNETHI-ARGANO,05/05/23
      v_loc             NUMBER;
      v_error           BOOLEAN;
      v_batch_source    VARCHAR2 (100)                           DEFAULT NULL;
      v_cust_trx_type   VARCHAR2 (100)                           DEFAULT NULL;

      /* 2.1 - 1 */
      CURSOR c_error_files
      IS
         SELECT file_name
           FROM ttec_ar_inv_hdr_import_stg
          WHERE status = 'NEW';
   BEGIN
      v_loc := 10;
      v_batch_source := NULL;
      v_cust_trx_type := NULL;
      g_gl_date := p_gl_date;
      g_gl_loc_override := p_override_gl_loc;
      g_gl_clt_override := p_change_rec_acct_client_code;

      -- 2.4 Begin
      BEGIN
         SELECT DISTINCT rbsa.NAME, rtt.NAME
                    INTO v_batch_source, v_cust_trx_type
                    FROM ra_batch_sources_all rbsa, ra_cust_trx_types_all rtt
                   WHERE batch_source_id = p_batch_source_id
                     AND rbsa.default_inv_trx_type = rtt.cust_trx_type_id;
      EXCEPTION
         WHEN NO_DATA_FOUND
         THEN
            v_batch_source := NULL;
            v_cust_trx_type := NULL;
         WHEN OTHERS
         THEN
            v_batch_source := NULL;
            v_cust_trx_type := NULL;
      END;

      fnd_file.put_line (fnd_file.LOG, '');
      fnd_file.put_line
         (fnd_file.LOG,
          '--------------------------------------------------------------------------------------------------------------------------------------------------'
         );
      fnd_file.put_line (fnd_file.LOG, '');
      fnd_file.put_line (fnd_file.LOG,
                         'Concurrent Program -> TeleTech AR Invoice Interface'
                        );
      fnd_file.put_line (fnd_file.LOG, '');
      fnd_file.put_line (fnd_file.LOG, 'Parameters:                  ');
      fnd_file.put_line (fnd_file.LOG,
                         '                           GL Date: ' || p_gl_date
                        );
      fnd_file.put_line (fnd_file.LOG,
                            '                   Batch Source ID: '
                         || p_batch_source_id
                        );
      fnd_file.put_line (fnd_file.LOG,
                            '                 Batch Source Name: '
                         || v_batch_source
                        );
      fnd_file.put_line (fnd_file.LOG,
                            '                  Transaction Type: '
                         || v_cust_trx_type
                        );
      fnd_file.put_line (fnd_file.LOG,
                            '   Receivable Client Override Flag: '
                         || p_change_rec_acct_client_code
                        );
      fnd_file.put_line (fnd_file.LOG,
                            'Receivable Location Override Value: '
                         || g_gl_loc_override
                        );
      fnd_file.put_line
         (fnd_file.LOG,
          '--------------------------------------------------------------------------------------------------------------------------------------------------'
         );
      fnd_file.put_line (fnd_file.LOG, '');

      -- 2.4 end
      FOR r_hdr IN c_ar_inv_hdr
      LOOP
         v_error := FALSE;
         v_loc := 20;

         IF NOT valid_hdr (r_hdr)
         THEN
            -- Mark as error but continue line evals
            v_error := TRUE;
         END IF;

         v_loc := 30;
         get_client_info (r_hdr, g_client_id, g_site_id);

         IF g_client_id IS NULL OR g_site_id IS NULL
         THEN
            ttec_error_logging.process_error (g_application_code,
                                              g_interface,
                                              g_package,
                                              v_module,
                                              g_warning_status,
                                              SQLCODE,
                                              SQLERRM,
                                              g_label1,
                                              v_loc,
                                              'Org ID',
                                              r_hdr.org_id,
                                              'FileName',
                                              r_hdr.file_name,
                                              'Client #',
                                              r_hdr.client_number,
                                              'Site #',
                                              r_hdr.site_number
                                             );
            v_error := TRUE;
         END IF;

         v_loc := 40;

         FOR r_line IN c_ar_inv_line (r_hdr.inv_hdr_id)
         LOOP
            v_loc := 50;

            IF NOT valid_line (r_hdr, r_line)
            THEN
               -- Mark as error but continue line evals
               v_error := TRUE;
            END IF;

            -- Only process if NO Lines have errors.
            IF NOT v_error
            THEN
               -- Convert Debit Amount to Negative
               r_line.debit_amount :=
                                       ABS (TO_NUMBER (r_line.debit_amount))
                                     * -1;
               v_loc := 60;

               IF r_line.line_type = 'LINE'
               THEN
                  insert_line (r_hdr, r_line, v_batch_source,
                               v_cust_trx_type);
               ELSIF r_line.line_type = 'TAX'
               THEN
                  insert_tax (r_hdr, r_line, v_batch_source, v_cust_trx_type);
               END IF;

               v_loc := 70;

               -- Update Invoice Line with Processed Status
               IF r_line.line_type IN ('LINE', 'TAX')
               THEN
                  UPDATE ttec_ar_inv_line_import_stg
                     SET status = 'PROCESSED'
                   WHERE inv_line_id = r_line.inv_line_id;

                  g_lines_processed := g_lines_processed + 1;
               ELSE
                  UPDATE ttec_ar_inv_line_import_stg
                     SET status = 'NOT INTERFACED'
                   WHERE inv_line_id = r_line.inv_line_id;

                  g_lines_skipped := g_lines_skipped + 1;
               END IF;
            END IF;
         END LOOP;

         /* 2.5  Begin */
         IF    p_change_rec_acct_client_code = 'Y'
            OR g_gl_loc_override IS NOT NULL
         THEN
            IF NOT v_error
            THEN
               v_loc := 75;
               insert_receivable_acct_client (r_hdr);
            END IF;
         END IF;

         /* 2.5  End */
         IF NOT v_error
         THEN
            v_loc := 80;

            -- Update Invoice with Processed Status
            UPDATE ttec_ar_inv_hdr_import_stg
               SET status = 'PROCESSED'
             WHERE inv_hdr_id = r_hdr.inv_hdr_id;

            COMMIT;                                   -- Entire Invoice Commit
            g_invs_processed := g_invs_processed + 1;
         ELSE
            -- Rollback any lines successfully processed prior to error
            ROLLBACK;
            v_loc := 90;

            -- Update Invoice with Error Status
            UPDATE ttec_ar_inv_hdr_import_stg
               SET status = 'ERROR'
             WHERE inv_hdr_id = r_hdr.inv_hdr_id;

            v_loc := 100;

            -- Update Invoice Lines with Error Status
            UPDATE ttec_ar_inv_line_import_stg
               SET status = 'ERROR'
             WHERE inv_hdr_id = r_hdr.inv_hdr_id;

            g_lines_errored := g_lines_errored + SQL%ROWCOUNT;
            g_invs_errored := g_invs_errored + 1;
            COMMIT;
         END IF;
      END LOOP;

      -- Purge Staging Tables of old data
      v_loc := 130;

      DELETE      ttec_ar_inv_hdr_import_stg
            WHERE last_update_date <= SYSDATE - g_purge_days
              AND status != 'NEW';

      DELETE      ttec_ar_inv_line_import_stg
            WHERE last_update_date <= SYSDATE - g_purge_days
              AND status != 'NEW';

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
                                           SQLERRM,
                                           g_label1,
                                           v_loc
                                          );
         ROLLBACK;

         /* Start Mod 2.1 - 1 */
         FOR r_error_file IN c_error_files
         LOOP
            -- Log Non-Loaded File
            ttec_error_logging.process_error
                                       (g_application_code,
                                        g_interface,
                                        g_package,
                                        v_module,
                                        g_failure_status,
                                        NULL,
                                        'File not loaded due to fatal error',
                                        g_label1,
                                        v_loc,
                                        'FileName',
                                        r_error_file.file_name
                                       );
         END LOOP;

         BEGIN
            -- Update all NonProcessed Lines and Hdrs as ERRORED
            -- to prevent them from permanently breaking this process
            UPDATE ttec_ar_inv_hdr_import_stg
               SET status = 'FATAL ERR'
             WHERE status = 'NEW';

            UPDATE ttec_ar_inv_line_import_stg
               SET status = 'FATAL ERR'
             WHERE status = 'NEW';

            COMMIT;
         EXCEPTION
            WHEN OTHERS
            THEN
               ttec_error_logging.process_error
                  (g_application_code,
                   g_interface,
                   g_package,
                   v_module,
                   g_failure_status,
                   SQLCODE,
                   'Unable to correct Fatal Files.  Open TTSD ticket with Oracle ERP Support.',
                   g_label1,
                   v_loc
                  );
         END;

         /* End Mod 2.1 - 1 */
         g_fail_flag := TRUE;

         IF g_return_code = 1
         THEN
            g_fail_msg := g_return_msg;                             /* 3.4 */
         ELSE
            g_fail_msg := SQLERRM;
         END IF;
   END main;

-- PROCEDURE conc_mgr_wrapper
--   Description: This is the front end process called by the Concurrent Manager.  It is responsible
--              for producing the Output and Log Files along with returning the final process status.
--              It calls the Main process to perform the actual data processing.
   PROCEDURE conc_mgr_wrapper (
      errbuf                          OUT      VARCHAR2,
      retcode                         OUT      NUMBER,
      p_gl_date                       IN       DATE,
      p_batch_source_id               IN       VARCHAR2,                -- 2.4
      p_change_rec_acct_client_code   IN       VARCHAR2,                 --2.5
      p_override_gl_loc               IN       VARCHAR2                  --2.7
   )
   IS
      --v_module            cust.ttec_error_handling.module_name%TYPE
      --                                                  := 'conc_mgr_wrapper';--code commented by RXNETHI-ARGANO,05/05/23
	  v_module            apps.ttec_error_handling.module_name%TYPE
                                                        := 'conc_mgr_wrapper';--code added by RXNETHI-ARGANO,05/05/23
      v_loc               NUMBER;
      v_start_timestamp   DATE                                     := SYSDATE;
      e_cleanup_err       EXCEPTION;
   BEGIN
      -- Submit the Main Process
      main (p_gl_date,
            p_batch_source_id,
            p_change_rec_acct_client_code,
            p_override_gl_loc
           );                                                           -- 2.4

      -- Log Counts
      BEGIN
         -- Write to Log
         fnd_file.new_line (fnd_file.LOG, 1);
         fnd_file.put_line (fnd_file.LOG, 'LINE COUNTS');
         fnd_file.put_line
                 (fnd_file.LOG,
                  '---------------------------------------------------------'
                 );
         fnd_file.put_line (fnd_file.LOG,
                            '  # Processed           : ' || g_lines_processed
                           );
         fnd_file.put_line (fnd_file.LOG,
                            '  # Skipped             : ' || g_lines_skipped
                           );
         fnd_file.put_line (fnd_file.LOG,
                            '  # Errored             : ' || g_lines_errored
                           );
         fnd_file.put_line
                  (fnd_file.LOG,
                   '---------------------------------------------------------'
                  );
         fnd_file.new_line (fnd_file.LOG, 1);
         fnd_file.put_line (fnd_file.LOG, 'INVOICE COUNTS');
         fnd_file.put_line
                  (fnd_file.LOG,
                   '---------------------------------------------------------'
                  );
         fnd_file.put_line (fnd_file.LOG,
                            '  # Processed           : ' || g_invs_processed
                           );
         fnd_file.put_line (fnd_file.LOG,
                            '  # Errored             : ' || g_invs_errored
                           );
         fnd_file.put_line
                  (fnd_file.LOG,
                   '---------------------------------------------------------'
                  );
         fnd_file.new_line (fnd_file.LOG, 2);
         -- Write to Output
         fnd_file.put_line (fnd_file.output, 'LINE COUNTS');
         fnd_file.put_line
                  (fnd_file.output,
                   '---------------------------------------------------------'
                  );
         fnd_file.put_line (fnd_file.output,
                            '  # Processed           : ' || g_lines_processed
                           );
         fnd_file.put_line (fnd_file.output,
                            '  # Skipped             : ' || g_lines_skipped
                           );
         fnd_file.put_line (fnd_file.output,
                            '  # Errored             : ' || g_lines_errored
                           );
         fnd_file.put_line
                  (fnd_file.output,
                   '---------------------------------------------------------'
                  );
         fnd_file.new_line (fnd_file.output, 1);
         fnd_file.put_line (fnd_file.output, 'INVOICE COUNTS');
         fnd_file.put_line
                  (fnd_file.output,
                   '---------------------------------------------------------'
                  );
         fnd_file.put_line (fnd_file.output,
                            '  # Processed           : ' || g_invs_processed
                           );
         fnd_file.put_line (fnd_file.output,
                            '  # Errored             : ' || g_invs_errored
                           );
         fnd_file.put_line
                  (fnd_file.output,
                   '---------------------------------------------------------'
                  );
         fnd_file.new_line (fnd_file.output, 2);

         IF g_invs_errored > 0 OR g_lines_errored > 0
         THEN
            retcode := 1;                            -- Lable CR with WARNING
         END IF;
      EXCEPTION
         WHEN OTHERS
         THEN
            fnd_file.put_line (fnd_file.LOG, '   Error reporting Counts');
            retcode := 1;
      END;

      -- Log Errors / Warnings
      BEGIN
         -- Critical Failures from this Package
         ttec_error_logging.log_error_details
                             (p_application        => g_application_code,
                              p_interface          => g_interface,
                              p_message_type       => g_failure_status,
                              p_message_label      => 'CRITICAL ERRORS - FAILURE',
                              p_request_id         => g_request_id
                             );
         -- Warnings from this Package
         ttec_error_logging.log_error_details
                            (p_application        => g_application_code,
                             p_interface          => g_interface,
                             p_message_type       => g_warning_status,
                             p_message_label      => 'Additional Warning Messages',
                             p_request_id         => g_request_id
                            );
      EXCEPTION
         WHEN OTHERS
         THEN
            fnd_file.put_line (fnd_file.LOG,
                               '   Error Reporting Errors / Warnings'
                              );
            retcode := 1;
      END;

      -- Cleanup Log Table
      BEGIN
         -- Purge old Logging Records for this Interface
         ttec_error_logging.purge_log_errors
                                        (p_application      => g_application_code,
                                         p_interface        => g_interface,
                                         p_keep_days        => g_keep_days
                                        );
      EXCEPTION
         WHEN OTHERS
         THEN
            fnd_file.put_line (fnd_file.LOG, 'Error Cleaning up Log tables');
            fnd_file.put_line (fnd_file.LOG, SQLCODE || ': ' || SQLERRM);
            retcode := 2;
            errbuf := SQLERRM;
      END;

      IF g_fail_flag
      THEN
         IF g_return_code = 1
         THEN
            fnd_file.put_line
                          (fnd_file.LOG,
                           'Refer to Output for Detailed Errors and Warnings'
                          );
            retcode := 1;
         ELSE
            fnd_file.put_line
                          (fnd_file.LOG,
                           'Refer to Output for Detailed Errors and Warnings'
                          );
            retcode := 2;
            errbuf := g_fail_msg;
         END IF;
      END IF;
   EXCEPTION
      WHEN OTHERS
      THEN
         fnd_file.put_line (fnd_file.LOG, SQLCODE || ': ' || SQLERRM);
         retcode := 2;
         errbuf := SQLERRM;
   END conc_mgr_wrapper;
END ttec_ar_invoice_iface;
/
show errors;
/