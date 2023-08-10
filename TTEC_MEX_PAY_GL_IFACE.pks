create or replace PACKAGE ttec_mex_pay_gl_iface
AUTHID CURRENT_USER AS
/* $Header: ttec_mex_pay_gl_iface.pks 1.0 2009/03/05 mdodge ship $ */

   /*== START ================================================================================================*\
      Author: Michelle Dodge
        Date: 05-MAR-2009
   Call From: 'TeleTech Mexico Payroll GL Interface' Conc Program AND
              'TeleTech Mex Pay GL Interface File Validate' Conc Program
        Desc: This package body contains the code necessary for processing the data
              in the ttec_mex_gl_iface_stg table and transferring it to the
              GL_INTERFACE table.  A wrapper procedure is provided which will be called
              from the registered concurrent program.  This procedure will call the
              Main procedure for data processing and will log the results and set the
              status on the Concurrent Request.
              The Submit_set function will be called by a Host Program to submit a request
              set for one File at a time.

     Modification History:

    Version    Date     Author   Description (Include Ticket#)
    -------  --------  --------  ------------------------------------------------------------------------------
        1.0  03/05/09  MDodge    WO #561427 - Initial Version
        1.0  16/05/23  RXNETHI-ARGANO  R12.2 Upgrade Remediation
   \*== END ==================================================================================================*/

   --
-- PROCEDURE Main
--
-- Description: This is the main procedure to process the records in the ttec_mex_gl_iface_stg
--     table and then load into the GL_Interface table.
--
-- Arguments:
--   IN:  p_sob_id        - Set of Books ID
--        p_source        - Journal Entry Source
--        p_category      - Journal Entry Category
--        p_currency      - Currency Code for Journal Entry
--        p_batch_name    - Batch Name
--        p_batch_descr   - Batch Description
--        p_journal_name  - Journal Entry Name
--        p_journal_descr - Journal Entry Description
--
   PROCEDURE main (
      /*
	  START R12.2 Upgrade Remediation
	  code commented by RXNETHI-ARGANO,16/05/23
	  p_sob_id          IN   gl.gl_interface.set_of_books_id%TYPE,
      p_source          IN   gl.gl_interface.user_je_source_name%TYPE,
      p_category        IN   gl.gl_interface.user_je_category_name%TYPE,
      p_currency        IN   gl.gl_interface.currency_code%TYPE,
      p_batch_name      IN   gl.gl_interface.reference1%TYPE,
      p_batch_descr     IN   gl.gl_interface.reference2%TYPE,
      p_journal_name    IN   gl.gl_interface.reference4%TYPE,
      p_journal_descr   IN   gl.gl_interface.reference5%TYPE
	  */
	  --code added by RXNETHI-ARGANO,16/05/23
	  p_sob_id          IN   apps.gl_interface.set_of_books_id%TYPE,
      p_source          IN   apps.gl_interface.user_je_source_name%TYPE,
      p_category        IN   apps.gl_interface.user_je_category_name%TYPE,
      p_currency        IN   apps.gl_interface.currency_code%TYPE,
      p_batch_name      IN   apps.gl_interface.reference1%TYPE,
      p_batch_descr     IN   apps.gl_interface.reference2%TYPE,
      p_journal_name    IN   apps.gl_interface.reference4%TYPE,
      p_journal_descr   IN   apps.gl_interface.reference5%TYPE
	  --END R12.2 Upgrade Remediation
   );

