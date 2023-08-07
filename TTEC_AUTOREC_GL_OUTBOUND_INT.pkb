create or replace PACKAGE BODY      TTEC_AUTOREC_GL_OUTBOUND_INT AS
--
--
-- Program Name:  TTEC_AUTOREC_GL_OUTBOUND_INT
-- /* $Header: TTEC_AUTOREC_GL_OUTBOUND_INT.pkb 1.0 2013/02/14  chchan ship $ */
--
-- /*== START ================================================================================================*\
--    Author: Christiane Chan
--      Date: 14-FEB-2013
--
-- Call From: Concurrent Program ->TeleTech AutoRec GL Outbound Interface
--      Desc: This program generates GL Data Feed mandated by Cheasapeak T-Recs requirements
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
--      1.3  04/27/13   CChan     Adding additional columns + Pick up Detail Account only on GL Detail Extract + Add condition to re-enforced the Actual + Posted flags
--      1.4  06/20/13   CChan     Allowing to send details when an account has a zero balance on GL Detail Feed
--      1.5  08/01/13   CChan     TeleTech US Set of Books - add the ability to reconcile by GL location
--      2.0  09/30/13   CChan     TTSD I#2758506 - AutoRec GL Balance include account with no activities with zero balance
--      2.1  02/14/14   CChan     Fix for By Location should only show account with location + remove header column being repeated
--      1.0	17-May-2023 IXPRAVEEN(ARGANO)   		R12.2 Upgrade Remediation
-- \*== END =====================================

    --v_module                         cust.ttec_error_handling.module_name%TYPE := 'Main';				-- Commented code by IXPRAVEEN-ARGANO,17-May-2023
    v_module                         apps.ttec_error_handling.module_name%TYPE := 'Main';               --  code Added by IXPRAVEEN-ARGANO,   17-May-2023
    v_loc                            NUMBER;
    v_msg                            varchar2(2000);
    v_rec                            varchar2(5000);

    /*********************************************************
     **  Private Procedures and Functions
    *********************************************************/
    PROCEDURE print_header_column_name IS
    BEGIN

                v_rec :=   'Record Type'
                   ||'|'|| 'Import Account ID'
                   ||'|'|| 'Closing Date'
                   ||'|'|| 'Closing Balance'
                   ||'|'|| 'Item Count'
                   ;
       apps.fnd_file.put_line(apps.fnd_file.output,v_rec);
       --utl_file.put_line(v_output_file, v_rec);

    END;

    PROCEDURE print_detail_column_name IS
    BEGIN

                v_rec :=   'Record Type'
                   ||'|'|| 'Import Account ID'
                   ||'|'|| 'Posted Date'
                   ||'|'|| 'Effective Date'
                   ||'|'|| 'Transaction Type'
                   ||'|'|| 'Debit Amount'
                   ||'|'|| 'Credit Amount'
                   ||'|'|| 'Location'
                   ||'|'|| 'Client'
                   ||'|'|| 'Department'
                   ||'|'|| 'Account'
                   ||'|'|| 'Intercompany'
                   ||'|'|| 'Period Name'
                   ||'|'|| 'Ledger Name'
                   ||'|'|| 'Batch Name'
                   ||'|'|| 'JE Line Description'
                   ||'|'|| 'Journal Header Name'
                   ||'|'|| 'Journal Header Description'
                   ||'|'|| 'Journal HeaderCategory'
                   ||'|'|| 'JE Line Entered Currency'
                   ||'|'|| 'JE Line Entered Currency Amount Debit'
                   ||'|'|| 'JE Line Entered Currency Amount Credit'
                   ;

       apps.fnd_file.put_line(apps.fnd_file.output,v_rec);
       --utl_file.put_line(v_output_file, v_rec);

    END;

    PROCEDURE print_balance_column_name IS
    BEGIN

                v_rec :=   'Record Type'
                   ||'|'|| 'Import Account ID'
                   ||'|'|| 'Closing Date'
                   ||'|'|| 'Closing Balance'
                   ||'|'|| 'Closing Balance Sign'
                   ;
       apps.fnd_file.put_line(apps.fnd_file.output,v_rec);
       --utl_file.put_line(v_output_file, v_rec);

    END;
    FUNCTION get_currency_code(p_ledger_id number)  RETURN VARCHAR2 IS

     v_currency_code VARCHAR2(3);
    BEGIN
            BEGIN

                SELECT gl.currency_code
                  INTO v_currency_code
                  FROM gl_ledgers gl
                 WHERE ledger_id = p_ledger_id;

                 RETURN v_currency_code;

            EXCEPTION

                 WHEN NO_DATA_FOUND THEN
                 apps.Fnd_File.put_line (apps.Fnd_File.log,' Cannot find Currency Code for Ledger: ' ||to_char(p_ledger_id)  );
                    NULL;

                 WHEN OTHERS THEN
                 apps.Fnd_File.put_line (apps.Fnd_File.log,' Error in Getting Currency Code For Ledger ID: ' ||to_char(p_ledger_id)  );
                    RAISE;

            END;
    END;

    FUNCTION get_org_id(p_ledger_id number)  RETURN NUMBER IS

     v_org_id NUMBER;

    BEGIN
            BEGIN

            IF p_ledger_id = 1 THEN

               RETURN 101;
            ELSE
                SELECT organization_id
                  INTO v_org_id
                  FROM hr_operating_units
                 WHERE set_of_books_id = p_ledger_id;

                 RETURN v_org_id;
             END IF;

            EXCEPTION

                 WHEN NO_DATA_FOUND THEN
                 apps.Fnd_File.put_line (apps.Fnd_File.log,' Cannot find ORG ID for Ledger: ' ||to_char(p_ledger_id)  );
                    NULL;

                 WHEN OTHERS THEN
                 apps.Fnd_File.put_line (apps.Fnd_File.log,' Error in Getting ORG ID For Ledger ID: ' ||to_char(p_ledger_id)  );
                    RAISE;

            END;
    END;

    FUNCTION get_country_code(p_org_id number) RETURN VARCHAR2 IS

     v_country_code VARCHAR2(2);

    BEGIN
            BEGIN

                SELECT DECODE (o.organization_id, 141, 'CA', l.country)
                  INTO v_country_code
                  FROM hr_organization_units o, hr_locations l
                 WHERE o.location_id IS NOT NULL
                   AND o.location_id = l.location_id
                   AND o.organization_id = p_org_id;

                 RETURN v_country_code;

            EXCEPTION

                 WHEN NO_DATA_FOUND THEN
                 apps.Fnd_File.put_line (apps.Fnd_File.log,' Cannot find Country Code for ORG ID: ' ||to_char(p_org_id)  );
                    NULL;

                 WHEN OTHERS THEN
                 apps.Fnd_File.put_line (apps.Fnd_File.log,' Error in Getting Country Code For ORG ID: ' ||to_char(p_org_id)  );
                    RAISE;

            END;
    END;
    FUNCTION get_latest_open_period(p_ledger_id number, p_application_id number) RETURN VARCHAR2 IS

      v_period_name  gl.gl_periods.period_name%TYPE;

    BEGIN

            BEGIN

                SELECT period_name
                  INTO v_period_name
                  FROM gl_period_statuses
                 WHERE ledger_id = p_ledger_id
                   AND application_id = p_application_id
                   AND start_date = (SELECT MAX (start_date)
                                       FROM gl_period_statuses gps
                                      WHERE ledger_id = p_ledger_id
                                        AND application_id = p_application_id
                                        AND gps.closing_status = 'O');
            RETURN v_period_name;

            EXCEPTION

                 WHEN NO_DATA_FOUND THEN
                 apps.Fnd_File.put_line (apps.Fnd_File.log,' Cannot find Open Latest Period for Ledger ID: ' ||to_char(g_ledger_id)  );
                    RAISE;

                 WHEN OTHERS THEN
                 apps.Fnd_File.put_line (apps.Fnd_File.log,' Error in Getting Latest Open Period For Ledger ID: ' ||to_char(g_ledger_id)  );
                    RAISE;

            END;

    END;
    FUNCTION get_application_id(p_application_name varchar2) RETURN VARCHAR2 IS

      v_application_id  number(15);

    BEGIN

            BEGIN

                SELECT application_id
                  INTO v_application_id
                  FROM fnd_application_tl
                 WHERE LANGUAGE = 'US'
                   AND application_name = p_application_name;

                 RETURN v_application_id;

            EXCEPTION

                 WHEN NO_DATA_FOUND THEN
                 apps.Fnd_File.put_line (apps.Fnd_File.log,' Cannot get Application ID for Application: ' ||p_application_name   );
                    RAISE;

                 WHEN OTHERS THEN
                 apps.Fnd_File.put_line (apps.Fnd_File.log,' Error in Getting Application ID for Application: ' ||p_application_name   );
                    RAISE;

            END;

    END;
    FUNCTION get_latest_closed_period(p_ledger_id number, p_application_id number) RETURN VARCHAR2 IS

      v_period_name  gl.gl_periods.period_name%TYPE;

    BEGIN

            BEGIN

                SELECT period_name
                  INTO v_period_name
                  FROM gl_period_statuses
                 WHERE ledger_id = p_ledger_id
                   AND application_id = p_application_id
                   AND start_date = (SELECT MAX (start_date)
                                       FROM gl_period_statuses gps
                                      WHERE ledger_id = p_ledger_id
                                        AND application_id = p_application_id
                                        AND gps.closing_status = 'C');

                 RETURN v_period_name;

            EXCEPTION

                 WHEN NO_DATA_FOUND THEN
                 apps.Fnd_File.put_line (apps.Fnd_File.log,' Cannot get latest Closed Period for Ledger ID: ' ||to_char(g_ledger_id)  );
                    RAISE;

                 WHEN OTHERS THEN
                 apps.Fnd_File.put_line (apps.Fnd_File.log,' Error in Getting latest Closed Period For Ledger ID: ' ||to_char(g_ledger_id)  );
                    RAISE;

            END;

    END;

    FUNCTION get_prior_period(p_ledger_id number, p_application_id number, p_period_name varchar2) RETURN VARCHAR2 IS

      v_period_name  gl.gl_periods.period_name%TYPE;

    BEGIN

            BEGIN

                SELECT period_name
                  INTO v_period_name
                  FROM gl_period_statuses
                 WHERE ledger_id = p_ledger_id
                   AND application_id = p_application_id
                   AND start_date = (SELECT MAX (start_date)
                                       FROM gl_period_statuses gps
                                      WHERE ledger_id = p_ledger_id
                                        AND application_id = p_application_id
                                        AND start_date < (SELECT MAX (start_date)
                                       FROM gl_period_statuses gps
                                      WHERE ledger_id = p_ledger_id
                                        AND application_id = p_application_id
                                        AND period_name = p_period_name));


                 RETURN v_period_name;

            EXCEPTION

                 WHEN NO_DATA_FOUND THEN
                 apps.Fnd_File.put_line (apps.Fnd_File.log,' Cannot get Prior Period for Period: ' ||to_char(p_period_name)  );
                    RAISE;

                 WHEN OTHERS THEN
                 apps.Fnd_File.put_line (apps.Fnd_File.log,' Error in Getting Prior Period For Period: ' ||to_char(p_period_name)  );
                    RAISE;

            END;

    END;

    FUNCTION get_posted_period(p_ledger_id number, p_application_id number, p_posted_date date) RETURN VARCHAR2 IS

      v_period_name  gl.gl_periods.period_name%TYPE;

    BEGIN

            BEGIN

                SELECT period_name
                  INTO v_period_name
                  FROM gl_period_statuses
                 WHERE ledger_id = p_ledger_id
                   AND application_id = p_application_id
                   AND p_posted_date between start_date and end_date;

                 RETURN v_period_name;

            EXCEPTION

                 WHEN NO_DATA_FOUND THEN
                 apps.Fnd_File.put_line (apps.Fnd_File.log,' Cannot get posted Period for Ledger ID: ' ||to_char(g_ledger_id)  );
                    RAISE;

                 WHEN OTHERS THEN
                 apps.Fnd_File.put_line (apps.Fnd_File.log,' Error in Getting posted Period For Ledger ID: ' ||to_char(g_ledger_id)  );
                    RAISE;

            END;

    END;
    FUNCTION get_posted_date RETURN DATE IS
     v_posted_date date;

    BEGIN

            BEGIN

                SELECT TRUNC(SYSDATE) - 1
                  INTO v_posted_date
                  FROM DUAL;

                RETURN v_posted_date;

            EXCEPTION

                 WHEN NO_DATA_FOUND THEN
                 apps.Fnd_File.put_line (apps.Fnd_File.log,' Cannot get latest Posted Date for Ledger ID: ' ||to_char(g_ledger_id)  );
                    RAISE;

                 WHEN OTHERS THEN
                 apps.Fnd_File.put_line (apps.Fnd_File.log,' Error in Getting latest Posted Date For Ledger ID: ' ||to_char(g_ledger_id)  );
                    RAISE;

            END;

    END;
    /************************************************************************************/
    /*                                  MAIN                                */
    /************************************************************************************/

