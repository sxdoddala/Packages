create or replace PACKAGE BODY TTEC_PAY_IFACE_KRONOS_DIRECT_2 IS

/*-----------------------------------------------------------------------
Program Name    : TTEC_PAY_IFACE_KRONOS_DIRECT_2
Desciption      : This is a copy of the pre-existing custom
   TTEC_PAY_IFACE_KRONOS_DIRECT.  The original package is called by the
   Kronos Connect process for all GBP2 (NZ, MY, HK) countries.  It creates
   a flat file of all payroll info for that country and pushes it to an
   external drive for the external payroll application to pick up and
   process.

   It has been modified to take Country Code instead of Business Group ID
   as input as Kronos will no longer maintain the BG ID.  The original
   version will remain in place so that KRONOS can cleanly transition from
   the prior version to the new when ready.

Modification Log:
Developer  Date        Description
---------  ----------  --------------------------------------------------
M Dodge    12/20/2007  Replace Business Group ID with Country Code param.
M Dodge    01/08/2008  Removed Purging of Prior Batches from KSS Interface.
M Dodge    02/19/2008  Removed Upper function on FND_Lookups select stmts
   for Lookup_type, lookup_code and Language to reenable indexes
                       Added Commit Points every 100 records.
                       Added TimeStamps to Logging.
Lalitha    08/21/2015  Rehosting changes for smtp
RXNETHI-ARGANO 05/15/2023  R12.2 Upgrade Remediation
-----------------------------------------------------------------------*/

/********************************************************************/
/* Log error message into KRONOS.KSS_PAYROLL_ERROR table            */
/* when fatal error occurs                                          */
/********************************************************************/
PROCEDURE log_kss_payroll_error
  (p_error_message IN varchar2
  ,p_error_record  IN varchar2
  )
IS

l_proc_name            varchar2(30) :=NULL;
l_pgm_loc              varchar2(10) :=NULL;
l_error_buffer         varchar2(2000) :=NULL;

BEGIN
 l_proc_name := 'log_kss_payroll_error';
 l_pgm_loc   := '100';

 --INSERT INTO KRONOS.KSS_PAYROLL_ERROR(BATCH_NAME,BATCH_DATE,RECORD_TRACK,MESSAGE,ERROR_RECORD) --code commented by RXNETHI-ARGANO,15/05/23
 INSERT INTO APPS.KSS_PAYROLL_ERROR(BATCH_NAME,BATCH_DATE,RECORD_TRACK,MESSAGE,ERROR_RECORD) --code added by RXNETHI-ARGANO,15/05/23
       VALUES ('KRONOS_BATCH_PROCESS',SYSDATE,G_BATCH_NAME,p_error_message,p_error_record);

 l_pgm_loc   := '200';

EXCEPTION
WHEN OTHERS THEN
 G_FATAL_ERROR := TRUE;
 l_error_buffer := 'ERROR in ' || G_PKG_NAME || '.' || l_proc_name || ' pgm_loc=' || l_pgm_loc || '-->' || SQLERRM;
 IF (UTL_FILE.IS_OPEN(G_LOG_FILE) AND G_LOG_FILE_W) THEN
   Printlog (G_LOG_FILE, l_error_buffer);
 END IF;

END log_kss_payroll_error;

/********************************************************************/
/* For fatal error, all rows insterted into table                   */
/* CUST.TTEC_PAY_IFACE_KSS_DIRECT_TBL based on                      */
/* KRONOS.KSS_PAYROLL_ORACLE table MANNUALLY deleted, before        */
/* saving (commit) logged error messages in table                   */
/* KRONOS.KSS_PAYROLL_ERROR.                                        */
/* Also, this routine try to make sure update DELETIONINDICATOR     */
/* value in KRONOS.KSS_PAYROLL_ORACLE table to 1, regardless        */
/* whatever happened - otherwise, it will cause problem in kronos   */
/* crystal control report.                                          */
/********************************************************************/
PROCEDURE delete_ttec_pay_iface_kss
IS

l_proc_name            varchar2(30)   :=NULL;
l_pgm_loc              varchar2(10)   :=NULL;
L_ERROR_RECORD         varchar2(2000) :=NULL;
L_ERROR_MESSAGE        varchar2(2000) :=NULL;

BEGIN

 l_proc_name := 'delete_ttec_pay_iface_kss';
 l_pgm_loc   := '100';

-- G_DELETE usally true in the exception of that processed batch_name is passed again by kronos connect process
-- in the above case, rows sholud not be deleted.
IF (G_DELETE) THEN
  DELETE
    --FROM CUST.TTEC_PAY_IFACE_KSS_DIRECT_TBL --code commented by RXNETHI-ARGANO,15/05/23
	FROM APPS.TTEC_PAY_IFACE_KSS_DIRECT_TBL --code added by RXNETHI-ARGANO,15/05/23
   WHERE upper(BATCH_NAME) = upper(G_BATCH_NAME);
END IF;

-- here try to make sure DELETIONINDICATOR updated as 1, regardless whatever happens
-- otherwise, kornos crystal control report will have prolem.
-- According to kornos team, restart will not be possible with failed batch name.
 l_pgm_loc   := '200';
 --UPDATE KRONOS.KSS_PAYROLL_ORACLE --code commented by RXNETHI-ARGANO,15/05/23
 UPDATE APPS.KSS_PAYROLL_ORACLE --code added by RXNETHI-ARGANO,15/05/23
    SET DELETIONINDICATOR='1'
  WHERE UPPER(BATCH_NAME) = UPPER(G_BATCH_NAME)
    AND DELETIONINDICATOR='0';

EXCEPTION
WHEN OTHERS THEN
 G_FATAL_ERROR := TRUE;
 L_ERROR_MESSAGE := 'Error --> '||SQLERRM;
 L_ERROR_RECORD := 'Deletion of CUST.TTEC_PAY_IFACE_KSS_DIRECT_TBL ' || 'in ' || G_PKG_NAME || '.' || l_proc_name || ' pgm_loc=' || l_pgm_loc;
 log_kss_payroll_error (L_ERROR_MESSAGE,L_ERROR_RECORD);
 IF (UTL_FILE.IS_OPEN(G_LOG_FILE) AND G_LOG_FILE_W) THEN
   Printlog (G_LOG_FILE, L_ERROR_RECORD);
   Printlog (G_LOG_FILE, L_ERROR_MESSAGE);
 END IF;

END delete_ttec_pay_iface_kss;

/********************************************************************/
/* Opens a file for writing.                                        */
/********************************************************************/
FUNCTION Open_File
  (p_file_name IN varchar2
  ,p_mode      IN varchar2
  )

Return Utl_File.FILE_TYPE
IS

l_proc_name            varchar2(30)   :=NULL;
l_pgm_loc              varchar2(10)   :=NULL;
L_ERROR_RECORD         varchar2(2000) :=NULL;
L_ERROR_MESSAGE        varchar2(2000) :=NULL;

x_file_name            varchar2(150);

BEGIN

 l_proc_name := 'Open_File';
 l_pgm_loc   := '100';
 x_file_name := p_file_name;

 return Utl_File.fopen(G_UTIL_FILE_OUT_DIR, x_file_name, p_mode);

EXCEPTION
WHEN UTL_FILE.INVALID_PATH THEN
 G_FATAL_ERROR := TRUE;
 L_ERROR_MESSAGE := 'Error --> '||SQLERRM;
 L_ERROR_RECORD := 'Opening flat file - INVALID_PATH ' || G_UTIL_FILE_OUT_DIR || ' in ' || G_PKG_NAME || '.' || l_proc_name || ' pgm_loc='
                   || l_pgm_loc;
 log_kss_payroll_error (L_ERROR_MESSAGE,L_ERROR_RECORD);

WHEN OTHERS THEN
 G_FATAL_ERROR := TRUE;
 L_ERROR_MESSAGE := 'Error --> '||SQLERRM;
 L_ERROR_RECORD := 'Opening flat file error mode=' || p_mode || ' ' || G_UTIL_FILE_OUT_DIR || '/' || x_file_name
                   || ' in ' || G_PKG_NAME || '.' || l_proc_name || ' pgm_loc=' || l_pgm_loc;
 log_kss_payroll_error (L_ERROR_MESSAGE,L_ERROR_RECORD);

END Open_File;

/********************************************************************/
/* Write one line to a target file.                                    */
/********************************************************************/
PROCEDURE Println
  ( p_target_file IN Utl_File.FILE_TYPE
   ,p_buffer      IN varchar2
  )

IS

l_proc_name            varchar2(30)   :=NULL;
l_pgm_loc              varchar2(10)   :=NULL;
L_ERROR_RECORD         varchar2(2000) :=NULL;
L_ERROR_MESSAGE        varchar2(2000) :=NULL;

BEGIN
 l_proc_name := 'Println';
 l_pgm_loc   := '100';

 Utl_File.put_line(p_target_file, p_buffer);

 l_pgm_loc   := '200';

EXCEPTION
WHEN OTHERS THEN
 G_FATAL_ERROR := TRUE;
 L_ERROR_MESSAGE := 'Error --> '||SQLERRM;
 L_ERROR_RECORD := 'Writing flat file error ' || 'in ' || G_PKG_NAME || '.' || l_proc_name || ' pgm_loc='
                   || l_pgm_loc;
 log_kss_payroll_error (L_ERROR_MESSAGE,L_ERROR_RECORD);

END Println;

/********************************************************************/
/* Append a TimeStamp to Log Output before writing to file          */
/********************************************************************/
PROCEDURE Printlog
  ( p_target_file IN Utl_File.FILE_TYPE
   ,p_buffer      IN varchar2
  )

IS

l_proc_name            varchar2(30)   :=NULL;
l_pgm_loc              varchar2(10)   :=NULL;

l_buffer               varchar2(2000) :=NULL;
L_ERROR_RECORD         varchar2(2000) :=NULL;
L_ERROR_MESSAGE        varchar2(2000) :=NULL;

BEGIN
 l_proc_name := 'Printlog';
 l_pgm_loc   := '100';

 l_buffer := to_char(sysdate,'HH24:MI:SS')||'->  '||p_buffer;
 Println(p_target_file, l_buffer);

 l_pgm_loc   := '200';

EXCEPTION
WHEN OTHERS THEN
 G_FATAL_ERROR := TRUE;
 L_ERROR_MESSAGE := 'Error --> '||SQLERRM;
 L_ERROR_RECORD := 'Writing flat file error ' || 'in ' || G_PKG_NAME || '.' || l_proc_name || ' pgm_loc='
                   || l_pgm_loc;
 log_kss_payroll_error (L_ERROR_MESSAGE,L_ERROR_RECORD);

END Printlog;

/********************************************************************/
/* Read one line from a target file.                                */
/* Called from send_email routine - uses G_EMAIL_ERROR              */
/* NOT USED ANY MORE - NOW USING APPS.SEND_EMAIL PROCEDURE...       */
/********************************************************************/
PROCEDURE Getln
  ( p_target_file  IN Utl_File.FILE_TYPE
   ,p_buffer      OUT varchar2
   ,p_eod_flag    OUT boolean
  )

IS

l_proc_name            varchar2(30)   :=NULL;
l_pgm_loc              varchar2(10)   :=NULL;
l_buffer               varchar2(2000) :=NULL;
l_eod_flag             boolean        :=FALSE;
L_ERROR_RECORD         varchar2(2000) :=NULL;
L_ERROR_MESSAGE        varchar2(2000) :=NULL;

BEGIN
 l_proc_name := 'Getln';
 l_pgm_loc   := '100';

  Begin
    Utl_File.get_line(p_target_file, l_buffer);
    p_buffer := l_buffer;
    p_eod_flag := l_eod_flag;

  l_pgm_loc   := '200';
  Exception
  When no_data_found then
   l_eod_flag := TRUE;
   p_eod_flag := l_eod_flag;
  End;

EXCEPTION
WHEN OTHERS THEN
 G_EMAIL_ERROR := TRUE;
 L_ERROR_MESSAGE := 'Error --> '||SQLERRM;
 L_ERROR_RECORD := 'Reading flat file error ' || 'in ' || G_PKG_NAME || '.' || l_proc_name || ' pgm_loc='
                   || l_pgm_loc;
 log_kss_payroll_error (L_ERROR_MESSAGE,L_ERROR_RECORD);

END Getln;

/********************************************************************/
/* Close target file.                                               */
/********************************************************************/
PROCEDURE Close_File
  (p_target_file IN OUT Utl_File.FILE_TYPE
  )

IS

l_proc_name            varchar2(30)   :=NULL;
l_pgm_loc              varchar2(10)   :=NULL;
L_ERROR_RECORD         varchar2(2000) :=NULL;
L_ERROR_MESSAGE        varchar2(2000) :=NULL;

BEGIN
 l_proc_name := 'Close_File';
 l_pgm_loc   := '100';
 Utl_File.fclose(p_target_file);

EXCEPTION
WHEN OTHERS THEN
 G_FATAL_ERROR := TRUE;
 L_ERROR_MESSAGE := 'Error --> '||SQLERRM;
 L_ERROR_RECORD := 'Closing flat file error ' || 'in ' || G_PKG_NAME || '.' || l_proc_name || ' pgm_loc=' || l_pgm_loc;
 log_kss_payroll_error (L_ERROR_MESSAGE,L_ERROR_RECORD);

END Close_File;

/********************************************************************/
/* Function  called by the other procedures to convert format of    */
/* H.HH to HMM format.                                              */
/********************************************************************/
FUNCTION format_h_dot_hh_hmm (iv_hours IN varchar2)
RETURN VARCHAR2
IS
l_hhh varchar2(3):= NULL;
l_mm  varchar2(2):= NULL;

BEGIN
select substr(to_char(iv_hours,'FM990.00'),1,instr(to_char(iv_hours,'FM990.00'),'.')-1)
      ,to_char(substr(to_char(iv_hours,'FM990.00'),instr(to_char(iv_hours,'FM990.00'),'.')+1)*60/100,'FM00')
into  l_hhh,l_mm
from dual;

IF l_hhh IS NULL and l_mm IS NULL THEN
return '000';
ELSE
return(l_hhh || l_mm);
END IF;

EXCEPTION
WHEN OTHERS THEN
return '000';

END format_h_dot_hh_hmm;

/********************************************************************/
/* Function  called by the other procedures to pad output field     */
/* with spaces for chanracter and number types.                     */
/********************************************************************/
FUNCTION  pad_data_output(iv_field_type   IN varchar2,
                          iv_pad_length   IN number,
                          iv_field_value  IN varchar2)
RETURN VARCHAR2
IS

  v_length_var  NUMBER;
  v_varchar_pad varchar2(1)   := ' ';
  v_number_pad  VARCHAR2(1)      := ' ';
  v_length_diff number  := 0;
  l_length_diff number:=0;

BEGIN
  IF upper(iv_field_type) = 'VARCHAR2' and iv_pad_length > 0 --and iv_field_value is not null
    THEN


       SELECT lengthb(iv_field_value) - length(iv_field_value)
         INTO l_length_diff
         FROM DUAL;

       return substrb(rpad( nvl(iv_field_value,' '), iv_pad_length, v_varchar_pad ),1,iv_pad_length+nvl(l_length_diff,0));

    ELSIF  UPPER(iv_field_type) = 'NUMBER' and iv_pad_length > 0 --AND iv_field_value IS NOT NULL
     THEN
        return lpad( nvl(iv_field_value,' '), iv_pad_length, v_number_pad );

  END IF;

  Exception
    When others then
        return null;

END pad_data_output;

/********************************************************************/
/* Push (copy) payroll output files to automounted dirctory via     */
/* submission of concurrent program TTEC_GBP2_PAY_DATA_PUSH (short  */
/* name) Teletech GBP2 Pay Data Push Process (conc pgm name)        */
/* Concurrent program will have 4 parameters                        */
/* payroll output directory (sourece of file), payroll file name,   */
/* leave file name, target_directory (place to copy files).         */
/* concurrent pgm is submitted by User APPSMGR.                     */
/********************************************************************/
PROCEDURE gbp2_pay_data_push
  ( p_out_dir     IN varchar2
   ,p_pay_file    IN varchar2
   ,p_lea_file    IN varchar2
   ,p_target_dir  IN varchar2
   ,p_push_status OUT varchar2)

IS
 l_proc_name            varchar2(30) :=NULL;
 l_pgm_loc              varchar2(10) :=NULL;
 L_ERROR_RECORD         varchar2(2000) :=NULL;
 L_ERROR_MESSAGE        varchar2(2000) :=NULL;

 l_req_id       NUMBER       := NULL;
 l_wait_outcome BOOLEAN;
 l_phase        VARCHAR2(80) := NULL;
 l_status       VARCHAR2(80) := NULL;
 l_dev_phase    VARCHAR2(80) := NULL;
 l_dev_status   VARCHAR2(80) := NULL;
 l_message      VARCHAR2(80) := NULL;

BEGIN
 l_proc_name := 'gbp2_pay_data_push';
 l_pgm_loc   := '100';

 -- DBMS_OUTPUT.PUT_LINE('before call fnd_conc_maintain.apps_initialize_for_mgr');
 fnd_conc_maintain.apps_initialize_for_mgr;
 l_pgm_loc   := '110';
 -- DBMS_OUTPUT.PUT_LINE('after call fnd_conc_maintain.apps_initialize_for_mgr');

 l_pgm_loc   := '120';
 l_req_id := fnd_request.submit_request(application => 'CUST',
                                        program     => 'TTEC_GBP2_PAY_DATA_PUSH',
                                        argument1   => p_out_dir,
                                        argument2   => p_pay_file,
                                        argument3   => p_lea_file,
                                        argument4   => p_target_dir
                                       );
 l_pgm_loc   := '130';

 -- DBMS_OUTPUT.PUT_LINE('after call fnd_request.submit_request');
 -- DBMS_OUTPUT.PUT_LINE('l_req_id=' || l_req_id);

 IF (l_req_id <= 0 or l_req_id is null) THEN
   l_pgm_loc   := '140';
   p_push_status := 'SUBMIT_FAIL';
 ELSE
   l_pgm_loc   := '150';
   COMMIT;
   l_pgm_loc   := '160';
   Printlog (G_LOG_FILE, pad_data_output('VARCHAR2',G_SIZE, '#### CONCURRENT REQUEST_ID=' || l_req_id || ' ####'));
   IF (G_FATAL_ERROR) THEN
     l_pgm_loc   := '165';
     RAISE G_PUSH_ABORT;
   END IF;

   -- DBMS_OUTPUT.PUT_LINE('before call fnd_concurrent.wait_for_request');
   l_pgm_loc   := '170';
   l_wait_outcome := fnd_concurrent.wait_for_request(
                            request_id => l_req_id,
                            interval   => 30,
                            max_wait   => G_CONC_MAX_WAIT,
                            phase      => l_phase,
                            status     => l_status,
                            dev_phase  => l_dev_phase,
                            dev_status => l_dev_status,
                            message    => l_message);
   l_pgm_loc   := '200';
   -- DBMS_OUTPUT.PUT_LINE('after call fnd_concurrent.wait_for_request');

   IF (l_dev_phase = 'COMPLETE' AND l_dev_status = 'NORMAL') THEN
     p_push_status := 'COMPLETE_NORMAL';
   ELSE
     p_push_status := 'COMPLETE_ERROR';
     Printlog (G_LOG_FILE, pad_data_output('VARCHAR2',G_SIZE, 'ERROR: REQUEST_ID=' || l_req_id || ' error=' || l_message));
       IF (G_FATAL_ERROR) THEN
         l_pgm_loc   := '210';
         RAISE G_PUSH_ABORT;
       END IF;
   END IF;
 END IF;

 -- DBMS_OUTPUT.PUT_LINE('l_dev_phase=' || l_dev_phase);
 -- DBMS_OUTPUT.PUT_LINE('l_dev_status=' || l_dev_status);
 -- DBMS_OUTPUT.PUT_LINE('l_phase=' || l_phase);
 -- DBMS_OUTPUT.PUT_LINE('l_status=' || l_status);
 -- DBMS_OUTPUT.PUT_LINE('l_message=' || l_message);

 EXCEPTION
  WHEN G_PUSH_ABORT THEN
   p_push_status := 'PUSH_ABORT_ERROR';
   L_ERROR_MESSAGE := 'Error --> '||SQLERRM;
   L_ERROR_RECORD := 'Error in ' || G_PKG_NAME || '.' || l_proc_name || ' pgm_loc=' || l_pgm_loc;
   log_kss_payroll_error (L_ERROR_MESSAGE,L_ERROR_RECORD);
   IF (UTL_FILE.IS_OPEN(G_LOG_FILE) AND G_LOG_FILE_W) THEN
     Printlog (G_LOG_FILE, L_ERROR_RECORD);
     Printlog (G_LOG_FILE, L_ERROR_MESSAGE);
   END IF;

  WHEN OTHERS THEN
   p_push_status := 'OTHER_ERROR';
   L_ERROR_MESSAGE := 'Error --> '||SQLERRM;
   L_ERROR_RECORD := 'Error in ' || G_PKG_NAME || '.' || l_proc_name || ' pgm_loc=' || l_pgm_loc;
   log_kss_payroll_error (L_ERROR_MESSAGE,L_ERROR_RECORD);
   IF (UTL_FILE.IS_OPEN(G_LOG_FILE) AND G_LOG_FILE_W) THEN
     Printlog (G_LOG_FILE, L_ERROR_RECORD);
     Printlog (G_LOG_FILE, L_ERROR_MESSAGE);
   END IF;
   -- DBMS_OUTPUT.PUT_LINE('other error occured xxx');

END gbp2_pay_data_push;

/********************************************************************/
/* Get Email address for the Lookup Type and Lookup Code provided
/********************************************************************/
FUNCTION get_email_addr
  ( p_lookup_type varchar2
   ,p_lookup_code varchar2
  ) RETURN VARCHAR2 IS

  l_email_addr fnd_lookup_values.description%TYPE;

BEGIN

  SELECT DESCRIPTION
    INTO l_email_addr
    FROM FND_LOOKUP_VALUES
   WHERE LOOKUP_TYPE = p_lookup_type
     AND LOOKUP_CODE = p_lookup_code
     AND upper(substr(replace(trim(MEANING),' ',''),1,4)) = G_SMTP_ENV
     AND LANGUAGE    = 'US'
     AND ENABLED_FLAG = 'Y'
     AND trunc(sysdate) between trunc(START_DATE_ACTIVE) AND TRUNC(NVL(END_DATE_ACTIVE,SYSDATE));

  RETURN l_email_addr;

EXCEPTION
  WHEN OTHERS THEN
    l_email_addr := NULL;
    RETURN l_email_addr;
END get_email_addr;

/********************************************************************/
/* Send Email to user via APPS.SEND_EMAIL procedure                 */
/* note: Global variable G_FATAL_ERROR is not used in routine       */
/********************************************************************/
PROCEDURE send_email
  ( p_business_group_name varchar2
   ,p_log_file_name       varchar2
   ,p_success_fail        varchar2
  )

IS

l_proc_name            varchar2(30)   :=NULL;
l_pgm_loc              varchar2(10)   :=NULL;
L_ERROR_RECORD         varchar2(2000) :=NULL;
L_ERROR_MESSAGE        varchar2(2000) :=NULL;

l_log_file_name        VARCHAR2(50)   :=NULL;
l_buffer               VARCHAR2(2000) :=NULL;
l_subject              VARCHAR2(200)  :=NULL;
l_from_email_addr      VARCHAR2(240)  :=NULL;
l_to_email_addr        VARCHAR2(240)  :=NULL;
l_cc_email_addr        VARCHAR2(240)  :=NULL;
l_pay_from_email_addr  VARCHAR2(240)  :=NULL;
l_pay_to_email_addr    VARCHAR2(1000) :=NULL;
l_pay_cc_email_addr    VARCHAR2(240)  :=NULL;
l_pay_to_all_email_addr VARCHAR2(1000) :=NULL;

l_smtp_server          VARCHAR2(30)   :=NULL;

l_email_error          NUMBER         :=NULL;
l_email_error_msg      varchar2(2000) :=NULL;

BEGIN
 l_proc_name := 'send_email';
 l_pgm_loc   := '005';

 l_log_file_name := p_log_file_name;
 -- when log file is closed, open it as append mode
 IF (l_log_file_name is NOT NULL) THEN
   IF (UTL_FILE.IS_OPEN(G_LOG_FILE) = FALSE) THEN
     l_pgm_loc   := '010';
     G_LOG_FILE := Utl_File.fopen(G_UTIL_FILE_OUT_DIR,l_log_file_name, 'A');
     G_LOG_FILE_W := TRUE;
   END IF;
 ELSE
   l_pgm_loc   := '020';
   RAISE G_EMAIL_ABORT;
 END IF;

 -- set email subject based on p_success_fail (S for success, F for failure)
 l_pgm_loc   := '030';
 IF (p_success_fail = 'F') THEN
   l_subject := 'FAILURE - PAYROLL INTERFACE for ' || p_business_group_name;
 END IF;

 IF (p_success_fail = 'SW') THEN
   l_subject := 'SUCCESS with WARNING - PAYROLL INTERFACE for ' || p_business_group_name;
 END IF;

 IF (p_success_fail = 'S') THEN
   l_subject := 'SUCCESS - PAYROLL INTERFACE for ' || p_business_group_name;
 END IF;

 l_pgm_loc   := '040';
 Printlog (G_LOG_FILE, '#### RETRIVING EMAIL ADDRESSES.... ####');

 -- get email addresses
 IF (trim(p_business_group_name) is NULL ) THEN
   l_pgm_loc   := '100';
   l_pay_from_email_addr := get_email_addr(G_HKG_EMAIL_LOOKUP, G_EMAIL_FROM_CODE);

   -- get HKG to_email addresses
   l_pgm_loc   := '120';
   l_to_email_addr := get_email_addr(G_HKG_EMAIL_LOOKUP, G_EMAIL_TO_CODE);

   l_pgm_loc   := '130';
   l_pay_to_email_addr := get_email_addr(G_HKG_EMAIL_LOOKUP, G_EMAIL_PAY_TO_CODE);

   IF (trim(l_pay_to_email_addr) is NULL) THEN
     l_pay_to_all_email_addr := l_to_email_addr;
   ELSE
     l_pay_to_all_email_addr := l_pay_to_email_addr;
   END IF;

   -- get MAL to_email addresses
   l_pgm_loc   := '135';
   l_to_email_addr := get_email_addr(G_MAL_EMAIL_LOOKUP, G_EMAIL_TO_CODE);

   l_pgm_loc   := '140';
   l_pay_to_email_addr := get_email_addr(G_MAL_EMAIL_LOOKUP, G_EMAIL_PAY_TO_CODE);

   IF (trim(l_pay_to_email_addr) is NULL) THEN
     IF (trim(l_to_email_addr) is NOT NULL) THEN
       l_pay_to_all_email_addr := l_pay_to_all_email_addr || ',' || l_to_email_addr;
     END IF;
   ELSE
     l_pay_to_all_email_addr := l_pay_to_all_email_addr || ',' || l_pay_to_email_addr;
   END IF;

   -- get SGP to_email addresses
   l_pgm_loc   := '145';
   l_to_email_addr := get_email_addr(G_SGP_EMAIL_LOOKUP, G_EMAIL_TO_CODE);

   l_pgm_loc   := '150';
   l_pay_to_email_addr := get_email_addr(G_SGP_EMAIL_LOOKUP, G_EMAIL_PAY_TO_CODE);

   IF (trim(l_pay_to_email_addr) is NULL) THEN
     IF (trim(l_to_email_addr) is NOT NULL) THEN
       l_pay_to_all_email_addr := l_pay_to_all_email_addr || ',' || l_to_email_addr;
     END IF;
   ELSE
     l_pay_to_all_email_addr := l_pay_to_all_email_addr || ',' || l_pay_to_email_addr;
   END IF;

   -- get NZ to_email addresses
   l_pgm_loc   := '155';
   l_to_email_addr := get_email_addr(G_NZ_EMAIL_LOOKUP, G_EMAIL_TO_CODE);

   l_pgm_loc   := '160';
   l_pay_to_email_addr := get_email_addr(G_NZ_EMAIL_LOOKUP, G_EMAIL_PAY_TO_CODE);

   IF (trim(l_pay_to_email_addr) is NULL) THEN
     IF (trim(l_to_email_addr) is NOT NULL) THEN
       l_pay_to_all_email_addr := l_pay_to_all_email_addr || ',' || l_to_email_addr;
     END IF;
   ELSE
     l_pay_to_all_email_addr := l_pay_to_all_email_addr || ',' || l_pay_to_email_addr;
   END IF;

   -- pass it to l_pay_to_email_addr
   l_pay_to_email_addr := l_pay_to_all_email_addr;

 END IF; -- IF (p_business_group_name is NULL )...

 IF (trim(p_business_group_name) = 'TeleTech Holdings - MAL' ) THEN
   l_pgm_loc   := '200';
   l_to_email_addr := get_email_addr(G_MAL_EMAIL_LOOKUP, G_EMAIL_TO_CODE);

   l_pgm_loc   := '210';
   l_from_email_addr := get_email_addr(G_MAL_EMAIL_LOOKUP, G_EMAIL_FROM_CODE);

   l_pgm_loc   := '220';
   l_cc_email_addr := get_email_addr(G_MAL_EMAIL_LOOKUP, G_EMAIL_CC_CODE);

   l_pgm_loc   := '230';
   l_pay_to_email_addr := get_email_addr(G_MAL_EMAIL_LOOKUP, G_EMAIL_PAY_TO_CODE);

   l_pgm_loc   := '240';
   l_pay_from_email_addr := get_email_addr(G_MAL_EMAIL_LOOKUP, G_EMAIL_PAY_FROM_CODE);

   l_pgm_loc   := '250';
   l_pay_cc_email_addr := get_email_addr(G_MAL_EMAIL_LOOKUP, G_EMAIL_PAY_CC_CODE);
 END IF;

 IF (trim(p_business_group_name) = 'TeleTech Holdings - SGP' ) THEN
   l_pgm_loc   := '300';
   l_to_email_addr := get_email_addr(G_SGP_EMAIL_LOOKUP, G_EMAIL_TO_CODE);

   l_pgm_loc   := '310';
   l_from_email_addr := get_email_addr(G_SGP_EMAIL_LOOKUP, G_EMAIL_FROM_CODE);

   l_pgm_loc   := '320';
   l_cc_email_addr := get_email_addr(G_SGP_EMAIL_LOOKUP, G_EMAIL_CC_CODE);

   l_pgm_loc   := '330';
   l_pay_to_email_addr := get_email_addr(G_SGP_EMAIL_LOOKUP, G_EMAIL_PAY_TO_CODE);

   l_pgm_loc   := '340';
   l_pay_from_email_addr := get_email_addr(G_SGP_EMAIL_LOOKUP, G_EMAIL_PAY_FROM_CODE);

   l_pgm_loc   := '350';
   l_pay_cc_email_addr := get_email_addr(G_SGP_EMAIL_LOOKUP, G_EMAIL_PAY_CC_CODE);
 END IF;

 IF (trim(p_business_group_name) = 'TeleTech Holdings - HKG' ) THEN
   l_pgm_loc   := '400';
   l_to_email_addr := get_email_addr(G_HKG_EMAIL_LOOKUP, G_EMAIL_TO_CODE);

   l_pgm_loc   := '410';
   l_from_email_addr := get_email_addr(G_HKG_EMAIL_LOOKUP, G_EMAIL_FROM_CODE);

   l_pgm_loc   := '420';
   l_cc_email_addr := get_email_addr(G_HKG_EMAIL_LOOKUP, G_EMAIL_CC_CODE);

   l_pgm_loc   := '430';
   l_pay_to_email_addr := get_email_addr(G_HKG_EMAIL_LOOKUP, G_EMAIL_PAY_TO_CODE);

   l_pgm_loc   := '440';
   l_pay_from_email_addr := get_email_addr(G_HKG_EMAIL_LOOKUP, G_EMAIL_PAY_FROM_CODE);

   l_pgm_loc   := '450';
   l_pay_cc_email_addr := get_email_addr(G_HKG_EMAIL_LOOKUP, G_EMAIL_PAY_CC_CODE);
 END IF;

 IF (trim(p_business_group_name) = 'TeleTech Holdings - NZ' ) THEN
   l_pgm_loc   := '500';
   l_to_email_addr := get_email_addr(G_NZ_EMAIL_LOOKUP, G_EMAIL_TO_CODE);

   l_pgm_loc   := '510';
   l_from_email_addr := get_email_addr(G_NZ_EMAIL_LOOKUP, G_EMAIL_FROM_CODE);

   l_pgm_loc   := '520';
   l_cc_email_addr := get_email_addr(G_NZ_EMAIL_LOOKUP, G_EMAIL_CC_CODE);

   l_pgm_loc   := '530';
   l_pay_to_email_addr := get_email_addr(G_NZ_EMAIL_LOOKUP, G_EMAIL_PAY_TO_CODE);

   l_pgm_loc   := '540';
   l_pay_from_email_addr := get_email_addr(G_NZ_EMAIL_LOOKUP, G_EMAIL_PAY_FROM_CODE);

   l_pgm_loc   := '550';
   l_pay_cc_email_addr := get_email_addr(G_NZ_EMAIL_LOOKUP, G_EMAIL_PAY_CC_CODE);
 END IF;

 -- When pay eamil address is null, default it with HR email address
 IF (trim(l_pay_from_email_addr) is NULL) THEN
   l_pay_from_email_addr := l_from_email_addr;
 END IF;

 IF (trim(l_pay_to_email_addr) is NULL) THEN
   l_pay_to_email_addr := l_to_email_addr;
 END IF;

 IF (trim(l_pay_cc_email_addr) is NULL) THEN
    l_pay_cc_email_addr := l_cc_email_addr;
 END IF;

 -- When both from and to email address are null, sending email will not work.
 IF (trim(l_pay_to_email_addr) is NULL AND trim(l_pay_from_email_addr) is NULL) THEN
    l_pgm_loc   := '589';
    RAISE G_EMAIL_ABORT;
 END IF;

 -- Try to default from or to email addresses, when either of it is missing...
 IF (trim(l_pay_to_email_addr) is NOT NULL and trim(l_pay_from_email_addr) is NULL) THEN
   -- try to default with the first l_pay_to_email_addr as from_email_address
   IF (instr(l_pay_to_email_addr, ',',1,1) = 0) THEN
     l_pay_from_email_addr := l_pay_to_email_addr;
   ELSE
     l_pay_from_email_addr := substr(l_pay_to_email_addr,1,instr(l_pay_to_email_addr,',',1,1) - 1);
   END IF;
 END IF;

 IF (trim(l_pay_to_email_addr) is NULL AND trim(l_pay_from_email_addr) is NOT NULL) THEN
   -- try to default with l_pay_from_email_addr as to_eamil_address
   l_pay_to_email_addr := l_pay_from_email_addr;
 END IF;


 IF (G_SMTP_ENV = 'PREP') THEN
   l_smtp_server := G_SMTP_SERVER_PREPROD;
 END IF;

 IF (G_SMTP_ENV = 'PROD') THEN
   l_smtp_server := G_SMTP_SERVER_PROD;
 END IF;

 l_pgm_loc   := '600';
 Printlog (G_LOG_FILE, 'SMTP Env=' || G_SMTP_ENV || ' SMTP Server=' || l_smtp_server);
 l_pgm_loc   := '610';
 Printlog (G_LOG_FILE, 'EMAIL ADDRESSES: From=' || l_pay_from_email_addr || ' To=' || l_pay_to_email_addr || ' CC=' || l_pay_cc_email_addr);

 -- before sending email with attachment of log file, it needs to closed first.
 l_pgm_loc   := '620';
 IF (UTL_FILE.IS_OPEN(G_LOG_FILE)) THEN
   Utl_File.fclose(G_LOG_FILE);
   G_LOG_FILE_W := FALSE;
 END IF;

 -- send email via APPS.SEND_EMAIL procedure
 l_pgm_loc   := '700';
 APPS.SEND_EMAIL ( ttec_library.XX_TTEC_SMTP_SERVER /* Rehosting project change for smtp */
                  --l_smtp_server
                  ,l_pay_from_email_addr
                  ,l_pay_to_email_addr
                  ,l_pay_cc_email_addr
                  ,NULL                      -- bcc_email
                  ,l_subject
                  ,'Please review attached log file for detail information.'
                  ,'   '
                  ,'Thanks'
                  ,NULL                      -- body line 4
                  ,NULL                      -- body line 5
                  ,G_UTIL_FILE_OUT_DIR || '/' || l_log_file_name
                  ,NULL                      -- attachment file name 2
                  ,NULL                      -- attachment file name 3
                  ,NULL                      -- attachment file name 4
                  ,NULL                      -- attachment file name 5
                  ,l_email_error
                  ,l_email_error_msg
                 );

 -- open log file as append mode, and log status of sending email operation
 l_pgm_loc   := '710';
 G_LOG_FILE := Utl_File.fopen(G_UTIL_FILE_OUT_DIR,l_log_file_name, 'A');
 G_LOG_FILE_W := TRUE;

 l_pgm_loc   := '720';
 IF (l_email_error != 0) THEN
   l_pgm_loc   := '730';
   Printlog (G_LOG_FILE, 'Error in APPS.SEND_EMAIL error msg=' || l_email_error_msg);
   RAISE G_EMAIL_ABORT;
 END IF;

 l_pgm_loc   := '800';
 Printlog (G_LOG_FILE, '#### EMAIL IS SENT TO ' || l_to_email_addr || ' SUCCESSFULLY.... ####');

EXCEPTION
WHEN G_EMAIL_ABORT THEN
 G_EMAIL_ERROR := TRUE;
 L_ERROR_MESSAGE := 'Error --> '||SQLERRM;
 L_ERROR_RECORD := 'Sending eamil Error in ' || G_PKG_NAME || '.' || l_proc_name || ' pgm_loc=' || l_pgm_loc;
 log_kss_payroll_error (L_ERROR_MESSAGE,L_ERROR_RECORD);
 IF (UTL_FILE.IS_OPEN(G_LOG_FILE) AND G_LOG_FILE_W) THEN
   Printlog (G_LOG_FILE, L_ERROR_RECORD);
   Printlog (G_LOG_FILE, L_ERROR_MESSAGE);
 END IF;

