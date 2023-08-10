

 /************************************************************************************
        Program Name: TTEC_WORKFLOW_ALERT_PKG 

        Description:   

        Developed by : 
        Date         :  

       Modification Log
       Name                  Version #    Date            Description
       -----                 --------     -----           -------------
    RXNETHI(ARGANO)            1.0      18-May-2023      R12.2 Upgrade Remediation
    ****************************************************************************************/


create or replace PACKAGE BODY      ttec_workflow_alert_pkg
AS
  -- v_email_to      VARCHAR2 (200)  := 'ERPDevelopment@ttec.com';
   v_email_from    VARCHAR2 (200)  := 'wfprod@teletech.com';
   v_inst          VARCHAR2 (50);
   v_subject       VARCHAR2 (256);
   v_body1         VARCHAR2 (500);
   v_body2         VARCHAR2 (500);
   v_body3         VARCHAR2 (500);
   v_body_final1   VARCHAR2 (5000);
   v_body_final2   VARCHAR2 (5000);
   v_body_final3   VARCHAR2 (5000);
   g_body_main     VARCHAR2 (5000);
   v_body9  VARCHAR2 (5000);
   v_body10 VARCHAR2 (5000);
   v_send_email    VARCHAR2 (1)    := 'N';
   v_body4         VARCHAR2 (500);
   v_body5         VARCHAR2 (500);
   v_body6         VARCHAR2 (500);
   v_body7         VARCHAR2 (500);
   v_body8         VARCHAR2 (500);
   v_body11        VARCHAR2 (500);
 --  v_body9         VARCHAR2 (500);
 --  v_body10         VARCHAR2 (500);
   g_cr            CHAR (2)        := CHR (13);
   g_crlf          CHAR (2)        := CHR (10) || CHR (13);
   l_mesg          VARCHAR2 (256);
   l_status        NUMBER;
   lc_request VARCHAR2(1000):=NULL;

   CURSOR wf_rec_cnt (p_rec_cnt IN NUMBER)
   IS
     /* SELECT cnt, msg_state, queue
        FROM (SELECT   COUNT (*) cnt, msg_state, 'wf_deferred:' queue
                  FROM applsys.aq$wf_deferred
                 WHERE corr_id = 'APPS:oracle.apps.wf.notification.send'
                   AND msg_state = 'READY'
              GROUP BY msg_priority, corr_id, msg_state
--              UNION ALL
--              SELECT   COUNT (*) cnt, msg_state, 'wf_deferred:'
--                  FROM applsys.aq$wf_notification_out
--                 WHERE msg_state = 'READY'
--              GROUP BY msg_state
              UNION ALL
              SELECT   COUNT (*) cnt, msg_state, 'wf_notification_out:'
                  FROM applsys.aq$wf_notification_out
                 WHERE msg_state = 'READY'
              GROUP BY msg_state)
       WHERE cnt > p_rec_cnt;*/
        SELECT SUM(cnt) cnt, msg_state, queue
        FROM (SELECT   COUNT (*) cnt, msg_state, 'wf_deferred:' queue
                  FROM applsys.aq$wf_deferred  
                 WHERE corr_id = 'APPS:oracle.apps.wf.notification.send'
                   AND msg_state = 'READY'
              GROUP BY msg_priority, corr_id, msg_state
              UNION ALL
              SELECT   COUNT (*) cnt, msg_state, 'wf_notification_out:'
                  FROM applsys.aq$wf_notification_out   
                 WHERE msg_state = 'READY'
              GROUP BY msg_state)
       WHERE 1=1-- cnt > p_rec_cnt--100  /*removing the check as we already checked the sum through function*/
       GROUP BY msg_state, queue; /*This query will give msg_state, with respect to deferred and notification out*/

   CURSOR wf_prc_status
   IS
      SELECT component_name, component_status
        FROM apps.fnd_svc_components a
       WHERE component_name LIKE 'Workflow%'
         AND component_name != 'Workflow Inbound JMS Agent Listener'
         AND component_status <> 'RUNNING';

   /*Cursor for fetching Workflow last SENT*/
   CURSOR  WF_LAST_SENT
   IS
       select begin_hour,time_taken_hrs from (
         select to_char(wn.begin_date,'DD-MON-YYYY HH24:MI:SS') BEGIN_HOUR,
                round( ( (SYSDATE - begin_date) * 24 ),2) time_taken_hrs
         --from applsys.wf_notifications wn    --code commented by RXNETHI-ARGANO,18/05/23
         from apps.wf_notifications wn         --code added by RXNETHI-ARGANO,18/05/23
         where wn.MAIL_STATUS = 'SENT'
         and TRUNC(wn.BEGIN_DATE) >= TRUNC(SYSDATE)
         ORDER BY 1 DESC)
      where rownum=1;


   PROCEDURE ttec_wf_alert (
      errbuf          OUT      VARCHAR2,
      retcode         OUT      VARCHAR2,
      p_rec_cnt       IN       NUMBER,
      p_days           IN       NUMBER,
      email_to_list   IN       VARCHAR2,
      email_cc        IN       VARCHAR2
   )
   AS
   BEGIN
      v_send_email := 'N';
      lc_request:= NULL;

    /*Resending Failed or Error Notifications*/
     lc_request:= resend_notification(p_days);

     fnd_file.put_line (fnd_file.LOG,
                         'Request Submitted: '||lc_request
                        );
     if lc_request is not null
      then
        v_send_email := 'Y';
        v_body11 :=
    'FYI.There are Error/Failed Notifiactions. We have Submitted the Program: Resend Failed/Error Workflow Notifications. Request ID: '||lc_request;

    fnd_file.put_line (fnd_file.LOG,
                         'Inside lc_request not null: ' || lc_request
                        );
      end if;

      SELECT instance_name
        INTO v_inst
        FROM v$instance;

      v_subject := v_inst || '!!ALERT!! ***CRITICAL*** Workflow Email Issue';
    --  v_subject := v_inst || '!!PLEASE IGNORE!!TESTING IN DEV INSTANCE!! Workflow Email Issue';
      v_body1 := 'Hi Syntax Team,';

      IF check_wf_queue (p_rec_cnt)
      THEN
         v_send_email := 'Y';
         v_body2 :=
            'Workflow Email Notifications count for following queue is High.';

         FOR i IN wf_rec_cnt (p_rec_cnt)
         LOOP
            v_body3 :=
                 v_body3 || i.queue || ' Queue Count - ' || i.cnt || CHR (10);
         END LOOP;

         v_body_final1 := g_crlf || v_body2 || CHR (10) || v_body3;
         NULL;
      END IF;

      IF check_wf_process
      THEN
         v_send_email := 'Y';
         v_body4 :=
            'Below Workflow Agent Listener Components are not in RUNNING status.';

         FOR i IN wf_prc_status
         LOOP
            v_body5 :=
                  v_body5
               || i.component_name
               || '-'
               || i.component_status
               || CHR (13);
         END LOOP;

         v_body_final2 := v_body4 || CHR (10) || v_body5 || g_crlf;
      END IF;


      if check_last_sent_time
      THEN
         v_send_email := 'Y';
         v_body6 :=
            'Workflow Notification OUTBOUND queue has stopped since last 1 hour';

         FOR i IN WF_LAST_SENT
         LOOP
            v_body7 :=
                  v_body7
               || 'Workflow Notification was Last Sent on : '
               || i.begin_hour
               || ' MST ('
               || i.time_taken_hrs
               || ' Hour Ago), since then no email has been sent.'
               || CHR (10);
         END LOOP;

         v_body_final3 := --v_body6 || CHR (10) ||
         v_body7;
      END IF;



      v_body8 :=
         'Please look into ASAP. If you have any questions, please contact the EBS Development Team <ebs_development@ttec.com>.';

     v_body9 :=  'Regards,';
     v_body10 := 'EBS Development Team';
