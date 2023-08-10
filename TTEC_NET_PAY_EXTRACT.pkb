create or replace PACKAGE BODY      TTEC_NET_PAY_EXTRACT
AS
  /*=============================================================================
     Desc:    This package is to extract the Net Pay values for Canada Employees and send it across.
    Creator: Manish Chauhan
    Date:    16-Oct-2017
    Version: 1.0

   --* Modification Log:
   --* Version       Developer             Date        Description
   --* -------       ---------             ----        -----------
        1.0          Manish Chauhan     16-Oct-2017     Initial Version
        2.0          Christiane Chan    Jan 08 2018     Enable Off-Cycle  + Third Party
        3.0             Venkat             28-May-2020     Commented hard coded server name as part of Syntax Retrofit 
                                                        and retrieving value using profile option.
        1.0          RXNETHI-ARGANO     17/07/2023      R12.2 Upgrade Remediation.
===========================================================================*/

  PROCEDURE main (errbuf OUT VARCHAR2, retcode OUT NUMBER, p_mail_id IN VARCHAR2,p_mail_id_1 IN VARCHAR2,p_payroll IN VARCHAR2,p_pay_date IN VARCHAR2,p_bank_account_ending IN VARCHAR2)
    AS
    v_file_handle          UTL_FILE.FILE_TYPE;
    v_date                  Date:=fnd_date.canonical_to_date (p_pay_date);
    v_count                NUMBER              := 0;
    l_request_id           NUMBER;
    l_outfile_path         VARCHAR2 (255)      := NULL;
    l_outfile_name         VARCHAR2 (255)      := NULL;
    crlf                   VARCHAR2 (2)        := CHR (13) || CHR (10);
    tab                    VARCHAR2(10) DEFAULT '     ';
    v_instance             VARCHAR2 (9);
    p_output_file_email    VARCHAR2 (255);
    p_output_file_email_1   VARCHAR (255);
    l_mail_msg             VARCHAR2 (1000);
    l_mail_conn            UTL_SMTP.connection;
    
    --l_mailhost             VARCHAR2 (64)       := 'mailgateway.teletech.com';-- Commented for 2.0
    l_mailhost             VARCHAR2 (64)       := ttec_library.XX_TTEC_SMTP_SERVER; -- Added for 2.0
    
    l_error_code           VARCHAR2 (100);
    l_month_period         VARCHAR2 (100);
    l_attribute5           VARCHAR2 (100);
    l_job_id               Number;
    l_employee_number     Number;
    l_last_upd_date        VARCHAR2 (100);
    l_effective_start_date  VARCHAR2 (100);
    l_Sup_name               VARCHAR2 (100);
    l_Sup_id                VARCHAR2 (100);
    l_sup_email             VARCHAR2 (100);
    l_person_id             Number;
    l_action_context_id     Number;
    l_ACTION_INFORMATION_ID     Number; /* 2.0 */
    l_netpay                Number;
    l_acc_no                Number;
     v_acc_no               NUMBER;
    l_pay_date              date;
    l_default_value         VARCHAR2 (100);
    l_assignment_id          Number;
    l_payroll              VARCHAR2 (50);
    V_Payroll                VARCHAR2 (50);
    l_org_payment_method     VARCHAR(100);
    l_checknumber            VARCHAR2 (50);

    /* 2.0  Begin */
    CURSOR EMP
      IS
                                SELECT  paaf.BUSINESS_GROUP_ID,
                                        papf.employee_number,
                                        papf.person_id,
                                 REPLACE(TRANSLATE (
                   REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(papf.full_name,CHR(10)),CHR(12)),CHR(13)),CHR(27)),'~') ,
                   'ÀÁÂÃÄÅÇÈÉÊËÌÍÎÏÑÒÓÔÕÖÙÚÛÜÝàáâãäåçèéêëìíîïñòóôõöøùúûüýÿºª"°#-',
                   'AAAAAACEEEEIIIINOOOOOUUUUYaaaaaaceeeeiiiinoooooouuuuyy      '),',','')    full_name,
                                        paaf.Assignment_id,
                                        (select  p.payroll_name
                                                   from Pay_payrolls_f p
                                                  where p.business_group_id=326 --fnd_profile.value_specific ('PER_BUSINESS_GROUP_ID')/* 2.0 */
                                                    and p.payroll_id = paaf.payroll_id
                                                    and trunc(sysdate) between p.effective_start_date and p.effective_end_date
                                        )payroll_name,
                                        pai.ACTION_INFORMATION_ID,
                                        pai.ACTION_INFORMATION18 org_payment_method,
                                            SUBSTR
                                           (pay_us_employee_payslip_web.get_check_number
                                                                                (pai.action_information17,
                                                                                 pai.action_information15
                                                                                ),
                                            1,
                                            150
                                           ) Check_Number,
                                          to_number(pai.ACTION_INFORMATION16) pymt_amount,
                                       pai.EFFECTIVE_DATE Check_date
                                   FROM pay_action_information pai
                                    ,   per_all_people_f papf
                                    ,   per_all_Assignments_f paaf
                                  WHERE 1=1
                                    AND pai.action_information_category in ( 'EMPLOYEE NET PAY DISTRIBUTION','EMPLOYEE THIRD PARTY PAYMENTS')
                                    AND paaf.BUSINESS_GROUP_ID = FND_PROFILE.VALUE_SPECIFIC('PER_BUSINESS_GROUP_ID')
                                    AND ( pai.ACTION_INFORMATION18 = 'Atelka Third Party'
                                       OR pai.ACTION_INFORMATION18 like '%Check%'
                                       OR pai.ACTION_INFORMATION18 like '%Cheque%')
                                    AND pai.action_context_type = 'AAP'
                                    AND pai.ASSIGNMENT_ID  = paaf.assignment_id
                                    AND papf.PERSON_ID     = paaf.person_id
                                    and v_date between papf.effective_start_date and papf.effective_end_date -- pay peiod end date
                                    and v_date between paaf.effective_start_date and paaf.effective_end_date -- pay peiod end date
                                    and pai.EFFECTIVE_DATE = v_date
                                    AND pai.ACTION_INFORMATION_ID
                                         NOT IN
                                          (SELECT l.ACTION_INFORMATION_ID
                                             --FROM CUST.TTEC_PAY_BOA_POSITIVE_PAY_LOG l  --code commented by RXNETHI-ARGANO,17/07/23
                                             FROM APPS.TTEC_PAY_BOA_POSITIVE_PAY_LOG l    --code added by RXNETHI-ARGANO,17/07/23
                                            WHERE l.ACTION_INFORMATION_ID = pai.ACTION_INFORMATION_ID
                                             ) ;
  /* 2.0  End  */

  BEGIN  --1
    l_request_id          := fnd_global.conc_request_id;
    p_output_file_email   := p_mail_id;
    p_output_file_email_1 := p_mail_id_1;
    l_payroll             := p_payroll;

    -- fnd_file.put_line (fnd_file.LOG, 'Program Starts From Here:');


       --   v_file_handle := UTL_FILE.fopen (l_outfile_path, l_outfile_name, 'w');
    BEGIN  --2
         fnd_file.put_line (fnd_file.LOG,'Program: Net Pay details extract starts:');
         /* 2.0  Begin */
         fnd_file.put_line (fnd_file.log,'BUSINESS_GROUP_ID'||'|'||
                                         'ACTION_INFORMATION_ID'||'|'||
                                         'Employee_Number'||'|'||
                                         'Full Name'||'|'||
                                         'Payroll Name'||'|'||
                                         'Payment Method'||'|'||
                                         'Check Number'||'|'||
                                         'Net Pay'||'|'||
                                         'ABA Routing'||'|'||
                                         'Account Number'||'|'||
                                         'Pay Date'||'|'||
                                         'Issue/Cancel'
                           );
         /* 2.0 End */

         fnd_file.put_line (fnd_file.output,
                               'Check Number'||'|'
                             || 'Net Pay' ||'|'
                             || 'ABA Routing' ||'|'
                             || 'Account Number' ||'|'
                             || 'Pay Date' ||'|'
                             || 'Issue/Cancel'
                           );

        FOR T1 IN EMP
         LOOP  --L1

            -- fnd_file.put_line (fnd_file.LOG, 'T! Loop Starts for Employee'||''||T1.Employee_Number);

            l_assignment_id        := T1.assignment_id;
            l_person_id            := T1.person_id;
            l_default_value        := 'BOFACATT';
            /* 2.0  Begin */
            l_employee_number      := T1.Employee_Number;
            l_ACTION_INFORMATION_ID:= T1.ACTION_INFORMATION_ID;
            l_org_payment_method   := T1.org_payment_method;
            l_checknumber          := T1.Check_Number;
            l_netpay               := T1.pymt_amount;
            l_pay_date             := T1.Check_date;
            /* 2.0 End */


           v_acc_no := '7114'||p_bank_account_ending;

                       BEGIN  --4

                            fnd_file.put_line (fnd_file.output,
                                          --l_employee_number ||tab||TO_CHAR(l_netpay,'9999999D99')||tab||l_default_value||tab||v_acc_no||tab||to_date(l_pay_date,'MM/DD/YYYY' )||tab||'I');  /* 2.0 Commented Out */
                                          l_checknumber||'|'||TRIM(TO_CHAR(l_netpay,'9999999D99'))||'|'||l_default_value||'|'||v_acc_no||'|'||to_char(l_pay_date,'MM/DD/YYYY' )||'|'||'I'); /* 2.0 */

                            /* 2.0 Begin */
                            fnd_file.put_line (fnd_file.log,
                                          T1.BUSINESS_GROUP_ID||'|'||l_ACTION_INFORMATION_ID||'|'||T1.Employee_Number||'|'||T1.full_name||'|'||T1.payroll_name||'|'||
                                          l_org_payment_method||'|'||l_checknumber||'|'||TRIM(TO_CHAR(l_netpay,'9999999D99'))||'|'||l_default_value||'|'||v_acc_no||'|'||
                                          to_char(l_pay_date,'MM/DD/YYYY' )||'|'||'I');

                             --INSERT INTO CUST.TTEC_PAY_BOA_POSITIVE_PAY_LOG  --code commented by RXNETHI-ARGANO,17/07/23
                             INSERT INTO APPS.TTEC_PAY_BOA_POSITIVE_PAY_LOG    --code added by RXNETHI-ARGANO,17/07/23
                             (        BUSINESS_GROUP_ID
                                ,   ACTION_INFORMATION_ID
                                ,    EMPLOYEE_NUMBER
                                ,    FULL_NAME
                                ,    payroll_name
                                ,   org_payment_method
                                ,    Check_DATE
                                ,    Check_Number
                                ,    Check_AMOUNT
                                ,    CREATION_DATE
                                 )
                              VALUES (    T1.BUSINESS_GROUP_ID,
                                        l_ACTION_INFORMATION_ID,
                                        T1.Employee_Number    ,
                                        T1.full_name    ,
                                        T1.payroll_name    ,
                                        l_org_payment_method,
                                        l_pay_date,
                                        l_checknumber    ,
                                        l_netpay    ,
                                        SYSDATE
                             );

                       EXCEPTION WHEN OTHERS THEN
                                        FND_FILE.PUT_LINE (FND_FILE.LOG, 'For Employee'||' '||l_employee_number||' '
                                                         || 'No Other unsent payment for date');


                       END;
                       /* 2.0 End */
              END LOOP;  --L1

    COMMIT;

    /* 2.0 Begin */
    --DELETE FROM cust.TTEC_PAY_BOA_POSITIVE_PAY_LOG  --code commented by RXNETHI-ARGANO,17/07/23
    DELETE FROM apps.TTEC_PAY_BOA_POSITIVE_PAY_LOG    --code added by RXNETHI-ARGANO,17/07/23
    WHERE CREATION_DATE < SYSDATE - 90;

    COMMIT;
    /* 2.0 End */
    EXCEPTION
      -- Utl_File.Get_Line will raise a No data found exception when last line is reached
      WHEN NO_DATA_FOUND
      THEN
        FND_FILE.PUT_LINE (FND_FILE.LOG, 'Unable to find Net Pay for Employee:'||''||l_employee_number);

    END; --2

    SELECT name
      INTO v_instance
      FROM v$database;


    BEGIN --6
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
        FND_FILE.PUT_LINE (FND_FILE.LOG, 'Error while fetching outfile path');
    END; --6

    DECLARE
      l_fexists        BOOLEAN;
      l_file_length    NUMBER;
      l_block_size     BINARY_INTEGER;
    BEGIN --7
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
    END;  --7

    l_mail_msg            := 'Date: ' ||
                             TO_CHAR (SYSDATE, 'dd Mon yy hh24:mi:ss') ||
                             crlf ||
                             'From:' ||
                             'applmgr@teletech.com' ||
                             crlf ||
                             'Subject:' ||
                             v_instance ||
                             ':- Net Pay Details for Canada REQUEST ID:' ||
                             l_request_id ||
                             crlf ||
                             'To: ' ||
                             p_output_file_email || p_output_file_email_1 ||
                             crlf;
    l_mail_conn           := UTL_SMTP.open_connection (l_mailhost, 25);
    -- Open SMTP Connection
    UTL_SMTP.helo (l_mail_conn, l_mailhost);   -- HandShake
    UTL_SMTP.mail (l_mail_conn, 'applmgr@teletech.com');
    UTL_SMTP.rcpt (l_mail_conn, p_output_file_email);
    UTL_SMTP.rcpt (l_mail_conn, p_output_file_email_1);
    UTL_SMTP.open_data (l_mail_conn);
    -- This will send the data as attachment
    UTL_SMTP.write_data (l_mail_conn
                        , 'Content-Disposition' ||
                          ': ' ||
                          'attachment; filename="' ||
                          SUBSTR (l_outfile_name, 1, INSTR (l_outfile_name, '.') - 1) ||
                          '_out.txt' ||
                          '"' ||
                          l_mail_msg ||
                          crlf);
    v_file_handle         := UTL_FILE.FOPEN (l_outfile_path, l_outfile_name, 'r');

    BEGIN  --8
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
    END;  --8

    FND_FILE.PUT_LINE (FND_FILE.LOG, 'END OF FILE');
--
    EXCEPTION
    WHEN OTHERS
    THEN
      FND_FILE.PUT_LINE (FND_FILE.LOG, 'Error:'||SUBSTR (SQLERRM, 1, 255));
    END;

  END TTEC_NET_PAY_EXTRACT; --1
  /
  show errors;
  /