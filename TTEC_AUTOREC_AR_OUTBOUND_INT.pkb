create or replace PACKAGE BODY      TTEC_AUTOREC_AR_OUTBOUND_INT AS
--
--
-- Program Name:  TTEC_AUTOREC_AR_OUTBOUND_INT
-- /* $Header: TTEC_AUTOREC_AR_OUTBOUND_INT.pkb 1.0 2013/02/14  chchan ship $ */
--
-- /*== START ================================================================================================*\
--    Author: Christiane Chan
--      Date: 14-FEB-2013
--
-- Call From: Concurrent Program ->TeleTech AutoRec AR Outbound Interface
--      Desc: This program generates AR Data Feed mandated by Cheasapeak T-Recs requirements
--
--     Parameter Description:
--
--         p_ledger_id               :
--         p_period_name             :
--         p_posted_date             :
--
--       Oracle Standard Parameters:
--
--   Modification History:
--
--  Version    Date     Author   Description (Include Ticket--)
--  -------  --------  --------  ------------------------------------------------------------------------------
--      1.0  02/14/13   CChan     Initial Version TTSD R#2204084 - AutoRec Project
--      1.1  02/27/13   CChan     Comment out the  exclusion of zero balance at the header level, also, do not send the detail lines of
--                                balance that have zero amount
--      1.2  03/06/13   CChan     Enable Looping through Ledgers + Modify file naming convention + eliminate directory structure by Country Code+ replace GL Location with Ledger ID in the Account IS section
--      1.0	12-May-2023 IXPRAVEEN(ARGANO)   		R12.2 Upgrade Remediation
-- \*== END =====================================

    --v_module                         cust.ttec_error_handling.module_name%TYPE := 'Main';				-- Commented code by IXPRAVEEN-ARGANO,12-May-2023
	v_module                         apps.ttec_error_handling.module_name%TYPE := 'Main';               --  code Added by IXPRAVEEN-ARGANO,   12-May-2023
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
                   ||'|'|| 'Reference 1'
                   ||'|'|| 'Reference 2'
                   ||'|'|| 'Reference 3'
                   ||'|'|| 'Reference 5'
                   ||'|'|| 'Details'
                   ||'|'|| 'Reference 6'
                   ||'|'|| 'Reference 7'
                   ||'|'|| 'Reference 8'
                   ||'|'|| 'Numeric Reference Field 1'
                   ||'|'|| 'Numeric Reference Field 2'
                   ;
       apps.fnd_file.put_line(apps.fnd_file.output,v_rec);
       --utl_file.put_line(v_output_file, v_rec);

    END;

    PROCEDURE print_balance_column_name IS
    BEGIN

                v_rec :=   'Record Type'
                   ||'|'|| 'Import Account ID'
                   ||'|'|| 'Adjusted Balance Date'
                   ||'|'|| 'Adjusted Balance'
                   ||'|'|| 'Adjusted Balance Sign'
                   ;
       apps.fnd_file.put_line(apps.fnd_file.output,v_rec);
       --utl_file.put_line(v_output_file, v_rec);

    END;
    /************************************************************************************/
    /*                                  MAIN                                */
    /************************************************************************************/