WHEN OTHERS THEN
 G_EMAIL_ERROR := TRUE;
 L_ERROR_MESSAGE := 'Error --> '||SQLERRM;
 L_ERROR_RECORD := 'Sending eamil error ' || 'in ' || G_PKG_NAME || '.' || l_proc_name || ' pgm_loc='
                   || l_pgm_loc;
 log_kss_payroll_error (L_ERROR_MESSAGE,L_ERROR_RECORD);
 IF (UTL_FILE.IS_OPEN(G_LOG_FILE) AND G_LOG_FILE_W) THEN
   Printlog (G_LOG_FILE, L_ERROR_RECORD);
   Printlog (G_LOG_FILE, L_ERROR_MESSAGE);
 END IF;

END send_email;

/********************************************************************/
/* Validate business group.                                         */
/********************************************************************/
FUNCTION validate_business_group
  (vBusGroup IN number
  )
Return varchar2
IS

l_proc_name            varchar2(30)   :=NULL;
l_pgm_loc              varchar2(10)   :=NULL;
L_ERROR_RECORD         varchar2(2000) :=NULL;
L_ERROR_MESSAGE        varchar2(2000) :=NULL;

l_business_group_name  PER_BUSINESS_GROUPS.NAME%TYPE :=NULL;

BEGIN
 l_proc_name := 'validate_business_group';
 l_pgm_loc   := '100';

  BEGIN
  SELECT NAME
    INTO l_business_group_name
    FROM PER_BUSINESS_GROUPS
   WHERE BUSINESS_GROUP_ID = vBusGroup
     AND NAME in ('TeleTech Holdings - MAL',
                  'TeleTech Holdings - SGP',
                  'TeleTech Holdings - HKG',
                  'TeleTech Holdings - NZ'
                 );

  l_pgm_loc   := '200';

  return l_business_group_name;

  EXCEPTION
  WHEN NO_DATA_FOUND THEN
    G_FATAL_ERROR := TRUE;
    l_pgm_loc   := '210';
    L_ERROR_MESSAGE := 'Error --> '||SQLERRM;
    L_ERROR_RECORD := 'Business group validation failed ' || 'in ' || G_PKG_NAME || '.' || l_proc_name || ' pgm_loc=' || l_pgm_loc;
    log_kss_payroll_error (L_ERROR_MESSAGE,L_ERROR_RECORD);
    IF (UTL_FILE.IS_OPEN(G_LOG_FILE) AND G_LOG_FILE_W) THEN
      Printlog (G_LOG_FILE, L_ERROR_RECORD);
      Printlog (G_LOG_FILE, L_ERROR_MESSAGE);
    END IF;
    l_business_group_name := NULL;
    return l_business_group_name;
  END;

EXCEPTION
WHEN OTHERS THEN
 G_FATAL_ERROR := TRUE;
 L_ERROR_MESSAGE := 'Error --> '||SQLERRM;
 L_ERROR_RECORD := 'Business group validation ' || 'in ' || G_PKG_NAME || '.' || l_proc_name || ' pgm_loc=' || l_pgm_loc;
 log_kss_payroll_error (L_ERROR_MESSAGE,L_ERROR_RECORD);
 IF (UTL_FILE.IS_OPEN(G_LOG_FILE) AND G_LOG_FILE_W) THEN
   Printlog (G_LOG_FILE, L_ERROR_RECORD);
   Printlog (G_LOG_FILE, L_ERROR_MESSAGE);
 END IF;

END validate_business_group;

/********************************************************************/
/* Procedure called by the other procedures to insert               */
/* table CUST.TTEC_PAY_IFACE_KSS_DIRECT_TBL                         */
/********************************************************************/
PROCEDURE insert_ttec_pay_pay_iface_kss
  --(ir_ttec_pay_pay_iface_kss CUST.TTEC_PAY_IFACE_KSS_DIRECT_TBL%ROWTYPE) --code commented by RXNETHI-ARGANO,15/05/23
  (ir_ttec_pay_pay_iface_kss APPS.TTEC_PAY_IFACE_KSS_DIRECT_TBL%ROWTYPE) --code added by RXNETHI-ARGANO,15/05/23

IS

l_proc_name            varchar2(30)   :=NULL;
l_pgm_loc              varchar2(10)   :=NULL;
L_ERROR_RECORD         varchar2(2000) :=NULL;
L_ERROR_MESSAGE        varchar2(2000) :=NULL;

BEGIN

 l_proc_name := 'insert_ttec_pay_pay_iface_kss';
 l_pgm_loc   := '100';

 INSERT
   --INTO CUST.TTEC_PAY_IFACE_KSS_DIRECT_TBL --code commented by RXNETHI-ARGANO,15/05/23
   INTO APPS.TTEC_PAY_IFACE_KSS_DIRECT_TBL --code added by RXNETHI-ARGANO,15/05/23
 VALUES ir_ttec_pay_pay_iface_kss;

 l_pgm_loc   := '200';
 IF G_COMMIT_CNTR >= G_COMMIT_POINT THEN
   COMMIT;
   G_COMMIT_CNTR := 1;
 ELSE
   G_COMMIT_CNTR := G_COMMIT_CNTR + 1;
 END IF;

EXCEPTION
WHEN OTHERS THEN
 G_FATAL_ERROR := TRUE;
 --DBMS_OUTPUT.PUT_LINE(' error on insert');
 L_ERROR_MESSAGE := 'Error --> '||SQLERRM;
 L_ERROR_RECORD := 'Insertion of CUST.TTEC_PAY_IFACE_KSS_DIRECT_TBL ' || 'in ' || G_PKG_NAME || '.' || l_proc_name || ' pgm_loc=' || l_pgm_loc;
 log_kss_payroll_error (L_ERROR_MESSAGE,L_ERROR_RECORD);
 IF (UTL_FILE.IS_OPEN(G_LOG_FILE) AND G_LOG_FILE_W) THEN
   Printlog (G_LOG_FILE, L_ERROR_RECORD);
   Printlog (G_LOG_FILE, L_ERROR_MESSAGE);
 END IF;

END insert_ttec_pay_pay_iface_kss;

/********************************************************************/
/* Payroll interface for Hong Kong, called by procedure             */
/* TTEC_PAY_IFACE_KRONOS_DIRECT                                     */
/********************************************************************/
PROCEDURE TTEC_HKG_PAY_IFACE
  (vBusGroup  IN number
  ,vBatchName IN varchar2
  ,v_payfile  OUT varchar2
  ,v_leafile  OUT varchar2
  )

IS

l_proc_name                  varchar2(30)   :=NULL;
l_pgm_loc                    varchar2(10)   :=NULL;
l_line_buffer                varchar2(2000) :=NULL;
L_ERROR_RECORD               varchar2(2000) :=NULL;
L_ERROR_MESSAGE              varchar2(2000) :=NULL;

l_out_pay_file_name          VARCHAR2(50)   :=NULL;
l_out_lea_file_name          VARCHAR2(50)   :=NULL;

l_rows_processed             number         :=0;
l_rows_lines_processed       number         :=0;

l_sequence_no                number         :=0;
-- l_last_element_name       varchar(60)    :=NULL;
l_last_assignment_number     varchar2(30)   :=NULL;
l_element_type_id            varchar2(60)   :=NULL;
l_assignment_id              varchar2(60)   :=NULL;

l_person_id                  PER_ALL_PEOPLE_F.PERSON_ID%TYPE :=NULL;
l_legacy_emp_number          PER_ALL_PEOPLE_F.ATTRIBUTE12%TYPE :=NULL;
--p
l_paycode_type               varchar2(10)   :=NULL;
l_unproc_cnt                 number :=0;
l_batch_h_cnt                number :=0;
l_batch_name_like            VARCHAR2(30) :=NULL;
l_ct_grand_tot               NUMBER(10,2) :=0.00;

-- Cursor for Getting the header records from the staging records.
CURSOR Kronos_Header_Csr(vBatchName varchar2) is
 SELECT Distinct *
   --FROM KRONOS.KSS_PAYROLL_ORACLE --code commented by RXNETHI-ARGANO,15/05/23
  FROM APPS.KSS_PAYROLL_ORACLE --code added by RXNETHI-ARGANO,15/05/23
  WHERE upper(BATCH_NAME) = upper(vBatchName)
    AND record_Track = 'H'
    AND DeletionIndicator=0 ;
Kronos_Header_Rec Kronos_Header_Csr%ROWTYPE;

-- Cursor for Getting the Line Records from the Staging Records, KRONOS.KSS_PAYROLL_ORACLE
CURSOR Kronos_Line_Csr(vBusGroup number, vBatchName varchar2) is
 SELECT
       KPO.BATCH_NAME,
       KPO.BATCH_DATE,
       KPO.RECORD_TRACK,
       KPO.ELEMENT_TYPE_ID,
       KPO.ASSIGNMENT_NUMBER,
       KPO.ASSIGNMENT_ID,
       KPO.ELEMENT_NAME,
       KPO.ENTRY_TYPE,
       KPO.REASON,
       KPO.VALUE_1,
       KPO.VALUE_2,
       KPO.VALUE_3,
       KPO.EFFECTIVE_DATE,
       KPO.DELETIONINDICATOR,
       KPO.EFFECTIVE_START_DATE,
       KPO.EFFECTIVE_END_DATE,
       KPO.LABORLEV3NM,
       KPO.LABORLEV3DSC,
       KPO.EMPLOYEENAME,
       KPO.COUNTRY,
       KPO.INTERFACE,
       KPO.RUNID,
       KPO.INTERFACE_TYPE
  FROM
       --KRONOS.KSS_PAYROLL_ORACLE KPO --code commented by RXNETHI-ARGANO,15/05/23
	   APPS.KSS_PAYROLL_ORACLE KPO --code added by RXNETHI-ARGANO,15/05/23
 WHERE upper(KPO.BATCH_NAME) = upper(vBatchName)
   AND KPO.RECORD_TRACK ='L'
   AND KPO.DELETIONINDICATOR=0
-- to get rid of null values of batch line row after discussion with kronos team.
   AND trim(KPO.ASSIGNMENT_NUMBER) is not null
   AND trim(KPO.ELEMENT_NAME) is not null
-- to get rid of null values of batch line row...
 ORDER BY KPO.BATCH_NAME, KPO.ASSIGNMENT_NUMBER, KPO.ELEMENT_NAME, KPO.EFFECTIVE_DATE;

 Kronos_Line_Rec  Kronos_Line_Csr%ROWTYPE;

 --r_ttec_pay_pay_iface_kss    CUST.TTEC_PAY_IFACE_KSS_DIRECT_TBL%ROWTYPE; --code commented by RXNETHI-ARGANO,15/05/23
 r_ttec_pay_pay_iface_kss    APPS.TTEC_PAY_IFACE_KSS_DIRECT_TBL%ROWTYPE; --code added by RXNETHI-ARGANO,15/05/23

-- Curssr for Getting the Line Records from CUST.TTEC_PAY_IFACE_KSS_DIRECT_TBL
CURSOR kss_direct_line_csr (vBatchName varchar2) is
 SELECT
       BATCH_NAME,
       BATCH_DATE,
       RECORD_TRACK,
       ELEMENT_TYPE_ID,
       ASSIGNMENT_NUMBER,
       ASSIGNMENT_ID,
       ELEMENT_NAME,
       ENTRY_TYPE,
       REASON,
       VALUE_1,
       VALUE_2,
       VALUE_3,
       EFFECTIVE_DATE,
       DELETIONINDICATOR,
       EFFECTIVE_START_DATE,
       EFFECTIVE_END_DATE,
       LABORLEV3NM,
       LABORLEV3DSC,
       EMPLOYEENAME,
       COUNTRY,
       INTERFACE,
       RUNID,
       BUSINESS_GROUP_ID,
       PERSON_ID,
       LEGACY_EMP_NUMBER,
       SEQUENCE_NUMBER,
       INTERFACE_TYPE,
       PAYCODE_TYPE
  FROM
       --CUST.TTEC_PAY_IFACE_KSS_DIRECT_TBL --code commented by RXNETHI-ARGANO,15/05/23
	   APPS.TTEC_PAY_IFACE_KSS_DIRECT_TBL --code added by RXNETHI-ARGANO,15/05/23
 WHERE upper(BATCH_NAME) = upper(vBatchName)
   AND RECORD_TRACK ='L'
   AND DELETIONINDICATOR=0
   AND LEGACY_EMP_NUMBER is NOT NULL
   AND trim(ELEMENT_NAME) is NOT NULL
   AND substr(PAYCODE_TYPE,1,1) in ('P', 'L', 'B')
 ORDER BY BATCH_NAME, LEGACY_EMP_NUMBER, ELEMENT_NAME, EFFECTIVE_DATE;

 kss_direct_line_rec kss_direct_line_csr%ROWTYPE;

-- Curssr for Getting UNPROCESSED line records from CUST.TTEC_PAY_IFACE_KSS_DIRECT_TBL
CURSOR kss_direct_line_unproc_csr (vBatchName varchar2) is
 SELECT
       BATCH_NAME,
       BATCH_DATE,
       RECORD_TRACK,
       ELEMENT_TYPE_ID,
       ASSIGNMENT_NUMBER,
       ASSIGNMENT_ID,
       ELEMENT_NAME,
       ENTRY_TYPE,
       REASON,
       VALUE_1,
       VALUE_2,
       VALUE_3,
       EFFECTIVE_DATE,
       DELETIONINDICATOR,
       EFFECTIVE_START_DATE,
       EFFECTIVE_END_DATE,
       LABORLEV3NM,
       LABORLEV3DSC,
       EMPLOYEENAME,
       COUNTRY,
       INTERFACE,
       RUNID,
       BUSINESS_GROUP_ID,
       PERSON_ID,
       LEGACY_EMP_NUMBER,
       SEQUENCE_NUMBER,
       INTERFACE_TYPE,
       PAYCODE_TYPE
  FROM
       --CUST.TTEC_PAY_IFACE_KSS_DIRECT_TBL --code commented by RXNETHI-ARGANO,15/05/23
	   APPS.TTEC_PAY_IFACE_KSS_DIRECT_TBL --code added by RXNETHI-ARGANO,15/05/23
 WHERE upper(BATCH_NAME) = upper(vBatchName)
   AND RECORD_TRACK ='L'
   AND DELETIONINDICATOR=0
 ORDER BY BATCH_NAME, LEGACY_EMP_NUMBER, ELEMENT_NAME, EFFECTIVE_DATE;

 kss_direct_line_unproc_rec kss_direct_line_unproc_csr%ROWTYPE;

-- Curssr for getting control totals based on pay codes from CUST.TTEC_PAY_IFACE_KSS_DIRECT_TBL
CURSOR kss_direct_ct_csr (vBatchName varchar2) is
 SELECT
       ELEMENT_NAME,
       sum(to_number(VALUE_1)) pay_code_ct_tot
  FROM
       --CUST.TTEC_PAY_IFACE_KSS_DIRECT_TBL --code commented by RXNETHI-ARGANO,15/05/23
	   APPS.TTEC_PAY_IFACE_KSS_DIRECT_TBL --code added by RXNETHI-ARGANO,15/05/23
 WHERE upper(BATCH_NAME) = upper(vBatchName)
   AND RECORD_TRACK ='L'
   AND DELETIONINDICATOR=1
 GROUP BY ELEMENT_NAME;

BEGIN
 l_proc_name := 'TTEC_HKG_PAY_IFACE';
 l_pgm_loc   := '100';

 Printlog (G_LOG_FILE, pad_data_output('VARCHAR2',G_SIZE,'#### START PROCESSING HKG PAYROLL INTERFACE.... ####'));
 IF (G_FATAL_ERROR) THEN
   l_pgm_loc   := '110';
   RAISE G_E_ABORT;
 END IF;

 -- format output file names
 l_out_pay_file_name := replace(trim(vBatchName), ' ', '_');
 l_out_pay_file_name := replace(l_out_pay_file_name, '/', '-');
 l_out_pay_file_name := replace(l_out_pay_file_name, ':', '_');
 l_out_lea_file_name := l_out_pay_file_name;
 l_out_pay_file_name := l_out_pay_file_name || '.pay';
 l_out_lea_file_name := l_out_lea_file_name || '.lea';

 v_payfile := l_out_pay_file_name;
 v_leafile := l_out_lea_file_name;

 -- Open output files
 l_pgm_loc   := '120';
 L_ERROR_RECORD:= 'Opening output file ' || l_out_pay_file_name;
 G_OUT_PAY_FILE := Open_File(l_out_pay_file_name, 'W');
 IF (G_FATAL_ERROR) THEN
   l_pgm_loc   := '130';
   RAISE G_E_ABORT;
 END IF;

 Printlog (G_LOG_FILE, pad_data_output('VARCHAR2',G_SIZE,'OUTPUT FILE DIRECTORY=' || G_UTIL_FILE_OUT_DIR));
 IF (G_FATAL_ERROR) THEN
   l_pgm_loc   := '135';
   RAISE G_E_ABORT;
 END IF;

 Printlog (G_LOG_FILE, pad_data_output('VARCHAR2',G_SIZE,'PAY OUTPUT FILE NAME=' || l_out_pay_file_name));
 IF (G_FATAL_ERROR) THEN
   l_pgm_loc   := '140';
   RAISE G_E_ABORT;
 END IF;

 l_pgm_loc   := '150';
 L_ERROR_RECORD:= 'Opening output file ' || l_out_lea_file_name;
 G_OUT_LEA_FILE := Open_File(l_out_lea_file_name, 'W');
 IF (G_FATAL_ERROR) THEN
   l_pgm_loc   := '160';
   RAISE G_E_ABORT;
 END IF;

 Printlog (G_LOG_FILE, pad_data_output('VARCHAR2',G_SIZE,'LEAVE OUTPUT FILE NAME=' || l_out_lea_file_name));
 IF (G_FATAL_ERROR) THEN
   l_pgm_loc   := '170';
   RAISE G_E_ABORT;
 END IF;

 Println (G_LOG_FILE, '                                                                                                                          ');
 IF (G_FATAL_ERROR) THEN
   l_pgm_loc   := '175';
   RAISE G_E_ABORT;
 END IF;

 Printlog (G_LOG_FILE, pad_data_output('VARCHAR2',G_SIZE,'#### START PROCESSING KRONOS.KSS_PAYROLL_ORACLE TABLE.... ####'));
 IF (G_FATAL_ERROR) THEN
   l_pgm_loc   := '180';
   RAISE G_E_ABORT;
 END IF;

 -- Check batch name in KRONOS.KSS_PAYROLL_ORACLE table if it is already processed before...
 l_pgm_loc   := '200';
 L_ERROR_RECORD:='Checking Batch header record count for batch ' || vBatchName || ' KRONOS.KSS_PAYROLL_ORACLE';
 SELECT count(*)
   INTO l_batch_h_cnt
   --FROM KRONOS.KSS_PAYROLL_ORACLE --code commented by RXNETHI-ARGANO,15/05/23
   FROM APPS.KSS_PAYROLL_ORACLE --code added by RXNETHI-ARGANO,15/05/23
  WHERE upper(BATCH_NAME) = upper(vBatchName)
    AND record_Track = 'H'
    AND DeletionIndicator = 0;

 l_pgm_loc   := '220';
 IF (l_batch_h_cnt = 0) THEN
    Printlog (G_LOG_FILE, 'WARNING: NO unprocessed batch header row exist in KRONOS.KSS_PAYROLL_ORACLE table - no payroll output files will be produced');
    IF (G_FATAL_ERROR) THEN
      l_pgm_loc   := '230';
      RAISE G_E_ABORT;
    END IF;
 END IF;

 -- Check batch name in CUST.TTEC_PAY_IFACE_KSS_DIRECT_TBL table if it is already processed before...
 l_batch_h_cnt := 0;
 l_pgm_loc   := '240';
 L_ERROR_RECORD:='Checking Batch header record count for batch ' || vBatchName || ' CUST.TTEC_PAY_IFACE_KSS_DIRECT_TBL';
 SELECT count(*)
  INTO l_batch_h_cnt
  --FROM CUST.TTEC_PAY_IFACE_KSS_DIRECT_TBL --code commented by RXNETHI-ARGANO,15/05/23
  FROM APPS.TTEC_PAY_IFACE_KSS_DIRECT_TBL --code added by RXNETHI-ARGANO,15/05/23
 WHERE upper(BATCH_NAME) = upper(vBatchName)
   AND record_Track = 'H'
   AND DeletionIndicator = 1;

 l_pgm_loc   := '250';
 IF (l_batch_h_cnt != 0) THEN
    G_DELETE := FALSE;
    Printlog (G_LOG_FILE, 'ERROR: KRONOS Batch name ' || vBatchName || ' already processed before in CUST.TTEC_PAY_IFACE_KSS_DIRECT_TBL');
    IF (G_FATAL_ERROR) THEN
      l_pgm_loc   := '260';
      RAISE G_E_ABORT;
    END IF;
    l_pgm_loc   := '270';
    RAISE G_E_ABORT;
 END IF;

 -- Delete Processed records before processing new records in KRONOS.KSS_PAYROLL_ORACLE table.
 -- When fatal error occurs after successful deletion, deletion of rows will be comitted.

 l_pgm_loc   := '280';
 l_batch_name_like := trim(substr(vBatchName, 0, 7)) || '%';

-- MDodge 01/08/08 Remove purging of KSS Table from code.
--   Kronos Connect will take care of the Purge from now on.
/*
 L_ERROR_RECORD:='Delete_batch_rows in KRONOS.KSS_PAYROLL_ORACLE for ' || l_batch_name_like;
 DELETE
   FROM KRONOS.KSS_PAYROLL_ORACLE
   WHERE BATCH_NAME like l_batch_name_like
    AND BATCH_NAME <> vBatchName and DELETIONINDICATOR='1';

 l_pgm_loc   := '290';
 Printlog (G_LOG_FILE, pad_data_output('VARCHAR2',G_SIZE,'#### ROWS DELETED IN KRONOS.KSS_PAYROLL_ORACLE TABLE for ' || l_batch_name_like || ' ####'));
 IF (G_FATAL_ERROR) THEN
   l_pgm_loc   := '300';
   RAISE G_E_ABORT;
 END IF;
*/

 -- Delete Processed records before processing new records in CUST.TTEC_PAY_IFACE_KSS_DIRECT_TBL table
 -- When fatal error occurs after successful deletion, deletion of rows will be comitted.
 l_pgm_loc   := '310';
 L_ERROR_RECORD:='Delete_batch_rows in CUST.TTEC_PAY_IFACE_KSS_DIRECT_TBL for ' || l_batch_name_like;
 DELETE
   --FROM CUST.TTEC_PAY_IFACE_KSS_DIRECT_TBL --code commented by RXNETHI-ARGANO,15/05/23
   FROM APPS.TTEC_PAY_IFACE_KSS_DIRECT_TBL --code added by RXNETHI-ARGANO,15/05/23
  WHERE BATCH_NAME like l_batch_name_like
    AND BATCH_NAME <> vBatchName and DELETIONINDICATOR='1';       -- remember that there is possibility to have DELETIONINDICATOR='0'
                                                                  -- which is unprocessed...

 l_pgm_loc   := '320';
 Printlog (G_LOG_FILE, pad_data_output('VARCHAR2',G_SIZE,'#### ROWS DELETED IN CUST.TTEC_PAY_IFACE_KSS_DIRECT_TBL TABLE for ' || l_batch_name_like || ' ####'));
 IF (G_FATAL_ERROR) THEN
   l_pgm_loc   := '330';
   RAISE G_E_ABORT;
 END IF;

 -- Now it is ok to process batch rows in KRONOS.KSS_PAYROLL_ORACLE table....
 -- Loop for the Header Records and process the Batch
 -- Batch header may not be needed for these countries, but process it to follow Kronos side.
 l_pgm_loc   := '400';
 FOR Kronos_Header_Rec IN Kronos_Header_Csr(vBatchName) LOOP
     -- insert batch header into CUST.TTEC_PAY_IFACE_KSS_DIRECT_TBL table
     l_pgm_loc   := '410';
     L_ERROR_RECORD:='Processing Batch header record for batch ' || vBatchName;

     r_ttec_pay_pay_iface_kss.BATCH_NAME                 := Kronos_Header_Rec.BATCH_NAME;
     r_ttec_pay_pay_iface_kss.BATCH_DATE                 := Kronos_Header_Rec.BATCH_DATE;
     r_ttec_pay_pay_iface_kss.RECORD_TRACK               := Kronos_Header_Rec.RECORD_TRACK;
     r_ttec_pay_pay_iface_kss.ELEMENT_TYPE_ID            := Kronos_Header_Rec.ELEMENT_TYPE_ID;
     r_ttec_pay_pay_iface_kss.ASSIGNMENT_NUMBER          := Kronos_Header_Rec.ASSIGNMENT_NUMBER;
     r_ttec_pay_pay_iface_kss.ASSIGNMENT_ID              := Kronos_Header_Rec.ASSIGNMENT_ID;
     r_ttec_pay_pay_iface_kss.ELEMENT_NAME               := Kronos_Header_Rec.ELEMENT_NAME;
     r_ttec_pay_pay_iface_kss.ENTRY_TYPE                 := Kronos_Header_Rec.ENTRY_TYPE;
     r_ttec_pay_pay_iface_kss.REASON                     := Kronos_Header_Rec.REASON;
     r_ttec_pay_pay_iface_kss.VALUE_1                    := Kronos_Header_Rec.VALUE_1;
     r_ttec_pay_pay_iface_kss.VALUE_2                    := Kronos_Header_Rec.VALUE_2;
     r_ttec_pay_pay_iface_kss.VALUE_3                    := Kronos_Header_Rec.VALUE_3;
     r_ttec_pay_pay_iface_kss.EFFECTIVE_DATE             := Kronos_Header_Rec.EFFECTIVE_DATE;
     r_ttec_pay_pay_iface_kss.DELETIONINDICATOR          := Kronos_Header_Rec.DELETIONINDICATOR;
     r_ttec_pay_pay_iface_kss.EFFECTIVE_START_DATE       := Kronos_Header_Rec.EFFECTIVE_START_DATE;
     r_ttec_pay_pay_iface_kss.EFFECTIVE_END_DATE         := Kronos_Header_Rec.EFFECTIVE_END_DATE;
     r_ttec_pay_pay_iface_kss.LABORLEV3NM                := Kronos_Header_Rec.LABORLEV3NM;
     r_ttec_pay_pay_iface_kss.LABORLEV3DSC               := Kronos_Header_Rec.LABORLEV3DSC;
     r_ttec_pay_pay_iface_kss.EMPLOYEENAME               := Kronos_Header_Rec.EMPLOYEENAME;
     r_ttec_pay_pay_iface_kss.COUNTRY                    := Kronos_Header_Rec.COUNTRY;
     r_ttec_pay_pay_iface_kss.INTERFACE                  := Kronos_Header_Rec.INTERFACE;
     r_ttec_pay_pay_iface_kss.RUNID                      := Kronos_Header_Rec.RUNID;

     r_ttec_pay_pay_iface_kss.BUSINESS_GROUP_ID          := vBusGroup;
     r_ttec_pay_pay_iface_kss.PERSON_ID                  := NULL;
     r_ttec_pay_pay_iface_kss.LEGACY_EMP_NUMBER          := NULL;
     r_ttec_pay_pay_iface_kss.SEQUENCE_NUMBER            := NULL;
     r_ttec_pay_pay_iface_kss.INTERFACE_TYPE             := Kronos_Header_Rec.INTERFACE_TYPE;
     r_ttec_pay_pay_iface_kss.PAYCODE_TYPE               := NULL;

     l_pgm_loc   := '420';
     insert_ttec_pay_pay_iface_kss (ir_ttec_pay_pay_iface_kss => r_ttec_pay_pay_iface_kss);
     IF (G_FATAL_ERROR) THEN
       l_pgm_loc   := '430';
       RAISE G_E_ABORT;
     END IF;

     l_pgm_loc   := '440';
     l_rows_processed := l_rows_processed + 1;

     -- Process the BATCH LINE record
     FOR Kronos_Line_Rec IN Kronos_Line_Csr(vBusGroup, vBatchName) LOOP
         l_pgm_loc   := '500';
         L_ERROR_RECORD:='KRONOS_LINE_CSR for batch ' || vBatchName;

         IF UPPER(Kronos_Line_Rec.assignment_number)=upper(l_last_assignment_number) THEN
           l_sequence_no :=l_sequence_no + 1;
         ELSE
           l_last_assignment_number:=trim(Kronos_Line_Rec.assignment_number);
           l_sequence_no :=1;
         END IF;

         -- get legacy employee number
         l_pgm_loc   := '510';
         Begin
           SELECT PAAF.PERSON_ID,
                  PAAF.ASSIGNMENT_ID,
                  PAPF.ATTRIBUTE12
             INTO
                  l_person_id,
                  l_assignment_id,
                  l_legacy_emp_number
             FROM
                  PER_ALL_ASSIGNMENTS_F PAAF,
                  PER_ALL_PEOPLE_F PAPF
            WHERE
                  PAAF.ASSIGNMENT_NUMBER = Kronos_Line_Rec.ASSIGNMENT_NUMBER
              AND PAAF.BUSINESS_GROUP_ID = vBusGroup
              AND (trunc(Kronos_Line_Rec.effective_date) BETWEEN trunc(PAAF.EFFECTIVE_START_DATE) AND trunc(PAAF.EFFECTIVE_END_DATE))
              AND PAAF.PERSON_ID = PAPF.PERSON_ID
              AND (trunc(Kronos_Line_Rec.effective_date) BETWEEN trunc(PAPF.EFFECTIVE_START_DATE) AND trunc(PAPF.EFFECTIVE_END_DATE));

         Exception
           When others Then
            G_WARNING           := TRUE;
            l_person_id         := NULL;
            l_assignment_id     := NULL;
            l_legacy_emp_number := NULL;
            Printlog (G_LOG_FILE, pad_data_output('VARCHAR2',G_SIZE,'WARNING: legacy employee number can not be found for ASSIGNMENT_NUMBER='
                                                 || Kronos_Line_Rec.ASSIGNMENT_NUMBER));
            IF (G_FATAL_ERROR) THEN
              l_pgm_loc   := '520';
              RAISE G_E_ABORT;
            END IF;
            Printlog (G_LOG_FILE, pad_data_output('VARCHAR2',G_SIZE,'WARNING: NULL legacy employee number is passed and will not be processed'));
            IF (G_FATAL_ERROR) THEN
              l_pgm_loc   := '525';
              RAISE G_E_ABORT;
            END IF;
         End;

         Begin
           SELECT upper(substr(trim(DESCRIPTION),1,1))
             INTO l_paycode_type
             FROM FND_LOOKUP_VALUES
            WHERE LOOKUP_TYPE = G_HKG_PAYCODES_LOOKUP
              AND LOOKUP_CODE = upper(trim(Kronos_Line_Rec.ELEMENT_NAME))
              AND LANGUAGE    = 'US'
              AND ENABLED_FLAG = 'Y'
              AND trunc(sysdate) between trunc(START_DATE_ACTIVE) AND TRUNC(NVL(END_DATE_ACTIVE,SYSDATE));

         Exception
           When others Then
            G_PAYCODE_FATAL := TRUE;
            l_paycode_type := NULL;
            Printlog (G_LOG_FILE, pad_data_output('VARCHAR2',G_SIZE,'WARNING: paycode type can not be found for PAY_CODE='
                                                 || Kronos_Line_Rec.ELEMENT_NAME || ', WILL NOT be processed'));
            IF (G_FATAL_ERROR) THEN
              l_pgm_loc   := '526';
              RAISE G_E_ABORT;
            END IF;
         End;

         r_ttec_pay_pay_iface_kss.BATCH_NAME                 := Kronos_Line_Rec.BATCH_NAME;
         r_ttec_pay_pay_iface_kss.BATCH_DATE                 := Kronos_Line_Rec.BATCH_DATE;
         r_ttec_pay_pay_iface_kss.RECORD_TRACK               := Kronos_Line_Rec.RECORD_TRACK;
         r_ttec_pay_pay_iface_kss.ELEMENT_TYPE_ID            := Kronos_Line_Rec.ELEMENT_TYPE_ID;
         r_ttec_pay_pay_iface_kss.ASSIGNMENT_NUMBER          := Kronos_Line_Rec.ASSIGNMENT_NUMBER;
         r_ttec_pay_pay_iface_kss.ASSIGNMENT_ID              := l_assignment_id;
         r_ttec_pay_pay_iface_kss.ELEMENT_NAME               := Kronos_Line_Rec.ELEMENT_NAME;
         r_ttec_pay_pay_iface_kss.ENTRY_TYPE                 := Kronos_Line_Rec.ENTRY_TYPE;
         r_ttec_pay_pay_iface_kss.REASON                     := Kronos_Line_Rec.REASON;
         r_ttec_pay_pay_iface_kss.VALUE_1                    := Kronos_Line_Rec.VALUE_1;
         r_ttec_pay_pay_iface_kss.VALUE_2                    := Kronos_Line_Rec.VALUE_2;
         r_ttec_pay_pay_iface_kss.VALUE_3                    := Kronos_Line_Rec.VALUE_3;
         r_ttec_pay_pay_iface_kss.EFFECTIVE_DATE             := Kronos_Line_Rec.EFFECTIVE_DATE;
         r_ttec_pay_pay_iface_kss.DELETIONINDICATOR          := Kronos_Line_Rec.DELETIONINDICATOR;
         r_ttec_pay_pay_iface_kss.EFFECTIVE_START_DATE       := Kronos_Line_Rec.EFFECTIVE_START_DATE;
         r_ttec_pay_pay_iface_kss.EFFECTIVE_END_DATE         := Kronos_Line_Rec.EFFECTIVE_END_DATE;
         r_ttec_pay_pay_iface_kss.LABORLEV3NM                := Kronos_Line_Rec.LABORLEV3NM;
         r_ttec_pay_pay_iface_kss.LABORLEV3DSC               := Kronos_Line_Rec.LABORLEV3DSC;
         r_ttec_pay_pay_iface_kss.EMPLOYEENAME               := Kronos_Line_Rec.EMPLOYEENAME;
         r_ttec_pay_pay_iface_kss.COUNTRY                    := Kronos_Line_Rec.COUNTRY;
         r_ttec_pay_pay_iface_kss.INTERFACE                  := Kronos_Line_Rec.INTERFACE;
         r_ttec_pay_pay_iface_kss.RUNID                      := Kronos_Line_Rec.RUNID;

         r_ttec_pay_pay_iface_kss.BUSINESS_GROUP_ID          := vBusGroup;
         r_ttec_pay_pay_iface_kss.PERSON_ID                  := l_person_id;
         r_ttec_pay_pay_iface_kss.LEGACY_EMP_NUMBER          := l_legacy_emp_number;
         r_ttec_pay_pay_iface_kss.SEQUENCE_NUMBER            := l_sequence_no;
         r_ttec_pay_pay_iface_kss.INTERFACE_TYPE             := Kronos_Line_Rec.INTERFACE_TYPE;
         r_ttec_pay_pay_iface_kss.PAYCODE_TYPE               := l_paycode_type;

         l_pgm_loc   := '530';
         insert_ttec_pay_pay_iface_kss (ir_ttec_pay_pay_iface_kss => r_ttec_pay_pay_iface_kss);
         IF (G_FATAL_ERROR) THEN
           l_pgm_loc   := '540';
           RAISE G_E_ABORT;
         END IF;

         l_rows_lines_processed := l_rows_lines_processed + 1;

     END LOOP; -- Kronos_Line_Rec IN Kronos_Line_Csr(vBusGroup, vBatchName)

 END LOOP; -- Kronos_Header_Rec IN Kronos_Header_Csr(vBatchName)

  l_pgm_loc   := '600';
  Printlog (G_LOG_FILE, pad_data_output('VARCHAR2',G_SIZE,'Total ' || l_rows_processed || ' Batch header rows processed in KRONOS.KSS_PAYROLL_ORACLE'));
  IF (G_FATAL_ERROR) THEN
    l_pgm_loc   := '610';
    RAISE G_E_ABORT;
  END IF;
  Printlog (G_LOG_FILE, pad_data_output('VARCHAR2',G_SIZE,'Total ' || l_rows_lines_processed || ' Batch line rows processed in KRONOS.KSS_PAYROLL_ORACLE'));
  IF (G_FATAL_ERROR) THEN
    l_pgm_loc   := '620';
    RAISE G_E_ABORT;
  END IF;

  -- issue warning when processed number of batch line row is zero.
  IF (l_rows_lines_processed = 0) THEN
    G_WARNING           := TRUE;
  END IF;

   -- Make rows (barch header and lines) in KRONOS.KSS_PAYROLL_ORACLE as processed.
   l_pgm_loc   := '700';
   L_ERROR_RECORD := 'Updating DELETIONINDICATOR column in KRONOS.KSS_PAYROLL_ORACLE table for batch ' || vBatchName;
   Printlog (G_LOG_FILE, pad_data_output('VARCHAR2',G_SIZE,'#### START UPDATING KRONOS.KSS_PAYROLL_ORACLE TABLE DELETIONINDICATOR.... ####'));
   IF (G_FATAL_ERROR) THEN
     l_pgm_loc   := '710';
     RAISE G_E_ABORT;
   END IF;

   l_pgm_loc   := '720';
   --UPDATE KRONOS.KSS_PAYROLL_ORACLE  --code commented by RXNETHI-ARGANO,15/05/23
   UPDATE APPS.KSS_PAYROLL_ORACLE      --code added by RXNETHI-ARGANO,15/05/23
      SET DELETIONINDICATOR='1'
    WHERE UPPER(BATCH_NAME) = UPPER(vBatchName);

   -- At this point entries in KRONOS.KSS_PAYROLL_ORACLE moved to table cust.ttec_pay_iface_kss_direct_tbl table..
   -- now process cust.ttec_pay_iface_kss_direct_tbl and generate output files for RECORD_TRACK ='L' only.
   -- hkgpay
   l_pgm_loc   := '800';
   L_ERROR_RECORD := 'PROCESSING CUST.TTEC_PAY_IFACE_KSS_DIRECT_TBL line records for batch ' || vBatchName;
   Printlog (G_LOG_FILE, pad_data_output('VARCHAR2',G_SIZE,'#### START PROCESSING CUST.TTEC_PAY_IFACE_KSS_DIRECT_TBL.... ####'));
   IF (G_FATAL_ERROR) THEN
     l_pgm_loc   := '810';
     RAISE G_E_ABORT;
   END IF;

   FOR kss_direct_line_rec IN  kss_direct_line_csr (vBatchName) LOOP
       -- produce leave output file based on pay codes..
       l_pgm_loc   := '900';
       IF (   substr(kss_direct_line_rec.PAYCODE_TYPE,1,1) = 'L'
           OR substr(kss_direct_line_rec.PAYCODE_TYPE,1,1) = 'B' ) THEN
         l_pgm_loc   := '910';

         -- data format of VALUE_3 from kronos is YYYY/MM/DD
         l_line_buffer := trim(kss_direct_line_rec.LEGACY_EMP_NUMBER)                                      || '|' ||
                          trim(kss_direct_line_rec.ELEMENT_NAME)                                           || '|' ||
                          to_char(to_date(trim(kss_direct_line_rec.VALUE_3), 'YYYY/MM/DD'), 'DD/MM/YYYY')  || '|' ||  -- start date
                          to_char(to_date(trim(kss_direct_line_rec.VALUE_3), 'YYYY/MM/DD'), 'DD/MM/YYYY')  || '|' ||  -- end date
                          to_char(kss_direct_line_rec.EFFECTIVE_DATE, 'DD/MM/YYYY')                        || '|' ||  -- posting date
                          trim(kss_direct_line_rec.VALUE_1);
         Println (G_OUT_LEA_FILE, l_line_buffer);
         IF (G_FATAL_ERROR) THEN
           l_pgm_loc   := '920';
           RAISE G_E_ABORT;
         END IF;
       END IF;  -- IF (substr(kss_direct_line_rec.PAYCODE_TYPE,1,1) = 'L' or 'B')

         -- produce pay output file, leave pay code does NOT go here..
       IF (   substr(kss_direct_line_rec.PAYCODE_TYPE,1,1) = 'P'
           OR substr(kss_direct_line_rec.PAYCODE_TYPE,1,1) = 'B' ) THEN
         l_pgm_loc   := '930';
         l_line_buffer := trim(kss_direct_line_rec.LEGACY_EMP_NUMBER) || '|' ||
                          trim(kss_direct_line_rec.ELEMENT_NAME)      || '|' ||
                          trim(kss_direct_line_rec.VALUE_1);
         Println (G_OUT_PAY_FILE, l_line_buffer);
         IF (G_FATAL_ERROR) THEN
           l_pgm_loc   := '940';
           RAISE G_E_ABORT;
         END IF;
       END IF;   -- IF (substr(kss_direct_line_rec.PAYCODE_TYPE,1,1) = 'P' or 'B')

       -- Update line rows as processed
       l_pgm_loc   := '950';
       --UPDATE CUST.TTEC_PAY_IFACE_KSS_DIRECT_TBL --code commented by RXNETHI-ARGANO,15/05/23
	   UPDATE APPS.TTEC_PAY_IFACE_KSS_DIRECT_TBL --code added by RXNETHI-ARGANO,15/05/23
          SET DELETIONINDICATOR = '1'
        WHERE UPPER(BATCH_NAME) = UPPER(vBatchName)
          AND RECORD_TRACK      ='L'
          AND LEGACY_EMP_NUMBER = kss_direct_line_rec.LEGACY_EMP_NUMBER
          AND ELEMENT_NAME      = kss_direct_line_rec.ELEMENT_NAME
          AND ASSIGNMENT_NUMBER = kss_direct_line_rec.ASSIGNMENT_NUMBER
          AND SEQUENCE_NUMBER   = kss_direct_line_rec.SEQUENCE_NUMBER;

       l_pgm_loc   := '952';
       l_ct_grand_tot := l_ct_grand_tot + to_number(trim(kss_direct_line_rec.VALUE_1));

   END LOOP; -- kss_direct_line_rec IN  kss_direct_line_csr (vBatchName)

   -- Update batch header row as processed in CUST.TTEC_PAY_IFACE_KSS_DIRECT_TBL
   l_pgm_loc   := '960';
   L_ERROR_RECORD := 'UPDATING CUST.TTEC_PAY_IFACE_KSS_DIRECT_TBL Header record for batch ' || vBatchName;
   Printlog (G_LOG_FILE, pad_data_output('VARCHAR2',G_SIZE,'#### START UPDATING CUST.TTEC_PAY_IFACE_KSS_DIRECT_TBL HEADER RECORD.... ####'));
   IF (G_FATAL_ERROR) THEN
     l_pgm_loc   := '970';
     RAISE G_E_ABORT;
   END IF;

   l_pgm_loc   := '980';
   --UPDATE CUST.TTEC_PAY_IFACE_KSS_DIRECT_TBL --code commented by RXNETHI-ARGANO,15/05/23
   UPDATE APPS.TTEC_PAY_IFACE_KSS_DIRECT_TBL --code added by RXNETHI-ARGANO,15/05/23
      SET DELETIONINDICATOR='1'
    WHERE UPPER(BATCH_NAME) = UPPER(vBatchName)
      AND RECORD_TRACK ='H';

   -- Report UNPROCESSED line records from CUST.TTEC_PAY_IFACE_KSS_DIRECT_TBL, if any...
   Println (G_LOG_FILE, '                                                                                                                         ');
   IF (G_FATAL_ERROR) THEN
     l_pgm_loc   := '985';
     RAISE G_E_ABORT;
   END IF;

   l_pgm_loc   := '990';
   L_ERROR_RECORD := 'REPORT UNPROCESSED CUST.TTEC_PAY_IFACE_KSS_DIRECT_TBL Line records for batch ' || vBatchName;
   Printlog (G_LOG_FILE, pad_data_output('VARCHAR2',G_SIZE,'#### REPORTING UNPROCESSED CUST.TTEC_PAY_IFACE_KSS_DIRECT_TBL LINE RECORDS.... ####'));
   IF (G_FATAL_ERROR) THEN
     l_pgm_loc   := '995';
     RAISE G_E_ABORT;
   END IF;

   Println (G_LOG_FILE, '=========================================================================================================================');
   IF (G_FATAL_ERROR) THEN
     l_pgm_loc   := '996';
     RAISE G_E_ABORT;
   END IF;

   l_pgm_loc   := '1000';
   FOR kss_direct_line_unproc_rec IN kss_direct_line_unproc_csr(vBatchName) LOOP
       l_unproc_cnt := l_unproc_cnt + 1;
       l_line_buffer := 'ASG_NUM='             || trim(kss_direct_line_unproc_rec.ASSIGNMENT_NUMBER) ||
                        ', LEGACY_EMP_NUM='    || trim(kss_direct_line_unproc_rec.LEGACY_EMP_NUMBER) ||
                        ', ELEMENT_NAME='      || trim(kss_direct_line_unproc_rec.ELEMENT_NAME)      ||
                        ', VALUE1='            || trim(kss_direct_line_unproc_rec.VALUE_1)           ||
                        ', VALUE3='            || trim(kss_direct_line_unproc_rec.VALUE_3)           ||
                        ', PAYCODE_TYPE='      || trim(kss_direct_line_unproc_rec.PAYCODE_TYPE);
       Println (G_LOG_FILE, pad_data_output('VARCHAR2',G_SIZE,l_line_buffer));
       IF (G_FATAL_ERROR) THEN
         l_pgm_loc   := '1010';
         RAISE G_E_ABORT;
       END IF;
   END LOOP;

   Println (G_LOG_FILE, pad_data_output('VARCHAR2',G_SIZE,'#### Total ' || l_unproc_cnt || ' UNPROCESSED LINE RECORDS....####'));
   IF (G_FATAL_ERROR) THEN
     l_pgm_loc   := '1020';
     RAISE G_E_ABORT;
   END IF;

   Println (G_LOG_FILE, '=========================================================================================================================');
   IF (G_FATAL_ERROR) THEN
     l_pgm_loc   := '1025';
     RAISE G_E_ABORT;
   END IF;

   Println (G_LOG_FILE, '                                                                                                                         ');
   IF (G_FATAL_ERROR) THEN
     l_pgm_loc   := '1030';
     RAISE G_E_ABORT;
   END IF;

   -- process control totals based on pay codes.
   Printlog (G_LOG_FILE, pad_data_output('VARCHAR2',G_SIZE,'#### REPORTING CONTROL TOTALS OF PROCESSED RECORDS.... ####'));
   IF (G_FATAL_ERROR) THEN
     l_pgm_loc   := '1100';
     RAISE G_E_ABORT;
   END IF;

   Println (G_LOG_FILE, '=========================================================================================================================');
   IF (G_FATAL_ERROR) THEN
     l_pgm_loc   := '1110';
     RAISE G_E_ABORT;
   END IF;

   l_line_buffer := pad_data_output('VARCHAR2',82,'PAY CODES/CATEGORY') || 'HOUR(H.HH)';
   Println (G_LOG_FILE, pad_data_output('VARCHAR2',G_SIZE,l_line_buffer));
   IF (G_FATAL_ERROR) THEN
     l_pgm_loc   := '1120';
     RAISE G_E_ABORT;
   END IF;

   l_line_buffer := '--------------------------------------------------------------------------------  ----------';
   Println (G_LOG_FILE, pad_data_output('VARCHAR2',G_SIZE,l_line_buffer));
   IF (G_FATAL_ERROR) THEN
     l_pgm_loc   := '1130';
     RAISE G_E_ABORT;
   END IF;

   l_pgm_loc   := '1140';
   l_line_buffer := pad_data_output('VARCHAR2',82,'GRAND TOTALS of Processed Records') ||
                    pad_data_output('NUMBER',10,to_char(l_ct_grand_tot, 'FM99999990.00'));

   Println (G_LOG_FILE, pad_data_output('VARCHAR2',G_SIZE,l_line_buffer));
   IF (G_FATAL_ERROR) THEN
     l_pgm_loc   := '1150';
     RAISE G_E_ABORT;
   END IF;

   l_pgm_loc   := '1160';
   FOR kss_direct_ct_rec IN kss_direct_ct_csr (vBatchName) LOOP
     l_line_buffer := pad_data_output('VARCHAR2',82,trim(kss_direct_ct_rec.ELEMENT_NAME))                   ||
                      pad_data_output('NUMBER',10,to_char(kss_direct_ct_rec.pay_code_ct_tot, 'FM99999990.00'));
     Println (G_LOG_FILE, pad_data_output('VARCHAR2',G_SIZE,l_line_buffer));
     IF (G_FATAL_ERROR) THEN
       l_pgm_loc   := '1170';
       RAISE G_E_ABORT;
     END IF;
   END LOOP;

   l_pgm_loc   := '1180';
   Println (G_LOG_FILE, '=========================================================================================================================');
   IF (G_FATAL_ERROR) THEN
     l_pgm_loc   := '1190';
     RAISE G_E_ABORT;
   END IF;

   Println (G_LOG_FILE, '                                                                                                                         ');
   IF (G_FATAL_ERROR) THEN
     l_pgm_loc   := '1195';
     RAISE G_E_ABORT;
   END IF;

