create or replace PACKAGE BODY      ttec_library
AS
/* $Header: ttec_library.pks 1.1 2010/11/09 mdodge ship $ */

   /*== START ================================================================================================*\
      Author: Wasim Manasfi
        Date: 2007
        Desc:  Library package to hold all cross module reusable ERP code.

     Modification History:

    Version    Date     Author   Description (Include Ticket#)
    -------  --------  --------  ------------------------------------------------------------------------------
        1.0  2007      WManasfi  Initial Checked-In Version.
        1.1  11/09/10  MDodge    New Code to build Unix Environment Directories duplicated in dba_directories.
        1.2  02/11/11  CHCHAN    New code to print line a line to the Concurrent Program's output or log file
        1.3  02/11/11  CHCHAN    New code to create backup table with timestamps
        2.0  11/01/11  CHCHAN    R12 Retrofit: Modified the CSF to get the proper R12 Directory Path
        2.1  12/27/11  MRDODGE   R12 Retrofit: Increased host_name size for new R12 environments.
        2.2  05/22/12  KBGONUGUNTLA Fixed Output value on function remove_non_ascii
        2.3  10/02/12  Kgonuguntla  Added new procedure purge_ss_stuck_trxn
        2.4  08/21/15  Lalitha    Added new function XX_TTEC_SMTP_SERVER
        2.5  02/21/18  Manish     Increase the v_str value to 4000 under TASK0717418
    3.0  05/28/20  Venkat     Commented hard coded server name as part of Syntax Retrofit 
                                  and retrieving value using profile option.
	1.0	18-july-2023 IXPRAVEEN(ARGANO)   		R12.2 Upgrade Remediation							  
   \*== END ==================================================================================================*/
   g_run_date            CONSTANT DATE                     := TRUNC (SYSDATE);
   g_oracle_start_date   CONSTANT DATE             := TO_DATE ('01-JAN-1950');
   g_oracle_end_date     CONSTANT DATE             := TO_DATE ('31-DEC-4712');
   --
   g_delimt                       CHAR (1)                           := '|';
   /* error handling parameters */
   g_e_program_run_status         NUMBER                             := 0;
   --g_e_error_hand                 cust.ttec_error_handling%ROWTYPE;		-- Commented code by IXPRAVEEN-ARGANO,18-july-2023
   g_e_error_hand                 apps.ttec_error_handling%ROWTYPE;         --  code Added by IXPRAVEEN-ARGANO,   18-july-2023

/*
------------------------------------------------------------------------------------------------
print a line to the log
------------------------------------------------------------------------------------------------
*/
   PROCEDURE print_line (p_data IN VARCHAR2)
   IS
   BEGIN
      fnd_file.put_line (fnd_file.LOG, p_data);
   END;

/*
------------------------------------------------------------------------------------------------
print a line to the Concurrent Program's output or log file
------------------------------------------------------------------------------------------------
*/
   PROCEDURE print_line2 (p_target IN VARCHAR2, p_data IN VARCHAR2)
   IS
   BEGIN
      IF p_target = 'OUTPUT'
      THEN
         fnd_file.put_line (fnd_file.output, p_data);
      ELSE
         fnd_file.put_line (fnd_file.LOG, p_data);
      END IF;
   END;

   --     --  UTL_FILE.fclose (v_file_handle);
   PROCEDURE send_email_attach_file (
      p_email_to_list   IN       VARCHAR2,
      p_email_subj      IN       VARCHAR2,
      p_email_body      IN       VARCHAR2,
      p_filename        IN       VARCHAR2 DEFAULT NULL,
      -- if null no file is sent
      p_error_stat      OUT      NUMBER
   )
   IS
      /* cursor to get host name */
      CURSOR c_host
      IS
         SELECT host_name                  -- 2.1 Removed Substr of length 10
           FROM v$instance;

      v_body         VARCHAR2 (4000);
      v_email_from   VARCHAR2 (64)   := 'EBSDevelopment@teletech.com';
