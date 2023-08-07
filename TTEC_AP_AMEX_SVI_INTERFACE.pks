create or replace PACKAGE      ttec_ap_amex_svi_interface
IS
/*== START ================================================================================================*\
  Author:  Kaushik Babu
    Date:  May 06, 2009
    Desc:  This package is for the purpose of adding new credit cards to the custom table and update
           changes for employee location/dept info, address, terminations, email address. This
           process sends email to the user about the changes as per scheduled in prodcution
  Concurrent program: TeleTech Amex Payables SVI Outbound Interface
  Parameters:     Run Date: Changes queried as per run date
                  email address: receipient email address for the changes to be sent
                  First time run : IF 'the value is Y' select all the credit cards in the database and upload into custom table
                                   IF the value is 'N' then changes are compared to the first run and sent to the user about the changes
  Modification History:

 Mod#  Person         Date     Comments
---------------------------------------------------------------------------
 1.0  Kaushik Babu  01-AUG-08 Created package
 1.1  Kaushik BAbu  14-May-09 Fixed code for 'CC' invalid identifier
 1.2  Kaushik Babu  28-OCT-11 Changed file generation cursor for R12 retrofit.
 1.0  MXKEERTHI(ARGANO)  18-JUL-2023                R12.2 Upgrade Remediation
\*== END ==================================================================================================*//* main query to obtain data from AP Interface table */
   CURSOR c_rec2_q (p_date IN VARCHAR2)
   IS
      SELECT   papf.employee_number,
               SUBSTR ((   papf.first_name
                        || ' '
                        || papf.middle_names
                        || ' '
                        || papf.last_name
                       ),
                       1,
                       20
                      ) full_name,
               papf.national_identifier, papf.person_id,
               papf.business_group_id, pad.date_from, pad.date_to, pad.style,
               pad.address_type,
               (pad.address_line1 || pad.address_line2) address,
               MIN (pph.phone_type) phone_type, pad.region_1, pad.region_2,
               pad.town_or_city, SUBSTR (pad.postal_code, 1, 5) postal_code,
               MAX (aca.card_number) card_number,
               MAX (gcc.segment1 || '.' || gcc.segment3) location_dept,
               LOWER (papf.email_address) email_address,
               MIN (TRANSLATE (pph.phone_number, '(''-''/'')'' ''.', ' ')
                   ) phone_number
          FROM apps.per_all_people_f papf,
               apps.per_addresses pad,
               apps.per_phones pph,
               apps.ap_cards_all aca,
               apps.per_all_assignments_f paaf,
               apps.gl_code_combinations gcc
         WHERE paaf.person_id = papf.person_id
           AND TO_DATE (p_date, 'YYYY/MM/DD HH24:MI:SS')
                  BETWEEN papf.effective_start_date
                      AND papf.effective_end_date
           AND TO_DATE (p_date, 'YYYY/MM/DD HH24:MI:SS')
                  BETWEEN paaf.effective_start_date
                      AND paaf.effective_end_date
           AND TO_DATE (p_date, 'YYYY/MM/DD HH24:MI:SS') BETWEEN pad.date_from
                                                             AND NVL
                                                                   (pad.date_to,
                                                                    SYSDATE
                                                                   )
           AND TO_DATE (p_date, 'YYYY/MM/DD HH24:MI:SS') BETWEEN pph.date_from(+)
                                                             AND NVL (pph.date_to(+),
                                                                      SYSDATE
                                                                     )
           AND papf.current_employee_flag = 'Y'
           AND pad.primary_flag = 'Y'
           AND papf.person_id = pad.person_id
           AND pph.parent_id(+) = pad.person_id
           AND papf.person_id = aca.employee_id(+)
           AND aca.inactive_date IS NULL
           AND pph.phone_number(+) NOT LIKE '0%'
           AND pph.phone_type(+) NOT IN 'HF'
           AND aca.card_number IS NOT NULL
           AND paaf.default_code_comb_id = gcc.code_combination_id(+)
           AND papf.business_group_id = 325
      -- AND papf.employee_number IN ('3048147', '3010695')
      GROUP BY papf.employee_number,
               (   papf.first_name
                || ' '
                || papf.middle_names
                || ' '
                || papf.last_name
               ),
               papf.national_identifier,
               papf.person_id,
               papf.business_group_id,
               pad.date_from,
               pad.date_to,
               pad.style,
               pad.address_type,
               pad.address_line1 || pad.address_line2,
               pad.region_1,
               pad.region_2,
               pad.town_or_city,
               pad.postal_code,
               papf.email_address;

   CURSOR c_term_emp
   IS
      SELECT emp_id, tran_type
	   --       FROM cust.ttec_ap_amex_interf_db;  --Commented code by MXKEERTHI-ARGANO,07/18/2023
       FROM apps.ttec_ap_amex_interf_db; --code added by MXKEERTHI-ARGANO, 07/18/2023
 
   CURSOR c_host
   IS
      SELECT SUBSTR (host_name, 1, 10)
        FROM v$instance;

   -- set directory destination for output file
   -- specify the file name and location

   CURSOR c_directory_path
   IS
    SELECT directory_path || '/data/temp',
             'TTEC_AMEX_SVI' || TO_CHAR (SYSDATE, '_MMDDYYYY_HHMMSS') || '.txt' file_name              -- Version 1.2
      FROM dba_directories
     WHERE directory_name = 'CUST_TOP';

   PROCEDURE print_line (p_data IN VARCHAR2);

   PROCEDURE GET_FILE_NAME (p_dir_name OUT VARCHAR2, p_file_name OUT VARCHAR2);

   PROCEDURE send_email_result (
      p_status          IN   NUMBER,
      p_host_name       IN   VARCHAR2,
      p_email_to_list   IN   VARCHAR2,
      p_filedir         IN   VARCHAR2,
      p_filename        IN   VARCHAR2
   );

   PROCEDURE init_error_msg;

   PROCEDURE log_error (
      p_label1       IN   VARCHAR2,
      p_reference1   IN   VARCHAR2,
      p_label2       IN   VARCHAR2,
      p_reference2   IN   VARCHAR2
   );

   PROCEDURE truncate_table (p_owner_name IN VARCHAR2, p_table_name IN VARCHAR2);

   PROCEDURE errvar_null (p_status OUT NUMBER);

   PROCEDURE build_header_rec (p_rec OUT VARCHAR2);

   PROCEDURE build_trailer_rec (
      p_rec_count        IN       NUMBER,
      p_first_time_run            VARCHAR2,
      p_rec              OUT      VARCHAR2
   );

   PROCEDURE build_data_rec (
      p_rec_in    IN       c_rec2_q%ROWTYPE,           -- in record from query
	   --  p_rec_out   OUT      cust.ttec_ap_amex_interf_db%ROWTYPE --Commented code by MXKEERTHI-ARGANO,07/18/2023
     p_rec_out   OUT      apps.ttec_ap_amex_interf_db%ROWTYPE  --code added by MXKEERTHI-ARGANO, 07/18/2023
 
   );

   PROCEDURE write_data_to_record (
    -- p_rec_db    IN       cust.ttec_ap_amex_interf_db%ROWTYPE, --Commented code by MXKEERTHI-ARGANO,07/18/2023
     p_rec_db    IN       apps.ttec_ap_amex_interf_db%ROWTYPE, --code added by MXKEERTHI-ARGANO, 07/18/2023
 
      p_rec_out   IN OUT   VARCHAR2
   );

   PROCEDURE insert_data_rec_in_db (
    --      p_rec_db   IN   cust.ttec_ap_amex_interf_db%ROWTYPE--Commented code by MXKEERTHI-ARGANO,07/18/2023
      p_rec_db   IN   apps.ttec_ap_amex_interf_db%ROWTYPE --code added by MXKEERTHI-ARGANO, 07/18/2023

   );

   PROCEDURE build_sql_select_statement (
      p_owner_name     IN       VARCHAR2,
      p_table_name     IN       VARCHAR2,
      p_alias_name     IN       VARCHAR2,
      p_where_clause   IN       VARCHAR2,
      p_order_by       IN       VARCHAR2,
      p_rec_out        IN OUT   VARCHAR2
   );

   PROCEDURE write_sql_results_file (
      p_output_file     IN   UTL_FILE.file_type,
      p_sql_statement   IN   VARCHAR2
   );

   PROCEDURE main (
      errcode                 VARCHAR2,
      errbuff                 VARCHAR2,
      p_date             IN   VARCHAR2,
      p_email_to_list    IN   VARCHAR2,
      p_first_time_run   IN   VARCHAR2
   );
END ttec_ap_amex_svi_interface;
/
show errors;
/