EXCEPTION
WHEN G_E_ABORT THEN
 G_FATAL_ERROR := TRUE;
 L_ERROR_MESSAGE := 'Error --> '||SQLERRM;
 L_ERROR_RECORD := L_ERROR_RECORD || ' - Hong Kong Interface ' || 'in ' || G_PKG_NAME || '.' || l_proc_name || ' pgm_loc=' || l_pgm_loc;
 log_kss_payroll_error (L_ERROR_MESSAGE,L_ERROR_RECORD);
 IF (UTL_FILE.IS_OPEN(G_LOG_FILE) AND G_LOG_FILE_W) THEN
   Printlog (G_LOG_FILE, L_ERROR_RECORD);
   Printlog (G_LOG_FILE, L_ERROR_MESSAGE);
 END IF;

WHEN OTHERS THEN
 G_FATAL_ERROR := TRUE;
 L_ERROR_MESSAGE := 'Error --> '||SQLERRM;
 L_ERROR_RECORD := L_ERROR_RECORD || ' - Hong Kong Interface ' || 'in ' || G_PKG_NAME || '.' || l_proc_name || ' pgm_loc=' || l_pgm_loc;
 log_kss_payroll_error (L_ERROR_MESSAGE,L_ERROR_RECORD);
 IF (UTL_FILE.IS_OPEN(G_LOG_FILE) AND G_LOG_FILE_W) THEN
   Printlog (G_LOG_FILE, L_ERROR_RECORD);
   Printlog (G_LOG_FILE, L_ERROR_MESSAGE);
 END IF;

END TTEC_HKG_PAY_IFACE;

/********************************************************************/
/* Payroll interface for New Zealand, called by procedure           */
/* TTEC_PAY_IFACE_KRONOS_DIRECT                                     */
/********************************************************************/
PROCEDURE TTEC_NZ_PAY_IFACE
  (vBusGroup  IN number
  ,vBatchName IN varchar2
  ,v_payfile  OUT varchar2
  ,v_leafile  OUT varchar2
  )

IS

l_proc_name                  varchar2(30)   :=NULL;
l_pgm_loc                    varchar2(10)   :=NULL;
l_line_buffer                varchar2(2000) :=NULL;
L_ERROR_RECORD               varchar2(2000) :=NULL;
L_ERROR_MESSAGE              varchar2(2000) :=NULL;

l_out_pay_file_name          VARCHAR2(50)   :=NULL;
l_out_lea_file_name          VARCHAR2(50)   :=NULL;

l_rows_processed             number         :=0;
l_rows_lines_processed       number         :=0;

l_sequence_no                number         :=0;
-- l_last_element_name       varchar(60)    :=NULL;
l_last_assignment_number     varchar2(30)   :=NULL;
l_element_type_id            varchar2(60)   :=NULL;
l_assignment_id              varchar2(60)   :=NULL;

l_person_id                  PER_ALL_PEOPLE_F.PERSON_ID%TYPE :=NULL;
l_legacy_emp_number          PER_ALL_PEOPLE_F.ATTRIBUTE12%TYPE :=NULL;
l_paycode_type               varchar2(10)   :=NULL;
l_unproc_cnt                 number :=0;
l_batch_h_cnt                number :=0;
l_batch_name_like            VARCHAR2(30) :=NULL;
l_ct_grand_tot               NUMBER(10,2) :=0.00;

-- Cursor for Getting the header records from the staging records.
CURSOR Kronos_Header_Csr(vBatchName varchar2) is
 SELECT Distinct *
   --FROM KRONOS.KSS_PAYROLL_ORACLE --code commented by RXNETHI-ARGANO,15/05/23
   FROM APPS.KSS_PAYROLL_ORACLE --code added by RXNETHI-ARGANO,15/05/23
  WHERE upper(BATCH_NAME) = upper(vBatchName)
    AND record_Track = 'H'
    AND DeletionIndicator=0 ;
Kronos_Header_Rec Kronos_Header_Csr%ROWTYPE;

-- Cursor for Getting the Line Records from the Staging Records, KRONOS.KSS_PAYROLL_ORACLE
CURSOR Kronos_Line_Csr(vBusGroup number, vBatchName varchar2) is
 SELECT
       KPO.BATCH_NAME,
       KPO.BATCH_DATE,
       KPO.RECORD_TRACK,
       KPO.ELEMENT_TYPE_ID,
       KPO.ASSIGNMENT_NUMBER,
       KPO.ASSIGNMENT_ID,
       KPO.ELEMENT_NAME,
       KPO.ENTRY_TYPE,
       KPO.REASON,
       KPO.VALUE_1,
       KPO.VALUE_2,
       KPO.VALUE_3,
       KPO.EFFECTIVE_DATE,
       KPO.DELETIONINDICATOR,
       KPO.EFFECTIVE_START_DATE,
       KPO.EFFECTIVE_END_DATE,
       KPO.LABORLEV3NM,
       KPO.LABORLEV3DSC,
       KPO.EMPLOYEENAME,
       KPO.COUNTRY,
       KPO.INTERFACE,
       KPO.RUNID,
       KPO.INTERFACE_TYPE
  FROM
       --KRONOS.KSS_PAYROLL_ORACLE KPO --code commented by RXNETHI-ARGANO,15/05/23
	   APPS.KSS_PAYROLL_ORACLE KPO --code added by RXNETHI-ARGANO,15/05/23
 WHERE upper(KPO.BATCH_NAME) = upper(vBatchName)
   AND KPO.RECORD_TRACK ='L'
   AND KPO.DELETIONINDICATOR=0
-- to get rid of null values of batch line row after discussion with kronos team.
   AND trim(KPO.ASSIGNMENT_NUMBER) is not null
   AND trim(KPO.ELEMENT_NAME) is not null
-- to get rid of null values of batch line row...
 ORDER BY KPO.BATCH_NAME, KPO.ASSIGNMENT_NUMBER, KPO.ELEMENT_NAME, KPO.EFFECTIVE_DATE;

 Kronos_Line_Rec  Kronos_Line_Csr%ROWTYPE;

 --r_ttec_pay_pay_iface_kss    CUST.TTEC_PAY_IFACE_KSS_DIRECT_TBL%ROWTYPE;   --code commented by RXNETHI-ARGANO,15/05/23
 r_ttec_pay_pay_iface_kss    APPS.TTEC_PAY_IFACE_KSS_DIRECT_TBL%ROWTYPE;     --code added by RXNETHI-ARGANO,15/05/23

-- Curssr for Getting the Line Records from CUST.TTEC_PAY_IFACE_KSS_DIRECT_TBL
CURSOR kss_direct_line_csr (vBatchName varchar2) is
 SELECT
       BATCH_NAME,
       BATCH_DATE,
       RECORD_TRACK,
       ELEMENT_TYPE_ID,
       ASSIGNMENT_NUMBER,
       ASSIGNMENT_ID,
       ELEMENT_NAME,
       ENTRY_TYPE,
       REASON,
       VALUE_1,
       VALUE_2,
       VALUE_3,
       EFFECTIVE_DATE,
       DELETIONINDICATOR,
       EFFECTIVE_START_DATE,
       EFFECTIVE_END_DATE,
       LABORLEV3NM,
       LABORLEV3DSC,
       EMPLOYEENAME,
       COUNTRY,
       INTERFACE,
       RUNID,
       BUSINESS_GROUP_ID,
       PERSON_ID,
       LEGACY_EMP_NUMBER,
       SEQUENCE_NUMBER,
       Decode (INTERFACE_TYPE, 1, 'N',
                               2, 'A',
                               3, 'N', NULL) decoded_interface_type,
      PAYCODE_TYPE
  FROM
       --CUST.TTEC_PAY_IFACE_KSS_DIRECT_TBL --code commented by RXNETHI-ARGANO,15/05/23
	   APPS.TTEC_PAY_IFACE_KSS_DIRECT_TBL --code added by RXNETHI-ARGANO,15/05/23
 WHERE upper(BATCH_NAME) = upper(vBatchName)
   AND RECORD_TRACK ='L'
   AND DELETIONINDICATOR=0
   AND LEGACY_EMP_NUMBER is NOT NULL
   AND trim(ELEMENT_NAME) is NOT NULL
   AND substr(PAYCODE_TYPE,1,1) in ('P', 'L', 'B')
 ORDER BY BATCH_NAME, LEGACY_EMP_NUMBER, ELEMENT_NAME, EFFECTIVE_DATE;

 kss_direct_line_rec kss_direct_line_csr%ROWTYPE;

-- Curssr for Getting UNPROCESSED line records from CUST.TTEC_PAY_IFACE_KSS_DIRECT_TBL
CURSOR kss_direct_line_unproc_csr (vBatchName varchar2) is
 SELECT
       BATCH_NAME,
       BATCH_DATE,
       RECORD_TRACK,
       ELEMENT_TYPE_ID,
       ASSIGNMENT_NUMBER,
       ASSIGNMENT_ID,
       ELEMENT_NAME,
       ENTRY_TYPE,
       REASON,
       VALUE_1,
       VALUE_2,
       VALUE_3,
       EFFECTIVE_DATE,
       DELETIONINDICATOR,
       EFFECTIVE_START_DATE,
       EFFECTIVE_END_DATE,
       LABORLEV3NM,
       LABORLEV3DSC,
       EMPLOYEENAME,
       COUNTRY,
       INTERFACE,
       RUNID,
       BUSINESS_GROUP_ID,
       PERSON_ID,
       LEGACY_EMP_NUMBER,
       SEQUENCE_NUMBER,
       INTERFACE_TYPE,
       PAYCODE_TYPE
  FROM
       --CUST.TTEC_PAY_IFACE_KSS_DIRECT_TBL --code commented by RXNETHI-ARGANO,15/05/23
	   APPS.TTEC_PAY_IFACE_KSS_DIRECT_TBL --code added by RXNETHI-ARGANO,15/05/23
 WHERE upper(BATCH_NAME) = upper(vBatchName)
   AND RECORD_TRACK ='L'
   AND DELETIONINDICATOR=0
 ORDER BY BATCH_NAME, LEGACY_EMP_NUMBER, ELEMENT_NAME, EFFECTIVE_DATE;

 kss_direct_line_unproc_rec kss_direct_line_unproc_csr%ROWTYPE;

-- Curssr for getting control totals based on pay codes from CUST.TTEC_PAY_IFACE_KSS_DIRECT_TBL
CURSOR kss_direct_ct_csr (vBatchName varchar2) is
 SELECT
       ELEMENT_NAME,
       sum(to_number(VALUE_1)) pay_code_ct_tot
  FROM
       --CUST.TTEC_PAY_IFACE_KSS_DIRECT_TBL --code commented by RXNETHI-ARGANO,15/05/23
	   APPS.TTEC_PAY_IFACE_KSS_DIRECT_TBL --code added by RXNETHI-ARGANO,15/05/23
 WHERE upper(BATCH_NAME) = upper(vBatchName)
   AND RECORD_TRACK ='L'
   AND DELETIONINDICATOR=1
 GROUP BY ELEMENT_NAME;

