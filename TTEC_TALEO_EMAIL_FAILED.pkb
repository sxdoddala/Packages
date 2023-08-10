create or replace PACKAGE BODY TTEC_TALEO_EMAIL_FAILED
AS
--
-- Program Name:  TTTEC_TALEO_EMAIL_FAILED_PKG
--
-- Description:  send emails of failed hires
-- Input/Output Parameters:
--
--
--
-- Tables Modified:  N/A
--
--
-- Created By:  Wasim Manasfi
-- Date: March 23, 2007
--
-- Modification Log:
-- Developer        Date        Description
-- ----------       --------    --------------------------------------------------------------------
-- 1.1  Wasim Manasfi Added generic routine to get CUST_TOP directory
-- 1.2  Christiane Chan R12 Upgrade- QC Defect #888 - Notification emails not being sent when running the Taleo inbound process
-- 1.3  Lalitha       rehosting changes for smtp
   PROCEDURE email_failed (errcode VARCHAR2, errbuff VARCHAR)
   IS
      p_filedir                   VARCHAR2 (200);
      p_filename                  VARCHAR2 (50);
      p_country                   VARCHAR2 (10);
      v_file_handle               UTL_FILE.file_type;
      -- Declare variables
      l_msg                       VARCHAR2 (2000);
      l_stage                     VARCHAR2 (400);
      l_element                   VARCHAR2 (400);
      l_rec                       VARCHAR2 (8000);
      l_key                       VARCHAR2 (400);
      l_test_indicator            VARCHAR2 (4) := '  ';
      l_bank_account              VARCHAR2 (100);
      l_file_num                  VARCHAR2 (4) := '01';
      -- raw_att                     RAW (32)       := HEXTORAW ('616262646566C2AA');
      -- vcr_att                     VARCHAR2 (255)   := 'This is a sample of a VARCHAR2 attachment!';
      p_status                    NUMBER;
      l_rec2                      VARCHAR2 (2000);
      crlf                        CHAR (2) := CHR (10) || CHR (13);
      l_tot_rec_count             NUMBER;
      l_sum_pos_pay_amount        NUMBER;
      l_check_number_hash_total   NUMBER;
      l_seq                       NUMBER;
      l_file_seq                  NUMBER;
      l_next_file_seq             NUMBER;
      l_test_flag                 VARCHAR2 (4);
      l_new_space                 VARCHAR2 (8) := '  ';
      l_date_stamp                VARCHAR2 (64);
      l_hire_name                 VARCHAR2 (256);
      l_email_from                VARCHAR2 (256)
                                     := 'hirepointsupport@teletech.com';
      l_email_to                  VARCHAR2 (256) := NULL;
      l_email_dir                 VARCHAR2 (256) := NULL;
      l_email_subj                VARCHAR2 (256)
         := 'Notice of new hire record failure for ';
      l_email_body1               VARCHAR2 (256)
         := 'Attached please find a listing of all errors encountered when attempting to import ';
      l_email_body2               VARCHAR2 (256)
         := ' into Oracle on ' || TO_CHAR (SYSDATE, 'MM/DD/YYYY HH24:MM');
      l_email_body3               VARCHAR2 (256)
         := '. The attached listing will provide you with specific information about the error and a course of action for correction.';
      l_email_body4               VARCHAR2 (256)
         := 'If you have any questions, please contact the HirePoint technology team.';

      -- set directory destination for output file
      CURSOR c_directory_path
      IS
         SELECT    ttec_library.get_directory('CUST_TOP')||'/data/Taleo_Email/' /* 1.2 Removed the hard code path /d01 */
                   directory_path
           FROM v$database;

      l_host_name                 VARCHAR2 (256);

      CURSOR c_host
      IS
         SELECT host_name FROM v$instance; /* 1.2  it was limited to 10 characters removed */

      --
      xsel                        cust.ttec_error_handling%ROWTYPE;
      file_to_send                VARCHAR2 (256);
      w_mesg                      VARCHAR2 (256);
      cand_num                    VARCHAR2 (64);
      fileisopen                  NUMBER;
      l_recruiter_written         NUMBER := 0;

      CURSOR c_err_msg
      IS
           SELECT DISTINCT
                  fnm.message_name,
                  fnm.MESSAGE_TEXT,
                  teh.module_name,
                  teh.status,
                  teh.ERROR_CODE,
                  teh.error_message,
                  teh.label1,
                  teh.reference1,
                  teh.label2,
                  teh.reference2,
                  teh.label3,
                  teh.reference3,
                  teh.label4,
                  teh.reference4,
                  teh.label5,
                  teh.reference5,
                  teh.label6,
                  teh.reference6,
                  teh.label7,
                  teh.reference7,
                  teh.label8,
                  teh.reference8,
                  teh.label9,
                  teh.reference9,
                  teh.label10,
                  teh.reference10,
                  teh.label11,
                  teh.reference11,
                  teh.label12,
                  teh.reference12,
                  teh.label13,
                  teh.reference13,
                  teh.label14,
                  teh.reference14,
                  teh.label15,
                  teh.reference15,                       -- teh.creation_date,
                     tts.lastname
                  || ', '
                  || tts.firstname
                  || ' '
                  || tts.mid
                  || '.'
                     hire_name,
                  tts.recruter_emailaddress rec_email
             FROM cust.ttec_error_handling teh,
                  apps.fnd_new_messages fnm,
                  cust.ttec_taleo_stage tts
            WHERE     SUBSTR (teh.program_name, 1, 10) = 'Ttec_Taleo'
                 AND (teh.creation_date > SYSDATE - .040) -- within last hour
                  AND fnm.message_name(+) = teh.label14
                  AND tts.cand_id = TO_NUMBER (teh.reference1)
                  AND tts.email_sent = 0                        -- CHANGE TO 0
                  AND (tts.emp_val_err = 1 OR tts.oracle_load_sucess = -1) -- -1 failed in load
         GROUP BY teh.reference1,
                  fnm.message_name,
                  fnm.MESSAGE_TEXT,
                  teh.creation_date,
                  teh.label2,
                  teh.module_name,
                  teh.status,
                  teh.ERROR_CODE,
                  teh.error_message,
                  teh.label1,
                  teh.reference2,
                  teh.label3,
                  teh.reference3,
                  teh.label4,
                  teh.reference4,
                  teh.label5,
                  teh.reference5,
                  teh.label6,
                  teh.reference6,
                  teh.label7,
                  teh.reference7,
                  teh.label8,
                  teh.reference8,
                  teh.label9,
                  teh.reference9,
                  teh.label10,
                  teh.reference10,
                  teh.label11,
                  teh.reference11,
                  teh.label12,
                  teh.reference12,
                  teh.label13,
                  teh.reference13,
                  teh.label14,
                  teh.reference14,
                  teh.label15,
                  teh.reference15,
                     tts.lastname
                  || ', '
                  || tts.firstname
                  || ' '
                  || tts.mid
                  || '.',
                  tts.recruter_emailaddress
         ORDER BY teh.REFERENCE1;
   BEGIN
      l_date_stamp := TO_CHAR (SYSDATE, 'MMDDYYYY_HH24MM');
      l_stage := 'c_directory_path';

      -- Fnd_File.put_line(Fnd_File.LOG, '1');
      -- OPEN c_directory_path;

      --FETCH c_directory_path
      --INTO l_email_dir;

      --CLOSE c_directory_path;

      OPEN c_host;

      FETCH c_host INTO l_host_name;

      CLOSE c_host;

      l_email_dir := TTEC_LIBRARY.GET_DIRECTORY ('CUST_TOP'); -- 1.1
      l_email_dir := l_email_dir || '/data/Taleo_Email/';

      Fnd_File.put_line (Fnd_File.output, ' ');
      Fnd_File.put_line (Fnd_File.LOG, ' ');
      Fnd_File.put_line (
         Fnd_File.output,
         'Processing Emails for Hires that Failed Validation - Program run date: '
         || TO_CHAR (SYSDATE, 'MM/DD/YYYY HH24:MM'));
      Fnd_File.put_line (
         Fnd_File.LOG,
         'Processing Emails for Hires that Failed Validation - Program run date: '
         || TO_CHAR (SYSDATE, 'MM/DD/YYYY HH24:MM'));
      cand_num := '1';
      fileisopen := 0;
      l_tot_rec_count := 0;
      l_recruiter_written := 0;

      FOR sel IN c_err_msg
      LOOP
         BEGIN
            --   Fnd_File.put_line(Fnd_File.log, 'if diff candidate  '||cand_num|| 'Ref1 '||sel.reference1);
            --   Fnd_File.put_line(Fnd_File.output, 'if diff  candidate  '||cand_num||'Ref1 '||sel.reference1);
            IF cand_num != sel.reference1
            THEN                                     -- new record open a file
               IF fileisopen = 1
               THEN
                  --Fnd_File.put_line(Fnd_File.output, 'closing file for candidate  '||cand_num);
                  --Fnd_File.put_line(Fnd_File.log, 'closing file for candidate  '||cand_num);
                  UTL_FILE.fclose (v_file_handle);
                  fileisopen := 0;
                  l_recruiter_written := 0;
                  file_to_send := l_email_dir || p_filename;
                  Fnd_File.put_line (
                     Fnd_File.output,
                        'Sent Email for Candidate '
                     || cand_num
                     || ' Hire Name: '
                     || l_hire_name
                     || ' To Recruiter Email Address: '
                     || l_email_to);
                  send_email (
                     ttec_library.XX_TTEC_SMTP_SERVER, /* rehosting changes for smtp */
					 --l_host_name,
                     l_email_from,
                     l_email_to,
                     NULL,
                     NULL,
                     l_email_subj || l_hire_name,                -- v_subject,
                        crlf
                     || l_email_body1
                     || l_hire_name
                     || l_email_body2
                     || l_email_body3
                     || crlf
                     || l_email_body4, -- NULL, --                        v_line1,
                     NULL,
                     NULL,
                     NULL,
                     NULL,
                     file_to_send,                             -- v_file_name,
                     NULL,
                     NULL,
                     NULL,
                     NULL,
                     p_status,
                     w_mesg);
                  fnd_file.put_line (fnd_file.LOG, 'Sent Email');
                  fnd_file.put_line (fnd_file.output, 'Sent Email');

                  --    dbms_output.put_line('to number '|| cand_num);
                  UPDATE cust.ttec_taleo_stage
                     SET email_sent = 1
                   WHERE cand_id = TO_NUMBER (cand_num);

                  COMMIT;
               END IF;

               l_email_to := sel.rec_email;
               l_hire_name := sel.hire_name;
               -- l_email_to := 'WasimM@teletech.com';  -- <<<<<<<<<<----------------------------
               p_filename :=
                  sel.reference1 || '_' || l_date_stamp || '.' || 'log';

               v_file_handle :=
                  UTL_FILE.fopen (l_email_dir,
                                  p_filename,
                                  'w',
                                  32767);
               fileisopen := 1;
               cand_num := sel.reference1;
            --  can_num := sel.label1;
            END IF;

            IF l_recruiter_written = 0
            THEN
               l_rec := ' ';
               UTL_FILE.put_line (v_file_handle, SUBSTR (l_rec, 1, 7000));
               l_rec :=
                  crlf
                  || '    Error Messages for hiring Candiadate Identified by number '
                  || sel.reference1
                  || ' Name: '
                  || l_hire_name
                  || crlf;

               UTL_FILE.put_line (v_file_handle, l_rec);

               IF ( (sel.label15 IS NOT NULL OR sel.reference15 IS NOT NULL))
               THEN
                  l_rec :=
                        '-- RECRUITER: '
                     || sel.label15
                     || ' Recruiter Email: '
                     || sel.reference15
                     || crlf;
                  UTL_FILE.put_line (v_file_handle, SUBSTR (l_rec, 1, 7000));

                  --         Fnd_File.put_line(Fnd_File.output, 'recruiter written '||cand_num);
                  --   Fnd_File.put_line(Fnd_File.log, 'recruiter written  '||cand_num);

                  l_recruiter_written := 1;
               END IF;
            END IF;                                    -- if recuriter written

            IF sel.message_name IS NOT NULL
            THEN
               -- l_rec := sel.message_name || '-' || sel.MESSAGE_TEXT || l_new_space;
               l_rec :=
                     '-- Validation Error -- '
                  || sel.message_name
                  || l_new_space
                  || sel.MESSAGE_TEXT
                  || l_new_space;
            ELSE
               l_rec :=
                  '-- API Error --  See Job Aid for Direction on Correcting the Issue --'
                  || l_new_space
                  || sel.ERROR_CODE
                  || '-'
                  || sel.error_message
                  || l_new_space;
            END IF;

            UTL_FILE.put_line (v_file_handle, SUBSTR (l_rec, 1, 7000));

            IF sel.label2 IS NOT NULL OR sel.reference2 IS NOT NULL
            THEN
               l_rec :=
                     'Field is: '
                  || sel.label2
                  || ' --      Field Content is:   '
                  || sel.reference2
                  || l_new_space;
               UTL_FILE.put_line (v_file_handle, SUBSTR (l_rec, 1, 7000));
            END IF;

            IF sel.label3 IS NOT NULL OR sel.reference3 IS NOT NULL
            THEN
               l_rec :=
                     'Field is: '
                  || sel.label3
                  || ' --      Field Content is:   '
                  || sel.reference3
                  || l_new_space;
               UTL_FILE.put_line (v_file_handle, SUBSTR (l_rec, 1, 7000));
            END IF;

            IF sel.label4 IS NOT NULL OR sel.reference4 IS NOT NULL
            THEN
               l_rec :=
                     'Field is: '
                  || sel.label4
                  || ' --      Field Content is:   '
                  || sel.reference4
                  || l_new_space;
               UTL_FILE.put_line (v_file_handle, SUBSTR (l_rec, 1, 7000));
            END IF;

            IF sel.label5 IS NOT NULL OR sel.reference5 IS NOT NULL
            THEN
               l_rec :=
                     'Field is: '
                  || sel.label5
                  || ' --      Field Content is:   '
                  || sel.reference5
                  || l_new_space;
               UTL_FILE.put_line (v_file_handle, SUBSTR (l_rec, 1, 7000));
            END IF;

            IF sel.label6 IS NOT NULL OR sel.reference6 IS NOT NULL
            THEN
               l_rec :=
                     'Field is: '
                  || sel.label6
                  || ' --      Field Content is:   '
                  || sel.reference6
                  || l_new_space;
               UTL_FILE.put_line (v_file_handle, SUBSTR (l_rec, 1, 7000));
            END IF;

            IF sel.label7 IS NOT NULL OR sel.reference7 IS NOT NULL
            THEN
               l_rec :=
                     'Field is: '
                  || sel.label7
                  || ' --      Field Content is:   '
                  || sel.reference7
                  || l_new_space;
               UTL_FILE.put_line (v_file_handle, SUBSTR (l_rec, 1, 7000));
            END IF;

            IF sel.label8 IS NOT NULL OR sel.reference8 IS NOT NULL
            THEN
               l_rec :=
                     'Field is: '
                  || sel.label8
                  || ' --      Field Content is:   '
                  || sel.reference8
                  || l_new_space;
               UTL_FILE.put_line (v_file_handle, SUBSTR (l_rec, 1, 7000));
            END IF;

            IF sel.label9 IS NOT NULL OR sel.reference9 IS NOT NULL
            THEN
               l_rec :=
                     'Field is: '
                  || sel.label9
                  || ' --      Field Content is:   '
                  || sel.reference9
                  || l_new_space;
               UTL_FILE.put_line (v_file_handle, SUBSTR (l_rec, 1, 7000));
            END IF;

            IF sel.label10 IS NOT NULL OR sel.reference10 IS NOT NULL
            THEN
               l_rec :=
                     'Field is: '
                  || sel.label10
                  || ' --      Field Content is:   '
                  || sel.reference10
                  || l_new_space;
               UTL_FILE.put_line (v_file_handle, SUBSTR (l_rec, 1, 7000));
            END IF;

            IF sel.label11 IS NOT NULL OR sel.reference11 IS NOT NULL
            THEN
               l_rec :=
                     'Field is: '
                  || sel.label11
                  || ' --      Field Content is:   '
                  || sel.reference11
                  || l_new_space;
               UTL_FILE.put_line (v_file_handle, SUBSTR (l_rec, 1, 7000));
            END IF;

            IF sel.label12 IS NOT NULL OR sel.reference12 IS NOT NULL
            THEN
               l_rec :=
                     'Field is: '
                  || sel.label12
                  || ' --      Field Content is:   '
                  || sel.reference12
                  || l_new_space;
               UTL_FILE.put_line (v_file_handle, SUBSTR (l_rec, 1, 7000));
            END IF;

            IF sel.label13 IS NOT NULL OR sel.reference13 IS NOT NULL
            THEN
               l_rec :=
                     'Field is: '
                  || sel.label13
                  || ' --      Field Content is:   '
                  || sel.reference13
                  || l_new_space;
               UTL_FILE.put_line (v_file_handle, SUBSTR (l_rec, 1, 7000));
            END IF;

            IF sel.label14 IS NOT NULL OR sel.reference14 IS NOT NULL
            THEN
               l_rec :=
                     'Field is: '
                  || 'Business Group ID :'
                  || sel.reference14
                  || l_new_space;
               UTL_FILE.put_line (v_file_handle, SUBSTR (l_rec, 1, 7000));
            END IF;

            l_tot_rec_count := l_tot_rec_count + 1;

            --         Fnd_File.put_line(Fnd_File.output, 'recruiter written '||cand_num||to_char(l_tot_rec_count));
            --   Fnd_File.put_line(Fnd_File.log, 'recruiter written  '||cand_num|| to_char(l_tot_rec_count));
            -- put flush to flush data to file to avoid errors
            UTL_FILE.FFLUSH (v_file_handle);
         EXCEPTION
            WHEN OTHERS
            THEN
               Fnd_File.put_line (
                  Fnd_File.output,
                  'Error in writing file for candidate  ' || cand_num);
               Fnd_File.put_line (
                  Fnd_File.LOG,
                  'Error in writing file for candidate  ' || cand_num);

               Fnd_File.put_line (Fnd_File.LOG, ' ');
               Fnd_File.put_line (
                  Fnd_File.output,
                     'Error Writing log file for  Candidate '
                  || cand_num
                  || ' Hire Name: '
                  || l_hire_name
                  || ' To Recruiter Email Address: '
                  || l_email_to);
         END;
      END LOOP;

      --   Fnd_File.put_line(Fnd_File.output, '222 closing  file for candidate  '||cand_num);
      --   Fnd_File.put_line(Fnd_File.log, '2222 closing file for candidate  '||cand_num);
      UTL_FILE.fclose (v_file_handle);
      fileisopen := 0;
      file_to_send := l_email_dir || p_filename;
      send_email (
         ttec_library.XX_TTEC_SMTP_SERVER, /* rehosting changes for smtp */
		 --l_host_name,
         l_email_from,
         l_email_to,
         NULL,
         NULL,
         l_email_subj || l_hire_name,                            -- v_subject,
            crlf
         || l_email_body1
         || l_hire_name
         || l_email_body2
         || l_email_body3
         || crlf
         || l_email_body4,
         -- NULL, --                        v_line1,                      v_line1,                       v_line1,
         NULL,
         NULL,
         NULL,
         NULL,
         file_to_send,                                         -- v_file_name,
         NULL,
         NULL,
         NULL,
         NULL,
         p_status,
         w_mesg);

      Fnd_File.put_line (Fnd_File.output, 'completed ' || cand_num);
      Fnd_File.put_line (Fnd_File.LOG, 'completed  ' || cand_num);

      UPDATE cust.ttec_taleo_stage
         SET email_sent = 1
       WHERE cand_id = TO_NUMBER (cand_num);

      IF l_tot_rec_count > 0
      THEN
         Fnd_File.put_line (
            Fnd_File.output,
               'Sent Email for Candidate '
            || cand_num
            || ' Hire Name: '
            || l_hire_name
            || ' To Recruiter Email Address: '
            || l_email_to);
      END IF;

      COMMIT;
      Fnd_File.put_line (Fnd_File.output, ' ');
      Fnd_File.put_line (
         Fnd_File.output,
         'Total Records Processed  ' || TO_CHAR (l_tot_rec_count));
      Fnd_File.put_line (Fnd_File.output, ' ');
      Fnd_File.put_line (Fnd_File.output, 'Process Completed Successfully'); --  l_tot_rec_count
      Fnd_File.put_line (Fnd_File.LOG, ' ');
      Fnd_File.put_line (
         Fnd_File.LOG,
         'Total Records Processed  ' || TO_CHAR (l_tot_rec_count));
      Fnd_File.put_line (Fnd_File.LOG, ' ');
      Fnd_File.put_line (Fnd_File.LOG, 'Process Completed Successfully'); --  l_tot_rec_count
   EXCEPTION
      WHEN OTHERS
      THEN
         Fnd_File.put_line (Fnd_File.LOG, ' ');
         Fnd_File.put_line (
            Fnd_File.LOG,
            'Total Records Processed  ' || TO_CHAR (l_tot_rec_count));
         Fnd_File.put_line (Fnd_File.LOG, ' ');
         Fnd_File.put_line (
            Fnd_File.LOG,
            'Program Failed With Error' || TO_CHAR (SQLCODE) || SQLERRM);
   END;
END TTEC_TALEO_EMAIL_FAILED;