--   g_body_main :=
--       v_body1 || g_crlf || v_body2 || CHR (10) || v_body3 ||g_crlf ||v_body_final2
--       || v_body6;v_body11
      g_body_main :=
                v_body1 || v_body_final1 || g_crlf || v_body_final2 ||g_crlf || v_body_final3 ||CHR(13)|| v_body11 ||g_crlf || v_body8||g_crlf||v_body9||CHR(10)||v_body10 ;

    if v_body11 is not null and v_body_final1 is null and v_body_final2 is null and v_body_final3 is null
    then
    g_body_main :=
                v_body1 ||  g_crlf || v_body11||g_crlf || v_body8 ||g_crlf||v_body9||CHR(10)||v_body10 ;
    end if;

    if v_body11 is null and v_body_final1 is null and v_body_final2 is not null and v_body_final3 is null
    then
    g_body_main :=
                v_body1 ||  g_crlf || v_body_final2||g_crlf || v_body8 ||g_crlf||v_body9||CHR(10)||v_body10 ;
    end if;

    if v_body11 is null and v_body_final1 is not null and v_body_final2 is null and v_body_final3 is null
    then
    g_body_main :=
                v_body1 ||  g_crlf || v_body_final1||g_crlf || v_body8 ||g_crlf||v_body9||CHR(10)||v_body10 ;
    end if;

 fnd_file.put_line (fnd_file.LOG,
                         'v_send_email:'||v_send_email
                        );
      IF v_send_email = 'Y'
      THEN
         send_email (p_smtp_srvr        => ttec_library.xx_ttec_smtp_server,
                     p_from_email       => v_email_from,
                     p_to_email         =>  email_to_list,
                     p_cc_email         => email_cc,
                     p_bcc_email        => NULL,
                     p_subject          => v_subject,
                     p_body_line1       => g_body_main,
                     p_body_line2       => NULL,
                     p_body_line3       => NULL,
                     p_body_line4       => NULL,
                     p_body_line5       => NULL,
                     p_attachment1      => NULL,
                     p_attachment2      => NULL,
                     p_attachment3      => NULL,
                     p_attachment4      => NULL,
                     p_attachment5      => NULL,
                     p_status           => l_status,
                     p_mesg             => l_mesg
                    );

      END IF;



   END;

   FUNCTION check_wf_queue (p_rec_cnt IN NUMBER)
      RETURN BOOLEAN
   IS
      v_cnt    NUMBER := 0;
      l_df_cnt NUMBER :=0;
      l_out_cnt NUMBER :=0;

   BEGIN
      fnd_file.put_line (fnd_file.LOG,
                         'In check_wf_queue FUNCTION for count ' || p_rec_cnt
                        );