BEGIN
 l_proc_name := 'TTEC_NZ_PAY_IFACE';
 l_pgm_loc   := '100';

 Printlog (G_LOG_FILE, pad_data_output('VARCHAR2',G_SIZE,'#### START PROCESSING NZ PAYROLL INTERFACE.... ####'));
 IF (G_FATAL_ERROR) THEN
   l_pgm_loc   := '110';
   RAISE G_E_ABORT;
 END IF;

 -- format output file names (NZ payroll vendor 8 characters - NZmmddyy with .pay and .lev)
 l_out_pay_file_name := 'NZ' || to_char(sysdate, 'MMDDYY') || '.pay';
 l_out_lea_file_name := 'NZ' || to_char(sysdate, 'MMDDYY') || '.lev';

 v_payfile := l_out_pay_file_name;
 v_leafile := l_out_lea_file_name;

 -- Open output files
 l_pgm_loc   := '120';
 L_ERROR_RECORD:= 'Opening output file ' || l_out_pay_file_name;
 G_OUT_PAY_FILE := Open_File(l_out_pay_file_name, 'W');
 IF (G_FATAL_ERROR) THEN
   l_pgm_loc   := '130';
   RAISE G_E_ABORT;
 END IF;

 Printlog (G_LOG_FILE, pad_data_output('VARCHAR2',G_SIZE,'OUTPUT FILE DIRECTORY=' || G_UTIL_FILE_OUT_DIR));
 IF (G_FATAL_ERROR) THEN
   l_pgm_loc   := '135';
   RAISE G_E_ABORT;
 END IF;

 Printlog (G_LOG_FILE, pad_data_output('VARCHAR2',G_SIZE,'PAY OUTPUT FILE NAME=' || l_out_pay_file_name));
 IF (G_FATAL_ERROR) THEN
   l_pgm_loc   := '140';
   RAISE G_E_ABORT;
 END IF;

 l_pgm_loc   := '150';
 L_ERROR_RECORD:= 'Opening output file ' || l_out_lea_file_name;
 G_OUT_LEA_FILE := Open_File(l_out_lea_file_name, 'W');
 IF (G_FATAL_ERROR) THEN
   l_pgm_loc   := '160';
   RAISE G_E_ABORT;
 END IF;

 Printlog (G_LOG_FILE, pad_data_output('VARCHAR2',G_SIZE,'LEAVE OUTPUT FILE NAME=' || l_out_lea_file_name));
 IF (G_FATAL_ERROR) THEN
   l_pgm_loc   := '170';
   RAISE G_E_ABORT;
 END IF;

 Println (G_LOG_FILE, '                                                                                                                          ');
 IF (G_FATAL_ERROR) THEN
   l_pgm_loc   := '175';
   RAISE G_E_ABORT;
 END IF;

 Printlog (G_LOG_FILE, pad_data_output('VARCHAR2',G_SIZE,'#### START PROCESSING KRONOS.KSS_PAYROLL_ORACLE TABLE.... ####'));
 IF (G_FATAL_ERROR) THEN
   l_pgm_loc   := '180';
   RAISE G_E_ABORT;
 END IF;

 -- Check batch name in KRONOS.KSS_PAYROLL_ORACLE table if it is already processed before...
 l_pgm_loc   := '200';
 L_ERROR_RECORD:='Checking Batch header record count for batch ' || vBatchName || ' KRONOS.KSS_PAYROLL_ORACLE';
 SELECT count(*)
   INTO l_batch_h_cnt
   --FROM KRONOS.KSS_PAYROLL_ORACLE --code commented by RXNETHI-ARGANO,15/05/23
   FROM APPS.KSS_PAYROLL_ORACLE --code added by RXNETHI-ARGANO,15/05/23
  WHERE upper(BATCH_NAME) = upper(vBatchName)
    AND record_Track = 'H'
    AND DeletionIndicator = 0;

 l_pgm_loc   := '220';
 IF (l_batch_h_cnt = 0) THEN
    Printlog (G_LOG_FILE, 'WARNING: NO unprocessed batch header row exist in KRONOS.KSS_PAYROLL_ORACLE table - no payroll output files will be produce
d');
    IF (G_FATAL_ERROR) THEN
      l_pgm_loc   := '230';
      RAISE G_E_ABORT;
    END IF;
 END IF;

 -- Check batch name in CUST.TTEC_PAY_IFACE_KSS_DIRECT_TBL table if it is already processed before...
 l_batch_h_cnt := 0;
 l_pgm_loc   := '240';
 L_ERROR_RECORD:='Checking Batch header record count for batch ' || vBatchName || ' CUST.TTEC_PAY_IFACE_KSS_DIRECT_TBL';
 SELECT count(*)
  INTO l_batch_h_cnt
  --FROM CUST.TTEC_PAY_IFACE_KSS_DIRECT_TBL --code commented by RXNETHI-ARGANO,15/05/23
  FROM APPS.TTEC_PAY_IFACE_KSS_DIRECT_TBL --code added by RXNETHI-ARGANO,15/05/23
 WHERE upper(BATCH_NAME) = upper(vBatchName)
   AND record_Track = 'H'
   AND DeletionIndicator = 1;

 l_pgm_loc   := '250';
 IF (l_batch_h_cnt != 0) THEN
    G_DELETE := FALSE;
    Printlog (G_LOG_FILE, 'ERROR: KRONOS Batch name ' || vBatchName || ' already processed before in CUST.TTEC_PAY_IFACE_KSS_DIRECT_TBL');
    IF (G_FATAL_ERROR) THEN
      l_pgm_loc   := '260';
      RAISE G_E_ABORT;
    END IF;
    l_pgm_loc   := '270';
    RAISE G_E_ABORT;
 END IF;

 -- Delete Processed records before processing new records in KRONOS.KSS_PAYROLL_ORACLE table.
 -- When fatal error occurs after successful deletion, deletion of rows will be comitted.

 l_pgm_loc   := '280';
 l_batch_name_like := trim(substr(vBatchName, 0, 7)) || '%';

 -- MDodge 01/08/08 Remove purging of KSS Table from code.
 --   Kronos Connect will take care of the Purge from now on.
/*
 L_ERROR_RECORD:='Delete_batch_rows in KRONOS.KSS_PAYROLL_ORACLE for ' || l_batch_name_like;
 DELETE
   FROM KRONOS.KSS_PAYROLL_ORACLE
   WHERE BATCH_NAME like l_batch_name_like
    AND BATCH_NAME <> vBatchName and DELETIONINDICATOR='1';

 l_pgm_loc   := '290';
 Printlog (G_LOG_FILE, pad_data_output('VARCHAR2',G_SIZE,'#### ROWS DELETED IN KRONOS.KSS_PAYROLL_ORACLE TABLE for ' || l_batch_name_like || ' ####'));
 IF (G_FATAL_ERROR) THEN
   l_pgm_loc   := '300';
   RAISE G_E_ABORT;
 END IF;
*/

 -- Delete Processed records before processing new records in CUST.TTEC_PAY_IFACE_KSS_DIRECT_TBL table
 -- When fatal error occurs after successful deletion, deletion of rows will be comitted.
 l_pgm_loc   := '310';
 L_ERROR_RECORD:='Delete_batch_rows in CUST.TTEC_PAY_IFACE_KSS_DIRECT_TBL for ' || l_batch_name_like;
 DELETE
   --FROM CUST.TTEC_PAY_IFACE_KSS_DIRECT_TBL --code commented by RXNETHI-ARGANO,15/05/23
   FROM APPS.TTEC_PAY_IFACE_KSS_DIRECT_TBL --code added by RXNETHI-ARGANO,15/05/23
  WHERE BATCH_NAME like l_batch_name_like
    AND BATCH_NAME <> vBatchName and DELETIONINDICATOR='1';       -- remember that there is possibility to have DELETIONINDICATOR='0'
                                                                  -- which is unprocessed...

 l_pgm_loc   := '320';
 Printlog (G_LOG_FILE, pad_data_output('VARCHAR2',G_SIZE,'#### ROWS DELETED IN CUST.TTEC_PAY_IFACE_KSS_DIRECT_TBL TABLE for ' || l_batch_name_like || ' ####'));
 IF (G_FATAL_ERROR) THEN
   l_pgm_loc   := '330';
   RAISE G_E_ABORT;
 END IF;

 -- Now it is ok to process batch rows in KRONOS.KSS_PAYROLL_ORACLE table....
 -- Loop for the Header Records and process the Batch
 -- Batch header may not be needed for these countries, but process it to follow Kronos side.
 l_pgm_loc   := '400';
 FOR Kronos_Header_Rec IN Kronos_Header_Csr(vBatchName) LOOP
     -- insert batch header into CUST.TTEC_PAY_IFACE_KSS_DIRECT_TBL table
     l_pgm_loc   := '410';
     L_ERROR_RECORD:='Processing Batch header record for batch ' || vBatchName;

     r_ttec_pay_pay_iface_kss.BATCH_NAME                 := Kronos_Header_Rec.BATCH_NAME;
     r_ttec_pay_pay_iface_kss.BATCH_DATE                 := Kronos_Header_Rec.BATCH_DATE;
     r_ttec_pay_pay_iface_kss.RECORD_TRACK               := Kronos_Header_Rec.RECORD_TRACK;
     r_ttec_pay_pay_iface_kss.ELEMENT_TYPE_ID            := Kronos_Header_Rec.ELEMENT_TYPE_ID;
     r_ttec_pay_pay_iface_kss.ASSIGNMENT_NUMBER          := Kronos_Header_Rec.ASSIGNMENT_NUMBER;
     r_ttec_pay_pay_iface_kss.ASSIGNMENT_ID              := Kronos_Header_Rec.ASSIGNMENT_ID;
     r_ttec_pay_pay_iface_kss.ELEMENT_NAME               := Kronos_Header_Rec.ELEMENT_NAME;
     r_ttec_pay_pay_iface_kss.ENTRY_TYPE                 := Kronos_Header_Rec.ENTRY_TYPE;
     r_ttec_pay_pay_iface_kss.REASON                     := Kronos_Header_Rec.REASON;
     r_ttec_pay_pay_iface_kss.VALUE_1                    := Kronos_Header_Rec.VALUE_1;
     r_ttec_pay_pay_iface_kss.VALUE_2                    := Kronos_Header_Rec.VALUE_2;
     r_ttec_pay_pay_iface_kss.VALUE_3                    := Kronos_Header_Rec.VALUE_3;
     r_ttec_pay_pay_iface_kss.EFFECTIVE_DATE             := Kronos_Header_Rec.EFFECTIVE_DATE;
     r_ttec_pay_pay_iface_kss.DELETIONINDICATOR          := Kronos_Header_Rec.DELETIONINDICATOR;
     r_ttec_pay_pay_iface_kss.EFFECTIVE_START_DATE       := Kronos_Header_Rec.EFFECTIVE_START_DATE;
     r_ttec_pay_pay_iface_kss.EFFECTIVE_END_DATE         := Kronos_Header_Rec.EFFECTIVE_END_DATE;
     r_ttec_pay_pay_iface_kss.LABORLEV3NM                := Kronos_Header_Rec.LABORLEV3NM;
     r_ttec_pay_pay_iface_kss.LABORLEV3DSC               := Kronos_Header_Rec.LABORLEV3DSC;
     r_ttec_pay_pay_iface_kss.EMPLOYEENAME               := Kronos_Header_Rec.EMPLOYEENAME;
     r_ttec_pay_pay_iface_kss.COUNTRY                    := Kronos_Header_Rec.COUNTRY;
     r_ttec_pay_pay_iface_kss.INTERFACE                  := Kronos_Header_Rec.INTERFACE;
     r_ttec_pay_pay_iface_kss.RUNID                      := Kronos_Header_Rec.RUNID;

     r_ttec_pay_pay_iface_kss.BUSINESS_GROUP_ID          := vBusGroup;
     r_ttec_pay_pay_iface_kss.PERSON_ID                  := NULL;
     r_ttec_pay_pay_iface_kss.LEGACY_EMP_NUMBER          := NULL;
     r_ttec_pay_pay_iface_kss.SEQUENCE_NUMBER            := NULL;
     r_ttec_pay_pay_iface_kss.INTERFACE_TYPE             := Kronos_Header_Rec.INTERFACE_TYPE;
     r_ttec_pay_pay_iface_kss.PAYCODE_TYPE               := NULL;

     l_pgm_loc   := '420';
     insert_ttec_pay_pay_iface_kss (ir_ttec_pay_pay_iface_kss => r_ttec_pay_pay_iface_kss);
     IF (G_FATAL_ERROR) THEN
       l_pgm_loc   := '430';
       RAISE G_E_ABORT;
     END IF;

     l_pgm_loc   := '440';
     l_rows_processed := l_rows_processed + 1;

     -- Process the BATCH LINE record
     FOR Kronos_Line_Rec IN Kronos_Line_Csr(vBusGroup, vBatchName) LOOP
         l_pgm_loc   := '500';
         L_ERROR_RECORD:='KRONOS_LINE_CSR for batch ' || vBatchName;

         IF UPPER(Kronos_Line_Rec.assignment_number)=upper(l_last_assignment_number) THEN
           l_sequence_no :=l_sequence_no + 1;
         ELSE
           l_last_assignment_number:=trim(Kronos_Line_Rec.assignment_number);
           l_sequence_no :=1;
         END IF;

         -- get legacy employee number
         l_pgm_loc   := '510';
         Begin
           SELECT PAAF.PERSON_ID,
                  PAAF.ASSIGNMENT_ID,
                  PAPF.ATTRIBUTE12
             INTO
                  l_person_id,
                  l_assignment_id,
                  l_legacy_emp_number
             FROM
                  PER_ALL_ASSIGNMENTS_F PAAF,
                  PER_ALL_PEOPLE_F PAPF
            WHERE
                  PAAF.ASSIGNMENT_NUMBER = Kronos_Line_Rec.ASSIGNMENT_NUMBER
              AND PAAF.BUSINESS_GROUP_ID = vBusGroup
              AND (trunc(Kronos_Line_Rec.effective_date) BETWEEN trunc(PAAF.EFFECTIVE_START_DATE) AND trunc(PAAF.EFFECTIVE_END_DATE))
              AND PAAF.PERSON_ID = PAPF.PERSON_ID
              AND (trunc(Kronos_Line_Rec.effective_date) BETWEEN trunc(PAPF.EFFECTIVE_START_DATE) AND trunc(PAPF.EFFECTIVE_END_DATE));

         Exception
           When others Then
            G_WARNING           := TRUE;
            l_person_id         := NULL;
            l_assignment_id     := NULL;
            l_legacy_emp_number := NULL;
            Printlog (G_LOG_FILE, pad_data_output('VARCHAR2',G_SIZE,'WARNING: legacy employee number can not be found for ASSIGNMENT_NUMBER='
                                                 || Kronos_Line_Rec.ASSIGNMENT_NUMBER));
            IF (G_FATAL_ERROR) THEN
              l_pgm_loc   := '520';
              RAISE G_E_ABORT;
            END IF;
            Printlog (G_LOG_FILE, pad_data_output('VARCHAR2',G_SIZE,'WARNING: NULL legacy employee number is passed and will not be processed'));
            IF (G_FATAL_ERROR) THEN
              l_pgm_loc   := '525';
              RAISE G_E_ABORT;
            END IF;
            IF (G_FATAL_ERROR) THEN
              l_pgm_loc   := '526';
              RAISE G_E_ABORT;
            END IF;
         End;

         Begin
           SELECT upper(substr(trim(DESCRIPTION),1,1))
             INTO l_paycode_type
             FROM FND_LOOKUP_VALUES
            WHERE LOOKUP_TYPE = G_NZ_PAYCODES_LOOKUP
              AND LOOKUP_CODE = upper(trim(Kronos_Line_Rec.ELEMENT_NAME))
              AND LANGUAGE    = 'US'
              AND ENABLED_FLAG = 'Y'
              AND trunc(sysdate) between trunc(START_DATE_ACTIVE) AND TRUNC(NVL(END_DATE_ACTIVE,SYSDATE));

         Exception
           When others Then
            G_PAYCODE_FATAL := TRUE;
            l_paycode_type := NULL;
            Printlog (G_LOG_FILE, pad_data_output('VARCHAR2',G_SIZE,'WARNING: paycode type can not be found for PAY_CODE='
                                                 || Kronos_Line_Rec.ELEMENT_NAME || ', WILL NOT be processed'));
            IF (G_FATAL_ERROR) THEN
              l_pgm_loc   := '527';
              RAISE G_E_ABORT;
            END IF;
         End;

         r_ttec_pay_pay_iface_kss.BATCH_NAME                 := Kronos_Line_Rec.BATCH_NAME;
         r_ttec_pay_pay_iface_kss.BATCH_DATE                 := Kronos_Line_Rec.BATCH_DATE;
         r_ttec_pay_pay_iface_kss.RECORD_TRACK               := Kronos_Line_Rec.RECORD_TRACK;
         r_ttec_pay_pay_iface_kss.ELEMENT_TYPE_ID            := Kronos_Line_Rec.ELEMENT_TYPE_ID;
         r_ttec_pay_pay_iface_kss.ASSIGNMENT_NUMBER          := Kronos_Line_Rec.ASSIGNMENT_NUMBER;
         r_ttec_pay_pay_iface_kss.ASSIGNMENT_ID              := l_assignment_id;
         r_ttec_pay_pay_iface_kss.ELEMENT_NAME               := Kronos_Line_Rec.ELEMENT_NAME;
         r_ttec_pay_pay_iface_kss.ENTRY_TYPE                 := Kronos_Line_Rec.ENTRY_TYPE;
         r_ttec_pay_pay_iface_kss.REASON                     := Kronos_Line_Rec.REASON;
         r_ttec_pay_pay_iface_kss.VALUE_1                    := Kronos_Line_Rec.VALUE_1;
         r_ttec_pay_pay_iface_kss.VALUE_2                    := Kronos_Line_Rec.VALUE_2;
         r_ttec_pay_pay_iface_kss.VALUE_3                    := Kronos_Line_Rec.VALUE_3;
         r_ttec_pay_pay_iface_kss.EFFECTIVE_DATE             := Kronos_Line_Rec.EFFECTIVE_DATE;
         r_ttec_pay_pay_iface_kss.DELETIONINDICATOR          := Kronos_Line_Rec.DELETIONINDICATOR;
         r_ttec_pay_pay_iface_kss.EFFECTIVE_START_DATE       := Kronos_Line_Rec.EFFECTIVE_START_DATE;
         r_ttec_pay_pay_iface_kss.EFFECTIVE_END_DATE         := Kronos_Line_Rec.EFFECTIVE_END_DATE;
         r_ttec_pay_pay_iface_kss.LABORLEV3NM                := Kronos_Line_Rec.LABORLEV3NM;
         r_ttec_pay_pay_iface_kss.LABORLEV3DSC               := Kronos_Line_Rec.LABORLEV3DSC;
         r_ttec_pay_pay_iface_kss.EMPLOYEENAME               := Kronos_Line_Rec.EMPLOYEENAME;
         r_ttec_pay_pay_iface_kss.COUNTRY                    := Kronos_Line_Rec.COUNTRY;
         r_ttec_pay_pay_iface_kss.INTERFACE                  := Kronos_Line_Rec.INTERFACE;
         r_ttec_pay_pay_iface_kss.RUNID                      := Kronos_Line_Rec.RUNID;

         r_ttec_pay_pay_iface_kss.BUSINESS_GROUP_ID          := vBusGroup;
         r_ttec_pay_pay_iface_kss.PERSON_ID                  := l_person_id;
         r_ttec_pay_pay_iface_kss.LEGACY_EMP_NUMBER          := l_legacy_emp_number;
         r_ttec_pay_pay_iface_kss.SEQUENCE_NUMBER            := l_sequence_no;
         r_ttec_pay_pay_iface_kss.INTERFACE_TYPE             := Kronos_Line_Rec.INTERFACE_TYPE;
         r_ttec_pay_pay_iface_kss.PAYCODE_TYPE               := l_paycode_type;

         l_pgm_loc   := '530';
         insert_ttec_pay_pay_iface_kss (ir_ttec_pay_pay_iface_kss => r_ttec_pay_pay_iface_kss);
         IF (G_FATAL_ERROR) THEN
           l_pgm_loc   := '540';
           RAISE G_E_ABORT;
         END IF;

         l_rows_lines_processed := l_rows_lines_processed + 1;

     END LOOP; -- Kronos_Line_Rec IN Kronos_Line_Csr(vBusGroup, vBatchName)

 END LOOP; -- Kronos_Header_Rec IN Kronos_Header_Csr(vBatchName)

  l_pgm_loc   := '600';
  Printlog (G_LOG_FILE, pad_data_output('VARCHAR2',G_SIZE,'Total ' || l_rows_processed || ' Batch header rows processed in KRONOS.KSS_PAYROLL_ORACLE'));
  IF (G_FATAL_ERROR) THEN
    l_pgm_loc   := '610';
    RAISE G_E_ABORT;
  END IF;
  Printlog (G_LOG_FILE, pad_data_output('VARCHAR2',G_SIZE,'Total ' || l_rows_lines_processed || ' Batch line rows processed in KRONOS.KSS_PAYROLL_ORACLE'));
  IF (G_FATAL_ERROR) THEN
    l_pgm_loc   := '620';
    RAISE G_E_ABORT;
  END IF;

  -- issue warning when processed number of batch line row is zero.
  IF (l_rows_lines_processed = 0) THEN
    G_WARNING           := TRUE;
  END IF;

   -- Make rows (barch header and lines) in KRONOS.KSS_PAYROLL_ORACLE as processed.
   l_pgm_loc   := '700';
   L_ERROR_RECORD := 'Updating DELETIONINDICATOR column in KRONOS.KSS_PAYROLL_ORACLE table for batch ' || vBatchName;
   Printlog (G_LOG_FILE, pad_data_output('VARCHAR2',G_SIZE,'#### START UPDATING KRONOS.KSS_PAYROLL_ORACLE TABLE DELETIONINDICATOR.... ####'));
   IF (G_FATAL_ERROR) THEN
     l_pgm_loc   := '710';
     RAISE G_E_ABORT;
   END IF;

   l_pgm_loc   := '720';
   --UPDATE KRONOS.KSS_PAYROLL_ORACLE   --code commented by RXNETHI-ARGANO,15/05/23
   UPDATE APPS.KSS_PAYROLL_ORACLE       --code added by RXNETHI-ARGANO,15/05/23
      SET DELETIONINDICATOR='1'
    WHERE UPPER(BATCH_NAME) = UPPER(vBatchName);

   -- At this point entries in KRONOS.KSS_PAYROLL_ORACLE moved to table cust.ttec_pay_iface_kss_direct_tbl table..
   -- now process cust.ttec_pay_iface_kss_direct_tbl and generate output files for RECORD_TRACK ='L' only.
   -- nzpay
   l_pgm_loc   := '800';
   L_ERROR_RECORD := 'PROCESSING CUST.TTEC_PAY_IFACE_KSS_DIRECT_TBL line records for batch ' || vBatchName;
   Printlog (G_LOG_FILE, pad_data_output('VARCHAR2',G_SIZE,'#### START PROCESSING CUST.TTEC_PAY_IFACE_KSS_DIRECT_TBL.... ####'));
   IF (G_FATAL_ERROR) THEN
     l_pgm_loc   := '810';
     RAISE G_E_ABORT;
   END IF;

   FOR kss_direct_line_rec IN  kss_direct_line_csr (vBatchName) LOOP
       -- produce leave output file based on pay codes..
       l_pgm_loc   := '900';
       IF (   substr(kss_direct_line_rec.PAYCODE_TYPE,1,1) = 'L'
           OR substr(kss_direct_line_rec.PAYCODE_TYPE,1,1) = 'B' ) THEN
         l_pgm_loc   := '910';
         -- data format of VALUE_3 from kronos is YYYY/MM/DD
         l_line_buffer := trim(kss_direct_line_rec.LEGACY_EMP_NUMBER)                                      || ',' ||
                          trim(kss_direct_line_rec.ELEMENT_NAME)                                           || ',' ||
                          to_char(to_date(trim(kss_direct_line_rec.VALUE_3), 'YYYY/MM/DD'), 'DDMMYY')      || ',' ||  -- start date
                          to_char(to_date(trim(kss_direct_line_rec.VALUE_3), 'YYYY/MM/DD'), 'DDMMYY')      || ',' ||  -- end date
              --          to_char(kss_direct_line_rec.EFFECTIVE_DATE, 'DD/MM/YYYY')                        || ',' ||  -- posting date
                          format_h_dot_hh_hmm(trim(kss_direct_line_rec.VALUE_1));

         Println (G_OUT_LEA_FILE, l_line_buffer);
         IF (G_FATAL_ERROR) THEN
           l_pgm_loc   := '920';
           RAISE G_E_ABORT;
         END IF;
       END IF; -- IF (substr(kss_direct_line_rec.PAYCODE_TYPE,1,1) = 'L' or 'B')

         -- produce pay output file, leave pay codes goes in here also.
       IF (   substr(kss_direct_line_rec.PAYCODE_TYPE,1,1) = 'P'
           OR substr(kss_direct_line_rec.PAYCODE_TYPE,1,1) = 'B' ) THEN
         l_pgm_loc   := '930';
         l_line_buffer := trim(kss_direct_line_rec.LEGACY_EMP_NUMBER)                || ',' ||
                          trim(kss_direct_line_rec.decoded_interface_type)           || ',,,' ||  -- payslip type
                          trim(kss_direct_line_rec.ELEMENT_NAME)                     || ',,' ||
                          replace(trim(kss_direct_line_rec.VALUE_1), '.', '')        || ',,,,' ||
                          to_char(kss_direct_line_rec.EFFECTIVE_DATE, 'DD-MM-YYYY');
         Println (G_OUT_PAY_FILE, l_line_buffer);
         IF (G_FATAL_ERROR) THEN
           l_pgm_loc   := '940';
           RAISE G_E_ABORT;
         END IF;
       END IF;     -- IF (substr(kss_direct_line_rec.PAYCODE_TYPE,1,1) = 'P' or 'B')

       -- Update line rows as processed
       l_pgm_loc   := '950';
       --UPDATE CUST.TTEC_PAY_IFACE_KSS_DIRECT_TBL --code commented by RXNETHI-ARGANO,15/05/23
	   UPDATE APPS.TTEC_PAY_IFACE_KSS_DIRECT_TBL --code added by RXNETHI-ARGANO,15/05/23
          SET DELETIONINDICATOR = '1'
        WHERE UPPER(BATCH_NAME) = UPPER(vBatchName)
          AND RECORD_TRACK      ='L'
          AND LEGACY_EMP_NUMBER = kss_direct_line_rec.LEGACY_EMP_NUMBER
          AND ELEMENT_NAME      = kss_direct_line_rec.ELEMENT_NAME
          AND ASSIGNMENT_NUMBER = kss_direct_line_rec.ASSIGNMENT_NUMBER
          AND SEQUENCE_NUMBER   = kss_direct_line_rec.SEQUENCE_NUMBER;

       l_pgm_loc   := '952';
       l_ct_grand_tot := l_ct_grand_tot + to_number(trim(kss_direct_line_rec.VALUE_1));

   END LOOP; -- kss_direct_line_rec IN  kss_direct_line_csr (vBatchName)

   -- Update batch header row as processed in CUST.TTEC_PAY_IFACE_KSS_DIRECT_TBL
   l_pgm_loc   := '960';
   L_ERROR_RECORD := 'UPDATING CUST.TTEC_PAY_IFACE_KSS_DIRECT_TBL Header record for batch ' || vBatchName;
   Printlog (G_LOG_FILE, pad_data_output('VARCHAR2',G_SIZE,'#### START UPDATING CUST.TTEC_PAY_IFACE_KSS_DIRECT_TBL HEADER RECORD.... ####'));
   IF (G_FATAL_ERROR) THEN
     l_pgm_loc   := '970';
     RAISE G_E_ABORT;
   END IF;

   l_pgm_loc   := '980';
   --UPDATE CUST.TTEC_PAY_IFACE_KSS_DIRECT_TBL --code commented by RXNETHI-ARGANO,15/05/23
   UPDATE APPS.TTEC_PAY_IFACE_KSS_DIRECT_TBL --code added by RXNETHI-ARGANO,15/05/23
      SET DELETIONINDICATOR='1'
    WHERE UPPER(BATCH_NAME) = UPPER(vBatchName)
      AND RECORD_TRACK ='H';

   -- Report UNPROCESSED line records from CUST.TTEC_PAY_IFACE_KSS_DIRECT_TBL, if any...
   Println (G_LOG_FILE, '                                                                                                                         ');
   IF (G_FATAL_ERROR) THEN
     l_pgm_loc   := '985';
     RAISE G_E_ABORT;
   END IF;

   l_pgm_loc   := '990';
   L_ERROR_RECORD := 'REPORT UNPROCESSED CUST.TTEC_PAY_IFACE_KSS_DIRECT_TBL Line records for batch ' || vBatchName;
   Printlog (G_LOG_FILE, pad_data_output('VARCHAR2',G_SIZE,'#### REPORTING UNPROCESSED CUST.TTEC_PAY_IFACE_KSS_DIRECT_TBL LINE RECORDS.... ####'));
   IF (G_FATAL_ERROR) THEN
     l_pgm_loc   := '995';
     RAISE G_E_ABORT;
   END IF;

   Println (G_LOG_FILE, '=========================================================================================================================');
   IF (G_FATAL_ERROR) THEN
     l_pgm_loc   := '996';
     RAISE G_E_ABORT;
   END IF;

   l_pgm_loc   := '1000';
   FOR kss_direct_line_unproc_rec IN kss_direct_line_unproc_csr(vBatchName) LOOP
       l_unproc_cnt := l_unproc_cnt + 1;
       l_line_buffer := 'ASG_NUM='             || trim(kss_direct_line_unproc_rec.ASSIGNMENT_NUMBER) ||
                        ', LEGACY_EMP_NUM='    || trim(kss_direct_line_unproc_rec.LEGACY_EMP_NUMBER) ||
                        ', ELEMENT_NAME='      || trim(kss_direct_line_unproc_rec.ELEMENT_NAME)      ||
                        ', VALUE1='            || trim(kss_direct_line_unproc_rec.VALUE_1)           ||
                        ', VALUE3='            || trim(kss_direct_line_unproc_rec.VALUE_3)           ||
                        ', PAYCODE_TYPE='      || trim(kss_direct_line_unproc_rec.PAYCODE_TYPE);
       Println (G_LOG_FILE, pad_data_output('VARCHAR2',G_SIZE,l_line_buffer));
       IF (G_FATAL_ERROR) THEN
         l_pgm_loc   := '1010';
         RAISE G_E_ABORT;
       END IF;
   END LOOP;

   Println (G_LOG_FILE, pad_data_output('VARCHAR2',G_SIZE,'#### Total ' || l_unproc_cnt || ' UNPROCESSED LINE RECORDS....####'));
   IF (G_FATAL_ERROR) THEN
     l_pgm_loc   := '1020';
     RAISE G_E_ABORT;
   END IF;

   Println (G_LOG_FILE, '=========================================================================================================================');
   IF (G_FATAL_ERROR) THEN
     l_pgm_loc   := '1025';
     RAISE G_E_ABORT;
   END IF;

   Println (G_LOG_FILE, '                                                                                                                         ');
   IF (G_FATAL_ERROR) THEN
     l_pgm_loc   := '1030';
     RAISE G_E_ABORT;
   END IF;

   -- process control totals based on pay codes.
   Printlog (G_LOG_FILE, pad_data_output('VARCHAR2',G_SIZE,'#### REPORTING CONTROL TOTALS OF PROCESSED RECORDS.... ####'));
   IF (G_FATAL_ERROR) THEN
     l_pgm_loc   := '1100';
     RAISE G_E_ABORT;
   END IF;

   Println (G_LOG_FILE, '=========================================================================================================================');
   IF (G_FATAL_ERROR) THEN
     l_pgm_loc   := '1110';
     RAISE G_E_ABORT;
   END IF;

   l_line_buffer := pad_data_output('VARCHAR2',82,'PAY CODES/CATEGORY') || 'HOUR(H.HH)';
   Println (G_LOG_FILE, pad_data_output('VARCHAR2',G_SIZE,l_line_buffer));
   IF (G_FATAL_ERROR) THEN
     l_pgm_loc   := '1120';
     RAISE G_E_ABORT;
   END IF;

   l_line_buffer := '--------------------------------------------------------------------------------  ----------';
   Println (G_LOG_FILE, pad_data_output('VARCHAR2',G_SIZE,l_line_buffer));
   IF (G_FATAL_ERROR) THEN
     l_pgm_loc   := '1130';
     RAISE G_E_ABORT;
   END IF;

   l_pgm_loc   := '1140';
   l_line_buffer := pad_data_output('VARCHAR2',82,'GRAND TOTALS of Processed Records') ||
                    pad_data_output('NUMBER',10,to_char(l_ct_grand_tot, 'FM99999990.00'));

   Println (G_LOG_FILE, pad_data_output('VARCHAR2',G_SIZE,l_line_buffer));
   IF (G_FATAL_ERROR) THEN
     l_pgm_loc   := '1150';
     RAISE G_E_ABORT;
   END IF;

   l_pgm_loc   := '1160';
   FOR kss_direct_ct_rec IN kss_direct_ct_csr (vBatchName) LOOP
     l_line_buffer := pad_data_output('VARCHAR2',82,trim(kss_direct_ct_rec.ELEMENT_NAME))                   ||
                      pad_data_output('NUMBER',10,to_char(kss_direct_ct_rec.pay_code_ct_tot, 'FM99999990.00'));
     Println (G_LOG_FILE, pad_data_output('VARCHAR2',G_SIZE,l_line_buffer));
     IF (G_FATAL_ERROR) THEN
       l_pgm_loc   := '1170';
       RAISE G_E_ABORT;
     END IF;
   END LOOP;

   l_pgm_loc   := '1180';
   Println (G_LOG_FILE, '=========================================================================================================================');
   IF (G_FATAL_ERROR) THEN
     l_pgm_loc   := '1190';
     RAISE G_E_ABORT;
   END IF;

   Println (G_LOG_FILE, '                                                                                                                         ');
   IF (G_FATAL_ERROR) THEN
     l_pgm_loc   := '1195';
     RAISE G_E_ABORT;
   END IF;

EXCEPTION
WHEN G_E_ABORT THEN
 G_FATAL_ERROR := TRUE;
 L_ERROR_MESSAGE := 'Error --> '||SQLERRM;
 L_ERROR_RECORD := L_ERROR_RECORD || ' -  New Zealand Interface ' || 'in ' || G_PKG_NAME || '.' || l_proc_name || ' pgm_loc=' || l_pgm_loc;
 log_kss_payroll_error (L_ERROR_MESSAGE,L_ERROR_RECORD);
 IF (UTL_FILE.IS_OPEN(G_LOG_FILE) AND G_LOG_FILE_W) THEN
   Printlog (G_LOG_FILE, L_ERROR_RECORD);
   Printlog (G_LOG_FILE, L_ERROR_MESSAGE);
 END IF;

WHEN OTHERS THEN
 G_FATAL_ERROR := TRUE;
 L_ERROR_MESSAGE := 'Error --> '||SQLERRM;
 L_ERROR_RECORD := L_ERROR_RECORD || ' -  New Zealand Interface ' || 'in ' || G_PKG_NAME || '.' || l_proc_name || ' pgm_loc=' || l_pgm_loc;
 log_kss_payroll_error (L_ERROR_MESSAGE,L_ERROR_RECORD);
 IF (UTL_FILE.IS_OPEN(G_LOG_FILE) AND G_LOG_FILE_W) THEN
   Printlog (G_LOG_FILE, L_ERROR_RECORD);
   Printlog (G_LOG_FILE, L_ERROR_MESSAGE);
 END IF;

END TTEC_NZ_PAY_IFACE;

/********************************************************************/
/* Payroll interface for Singapore, called by procedure             */
/* TTEC_PAY_IFACE_KRONOS_DIRECT                                     */
/********************************************************************/
PROCEDURE TTEC_SGP_PAY_IFACE
  (vBusGroup  IN number
  ,vBatchName IN varchar2
  ,v_payfile  OUT varchar2
  ,v_leafile  OUT varchar2
  )

IS

l_proc_name                  varchar2(30)   :=NULL;
l_pgm_loc                    varchar2(10)   :=NULL;
l_line_buffer                varchar2(2000) :=NULL;
L_ERROR_RECORD               varchar2(2000) :=NULL;
L_ERROR_MESSAGE              varchar2(2000) :=NULL;

l_out_pay_file_name          VARCHAR2(50)   :=NULL;
l_out_lea_file_name          VARCHAR2(50)   :=NULL;

l_rows_processed             number         :=0;
l_rows_lines_processed       number         :=0;

l_sequence_no                number         :=0;
-- l_last_element_name       varchar(60)    :=NULL;
l_last_assignment_number     varchar2(30)   :=NULL;
l_element_type_id            varchar2(60)   :=NULL;
l_assignment_id              varchar2(60)   :=NULL;

l_person_id                  PER_ALL_PEOPLE_F.PERSON_ID%TYPE :=NULL;
l_legacy_emp_number          PER_ALL_PEOPLE_F.ATTRIBUTE12%TYPE :=NULL;
l_last_legacy_emp_number     PER_ALL_PEOPLE_F.ATTRIBUTE12%TYPE :=NULL;
--p
l_paycode_type               varchar2(10)   :=NULL;

l_unproc_cnt                 number :=0;
l_batch_h_cnt                number :=0;
l_batch_name_like            VARCHAR2(30) :=NULL;
l_ct_grand_tot               NUMBER(10,2) :=0.00;

l_max_col                   BINARY_INTEGER :=0;
i                           BINARY_INTEGER :=0;
l_col_total                 number(8,2)  :=0.00;

TYPE tot_rec IS RECORD (total_num  number(6,2));

TYPE tot_tabtype IS TABLE OF tot_rec
     INDEX BY BINARY_INTEGER;

tot_table tot_tabtype;

-- Cursor for Getting the header records from the staging records.
CURSOR Kronos_Header_Csr(vBatchName varchar2) is
 SELECT Distinct *
   --FROM KRONOS.KSS_PAYROLL_ORACLE --code commented by RXNETHI-ARGANO,15/05/23
   FROM APPS.KSS_PAYROLL_ORACLE --code added by RXNETHI-ARGANO,15/05/23
  WHERE upper(BATCH_NAME) = upper(vBatchName)
    AND record_Track = 'H'
    AND DeletionIndicator=0 ;
Kronos_Header_Rec Kronos_Header_Csr%ROWTYPE;

-- Cursor for Getting the Line Records from the Staging Records, KRONOS.KSS_PAYROLL_ORACLE
CURSOR Kronos_Line_Csr(vBusGroup number, vBatchName varchar2) is
 SELECT
       KPO.BATCH_NAME,
       KPO.BATCH_DATE,
       KPO.RECORD_TRACK,
       KPO.ELEMENT_TYPE_ID,
       KPO.ASSIGNMENT_NUMBER,
       KPO.ASSIGNMENT_ID,
       KPO.ELEMENT_NAME,
       KPO.ENTRY_TYPE,
       KPO.REASON,
       KPO.VALUE_1,
       KPO.VALUE_2,
       KPO.VALUE_3,
       KPO.EFFECTIVE_DATE,
       KPO.DELETIONINDICATOR,
       KPO.EFFECTIVE_START_DATE,
       KPO.EFFECTIVE_END_DATE,
       KPO.LABORLEV3NM,
       KPO.LABORLEV3DSC,
       KPO.EMPLOYEENAME,
       KPO.COUNTRY,
       KPO.INTERFACE,
       KPO.RUNID,
       KPO.INTERFACE_TYPE
  FROM
       --KRONOS.KSS_PAYROLL_ORACLE KPO --code commented by RXNETHI-ARGANO,15/05/23
	   APPS.KSS_PAYROLL_ORACLE KPO --code added by RXNETHI-ARGANO,15/05/23
 WHERE upper(KPO.BATCH_NAME) = upper(vBatchName)
   AND KPO.RECORD_TRACK ='L'
   AND KPO.DELETIONINDICATOR=0
-- to get rid of null values of batch line row after discussion with kronos team.
   AND trim(KPO.ASSIGNMENT_NUMBER) is not null
   AND trim(KPO.ELEMENT_NAME) is not null
-- to get rid of null values of batch line row...
 ORDER BY KPO.BATCH_NAME, KPO.ASSIGNMENT_NUMBER, KPO.ELEMENT_NAME, KPO.EFFECTIVE_DATE;

 Kronos_Line_Rec  Kronos_Line_Csr%ROWTYPE;

 --r_ttec_pay_pay_iface_kss    CUST.TTEC_PAY_IFACE_KSS_DIRECT_TBL%ROWTYPE; --code commented by RXNETHI-ARGANO,15/05/23
 r_ttec_pay_pay_iface_kss    APPS.TTEC_PAY_IFACE_KSS_DIRECT_TBL%ROWTYPE; --code added by RXNETHI-ARGANO,15/05/23

-- Curssr for Getting the Line Records from CUST.TTEC_PAY_IFACE_KSS_DIRECT_TBL
CURSOR kss_direct_line_csr (vBatchName varchar2) is
 SELECT
       BATCH_NAME,
       BATCH_DATE,
       RECORD_TRACK,
       ELEMENT_TYPE_ID,
       ASSIGNMENT_NUMBER,
       ASSIGNMENT_ID,
       ELEMENT_NAME,
       ENTRY_TYPE,
       REASON,
       VALUE_1,
       VALUE_2,
       VALUE_3,
       EFFECTIVE_DATE,
       DELETIONINDICATOR,
       EFFECTIVE_START_DATE,
       EFFECTIVE_END_DATE,
       LABORLEV3NM,
       LABORLEV3DSC,
       EMPLOYEENAME,
       COUNTRY,
       INTERFACE,
       RUNID,
       BUSINESS_GROUP_ID,
       PERSON_ID,
       LEGACY_EMP_NUMBER,
       SEQUENCE_NUMBER,
       INTERFACE_TYPE,
       PAYCODE_TYPE
  FROM
       --CUST.TTEC_PAY_IFACE_KSS_DIRECT_TBL --code commented by RXNETHI-ARGANO,15/05/23
	   APPS.TTEC_PAY_IFACE_KSS_DIRECT_TBL --code added by RXNETHI-ARGANO,15/05/23
 WHERE upper(BATCH_NAME) = upper(vBatchName)
   AND RECORD_TRACK ='L'
   AND DELETIONINDICATOR=0
   AND LEGACY_EMP_NUMBER is NOT NULL
   AND trim(ELEMENT_NAME) is NOT NULL
   AND substr(PAYCODE_TYPE,1,1) in ('P', 'L', 'B')
-- ORDER BY BATCH_NAME, LEGACY_EMP_NUMBER, ELEMENT_NAME, EFFECTIVE_DATE;
   ORDER BY LEGACY_EMP_NUMBER, ELEMENT_NAME;

 kss_direct_line_rec kss_direct_line_csr%ROWTYPE;

-- Curssr for Getting UNPROCESSED line records from CUST.TTEC_PAY_IFACE_KSS_DIRECT_TBL
CURSOR kss_direct_line_unproc_csr (vBatchName varchar2) is
 SELECT
       BATCH_NAME,
       BATCH_DATE,
       RECORD_TRACK,
       ELEMENT_TYPE_ID,
       ASSIGNMENT_NUMBER,
       ASSIGNMENT_ID,
       ELEMENT_NAME,
       ENTRY_TYPE,
       REASON,
       VALUE_1,
       VALUE_2,
       VALUE_3,
       EFFECTIVE_DATE,
       DELETIONINDICATOR,
       EFFECTIVE_START_DATE,
       EFFECTIVE_END_DATE,
       LABORLEV3NM,
       LABORLEV3DSC,
       EMPLOYEENAME,
       COUNTRY,
       INTERFACE,
       RUNID,
       BUSINESS_GROUP_ID,
       PERSON_ID,
       LEGACY_EMP_NUMBER,
       SEQUENCE_NUMBER,
       INTERFACE_TYPE,
       PAYCODE_TYPE
  FROM
       --CUST.TTEC_PAY_IFACE_KSS_DIRECT_TBL --code commented by RXNETHI-ARGANO,15/05/23
	   APPS.TTEC_PAY_IFACE_KSS_DIRECT_TBL --code added by RXNETHI-ARGANO,15/05/23
 WHERE upper(BATCH_NAME) = upper(vBatchName)
   AND RECORD_TRACK ='L'
   AND DELETIONINDICATOR=0
 ORDER BY BATCH_NAME, LEGACY_EMP_NUMBER, ELEMENT_NAME, EFFECTIVE_DATE;

 kss_direct_line_unproc_rec kss_direct_line_unproc_csr%ROWTYPE;

-- Curssr for getting control totals based on pay codes from CUST.TTEC_PAY_IFACE_KSS_DIRECT_TBL
CURSOR kss_direct_ct_csr (vBatchName varchar2) is
 SELECT
       ELEMENT_NAME,
       sum(to_number(VALUE_1)) pay_code_ct_tot
  FROM
       --CUST.TTEC_PAY_IFACE_KSS_DIRECT_TBL --code commented by RXNETHI-ARGANO,15/05/23
	   APPS.TTEC_PAY_IFACE_KSS_DIRECT_TBL --code added by RXNETHI-ARGANO,15/05/23
 WHERE upper(BATCH_NAME) = upper(vBatchName)
   AND RECORD_TRACK ='L'
   AND DELETIONINDICATOR=1
 GROUP BY ELEMENT_NAME;

BEGIN
 l_proc_name := 'TTEC_SGP_PAY_IFACE';
 l_pgm_loc   := '100';

 Printlog (G_LOG_FILE, pad_data_output('VARCHAR2',G_SIZE,'#### START PROCESSING SPG PAYROLL INTERFACE.... ####'));
 IF (G_FATAL_ERROR) THEN
   l_pgm_loc   := '110';
   RAISE G_E_ABORT;
 END IF;

 -- format output file names
 l_out_pay_file_name := replace(trim(vBatchName), ' ', '_');
 l_out_pay_file_name := replace(l_out_pay_file_name, '/', '-');
 l_out_pay_file_name := replace(l_out_pay_file_name, ':', '_');
 l_out_lea_file_name := l_out_pay_file_name;
 l_out_pay_file_name := l_out_pay_file_name || '.pay';
 l_out_lea_file_name := l_out_lea_file_name || '.lea';

 v_payfile := l_out_pay_file_name;
 v_leafile := l_out_lea_file_name;

 -- Open output files
 l_pgm_loc   := '120';
 L_ERROR_RECORD:= 'Opening output file ' || l_out_pay_file_name;
 G_OUT_PAY_FILE := Open_File(l_out_pay_file_name, 'W');
 IF (G_FATAL_ERROR) THEN
   l_pgm_loc   := '130';
   RAISE G_E_ABORT;
 END IF;

 Printlog (G_LOG_FILE, pad_data_output('VARCHAR2',G_SIZE,'OUTPUT FILE DIRECTORY=' || G_UTIL_FILE_OUT_DIR));
 IF (G_FATAL_ERROR) THEN
   l_pgm_loc   := '135';
   RAISE G_E_ABORT;
 END IF;

 Printlog (G_LOG_FILE, pad_data_output('VARCHAR2',G_SIZE,'PAY OUTPUT FILE NAME=' || l_out_pay_file_name));
 IF (G_FATAL_ERROR) THEN
   l_pgm_loc   := '140';
   RAISE G_E_ABORT;
 END IF;

 l_pgm_loc   := '150';
 L_ERROR_RECORD:= 'Opening output file ' || l_out_lea_file_name;
 G_OUT_LEA_FILE := Open_File(l_out_lea_file_name, 'W');
 IF (G_FATAL_ERROR) THEN
   l_pgm_loc   := '160';
   RAISE G_E_ABORT;
 END IF;

 Printlog (G_LOG_FILE, pad_data_output('VARCHAR2',G_SIZE,'LEAVE OUTPUT FILE NAME=' || l_out_lea_file_name));
 IF (G_FATAL_ERROR) THEN
   l_pgm_loc   := '170';
   RAISE G_E_ABORT;
 END IF;

 Println (G_LOG_FILE, '                                                                                                                          ');
 IF (G_FATAL_ERROR) THEN
   l_pgm_loc   := '175';
   RAISE G_E_ABORT;
 END IF;

 Printlog (G_LOG_FILE, pad_data_output('VARCHAR2',G_SIZE,'#### START PROCESSING KRONOS.KSS_PAYROLL_ORACLE TABLE.... ####'));
 IF (G_FATAL_ERROR) THEN
   l_pgm_loc   := '180';
   RAISE G_E_ABORT;
 END IF;

 -- Check batch name in KRONOS.KSS_PAYROLL_ORACLE table if it is already processed before...
 l_pgm_loc   := '200';
 L_ERROR_RECORD:='Checking Batch header record count for batch ' || vBatchName || ' KRONOS.KSS_PAYROLL_ORACLE';
 SELECT count(*)
   INTO l_batch_h_cnt
   --FROM KRONOS.KSS_PAYROLL_ORACLE --code commented by RXNETHI-ARGANO,15/05/23
   FROM APPS.KSS_PAYROLL_ORACLE --code added by RXNETHI-ARGANO,15/05/23
  WHERE upper(BATCH_NAME) = upper(vBatchName)
    AND record_Track = 'H'
    AND DeletionIndicator = 0;

 l_pgm_loc   := '220';
 IF (l_batch_h_cnt = 0) THEN
    Printlog (G_LOG_FILE, 'WARNING: NO unprocessed batch header row exist in KRONOS.KSS_PAYROLL_ORACLE table - no payroll output files will be produced');
    IF (G_FATAL_ERROR) THEN
      l_pgm_loc   := '230';
      RAISE G_E_ABORT;
    END IF;
 END IF;

 -- Check batch name in CUST.TTEC_PAY_IFACE_KSS_DIRECT_TBL table if it is already processed before...
 l_batch_h_cnt := 0;
 l_pgm_loc   := '240';
 L_ERROR_RECORD:='Checking Batch header record count for batch ' || vBatchName || ' CUST.TTEC_PAY_IFACE_KSS_DIRECT_TBL';
 SELECT count(*)
  INTO l_batch_h_cnt
  --FROM CUST.TTEC_PAY_IFACE_KSS_DIRECT_TBL --code commented by RXNETHI-ARGANO,15/05/23
  FROM APPS.TTEC_PAY_IFACE_KSS_DIRECT_TBL --code added by RXNETHI-ARGANO,15/05/23
 WHERE upper(BATCH_NAME) = upper(vBatchName)
   AND record_Track = 'H'
   AND DeletionIndicator = 1;

 l_pgm_loc   := '250';
 IF (l_batch_h_cnt != 0) THEN
    G_DELETE := FALSE;
    Printlog (G_LOG_FILE, 'ERROR: KRONOS Batch name ' || vBatchName || ' already processed before in CUST.TTEC_PAY_IFACE_KSS_DIRECT_TBL');
    IF (G_FATAL_ERROR) THEN
      l_pgm_loc   := '260';
      RAISE G_E_ABORT;
    END IF;
    l_pgm_loc   := '270';
    RAISE G_E_ABORT;
 END IF;

 -- Delete Processed records before processing new records in KRONOS.KSS_PAYROLL_ORACLE table.
 -- When fatal error occurs after successful deletion, deletion of rows will be comitted.

 l_pgm_loc   := '280';
 l_batch_name_like := trim(substr(vBatchName, 0, 7)) || '%';

 -- MDodge 01/08/08 Remove purging of KSS Table from code.
 --   Kronos Connect will take care of the Purge from now on.
/*
 L_ERROR_RECORD:='Delete_batch_rows in KRONOS.KSS_PAYROLL_ORACLE for ' || l_batch_name_like;
 DELETE
   FROM KRONOS.KSS_PAYROLL_ORACLE
   WHERE BATCH_NAME like l_batch_name_like
    AND BATCH_NAME <> vBatchName and DELETIONINDICATOR='1';

 l_pgm_loc   := '290';
 Printlog (G_LOG_FILE, pad_data_output('VARCHAR2',G_SIZE,'#### ROWS DELETED IN KRONOS.KSS_PAYROLL_ORACLE TABLE for ' || l_batch_name_like || ' ####'));
 IF (G_FATAL_ERROR) THEN
   l_pgm_loc   := '300';
   RAISE G_E_ABORT;
 END IF;
*/

 -- Delete Processed records before processing new records in CUST.TTEC_PAY_IFACE_KSS_DIRECT_TBL table
 -- When fatal error occurs after successful deletion, deletion of rows will be comitted.
 l_pgm_loc   := '310';
 L_ERROR_RECORD:='Delete_batch_rows in CUST.TTEC_PAY_IFACE_KSS_DIRECT_TBL for ' || l_batch_name_like;
 DELETE
   --FROM CUST.TTEC_PAY_IFACE_KSS_DIRECT_TBL --code commented by RXNETHI-ARGANO,15/05/23
   FROM APPS.TTEC_PAY_IFACE_KSS_DIRECT_TBL --code added by RXNETHI-ARGANO,15/05/23
  WHERE BATCH_NAME like l_batch_name_like
    AND BATCH_NAME <> vBatchName and DELETIONINDICATOR='1';       -- remember that there is possibility to have DELETIONINDICATOR='0'
                                                                  -- which is unprocessed...

 l_pgm_loc   := '320';
 Printlog (G_LOG_FILE, pad_data_output('VARCHAR2',G_SIZE,'#### ROWS DELETED IN CUST.TTEC_PAY_IFACE_KSS_DIRECT_TBL TABLE for ' || l_batch_name_like || ' ####'
));
 IF (G_FATAL_ERROR) THEN
   l_pgm_loc   := '330';
   RAISE G_E_ABORT;
 END IF;

 -- Now it is ok to process batch rows in KRONOS.KSS_PAYROLL_ORACLE table....
 -- Loop for the Header Records and process the Batch
 -- Batch header may not be needed for these countries, but process it to follow Kronos side.
 l_pgm_loc   := '400';
 FOR Kronos_Header_Rec IN Kronos_Header_Csr(vBatchName) LOOP
     -- insert batch header into CUST.TTEC_PAY_IFACE_KSS_DIRECT_TBL table
     l_pgm_loc   := '410';
     L_ERROR_RECORD:='Processing Batch header record for batch ' || vBatchName;

     r_ttec_pay_pay_iface_kss.BATCH_NAME                 := Kronos_Header_Rec.BATCH_NAME;
     r_ttec_pay_pay_iface_kss.BATCH_DATE                 := Kronos_Header_Rec.BATCH_DATE;
     r_ttec_pay_pay_iface_kss.RECORD_TRACK               := Kronos_Header_Rec.RECORD_TRACK;
     r_ttec_pay_pay_iface_kss.ELEMENT_TYPE_ID            := Kronos_Header_Rec.ELEMENT_TYPE_ID;
     r_ttec_pay_pay_iface_kss.ASSIGNMENT_NUMBER          := Kronos_Header_Rec.ASSIGNMENT_NUMBER;
     r_ttec_pay_pay_iface_kss.ASSIGNMENT_ID              := Kronos_Header_Rec.ASSIGNMENT_ID;
     r_ttec_pay_pay_iface_kss.ELEMENT_NAME               := Kronos_Header_Rec.ELEMENT_NAME;
     r_ttec_pay_pay_iface_kss.ENTRY_TYPE                 := Kronos_Header_Rec.ENTRY_TYPE;
     r_ttec_pay_pay_iface_kss.REASON                     := Kronos_Header_Rec.REASON;
     r_ttec_pay_pay_iface_kss.VALUE_1                    := Kronos_Header_Rec.VALUE_1;
     r_ttec_pay_pay_iface_kss.VALUE_2                    := Kronos_Header_Rec.VALUE_2;
     r_ttec_pay_pay_iface_kss.VALUE_3                    := Kronos_Header_Rec.VALUE_3;
     r_ttec_pay_pay_iface_kss.EFFECTIVE_DATE             := Kronos_Header_Rec.EFFECTIVE_DATE;
     r_ttec_pay_pay_iface_kss.DELETIONINDICATOR          := Kronos_Header_Rec.DELETIONINDICATOR;
     r_ttec_pay_pay_iface_kss.EFFECTIVE_START_DATE       := Kronos_Header_Rec.EFFECTIVE_START_DATE;
     r_ttec_pay_pay_iface_kss.EFFECTIVE_END_DATE         := Kronos_Header_Rec.EFFECTIVE_END_DATE;
     r_ttec_pay_pay_iface_kss.LABORLEV3NM                := Kronos_Header_Rec.LABORLEV3NM;
     r_ttec_pay_pay_iface_kss.LABORLEV3DSC               := Kronos_Header_Rec.LABORLEV3DSC;
     r_ttec_pay_pay_iface_kss.EMPLOYEENAME               := Kronos_Header_Rec.EMPLOYEENAME;
     r_ttec_pay_pay_iface_kss.COUNTRY                    := Kronos_Header_Rec.COUNTRY;
     r_ttec_pay_pay_iface_kss.INTERFACE                  := Kronos_Header_Rec.INTERFACE;
     r_ttec_pay_pay_iface_kss.RUNID                      := Kronos_Header_Rec.RUNID;

     r_ttec_pay_pay_iface_kss.BUSINESS_GROUP_ID          := vBusGroup;
     r_ttec_pay_pay_iface_kss.PERSON_ID                  := NULL;
     r_ttec_pay_pay_iface_kss.LEGACY_EMP_NUMBER          := NULL;
     r_ttec_pay_pay_iface_kss.SEQUENCE_NUMBER            := NULL;
     r_ttec_pay_pay_iface_kss.INTERFACE_TYPE             := Kronos_Header_Rec.INTERFACE_TYPE;
     r_ttec_pay_pay_iface_kss.PAYCODE_TYPE               := NULL;

     l_pgm_loc   := '420';
     insert_ttec_pay_pay_iface_kss (ir_ttec_pay_pay_iface_kss => r_ttec_pay_pay_iface_kss);
     IF (G_FATAL_ERROR) THEN
       l_pgm_loc   := '430';
       RAISE G_E_ABORT;
     END IF;

     l_pgm_loc   := '440';
     l_rows_processed := l_rows_processed + 1;

     -- Process the BATCH LINE record
     FOR Kronos_Line_Rec IN Kronos_Line_Csr(vBusGroup, vBatchName) LOOP
         l_pgm_loc   := '500';
         L_ERROR_RECORD:='KRONOS_LINE_CSR for batch ' || vBatchName;

         IF UPPER(Kronos_Line_Rec.assignment_number)=upper(l_last_assignment_number) THEN
           l_sequence_no :=l_sequence_no + 1;
         ELSE
           l_last_assignment_number:=trim(Kronos_Line_Rec.assignment_number);
           l_sequence_no :=1;
         END IF;

         -- get legacy employee number
         l_pgm_loc   := '510';
         Begin
           SELECT PAAF.PERSON_ID,
                  PAAF.ASSIGNMENT_ID,
                  PAPF.ATTRIBUTE12
             INTO
                  l_person_id,
                  l_assignment_id,
                  l_legacy_emp_number
             FROM
                  PER_ALL_ASSIGNMENTS_F PAAF,
                  PER_ALL_PEOPLE_F PAPF
            WHERE
                  PAAF.ASSIGNMENT_NUMBER = Kronos_Line_Rec.ASSIGNMENT_NUMBER
              AND PAAF.BUSINESS_GROUP_ID = vBusGroup
              AND (trunc(Kronos_Line_Rec.effective_date) BETWEEN trunc(PAAF.EFFECTIVE_START_DATE) AND trunc(PAAF.EFFECTIVE_END_DATE))
              AND PAAF.PERSON_ID = PAPF.PERSON_ID
              AND (trunc(Kronos_Line_Rec.effective_date) BETWEEN trunc(PAPF.EFFECTIVE_START_DATE) AND trunc(PAPF.EFFECTIVE_END_DATE));

         Exception
           When others Then
            G_WARNING           := TRUE;
            l_person_id         := NULL;
            l_assignment_id     := NULL;
            l_legacy_emp_number := NULL;
            Printlog (G_LOG_FILE, pad_data_output('VARCHAR2',G_SIZE,'WARNING: legacy employee number can not be found for ASSIGNMENT_NUMBER='
                                                 || Kronos_Line_Rec.ASSIGNMENT_NUMBER));
            IF (G_FATAL_ERROR) THEN
              l_pgm_loc   := '520';
              RAISE G_E_ABORT;
            END IF;
            Printlog (G_LOG_FILE, pad_data_output('VARCHAR2',G_SIZE,'WARNING: NULL legacy employee number is passed and will not be processed'));
            IF (G_FATAL_ERROR) THEN
              l_pgm_loc   := '525';
              RAISE G_E_ABORT;
            END IF;
         End;

         Begin
           SELECT upper(substr(trim(DESCRIPTION),1,3))
             INTO l_paycode_type
             FROM FND_LOOKUP_VALUES
            WHERE LOOKUP_TYPE = G_SGP_PAYCODES_LOOKUP
              AND LOOKUP_CODE = upper(trim(Kronos_Line_Rec.ELEMENT_NAME))
              AND LANGUAGE    = 'US'
              AND ENABLED_FLAG = 'Y'
              AND trunc(sysdate) between trunc(START_DATE_ACTIVE) AND TRUNC(NVL(END_DATE_ACTIVE,SYSDATE));

         Exception
           When others Then
            G_PAYCODE_FATAL := TRUE;
            l_paycode_type := NULL;
            Printlog (G_LOG_FILE, pad_data_output('VARCHAR2',G_SIZE,'WARNING: paycode type can not be found for PAY_CODE='
                                                 || Kronos_Line_Rec.ELEMENT_NAME || ', WILL NOT be processed'));
            IF (G_FATAL_ERROR) THEN
              l_pgm_loc   := '526';
              RAISE G_E_ABORT;
            END IF;
         End;


         r_ttec_pay_pay_iface_kss.BATCH_NAME                 := Kronos_Line_Rec.BATCH_NAME;
         r_ttec_pay_pay_iface_kss.BATCH_DATE                 := Kronos_Line_Rec.BATCH_DATE;
         r_ttec_pay_pay_iface_kss.RECORD_TRACK               := Kronos_Line_Rec.RECORD_TRACK;
         r_ttec_pay_pay_iface_kss.ELEMENT_TYPE_ID            := Kronos_Line_Rec.ELEMENT_TYPE_ID;
         r_ttec_pay_pay_iface_kss.ASSIGNMENT_NUMBER          := Kronos_Line_Rec.ASSIGNMENT_NUMBER;
         r_ttec_pay_pay_iface_kss.ASSIGNMENT_ID              := l_assignment_id;
         r_ttec_pay_pay_iface_kss.ELEMENT_NAME               := Kronos_Line_Rec.ELEMENT_NAME;
         r_ttec_pay_pay_iface_kss.ENTRY_TYPE                 := Kronos_Line_Rec.ENTRY_TYPE;
         r_ttec_pay_pay_iface_kss.REASON                     := Kronos_Line_Rec.REASON;
         r_ttec_pay_pay_iface_kss.VALUE_1                    := Kronos_Line_Rec.VALUE_1;
         r_ttec_pay_pay_iface_kss.VALUE_2                    := Kronos_Line_Rec.VALUE_2;
         r_ttec_pay_pay_iface_kss.VALUE_3                    := Kronos_Line_Rec.VALUE_3;
         r_ttec_pay_pay_iface_kss.EFFECTIVE_DATE             := Kronos_Line_Rec.EFFECTIVE_DATE;
         r_ttec_pay_pay_iface_kss.DELETIONINDICATOR          := Kronos_Line_Rec.DELETIONINDICATOR;
         r_ttec_pay_pay_iface_kss.EFFECTIVE_START_DATE       := Kronos_Line_Rec.EFFECTIVE_START_DATE;
         r_ttec_pay_pay_iface_kss.EFFECTIVE_END_DATE         := Kronos_Line_Rec.EFFECTIVE_END_DATE;
         r_ttec_pay_pay_iface_kss.LABORLEV3NM                := Kronos_Line_Rec.LABORLEV3NM;
         r_ttec_pay_pay_iface_kss.LABORLEV3DSC               := Kronos_Line_Rec.LABORLEV3DSC;
         r_ttec_pay_pay_iface_kss.EMPLOYEENAME               := Kronos_Line_Rec.EMPLOYEENAME;
         r_ttec_pay_pay_iface_kss.COUNTRY                    := Kronos_Line_Rec.COUNTRY;
         r_ttec_pay_pay_iface_kss.INTERFACE                  := Kronos_Line_Rec.INTERFACE;
         r_ttec_pay_pay_iface_kss.RUNID                      := Kronos_Line_Rec.RUNID;

         r_ttec_pay_pay_iface_kss.BUSINESS_GROUP_ID          := vBusGroup;
         r_ttec_pay_pay_iface_kss.PERSON_ID                  := l_person_id;
         r_ttec_pay_pay_iface_kss.LEGACY_EMP_NUMBER          := l_legacy_emp_number;
         r_ttec_pay_pay_iface_kss.SEQUENCE_NUMBER            := l_sequence_no;
         r_ttec_pay_pay_iface_kss.INTERFACE_TYPE             := Kronos_Line_Rec.INTERFACE_TYPE;
         r_ttec_pay_pay_iface_kss.PAYCODE_TYPE               := l_paycode_type;

         l_pgm_loc   := '530';
         insert_ttec_pay_pay_iface_kss (ir_ttec_pay_pay_iface_kss => r_ttec_pay_pay_iface_kss);
         IF (G_FATAL_ERROR) THEN
           l_pgm_loc   := '540';
           RAISE G_E_ABORT;
         END IF;

         l_rows_lines_processed := l_rows_lines_processed + 1;

     END LOOP; -- Kronos_Line_Rec IN Kronos_Line_Csr(vBusGroup, vBatchName)

 END LOOP; -- Kronos_Header_Rec IN Kronos_Header_Csr(vBatchName)

  l_pgm_loc   := '600';
  Printlog (G_LOG_FILE, pad_data_output('VARCHAR2',G_SIZE,'Total ' || l_rows_processed || ' Batch header rows processed in KRONOS.KSS_PAYROLL_ORACLE'));
  IF (G_FATAL_ERROR) THEN
    l_pgm_loc   := '610';
    RAISE G_E_ABORT;
  END IF;
  Printlog (G_LOG_FILE, pad_data_output('VARCHAR2',G_SIZE,'Total ' || l_rows_lines_processed || ' Batch line rows processed in KRONOS.KSS_PAYROLL_ORACLE'));
  IF (G_FATAL_ERROR) THEN
    l_pgm_loc   := '620';
    RAISE G_E_ABORT;
  END IF;

  -- issue warning when processed number of batch line row is zero.
  IF (l_rows_lines_processed = 0) THEN
    G_WARNING           := TRUE;
  END IF;

   -- Make rows (barch header and lines) in KRONOS.KSS_PAYROLL_ORACLE as processed.
   l_pgm_loc   := '700';
   L_ERROR_RECORD := 'Updating DELETIONINDICATOR column in KRONOS.KSS_PAYROLL_ORACLE table for batch ' || vBatchName;
   Printlog (G_LOG_FILE, pad_data_output('VARCHAR2',G_SIZE,'#### START UPDATING KRONOS.KSS_PAYROLL_ORACLE TABLE DELETIONINDICATOR.... ####'));
   IF (G_FATAL_ERROR) THEN
     l_pgm_loc   := '710';
     RAISE G_E_ABORT;
   END IF;

   l_pgm_loc   := '720';
   --UPDATE KRONOS.KSS_PAYROLL_ORACLE --code commented by RXNETHI-ARGANO,15/05/23
   UPDATE APPS.KSS_PAYROLL_ORACLE --code added by RXNETHI-ARGANO,15/05/23
      SET DELETIONINDICATOR='1'
    WHERE UPPER(BATCH_NAME) = UPPER(vBatchName);

   -- At this point entries in KRONOS.KSS_PAYROLL_ORACLE moved to table cust.ttec_pay_iface_kss_direct_tbl table..
   -- now process cust.ttec_pay_iface_kss_direct_tbl and generate output files for RECORD_TRACK ='L' only.
   -- sgppay
   l_pgm_loc   := '800';
   L_ERROR_RECORD := 'PROCESSING CUST.TTEC_PAY_IFACE_KSS_DIRECT_TBL line records for batch ' || vBatchName;
   Printlog (G_LOG_FILE, pad_data_output('VARCHAR2',G_SIZE,'#### START PROCESSING CUST.TTEC_PAY_IFACE_KSS_DIRECT_TBL.... ####'));
   IF (G_FATAL_ERROR) THEN
     l_pgm_loc   := '810';
     RAISE G_E_ABORT;
   END IF;

   -- produce header in leave output file, it will make eaiser to import it to msft excel
   l_line_buffer := 'Legacy Emp Num,Emp Name,Leave Type,Start Date(DD/MM/YYYY),End Date(DD/MM/YYYY),Period End Date(DD/MM/YYYY),Duration(H.HH)';
   Println (G_OUT_LEA_FILE, l_line_buffer);
   IF (G_FATAL_ERROR) THEN
     l_pgm_loc   := '820';
     RAISE G_E_ABORT;
   END IF;

  -- get max number of payroll output fields from fnd_lookup_values table.
  Begin
    SELECT max(to_number(substr(trim(DESCRIPTION),2,2)))
      INTO l_max_col
      FROM FND_LOOKUP_VALUES
     WHERE LOOKUP_TYPE = G_SGP_PAYCODES_LOOKUP
       AND (upper(trim(DESCRIPTION)) like 'P%' OR upper(trim(DESCRIPTION)) like 'B%')
       AND LANGUAGE    = 'US'
       AND ENABLED_FLAG = 'Y'
       AND trunc(sysdate) between trunc(START_DATE_ACTIVE) AND TRUNC(NVL(END_DATE_ACTIVE,SYSDATE));

    Exception
      When others Then
        l_pgm_loc   := '825';
        L_ERROR_RECORD := 'ERROR: Problem to retrive maxinum payroll output fields ';
        Printlog (G_LOG_FILE, pad_data_output('VARCHAR2',G_SIZE,L_ERROR_RECORD));
        RAISE G_E_ABORT;
  End;

  -- initialize totals
  FOR i IN 1 .. l_max_col LOOP
    tot_table(i).total_num := 0.00;
  END LOOP;

  l_last_legacy_emp_number := 'FIRST_TIME_xX';
  FOR kss_direct_line_rec IN  kss_direct_line_csr (vBatchName) LOOP
       l_pgm_loc   := '900';
       IF (kss_direct_line_rec.LEGACY_EMP_NUMBER != l_last_legacy_emp_number AND l_last_legacy_emp_number != 'FIRST_TIME_xX') THEN
         -- produce pay output file as summary
         l_col_total := 0.00;
         FOR i IN 1 .. l_max_col LOOP
           l_col_total := l_col_total + abs(tot_table(i).total_num);
         END LOOP;
         IF ( l_col_total > 0 ) THEN
           l_line_buffer := pad_data_output('VARCHAR2',12,trim(l_last_legacy_emp_number));
           FOR i IN 1 .. l_max_col LOOP
             l_line_buffer := l_line_buffer || pad_data_output('NUMBER',6,to_char(tot_table(i).total_num * 100, 'FM999099'));
           END LOOP;
           Println (G_OUT_PAY_FILE, l_line_buffer);
           IF (G_FATAL_ERROR) THEN
             l_pgm_loc   := '910';
             RAISE G_E_ABORT;
           END IF;
         END IF;

          l_last_legacy_emp_number := kss_direct_line_rec.LEGACY_EMP_NUMBER;
          FOR i IN 1 .. l_max_col LOOP
            tot_table(i).total_num := 0.00;
          END LOOP;
       ELSE
          l_last_legacy_emp_number := kss_direct_line_rec.LEGACY_EMP_NUMBER;
       END IF; -- IF (kss_direct_line_rec.LEGACY_EMP_NUMBER != l_last_legacy_emp_number AND l_last_legacy_emp_number != 'FIRST_TIME_xX')

       l_pgm_loc   := '920';
       IF (   substr(kss_direct_line_rec.PAYCODE_TYPE,1,1) = 'P'
           OR substr(kss_direct_line_rec.PAYCODE_TYPE,1,1) = 'B') THEN
         -- check and issue warning for negative value_1
         IF (to_number(trim(kss_direct_line_rec.VALUE_1)) < 0) THEN
           G_WARNING           := TRUE;
           Printlog (G_LOG_FILE, pad_data_output('VARCHAR2',G_SIZE,'WARNING: NEGATIVE value of value_1=' || kss_direct_line_rec.VALUE_1
                                                 || ', Legacy emp=' || kss_direct_line_rec.LEGACY_EMP_NUMBER
                                                 || ', Pay code=' || kss_direct_line_rec.ELEMENT_NAME));
           IF (G_FATAL_ERROR) THEN
             l_pgm_loc   := '921';
             RAISE G_E_ABORT;
           END IF;
         END IF;
         i := to_number(substr(kss_direct_line_rec.PAYCODE_TYPE,2,2));
         -- IF (upper(substr(trim(kss_direct_line_rec.ELEMENT_NAME),1,5)) = 'SHIFT') THEN
         IF (instr(upper(kss_direct_line_rec.ELEMENT_NAME),'SHIFT',1,1) > 0) THEN
           tot_table(i).total_num := tot_table(i).total_num + 1.00;
         ELSE
           tot_table(i).total_num := tot_table(i).total_num + to_number(trim(kss_direct_line_rec.VALUE_1));
         END IF;
       END IF;

       -- produce leave output file based on pay codes..
       l_pgm_loc   := '930';
       IF (substr(kss_direct_line_rec.PAYCODE_TYPE,1,1) != 'P') THEN
         l_pgm_loc   := '940';

         -- data format of VALUE_3 from kronos is YYYY/MM/DD
         l_line_buffer := trim(kss_direct_line_rec.LEGACY_EMP_NUMBER)                                      || ',' ||
                          replace(trim(kss_direct_line_rec.EMPLOYEENAME),',','')                           || ',' ||
                          trim(kss_direct_line_rec.ELEMENT_NAME)                                           || ',' ||
                          to_char(to_date(trim(kss_direct_line_rec.VALUE_3), 'YYYY/MM/DD'), 'DD/MM/YYYY')  || ',' ||  -- start date
                          to_char(to_date(trim(kss_direct_line_rec.VALUE_3), 'YYYY/MM/DD'), 'DD/MM/YYYY')  || ',' ||  -- end date
                          to_char(kss_direct_line_rec.EFFECTIVE_DATE, 'DD/MM/YYYY')                        || ',' ||  -- posting date
                          trim(kss_direct_line_rec.VALUE_1);
         Println (G_OUT_LEA_FILE, l_line_buffer);
         IF (G_FATAL_ERROR) THEN
           l_pgm_loc   := '950';
           RAISE G_E_ABORT;
         END IF;
       END IF;   -- IF (substr(trim(kss_direct_line_rec.PAYCODE_TYPE),1,1)) != 'P')...

       -- Update line rows as processed
       l_pgm_loc   := '955';
       --UPDATE CUST.TTEC_PAY_IFACE_KSS_DIRECT_TBL --code commented by RXNETHI-ARGANO,15/05/23
	   UPDATE APPS.TTEC_PAY_IFACE_KSS_DIRECT_TBL --code added by RXNETHI-ARGANO,15/05/23
          SET DELETIONINDICATOR = '1'
        WHERE UPPER(BATCH_NAME) = UPPER(vBatchName)
          AND RECORD_TRACK      ='L'
          AND LEGACY_EMP_NUMBER = kss_direct_line_rec.LEGACY_EMP_NUMBER
          AND ELEMENT_NAME      = kss_direct_line_rec.ELEMENT_NAME
          AND ASSIGNMENT_NUMBER = kss_direct_line_rec.ASSIGNMENT_NUMBER
          AND SEQUENCE_NUMBER   = kss_direct_line_rec.SEQUENCE_NUMBER;

       l_pgm_loc   := '956';
       l_ct_grand_tot := l_ct_grand_tot + to_number(trim(kss_direct_line_rec.VALUE_1));

  END LOOP; -- kss_direct_line_rec IN  kss_direct_line_csr (vBatchName)

   -- print the last employees pay output summary line.
   IF (l_last_legacy_emp_number != 'FIRST_TIME_xX') THEN
     l_col_total := 0.00;
     FOR i IN 1 .. l_max_col LOOP
       l_col_total := l_col_total + abs(tot_table(i).total_num);
     END LOOP;
     IF ( l_col_total > 0 ) THEN
       l_line_buffer := pad_data_output('VARCHAR2',12,trim(l_last_legacy_emp_number));
       FOR i IN 1 .. l_max_col LOOP
         l_line_buffer := l_line_buffer || pad_data_output('NUMBER',6,to_char(tot_table(i).total_num * 100, 'FM999099'));
       END LOOP;
       Println (G_OUT_PAY_FILE, l_line_buffer);
        IF (G_FATAL_ERROR) THEN
          l_pgm_loc   := '957';
          RAISE G_E_ABORT;
        END IF;
      END IF;
    END IF;

   -- Update batch header row as processed in CUST.TTEC_PAY_IFACE_KSS_DIRECT_TBL
   l_pgm_loc   := '960';
   L_ERROR_RECORD := 'UPDATING CUST.TTEC_PAY_IFACE_KSS_DIRECT_TBL Header record for batch ' || vBatchName;
   Printlog (G_LOG_FILE, pad_data_output('VARCHAR2',G_SIZE,'#### START UPDATING CUST.TTEC_PAY_IFACE_KSS_DIRECT_TBL HEADER RECORD.... ####'));
   IF (G_FATAL_ERROR) THEN
     l_pgm_loc   := '970';
     RAISE G_E_ABORT;
   END IF;

   l_pgm_loc   := '980';
   --UPDATE CUST.TTEC_PAY_IFACE_KSS_DIRECT_TBL --code commented by RXNETHI-ARGANO,15/05/23
   UPDATE APPS.TTEC_PAY_IFACE_KSS_DIRECT_TBL --code added by RXNETHI-ARGANO,15/05/23
      SET DELETIONINDICATOR='1'
    WHERE UPPER(BATCH_NAME) = UPPER(vBatchName)
      AND RECORD_TRACK ='H';

   -- Report UNPROCESSED line records from CUST.TTEC_PAY_IFACE_KSS_DIRECT_TBL, if any...
   Println (G_LOG_FILE, '                                                                                                                         ');
   IF (G_FATAL_ERROR) THEN
     l_pgm_loc   := '985';
     RAISE G_E_ABORT;
   END IF;

   l_pgm_loc   := '990';
   L_ERROR_RECORD := 'REPORT UNPROCESSED CUST.TTEC_PAY_IFACE_KSS_DIRECT_TBL Line records for batch ' || vBatchName;
   Printlog (G_LOG_FILE, pad_data_output('VARCHAR2',G_SIZE,'#### REPORTING UNPROCESSED CUST.TTEC_PAY_IFACE_KSS_DIRECT_TBL LINE RECORDS.... ####'));
   IF (G_FATAL_ERROR) THEN
     l_pgm_loc   := '995';
     RAISE G_E_ABORT;
   END IF;

   Println (G_LOG_FILE, '=========================================================================================================================');
   IF (G_FATAL_ERROR) THEN
     l_pgm_loc   := '996';
     RAISE G_E_ABORT;
   END IF;

   l_pgm_loc   := '1000';
   FOR kss_direct_line_unproc_rec IN kss_direct_line_unproc_csr(vBatchName) LOOP
       l_unproc_cnt := l_unproc_cnt + 1;
       l_line_buffer := 'ASG_NUM='             || trim(kss_direct_line_unproc_rec.ASSIGNMENT_NUMBER) ||
                        ', LEGACY_EMP_NUM='    || trim(kss_direct_line_unproc_rec.LEGACY_EMP_NUMBER) ||
                        ', ELEMENT_NAME='      || trim(kss_direct_line_unproc_rec.ELEMENT_NAME)      ||
                        ', VALUE1='            || trim(kss_direct_line_unproc_rec.VALUE_1)           ||
                        ', VALUE3='            || trim(kss_direct_line_unproc_rec.VALUE_3)           ||
                        ', PAYCODE_TYPE='      || trim(kss_direct_line_unproc_rec.PAYCODE_TYPE);
       Println (G_LOG_FILE, pad_data_output('VARCHAR2',G_SIZE,l_line_buffer));
       IF (G_FATAL_ERROR) THEN
         l_pgm_loc   := '1010';
         RAISE G_E_ABORT;
       END IF;
   END LOOP;

   Println (G_LOG_FILE, pad_data_output('VARCHAR2',G_SIZE,'#### Total ' || l_unproc_cnt || ' UNPROCESSED LINE RECORDS....####'));
   IF (G_FATAL_ERROR) THEN
     l_pgm_loc   := '1020';
     RAISE G_E_ABORT;
   END IF;

   Println (G_LOG_FILE, '=========================================================================================================================');
   IF (G_FATAL_ERROR) THEN
     l_pgm_loc   := '1025';
     RAISE G_E_ABORT;
   END IF;

   Println (G_LOG_FILE, '                                                                                                                         ');
   IF (G_FATAL_ERROR) THEN
     l_pgm_loc   := '1030';
     RAISE G_E_ABORT;
   END IF;

   -- process control totals based on pay codes.
   Printlog (G_LOG_FILE, pad_data_output('VARCHAR2',G_SIZE,'#### REPORTING CONTROL TOTALS OF PROCESSED RECORDS.... ####'));
   IF (G_FATAL_ERROR) THEN
     l_pgm_loc   := '1100';
     RAISE G_E_ABORT;
   END IF;

   Println (G_LOG_FILE, '=========================================================================================================================');
   IF (G_FATAL_ERROR) THEN
     l_pgm_loc   := '1110';
     RAISE G_E_ABORT;
   END IF;

   l_line_buffer := pad_data_output('VARCHAR2',82,'PAY CODES/CATEGORY') || 'HOUR(H.HH)';
   Println (G_LOG_FILE, pad_data_output('VARCHAR2',G_SIZE,l_line_buffer));
   IF (G_FATAL_ERROR) THEN
     l_pgm_loc   := '1120';
     RAISE G_E_ABORT;
   END IF;

   l_line_buffer := '--------------------------------------------------------------------------------  ----------';
   Printlog (G_LOG_FILE, pad_data_output('VARCHAR2',G_SIZE,l_line_buffer));
   IF (G_FATAL_ERROR) THEN
     l_pgm_loc   := '1130';
     RAISE G_E_ABORT;
   END IF;

   l_pgm_loc   := '1140';
   l_line_buffer := pad_data_output('VARCHAR2',82,'GRAND TOTALS of Processed Records') ||
                    pad_data_output('NUMBER',10,to_char(l_ct_grand_tot, 'FM99999990.00'));

   Println (G_LOG_FILE, pad_data_output('VARCHAR2',G_SIZE,l_line_buffer));
   IF (G_FATAL_ERROR) THEN
     l_pgm_loc   := '1150';
     RAISE G_E_ABORT;
   END IF;

   l_pgm_loc   := '1160';
   FOR kss_direct_ct_rec IN kss_direct_ct_csr (vBatchName) LOOP
     l_line_buffer := pad_data_output('VARCHAR2',82,trim(kss_direct_ct_rec.ELEMENT_NAME))                   ||
                      pad_data_output('NUMBER',10,to_char(kss_direct_ct_rec.pay_code_ct_tot, 'FM99999990.00'));
     Println (G_LOG_FILE, pad_data_output('VARCHAR2',G_SIZE,l_line_buffer));
     IF (G_FATAL_ERROR) THEN
       l_pgm_loc   := '1170';
       RAISE G_E_ABORT;
     END IF;
   END LOOP;

   l_pgm_loc   := '1180';
   Println (G_LOG_FILE, '=========================================================================================================================');
   IF (G_FATAL_ERROR) THEN
     l_pgm_loc   := '1190';
     RAISE G_E_ABORT;
   END IF;

   Println (G_LOG_FILE, '                                                                                                                         ');
   IF (G_FATAL_ERROR) THEN
     l_pgm_loc   := '1195';
     RAISE G_E_ABORT;
   END IF;

