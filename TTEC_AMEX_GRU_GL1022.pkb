create or replace PACKAGE BODY      TTEC_AMEX_GRU_GL1022 AS
--
-- Program Name:  TTEC_AMEX_GRU_GL1022
--
-- Description:  This program generates Global Remittance Fixed File Format mandated by:
--               AMEX Global Remit Layout (File Spec) v1.5.8.xlsx
-- Input/Output Parameters:
--
--
--
-- Tables Modified:  N/A
--
--
-- Created By:  Christiane Chan
-- Date: Dec 09, 2016
--
-- Version  Developer        Date        Description
-- -------  ----------       --------    --------------------------------------------------------------------
-- 1.0      C. Chan          12/9/2016   Copy from TTEC_AMEX_GLOBAL_REMITTANCE need to access GL1022 staging
--                                       table to obtain the Credit Card and Card Program number
--
-- 1.2      C. Chan          07/18/2017  Fix for feedback obtained from RogenSi Testing
-- 1.3      C. Chan          12/01/2017  Fix for 399 Length to 400
--1.0	IXPRAVEEN(ARGANO)  12-May-2023		R12.2 Upgrade Remediation
--
-- Global Variables ---------------------------------------------------------------------------------

PROCEDURE gen_global_amex_pay_file(errcode out varchar2, errbuff out varchar2, p_invoice_number       IN VARCHAR2) IS

    -- Filehandle Variables
    p_FileDir                      varchar2(200);
    p_FileName                     varchar2(200);
    p_Country                      varchar2(10);
    v_remittance_file              UTL_FILE.FILE_TYPE;

    NO_REMITTANCE                  EXCEPTION; /* 1.1 */
    -- Declare variables
    l_msg                          varchar2(2000);
    l_stage                           varchar2(100);
    l_country_sob                  varchar2(100);
    l_rec                            varchar2(400);
    l_key                          varchar2(100);
    l_process_date                 date;

    l_tot_rec_process              number; /* 1.1 */
    l_tot_rec_count                number;
    l_request_id                   number;
    l_seq                          number;

    v_request_id                   number;

    l_param1                       varchar2(240);
    l_param2                       varchar2(240);
    l_param3                       varchar2(240);
    l_param4                       varchar2(240);
    l_param5                       varchar2(240);
    v_process_status               varchar2(240);


    cursor c_directory_path is
    SELECT ttec_library.get_directory('CUST_TOP')|| '/data/EBS/FIN/AP/Amex_Global_Remit/Outbound/' directory_path
        ,'TTEC_GLOBAL_REMITTANCE_'|| to_char(SYSTIMESTAMP AT TIME ZONE dbtimezone,'YYYYMMDD_HH24_MI')|| '.out' file_name
    FROM DUAL;

    cursor c_get_param is
    SELECT ttec_library.get_directory('CUST_TOP')|| '/data/EBS/FIN/AP/Amex_Global_Remit/Outbound/' param1,
          'GRU_TTEC_GLOBAL_REMITTANCE_' ||decode(apps.TTEC_GET_INSTANCE,'PROD','PROD','TEST') ||'_'||'*'  param2,
           --decode(apps.TTEC_GET_INSTANCE,'PROD','/fin/ap/Amex_Global_Remit/outbound/prod','/fin/ap/Amex_Global_Remit/outbound/test') param3,
decode(apps.TTEC_GET_INSTANCE,'PROD','/fin/ap/Amex_Global_Remit/outbound/prod','/fin/ap/Amex_Global_Remit/outbound/test') param3,
           apps.TTEC_GET_SFTP_SERVER param4,
           decode(apps.TTEC_GET_INSTANCE,'PROD','erpebs@','erpebstest@') param5
    FROM DUAL;

--
-- File Header - Record Type 00
--

--    cursor c_header_record_type_00 is
--    SELECT  '00'                                                          -- Field #1 Record Type
--        --|| rpad('37613330',15,' ')                                      -- Field #2 Global Corporate Identifier
--        || rpad('TTEC',15,' ')                                  -- Field #2 Global Corporate Identifier
--        || to_char(SYSTIMESTAMP AT TIME ZONE dbtimezone,'YYYYMMDD')       -- Field #3 File Creation Date (GMT)
--        || to_char(SYSTIMESTAMP AT TIME ZONE dbtimezone,'HH24MISS')       -- Field #4 File Creation Time (GMT)
--        || decode(apps.TTEC_GET_INSTANCE,'PROD','  ','TT')                -- Field #5 Test File Indicator
--        || rpad(APPS.TT_AMEX_GLOBAL_REMIT_FILE_SEQ.nextval,20,' ')        -- Field #6 File ID
--        || rpad(' ',347,' ')                                              -- Field #7 Space Fill
--         record
--    FROM DUAL;

/* 1.1 */
cursor c_tot_record_process is
       SELECT  COUNT(*)
         --START R12.2 Upgrade Remediation
		 /*FROM     ap.ap_invoices_all ai					-- Commented code by IXPRAVEEN-ARGANO,12-May-2023
                , ap.ap_invoice_payments_all aip
                , ap.ap_checks_all ac
                , CUST.TTEC_PCARD_PHP_SUMM_HDR_ALL pc
              --  , ap.ap_expense_report_headers_all aeh
                , ap.ap_card_programs_all acp
--                , ap.ap_cards_all aca,
--                  apps.iby_creditcard  ic*/
		 FROM     APPS.ap_invoices_all ai						--  code Added by IXPRAVEEN-ARGANO,   12-May-2023
                , apps.ap_invoice_payments_all aip
                , apps.ap_checks_all ac
                , APPS.TTEC_PCARD_PHP_SUMM_HDR_ALL pc
              --  , ap.ap_expense_report_headers_all aeh
                , APPS.ap_card_programs_all acp
--                , ap.ap_cards_all aca,
--                  apps.iby_creditcard  ic
--END R12.2.12 Upgrade remediation
         WHERE    aip.check_id = ac.check_id
         --AND      ai.invoice_num = aeh.invoice_num
         AND      ai.invoice_num = pc.INVOICE_NUMBER
         AND      ai.invoice_id = aip.invoice_id