PROCEDURE process_detail(
          errcode                     OUT VARCHAR2,
          errbuff                     OUT VARCHAR2,
          p_ledger_id                  IN NUMBER,
          p_period_name                IN VARCHAR2,
          p_posted_date                IN VARCHAR2
    ) IS

        -- Declare variables
    v_Adjusted_balance_sign varchar2(1);
    --START R12.2 Upgrade Remediation
	/*v_billing_location_id   hr.hr_locations_all.LOCATION_ID%TYPE;					-- Commented code by IXPRAVEEN-ARGANO,12-May-2023
    v_billing_location_name hr.hr_locations_all.location_code%TYPE;                 
    v_billing_contact_name  hr.hr_locations_all.address_line_1%TYPE;
    v_billing_address_1     hr.hr_locations_all.address_line_2%TYPE;
    v_billing_address_2     hr.hr_locations_all.address_line_2%TYPE;
    v_billing_address_3     hr.hr_locations_all.address_line_3%TYPE;
    v_billing_city          hr.hr_locations_all.town_or_city%TYPE;
    v_billing_state         hr.hr_locations_all.region_2%TYPE;
    v_billing_postal        hr.hr_locations_all.POSTAL_CODE%TYPE;
    v_billing_country       hr.hr_locations_all.country%TYPE;
    v_billing_phone         hr.hr_locations_all.telephone_number_1%TYPE;*/
	v_billing_location_id   APPS.hr_locations_all.LOCATION_ID%TYPE;					--  code Added by IXPRAVEEN-ARGANO,   12-May-2023
    v_billing_location_name apps.hr_locations_all.location_code%TYPE;
    v_billing_contact_name  apps.hr_locations_all.address_line_1%TYPE;
    v_billing_address_1     apps.hr_locations_all.address_line_2%TYPE;
    v_billing_address_2     apps.hr_locations_all.address_line_2%TYPE;
    v_billing_address_3     apps.hr_locations_all.address_line_3%TYPE;
    v_billing_city          apps.hr_locations_all.town_or_city%TYPE;
    v_billing_state         apps.hr_locations_all.region_2%TYPE;
    v_billing_postal        apps.hr_locations_all.POSTAL_CODE%TYPE;
    v_billing_country       apps.hr_locations_all.country%TYPE;
    v_billing_phone         apps.hr_locations_all.telephone_number_1%TYPE;
	--END R12.2.12 Upgrade remediation

    v_print_balance_column_flag     varchar2(1):= 0;
    v_print_detail_column_flag     varchar2(1):= 0;


   BEGIN

    v_loc := 10;
    v_module := 'detail main';

    g_ledger_id := p_ledger_id;

    v_loc := 15;
    v_module := 'get apps id';
    g_application_id := APPS.TTEC_AUTOREC_GL_OUTBOUND_INT.get_application_id('Receivables');

    v_loc := 20;
    v_module := 'get currency';
    g_currency_code := APPS.TTEC_AUTOREC_GL_OUTBOUND_INT.get_currency_code(g_ledger_id);

    v_loc := 25;
    v_module := 'get ORG_ID';
    g_org_id := APPS.TTEC_AUTOREC_GL_OUTBOUND_INT.get_org_id(g_ledger_id);

    v_loc := 30;
    v_module := 'get country';
    g_country_code := APPS.TTEC_AUTOREC_GL_OUTBOUND_INT.get_country_code(g_org_id);

    v_loc := 35;
    v_module := 'get period';

    g_period_name := APPS.TTEC_AUTOREC_GL_OUTBOUND_INT.get_latest_open_period(g_ledger_id,g_application_id);
    g_latest_closed_period := APPS.TTEC_AUTOREC_GL_OUTBOUND_INT.get_latest_closed_period(g_ledger_id,g_application_id); /* 1.1 */

    v_loc := 40;
    v_module := 'get posted dt';
    IF p_posted_date IS NOT NULL THEN

       g_posted_date := to_date(p_posted_date);

       IF p_period_name IS NOT NULL THEN /* 1.1 */
          g_period_name := p_period_name;
          g_latest_closed_period := APPS.TTEC_AUTOREC_GL_OUTBOUND_INT.get_prior_period(g_ledger_id,g_application_id,p_period_name); /* 1.1 */
       END IF;

    ELSE

       g_posted_date:= APPS.TTEC_AUTOREC_GL_OUTBOUND_INT.get_posted_date;

    END IF;


    v_loc := 50;


    v_module := 'c_directory_path';
    v_loc := 60;
    open c_directory_path;
    fetch c_directory_path into v_file_path,v_filename;
    close c_directory_path;

    v_loc := 70;
    Fnd_File.put_line(Fnd_File.LOG, '');
    Fnd_File.put_line(Fnd_File.LOG,'--------------------------------------------------------------------------------------------------------------------------------------------------');
    Fnd_File.put_line(Fnd_File.LOG, '');
    Fnd_File.put_line(Fnd_File.LOG,'Concurrent Program -> TeleTech AutoRec AR Detail Outbound Interface');
    Fnd_File.put_line(Fnd_File.LOG, '');
    Fnd_File.put_line(Fnd_File.LOG,'Parameters:                  ');
    Fnd_File.put_line(Fnd_File.LOG,'           Ledger ID: '||g_ledger_id);
    Fnd_File.put_line(Fnd_File.LOG,'       Currency Code: '||g_currency_code);
    Fnd_File.put_line(Fnd_File.LOG,'         Period Name: '||g_period_name);
    Fnd_File.put_line(Fnd_File.LOG,'   Prior Period Name: '||g_latest_closed_period);
    Fnd_File.put_line(Fnd_File.LOG,'         Posted Date: '||to_char(g_posted_date,'DD-MON-RRRR'));
    Fnd_File.put_line(Fnd_File.LOG,'           File Path: '||v_file_path);
    Fnd_File.put_line(Fnd_File.LOG,'           File Name: '||v_filename);
    Fnd_File.put_line(Fnd_File.LOG,'         Starts Time: '||to_char(SYSDATE,'DD-MON-YYYY HH24:MI:SS'));     -- 1.2
    Fnd_File.put_line(Fnd_File.LOG,'--------------------------------------------------------------------------------------------------------------------------------------------------');

    v_loc := 80;
    v_module := 'Open File';

    v_output_file := UTL_FILE.FOPEN(v_file_path, v_filename, 'w');






    FOR header_rec IN c_header
    LOOP

            print_balance_column_name;
            v_print_detail_column_flag := '0';

            v_loc := 90;
            v_module := 'Header Rec';

            IF SIGN(header_rec.Adjusted_Balance) = -1 THEN
               v_Adjusted_balance_sign := 'C';
            ELSE
               v_Adjusted_balance_sign := 'D';
            END IF;

           g_import_acct := header_rec.ledger_id --1.2
                           --header_rec.location --1.2
                   ||' '|| header_rec.account;

           v_rec :=        header_rec.Record_Type
                   ||'|'|| header_rec.ledger_id --1.2
                   --||'|'|| header_rec.location --1.2
                   ||' '|| header_rec.account
                   ||' '|| header_rec.currency
                   ||'|'|| header_rec.Adjusted_Balance_Date
                   ||'|'|| header_rec.Adjusted_Balance
                   ||'|'|| v_Adjusted_Balance_sign;

            apps.fnd_file.put_line(apps.fnd_file.output,v_rec);
            utl_file.put_line(v_output_file, v_rec);

            IF header_rec.Adjusted_Balance != 0 /* 1.1 */
               AND header_rec.Acct_flag = 'D'  /* 1.2 */
            THEN
            BEGIN


                --FOR detail_rec IN c_detail(header_rec.location, header_rec.account) --1.2
                FOR detail_rec IN c_detail(header_rec.account) --1.2
                LOOP
                v_loc := 100;
                v_module := 'Detail Rec';

                    IF v_print_detail_column_flag = '0' THEN
                       print_detail_column_name;
                       v_print_detail_column_flag := '1';
                    END IF;

                    v_rec := detail_rec.detail_line;
                    apps.fnd_file.put_line(apps.fnd_file.output,v_rec);
                    utl_file.put_line(v_output_file, v_rec);

                END LOOP; /* Detail */

            END;
            END IF;

    END LOOP; /* Header */

    v_loc := 110;
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

         ttec_error_logging.process_error( g_application_code -- 'AR'
                                         , g_interface        -- 'AutoRec AR Intf';
                                         , g_package          -- 'TTEC_AUTOREC_AR_OUTBOUND_INT'
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

         ttec_error_logging.process_error( g_application_code -- 'AR
                                         , g_interface        -- 'AutoRec AR Intf';
                                         , g_package          -- 'TTEC_AUTOREC_AR_OUTBOUND_INT'
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

        RAISE_APPLICATION_ERROR(-20003,'Exception OTHERS in TTEC_AUTOREC_AR_OUTBOUND_INT.process_detail: '||'Module >-' ||v_module||' ['||g_label1||']['||v_loc||']['||g_label2||']['||g_import_acct|| '] ERROR:'||errbuff);

    END process_detail;
PROCEDURE detail_main(
          errcode                     OUT VARCHAR2,
          errbuff                     OUT VARCHAR2,
          p_ledger_id                  IN NUMBER,
          p_period_name                IN VARCHAR2,
          p_posted_date                IN VARCHAR2
    ) IS
BEGIN
   IF p_ledger_id is not NULL THEN
          process_detail(errcode ,errbuff,p_ledger_id,p_period_name,p_posted_date);
   ELSE
      FOR ledger_rec IN APPS.TTEC_AUTOREC_GL_OUTBOUND_INT.c_ledger
      LOOP
          process_detail(errcode ,errbuff,ledger_rec.ledger_id,p_period_name,p_posted_date);
      END LOOP;
   END IF;
END detail_main;
END TTEC_AUTOREC_AR_OUTBOUND_INT;
/
show errors;
/