EXCEPTION
WHEN G_E_ABORT THEN
 G_FATAL_ERROR := TRUE;
 L_ERROR_MESSAGE := 'Error --> '||SQLERRM;
 L_ERROR_RECORD := L_ERROR_RECORD || ' - Singapore Interface ' || 'in ' || G_PKG_NAME || '.' || l_proc_name || ' pgm_loc=' || l_pgm_loc;
 log_kss_payroll_error (L_ERROR_MESSAGE,L_ERROR_RECORD);
 IF (UTL_FILE.IS_OPEN(G_LOG_FILE) AND G_LOG_FILE_W) THEN
   Printlog (G_LOG_FILE, L_ERROR_RECORD);
   Printlog (G_LOG_FILE, L_ERROR_MESSAGE);
 END IF;

WHEN OTHERS THEN
 G_FATAL_ERROR := TRUE;
 L_ERROR_MESSAGE := 'Error --> '||SQLERRM;
 L_ERROR_RECORD := L_ERROR_RECORD || ' - Singapore Interface ' || 'in ' || G_PKG_NAME || '.' || l_proc_name || ' pgm_loc=' || l_pgm_loc;
 log_kss_payroll_error (L_ERROR_MESSAGE,L_ERROR_RECORD);
 IF (UTL_FILE.IS_OPEN(G_LOG_FILE) AND G_LOG_FILE_W) THEN
   Printlog (G_LOG_FILE, L_ERROR_RECORD);
   Printlog (G_LOG_FILE, L_ERROR_MESSAGE);
 END IF;

END TTEC_SGP_PAY_IFACE;

/********************************************************************/
/* Payroll interface for Malaysia, called by procedure              */
/* TTEC_PAY_IFACE_KRONOS_DIRECT                                     */
/********************************************************************/
PROCEDURE TTEC_MAL_PAY_IFACE
  (vBusGroup  IN number
  ,vBatchName IN varchar2
  ,v_payfile  OUT varchar2
  ,v_leafile  OUT varchar2
  )

IS

l_proc_name                  varchar2(30)   :=NULL;
l_pgm_loc                    varchar2(10)   :=NULL;
l_line_buffer                varchar2(2000) :=NULL;
L_ERROR_RECORD               varchar2(2000) :=NULL;
L_ERROR_MESSAGE              varchar2(2000) :=NULL;

l_out_pay_file_name          VARCHAR2(50)   :=NULL;
l_out_lea_file_name          VARCHAR2(50)   :=NULL;

l_rows_processed             number         :=0;
l_rows_lines_processed       number         :=0;

l_sequence_no                number         :=0;
-- l_last_element_name       varchar(60)    :=NULL;
l_last_assignment_number     varchar2(30)   :=NULL;
l_element_type_id            varchar2(60)   :=NULL;
l_assignment_id              varchar2(60)   :=NULL;

l_person_id                  PER_ALL_PEOPLE_F.PERSON_ID%TYPE :=NULL;
l_legacy_emp_number          PER_ALL_PEOPLE_F.ATTRIBUTE12%TYPE :=NULL;
l_last_legacy_emp_number     PER_ALL_PEOPLE_F.ATTRIBUTE12%TYPE :=NULL;
l_paycode_type               varchar2(10)   :=NULL;

l_unproc_cnt                 number :=0;
l_batch_h_cnt                number :=0;
l_batch_name_like            VARCHAR2(30) :=NULL;
l_ct_grand_tot               NUMBER(10,2) :=0.00;

l_max_col                   BINARY_INTEGER :=0;
i                           BINARY_INTEGER :=0;
l_col_total                 number(8,2)  :=0.00;

TYPE tot_rec IS RECORD (total_num  number(6,2));

TYPE tot_tabtype IS TABLE OF tot_rec
     INDEX BY BINARY_INTEGER;

tot_table tot_tabtype;

-- Cursor for Getting the header records from the staging records.
CURSOR Kronos_Header_Csr(vBatchName varchar2) is
 SELECT Distinct *
   --FROM KRONOS.KSS_PAYROLL_ORACLE --code commented by RXNETHI-ARGANO,15/05/23
   FROM APPS.KSS_PAYROLL_ORACLE --code added by RXNETHI-ARGANO,15/05/23
  WHERE upper(BATCH_NAME) = upper(vBatchName)
    AND record_Track = 'H'
    AND DeletionIndicator=0 ;
Kronos_Header_Rec Kronos_Header_Csr%ROWTYPE;

-- Cursor for Getting the Line Records from the Staging Records, KRONOS.KSS_PAYROLL_ORACLE
CURSOR Kronos_Line_Csr(vBusGroup number, vBatchName varchar2) is
 SELECT
       KPO.BATCH_NAME,
       KPO.BATCH_DATE,
       KPO.RECORD_TRACK,
       KPO.ELEMENT_TYPE_ID,
       KPO.ASSIGNMENT_NUMBER,
       KPO.ASSIGNMENT_ID,
       KPO.ELEMENT_NAME,
       KPO.ENTRY_TYPE,
       KPO.REASON,
       KPO.VALUE_1,
       KPO.VALUE_2,
       KPO.VALUE_3,
       KPO.EFFECTIVE_DATE,
       KPO.DELETIONINDICATOR,
       KPO.EFFECTIVE_START_DATE,
       KPO.EFFECTIVE_END_DATE,
       KPO.LABORLEV3NM,
       KPO.LABORLEV3DSC,
       KPO.EMPLOYEENAME,
       KPO.COUNTRY,
       KPO.INTERFACE,
       KPO.RUNID,
       KPO.INTERFACE_TYPE
  FROM
       --KRONOS.KSS_PAYROLL_ORACLE KPO --code commented by RXNETHI-ARGANO,15/05/23
	   APPS.KSS_PAYROLL_ORACLE KPO --code added by RXNETHI-ARGANO,15/05/23
 WHERE upper(KPO.BATCH_NAME) = upper(vBatchName)
   AND KPO.RECORD_TRACK ='L'
   AND KPO.DELETIONINDICATOR=0
-- to get rid of null values of batch line row after discussion with kronos team.
   AND trim(KPO.ASSIGNMENT_NUMBER) is not null
   AND trim(KPO.ELEMENT_NAME) is not null
-- to get rid of null values of batch line row...
 ORDER BY KPO.BATCH_NAME, KPO.ASSIGNMENT_NUMBER, KPO.ELEMENT_NAME, KPO.EFFECTIVE_DATE;

 Kronos_Line_Rec  Kronos_Line_Csr%ROWTYPE;

 --r_ttec_pay_pay_iface_kss    CUST.TTEC_PAY_IFACE_KSS_DIRECT_TBL%ROWTYPE; --code commented by RXNETHI-ARGANO,15/05/23
 r_ttec_pay_pay_iface_kss    APPS.TTEC_PAY_IFACE_KSS_DIRECT_TBL%ROWTYPE; --code added by RXNETHI-ARGANO,15/05/23

-- Curssr for Getting the Line Records from CUST.TTEC_PAY_IFACE_KSS_DIRECT_TBL
CURSOR kss_direct_line_csr (vBatchName varchar2) is
 SELECT
       BATCH_NAME,
       BATCH_DATE,
       RECORD_TRACK,
       ELEMENT_TYPE_ID,
       ASSIGNMENT_NUMBER,
       ASSIGNMENT_ID,
       ELEMENT_NAME,
       ENTRY_TYPE,
       REASON,
       VALUE_1,
       VALUE_2,
       VALUE_3,
       EFFECTIVE_DATE,
       DELETIONINDICATOR,
       EFFECTIVE_START_DATE,
       EFFECTIVE_END_DATE,
       LABORLEV3NM,
       LABORLEV3DSC,
       EMPLOYEENAME,
       COUNTRY,
       INTERFACE,
       RUNID,
       BUSINESS_GROUP_ID,
       PERSON_ID,
       LEGACY_EMP_NUMBER,
       SEQUENCE_NUMBER,
       INTERFACE_TYPE,
       PAYCODE_TYPE
  FROM
       --CUST.TTEC_PAY_IFACE_KSS_DIRECT_TBL --code commented by RXNETHI-ARGANO,15/05/23
	   APPS.TTEC_PAY_IFACE_KSS_DIRECT_TBL --code added by RXNETHI-ARGANO,15/05/23
 WHERE upper(BATCH_NAME) = upper(vBatchName)
   AND RECORD_TRACK ='L'
   AND DELETIONINDICATOR=0
   AND LEGACY_EMP_NUMBER is NOT NULL
   AND trim(ELEMENT_NAME) is NOT NULL
   AND substr(PAYCODE_TYPE,1,1) in ('P', 'L', 'B')
-- ORDER BY BATCH_NAME, LEGACY_EMP_NUMBER, ELEMENT_NAME, EFFECTIVE_DATE;
   ORDER BY LEGACY_EMP_NUMBER, ELEMENT_NAME;

 kss_direct_line_rec kss_direct_line_csr%ROWTYPE;