--         AND      aeh.employee_id = aca.employee_id
--         AND      ic.instrid = aca.card_reference_id
--         AND      aca.CARD_PROGRAM_ID =  acp.CARD_PROGRAM_ID
--         AND      acp.CARD_BRAND_LOOKUP_CODE = 'American Express'
--         AND      acp.CARD_TYPE_LOOKUP_CODE in ('TRAVEL','MEETING') /* 1.1 */
--         AND      acp.GL_PROGRAM_NAME LIKE '%GLOBAL AMEX CARD%' /* 1.1 */
--         and      acp.ATTRIBUTE2 IS NOT NULL --Company_ID
--         and      acp.ATTRIBUTE4 IS NOT NULL --Basic_Control_Account
--         and      acp.MARKET_CODE IS NOT NULL --market
--         and      acp.COMPANY_NUMBER IS NOT NULL --global_client_origin_id
--         and      acp.ATTRIBUTE1 IS NOT NULL --Load_number
--         and      acp.ATTRIBUTE3 IS NOT NULL --Book_number
--         and      acp.ATTRIBUTE5 IS NOT NULL --ISO Currency
--         and      acp.ATTRIBUTE6 IS NOT NULL --ISO Country
--         AND      aca.ORG_ID = aeh.ORG_ID -- 1.5
--         and      ac.CHECKRUN_NAME = 'TTCANAMEX022216'
--         and      ac.CHECK_DATE= l_process_date
         AND      pc.CM_BASIC_BCA_ACCT_NUM  = acp.ATTRIBUTE4
         and      pc.INVOICE_NUMBER = p_invoice_number --'PCARDTEST.01' --
         AND      ac.check_id  --=  '1100061787' --'1100061504' --p_check_num   -- p_check_number
            in (
                select aip1.CHECK_ID
                --START R12.2 Upgrade Remediation
				/*from ap.ap_invoice_payments_all aip1				-- Commented code by IXPRAVEEN-ARGANO,12-May-2023
                   , ap.ap_checks_all ac1*/
				from apps.ap_invoice_payments_all aip1				--  code Added by IXPRAVEEN-ARGANO,   12-May-2023
                   , apps.ap_checks_all ac1
				--END R12.2.12 Upgrade remediation
                where aip1.REMIT_TO_SUPPLIER_NAME like '%AMERICAN%EXPRESS%'
                  and aip1.CHECK_ID = ac1.CHECK_ID
                  --and ac1.CHECK_DATE =  l_process_date
                  and ac1.CHECK_ID = ac.check_id
          );
       --  AND      nvl(aca.inactive_date,'31-DEC-4712') >= ai.INVOICE_DATE /* 1.2 */

--
-- Remittance Detail - Record Type 01
--

cursor c_detail_record is
SELECT
/* 01 - 17 */         '01' Record_type --Set to "01" to indicate Remittance Detail Record
--/* 01 - 18 */        , DECODE(SIGN(aip.amount),1,'+','-') remit_amt_sign --Credit or Debit Identifier    Indicates whether it is a Credit to account (minus sign) or Debit to account (plus sign).
--/* 01 - 18 */        , DECODE(SIGN(aip.amount),1,'-','+') remit_amt_sign --Credit or Debit Identifier    Indicates whether it is a Credit to account (minus sign) or Debit to account (plus sign).
--/* 1.2 *//* 01 - 18 */        , DECODE(pc.CM_BALANCE_INDICATOR ,'+','-','-','+','-') remit_amt_sign --Credit or Debit Identifier    Indicates whether it is a Credit to account (minus sign) or Debit to account (plus sign).
--/* 01 - 19 */        , aip.amount remittance_amount --The remittance amount for the cardmember
--/* 1.2 *//* 01 - 19 */        , pc.CM_BALANCE remittance_amount --The remittance amount for the cardmember
/* 01 - 18 */        , DECODE(pc.TOTAL_REMITTED_AMOUNT ,'+','-'
                                                    ,'-','+','-') remit_amt_sign --Credit or Debit Identifier    Indicates whether it is a Credit to account (minus sign) or Debit to account (plus sign).
