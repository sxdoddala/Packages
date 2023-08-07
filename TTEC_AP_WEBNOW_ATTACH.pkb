set define off;
create or replace PACKAGE BODY      TTEC_AP_WEBNOW_ATTACH AS
/* $Header: TTEC_AP_WEBNOW_ATTACH.pkb 1.0 2011/01/31 mdodge ship $ */

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
  --g_label1             cust.ttec_error_handling.label1%TYPE            := 'Err Location';				-- Commented code by IXPRAVEEN-ARGANO,18-May-2023
  g_label1             apps.ttec_error_handling.label1%TYPE            := 'Err Location';               --  code Added by IXPRAVEEN-ARGANO,   18-May-2023
  g_keep_days          NUMBER                                          := 30;  -- Number of days to keep error logging.

  -- Process FAILURE variables
  g_fail_flag          BOOLEAN                                         := FALSE;
  g_fail_msg           VARCHAR2(240);

  -- declare who columns
  g_request_id         NUMBER                                          := fnd_global.conc_request_id;
  g_created_by         NUMBER                                          := fnd_global.user_id;

  -- Global Count Variables for logging information
  g_invs_processed     NUMBER                                          := 0;
  g_prs_processed      NUMBER                                          := 0;
  g_invs_errored       NUMBER                                          := 0;
  g_prs_errored        NUMBER                                          := 0;

/*********************************************************
**  Public Procedures and Functions
*********************************************************/

-- Function add_attach
--
-- Description: This Function will add an AP Invoice WebNow URL attachment
--              to the input Entity.
FUNCTION add_attach( p_entity_name     IN fnd_attached_documents.entity_name%TYPE
                   , p_description     IN fnd_documents_tl.description%TYPE
                   , p_url             IN fnd_documents.file_name%TYPE
                   , p_pk1_value       fnd_attached_documents.pk1_value%TYPE  )
RETURN BOOLEAN IS

  --v_module          cust.ttec_error_handling.module_name%TYPE := 'add_attach';			-- Commented code by IXPRAVEEN-ARGANO,18-May-2023
  v_module          Apps.ttec_error_handling.module_name%TYPE := 'add_attach';              --  code Added by IXPRAVEEN-ARGANO,   18-May-2023
  v_loc             NUMBER;

  v_category_id     fnd_attached_documents.category_id%TYPE  := 1;                  -- Miscellaneous
  v_datatype_id     fnd_documents.datatype_id%TYPE           := 5;                  -- Web Page / URL
  v_usage_type      fnd_documents.usage_type%TYPE            := 'O';                -- One Time
  v_user_id         NUMBER                                   := fnd_global.user_id;

  v_seq_num         fnd_attached_documents.seq_num%TYPE;
  v_cnt             NUMBER;

  -- NULL variables necessary for API call
  v_function_name   fnd_attachment_functions.function_name%TYPE;
  v_text            VARCHAR2(1);
  v_file_name       VARCHAR2(1);
  v_pk2_value       fnd_attached_documents.pk1_value%TYPE;
  v_pk3_value       fnd_attached_documents.pk1_value%TYPE;
  v_pk4_value       fnd_attached_documents.pk1_value%TYPE;
  v_pk5_value       fnd_attached_documents.pk1_value%TYPE;
  v_media_id        NUMBER;

BEGIN

  v_loc := 10;
  -- Confirm that the attachment does not already exist
  SELECT COUNT(*)
    INTO v_cnt
    FROM fnd_attached_documents fad
       , fnd_documents_tl fdt
   WHERE fad.entity_name = p_entity_name
     AND fad.pk1_value = p_pk1_value
     AND fdt.document_id = fad.document_id
     AND fdt.language = 'US'
     AND description = p_description;

  IF v_cnt = 0 THEN

    v_loc := 20;
    -- Get the next PR Attachment sequence number
    SELECT NVL(TRUNC(MAX(seq_num),-1),0) + 10
      INTO v_seq_num
      FROM fnd_attached_documents
     WHERE entity_name = p_entity_name
       AND pk1_value = p_pk1_value;

    v_loc := 30;
    -- Add the attachment to the PR Header
    fnd_webattch.add_attachment( seq_num              => v_seq_num
                               , category_id          => v_category_id
                               , document_description => p_description
                               , datatype_id          => v_datatype_id
                               , text                 => v_text
                               , file_name            => v_file_name
                               , url                  => p_url
                               , function_name        => v_function_name
                               , entity_name          => p_entity_name
                               , pk1_value            => p_pk1_value
                               , pk2_value            => v_pk2_value
                               , pk3_value            => v_pk3_value
                               , pk4_value            => v_pk4_value
                               , pk5_value            => v_pk5_value
                               , media_id             => v_media_id
                               , user_id              => v_user_id
                               , usage_type           => v_usage_type     );
  ELSE

    v_loc := 40;
    --Log error and continue
    ttec_error_logging.process_error
      ( g_application_code, g_interface, g_package
      , v_module, g_info_status
      , NULL, 'Attachment already exists'
      , 'Entity',p_entity_name
      , 'Doc ID',p_pk1_value
      , 'Description',p_description
      , 'URL',p_url );

  END IF;

  RETURN TRUE;

