create or replace PACKAGE BODY      ttec_amex_payment_file
AS
   /*============================================================*\
     Author:  Christian Chan
       Date:  23-JUN-2005
       Desc:  This program generates a payment file to send to American Express
       Canada per Am Ex specifications - FINCAP80

     Modification History:

     Mod#    Date     Author    Description (Include Ticket#)
    -----  --------  --------  ----------------------------------------------
     1.0   06/23/05  Christian   Initial Script
     1.1   07/20/10  Kaushik   changed the query to generate credit number from AP_CARDS_ALL table instead of
                               from ap_invoice_all table. TTSD - 21365 - Opened SR 1302808281 by user to not to display
                               credit card numbers on the iexpense invoice in AP.
    1.2   08/03/10  Kaushik   To remove duplicates amounts on the output file TTSD I-298475
    1.3   12/21/10  Wasim Manasfi   - multi card programs
    1.4   04/10/2    Ravi Pasula   -- changed code to pull credit card number from right tale.
    1.5   08/25/14  CChan          -- Fix on duplicate
    1.6   04/12/16  CChan          -- Vendor ID and Site Code info provided at the parameter level were not used in the cursor.
                                      Default the vendor to AMERICAN EXPRESS if the parameter is not provided, to exclude
                                      payment made to employee from prior year with same document number(iKnowtion issue in PROD from Marshal email on 4/11/2016)
    1.7   10/05/16  CChan          -- Need to exclude PCARD for AMEX
    2.0   01/12/17  CChan         INC2654820 - Fix for iKnowtion - need ability to Generate AMEX Remittance (payment to iKnowtion), regardless if the card is ended from employee, who moved to Guidon from iKnowtion
    2.1   02/01/17  CChan          INC??????? - Get latest card assigned to the card holder regardless the card is ended or noy
	1.0	09-May-2023 IXPRAVEEN(ARGANO)   		R12.2 Upgrade Remediation
   \*=============================================================*/
   PROCEDURE gen_amex_pay_file(
      errcode               VARCHAR2
    , errbuff               VARCHAR2
    , p_vendor         IN   VARCHAR2
    , p_site           IN   VARCHAR2
    , p_check_number   IN   VARCHAR2 )
   IS
      --  Program to write out American Express paymement file per Am Ex specifications
      -- Individual bill/company data transmission
      --    Wasim Manasfi    July 19 2006
      ---- 3/1/2010    Wasim Manasfi    Added government soultions
      -- Filehandle Variables
      p_filedir                     VARCHAR2( 200 );
      p_filename                    VARCHAR2( 50 );
      p_country                     VARCHAR2( 10 );
      v_bank_file                   UTL_FILE.file_type;
      -- Declare variables
      l_msg                         VARCHAR2( 2000 );
      l_stage                       VARCHAR2( 400 );
      l_element                     VARCHAR2( 400 );
      l_rec                         VARCHAR2( 400 );
      l_key                         VARCHAR2( 400 );
      l_test_indicator              VARCHAR2( 4 ) := '  ';
      l_bank_account                VARCHAR2( 100 );
      l_file_num                    VARCHAR2( 4 ) := '01';
      l_tot_rec_count               NUMBER;
      l_sum_pos_pay_amount          NUMBER;
      l_check_number_hash_total     NUMBER;
      l_seq                         NUMBER;
      l_file_seq                    NUMBER;
      l_next_file_seq               NUMBER;
      l_test_flag                   VARCHAR2( 4 );
      l_program                     ap_card_programs_all.card_program_name%TYPE;
      l_load_num                    ap_card_programs_all.attribute1%TYPE;
      l_cid                         ap_card_programs_all.attribute2%TYPE;
      l_book_num                    ap_card_programs_all.attribute3%TYPE;
      l_card_program_id             ap_card_programs_all.card_program_id%TYPE;
      l_dum_char_1                  ap_invoices_all.invoice_num%TYPE;
      l_dum_char_2                  ap_cards_all.card_number%TYPE;
      l_dum_num_3                   NUMBER;
      l_dum_num_4                   NUMBER;
      l_check_num                   NUMBER;

            -- set directory destination for output file
            -- dire path this will be overwritten with new routine for getting CUST_TOP. Keep for file name
      --      CURSOR c_directory_path
      --      IS
      --         SELECT   NULL  directory_path,
      --                   'TTEC_'
      --                || 'US'
      --                || '_AMEX_PAY_'
      --                || LTRIM (RTRIM (p_check_number))
      --                || TO_CHAR (SYSDATE, '_MMDDYYYY')
      --                || '.out' file_name,
      --                'US' country
      --           FROM v$database;

      -- get Am Ex setup data
        --Version 1.1
      CURSOR c_setupinfo(
         p_card_program_id   IN   NUMBER )
      IS
         SELECT DISTINCT LPAD( acp.attribute1, 10, '0' ) loadnum
                       , acp.attribute2 cid
                       , acp.attribute3 book
         FROM            ap_card_programs_all acp
         WHERE           acp.card_program_currency_code = 'USD'
         AND             NVL( inactive_date, SYSDATE ) >= SYSDATE
         AND             acp.card_program_id = p_card_program_id;

      /* SELECT card_program_name, LPAD (attribute1, 10, '0') loadnum,
              attribute2 cid, attribute3 book
         FROM ap_card_programs_all
        WHERE card_program_name LIKE 'American Express-TeleTech US%'
           OR card_program_name LIKE 'AMEX GVT SOLUTIONS%';*/
      CURSOR c_header_record
      IS
         SELECT SYSDATE
         FROM   DUAL;

      -- get required info for transmission
      CURSOR c_detail_record_op4(
         p_check_num   IN   NUMBER )
      IS
         SELECT   ai.invoice_num
                , max(ic.ccnumber) card_number
                , aip.amount amount
                , ai.invoice_id   -- Version 1.2
                , aca.card_program_id
         FROM     ap_invoices_all ai
                , ap_invoice_payments_all aip
                , ap_checks_all ac
                , ap_expense_report_headers_all aeh
                --START R12.2 Upgrade Remediation
				/*, ap.AP_SUPPLIER_SITES_ALL assa			-- Commented code by IXPRAVEEN-ARGANO,09-May-2023
                ,   --Version 1.1
                  AP.AP_CARD_PROGRAMS_ALL acpa,-- 1.7*/
				, apps.AP_SUPPLIER_SITES_ALL assa			--  code Added by IXPRAVEEN-ARGANO,09-May-2023
                ,   --Version 1.1
                  apps.AP_CARD_PROGRAMS_ALL acpa,-- 1.7
				  --END R12.2.10 Upgrade remediation
                  ap_cards_all aca,  --Version 1.1
                  apps.iby_creditcard  ic
         WHERE    aip.invoice_id = ai.invoice_id
         AND      aip.check_id = ac.check_id
         AND      ai.invoice_num = aeh.invoice_num   --Version 1.1
         AND      aeh.employee_id = aca.employee_id   --Version 1.1
         AND       ic.instrid = aca.card_reference_id  --- 1.4
         AND acpa.card_program_name NOT LIKE '%PCARD%'         -- 1.7
         AND acpa.card_brand_lookup_code = 'American Express'  -- 1.7
         AND aca.card_program_id = acpa.CARD_PROGRAM_ID        -- 1.7
         AND      aca.ORG_ID = aeh.ORG_ID -- 1.5
         AND      ac.check_number = p_check_num   -- p_check_number
         --AND      aca.inactive_date IS NULL   --Version 1.2 /* 2.0 */
         AND acpa.ATTRIBUTE4 is not null
         and  aca.CREATION_DATE = (select max(aca1.creation_date)
                                   --from ap.ap_cards_all aca1		-- Commented code by IXPRAVEEN-ARGANO,09-May-2023
                                   from ap.ap_cards_all aca1		--  code Added by IXPRAVEEN-ARGANO,09-May-2023
                                   where aca1.employee_id = aca.employee_id
                                     and aca1.CARD_PROGRAM_ID = aca.CARD_PROGRAM_ID
                                     and aca1.ORG_ID = aeh.ORG_ID)
         AND      ai.VENDOR_SITE_ID = assa.VENDOR_SITE_ID --1.6
         AND      assa.VENDOR_SITE_CODE = NVL(p_site,assa.VENDOR_SITE_CODE) --1.6
         AND      aip.REMIT_TO_SUPPLIER_NAME = NVL(p_vendor,'AMERICAN, EXPRESS') -- 1.6
         AND      ai.set_of_books_id =
                     fnd_profile.value_specific( 'GL_SET_OF_BKS_ID'
                                               , NULL
                                               , fnd_global.resp_id
                                               , fnd_global.resp_appl_id )
         GROUP BY ai.invoice_num
                , aip.amount
                , ai.invoice_id
                , aca.card_program_id;   -- Version 1.2
   BEGIN
      apps.fnd_file.put_line( apps.fnd_file.LOG, ' begin ' );
      l_stage                      := 'c_directory_path';
      l_test_indicator             := 'TT';
      l_check_num                  := TO_NUMBER( p_check_number );
      -- OPEN c_directory_path;

      -- FETCH c_directory_path
       -- INTO p_filedir, p_filename, p_country;

      --      CLOSE c_directory_path;
      p_filedir                    :=
         ttec_library.get_directory( 'CUST_TOP' )
         || '/data/Payment_Interface/Amex_Pay/US/';
      p_filename                   :=
         'TTEC_US_AMEX_PAY_'
         || LTRIM( RTRIM( p_check_number ))
         || TO_CHAR( SYSDATE, '_MMDDYYYY' )
         || '.out';
      apps.fnd_file.put_line( apps.fnd_file.LOG, ' gooooooooood ' );

      OPEN c_detail_record_op4( l_check_num );

      FETCH c_detail_record_op4
      INTO  l_dum_char_1
          , l_dum_char_2
          , l_dum_num_3
          , l_dum_num_4
          , l_card_program_id;

      CLOSE c_detail_record_op4;

      apps.fnd_file.put_line( apps.fnd_file.LOG
                            , ' Start'
                              || TO_CHAR( l_card_program_id ));
      apps.fnd_file.put_line( apps.fnd_file.LOG
                            , ' Start'
                              || TO_CHAR( l_card_program_id ));

      OPEN c_setupinfo( l_card_program_id );

      FETCH c_setupinfo
      INTO  l_load_num
          , l_cid
          , l_book_num;

      CLOSE c_setupinfo;

      apps.fnd_file.put_line( apps.fnd_file.LOG, ' After setup ' );

      -- get seeded file number
      SELECT file_seq
           , test_flag
      INTO   l_file_seq
           , l_test_flag
      --FROM   cust.ttec_amex_pay_file_cntrl			-- Commented code by IXPRAVEEN-ARGANO,09-May-2023
      FROM   apps.ttec_amex_pay_file_cntrl              --  code Added by IXPRAVEEN-ARGANO,09-May-2023
      WHERE  ROWNUM = 1;

      apps.fnd_file.put_line( apps.fnd_file.LOG, ' after test  ' );
      l_test_flag                  := '  ';
      l_stage                      := 'c_open_file';
      v_bank_file                  :=
                                  UTL_FILE.fopen( p_filedir, p_filename, 'w' );
      fnd_file.put_line( fnd_file.LOG, '**********************************' );
      fnd_file.put_line( fnd_file.LOG
                       , 'Output file created >>> '
                         || p_filedir
                         || '/'
                         || p_filename );
      fnd_file.put_line( fnd_file.LOG, '**********************************' );
      l_next_file_seq              := NVL( l_file_seq, 1 );
      apps.fnd_file.put_line( apps.fnd_file.LOG, ' got the file name  ' );

      -- range between 1 and 99, then recycle
      IF l_file_seq > 99
      THEN
         l_next_file_seq    := 0;
      END IF;

      l_next_file_seq              := l_file_seq
                                      + 1;
      l_tot_rec_count              := 0;
      l_sum_pos_pay_amount         := 0;
      l_check_number_hash_total    := 0;
      -- set record type 1 all records 220 char long
      apps.fnd_file.put_line( apps.fnd_file.LOG, 'l_rec ' );
      l_rec                        :=
         '00'
         || l_load_num
         || TO_CHAR( SYSDATE, 'YYYYMMDD' )
         || l_cid
         || l_book_num
         || '00'
         || l_test_flag
         || LPAD( TO_CHAR( l_file_seq ), 2, '0' )
         || LPAD( ' ', 184, ' ' );
      l_stage                      := 'c_header';
      apps.fnd_file.put_line( apps.fnd_file.LOG, 'bgefore header ' );
      UTL_FILE.put_line( v_bank_file, l_rec );
      apps.fnd_file.put_line( apps.fnd_file.output, l_rec );

      -- loop on all invoices
      FOR pos_pay IN c_detail_record_op4( l_check_num )
      LOOP
         l_rec                   :=
            '10'
            || '-'
            || NVL( REPLACE( REPLACE( TO_CHAR( pos_pay.amount
                                             , 'S0000000000.00' )
                                    , '+'
                                    , NULL )
                           , '.'
                           , '' )
                  , LPAD( '0', 12, '0' ))
            || pos_pay.card_number
            || LPAD( ' ', 69, ' ' )
            || '01'
            || LPAD( ' ', 119, ' ' );
         l_stage                 := 'c_amount record';
         UTL_FILE.put_line( v_bank_file, l_rec );
         apps.fnd_file.put_line( apps.fnd_file.LOG, 'in loop  ' );
         apps.fnd_file.put_line( apps.fnd_file.output, l_rec );
         -- get totals
         l_sum_pos_pay_amount    :=
                               l_sum_pos_pay_amount
                               + NVL( pos_pay.amount, 0 );
         l_tot_rec_count         := l_tot_rec_count
                                    + 1;
         apps.fnd_file.put_line( apps.fnd_file.LOG, 'after rec count ' );
      END LOOP;

      --  Account Trailer Record
      l_stage                      := 'Trailer Record';
      l_rec                        :=
         '99'
         || ' '
         || NVL( REPLACE( REPLACE( TO_CHAR( l_sum_pos_pay_amount
                                          , 'S0000000000.00' )
                                 , '+'
                                 , NULL )
                        , '.'
                        , '' )
               , LPAD( '0', 12, '0' ))
         || NVL( REPLACE( REPLACE( TO_CHAR( l_tot_rec_count, 'S000000' )
                                 , '+'
                                 , NULL )
                        , '.'
                        , '' )
               , LPAD( '0', 6, '0' ))
         || ' '
         || LPAD( '0', 18, '0' )
         || LPAD( ' ', 180, ' ' );
      UTL_FILE.put_line( v_bank_file, l_rec );
      apps.fnd_file.put_line( apps.fnd_file.output, l_rec );
      UTL_FILE.fclose( v_bank_file );

      --UPDATE cust.ttec_amex_pay_file_cntrl			-- Commented code by IXPRAVEEN-ARGANO,09-May-2023
      UPDATE apps.ttec_amex_pay_file_cntrl              --  code Added by IXPRAVEEN-ARGANO,   09-May-2023
         SET file_seq = l_next_file_seq
       WHERE ROWNUM = 1;

      COMMIT;
   EXCEPTION
      WHEN UTL_FILE.invalid_operation
      THEN
         UTL_FILE.fclose( v_bank_file );
         raise_application_error( -20051
                                , p_filename
                                  || ':  Invalid Operation' );
         ROLLBACK;
      WHEN UTL_FILE.invalid_filehandle
      THEN
         UTL_FILE.fclose( v_bank_file );
         raise_application_error( -20052
                                , p_filename
                                  || ':  Invalid File Handle' );
         ROLLBACK;
      WHEN UTL_FILE.read_error
      THEN
         UTL_FILE.fclose( v_bank_file );
         raise_application_error( -20053, p_filename
                                   || ':  Read Error' );
         ROLLBACK;
      WHEN UTL_FILE.invalid_path
      THEN
         UTL_FILE.fclose( v_bank_file );
         raise_application_error( -20054, p_filedir
                                   || ':  Invalid Path' );
         ROLLBACK;
      WHEN UTL_FILE.invalid_mode
      THEN
         UTL_FILE.fclose( v_bank_file );
         raise_application_error( -20055, p_filename
                                   || ':  Invalid Mode' );
         ROLLBACK;
      WHEN UTL_FILE.write_error
      THEN
         UTL_FILE.fclose( v_bank_file );
         raise_application_error( -20056, p_filename
                                   || ':  Write Error' );
         ROLLBACK;
      WHEN UTL_FILE.internal_error
      THEN
         UTL_FILE.fclose( v_bank_file );
         raise_application_error( -20057, p_filename
                                   || ':  Internal Error' );
         ROLLBACK;
      WHEN UTL_FILE.invalid_maxlinesize
      THEN
         UTL_FILE.fclose( v_bank_file );
         raise_application_error( -20058
                                , p_filename
                                  || ':  Maxlinesize Error' );
         ROLLBACK;
      WHEN OTHERS
      THEN
         UTL_FILE.fclose( v_bank_file );
         l_msg    := SQLERRM;
         raise_application_error
            ( -20003
            , 'Exception OTHERS in American Express gen_positive_pay_file: '
              || l_msg );
         ROLLBACK;
   END gen_amex_pay_file;
END ttec_amex_payment_file;
/
show errors;
/