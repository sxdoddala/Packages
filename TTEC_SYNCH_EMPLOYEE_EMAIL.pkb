create or replace PACKAGE BODY      ttec_synch_employee_email
AS
--************************************************************************************--
--*                                                                                  *--
--*     Program Name: ttec_synch_emplpoyee email                             *--
--*                                                                                  *--
--*     Description:  Update AP Vendor sites emails for employee-suppliers
--*                   and emails for employees in FND_USERS
--*                                                                                  *--
--*     Input/Output Parameters:                                                     *--
--*                                                                                  *--
--*     Tables Accessed:                                                             *--
--*                                                                                  *--
--*     Tables Modified:         po_vendor_sites_all, fnd_users
--*
--*     Procedures Called:                                                           *--
--*                                                                                  *--
--*                                                                                  *--
--*                                                                                  *--
--* C  reated By: Wasim Manasfi                                                         *--
--* Date: 04/12/2009                                                                  *--
--*
--*                                                                                  *--
--* Modification Log:                                                                 *--
--* Developer          Date        Description                                        *--
--* ---------          ----        -----------                                        *--
--* Wasim Manasfi   04/12/2009  Created                                               *--
--*                                                                                  *--
--*RXNETHI-ARGANO   18/MAY/2023 R12.2 Upgrade Remediation
--*                                                                                  *--
--************************************************************************************--

------------------------------------------------------------------------------------------------
-- print a line to the log
------------------------------------------------------------------------------------------------

   PROCEDURE print_line (p_data IN VARCHAR2)
   IS
   BEGIN
      fnd_file.put_line (fnd_file.LOG, p_data);
   END;

   PROCEDURE main (
      errcode                  VARCHAR2,
      errbuff                  VARCHAR2,
  --    p_m_setofbooks      IN   VARCHAR2,
   --   p_m_source          IN   VARCHAR2,
      p_m_email_to_list   IN   VARCHAR2
   )
   IS
      v_update_vendor_record       NUMBER;
      v_update_bank_account_uses   NUMBER;
      v_tmp1                       VARCHAR (250);
      v_tmp2                       VARCHAR (250);
      v_stat                       NUMBER:= 0;
      v_email_subj VARCHAR2(80) := 'Successful - Email Synch Program - '||TO_CHAR(SYSDATE, 'DD-MON-YYYY');
      v_failed_message VARCHAR2(80) := 'Error in Email Synch Program - ' ||TO_CHAR(SYSDATE, 'DD-MON-YYYY');
      v_email_body VARCHAR2(300) := 'Teletech - Synch Employee Emails - Vendor Site and FND User tables. Check log for Concurrent Request ID: ' ||  TO_CHAR( FND_GLOBAL.CONC_REQUEST_ID);
      v_error_stat NUMBER := 0;
   BEGIN
   BEGIN
      fnd_file.put_line
         (fnd_file.output,
             'Teletech - Synch Employee Emails - Vendor Site and FND User tables -  Report Date:'
          || SYSDATE
         );
      fnd_file.new_line (fnd_file.output, 2);
      v_tmp1 := 'Changing Email addresses for Suppliers. Change has been made for listed employees';
      print_line (v_tmp1);
      v_tmp1 := '---------------------------------------';
      print_line (v_tmp1);

      -- finance has end dates as null, does not put end of time in as end date for financials
      BEGIN
         FOR v_rec IN ttec_hr_vendor
         LOOP
            BEGIN
               v_tmp1 :=
                     'Changed Email Address for Vendor '
                  || v_rec.vendor_name
                  || ' Vendor ID: '
                  || TO_CHAR (v_rec.vendor_id)
                  || ' From: '
                  || v_rec.vendor_email
                  || ' To: '
                  || v_rec.hr_email;
               print_line (v_tmp1);

               UPDATE po_vendor_sites_all
                  SET email_address = v_rec.hr_email
                WHERE vendor_id = v_rec.vendor_id
                  AND vendor_site_id = v_rec.vendor_site_id;
            EXCEPTION
               WHEN OTHERS
               THEN
                  v_tmp1 :=
                        '* * * Error in Changing  Email Address for Vendors '
                     || v_rec.vendor_name
                     || ' Vendor ID: '
                     || TO_CHAR (v_rec.vendor_id)
                     || ' From: '
                     || v_rec.vendor_email
                     || ' To: '
                     || v_rec.hr_email;
                  print_line (v_tmp1);
                  v_email_subj  := v_failed_message;
            END;
         END LOOP;

         COMMIT;
      END;

      v_tmp2 := 'Changing Email addresses for users in FND_USER. Change has been made for listed employees';
      print_line (v_tmp2);
      v_tmp2 := '---------------------------------------';
      print_line (v_tmp2);

      BEGIN
         FOR v_rec2 IN ttec_hr_fnd
         LOOP
            BEGIN
               v_tmp2 :=
                     'Changed Email Address for Employee in FND_USER '
                  || v_rec2.full_name
                  || ' User Name '
                  || TO_CHAR (v_rec2.user_name)
                  || ' From: '
                  || v_rec2.user_email
                  || ' To: '
                  || v_rec2.hr_email;
               print_line (v_tmp2);

               --UPDATE applsys.fnd_user   --code commented by RXNETHI-ARGANO,18/05/23
               UPDATE apps.fnd_user        --code added by RXNETHI-ARGANO,18/05/23
                  SET email_address =  v_rec2.Hr_Email
                WHERE employee_id = v_rec2.person_id;
            EXCEPTION
               WHEN OTHERS
               THEN
                  v_tmp2 :=
                        '* * * ERROR in Changing Email Address for Employee in FND_USER '
                     || v_rec2.full_name
                     || ' User Name '
                     || TO_CHAR (v_rec2.user_name)
                     || ' From: '
                     || v_rec2.user_email
                     || ' To: '
                     || v_rec2.hr_email;
                  print_line (v_tmp2);
                  v_email_subj  := v_failed_message;
            END;
         END LOOP;

         COMMIT;
      END;

      fnd_file.put_line (fnd_file.output,
                            'Program completed successfully .  Report Date:'
                         || SYSDATE
                        );

   EXCEPTION
      WHEN OTHERS
      THEN
         fnd_file.put_line (fnd_file.output,
                               ' Error Code: '
                            || TO_CHAR (SQLCODE)
                            || ' Message: '
                            || SUBSTR (SQLERRM, 1, 240)
                           );
         fnd_file.put_line (fnd_file.LOG,
                               ' Error Code: '
                            || TO_CHAR (SQLCODE)
                            || ' Message: '
                            || SUBSTR (SQLERRM, 1, 240)
                           );
         v_email_subj  := v_failed_message;
   END;
     apps.ttec_library.send_email_attach_file (
      p_m_email_to_list,
      v_email_subj,
      v_email_body,
      NULL,
      v_error_stat);
   END;
END;
/
show errors;
/