/* 01 - 19 */        , pc.TOTAL_REMITTED_AMOUNT remittance_amount --The remittance amount for the cardmember
/* 01 - 20 */        , 2 DECIMAL_PLACES --Remittance Decimal Places    Indicates the number of decimal places for the given remittance amount
--/* 01 - 22 */        , ic.ccnumber corporate_card_number --Card member's corporate card number
/* 01 - 22 */        , pc.CM_CARD_NUMBER corporate_card_number --Card member's corporate card number
/* 01 - 23 */        , acp.ATTRIBUTE2 Company_ID --The control account associated with the account number. Sourced from GL1205 and GL1025 Files.
/* 01 - 24 */        , acp.ATTRIBUTE4 Basic_Control_Account --Basic control account to which the card number is associated.  Sourced from GL1205 and GL1025 Files.
--/* 01 - 25 */        , acp.MARKET_CODE market --Sourced from GL1205 and GL1025 Files.
/* 01 - 25 */        , pc.CM_MARKET_CODE market --Sourced from GL1022 file
--/* 01 - 26 */        , acp.COMPANY_NUMBER global_client_origin_id --Sourced from GL 1205 and GL 1025 Files. This is usually the Market Code+CID combined into a single value.
/* 01 - 26 */        , pc.CM_COMPANY_NUMBER global_client_origin_id --Sourced from GL 1205 and GL 1025 Files. This is usually the Market Code+CID combined into a single value.
/* 01 - 27 */        , acp.ATTRIBUTE1 Load_number --ID assigned to the corporation - Corporations can be assigned more than 1 Sender ID or Load Number to correspond to the corporation's region or
/* 01 - 28 */        , acp.ATTRIBUTE3 Book_number --Identifier assigned by American Express at the time of setup
/* 01 - 29 */        , acp.ATTRIBUTE5  ISO_Currency_Code -- must be a valid NUMERIC ISO currency code, alpha codes cannot be used, value must match Neutral ISO
/* 01 - 31 */        , '01' RMCL1--  01  = CORPORATE REMITTANCE RECEIVED: Remittance Message Code - Line 1    The selected standard AMEX literal that is the message appearing next to the payment credited to a Cardmember account. For US only - will appear on statement: Code Message
/* 01 - 32 */        , '01' DMCL2--  01  = Expense Report #: Descriptive Message Code - Line 2    The code which drives the descriptive bill message which appears on the billing statement.  These messages will appear on the statement in the same sequence as they are on the file, however only the first line is required.  The messages should be selected from the Options section of this document .  For US only - will appear on statement: Code  Message
/* 01 - 33 */        , ai.invoice_num cdl2 --Expense_report_no: Company Data -  Line 2    The Client data which corresponds with the selected Descriptive Message
/* 01 - 34 */        , ' ' DMCL3 --Descriptive Message Code - Line 3 The code which drives the descriptive bill message which appears on the billing statement.  These messages will appear on the statement in the same sequence as they are in the file; however, only the first line is required.
/* 01 - 35 */        , RPAD(' ',16,' ') CDL3 --Company_Data_Line3    The Client data which corresponds with the selected Descriptive Message
/* 01 - 36 */        , ' ' DMCL4 --Descriptive Message Code - Line 4    The code which drives the descriptive bill message which appears on the billing statement.  These messages will appear on the statement in the same sequence as they are in the file; however, only the first line is required.
/* 01 - 37 */        , RPAD(' ',16,' ') CDL4 --Company Data for Previous Message Code  - Line 4    The Client data which corresponds with the selected Descriptive Message
/* 02 - 45 */        , acp.ATTRIBUTE6  ISO_Country_Code --  The country in which the American Express card was issued. The NUMERIC ISO code must be used. Sourced from GL1205 file (not available in GL1025)
/* 02 - 54 */        , aip.ACCOUNTING_DATE Payment_Posting_Date -- The date the transactions for the given Market and Currency Code should be posted Format: yyyymmdd
                , (
--select l.COUNTRY
--from apps.HR_ORGANIZATION_UNITS o,
--     hr.HR_LOCATIONS_ALL l
--where o.location_id is not null
--and o.location_id = l.location_id
--and o.organization_id = ( select o1.BUSINESS_GROUP_ID
--                          from apps.HR_ORGANIZATION_UNITS o1
--                          where o1.organization_id = aca.ORG_ID
--                          and rownum < 2 )
--and rownum < 2
SELECT
DECODE(c.currency_code,'EUR',  (select l.COUNTRY
                                from apps.HR_ORGANIZATION_UNITS o,
                                     --hr.HR_LOCATIONS_ALL l				-- Commented code by IXPRAVEEN-ARGANO,12-May-2023
                                     apps.HR_LOCATIONS_ALL l                  --  code Added by IXPRAVEEN-ARGANO,   12-May-2023
                                where o.location_id is not null
                                and o.location_id = l.location_id
                                and o.organization_id = hou.ORGANIZATION_ID
                                and rownum < 2 )
                      ,'USD',  (select l.COUNTRY
                                from apps.HR_ORGANIZATION_UNITS o,
                                     --hr.HR_LOCATIONS_ALL l			-- Commented code by IXPRAVEEN-ARGANO,12-May-2023
                                     apps.HR_LOCATIONS_ALL l              --  code Added by IXPRAVEEN-ARGANO,   12-May-2023
                                where o.location_id is not null
                                and o.location_id = l.location_id
                                and o.organization_id = hou.ORGANIZATION_ID
                                and rownum < 2 )
                      ,NULL,   (select l.COUNTRY
                                from apps.HR_ORGANIZATION_UNITS o,
                                     --hr.HR_LOCATIONS_ALL l			-- Commented code by IXPRAVEEN-ARGANO,12-May-2023
                                     apps.HR_LOCATIONS_ALL l              --  code Added by IXPRAVEEN-ARGANO,   12-May-2023
                                where o.location_id is not null
                                and o.location_id = l.location_id
                                and o.organization_id = hou.ORGANIZATION_ID
                                and rownum < 2 )
                      ,c.ISSUING_TERRITORY_CODE)country_code
FROM apps.hr_operating_units hou
   --, gl.gl_ledgers gl			-- Commented code by IXPRAVEEN-ARGANO,12-May-2023
   , apps.gl_ledgers gl           --  code Added by IXPRAVEEN-ARGANO,   12-May-2023
   , gl_currencies c
where gl.ledger_id = hou.SET_OF_BOOKS_ID
and c.CURRENCY_CODE = gl.CURRENCY_CODE
and hou.BUSINESS_GROUP_ID != hou.ORGANIZATION_ID
and hou.ORGANIZATION_ID = pc.ORG_ID
and rownum < 2
)  Country_code
                , ac.CHECK_DATE
                , ac.CHECKRUN_NAME
                , ac.check_number
                , ac.amount
                , ac.VENDOR_NAME
                , ai.set_of_books_id sob
                , ai.INVOICE_CURRENCY_CODE
                , ai.PAYMENT_METHOD_CODE
                , ai.EXTERNAL_BANK_ACCOUNT_ID
                , ai.INVOICE_TYPE_LOOKUP_CODE
                , ai.invoice_num
                , ai.INVOICE_DATE
              --  , ai.PROJECT_ID
                , ai.GL_DATE
                , ai.DESCRIPTION
                --, max(ic.ccnumber) card_number
                , aip.PERIOD_NAME
                , aip.POSTED_FLAG
                , aip.REMIT_TO_SUPPLIER_NAME
                , aip.REMIT_TO_SUPPLIER_SITE
                , SYSDATE creation_date
                , FND_GLOBAL.USER_ID created_by
                , FND_GLOBAL.CONC_REQUEST_ID  Request_ID
         --START R12.2 Upgrade Remediation
		 /*FROM     ap.ap_invoices_all ai					-- Commented code by IXPRAVEEN-ARGANO,12-May-2023
                , ap.ap_invoice_payments_all aip
                , ap.ap_checks_all ac
                , CUST.TTEC_PCARD_PHP_SUMM_HDR_ALL pc
              --  , ap.ap_expense_report_headers_all aeh
                , ap.ap_card_programs_all acp
--                , ap.ap_cards_all aca,
--                  apps.iby_creditcard  ic*/
		 FROM     apps.ap_invoices_all ai					--  code Added by IXPRAVEEN-ARGANO,   12-May-2023
                , apps.ap_invoice_payments_all aip
                , apps.ap_checks_all ac
                , apps.TTEC_PCARD_PHP_SUMM_HDR_ALL pc
              --  , ap.ap_expense_report_headers_all aeh
                , apps.ap_card_programs_all acp
--                , ap.ap_cards_all aca,
--                  apps.iby_creditcard  ic
			--END R12.2.12 Upgrade remediation
         WHERE    aip.check_id = ac.check_id
         --AND      ai.invoice_num = aeh.invoice_num
         AND      ai.invoice_num = pc.INVOICE_NUMBER
         AND      ai.invoice_id = aip.invoice_id
--         AND      aeh.employee_id = aca.employee_id
--         AND      ic.instrid = aca.card_reference_id
--         AND      aca.CARD_PROGRAM_ID =  acp.CARD_PROGRAM_ID
--         AND      acp.CARD_BRAND_LOOKUP_CODE = 'American Express'
--         AND      acp.CARD_TYPE_LOOKUP_CODE in ('TRAVEL','MEETING') /* 1.1 */
--         AND      acp.GL_PROGRAM_NAME LIKE '%GLOBAL AMEX CARD%' /* 1.1 */
--         and      acp.ATTRIBUTE2 IS NOT NULL --Company_ID
--         and      acp.ATTRIBUTE4 IS NOT NULL --Basic_Control_Account
--         and      acp.MARKET_CODE IS NOT NULL --market
--         and      acp.COMPANY_NUMBER IS NOT NULL --global_client_origin_id
--         and      acp.ATTRIBUTE1 IS NOT NULL --Load_number
--         and      acp.ATTRIBUTE3 IS NOT NULL --Book_number
--         and      acp.ATTRIBUTE5 IS NOT NULL --ISO Currency
--         and      acp.ATTRIBUTE6 IS NOT NULL --ISO Country
--         AND      aca.ORG_ID = aeh.ORG_ID -- 1.5
--         and      ac.CHECKRUN_NAME = 'TTCANAMEX022216'
--         and      ac.CHECK_DATE= l_process_date
         AND      pc.CM_BASIC_BCA_ACCT_NUM  = acp.ATTRIBUTE4
         and      pc.INVOICE_NUMBER = p_invoice_number --'PCARDTEST.01' --