--      crlf           CHAR (2)        := CHR (10) || CHR (13);
--      cr             CHAR (2)        := CHR (13);
      v_status       NUMBER;
      v_host_name    VARCHAR2 (64);
      v_err_mesg     VARCHAR2 (4000);
   BEGIN
      g_e_error_hand.module_name := 'send_email_attach_file';
      p_error_stat := 0;

      /* do minimum check on the email address */
      IF (LENGTH (p_email_to_list) < 5)
      THEN
         p_error_stat := 1;
         RETURN;
      END IF;

      OPEN c_host;

      FETCH c_host
       INTO v_host_name;

      CLOSE c_host;

      send_email (v_host_name,
                  v_email_from,
                  p_email_to_list,
                  NULL,
                  NULL,
                  p_email_subj,                                  -- v_subject,
                  p_email_body,
                  -- NULL, --                        v_line1,
                  NULL,
                  NULL,
                  NULL,
                  NULL,
                  p_filename,                                -- file to attach
                  NULL,
                  NULL,
                  NULL,
                  NULL,
                  v_status,
                  v_err_mesg
                 );
      p_error_stat := v_status;    -- this is the status returned by send_mail
   EXCEPTION
      WHEN OTHERS
      THEN
--         log_error ('SQLCODE',
--                    TO_CHAR (SQLCODE),
--                    'Error Message',
--                    SUBSTR (SQLERRM, 1, 120)
--                   );
         print_line ('Error in module: ' || g_e_error_hand.module_name);
         print_line (   'Failed  with Error '
                     || TO_CHAR (SQLCODE)
                     || '|'
                     || SUBSTR (SQLERRM, 1, 120)
                    );
         p_error_stat := 1;
   END;

/* function to remove Non Ascii characters from a string */
   FUNCTION remove_non_ascii (p_input_str IN VARCHAR2)
      RETURN VARCHAR2
   IS
      v_str          VARCHAR2 (4000); --increase the value to 4000 under #TASK0717418
      v_act          NUMBER          := 0;
      v_cnt          NUMBER          := 0;
      v_askey        NUMBER          := 0;
      v_output_str   VARCHAR2 (2000);
   BEGIN
      v_str := '^' || TO_CHAR (p_input_str) || '^';
      v_str :=
         TRANSLATE (SUBSTR (p_input_str, 1, 2000),
                    '¿¿¿¿¿¿¿¿¿¿¿¿¿¿¿¿¿¿¿¿¿¿¿¿¿¿"',
                    'aaaaeeeeiiiooouuuuAAAAEEEEIIIOOOUUUUcCoOoONnoa '
                   );
      v_cnt := LENGTH (v_str);

      IF v_cnt >= 1
      THEN
         FOR i IN 1 .. v_cnt
         LOOP
            v_askey := 0;
            v_askey := ASCII (SUBSTR (v_str, i, 1));

            IF v_askey < 32 OR v_askey >= 127
            THEN
               v_str := '^' || REPLACE (v_str, CHR (v_askey), '');
            END IF;
         END LOOP;
      END IF;

      v_output_str := TRIM (LTRIM (RTRIM (TRIM (v_str), '^'), '^'));
      RETURN (v_output_str);
   END;

-- FUNCTION Get_Directory       -- Added 1.1
-- Description: This function will return the Directory Path maintained in DBA_Directories
--   for the input Directory Name.  It is mainly designed to get Unix level directory
--   such as CUST_TOP that will be dual maintained in the dba_directories table.
   FUNCTION get_directory (p_directory_name IN VARCHAR2)
      RETURN VARCHAR2
   IS
      v_directory   dba_directories.directory_path%TYPE;
   BEGIN
      SELECT db.directory_path
        INTO v_directory
        FROM dba_directories db
       WHERE db.directory_name = p_directory_name;

      RETURN v_directory;
   EXCEPTION
      WHEN OTHERS
      THEN
         RETURN NULL;
   END get_directory;

-- FUNCTION Get_ApplCSF_Dir     -- Added 1.1
-- Description: This function will return the Concurrent Log or Output directory
--   path dependent on the input Type desired.
   FUNCTION get_applcsf_dir (p_type IN VARCHAR2)
      RETURN VARCHAR2
   IS
      v_type        VARCHAR2 (3);
      v_directory   dba_directories.directory_path%TYPE;
   BEGIN
      v_type := LOWER (p_type);

      IF p_type NOT IN ('log', 'out')
      THEN
         RETURN NULL;
      END IF;

      SELECT db.directory_path || '/' || v_type                        -- V2.0
        INTO v_directory
        FROM dba_directories db, v$instance vi
       WHERE db.directory_name = 'APPLCSF';                            -- V2.0

      RETURN v_directory;
   EXCEPTION
      WHEN OTHERS
      THEN
         RETURN NULL;
   END get_applcsf_dir;