EXCEPTION
  WHEN OTHERS THEN
    ttec_error_logging.process_error
      ( g_application_code, g_interface, g_package
      , v_module, g_failure_status
      , SQLCODE, SUBSTRB(SQLERRM,512)
      , g_label1, v_loc );

    RETURN FALSE;

END add_attach;


/************************************************************************************/
/*                               MAIN PROGRAM PROCEDURE                             */
/************************************************************************************/

-- PROCEDURE main
--
-- Description: This is the main process which will select eligible invoices from
--              '01-JAN-2006' to today and add WebNow URL attachments to each of them
--              and their associated PR's for the Image of the actual Invoice.
PROCEDURE main( p_bucket_number   IN  NUMBER
              , p_buckets         IN  NUMBER ) IS

  --v_module          cust.ttec_error_handling.module_name%TYPE := 'main';			-- Commented code by IXPRAVEEN-ARGANO,18-May-2023
  v_module          Apps.ttec_error_handling.module_name%TYPE := 'main';            --  code Added by IXPRAVEEN-ARGANO,   18-May-2023
  v_loc             NUMBER;

  v_inv_entity_name fnd_attached_documents.entity_name%TYPE  := 'AP_INVOICES';
  v_pr_entity_name  fnd_attached_documents.entity_name%TYPE  := 'REQ_HEADERS';

  v_description     fnd_documents_tl.description%TYPE;
  v_url             fnd_documents.file_name%TYPE;

  v_commit_cnt      NUMBER := 0;
  c_commit_pnt      NUMBER := 100;

  CURSOR c_ap_invoices IS
    SELECT aia.invoice_id
         , aia.invoice_num
         , pv.segment1 vendor_num
         , hou.name org
         , fpov.profile_option_value||'index.jsp?action=filter&username=anonymous&password=1&folder='||pv.segment1||'&field4='||aia.invoice_num url
      FROM apps.ap_invoices_all aia
         , apps.po_vendors pv
         , apps.hr_all_organization_units hou
         , apps.fnd_profile_options fpo
         , apps.fnd_profile_option_values fpov
     WHERE aia.invoice_date >= TO_DATE('01-JAN-2006','DD-MON-YYYY')
       AND aia.invoice_type_lookup_code IN ('CREDIT','STANDARD')
       AND pv.vendor_id = aia.vendor_id
       AND pv.vendor_type_lookup_code != 'EMPLOYEE'
       AND hou.organization_id = aia.org_id
       AND fpo.profile_option_name = 'TTEC WEBNOW HOST ADDRESS'
       AND fpov.application_id = fpo.application_id
       AND fpov.profile_option_id = fpo.profile_option_id
       AND fpov.level_id = 10001
       AND fpov.level_value = 0
       AND MOD( aia.invoice_id, NVL( p_buckets, 1 )) = NVL( p_bucket_number, 0 )
    ORDER BY 2,1;

  CURSOR c_po_reqs( l_invoice_id NUMBER ) IS
    SELECT UNIQUE rh.requisition_header_id req_id
         , rh.segment1 req_num
      FROM apps.ap_invoice_distributions_all aid
         , apps.po_distributions_all pd
         , apps.po_req_distributions_all rd
         , apps.po_requisition_lines_all rl
         , apps.po_requisition_headers_all rh
     WHERE aid.invoice_id = l_invoice_id
       AND pd.po_distribution_id = aid.po_distribution_id
       AND rd.distribution_id = pd.req_distribution_id
       AND rl.requisition_line_id = rd.requisition_line_id
       AND rh.requisition_header_id = rl.requisition_header_id;

