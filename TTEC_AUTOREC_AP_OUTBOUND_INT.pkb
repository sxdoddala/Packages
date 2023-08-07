create or replace PACKAGE BODY      TTEC_AUTOREC_AP_OUTBOUND_INT AS
--
-- Program Name:  TTEC_AUTOREC_AP_OUTBOUND_INT
-- /* $Header TTEC_AUTOREC_AP_OUTBOUND_INT.pks 1.0 2013/10/07  chchan ship $ */
--
-- /*== START ================================================================================================*\
--    Author: Christiane Chan
--      Date: 07-OCT-2013
--
-- Call From: Concurrent Program ->TeleTech AutoRec AP Outbound Interface
--      Desc: This program generates AP Data Feed mandated by Cheasapeak T-Recs requirements
--
--     Parameter Description:
--
--         p_ledger_id             :  Optional Value
--         p_AsOf_date             :  AP Trial Balance As Of Date DD-MON-RRRR
--         By Location             :  Hidden from End User -> Value will always be set to 'No'
--
--       Oracle Standard Parameters:
--
--   Modification History:
--
--  Version    Date     Author   Description (Include Ticket--)
--  -------  --------  --------  ------------------------------------------------------------------------------
--      1.0  10/07/13   CChan     Initial Version TTSD R#2744426 - Global AP Trial Balance Development
--      1.0	15-May-2023 IXPRAVEEN(ARGANO)   		R12.2 Upgrade Remediation
-- \*== END =====================================

    --v_module                         cust.ttec_error_handling.module_name%TYPE := 'Main';				-- Commented code by IXPRAVEEN-ARGANO,15-May-2023
    v_module                         apps.ttec_error_handling.module_name%TYPE := 'Main';               --  code Added by IXPRAVEEN-ARGANO,   15-May-2023
    v_loc                            NUMBER;
    v_msg                            varchar2(2000);
    v_rec                            varchar2(5000);

    /*********************************************************
     **  Private Procedures and Functions
    *********************************************************/
    PROCEDURE print_detail_column_name IS
    BEGIN

                v_rec :=   'Record Type'
                   ||'|'|| 'Import Account ID'
                   ||'|'|| 'Posted Date'
                   ||'|'|| 'Effective Date'
                   ||'|'|| 'Transaction Type'
                   ||'|'|| 'Debit Amount'
                   ||'|'|| 'Credit Amount'
                   ||'|'|| 'Intercompany'
                   ||'|'|| 'Operating Unit Name'
                   ||'|'|| 'Line Description'
                   ||'|'|| 'Vendor Number'
                   ||'|'|| 'Vendor Name'
                   ||'|'|| 'Invoice/Check Number'
                   ||'|'|| 'Invoice/Check Amount'
                   ||'|'|| 'Invoice/Check Currency Code'
                   ||'|'|| 'Entered Currency Amount Debit'
                   ||'|'|| 'Entered Currency Amount Credit'
                   ;
       apps.fnd_file.put_line(apps.fnd_file.output,v_rec);
       --utl_file.put_line(v_output_file, v_rec);

    END;

    PROCEDURE print_balance_column_name IS
    BEGIN

                v_rec :=   'Record Type'
                   ||'|'|| 'Import Account ID'
                   ||'|'|| 'As Of Balance Date'
                   ||'|'|| 'Remaining Balance'
                   ||'|'|| 'Remaining Balance Sign'
                   ;
       apps.fnd_file.put_line(apps.fnd_file.output,v_rec);
       --utl_file.put_line(v_output_file, v_rec);

    END;
    /************************************************************************************/
    /*                                  MAIN                                            */
    /************************************************************************************/
