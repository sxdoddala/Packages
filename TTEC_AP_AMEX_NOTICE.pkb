create or replace PACKAGE BODY TTEC_AP_AMEX_NOTICE AS

/*============================================================*\
  Author:  Marcela Lagostena
    Date:  09-NOV-2011
    Desc:  This program generates notification if the file is generated from american express
  Modification History:

  Mod#    Date     Author    Description (Include Ticket#)
 -----  --------  --------  ----------------------------------------------
   1.1   11/09/11  Kaushik   fixed the custom top path for R12 upgrade project
   1.2   08/21/15  Lalitha   rehosting changes for smtp server
   1.0   07/17/23  MXKEERTHI(ARGANO)                R12.2 Upgrade Remediation
\*=============================================================*/

PROCEDURE email_notification (errcode VARCHAR2, errbuff VARCHAR, email_TO_list IN  VARCHAR2,email_CC_list IN  VARCHAR2, p_filename IN VARCHAR2 ) IS

    /*** Declare variables ***/
    v_file_handle       UTL_FILE.file_type;
    p_status            NUMBER;
    l_body              VARCHAR2 (8000);
    crlf                CHAR (2) := CHR (10) || CHR (13); -- carriage return/line_feed
    cr                  CHAR (2) := CHR (13); -- carriage return
    l_rec_num           VARCHAR2 (64);
    l_text              VARCHAR2(32767);
    l_date_stamp        VARCHAR2(64);
    l_email_from        VARCHAR2(256) := 'EBS_Development@TeleTech.com';
    l_email_to          VARCHAR2(256) := NULL;
    l_email_cc          VARCHAR2(256) := NULL;
    l_dir               VARCHAR2(256) := NULL;
    l_email_subj        VARCHAR2(256);
    l_email_body1       VARCHAR2 (256);
    l_email_body2       VARCHAR2 (256) :=  TO_CHAR (SYSDATE, 'MM/DD/YYYY HH24:MM' ||'. ');
    l_email_body3       VARCHAR2 (256);
    l_email_body4       VARCHAR2 (256);

    -- set directory destination for output file
    l_host_name       VARCHAR2 (256);
    c_start_date      VARCHAR(64);
    c_end_date        VARCHAR2(64);

    l_last_file_date   VARCHAR2(8);
    l_last_process_date VARCHAR2(20);
    l_day_counter           NUMBER;

    CURSOR c_host
    IS
        SELECT SUBSTR (host_name, 1, 10)
        FROM v$instance;
    -- Set directory destination for output file -- R12 upgrade fix. <1.1>
    CURSOR c_directory_path
    IS
        SELECT  ttec_library.get_directory( 'CUST_TOP' )||'/data/' from dual;

    CURSOR c_last_file_date
    IS
        SELECT file_date
        FROM 	--cust.ap_amex_processed_dates--Commented code by MXKEERTHI-ARGANO,07/17/2023
	              apps.ap_amex_processed_dates  --code added by MXKEERTHI-ARGANO, 07/17/2023 
        WHERE process_date = (SELECT MAX(process_date)
                              FROM 	--cust.ap_amex_processed_dates--Commented code by MXKEERTHI-ARGANO,07/17/2023
	                                  apps.ap_amex_processed_dates);  --code added by MXKEERTHI-ARGANO, 07/17/2023 

    CURSOR c_last_process_date
    IS
        SELECT TO_CHAR(MAX(process_date),'DD-MON-YYYY HH24:MM:SS') AS process_date
        FROM 	--cust.ap_amex_processed_dates--Commented code by MXKEERTHI-ARGANO,07/17/2023
	             apps.ap_amex_processed_dates;  --code added by MXKEERTHI-ARGANO, 07/17/2023 ;

    CURSOR c_day_counter
    IS
        SELECT TRUNC(SYSDATE - process_date)
        FROM 	--cust.ap_amex_processed_dates--Commented code by MXKEERTHI-ARGANO,07/17/2023
	              apps.ap_amex_processed_dates  --code added by MXKEERTHI-ARGANO, 07/17/2023 
        WHERE process_date = (SELECT MAX(process_date)
                              FROM 	--cust.ap_amex_processed_dates--Commented code by MXKEERTHI-ARGANO,07/17/2023
	                                  apps.ap_amex_processed_dates);  --code added by MXKEERTHI-ARGANO, 07/17/2023 

    /** Get AmEx setup data **/
    --xsel            cust.ttec_error_handling%ROWTYPE;--Commented code by MXKEERTHI-ARGANO,07/17/2023
    xsel            apps.ttec_error_handling%ROWTYPE;  --code added by MXKEERTHI-ARGANO, 07/17/2023 
    w_mesg          VARCHAR2(256);
    rec_email       VARCHAR2(256);
    l_email_to_send NUMBER;


    BEGIN
        -- Get host name
        OPEN c_host;

        FETCH c_host
        INTO l_host_name;

        CLOSE c_host;

        -- Get directory path
        OPEN c_directory_path;

        FETCH c_directory_path
        INTO l_dir;

        CLOSE c_directory_path;

        -- Get last file date
        OPEN c_last_file_date;

        FETCH c_last_file_date
        INTO l_last_file_date;

        CLOSE c_last_file_date;

        -- Get last process date
        OPEN c_last_process_date;

        FETCH c_last_process_date
        INTO l_last_process_date;

        CLOSE c_last_process_date;

        --Get number of days since last load
        OPEN c_day_counter;

        FETCH c_day_counter
        INTO l_day_counter;

        CLOSE c_day_counter;

        /** Initializing log & output files **/
        Fnd_File.put_line(Fnd_File.output, ' ' );
        Fnd_File.put_line(Fnd_File.log, ' ');
        Fnd_File.put_line(Fnd_File.output, 'Processing Emails for Am Ex Notification  - Program run date: ' ||  TO_CHAR (SYSDATE, 'MM/DD/YYYY HH24:MM') );
        Fnd_File.put_line(Fnd_File.log, 'Processing Emails for Am Ex Notification - Program run date: ' ||  TO_CHAR (SYSDATE, 'MM/DD/YYYY HH24:MM') );

        /** Initializing email components **/
        l_body := NULL;

        /** Opening file **/
        v_file_handle := UTL_FILE.fopen (l_dir, p_filename, 'r', 32767);

        -- Get first line of the file
        UTL_FILE.get_line(v_file_handle, l_text, 32767);

        -- Get dates from file
        c_start_date := SUBSTR(l_text, 34, 8);
        c_end_date  := SUBSTR(l_text, 43, 8);

        --Closing file
        UTL_FILE.fclose (v_file_handle);

      IF p_filename = 'ge1500.dat'
      THEN

        IF(c_start_date = l_last_file_date) /** The file has already been loaded **/
        THEN

            l_email_subj := 'The last US file was loaded on '||l_last_process_date||' MT with data from '||l_last_file_date||'. ';

            l_email_body1 := 'There are no new US files to load from American Express on: ';
            l_email_body3 := 'No new US files have been loaded from American Express in the last ' ||TO_CHAR(l_day_counter) ||' days. '
                               ||'The last US file was loaded on '||l_last_process_date||' MT with data from '||l_last_file_date||'. ';
            l_email_body4 := 'If you have any questions, please contact the ERP Development Team.';



            IF(l_day_counter > 2) /*** No new files in the last 2 days ***/
            THEN
                l_email_cc := 'EBS_Development@TeleTech.com' ||' , '|| email_CC_list;

                l_email_subj := 'WARNING! There are no new US files to load from American Express';

                l_email_body1 := 'WARNING! There are no new US files to load from American Express on: ';
                l_email_body4 := 'The name of the US file is: '||p_filename||'. The ERP Development Team has already been notified.';

            END IF;

            Fnd_File.put_line(Fnd_File.output, ' ' );
            Fnd_File.put_line(Fnd_File.output, 'There are no new US files to load from American Express.');
            Fnd_File.put_line(Fnd_File.output, 'Notification e-mail sent successfully to list' ||email_TO_list ||' and CC to '||l_email_cc );
            Fnd_File.put_line(Fnd_File.output, ' ' );
            Fnd_File.put_line(Fnd_File.output, 'There has been no new US files from American Express in the last ' ||l_day_counter ||' days.');
            Fnd_File.put_line(Fnd_File.output, 'Process Completed.');
            Fnd_File.put_line(Fnd_File.log, ' ' );

        ELSE /** A new file has been loaded **/

            l_email_subj := 'US Am Ex Files: '||p_filename||' for Dates: ' ||TO_CHAR(TO_DATE(c_start_date, 'YYYYMMDD'), 'DD-MON-YYYY')
                          ||' Through '|| TO_CHAR(TO_DATE(c_end_date, 'YYYYMMDD'), 'DD-MON-YYYY');
            l_email_body1 := 'Data received from American Express. The US files: '||p_filename||' have been loaded into Production On ';
            l_email_body3 := 'Check Oracle Log file for Status of load. ' ;
            l_email_body4 := 'If you have any questions, please contact the ERP Development Team.';

            /** Insert dates into log table **/
            INSERT INTO 	--cust.ap_amex_processed_dates--Commented code by MXKEERTHI-ARGANO,07/17/2023
	                          apps.ap_amex_processed_dates  --code added by MXKEERTHI-ARGANO, 07/17/2023 
             VALUES (c_start_date, SYSDATE);

            COMMIT;

            Fnd_File.put_line(Fnd_File.output, ' ' );
            Fnd_File.put_line(Fnd_File.output, 'Email sent successfully to list' ||email_TO_list ||' and CC to '||l_email_cc );
            Fnd_File.put_line(Fnd_File.output, ' ' );
            Fnd_File.put_line(Fnd_File.output, 'Process Completed Successfully');
            Fnd_File.put_line(Fnd_File.log, ' ' );

        END IF;

       ELSE
       IF (c_start_date = l_last_file_date) /** The file has already been loaded **/
       THEN

            l_email_subj := 'The last CAN file was loaded on '||l_last_process_date||' MT with data from '||l_last_file_date||'. ';

            l_email_body1 := 'There are no new CAN files to load from American Express on: ';
            l_email_body3 := 'No new CAN files have been loaded from American Express in the last ' ||TO_CHAR(l_day_counter) ||' days. '
                               ||'The last CAN file was loaded on '||l_last_process_date||' MT with data from '||l_last_file_date||'. ';
            l_email_body4 := 'If you have any questions, please contact the ERP Development Team.';



            IF(l_day_counter > 2) /*** No new files in the last 2 days ***/
            THEN
                l_email_cc := 'EBS_Development@TeleTech.com' ||' , '|| email_CC_list;

                l_email_subj := 'WARNING! There are no new CAN files to load from American Express';

                l_email_body1 := 'WARNING! There are no new CAN files to load from American Express on: ';
                l_email_body4 := 'The name of the CAN file is: '||p_filename||'. The ERP Development Team has already been notified.';

            END IF;

            Fnd_File.put_line(Fnd_File.output, ' ' );
            Fnd_File.put_line(Fnd_File.output, 'There are no new CAN files to load from American Express.');
            Fnd_File.put_line(Fnd_File.output, 'Notification e-mail sent successfully to list' ||email_TO_list ||' and CC to '||l_email_cc );
            Fnd_File.put_line(Fnd_File.output, ' ' );
            Fnd_File.put_line(Fnd_File.output, 'There has been no new CAN files from American Express in the last ' ||l_day_counter ||' days.');
            Fnd_File.put_line(Fnd_File.output, 'Process Completed.');
            Fnd_File.put_line(Fnd_File.log, ' ' );

        ELSE /** A new file has been loaded **/

            l_email_subj := 'CAN Am Ex Files: '||p_filename||' for Dates: ' ||TO_CHAR(TO_DATE(c_start_date, 'YYYYMMDD'), 'DD-MON-YYYY')
                          ||' Through '|| TO_CHAR(TO_DATE(c_end_date, 'YYYYMMDD'), 'DD-MON-YYYY');
            l_email_body1 := 'Data received from American Express. The CAN files: '||p_filename||' have been loaded into Production On ';
            l_email_body3 := 'Check Oracle Log file for Status of load. ' ;
            l_email_body4 := 'If you have any questions, please contact the ERP Development Team.';

            /** Insert dates into log table **/
            INSERT INTO 	--cust.ap_amex_processed_dates--Commented code by MXKEERTHI-ARGANO,07/17/2023
	                          apps.ap_amex_processed_dates  --code added by MXKEERTHI-ARGANO, 07/17/2023 
            VALUES (c_start_date, SYSDATE);

            COMMIT;

            Fnd_File.put_line(Fnd_File.output, ' ' );
            Fnd_File.put_line(Fnd_File.output, 'Email sent successfully to list' ||email_TO_list ||' and CC to '||l_email_cc );
            Fnd_File.put_line(Fnd_File.output, ' ' );
            Fnd_File.put_line(Fnd_File.output, 'Process Completed Successfully');
            Fnd_File.put_line(Fnd_File.log, ' ' );

        END IF;

      END IF;

        /** Send e-mail **/
        send_email(ttec_library.XX_TTEC_SMTP_SERVER/*l_host_name*/ --Rehosting changes
                      ,l_email_from
                      ,email_TO_list
                      ,l_email_cc
                      ,NULL
                      ,l_email_subj
                      ,crlf
                      || l_email_body1
                      || l_email_body2|| crlf
                      || l_email_body3|| crlf
                      || crlf
                      || l_email_body4 || crlf
                      ,l_body
                      ,NULL
                      ,NULL
                      ,NULL
                      ,NULL
                      ,NULL
                      ,NULL
                      ,NULL
                      ,NULL
                      ,p_status
                      ,w_mesg
                      );

        EXCEPTION

        WHEN OTHERS
        THEN

            Fnd_File.put_line(Fnd_File.log, ' ');
            Fnd_File.put_line(Fnd_File.log, 'Email process failed ' );
            Fnd_File.put_line(Fnd_File.log, ' ');
            Fnd_File.put_line(Fnd_File.log, 'Program Failed With Error' ||to_char( SQLCODE) || SQLERRM);
    END;

END TTEC_AP_AMEX_NOTICE;
/
show errors;
/