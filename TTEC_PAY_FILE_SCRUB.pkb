create or replace PACKAGE BODY ttec_pay_file_scrub
/* $Header: APPS.ttec_pay_file_scrub.pkb 1.1 2007/08/01 wgmanafi ship $ */

  /*== START ================================================================================================*\
     Author: Wasim Manasfi
       Date: August 19, 2007
       Desc: Scrub Oracle Pay file to remove non English ASCII7 characters
       Input/Output Parameters:

    Modification History:

   Version    Date     Author   Description (Include Ticket#)
   -------  --------  --------  ------------------------------------------------------------------------------
       1.0  11/07/12  CHCHAN    R12 Retrofit: Modified the CSF to get the proper R12 Directory Path
	   2.0  08/21/15  Lalitha   Rehosting project smtp server change
  \*== END ==================================================================================================*/
AS
   FUNCTION check_is_asci7 (iv_text IN VARCHAR2)
      RETURN NUMBER
   IS
      v_number     VARCHAR2 (255);
      v_length     NUMBER;
      i            NUMBER;
      l_stat       NUMBER         := 0;
      l_asci_num   NUMBER         := 0;
   BEGIN
      v_length := LENGTH (iv_text);

      IF v_length > 0
      THEN
         -- look at each character in text and remove any ascii
         FOR i IN 1 .. v_length
         LOOP
            l_asci_num := ASCII (SUBSTR (iv_text, i, 1));

            IF l_asci_num < 32 OR l_asci_num > 125
            THEN
               l_stat := 1;
            END IF;
         END LOOP;                                                        -- i
      END IF;                                                      -- v_length

      RETURN l_stat;
   EXCEPTION
      WHEN OTHERS
      THEN
         RETURN l_stat;
   END;                                                            -- function

   PROCEDURE main (
      errcode              VARCHAR2,
      errbuff              VARCHAR,
      in_file         IN   VARCHAR2,
      email_to_list   IN   VARCHAR2,
      email_cc_list   IN   VARCHAR2
   )
   IS
      v_file_handle     UTL_FILE.file_type;
      v_out_file        UTL_FILE.file_type;
      v_request_id      NUMBER;
-- Declare variables
      p_status          NUMBER;
      l_body            VARCHAR2 (8000);
      crlf              CHAR (2)                       := CHR (10)
                                                          || CHR (13);
      cr                CHAR (2)                           := CHR (13);
      l_rec_num         VARCHAR2 (64);
      l_tot_rec_count   NUMBER                             := 0;
      l_text            VARCHAR2 (32767);
      l_text_out        VARCHAR2 (256);
      l_text_temp       VARCHAR2 (256);
      l_text_temp2      VARCHAR2 (256);
      l_text_temp3      VARCHAR2 (256);
      l_len             NUMBER                             := 0;
      p_filename        VARCHAR2 (256)                     := 'ge1500.dat';
      p_filename_out    VARCHAR2 (256)                     := 'ge1500_2.dat';
      l_date_stamp      VARCHAR2 (64);
      l_email_from      VARCHAR2 (256)      := 'EBS_Development@Teletech.com';
      l_email_to        VARCHAR2 (256)                     := NULL;
      l_dir1            VARCHAR2 (256)                     := NULL;
      l_dir2            VARCHAR2 (256)
                          := APPS.ttec_library.get_applcsf_dir('out'); /* 1.0 */
      l_dir             VARCHAR2 (256)                     := NULL;
      l_line_num        NUMBER                             := 0;
      l_email_subj      VARCHAR2 (256);
      l_email_body1     VARCHAR2 (256)
                      := 'TeleTech Pay File Audit for Latin Chars ';
      l_email_body2     VARCHAR2 (256)
                            := TO_CHAR (SYSDATE, 'MM/DD/YYYY HH24:MM' || '.');
      l_email_body3     VARCHAR2 (256);
      l_email_body4     VARCHAR2 (256)
         := 'If you have any questions, please contact the Payroll Department.';
      l_prcs_fail1      VARCHAR2 (256)
         := '* * * WARNING - Record contains non ASCII 7 characters or not correct length. Edit Record for employee: ';
      l_prcs_fail2      VARCHAR2 (256)
                        := '* * * WARNING - Error in record on line number: ';
      l_prcs_pass       VARCHAR2 (256)
         := 'TeleTech Pay File Audit for Latin Charss - All Records passed Audit - Success';
-- set directory destination for output file
      l_host_name       VARCHAR2 (256);
      c_start_date      VARCHAR (64);
      c_end_date        VARCHAR2 (64);
      l_subj            VARCHAR2 (64) := NULL;
      c_process         NUMBER                             := 0;
      l_num_faild       NUMBER                             := 0;

      -- flag for successful process

      -- get the request ID of the previous progran
      CURSOR c_request
      IS
         SELECT MAX (request_id)
           FROM fnd_concurrent_requests
          WHERE has_sub_request = 'N'
            AND priority_request_id =
                              (SELECT priority_request_id
                                 FROM fnd_concurrent_requests
                                WHERE request_id = fnd_global.conc_request_id)
            AND request_id != fnd_global.conc_request_id;

      -- get host ID
      CURSOR c_host
      IS
         SELECT SUBSTR (host_name, 1, 10)
           FROM v$instance;

      -- get directory path
      CURSOR c_directory_path
      IS
         SELECT ttec_library.get_directory('CUST_TOP')||'/data/temp' directory_path /* 1.0 */
           FROM dual;

