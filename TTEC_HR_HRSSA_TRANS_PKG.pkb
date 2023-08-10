create or replace PACKAGE BODY      ttec_hr_hrssa_trans_pkg
AS
/* $Header: ttec_hr_hrssa_trans_pkg 1.0 2009/12/29 kbabu $ */
/*== START ================================================================================================*\
  Author:  Kaushik Babu
    Date:  December 29, 2009
    Desc:  To Archieve HRSSA Workflow Transactions on a daily basis.
  Modification History:

 Mod#  Person         Date     Comments
---------------------------------------------------------------------------
 1.0  Kaushik Babu  29-DEC-09 Created package
 1.1  Kaushik Babu  18-FEB-10 Changed query to select the rows as per the parameters
 1.0   MXKEERTHI(ARGANO)     06-Jul-2023      R12.2 Upgrade Remediation
\*== END ==================================================================================================*/
   PROCEDURE main_proc (
      p_errbuf       IN   VARCHAR2,
      p_errcode      IN   NUMBER,
      p_start_date   IN   VARCHAR2,
      p_end_date     IN   VARCHAR2,
      p_item_key     IN   VARCHAR2,
      p_trans_type   IN   VARCHAR2
   )
   IS
      CURSOR c_mss_tran_type
      IS
         SELECT *
           FROM fnd_lookup_values
          WHERE lookup_type = 'TTEC_HRSSA_MSS_TRANSACTION'
            AND enabled_flag = 'Y'
            AND LANGUAGE = 'US'
            AND lookup_code = NVL (p_trans_type, lookup_code)
            AND SYSDATE BETWEEN start_date_active
                            AND NVL (end_date_active, SYSDATE);

      CURSOR c_wf_items (
         l_trans_type   VARCHAR2,
         p_start_date   VARCHAR2,
         p_end_date     VARCHAR2
      )
      IS
         SELECT   *
             FROM apps.wf_items
            WHERE item_type = 'HRSSA'
              AND end_date IS NOT NULL
              AND root_activity = l_trans_type
              AND TO_DATE (end_date) BETWEEN TO_DATE (p_start_date,
                                                      'YYYY/MM/DD HH24:MI:SS'
                                                     )
                                         AND TO_DATE
                                               (p_end_date,
                                                'YYYY/MM/DD HH24:MI:SS'
                                               )               -- Revision 1.1
              AND item_key = NVL (p_item_key, item_key)
         ORDER BY item_key, begin_date;

      CURSOR c_wf_item_acty_stat (l_item_key VARCHAR2)
      IS
         SELECT *
           FROM apps.wf_item_activity_statuses
          WHERE item_type = 'HRSSA' AND item_key = l_item_key;

      CURSOR c_wf_item_att_val (l_item_key VARCHAR2)
      IS
         SELECT *
           FROM apps.wf_item_attribute_values
          WHERE item_type = 'HRSSA' AND item_key = l_item_key;

      CURSOR c_wf_notifications (l_item_key VARCHAR2)
      IS
         SELECT   *
             FROM apps.wf_notifications
            WHERE MESSAGE_TYPE = 'HRSSA' AND item_key = l_item_key
         ORDER BY item_key, notification_id;

      CURSOR c_wf_notif_att (l_notification_id NUMBER)
      IS
         SELECT *
           FROM apps.wf_notification_attributes
          WHERE notification_id = l_notification_id;

      CURSOR c_twf_items (
         l_trans_type   VARCHAR2,
         l_start_date   DATE,
         l_end_date     DATE
      )
      IS
         SELECT   *
		 		--  FROM cust.ttec_wf_items-- Commented code by MXKEERTHI-ARGANO, 07/06/2023
             FROM apps.ttec_wf_items--  code Added by MXKEERTHI-ARGANO, 07/06/2023

            WHERE item_type = 'HRSSA'
              AND end_date IS NOT NULL
              AND root_activity = l_trans_type
              AND TO_DATE (end_date) BETWEEN TO_DATE (l_start_date)
                                         AND TO_DATE (l_end_date)
              AND item_key = NVL (p_item_key, item_key)
         ORDER BY item_key, begin_date;

      CURSOR c_twf_item_acty_stat (l_item_key VARCHAR2)
      IS
         SELECT *
		 		-- FROM cust.ttec_wf_item_acty_stat -- Commented code by MXKEERTHI-ARGANO, 07/06/2023
	           FROM apps.ttec_wf_item_acty_stat--  code Added by MXKEERTHI-ARGANO, 07/06/2023

          WHERE item_type = 'HRSSA' AND item_key = l_item_key;

      CURSOR c_twf_item_att_val (l_item_key VARCHAR2)
      IS
         SELECT *
		 		--FROM cust.ttec_wf_item_att_values -- Commented code by MXKEERTHI-ARGANO, 07/06/2023
	           FROM apps.ttec_wf_item_att_values--  code Added by MXKEERTHI-ARGANO, 07/06/2023

          WHERE item_type = 'HRSSA' AND item_key = l_item_key;

      CURSOR c_twf_notifications (l_item_key VARCHAR2)
      IS
         SELECT   *
		 		-- FROM cust.ttec_wf_notifications-- Commented code by MXKEERTHI-ARGANO, 07/06/2023
	            FROM apps.ttec_wf_notifications--  code Added by MXKEERTHI-ARGANO, 07/06/2023
 
            WHERE MESSAGE_TYPE = 'HRSSA' AND item_key = l_item_key
         ORDER BY item_key, notification_id;

      CURSOR c_twf_notif_att (l_notification_id NUMBER)
      IS
         SELECT *
		 		--  FROM cust.ttec_wf_notif_att -- Commented code by MXKEERTHI-ARGANO, 07/06/2023
		          FROM apps.ttec_wf_notif_att--  code Added by MXKEERTHI-ARGANO, 07/06/2023
 
          WHERE notification_id = l_notification_id;

      l_value        NUMBER;
      l_start_date   DATE;
      l_end_date     DATE;
      l_cnt_num1     NUMBER DEFAULT 0;
      l_cnt_num2     NUMBER DEFAULT 0;
      l_cnt_num3     NUMBER DEFAULT 0;
      l_cnt_num4     NUMBER DEFAULT 0;
      l_cnt_num5     NUMBER DEFAULT 0;
   BEGIN
      -- Deleting Record in the custom tables from each transaction type and item key
      BEGIN
         l_cnt_num1 := 0;
         l_cnt_num2 := 0;
         l_cnt_num3 := 0;
         l_cnt_num4 := 0;
         l_cnt_num5 := 0;
         fnd_file.put_line (fnd_file.LOG, 'DELETION');

         SELECT TRUNC (TRUNC (TRUNC (SYSDATE, 'YYYY') - 1, 'YYYY') - 1,
                       'YYYY')
           INTO l_start_date
           FROM DUAL;

         SELECT TRUNC (TRUNC (SYSDATE, 'YYYY') - 1, 'YYYY') - 1
           INTO l_end_date
           FROM DUAL;

         fnd_file.put_line (fnd_file.LOG, l_start_date || '-' || l_end_date);

         FOR r_mss_tran_type IN c_mss_tran_type
         LOOP
            FOR r_twf_items IN c_twf_items (r_mss_tran_type.lookup_code,
                                            l_start_date,
                                            l_end_date
                                           )
            LOOP
               fnd_file.put_line (fnd_file.LOG,
                                     r_twf_items.item_type
                                  || '-'
                                  || r_twf_items.item_key
                                  || '-'
                                  || r_twf_items.root_activity
                                 );

               BEGIN
			   		-- DELETE FROM cust.ttec_wf_items-- Commented code by MXKEERTHI-ARGANO, 07/06/2023
                 DELETE FROM apps.ttec_wf_items--  code Added by MXKEERTHI-ARGANO, 07/06/2023
 
                        WHERE item_type = r_twf_items.item_type
                          AND item_key = r_twf_items.item_key
                          AND root_activity = r_twf_items.root_activity;

                  l_cnt_num1 := l_cnt_num1 + 1;
               EXCEPTION
                  WHEN OTHERS
                  THEN
                     fnd_file.put_line
                                      (fnd_file.LOG,
                                          'Errored out of r_twf_items loop -'
                                       || r_mss_tran_type.lookup_code
                                       || '-'
                                       || r_twf_items.item_key
                                       || '-'
                                       || SQLERRM
                                      );
               END;

               FOR r_twf_item_acty_stat IN
                  c_twf_item_acty_stat (r_twf_items.item_key)
               LOOP
                  BEGIN
				  		--  DELETE FROM cust.ttec_wf_item_acty_stat -- Commented code by MXKEERTHI-ARGANO, 07/06/2023
		                    DELETE FROM apps.ttec_wf_item_acty_stat--  code Added by MXKEERTHI-ARGANO, 07/06/2023
 
                           WHERE item_type = r_twf_item_acty_stat.item_type
                             AND item_key = r_twf_item_acty_stat.item_key
                             AND process_activity =
                                         r_twf_item_acty_stat.process_activity;

                     l_cnt_num2 := l_cnt_num2 + 1;
                  EXCEPTION
                     WHEN OTHERS
                     THEN
                        fnd_file.put_line
                              (fnd_file.LOG,
                                  'Errored out of r_wf_item_acty_stat loop -'
                               || r_mss_tran_type.lookup_code
                               || '-'
                               || r_twf_item_acty_stat.item_key
                               || '-'
                               || r_twf_item_acty_stat.process_activity
                               || '-'
                               || SQLERRM
                              );
                  END;
               END LOOP;

               FOR r_twf_item_att_val IN
                  c_twf_item_att_val (r_twf_items.item_key)
               LOOP
                  BEGIN
				  		-- DELETE FROM cust.ttec_wf_item_att_values-- Commented code by MXKEERTHI-ARGANO, 07/06/2023
		                    DELETE FROM apps.ttec_wf_item_att_values--  code Added by MXKEERTHI-ARGANO, 07/06/2023
 
                           WHERE item_type = r_twf_item_att_val.item_type
                             AND item_key = r_twf_item_att_val.item_key
                             AND NAME = r_twf_item_att_val.NAME;

                     l_cnt_num3 := l_cnt_num3 + 1;
                  EXCEPTION
                     WHEN OTHERS
                     THEN
                        fnd_file.put_line
                                (fnd_file.LOG,
                                    'Errored out of r_wf_item_att_val loop -'
                                 || r_mss_tran_type.lookup_code
                                 || '-'
                                 || r_twf_item_att_val.item_key
                                 || '-'
                                 || r_twf_item_att_val.NAME
                                 || '-'
                                 || SQLERRM
                                );
                  END;
               END LOOP;

               FOR r_twf_notifications IN
                  c_twf_notifications (r_twf_items.item_key)
               LOOP
                  BEGIN
				  		-- DELETE FROM cust.ttec_wf_notifications -- Commented code by MXKEERTHI-ARGANO, 07/06/2023
                     DELETE FROM apps.ttec_wf_notifications--  code Added by MXKEERTHI-ARGANO, 07/06/2023

                           WHERE MESSAGE_TYPE =
                                             r_twf_notifications.MESSAGE_TYPE
                             AND item_key = r_twf_notifications.item_key
                             AND notification_id =
                                           r_twf_notifications.notification_id;

                     l_cnt_num4 := l_cnt_num4 + 1;
                  EXCEPTION
                     WHEN OTHERS
                     THEN
                        fnd_file.put_line
                               (fnd_file.LOG,
                                   'Errored out of r_wf_notifications loop -'
                                || r_mss_tran_type.lookup_code
                                || '-'
                                || r_twf_notifications.item_key
                                || '-'
                                || r_twf_notifications.message_name
                                || '-'
                                || SQLERRM
                               );
                  END;

                  FOR r_twf_notif_att IN
                     c_twf_notif_att (r_twf_notifications.notification_id)
                  LOOP
                     BEGIN
					 		-- DELETE FROM cust.ttec_wf_notif_att -- Commented code by MXKEERTHI-ARGANO, 07/06/2023
                        DELETE FROM apps.ttec_wf_notif_att--  code Added by MXKEERTHI-ARGANO, 07/06/2023

                              WHERE notification_id =
                                              r_twf_notif_att.notification_id
                                AND NAME = r_twf_notif_att.NAME;

                        l_cnt_num5 := l_cnt_num5 + 1;
                     EXCEPTION
                        WHEN OTHERS
                        THEN
                           fnd_file.put_line
                                   (fnd_file.LOG,
                                       'Errored out of r_wf_notif_att loop -'
                                    || r_mss_tran_type.lookup_code
                                    || '-'
                                    || r_twf_notif_att.notification_id
                                    || '-'
                                    || r_twf_notif_att.NAME
                                    || '-'
                                    || SQLERRM
                                   );
                     END;
                  END LOOP;
               END LOOP;
            END LOOP;
         END LOOP;

         COMMIT;
         fnd_file.put_line (fnd_file.output,
		 
                            'NO OF ROWS DELETED FROM ARCHIVE TABLES'
                           );
         fnd_file.put_line (fnd_file.output,
		 	 'No of Rows Deleted from cust.ttec_wf_items :'
              
                            || l_cnt_num1
                           );
         fnd_file.put_line
                   (fnd_file.output,
				   'No of Rows Deleted from cust.ttec_wf_item_acty_stat :'
         
                    || l_cnt_num2
                   );
         fnd_file.put_line
                  (fnd_file.output,
	
                      'No of Rows Deleted from cust.ttec_wf_item_att_values :'
                   || l_cnt_num3
                  );
         fnd_file.put_line
                    (fnd_file.output,
							 'No of Rows Deleted from cust.ttec_wf_notifications :' 
                  

                     || l_cnt_num4
                    );
         fnd_file.put_line
                        (fnd_file.output,
                                 'No of Rows Deleted from cust.ttec_wf_notif_att :'
                  
                         || l_cnt_num5
                        );
      EXCEPTION
         WHEN OTHERS
         THEN
            ROLLBACK;
            fnd_file.put_line
                    (fnd_file.LOG,
                        'Errored out during deleting data in custom tables -'
                     || SQLERRM
                    );
      END;

      -- Inserting Records into custom tables for each transaction type and item key\
      BEGIN
         l_cnt_num1 := 0;
         l_cnt_num2 := 0;
         l_cnt_num3 := 0;
         l_cnt_num4 := 0;
         l_cnt_num5 := 0;
         fnd_file.put_line (fnd_file.LOG, 'INSERTION');

         FOR r_mss_tran_type IN c_mss_tran_type
         LOOP
            FOR r_wf_items IN c_wf_items (r_mss_tran_type.lookup_code,
                                          p_start_date,
                                          p_end_date
                                         )
            LOOP
               l_value := NULL;
               fnd_file.put_line (fnd_file.LOG,
                                     r_wf_items.item_type
                                  || '-'
                                  || r_wf_items.item_key
                                  || '-'
                                  || r_wf_items.root_activity
                                 );

               BEGIN
                  SELECT 1
                    INTO l_value
							--FROM cust.ttec_wf_items-- Commented code by MXKEERTHI-ARGANO, 07/06/2023
                    FROM apps.ttec_wf_items--  code Added by MXKEERTHI-ARGANO, 07/06/2023

                   WHERE item_type = r_wf_items.item_type
                     AND item_key = r_wf_items.item_key
                     AND root_activity = r_wf_items.root_activity;
               EXCEPTION
                  WHEN NO_DATA_FOUND
                  THEN
                     BEGIN
					 		--  INSERT INTO cust.ttec_wf_items -- Commented code by MXKEERTHI-ARGANO, 07/06/2023
	                        INSERT INTO apps.ttec_wf_items--  code Added by MXKEERTHI-ARGANO, 07/06/2023

                                    (item_type,
                                     item_key,
                                     root_activity,
                                     root_activity_version,
                                     owner_role,
                                     parent_item_type,
                                     parent_item_key,
                                     parent_context,
                                     begin_date,
                                     end_date,
                                     user_key,
                                     ha_migration_flag,
                                     security_group_id
                                    )
                             VALUES (r_wf_items.item_type,
                                     r_wf_items.item_key,
                                     r_wf_items.root_activity,
                                     r_wf_items.root_activity_version,
                                     r_wf_items.owner_role,
                                     r_wf_items.parent_item_type,
                                     r_wf_items.parent_item_key,
                                     r_wf_items.parent_context,
                                     r_wf_items.begin_date,
                                     r_wf_items.end_date,
                                     r_wf_items.user_key,
                                     r_wf_items.ha_migration_flag,
                                     r_wf_items.security_group_id
                                    );

                        l_cnt_num1 := l_cnt_num1 + 1;
                     EXCEPTION
                        WHEN OTHERS
                        THEN
                           fnd_file.put_line
                              (fnd_file.LOG,
                                  'Errored - Insert Into cust.ttec_wf_items -'
                               || r_mss_tran_type.lookup_code
                               || '-'
                               || r_wf_items.item_key
                               || '-'
                               || SQLERRM
                              );
                     END;
                  WHEN OTHERS
                  THEN
                     fnd_file.put_line (fnd_file.LOG,
                                           'Errored out of r_wf_items loop -'
                                        || r_mss_tran_type.lookup_code
                                        || '-'
                                        || r_wf_items.item_key
                                        || '-'
                                        || SQLERRM
                                       );
               END;

               FOR r_wf_item_acty_stat IN
                  c_wf_item_acty_stat (r_wf_items.item_key)
               LOOP
                  l_value := NULL;

                  BEGIN
                     SELECT 1
                       INTO l_value
					   		-- FROM cust.ttec_wf_item_acty_stat -- Commented code by MXKEERTHI-ARGANO, 07/06/2023
                       FROM apps.ttec_wf_item_acty_stat--  code Added by MXKEERTHI-ARGANO, 07/06/2023

                      WHERE item_type = r_wf_item_acty_stat.item_type
                        AND item_key = r_wf_item_acty_stat.item_key
                        AND process_activity =
                                          r_wf_item_acty_stat.process_activity;
                  EXCEPTION
                     WHEN NO_DATA_FOUND
                     THEN
                        BEGIN
								--  INSERT INTO cust.ttec_wf_item_acty_stat  -- Commented code by MXKEERTHI-ARGANO, 07/06/2023
                           INSERT INTO apps.ttec_wf_item_acty_stat--  code Added by MXKEERTHI-ARGANO, 07/06/2023

                                       (item_type,
                                        item_key,
                                        process_activity,
                                        activity_status,
                                        activity_result_code,
                                        assigned_user,
                                        notification_id,
                                        begin_date,
                                        end_date,
                                        execution_time,
                                        error_name,
                                        error_message,
                                        error_stack,
                                        outbound_queue_id,
                                        due_date,
                                        security_group_id,
                                        action,
                                        performed_by
                                       )
                                VALUES (r_wf_item_acty_stat.item_type,
                                        r_wf_item_acty_stat.item_key,
                                        r_wf_item_acty_stat.process_activity,
                                        r_wf_item_acty_stat.activity_status,
                                        r_wf_item_acty_stat.activity_result_code,
                                        r_wf_item_acty_stat.assigned_user,
                                        r_wf_item_acty_stat.notification_id,
                                        r_wf_item_acty_stat.begin_date,
                                        r_wf_item_acty_stat.end_date,
                                        r_wf_item_acty_stat.execution_time,
                                        r_wf_item_acty_stat.error_name,
                                        r_wf_item_acty_stat.error_message,
                                        r_wf_item_acty_stat.error_stack,
                                        r_wf_item_acty_stat.outbound_queue_id,
                                        r_wf_item_acty_stat.due_date,
                                        r_wf_item_acty_stat.security_group_id,
                                        r_wf_item_acty_stat.action,
                                        r_wf_item_acty_stat.performed_by
                                       );

                           l_cnt_num2 := l_cnt_num2 + 1;
                        EXCEPTION
                           WHEN OTHERS
                           THEN
                              fnd_file.put_line
                                 (fnd_file.LOG,
                                     'Errored - Insert Into cust.ttec_wf_item_acty_stat -'
                                  || r_mss_tran_type.lookup_code
                                  || '-'
                                  || r_wf_item_acty_stat.item_key
                                  || '-'
                                  || r_wf_item_acty_stat.process_activity
                                  || '-'
                                  || SQLERRM
                                 );
                        END;
                     WHEN OTHERS
                     THEN
                        fnd_file.put_line
                              (fnd_file.LOG,
                                  'Errored out of r_wf_item_acty_stat loop -'
                               || r_mss_tran_type.lookup_code
                               || '-'
                               || r_wf_item_acty_stat.item_key
                               || '-'
                               || r_wf_item_acty_stat.process_activity
                               || '-'
                               || SQLERRM
                              );
                  END;
               END LOOP;

               FOR r_wf_item_att_val IN c_wf_item_att_val (r_wf_items.item_key)
               LOOP
                  l_value := NULL;

                  BEGIN
                     SELECT 1
                       INTO l_value
					   		-- FROM cust.ttec_wf_item_att_values -- Commented code by MXKEERTHI-ARGANO, 07/06/2023
                     FROM apps.ttec_wf_item_att_values--  code Added by MXKEERTHI-ARGANO, 07/06/2023
  
                      WHERE item_type = r_wf_item_att_val.item_type
                        AND item_key = r_wf_item_att_val.item_key
                        AND NAME = r_wf_item_att_val.NAME;
                  EXCEPTION
                     WHEN NO_DATA_FOUND
                     THEN
                        BEGIN
								--  INSERT INTO cust.ttec_wf_item_att_values  -- Commented code by MXKEERTHI-ARGANO, 07/06/2023
                           INSERT INTO apps.ttec_wf_item_att_values--  code Added by MXKEERTHI-ARGANO, 07/06/2023

                                       (item_type,
                                        item_key,
                                        NAME,
                                        text_value,
                                        number_value,
                                        date_value,
                                        event_value,
                                        security_group_id
                                       )
                                VALUES (r_wf_item_att_val.item_type,
                                        r_wf_item_att_val.item_key,
                                        r_wf_item_att_val.NAME,
                                        r_wf_item_att_val.text_value,
                                        r_wf_item_att_val.number_value,
                                        r_wf_item_att_val.date_value,
                                        r_wf_item_att_val.event_value,
                                        r_wf_item_att_val.security_group_id
                                       );

                           l_cnt_num3 := l_cnt_num3 + 1;
                        EXCEPTION
                           WHEN OTHERS
                           THEN
                              fnd_file.put_line
                                 (fnd_file.LOG,
								 'Errored - Insert Into cust.ttec_wf_item_att_values -'
                           

                                  || r_mss_tran_type.lookup_code
                                  || '-'
                                  || r_wf_item_att_val.item_key
                                  || '-'
                                  || r_wf_item_att_val.NAME
                                  || '-'
                                  || SQLERRM
                                 );
                        END;
                     WHEN OTHERS
                     THEN
                        fnd_file.put_line
                                (fnd_file.LOG,
                                    'Errored out of r_wf_item_att_val loop -'
                                 || r_mss_tran_type.lookup_code
                                 || '-'
                                 || r_wf_item_att_val.item_key
                                 || '-'
                                 || r_wf_item_att_val.NAME
                                 || '-'
                                 || SQLERRM
                                );
                  END;
               END LOOP;

               FOR r_wf_notifications IN
                  c_wf_notifications (r_wf_items.item_key)
               LOOP
                  l_value := NULL;

                  BEGIN
                     SELECT 1
                       INTO l_value
					   		--FROM cust.ttec_wf_notifications -- Commented code by MXKEERTHI-ARGANO, 07/06/2023
                      FROM apps.ttec_wf_notifications--  code Added by MXKEERTHI-ARGANO, 07/06/2023
 
                      WHERE MESSAGE_TYPE = r_wf_notifications.MESSAGE_TYPE
                        AND item_key = r_wf_notifications.item_key
                        AND notification_id =
                                            r_wf_notifications.notification_id;
                  EXCEPTION
                     WHEN NO_DATA_FOUND
                     THEN
                        BEGIN
								--UPDATE cust.ttec_wf_notifications  -- Commented code by MXKEERTHI-ARGANO, 07/06/2023
	                          INSERT INTO apps.ttec_wf_notifications--  code Added by MXKEERTHI-ARGANO, 07/06/2023
 
                                       (notification_id,
                                        GROUP_ID,
                                        MESSAGE_TYPE,
                                        message_name,
                                        recipient_role,
                                        status,
                                        access_key,
                                        mail_status,
                                        priority,
                                        begin_date,
                                        end_date,
                                        due_date,
                                        responder,
                                        user_comment,
                                        callback,
                                        CONTEXT,
                                        original_recipient,
                                        from_user,
                                        to_user,
                                        subject,
                                        LANGUAGE,
                                        more_info_role,
                                        from_role,
                                        security_group_id,
                                        user_key,
                                        item_key,
                                        protected_text_attribute1,
                                        protected_text_attribute2,
                                        protected_text_attribute3,
                                        protected_text_attribute4,
                                        protected_text_attribute5,
                                        protected_text_attribute6,
                                        protected_text_attribute7,
                                        protected_text_attribute8,
                                        protected_text_attribute9,
                                        protected_text_attribute10,
                                        protected_form_attribute1,
                                        protected_form_attribute2,
                                        protected_form_attribute3,
                                        protected_form_attribute4,
                                        protected_form_attribute5,
                                        protected_url_attribute1,
                                        protected_url_attribute2,
                                        protected_url_attribute3,
                                        protected_url_attribute4,
                                        protected_url_attribute5,
                                        protected_date_attribute1,
                                        protected_date_attribute2,
                                        protected_date_attribute3,
                                        protected_date_attribute4,
                                        protected_date_attribute5,
                                        protected_number_attribute1,
                                        protected_number_attribute2,
                                        protected_number_attribute3,
                                        protected_number_attribute4,
                                        protected_number_attribute5,
                                        text_attribute1,
                                        text_attribute2,
                                        text_attribute3,
                                        text_attribute4,
                                        text_attribute5,
                                        text_attribute6,
                                        text_attribute7,
                                        text_attribute8,
                                        text_attribute9,
                                        text_attribute10,
                                        form_attribute1,
                                        form_attribute2,
                                        form_attribute3,
                                        form_attribute4,
                                        form_attribute5,
                                        url_attribute1,
                                        url_attribute2,
                                        url_attribute3,
                                        url_attribute4,
                                        url_attribute5,
                                        date_attribute1,
                                        date_attribute2,
                                        date_attribute3,
                                        date_attribute4,
                                        date_attribute5,
                                        number_attribute1,
                                        number_attribute2,
                                        number_attribute3,
                                        number_attribute4,
                                        number_attribute5
                                       )
                                VALUES (r_wf_notifications.notification_id,
                                        r_wf_notifications.GROUP_ID,
                                        r_wf_notifications.MESSAGE_TYPE,
                                        r_wf_notifications.message_name,
                                        r_wf_notifications.recipient_role,
                                        r_wf_notifications.status,
                                        r_wf_notifications.access_key,
                                        r_wf_notifications.mail_status,
                                        r_wf_notifications.priority,
                                        r_wf_notifications.begin_date,
                                        r_wf_notifications.end_date,
                                        r_wf_notifications.due_date,
                                        r_wf_notifications.responder,
                                        r_wf_notifications.user_comment,
                                        r_wf_notifications.callback,
                                        r_wf_notifications.CONTEXT,
                                        r_wf_notifications.original_recipient,
                                        r_wf_notifications.from_user,
                                        r_wf_notifications.to_user,
                                        r_wf_notifications.subject,
                                        r_wf_notifications.LANGUAGE,
                                        r_wf_notifications.more_info_role,
                                        r_wf_notifications.from_role,
                                        r_wf_notifications.security_group_id,
                                        r_wf_notifications.user_key,
                                        r_wf_notifications.item_key,
                                        r_wf_notifications.protected_text_attribute1,
                                        r_wf_notifications.protected_text_attribute2,
                                        r_wf_notifications.protected_text_attribute3,
                                        r_wf_notifications.protected_text_attribute4,
                                        r_wf_notifications.protected_text_attribute5,
                                        r_wf_notifications.protected_text_attribute6,
                                        r_wf_notifications.protected_text_attribute7,
                                        r_wf_notifications.protected_text_attribute8,
                                        r_wf_notifications.protected_text_attribute9,
                                        r_wf_notifications.protected_text_attribute10,
                                        r_wf_notifications.protected_form_attribute1,
                                        r_wf_notifications.protected_form_attribute2,
                                        r_wf_notifications.protected_form_attribute3,
                                        r_wf_notifications.protected_form_attribute4,
                                        r_wf_notifications.protected_form_attribute5,
                                        r_wf_notifications.protected_url_attribute1,
                                        r_wf_notifications.protected_url_attribute2,
                                        r_wf_notifications.protected_url_attribute3,
                                        r_wf_notifications.protected_url_attribute4,
                                        r_wf_notifications.protected_url_attribute5,
                                        r_wf_notifications.protected_date_attribute1,
                                        r_wf_notifications.protected_date_attribute2,
                                        r_wf_notifications.protected_date_attribute3,
                                        r_wf_notifications.protected_date_attribute4,
                                        r_wf_notifications.protected_date_attribute5,
                                        r_wf_notifications.protected_number_attribute1,
                                        r_wf_notifications.protected_number_attribute2,
                                        r_wf_notifications.protected_number_attribute3,
                                        r_wf_notifications.protected_number_attribute4,
                                        r_wf_notifications.protected_number_attribute5,
                                        r_wf_notifications.text_attribute1,
                                        r_wf_notifications.text_attribute2,
                                        r_wf_notifications.text_attribute3,
                                        r_wf_notifications.text_attribute4,
                                        r_wf_notifications.text_attribute5,
                                        r_wf_notifications.text_attribute6,
                                        r_wf_notifications.text_attribute7,
                                        r_wf_notifications.text_attribute8,
                                        r_wf_notifications.text_attribute9,
                                        r_wf_notifications.text_attribute10,
                                        r_wf_notifications.form_attribute1,
                                        r_wf_notifications.form_attribute2,
                                        r_wf_notifications.form_attribute3,
                                        r_wf_notifications.form_attribute4,
                                        r_wf_notifications.form_attribute5,
                                        r_wf_notifications.url_attribute1,
                                        r_wf_notifications.url_attribute2,
                                        r_wf_notifications.url_attribute3,
                                        r_wf_notifications.url_attribute4,
                                        r_wf_notifications.url_attribute5,
                                        r_wf_notifications.date_attribute1,
                                        r_wf_notifications.date_attribute2,
                                        r_wf_notifications.date_attribute3,
                                        r_wf_notifications.date_attribute4,
                                        r_wf_notifications.date_attribute5,
                                        r_wf_notifications.number_attribute1,
                                        r_wf_notifications.number_attribute2,
                                        r_wf_notifications.number_attribute3,
                                        r_wf_notifications.number_attribute4,
                                        r_wf_notifications.number_attribute5
                                       );

                           l_cnt_num4 := l_cnt_num4 + 1;
                        EXCEPTION
                           WHEN OTHERS
                           THEN
                              fnd_file.put_line
                                 (fnd_file.LOG,
								 	 'Errored - Insert Into cust.ttec_wf_notifications -' 
 
                                  || r_mss_tran_type.lookup_code
                                  || '-'
                                  || r_wf_notifications.item_key
                                  || '-'
                                  || r_wf_notifications.message_name
                                  || '-'
                                  || SQLERRM
                                 );
                        END;
                     WHEN OTHERS
                     THEN
                        fnd_file.put_line
                               (fnd_file.LOG,
                                   'Errored out of r_wf_notifications loop -'
                                || r_mss_tran_type.lookup_code
                                || '-'
                                || r_wf_notifications.item_key
                                || '-'
                                || r_wf_notifications.message_name
                                || '-'
                                || SQLERRM
                               );
                  END;

                  FOR r_wf_notif_att IN
                     c_wf_notif_att (r_wf_notifications.notification_id)
                  LOOP
                     l_value := NULL;

                     BEGIN
                        SELECT 1
                          INTO l_value
						  		--FROM cust.ttec_wf_notif_att-- Commented code by MXKEERTHI-ARGANO, 07/06/2023
                          FROM apps.ttec_wf_notif_att--  code Added by MXKEERTHI-ARGANO, 07/06/2023

                         WHERE notification_id =
                                                r_wf_notif_att.notification_id
                           AND NAME = r_wf_notif_att.NAME;
                     EXCEPTION
                        WHEN NO_DATA_FOUND
                        THEN
                           BEGIN
						   		--  INSERT INTO cust.ttec_wf_notif_att -- Commented code by MXKEERTHI-ARGANO, 07/06/2023
                              INSERT INTO apps.ttec_wf_notif_att--  code Added by MXKEERTHI-ARGANO, 07/06/2023

                                          (notification_id,
                                           NAME,
                                           text_value,
                                           number_value,
                                           date_value,
                                           event_value,
                                           security_group_id
                                          )
                                   VALUES (r_wf_notif_att.notification_id,
                                           r_wf_notif_att.NAME,
                                           r_wf_notif_att.text_value,
                                           r_wf_notif_att.number_value,
                                           r_wf_notif_att.date_value,
                                           r_wf_notif_att.event_value,
                                           r_wf_notif_att.security_group_id
                                          );

                              l_cnt_num5 := l_cnt_num5 + 1;
                           EXCEPTION
                              WHEN OTHERS
                              THEN
                                 fnd_file.put_line
                                    (fnd_file.LOG,
									 'Errored - Insert Into cust.ttec_wf_notif_att -' 
 

                                     || r_mss_tran_type.lookup_code
                                     || '-'
                                     || r_wf_notif_att.notification_id
                                     || '-'
                                     || r_wf_notif_att.NAME
                                     || '-'
                                     || SQLERRM
                                    );
                           END;
                        WHEN OTHERS
                        THEN
                           fnd_file.put_line
                                   (fnd_file.LOG,
                                       'Errored out of r_wf_notif_att loop -'
                                    || r_mss_tran_type.lookup_code
                                    || '-'
                                    || r_wf_notif_att.notification_id
                                    || '-'
                                    || r_wf_notif_att.NAME
                                    || '-'
                                    || SQLERRM
                                   );
                     END;
                  END LOOP;
               END LOOP;
            END LOOP;
         END LOOP;

         COMMIT;
         fnd_file.put_line (fnd_file.output,
                            'NO OF ROWS INSERTED INTO ARCHIVE TABLES'
                           );
         fnd_file.put_line (fnd_file.output,
		 	'No of Rows Inserted Into cust.ttec_wf_items :' 

 
                            || l_cnt_num1
                           );
         fnd_file.put_line
                  (fnd_file.output,
				  		 'No of Rows Inserted Into cust.ttec_wf_item_acty_stat :'
              
                   || l_cnt_num2
                  );
         fnd_file.put_line
                 (fnd_file.output,
				 		'No of Rows Inserted Into cust.ttec_wf_item_att_values :'
                    

                  || l_cnt_num3
                 );
         fnd_file.put_line
                   (fnd_file.output,
				   		'No of Rows Inserted Into cust.ttec_wf_notifications :'
                 
                    || l_cnt_num4
                   );
         fnd_file.put_line
                       (fnd_file.output,
					   
                           'No of Rows Inserted Into cust.ttec_wf_notif_att :'

                        || l_cnt_num5
                       );
      EXCEPTION
         WHEN OTHERS
         THEN
            ROLLBACK;
            fnd_file.put_line
                 (fnd_file.LOG,
                     'Errored out during inserting data into custom tables -'
                  || SQLERRM
                 );
      END;
   EXCEPTION
      WHEN OTHERS
      THEN
         ROLLBACK;
         fnd_file.put_line (fnd_file.LOG,
                            'Errored out of main proc -' || SQLERRM
                           );
   END main_proc;
END ttec_hr_hrssa_trans_pkg;
/
show errors;
/