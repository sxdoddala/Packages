create or replace PACKAGE BODY TTEC_TALEO_EMAIL_SUCCESS AS
--
-- Program Name:  TTTEC_TALEO_EMAIL_SUCCESS_PKG
--
-- Description:  send emails of SUCCESS hires
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
-- Version   Developer        Date           Description
-- -------   ----------       -----------    --------------------------------------------------------------------
-- 1.2      Christiane Chan   Jan-19-2012    R12 Upgrade- QC Defect #888 - Notification emails not being sent when running the Taleo inbound process
-- 1.3      Lalitha            Aug-21-2015   rehosting changes for smtp server
--1.0	IXPRAVEEN(ARGANO)  18-july-2023		R12.2 Upgrade Remediation
PROCEDURE email_success (errcode varchar2, errbuff varchar) IS

   v_file_handle     UTL_FILE.file_type;
-- Declare variables
   p_status          NUMBER;
   l_body            VARCHAR2 (8000);
   crlf              CHAR (2)                          := CHR (10) || CHR (13);
   cr                CHAR (2)                          := CHR (13);
   l_rec_num         VARCHAR2 (64);
   l_tot_rec_count   NUMBER := 0;
   l_cand_id         NUMBER := 0;
   l_new_line        VARCHAR2 (8)                       := '  ';
   l_date_stamp      VARCHAR2 (64);
   l_hire_name       VARCHAR2 (256);
   l_email_from      VARCHAR2 (256):= 'hirepointsupport@teletech.com';
   l_email_to        VARCHAR2 (256) := NULL;
   l_email_dir       VARCHAR2 (256)                     := NULL;
   l_email_subj      VARCHAR2 (256)
                                  := 'Successful new hire import '|| TO_CHAR (SYSDATE, 'MM/DD/YYYY HH24:MM');
   l_email_body1     VARCHAR2 (256)
      := 'Listed below please find a listing of all candidates processed in the Taleo to Oracle new hire integration run on  ';
   l_email_body2     VARCHAR2 (256) :=  TO_CHAR (SYSDATE, 'MM/DD/YYYY HH24:MM' ||'.');
   l_email_body3     VARCHAR2 (256)
      := '' ; -- . The attached listing will provide you with specific information about the error and a course of action for correction.';
   l_email_body4     VARCHAR2 (256)
      := 'If you have any questions, please contact the HirePoint technology team.';
-- set directory destination for output file
   l_host_name       VARCHAR2 (256);

   CURSOR c_host
   IS
      SELECT host_name    /* 1.2  it was limited to 10 characters removed */
        FROM v$instance;

-- get Am Ex setup data
   --xsel              cust.ttec_error_handling%ROWTYPE;		 -- Commented code by IXPRAVEEN-ARGANO,18-july-2023
   xsel              apps.ttec_error_handling%ROWTYPE;           --  code Added by IXPRAVEEN-ARGANO,   18-july-2023
   w_mesg            VARCHAR2 (256);
   rec_email         VARCHAR2 (256);
   l_email_to_send   NUMBER;

   CURSOR c_suc_msg
   IS
      SELECT   cand_id,
               lastname || ', ' || firstname || ', ' || mid hire_name,
               recruiterowneremployeeid rec_num, recruter_emailaddress, employee_number
          --FROM cust.ttec_taleo_stage			 -- Commented code by IXPRAVEEN-ARGANO,18-july-2023
          FROM apps.ttec_taleo_stage             --  code Added by IXPRAVEEN-ARGANO,   18-july-2023
         WHERE emp_val_err = 0 AND oracle_load_sucess = 1 AND email_sent = 0
      GROUP BY recruiterowneremployeeid,
               recruter_emailaddress,
               cand_id,
               lastname || ', ' || firstname || ', ' || mid,
               employee_number
      ORDER BY cand_id;
