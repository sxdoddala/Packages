create or replace PACKAGE BODY      TTEC_BDO_PAYROLL_H2H_EXTRACT AS
--
-- Program Name:  TTEC_BDO_PAYROLL_H2H_EXTRACT
--
-- Description:  This program generates Payroll File Format for HOST TO HOST (H2H) file format mandated by:
--               BDO's BOB document issued on December 04, 2017
--
-- Input/Output Parameters:
--
--
--
-- Tables Modified:  N/A
--
--
-- Created By:  Christiane Chan
-- Date: Jan 10, 2006
--
-- Version  Developer        Date        Description
-- -------  ----------       --------    --------------------------------------------------------------------
--          C. Chan			12/12/17    Initial
--
-- Global Variables ---------------------------------------------------------------------------------

PROCEDURE gen_payment_file(errbuf OUT VARCHAR2, retcode OUT NUMBER,
                           p_output_directory       IN       VARCHAR2,
                           p_filename_prefix        IN       VARCHAR2,
                           p_payroll_id             IN       NUMBER,
                           p_employee_number        IN       VARCHAR2,
                           p_pay_date               IN       VARCHAR2,
                           p_bank_trx_time          IN       VARCHAR2,
						   p_org_bank_number        IN       VARCHAR2,
                           p_org_bank_name          IN       VARCHAR2,
                           p_ORG_PYMT_METHOD_NAME   IN       VARCHAR2,
                           p_action_info_cat_name   IN       VARCHAR2,
                           p_manual_upload          IN       VARCHAR2
						 ) IS

-- Filehandle Variables
p_FileDir                      varchar2(200);
p_FileName                     varchar2(50);
p_Country                      varchar2(10);
v_bank_file                    UTL_FILE.FILE_TYPE;

-- Declare variables
l_msg                          varchar2(2000);
l_stage	                       varchar2(100);
l_element                      varchar2(100);
l_rec 	                       varchar2(100);
l_key                          varchar2(100);
l_final_indicator              varchar2(1);
l_bank_account                 varchar2(100);
l_bank_trx_time                varchar2(8);
l_pay_date                     date;



l_tot_rec_count                number;
l_sum_pay_amount               number;
l_check_number_hash_total      number;

cursor c_directory_path(v_bank_trx_time varchar,v_paydate date) is
select DECODE(p_manual_upload, 'Y',substr(p_output_directory, 1, length(p_output_directory) - 3)||'/Manual',p_output_directory) file_path,
       p_filename_prefix
       || to_char(v_paydate,'MMDDYYYY')
       ||LPAD(APPS.TTEC_BDO_PH_H2H_BATCH_SEQ.nextval,2,'0')
   --    || v_bank_trx_time
   --    || decode(HOST_NAME,ttec_library.XX_TTEC_PROD_HOST_NAME,'','16:00:00')
       || '.txt' file_name
from v$INSTANCE;