BEGIN

  v_loc := 10;
  FOR inv_rec IN c_ap_invoices
  LOOP

    v_loc := 20;
    v_url := inv_rec.url;
    v_description := 'Invoice '||inv_rec.invoice_num||' WebNow Link';

    FOR pr_rec IN c_po_reqs( inv_rec.invoice_id )
    LOOP

      v_loc := 30;
      -- Add the attachment to the PR Header
      IF add_attach( p_entity_name => v_pr_entity_name
                   , p_description => v_description
                   , p_url         => v_url
                   , p_pk1_value   => TO_CHAR(pr_rec.req_id) )
      THEN g_prs_processed := g_prs_processed + 1;
      ELSE
        g_prs_errored := g_prs_errored + 1;

        --Log error and continue
        ttec_error_logging.process_error
          ( g_application_code, g_interface, g_package
          , v_module, g_warning_status
          , SQLCODE, SQLERRM
          , g_label1, v_loc
          , 'Org',inv_rec.org
          , 'PR #',pr_rec.req_num
          , 'Description',v_description
          , 'URL',v_url );
      END IF;

    END LOOP;

    v_loc := 40;
    -- Add the attachment to the AP Invoice Header
    IF add_attach( p_entity_name => v_inv_entity_name
                 , p_description => v_description
                 , p_url         => v_url
                 , p_pk1_value   => TO_CHAR(inv_rec.invoice_id) )
    THEN g_invs_processed := g_invs_processed + 1;
    ELSE
      g_invs_errored := g_invs_errored + 1;

      --Log error and continue
      ttec_error_logging.process_error
        ( g_application_code, g_interface, g_package
        , v_module, g_warning_status
        , SQLCODE, SQLERRM
        , g_label1, v_loc
        , 'Org',inv_rec.org
        , 'Invoice #',inv_rec.invoice_num
        , 'Description',v_description
        , 'URL',v_url );
    END IF;

    v_loc := 50;
    v_commit_cnt := v_commit_cnt + 1;

    IF v_commit_cnt = c_commit_pnt THEN
      COMMIT;
      v_commit_cnt := 0;
    END IF;

  END LOOP;

  COMMIT;

EXCEPTION
  WHEN OTHERS THEN
    ttec_error_logging.process_error
      ( g_application_code, g_interface, g_package
      , v_module, g_failure_status
      , SQLCODE, SUBSTRB(SQLERRM,512)
      , g_label1, v_loc );

    ROLLBACK;

    g_fail_flag := TRUE;
    g_fail_msg := SQLERRM;
END main;


-- PROCEDURE conc_mgr_wrapper
--
-- Description: This is the front end process called by the Concurrent Manager.  It is responsible
--              for producing the Output and Log Files along with returning the final process status.
--              It calls the Main process to perform the actual data processing.
PROCEDURE conc_mgr_wrapper( errbuf           OUT  VARCHAR2
                          , retcode          OUT  NUMBER
                          , p_bucket_number   IN  NUMBER
                          , p_buckets         IN  NUMBER ) IS

  --v_module            cust.ttec_error_handling.module_name%TYPE := 'conc_mgr_wrapper';			-- Commented code by IXPRAVEEN-ARGANO,18-May-2023
  v_module            Apps.ttec_error_handling.module_name%TYPE := 'conc_mgr_wrapper';              --  code Added by IXPRAVEEN-ARGANO,   18-May-2023
  v_loc               NUMBER;

  v_start_timestamp   DATE      := SYSDATE;
  e_cleanup_err       EXCEPTION;