--
-- PROCEDURE conc_mgr_wrapper
--
-- Description: This is a wrapper procedure to be called directly from the Concurrent
--   Mgr.  It will set Test Globals from input parameters and will output the final log.
--   This approach will allow the Main process to be ran/tested from the Conc Mgr.
--
-- Arguments:
--   IN:  p_sob_id        - Set of Books ID
--        p_source        - Journal Entry Source
--        p_category      - Journal Entry Category
--        p_currency      - Currency Code for Journal Entry
--        p_batch_name    - Batch Name
--        p_batch_descr   - Batch Description
--        p_journal_name  - Journal Entry Name
--        p_journal_descr - Journal Entry Description
--        p_keep_days     - Number of Days to keep data and logs
--   OUT: ERRBUF          - Required OUT param for Conc Requests
--        RETCODE         - Required OUT param for Conc Requests
--
   PROCEDURE conc_mgr_wrapper (
      errbuf            OUT      VARCHAR2,
      retcode           OUT      NUMBER,
      /*
	  START R12.2 Upgrade Remediation
	  code commente by RXNETHI-ARGANO,16/05/23
	  p_sob_id          IN       gl.gl_interface.set_of_books_id%TYPE,
      p_source          IN       gl.gl_interface.user_je_source_name%TYPE,
      p_category        IN       gl.gl_interface.user_je_category_name%TYPE,
      p_currency        IN       gl.gl_interface.currency_code%TYPE,
      p_batch_name      IN       gl.gl_interface.reference1%TYPE,
      p_batch_descr     IN       gl.gl_interface.reference2%TYPE,
      p_journal_name    IN       gl.gl_interface.reference4%TYPE,
      p_journal_descr   IN       gl.gl_interface.reference5%TYPE,
      p_keep_days       IN       NUMBER
	  */
	  --code added by RXNETHI-ARGANO,16/05/23
	  p_sob_id          IN       apps.gl_interface.set_of_books_id%TYPE,
      p_source          IN       apps.gl_interface.user_je_source_name%TYPE,
      p_category        IN       apps.gl_interface.user_je_category_name%TYPE,
      p_currency        IN       apps.gl_interface.currency_code%TYPE,
      p_batch_name      IN       apps.gl_interface.reference1%TYPE,
      p_batch_descr     IN       apps.gl_interface.reference2%TYPE,
      p_journal_name    IN       apps.gl_interface.reference4%TYPE,
      p_journal_descr   IN       apps.gl_interface.reference5%TYPE,
      p_keep_days       IN       NUMBER
	  --END R12.2 Upgrade Remediation
   );

--
-- FUNCTION submit_set
--
-- Description: This Procedure will be called by the Unix Shell script which loops
--   through all the files to be Interfaced and submits the Request Set once per
--   file.
--
-- Arguments:
--   IN: p_file_name      - Mexico GL Interface file to import
--       p_sob_id         - Set of Books ID to Import the Journals under
--       p_source         - Journal Source to use when Importing Journals
--       p_category       - Journal Category to use when Importing Journals
--       p_currency       - Currency of Journal Entries being imported
--       p_batch_name     - Batch Name, Description, Journal Entry Name and Description
--       p_log_keep_days  - Number of Days to Keep Error Logs for reference
--       p_post_errors    - Post Errors to Suspense parameter for Import Journals program
--       p_cr_summ_jrnls  - Create Summary Journals parameter for Import Journals program
--       p_import_dff     - Import Descriptive Flexfields parameter for Import Journals program
--   RETURN: Concurrent_Request_ID of submitted Set
--
   FUNCTION submit_set (
      p_user_id         IN   fnd_user.user_id%TYPE,
      p_resp_id         IN   fnd_responsibility.responsibility_id%TYPE,
      p_file_name       IN   VARCHAR2,
      p_sob_id          IN   gl_sets_of_books.set_of_books_id%TYPE,
      /*
	  START R12.2 Upgrade Remediation
	  code commente by RXNETHI-ARGANO,16/05/23
	  p_source          IN   gl.gl_interface.user_je_source_name%TYPE,
      p_category        IN   gl.gl_interface.user_je_category_name%TYPE,
      p_currency        IN   gl.gl_interface.currency_code%TYPE,
      p_batch_name      IN   gl.gl_interface.reference1%TYPE,
	  */
	  --code added by RXNETHI-ARGANO,16/05/23
	  p_source          IN   apps.gl_interface.user_je_source_name%TYPE,
      p_category        IN   apps.gl_interface.user_je_category_name%TYPE,
      p_currency        IN   apps.gl_interface.currency_code%TYPE,
      p_batch_name      IN   apps.gl_interface.reference1%TYPE,
	  --END R12.2 Upgrade Remediation
      p_log_keep_days   IN   NUMBER,
      p_post_errors     IN   VARCHAR2,
      p_cr_summ_jrnls   IN   VARCHAR2,
      p_import_dff      IN   VARCHAR2
   )
      RETURN NUMBER;
END ttec_mex_pay_gl_iface;
/
show errors;
/