cursor c_detail_record IS
/* Formatted on 2017/12/12 18:08 (Formatter Plus v4.8.8) */
SELECT papf.employee_number, papf.person_id, papf.full_name, paaf.payroll_id,paaf.business_group_id,
       pai.ACTION_INFORMATION_ID,
       pai.assignment_id, pai.effective_date, pai.action_information_category,
       pai.action_information5 bank_name, pai.action_information15 PrePymt_id,
      -- pai.action_information10 emp_name,
       pai.action_information6 emp_bank_acct,
       pai.action_information13 pymt_currency,
       pai.action_information16 pymt_amount,
       pai.action_information18 pymt_method
  FROM per_all_people_f papf,
       per_all_assignments_f paaf,
       pay_action_information pai
 WHERE 1 = 1
   AND papf.person_id = paaf.person_id
   AND paaf.assignment_id = pai.assignment_id
   AND paaf.business_group_id = fnd_profile.value_specific ('PER_BUSINESS_GROUP_ID')--1517
   AND TRUNC (pai.effective_date) BETWEEN papf.effective_start_date
                                      AND papf.effective_end_date
   AND TRUNC (pai.effective_date) BETWEEN paaf.effective_start_date
                                      AND paaf.effective_end_date
   --and pai.assignment_id = 230286
   AND pai.action_information_category = p_action_info_cat_name  --'EMPLOYEE NET PAY DISTRIBUTION'
   AND pai.action_information5         = p_org_bank_name         --'Bank of the Philippines'
   AND pai.action_information18        = p_org_pymt_method_name  --'Direct Deposit ROHQ'
   AND pai.effective_date              = l_pay_date      --to_date('25-SEP-2017')
   AND pai.assignment_id IN (
          SELECT paaf.assignment_id
            FROM per_all_people_f papf,
                 per_all_assignments_f paaf,
                 pay_all_payrolls_f ppf,
                 (SELECT DISTINCT payroll_name, payroll_id
                             FROM pay_payrolls_f
                            WHERE business_group_id = fnd_profile.value_specific ('PER_BUSINESS_GROUP_ID') --1517
                              AND l_pay_date  BETWEEN effective_start_date
                                                  AND effective_end_date) pay
           WHERE papf.person_id = paaf.person_id
             AND paaf.payroll_id = ppf.payroll_id
             AND papf.business_group_id = fnd_profile.value_specific ('PER_BUSINESS_GROUP_ID')--1517 --
             --AND papf.current_employee_flag = 'Y'
             --AND paaf.primary_flag='Y'
             AND pay.payroll_id = ppf.payroll_id
             AND papf.employee_number = NVL (p_employee_number, papf.employee_number)--'2006221'
             AND ppf.payroll_id = NVL (p_payroll_id, ppf.payroll_id)
             --and ppf.payroll_name= NVL('PHL ROHQ Non-Management',pay.payroll_name)
             AND l_pay_date   BETWEEN ppf.effective_start_date
                                     AND ppf.effective_end_date
             AND l_pay_date  BETWEEN papf.effective_start_date
                                     AND papf.effective_end_date
             AND l_pay_date   BETWEEN paaf.effective_start_date
                                     AND paaf.effective_end_date)
             AND pai.ACTION_INFORMATION_ID NOT IN (SELECT ACTION_INFORMATION_ID
                                                     FROM CUST.TTEC_PAY_BDO_BANK_EXTRACT_LOG l
                                                    WHERE l.BUSINESS_GROUP_ID = fnd_profile.value_specific ('PER_BUSINESS_GROUP_ID')--1517 --
                                                      AND l.EFFECTIVE_DATE = l_pay_date);