BEGIN

  -- Submit the Main Process
  main( p_bucket_number, p_buckets );

  -- Log Counts
  BEGIN
    -- Write to Log
    fnd_file.new_line(fnd_file.log,1);
    fnd_file.put_line(fnd_file.log,'AP INVOICE ATTACHMENT COUNTS');
    fnd_file.put_line(fnd_file.log,'---------------------------------------------------------');
    fnd_file.put_line(fnd_file.log,'  # Processed           : '||g_invs_processed);
    fnd_file.put_line(fnd_file.log,'  # Errored             : '||g_invs_errored);
    fnd_file.put_line(fnd_file.log,'---------------------------------------------------------');
    fnd_file.new_line(fnd_file.log,1);
    fnd_file.put_line(fnd_file.log,'PR ATTACHMENT COUNTS');
    fnd_file.put_line(fnd_file.log,'---------------------------------------------------------');
    fnd_file.put_line(fnd_file.log,'  # Processed           : '||g_prs_processed);
    fnd_file.put_line(fnd_file.log,'  # Errored             : '||g_prs_errored);
    fnd_file.put_line(fnd_file.log,'---------------------------------------------------------');
    fnd_file.new_line(fnd_file.log,2);

    -- Write to Output
    fnd_file.put_line(fnd_file.output,'AP INVOICE ATTACHMENT COUNTS');
    fnd_file.put_line(fnd_file.output,'---------------------------------------------------------');
    fnd_file.put_line(fnd_file.output,'  # Processed           : '||g_invs_processed);
    fnd_file.put_line(fnd_file.output,'  # Errored             : '||g_invs_errored);
    fnd_file.put_line(fnd_file.output,'---------------------------------------------------------');
    fnd_file.new_line(fnd_file.output,1);
    fnd_file.put_line(fnd_file.output,'PR ATTACHMENT COUNTS');
    fnd_file.put_line(fnd_file.output,'---------------------------------------------------------');
    fnd_file.put_line(fnd_file.output,'  # Processed           : '||g_prs_processed);
    fnd_file.put_line(fnd_file.output,'  # Errored             : '||g_prs_errored);
    fnd_file.put_line(fnd_file.output,'---------------------------------------------------------');
    fnd_file.new_line(fnd_file.output,2);

    IF g_invs_errored > 0 OR g_prs_errored > 0 THEN
      retcode := 1;        -- Lable CR with WARNING
    END IF;

  EXCEPTION
    WHEN OTHERS THEN
      fnd_file.put_line( fnd_file.LOG, '   Error reporting Counts' );
      retcode := 1;
  END;

  -- Log Errors / Warnings
  BEGIN

    -- Critical Failures from this Package
    ttec_error_logging.log_error_details
      ( p_application   => g_application_code
      , p_interface     => g_interface
      , p_message_type  => g_failure_status
      , p_message_label => 'CRITICAL ERRORS - FAILURE'
      , p_request_id    => g_request_id
      );

    -- Warnings from this Package
    ttec_error_logging.log_error_details
      ( p_application   => g_application_code
      , p_interface     => g_interface
      , p_message_type  => g_warning_status
      , p_message_label => 'Additional Warning Messages'
      , p_request_id    => g_request_id
      );

    -- Warnings from this Package
    ttec_error_logging.log_error_details
      ( p_application   => g_application_code
      , p_interface     => g_interface
      , p_message_type  => g_info_status
      , p_message_label => 'Additional Information'
      , p_request_id    => g_request_id
      );

  EXCEPTION
    WHEN OTHERS THEN
      fnd_file.put_line( fnd_file.LOG, '   Error Reporting Errors / Warnings' );
      retcode := 1;
  END;

  -- Cleanup Log Table
  BEGIN
    -- Purge old Logging Records for this Interface
    ttec_error_logging.purge_log_errors( p_application => g_application_code
                                       , p_interface   => g_interface
                                       , p_keep_days   => g_keep_days
                                       );
  EXCEPTION
    WHEN OTHERS THEN
      fnd_file.put_line( fnd_file.LOG, 'Error Cleaning up Log tables' );
      fnd_file.put_line( fnd_file.LOG, SQLCODE || ': ' || SQLERRM );
      retcode := 2;
      errbuf := SQLERRM;
  END;

  IF g_fail_flag THEN
    fnd_file.put_line( fnd_file.LOG, 'Refer to Output for Detailed Errors and Warnings' );
    retcode := 2;
    errbuf := g_fail_msg;
  END IF;

EXCEPTION
  WHEN OTHERS THEN
    fnd_file.put_line( fnd_file.LOG, SQLCODE || ': ' || SQLERRM );
    retcode := 2;
    errbuf := SQLERRM;
END conc_mgr_wrapper;


END TTEC_AP_WEBNOW_ATTACH;
/
show errors;
/