PROCEDURE process_detail(
          errcode                     OUT VARCHAR2,
          errbuff                     OUT VARCHAR2,
          p_ledger_id                  IN NUMBER,
          p_period_name                IN VARCHAR2,
          p_posted_date                IN VARCHAR2,
          p_by_location_indicator      IN VARCHAR2
    ) IS
        -- Declare variables

    v_print_header_column_flag     varchar2(1):= '0';
    v_print_detail_column_flag     varchar2(1):= '0';
    v_detail_count                 number:=0;

   BEGIN


    v_loc := 10;
    v_module := 'detail main';

    g_ledger_id := p_ledger_id;
    g_by_location_indicator := p_by_location_indicator;

    v_loc := 15;
    v_module := 'get apps id';
    g_application_id := get_application_id('General Ledger');

    v_loc := 20;
    v_module := 'get currency';
    g_currency_code := get_currency_code(g_ledger_id);

    v_loc := 25;
    v_module := 'get ORG_ID';
--    g_org_id := APPS.TTEC_AUTOREC_GL_OUTBOUND_INT.get_org_id(g_ledger_id);

    v_loc := 30;
    v_module := 'get country';
--    g_country_code := APPS.TTEC_AUTOREC_GL_OUTBOUND_INT.get_country_code(g_org_id);

    v_loc := 30;
    v_module := 'get period';

    g_period_name := get_latest_open_period(g_ledger_id,g_application_id);
    g_latest_closed_period := get_latest_closed_period(g_ledger_id,g_application_id); /* 1.1 */

    v_loc := 40;
    v_module := 'get posted dt';
    IF p_posted_date IS NOT NULL THEN

       g_posted_date := to_date(p_posted_date);

       IF p_period_name IS NOT NULL THEN /* 1.1 */
          g_period_name := p_period_name;
          g_latest_closed_period := get_prior_period(g_ledger_id,g_application_id,p_period_name); /* 1.1 */
       END IF;

    ELSE

       g_posted_date:= get_posted_date;

    END IF;


    v_loc := 60;
    v_module := 'c_directory_path';

    open c_directory_path;
    fetch c_directory_path into v_file_path,v_filename;
    close c_directory_path;

    v_loc := 70;
    Fnd_File.put_line(Fnd_File.LOG, '');
    Fnd_File.put_line(Fnd_File.LOG,'>>>>>>>>>>>>>>>> Processing GL Detail Extract For <<<<<<<<<<<<<<<<<<<');   /* 1.5 */
    Fnd_File.put_line(Fnd_File.LOG, '');
    Fnd_File.put_line(Fnd_File.LOG,'           Ledger ID: '||g_ledger_id);
    Fnd_File.put_line(Fnd_File.LOG,'       Currency Code: '||g_currency_code);
    Fnd_File.put_line(Fnd_File.LOG,'         Period Name: '||g_period_name);
    Fnd_File.put_line(Fnd_File.LOG,'   Prior Period Name: '||g_latest_closed_period);
    Fnd_File.put_line(Fnd_File.LOG,'         Posted Date: '||to_char(g_posted_date,'DD-MON-RRRR'));
    Fnd_File.put_line(Fnd_File.LOG,'           File Path: '||v_file_path);
    Fnd_File.put_line(Fnd_File.LOG,'           File Name: '||v_filename);
    Fnd_File.put_line(Fnd_File.LOG,'         Starts Time: '||to_char(SYSDATE,'DD-MON-YYYY HH24:MI:SS'));     -- 1.2
    Fnd_File.put_line(Fnd_File.LOG, '');

    v_loc := 80;
    v_module := 'Open File';

    v_output_file := UTL_FILE.FOPEN(v_file_path, v_filename, 'w');

    v_loc := 90;
    v_module := 'Prnt Header Rec';



    FOR header_rec IN c_header
    LOOP
           print_header_column_name;
           v_print_detail_column_flag := '0';

           v_loc := 100;
           v_module := 'Header Rec';

           g_import_acct := header_rec.ledger_id -- 1.2
                   -- header_rec.location
                   ||' '|| header_rec.account;

           v_rec :=        header_rec.Record_Type
                   ||'|'|| header_rec.ledger_id; -- 1.2

           IF  g_by_location_indicator = 'Y' THEN

               v_rec := v_rec ||'.'|| header_rec.location; -- 1.5

           END IF;

           v_rec := v_rec
                   ||'.'|| header_rec.account
                   ||'.'|| header_rec.currency
                   ||'|'|| header_rec.closing_Date
                   ||'|'|| header_rec.Closing_Balance;

           open c_detail_count(header_rec.location,header_rec.account);
           fetch c_detail_count into v_detail_count;
           Close c_detail_count;

           v_rec := v_rec||'|' ||v_detail_count;
           apps.fnd_file.put_line(apps.fnd_file.output,v_rec);
           utl_file.put_line(v_output_file, v_rec);

            IF (   header_rec.Closing_Balance != 0 /* 1.1 */
                OR v_detail_count !=0 )  /* 1.4 */
               AND header_rec.Acct_flag = 'D'  /* 1.2 */
            THEN
            BEGIN

                --FOR detail_rec IN c_detail(header_rec.location, header_rec.account) -- 1.2
                FOR detail_rec IN c_detail(header_rec.location,header_rec.account) -- 1.5
                LOOP

                IF v_print_detail_column_flag = '0' THEN

                   print_detail_column_name;
                   v_print_detail_column_flag := '1';

                END IF;

                v_loc := 120;
                v_module := 'Detail Rec';

                    v_rec := detail_rec.detail_line;
                    apps.fnd_file.put_line(apps.fnd_file.output,v_rec);
                    utl_file.put_line(v_output_file, v_rec);

                END LOOP; /* Detail */
            END;
            END IF;

    END LOOP; /* Header */

    v_loc := 130;
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

         ttec_error_logging.process_error( g_application_code -- 'GL'
                                         , g_interface        -- 'AutoRec GL Intf';
                                         , g_package          -- 'TTEC_AUTOREC_GL_OUTBOUND_INT'
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

         ttec_error_logging.process_error( g_application_code -- 'GL'
                                         , g_interface        -- 'AutoRec GL Intf';
                                         , g_package          -- 'TTEC_AUTOREC_GL_OUTBOUND_INT'
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

        RAISE_APPLICATION_ERROR(-20003,'Exception OTHERS in TTEC_AUTOREC_GL_OUTBOUND_INT.process_detail: '||'Module >-' ||v_module||' ['||g_label1||']['||v_loc||']['||g_label2||']['||g_import_acct|| '] ERROR:'||errbuff);

    END process_detail;
PROCEDURE detail_main(
          errcode                     OUT VARCHAR2,
          errbuff                     OUT VARCHAR2,
          p_ledger_id                  IN NUMBER,
          p_period_name                IN VARCHAR2,
          p_posted_date                IN VARCHAR2,
          p_by_location_indicator      IN VARCHAR2
    ) IS
BEGIN

    /* 1.5 Begin */
    Fnd_File.put_line(Fnd_File.LOG, '');
    Fnd_File.put_line(Fnd_File.LOG,'--------------------------------------------------------------------------------------------------------------------------------------------------');
    Fnd_File.put_line(Fnd_File.LOG, '');
    Fnd_File.put_line(Fnd_File.LOG,'Concurrent Program -> TeleTech AutoRec GL Detail Outbound Interface');
    Fnd_File.put_line(Fnd_File.LOG, '');
    Fnd_File.put_line(Fnd_File.LOG,'Parameters:                  ');
    Fnd_File.put_line(Fnd_File.LOG,'            p_ledger_id: '||p_ledger_id);
    Fnd_File.put_line(Fnd_File.LOG,'          p_period_name: '||p_period_name);
    Fnd_File.put_line(Fnd_File.LOG,'          p_posted_date: '||p_posted_date);
    Fnd_File.put_line(Fnd_File.LOG,'p_by_location_indicator: '||p_by_location_indicator);
    Fnd_File.put_line(Fnd_File.LOG, '');
    Fnd_File.put_line(Fnd_File.LOG,'--------------------------------------------------------------------------------------------------------------------------------------------------');

   g_by_location_indicator := p_by_location_indicator;

   /* 1.5 End */

   IF p_ledger_id is not NULL THEN
          process_detail(errcode ,errbuff,p_ledger_id,p_period_name,p_posted_date,g_by_location_indicator); /* 1.5 */
   ELSE
      FOR ledger_rec IN c_ledger
      LOOP
          process_detail(errcode ,errbuff,ledger_rec.ledger_id,p_period_name,p_posted_date,g_by_location_indicator); /* 1.5 */
      END LOOP;
   END IF;
END detail_main;
PROCEDURE process_balance(
          errcode                     OUT VARCHAR2,
          errbuff                     OUT VARCHAR2,
          p_ledger_id                  IN NUMBER,
          p_period_name                IN VARCHAR2,
          p_by_location_indicator      IN VARCHAR2
    ) IS

        -- Declare variables
    /* 2.0 Begin */
    v_record_type           varchar2(1);
    v_ledger_id             number;
    v_location              varchar2(5);
    v_account               varchar2(4);
    v_currency              varchar2(3);
    v_Adjusted_balance_date varchar2(8);
    v_Adjusted_Balance      number;
    /* 2.0 End */
    v_Adjusted_balance_sign varchar2(1);
--    v_print_header_flag     varchar2(1):= 0;

   BEGIN

        g_ledger_id := p_ledger_id;

        g_application_id := get_application_id('General Ledger');

        g_currency_code := get_currency_code(g_ledger_id);

        IF p_period_name IS NOT NULL THEN

           g_period_name := p_period_name;

        ELSE

           g_period_name := get_latest_closed_period(g_ledger_id,g_application_id);

        END IF;


    v_loc := 25;
    v_module := 'get ORG_ID';
--    g_org_id := APPS.TTEC_AUTOREC_GL_OUTBOUND_INT.get_org_id(g_ledger_id);

    v_loc := 30;
    v_module := 'get country';
--    g_country_code := APPS.TTEC_AUTOREC_GL_OUTBOUND_INT.get_country_code(g_org_id);

    v_loc := 10;
    v_module := 'c_directory_path';
    v_loc := 20;
    open c_directory_path2;
    fetch c_directory_path2 into v_file_path,v_filename;
    close c_directory_path2;

    v_loc := 30;
    Fnd_File.put_line(Fnd_File.LOG, '');
    Fnd_File.put_line(Fnd_File.LOG,'>>>>>>>>>>>>>>>> Processing GL Balance Extract For <<<<<<<<<<<<<<<<<<<');   /* 1.5 */
    Fnd_File.put_line(Fnd_File.LOG, '');
    Fnd_File.put_line(Fnd_File.LOG,'           Ledger ID: '||g_ledger_id);
    Fnd_File.put_line(Fnd_File.LOG,'       Currency Code: '||g_currency_code);
    Fnd_File.put_line(Fnd_File.LOG,'         Period Name: '||g_period_name);
    Fnd_File.put_line(Fnd_File.LOG,'           File Path: '||v_file_path);
    Fnd_File.put_line(Fnd_File.LOG,'           File Name: '||v_filename);
    Fnd_File.put_line(Fnd_File.LOG,'         Starts Time: '||to_char(SYSDATE,'DD-MON-YYYY HH24:MI:SS'));    -- 1.2
    Fnd_File.put_line(Fnd_File.LOG, '');

    v_loc := 40;
    v_module := 'Open File';

    v_output_file := UTL_FILE.FOPEN(v_file_path, v_filename, 'w');

    FOR ledger_account IN c_ledger_account /* 2.0 */
    LOOP
        BEGIN
                /* 2.0 Begin */
                v_loc := 42;
                v_module := 'Get Period';
                SELECT TO_CHAR(gp.end_date, 'YYYYMMDD')
                  INTO v_Adjusted_balance_date
                  FROM gl_periods  gp
                WHERE gp.period_name =   g_period_name;
                v_loc := 44;
                v_module := 'Get Bal';
                Fnd_File.put_line(Fnd_File.LOG, '');

                SELECT 'B'                record_type,
                       gl.ledger_id          ledger_id, -- 1.2
                       decode(g_by_location_indicator,'Y',gcc.segment1,'') location, -- 1.2  1.4
                       gcc.segment4       account,-- account
                       gb.currency_code   currency,
                      -- TO_CHAR(gp.end_date, 'YYYYMMDD')                Adjusted_balance_date,        --                                 "Adjusted Balance Date",
                       SUM(nvl(gb.period_net_dr,0) + nvl(gb.BEGIN_BALANCE_DR,0)) - SUM(nvl(gb.period_net_cr,0) + nvl(gb.BEGIN_BALANCE_CR,0) )        Adjusted_Balance                             --   "Adjusted Balance",
                  INTO v_record_type,
                       v_ledger_id,
                       v_location,
                       v_account,
                       v_currency,
                       --v_Adjusted_balance_date
                       v_Adjusted_Balance
                  FROM gl_code_combinations gcc,
                       gl_balances           gb,
                    --   gl_periods            gp,
                       fnd_lookup_values    flv,
                       gl_ledgers            gl
                WHERE gcc.code_combination_id = gb.code_combination_id
                   --AND gb.period_name          = gp.period_name
                   AND gl.ledger_id            = gb.ledger_id
                   AND gcc.segment1  = decode(g_by_location_indicator,'Y',flv.attribute2,gcc.segment1) -- V. 1.4
                   AND gcc.segment4  = SUBSTR(flv.lookup_code,1,4)
                   AND flv.lookup_type = 'TTEC_AUTO_RECON_ACCOUNTS'
                   AND flv.LANGUAGE = 'US'
                   AND flv.enabled_flag = 'Y'
                   AND flv.attribute1 = g_ledger_id /* 1.2 */
                   AND SUBSTR(flv.lookup_code,1,4) = ledger_account.account
                   AND NVL(flv.attribute2,1) = decode(g_by_location_indicator,'Y',ledger_account.location,NVL(flv.attribute2,1))
                   AND gb.currency_code        = NVL(g_currency_code, gb.currency_code)
                  -- AND gp.period_name          = NVL(g_period_name, gp.period_name)
                   AND gb.period_name         = NVL(g_period_name, gb.period_name )
                   AND gb.LEDGER_ID           = g_ledger_id
                   AND gb.actual_flag          = 'A'
                GROUP BY 'B',
                          gl.ledger_id,   --1.2
                          decode(g_by_location_indicator,'Y',gcc.segment1,'') , -- 1.2  1.4
                          gcc.segment4 ,
                          gb.currency_code;
                          --TO_CHAR(gp.end_date, 'YYYYMMDD');
                /* 2.0 End */

                IF g_print_balance_header_flag = '0' THEN  /* 2.1 */
                   print_balance_column_name;
                   g_print_balance_header_flag := '1';      /* 2.1 */
                END IF;
                v_loc := 50;
                v_module := 'Balance Rec';

                IF SIGN(v_Adjusted_Balance) = -1 THEN
                   v_Adjusted_balance_sign := 'C';
                ELSE
                   v_Adjusted_balance_sign := 'D';
                END IF;

               g_import_acct := v_ledger_id;

               v_rec :=        v_Record_Type
                       ||'|'|| v_ledger_id; --1.2

               IF  g_by_location_indicator = 'Y' THEN

                   v_rec := v_rec ||'.'|| v_location; -- 1.5

                   g_import_acct := g_import_acct
                           ||' '|| v_location;

               END IF;

               g_import_acct := g_import_acct
                       ||' '|| v_account;

               v_rec := v_rec ||'.'|| v_account --1.3
                       ||'.'|| v_currency --1.3
                       ||'|'|| v_Adjusted_balance_date
                       ||'|'|| v_Adjusted_Balance
                       ||'|'|| v_Adjusted_balance_sign;

                apps.fnd_file.put_line(apps.fnd_file.output,v_rec);
                utl_file.put_line(v_output_file, v_rec);
        /* 2.0 Begin */
        EXCEPTION
        WHEN NO_DATA_FOUND THEN
               v_rec :=        'B'
                       ||'|'|| g_ledger_id; --1.2

               IF  g_by_location_indicator = 'Y' THEN
                   v_rec := v_rec ||'.'|| ledger_account.location; -- 1.5
               END IF;

               v_rec := v_rec ||'.'|| ledger_account.account --1.3
                       ||'.'|| g_currency_code
                       ||'|'|| v_Adjusted_balance_date
                       ||'|'|| '0'
                       ||'|'|| 'D';

                apps.fnd_file.put_line(apps.fnd_file.output,v_rec);
                utl_file.put_line(v_output_file, v_rec);

        WHEN OTHERS THEN
                 apps.Fnd_File.put_line (apps.Fnd_File.log,' Error in Getting GL Balance For: ' ||ledger_account.account||ledger_account.location||' at Loc/Module -><<'||v_loc||'/'|| v_module||'>>' );
                 errcode  := SQLCODE;
                 errbuff  := SUBSTR (SQLERRM, 1, 255);
                 RAISE;
        END;
        /* 2.0 End */
    END LOOP; /* Account */

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

         ttec_error_logging.process_error( g_application_code -- 'GL'
                                         , g_interface        -- 'AutoRec GL Intf';
                                         , g_package          -- 'TTEC_AUTOREC_GL_OUTBOUND_INT'
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

         ttec_error_logging.process_error( g_application_code -- 'GL'
                                         , g_interface        -- 'AutoRec GL Intf';
                                         , g_package          -- 'TTEC_AUTOREC_GL_OUTBOUND_INT'
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

        RAISE_APPLICATION_ERROR(-20003,'Exception OTHERS in TTEC_AUTOREC_GL_OUTBOUND_INT.process_balance: '||'Module >-' ||v_module||' ['||g_label1||']['||v_loc||']['||g_label2||']['||g_import_acct|| '] ERROR:'||errbuff);

    END process_balance;

PROCEDURE balance_main(
          errcode                     OUT VARCHAR2,
          errbuff                     OUT VARCHAR2,
          p_ledger_id                  IN NUMBER,
          p_period_name                IN VARCHAR2,
          p_by_location_indicator      IN VARCHAR2
    ) IS
BEGIN
    /* 1.5 Begin */
    Fnd_File.put_line(Fnd_File.LOG, '');
    Fnd_File.put_line(Fnd_File.LOG,'--------------------------------------------------------------------------------------------------------------------------------------------------');
    Fnd_File.put_line(Fnd_File.LOG, '');
    Fnd_File.put_line(Fnd_File.LOG,'Concurrent Program -> TeleTech AutoRec GL Balance Data Feed ');
    Fnd_File.put_line(Fnd_File.LOG, '');
    Fnd_File.put_line(Fnd_File.LOG,'Parameters:                  ');
    Fnd_File.put_line(Fnd_File.LOG,'            p_ledger_id: '||p_ledger_id);
    Fnd_File.put_line(Fnd_File.LOG,'          p_period_name: '||p_period_name);
    Fnd_File.put_line(Fnd_File.LOG,'p_by_location_indicator: '||p_by_location_indicator);
    Fnd_File.put_line(Fnd_File.LOG, '');
    Fnd_File.put_line(Fnd_File.LOG,'--------------------------------------------------------------------------------------------------------------------------------------------------');

   g_by_location_indicator := p_by_location_indicator;
   g_print_balance_header_flag := 0;  /* 2.1 */

   /* 1.5 End */

   IF p_ledger_id is not NULL THEN
          process_balance(errcode ,errbuff,p_ledger_id,p_period_name,g_by_location_indicator); /* 1.5 */
   ELSE
      FOR ledger_rec IN c_ledger
      LOOP
          process_balance(errcode ,errbuff,ledger_rec.ledger_id,p_period_name,g_by_location_indicator); /* 1.5 */
      END LOOP;
   END IF;
END balance_main;
END TTEC_AUTOREC_GL_OUTBOUND_INT;
/
show errors;
/