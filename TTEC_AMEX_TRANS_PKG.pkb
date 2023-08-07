create or replace PACKAGE BODY      TTEC_AMEX_TRANS_PKG
AS
  /*=============================================================================
    Desc:    This package will email the AMEX transactions details
    Creator: Manish Chauhan
    Date:    18-Apr-2018
    Version: 1.0

	Version  Date      Author        Description (Include Ticket#)
    -------  --------  ------------  -----------------------------
    2.0      05/28/20  Venkat        Commented hard coded server name as part of Syntax Retrofit
	                                 and retrieving value using profile option.
	1.0	   16-May-2023 IXPRAVEEN(ARGANO)   		R12.2 Upgrade Remediation
===========================================================================*/


  PROCEDURE main (errbuf      OUT VARCHAR2,
                  retcode     OUT NUMBER,
                  p_mail_id   IN VARCHAR2,
                  p_date_from IN VARCHAR2,
                  p_date_to   IN VARCHAR2,
                  p_ledger    IN VARCHAR2)
    AS
    v_file_handle          UTL_FILE.FILE_TYPE;
    v_count                NUMBER              := 0;
    l_request_id           NUMBER;
    l_outfile_path         VARCHAR2 (255)      := NULL;
    l_outfile_name         VARCHAR2 (255)      := NULL;
    crlf                   VARCHAR2 (2)        := CHR (13) || CHR (10);
    v_instance             VARCHAR2 (9);
    p_output_file_email    VARCHAR2 (255);
    p_output_file_email1   VARCHAR2 (255);
    l_mail_msg             VARCHAR2 (1000);
    l_mail_conn            UTL_SMTP.connection;

    --l_mailhost             VARCHAR2 (64)       := 'smtpsvr.teletech.com'; -- Commented for 2.0
	l_mailhost             VARCHAR2 (64)       := ttec_library.XX_TTEC_SMTP_SERVER; -- Added for 2.0

    l_error_code           VARCHAR2 (100);
    l_month_period         VARCHAR2 (100);
   -- v_date_from             DATE;
   -- v_date_to               DATE;
    v_date_from             DATE:=fnd_date.canonical_to_date (p_date_from);
    v_date_to               DATE:=fnd_date.canonical_to_date (p_date_to);


    CURSOR c_emp ( C_date_from IN DATE,
                   C_date_to   IN DATE,
                   C_Ledger    IN Number
                  )
      IS
select         papf.full_name,
               papf.EMPLOYEE_NUMBER,
               acpa.CARD_PROGRAM_NAME,
               'XXXX'||SUBSTR(cc.CCNUMBER,-6) card_number,
               hla.LOCATION_CODE,
               accta.TRANSACTION_DATE ,
               TRANSACTION_AMOUNT,
               merchant_name1,
               --REPORT_HEADER_ID,
               accta.VALIDATE_CODE,
               gl.Name
             --  hou.set_of_books_id,
             --  gl.ledger_id,
             --  accta.org_id
FROM APPS.AP_CREDIT_CARD_TRXNS_ALL accta
   --, AP.AP_CARD_PROGRAMS_ALL acpa					-- Commented code by IXPRAVEEN-ARGANO,16-May-2023	
   , apps.AP_CARD_PROGRAMS_ALL acpa                   --  code Added by IXPRAVEEN-ARGANO,   16-May-2023
   , APPS.AP_CARDS_ALL AC
   , APPS.IBY_CREDITCARD cc
   , PER_ALL_PEOPLE_F papf
   , PER_ALL_ASSIGNMENTS_F paaf
   --, HR.HR_LOCATIONS_ALL hla				-- Commented code by IXPRAVEEN-ARGANO,16-May-2023
   , apps.HR_LOCATIONS_ALL hla                --  code Added by IXPRAVEEN-ARGANO,   16-May-2023
  -- , apps.FND_USER_RESP_GROUPS_DIRECT  a
  -- , applsys.fnd_user u
  -- , apps.FND_RESPONSIBILITY_vl b
   ,hr_operating_units hou
   ,gl_ledgers gl