--         and      bca_market_code is not null
         AND      ac.check_id  --=  '1100061787' --'1100061504' --p_check_num   -- p_check_number
            in (
                select aip1.CHECK_ID
                --START R12.2 Upgrade Remediation
				/*from ap.ap_invoice_payments_all aip1			-- Commented code by IXPRAVEEN-ARGANO,12-May-2023
                   , ap.ap_checks_all ac1*/
				from apps.ap_invoice_payments_all aip1			--  code Added by IXPRAVEEN-ARGANO,   12-May-2023
                   , apps.ap_checks_all ac1
					--END R12.2.12 Upgrade remediation
                where aip1.REMIT_TO_SUPPLIER_NAME like '%AMERICAN%EXPRESS%'
                  and aip1.CHECK_ID = ac1.CHECK_ID
                  --and ac1.CHECK_DATE =  l_process_date
                  and ac1.CHECK_ID = ac.check_id
          )
       --  AND      nvl(aca.inactive_date,'31-DEC-4712') >= ai.INVOICE_DATE /* 1.2 */
ORDER BY acp.ATTRIBUTE1
       , acp.ATTRIBUTE3
       , acp.ATTRIBUTE5
       , aip.ACCOUNTING_DATE
     --  , ic.ccnumber
       , pc.CM_CARD_NUMBER
       , ai.invoice_num;


cursor c_summary_record is
SELECT
/* 02 - 44 */           amex_market
/* 02 - 45 */        ,  amex_ISO_Country_code
/* 02 - 46 */        ,  amex_Load_number
/* 02 - 47 */        ,  amex_Book_number
/* 02 - 48 */        ,  amex_ISO_Currency_Code -- must be a valid NUMERIC ISO currency code, alpha codes cannot be used, value must match Neutral ISO Currency Code Sourced from GL1205 and GL1025 files.
/* 02 - 49 */        ,
DECODE(NVL((
select count(distinct l2.TTEC_REQUEST_ID)
--from CUST.TT_GLOBAL_AMEX_GRU_GL1022_LOG l2			-- Commented code by IXPRAVEEN-ARGANO,12-May-2023
from apps.TT_GLOBAL_AMEX_GRU_GL1022_LOG l2              --  code Added by IXPRAVEEN-ARGANO,   12-May-2023
where l2.TTEC_INVOICE_NUM = p_invoice_number
and l2.TTEC_REQUEST_ID <> l_request_id
),'0'),'0','00','01')
Resubmit_Version_No-- '01' if aready exist in the history table
/* 02 - 51 */        , --count(*)
SUM( 1) Record_Count-- The total number of transaction details for the given market and currency codes
/* 02 - 52 */        , --SUM
SUM(amex_remittance_amount) Total_Remittance-- Sum of all Remittance Credits - Sum of all Remittance Debits for the given Global Origin Identifier and ISO Currency Codes.
/* 02 - 53 */        , 2 Decimal_Places-- Indicates the number of decimal places for the given amount
/* 02 - 54 */        , amex_Payment_Posting_Date -- The date the transactions for the given Market and Currency Code should be posted Format: yyyymmdd
/* 02 - 55 */        --, ieba.BANK_ACCOUNT_NUM BRZ_Ref_Bank_No -- Transaction Reference Bank Number  , not mandatory will leave bank, potentially aip.BANK_NUM --make sure the same bank for given market_code (cemmented by C. Chan)
                     , NULL BRZ_Ref_Bank_No -- Transaction Reference Bank Number  , not mandatory will leave bank, potentially aip.BANK_NUM --make sure the same bank for given market_code (cemmented by C. Chan)
/* 02 - 56 */        , NULL BRZ_Bank_Code -- Required only if Brazil-based cards: Bank Code    The bank code to which the payment will be made
/* 02 - 57 */        , NULL BRZ_Bank_Agency_Code -- Required only if Brazil-based cards: Bank Agency Code    The bank agency to which the payment will be made
/* 02 - 58 */        , NULL BRZ_Bank_Acct_No-- Required only if Brazil-based cards: Bank Account Number    The bank account associated with the payment.
/* 02 - 59 */        --,  ebb.BRANCH_NUMBER
                     , NULL BRZ_Bank_SubAcct_No-- Required only if Brazil-based cards: Sub Account Number    Validation digits in the Bank Account Number.
/* 02 - 60 */        , ' '  Filler -- Filler
--FROM CUST.TT_GLOBAL_AMEX_GRU_GL1022_LOG l			-- Commented code by IXPRAVEEN-ARGANO,12-May-2023
FROM apps.TT_GLOBAL_AMEX_GRU_GL1022_LOG l           --  code Added by IXPRAVEEN-ARGANO,   12-May-2023
WHERE l.TTEC_REQUEST_ID = l_request_id
  --    , iby.iby_ext_bank_accounts ieba
   --   , apps.iby_ext_bank_branches_v ebb
--where l.TTEC_EXTERNAL_BANK_ACCOUNT_ID = ieba.ext_bank_account_id
--and ebb.BRANCH_PARTY_ID = ieba.BRANCH_ID
   --and ieba.ext_bank_account_id = ac.external_bank_account_id
GROUP BY
/* 02 - 44 */           amex_market
/* 02 - 45 */        ,  amex_ISO_Country_code
/* 02 - 46 */        ,  amex_Load_number
/* 02 - 47 */        ,  amex_Book_number
/* 02 - 48 */        ,  amex_ISO_Currency_Code -- must be a valid NUMERIC ISO currency code, alpha codes cannot be used, value must match Neutral ISO Currency Code Sourced from GL1205 and GL1025 files.
/* 02 - 53 */        , 2  -- Indicates the number of decimal places for the given amount
/* 02 - 54 */        , amex_Payment_Posting_Date;


BEGIN

    l_process_date := TRUNC(SYSDATE);

    l_stage    := '10';
    /* 1.1 begin */
    l_stage := 'c_rec_process';
    OPEN c_tot_record_process;
    FETCH c_tot_record_process INTO l_tot_rec_process;
    CLOSE c_tot_record_process;

    l_stage    := '20';

    IF l_tot_rec_process = 0 THEN
       RAISE NO_REMITTANCE;
    END IF;
    /* 1.1 end */

    l_stage := 'c_seq';


    SELECT APPS.TT_AMEX_GLOBAL_REMIT_FILE_SEQ.nextval
    INTO l_seq
    from dual;

    l_stage := 'c_directory_path';

