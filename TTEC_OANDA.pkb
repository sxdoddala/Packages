set define off;
create or replace PACKAGE BODY      ttec_oanda
AS
/* $Header: ttec_oanda.pks 1.1 2015/11/30 chchan ship $ */

   /*== START ================================================================================================*\
      Author: Christiane Chan
        Date: 2015/11/30
        Desc:  Library package to hold all Oanda related code.

     Modification History:

    Version    Date     Author   Description (Include Ticket#)
    -------  --------  --------  ------------------------------------------------------------------------------
        1.0  11/30/15  CChan     Initial Checked-In Version.
        1.1  01/04/16  CChan     Take out the date parameter when pulling the sysdate + 1 from the Oanda API call
                                 This way we do not have to wait until 8:00 PM MT to pull the Official Oanda
                                 next day rate. Oanda confirmed that 10:00 PM NY time to release the official rates
        1.2  01/19/16  CChan     Change the bat filename to sysdate when date parameter is null
		1.0  05/05/23  MXKEERTHI(ARGANO)                R12.2 Upgrade Remediation
*/
    PROCEDURE Gen_API_calls (  errcode            OUT VARCHAR2,
                               errbuff            OUT VARCHAR2,
                               p_conversion_date  IN VARCHAR2,
                               p_filepath         IN VARCHAR2,
                               p_filename         IN VARCHAR2,
                               p_API_CMD_STRING_1 IN VARCHAR2,
                               p_API_CMD_STRING_2 IN VARCHAR2,
                               p_API_CMD_STRING_3 IN VARCHAR2,
                               p_API_CMD_STRING_4 IN VARCHAR2,
                               p_API_CMD_STRING_5 IN VARCHAR2,
                               p_API_CMD_STRING_6 IN VARCHAR2,
                               p_API_CMD_STRING_7 IN VARCHAR2) IS

      v_get_weboutput_command VARCHAR2(10000);
      currency_code_list VARCHAR2(1022);
      v_conversion_date date;
      v_filename_date   date;
      v_cmd_string_3_5  VARCHAR2(100); /* 1.1 */
      v_filepath   VARCHAR2(240);
      v_filename   VARCHAR2(240);

      from_currency FND_CURRENCIES.CURRENCY_CODE%type;

       CURSOR get_from_currency IS
       SELECT DISTINCT currency_code FROM FND_CURRENCIES
       WHERE enabled_flag = 'Y'
       AND currency_flag = 'Y'
       AND NVL(end_date_active,'31-DEC-4712') >= v_conversion_date    /* V1.1 */
       AND NVL(start_date_active,'01-JAN-1000') <= v_conversion_date  /* V1.1 */
       AND currency_code != 'STAT' --Statistical Currency
       AND REGEXP_LIKE(currency_code,'[[:alpha:]]{3}') -- Makes sure the first 3 characters are Alpha
       AND length(currency_code) < 4  -- Makes sure the cirrency code is only 3 characters long.
       order by currency_code;


       CURSOR get_codes IS
       SELECT DISTINCT currency_code FROM FND_CURRENCIES
       WHERE enabled_flag = 'Y'
       AND currency_flag = 'Y'
       AND NVL(end_date_active,'31-DEC-4712') >= v_conversion_date    /* V1.1 */
       AND NVL(start_date_active,'01-JAN-1000') <= v_conversion_date  /* V1.1 */
       AND currency_code != 'STAT' --Statistical Currency
       --AND currency_code > from_currency
       AND REGEXP_LIKE(currency_code,'[[:alpha:]]{3}') -- Makes sure the first 3 characters are Alpha
       AND length(currency_code) < 4  -- Makes sure the cirrency code is only 3 characters long.
       ORDER BY currency_code;

       code_rec get_codes%ROWTYPE;

      output_file utl_file.file_type;



    BEGIN
     -- output_file := utl_file.fopen(ttec_library.get_directory('CUST_TOP')||'/data/OANDA/SEND',v_filename,'W',max_linesize => 32767);

      if p_conversion_date is null
      then
         v_conversion_date := trunc(sysdate + 1);
         v_filename_date   := trunc(sysdate); /* 1.2 */
         v_cmd_string_3_5  := ''; /* 1.1 */
      else
         --v_conversion_date := p_conversion_date;
         v_conversion_date := TO_CHAR (TO_DATE (p_conversion_date, 'MM/DD/YYYY'));
         v_filename_date   := v_conversion_date; /* 1.2 */
         v_cmd_string_3_5  := '&date='|| TO_CHAR(v_conversion_date,'YYYY-MM-DD'); /* 1.1 */
      end if;

      v_filepath := p_filepath;

      /* 1.2 Begin */
      --v_filename := p_filename||TO_CHAR(v_conversion_date, 'YYYYMMDD')||'.bat';
      v_filename := p_filename||TO_CHAR(v_filename_date, 'YYYYMMDD')||'.bat';
      /* 1.2 End */

      Fnd_File.put_line(Fnd_File.log, '====================');
      Fnd_File.put_line(Fnd_File.log, 'Parameters:');
      Fnd_File.put_line(Fnd_File.log, '====================');
      Fnd_File.put_line(Fnd_File.log, 'v_conversion_date...:'||v_conversion_date);
      Fnd_File.put_line(Fnd_File.log, 'v_filepath..........:'||p_filepath);
      Fnd_File.put_line(Fnd_File.log, 'v_filename..........:'||p_filename);
      Fnd_File.put_line(Fnd_File.log, 'v_filepath..........:'||v_filepath);
      Fnd_File.put_line(Fnd_File.log, 'v_filename..........:'||v_filename);
      Fnd_File.put_line(Fnd_File.log, 'v_cmd_string_1......:'||p_API_CMD_STRING_1);
      Fnd_File.put_line(Fnd_File.log, 'v_cmd_string_2......:'||p_API_CMD_STRING_2);
      Fnd_File.put_line(Fnd_File.log, 'v_cmd_string_3......:'||p_API_CMD_STRING_3);
      Fnd_File.put_line(Fnd_File.log, 'v_cmd_string_3_5....:'||v_cmd_string_3_5);
      Fnd_File.put_line(Fnd_File.log, 'v_cmd_string_4......:'||p_API_CMD_STRING_4);
      Fnd_File.put_line(Fnd_File.log, 'v_cmd_string_5......:'||p_API_CMD_STRING_5);
      Fnd_File.put_line(Fnd_File.log, 'v_cmd_string_6......:'||p_API_CMD_STRING_6);
      Fnd_File.put_line(Fnd_File.log, 'v_cmd_string_7......:'||p_API_CMD_STRING_7);

      output_file := utl_file.fopen(p_filepath,v_filename,'W',max_linesize => 32767);

      FOR v_from_currency in get_from_currency
      LOOP


          from_currency := v_from_currency.currency_code;
          Fnd_File.put_line(Fnd_File.log, 'from_currency..:'||from_currency);

          currency_code_list := '';

    --      OPEN get_codes;
    --       LOOP
    --          FETCH get_codes
    --          INTO code_rec;
    --          EXIT WHEN get_codes%NOTFOUND;
    --
    --         -- Fnd_File.put_line(Fnd_File.log, 'to_currency..:'||code_rec);
    --
    --          currency_code_list := currency_code_list||'&quote='||to_char(code_rec.currency_code);
    --
    --       END LOOP;
    --      CLOSE get_codes;

              FOR v_to_currency in get_codes
              LOOP
                currency_code_list := currency_code_list||'&quote='||to_char(v_to_currency.currency_code);
              END LOOP;

          Fnd_File.put_line(Fnd_File.log, 'to_currency_code_list..:'||currency_code_list);
      -- Remove last underscore
      --currency_code_list := SUBSTR(currency_code_list,1,LENGTH(currency_code_list)-1);

      IF currency_code_list IS NOT NULL THEN

    /*
          v_get_weboutput_command := '"E:\Inetpub\HirePoint\OANDA\WebOutput.exe"'                 || ' '||
                                     '"https://www.oanda.com/rates/api/v1/rates/'                 || v_from_currency.currency_code||
                                     '.csv?api_key=Teletech&decimal_places=all&date='             || TO_CHAR(v_conversion_date,'YYYY-MM-DD')||
                                     '&fields=averages'                                           || currency_code_list||
                                     '"'                                                          || ' '||
                                     '"E:\Inetpub\HirePoint\OANDA\TEST\RECEIVE\gl_exchange_rates_'|| v_from_currency.currency_code ||'_'||TO_CHAR(v_conversion_date, 'YYYYMMDD')||
                                     '.txt"';
    */

    Fnd_File.put_line(Fnd_File.log, 'conversion date..:'||TO_CHAR(v_conversion_date,'YYYY-MM-DD'));
         v_get_weboutput_command := p_API_CMD_STRING_1|| ' '||
                                     p_API_CMD_STRING_2|| v_from_currency.currency_code||
                                     p_API_CMD_STRING_3|| v_cmd_string_3_5||
                                     p_API_CMD_STRING_4|| currency_code_list||
                                     p_API_CMD_STRING_5|| ' '||
                                     p_API_CMD_STRING_6|| v_from_currency.currency_code ||'_'||TO_CHAR(v_conversion_date, 'YYYYMMDD')||
                                     p_API_CMD_STRING_7;


          Fnd_File.put_line(Fnd_File.output, v_get_weboutput_command);
          utl_file.put_line (output_file, v_get_weboutput_command);
      END IF;

      END LOOP;

      utl_file.fclose(output_file);


    EXCEPTION
     WHEN OTHERS THEN
         utl_file.fclose(output_file);
    END Gen_API_calls;

    PROCEDURE send_OANDA_email(v_email_recipients IN varchar2,
                               v_email_body_2     IN varchar2,
                               v_email_body_3     IN varchar2
    ) IS


      l_email_from                VARCHAR2 (256)
                                     := '@teletech.com';
      l_email_to                  VARCHAR2 (256) := v_email_recipients; --'christiane.chan@teletech.com, heathersuperchi@teletech.com';
      l_email_dir                 VARCHAR2 (256) := NULL;
      l_email_subj                VARCHAR2 (256) := NULL;
      l_email_body1               VARCHAR2 (256) := 'Please contact Oracle Finance Department Support and GL Rates Administrator.';
      l_email_body2               VARCHAR2 (256) := v_email_body_2;
      l_email_body3               VARCHAR2 (256) := v_email_body_3;
      l_email_body4               VARCHAR2 (256)
         := 'If you have any questions, please contact the Oracle Financial Support OR Oracle ERP Development team.';
      crlf                        CHAR (2) := CHR (10) || CHR (13);
      l_host_name                 VARCHAR2 (256);
      l_instance_name             VARCHAR2 (256);
      w_mesg                      VARCHAR2 (256);
      p_status                    NUMBER;

  -- declare cursors

    CURSOR c_host IS
    SELECT host_name,instance_name FROM v$instance;

    BEGIN
                 OPEN c_host;
                 FETCH c_host INTO l_host_name,l_instance_name;
                 CLOSE c_host;

