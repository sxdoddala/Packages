create or replace PACKAGE BODY ttec_ap_oie_pkg
AS


  ------------------------------------------------------------
  -- Called cm to update AMEX CC transaction
   /************************************************************************************
        Program Name: TTEC_AP_OIE_PKG 

        Description:   

        Developed by : 
        Date         :  

       Modification Log
       Name                  Version #    Date            Description
       -----                 --------     -----           -------------
    RXNETHI(ARGANO)            1.0      02-May-2023      R12.2 Upgrade Remediation
    ****************************************************************************************/
  ------------------------------------------------------------
  PROCEDURE	  set_cc_trans (
  			  			       	 	errbuf OUT VARCHAR2
							   	,   retcode OUT NUMBER
  			  			   		,	in_type        in varchar2
                            	,	cc_number        in varchar2
                            	, 	in_date			  DATE
								 )IS

  l_date date := in_date;

BEGIN


    IF in_type='P' THEN -- P for Purge

		-- Marks transactions as already processed
		--UPDATE AP.AP_CREDIT_CARD_TRXNS_ALL    --code commented by RXNETHI-ARGANO,05/02/23
		UPDATE APPS.AP_CREDIT_CARD_TRXNS_ALL    --code added by RXNETHI-ARGANO,05/02/23
		SET	   report_header_id= -9999
		WHERE  CARD_NUMBER=cc_number
	    AND    posted_date < l_date
		AND    report_header_id is null;

	ELSIF in_type='R' THEN  -- R for reset
		-- Marks transactions unprocessed
		--UPDATE AP.AP_CREDIT_CARD_TRXNS_ALL     --code commented by RXNETHI-ARGANO,05/02/23
		UPDATE APPS.AP_CREDIT_CARD_TRXNS_ALL     --code added by RXNETHI-ARGANO,05/02/23
		SET	   report_header_id= NULL
		WHERE  CARD_NUMBER=cc_number
	    AND    posted_date > l_date
		AND	   report_header_id = -9999;

    END IF; -- run mode

	COMMIT;

	fnd_file.put_line( fnd_file.LOG, 'Records modified - ');

EXCEPTION
 WHEN OTHERS THEN
    RAISE;

END set_cc_trans;


------------------------------------------------------------
  -- Called cm to update AMEX vendor info
  ------------------------------------------------------------
  PROCEDURE	  set_cc_vendor (in_type        in varchar2,
                             in_trx_id in number)IS


BEGIN

    IF in_type='N' THEN -- N for Vendor Name

		-- Reset Vendor name fields due to corrupt char
		--UPDATE AP.AP_CREDIT_CARD_TRXNS_ALL   --code commented by RXNETHI-ARGANO,05/02/23
		UPDATE APPS.AP_CREDIT_CARD_TRXNS_ALL   --code added by RXNETHI-ARGANO,05/02/23
		SET	   merchant_name1 =null,
			   merchant_name2 =null
		WHERE  trx_id = in_trx_id;

	ELSIF in_type='A' THEN  -- A for Address
		-- Reset Vendor address fields due to corrupt char
		--UPDATE AP.AP_CREDIT_CARD_TRXNS_ALL       --code commented by RXNETHI-ARGANO,05/02/23
 		UPDATE APPS.AP_CREDIT_CARD_TRXNS_ALL       --code added by RXNETHI-ARGANO,05/02/23
		SET	   merchant_address1 =null,
			   merchant_address2 =null,
			   merchant_address3 =null,
			   merchant_address4 =null
		WHERE  trx_id = in_trx_id;

    END IF; --


EXCEPTION
 WHEN OTHERS THEN
    RAISE;

END set_cc_vendor;

END;
/
show errors;
/