--    open c_directory_path;
--    fetch c_directory_path into p_FileDir,p_FileName;
--    close c_directory_path;
    l_stage    := '30';
--    IF p_process_date IS NULL THEN
        SELECT ttec_library.get_directory('CUST_TOP')|| '/data/EBS/FIN/AP/Amex_Global_Remit/Outbound/' directory_path
            ,'GRU_TTEC_GLOBAL_REMITTANCE_' ||decode(apps.TTEC_GET_INSTANCE,'PROD','PROD','TEST') ||'_' || to_char(SYSTIMESTAMP AT TIME ZONE dbtimezone,'YYYYMMDDHH24MISS')||'_'||l_seq ||'.out' file_name
        into p_FileDir,p_FileName
        FROM DUAL;
--    ELSE
--        SELECT ttec_library.get_directory('CUST_TOP')|| '/data/EBS/FIN/AP/Amex_Global_Remit/Outbound/' directory_path
--            ,'GRU_TTEC_GLOBAL_REMITTANCE_' ||decode(apps.TTEC_GET_INSTANCE,'PROD','PROD','TEST') ||'_' ||  to_char(l_process_date,'YYYYMMDDHH24MISS')||'_'||l_seq ||'.out' file_name
--        into p_FileDir,p_FileName
--        FROM DUAL;
--    END IF;

    l_stage    := '40';
    v_remittance_file := UTL_FILE.FOPEN(p_FileDir, p_FileName, 'w');
    l_tot_rec_count          := 0;

   FND_FILE.PUT_LINE(FND_FILE.Log,'TTEC_AMEX_GRU_GL1022_EXTRACT');
   FND_FILE.PUT_LINE(FND_FILE.Log,'Submitted On: ' ||to_char(SYSDATE,'DD-MON-RRRR HH24:MI:SS'));
   FND_FILE.PUT_LINE(FND_FILE.Log,'');
   FND_FILE.PUT_LINE(FND_FILE.Log,'=============================================================================');
   FND_FILE.PUT_LINE(FND_FILE.Log,'                          Parameters');
   FND_FILE.PUT_LINE(FND_FILE.Log,'=============================================================================');
   FND_FILE.PUT_LINE(FND_FILE.Log,'  Global Corp Identifier: '||'TTEC');
   FND_FILE.PUT_LINE(FND_FILE.Log,'           GRU File Name: '||p_FileName);

    --
    --  File Header - Record Type 00
    --

    l_stage := 'Header Record Type 00';

--    IF p_process_date IS NULL THEN

        SELECT  '00'                                                          -- Field #1 Record Type
            --|| rpad('37613330',15,' ')                                      -- Field #2 Global Corporate Identifier
            || rpad('TTEC',15,' ')                                  -- Field #2 Global Corporate Identifier
            || to_char(SYSTIMESTAMP AT TIME ZONE dbtimezone,'YYYYMMDD')       -- Field #3 File Creation Date (GMT)
            || to_char(SYSTIMESTAMP AT TIME ZONE dbtimezone,'HH24MISS')       -- Field #4 File Creation Time (GMT)
            || decode(apps.TTEC_GET_INSTANCE,'PROD','  ','TT')                -- Field #5 Test File Indicator
            || rpad(l_seq,20,' ')                                             -- Field #6 File ID
            || rpad(' ',347,' ')  /* 1.3 restore original */                  -- Field #7 Space Fill
           -- || rpad(' ',346,' ')                                            -- Field #7 Space Fill
             record
        INTO l_rec
        FROM DUAL;