BEGIN
   --  l_date_stamp := TO_CHAR (SYSDATE, 'MMDDYYYY_HH24MM');
   OPEN c_host;

   FETCH c_host
    INTO l_host_name;

   CLOSE c_host;
     Fnd_File.put_line(Fnd_File.output, ' ' );
     Fnd_File.put_line(Fnd_File.log, ' ');
     Fnd_File.put_line(Fnd_File.output, 'Processing Emails for Hires that have Successful Validation - Program run date: ' ||  TO_CHAR (SYSDATE, 'MM/DD/YYYY HH24:MM') );
     Fnd_File.put_line(Fnd_File.log, 'Processing Emails for Hires that that have Successful Validation - Program run date: ' ||  TO_CHAR (SYSDATE, 'MM/DD/YYYY HH24:MM') );
     l_email_to := l_email_from;

   l_rec_num := 'X';
   l_email_to_send := 0;
   l_body := NULL;

	 DBMS_OUTPUT.put_line ('Processing Successful Hires Email ' );

   l_tot_rec_count   := 0;

   FOR sel IN c_suc_msg
   LOOP


      IF l_rec_num != to_char(sel.rec_num)
      THEN                                          -- new record open a file
         IF l_email_to_send = 1
         THEN
            send_email
               (ttec_library.XX_TTEC_SMTP_SERVER, /*Rehosting changes for smtp server */
			    --l_host_name,
                l_email_from,
                l_email_to,
                NULL,
                NULL,
                l_email_subj ,                     -- v_subject,
                   crlf
                || l_email_body1
                || l_email_body2
                || l_email_body3
                || crlf
                || l_email_body4 || crlf
                ,         -- NULL, --                        v_line1,
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
         END IF;

         l_email_to_send := 1;
         l_rec_num := to_char(sel.rec_num);
      END IF;
      l_email_to := NVL(sel.recruter_emailaddress, l_email_from);
     -- DBMS_OUTPUT.put_line ('Total Records Processed  ' || l_email_to);
     --  l_email_to:='Wasimm@teletech.com';
      l_hire_name := sel.hire_name;
      l_cand_id := sel.cand_id;
      l_body := l_body || 'Candidate ID: ' || to_char(sel.cand_id)|| ' Name: ' || sel.hire_name ||' (Oracle #:' ||sel.employee_number||')'|| crlf ;


     -- UPDATE cust.ttec_taleo_stage			 -- Commented code by IXPRAVEEN-ARGANO,18-july-2023
      UPDATE apps.ttec_taleo_stage               --  code Added by IXPRAVEEN-ARGANO,   18-july-2023
         SET email_sent = 1
       WHERE cand_id = sel.cand_id;

	     Fnd_File.put_line(Fnd_File.output, 'Sent Email for Candidate ' || to_char(sel.cand_id)||' Hire Name: ' ||l_hire_name|| ' To Recruiter Email Address: '||l_email_to );
       l_tot_rec_count := l_tot_rec_count + 1;
        commit;
   END LOOP;


    send_email  (ttec_library.XX_TTEC_SMTP_SERVER, /* rehosting changes for smtp */
	            --l_host_name,
                l_email_from,
                l_email_to,
                NULL,
                NULL,
                l_email_subj ,                     -- v_subject,
                   crlf
                || l_email_body1
                || l_email_body2
                || l_email_body3
                || crlf
                || l_email_body4 || crlf
                ,         -- NULL, --                        v_line1,
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

				UPDATE cust.ttec_taleo_stage
        SET email_sent = 1
        WHERE cand_id = l_cand_id;

   COMMIT;
    IF l_tot_rec_count > 0 THEN
          Fnd_File.put_line(Fnd_File.output, 'Sent Email for Candidate ' || TO_CHAR(l_cand_id)||' Hire Name: ' ||l_hire_name|| ' To Recruiter Email Address: '||l_email_to );
     END IF;
     Fnd_File.put_line(Fnd_File.output, ' ' );
     Fnd_File.put_line(Fnd_File.output, 'Total Records Processed  ' || TO_CHAR(l_tot_rec_count));
     Fnd_File.put_line(Fnd_File.output, ' ' );
     Fnd_File.put_line(Fnd_File.output,    'Process Completed Successfully'); --  l_tot_rec_count
     Fnd_File.put_line(Fnd_File.log, ' ' );
     Fnd_File.put_line(Fnd_File.log, 'Total Records Processed  ' || TO_CHAR(l_tot_rec_count));
     Fnd_File.put_line(Fnd_File.log, ' ' );
     Fnd_File.put_line(Fnd_File.log,    'Process Completed Successfully'); --  l_tot_rec_count
EXCEPTION
   WHEN OTHERS
   THEN
       Fnd_File.put_line(Fnd_File.log, ' ');
      Fnd_File.put_line(Fnd_File.log,'Total Records Processed  ' || TO_CHAR(l_tot_rec_count));
      Fnd_File.put_line(Fnd_File.log, ' ');
      Fnd_File.put_line(Fnd_File.log, 'Program Failed With Error' ||to_char( SQLCODE) || SQLERRM);
END;

END TTEC_TALEO_EMAIL_SUCCESS;
/
show errors;
/