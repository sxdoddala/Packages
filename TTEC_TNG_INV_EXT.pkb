create or replace PACKAGE BODY      TTEC_TNG_INV_EXT
AS
/********************************************************************************
    PROGRAM NAME:   TTEC_TNG_INV_EXT

    DESCRIPTION:    This package extracts Tangoe Invoices Paid in present date

    INPUT      :    Payment Date

    OUTPUT     :   NA

    CREATED BY:     Elango Pandurangan

    DATE:           11-DEC-2013

    CALLING FROM   :  Teletech Tangoe Invoice Extract

    ----------------
    MODIFICATION LOG
    ----------------

--  Version      DEVELOPER             DATE          DESCRIPTION
--  -------     -------------------   ------------  -----------------------------------------------------------
--      1.0     Nimai Meher              10-Nov-2013     Initial Version
--      1.1     CCHAN                 08-Aug-2014    Date format changes on filename from MMDDYYYY to RRRRMMDD
--      1.2     CCHAN                 27-Aug-2014    Changes are the following:
                                                       1.     The name of the "invoiceamount" column should be named just "Amount"
                                                       2.     Make sure that the vendor number is a concatenation of the TTECH Oracle Supplier Number_ TTECH Paysite Code
                                                       3.     Change file naming convention to " TTI_PAYMENT_MMDDYYYY " instead of "CTM_PAYMENT_MMDDYYYY.csv"
                                                       4.   Incorrect Payment amount
                                                       5.   Incorrect Payment date Range
--      1.3     Amir Aslam            08/04/2015  changes for Re hosting Project
--		1.0		IXPRAVEEN(ARGANO)    02-May-2023	R12.2 Upgrade Remediation
********************************************************************************/
PROCEDURE main(
    errbuf OUT NOCOPY  VARCHAR2,
    retcode OUT NOCOPY VARCHAR2,
    p_date IN VARCHAR2 )
AS
  v_dt_time VARCHAR2(100);
  --v_path varchar2(300):='$CUST_TOP/data/dac_data/data_in';
  --v_path varchar2(300):='/d41/applcrp1/CRP1/apps/apps_st/appl/teletech/12.0.0/data/dac_data/data_in';
  --v_path varchar2(300):='/d41/applcrp1/CRP1/apps/apps_st/comn/temp'; -- for testing only , file created in this path
  v_path        VARCHAR2(400);
  v_filename    VARCHAR2(100); /* 1.1 */
  v_date        DATE;
  v_columns_str VARCHAR2(4000);
  v_header      VARCHAR2(4000);
  CURSOR tng_inv
  IS
    SELECT --aia.INVOICE_ID "Invoice Id",
  aia.INVOICE_NUM InvoiceNumber,
  to_char(aia.INVOICE_DATE,'DD-MON-YY') InvoiceDate,
  to_char(aia.INVOICE_AMOUNT,99999999.99) InvoiceAmount,
  --aps.segment1 VendorNumber, /* 1.2.2 */
  aps.SEGMENT1 ||'_'|| assa.VENDOR_SITE_CODE VendorNumber,  /* 1.2.2 */
  ACA.CHECK_NUMBER CheckNumber,
  to_char(ACA.check_date,'DD-MON-YY')  CheckDate,
  --aca.amount PaymentAmount, /* 1.2.4 */
  to_char(aip.AMOUNT,99999999.99) PaymentAmount,   /* 1.2.4 */
  replace(aia.description,',',' ')  InternalComments, -- as per mail from Bhusan on January 08, 2014
  replace(aca.description,',',' ') RemittanceNotes -- as per mail from Bhusan on January 08, 2014
--START R12.2 Upgrade Remediation
/*
FROM ap.ap_invoices_all aia,
  ap.AP_SUPPLIER_SITES_ALL assa,/* 1.2.2 */ -- Commented code by IXPRAVEEN-ARGANO, 02-May-2023
  --ap.ap_suppliers aps ,*/
  
  FROM apps.ap_invoices_all aia,
  apps.AP_SUPPLIER_SITES_ALL assa,/* 1.2.2 */	--  code Added by IXPRAVEEN-ARGANO, 02-May-2023
  apps.ap_suppliers aps ,
  --END R12.2.10 Upgrade remediation
  AP_INVOICE_PAYMENTS_ALL AIP,
  AP_CHECKS_ALL ACA
WHERE aia.VENDOR_ID          =aps.VENDOR_ID
--AND aia.Invoice_id= 1938253
and aia.VENDOR_SITE_ID = assa.VENDOR_SITE_ID /* 1.2.2 */
AND AIP.ORG_ID = assa.org_id /* 1.2.2 */
AND assa.PAY_SITE_FLAG = 'Y' /* 1.2.2 */
AND aps.VENDOR_ID = assa.VENDOR_ID /* 1.2.2 */
AND aps.PAY_GROUP_LOOKUP_CODE = assa.PAY_GROUP_LOOKUP_CODE /* 1.2.2 */
AND AIA.INVOICE_ID = AIP.INVOICE_ID
AND AIP.CHECK_ID = ACA.CHECK_ID
--and trunc(ACA.check_date) = trunc(v_date);
--and trunc(ACA.check_date) between trunc(NEXT_DAY(v_date-7,'FRIDAY')) and trunc(NEXT_DAY(v_date-7,'FRIDAY'))+6; /* 1.2.6 */
and trunc(ACA.check_date) between trunc(NEXT_DAY(v_date-7,'FRIDAY')) - 6 and trunc(NEXT_DAY(v_date-7,'FRIDAY')); /* 1.2.6 */