--    ELSE
--        SELECT  '00'                                                          -- Field #1 Record Type
--            --|| rpad('37613330',15,' ')                                      -- Field #2 Global Corporate Identifier
--            || rpad('TTEC',15,' ')                                  -- Field #2 Global Corporate Identifier
--            || to_char(l_process_date,'YYYYMMDD')                             -- Field #3 File Creation Date (GMT)
--            || to_char(SYSTIMESTAMP AT TIME ZONE dbtimezone,'HH24MISS')       -- Field #4 File Creation Time (GMT)
--            || decode(apps.TTEC_GET_INSTANCE,'PROD','  ','TT')                -- Field #5 Test File Indicator
--            || rpad(l_seq,20,' ')                                             -- Field #6 File ID
--          --  || rpad(' ',347,' ')                                              -- Field #7 Space Fill
--            || rpad(' ',346,' ')                                              -- Field #7 Space Fill
--             record
--        INTO l_rec
--        FROM DUAL;
--    END IF;

    l_tot_rec_count := l_tot_rec_count + 1;

    utl_file.put_line(v_remittance_file, l_rec);

    --
    --  Remittance Detail - Record Type 01
    --

    l_stage := 'Detail Record Type 01';

    For v_rec in c_detail_record loop

        l_country_sob := 'Country: ['||v_rec.Country_code||'] SOB: ['||to_char(v_rec.SOB)||']';
        l_key := 'CC_INV'||v_rec.corporate_card_number||'_'||v_rec.check_number;
        l_request_id := v_rec.request_id;

        l_rec :=
               '01'                                                                            -- Field #1  Set to "01" to indicate Remittance Detail Record
            || v_rec.remit_amt_sign                                                            -- Field #2  Credit or Debit Identifier    Indicates whether it is a Credit to account (minus sign) or Debit to account (plus sign).
            --|| nvl(substr(lpad(v_rec.remittance_amount,20,'0'),1,20),lpad('0',20,'0'))         -- Field #3  The remittance amount for the cardmember
            || nvl(replace(replace(replace(to_char(v_rec.remittance_amount,'S00000000000000000.00'),'+','0'),'-','0'),'.',''),lpad('0',20,'0')) -- Field #3  The remittance amount for the cardmember
            || v_rec.DECIMAL_PLACES                                                            -- Field #4  Remittance Decimal Places    Indicates the number of decimal places for the given remittance amount
            || lpad('0',42,'0')                                                                -- Field #5  Data formerly used in this area is obsolete.
            || nvl(substr(lpad(v_rec.corporate_card_number,20,'0'),1,20),lpad('0',20,'0'))     -- Field #6  Card member's corporate card number
           -- || nvl(substr(lpad(v_rec.Company_ID ,19,'0'),1,19),lpad('0',19,'0'))               -- Field #7  The control account associated with the account number. Sourced from GL1205 and GL1025 Files.
            || nvl(substr(lpad('' ,19,'0'),1,19),lpad('0',19,'0'))               -- Field #7  The control account associated with the account number. Sourced from GL1205 and GL1025 Files.
            || nvl(substr(lpad(v_rec.Basic_Control_Account,19,'0'),1,19),lpad('0',19,'0'))     -- Field #8  Basic control account to which the card number is associated.  Sourced from GL1205 and GL1025 Files.
            || nvl(substr(lpad(v_rec.market,3,'0'),1,3),lpad('0',3,'0'))                       -- Field #9  Sourced from GL1205 and GL1025 Files.
            || nvl(substr(rpad(v_rec.global_client_origin_id,19,' '),1,19),rpad(' ',19,' '))   -- Field #10  Sourced from GL 1205 and GL 1025 Files. This is usually the Market Code+CID combined into a single value.
            || nvl(substr(lpad(v_rec.Load_number,10,'0'),1,10),lpad('0',10,'0'))               -- Field #11 ID assigned to the corporation - Corporations can be assigned more than 1 Sender ID or Load Number to correspond to the corporation's region or
            || nvl(substr(lpad(v_rec.Book_number,4,'0'),1,4),lpad('0',4,'0'))                  -- Field #12 Identifier assigned by American Express at the time of setup
            || nvl(substr(rpad(v_rec.ISO_Currency_Code,3,' '),1,3),rpad(' ',3,' '))            -- Field #13 must be a valid NUMERIC ISO currency code, alpha codes cannot be used, value must match Neutral ISO
            || nvl(substr(rpad(v_rec.ISO_Country_Code,3,' '),1,3),rpad(' ',3,' '))             -- Field #14 The country in which the American Express card was issued. The NUMERIC ISO code must be used. Sourced from GL1205 file (not available in GL1025)
            || nvl(substr(rpad(v_rec.RMCL1,2,' '),1,2),rpad(' ',2,' '))                        -- Field #15 01  = CORPORATE REMITTANCE RECEIVED: Remittance Message Code - Line 1    The selected standard AMEX literal that is the message appearing next to the payment credited to a Cardmember account. For US only - will appear on statement: Code Message
            || nvl(substr(rpad(v_rec.DMCL2,2,' '),1,2),rpad(' ',2,' '))                        -- Field #16 01  = Expense Report #: Descriptive Message Code - Line 2    The code which drives the descriptive bill message which appears on the billing statement.  These messages will appear on the statement in the same sequence as they are on the file, however only the first line is required.  The messages should be selected from the Options section of this document .  For US only - will appear on statement: Code  Message
            || nvl(substr(rpad(v_rec.cdl2,16,' '),1,16),rpad(' ',16,' '))                      -- Field #17 Expense_report_no: Company Data -  Line 2    The Client data which corresponds with the selected Descriptive Message
            || nvl(substr(rpad(v_rec.DMCL3,2,' '),1,2),rpad(' ',2,' '))                        -- Field #18 Descriptive Message Code - Line 3 The code which drives the descriptive bill message which appears on the billing statement.  These messages will appear on the statement in the same sequence as they are in the file; however, only the first line is required.
            || nvl(substr(rpad(v_rec.cdl3,16,' '),1,16),rpad(' ',16,' '))                      -- Field #19 Company_Data_Line3    The Client data which corresponds with the selected Descriptive Message
            || nvl(substr(rpad(v_rec.DMCL4,2,' '),1,2),rpad(' ',2,' '))                        -- Field #20 Descriptive Message Code - Line 4    The code which drives the descriptive bill message which appears on the billing statement.  These messages will appear on the statement in the same sequence as they are in the file; however, only the first line is required.
            || nvl(substr(rpad(v_rec.cdl4,16,' '),1,16),rpad(' ',16,' '))                      -- Field #21 Company Data for Previous Message Code  - Line 4    The Client data which corresponds with the selected Descriptive Message
            || rpad(' ',178,' '); /* 1.3 restore original length */
           -- || rpad(' ',177,' '); /* 1.3 */


        l_tot_rec_count := l_tot_rec_count + 1;
        utl_file.put_line(v_remittance_file, l_rec);
    l_stage    := '50';
        --INSERT INTO CUST.TT_GLOBAL_AMEX_GRU_GL1022_LOG -- Commented code by IXPRAVEEN-ARGANO,12-May-2023
        INSERT INTO APPS.TT_GLOBAL_AMEX_GRU_GL1022_LOG -- Added code by IXPRAVEEN-ARGANO,12-May-2023
        (
        AMEX_RECORD_TYPE    ,
        AMEX_REMIT_AMT_SIGN    ,
        AMEX_REMITTANCE_AMOUNT    ,
        AMEX_DECIMAL_PLACES    ,
        AMEX_CORPORATE_CARD_NUMBER    ,
        AMEX_COMPANY_ID    ,
        AMEX_BASIC_CONTROL_ACCOUNT    ,
        AMEX_MARKET    ,
        AMEX_GLOBAL_CLIENT_ORIGIN_ID    ,
        AMEX_LOAD_NUMBER    ,
        AMEX_BOOK_NUMBER    ,
        AMEX_ISO_CURRENCY_CODE    ,
        AMEX_ISO_Country_Code ,
        AMEX_RMCL1    ,
        AMEX_DMCL2    ,
        AMEX_CDL2    ,
        AMEX_DMCL3    ,
        AMEX_CDL3    ,
        AMEX_DMCL4    ,
        AMEX_CDL4    ,
        AMEX_PAYMENT_POSTING_DATE    ,
        TTEC_COUNTRY_CODE    ,
        TTEC_SOB  ,
        TTEC_CHECK_DATE  ,
        TTEC_CHECKRUN_NAME    ,
        TTEC_CHECK_NUMBER    ,
        TTEC_AMOUNT    ,
        TTEC_VENDOR_NAME    ,
        TTEC_INVOICE_CURRENCY_CODE    ,
        TTEC_PAYMENT_METHOD_CODE    ,
        TTEC_EXTERNAL_BANK_ACCOUNT_ID    ,
        TTEC_INVOICE_TYPE_LOOKUP_CODE    ,
        TTEC_INVOICE_NUM    ,
        TTEC_INVOICE_DATE    ,
        TTEC_GL_DATE    ,
        TTEC_DESCRIPTION    ,
        TTEC_PERIOD_NAME    ,
        TTEC_POSTED_FLAG    ,
        TTEC_REMIT_TO_SUPPLIER_NAME    ,
        TTEC_REMIT_TO_SUPPLIER_SITE    ,
        TTEC_CREATION_DATE    ,
        TTEC_CREATED_BY    ,
        TTEC_REQUEST_ID
        )
        VALUES(
        v_rec.Record_type,
        v_rec.remit_amt_sign,
        v_rec.remittance_amount,
        v_rec.DECIMAL_PLACES,
        v_rec.corporate_card_number,
        v_rec.Company_ID,
        v_rec.Basic_Control_Account,
        v_rec.market,
        v_rec.global_client_origin_id,
        v_rec.Load_number,
        v_rec.Book_number,
        v_rec.ISO_Currency_Code,
        v_rec.ISO_Country_Code,
        v_rec.RMCL1,
        v_rec.DMCL2,
        v_rec.cdl2,
        v_rec.DMCL3,
        v_rec.CDL3,
        v_rec.DMCL4,
        v_rec.CDL4,
        v_rec.Payment_Posting_Date,
        v_rec.Country_code,
        v_rec.SOB,
        v_rec.CHECK_DATE,
        v_rec.CHECKRUN_NAME,
        v_rec.check_number,
        v_rec.amount,
        v_rec.VENDOR_NAME,
        v_rec.INVOICE_CURRENCY_CODE,
        v_rec.PAYMENT_METHOD_CODE,
        v_rec.EXTERNAL_BANK_ACCOUNT_ID,
        v_rec.INVOICE_TYPE_LOOKUP_CODE,
        v_rec.invoice_num,
        v_rec.INVOICE_DATE,
        v_rec.GL_DATE,
        v_rec.DESCRIPTION,
        v_rec.PERIOD_NAME,
        v_rec.POSTED_FLAG,
        v_rec.REMIT_TO_SUPPLIER_NAME,
        v_rec.REMIT_TO_SUPPLIER_SITE,
        v_rec.creation_date,
        v_rec.created_by,
        v_rec.Request_ID
        );

    End Loop; /* Detail Records */

    -------------------------------------------------------------------------------------------------------------------------
    --
    --  Market-Payment Summary - Record Type 02
    --

    l_stage := 'Summary Record Type 02';

    For v_rec in c_summary_record loop

        l_country_sob := 'ISO Country Code: ['||v_rec.amex_ISO_Country_code||'] Market: ['||v_rec.amex_market||']';
        l_key := 'Load_Book_ISOCurrency'||v_rec.amex_Load_number||'_'||v_rec.amex_Book_number||'_'||v_rec.amex_ISO_Currency_Code;

        l_rec :=
                   '02'                                                                            -- Field #1  Set to 02 to indicate Market Payment Summary
                || nvl(substr(lpad(v_rec.amex_market,3,'0'),1,3),lpad('0',3,'0'))                  -- Field #2  Sourced from GL1205 and GL1025 Files.
                || nvl(substr(rpad(v_rec.amex_ISO_Country_code,3,' '),1,3),rpad('0',3,'0'))        -- Field #3  The country in which the American Express card was issued. The NUMERIC ISO code must be used. Sourced from GL1205 file (not available in GL1025)
                || nvl(substr(lpad(v_rec.amex_Load_number,10,'0'),1,10),lpad('0',10,'0'))          -- Field #4  ID assigned to the corporation - Corporations can be assigned more than 1 Sender ID or Load Number to correspond to the corporation's region or
                || nvl(substr(lpad(v_rec.amex_Book_number,4,'0'),1,4),lpad('0',4,'0'))             -- Field #5  Identifier assigned by American Express at the time of setup
                || nvl(substr(rpad(v_rec.amex_ISO_Currency_Code,3,' '),1,3),rpad(' ',3,' '))       -- Field #6  The currency in which the remittance is denominated. The NUMERIC version of the ISO code must be used. Sourced from GL1205 and GL1025 files.
                || nvl(substr(lpad(v_rec.Resubmit_Version_No,2,'0'),1,2),lpad('0',2,'0'))          -- Field #7  ??The version number of the batch to resubmit.  This allows a client to resubmit a set of transactions related to a payment through the GRU (that may have been successfully
                || lpad('0',21,'0')                                                                -- Field #8  Data formerly used in this area is obsolete.
                || nvl(substr(lpad(v_rec.Record_Count,15,'0'),1,15),lpad('0',15,'0'))              -- Field #9  The total number of transaction details for the given market and currency codes
                --|| nvl(substr(lpad(v_rec.Total_Remittance,20,'0'),1,20),lpad('0',20,'0'))          -- Field #10  Sum of all Remittance Credits - Sum of all Remittance Debits for the given Global Origin Identifier and ISO Currency Codes.
                || nvl(replace(replace(replace(to_char(v_rec.Total_Remittance,'S00000000000000000.00'),'+','0'),'-','0'),'.',''),lpad('0',20,'0')) -- Field #10  Sum of all Remittance Credits - Sum of all Remittance Debits for the given Global Origin Identifier and ISO Currency Codes.
                || nvl(substr(lpad(v_rec.Decimal_Places,1,'0'),1,1),lpad('0',1,'0'))               -- Field #11  Indicates the number of decimal places for the given amount
                || nvl(substr(lpad(to_char(v_rec.amex_Payment_Posting_Date,'YYYYMMDD'),8,'0'),1,8)
                                ,lpad('0',8,'0'))                                                  -- Field #12 The date the transactions for the given Market and Currency Code should be posted                                                             -- Field #10 Remittance Decimal Places    Indicates the number of decimal places for the given amount
                || rpad('0',20,'0')                                                                -- Field #13 BRZ_Ref_Bank_No -- Transaction Reference Bank Number  , not mandatory will leave bank, potentially aip.BANK_NUM --make sure the same bank for given market_code (cemmented by C. Chan)
                || rpad('0',3,'0')                                                                 -- Field #14  BRZ_Bank_Code -- Required only if Brazil-based cards: Bank Code    The bank code to which the payment will be made
                || rpad('0',5,'0')                                                                 -- Field #15  BRZ_Bank_Agency_Code -- Required only if Brazil-based cards: Bank Agency Code    The bank agency to which the payment will be made
                || rpad('0',11,'0')                                                                -- Field #16 BRZ_Bank_Acct_No-- Required only if Brazil-based cards: Bank Account Number    The bank account associated with the payment.
                || rpad('0',2,'0')                                                                 -- Field #17  BRZ_Bank_SubAcct_No-- Required only if Brazil-based cards: Sub Account Number    Validation digits in the Bank Account Number.
                || rpad(' ',267,' ');   /*1.3 restore original length */                                                           -- Field #18 Filler -- Filler
                --|| rpad(' ',266,' ');                                                              -- Field #18 Filler -- Filler

        l_tot_rec_count := l_tot_rec_count + 1;
        utl_file.put_line(v_remittance_file, l_rec);

    End Loop; /* Summary Records */

    -------------------------------------------------------------------------------------------------------------------------

    --
    --  File Summary Trailer - Record Type 09
    --
    l_stage := 'Trailer Record Type 09';

    l_tot_rec_count := l_tot_rec_count + 1;

    l_rec := '09'                                                                         -- Field #1 Indicates whether the record is Header, Detail, Market Summary or Trailer
        || lpad(l_tot_rec_count,15,'0')                                                   -- Field #2 The total number of records in the file (including Header, Detail, Market Summary and Trailer rows)
        ||  rpad(' ',383,' ');    /* 1.3 restore original length */                                                        -- Field #3 Space Fill
       -- ||  rpad(' ',382,' ');  /* 1.3 */                                                          -- Field #3 Space Fill

    l_stage    := '60';
    utl_file.put_line(v_remittance_file, l_rec);

    l_stage    := '70';
    UTL_FILE.FCLOSE(v_remittance_file);

  COMMIT;
    l_stage    := '80';
  --DELETE FROM CUST.TT_GLOBAL_AMEX_GRU_GL1022_LOG			-- Commented code by IXPRAVEEN-ARGANO,12-May-2023
  DELETE FROM apps.TT_GLOBAL_AMEX_GRU_GL1022_LOG            --  code Added by IXPRAVEEN-ARGANO,   12-May-2023
  WHERE TTEC_CREATION_DATE < SYSDATE - 365;

  COMMIT;

    l_stage    := '90';
  open c_get_param;
  fetch c_get_param into l_param1,l_param2,l_param3,l_param4, l_param5;
  close c_get_param;

    l_stage    := '100';
  v_request_id := fnd_request.submit_request(application => 'CUST',
                                             program     => 'TTEC_OUTBOUND_SFTP_GL1022',
                                             argument1   => l_param1,
                                             argument2   => l_param2,
                                             argument3   => l_param3,
                                             argument4   => l_param4,
                                             argument5   => l_param5
                                             );
    l_stage    := '110';
  commit;
    l_stage    := '120';
  if v_request_id > 0 then

     fnd_file.put_line(fnd_file.LOG,'Successfully submitted ... Request ID:'||to_char(v_request_id));
     v_process_status := 'Successfully submitted ... Request ID:'||to_char(v_request_id);

     --UPDATE  CUST.TTEC_PCARD_PHP_SUMM_HDR_ALL					-- Commented code by IXPRAVEEN-ARGANO,12-May-2023
     UPDATE  apps.TTEC_PCARD_PHP_SUMM_HDR_ALL                   --  code Added by IXPRAVEEN-ARGANO,   12-May-2023
     SET PROCESSED_FLAG = 'Y',
         CONC_REQUEST_ID = v_request_id
     WHERE INVOICE_NUMBER = p_invoice_number ;

     COMMIT;

  else
     l_stage    := '130';
     fnd_file.put_line(fnd_file.LOG,'Not Submitted');
     v_process_status := 'GRU Not Submitted';
     apps.Fnd_File.put_line (apps.Fnd_File.log,'Could not submit request>>TeleTech Transferring GRU GL1022 to AMEX<< for unknown reason. Please verify parameter values...' );
     apps.Fnd_File.put_line (apps.Fnd_File.log,'l_param1:' || l_param1);
     apps.Fnd_File.put_line (apps.Fnd_File.log,'l_param2:' || l_param2);
     apps.Fnd_File.put_line (apps.Fnd_File.log,'l_param3:' || l_param3);
     apps.Fnd_File.put_line (apps.Fnd_File.log,'l_param4:' || l_param4);
     apps.Fnd_File.put_line (apps.Fnd_File.log,'l_param5:' || l_param5);
     RAISE_APPLICATION_ERROR(-20050, 'Could not submit request>>TeleTech Transferring GRU GL1022 to AMEX<< for unknown reason. Please verify the LOG file');
  end if;

    l_stage    := '140';

   -- p_process_status := substr(v_process_status,1,100);