WHERE hla.LOCATION_ID = paaf.LOCATION_ID
and trunc(sysdate) BETWEEN papf.EFFECTIVE_START_DATE AND papf.EFFECTIVE_END_DATE  --Parameter 1
and trunc(sysdate) BETWEEN paaf.EFFECTIVE_START_DATE AND paaf.EFFECTIVE_END_DATE   --Parameter 1
and accta.transaction_date between C_date_from and C_date_to
and accta.org_id = hou.organization_id
and hou.set_of_books_id = gl.ledger_id
and gl.ledger_id = C_Ledger --'ELOYALTY US'--gl.Name
and paaf.PERSON_ID = papf.PERSON_ID
and papf.PERSON_ID = ac.EMPLOYEE_ID
--and a.RESPONSIBILITY_ID = b.RESPONSIBILITY_ID
--and a.USER_ID = u.USER_ID
and cc.INSTRID = ac.CARD_REFERENCE_ID
--and u.employee_id = ac.EMPLOYEE_ID
--and b.responsibility_name like 'eLoyalty US Internet Expenses%'
--  AND acpa.card_program_name LIKE '%PCARD%'
and ac.card_program_id = acpa.CARD_PROGRAM_ID
and ac.CARD_ID = accta.CARD_ID
and ac.ORG_ID in ( select org_id
--from ap.ap_card_programs_all				-- Commented code by IXPRAVEEN-ARGANO,16-May-2023
from apps.ap_card_programs_all                --  code Added by IXPRAVEEN-ARGANO,   16-May-2023
where card_brand_lookup_code = 'American Express'
)
and ac.card_program_id = acpa.CARD_PROGRAM_ID
and REPORT_HEADER_ID is null
and TRANSACTION_AMOUNT > 0
--and papf.EMPLOYEE_NUMBER =  '3062932'   --Parameter 2
order by accta.transaction_DATE desc;


  BEGIN
    l_request_id               := fnd_global.conc_request_id;
    p_output_file_email        := p_mail_id;
    --p_effective_date      := p_effective_date;


    fnd_file.put_line (fnd_file.LOG, 'TTEC Amex Transactions detail Program:');
    fnd_file.put_line (fnd_file.LOG, '----------------------------------------');

    fnd_file.put_line (fnd_file.LOG, 'Parameters:');
    fnd_file.put_line (fnd_file.LOG, 'Email->'||''||p_mail_id);
    fnd_file.put_line (fnd_file.LOG, 'Date From->'||''||v_date_from);
    fnd_file.put_line (fnd_file.LOG, 'Date To->'||''||v_date_to);
    fnd_file.put_line (fnd_file.LOG, 'Ledger->'||''||p_ledger);



    BEGIN

         fnd_file.put_line (fnd_file.output,
                               'Employee Name' ||','
                            || 'Employee Number'  ||','
                            || 'Card Program Assigned' ||','
                            || 'CC Number' ||','
                            || 'Current Location Code' ||','
                            || 'Transaction Date' ||','
                            || 'Transaction Amount' ||','
                            || 'Merchant Name' ||','
                           -- || 'Report Header Id' ||','
                            || 'Validate Code' ||','
                            || 'Ledger Name'
                           );
             fnd_file.put_line (fnd_file.LOG, 'before For Loop');
            FOR T IN c_emp ( C_date_from     => v_date_from,
                             C_date_to       => v_date_to,
                             C_Ledger        => p_ledger
                            )
            LOOP
               fnd_file.put_line (fnd_file.LOG, 'Inside For Loop');
            v_count := v_count + 1;
            fnd_file.put_line (fnd_file.output,
                                  '"'||T.full_name||'"'
                               || ','
                               || '"'||T.employee_number||'"'
                               || ','
                               || '"'||T.CARD_PROGRAM_NAME||'"'
                               || ','
                               || '"'||T.card_number||'"'
                               || ','
                               || '"'||T.LOCATION_CODE||'"'
                               || ','
                               || '"'||T.TRANSACTION_DATE||'"'
                               || ','
                               || '"'||T.TRANSACTION_AMOUNT||'"'
                               || ','
                               || '"'||T.merchant_name1||'"'
                               || ','
                              -- || '"'||T.REPORT_HEADER_ID||'"'
                              -- || ','
                               || '"'||T.VALIDATE_CODE||'"'
                               || ','
                               || '"'||T.Name||'"'
                              );
         END LOOP;

    EXCEPTION
      -- Utl_File.Get_Line will raise a No data found exception when last line is reached
      WHEN NO_DATA_FOUND
      THEN
        FND_FILE.PUT_LINE (FND_FILE.LOG, 'No Amex Transaction Found'||' '||SUBSTR(SQLERRM,1,100));

    END;

    SELECT name
      INTO v_instance
      FROM v$database;

    BEGIN
      SELECT fcp.plsql_dir
            ,fcp.plsql_out
        INTO l_outfile_path
            ,l_outfile_name
        FROM fnd_concurrent_requests fcr
            ,fnd_concurrent_processes fcp
       WHERE fcr.request_id = l_request_id
         AND fcp.concurrent_process_id = fcr.controlling_manager;
    EXCEPTION
      WHEN OTHERS
      THEN
        FND_FILE.PUT_LINE (FND_FILE.LOG, 'Error while fetching outfile path'||' '||SUBSTR(SQLERRM,1,100));
    END;

    DECLARE
      l_fexists        BOOLEAN;
      l_file_length    NUMBER;
      l_block_size     BINARY_INTEGER;
    BEGIN
      UTL_FILE.fgetattr (l_outfile_path
                        ,l_outfile_name
                        ,l_fexists
                        ,l_file_length
                        ,l_block_size
                        );

      IF l_fexists
      THEN
        FND_FILE.PUT_LINE (FND_FILE.LOG, 'l_file_length -> ' || l_file_length || '   ' || 'l_block_size -> ' || l_block_size);
      END IF;
    END;

    l_mail_msg            := 'Date: ' ||
                             TO_CHAR (SYSDATE, 'dd Mon yy hh24:mi:ss') ||
                             crlf ||
                             'From:' ||
                             'applmgr@teletech.com' ||
                             crlf ||
                             'Subject:' ||
                             v_instance ||
                             ':- TTEC Amex Transactions Report REQUEST ID:' ||
                             l_request_id ||
                             crlf ||
                             'To: ' ||
                             p_output_file_email || --p_output_file_email1 ||
                             crlf;
    l_mail_conn           := UTL_SMTP.open_connection (l_mailhost, 25);
    -- Open SMTP Connection
    UTL_SMTP.helo (l_mail_conn, l_mailhost);   -- HandShake
    UTL_SMTP.mail (l_mail_conn, 'applmgr@teletech.com');
    UTL_SMTP.rcpt (l_mail_conn, p_output_file_email);
    --UTL_SMTP.rcpt (l_mail_conn, p_output_file_email1);
    UTL_SMTP.open_data (l_mail_conn);
    -- This will send the data as attachment
    UTL_SMTP.write_data (l_mail_conn
                        , 'Content-Disposition' ||
                          ': ' ||
                          'attachment; filename="' ||
                          SUBSTR (l_outfile_name, 1, INSTR (l_outfile_name, '.') - 1) ||
                          '_out.csv' ||
                          '"' ||
                          l_mail_msg ||
                          crlf);
    v_file_handle         := UTL_FILE.FOPEN (l_outfile_path, l_outfile_name, 'r');

    BEGIN
      LOOP
        UTL_FILE.get_line (v_file_handle, l_mail_msg);
        UTL_SMTP.write_data (l_mail_conn, l_mail_msg || crlf);
      END LOOP;
    EXCEPTION
      -- Utl_File.Get_Line will raise a No data found exception when last line is reached
      WHEN NO_DATA_FOUND
      THEN
        UTL_SMTP.close_data (l_mail_conn);
        UTL_SMTP.quit (l_mail_conn);
        UTL_FILE.FCLOSE (v_file_handle);
    END;

    FND_FILE.PUT_LINE (FND_FILE.LOG, 'END OF FILE');
    EXCEPTION
    WHEN OTHERS
    THEN
      FND_FILE.PUT_LINE (FND_FILE.LOG, 'Error While Writing data'||' '||SUBSTR(SQLERRM,1,100));

  END;

  END TTEC_AMEX_TRANS_PKG;
  /
  show errors;
  /