BEGIN

  IF p_pay_date = 'DD-MON-YYYY'
  THEN
    l_pay_date := TRUNC (SYSDATE); --TO_DATE('25-SEP-2017') ;
    l_bank_trx_time  := '';
  ELSE
    l_pay_date := TO_DATE (p_pay_date); -- TO_DATE('25-SEP-2017');
    l_bank_trx_time  := p_bank_trx_time;
  END IF;

  l_stage := 'c_directory_path';

  --Fnd_File.put_line(Fnd_File.LOG,'Processing ->'||l_stage);
  open c_directory_path(l_bank_trx_time,l_pay_date);
  fetch c_directory_path into p_FileDir,p_FileName; --,p_Country;
  close c_directory_path;

  Fnd_File.put_line(Fnd_File.LOG,'----------------------------------------------------------------------');
  Fnd_File.put_line(Fnd_File.LOG,'Extract Parameters:');
  Fnd_File.put_line(Fnd_File.LOG,'----------------------------------------------------------------------');
  Fnd_File.put_line(Fnd_File.LOG,'File Output Directory                :'||p_output_directory);
  Fnd_File.put_line(Fnd_File.LOG,'Filename Prefix                      :'||p_filename_prefix);
  Fnd_File.put_line(Fnd_File.LOG,'Payroll Name                         :'||p_payroll_id);
  Fnd_File.put_line(Fnd_File.LOG,'Employee Number                      :'||p_employee_number);
  Fnd_File.put_line(Fnd_File.LOG,'Pay Date                             :'||l_pay_date);
  Fnd_File.put_line(Fnd_File.LOG,'Bank Transaction Time                :'||p_bank_trx_time);
  Fnd_File.put_line(Fnd_File.LOG,'Org Bank Number                      :'||p_org_bank_number);
  Fnd_File.put_line(Fnd_File.LOG,'Org Bank Name                        :'||p_org_bank_name);
  Fnd_File.put_line(Fnd_File.LOG,'Org Payment Method Name              :'||p_ORG_PYMT_METHOD_NAME);
  Fnd_File.put_line(Fnd_File.LOG,'Pay Action Information Category Name :'||p_action_info_cat_name);
  Fnd_File.put_line(Fnd_File.LOG,'');

  v_bank_file := UTL_FILE.FOPEN(p_FileDir, p_FileName, 'w');

  Fnd_File.put_line(Fnd_File.OUTPUT,'TTEC BDO payroll H2H extract - PHL Motif (Report for Internal Payroll Users)');
  Fnd_File.put_line(Fnd_File.OUTPUT,'File Output Directory -> '||p_FileDir);
  Fnd_File.put_line(Fnd_File.OUTPUT,'Filename              -> '||p_FileName);
  Fnd_File.put_line(Fnd_File.OUTPUT,'Pay Date              -> '||l_pay_date);
  Fnd_File.put_line(Fnd_File.OUTPUT,'Bank Transaction Time -> '||p_bank_trx_time);
  Fnd_File.put_line(Fnd_File.OUTPUT,'Manual Upload         -> '||p_manual_upload);
  Fnd_File.put_line(Fnd_File.OUTPUT,'');
  Fnd_File.put_line(Fnd_File.OUTPUT,'BDO Extract Begin Processing Time:'||to_char(SYSDATE,'YYYYMMDD HH24:MI:SS'));

  l_stage := 'c_header_record';
  Fnd_File.put_line(Fnd_File.LOG,'Processing ->'||l_stage);

  --For Bk_Acct_header in c_header_record loop

      l_tot_rec_count          := 0;
      l_sum_pay_amount     := 0;
      l_check_number_hash_total := 0;
	  l_bank_account            := p_org_bank_number;

      --
      --  Account Header Record
      --

      IF p_manual_upload = 'Y'
      THEN
         NULL;
      ELSE

          l_rec := 'H'
                ||'|'||p_org_bank_number
                ||'|'||to_char(l_pay_date,'MM/DD/YYYY')
                ||'|'||l_bank_trx_time;

          utl_file.put_line(v_bank_file, l_rec);

          Fnd_File.put_line(Fnd_File.OUTPUT,'Header|FundingAccount|Transaction Date|Transaction Time');
          apps.fnd_file.put_line(apps.fnd_file.output,
                'H'
                ||'|'||p_org_bank_number
                ||'|'||to_char(l_pay_date,'MM/DD/YYYY')
                ||'|'||l_bank_trx_time);
     END IF;