PROCEDURE process_balance(
          errcode                     OUT VARCHAR2,
          errbuff                     OUT VARCHAR2,
          p_ledger_id                  IN NUMBER,
          p_process_date               IN DATE
    ) IS

        -- Declare variables
    v_record_type           varchar2(1);
    v_ledger_id             number;
    v_location              varchar2(5);
    v_account               varchar2(4);
    v_currency              varchar2(3);
    v_remaining_balance_date varchar2(8);
    v_remaining_Balance      number;
    v_remaining_balance_sign varchar2(1);
    v_print_header_flag     varchar2(1):= 0;

   BEGIN

    g_ledger_id := p_ledger_id;
    v_loc := 10;

    v_module := 'get apps id';
    g_application_id := APPS.TTEC_AUTOREC_GL_OUTBOUND_INT.get_application_id('Payables');

    v_loc := 20;
    v_module := 'get currency';
    g_currency_code := APPS.TTEC_AUTOREC_GL_OUTBOUND_INT.get_currency_code(g_ledger_id);
    v_loc := 20;
    v_module := 'c_directory_path';

    open c_directory_path2;
    fetch c_directory_path2 into v_file_path,v_filename;
    close c_directory_path2;

    v_module := 'Open File';
    v_output_file := UTL_FILE.FOPEN(v_file_path, v_filename, 'w');

    v_loc := 30;
    v_module := 'c_def_code';

    g_definition_code :='';
    open c_definition_code;
    fetch c_definition_code into g_definition_code;
    close c_definition_code;

    v_loc := 40;
    Fnd_File.put_line(Fnd_File.LOG, '');
    Fnd_File.put_line(Fnd_File.LOG,'>>>>>>>>>>>>>>>> Processing AP Trial Balance Extract For <<<<<<<<<<<<<<<<<<<');
    Fnd_File.put_line(Fnd_File.LOG, '');
    Fnd_File.put_line(Fnd_File.LOG,'           Ledger ID: '||g_ledger_id);
    Fnd_File.put_line(Fnd_File.LOG,'       Currency Code: '||g_currency_code);
    Fnd_File.put_line(Fnd_File.LOG,'     Definition Code: '||g_definition_code);
    Fnd_File.put_line(Fnd_File.LOG,'           File Path: '||v_file_path);
    Fnd_File.put_line(Fnd_File.LOG,'           File Name: '||v_filename);
    Fnd_File.put_line(Fnd_File.LOG,'         Starts Time: '||to_char(SYSDATE,'DD-MON-YYYY HH24:MI:SS'));
    Fnd_File.put_line(Fnd_File.LOG, '');

    FOR ledger_account IN c_ledger_account
    LOOP
        BEGIN

            SELECT   /*+ parallel(xtb) leading(xtb) NO_MERGE */
                     'B' record_type
                   , xtb.ledger_id ledger_id
                   , decode(g_by_location_indicator,'Y',gcc.segment1,'')  LOCATION
                   , gcc.segment4 ACCOUNT
                   , gl.currency_code currency
                   , TO_CHAR (g_process_date, 'YYYYMMDD') remaining_balance_date
                   ,   SUM (NVL (xtb.acctd_unrounded_cr, 0))
                     - SUM (NVL (xtb.acctd_unrounded_dr, 0)) remaining_balance
                  INTO v_record_type,
                       v_ledger_id,
                       v_location,
                       v_account,
                       v_currency,
                       v_remaining_balance_date,
                       v_remaining_Balance
                --START R12.2 Upgrade Remediation
				/*FROM xla.xla_trial_balances xtb							-- Commented code by IXPRAVEEN-ARGANO,15-May-2023
                   , xla.xla_transaction_entities xte                       
                   , apps.ap_sla_invoices_transaction_v tiv
                   , gl.gl_ledgers gl
                   , gl.gl_code_combinations gcc*/
				FROM apps.xla_trial_balances xtb								--  code Added by IXPRAVEEN-ARGANO,   15-May-2023
                   , apps.xla_transaction_entities xte
                   , apps.ap_sla_invoices_transaction_v tiv
                   , apps.gl_ledgers gl
                   , apps.gl_code_combinations gcc
				 --END R12.2.12 Upgrade remediation
               WHERE xtb.definition_code = g_definition_code
                 AND xtb.source_application_id = 200
                 AND (   xtb.party_type_code IS NULL
                      OR xtb.party_type_code = 'S')
                 AND NVL (xte.source_id_int_1, -99) = tiv.invoice_id
                 AND gl.ledger_id = xtb.ledger_id
                 AND gcc.code_combination_id = xtb.code_combination_id
                 AND xte.application_id = xtb.applied_to_application_id
                 AND xte.entity_id = NVL (xtb.applied_to_entity_id, xtb.source_entity_id)
                 AND xte.ledger_id = xtb.ledger_id
                 AND gcc.segment1  = decode(g_by_location_indicator,'Y',ledger_account.location,gcc.segment1)
                 AND gcc.segment4  = ledger_account.account
                 AND xtb.ledger_id = g_ledger_id
                 AND xtb.gl_date <= g_process_date
            GROUP BY 'B'
                   , xtb.ledger_id
                   , decode(g_by_location_indicator,'Y',gcc.segment1,'')
                   , gcc.segment4
                   , gl.currency_code
                   , TO_CHAR (g_process_date, 'YYYYMMDD');

                v_loc := 50;
                v_module := 'Balance Rec';

                IF SIGN(v_remaining_Balance) = -1 THEN
                   v_remaining_balance_sign := 'D';
                ELSE
                   v_remaining_balance_sign := 'C';
                END IF;

               g_import_acct := v_ledger_id;

               v_rec :=        v_Record_Type
                       ||'|'|| v_ledger_id;

               IF  g_by_location_indicator = 'Y' THEN

                   v_rec := v_rec ||'.'|| v_location;

                   g_import_acct := g_import_acct
                           ||' '|| v_location;

               END IF;

               g_import_acct := g_import_acct
                       ||' '|| v_account;

               v_rec := v_rec ||'.'|| v_account
                       ||'.'|| v_currency
                       ||'_'|| 'AP'-- Added on Oct 15,2013 to differientiate from GL account setup
                       ||'|'|| v_remaining_balance_date
                       ||'|'|| v_remaining_Balance
                       ||'|'|| v_remaining_balance_sign;

            apps.fnd_file.put_line(apps.fnd_file.output,v_rec);
            utl_file.put_line(v_output_file, v_rec);

        EXCEPTION
        WHEN NO_DATA_FOUND THEN
             NULL;
        /* in AP we should never send 0, otherwise, it SAYS NO OUTSTANDING Payement for theta Ledger */
        /*
               v_rec :=        'B'
                       ||'|'|| g_ledger_id; --1.2

               IF  g_by_location_indicator = 'Y' THEN
                   v_rec := v_rec ||'.'|| ledger_account.location; -- 1.5
               END IF;

               v_rec := v_rec ||'.'|| ledger_account.account --1.3
                       ||'.'|| g_currency_code
                       ||'_'|| 'AP'-- Added on Oct 15,2013 to differientiate from GL account setup
                       ||'|'|| TO_CHAR (g_process_date, 'YYYYMMDD')
                       ||'|'|| '0'
                       ||'|'|| 'D';

                apps.fnd_file.put_line(apps.fnd_file.output,v_rec);
                utl_file.put_line(v_output_file, v_rec);
           */

        WHEN OTHERS THEN
                 apps.Fnd_File.put_line (apps.Fnd_File.log,' Error in Getting AP Balance For: ' ||ledger_account.account||ledger_account.location||' at Loc/Module -><<'||v_loc||'/'|| v_module||'>>' );
                 errcode  := SQLCODE;
                 errbuff  := SUBSTR (SQLERRM, 1, 255);
                 RAISE;
        END;

    END LOOP; /* Header */

    v_loc := 70;
    v_module := 'Close File';

    UTL_FILE.FCLOSE(v_output_file);

    EXCEPTION
    WHEN UTL_FILE.INVALID_OPERATION THEN
        UTL_FILE.FCLOSE(v_output_file);
        RAISE_APPLICATION_ERROR(-20051, v_filename ||':  Invalid Operation');

    WHEN UTL_FILE.INVALID_FILEHANDLE THEN
        UTL_FILE.FCLOSE(v_output_file);
        RAISE_APPLICATION_ERROR(-20052, v_filename ||':  Invalid File Handle');

    WHEN UTL_FILE.READ_ERROR THEN
        UTL_FILE.FCLOSE(v_output_file);
        RAISE_APPLICATION_ERROR(-20053, v_filename ||':  Read Error');
        ROLLBACK;
    WHEN UTL_FILE.INVALID_PATH THEN
        UTL_FILE.FCLOSE(v_output_file);
        RAISE_APPLICATION_ERROR(-20054, v_file_path ||':  Invalid Path');

    WHEN UTL_FILE.INVALID_MODE THEN
        UTL_FILE.FCLOSE(v_output_file);
        RAISE_APPLICATION_ERROR(-20055, v_filename ||':  Invalid Mode');

    WHEN UTL_FILE.WRITE_ERROR THEN
        UTL_FILE.FCLOSE(v_output_file);
        RAISE_APPLICATION_ERROR(-20056, v_filename ||':  Write Error');

    WHEN UTL_FILE.INTERNAL_ERROR THEN
        UTL_FILE.FCLOSE(v_output_file);
        RAISE_APPLICATION_ERROR(-20057, v_filename ||':  Internal Error');

    WHEN UTL_FILE.INVALID_MAXLINESIZE THEN
         UTL_FILE.FCLOSE(v_output_file);
         RAISE_APPLICATION_ERROR(-20058, v_filename ||':  Maxlinesize Error');

    WHEN INVALID_CURSOR
    THEN

         UTL_FILE.FCLOSE(v_output_file);

         ttec_error_logging.process_error( g_application_code -- 'AP'
                                         , g_interface        -- 'AutoRec AP Intf';
                                         , g_package          -- 'TTEC_AUTOREC_AP_OUTBOUND_INT'
                                         , v_module
                                         , g_failure_status
                                         , SQLCODE
                                         , SQLERRM
                                         , g_label1
                                         , v_loc
                                         , g_label2
                                         , g_import_acct );

          errcode  := SQLCODE;
          errbuff  := SUBSTR (SQLERRM, 1, 255);

    WHEN OTHERS
    THEN
         UTL_FILE.FCLOSE(v_output_file);

         ttec_error_logging.process_error( g_application_code -- 'AP'
                                         , g_interface        -- 'AutoRec AP Intf';
                                         , g_package          -- 'TTEC_AUTOREC_AP_OUTBOUND_INT'
                                         , v_module
                                         , g_failure_status
                                         , SQLCODE
                                         , SQLERRM
                                         , g_label1
                                         , v_loc
                                         , g_label2
                                         , g_import_acct );

          errcode  := SQLCODE;
          errbuff  := SUBSTR (SQLERRM, 1, 255);

        RAISE_APPLICATION_ERROR(-20003,'Exception OTHERS in TTEC_AUTOREC_AP_OUTBOUND_INT.process_balance: '||'Module >-' ||v_module||' ['||g_label1||']['||v_loc||']['||g_label2||']['||g_import_acct|| '] ERROR:'||errbuff);

    END process_balance;