EXCEPTION
    WHEN NO_REMITTANCE THEN
        apps.Fnd_File.put_line (apps.Fnd_File.log,'No GL1022 GRU payment made to AMERICAN EXPRESS for INVOICE NUMBER <<'||p_invoice_number||'>> aborting the process...' );
        apps.Fnd_File.put_line (apps.Fnd_File.log,'Due to missing step(s). Please review Job Aid and RETRY.' );

        RAISE_APPLICATION_ERROR(-20050, 'No GL1022 GRU payment made to AMERICAN EXPRESS for INVOICE NUMBER <<'||p_invoice_number||'>> aborting the process...');
    WHEN UTL_FILE.INVALID_OPERATION THEN
        UTL_FILE.FCLOSE(v_remittance_file);
        RAISE_APPLICATION_ERROR(-20051, p_FileName ||':  Invalid Operation');
        ROLLBACK;
    WHEN UTL_FILE.INVALID_FILEHANDLE THEN
        UTL_FILE.FCLOSE(v_remittance_file);
        RAISE_APPLICATION_ERROR(-20052, p_FileName ||':  Invalid File Handle');
        ROLLBACK;
    WHEN UTL_FILE.READ_ERROR THEN
        UTL_FILE.FCLOSE(v_remittance_file);
        RAISE_APPLICATION_ERROR(-20053, p_FileName ||':  Read Error');
        ROLLBACK;
    WHEN UTL_FILE.INVALID_PATH THEN
        UTL_FILE.FCLOSE(v_remittance_file);
        RAISE_APPLICATION_ERROR(-20054, p_FileDir ||':  Invalid Path');
        ROLLBACK;
    WHEN UTL_FILE.INVALID_MODE THEN
        UTL_FILE.FCLOSE(v_remittance_file);
        RAISE_APPLICATION_ERROR(-20055, p_FileName ||':  Invalid Mode');
        ROLLBACK;
    WHEN UTL_FILE.WRITE_ERROR THEN
        UTL_FILE.FCLOSE(v_remittance_file);
        RAISE_APPLICATION_ERROR(-20056, p_FileName ||':  Write Error');
        ROLLBACK;
    WHEN UTL_FILE.INTERNAL_ERROR THEN
        UTL_FILE.FCLOSE(v_remittance_file);
          RAISE_APPLICATION_ERROR(-20057, p_FileName ||':  Internal Error');
        ROLLBACK;
    WHEN UTL_FILE.INVALID_MAXLINESIZE THEN
            UTL_FILE.FCLOSE(v_remittance_file);
          RAISE_APPLICATION_ERROR(-20058, p_FileName ||':  Maxlinesize Error');
        ROLLBACK;
    WHEN OTHERS THEN
        UTL_FILE.FCLOSE(v_remittance_file);

        --DBMS_OUTPUT.PUT_LINE('Operation fails on '||l_stage||' '||l_country_sob||' '||l_key);

        l_msg := SQLERRM;
        fnd_file.put_line(fnd_file.LOG,'Exception OTHERS in TTEC_AMEX_GRU_GL1022: '||l_msg);
        RAISE_APPLICATION_ERROR(-20003,'Exception OTHERS in TTEC_AMEX_GRU_GL1022: '||    l_stage ||' '||substr(l_msg,1,240));
        ROLLBACK;

END gen_global_amex_pay_file;

END TTEC_AMEX_GRU_GL1022;
/
show errors;
/