-------------------------------------------------------------------------------------------------------------------------

     l_stage := 'c_detail_record';
     --Fnd_File.put_line(Fnd_File.LOG,'Processing ->'||l_stage);

     Fnd_File.put_line(Fnd_File.OUTPUT,'D|Account Number|Amount|Payment Record Details -> |Employee|Full Name|Effective Date|Bank Name|Prepayment ID|Pmt Emp Bank Acct|Pmt Currency|Pmt Amount|Pmt Method');

     For pay_rec in c_detail_record loop

        l_element := 'EMPNumber';
   		l_key     := pay_rec.employee_number;

        -------------------------------------------------------------------------------------------------------------------------

        --
        --  Bank Payment Detail Record
        --

        --l_stage := 'Payment Detail Record';

        IF p_manual_upload = 'Y'
        THEN
            l_rec :=
                  nvl(substr(lpad(UPPER(pay_rec.emp_bank_acct),12,'0'),1,12),lpad('0',12,'0'))
                  ||chr(9)||nvl(  to_char(pay_rec.pymt_amount,'999999999.99') ,'0.00')
                  ;
        ELSE

            l_rec := 'D'
                  ||'|'||nvl(substr(lpad(UPPER(pay_rec.emp_bank_acct),12,'0'),1,12),lpad('0',12,'0'))
                  ||'|'||nvl(  to_char(pay_rec.pymt_amount,'999999999.99') ,'0.00')
                  ;

        END IF;

        utl_file.put_line(v_bank_file, l_rec);

        apps.fnd_file.put_line(apps.fnd_file.output, 'D'
              ||'|'||nvl(substr(lpad(UPPER(pay_rec.emp_bank_acct),12,'0'),1,12),lpad('0',12,'0'))
              ||'|'||nvl(  to_char(pay_rec.pymt_amount,'999999999.99') ,'0.00')
                                                    ||'|'||'Payment Record Details -> '
                                                    ||'|'||pay_rec.employee_number
                                                    ||'|'||pay_rec.full_name
                                                    ||'|'||pay_rec.effective_date
                                                    ||'|'||pay_rec.bank_name
                                                    ||'|'||pay_rec.PrePymt_id
                                                   -- ||'|'||pay_rec.emp_name
                                                    ||'|'||pay_rec.emp_bank_acct
                                                    ||'|'||pay_rec.pymt_currency
                                                    ||'|'||nvl(  to_char(pay_rec.pymt_amount,'999999999.99') ,' 0.00')
                                                    ||'|'||pay_rec.pymt_method);

         INSERT INTO CUST.TTEC_PAY_BDO_BANK_EXTRACT_LOG
         (	ACTION_INFORMATION_ID	,
            BUSINESS_GROUP_ID,
            EMPLOYEE_NUMBER	,
            FULL_NAME	,
            EFFECTIVE_DATE	,
            BANK_NAME	,
            PREPAYMENT_ID	,
            EMP_BANK_ACCT	,
            PMT_CURRENCY	,
            PMT_AMOUNT	,
            PMT_METHOD	,
            CREATION_DATE
             )
          VALUES (	pay_rec.ACTION_INFORMATION_ID	,
                    pay_rec.BUSINESS_GROUP_ID,
                    pay_rec.employee_number	,
                    pay_rec.full_name	,
                    pay_rec.effective_date	,
                    pay_rec.bank_name	,
                    pay_rec.PrePymt_id	,
                    pay_rec.emp_bank_acct	,
                    pay_rec.pymt_currency	,
                    nvl(  to_char(pay_rec.pymt_amount,'999999999.99') ,' 0.00')	,
                    pay_rec.pymt_method	,
                    SYSDATE
         );

        l_sum_pay_amount := l_sum_pay_amount + nvl(pay_rec.pymt_amount,0);
        l_tot_rec_count  := l_tot_rec_count + 1;


     End Loop; /* pay */

