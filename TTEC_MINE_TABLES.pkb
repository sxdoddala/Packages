create or replace PACKAGE BODY      TTEC_MINE_TABLES
AS
--************************************************************************************--
--*                                                                                  *--
--*     Program Name: TTEC_MINE_TABLES                                               *--
--*                                                                                  *--
--*     search for tables and objects in pacakges starting with passed parameter    *--
--*                                                                                  *--
--*    Mine object names from Schema                                                 *--
--*                                                                                  *--
--* Modification Log:                                                                *--
--* Developer          Date        Description                                       *--
--*     ---------          ----        -----------                                   *--
--* Wasim Manasfi   10/5/2009  Created                                               *--
--*RXNETHI-ARGANO   17/07/2023 R12.2 Upgrade Remediation
--*                                                                                  *--
--************************************************************************************--

   TYPE t_all_tab_columns IS TABLE OF apps.fnd_lookup_values%ROWTYPE;

   g_domain_rec   t_all_tab_columns;

   CURSOR c_code (p_name_start VARCHAR2)
   IS
      SELECT DISTINCT owner, NAME, TYPE, line, text
                 FROM SYS.dba_source
                WHERE (owner = 'APPS' OR owner = 'CUST')
                  AND NAME LIKE p_name_start
               --   AND TYPE != 'PACKAGE'
             ORDER BY NAME, line;
   -- load mapping data from lookup
   PROCEDURE load_map_table
   IS
   BEGIN
      SELECT *
      BULK COLLECT INTO g_domain_rec
        FROM apps.fnd_lookup_values
       WHERE (   NVL ('', territory_code) = territory_code
              OR territory_code IS NULL
             )
         AND lookup_type = 'TTEC_TABLE_NAME_MINE'
         AND (lookup_type LIKE 'TTEC_TABLE_NAME_MINE')
         AND (view_application_id = 3)
         -- AND (security_group_id = 2)
         AND enabled_flag = 'Y'
         AND LANGUAGE = 'US'
         AND TAG = 'Y'
         AND (end_date_active IS NULL OR end_date_active > SYSDATE);
   EXCEPTION
      WHEN OTHERS
      THEN
         ttec_library.print_line ('Error in module: load_map_table');
         ttec_library.print_line (   'Failed  with Error '
                     || TO_CHAR (SQLCODE)
                     || '|'
                     || SUBSTR (SQLERRM, 1, 64)
                    );
   END;

   PROCEDURE TTEC_MINE_TABLES (
      errcode        VARCHAR2,
      errbuff        VARCHAR2,
      e_name_start   VARCHAR2
   )
   IS
      --l_error_message   cust.ttec_error_handling.error_message%TYPE;  --code commented by RXNETHI-ARGANO,17/07/23
      l_error_message   apps.ttec_error_handling.error_message%TYPE;    --code added by RXNETHI-ARGANO,17/07/23
      v_owner           SYS.dba_source.owner%TYPE;
      v_name            SYS.dba_source.NAME%TYPE;
      v_type            SYS.dba_source.TYPE%TYPE;
      v_line            SYS.dba_source.line%TYPE;
      v_text            SYS.dba_source.text%TYPE;
      v_place           NUMBER;
      v_schema          VARCHAR2 (80);
      v_name_start      VARCHAR2 (80);
      v_text_search     VARCHAR2 (80);
   BEGIN
      ttec_library.print_line
         (
             'Teletech - Mine Code for Table Names defined in Lookup TTEC_TABLE_NAME_MINE  - Find table names that match patterners in Lookup TTEC_TABLE_NAME_MINE'
          || ' Run Date: '
          || TO_CHAR (SYSDATE)
         );
      ttec_library.print_line (' ');


      v_name_start := NVL (e_name_start || '%', 'T%');
      ttec_library.print_line(
              'Searching For Object Names in Schema APPS and CUST in Package Names Start with: '
           || v_name_start
          );

          ttec_library.print_line ( RPAD('TYPE', 40, ' ')
          																 || ' | '
                                           || RPAD('NAME', 40, ' ')
                                           || ' | '
                                           || RPAD('Line', 4, ' ')
                                           || ' | '
                                           || 'Text Found'
                                          );
      -- load the lookup table
      load_map_table;

      BEGIN
         FOR lcode IN c_code (v_name_start)
         LOOP
            v_owner := lcode.owner;
            v_name := lcode.NAME;
            v_type := lcode.TYPE;
            v_line := lcode.line;
            v_text := UPPER (lcode.text);

            FOR i IN g_domain_rec.FIRST .. g_domain_rec.LAST
            LOOP
               IF (    (INSTR (v_text,
                               TO_CHAR (g_domain_rec (i).meaning),
                               1,
                               1
                              ) != 0
                       )
                  )
               THEN
                  ttec_library.print_line ( RPAD(v_type, 40, ' ')
                                           || ' | '
                                           || RPAD(v_name, 40, '  ')
                                           || ' | '
                                           || RPAD(TO_CHAR (v_line), 4, ' ')
                                           || ' | '
                                           || v_text
                                          );
               END IF;
            END LOOP;
         END LOOP;
      EXCEPTION
         WHEN NO_DATA_FOUND
         THEN
            ttec_library.print_line (   'No More Data found '
                                     || TO_CHAR (SQLCODE)
                                     || ' Message: '
                                     || SUBSTR (SQLERRM, 1, 240)
                                    );
            NULL;
         WHEN OTHERS
         THEN
            ttec_library.print_line (   'Text of Error '
                                     || TO_CHAR (SQLCODE)
                                     || ' Message: '
                                     || SUBSTR (SQLERRM, 1, 240)
                                    );
            -- fnd_file.new_line (fnd_file.output, 2);
            NULL;
      END;


      NULL;
   END TTEC_MINE_TABLES;


END TTEC_MINE_TABLES;
/
show errors;
/