-- get Am Ex setup data
      xsel              cust.ttec_error_handling%ROWTYPE;
      w_mesg            VARCHAR2 (256);
      rec_email         VARCHAR2 (256);
      l_email_to_send   NUMBER;
      l_stat            NUMBER;
      l_chk1            NUMBER                             := 0;
      l_chk2            NUMBER                             := 0;
      l_chk3            NUMBER                             := 0;
      l_chk4            NUMBER                             := 0;
      l_chk5            NUMBER                             := 0;
      l_chk6            NUMBER                             := 0;
   BEGIN
      --  l_date_stamp := TO_CHAR (SYSDATE, 'MMDDYYYY_HH24MM');
      OPEN c_host;

      FETCH c_host
       INTO l_host_name;

      CLOSE c_host;

      -- Fnd_File.put_line(Fnd_File.LOG, '1');
      OPEN c_directory_path;

/*
      FETCH c_directory_path
       INTO l_dir1;

      CLOSE c_directory_path;
*/
      OPEN c_request;

      FETCH c_request
       INTO v_request_id;

      CLOSE c_request;

      l_dir := l_dir2 || '/';
      fnd_file.put_line (fnd_file.output, ' ');
      fnd_file.put_line (fnd_file.LOG, ' ');
      fnd_file.put_line
         (fnd_file.output,
             'Processing TeleTech Pay File Audit for Latin Chars - Program run date: '
          || TO_CHAR (SYSDATE, 'MM/DD/YYYY HH24:MM')
         );
      fnd_file.put_line
          (fnd_file.LOG,
              'Processing TeleTech Pay File Audit for Latin Chars - Program run date: '
           || TO_CHAR (SYSDATE, 'MM/DD/YYYY HH24:MM')
          );
      l_email_to := l_email_from;
      l_email_subj :=
            'TeleTech Pay File Audit for Latin Chars -'
         || TO_CHAR (SYSDATE, 'DD/MON/YYYY');
      l_body := NULL;
      l_tot_rec_count := 0;

      -- l_dir1 was used for testing only
      IF in_file IS NULL
      THEN
         p_filename := 'p' || TO_CHAR (v_request_id) || '.mf';  --pXXXXXXX.mf
         l_dir := l_dir2 || '/';
      ELSE
         p_filename := in_file;
         l_dir := l_dir2 || '/';
      END IF;

      p_filename_out := p_filename || 'tt';
      fnd_file.put_line
           (fnd_file.output,
               'Processing TeleTech Pay File Audit for Latin Chars - Input File Name: '
            || p_filename
            || ' - Output File Name: '
            || l_dir
            || p_filename_out
           );
      fnd_file.put_line
           (fnd_file.LOG,
               'Processing TeleTech Pay File Audit for Latin Chars - Input File Name  '
            || p_filename
            || ' - Output File Name: '
            || l_dir
            || p_filename_out
           );
      -- open the files
      fnd_file.put_line (fnd_file.LOG,
                            'Opening file for reading - input file '
                         || l_dir
                         || p_filename
                        );
      v_file_handle := UTL_FILE.fopen (l_dir, p_filename, 'r', 32767);
      fnd_file.put_line (fnd_file.LOG,
                         'Success - Opening file ' || l_dir || p_filename
                        );
      fnd_file.put_line (fnd_file.LOG,
                            'Opening file for writing -  file '
                         || l_dir
                         || p_filename_out
                        );
      --  v_out_file := UTL_FILE.fopen (l_dir, p_filename_out, 'w');
      fnd_file.put_line (fnd_file.LOG,
                         'Success - Opening file ' || l_dir || p_filename_out
                        );
      fnd_file.new_line (fnd_file.output);
      fnd_file.put_line (fnd_file.output,
                         'List of records that should be CORRECTED before being SENT to BANK - Please review '
                        );
      fnd_file.put_line (fnd_file.output,
                         '------------------------------------------------------------------------------------'
                        );
      l_line_num := 0;

      BEGIN
         LOOP
            l_chk1 := 0;
            l_chk2 := 0;
            l_chk3 := 0;
            l_chk4 := 0;
            l_chk5 := 0;
            l_chk6 := 0;
            l_text_out := NULL;

            UTL_FILE.get_line (v_file_handle, l_text, 32767);
            l_text_temp := l_text;
            l_line_num := l_line_num + 1;
            -- check how many characters we are getting
            l_len := LENGTH (l_text);

            l_text_temp2 :=
                  SUBSTR (l_text_temp, 1, 54)
               || TRANSLATE
                          (SUBSTR (l_text_temp, 55, 22),
                            'àáâãèëéêìîíòôóùûúüÀÁÂÃÈÉÊËÌÎÍÒÔÓÙÛÚÜçÇõÕöÖÑñ¿ºª"',
                            'aaaaeeeeiiiooouuuuAAAAEEEEIIIOOOUUUUcCoOoONn oa '
                          )
               || SUBSTR (l_text_temp, 77, 50);

             IF l_text_temp2 != l_text_temp THEN
             l_chk6 := 1;
             END IF;
             l_chk4 := check_is_asci7 (SUBSTR (l_text, 55, 22));

            -- use convert to throw off inverse ? for any character that does not translate to ASCII7
            -- this is stricktest measure
            l_text_out :=
                  SUBSTR (l_text_temp, 1, 54)
               || CONVERT (SUBSTR (l_text_temp, 55, 22),
                           'WE8MSWIN1252',
                           'UTF8'
                          )
               || SUBSTR (l_text_temp, 77, 50);                  -- l_line_num
            -- now see if there is any inverted ?, indicating any non asciii 7
            l_chk1 := instrc (SUBSTR (l_text_out, 55, 22), '¿', 1);
            l_chk5 := instrc (SUBSTR (l_text_out, 55, 22), '?', 1);
            fnd_file.put_line (fnd_file.LOG, l_text_out);

            IF l_len != 94
            THEN
               l_chk2 := 1;
            END IF;

            l_len := LENGTH (l_text_out);

            IF l_len != 94
            THEN
               l_chk3 := 1;
            END IF;

            fnd_file.put_line (fnd_file.LOG,
                                  'status of run l_chk1 '
                               || TO_CHAR (l_chk1)
                               || 'l_chk2'
                               || TO_CHAR (l_chk2)
                               || 'length'
                               || l_len
                              );

            IF (l_chk1 != 0 OR l_chk2 != 0 OR l_chk3 != 0 OR l_chk4 != 0 OR l_chk5 !=0 OR l_chk6 !=0)
            THEN
               l_num_faild := l_num_faild + 1;
               fnd_file.put_line (fnd_file.output,
                                  l_prcs_fail2 || TO_CHAR (l_line_num)
                                 );
               fnd_file.put_line (fnd_file.output,
                                  l_prcs_fail1 || SUBSTR (l_text_temp, 55, 22)
                                 );
               l_stat := 1;
               l_subj:= '* * * ERROR * * *  ';
            END IF;
         END LOOP;
      EXCEPTION
         WHEN NO_DATA_FOUND
         THEN
            NULL;
         WHEN OTHERS
         THEN
            c_process := 1;
      END;

      UTL_FILE.fclose (v_file_handle);

      --  UTL_FILE.fclose (v_out_file);

      --   l_email_from := 'WasimM@Teletech.com';
      -- l_email_to := 'WasimM@Teletech.com, Christiane.chan@teletech.com';
      IF l_stat != 0
      THEN
         l_email_body3 :=
               'Total Records WITH ERROR detected '
            || TO_CHAR (l_num_faild)
            || '- Check log file for TeleTech Pay File Audit for Latin Chars Program for list';
      ELSE
         l_email_body3 := l_prcs_pass;
      END IF;

      send_email (ttec_library.XX_TTEC_SMTP_SERVER, /* Rehosting project change for smtp */
	              --l_host_name,
                  l_email_from,
                  email_to_list,
                  email_cc_list,
                  NULL,
                  l_subj||l_email_subj,                                  -- v_subject,
                     crlf
                  || l_email_body1
                  || l_email_body2
                  || l_email_body3
                  || crlf
                  || l_email_body4
                  || crlf,         -- NULL, --                        v_line1,
                  l_body,
                  NULL,
                  NULL,
                  NULL,
                  NULL,
                  -- file_to_send,                                 -- v_file_name,
                  NULL,
                  NULL,
                  NULL,
                  NULL,
                  p_status,
                  w_mesg
                 );
      l_body := NULL;
      fnd_file.put_line (fnd_file.LOG, ' ');
      fnd_file.put_line (fnd_file.LOG,
                            'Email sent successfully to list'
                         || email_to_list
                         || ' and CC to '
                         || email_cc_list
                        );
      fnd_file.put_line (fnd_file.LOG, ' ');
      fnd_file.put_line (fnd_file.LOG, 'Process Completed Successfully');
      --  l_tot_rec_count
      fnd_file.put_line (fnd_file.LOG, ' ');
   EXCEPTION
      WHEN OTHERS
      THEN
         fnd_file.put_line (fnd_file.LOG, ' ');
         fnd_file.put_line
            (fnd_file.LOG,
             'Error in processing TeleTech Pay File Audit for Latin Chars Make sure file named exists'
            );
         fnd_file.put_line
            (fnd_file.output,
             'Error in processing TeleTech Pay File Audit for Latin Chars. Make sure file named exists'
            );
         fnd_file.put_line (fnd_file.LOG, ' ');
         fnd_file.put_line (fnd_file.LOG,
                               'Program Failed With Error'
                            || TO_CHAR (SQLCODE)
                            || SQLERRM
                           );
   END;
END ttec_pay_file_scrub;