-- Curssr for Getting UNPROCESSED line records from CUST.TTEC_PAY_IFACE_KSS_DIRECT_TBL
CURSOR kss_direct_line_unproc_csr (vBatchName varchar2) is
 SELECT
       BATCH_NAME,
       BATCH_DATE,
       RECORD_TRACK,
       ELEMENT_TYPE_ID,
       ASSIGNMENT_NUMBER,
       ASSIGNMENT_ID,
       ELEMENT_NAME,
       ENTRY_TYPE,
       REASON,
       VALUE_1,
       VALUE_2,
       VALUE_3,
       EFFECTIVE_DATE,
       DELETIONINDICATOR,
       EFFECTIVE_START_DATE,
       EFFECTIVE_END_DATE,
       LABORLEV3NM,
       LABORLEV3DSC,
       EMPLOYEENAME,
       COUNTRY,
       INTERFACE,
       RUNID,
       BUSINESS_GROUP_ID,
       PERSON_ID,
       LEGACY_EMP_NUMBER,
       SEQUENCE_NUMBER,
       INTERFACE_TYPE,
       PAYCODE_TYPE
  FROM
       --CUST.TTEC_PAY_IFACE_KSS_DIRECT_TBL --code commented by RXNETHI-ARGANO,15/05/23
	   APPS.TTEC_PAY_IFACE_KSS_DIRECT_TBL --code added by RXNETHI-ARGANO,15/05/23
 WHERE upper(BATCH_NAME) = upper(vBatchName)
   AND RECORD_TRACK ='L'
   AND DELETIONINDICATOR=0
 ORDER BY BATCH_NAME, LEGACY_EMP_NUMBER, ELEMENT_NAME, EFFECTIVE_DATE;

 kss_direct_line_unproc_rec kss_direct_line_unproc_csr%ROWTYPE;

-- Curssr for getting control totals based on pay codes from CUST.TTEC_PAY_IFACE_KSS_DIRECT_TBL
CURSOR kss_direct_ct_csr (vBatchName varchar2) is
 SELECT
       ELEMENT_NAME,
       sum(to_number(VALUE_1)) pay_code_ct_tot
  FROM
       --CUST.TTEC_PAY_IFACE_KSS_DIRECT_TBL --code commented by RXNETHI-ARGANO,15/05/23
	   APPS.TTEC_PAY_IFACE_KSS_DIRECT_TBL --code added by RXNETHI-ARGANO,15/05/23
 WHERE upper(BATCH_NAME) = upper(vBatchName)
   AND RECORD_TRACK ='L'
   AND DELETIONINDICATOR=1
 GROUP BY ELEMENT_NAME;

BEGIN
 l_proc_name := 'TTEC_MAL_PAY_IFACE';
 l_pgm_loc   := '100';

 Printlog (G_LOG_FILE, pad_data_output('VARCHAR2',G_SIZE,'#### START PROCESSING MAL PAYROLL INTERFACE.... ####'));
 IF (G_FATAL_ERROR) THEN
   l_pgm_loc   := '110';
   RAISE G_E_ABORT;
 END IF;

 -- format output file names
 l_out_pay_file_name := replace(trim(vBatchName), ' ', '_');
 l_out_pay_file_name := replace(l_out_pay_file_name, '/', '-');
 l_out_pay_file_name := replace(l_out_pay_file_name, ':', '_');
 l_out_lea_file_name := l_out_pay_file_name;
 l_out_pay_file_name := l_out_pay_file_name || '.pay';
 l_out_lea_file_name := l_out_lea_file_name || '.lea';

 v_payfile := l_out_pay_file_name;
 v_leafile := l_out_lea_file_name;

 -- Open output files
 l_pgm_loc   := '120';
 L_ERROR_RECORD:= 'Opening output file ' || l_out_pay_file_name;
 G_OUT_PAY_FILE := Open_File(l_out_pay_file_name, 'W');
 IF (G_FATAL_ERROR) THEN
   l_pgm_loc   := '130';
   RAISE G_E_ABORT;
 END IF;

 Printlog (G_LOG_FILE, pad_data_output('VARCHAR2',G_SIZE,'OUTPUT FILE DIRECTORY=' || G_UTIL_FILE_OUT_DIR));
 IF (G_FATAL_ERROR) THEN
   l_pgm_loc   := '135';
   RAISE G_E_ABORT;
 END IF;

 Printlog (G_LOG_FILE, pad_data_output('VARCHAR2',G_SIZE,'PAY OUTPUT FILE NAME=' || l_out_pay_file_name));
 IF (G_FATAL_ERROR) THEN
   l_pgm_loc   := '140';
   RAISE G_E_ABORT;
 END IF;

 l_pgm_loc   := '150';
 L_ERROR_RECORD:= 'Opening output file ' || l_out_lea_file_name;
 G_OUT_LEA_FILE := Open_File(l_out_lea_file_name, 'W');
 IF (G_FATAL_ERROR) THEN
   l_pgm_loc   := '160';
   RAISE G_E_ABORT;
 END IF;

 Printlog (G_LOG_FILE, pad_data_output('VARCHAR2',G_SIZE,'LEAVE OUTPUT FILE NAME=' || l_out_lea_file_name));
 IF (G_FATAL_ERROR) THEN
   l_pgm_loc   := '170';
   RAISE G_E_ABORT;
 END IF;

 Println (G_LOG_FILE, '                                                                                                                          ');
 IF (G_FATAL_ERROR) THEN
   l_pgm_loc   := '175';
   RAISE G_E_ABORT;
 END IF;

 Printlog (G_LOG_FILE, pad_data_output('VARCHAR2',G_SIZE,'#### START PROCESSING KRONOS.KSS_PAYROLL_ORACLE TABLE.... ####'));
 IF (G_FATAL_ERROR) THEN
   l_pgm_loc   := '180';
   RAISE G_E_ABORT;
 END IF;

 -- Check batch name in KRONOS.KSS_PAYROLL_ORACLE table if it is already processed before...
 l_pgm_loc   := '200';
 L_ERROR_RECORD:='Checking Batch header record count for batch ' || vBatchName || ' KRONOS.KSS_PAYROLL_ORACLE';
 SELECT count(*)
   INTO l_batch_h_cnt
   --FROM KRONOS.KSS_PAYROLL_ORACLE --code commented by RXNETHI-ARGANO,15/05/23
   FROM APPS.KSS_PAYROLL_ORACLE --code added by RXNETHI-ARGANO,15/05/23
  WHERE upper(BATCH_NAME) = upper(vBatchName)
    AND record_Track = 'H'
    AND DeletionIndicator = 0;

 l_pgm_loc   := '220';
 IF (l_batch_h_cnt = 0) THEN
    Printlog (G_LOG_FILE, 'WARNING: NO unprocessed batch header row exist in KRONOS.KSS_PAYROLL_ORACLE table - no payroll output files will be produced');
    IF (G_FATAL_ERROR) THEN
      l_pgm_loc   := '230';
      RAISE G_E_ABORT;
    END IF;
 END IF;

 -- Check batch name in CUST.TTEC_PAY_IFACE_KSS_DIRECT_TBL table if it is already processed before...
 l_batch_h_cnt := 0;
 l_pgm_loc   := '240';
 L_ERROR_RECORD:='Checking Batch header record count for batch ' || vBatchName || ' CUST.TTEC_PAY_IFACE_KSS_DIRECT_TBL';
 SELECT count(*)
  INTO l_batch_h_cnt
  --FROM CUST.TTEC_PAY_IFACE_KSS_DIRECT_TBL --code commented by RXNETHI-ARGANO,15/05/23
  FROM APPS.TTEC_PAY_IFACE_KSS_DIRECT_TBL --code added by RXNETHI-ARGANO,15/05/23
 WHERE upper(BATCH_NAME) = upper(vBatchName)
   AND record_Track = 'H'
   AND DeletionIndicator = 1;

 l_pgm_loc   := '250';
 IF (l_batch_h_cnt != 0) THEN
    G_DELETE := FALSE;
    Printlog (G_LOG_FILE, 'ERROR: KRONOS Batch name ' || vBatchName || ' already processed before in CUST.TTEC_PAY_IFACE_KSS_DIRECT_TBL');
    IF (G_FATAL_ERROR) THEN
      l_pgm_loc   := '260';
      RAISE G_E_ABORT;
    END IF;
    l_pgm_loc   := '270';
    RAISE G_E_ABORT;
 END IF;

 -- Delete Processed records before processing new records in KRONOS.KSS_PAYROLL_ORACLE table.
 -- When fatal error occurs after successful deletion, deletion of rows will be comitted.

 l_pgm_loc   := '280';
 l_batch_name_like := trim(substr(vBatchName, 0, 7)) || '%';

 -- MDodge 01/08/08 Remove purging of KSS Table from code.
 --   Kronos Connect will take care of the Purge from now on.
/*
 L_ERROR_RECORD:='Delete_batch_rows in KRONOS.KSS_PAYROLL_ORACLE for ' || l_batch_name_like;
 DELETE
   FROM KRONOS.KSS_PAYROLL_ORACLE
   WHERE BATCH_NAME like l_batch_name_like
    AND BATCH_NAME <> vBatchName and DELETIONINDICATOR='1';

 l_pgm_loc   := '290';
 Printlog (G_LOG_FILE, pad_data_output('VARCHAR2',G_SIZE,'#### ROWS DELETED IN KRONOS.KSS_PAYROLL_ORACLE TABLE for ' || l_batch_name_like || ' ####'));
 IF (G_FATAL_ERROR) THEN
   l_pgm_loc   := '300';
   RAISE G_E_ABORT;
 END IF;
*/

 -- Delete Processed records before processing new records in CUST.TTEC_PAY_IFACE_KSS_DIRECT_TBL table
 -- When fatal error occurs after successful deletion, deletion of rows will be comitted.
 l_pgm_loc   := '310';
 L_ERROR_RECORD:='Delete_batch_rows in CUST.TTEC_PAY_IFACE_KSS_DIRECT_TBL for ' || l_batch_name_like;
 DELETE
   --FROM CUST.TTEC_PAY_IFACE_KSS_DIRECT_TBL --code commented by RXNETHI-ARGANO,15/05/23
   FROM APPS.TTEC_PAY_IFACE_KSS_DIRECT_TBL --code added by RXNETHI-ARGANO,15/05/23
  WHERE BATCH_NAME like l_batch_name_like
    AND BATCH_NAME <> vBatchName and DELETIONINDICATOR='1';       -- remember that there is possibility to have DELETIONINDICATOR='0'
                                                                  -- which is unprocessed...

 l_pgm_loc   := '320';
 Printlog (G_LOG_FILE, pad_data_output('VARCHAR2',G_SIZE,'#### ROWS DELETED IN CUST.TTEC_PAY_IFACE_KSS_DIRECT_TBL TABLE for ' || l_batch_name_like || ' ####'
));
 IF (G_FATAL_ERROR) THEN
   l_pgm_loc   := '330';
   RAISE G_E_ABORT;
 END IF;

 -- Now it is ok to process batch rows in KRONOS.KSS_PAYROLL_ORACLE table....
 -- Loop for the Header Records and process the Batch
 -- Batch header may not be needed for these countries, but process it to follow Kronos side.
 l_pgm_loc   := '400';
 FOR Kronos_Header_Rec IN Kronos_Header_Csr(vBatchName) LOOP
     -- insert batch header into CUST.TTEC_PAY_IFACE_KSS_DIRECT_TBL table
     l_pgm_loc   := '410';
     L_ERROR_RECORD:='Processing Batch header record for batch ' || vBatchName;

     r_ttec_pay_pay_iface_kss.BATCH_NAME                 := Kronos_Header_Rec.BATCH_NAME;
     r_ttec_pay_pay_iface_kss.BATCH_DATE                 := Kronos_Header_Rec.BATCH_DATE;
     r_ttec_pay_pay_iface_kss.RECORD_TRACK               := Kronos_Header_Rec.RECORD_TRACK;
     r_ttec_pay_pay_iface_kss.ELEMENT_TYPE_ID            := Kronos_Header_Rec.ELEMENT_TYPE_ID;
     r_ttec_pay_pay_iface_kss.ASSIGNMENT_NUMBER          := Kronos_Header_Rec.ASSIGNMENT_NUMBER;
     r_ttec_pay_pay_iface_kss.ASSIGNMENT_ID              := Kronos_Header_Rec.ASSIGNMENT_ID;
     r_ttec_pay_pay_iface_kss.ELEMENT_NAME               := Kronos_Header_Rec.ELEMENT_NAME;
     r_ttec_pay_pay_iface_kss.ENTRY_TYPE                 := Kronos_Header_Rec.ENTRY_TYPE;
     r_ttec_pay_pay_iface_kss.REASON                     := Kronos_Header_Rec.REASON;
     r_ttec_pay_pay_iface_kss.VALUE_1                    := Kronos_Header_Rec.VALUE_1;
     r_ttec_pay_pay_iface_kss.VALUE_2                    := Kronos_Header_Rec.VALUE_2;
     r_ttec_pay_pay_iface_kss.VALUE_3                    := Kronos_Header_Rec.VALUE_3;
     r_ttec_pay_pay_iface_kss.EFFECTIVE_DATE             := Kronos_Header_Rec.EFFECTIVE_DATE;
     r_ttec_pay_pay_iface_kss.DELETIONINDICATOR          := Kronos_Header_Rec.DELETIONINDICATOR;
     r_ttec_pay_pay_iface_kss.EFFECTIVE_START_DATE       := Kronos_Header_Rec.EFFECTIVE_START_DATE;
     r_ttec_pay_pay_iface_kss.EFFECTIVE_END_DATE         := Kronos_Header_Rec.EFFECTIVE_END_DATE;
     r_ttec_pay_pay_iface_kss.LABORLEV3NM                := Kronos_Header_Rec.LABORLEV3NM;
     r_ttec_pay_pay_iface_kss.LABORLEV3DSC               := Kronos_Header_Rec.LABORLEV3DSC;
     r_ttec_pay_pay_iface_kss.EMPLOYEENAME               := Kronos_Header_Rec.EMPLOYEENAME;
     r_ttec_pay_pay_iface_kss.COUNTRY                    := Kronos_Header_Rec.COUNTRY;
     r_ttec_pay_pay_iface_kss.INTERFACE                  := Kronos_Header_Rec.INTERFACE;
     r_ttec_pay_pay_iface_kss.RUNID                      := Kronos_Header_Rec.RUNID;

     r_ttec_pay_pay_iface_kss.BUSINESS_GROUP_ID          := vBusGroup;
     r_ttec_pay_pay_iface_kss.PERSON_ID                  := NULL;
     r_ttec_pay_pay_iface_kss.LEGACY_EMP_NUMBER          := NULL;
     r_ttec_pay_pay_iface_kss.SEQUENCE_NUMBER            := NULL;
     r_ttec_pay_pay_iface_kss.INTERFACE_TYPE             := Kronos_Header_Rec.INTERFACE_TYPE;
     r_ttec_pay_pay_iface_kss.PAYCODE_TYPE               := NULL;

     l_pgm_loc   := '420';
     insert_ttec_pay_pay_iface_kss (ir_ttec_pay_pay_iface_kss => r_ttec_pay_pay_iface_kss);
     IF (G_FATAL_ERROR) THEN
       l_pgm_loc   := '430';
       RAISE G_E_ABORT;
     END IF;

     l_pgm_loc   := '440';
     l_rows_processed := l_rows_processed + 1;

     -- Process the BATCH LINE record
     FOR Kronos_Line_Rec IN Kronos_Line_Csr(vBusGroup, vBatchName) LOOP
         l_pgm_loc   := '500';
         L_ERROR_RECORD:='KRONOS_LINE_CSR for batch ' || vBatchName;

         IF UPPER(Kronos_Line_Rec.assignment_number)=upper(l_last_assignment_number) THEN
           l_sequence_no :=l_sequence_no + 1;
         ELSE
           l_last_assignment_number:=trim(Kronos_Line_Rec.assignment_number);
           l_sequence_no :=1;
         END IF;

         -- get legacy employee number
         l_pgm_loc   := '510';
         Begin
           SELECT PAAF.PERSON_ID,
                  PAAF.ASSIGNMENT_ID,
                  PAPF.ATTRIBUTE12
             INTO
                  l_person_id,
                  l_assignment_id,
                  l_legacy_emp_number
             FROM
                  PER_ALL_ASSIGNMENTS_F PAAF,
                  PER_ALL_PEOPLE_F PAPF
            WHERE
                  PAAF.ASSIGNMENT_NUMBER = Kronos_Line_Rec.ASSIGNMENT_NUMBER
              AND PAAF.BUSINESS_GROUP_ID = vBusGroup
              AND (trunc(Kronos_Line_Rec.effective_date) BETWEEN trunc(PAAF.EFFECTIVE_START_DATE) AND trunc(PAAF.EFFECTIVE_END_DATE))
              AND PAAF.PERSON_ID = PAPF.PERSON_ID
              AND (trunc(Kronos_Line_Rec.effective_date) BETWEEN trunc(PAPF.EFFECTIVE_START_DATE) AND trunc(PAPF.EFFECTIVE_END_DATE));

         Exception
           When others Then
            G_WARNING           := TRUE;
            l_person_id         := NULL;
            l_assignment_id     := NULL;
            l_legacy_emp_number := NULL;
            Printlog (G_LOG_FILE, pad_data_output('VARCHAR2',G_SIZE,'WARNING: legacy employee number can not be found for ASSIGNMENT_NUMBER='
                                                 || Kronos_Line_Rec.ASSIGNMENT_NUMBER));
            IF (G_FATAL_ERROR) THEN
              l_pgm_loc   := '520';
              RAISE G_E_ABORT;
            END IF;
            Printlog (G_LOG_FILE, pad_data_output('VARCHAR2',G_SIZE,'WARNING: NULL legacy employee number is passed and will not be processed'));
            IF (G_FATAL_ERROR) THEN
              l_pgm_loc   := '525';
              RAISE G_E_ABORT;
            END IF;
         End;

         Begin
           SELECT upper(substr(trim(DESCRIPTION),1,3))
             INTO l_paycode_type
             FROM FND_LOOKUP_VALUES
            WHERE LOOKUP_TYPE = G_MAL_PAYCODES_LOOKUP
              AND LOOKUP_CODE = upper(trim(Kronos_Line_Rec.ELEMENT_NAME))
              AND LANGUAGE    = 'US'
              AND ENABLED_FLAG = 'Y'
              AND trunc(sysdate) between trunc(START_DATE_ACTIVE) AND TRUNC(NVL(END_DATE_ACTIVE,SYSDATE));

         Exception
           When others Then
            G_PAYCODE_FATAL := TRUE;
            l_paycode_type := NULL;
            Printlog (G_LOG_FILE, pad_data_output('VARCHAR2',G_SIZE,'WARNING: paycode type can not be found for PAY_CODE='
                                                 || Kronos_Line_Rec.ELEMENT_NAME || ', WILL NOT be processed'));
            IF (G_FATAL_ERROR) THEN
              l_pgm_loc   := '526';
              RAISE G_E_ABORT;
            END IF;
         End;


         r_ttec_pay_pay_iface_kss.BATCH_NAME                 := Kronos_Line_Rec.BATCH_NAME;
         r_ttec_pay_pay_iface_kss.BATCH_DATE                 := Kronos_Line_Rec.BATCH_DATE;
         r_ttec_pay_pay_iface_kss.RECORD_TRACK               := Kronos_Line_Rec.RECORD_TRACK;
         r_ttec_pay_pay_iface_kss.ELEMENT_TYPE_ID            := Kronos_Line_Rec.ELEMENT_TYPE_ID;
         r_ttec_pay_pay_iface_kss.ASSIGNMENT_NUMBER          := Kronos_Line_Rec.ASSIGNMENT_NUMBER;
         r_ttec_pay_pay_iface_kss.ASSIGNMENT_ID              := l_assignment_id;
         r_ttec_pay_pay_iface_kss.ELEMENT_NAME               := Kronos_Line_Rec.ELEMENT_NAME;
         r_ttec_pay_pay_iface_kss.ENTRY_TYPE                 := Kronos_Line_Rec.ENTRY_TYPE;
         r_ttec_pay_pay_iface_kss.REASON                     := Kronos_Line_Rec.REASON;
         r_ttec_pay_pay_iface_kss.VALUE_1                    := Kronos_Line_Rec.VALUE_1;
         r_ttec_pay_pay_iface_kss.VALUE_2                    := Kronos_Line_Rec.VALUE_2;
         r_ttec_pay_pay_iface_kss.VALUE_3                    := Kronos_Line_Rec.VALUE_3;
         r_ttec_pay_pay_iface_kss.EFFECTIVE_DATE             := Kronos_Line_Rec.EFFECTIVE_DATE;
         r_ttec_pay_pay_iface_kss.DELETIONINDICATOR          := Kronos_Line_Rec.DELETIONINDICATOR;
         r_ttec_pay_pay_iface_kss.EFFECTIVE_START_DATE       := Kronos_Line_Rec.EFFECTIVE_START_DATE;
         r_ttec_pay_pay_iface_kss.EFFECTIVE_END_DATE         := Kronos_Line_Rec.EFFECTIVE_END_DATE;
         r_ttec_pay_pay_iface_kss.LABORLEV3NM                := Kronos_Line_Rec.LABORLEV3NM;
         r_ttec_pay_pay_iface_kss.LABORLEV3DSC               := Kronos_Line_Rec.LABORLEV3DSC;
         r_ttec_pay_pay_iface_kss.EMPLOYEENAME               := Kronos_Line_Rec.EMPLOYEENAME;
         r_ttec_pay_pay_iface_kss.COUNTRY                    := Kronos_Line_Rec.COUNTRY;
         r_ttec_pay_pay_iface_kss.INTERFACE                  := Kronos_Line_Rec.INTERFACE;
         r_ttec_pay_pay_iface_kss.RUNID                      := Kronos_Line_Rec.RUNID;

         r_ttec_pay_pay_iface_kss.BUSINESS_GROUP_ID          := vBusGroup;
         r_ttec_pay_pay_iface_kss.PERSON_ID                  := l_person_id;
         r_ttec_pay_pay_iface_kss.LEGACY_EMP_NUMBER          := l_legacy_emp_number;
         r_ttec_pay_pay_iface_kss.SEQUENCE_NUMBER            := l_sequence_no;
         r_ttec_pay_pay_iface_kss.INTERFACE_TYPE             := Kronos_Line_Rec.INTERFACE_TYPE;
         r_ttec_pay_pay_iface_kss.PAYCODE_TYPE               := l_paycode_type;

         l_pgm_loc   := '530';
         insert_ttec_pay_pay_iface_kss (ir_ttec_pay_pay_iface_kss => r_ttec_pay_pay_iface_kss);
         IF (G_FATAL_ERROR) THEN
           l_pgm_loc   := '540';
           RAISE G_E_ABORT;
         END IF;

         l_rows_lines_processed := l_rows_lines_processed + 1;

     END LOOP; -- Kronos_Line_Rec IN Kronos_Line_Csr(vBusGroup, vBatchName)

 END LOOP; -- Kronos_Header_Rec IN Kronos_Header_Csr(vBatchName)

  l_pgm_loc   := '600';
  Printlog (G_LOG_FILE, pad_data_output('VARCHAR2',G_SIZE,'Total ' || l_rows_processed || ' Batch header rows processed in KRONOS.KSS_PAYROLL_ORACLE'));
  IF (G_FATAL_ERROR) THEN
    l_pgm_loc   := '610';
    RAISE G_E_ABORT;
  END IF;
  Printlog (G_LOG_FILE, pad_data_output('VARCHAR2',G_SIZE,'Total ' || l_rows_lines_processed || ' Batch line rows processed in KRONOS.KSS_PAYROLL_ORACLE'));
  IF (G_FATAL_ERROR) THEN
    l_pgm_loc   := '620';
    RAISE G_E_ABORT;
  END IF;

  -- issue warning when processed number of batch line row is zero.
  IF (l_rows_lines_processed = 0) THEN
    G_WARNING           := TRUE;
  END IF;

   -- Make rows (barch header and lines) in KRONOS.KSS_PAYROLL_ORACLE as processed.
   l_pgm_loc   := '700';
   L_ERROR_RECORD := 'Updating DELETIONINDICATOR column in KRONOS.KSS_PAYROLL_ORACLE table for batch ' || vBatchName;
   Printlog (G_LOG_FILE, pad_data_output('VARCHAR2',G_SIZE,'#### START UPDATING KRONOS.KSS_PAYROLL_ORACLE TABLE DELETIONINDICATOR.... ####'));
   IF (G_FATAL_ERROR) THEN
     l_pgm_loc   := '710';
     RAISE G_E_ABORT;
   END IF;

   l_pgm_loc   := '720';
   --UPDATE KRONOS.KSS_PAYROLL_ORACLE --code commented by RXNETHI-ARGANO,15/05/23
   UPDATE APPS.KSS_PAYROLL_ORACLE --code added by RXNETHI-ARGANO,15/05/23
      SET DELETIONINDICATOR='1'
    WHERE UPPER(BATCH_NAME) = UPPER(vBatchName);

   -- At this point entries in KRONOS.KSS_PAYROLL_ORACLE moved to table cust.ttec_pay_iface_kss_direct_tbl table..
   -- now process cust.ttec_pay_iface_kss_direct_tbl and generate output files for RECORD_TRACK ='L' only.
   -- malpay
   l_pgm_loc   := '800';
   L_ERROR_RECORD := 'PROCESSING CUST.TTEC_PAY_IFACE_KSS_DIRECT_TBL line records for batch ' || vBatchName;
   Printlog (G_LOG_FILE, pad_data_output('VARCHAR2',G_SIZE,'#### START PROCESSING CUST.TTEC_PAY_IFACE_KSS_DIRECT_TBL.... ####'));
   IF (G_FATAL_ERROR) THEN
     l_pgm_loc   := '810';
     RAISE G_E_ABORT;
   END IF;

   -- produce header in leave output file, it will make eaiser to import it to msft excel
   l_line_buffer := 'Legacy Emp Num,Emp Name,Leave Type,Start Date(DD/MM/YYYY),End Date(DD/MM/YYYY),Period End Date(DD/MM/YYYY),Duration(H.HH)';
   Println (G_OUT_LEA_FILE, l_line_buffer);
   IF (G_FATAL_ERROR) THEN
     l_pgm_loc   := '820';
     RAISE G_E_ABORT;
   END IF;

  -- get max number of payroll output fields from fnd_lookup_values table.
  Begin
    SELECT max(to_number(substr(trim(DESCRIPTION),2,2)))
      INTO l_max_col
      FROM FND_LOOKUP_VALUES
     WHERE LOOKUP_TYPE = G_MAL_PAYCODES_LOOKUP
       AND (upper(trim(DESCRIPTION)) like 'P%' OR upper(trim(DESCRIPTION)) like 'B%')
       AND LANGUAGE    = 'US'
       AND ENABLED_FLAG = 'Y'
       AND trunc(sysdate) between trunc(START_DATE_ACTIVE) AND TRUNC(NVL(END_DATE_ACTIVE,SYSDATE));

    Exception
      When others Then
        l_pgm_loc   := '825';
        L_ERROR_RECORD := 'ERROR: Problem to retrive maxinum payroll output fields ';
        Printlog (G_LOG_FILE, pad_data_output('VARCHAR2',G_SIZE,L_ERROR_RECORD));
        RAISE G_E_ABORT;
  End;

  -- initialize totals
  FOR i IN 1 .. l_max_col LOOP
    tot_table(i).total_num := 0.00;
  END LOOP;

  l_last_legacy_emp_number := 'FIRST_TIME_xX';
  FOR kss_direct_line_rec IN  kss_direct_line_csr (vBatchName) LOOP
       l_pgm_loc   := '900';
       IF (kss_direct_line_rec.LEGACY_EMP_NUMBER != l_last_legacy_emp_number AND l_last_legacy_emp_number != 'FIRST_TIME_xX') THEN
         -- produce pay output file as summary
         l_col_total := 0.00;
         FOR i IN 1 .. l_max_col LOOP
           l_col_total := l_col_total + abs(tot_table(i).total_num);
         END LOOP;
         IF ( l_col_total > 0 ) THEN
           l_line_buffer := pad_data_output('VARCHAR2',12,trim(l_last_legacy_emp_number));
           FOR i IN 1 .. l_max_col LOOP
             l_line_buffer := l_line_buffer || pad_data_output('NUMBER',6,to_char(tot_table(i).total_num * 100, 'FM999099'));
           END LOOP;
           Println (G_OUT_PAY_FILE, l_line_buffer);
           IF (G_FATAL_ERROR) THEN
             l_pgm_loc   := '910';
             RAISE G_E_ABORT;
           END IF;
         END IF;

          l_last_legacy_emp_number := kss_direct_line_rec.LEGACY_EMP_NUMBER;
          FOR i IN 1 .. l_max_col LOOP
            tot_table(i).total_num := 0.00;
          END LOOP;
       ELSE
          l_last_legacy_emp_number := kss_direct_line_rec.LEGACY_EMP_NUMBER;
       END IF; -- IF (kss_direct_line_rec.LEGACY_EMP_NUMBER != l_last_legacy_emp_number AND l_last_legacy_emp_number != 'FIRST_TIME_xX')

       l_pgm_loc   := '920';
       IF (   substr(kss_direct_line_rec.PAYCODE_TYPE,1,1) = 'P'
           OR substr(kss_direct_line_rec.PAYCODE_TYPE,1,1) = 'B') THEN
         IF (to_number(trim(kss_direct_line_rec.VALUE_1)) < 0) THEN
           G_WARNING           := TRUE;
           Printlog (G_LOG_FILE, pad_data_output('VARCHAR2',G_SIZE,'WARNING: NEGATIVE value of value_1=' || kss_direct_line_rec.VALUE_1
                                                 || ', Legacy emp=' || kss_direct_line_rec.LEGACY_EMP_NUMBER
                                                 || ', Pay code=' || kss_direct_line_rec.ELEMENT_NAME));
           IF (G_FATAL_ERROR) THEN
             l_pgm_loc   := '921';
             RAISE G_E_ABORT;
           END IF;
         END IF;
         i := to_number(substr(trim(kss_direct_line_rec.PAYCODE_TYPE),2,2));
         -- IF (upper(substr(trim(kss_direct_line_rec.ELEMENT_NAME),1,5)) = 'SHIFT') THEN
         IF (instr(upper(kss_direct_line_rec.ELEMENT_NAME),'SHIFT',1,1) > 0) THEN
           tot_table(i).total_num := tot_table(i).total_num + 1.00;
         ELSE
           tot_table(i).total_num := tot_table(i).total_num + to_number(trim(kss_direct_line_rec.VALUE_1));
         END IF;
       END IF;

       -- produce leave output file based on pay codes..
       l_pgm_loc   := '930';
       IF (substr(kss_direct_line_rec.PAYCODE_TYPE,1,1) != 'P') THEN
         l_pgm_loc   := '940';

         -- data format of VALUE_3 from kronos is YYYY/MM/DD
         l_line_buffer := trim(kss_direct_line_rec.LEGACY_EMP_NUMBER)                                      || ',' ||
                          replace(trim(kss_direct_line_rec.EMPLOYEENAME),',','')                           || ',' ||
                          trim(kss_direct_line_rec.ELEMENT_NAME)                                           || ',' ||
                          to_char(to_date(trim(kss_direct_line_rec.VALUE_3), 'YYYY/MM/DD'), 'DD/MM/YYYY')  || ',' ||  -- start date
                          to_char(to_date(trim(kss_direct_line_rec.VALUE_3), 'YYYY/MM/DD'), 'DD/MM/YYYY')  || ',' ||  -- end date
                          to_char(kss_direct_line_rec.EFFECTIVE_DATE, 'DD/MM/YYYY')                        || ',' ||  -- posting date
                          trim(kss_direct_line_rec.VALUE_1);
         Println (G_OUT_LEA_FILE, l_line_buffer);
         IF (G_FATAL_ERROR) THEN
           l_pgm_loc   := '950';
           RAISE G_E_ABORT;
         END IF;
       END IF;   -- (substr(trim(kss_direct_line_rec.PAYCODE_TYPE),1,1)) != 'P')...

       -- Update line rows as processed
       l_pgm_loc   := '955';
       --UPDATE CUST.TTEC_PAY_IFACE_KSS_DIRECT_TBL --code commented by RXNETHI-ARGANO,15/05/23
	   UPDATE APPS.TTEC_PAY_IFACE_KSS_DIRECT_TBL --code added by RXNETHI-ARGANO,15/05/23
          SET DELETIONINDICATOR = '1'
        WHERE UPPER(BATCH_NAME) = UPPER(vBatchName)
          AND RECORD_TRACK      ='L'
          AND LEGACY_EMP_NUMBER = kss_direct_line_rec.LEGACY_EMP_NUMBER
          AND ELEMENT_NAME      = kss_direct_line_rec.ELEMENT_NAME
          AND ASSIGNMENT_NUMBER = kss_direct_line_rec.ASSIGNMENT_NUMBER
          AND SEQUENCE_NUMBER   = kss_direct_line_rec.SEQUENCE_NUMBER;

       l_pgm_loc   := '956';
       l_ct_grand_tot := l_ct_grand_tot + to_number(trim(kss_direct_line_rec.VALUE_1));

  END LOOP; -- kss_direct_line_rec IN  kss_direct_line_csr (vBatchName)

   -- print the last employees pay output summary line.
   IF (l_last_legacy_emp_number != 'FIRST_TIME_xX') THEN
     l_col_total := 0.00;
     FOR i IN 1 .. l_max_col LOOP
       l_col_total := l_col_total + abs(tot_table(i).total_num);
     END LOOP;
     IF ( l_col_total > 0 ) THEN
       l_line_buffer := pad_data_output('VARCHAR2',12,trim(l_last_legacy_emp_number));
       FOR i IN 1 .. l_max_col LOOP
         l_line_buffer := l_line_buffer || pad_data_output('NUMBER',6,to_char(tot_table(i).total_num * 100, 'FM999099'));
       END LOOP;
       Println (G_OUT_PAY_FILE, l_line_buffer);
        IF (G_FATAL_ERROR) THEN
          l_pgm_loc   := '957';
          RAISE G_E_ABORT;
        END IF;
      END IF;
    END IF;

   -- Update batch header row as processed in CUST.TTEC_PAY_IFACE_KSS_DIRECT_TBL
   l_pgm_loc   := '960';
   L_ERROR_RECORD := 'UPDATING CUST.TTEC_PAY_IFACE_KSS_DIRECT_TBL Header record for batch ' || vBatchName;
   Printlog (G_LOG_FILE, pad_data_output('VARCHAR2',G_SIZE,'#### START UPDATING CUST.TTEC_PAY_IFACE_KSS_DIRECT_TBL HEADER RECORD.... ####'));
   IF (G_FATAL_ERROR) THEN
     l_pgm_loc   := '970';
     RAISE G_E_ABORT;
   END IF;

   l_pgm_loc   := '980';
   --UPDATE CUST.TTEC_PAY_IFACE_KSS_DIRECT_TBL --code commented by RXNETHI-ARGANO,15/05/23
   UPDATE APPS.TTEC_PAY_IFACE_KSS_DIRECT_TBL --code added by RXNETHI-ARGANO,15/05/23
      SET DELETIONINDICATOR='1'
    WHERE UPPER(BATCH_NAME) = UPPER(vBatchName)
      AND RECORD_TRACK ='H';

   -- Report UNPROCESSED line records from CUST.TTEC_PAY_IFACE_KSS_DIRECT_TBL, if any...
   Println (G_LOG_FILE, '                                                                                                                         ');
   IF (G_FATAL_ERROR) THEN
     l_pgm_loc   := '985';
     RAISE G_E_ABORT;
   END IF;

   l_pgm_loc   := '990';
   L_ERROR_RECORD := 'REPORT UNPROCESSED CUST.TTEC_PAY_IFACE_KSS_DIRECT_TBL Line records for batch ' || vBatchName;
   Printlog (G_LOG_FILE, pad_data_output('VARCHAR2',G_SIZE,'#### REPORTING UNPROCESSED CUST.TTEC_PAY_IFACE_KSS_DIRECT_TBL LINE RECORDS.... ####'));
   IF (G_FATAL_ERROR) THEN
     l_pgm_loc   := '995';
     RAISE G_E_ABORT;
   END IF;

   Println (G_LOG_FILE, '=========================================================================================================================');
   IF (G_FATAL_ERROR) THEN
     l_pgm_loc   := '996';
     RAISE G_E_ABORT;
   END IF;

   l_pgm_loc   := '1000';
   FOR kss_direct_line_unproc_rec IN kss_direct_line_unproc_csr(vBatchName) LOOP
       l_unproc_cnt := l_unproc_cnt + 1;
       l_line_buffer := 'ASG_NUM='             || trim(kss_direct_line_unproc_rec.ASSIGNMENT_NUMBER) ||
                        ', LEGACY_EMP_NUM='    || trim(kss_direct_line_unproc_rec.LEGACY_EMP_NUMBER) ||
                        ', ELEMENT_NAME='      || trim(kss_direct_line_unproc_rec.ELEMENT_NAME)      ||
                        ', VALUE1='            || trim(kss_direct_line_unproc_rec.VALUE_1)           ||
                        ', VALUE3='            || trim(kss_direct_line_unproc_rec.VALUE_3)           ||
                        ', PAYCODE_TYPE='      || trim(kss_direct_line_unproc_rec.PAYCODE_TYPE);
       Println (G_LOG_FILE, pad_data_output('VARCHAR2',G_SIZE,l_line_buffer));
       IF (G_FATAL_ERROR) THEN
         l_pgm_loc   := '1010';
         RAISE G_E_ABORT;
       END IF;
   END LOOP;

   Println (G_LOG_FILE, pad_data_output('VARCHAR2',G_SIZE,'#### Total ' || l_unproc_cnt || ' UNPROCESSED LINE RECORDS....####'));
   IF (G_FATAL_ERROR) THEN
     l_pgm_loc   := '1020';
     RAISE G_E_ABORT;
   END IF;

   Println (G_LOG_FILE, '=========================================================================================================================');
   IF (G_FATAL_ERROR) THEN
     l_pgm_loc   := '1025';
     RAISE G_E_ABORT;
   END IF;

   Println (G_LOG_FILE, '                                                                                                                         ');
   IF (G_FATAL_ERROR) THEN
     l_pgm_loc   := '1030';
     RAISE G_E_ABORT;
   END IF;

   -- process control totals based on pay codes.
   Printlog (G_LOG_FILE, pad_data_output('VARCHAR2',G_SIZE,'#### REPORTING CONTROL TOTALS OF PROCESSED RECORDS.... ####'));
   IF (G_FATAL_ERROR) THEN
     l_pgm_loc   := '1100';
     RAISE G_E_ABORT;
   END IF;

   Println (G_LOG_FILE, '=========================================================================================================================');
   IF (G_FATAL_ERROR) THEN
     l_pgm_loc   := '1110';
     RAISE G_E_ABORT;
   END IF;

   l_line_buffer := pad_data_output('VARCHAR2',82,'PAY CODES/CATEGORY') || 'HOUR(H.HH)';
   Println (G_LOG_FILE, pad_data_output('VARCHAR2',G_SIZE,l_line_buffer));
   IF (G_FATAL_ERROR) THEN
     l_pgm_loc   := '1120';
     RAISE G_E_ABORT;
   END IF;

   l_line_buffer := '--------------------------------------------------------------------------------  ----------';
   Println (G_LOG_FILE, pad_data_output('VARCHAR2',G_SIZE,l_line_buffer));
   IF (G_FATAL_ERROR) THEN
     l_pgm_loc   := '1130';
     RAISE G_E_ABORT;
   END IF;

   l_pgm_loc   := '1140';
   l_line_buffer := pad_data_output('VARCHAR2',82,'GRAND TOTALS of Processed Records') ||
                    pad_data_output('NUMBER',10,to_char(l_ct_grand_tot, 'FM99999990.00'));

   Println (G_LOG_FILE, pad_data_output('VARCHAR2',G_SIZE,l_line_buffer));
   IF (G_FATAL_ERROR) THEN
     l_pgm_loc   := '1150';
     RAISE G_E_ABORT;
   END IF;

   l_pgm_loc   := '1160';
   FOR kss_direct_ct_rec IN kss_direct_ct_csr (vBatchName) LOOP
     l_line_buffer := pad_data_output('VARCHAR2',82,trim(kss_direct_ct_rec.ELEMENT_NAME))                   ||
                      pad_data_output('NUMBER',10,to_char(kss_direct_ct_rec.pay_code_ct_tot, 'FM99999990.00'));
     Println (G_LOG_FILE, pad_data_output('VARCHAR2',G_SIZE,l_line_buffer));
     IF (G_FATAL_ERROR) THEN
       l_pgm_loc   := '1170';
       RAISE G_E_ABORT;
     END IF;
   END LOOP;

   l_pgm_loc   := '1180';
   Println (G_LOG_FILE, '=========================================================================================================================');
   IF (G_FATAL_ERROR) THEN
     l_pgm_loc   := '1190';
     RAISE G_E_ABORT;
   END IF;

   Println (G_LOG_FILE, '                                                                                                                         ');
   IF (G_FATAL_ERROR) THEN
     l_pgm_loc   := '1195';
     RAISE G_E_ABORT;
   END IF;

