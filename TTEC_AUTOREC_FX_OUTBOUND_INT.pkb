create or replace PACKAGE BODY      TTEC_AUTOREC_FX_OUTBOUND_INT  AS
--
--
-- Program Name:  TTEC_AUTOREC_FX_OUTBOUND_INT
-- /* $Header: TTEC_AUTOREC_FX_OUTBOUND_INT .pkb 1.0 2013/06/03  chchan ship $ */
--
-- /*== START ================================================================================================*\
--    Author: Christiane Chan
--      Date: 03-JUN-2013
--
-- Call From: Concurrent Program ->TeleTech AutoRec FX Outbound Interface
--      Desc: This program generates FX Data Feed mandated by Cheasapeak T-Recs requirements
--
--     Parameter Description:
--
--         p_ledger_id               :
--         p_period_name             :
--         p_conversion_date             :
--
--       Oracle Standard Parameters:
--
--   Modification History:
--
--  Version    Date     Author   Description (Include Ticket--)
--  -------  --------  --------  ------------------------------------------------------------------------------
--      1.0  06/03/13   CChan     Initial Version TTSD R#2340332 - AutoRec Project
--      1.2  09/30/13   CChan     TTSD I#2699480 - Change Logic to set the default Period Name to prior month of SYSDATE,
--                                                 so the scheduled job will pull the prior month's Period End Rate
--		1.0	15-May-2023 IXPRAVEEN(ARGANO)   		R12.2 Upgrade Remediation
-- \*== END =====================================

    --v_module                         cust.ttec_error_handling.module_name%TYPE := 'Main';				-- Commented code by IXPRAVEEN-ARGANO,15-May-2023
    v_module                         apps.ttec_error_handling.module_name%TYPE := 'Main';               --  code Added by IXPRAVEEN-ARGANO,   15-May-2023
    v_loc                            NUMBER;
    v_msg                            varchar2(2000);
    v_rec                            varchar2(5000);

    /*********************************************************
     **  Private Procedures and Functions
    *********************************************************/
    PROCEDURE print_FX_column_name IS
    BEGIN

                v_rec :=   'Record Identifier'
                   ||'|'|| 'From Currency'
                   ||'|'|| 'To Currency'
                   ||'|'|| 'Start Date'
                   ||'|'|| 'End Date'
                   ||'|'|| 'Exchange Rate'
                   ||'|'|| 'Reverse Exchange Rate'
                   ;
       apps.fnd_file.put_line(apps.fnd_file.output,v_rec);
       --utl_file.put_line(v_output_file, v_rec);

    END;
    /************************************************************************************/
    /*                                  MAIN                                */
    /************************************************************************************/

PROCEDURE fx_main(
          errcode                     OUT VARCHAR2,
          errbuff                     OUT VARCHAR2,
          p_period_name                IN VARCHAR2,
          p_rate_type_1                IN VARCHAR2,
          p_rate_type_2                IN VARCHAR2
    ) IS
BEGIN

    v_loc := 10;
    v_module := 'get apps id';
    g_application_id := APPS.TTEC_AUTOREC_GL_OUTBOUND_INT.get_application_id('General Ledger');

    IF p_period_name IS NOT NULL THEN

       g_period_name := p_period_name;

    ELSE

       --g_period_name := APPS.TTEC_AUTOREC_GL_OUTBOUND_INT.get_latest_closed_period(1,g_application_id); /* Commented out for 1.2 */
       g_period_name := TO_CHAR(add_months(sysdate,-1),'MON-YY'); /* 1.2 */

    END IF;

    g_rate_type_1 := p_rate_type_1;
    g_rate_type_2 := p_rate_type_2;

    v_module := 'c_directory_path';
    v_loc := 20;
    open c_directory_path;
    fetch c_directory_path into v_file_path,v_filename;
    close c_directory_path;

    v_loc := 30;
    Fnd_File.put_line(Fnd_File.LOG, '');
    Fnd_File.put_line(Fnd_File.LOG,'--------------------------------------------------------------------------------------------------------------------------------------------------');
    Fnd_File.put_line(Fnd_File.LOG, '');
    Fnd_File.put_line(Fnd_File.LOG,'Concurrent Program -> TeleTech AutoRec FX Outbound Interface');
    Fnd_File.put_line(Fnd_File.LOG, '');
    Fnd_File.put_line(Fnd_File.LOG,'Parameters:                  ');
    Fnd_File.put_line(Fnd_File.LOG,'Latest Closed Period Name: '||g_period_name);
    Fnd_File.put_line(Fnd_File.LOG,'              Rate Type 1: '||g_rate_type_1);
    Fnd_File.put_line(Fnd_File.LOG,'              Rate Type 2: '||g_rate_type_2);
    Fnd_File.put_line(Fnd_File.LOG,'                File Path: '||v_file_path);
    Fnd_File.put_line(Fnd_File.LOG,'                File Name: '||v_filename);
    Fnd_File.put_line(Fnd_File.LOG,'              Starts Time: '||to_char(SYSDATE,'DD-MON-YYYY HH24:MI:SS'));     -- 1.2
    Fnd_File.put_line(Fnd_File.LOG,'--------------------------------------------------------------------------------------------------------------------------------------------------');

    v_loc := 40;
    v_module := 'Open File';

    v_output_file := UTL_FILE.FOPEN(v_file_path, v_filename, 'w');

    v_loc := 50;
    v_module := 'FX Rec';

    print_FX_column_name;

    FOR fx_rec IN c_fx
    LOOP

        v_rec := fx_rec.detail_line;
        apps.fnd_file.put_line(apps.fnd_file.output,v_rec);
        utl_file.put_line(v_output_file, v_rec);

    END LOOP; /* Header */

    v_loc := 60;
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

         ttec_error_logging.process_error( g_application_code -- 'FX'
                                         , g_interface        -- 'AutoRec FX Intf';
                                         , g_package          -- 'TTEC_AUTOREC_FX_OUTBOUND_INT '
                                         , v_module
                                         , g_failure_status
                                         , SQLCODE
                                         , SQLERRM
                                         , g_label1
                                         , v_loc
                                         , g_label2
                                         , g_period_name );

          errcode  := SQLCODE;
          errbuff  := SUBSTR (SQLERRM, 1, 255);

    WHEN OTHERS
    THEN
         UTL_FILE.FCLOSE(v_output_file);

         ttec_error_logging.process_error( g_application_code -- 'FX'
                                         , g_interface        -- 'AutoRec FX Intf';
                                         , g_package          -- 'TTEC_AUTOREC_FX_OUTBOUND_INT '
                                         , v_module
                                         , g_failure_status
                                         , SQLCODE
                                         , SQLERRM
                                         , g_label1
                                         , v_loc
                                         , g_label2
                                         , g_period_name );

          errcode  := SQLCODE;
          errbuff  := SUBSTR (SQLERRM, 1, 255);

        RAISE_APPLICATION_ERROR(-20003,'Exception OTHERS in TTEC_AUTOREC_FX_OUTBOUND_INT .process_detail: '||'Module >-' ||v_module||' ['||g_label1||']['||v_loc||']['||g_label2||']['||g_rate_type_1 ||' '||g_rate_type_2|| '] ERROR:'||errbuff);
END fx_main;
END TTEC_AUTOREC_FX_OUTBOUND_INT ;
/
show errors;
/