--
--  PROCEDURE: create_backup  -- Added 1.3
-- Description: This procedure will create a backup table that will re-enforce the
--              ERP backup table naming convention rule
--
--             OWNER.TTEC_?????????_BK_YYMMDDHHMISS
--
--             where ????????? is the abbreviation of the table name to be backup
--
--            If the created backup date has 0 record. It will rollback to undo
--            to remove the empty table and return a 'fail' status .
--
--
   PROCEDURE create_backup (
      p_backup_tbl_owner   IN       VARCHAR2 DEFAULT 'CUST',
      p_backup_tbl_name    IN       VARCHAR2,
      -- Accepts up to 9 characters value (table name abbreviation)
      p_msg_destination    IN       VARCHAR2 DEFAULT 'LOG',
      -- Accepts either 'LOG' or 'OUTPUT'
      p_sql_body_1         IN       VARCHAR2 DEFAULT NULL,
      p_sql_body_2         IN       VARCHAR2 DEFAULT NULL,
      p_sql_body_3         IN       VARCHAR2 DEFAULT NULL,
      p_sql_body_4         IN       VARCHAR2 DEFAULT NULL,
      p_sql_body_5         IN       VARCHAR2 DEFAULT NULL,
      p_sql_body_6         IN       VARCHAR2 DEFAULT NULL,
      p_sql_body_7         IN       VARCHAR2 DEFAULT NULL,
      p_sql_body_8         IN       VARCHAR2 DEFAULT NULL,
      p_sql_body_9         IN       VARCHAR2 DEFAULT NULL,
      p_sql_body_10        IN       VARCHAR2 DEFAULT NULL,
      p_status             OUT      VARCHAR2
   )                                     -- Returns either 'Success' or 'Fail'
   IS
      v_timestamp   VARCHAR2 (50)    := NULL;
      v_sql         VARCHAR2 (32000) := NULL;
      v_stage       VARCHAR2 (200)   := NULL;
   BEGIN
      v_stage := 'PROCEDURE ttec_library.create_backup - Obtain Timestamp';
      p_status := '';

      BEGIN
         /* Query to obtain timestamp to create a backup table  */
         SELECT TO_CHAR (SYSDATE, 'YYMMDDHH24MISS')
           INTO v_timestamp
           FROM DUAL;
      EXCEPTION
         WHEN OTHERS
         THEN
            print_line2 (p_msg_destination, 'Operation fails on ' || v_stage);
            print_line2 (p_msg_destination, '');
            print_line2 (p_msg_destination,
                         'Error: ' || SQLCODE || '-' || SQLERRM
                        );
            print_line2 (p_msg_destination, '');
            p_status := 'Failed';
            RETURN;
      END;

      v_stage := 'PROCEDURE ttec_library.create_backup - Create backup table';

      BEGIN
         /* Build dynamic SQL statement to create the back up table with Timestamp */
         v_sql := NULL;
         v_sql :=
               'CREATE TABLE '
            || p_backup_tbl_owner
            || '.'
            || 'ttec_'
            || p_backup_tbl_name
            || '_bk_'
            || v_timestamp
            || ' AS SELECT '
            || p_sql_body_1
            || p_sql_body_2
            || p_sql_body_3
            || p_sql_body_4
            || p_sql_body_5
            || p_sql_body_6
            || p_sql_body_7
            || p_sql_body_8
            || p_sql_body_9
            || p_sql_body_10;
         print_line2 (p_msg_destination, 'Executing: ' || v_sql);
         print_line2 (p_msg_destination, '');

         EXECUTE IMMEDIATE (v_sql);

         IF SQL%ROWCOUNT = 0
         THEN
            print_line2 (p_msg_destination,
                         'No record(s) found to meet this criteria.'
                        );
            print_line2 (p_msg_destination, '');
            ROLLBACK;
            p_status := 'Fail';
         ELSE
            print_line2 (p_msg_destination,
                         'Backup table is successfully created...'
                        );
            print_line2 (p_msg_destination, '');
            p_status := 'Success';
         END IF;
      EXCEPTION
         WHEN OTHERS
         THEN
            print_line2 (p_msg_destination, 'Operation fails on ' || v_stage);
            print_line2 (p_msg_destination, '');
            print_line2 (p_msg_destination,
                         'Error: ' || SQLCODE || '-' || SQLERRM
                        );
            print_line2 (p_msg_destination, '');
            p_status := 'Fail';
            RETURN;
      END;
   END create_backup;

   PROCEDURE purge_ss_stuck_trxn (
      errcode     OUT      VARCHAR2,
      errbuff     OUT      VARCHAR2,
      p_emp_num   IN       VARCHAR2
   )
   IS
      CURSOR c_query
      IS
         SELECT transaction_id, item_type, item_key, process_name
           FROM hr_api_transactions
          WHERE selected_person_id = (SELECT DISTINCT person_id
                                                 FROM apps.per_all_people_f
                                                WHERE employee_number =
                                                                    p_emp_num);
   --IN (1067026, 1060084);
   BEGIN
      FOR r_query IN c_query
      LOOP
         BEGIN
            hr_transaction_api.rollback_transaction
                                 (p_transaction_id      => r_query.transaction_id,
                                  p_validate            => FALSE
                                 );
            COMMIT;
            print_line2
                      ('OUTPUT',
                          'Successfully Rollback Transaction for Employee No-'
                       || p_emp_num
                       || '- Transaction Id'
                       || r_query.transaction_id
                       || '- Item Key'
                       || r_query.item_key
                       || '- Process Name'
                       || r_query.process_name
                      );
         EXCEPTION
            WHEN NO_DATA_FOUND
            THEN
               print_line2 ('LOG', 'API NO_DATA_FOUND Error -' || SQLERRM);
            WHEN TOO_MANY_ROWS
            THEN
               print_line2 ('LOG', 'API TOO_MANY_ROWS Error -' || SQLERRM);
            WHEN OTHERS
            THEN
               print_line2 ('LOG', 'API OTHERS Error -' || SQLERRM);
         END;
      END LOOP;
   EXCEPTION
      WHEN OTHERS
      THEN
         print_line2 ('LOG', 'Error in Main -' || SQLERRM);
   END purge_ss_stuck_trxn;


