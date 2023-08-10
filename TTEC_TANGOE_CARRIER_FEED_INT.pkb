create or replace PACKAGE BODY      TTEC_TANGOE_CARRIER_FEED_INT AS
--
-- Program Name:  TTEC_TANGOE_CARRIER_FEED_INT
-- /* $Header: TTEC_TANGOE_CARRIER_FEED_INT.pkb 1.0 2014/07/07 chchan ship $ */
--
-- /*== START ================================================================================================*\
--    Author: Christiane Chan
--      Date: 07-JUL-2014
--
-- Call From: Concurrent Program ->TeleTech Tangoe Carrier Outbound Interface
--      Desc: This program generates TeleTech TELECOM Supplier (CARRIER) data feed to TANGOE
--
--     Parameter Description:
--
--           p_business_group_id       :   Business Group to be pushed to Egencia, each BG will be generated on a seperate file with respect with the File Naming Convention
--
--       Oracle Standard Parameters:
--
--   Modification History:
--
--  Version    Date     Author   Description (Include Ticket--)
--  -------  --------  --------  ------------------------------------------------------------------------------
--      1.0  03707/14   CChan     Initial Version REQ00???? - TeleTech Tangoe  Carrier Outbound Interface
--      1.0  05/2/23    RXNETHI-ARGANO  R12.2 Upgrade Remediation
-- \*== END =========================================================================================================

    --v_module                         cust.ttec_error_handling.module_name%TYPE := 'Main';     --code commented by RXNETHI-ARGANO,02/05/23
    v_module                         apps.ttec_error_handling.module_name%TYPE := 'Main';       --code added by RXNETHI-ARGANO,02/05/23
    v_loc                            NUMBER;
    v_msg                            varchar2(2000);
    v_rec                            varchar2(5000);

    /*********************************************************
     **  Private Procedures and Functions
    *********************************************************/

    PROCEDURE print_detail_column_name (v_rec OUT VARCHAR2) IS
    BEGIN

           IF g_manual_upload = 'Y'
           THEN
               v_rec :=   '"xRowID"'
                        ||',"ACTION"'
                        ||',"CARRIER"'
                        ||',"VendorID"'
                        ||',"Vendor Number"'
                        ||',"ADDRESS1"'
                        ||',"ADDRESS2"'
                        ||',"ADDRESS3"'
                        ||',"CITY"'
                        ||',"STATE"'
                        ||',"ZIP"'
                        ||',"COUNTRY"'
                        ||',"NOTES"'
                        ||',"PAYMENT TERM"'
                        ||',"IS_CARRIER_POP"'
                        ||',"CLLI"'
                   ;
            ELSE
             v_rec :=     '"ACTION"'
                        ||',"CARRIER"'
                        ||',"VendorID"'
                        ||',"Vendor Number"'
                        ||',"ADDRESS1"'
                        ||',"ADDRESS2"'
                        ||',"ADDRESS3"'
                        ||',"CITY"'
                        ||',"STATE"'
                        ||',"ZIP"'
                        ||',"COUNTRY"'
                        ||',"NOTES"'
                        ||',"PAYMENT TERM"'
                        ||',"IS_CARRIER_POP"'
                        ||',"CLLI"'
                   ;
            END IF;

       apps.fnd_file.put_line(apps.fnd_file.output,v_rec);

    END;

    /************************************************************************************/
    /*                                  MAIN                                */
    /************************************************************************************/

PROCEDURE main(
          errcode                     OUT VARCHAR2,
          errbuff                     OUT VARCHAR2,
          p_last_run                  IN  DATE
    ) IS

   BEGIN

    INSERT INTO FND_SESSIONS VALUES (USERENV('SESSIONID'), trunc(sysdate));

    v_loc := 10;

    IF p_last_run IS NULL THEN
        OPEN c_last_run;
        FETCH c_last_run INTO g_last_run;
        CLOSE c_last_run;

        IF g_last_run IS NULL THEN
           g_last_run := to_date('01-AUG-2014');
        END IF;

    ELSE
        g_last_run := to_date(p_last_run);
    END IF;

    v_module := 'c_directory_path';
    v_loc := 20;
    open c_directory_path;
    fetch c_directory_path into v_file_path,v_filename;
    close c_directory_path;

    v_loc := 30;
    Fnd_File.put_line(Fnd_File.LOG, '');
    Fnd_File.put_line(Fnd_File.LOG,'--------------------------------------------------------------------------------------------------------------------------------------------------');
    Fnd_File.put_line(Fnd_File.LOG, '');
    Fnd_File.put_line(Fnd_File.LOG,'Concurrent Program -> TeleTech Tangoe Carrier Outbound Interface');
    Fnd_File.put_line(Fnd_File.LOG, '');
    Fnd_File.put_line(Fnd_File.LOG,'Parameters:                  ');
    Fnd_File.put_line(Fnd_File.LOG,'             Last Run Date: '||g_last_run);
    Fnd_File.put_line(Fnd_File.LOG,'--------------------------------------------------------------------------------------------------------------------------------------------------');

    v_loc := 40;
    v_module := 'Open File';

    v_output_file := UTL_FILE.FOPEN(v_file_path, v_filename, 'w');

    v_loc := 50;
    v_module := 'Emp Rec';

    print_detail_column_name (v_rec);
    utl_file.put_line(v_output_file, v_rec);

    v_row_id := 0;

    FOR carrier_rec IN c_carrier_cur
    LOOP
           v_rec := NULL;
           v_loc := 60;

            v_rec :=  carrier_rec.line;
            apps.fnd_file.put_line(apps.fnd_file.output,v_rec);
            utl_file.put_line(v_output_file, v_rec);
            v_loc := 70;
            g_emp_no := 'nxtRec';

    END LOOP; /* Employees */

    v_loc := 80;
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
                                         , g_interface        -- 'Tangoe Intf';
                                         , g_package          -- 'TTEC_TANGOE_CARRIER_FEED_INT'
                                         , v_module
                                         , g_failure_status
                                         , SQLCODE
                                         , SQLERRM
                                         , g_label1
                                         , v_loc
                                         , g_label2
                                         , g_emp_no
                                         , g_label3 );

          errcode  := SQLCODE;
          errbuff  := SUBSTR (SQLERRM, 1, 255);

    WHEN OTHERS
    THEN
         UTL_FILE.FCLOSE(v_output_file);

         ttec_error_logging.process_error( g_application_code -- 'AP'
                                         , g_interface        -- 'Tangoe Intf';
                                         , g_package          -- 'TTEC_TANGOE_CARRIER_FEED_INT'
                                         , v_module
                                         , g_failure_status
                                         , SQLCODE
                                         , SQLERRM
                                         , g_label1
                                         , v_loc
                                         , g_label2
                                         , g_emp_no
                                         , g_label3                                          );

          errcode  := SQLCODE;
          errbuff  := SUBSTR (SQLERRM, 1, 255);

        RAISE_APPLICATION_ERROR(-20003,'Exception OTHERS in TTEC_TANGOE_CARRIER_FEED_INT.main: '||'Module >-' ||v_module||' ['||g_label1||']['||v_loc||']['||g_label2||']['||g_emp_no|| '] ERROR:'||errbuff);

    END main;

END TTEC_TANGOE_CARRIER_FEED_INT;
/
show errors;
/