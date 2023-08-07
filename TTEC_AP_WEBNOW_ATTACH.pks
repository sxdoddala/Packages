create or replace PACKAGE      TTEC_AP_WEBNOW_ATTACH AUTHID CURRENT_USER AS
/* $Header: TTEC_AP_WEBNOW_ATTACH.pks 1.0 2011/01/31 mdodge ship $ */

/*== START ================================================================================================*\
   Author: Michelle Dodge
     Date: 01/31/2011
Call From:
     Desc:

  Modification History:

 Version    Date     Author   Description (Include Ticket#)
 -------  --------  --------  ------------------------------------------------------------------------------
     1.0  01/31/11  MDodge    R369254 - WebNow Integration with Oracle Apps
     1.0	18-May-2023 IXPRAVEEN(ARGANO)   		R12.2 Upgrade Remediation
\*== END ==================================================================================================*/

  -- Error Constants
  --START R12.2 Upgrade Remediation
  /*g_application_code   cust.ttec_error_handling.application_code%TYPE  := 'AP';							-- Commented code by IXPRAVEEN-ARGANO,18-May-2023
  g_interface          cust.ttec_error_handling.INTERFACE%TYPE         := 'WebNow Attach';
  g_package            cust.ttec_error_handling.program_name%TYPE      := 'TTEC_AP_WEBNOW_ATTACH';

  g_info_status        cust.ttec_error_handling.status%TYPE            := 'INFO';
  g_warning_status     cust.ttec_error_handling.status%TYPE            := 'WARNING';
  g_error_status       cust.ttec_error_handling.status%TYPE            := 'ERROR';
  g_failure_status     cust.ttec_error_handling.status%TYPE            := 'FAILURE';*/
  g_application_code   apps.ttec_error_handling.application_code%TYPE  := 'AP';								--  code Added by IXPRAVEEN-ARGANO,   18-May-2023
  g_interface          apps.ttec_error_handling.INTERFACE%TYPE         := 'WebNow Attach';
  g_package            apps.ttec_error_handling.program_name%TYPE      := 'TTEC_AP_WEBNOW_ATTACH';

  g_info_status        apps.ttec_error_handling.status%TYPE            := 'INFO';
  g_warning_status     apps.ttec_error_handling.status%TYPE            := 'WARNING';
  g_error_status       apps.ttec_error_handling.status%TYPE            := 'ERROR';
  g_failure_status     apps.ttec_error_handling.status%TYPE            := 'FAILURE';
	--END R12.2.12 Upgrade remediation
--
-- Function add_attach
--
-- Description: This Function will add an AP Invoice WebNow URL attachment
--              to the input Entity.
--
-- Arguments:
--   IN:      p_entity_name - Object Type (ie Invoice, PR) that the URL is going
--                            to be attached to.
--            p_description - Attachment Description
--            p_url         - URL of attachment (WebNow URL)
--            p_pk1_value   - ID of specific Entity that for the attachment.
--  OUT:      TRUE  - Attachment successfully added or already exists.
--            FALSE - Attachment failed being added
--
FUNCTION add_attach( p_entity_name     IN fnd_attached_documents.entity_name%TYPE
                   , p_description     IN fnd_documents_tl.description%TYPE
                   , p_url             IN fnd_documents.file_name%TYPE
                   , p_pk1_value       fnd_attached_documents.pk1_value%TYPE  )
RETURN BOOLEAN;

--
-- PROCEDURE main
--
-- Description: This is the main process which will select eligible invoices from
--              '01-JAN-2006' to today and add WebNow URL attachments to each of them
--              and their associated PR's for the Image of the actual Invoice.
--
-- Arguments:
--   IN:      p_bucket_number    - TEST ONLY - limit data selection to bucket_number OF '# of buckets'
--            p_buckets          - TEST ONLY - This is the '# of buckets'
--
PROCEDURE main( p_bucket_number   IN  NUMBER
              , p_buckets         IN  NUMBER );


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
--            p_bucket_number    - TEST ONLY - limit data selection to bucket_number OF '# of buckets'
--            p_buckets          - TEST ONLY - This is the '# of buckets'
--
PROCEDURE conc_mgr_wrapper( errbuf           OUT  VARCHAR2
                          , retcode          OUT  NUMBER
                          , p_bucket_number   IN  NUMBER
                          , p_buckets         IN  NUMBER );


END TTEC_AP_WEBNOW_ATTACH;
/
show errors;
/