BEGIN
  SELECT TO_CHAR(sysdate,'MMDDDYYYY') INTO v_dt_time FROM dual; /* 2.0 */
  /*select fnd_profile.value('ORG_ID') into v_org from dual;
  FND_FILE.PUT_LINE(FND_FILE.LOG,'ORG_ID : '||v_org);*/
  SELECT To_date(p_date,'YYYY/MM/DD HH24:MI:SS')
  INTO V_DATE
  FROM dual;
  FND_FILE.PUT_LINE(FND_FILE.LOG,'p_date : '||p_date);
  FND_FILE.PUT_LINE(FND_FILE.LOG,'V_date : '||V_date);
  BEGIN
    SELECT directory_path
      || '/data/EBS/FIN/AP/Tangoe/Outbound' /* 1.1 */
     ,  (select decode(HOST_NAME,ttec_library.XX_TTEC_PROD_HOST_NAME,'','TEST_')||'TTI_PAYMENT'  --  -- Changes for Version 1.3
    --,  (select decode(HOST_NAME,'den-erp046','','TEST_')||'TTI_PAYMENT' /* 1.2.3 */  -- Changes for Version 1.3
    ||'_'||  to_char(SYSDATE,'RRRRMMDD')
    from v$INSTANCE)
    ||  '.csv' file_name
    INTO v_path,v_filename
    FROM dba_directories
    WHERE directory_name = 'CUST_TOP';
    --v_path := '$CUST_TOP/data/EBS/HC/HR';
  EXCEPTION
  WHEN OTHERS THEN
    fnd_file.put_line(fnd_file.log,'Program did not get destination directory : '||sqlerrm);
    raise;
  END ;
  --TTEC_TNG_INV_EXT.write_process('CTM_PAYMENT_'||v_dt_time||'.csv','','W',v_path); /* 1.1 */
  TTEC_TNG_INV_EXT.write_process(v_filename,'','W',v_path); /* 1.1 */
  -- Writing Header /* 1.2.1 */
  v_header := 'InvoiceNumber,InvoiceDate,Amount,VendorNumber,CheckNumber,CheckDate,PaymentAmount,InternalComments,RemittanceNotes,';
  fnd_file.put_line(fnd_file.output,v_header);
  --TTEC_TNG_INV_EXT.write_process('CTM_PAYMENT_'||v_dt_time||'.csv', v_header,'A',v_path); /* 1.1 */
  TTEC_TNG_INV_EXT.write_process(v_filename, v_header,'A',v_path); /* 1.1 */
  FOR cur_tng_inv IN tng_inv
  LOOP
   v_columns_str := cur_tng_inv.InvoiceNumber||','||cur_tng_inv.InvoiceDate||','||cur_tng_inv.InvoiceAmount||','||cur_tng_inv.VendorNumber||','||cur_tng_inv.CheckNumber||','||cur_tng_inv.CheckDate||','||cur_tng_inv.PaymentAmount||','||cur_tng_inv.InternalComments||','||cur_tng_inv.RemittanceNotes||',';
    fnd_file.put_line(fnd_file.output,v_columns_str);
    --TTEC_TNG_INV_EXT.write_process('CTM_PAYMENT_'||v_dt_time||'.csv', v_columns_str,'A',v_path);/* 1.1 */
    TTEC_TNG_INV_EXT.write_process(v_filename, v_columns_str,'A',v_path);/* 1.1 */
  END LOOP;


  fnd_file.put_line(fnd_file.log,'PROGRAM SUCCESSFULLY COMPLETED');
EXCEPTION
WHEN OTHERS THEN
  fnd_file.put_line(fnd_file.log,'Program completed with error '||sqlerrm);
  raise;
END main;
PROCEDURE write_process(
    p_file_name IN VARCHAR2,
    p_data      IN VARCHAR2,
    p_mode      IN VARCHAR2,
    p_path      IN VARCHAR2)
AS
  F1 UTL_FILE.FILE_TYPE;
  v_path VARCHAR2(200):=p_path;
BEGIN
  --fnd_file.put_line(fnd_file.log,'extract line : '||p_data);
  F1        := UTL_FILE.FOPEN(v_path,p_file_name,p_mode,32767);
  IF p_data IS NOT NULL THEN
    UTL_FILE.put_line(F1,p_data,false);
    --UTL_FILE.NEW_LINE(F1, 1);
  END IF;
  utl_file.fflush(F1);
  UTL_FILE.FCLOSE(F1);
EXCEPTION
WHEN OTHERS THEN
  fnd_file.put_line(fnd_file.log,'Write_process could not complete successfully: '||sqlerrm||' : '||v_path);
END write_process;
END TTEC_TNG_INV_EXT;
/
show errors;
/