/*       -- commented for ver 3.0
                 IF l_host_name <> 'den-erp046' THEN
                     IF l_host_name = 'den-erp042' THEN
                        l_email_subj := l_host_name|| ' PRE'||l_instance_name||' TESTING!! Please ignore... '||l_email_subj;
                     ELSIF l_host_name = 'den-erp092' and SUBSTR(l_instance_name,1,3) = 'DEV' THEN
                        l_email_subj := l_host_name|| ' IT'||l_instance_name||' TESTING!! Please ignore... '||l_email_subj;
                     ELSE
                        l_email_subj := l_host_name|| ' '||l_instance_name||' TESTING!! Please ignore... '||l_email_subj;
                     END IF;
                 END IF;
*/

                 IF l_host_name <> ttec_library.XX_TTEC_PROD_HOST_NAME THEN

                        l_email_subj := l_host_name|| '  '|| l_instance_name||' TESTING!! Please ignore... '||l_email_subj;
                 END IF;


                  send_email (
                     ttec_library.XX_TTEC_SMTP_SERVER, /*l_host_name,*/
                     l_host_name||l_email_from,
                     l_email_to,
                     NULL,
                     NULL,
                     l_email_subj,
                        crlf
                     || l_email_body1
                     || l_email_body2
                     || crlf
                     || l_email_body3
                     || crlf
                     || l_email_body4, -- NULL, --                        v_line1,
                     NULL,
                     NULL,
                     NULL,
                     NULL,
                     NULL,                             -- v_file_name,
                     NULL,
                     NULL,
                     NULL,
                     NULL,
                     p_status,
                     w_mesg);
    END;
   /*== START ================================================================================================*\
      Author: Christiane Chan

        Date: 2015/11/30

        Desc:  This procedure loads the rates from external_table into gl_daily_rates_interface table for oracle process.

        Call from: TeleTech Oanda Load Rates to GL Daily Rates Interface Table

        Parameter: p_conversion_date  - Conversion Date needs to be run.

        Modification History:

        Mod#  Date      Developer    Comments
       -----  --------- ------------ ---------------------------------------------
        1.0   11/30/15  CChan        Initial Checked-In Version.
\*== END ==================================================================================================*/
    PROCEDURE Load_rates_to_gl_daily_intf (errbuf                       OUT     VARCHAR2,
                                           retcode                      OUT     VARCHAR2,
                                           p_conversion_date            IN      VARCHAR2,
                                           p_enable_spot_rate_override  IN      VARCHAR2,
                                           p_email_recipients           IN      VARCHAR2
    )
    IS
       v_date                  DATE;
       v_oanda_original_rate   NUMBER;

       cannot_find_rate_to_override EXCEPTION;


       cursor get_override_rate IS
        SELECT SUBSTR (meaning, 1, 3) from_currency,
               SUBSTR (meaning, 5, 3) to_currency,
               TO_NUMBER (description) override_rate,
               flv.last_update_date override_last_upd_date
          FROM fnd_lookup_values flv
         WHERE flv.lookup_type = 'TTEC_GL_DAILY_RATE_OVERRIDE_SR'
           AND SUBSTR (meaning, 9, 4) = 'Spot'
           AND flv.LANGUAGE = 'US'
           AND flv.enabled_flag = 'Y'
           AND v_date BETWEEN flv.start_date_active AND NVL (flv.end_date_active, '31-DEC-4712');

    BEGIN

      IF p_conversion_date IS NULL THEN
         v_date := TRUNC(SYSDATE + 1);
      ELSE
         v_date := TO_DATE (p_conversion_date, 'MM/DD/YYYY');
      END IF;

      Fnd_File.put_line(Fnd_File.log, '====================');
      Fnd_File.put_line(Fnd_File.log, 'Parameters:');
      Fnd_File.put_line(Fnd_File.log, '====================');
      Fnd_File.put_line(Fnd_File.log, 'p_conversion_date.............:'||p_conversion_date);
      Fnd_File.put_line(Fnd_File.log, 'p_enable_spot_rate_override ..:'||p_enable_spot_rate_override );
      Fnd_File.put_line(Fnd_File.log, 'p_email_recipients............:'||p_email_recipients);
      Fnd_File.put_line(Fnd_File.log, 'Loading conversion date.......:'||v_date);

       apps.Fnd_File.put_line (apps.Fnd_File.log,'INSERT INTO gl.gl_daily_rates_interface');
	   --INSERT INTO gl.gl_daily_rates_interface  --Commented code by MXKEERTHI-ARGANO, 05/05/2023
       INSERT INTO apps.gl_daily_rates_interface --code added by MXKEERTHI-ARGANO, 05/05/2023
                    (from_currency, to_currency, from_conversion_date, to_conversion_date,
                    user_conversion_type, conversion_rate, mode_flag, user_id)
          SELECT base_from_currency, quote_to_currency, v_date, v_date, 'Spot', bid_conversion_rate, 'I',
                 fnd_profile.VALUE ('USER_ID')
		    --FROM cust.TTEC_OANDA_DAILY_RATES_API_STG      --Commented code by MXKEERTHI-ARGANO, 05/05/2023
              FROM apps.TTEC_OANDA_DAILY_RATES_API_STG      --code added by MXKEERTHI-ARGANO, 05/05/2023
 
                                                     --Version 2.0
           WHERE base_from_currency > quote_to_currency  -- Since we are overring from USD, it is a must to have the > here. this will get a unique combination of each currency. Version 2.1
             --AND file_process_time > TO_CHAR (SYSDATE - .25, 'YYYYMMDDhhmi')
             -- Will only capture data from a file ran in the last 6 hours.
             AND bid_conversion_rate > .00000000000;

        apps.Fnd_File.put_line (apps.Fnd_File.log,'IF p_enable_spot_rate_override = Y');

        IF p_enable_spot_rate_override = 'Y' THEN

           apps.Fnd_File.put_line (apps.Fnd_File.log,'FOR c_override in get_override_rate LOOP');
           FOR c_override in get_override_rate LOOP

             BEGIN

               BEGIN
                apps.Fnd_File.put_line (apps.Fnd_File.log,'get_oanda_original_rate');
                SELECT conversion_rate
                  INTO v_oanda_original_rate
				  --FROM gl.gl_daily_rates_interface dri --Commented code by MXKEERTHI-ARGANO, 05/05/2023
                    FROM apps.gl_daily_rates_interface dri --code added by MXKEERTHI-ARGANO, 05/05/2023
   
               
                 WHERE dri.from_currency = c_override.from_currency
                   AND dri.to_currency = c_override.to_currency
                   AND dri.user_conversion_type = 'Spot'
                   AND dri.to_conversion_date = v_date;


                EXCEPTION
                   WHEN NO_DATA_FOUND THEN
                           -- IF SQL%NOTFOUND THEN
                            apps.Fnd_File.put_line (apps.Fnd_File.log,'SQL NOTFOUND');
                            send_OANDA_email(p_email_recipients,'Please note that we cannot override the rate, due to rate is missing from the GL_DAILY_RATES_INTERFACE table','Take necessary action to end date the override rate or reload the SPOT rates for '||'Conversion_Date :'||v_date||' FROM_CURRENCY :'||c_override.from_currency||' TO_CURRENCY :'||c_override.to_currency);
                            RAISE_APPLICATION_ERROR(-20003,'Missing GL Spot Rate(s) to PROCESS......'||'Conversion_Date :'||v_date||' FROM_CURRENCY :'||c_override.from_currency||' TO_CURRENCY :'||c_override.to_currency);
                           -- END IF;
                   WHEN OTHERS THEN
                         apps.Fnd_File.put_line (apps.Fnd_File.log,'when others');
                END;

                apps.Fnd_File.put_line (apps.Fnd_File.log,'UPDATE gl.gl_daily_rates_interface');
				--UPDATE gl.gl_daily_rates_interface dri --Commented code by MXKEERTHI-ARGANO, 05/05/2023
                UPDATE apps.gl_daily_rates_interface dri   --code added by MXKEERTHI-ARGANO, 05/05/2023
   
                
                   SET dri.conversion_rate = c_override.override_rate,
                       dri.attribute1      = 'Y',
                       dri.attribute2      = v_oanda_original_rate
                 WHERE dri.from_currency = c_override.from_currency
                   AND dri.to_currency = c_override.to_currency
                   AND dri.user_conversion_type = 'Spot'
                   AND dri.to_conversion_date = v_date;

            apps.Fnd_File.put_line (apps.Fnd_File.log,'-----------------------------------------------------------------------');
            apps.Fnd_File.put_line (apps.Fnd_File.log,' Successfully Overrided>>>>>> Conversion_Date :'||v_date||' FROM_CURRENCY :'||c_override.from_currency||' TO_CURRENCY :'||c_override.to_currency);
            apps.Fnd_File.put_line (apps.Fnd_File.log,'                                 Original Rate:'||v_oanda_original_rate);
            apps.Fnd_File.put_line (apps.Fnd_File.log,'                                 Override Rate:'||c_override.override_rate);
             EXCEPTION WHEN cannot_find_rate_to_override THEN
                            apps.Fnd_File.put_line (apps.Fnd_File.log,'RAISED cannot_find_rate_to_override ');
                            send_OANDA_email(p_email_recipients,'Please note that we cannot override the rate, due to rate is missing from the GL_DAILY_RATES_INTERFACE table','Take necessary action to end date the override rate or reload the SPOT rates for '||'Conversion_Date :'||v_date||' FROM_CURRENCY :'||c_override.from_currency||' TO_CURRENCY :'||c_override.to_currency);
                            RAISE_APPLICATION_ERROR(-20003,'Missing GL Spot Rate(s) to PROCESS......'||'Conversion_Date :'||v_date||' FROM_CURRENCY :'||c_override.from_currency||' TO_CURRENCY :'||c_override.to_currency);
                       WHEN OTHERS THEN
                            NULL;
             END;


           END LOOP;
        END IF;
    EXCEPTION
       WHEN NO_DATA_FOUND
       THEN
          NULL;
       WHEN OTHERS
       THEN
          -- Consider logging the error and then re-raise
          RAISE;
    END Load_rates_to_gl_daily_intf;

END ttec_oanda;
/
show errors;
/