--
   FUNCTION XX_TTEC_INSTANCE_TYPE
      RETURN VARCHAR2
   IS

v_inst  v$instance.INSTANCE_NAME%type;
v_host  v$instance.HOST_NAME%type;
v_curr  varchar2(100);

BEGIN

        BEGIN
            v_curr := NULL;
            select  INSTANCE_NAME , HOST_NAME
            into    v_inst    , v_host
            from    v$instance;
        EXCEPTION WHEN OTHERS THEN
            v_inst  := NULL;
            v_host  := NULL;
        END;


       v_curr := 'NONPROD';
   --    if v_inst = 'PROD' and v_host = 'l123536sdbs3001.teletech.com' --'den-erp046' -- commented for version 3.0
         if upper(v_inst) = 'TECP' and upper(v_host) = 'TECDBP01' -- added for version 3.0
       --if v_inst = 'PROD' and upper(v_host) = 'TESTl123536sdbs3001.teletech.com' --'den-erp046'
       then
           v_curr := 'PROD';
       elsif v_inst = 'PPRD' and v_host = 'den-erp042'
       then
           v_curr := 'NONPROD:PREPROD';
       elsif v_inst = 'DEV1' and v_host = 'den-erp092'
       then
           v_curr := 'NONPROD:DEV1';
       elsif v_inst = 'DEV2' and v_host = 'den-erp092'
       then
           v_curr := 'NONPROD:DEV2';
       end if;


       RETURN  nvl(v_curr,' ');
   END;



   FUNCTION XX_TTEC_INSTANCE_HOST
      RETURN VARCHAR2

   IS

v_host  v$instance.HOST_NAME%type;
-- v_curr  varchar2(100);

BEGIN

        BEGIN
            select  HOST_NAME
            into    v_host
            from    v$instance;
        EXCEPTION WHEN OTHERS THEN
            v_host  := NULL;
        END;


       RETURN  nvl(v_host,' ');
   END;



   FUNCTION XX_TTEC_PROD_HOST_NAME
      RETURN VARCHAR2
   IS

BEGIN
      BEGIN
         --     RETURN  'l123536sdbs3001.teletech.com';  -- commented for version 3.0
         RETURN  'tecdbp01';  -- added for version 3.0 to return tecp host name
        -- RETURN  'TESTl123536sdbs3001.teletech.com';
      END;

END;


   FUNCTION XX_TTEC_PREPROD_HOST_NAME
      RETURN VARCHAR2
   IS

BEGIN
      BEGIN
           -- RETURN  'PREPROD.teletech.com';
        RETURN  'm223537sdbs3001.teletech.com';
      END;

END;


FUNCTION XX_TTEC_SMTP_SERVER RETURN VARCHAR2 IS
  BEGIN
    -- RETURN 'mailgateway.teletech.com'; -- Commented for 3.0
    RETURN FND_PROFILE.VALUE('FND_SMTP_HOST'); -- Added for 3.0
END;

END ttec_library;
/
show errors;
/