-------------------------------------------------------------------------------------------------------------------------

      --
      --  Account Trailer Record
      --
      l_stage := 'Account Trailer Record';
      --Fnd_File.put_line(Fnd_File.LOG,'Processing ->'||l_stage);

      IF p_manual_upload = 'Y'
      THEN
         NULL;
      ELSE
        l_rec := 'T'
              ||'|'||l_tot_rec_count
              ||'|'||nvl(  to_char(l_sum_pay_amount,'999999999.99') ,' 0.00');

        utl_file.put_line(v_bank_file, l_rec);


        apps.fnd_file.put_line(apps.fnd_file.output,
                  'T'
             ||'|'|| l_tot_rec_count
             ||'|'|| nvl(  to_char(l_sum_pay_amount,'999999999.99') ,' 0.00'));

      END IF;


  Fnd_File.put_line(Fnd_File.OUTPUT,'BDO Extract End Processing Time:'||to_char(SYSDATE,'YYYYMMDD HH24:MI:SS'));

  Fnd_File.put_line(Fnd_File.LOG, '');
  Fnd_File.put_line(Fnd_File.LOG, '');
  Fnd_File.put_line(Fnd_File.LOG, 'Checks Processed   : '||lpad(' ',18,' ')||l_tot_rec_count);
  Fnd_File.put_line(Fnd_File.LOG, 'Total Issued Amount: '||to_char(l_sum_pay_amount,'9,999,999,999,999.99'));
  Fnd_File.put_line(Fnd_File.LOG, '');
  Fnd_File.put_line(Fnd_File.LOG,'--------------------------------------------------------------------------------------------------------------------------------------------------');
  --End Loop; /* bank */

  UTL_FILE.FCLOSE(v_bank_file);

  COMMIT;

  DELETE FROM CUST.TTEC_PAY_BDO_BANK_EXTRACT_LOG
  WHERE CREATION_DATE < SYSDATE - 90;

  COMMIT;

EXCEPTION
    WHEN UTL_FILE.INVALID_OPERATION THEN
		UTL_FILE.FCLOSE(v_bank_file);
		RAISE_APPLICATION_ERROR(-20051, p_FileName ||':  Invalid Operation');
		ROLLBACK;
    WHEN UTL_FILE.INVALID_FILEHANDLE THEN
		UTL_FILE.FCLOSE(v_bank_file);
		RAISE_APPLICATION_ERROR(-20052, p_FileName ||':  Invalid File Handle');
		ROLLBACK;
    WHEN UTL_FILE.READ_ERROR THEN
		UTL_FILE.FCLOSE(v_bank_file);
		RAISE_APPLICATION_ERROR(-20053, p_FileName ||':  Read Error');
		ROLLBACK;
    WHEN UTL_FILE.INVALID_PATH THEN
		UTL_FILE.FCLOSE(v_bank_file);
		RAISE_APPLICATION_ERROR(-20054, p_FileDir ||':  Invalid Path');
		ROLLBACK;
    WHEN UTL_FILE.INVALID_MODE THEN
		UTL_FILE.FCLOSE(v_bank_file);
		RAISE_APPLICATION_ERROR(-20055, p_FileName ||':  Invalid Mode');
		ROLLBACK;
    WHEN UTL_FILE.WRITE_ERROR THEN
		UTL_FILE.FCLOSE(v_bank_file);
		RAISE_APPLICATION_ERROR(-20056, p_FileName ||':  Write Error');
		ROLLBACK;
    WHEN UTL_FILE.INTERNAL_ERROR THEN
		UTL_FILE.FCLOSE(v_bank_file);
  		RAISE_APPLICATION_ERROR(-20057, p_FileName ||':  Internal Error');
		ROLLBACK;
    WHEN UTL_FILE.INVALID_MAXLINESIZE THEN
    		UTL_FILE.FCLOSE(v_bank_file);
  		RAISE_APPLICATION_ERROR(-20058, p_FileName ||':  Maxlinesize Error');
		ROLLBACK;
    WHEN OTHERS THEN
        UTL_FILE.FCLOSE(v_bank_file);

        DBMS_OUTPUT.PUT_LINE('Operation fails on '||l_stage||' '||l_element||' '||l_key);

	    l_msg := SQLERRM;

        RAISE_APPLICATION_ERROR(-20003,'Exception OTHERS in gen_payment_file: '||l_msg);
		ROLLBACK;

END gen_payment_file;

END TTEC_BDO_PAYROLL_H2H_EXTRACT;