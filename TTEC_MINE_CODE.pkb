create or replace PACKAGE BODY      ttec_mine_code
AS
--************************************************************************************--
--*                                                                                  *--
--*     Program Name: APPS.TTEC_MINE_CODE                                            *--
--*                                                                                  *--
--                                                                                   *--
--*                                                                                  *--
--*     Description: Search for a specific text in a package (s)under a specific schema *--
--*     INPUTS   SCHEMA, PACKAGE, and TEXT                                           *--
--*                                                                                  *--
--* Modification Log:                                                                *--
--* Developer          Date        Description                                       *--
--*     ---------          ----        -----------                                   *--
--* Wasim Manasfi   10/5/2009  Created                                               *--
--*   XPRAVEEN(ARGANO)  18-july-2023		R12.2 Upgrade Remediation                                                                               *--
--*                                                                                  *--
--*                                                                                  *--
--************************************************************************************--
-- main cursor to find text in package under a schema
   CURSOR c_code (p_schema VARCHAR2, p_name_start VARCHAR2)
   IS
      SELECT DISTINCT owner, NAME, TYPE, line, text
                 FROM SYS.dba_source
                WHERE (owner = p_schema)
                  AND NAME LIKE p_name_start
              --    AND TYPE != 'PACKAGE'
             ORDER BY NAME, line;

   PROCEDURE ttec_mine_text (
      errcode        VARCHAR2,
      errbuff        VARCHAR2,
      e_schema       VARCHAR2,
      e_name_start   VARCHAR2,
      e_tbl_name     VARCHAR2
   )
   IS
      --l_error_message   cust.ttec_error_handling.error_message%TYPE;			-- Commented code by IXPRAVEEN-ARGANO,18-july-2023
      l_error_message   apps.ttec_error_handling.error_message%TYPE;            --  code Added by IXPRAVEEN-ARGANO,   18-july-2023
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
                   (   'Teletech - Mine Code  - Find Text that match pattern in Packages under a Schema '
                    || ' Run Date: '
                    || TO_CHAR (SYSDATE)
                   );
      v_schema := e_schema;
      v_name_start := e_name_start || '%';
      v_text_search := e_tbl_name;
      ttec_library.print_line (   'Searching in Schema  '
                               || v_schema
                               || ' Package Names Like: '
                               || v_name_start
                               || ' Searching for Text: '
                               || v_text_search
                              );
      ttec_library.print_line (' ');


      IF LENGTH (v_schema) < 2
      THEN
         v_schema := 'APPS';
      END IF;

      BEGIN
         FOR lcode IN c_code (v_schema, v_name_start)
         LOOP
            v_owner := lcode.owner;
            v_name := lcode.NAME;
            v_type := lcode.TYPE;
            v_line := lcode.line;
            v_text := lcode.text;
            v_place := INSTR (UPPER (v_text), UPPER (v_text_search), 1, 1);

            IF v_place != 0
            THEN
               ttec_library.print_line (   'Package Type '
                                        ||  ' | '
                                        || v_type
                                        || '  | '
                                        || '      Package Name: '
                                        ||  ' | '
                                        || v_name
                                        ||  ' | '
                                        || TO_CHAR (v_line)
                                        ||  ' | '
                                        || v_text
                                       );
            END IF;
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

      -- lvendor IN c_vendors

      -- commit;
      NULL;
   END ttec_mine_text;
END ttec_mine_code;
/
show errors;
/