PROCEDURE balance_main(
          errcode                     OUT VARCHAR2,
          errbuff                     OUT VARCHAR2,
          p_ledger_id                  IN NUMBER,
          p_process_date               IN VARCHAR2,
          p_by_location_indicator      IN VARCHAR2
    ) IS
BEGIN

    v_loc := 10;
    v_module := 'process dt';

    IF p_process_date IS NOT NULL THEN
       g_process_date := to_date(p_process_date);
    ELSE
       g_process_date := trunc(SYSDATE);
    END IF;

   g_by_location_indicator := p_by_location_indicator;

    Fnd_File.put_line(Fnd_File.LOG, '');
    Fnd_File.put_line(Fnd_File.LOG,'--------------------------------------------------------------------------------------------------------------------------------------------------');
    Fnd_File.put_line(Fnd_File.LOG, '');
    Fnd_File.put_line(Fnd_File.LOG,'Concurrent Program -> TeleTech AutoRec AP Balance Data Feed ');
    Fnd_File.put_line(Fnd_File.LOG, '');
    Fnd_File.put_line(Fnd_File.LOG,'Parameters:                  ');
    Fnd_File.put_line(Fnd_File.LOG,'            p_ledger_id: '||p_ledger_id);
    Fnd_File.put_line(Fnd_File.LOG,'         p_process_date: '||g_process_date);
    Fnd_File.put_line(Fnd_File.LOG,'p_by_location_indicator: '||p_by_location_indicator);
    Fnd_File.put_line(Fnd_File.LOG, '');
    Fnd_File.put_line(Fnd_File.LOG,'--------------------------------------------------------------------------------------------------------------------------------------------------');

    v_loc := 20;
    v_module := 'PrntColNm';

    print_balance_column_name;



   IF p_ledger_id is not NULL THEN
          process_balance(errcode ,errbuff,p_ledger_id,g_process_date);
   ELSE

      v_loc := 30;
      v_module := 'c_ledger';

      FOR ledger_rec IN c_ledger
      LOOP
          process_balance(errcode ,errbuff,ledger_rec.ledger_id,g_process_date);
      END LOOP;

   END IF;

EXCEPTION
    WHEN OTHERS
    THEN
         UTL_FILE.FCLOSE(v_output_file);

         ttec_error_logging.process_error( g_application_code -- 'AP'
                                         , g_interface        -- 'AutoRec AP Intf';
                                         , g_package          -- 'TTEC_AUTOREC_AP_OUTBOUND_INT'
                                         , v_module
                                         , g_failure_status
                                         , SQLCODE
                                         , SQLERRM
                                         , g_label1
                                         , v_loc
                                         , g_label2
                                         , g_import_acct );

          errcode  := SQLCODE;
          errbuff  := SUBSTR (SQLERRM, 1, 255);

        RAISE_APPLICATION_ERROR(-20003,'Exception OTHERS in TTEC_AUTOREC_AP_OUTBOUND_INT.balance.main: '||'Module >-' ||v_module||' ['||g_label1||']['||v_loc||']['||g_label2||']['||g_import_acct|| '] ERROR:'||errbuff);

END balance_main;

END TTEC_AUTOREC_AP_OUTBOUND_INT;
/
show errors;
/