/*Deffered Count*/
 BEGIN
    SELECT   COUNT (*) cnt
           into l_df_cnt
                  FROM applsys.aq$wf_deferred   
                 WHERE corr_id = 'APPS:oracle.apps.wf.notification.send'
                 AND msg_state = 'READY'
              GROUP BY msg_priority, corr_id, msg_state;
  EXCEPTION WHEN
  OTHERS
  THEN
    l_df_cnt:=0;
    fnd_file.put_line (fnd_file.LOG,
                         'Exception while deriving the deferred queue:'
                        );
END;


/*Out Notification Count*/
 BEGIN
   SELECT   COUNT (*) cnt
        into l_out_cnt
                  FROM applsys.aq$wf_notification_out                     
                 WHERE msg_state = 'READY'
              GROUP BY msg_state;
  EXCEPTION WHEN
   OTHERS
   THEN
   l_out_cnt:=0;
    fnd_file.put_line (fnd_file.LOG,
                         'Exception while deriving count of notification out:'
                        );
  END;

  /*Sum of deffered count + Notification Out count */
   v_cnt := l_df_cnt + l_out_cnt;

  /*    SELECT COUNT (*)
        INTO v_cnt
        FROM (SELECT   COUNT (*) cnt, msg_state, 'In Deferred Queue' queue
                  FROM applsys.aq$wf_deferred
                 WHERE corr_id = 'APPS:oracle.apps.wf.notification.send'
                   AND msg_state = 'READY'
              GROUP BY msg_priority, corr_id, msg_state
              UNION ALL
              SELECT   COUNT (*) cnt, msg_state, 'In Out Queue'
                  FROM applsys.aq$wf_notification_out
                 WHERE msg_state = 'READY'
              GROUP BY msg_state)
       WHERE cnt > p_rec_cnt;  */

      IF v_cnt > p_rec_cnt
      THEN
         RETURN TRUE;
      ELSE
         RETURN FALSE;
      END IF;
   END check_wf_queue;

   FUNCTION check_wf_process
      RETURN BOOLEAN
   IS
      v_count   NUMBER := 0;
   BEGIN
      fnd_file.put_line (fnd_file.LOG, 'In check_wf_process FUNCTION');

      SELECT COUNT (*)
        INTO v_count
        FROM apps.fnd_svc_components a
       WHERE component_name LIKE 'Workflow%'
         AND component_name != 'Workflow Inbound JMS Agent Listener'
         AND component_status <> 'RUNNING';

      IF v_count > 0
      THEN
         RETURN TRUE;
      ELSE
         RETURN FALSE;
      END IF;
   END check_wf_process;

   FUNCTION check_last_sent_time
      RETURN BOOLEAN
   IS
      l_time_taken NUMBER(10,2):=0;
   BEGIN
      fnd_file.put_line (fnd_file.LOG, 'In check_last_sent_time FUNCTION');

/*Calculate last sent duration*/
BEGIN
     SELECT
    round( ( (SYSDATE - begin_date) * 24 * 60),2) time_taken_min
    INTO l_time_taken