EXCEPTION
WHEN G_E_ABORT THEN
 G_FATAL_ERROR := TRUE;
 L_ERROR_MESSAGE := 'Error --> '||SQLERRM;
 L_ERROR_RECORD := L_ERROR_RECORD || ' - Malaysia Interface ' || 'in ' || G_PKG_NAME || '.' || l_proc_name || ' pgm_loc=' || l_pgm_loc;
 log_kss_payroll_error (L_ERROR_MESSAGE,L_ERROR_RECORD);
 IF (UTL_FILE.IS_OPEN(G_LOG_FILE) AND G_LOG_FILE_W) THEN
   Printlog (G_LOG_FILE, L_ERROR_RECORD);
   Printlog (G_LOG_FILE, L_ERROR_MESSAGE);
 END IF;

WHEN OTHERS THEN
 G_FATAL_ERROR := TRUE;
 L_ERROR_MESSAGE := 'Error --> '||SQLERRM;
 L_ERROR_RECORD := L_ERROR_RECORD || ' - Malaysia Interface ' || 'in ' || G_PKG_NAME || '.' || l_proc_name || ' pgm_loc=' || l_pgm_loc;
 log_kss_payroll_error (L_ERROR_MESSAGE,L_ERROR_RECORD);
 IF (UTL_FILE.IS_OPEN(G_LOG_FILE) AND G_LOG_FILE_W) THEN
   Printlog (G_LOG_FILE, L_ERROR_RECORD);
   Printlog (G_LOG_FILE, L_ERROR_MESSAGE);
 END IF;

END TTEC_MAL_PAY_IFACE;

-- directx
/********************************************************************/
/* This procedure is executed by KRONOS CONNECT process             */
/********************************************************************/
PROCEDURE TTEC_PAY_IFACE_KRONOS_DIRECT
  (vCountryCode  IN varchar2
  ,vBatchName    IN varchar2
  )

IS

l_proc_name                  varchar2(30)   :=NULL;
l_pgm_loc                    varchar2(10)   :=NULL;
L_ERROR_RECORD               varchar2(2000) :=NULL;
L_ERROR_MESSAGE              varchar2(2000) :=NULL;

l_log_file_name              VARCHAR2(50)   :=NULL;
l_business_group_name        PER_BUSINESS_GROUPS.NAME%TYPE :=NULL;
l_business_group_id          NUMBER;
l_target_dir                 VARCHAR2(100)  :=NULL;
l_payfile                    VARCHAR2(50)   :=NULL;
l_leafile                    VARCHAR2(50)   :=NULL;
l_push_status                VARCHAR2(80)   :=NULL;

BEGIN
  l_proc_name := 'TTEC_PAY_IFACE_KRONOS_DIRECT';
  l_pgm_loc   := '100';

  G_BATCH_NAME := vBatchName;

  IF (vBatchName IS NULL) THEN
    -- log error in kronos.kss_payroll_error table.
    L_ERROR_MESSAGE := 'Error --> Null Kornos batch name is passed';
    L_ERROR_RECORD := 'Null Kornos batch name ' || 'in ' || G_PKG_NAME || '.' || l_proc_name || ' pgm_loc=' || l_pgm_loc;
    log_kss_payroll_error (L_ERROR_MESSAGE,L_ERROR_RECORD);
    RAISE G_E_ABORT;
  END IF;

  l_pgm_loc   := '110';

  -- format log flat file name.
  l_pgm_loc   := '200';
  l_log_file_name := replace(trim(vBatchName), ' ', '_');
  l_log_file_name := replace(l_log_file_name, '/', '-');
  l_log_file_name := l_log_file_name || '.log';

  -- Open log flat files.
  l_pgm_loc   := '300';
  G_LOG_FILE := Open_File(l_log_file_name, 'W');
  G_LOG_FILE_W := TRUE;
  IF (G_FATAL_ERROR) THEN
    RAISE G_E_ABORT;
  END IF;

  l_pgm_loc   := '310';
  Printlog (G_LOG_FILE, pad_data_output('VARCHAR2',G_SIZE,'RUN DATE=' || to_char(sysdate, 'MM/DD/YYYY HH24:MI:SS')));
  IF (G_FATAL_ERROR) THEN
    RAISE G_E_ABORT;
  END IF;
  Printlog (G_LOG_FILE, pad_data_output('VARCHAR2',G_SIZE,'KRONOS BATCH NAME=' || G_BATCH_NAME));
  IF (G_FATAL_ERROR) THEN
    RAISE G_E_ABORT;
  END IF;
  Printlog (G_LOG_FILE, pad_data_output('VARCHAR2',G_SIZE,'COUNTRY CODE=' || vCountryCode));
  IF (G_FATAL_ERROR) THEN
    RAISE G_E_ABORT;
  END IF;

  l_pgm_loc := '320';
  -- Get Business Group ID for input Country Code
  SELECT hou.business_group_id
    INTO l_business_group_id
    --FROM hr.hr_all_organization_units HOU    --code commented by rXNETHI-ARGANO,15/05/23
    --   , hr.hr_locations_all hl              --code commented by rXNETHI-ARGANO,15/05/23
	FROM apps.hr_all_organization_units HOU    --code added by RXNETHI-ARGANO,15/05/23
       , apps.hr_locations_all hl              --code added by RXNETHI-ARGANO,15/05/23
   WHERE hou.ORGANIZATION_ID =
            (CASE WHEN hou.business_group_id !=5054 THEN hou.business_group_id ELSE
               (SELECT TO_NUMBER(SUBSTR(SYS_CONNECT_BY_PATH(pose.organization_id_child,'-')
                                        ,2 ,INSTR(SYS_CONNECT_BY_PATH(pose.organization_id_child,'-')||'-','-',2)
                                                  - 2))
                  FROM per_org_structure_elements pose
                     , hr_all_organization_units org
                     , hr_all_organization_units orc
                     , per_org_structure_versions pvr
                 WHERE pvr.business_group_id = 5054
                   AND TRUNC(SYSDATE) BETWEEN pvr.date_from AND NVL(pvr.date_to, SYSDATE)
                   AND pose.org_structure_version_id = pvr.org_structure_version_id
                   AND org.organization_id = pose.organization_id_parent
                   AND orc.organization_id = pose.organization_id_child
                   AND pose.organization_id_child = hou.organization_id
                START WITH pose.organization_id_parent = 5054
                CONNECT BY PRIOR pose.organization_id_child = pose.organization_id_parent) END)
     AND hl.location_id = hou.location_id
     AND hl.country = vCountryCode;

  l_pgm_loc := '330';
  Printlog (G_LOG_FILE, pad_data_output('VARCHAR2',G_SIZE,'BUSINESS GROUP ID=' || l_business_group_id));
  IF (G_FATAL_ERROR) THEN
    RAISE G_E_ABORT;
  END IF;

  -- validate business group id and get its name.
  l_pgm_loc   := '400';
  l_business_group_name := validate_business_group (l_business_group_id);
  IF (G_FATAL_ERROR) THEN
    RAISE G_E_ABORT;
  END IF;

  l_pgm_loc   := '450';
  Printlog (G_LOG_FILE, pad_data_output('VARCHAR2',G_SIZE,'BUSINESS GROUP NAME=' || l_business_group_name));
  IF (G_FATAL_ERROR) THEN
    RAISE G_E_ABORT;
  END IF;

  l_pgm_loc   := '460';
  Println (G_LOG_FILE, '                                                                                                                          ');
  IF (G_FATAL_ERROR) THEN
    RAISE G_E_ABORT;
  END IF;

  IF (l_business_group_name = 'TeleTech Holdings - MAL') THEN
    l_pgm_loc   := '600';
    --DBMS_OUTPUT.PUT_LINE('MAL business_group_name');
    l_target_dir := G_MAL_TARGET_DIR;
    TTEC_MAL_PAY_IFACE (l_business_group_id, vBatchName, l_payfile, l_leafile);
    l_pgm_loc   := '609';
    IF (G_FATAL_ERROR) THEN
      RAISE G_E_ABORT;
    END IF;
  END IF;

  IF (l_business_group_name = 'TeleTech Holdings - SGP') THEN
    l_pgm_loc   := '620';
    --DBMS_OUTPUT.PUT_LINE('SGP business_group_name');
    l_target_dir := G_SGP_TARGET_DIR;
    TTEC_SGP_PAY_IFACE (l_business_group_id, vBatchName, l_payfile, l_leafile);
    l_pgm_loc   := '629';
    IF (G_FATAL_ERROR) THEN
      RAISE G_E_ABORT;
    END IF;
  END IF;

  IF (l_business_group_name = 'TeleTech Holdings - HKG') THEN
    l_pgm_loc   := '640';
    --DBMS_OUTPUT.PUT_LINE('HKG business_group_name');
    l_target_dir := G_HKG_TARGET_DIR;
    TTEC_HKG_PAY_IFACE (l_business_group_id, vBatchName, l_payfile, l_leafile);
    l_pgm_loc   := '649';
    IF (G_FATAL_ERROR) THEN
      RAISE G_E_ABORT;
    END IF;
  END IF;

  IF (l_business_group_name = 'TeleTech Holdings - NZ') THEN
    l_pgm_loc   := '660';
    --DBMS_OUTPUT.PUT_LINE('NZ business_group_name');
    l_target_dir := G_NZ_TARGET_DIR;
    TTEC_NZ_PAY_IFACE (l_business_group_id, vBatchName, l_payfile, l_leafile);
    l_pgm_loc   := '669';
    IF (G_FATAL_ERROR) THEN
      RAISE G_E_ABORT;
    END IF;
  END IF;

  -- Close output files and log file (last)...
  l_pgm_loc   := '720';
  Close_File(G_OUT_PAY_FILE);
  IF (G_FATAL_ERROR) THEN
    RAISE G_E_ABORT;
  END IF;

  l_pgm_loc   := '730';
  IF (UTL_FILE.IS_OPEN(G_OUT_LEA_FILE)) THEN
    Close_File(G_OUT_LEA_FILE);
    IF (G_FATAL_ERROR) THEN
      RAISE G_E_ABORT;
    END IF;
  END IF;

  l_pgm_loc   := '740';
  IF (G_PAYCODE_FATAL) THEN
    l_pgm_loc   := '749';
    RAISE G_PAYCODE_ABORT;
  END IF;

  l_pgm_loc   := '750';
  COMMIT;  -- for normal end of processing, at after this point, DO NOT raise G_E_ABORT, because commit is done.

  l_pgm_loc   := '755';
  Printlog (G_LOG_FILE, pad_data_output('VARCHAR2',G_SIZE, '#### PAYROLL INTERFACE HAS BEEN PROCESSED SUCCESSFULLY - COMMIT DONE.... ####'));
  IF (G_FATAL_ERROR) THEN
    RAISE G_PUSH_ABORT;
  END IF;

-- Push (Copy) payroll output files to target directory, via submission of conc program and checking status.
  l_pgm_loc   := '760';
  Printlog (G_LOG_FILE, pad_data_output('VARCHAR2',G_SIZE, '#### PUSHING OUTPUT FILES TO DIRECTORY ' || l_target_dir || ' ####'));
  IF (G_FATAL_ERROR) THEN
    RAISE G_PUSH_ABORT;
  END IF;

  l_pgm_loc   := '765';
  gbp2_pay_data_push(G_UTIL_FILE_OUT_DIR,l_payfile,l_leafile,l_target_dir,l_push_status);

  l_pgm_loc   := '770';
  IF (l_push_status != 'COMPLETE_NORMAL') THEN
    G_WARNING           := TRUE;
    Printlog (G_LOG_FILE, pad_data_output('VARCHAR2',G_SIZE,'WARNING: FILE PUSH NOT DONE .... Required to push files manually...'));
      IF (G_FATAL_ERROR) THEN
        l_pgm_loc   := '771';
        RAISE G_PUSH_ABORT;
      END IF;
  ELSE
    Printlog (G_LOG_FILE, pad_data_output('VARCHAR2',G_SIZE,'#### SUCCESSFUL FILE PUSH DONE .... ####'));
      IF (G_FATAL_ERROR) THEN
        l_pgm_loc   := '772';
        RAISE G_PUSH_ABORT;
      END IF;
  END IF;

  l_pgm_loc   := '798';
  Printlog (G_LOG_FILE, pad_data_output('VARCHAR2',G_SIZE,'#### SENDING EMAIL TO ' || l_business_group_name || ' USER.... ####'));
  IF (G_FATAL_ERROR) THEN
    RAISE G_EMAIL_ABORT;
  END IF;

  -- Close log file
  l_pgm_loc   := '799';
  Close_File(G_LOG_FILE);
  G_LOG_FILE_W := FALSE;
  IF (G_FATAL_ERROR) THEN
    RAISE G_EMAIL_ABORT;
  END IF;

  -- Now, send email for successful interface completion... S - for success
  -- Everything is done at this point, so even if there are any error on further operations
  -- G_FATAL_ERROR flag will be ignored(not to raise g_e_abort exception), and G_EMAIL_ERROR will be tracked to
  -- log error message in log file, when any error is encountered.
  -- G_EMAIL_ABORT exception will be raised, instead of G_E_ABORT exception.
  l_pgm_loc   := '800';
  IF (G_WARNING) THEN     -- for missing hr data, negative value_1 for MAL and SGP, push payroll conc pgm error cases...
    l_pgm_loc   := '820';
    send_email (l_business_group_name, l_log_file_name,'SW');
    IF (G_EMAIL_ERROR) THEN
      l_pgm_loc   := '829';
      RAISE G_EMAIL_ABORT;
    END IF;
  END IF;

  IF (G_WARNING = FALSE) THEN   -- check G_FTP_ERROR (AND G_FTP_ERROR = FALSE)
    l_pgm_loc   := '830';
    send_email (l_business_group_name, l_log_file_name,'S');
    IF (G_EMAIL_ERROR) THEN
      l_pgm_loc   := '839';
      RAISE G_EMAIL_ABORT;
    END IF;
  END IF;

  -- Close log file for the last time
  l_pgm_loc   := '900';
  Close_File(G_LOG_FILE);
  G_LOG_FILE_W := FALSE;
  l_pgm_loc   := '910';
  IF (G_FATAL_ERROR) THEN
    RAISE G_EMAIL_ABORT;
  END IF;

EXCEPTION
WHEN G_E_ABORT THEN
 L_ERROR_MESSAGE := 'Error --> '||SQLERRM;
 L_ERROR_RECORD := 'Error in ' || G_PKG_NAME || '.' || l_proc_name || ' pgm_loc=' || l_pgm_loc;
 log_kss_payroll_error (L_ERROR_MESSAGE,L_ERROR_RECORD);
 delete_ttec_pay_iface_kss;  -- for manual rollback of table CUST.TTEC_PAY_IFACE_KSS_DIRECT_TBL
 COMMIT;                     -- to save logged error in table KRONOS.KSS_PAYROLL_ERROR table
 IF (UTL_FILE.IS_OPEN(G_LOG_FILE) AND G_LOG_FILE_W) THEN
   Printlog (G_LOG_FILE, L_ERROR_RECORD);
   Printlog (G_LOG_FILE, L_ERROR_MESSAGE);
 END IF;
 send_email (l_business_group_name, l_log_file_name,'F');
 UTL_FILE.FCLOSE_ALL;

WHEN G_PAYCODE_ABORT THEN
 L_ERROR_MESSAGE := 'Error --> PAYROLL INTERFACE FAILED DUE TO PAYCODE TYPES PROBLEM - DISCARD OUTPUT FILES, USE TTEC GBP2 PAYROLL DATA PRINT '
                    || 'concurrent program for reproduce output file ';
 L_ERROR_RECORD := 'Error in ' || G_PKG_NAME || '.' || l_proc_name || ' pgm_loc=' || l_pgm_loc;
 log_kss_payroll_error (L_ERROR_MESSAGE,L_ERROR_RECORD);
-- delete_ttec_pay_iface_kss;  -- for manual rollback of table CUST.TTEC_PAY_IFACE_KSS_DIRECT_TBL
 COMMIT;                     -- to save logged error in table KRONOS.KSS_PAYROLL_ERROR table
 IF (UTL_FILE.IS_OPEN(G_LOG_FILE) AND G_LOG_FILE_W) THEN
   Printlog (G_LOG_FILE, L_ERROR_RECORD);
   Printlog (G_LOG_FILE, L_ERROR_MESSAGE);
 END IF;
 send_email (l_business_group_name, l_log_file_name,'F');
 UTL_FILE.FCLOSE_ALL;

WHEN G_PUSH_ABORT THEN
 L_ERROR_MESSAGE := 'Error --> '||SQLERRM;
 L_ERROR_RECORD := 'Error in ' || G_PKG_NAME || '.' || l_proc_name || ' pgm_loc=' || l_pgm_loc;
 log_kss_payroll_error (L_ERROR_MESSAGE,L_ERROR_RECORD);
 COMMIT;                     -- to save logged error in table KRONOS.KSS_PAYROLL_ERROR table
 IF (UTL_FILE.IS_OPEN(G_LOG_FILE) AND G_LOG_FILE_W) THEN
   Printlog (G_LOG_FILE, L_ERROR_RECORD);
   Printlog (G_LOG_FILE, L_ERROR_MESSAGE);
 END IF;
 send_email (l_business_group_name, l_log_file_name,'SW');
 UTL_FILE.FCLOSE_ALL;

WHEN G_EMAIL_ABORT THEN
 L_ERROR_MESSAGE := 'Error --> '||SQLERRM;
 L_ERROR_RECORD := 'Error in ' || G_PKG_NAME || '.' || l_proc_name || ' pgm_loc=' || l_pgm_loc;
 log_kss_payroll_error (L_ERROR_MESSAGE,L_ERROR_RECORD);
 COMMIT;                     -- to save logged error in table KRONOS.KSS_PAYROLL_ERROR table
 IF (UTL_FILE.IS_OPEN(G_LOG_FILE) AND G_LOG_FILE_W) THEN
   Printlog (G_LOG_FILE, L_ERROR_RECORD);
   Printlog (G_LOG_FILE, L_ERROR_MESSAGE);
 END IF;
 UTL_FILE.FCLOSE_ALL;

WHEN OTHERS THEN
 L_ERROR_MESSAGE := 'Error --> '||SQLERRM;
 L_ERROR_RECORD := 'Error in ' || G_PKG_NAME || '.' || l_proc_name || ' pgm_loc=' || l_pgm_loc;
 log_kss_payroll_error (L_ERROR_MESSAGE,L_ERROR_RECORD);
 delete_ttec_pay_iface_kss;  -- for manual rollback of table CUST.TTEC_PAY_IFACE_KSS_DIRECT_TBL
 COMMIT;                     -- to save logged error in table KRONOS.KSS_PAYROLL_ERROR table
 IF (UTL_FILE.IS_OPEN(G_LOG_FILE) AND G_LOG_FILE_W) THEN
   Printlog (G_LOG_FILE, L_ERROR_RECORD);
   Printlog (G_LOG_FILE, L_ERROR_MESSAGE);
 END IF;
 send_email (l_business_group_name, l_log_file_name,'F');
 UTL_FILE.FCLOSE_ALL;

END TTEC_PAY_IFACE_KRONOS_DIRECT; -- procedure


/********************************************************************/
/* This procedure is executed by Concurrent Program                 */
/********************************************************************/

PROCEDURE TTEC_PAY_IFACE_KSS_PRNT
  (ov_errbuf       out varchar2
  ,ov_retcode      out number
  ,vBatchName       in varchar2
  )

IS

l_proc_name                  varchar2(30)   :=NULL;
l_pgm_loc                    varchar2(10)   :=NULL;
L_ERROR_RECORD               varchar2(2000) :=NULL;
L_ERROR_MESSAGE              varchar2(2000) :=NULL;
l_line_buffer                varchar2(2000) :=NULL;

-- l_error_buffer               varchar2(2000) :=NULL;

l_out_pay_file_name          VARCHAR2(50)   :=NULL;
l_out_lea_file_name          VARCHAR2(50)   :=NULL;

l_rows_lines_processed       number         :=0;
l_unproc_cnt                 number         :=0;
l_upd_cnt                    number         :=0;

l_assignment_id              varchar2(60)   :=NULL;
l_person_id                  PER_ALL_PEOPLE_F.PERSON_ID%TYPE                :=NULL;
l_legacy_emp_number          PER_ALL_PEOPLE_F.ATTRIBUTE12%TYPE              :=NULL;
l_last_legacy_emp_number     PER_ALL_PEOPLE_F.ATTRIBUTE12%TYPE              :=NULL;
l_business_group_id          PER_BUSINESS_GROUPS.BUSINESS_GROUP_ID%TYPE     :=NULL;
l_business_group_name        PER_BUSINESS_GROUPS.NAME%TYPE                  :=NULL;

l_paycode_lookup             varchar2(30)   :=NULL;
l_paycode_type               varchar2(10)   :=NULL;
l_deletionindicator          varchar2(1)    :=NULL;
l_max_col                   BINARY_INTEGER  :=0;
i                           BINARY_INTEGER  :=0;
l_col_total                 number(8,2)    :=0.00;

TYPE tot_rec IS RECORD (total_num  number(6,2));

TYPE tot_tabtype IS TABLE OF tot_rec
     INDEX BY BINARY_INTEGER;

tot_table tot_tabtype;

-- Curssr for Getting the Line Records from CUST.TTEC_PAY_IFACE_KSS_DIRECT_TBL
CURSOR kss_direct_line_csr (vBatchName varchar2) is
 SELECT
       BATCH_NAME,
       BATCH_DATE,
       RECORD_TRACK,
       ELEMENT_TYPE_ID,
       ASSIGNMENT_NUMBER,
       ASSIGNMENT_ID,
       ELEMENT_NAME,
       ENTRY_TYPE,
       REASON,
       VALUE_1,
       VALUE_2,
       VALUE_3,
       EFFECTIVE_DATE,
       DELETIONINDICATOR,
       EFFECTIVE_START_DATE,
       EFFECTIVE_END_DATE,
       LABORLEV3NM,
       LABORLEV3DSC,
       EMPLOYEENAME,
       COUNTRY,
       INTERFACE,
       RUNID,
       BUSINESS_GROUP_ID,
       PERSON_ID,
       LEGACY_EMP_NUMBER,
       SEQUENCE_NUMBER,
       Decode (INTERFACE_TYPE, 1, 'N',
                               2, 'A',
                               3, 'N', NULL) decoded_interface_type,
       PAYCODE_TYPE
  FROM
       --CUST.TTEC_PAY_IFACE_KSS_DIRECT_TBL --code commented by RXNETHI-ARGANO,15/05/23
	   APPS.TTEC_PAY_IFACE_KSS_DIRECT_TBL --code added by RXNETHI-ARGANO,15/05/23
 WHERE upper(BATCH_NAME) = upper(vBatchName)
   AND RECORD_TRACK ='L'
   AND DELETIONINDICATOR=1
   AND LEGACY_EMP_NUMBER is NOT NULL
   AND trim(ELEMENT_NAME) is NOT NULL
   AND substr(PAYCODE_TYPE,1,1) in ('P', 'L', 'B')
 ORDER BY BATCH_NAME, LEGACY_EMP_NUMBER, ELEMENT_NAME, EFFECTIVE_DATE;

 kss_direct_line_rec kss_direct_line_csr%ROWTYPE;

-- Curssr for Getting UNPROCESSED line records from CUST.TTEC_PAY_IFACE_KSS_DIRECT_TBL
CURSOR kss_direct_line_unproc_csr (vBatchName varchar2) is
 SELECT
       BATCH_NAME,
       BATCH_DATE,
       RECORD_TRACK,
       ELEMENT_TYPE_ID,
       ASSIGNMENT_NUMBER,
       ASSIGNMENT_ID,
       ELEMENT_NAME,
       ENTRY_TYPE,
       REASON,
       VALUE_1,
       VALUE_2,
       VALUE_3,
       EFFECTIVE_DATE,
       DELETIONINDICATOR,
       EFFECTIVE_START_DATE,
       EFFECTIVE_END_DATE,
       LABORLEV3NM,
       LABORLEV3DSC,
       EMPLOYEENAME,
       COUNTRY,
       INTERFACE,
       RUNID,
       BUSINESS_GROUP_ID,
       PERSON_ID,
       LEGACY_EMP_NUMBER,
       SEQUENCE_NUMBER,
       INTERFACE_TYPE,
       PAYCODE_TYPE
  FROM
       --CUST.TTEC_PAY_IFACE_KSS_DIRECT_TBL --code commented by RXNETHI-ARGANO,15/05/23
	   APPS.TTEC_PAY_IFACE_KSS_DIRECT_TBL --code added by RXNETHI-ARGANO,15/05/23
 WHERE upper(BATCH_NAME) = upper(vBatchName)
   AND RECORD_TRACK ='L'
   AND DELETIONINDICATOR=0
 ORDER BY BATCH_NAME, LEGACY_EMP_NUMBER, ELEMENT_NAME, EFFECTIVE_DATE;

 kss_direct_line_unproc_rec kss_direct_line_unproc_csr%ROWTYPE;

BEGIN
 l_proc_name := 'TTEC_PAY_IFACE_KSS_PRNT';
 l_pgm_loc   := '100';

 G_BATCH_NAME := vBatchName;

 fnd_file.put_line(fnd_file.log,'#### START PRINT PAYROLL OUTPUT FILES PRINT PROCESS ####');

 IF (vBatchName IS NULL) THEN
   l_pgm_loc   := '110';
   G_RETCODE := SQLCODE;
   G_ERRBUF := substr(SQLERRM,1,255);
   L_ERROR_RECORD := 'ERROR: Null Kornos batch name ' || 'in ' || G_PKG_NAME || '.' || l_proc_name || ' pgm_loc=' || l_pgm_loc;
   fnd_file.put_line(fnd_file.log,L_ERROR_RECORD);
   RAISE G_E_ABORT;
 END IF;

 l_pgm_loc   := '120';
 fnd_file.put_line(fnd_file.log,'RUN DATE=' || to_char(sysdate, 'MM/DD/YYYY HH24:MI:SS'));
 fnd_file.put_line(fnd_file.log,'KRONOS BATCH NAME=' || G_BATCH_NAME);

 l_pgm_loc   := '130';
 Begin
   SELECT BUSINESS_GROUP_ID
     INTO l_business_group_id
    --FROM CUST.TTEC_PAY_IFACE_KSS_DIRECT_TBL --code commented by RXNETHI-ARGANO,15/05/23
	FROM APPS.TTEC_PAY_IFACE_KSS_DIRECT_TBL --code added by RXNETHI-ARGANO,15/05/23
   WHERE upper(BATCH_NAME) = upper(vBatchName)
     AND record_Track = 'H'
     AND DeletionIndicator = 1;

 Exception
  When no_data_found Then
    G_RETCODE := SQLCODE;
    G_ERRBUF := substr(SQLERRM,1,255);
    fnd_file.put_line(fnd_file.log,'ERROR: NO Previously Processed Rows in CUST.TTEC_PAY_IFACE_KSS_DIRECT_TBL table');
    l_pgm_loc   := '140';
    RAISE G_E_ABORT;
 End;

 l_pgm_loc   := '150';
 Begin
     SELECT NAME
       INTO l_business_group_name
       FROM PER_BUSINESS_GROUPS
      WHERE BUSINESS_GROUP_ID = l_business_group_id
        AND NAME in ('TeleTech Holdings - MAL',
                     'TeleTech Holdings - SGP',
                     'TeleTech Holdings - HKG',
                     'TeleTech Holdings - NZ'
                    );

  Exception
  When no_data_found Then
    G_RETCODE := SQLCODE;
    G_ERRBUF := substr(SQLERRM,1,255);
    fnd_file.put_line(fnd_file.log,'ERROR: Business group id=' || l_business_group_id || ' is NOT GBP2 country');
    l_pgm_loc   := '160';
    RAISE G_E_ABORT;
 End;

 l_pgm_loc   := '170';
 fnd_file.put_line(fnd_file.log,'BUSINESS GROUP ID=' || l_business_group_id);
 fnd_file.put_line(fnd_file.log,'BUSINESS GROUP NAME=' || l_business_group_name);

 fnd_file.put_line(fnd_file.log,'   ');
 fnd_file.put_line(fnd_file.log,'#### START TO REFRESH PAYCODE TYPE VALUES for previously processed rows ####');

 IF (l_business_group_name = 'TeleTech Holdings - HKG') THEN
   l_paycode_lookup := G_HKG_PAYCODES_LOOKUP;
 END IF;

 IF (l_business_group_name = 'TeleTech Holdings - SGP') THEN
   l_paycode_lookup := G_SGP_PAYCODES_LOOKUP;
 END IF;

 IF (l_business_group_name = 'TeleTech Holdings - NZ') THEN
   l_paycode_lookup := G_NZ_PAYCODES_LOOKUP;
 END IF;

 IF (l_business_group_name = 'TeleTech Holdings - MAL') THEN
   l_paycode_lookup := G_MAL_PAYCODES_LOOKUP;
 END IF;

--koo
 FOR kss_direct_line_rec IN kss_direct_line_csr (vBatchName) LOOP
         Begin
           SELECT upper(substr(trim(DESCRIPTION),1,3))      -- for sgp, mal need the fist 3 chars, so it can have max 99 columns
             INTO l_paycode_type
             FROM FND_LOOKUP_VALUES
            WHERE LOOKUP_TYPE = l_paycode_lookup
              AND LOOKUP_CODE = upper(trim(kss_direct_line_rec.ELEMENT_NAME))
              AND LANGUAGE    = 'US'
              AND ENABLED_FLAG = 'Y'
              AND trunc(sysdate) between trunc(START_DATE_ACTIVE) AND TRUNC(NVL(END_DATE_ACTIVE,SYSDATE));

         Exception
           When others Then
            G_PAYCODE_FATAL := TRUE;
            l_paycode_type := NULL;
            fnd_file.put_line(fnd_file.log,'WARNING: paycode type can not be found for PAY_CODE='
                                                 || kss_direct_line_rec.ELEMENT_NAME || ', WILL NOT be processed');
         End;

         IF (kss_direct_line_rec.PAYCODE_TYPE != l_paycode_type) THEN
           l_upd_cnt := l_upd_cnt + 1;
           IF (l_paycode_type is NULL) THEN
             l_deletionindicator := '0';
           ELSE
             l_deletionindicator := '1';
           END IF;

           Begin
             --UPDATE CUST.TTEC_PAY_IFACE_KSS_DIRECT_TBL --code commented by RXNETHI-ARGANO,15/05/23
			 UPDATE APPS.TTEC_PAY_IFACE_KSS_DIRECT_TBL --code added by RXNETHI-ARGANO,15/05/23
                SET PAYCODE_TYPE        = l_paycode_type,
                    DELETIONINDICATOR   = l_deletionindicator
              WHERE UPPER(BATCH_NAME)   = UPPER(vBatchName)
                AND RECORD_TRACK        ='L'
                AND ELEMENT_NAME        = kss_direct_line_rec.ELEMENT_NAME
                AND ASSIGNMENT_NUMBER   = kss_direct_line_rec.ASSIGNMENT_NUMBER
                AND SEQUENCE_NUMBER     = kss_direct_line_rec.SEQUENCE_NUMBER
                AND  DELETIONINDICATOR  = '1';


           Exception
             When others Then
               G_RETCODE := SQLCODE;
               G_ERRBUF := substr(SQLERRM,1,255);
               l_pgm_loc   := '180';
               fnd_file.put_line(fnd_file.log,'ERROR: UPDATE filed');
               RAISE G_E_ABORT;
           End;
         END IF;

 END LOOP;

  l_pgm_loc   := '185';
 IF (l_upd_cnt > 0) THEN
   l_pgm_loc   := '190';
   COMMIT;
 END IF;

 fnd_file.put_line(fnd_file.log,'   ');
 fnd_file.put_line(fnd_file.log,'#### START CHECKING UNPROCESSED ROWS ####');

 l_pgm_loc   := '195';
 l_unproc_cnt := 0;
 FOR kss_direct_line_unproc_rec IN kss_direct_line_unproc_csr(vBatchName) LOOP
         -- get legacy employee number
         l_pgm_loc   := '200';
         Begin
           SELECT PAAF.PERSON_ID,
                  PAAF.ASSIGNMENT_ID,
                  PAPF.ATTRIBUTE12
             INTO
                  l_person_id,
                  l_assignment_id,
                  l_legacy_emp_number
             FROM
                  PER_ALL_ASSIGNMENTS_F PAAF,
                  PER_ALL_PEOPLE_F PAPF
            WHERE
                  PAAF.ASSIGNMENT_NUMBER = kss_direct_line_unproc_rec.ASSIGNMENT_NUMBER
              AND PAAF.BUSINESS_GROUP_ID = kss_direct_line_unproc_rec.business_group_id
              AND (trunc(kss_direct_line_unproc_rec.effective_date) BETWEEN trunc(PAAF.EFFECTIVE_START_DATE) AND trunc(PAAF.EFFECTIVE_END_DATE))
              AND PAAF.PERSON_ID = PAPF.PERSON_ID
              AND (trunc(kss_direct_line_unproc_rec.effective_date) BETWEEN trunc(PAPF.EFFECTIVE_START_DATE) AND trunc(PAPF.EFFECTIVE_END_DATE));

         Exception
           When others Then
            G_WARNING           := TRUE;
            l_person_id         := NULL;
            l_assignment_id     := NULL;
            l_legacy_emp_number := NULL;
            fnd_file.put_line(fnd_file.log,'WARNING: legacy employee number can not be found for ASSIGNMENT_NUMBER='
                                            || kss_direct_line_unproc_rec.ASSIGNMENT_NUMBER);
            fnd_file.put_line(fnd_file.log,'WARNING: NULL legacy employee number is passed and will not be processed');
         End;

         -- get pay code type
         Begin
           SELECT upper(substr(trim(DESCRIPTION),1,3))      -- for sgp, mal need the fist 3 chars, so it can have max 99 columns
             INTO l_paycode_type
             FROM FND_LOOKUP_VALUES
            WHERE LOOKUP_TYPE = l_paycode_lookup
              AND LOOKUP_CODE = upper(trim(kss_direct_line_unproc_rec.ELEMENT_NAME))
              AND LANGUAGE    = 'US'
              AND ENABLED_FLAG = 'Y'
              AND trunc(sysdate) between trunc(START_DATE_ACTIVE) AND TRUNC(NVL(END_DATE_ACTIVE,SYSDATE));

         Exception
           When others Then
            G_PAYCODE_FATAL := TRUE;
            l_paycode_type := NULL;
            fnd_file.put_line(fnd_file.log,'WARNING: paycode type can not be found for PAY_CODE='
                                                 || kss_direct_line_unproc_rec.ELEMENT_NAME || ', WILL NOT be processed');
         End;

         IF (l_legacy_emp_number is NOT NULL AND l_paycode_type is NOT NULL) THEN
           l_unproc_cnt := l_unproc_cnt + 1;
           Begin
             l_pgm_loc   := '210';
             --UPDATE CUST.TTEC_PAY_IFACE_KSS_DIRECT_TBL --code commented by RXNETHI-ARGANO,15/05/23
			 UPDATE APPS.TTEC_PAY_IFACE_KSS_DIRECT_TBL --code added by RXNETHI-ARGANO,15/05/23
                SET ASSIGNMENT_ID       = l_assignment_id,
                    PERSON_ID           = l_person_id,
                    LEGACY_EMP_NUMBER   = l_legacy_emp_number,
                    PAYCODE_TYPE        = l_paycode_type,
                    DELETIONINDICATOR   = '1'
              WHERE UPPER(BATCH_NAME)   = UPPER(vBatchName)
                AND RECORD_TRACK        ='L'
                AND ELEMENT_NAME        = kss_direct_line_unproc_rec.ELEMENT_NAME
                AND ASSIGNMENT_NUMBER   = kss_direct_line_unproc_rec.ASSIGNMENT_NUMBER
                AND SEQUENCE_NUMBER     = kss_direct_line_unproc_rec.SEQUENCE_NUMBER
                AND  DELETIONINDICATOR  = '0';

           Exception
             When others Then
               G_RETCODE := SQLCODE;
               G_ERRBUF := substr(SQLERRM,1,255);
               l_pgm_loc   := '215';
               fnd_file.put_line(fnd_file.log,'ERROR: UPDATE filed');
               RAISE G_E_ABORT;
           End;

         END IF;  -- IF (l_legacy_emp_number is NOT NULL AND l_paycode_type is NOT NULL)

 END LOOP;

 -- close cursor kss_direct_line_unproc_csr ??

 l_pgm_loc   := '300';
 IF (l_unproc_cnt > 0) THEN
   l_pgm_loc   := '310';
   COMMIT;
 END IF;

 l_pgm_loc   := '320';
 fnd_file.put_line(fnd_file.log,'Total ' || l_unproc_cnt || ' Previously unprocessed rows processed and updated');
 fnd_file.put_line(fnd_file.log,'   ');
 fnd_file.put_line(fnd_file.log,'OUTPUT FILE DIRECTORY=' || G_UTIL_FILE_OUT_DIR);