FROM
    (
        SELECT
            TO_CHAR(wn.begin_date,'DD-MON-YYYY HH24:MI:SS') begin_hour,
            wn.begin_date
        FROM
            --applsys.wf_notifications wn   --code commented by RXNETHI-ARGANO,18/05/23
            apps.wf_notifications wn        --code added by RXNETHI-ARGANO,18/05/23
        WHERE
            wn.mail_status = 'SENT'
            AND   trunc(wn.begin_date) >= trunc(SYSDATE)
        ORDER BY
            1 DESC
    )
WHERE
    ROWNUM = 1;
 EXCEPTION WHEN OTHERS
 THEN
 l_time_taken:=0;
 END;

/* if last email sent is more than 60 mins i.e 1 hour send and email  */
      IF l_time_taken > 60 --60
      THEN
         RETURN TRUE;--TRUE;
      ELSE
         RETURN FALSE;
      END IF;
   END check_last_sent_time;

/*Resending Failed or Error Notifications*/
function resend_notification(p_no_days IN NUMBER)
return VARCHAR2
is

L_FAILED_COUNT NUMBER:=0;
L_ERROR_COUNT NUMBER:=0;
l_request_id number;
l_request_ids varchar2(500):=NULL;

begin

fnd_file.put_line (fnd_file.LOG,'Entered into Re-Send Notifications:');

BEGIN

select COUNT(1) INTO L_FAILED_COUNT from apps.wf_notifications
where mail_status='FAILED'
AND BEGIN_DATE >= SYSDATE - p_no_days;

EXCEPTION WHEN OTHERS
THEN
L_FAILED_COUNT:=0;
END;


BEGIN
select COUNT(1) INTO L_ERROR_COUNT from apps.wf_notifications
where mail_status='ERROR'
AND BEGIN_DATE >= SYSDATE - p_no_days;
EXCEPTION WHEN OTHERS
THEN
L_FAILED_COUNT:=0;
END;


IF L_FAILED_COUNT > 0
THEN
l_request_id:=submit_request('FAILED',p_no_days);

l_request_ids:=l_request_id||'--->FAILED, Failed Count:'||L_FAILED_COUNT||' ';
END IF;

IF L_ERROR_COUNT > 0
THEN
l_request_id:=submit_request('ERROR',p_no_days);

   IF l_request_ids IS NOT NULL
   THEN
   l_request_ids:=l_request_ids||',Request ID: '||l_request_id||'--->ERROR, Error Count:'||L_ERROR_COUNT||' ';
   ELSE
   l_request_ids:=l_request_id||',Request ID: '||'--->ERROR, Error Count:'||L_ERROR_COUNT||' ';
   END IF;

END IF;

return l_request_ids;

END resend_notification;

function submit_request(P_ERR_TYPE IN VARCHAR2,p_no_days IN NUMBER)
return number
is

l_responsibility_id NUMBER;
l_application_id NUMBER;
l_user_id NUMBER;
l_request_id NUMBER;

BEGIN

SELECT DISTINCT fr.responsibility_id,
frx.application_id
INTO l_responsibility_id,
l_application_id
FROM apps.fnd_responsibility frx,
apps.fnd_responsibility_tl fr
WHERE fr.responsibility_id = frx.responsibility_id
AND fr.responsibility_name='System Administrator';

SELECT user_id INTO l_user_id FROM fnd_user
               WHERE user_name = 'SYSADMIN';

/*Apps initialize*/
fnd_global.APPS_INITIALIZE(user_id => l_user_id,
                           resp_id => l_responsibility_id,
                           resp_appl_id => l_application_id);


l_request_id := fnd_request.submit_request(application => 'FND',program => 'FNDWF_NTF_RESEND',description => 'Resend Faile or Error notifications'
,start_time => SYSDATE,sub_request => false,argument1 => P_ERR_TYPE, -- Parameter Whether ERROR/FAILED
argument2 => NULL,argument3 => NULL,argument4 => to_char(SYSDATE - p_no_days,'yyyy/mm/dd')||'00:00:00',--TO_CHAR(SYSDATE,
argument5 => to_char(SYSDATE,'yyyy/mm/dd')||'00:00:00'--SYSDATE
 );

COMMIT;

IF l_request_id = 0
THEN
fnd_file.put_line (fnd_file.LOG,'Concurrent request : Resend Failed/Error Workflow Notifications failed to submit');
ELSE
fnd_file.put_line (fnd_file.LOG,'Successfully Submitted the Concurrent Request: Resend Failed/Error Workflow Notifications, request id:'||l_request_id);
END IF;

return l_request_id;
EXCEPTION WHEN
OTHERS THEN

fnd_file.put_line (fnd_file.LOG,'Error While Submitting Concurrent Request '||TO_CHAR(SQLCODE)||'-'||sqlerrm);

end;

END ttec_workflow_alert_pkg;
/
show errors;
/