--kenprint
 -- Process Hong Kong..., output file names have _pr file extension...
 IF (l_business_group_name = 'TeleTech Holdings - HKG') THEN
   -- fromat output file names
   l_pgm_loc   := '400';
   l_out_pay_file_name := replace(trim(vBatchName), ' ', '_');
   l_out_pay_file_name := replace(l_out_pay_file_name, '/', '-');
   l_out_pay_file_name := replace(l_out_pay_file_name, ':', '_');
   l_out_lea_file_name := l_out_pay_file_name;
   l_out_pay_file_name := l_out_pay_file_name || '.pay_pr';
   l_out_lea_file_name := l_out_lea_file_name || '.lea_pr';

   -- open pay output file
   l_pgm_loc   := '410';
   G_OUT_PAY_FILE := Utl_File.fopen(G_UTIL_FILE_OUT_DIR, l_out_pay_file_name, 'W');
   fnd_file.put_line(fnd_file.log,'PAY OUTPUT FILE NAME=' || l_out_pay_file_name);

   -- open leave output file
   l_pgm_loc   := '420';
   G_OUT_LEA_FILE := Utl_File.fopen(G_UTIL_FILE_OUT_DIR, l_out_lea_file_name, 'W');
   fnd_file.put_line(fnd_file.log,'LEAVE OUTPUT FILE NAME=' || l_out_lea_file_name);

   -- process and print output file records
   -- hkgpay_pr
   l_rows_lines_processed := 0;
   l_pgm_loc   := '430';
   FOR kss_direct_line_rec IN  kss_direct_line_csr (vBatchName) LOOP
       -- produce leave output file based on pay codes..
       l_rows_lines_processed := l_rows_lines_processed + 1;
       l_pgm_loc   := '435';
       IF (   substr(kss_direct_line_rec.PAYCODE_TYPE,1,1) = 'L'
           OR substr(kss_direct_line_rec.PAYCODE_TYPE,1,1) = 'B' ) THEN
         l_pgm_loc   := '436';

         -- data format of VALUE_3 from kronos is YYYY/MM/DD
         l_line_buffer := trim(kss_direct_line_rec.LEGACY_EMP_NUMBER)                                      || '|' ||
                          trim(kss_direct_line_rec.ELEMENT_NAME)                                           || '|' ||
                          to_char(to_date(trim(kss_direct_line_rec.VALUE_3), 'YYYY/MM/DD'), 'DD/MM/YYYY')  || '|' ||  -- start date
                          to_char(to_date(trim(kss_direct_line_rec.VALUE_3), 'YYYY/MM/DD'), 'DD/MM/YYYY')  || '|' ||  -- end date
                          to_char(kss_direct_line_rec.EFFECTIVE_DATE, 'DD/MM/YYYY')                        || '|' ||  -- posting date
                          trim(kss_direct_line_rec.VALUE_1);

         l_pgm_loc   := '440';
         Utl_File.put_line(G_OUT_LEA_FILE, l_line_buffer);
       END IF;  -- IF (substr(kss_direct_line_rec.PAYCODE_TYPE,1,1) = 'L' or 'B')

         -- produce pay output file, leave pay code does NOT go here..
       IF (   substr(kss_direct_line_rec.PAYCODE_TYPE,1,1) = 'P'
           OR substr(kss_direct_line_rec.PAYCODE_TYPE,1,1) = 'B' ) THEN
         l_pgm_loc   := '445';
         l_line_buffer := trim(kss_direct_line_rec.LEGACY_EMP_NUMBER) || '|' ||
                          trim(kss_direct_line_rec.ELEMENT_NAME)      || '|' ||
                          trim(kss_direct_line_rec.VALUE_1);

         l_pgm_loc   := '450';
         Utl_File.put_line(G_OUT_PAY_FILE, l_line_buffer);
       END IF;   -- IF (substr(kss_direct_line_rec.PAYCODE_TYPE,1,1) = 'P' or 'B')

   END LOOP; -- kss_direct_line_rec IN  kss_direct_line_csr (vBatchName)

   fnd_file.put_line(fnd_file.log, 'Total ' || l_rows_lines_processed || ' Rows Processed in CUST.TTEC_PAY_IFACE_KSS_DIRECT_TBL table');

   -- Cloase output files
   l_pgm_loc   := '460';
   Utl_File.fclose(G_OUT_PAY_FILE);
   l_pgm_loc   := '470';
   Utl_File.fclose(G_OUT_LEA_FILE);

   l_pgm_loc   := '480';
   fnd_file.put_line(fnd_file.log, '#### REPORTING UNPROCESSED CUST.TTEC_PAY_IFACE_KSS_DIRECT_TBL LINE RECORDS.... ####');
   fnd_file.put_line(fnd_file.log, '--------------------------------------------------------------------------------------------------');

   -- report unporcessed rows, if any...
   l_pgm_loc   := '490';
   l_unproc_cnt :=0;
   FOR kss_direct_line_unproc_rec IN kss_direct_line_unproc_csr(vBatchName) LOOP
       l_unproc_cnt := l_unproc_cnt + 1;
       l_line_buffer := 'ASG_NUM='             || trim(kss_direct_line_unproc_rec.ASSIGNMENT_NUMBER) ||
                        ', LEGACY_EMP_NUM='    || trim(kss_direct_line_unproc_rec.LEGACY_EMP_NUMBER) ||
                        ', ELEMENT_NAME='      || trim(kss_direct_line_unproc_rec.ELEMENT_NAME)      ||
                        ', VALUE1='            || trim(kss_direct_line_unproc_rec.VALUE_1)           ||
                        ', VALUE3='            || trim(kss_direct_line_unproc_rec.VALUE_3)           ||
                        ', PAYCODE_TYPE='      || substr(trim(kss_direct_line_unproc_rec.PAYCODE_TYPE),1,1);
       fnd_file.put_line(fnd_file.log, l_line_buffer);
   END LOOP;

   fnd_file.put_line(fnd_file.log, '#### Total ' || l_unproc_cnt || ' UNPROCESSED LINE RECORDS....####');
   fnd_file.put_line(fnd_file.log, '--------------------------------------------------------------------------------------------------');
   fnd_file.put_line(fnd_file.log, '#### PAYROLL INTERFACE PRINT HAS BEEN PROCESSED SUCCESSFULLY.... ####');

 END IF; -- IF (l_business_group_name = 'TeleTech Holdings - HKG')

 -- Process New Zealand..., output file names have _pr file extension...
 IF (l_business_group_name = 'TeleTech Holdings - NZ') THEN
   -- fromat output file names
   l_pgm_loc   := '500';
   l_out_pay_file_name := 'NZ' || to_char(sysdate, 'MMDDYY') || '.pay_pr';
   l_out_lea_file_name := 'NZ' || to_char(sysdate, 'MMDDYY') || '.lev_pr';

   -- open pay output file
   l_pgm_loc   := '510';
   G_OUT_PAY_FILE := Utl_File.fopen(G_UTIL_FILE_OUT_DIR, l_out_pay_file_name, 'W');
   fnd_file.put_line(fnd_file.log,'PAY OUTPUT FILE NAME=' || l_out_pay_file_name);

   -- open leave output file
   l_pgm_loc   := '520';
   G_OUT_LEA_FILE := Utl_File.fopen(G_UTIL_FILE_OUT_DIR, l_out_lea_file_name, 'W');
   fnd_file.put_line(fnd_file.log,'LEAVE OUTPUT FILE NAME=' || l_out_lea_file_name);

   -- process and print output file records
   -- nzpay_pr
   l_rows_lines_processed := 0;
   l_pgm_loc   := '530';
   FOR kss_direct_line_rec IN  kss_direct_line_csr (vBatchName) LOOP
       -- produce leave output file based on pay codes..
       l_rows_lines_processed := l_rows_lines_processed + 1;
       l_pgm_loc   := '535';
       IF (   substr(kss_direct_line_rec.PAYCODE_TYPE,1,1) = 'L'
           OR substr(kss_direct_line_rec.PAYCODE_TYPE,1,1) = 'B' ) THEN
         l_pgm_loc   := '536';
         -- data format of VALUE_3 from kronos is YYYY/MM/DD
         l_line_buffer := trim(kss_direct_line_rec.LEGACY_EMP_NUMBER)                                      || ',' ||
                          trim(kss_direct_line_rec.ELEMENT_NAME)                                           || ',' ||
                          to_char(to_date(trim(kss_direct_line_rec.VALUE_3), 'YYYY/MM/DD'), 'DDMMYY')      || ',' ||  -- start date
                          to_char(to_date(trim(kss_direct_line_rec.VALUE_3), 'YYYY/MM/DD'), 'DDMMYY')      || ',' ||  -- end date
              --          to_char(kss_direct_line_rec.EFFECTIVE_DATE, 'DD/MM/YYYY')                        || ',' ||  -- posting date
                          format_h_dot_hh_hmm(trim(kss_direct_line_rec.VALUE_1));

         l_pgm_loc   := '540';
         Utl_File.put_line(G_OUT_LEA_FILE, l_line_buffer);
       END IF; -- IF (substr(kss_direct_line_rec.PAYCODE_TYPE,1,1) = 'L' or 'B')

         -- produce pay output file, leave pay codes goes in here also.
       IF (   substr(kss_direct_line_rec.PAYCODE_TYPE,1,1) = 'P'
           OR substr(kss_direct_line_rec.PAYCODE_TYPE,1,1) = 'B' ) THEN
         l_pgm_loc   := '545';
         l_line_buffer := trim(kss_direct_line_rec.LEGACY_EMP_NUMBER)                || ',' ||
                          trim(kss_direct_line_rec.decoded_interface_type)           || ',,,' ||  -- payslip type
                          trim(kss_direct_line_rec.ELEMENT_NAME)                     || ',,' ||
                          replace(trim(kss_direct_line_rec.VALUE_1), '.', '')        || ',,,,' ||
                          to_char(kss_direct_line_rec.EFFECTIVE_DATE, 'DD-MM-YYYY');

         l_pgm_loc   := '550';
         Utl_File.put_line(G_OUT_PAY_FILE, l_line_buffer);
        END IF;     -- IF (substr(kss_direct_line_rec.PAYCODE_TYPE,1,1) = 'P' or 'B')

   END LOOP; -- kss_direct_line_rec IN  kss_direct_line_csr (vBatchName)

   fnd_file.put_line(fnd_file.log, 'Total ' || l_rows_lines_processed || ' Rows Processed in CUST.TTEC_PAY_IFACE_KSS_DIRECT_TBL table');

   -- Cloase output files
   l_pgm_loc   := '560';
   Utl_File.fclose(G_OUT_PAY_FILE);
   l_pgm_loc   := '570';
   Utl_File.fclose(G_OUT_LEA_FILE);

   l_pgm_loc   := '580';
   fnd_file.put_line(fnd_file.log, '#### REPORTING UNPROCESSED CUST.TTEC_PAY_IFACE_KSS_DIRECT_TBL LINE RECORDS.... ####');
   fnd_file.put_line(fnd_file.log, '--------------------------------------------------------------------------------------------------');

   -- report unporcessed rows, if any...
   l_pgm_loc   := '590';
   l_unproc_cnt :=0;
   FOR kss_direct_line_unproc_rec IN kss_direct_line_unproc_csr(vBatchName) LOOP
       l_unproc_cnt := l_unproc_cnt + 1;
       l_line_buffer := 'ASG_NUM='             || trim(kss_direct_line_unproc_rec.ASSIGNMENT_NUMBER) ||
                        ', LEGACY_EMP_NUM='    || trim(kss_direct_line_unproc_rec.LEGACY_EMP_NUMBER) ||
                        ', ELEMENT_NAME='      || trim(kss_direct_line_unproc_rec.ELEMENT_NAME)      ||
                        ', VALUE1='            || trim(kss_direct_line_unproc_rec.VALUE_1)           ||
                        ', VALUE3='            || trim(kss_direct_line_unproc_rec.VALUE_3)           ||
                        ', PAYCODE_TYPE='      || substr(trim(kss_direct_line_unproc_rec.PAYCODE_TYPE),1,1);
       fnd_file.put_line(fnd_file.log, l_line_buffer);
   END LOOP;

   fnd_file.put_line(fnd_file.log, '#### Total ' || l_unproc_cnt || ' UNPROCESSED LINE RECORDS....####');
   fnd_file.put_line(fnd_file.log, '--------------------------------------------------------------------------------------------------');
   fnd_file.put_line(fnd_file.log, '#### PAYROLL INTERFACE PRINT HAS BEEN PROCESSED SUCCESSFULLY.... ####');

 END IF; -- IF (l_business_group_name = 'TeleTech Holdings - NZ')

 -- Process Singapore..., output file names have _pr file extension...
 IF (l_business_group_name = 'TeleTech Holdings - SGP') THEN
   -- fromat output file names
   l_pgm_loc   := '600';
   l_out_pay_file_name := replace(trim(vBatchName), ' ', '_');
   l_out_pay_file_name := replace(l_out_pay_file_name, '/', '-');
   l_out_pay_file_name := replace(l_out_pay_file_name, ':', '_');
   l_out_lea_file_name := l_out_pay_file_name;
   l_out_pay_file_name := l_out_pay_file_name || '.pay_pr';
   l_out_lea_file_name := l_out_lea_file_name || '.lea_pr';

   -- open pay output file
   l_pgm_loc   := '610';
   G_OUT_PAY_FILE := Utl_File.fopen(G_UTIL_FILE_OUT_DIR, l_out_pay_file_name, 'W');
   fnd_file.put_line(fnd_file.log,'PAY OUTPUT FILE NAME=' || l_out_pay_file_name);

   -- open leave output file
   l_pgm_loc   := '620';
   G_OUT_LEA_FILE := Utl_File.fopen(G_UTIL_FILE_OUT_DIR, l_out_lea_file_name, 'W');
   fnd_file.put_line(fnd_file.log,'LEAVE OUTPUT FILE NAME=' || l_out_lea_file_name);

   -- get max number of payroll output fields from fnd_lookup_values table.
   Begin
     SELECT max(to_number(substr(trim(DESCRIPTION),2,2)))
       INTO l_max_col
       FROM FND_LOOKUP_VALUES
      WHERE LOOKUP_TYPE = G_SGP_PAYCODES_LOOKUP
        AND (upper(trim(DESCRIPTION)) like 'P%' OR upper(trim(DESCRIPTION)) like 'B%')
        AND LANGUAGE    = 'US'
        AND ENABLED_FLAG = 'Y'
        AND trunc(sysdate) between trunc(START_DATE_ACTIVE) AND TRUNC(NVL(END_DATE_ACTIVE,SYSDATE));

     Exception
       When others Then
         l_pgm_loc   := '625';
         G_RETCODE := SQLCODE;
         G_ERRBUF := substr(SQLERRM,1,255);
         L_ERROR_RECORD := 'ERROR: Problem to retrive maxinum payroll output fields ';
         fnd_file.put_line(fnd_file.log,L_ERROR_RECORD);
         RAISE G_E_ABORT;
   End;

   -- produce header in leave output file, it will make eaiser to import it to msft excel
   l_line_buffer := 'Legacy Emp Num,Emp Name,Leave Type,Start Date(DD/MM/YYYY),End Date(DD/MM/YYYY),Period End Date(DD/MM/YYYY),Duration(H.HH)';
   Utl_File.put_line(G_OUT_LEA_FILE, l_line_buffer);

  -- process and print output file records
  -- sgppay_pr
  l_rows_lines_processed := 0;
  -- initialize totals
  FOR i IN 1 .. l_max_col LOOP
    tot_table(i).total_num := 0.00;
  END LOOP;

  l_last_legacy_emp_number := 'FIRST_TIME_xX';
  FOR kss_direct_line_rec IN  kss_direct_line_csr (vBatchName) LOOP
       l_rows_lines_processed := l_rows_lines_processed + 1;
       l_pgm_loc   := '630';
       IF (kss_direct_line_rec.LEGACY_EMP_NUMBER != l_last_legacy_emp_number AND l_last_legacy_emp_number != 'FIRST_TIME_xX') THEN
         -- produce pay output file as summary
         l_col_total := 0.00;
         FOR i IN 1 .. l_max_col LOOP
           l_col_total := l_col_total + abs(tot_table(i).total_num);
         END LOOP;
         IF ( l_col_total > 0 ) THEN
           l_line_buffer := pad_data_output('VARCHAR2',12,trim(l_last_legacy_emp_number));
           FOR i IN 1 .. l_max_col LOOP
             l_line_buffer := l_line_buffer || pad_data_output('NUMBER',6,to_char(tot_table(i).total_num * 100, 'FM999099'));
           END LOOP;
           Utl_File.put_line(G_OUT_PAY_FILE, l_line_buffer);
         END IF;

          l_last_legacy_emp_number := kss_direct_line_rec.LEGACY_EMP_NUMBER;
          FOR i IN 1 .. l_max_col LOOP
            tot_table(i).total_num := 0.00;
          END LOOP;
       ELSE
          l_last_legacy_emp_number := kss_direct_line_rec.LEGACY_EMP_NUMBER;
       END IF; -- IF (kss_direct_line_rec.LEGACY_EMP_NUMBER != l_last_legacy_emp_number AND l_last_legacy_emp_number != 'FIRST_TIME_xX')

       l_pgm_loc   := '640';
       IF (   substr(kss_direct_line_rec.PAYCODE_TYPE,1,1) = 'P'
           OR substr(kss_direct_line_rec.PAYCODE_TYPE,1,1) = 'B') THEN
         IF (to_number(trim(kss_direct_line_rec.VALUE_1)) < 0) THEN
           fnd_file.put_line(fnd_file.log,'WARNING: NEGATIVE value of value_1=' || kss_direct_line_rec.VALUE_1
                                                 || ', Legacy emp=' || kss_direct_line_rec.LEGACY_EMP_NUMBER
                                                 || ', Pay code=' || kss_direct_line_rec.ELEMENT_NAME);
         END IF;
         i := to_number(substr(kss_direct_line_rec.PAYCODE_TYPE,2,2));
         -- IF (upper(substr(trim(kss_direct_line_rec.ELEMENT_NAME),1,5)) = 'SHIFT') THEN
         IF (instr(upper(kss_direct_line_rec.ELEMENT_NAME),'SHIFT',1,1) > 0) THEN
           tot_table(i).total_num := tot_table(i).total_num + 1.00;
         ELSE
           tot_table(i).total_num := tot_table(i).total_num + to_number(trim(kss_direct_line_rec.VALUE_1));
         END IF;
       END IF;

       -- produce leave output file based on pay codes..
       l_pgm_loc   := '645';
       IF (substr(kss_direct_line_rec.PAYCODE_TYPE,1,1) != 'P') THEN
         l_pgm_loc   := '650';

         -- data format of VALUE_3 from kronos is YYYY/MM/DD
         l_line_buffer := trim(kss_direct_line_rec.LEGACY_EMP_NUMBER)                                      || ',' ||
                          replace(trim(kss_direct_line_rec.EMPLOYEENAME),',','')                           || ',' ||
                          trim(kss_direct_line_rec.ELEMENT_NAME)                                           || ',' ||
                          to_char(to_date(trim(kss_direct_line_rec.VALUE_3), 'YYYY/MM/DD'), 'DD/MM/YYYY')  || ',' ||  -- start date
                          to_char(to_date(trim(kss_direct_line_rec.VALUE_3), 'YYYY/MM/DD'), 'DD/MM/YYYY')  || ',' ||  -- end date
                          to_char(kss_direct_line_rec.EFFECTIVE_DATE, 'DD/MM/YYYY')                        || ',' ||  -- posting date
                          trim(kss_direct_line_rec.VALUE_1);
         Utl_File.put_line(G_OUT_LEA_FILE, l_line_buffer);
       END IF;   -- IF (substr(trim(kss_direct_line_rec.PAYCODE_TYPE),1,1)) != 'P')...

  END LOOP; -- kss_direct_line_rec IN  kss_direct_line_csr (vBatchName)

   -- print the last employees pay output summary line.
   IF (l_last_legacy_emp_number != 'FIRST_TIME_xX') THEN
     l_col_total := 0.00;
     FOR i IN 1 .. l_max_col LOOP
       l_col_total := l_col_total + abs(tot_table(i).total_num);
     END LOOP;
     IF ( l_col_total > 0 ) THEN
       l_line_buffer := pad_data_output('VARCHAR2',12,trim(l_last_legacy_emp_number));
       FOR i IN 1 .. l_max_col LOOP
         l_line_buffer := l_line_buffer || pad_data_output('NUMBER',6,to_char(tot_table(i).total_num * 100, 'FM999099'));
       END LOOP;
       Utl_File.put_line(G_OUT_PAY_FILE, l_line_buffer);
      END IF;
    END IF;

   fnd_file.put_line(fnd_file.log, 'Total ' || l_rows_lines_processed || ' Rows Processed in CUST.TTEC_PAY_IFACE_KSS_DIRECT_TBL table');

   -- Cloase output files
   l_pgm_loc   := '655';
   Utl_File.fclose(G_OUT_PAY_FILE);
   l_pgm_loc   := '660';
   Utl_File.fclose(G_OUT_LEA_FILE);

   l_pgm_loc   := '670';
   fnd_file.put_line(fnd_file.log, '#### REPORTING UNPROCESSED CUST.TTEC_PAY_IFACE_KSS_DIRECT_TBL LINE RECORDS.... ####');
   fnd_file.put_line(fnd_file.log, '--------------------------------------------------------------------------------------------------');

   -- report unporcessed rows, if any...
   l_pgm_loc   := '680';
   fnd_file.put_line(fnd_file.log, '#### REPORTING UNPROCESSED CUST.TTEC_PAY_IFACE_KSS_DIRECT_TBL LINE RECORDS.... ####');
   fnd_file.put_line(fnd_file.log, '--------------------------------------------------------------------------------------------------');

   -- report unporcessed rows, if any...
   l_pgm_loc   := '690';
   l_unproc_cnt :=0;
   FOR kss_direct_line_unproc_rec IN kss_direct_line_unproc_csr(vBatchName) LOOP
       l_unproc_cnt := l_unproc_cnt + 1;
       l_line_buffer := 'ASG_NUM='             || trim(kss_direct_line_unproc_rec.ASSIGNMENT_NUMBER) ||
                        ', LEGACY_EMP_NUM='    || trim(kss_direct_line_unproc_rec.LEGACY_EMP_NUMBER) ||
                        ', ELEMENT_NAME='      || trim(kss_direct_line_unproc_rec.ELEMENT_NAME)      ||
                        ', VALUE1='            || trim(kss_direct_line_unproc_rec.VALUE_1)           ||
                        ', VALUE3='            || trim(kss_direct_line_unproc_rec.VALUE_3)           ||
                        ', PAYCODE_TYPE='      || trim(kss_direct_line_unproc_rec.PAYCODE_TYPE);
       fnd_file.put_line(fnd_file.log, l_line_buffer);
   END LOOP;

   fnd_file.put_line(fnd_file.log, '#### Total ' || l_unproc_cnt || ' UNPROCESSED LINE RECORDS....####');
   fnd_file.put_line(fnd_file.log, '--------------------------------------------------------------------------------------------------');
   fnd_file.put_line(fnd_file.log, '#### PAYROLL INTERFACE PRINT HAS BEEN PROCESSED SUCCESSFULLY.... ####');

 END IF; -- IF (l_business_group_name = 'TeleTech Holdings - SGP')

 -- Process Malaysia..., output file names have _pr file extension...
 IF (l_business_group_name = 'TeleTech Holdings - MAL') THEN
   -- fromat output file names
   l_pgm_loc   := '700';
   l_out_pay_file_name := replace(trim(vBatchName), ' ', '_');
   l_out_pay_file_name := replace(l_out_pay_file_name, '/', '-');
   l_out_pay_file_name := replace(l_out_pay_file_name, ':', '_');
   l_out_lea_file_name := l_out_pay_file_name;
   l_out_pay_file_name := l_out_pay_file_name || '.pay_pr';
   l_out_lea_file_name := l_out_lea_file_name || '.lea_pr';

   -- open pay output file
   l_pgm_loc   := '710';
   G_OUT_PAY_FILE := Utl_File.fopen(G_UTIL_FILE_OUT_DIR, l_out_pay_file_name, 'W');
   fnd_file.put_line(fnd_file.log,'PAY OUTPUT FILE NAME=' || l_out_pay_file_name);

   -- open leave output file
   l_pgm_loc   := '720';
   G_OUT_LEA_FILE := Utl_File.fopen(G_UTIL_FILE_OUT_DIR, l_out_lea_file_name, 'W');
   fnd_file.put_line(fnd_file.log,'LEAVE OUTPUT FILE NAME=' || l_out_lea_file_name);

   -- get max number of payroll output fields from fnd_lookup_values table.
   Begin
     SELECT max(to_number(substr(trim(DESCRIPTION),2,2)))
       INTO l_max_col
       FROM FND_LOOKUP_VALUES
      WHERE LOOKUP_TYPE = G_MAL_PAYCODES_LOOKUP
        AND (upper(trim(DESCRIPTION)) like 'P%' OR upper(trim(DESCRIPTION)) like 'B%')
        AND LANGUAGE    = 'US'
        AND ENABLED_FLAG = 'Y'
        AND trunc(sysdate) between trunc(START_DATE_ACTIVE) AND TRUNC(NVL(END_DATE_ACTIVE,SYSDATE));

     Exception
       When others Then
         l_pgm_loc   := '730';
         G_RETCODE := SQLCODE;
         G_ERRBUF := substr(SQLERRM,1,255);
         L_ERROR_RECORD := 'ERROR: Problem to retrive maxinum payroll output fields ';
         fnd_file.put_line(fnd_file.log,L_ERROR_RECORD);
         RAISE G_E_ABORT;
   End;

   -- produce header in leave output file, it will make eaiser to import it to msft excel
   l_line_buffer := 'Legacy Emp Num,Emp Name,Leave Type,Start Date(DD/MM/YYYY),End Date(DD/MM/YYYY),Period End Date(DD/MM/YYYY),Duration(H.HH)';
   Utl_File.put_line(G_OUT_LEA_FILE, l_line_buffer);

  -- process and print output file records
  -- malpay_pr
  l_rows_lines_processed := 0;
  -- initialize totals
  FOR i IN 1 .. l_max_col LOOP
    tot_table(i).total_num := 0.00;
  END LOOP;

  l_last_legacy_emp_number := 'FIRST_TIME_xX';
  FOR kss_direct_line_rec IN  kss_direct_line_csr (vBatchName) LOOP
       l_rows_lines_processed := l_rows_lines_processed + 1;
       l_pgm_loc   := '740';
       IF (kss_direct_line_rec.LEGACY_EMP_NUMBER != l_last_legacy_emp_number AND l_last_legacy_emp_number != 'FIRST_TIME_xX') THEN
         -- produce pay output file as summary
         l_col_total := 0.00;
         FOR i IN 1 .. l_max_col LOOP
           l_col_total := l_col_total + abs(tot_table(i).total_num);
         END LOOP;
         IF ( l_col_total > 0 ) THEN
           l_line_buffer := pad_data_output('VARCHAR2',12,trim(l_last_legacy_emp_number));
           FOR i IN 1 .. l_max_col LOOP
             l_line_buffer := l_line_buffer || pad_data_output('NUMBER',6,to_char(tot_table(i).total_num * 100, 'FM999099'));
           END LOOP;
           Utl_File.put_line(G_OUT_PAY_FILE, l_line_buffer);
         END IF;

          l_last_legacy_emp_number := kss_direct_line_rec.LEGACY_EMP_NUMBER;
          FOR i IN 1 .. l_max_col LOOP
            tot_table(i).total_num := 0.00;
          END LOOP;
       ELSE
          l_last_legacy_emp_number := kss_direct_line_rec.LEGACY_EMP_NUMBER;
       END IF; -- IF (kss_direct_line_rec.LEGACY_EMP_NUMBER != l_last_legacy_emp_number AND l_last_legacy_emp_number != 'FIRST_TIME_xX')

       l_pgm_loc   := '745';
       IF (   substr(kss_direct_line_rec.PAYCODE_TYPE,1,1) = 'P'
           OR substr(kss_direct_line_rec.PAYCODE_TYPE,1,1) = 'B') THEN
         IF (to_number(trim(kss_direct_line_rec.VALUE_1)) < 0) THEN
           fnd_file.put_line(fnd_file.log,'WARNING: NEGATIVE value of value_1=' || kss_direct_line_rec.VALUE_1
                                                 || ', Legacy emp=' || kss_direct_line_rec.LEGACY_EMP_NUMBER
                                                 || ', Pay code=' || kss_direct_line_rec.ELEMENT_NAME);
         END IF;
         i := to_number(substr(kss_direct_line_rec.PAYCODE_TYPE,2,2));
         -- IF (upper(substr(trim(kss_direct_line_rec.ELEMENT_NAME),1,5)) = 'SHIFT') THEN
         IF (instr(upper(kss_direct_line_rec.ELEMENT_NAME),'SHIFT',1,1) > 0) THEN
           tot_table(i).total_num := tot_table(i).total_num + 1.00;
         ELSE
           tot_table(i).total_num := tot_table(i).total_num + to_number(trim(kss_direct_line_rec.VALUE_1));
         END IF;
       END IF;

       -- produce leave output file based on pay codes..
       l_pgm_loc   := '746';
       IF (substr(kss_direct_line_rec.PAYCODE_TYPE,1,1) != 'P') THEN
         l_pgm_loc   := '747';

         -- data format of VALUE_3 from kronos is YYYY/MM/DD
         l_line_buffer := trim(kss_direct_line_rec.LEGACY_EMP_NUMBER)                                      || ',' ||
                          replace(trim(kss_direct_line_rec.EMPLOYEENAME),',','')                           || ',' ||
                          trim(kss_direct_line_rec.ELEMENT_NAME)                                           || ',' ||
                          to_char(to_date(trim(kss_direct_line_rec.VALUE_3), 'YYYY/MM/DD'), 'DD/MM/YYYY')  || ',' ||  -- start date
                          to_char(to_date(trim(kss_direct_line_rec.VALUE_3), 'YYYY/MM/DD'), 'DD/MM/YYYY')  || ',' ||  -- end date
                          to_char(kss_direct_line_rec.EFFECTIVE_DATE, 'DD/MM/YYYY')                        || ',' ||  -- posting date
                          trim(kss_direct_line_rec.VALUE_1);
         Utl_File.put_line(G_OUT_LEA_FILE, l_line_buffer);
       END IF;   -- IF (substr(trim(kss_direct_line_rec.PAYCODE_TYPE),1,1)) != 'P')...

  END LOOP; -- kss_direct_line_rec IN  kss_direct_line_csr (vBatchName)

   -- print the last employees pay output summary line.
   IF (l_last_legacy_emp_number != 'FIRST_TIME_xX') THEN
     l_col_total := 0.00;
     FOR i IN 1 .. l_max_col LOOP
       l_col_total := l_col_total + abs(tot_table(i).total_num);
     END LOOP;
     IF ( l_col_total > 0 ) THEN
       l_line_buffer := pad_data_output('VARCHAR2',12,trim(l_last_legacy_emp_number));
       FOR i IN 1 .. l_max_col LOOP
         l_line_buffer := l_line_buffer || pad_data_output('NUMBER',6,to_char(tot_table(i).total_num * 100, 'FM999099'));
       END LOOP;
       Utl_File.put_line(G_OUT_PAY_FILE, l_line_buffer);
      END IF;
    END IF;

   fnd_file.put_line(fnd_file.log, 'Total ' || l_rows_lines_processed || ' Rows Processed in CUST.TTEC_PAY_IFACE_KSS_DIRECT_TBL table');

   -- Cloase output files
   l_pgm_loc   := '760';
   Utl_File.fclose(G_OUT_PAY_FILE);
   l_pgm_loc   := '770';
   Utl_File.fclose(G_OUT_LEA_FILE);

   l_pgm_loc   := '780';
   fnd_file.put_line(fnd_file.log, '#### REPORTING UNPROCESSED CUST.TTEC_PAY_IFACE_KSS_DIRECT_TBL LINE RECORDS.... ####');
   fnd_file.put_line(fnd_file.log, '--------------------------------------------------------------------------------------------------');

   -- report unporcessed rows, if any...
   l_pgm_loc   := '785';
   fnd_file.put_line(fnd_file.log, '#### REPORTING UNPROCESSED CUST.TTEC_PAY_IFACE_KSS_DIRECT_TBL LINE RECORDS.... ####');
   fnd_file.put_line(fnd_file.log, '--------------------------------------------------------------------------------------------------');

   -- report unporcessed rows, if any...
   l_pgm_loc   := '790';
   l_unproc_cnt :=0;
   FOR kss_direct_line_unproc_rec IN kss_direct_line_unproc_csr(vBatchName) LOOP
       l_unproc_cnt := l_unproc_cnt + 1;
       l_line_buffer := 'ASG_NUM='             || trim(kss_direct_line_unproc_rec.ASSIGNMENT_NUMBER) ||
                        ', LEGACY_EMP_NUM='    || trim(kss_direct_line_unproc_rec.LEGACY_EMP_NUMBER) ||
                        ', ELEMENT_NAME='      || trim(kss_direct_line_unproc_rec.ELEMENT_NAME)      ||
                        ', VALUE1='            || trim(kss_direct_line_unproc_rec.VALUE_1)           ||
                        ', VALUE3='            || trim(kss_direct_line_unproc_rec.VALUE_3)           ||
                        ', PAYCODE_TYPE='      || trim(kss_direct_line_unproc_rec.PAYCODE_TYPE);
       fnd_file.put_line(fnd_file.log, l_line_buffer);
   END LOOP;

   fnd_file.put_line(fnd_file.log, '#### Total ' || l_unproc_cnt || ' UNPROCESSED LINE RECORDS....####');
   fnd_file.put_line(fnd_file.log, '--------------------------------------------------------------------------------------------------');
   fnd_file.put_line(fnd_file.log, '#### PAYROLL INTERFACE PRINT HAS BEEN PROCESSED SUCCESSFULLY.... ####');

 END IF; -- IF (l_business_group_name = 'TeleTech Holdings - MAL')

-- check here for G_PAYCODE_FATAL G_WARNING
 IF (G_PAYCODE_FATAL) THEN
   RAISE G_PAYCODE_ABORT;
 END IF;

 ov_retcode := G_RETCODE;
 ov_errbuf  := G_ERRBUF;

EXCEPTION
 WHEN G_E_ABORT THEN
   L_ERROR_MESSAGE := 'Error --> '||SQLERRM;
   L_ERROR_RECORD := 'Error in ' || G_PKG_NAME || '.' || l_proc_name || ' pgm_loc=' || l_pgm_loc;
   fnd_File.put_line(fnd_file.log, L_ERROR_RECORD);
   fnd_File.put_line(fnd_file.log, L_ERROR_MESSAGE);
   fnd_File.put_line(fnd_file.log,'Process Aborted - Contact Teletech Help Desk');
   UTL_FILE.FCLOSE_ALL;

   ov_retcode := G_RETCODE;
   ov_errbuf  := G_ERRBUF;

 WHEN G_PAYCODE_ABORT THEN
   L_ERROR_MESSAGE := 'Error --> PAYROLL INTERFACE FAILED DUE TO PAYCODE TYPES PROBLEM - DISCARD OUTPUT FILES, USE TTEC GBP2 PAYROLL DATA PRINT '
                      || 'concurrent program for reproduce output file ';
   L_ERROR_RECORD := 'Error in ' || G_PKG_NAME || '.' || l_proc_name || ' pgm_loc=' || l_pgm_loc;
   fnd_File.put_line(fnd_file.log, L_ERROR_RECORD);
   fnd_File.put_line(fnd_file.log, L_ERROR_MESSAGE);
   fnd_File.put_line(fnd_file.log,'Process Aborted - Contact Teletech Help Desk');
   UTL_FILE.FCLOSE_ALL;

 WHEN OTHERS THEN
   ov_retcode := SQLCODE;
   ov_errbuf  := substr(SQLERRM,1,255);

   L_ERROR_MESSAGE := 'Error --> '||SQLERRM;
   L_ERROR_RECORD := 'Error in ' || G_PKG_NAME || '.' || l_proc_name || ' pgm_loc=' || l_pgm_loc;
   fnd_File.put_line(fnd_file.log, L_ERROR_RECORD);
   fnd_File.put_line(fnd_file.log, L_ERROR_MESSAGE);
   fnd_file.put_line(fnd_file.log,'When Others Exception - Contact Teltech Help Desk');
   UTL_FILE.FCLOSE_ALL;

END TTEC_PAY_IFACE_KSS_PRNT;

END TTEC_PAY_IFACE_KRONOS_DIRECT_2;    -- pakage body
/
show errors;
/