/************************************************************************************
        Program Name:  TELTEC_CUSTOM_WF_UTILITY

       Modification Log
       Name                  Version #    Date            Description
       -----                 --------     -----           -------------
    IXPRAVEEN(ARGANO)            1.0     15-May-2023     R12.2 Upgrade Remediation
    ****************************************************************************************/
create or replace PACKAGE BODY teltec_custom_wf_utility
AS
-- XCELICOR Custom objects
-- Mark Mestetskiy
-- 10-Aug-06
-- 7-Dev-06 -  Implementing location change identification for HR approver  #1101
-- 3-Jan-2007 Grade changes key : ------  mark   01032007
-- Sept 2007 Michelle Dodge  added sort by
-- October 12 2007   Wasim Manasfi  -- consolidated code between two versions. Changed JMMASTERS to BLROYBAL for role per Brandy
----------------------------------------------------------
   g_cnt   NUMBER := 1;

   PROCEDURE mydebug (msg VARCHAR2)
   IS
      PRAGMA AUTONOMOUS_TRANSACTION;
   BEGIN
--  INSERT INTO MM VALUES(msg,SYSDATE,g_cnt);
--  g_cnt := g_cnt + 1;
--  COMMIT;
      NULL;
--dbms_output.put_line(msg);
   END;

----------------------------------------------------------
   PROCEDURE computetimeout (
      p_item_type   IN              VARCHAR2,
      p_item_key    IN              VARCHAR2,
      p_act_id      IN              NUMBER,
      funmode       IN              VARCHAR2,
      RESULT        OUT NOCOPY      VARCHAR2
   )
   IS
      v_number           NUMBER;
      v_varchar          VARCHAR2 (200);
      v_dynamictimeout   NUMBER;
      v_delay            NUMBER;
      v_defaulttimeout   NUMBER;
      v_date             DATE;
      v_currentdate      DATE           := SYSDATE;
      v_startdate        DATE           := v_currentdate;
      v_off              NUMBER         := 0;
      v_factor           NUMBER         := 0;
   BEGIN
--     TTEC_DYNAMIC_TIMEOUT

      -- v_currentDate:=sysdate;
-- v_startDate:=v_currentDate;

      --dbms_output.put(' Start '||v_currentDate||'-'||to_char(v_currentDate,'DAY'));
      v_defaulttimeout := fnd_profile.VALUE ('TELETECH_DEFAULT_TIMEOUT');
      -- v_off := nvl(fnd_profile.value('TEST_ONLY_DAYS_COUNTER'),0);
      v_off := 0;
      v_currentdate := v_currentdate + v_off;
      v_startdate := v_currentdate;
      v_defaulttimeout := NVL (v_defaulttimeout, 2);

      SELECT TRIM (TO_CHAR (v_currentdate, 'DAY'))
        INTO v_varchar
        FROM DUAL;

      v_factor := 1;

      IF v_varchar IN ('SUNDAY', 'SATURDAY')
      THEN
         v_startdate := NEXT_DAY (v_currentdate, 'Monday');
         v_factor := 0;
      END IF;

      SELECT TRIM (TO_CHAR (v_startdate + v_defaulttimeout, 'DAY'))
        INTO v_varchar
        FROM DUAL;

      IF v_varchar IN ('SUNDAY', 'SATURDAY')
      THEN
         v_delay := 2 + v_defaulttimeout;
      ELSE
         v_delay := v_defaulttimeout;
      END IF;

      v_currentdate := v_startdate + v_delay;
      v_date := TRUNC (v_currentdate + 1 * v_factor);
      --  v_Date := sysdate+v_delay;
      v_number := ROUND ((v_date - SYSDATE) * 24 * 60, 2);
      DBMS_OUTPUT.put_line (TO_CHAR (v_date, 'DD-MON-YY HH24:MI:SS'));
      hr_approval_wf.create_item_attrib_if_notexist
                                         (p_item_type      => p_item_type,
                                          p_item_key       => p_item_key,
                                          p_name           => 'TELETECH_DYNAMIC_TIMEOUT'
                                         );
      wf_engine.setitemattrnumber (itemtype      => p_item_type,
                                   itemkey       => p_item_key,
                                   aname         => 'TELETECH_DYNAMIC_TIMEOUT',
                                   avalue        => v_number
                                  );
      RESULT := 'COMPLETE:Y';
   EXCEPTION
      WHEN OTHERS
      THEN
         mydebug (   'TIMEOUT - '
                  || v_defaulttimeout
                  || '-'
                  || v_varchar
                  || '-'
                  || v_delay
                 );
   END;

-----------------------------------------------------------------------
   FUNCTION getnumtransactionvaluefromitem (
      p_item_key   VARCHAR2,
      p_name       VARCHAR2
   )
      RETURN NUMBER
   IS
      retvalue       NUMBER;
      p_calledfrom   VARCHAR2 (100);
      v_count        NUMBER         := 0;
   BEGIN
      mydebug ('getNumTransactionValueFromItem ' || p_item_key || ' '
               || p_name
              );
      p_calledfrom :=
         wf_engine.getitemattrtext (itemtype      => 'HRSSA',
                                    itemkey       => p_item_key,
                                    aname         => 'P_CALLED_FROM'
                                   );

-- select count(1) -
-- into v_count
-- from hr_api_transaction_steps where item_type ='HRSSA' and item_key = p_item_key;
      SELECT number_value
        INTO retvalue
        FROM hr_api_transaction_values
       WHERE transaction_step_id IN (
                           SELECT transaction_step_id
                             FROM hr_api_transaction_steps
                            WHERE item_type = 'HRSSA'
                                  AND item_key = p_item_key)
         AND NAME = p_name
         AND ROWNUM < 2;

      mydebug (   'getNumTransactionValueFromItem '
               || p_item_key
               || ' '
               || p_name
               || '-'
               || retvalue
              );
      RETURN retvalue;
   EXCEPTION
      WHEN OTHERS
      THEN
         mydebug (   p_item_key
                  || ' Exception in getNumtransactionvaluefromitem '
                  || p_calledfrom
                  || ' '
                  || SUBSTR (SQLERRM, 1, 200)
                 );
         RETURN NULL;
   END getnumtransactionvaluefromitem;

----------------------------------------------------------
   FUNCTION getdatetransvalue (p_item_key VARCHAR2, p_name VARCHAR2)
      RETURN DATE
   IS
      retvalue       DATE;
      p_calledfrom   VARCHAR2 (100);
   BEGIN
      p_calledfrom :=
         wf_engine.getitemattrtext (itemtype      => 'HRSSA',
                                    itemkey       => p_item_key,
                                    aname         => 'P_CALLED_FROM'
                                   );

      SELECT date_value
        INTO retvalue
        FROM hr_api_transaction_values
       WHERE transaction_step_id IN (
                           SELECT transaction_step_id
                             FROM hr_api_transaction_steps
                            WHERE item_type = 'HRSSA'
                                  AND item_key = p_item_key)
         AND NAME = p_name
         AND ROWNUM < 2;

      RETURN retvalue;
   EXCEPTION
      WHEN OTHERS
      THEN
         RETURN NULL;
   END getdatetransvalue;

-----------------------------------------------------------------------
----------------------------------------------------------
   FUNCTION getoriginaldatetransvalue (p_item_key VARCHAR2, p_name VARCHAR2)
      RETURN DATE
   IS
      retvalue       DATE;
      p_calledfrom   VARCHAR2 (100);
   BEGIN
      p_calledfrom :=
         wf_engine.getitemattrtext (itemtype      => 'HRSSA',
                                    itemkey       => p_item_key,
                                    aname         => 'P_CALLED_FROM'
                                   );

      SELECT original_date_value
        INTO retvalue
        FROM hr_api_transaction_values
       WHERE transaction_step_id IN (
                           SELECT transaction_step_id
                             FROM hr_api_transaction_steps
                            WHERE item_type = 'HRSSA'
                                  AND item_key = p_item_key)
         AND NAME = p_name
         AND ROWNUM < 2;

      RETURN retvalue;
   EXCEPTION
      WHEN OTHERS
      THEN
         RETURN NULL;
   END getoriginaldatetransvalue;

-----------------------------------------------------------------------
   FUNCTION getusernamefromuserid (p_user_id NUMBER)
      RETURN VARCHAR2
   IS
      retvalue   VARCHAR2 (50);
   BEGIN
      SELECT user_name
        INTO retvalue
        FROM fnd_user
       WHERE SYSDATE < NVL (end_date, SYSDATE + 1) AND user_id = p_user_id;

      RETURN retvalue;
   EXCEPTION
      WHEN OTHERS
      THEN
         RETURN NULL;
   END;

----------------------------------------------------------
-- Mod By: Michelle Dodge   Mod Date: 18-Jan-2007
-- Description: Added Order by clause to force the 'EXMIDPT'
-- value to always sort to the bottom.
--
----------------------------------------------------------
   PROCEDURE getlookupvalues (
      p_lookuptable   IN OUT   lookuprecord_tabletype,
      p_lookup_type            fnd_lookup_values.lookup_type%TYPE
   )
   IS
      ilookupcount     NUMBER            := 0;
      v_lookuprecord   lookuprecord_type;
   BEGIN
      FOR c IN (SELECT UNIQUE lookup_code, meaning, description
                         FROM fnd_lookup_values
                        WHERE lookup_type = p_lookup_type
                          AND SYSDATE BETWEEN start_date_active
                                          AND NVL (end_date_active,
                                                   SYSDATE + 1
                                                  )
                     ORDER BY lookup_code)
      LOOP
         ilookupcount := ilookupcount + 1;
         v_lookuprecord.lookup_code := c.lookup_code;
         v_lookuprecord.meaning := c.meaning;
         v_lookuprecord.description := c.description;
         p_lookuptable (ilookupcount) := v_lookuprecord;
      END LOOP;
   END getlookupvalues;

--------------------------------------------------------------------
   PROCEDURE setupapproverrole (
      p_item_type   IN              VARCHAR2,
      p_item_key    IN              VARCHAR2,
      p_act_id      IN              NUMBER,
      funmode       IN              VARCHAR2,
      RESULT        OUT NOCOPY      VARCHAR2
   )
   IS
      v_number            NUMBER;
      v_varchar           VARCHAR2 (200);
      v_approvallevel     VARCHAR2 (20);
      v_usersarray        v_t_type;

      CURSOR getapprovers_c (p_key VARCHAR2)
      IS
         SELECT VALUE
           FROM ttec_temp_wf
          WHERE item_type = p_item_type
            AND item_key = p_item_key
            AND KEY = p_key;

      v_tempstring        VARCHAR2 (500) := '';
      v_rolename          VARCHAR2 (100);
      v_roledescription   VARCHAR2 (100);
      v_initialapprover   NUMBER;
      vgetinitial         BOOLEAN        := FALSE;
      v_username          VARCHAR2 (100);
      v_t                 v_t_type;
      v_submitterid       NUMBER;
   BEGIN
      v_number :=
         wf_engine.getitemattrnumber (itemtype      => p_item_type,
                                      itemkey       => p_item_key,
                                      aname         => 'TTEC_HR_APPROVAL_LEVEL'
                                     );
      v_submitterid :=
         wf_engine.getitemattrnumber (itemtype      => p_item_type,
                                      itemkey       => p_item_key,
                                      aname         => 'CREATOR_PERSON_ID'
                                     );
      v_approvallevel := 'APPROVAL' || TO_CHAR (v_number);
      mydebug ('APproval level :' || v_approvallevel || '<');

      FOR c IN getapprovers_c (v_approvallevel)
      LOOP
         v_username := '';

         BEGIN
            SELECT user_name
              INTO v_username
              FROM fnd_user
             WHERE user_id = c.VALUE AND NVL (end_date, SYSDATE + 1) > SYSDATE;
         EXCEPTION
            WHEN OTHERS
            THEN
               NULL;
         END;

         v_tempstring := v_tempstring || v_username || ',';

         IF vgetinitial = FALSE
         THEN
            v_initialapprover := c.VALUE;
            vgetinitial := TRUE;
         END IF;
      END LOOP;

      v_tempstring := RTRIM (v_tempstring, ',');
      v_t := getstrings (v_tempstring, ',');
      mydebug ('SetUPROle : Approver :' || v_tempstring || '<');

-- Fix this

      --  if trim(G_hcm_role_description)=null Then @@@
      IF g_hcm_role_description = NULL
      THEN
         g_hcm_role_description := 'HCM Approver Role ';
      END IF;

      IF g_locationname = NULL
      THEN
         g_locationname := getlocationname (getlocationid (v_submitterid));

         IF LENGTH (TRIM (g_locationname)) = 0
         THEN
            g_locationname :=
                           getlocationnamepid (getlocationid (v_submitterid));
         END IF;
      END IF;

      g_hcm_role_description := gethcmroledescription (p_item_key);

      IF TRIM (LENGTH (g_locationname)) = 0
      THEN
         g_locationname := getlocationnamepid (v_submitterid);
      END IF;

      v_roledescription :=
            g_hcm_role_description
         || '('
         || g_locationname
         || '-'
         || p_item_key
         || ')';

      IF v_t.COUNT > 1
      THEN
         wf_directory.createadhocrole
            (v_rolename,                   --          in out nocopy varchar2,
             v_roledescription,              --       in out nocopy  varchar2,
             NULL,        --language                in  varchar2 default null,
             NULL,        --territory               in  varchar2 default null,
             NULL,        --role_description        in  varchar2 default null,
             'MAILHTML',
                     --notification_preference in varchar2 default 'MAILHTML',
             v_tempstring,
                          --role_users              in  varchar2 default null,
             NULL,        --email_address           in  varchar2 default null,
             NULL,        --fax                     in  varchar2 default null,
             'ACTIVE',
                      --status                  in  varchar2 default 'ACTIVE',
             TRUNC (SYSDATE) + 14,
                              --expiration_date         in  date default null,
             NULL,        -- parent_orig_system      in varchar2 default null,
             NULL,          -- parent_orig_system_id   in number default null,
             NULL          --owner_tag               in  varchar2 default null
            );
      ELSE
         v_rolename := v_tempstring;
      END IF;

      hr_approval_wf.create_item_attrib_if_notexist
                                          (p_item_type      => p_item_type,
                                           p_item_key       => p_item_key,
                                           p_name           => 'TTEC_HR_LOCAL_APPROVALS'
                                          );
/*
      select user_name,employee_id
      into v_varchar,v_number
      from fnd_user
      where user_id = v_initialApprover
      and sysdate < nvl(end_date,sysdate+1)
      and rownum < 2;
*/
      mydebug ('Setup Role ' || v_rolename);
      wf_engine.setitemattrtext (itemtype      => p_item_type,
                                 itemkey       => p_item_key,
                                 aname         => 'TTEC_HR_LOCAL_APPROVALS',
                                 avalue        => v_rolename
                                );
      RESULT := 'COMPLETE:Y';
   EXCEPTION
      WHEN OTHERS
      THEN
         v_varchar := SUBSTR (SQLERRM, 1, 200);
         mydebug ('EXCEPTION IN SETROLE ' || v_varchar);
   END;

--------------------------------------------------------------------
   PROCEDURE increaseapprovallevel (
      p_item_type   IN              VARCHAR2,
      p_item_key    IN              VARCHAR2,
      p_act_id      IN              NUMBER,
      funmode       IN              VARCHAR2,
      RESULT        OUT NOCOPY      VARCHAR2
   )
   IS
      v_number         NUMBER;
      v_varchar        VARCHAR2 (200);
      v_tempnumber     NUMBER         := 0;
      v_process_name   VARCHAR2 (100);
   BEGIN
      v_number :=
         wf_engine.getitemattrnumber (itemtype      => p_item_type,
                                      itemkey       => p_item_key,
                                      aname         => 'TTEC_HR_APPROVAL_LEVEL'
                                     );

      IF NVL (v_number, -1) = -1
      THEN
         v_number := 0;
      END IF;

      v_process_name :=
         wf_engine.getitemattrtext (itemtype      => p_item_type,
                                    itemkey       => p_item_key,
                                    aname         => 'PROCESS_NAME'
                                   );

-- verify that there is higher level
      SELECT MAX (KEY)
        INTO v_varchar
        FROM ttec_temp_wf
       WHERE item_type = p_item_type AND item_key = p_item_key;

      v_tempnumber := TO_NUMBER (LTRIM (v_varchar, 'APPROVAL'));
      v_number := v_number + 1;

      IF v_number <= v_tempnumber
      THEN
         NULL;
      ELSE
         IF v_process_name LIKE '%TERMINATION%'
         THEN
            NULL;
         ELSE
            v_number := v_number - 1;
         END IF;
      END IF;

      wf_engine.setitemattrnumber (itemtype      => p_item_type,
                                   itemkey       => p_item_key,
                                   aname         => 'TTEC_HR_APPROVAL_LEVEL',
                                   avalue        => v_number
                                  );
      RESULT := 'COMPLETE:Y';
   END;

--------------------------------------------------------------------
   PROCEDURE setinitialapprover (
      p_item_type   IN              VARCHAR2,
      p_item_key    IN              VARCHAR2,
      p_act_id      IN              NUMBER,
      funmode       IN              VARCHAR2,
      RESULT        OUT NOCOPY      VARCHAR2
   )
   IS
      v_number    NUMBER;
      v_varchar   VARCHAR2 (200);
   BEGIN
      SELECT VALUE
        INTO v_number
        FROM ttec_temp_wf
       WHERE item_type = p_item_type
         AND item_key = p_item_key
         AND KEY = 'APPROVAL1'
         AND ROWNUM < 2;

      SELECT user_name, employee_id
        INTO v_varchar, v_number
        FROM fnd_user
       WHERE user_id = v_number AND NVL (end_date, SYSDATE + 1) > SYSDATE;

      wf_engine.setitemattrtext (itemtype      => p_item_type,
                                 itemkey       => p_item_key,
                                 aname         => 'FORWARD_TO_USERNAME',
                                 avalue        => v_varchar
                                );
      wf_engine.setitemattrnumber (itemtype      => p_item_type,
                                   itemkey       => p_item_key,
                                   aname         => 'FORWARD_TO_PERSON_ID',
                                   avalue        => v_number
                                  );

      SELECT full_name
        INTO v_varchar
        FROM per_all_people_f
       WHERE SYSDATE BETWEEN effective_start_date
                         AND NVL (effective_end_date, SYSDATE + 1)
         AND person_id = v_number;

      wf_engine.setitemattrtext (itemtype      => p_item_type,
                                 itemkey       => p_item_key,
                                 aname         => 'FORWARD_TO_DISPLAY_NAME',
                                 avalue        => v_varchar
                                );
      wf_engine.setitemattrnumber (itemtype      => p_item_type,
                                   itemkey       => p_item_key,
                                   aname         => 'TTEC_HR_APPROVAL_LEVEL',
                                   avalue        => 1
                                  );
      RESULT := 'COMPLETE:Y';
   END;

--------------------------------------------------------------------
   PROCEDURE customglobals (
      p_item_type   IN              VARCHAR2,
      p_item_key    IN              VARCHAR2,
      p_act_id      IN              NUMBER,
      funmode       IN              VARCHAR2,
      RESULT        OUT NOCOPY      VARCHAR2
   )
   IS
   BEGIN
      hr_approval_custom.g_itemtype := p_item_type;
      hr_approval_custom.g_itemkey := p_item_key;
      RESULT := 'COMPLETE:Y';
   END;

-------------------------------------------------------------------
   PROCEDURE findsrhumancapital (
      p_item_type   IN              VARCHAR2,
      p_item_key    IN              VARCHAR2,
      p_act_id      IN              NUMBER,
      funmode       IN              VARCHAR2,
      RESULT        OUT NOCOPY      VARCHAR2
   )
   IS
--p_item_type Varchar2(100) := 'HRSSA';
--p_item_key Varchar2(100) := '393077';
      v_personid          NUMBER;
      v_rolename          VARCHAR2 (50);
      v_roledescription   VARCHAR2 (500);

      CURSOR getapprovers (p_role VARCHAR2)
      IS
         SELECT user_name
           FROM wf_local_user_roles
          WHERE role_name = p_role;

      v_t                 teltec_custom_wf_utility.v_t_type;
      v_t_sr              teltec_custom_wf_utility.v_t_type;
      v_count             NUMBER                            := 0;
      v_employeeid        NUMBER;
      v_addperson         BOOLEAN                           := FALSE;
      v_sr_hc             VARCHAR2 (500);
      v_tempstring        VARCHAR2 (600);
      v_username          VARCHAR2 (100);
      v_number            NUMBER;
      v_varchar           VARCHAR2 (300);
   BEGIN
      v_rolename :=
         wf_engine.getitemattrtext (itemtype      => p_item_type,
                                    itemkey       => p_item_key,
                                    aname         => 'TTEC_HR_LOCAL_APPROVALS'
                                   );

      FOR c IN getapprovers (v_rolename)
      LOOP
         SELECT employee_id
           INTO v_employeeid
           FROM fnd_user
          WHERE user_name = c.user_name
            AND SYSDATE < NVL (end_date, SYSDATE + 1);

         v_sr_hc :=
            teltec_custom_wf_utility.finduserinjobhierarchy ('79071',
                                                             v_employeeid
                                                            );
         v_tempstring := v_tempstring || ',' || v_sr_hc;
      END LOOP;

      v_tempstring := LTRIM (v_tempstring, ',');
      v_tempstring := RTRIM (v_tempstring, ',');
      v_t_sr := teltec_custom_wf_utility.getstrings (v_tempstring, ',');

      FOR v IN 1 .. v_t_sr.LAST
      LOOP
         IF v = 1
         THEN
            v_count := 1;
            v_t (v_count) := v_t_sr (v);
         ELSE
            v_addperson := FALSE;

            FOR v1 IN 1 .. v_t.LAST
            LOOP
               IF v_t (v1) = v_t_sr (v)
               THEN
                  NULL;
               ELSE
                  v_addperson := TRUE;
               END IF;
            END LOOP;

            IF v_addperson = TRUE
            THEN
               v_count := v_count + 1;
               v_t (v_count) := v_t_sr (v);
            END IF;
         END IF;
      END LOOP;

      v_tempstring := '';

      FOR v IN 1 .. v_t.LAST
      LOOP
         --     dbms_output.put_line('Step 1' ||v_t(v));
         IF NVL (v_t (v), '-100') != -100
         THEN
            SELECT user_name
              INTO v_username
              FROM fnd_user
             WHERE user_id = v_t (v) AND SYSDATE < NVL (end_date, SYSDATE + 1);

            v_tempstring := v_tempstring || v_username || ',';
         END IF;
      END LOOP;

      v_tempstring := RTRIM (v_tempstring, ',');
      v_tempstring := RTRIM (v_tempstring, ',');
      v_tempstring := LTRIM (v_tempstring, ',');
      v_t := teltec_custom_wf_utility.getstrings (v_tempstring, ',');
      v_tempstring := v_t (1);

      --                         dbms_output.put_line(v_tempSTring);
      SELECT employee_id
        INTO v_number
        FROM fnd_user
       WHERE user_name = v_tempstring;

      SELECT full_name, person_id
        INTO v_varchar, v_number
        FROM per_all_people_f
       WHERE SYSDATE BETWEEN effective_start_date AND effective_end_date
         AND person_id = v_number;

      --         dbms_output.put_line(v_tempString);
      hr_approval_wf.create_item_attrib_if_notexist
                                          (p_item_type      => p_item_type,
                                           p_item_key       => p_item_key,
                                           p_name           => 'TTEC_HR_LOCAL_APPROVALS'
                                          );
      wf_engine.setitemattrtext (itemtype      => p_item_type,
                                 itemkey       => p_item_key,
                                 aname         => 'TTEC_HR_LOCAL_APPROVALS',
                                 avalue        => v_varchar
                                );
      v_number :=
         wf_engine.getitemattrnumber (itemtype      => p_item_type,
                                      itemkey       => p_item_key,
                                      aname         => 'FORWARD_TO_PERSON_ID'
                                     );
      wf_engine.setitemattrnumber (itemtype      => p_item_type,
                                   itemkey       => p_item_key,
                                   aname         => 'FORWARD_FROM_PERSON_ID',
                                   avalue        => v_number
                                  );
      v_varchar :=
         wf_engine.getitemattrtext (itemtype      => p_item_type,
                                    itemkey       => p_item_key,
                                    aname         => 'FORWARD_TO_USERNAME'
                                   );
      wf_engine.setitemattrtext (itemtype      => p_item_type,
                                 itemkey       => p_item_key,
                                 aname         => 'FORWARD_FROM_USERNAME',
                                 avalue        => v_varchar
                                );
      v_varchar :=
         wf_engine.getitemattrtext (itemtype      => p_item_type,
                                    itemkey       => p_item_key,
                                    aname         => 'FORWARD_TO_DISPLAY_NAME'
                                   );
      wf_engine.setitemattrtext (itemtype      => p_item_type,
                                 itemkey       => p_item_key,
                                 aname         => 'FORWARD_FROM_DISPLAY_NAME',
                                 avalue        => v_varchar
                                );
      wf_engine.setitemattrtext (itemtype      => p_item_type,
                                 itemkey       => p_item_key,
                                 aname         => 'FORWARD_TO_DISPLAY_NAME',
                                 avalue        => v_varchar
                                );
      wf_engine.setitemattrtext (itemtype      => p_item_type,
                                 itemkey       => p_item_key,
                                 aname         => 'FORWARD_TO_PERSON_ID',
                                 avalue        => v_number
                                );
      RESULT := 'COMPLETE:Y';
   EXCEPTION
      WHEN OTHERS
      THEN
         RESULT := 'COMPLETE:N';
   END findsrhumancapital;

-------------------------------------------------------------------
   FUNCTION finduserinjobhierarchy (p_job_code VARCHAR2, p_person_id NUMBER)
      RETURN VARCHAR2
   IS
      CURSOR getuserid (v_job VARCHAR2, v_person_id NUMBER)
      IS
         SELECT user_id, user_name
           FROM fnd_user f, per_jobs j, per_assignments_x a
          WHERE a.person_id IN (
                   SELECT     person_id
                         FROM per_assignments_x asg
                        WHERE asg.supervisor_id IS NOT NULL
                          AND SYSDATE BETWEEN effective_start_date
                                          AND effective_end_date
                   START WITH asg.person_id = p_person_id             --248637
                   CONNECT BY PRIOR asg.supervisor_id = asg.person_id)
            AND SYSDATE BETWEEN a.effective_start_date AND a.effective_end_date
            AND j.job_id = a.job_id
            AND j.NAME LIKE TRIM (p_job_code) || '.%'
            AND f.employee_id = a.person_id
            AND NVL (end_date, SYSDATE + 1) > SYSDATE;

      retline   VARCHAR2 (500) := '';
   BEGIN
      mydebug (   'Find user In Job Hierarchy for '
               || p_person_id
               || '-'
               || p_job_code
              );

      FOR c IN getuserid (p_job_code, p_person_id)
      LOOP
         retline := retline || c.user_id || ',';
      END LOOP;

      mydebug ('User InJob ' || retline || '<' || LENGTH (NVL (retline, ' ')));

      IF LENGTH (NVL (retline, ' ')) < 3
      THEN
         mydebug (   'Not found in job User In Job '
                  || p_person_id
                  || '-'
                  || p_job_code
                 );
         retline := finduserinlocation (p_job_code, p_person_id);
         mydebug (   'May be found in job User In Location '
                  || p_person_id
                  || '-'
                  || p_job_code
                  || '-'
                  || retline
                  || '<'
                 );
      END IF;

      mydebug ('FindUserinJobJier :' || retline || '<');
      RETURN retline;
   END finduserinjobhierarchy;

-------------------------------------------------------------------
   FUNCTION findocinjobhierarchy (p_person_id NUMBER)
      RETURN VARCHAR2
   IS
      CURSOR getuserid (v_person_id NUMBER)
      IS
         SELECT user_id, user_name
           FROM fnd_user f, per_jobs j, per_assignments_x a
          WHERE a.person_id IN (
                   SELECT     person_id
                         FROM per_assignments_x asg
                        WHERE asg.supervisor_id IS NOT NULL
                          AND SYSDATE BETWEEN effective_start_date
                                          AND effective_end_date
                   START WITH asg.person_id = v_person_id
                   CONNECT BY PRIOR asg.supervisor_id = asg.person_id)
            AND SYSDATE BETWEEN a.effective_start_date AND a.effective_end_date
            AND j.job_id = a.job_id
            AND j.attribute6 LIKE 'Operating Comm%'
            AND f.employee_id = a.person_id
            AND NVL (end_date, SYSDATE + 1) > SYSDATE;

      retline   VARCHAR2 (500) := '';
   BEGIN
      mydebug ('Find user In Job Hierarchy for ' || p_person_id);

      FOR c IN getuserid (p_person_id)
      LOOP
         retline := retline || c.user_id || ',';
      END LOOP;

      mydebug ('User InJob ' || retline || '<' || LENGTH (NVL (retline, ' ')));
      mydebug ('FindOCinJobJier :' || retline || '<');
      RETURN retline;
   END findocinjobhierarchy;

-------------------------------------------------------------------
   FUNCTION finduserinlocation (p_job_code VARCHAR2, p_person_id NUMBER)
      RETURN VARCHAR2
   IS
      CURSOR getuserid (v_job VARCHAR2, v_person_id NUMBER)
      IS
         SELECT user_id, user_name, employee_id
           FROM fnd_user f
          WHERE employee_id IN (
                   SELECT a.person_id
                     FROM per_assignments_x a,
                          per_jobs j,
                          per_assignment_status_types pass
                    WHERE SYSDATE BETWEEN a.effective_start_date
                                      AND NVL (a.effective_end_date,
                                               SYSDATE + 1
                                              )
                      AND a.location_id = (SELECT location_id
                                             FROM per_assignments_x
                                            WHERE person_id = p_person_id)
                      AND a.job_id = j.job_id
                      AND pass.user_status = 'ACTIVE ASSGNMENT'
                      AND pass.assignment_status_type_id =
                                                   a.assignment_status_type_id
                      AND j.NAME LIKE p_job_code || '.%')
            AND NVL (end_date, SYSDATE + 1) > SYSDATE;

      retline   VARCHAR2 (500) := '';
   BEGIN
      mydebug ('Find User in Location ' || p_job_code || '-' || p_person_id);

      FOR c IN getuserid (p_job_code, p_person_id)
      LOOP
         retline := retline || c.user_id || ',';
      END LOOP;

      mydebug (   'Founf User in Location '
               || p_job_code
               || '-'
               || p_person_id
               || '-'
               || retline
              );
      RETURN retline;
   END finduserinlocation;

----------------------------------------------------------
-------------------------------------------------------------------
   FUNCTION finduserinmgrlevelhierarchy (
      p_job_code    VARCHAR2,
      p_person_id   NUMBER
   )
      RETURN VARCHAR2
   IS
      CURSOR getuserid (v_job VARCHAR2, v_person_id NUMBER)
      IS
         SELECT user_id, user_name
           FROM fnd_user f, per_jobs j, per_assignments_x a
          WHERE a.person_id IN (
                   SELECT     person_id
                         FROM per_assignments_x asg
                        WHERE asg.supervisor_id IS NOT NULL
                          AND SYSDATE BETWEEN effective_start_date
                                          AND effective_end_date
                   START WITH asg.person_id = p_person_id             --248637
                   CONNECT BY PRIOR asg.supervisor_id = asg.person_id)
            AND SYSDATE BETWEEN a.effective_start_date AND a.effective_end_date
            AND j.job_id = a.job_id
            AND TRIM (j.attribute6) = p_job_code
            AND f.employee_id = a.person_id
            AND NVL (end_date, SYSDATE + 1) > SYSDATE;

      CURSOR get_approval_lookup (p_lookup_code IN VARCHAR2)
      IS
         SELECT meaning
           FROM fnd_lookup_values
          WHERE lookup_type = 'TTEC_WF_APPROVALS'
            AND lookup_code = p_lookup_code
            AND enabled_flag = 'Y'
            AND SYSDATE BETWEEN start_date_active
                            AND NVL (end_date_active, SYSDATE + 1);

      retline           VARCHAR2 (500) := '';
      v_locationid      VARCHAR2 (100);
      v_location_code   VARCHAR2 (200);
      v_corplocations   VARCHAR2 (100)
                             := fnd_profile.VALUE ('TTEC_CORPORATE_LOCATIONS');
      v_users           VARCHAR2 (100);
   BEGIN
      mydebug (' Find job ' || p_job_code || ' ' || p_person_id);

      FOR c IN getuserid (p_job_code, p_person_id)
      LOOP
         retline := retline || c.user_name || ',';
      END LOOP;

-- mark 1201
      v_locationid := getlocationid (p_person_id);
      v_location_code := getlocationname (v_locationid);

      IF v_location_code LIKE '%At Home%'
      THEN
         OPEN get_approval_lookup ('AT HOME');

         FETCH get_approval_lookup
          INTO v_users;

         CLOSE get_approval_lookup;
      ELSIF INSTR (v_corplocations, ':' || v_locationid || ':') > 0
      THEN
         OPEN get_approval_lookup ('CORP');

         FETCH get_approval_lookup
          INTO v_users;

         CLOSE get_approval_lookup;
      --v_users := 'MXDEACON'; --Maggy Deacon  --'DEKOELLING'; -- demetra
      ELSE
         OPEN get_approval_lookup ('SITE');

         FETCH get_approval_lookup
          INTO v_users;

         CLOSE get_approval_lookup;
      --v_users := 'TMHINDS';  -- Tim Hinds  --'KIHUGHES'; -- Kelly
      END IF;

      mydebug (   'RetLine='
               || retline
               || ' '
               || v_locationid
               || ' '
               || v_corplocations
              );

      IF NVL (REPLACE (retline, ','), 'X') = 'X'
      THEN
         retline := v_users;
      ELSE
         retline := RTRIM (retline, ',');
      END IF;

      RETURN retline;
   END finduserinmgrlevelhierarchy;

----------------------------------------------------------
   FUNCTION getstrings (p_items VARCHAR2, p_delimiter VARCHAR2)
      RETURN v_t_type
   IS
      v_vartab_i   v_t_type;
      tempstring   VARCHAR2 (16000);
      i            BINARY_INTEGER   := 1;
      i_s          NUMBER;
      i_e          NUMBER;
      i_sp         NUMBER;
      i_ep         NUMBER           := 1;
--add Varchar2(100);
      t_items      VARCHAR2 (16000);
   BEGIN
      t_items := RTRIM (p_items, p_delimiter);
      t_items := t_items || p_delimiter;
      i_s := 1;
      tempstring := SUBSTR (t_items, i_s);
      i := 1;

      WHILE i_ep > 0
      LOOP
         i_ep := INSTR (tempstring, p_delimiter, i_s);

         IF i_ep > 0
         THEN
            IF i_ep - i_s = 0
            THEN
               v_vartab_i (i) := NULL;
            ELSE
               v_vartab_i (i) := SUBSTR (tempstring, i_s, i_ep - i_s);
            END IF;

            i := i + 1;
            tempstring := SUBSTR (tempstring, i_ep + LENGTH (p_delimiter));
         END IF;
      END LOOP;

      RETURN v_vartab_i;
   EXCEPTION
      WHEN OTHERS
      THEN
         NULL;
   END getstrings;

-----------------------------------------------------------
-----------------------------------------------------------
   FUNCTION findnextpersonorgroup (p_item_type VARCHAR2, p_item_key VARCHAR2)
      RETURN VARCHAR2
   IS
      retvalue                VARCHAR2 (50);
      v_location              VARCHAR2 (50);
      --v_department            hr.pay_cost_allocation_keyflex.segment3%TYPE;						-- Commented code by IXPRAVEEN-ARGANO,15-May-2023
      v_department            apps.pay_cost_allocation_keyflex.segment3%TYPE;                         --  code Added by IXPRAVEEN-ARGANO,   15-May-2023
      v_lr                    lookuprecord_type;
      v_country               VARCHAR2 (30);
      v_meaning               fnd_lookup_values.meaning%TYPE;
      v_lookupcode            fnd_lookup_values.lookup_code%TYPE;
      v_description           fnd_lookup_values.description%TYPE;
      v_recordidentified      BOOLEAN                                := FALSE;

      TYPE temptabletype IS TABLE OF VARCHAR2 (100)
         INDEX BY BINARY_INTEGER;

      temptable               temptabletype;
      meaningtable            temptabletype;
      descriptiontable        temptabletype;
      v_temptable             v_t_type;
      v_hierarchy             VARCHAR2 (200);
      v_responsibility        BOOLEAN                                := FALSE;
      v_corpresponsibility    BOOLEAN                                := FALSE;
      v_localresponsibility   BOOLEAN                                := FALSE;
      v_job_code              BOOLEAN                                := FALSE;
      v_supervisor            BOOLEAN                                := FALSE;
      v_jobcodevalue          VARCHAR2 (50);
      v_responsibilityvalue   VARCHAR2 (50);
      v_approversstring       VARCHAR2 (1000);
      v_attributeroutevalue   VARCHAR2 (100)                            := '';
      v_lookuprecord          teltec_custom_wf_utility.lookuprecord_type;
      lookuprecord_table      lookuprecord_tabletype;
      ilookupcount            NUMBER                                     := 0;
      v_personid              NUMBER;
      p_person_id             NUMBER;
      v_supervisorid          NUMBER;
      v_supervisorusername    VARCHAR2 (50);
      v_locationname          VARCHAR2 (100);
      v_corplocations         VARCHAR2 (100)
                            := fnd_profile.VALUE ('TTEC_CORPORATE_LOCATIONS');
   BEGIN
      mydebug ('Start 1');
      v_personid :=
         wf_engine.getitemattrnumber (itemtype      => p_item_type,
                                      itemkey       => p_item_key,
                                      aname         => 'CREATOR_PERSON_ID'
                                     );
      p_person_id := v_personid;
      getlookupvalues (lookuprecord_table, 'TTEC_WORKFLOW_HCM_APPROVER_RSP');
      v_department := getdepartmentnumber (p_person_id);
      --v_location   := getPersonLocationCode(p_person_id);   -- Mark011607
      v_location := getlocationid (p_person_id);

-- #1101 MarkM
      IF INSTR (v_corplocations, ':' || v_location || ':') > 0
      THEN
         NULL;
      ELSE
         IF g_islocationchanged = TRUE
         THEN
            v_location := g_newlocationid;
         END IF;
      END IF;

-- #1101 MarkM
      BEGIN
         g_locationname := getlocationname (v_location);
      EXCEPTION
         WHEN OTHERS
         THEN
            g_locationname := v_location;
      END;

      --   G_locationName := v_location;
      temptable (1) := TRIM (v_location) || ':' || TRIM (v_department);
      temptable (2) := '*:' || TRIM (v_department);
      temptable (3) := TRIM (v_location) || ':*';
      temptable (4) := '*:*';
      temptable (5) := '*';
      meaningtable (1) := '';
      meaningtable (2) := '';
      meaningtable (3) := '';
      meaningtable (4) := '';
      meaningtable (5) := '';
      descriptiontable (1) := '';
      descriptiontable (2) := '';
      descriptiontable (3) := '';
      descriptiontable (4) := '';
      descriptiontable (5) := '';
      mydebug ('Step 1');
      v_country := getcountry (p_person_id);

-- identify the record from lookup
      FOR j IN lookuprecord_table.FIRST .. lookuprecord_table.LAST
      LOOP
         v_lr := lookuprecord_table (j);

         FOR k IN 1 .. temptable.LAST
         LOOP
            mydebug ('D1:=' || v_lr.lookup_code);

            IF v_lr.lookup_code = temptable (k)
            THEN
               mydebug ('Found:' || v_lr.lookup_code || ' ' || v_lr.meaning);
               meaningtable (k) := v_lr.meaning;
               descriptiontable (k) := v_lr.description;
            END IF;
         END LOOP;
      END LOOP;

      -- define the approvers chain
      FOR k IN 1 .. meaningtable.LAST
      LOOP
         mydebug (k || '-' || meaningtable (k));

         IF LENGTH (meaningtable (k)) > 0
         THEN
            mydebug ('Hir=' || meaningtable (k));
            v_hierarchy := meaningtable (k);
            g_hcm_role_description := descriptiontable (k);
            EXIT;
         END IF;
      END LOOP;

      --
      mydebug ('Result=' || v_hierarchy);

      IF UPPER (TRIM (v_hierarchy)) LIKE 'JOB_CODE%'
      THEN
         v_job_code := TRUE;
         v_attributeroutevalue := 'JOB_CODE:';                 --v_hierarchy;
      ELSIF UPPER (TRIM (v_hierarchy)) LIKE 'SUPV%'
      THEN
         v_supervisor := TRUE;
         v_attributeroutevalue := 'SUPERVISOR:';
      ELSIF UPPER (TRIM (v_hierarchy)) LIKE 'GLOBAL%:%'
      THEN
         v_corpresponsibility := TRUE;
      ELSIF UPPER (TRIM (v_hierarchy)) LIKE 'LOCAL%:%'
      THEN
         v_localresponsibility := TRUE;
      END IF;

--
      IF v_supervisor = TRUE
      THEN
         mydebug ('Start looking for supervisor for ' || p_person_id);
         v_supervisorid := getsupervisorpersonid (p_person_id);
         mydebug (   'Found supervisor Personid  for '
                  || p_person_id
                  || ' ->'
                  || v_supervisorid
                 );
         v_supervisorid := getsupervisoruser (v_supervisorid);
         mydebug ('Found supervisor User  ' || ' ->' || v_supervisorid);
         v_supervisorusername := getusernamefromuserid (v_supervisorid);
         v_approversstring := v_supervisorid;
         mydebug (   'Supervisor true :'
                  || v_supervisorid
                  || ' :'
                  || v_supervisorusername
                  || ' :'
                  || v_approversstring
                 );
      END IF;

      IF v_job_code = TRUE
      THEN
         v_jobcodevalue := SUBSTR (v_hierarchy, INSTR (v_hierarchy, ':') + 1);
         v_approversstring :=
                         finduserinjobhierarchy (v_jobcodevalue, p_person_id);
      END IF;

---------------------------------------------------------------------------
      IF v_corpresponsibility = TRUE OR v_localresponsibility = TRUE
      THEN
         mydebug ('resp=true ' || v_hierarchy);
         v_responsibilityvalue :=
                            SUBSTR (v_hierarchy, INSTR (v_hierarchy, ':') + 1);
         v_responsibilityvalue :=
                      REPLACE (v_responsibilityvalue, '##COUNTRY', v_country);
         mydebug (v_responsibilityvalue);
         v_attributeroutevalue := 'RESPONSIBILITY:';
                                                   --||v_responsibilityValue;

         IF v_corpresponsibility = TRUE
         THEN
            v_approversstring :=
                      ttec_adhoc_hr_corp (p_person_id, v_responsibilityvalue);
         ELSIF v_localresponsibility = TRUE
         THEN
            v_approversstring :=
                     ttec_adhoc_hr_local (p_person_id, v_responsibilityvalue);
         END IF;
      END IF;

----------------------------------------------------------------------------
      v_temptable := getstrings (v_approversstring, ',');

      DELETE FROM ttec_temp_wf t
            WHERE t.item_type = p_item_type AND t.item_key = p_item_key;

      FOR k IN 1 .. v_temptable.LAST
      LOOP
         IF LENGTH (v_temptable (k)) > 0
         THEN
            INSERT INTO ttec_temp_wf
                        (item_type, item_key, VALUE, line_number,
                         KEY, description
                        )
                 VALUES (p_item_type, p_item_key, v_temptable (k), k,
                         'APPROVAL1', g_hcm_role_description
                        );
         END IF;
      END LOOP;

      RETURN v_attributeroutevalue || v_approversstring;
   END findnextpersonorgroup;

-----------------------------------------------------------
   PROCEDURE deletetempdata (
      p_item_type   IN              VARCHAR2,
      p_item_key    IN              VARCHAR2,
      p_act_id      IN              NUMBER,
      funmode       IN              VARCHAR2,
      RESULT        OUT NOCOPY      VARCHAR2
   )
   IS
   BEGIN
      DELETE FROM ttec_temp_wf
            WHERE item_key = p_item_key AND item_type = p_item_type;
   END deletetempdata;

------------------------------------------
   FUNCTION getlocationid_1 (p_person_id NUMBER)
      RETURN VARCHAR2
   IS
      retvalue   NUMBER;
   BEGIN
      SELECT location_id
        INTO retvalue
        FROM per_assignments_x
       WHERE person_id = p_person_id;

      RETURN retvalue;
   END getlocationid_1;

-------------------------------------------------------------
   PROCEDURE setupfinalapprover (
      p_item_type   IN              VARCHAR2,
      p_item_key    IN              VARCHAR2,
      p_act_id      IN              NUMBER,
      funmode       IN              VARCHAR2,
      RESULT        OUT NOCOPY      VARCHAR2
   )
   IS
      v_level      NUMBER        := 0;
      v_username   VARCHAR2 (50);
      v_personid   NUMBER;
   BEGIN
      v_level :=
         wf_engine.getitemattrnumber (itemtype      => p_item_type,
                                      itemkey       => p_item_key,
                                      aname         => 'TTEC_HR_APPROVAL_LEVEL'
                                     );
      v_level := v_level + 1;
      wf_engine.setitemattrnumber (itemtype      => p_item_type,
                                   itemkey       => p_item_key,
                                   aname         => 'TTEC_HR_APPROVAL_LEVEL',
                                   avalue        => v_level
                                  );
      RESULT := 'COMPLETE:Y';
   END;

-------------------------------------------------------------
   PROCEDURE buildapproversrole (
      p_item_type   IN              VARCHAR2,
      p_item_key    IN              VARCHAR2,
      p_act_id      IN              NUMBER,
      funmode       IN              VARCHAR2,
      RESULT        OUT NOCOPY      VARCHAR2
   )
   IS
      v_process_name            VARCHAR2 (100);
      v_person_id               NUMBER;
      v_country                 hr_locations.country%TYPE;
      v_userslist               VARCHAR2 (1000);
      v_userssrhrlist           VARCHAR2 (1000);
      v_rolename                VARCHAR2 (100);
      v_locationid              NUMBER;
      v_glcode                  VARCHAR2 (100);
      v_generalresponsibility   fnd_lookup_values.meaning%TYPE   := '';
      v_localresponsibility     fnd_lookup_values.meaning%TYPE   := '';
      v_localboolean            BOOLEAN                          := FALSE;
      role_name                 VARCHAR2 (100);
      role_display_name         VARCHAR2 (200);
                                               --:='Teletech Approvers List';
      p_calledfrom              VARCHAR2 (200);
      v_lookuprecord            lookuprecord_type;
      lookuprecord_table        lookuprecord_tabletype;
      ilookupcount              NUMBER                           := 0;
      v_table1                  v_t_type;
      v_table2                  v_t_type;
      v_tempuser                VARCHAR2 (30);
      v_srusers                 VARCHAR2 (1000);
      v_insert                  BOOLEAN                          := FALSE;
      v_count                   NUMBER                           := 0;
      v_attributeroutevalue     VARCHAR2 (100);
      v_tempstring              VARCHAR2 (1000)                  := '';
      v_tempnumber              NUMBER;
      v_nextdisplayname         VARCHAR2 (500);
--  7-Dec-06  MarkM
      v_newlocationid           VARCHAR2 (20);
      v_locationchanged         BOOLEAN                          := FALSE;
--  7-Dec-06  MarkM

   --futl utl_file.file_type;
   BEGIN
      -- futl :=utl_file.fopen('/usr/tmp/','wf-4','a');

      -- utl_file.put_line(futl,'Start buildsRole '||p_item_type||'-'||p_item_key);

      -- utl_file.fclose(futl);
      mydebug ('Start buildsRole ' || p_item_type || '-' || p_item_key);
      v_process_name :=
         wf_engine.getitemattrtext (itemtype      => p_item_type,
                                    itemkey       => p_item_key,
                                    aname         => 'PROCESS_NAME'
                                   );
      hr_approval_custom.g_itemtype := p_item_type;
      hr_approval_custom.g_itemkey := p_item_key;
      getlookupvalues (lookuprecord_table, 'TTEC_WORKFLOW_HCM_APPROVER_RSP');

      IF v_process_name IN
            ('TTEC_HR_TERMINATION_JSP_PRC', 'TTEC_HR_P_RATE_JSP_PRC',
             'TELTEC_HR_P_RATE_JSP_PRC', 'TELETECH_HR_P_RATE_JSP_PRC',
             'TELETEC_HR_TERMINATION_JSP_PRC',
             'TELETECH_HR_EMP_S_CHG_JSP_PRC')
      THEN
-- Generate HR Locals List
         p_calledfrom :=
            wf_engine.getitemattrtext (itemtype      => p_item_type,
                                       itemkey       => p_item_key,
                                       aname         => 'P_CALLED_FROM'
                                      );
         v_person_id :=
            wf_engine.getitemattrnumber (itemtype      => p_item_type,
                                         itemkey       => p_item_key,
                                         aname         => 'CREATOR_PERSON_ID'
                                        );
         mydebug ('Start buildsRole PersonId :' || v_person_id);
--    Use current person if location is changed --
         v_locationid := getlocationid (v_person_id);
         mydebug ('Start buildsRole LocationId :' || v_locationid);
         v_country := getcountry (v_person_id);
         mydebug ('Start buildsRole Country :' || v_country);
         -- v_glCode :=getPersonLocationCode(v_person_id);
         v_glcode := getlocationid (v_person_id);                -- Mark011607
-- #1101
         v_newlocationid :=
            NVL (getnumtransactionvaluefromitem (p_item_key, 'P_LOCATION_ID'),
                 v_locationid
                );
         g_islocationchanged := FALSE;

         IF TO_NUMBER (v_newlocationid) != TO_NUMBER (v_locationid)
         THEN
            mydebug ('Locations ' || v_locationid || '-' || v_newlocationid);
            v_locationchanged := TRUE;
            g_islocationchanged := TRUE;
            g_newlocationid := v_newlocationid;
            v_country := getlocationcountry (v_newlocationid);
            v_locationid := v_newlocationid;
         END IF;

         g_locationname := getlocationname (v_locationid);
-- #1101
         mydebug (   'Country='
                  || v_country
                  || ' '
                  || v_person_id
                  || '<'
                  || v_locationid
                  || '<'
                 );
         -- replace country token
         v_localboolean := FALSE;

         FOR j IN lookuprecord_table.FIRST .. lookuprecord_table.LAST
         LOOP
            v_lookuprecord := lookuprecord_table (j);
            v_lookuprecord.meaning :=
               REPLACE (UPPER (v_lookuprecord.meaning),
                        '##COUNTRY',
                        v_country
                       );
            mydebug (v_lookuprecord.meaning);
            lookuprecord_table (j) := v_lookuprecord;

            IF v_lookuprecord.lookup_code = '*'
            THEN
               v_generalresponsibility := v_lookuprecord.meaning;
            END IF;

            IF TRIM (v_lookuprecord.lookup_code) = TO_CHAR (v_glcode)
            THEN
               v_localresponsibility := v_lookuprecord.meaning;
               v_localboolean := TRUE;
            END IF;
         END LOOP;

         --
         -- Identify the location related HCM responsibility for Approvers
         IF v_localboolean = TRUE
         THEN
            NULL;
         ELSE
            v_localresponsibility := v_generalresponsibility;
         END IF;

         --    v_usersList := ttec_adhoc_hr_local(v_person_id,v_localResponsibility);
         mydebug ('ITEMS ' || p_item_type || '-' || p_item_key);
         v_userslist := findnextpersonorgroup (p_item_type, p_item_key);
         mydebug ('Step 101 ' || v_userslist || '<');
         v_attributeroutevalue :=
               NVL (SUBSTR (v_userslist, 1, INSTR (v_userslist, ':') - 1),
                    ' ');
         v_userslist := SUBSTR (v_userslist, INSTR (v_userslist, ':') + 1);
         hr_approval_wf.create_item_attrib_if_notexist
                                        (p_item_type      => p_item_type,
                                         p_item_key       => p_item_key,
                                         p_name           => 'TTEC_HR_TERMINATION_ROUTE'
                                        );
         mydebug ('Step 101A ' || v_userslist || '<');
         hr_approval_wf.create_item_attrib_if_notexist
                                           (p_item_type      => p_item_type,
                                            p_item_key       => p_item_key,
                                            p_name           => 'TTEC_HR_APPROVAL_LEVEL'
                                           );
         mydebug ('Step 101A ' || v_userslist || '<');
         wf_engine.setitemattrnumber (itemtype      => p_item_type,
                                      itemkey       => p_item_key,
                                      aname         => 'TTEC_HR_APPROVAL_LEVEL',
                                      avalue        => 1
                                     );
         mydebug ('Step 101B ' || v_userslist || '<');
         v_userslist := LTRIM (v_userslist, ',');
         v_userslist := RTRIM (v_userslist, ',');
-- Process users list and find SR level Human Capital
         v_table1 := getstrings (v_userslist, ',');
         mydebug ('Step 103 ' || v_userslist || '<');
         v_srusers := '';

         BEGIN
            FOR u IN 1 .. v_table1.LAST
            LOOP
               v_tempnumber := TO_NUMBER (v_table1 (u));
               mydebug ('D10=' || v_table1 (u));

               BEGIN
                  SELECT user_name
                    INTO v_tempstring
                    FROM fnd_user
                   WHERE user_id = v_tempnumber
                     AND SYSDATE < NVL (end_date, SYSDATE + 1);

                  IF INSTR (v_srusers, v_tempstring || ',') > 0
                  THEN
                     NULL;
                  ELSE
                     v_srusers := v_srusers || v_tempstring || ',';
                  END IF;
               EXCEPTION
                  WHEN OTHERS
                  THEN
                     NULL;
                     mydebug ('Exception ' || SUBSTR (SQLERRM, 1, 200));
               END;

               v_tempstring := '';
            END LOOP;
         EXCEPTION
            WHEN OTHERS
            THEN
               mydebug ('No user found');
               RAISE NO_DATA_FOUND;
         END;

         mydebug ('Step 104=');
-- Remove duplicated users and current person id
--       v_table1 := getStrings(v_srUsers,',');
         v_srusers := RTRIM (v_srusers, ',');
         mydebug ('D11=' || v_srusers);

         IF LENGTH (v_srusers) > 3
         THEN
            -- create adhoc role
            mydebug ('D11A=' || v_srusers);
            role_display_name :=
                gethcmroledescription (p_item_key) || '(' || p_item_key
                || ')';
            wf_directory.createadhocrole
               (role_name,                 --          in out nocopy varchar2,
                role_display_name,           --       in out nocopy  varchar2,
                'AMERICAN',
                          --language                in  varchar2 default null,
                '',       --territory               in  varchar2 default null,
                'Teletech Approvers Role',
                          --role_description        in  varchar2 default null,
                'MAILHTML',
                     --notification_preference in varchar2 default 'MAILHTML',
                v_srusers,
                          --role_users              in  varchar2 default null,
                '',       --email_address           in  varchar2 default null,
                '',       --fax                     in  varchar2 default null,
                'ACTIVE',
                      --status                  in  varchar2 default 'ACTIVE',
                TRUNC (SYSDATE + 14),
                              --expiration_date         in  date default null,
                '',       -- parent_orig_system      in varchar2 default null,
                '',         -- parent_orig_system_id   in number default null,
                ''         --owner_tag               in  varchar2 default null
               );
            mydebug ('D12=' || v_srusers || ' ' || role_name);
            v_rolename := role_name;
            hr_approval_wf.create_item_attrib_if_notexist
                                          (p_item_type      => p_item_type,
                                           p_item_key       => p_item_key,
                                           p_name           => 'TTEC_HR_LOCAL_APPROVALS'
                                          );
            wf_engine.setitemattrtext (itemtype      => p_item_type,
                                       itemkey       => p_item_key,
                                       aname         => 'TTEC_HR_LOCAL_APPROVALS',
                                       avalue        => v_rolename
                                      );
            mydebug ('D15=' || v_rolename);

            IF v_process_name IN ('TTEC_HR_TERMINATION_JSP_PRC')
            THEN
               wf_engine.setitemattrtext
                                       (itemtype      => p_item_type,
                                        itemkey       => p_item_key,
                                        aname         => 'FORWARD_TO_DISPLAY_NAME',
                                        avalue        => 'Termination approval role'
                                       );
            END IF;

            IF v_process_name IN ('TTEC_HR_P_RATE_JSP_PRC')
            THEN
               mydebug (v_process_name || '-' || v_srusers);
               v_table1 := getstrings (v_srusers, ',');
               mydebug ('R1=' || v_table1 (1));

               BEGIN
                  SELECT full_name
                    INTO v_nextdisplayname
                    FROM per_all_people_f
                   WHERE person_id =
                            (SELECT employee_id
                               FROM fnd_user
                              WHERE user_name = v_table1 (1)
                                AND SYSDATE < NVL (end_date, SYSDATE + 1))
                     AND SYSDATE BETWEEN effective_start_date
                                     AND NVL (effective_end_date, SYSDATE + 1);
               EXCEPTION
                  WHEN OTHERS
                  THEN
                     v_nextdisplayname := 'Hr Role';
                     NULL;
               END;

               mydebug ('R2=' || v_table1 (1) || '-' || v_nextdisplayname);
               wf_engine.setitemattrtext (itemtype      => p_item_type,
                                          itemkey       => p_item_key,
                                          aname         => 'FORWARD_TO_DISPLAY_NAME',
                                          avalue        => v_nextdisplayname
                                         );
            END IF;
         END IF;
      END IF;

      mydebug ('R3=' || v_table1 (1) || '-' || v_nextdisplayname);
      RESULT := 'COMPLETE:Y';
   EXCEPTION
      WHEN OTHERS
      THEN
         mydebug (SQLERRM);
         RESULT := 'COMPLETE:Y';
   END;

-------------------------------------------------------------------------
-----------------------------------------------------------

   ----------------------------------------------------------
   FUNCTION gettransactionvalue (p_transactionid NUMBER)
      RETURN VARCHAR
   IS
      retvalue       VARCHAR2 (500);
      p_calledfrom   VARCHAR2 (100);
   BEGIN
      SELECT user_id
        INTO retvalue
        FROM fnd_user
       WHERE employee_id IN (
                SELECT number_value
                  FROM hr_api_transaction_values
                 WHERE transaction_step_id IN (
                                        SELECT transaction_step_id
                                          FROM hr_api_transaction_steps
                                         WHERE transaction_id =
                                                               p_transactionid)
                   AND NAME = 'P_SELECTED_PERSON_SUP_ID'
                   AND ROWNUM < 2);

      RETURN retvalue;
   EXCEPTION
      WHEN OTHERS
      THEN
         retvalue := '';
         RETURN retvalue;
   END gettransactionvalue;

----------------------------------------------------------------
   FUNCTION gettransactionvalue (
      p_item_type    IN   VARCHAR2,
      p_item_key     IN   VARCHAR2,
      ATTRIBUTE      IN   VARCHAR2,
      p_calledfrom   IN   VARCHAR2
   )
      RETURN VARCHAR2
   IS
      retvalue   VARCHAR2 (500);
   BEGIN
      SELECT DECODE (datatype,
                     'VARCHAR2', varchar2_value,
                     'NUMBER', TO_CHAR (number_value),
                     'DATE', TO_CHAR (date_value),
                     NULL
                    )
        INTO retvalue
        FROM hr_api_transaction_values
       WHERE transaction_step_id IN (
                SELECT transaction_step_id
                  FROM hr_api_transaction_steps
                 WHERE item_type = p_item_type
                   AND item_key = p_item_key
                   AND api_name LIKE p_calledfrom || '%')
         AND NAME = ATTRIBUTE
         AND ROWNUM < 2;

      RETURN retvalue;
   EXCEPTION
      WHEN OTHERS
      THEN
         RETURN NULL;
   END;

-------------------------------------------------------------------------
   FUNCTION getsupervisorpersonid (p_personid IN NUMBER)
      RETURN NUMBER
   IS
      retvalue   NUMBER;
   BEGIN
      SELECT ppf.person_id
        INTO retvalue
        FROM per_all_assignments_f paf, per_all_people_f ppf
       WHERE paf.person_id = p_personid
         AND paf.primary_flag = 'Y'
         AND TRUNC (SYSDATE) BETWEEN paf.effective_start_date
                                 AND paf.effective_end_date
         AND paf.assignment_type IN ('E', 'C')
         AND paf.assignment_status_type_id NOT IN (
                                       SELECT assignment_status_type_id
                                         FROM per_assignment_status_types
                                        WHERE per_system_status =
                                                                 'TERM_ASSIGN')
         AND ppf.person_id = paf.supervisor_id
         AND (ppf.current_employee_flag = 'Y' OR ppf.current_npw_flag = 'Y')
         AND TRUNC (SYSDATE) BETWEEN ppf.effective_start_date
                                 AND ppf.effective_end_date;

      RETURN retvalue;
   EXCEPTION
      WHEN OTHERS
      THEN
         RETURN NULL;
   END;

-------------------------------------------------------------------------
   FUNCTION getsupervisor (p_personid IN NUMBER)
      RETURN NUMBER
   IS
      retvalue   NUMBER;
   BEGIN
      retvalue := hr_approval_custom.get_next_approver (p_personid);
      RETURN retvalue;
   EXCEPTION
      WHEN OTHERS
      THEN
         RETURN NULL;
   END;

-------------------------------------------------------------------------
   FUNCTION getsupervisoruser (p_personid IN NUMBER)
      RETURN NUMBER
   IS
      retvalue   NUMBER;

      CURSOR gets_c
      IS
         SELECT user_id
           FROM fnd_user
          WHERE employee_id = p_personid
            AND SYSDATE < NVL (end_date, SYSDATE + 1);
   BEGIN
--   retValue:=HR_APPROVAL_CUSTOM.get_Next_Approver(p_personId);
      FOR c IN gets_c
      LOOP
         retvalue := c.user_id;
         EXIT;
      END LOOP;

      mydebug ('Found superId :' || retvalue);
      RETURN retvalue;
   EXCEPTION
      WHEN OTHERS
      THEN
         mydebug ('Find Sup Usert id exception ' || SUBSTR (SQLERRM, 1, 100));
         RETURN NULL;
   END;

-------------------------------------------------------------------------
   FUNCTION getusername (p_personid IN NUMBER)
      RETURN VARCHAR2
   IS
      retvalue   fnd_user.user_name%TYPE;
   BEGIN
      SELECT user_name
        INTO retvalue
        FROM fnd_user
       WHERE employee_id = p_personid;

      RETURN retvalue;
   EXCEPTION
      WHEN OTHERS
      THEN
         RETURN NULL;
   END;

-------------------------------------------------------------------------
   FUNCTION getpersonfullname (p_personid IN NUMBER)
      RETURN VARCHAR2
   IS
      retvalue   per_all_people_f.full_name%TYPE;
   BEGIN
      SELECT full_name
        INTO retvalue
        FROM per_all_people_f
       WHERE person_id = p_personid
         AND SYSDATE BETWEEN effective_start_date AND effective_end_date;

      RETURN retvalue;
   EXCEPTION
      WHEN OTHERS
      THEN
         RETURN NULL;
   END;

-------------------------------------------------------------------------
   PROCEDURE ttec_chg_manager_initialize (
      p_item_type   IN              VARCHAR2,
      p_item_key    IN              VARCHAR2,
      p_act_id      IN              NUMBER,
      funmode       IN              VARCHAR2,
      RESULT        OUT NOCOPY      VARCHAR2
   )
   IS
      newsupid         per_all_people_f.person_id%TYPE;
      newsupname       per_all_people_f.full_name%TYPE;
      newsupusername   fnd_user.user_name%TYPE;
      p_calledfrom     VARCHAR2 (300);
      DEBUG            VARCHAR2 (100);
   BEGIN
      p_calledfrom :=
         wf_engine.getitemattrtext (itemtype      => p_item_type,
                                    itemkey       => p_item_key,
                                    aname         => 'P_CALLED_FROM'
                                   );
      newsupid :=
         gettransactionvalue (p_item_type,
                              p_item_key,
                              'P_SELECTED_PERSON_SUP_ID',
                              p_calledfrom
                             );
      mydebug ('New sup=' || newsupid);
      DEBUG := 'St 1';

      SELECT user_name
        INTO newsupusername
        FROM fnd_user
       WHERE employee_id = newsupid;

      newsupname := getpersonfullname (newsupid);
      DEBUG := 'St 2';
      wf_engine.setitemattrnumber (itemtype      => p_item_type,
                                   itemkey       => p_item_key,
                                   aname         => 'FORWARD_TO_PERSON_ID',
                                   avalue        => newsupid
                                  );
      DEBUG := 'St 3';
      wf_engine.setitemattrtext (itemtype      => p_item_type,
                                 itemkey       => p_item_key,
                                 aname         => 'FORWARD_TO_DISPLAY_NAME',
                                 avalue        => newsupname
                                );
      DEBUG := 'St 4';
      wf_engine.setitemattrtext (itemtype      => p_item_type,
                                 itemkey       => p_item_key,
                                 aname         => 'FORWARD_TO_USERNAME',
                                 avalue        => newsupusername
                                );
      wf_engine.setitemattrnumber (itemtype      => p_item_type,
                                   itemkey       => p_item_key,
                                   aname         => 'SUPERVISOR_ID',
                                   avalue        => newsupid
                                  );
      wf_engine.setitemattrnumber (itemtype      => p_item_type,
                                   itemkey       => p_item_key,
                                   aname         => 'SUPERVISOR_DISPLAY_NAME',
                                   avalue        => getpersonfullname
                                                                     (newsupid)
                                  );
      wf_engine.setitemattrnumber (itemtype      => p_item_type,
                                   itemkey       => p_item_key,
                                   aname         => 'SUPERVISOR_USERNAME',
                                   avalue        => getusername (newsupid)
                                  );
      RESULT := 'COMPLETE:';
   --commit;
   EXCEPTION
      WHEN OTHERS
      THEN
         DEBUG := DEBUG || ' ' || SUBSTR (SQLERRM, 1, 70);
         mydebug ('Exception ' || DEBUG);
   --commit;
   END ttec_chg_manager_initialize;

---------------------------------------------------------------------
   PROCEDURE ttec_next_approver (
      p_item_type   IN              VARCHAR2,
      p_item_key    IN              VARCHAR2,
      p_act_id      IN              NUMBER,
      funmode       IN              VARCHAR2,
      RESULT        OUT NOCOPY      VARCHAR2
   )
   IS
      newsupid               per_all_people_f.person_id%TYPE;
      newsupname             per_all_people_f.full_name%TYPE;
      newsupusername         fnd_user.user_name%TYPE;
      nextapprover           per_all_people_f.person_id%TYPE;
      nextapproverfullname   per_all_people_f.full_name%TYPE;
      p_calledfrom           VARCHAR2 (300);
      DEBUG                  VARCHAR2 (100);
   BEGIN
      p_calledfrom :=
         wf_engine.getitemattrtext (itemtype      => p_item_type,
                                    itemkey       => p_item_key,
                                    aname         => 'P_CALLED_FROM'
                                   );
      newsupid :=
         gettransactionvalue (p_item_type,
                              p_item_key,
                              'P_SELECTED_PERSON_SUP_ID',
                              p_calledfrom
                             );
      nextapprover := getsupervisor (newsupid);
      nextapproverfullname := getpersonfullname (newsupid);

      SELECT user_name
        INTO newsupusername
        FROM fnd_user
       WHERE employee_id = nextapprover;

      wf_engine.setitemattrnumber (itemtype      => p_item_type,
                                   itemkey       => p_item_key,
                                   aname         => 'FORWARD_TO_PERSON_ID',
                                   avalue        => nextapprover
                                  );
      wf_engine.setitemattrtext (itemtype      => p_item_type,
                                 itemkey       => p_item_key,
                                 aname         => 'FORWARD_TO_DISPLAY_NAME',
                                 avalue        => nextapproverfullname
                                );
      wf_engine.setitemattrtext (itemtype      => p_item_type,
                                 itemkey       => p_item_key,
                                 aname         => 'FORWARD_TO_USERNAME',
                                 avalue        => newsupusername
                                );
      RESULT := 'COMPLETE:';
   --commit;
   EXCEPTION
      WHEN OTHERS
      THEN
         DEBUG := DEBUG || ' ' || SUBSTR (SQLERRM, 1, 70);
         mydebug ('Exception ' || DEBUG);
         --commit;
         RESULT := 'ERROR';
   END ttec_next_approver;

----------------------------------------------------------------------
   FUNCTION ttec_adhoc_hr_local (p_person_id NUMBER, responsibilitykey VARCHAR2)
      RETURN VARCHAR2
   IS
      hruserslist         VARCHAR2 (1000) := '';
      v_organization_id   NUMBER;
      v_location_id       NUMBER;

      CURSOR getlocalapprovers_c (loc_id NUMBER, org_id NUMBER)
      IS
         SELECT user_id, user_name
           FROM fnd_user fu
          WHERE user_id IN (
                   SELECT user_id
                     FROM fnd_user_resp_groups
                    WHERE SYSDATE BETWEEN start_date
                                      AND NVL (end_date, SYSDATE + 1)
                      AND responsibility_id IN (
                                  SELECT responsibility_id
                                    FROM fnd_responsibility
                                   WHERE responsibility_key =
                                                             responsibilitykey))
            AND EXISTS (
                   SELECT 'x'
                     FROM per_all_people_f pp, per_assignments_x pa
                    WHERE SYSDATE BETWEEN pp.effective_start_date
                                      AND NVL (pp.effective_end_date,
                                               SYSDATE + 1
                                              )
                      AND SYSDATE BETWEEN pa.effective_start_date
                                      AND NVL (pa.effective_end_date,
                                               SYSDATE + 1
                                              )
                      AND pp.person_id = pa.person_id
                      AND pp.person_id = fu.employee_id
                      AND pa.location_id = loc_id)
            AND SYSDATE < NVL (end_date, SYSDATE + 1);
   --and pa.organization_id = org_id);
   BEGIN
      mydebug ('Start ad_hoc_hr_local');

---        Find person location and org
      SELECT pa.location_id, pa.organization_id
        INTO v_location_id, v_organization_id
        FROM per_all_people_f pp, per_assignments_x pa
       WHERE pp.person_id = pa.person_id
         AND pp.person_id = p_person_id
         AND SYSDATE BETWEEN pp.effective_start_date AND pp.effective_end_date
         AND SYSDATE BETWEEN pa.effective_start_date AND pa.effective_end_date;

      -- Build the users list
      mydebug ('Step 102 #' || v_location_id || ':' || v_organization_id);

-- #1101
      IF g_islocationchanged = TRUE
      THEN
         v_location_id := g_newlocationid;
      END IF;

-- #1101
      FOR c IN getlocalapprovers_c (v_location_id, v_organization_id)
      LOOP
         hruserslist := hruserslist || c.user_id || ',';
      END LOOP;

      g_locationname := getlocationname (v_location_id);
      hruserslist := RTRIM (hruserslist, ',');

      IF LENGTH (hruserslist) = 0
      THEN
         RAISE NO_DATA_FOUND;
         hruserslist := ' ';
      END IF;

      RETURN hruserslist;
   EXCEPTION
      WHEN OTHERS
      THEN
         RAISE NO_DATA_FOUND;
   END ttec_adhoc_hr_local;

------------------------------------------------------
   FUNCTION ttec_adhoc_hr_corp (p_person_id NUMBER, responsibilitykey VARCHAR2)  -- returns fnd_user_id
      RETURN VARCHAR2
   IS
      hruserslist         VARCHAR2 (1000) := ',';
      v_organization_id   NUMBER;
      v_location_id       NUMBER;

      CURSOR getlocalapprovers_c
      IS
/*--select unique fg.user_id
       from
           FND_USER_RESP_GROUPS fg,FND_USER fu,fnd_responsibility fr,
           per_all_people_f pp,
   --      per_all_assignments_f pa,
           per_assignment_status_types at
       where
       fg.user_id = fu.user_id and
       sysdate between fg.start_date and fg.end_date
       and fg.responsibility_id=fr.responsibility_id
          and fr.responsibility_key = responsibilityKey
         and    sysdate between pp.effective_start_date and pp.effective_end_date
      --    and sysdate between pa.effective_start_date and pa.effective_end_date
            and upper(at.user_status)='ACTIVE ASSIGNMENT'
         -- and pp.person_id = pa.person_id
            and pp.person_id = fu.employee_id
            and sysdate < nvl(fu.end_date,sysdate+1);
*/
         SELECT user_id
           FROM fnd_user fu, per_assignments_x pa
          WHERE user_id IN (
                   SELECT UNIQUE fg.user_id
                            FROM fnd_user_resp_groups fg
                                    --,FND_USER fu --,fnd_responsibility fr--,
                           WHERE SYSDATE BETWEEN fg.start_date
                                             AND NVL (fg.end_date,
                                                      SYSDATE + 1)
                             AND fg.responsibility_id IN (
                                    SELECT responsibility_id
                                      FROM fnd_responsibility
                                     WHERE responsibility_key =
                                                             responsibilitykey))
            AND SYSDATE BETWEEN pa.effective_start_date AND pa.effective_end_date
            AND pa.person_id = fu.employee_id
            AND SYSDATE < NVL (fu.end_date, SYSDATE + 1);
   BEGIN
---        Find person location and org
      mydebug (   'Step 102 ## p_id'
               || p_person_id
               || ' respKey='
               || responsibilitykey
               || ' locid='
               || v_location_id
               || ': orgId='
               || v_organization_id
              );

      FOR c IN getlocalapprovers_c
      LOOP
         hruserslist := hruserslist || c.user_id || ',';
      END LOOP;

      hruserslist := RTRIM (hruserslist, ',');

      IF LENGTH (hruserslist) = 0
      THEN
         RAISE NO_DATA_FOUND;
         hruserslist := ' ';
      END IF;

      mydebug (hruserslist);
      RETURN hruserslist;
   EXCEPTION
      WHEN OTHERS
      THEN
         RAISE NO_DATA_FOUND;
   END ttec_adhoc_hr_corp;

------------------------------------------------------

   -------------------------------------------------------------
   FUNCTION getdepartmentnumber (p_person_id NUMBER)
      --RETURN hr.pay_cost_allocation_keyflex.segment3%TYPE				-- Commented code by IXPRAVEEN-ARGANO,15-May-2023
      RETURN apps.pay_cost_allocation_keyflex.segment3%TYPE               --  code Added by IXPRAVEEN-ARGANO,   15-May-2023
   IS
      /*v_department   hr.pay_cost_allocation_keyflex.segment3%TYPE;			-- Commented code by IXPRAVEEN-ARGANO,15-May-2023
      v_location     hr.pay_cost_allocation_keyflex.segment1%TYPE;*/            
	  v_department   apps.pay_cost_allocation_keyflex.segment3%TYPE;			--  code Added by IXPRAVEEN-ARGANO,   15-May-2023
      v_location     apps.pay_cost_allocation_keyflex.segment1%TYPE;
   BEGIN
      BEGIN
         BEGIN
            SELECT DISTINCT
                            -- pcak_org.segment3||pcak_asg.segment2 department_id,
                            pcak_asg.segment1 LOCATION,
                            pcak_asg.segment3 department_code
                       INTO v_location,
                            v_department
                       FROM per_all_people_f papf,
                            per_all_assignments_f paaf,
                            hr_all_organization_units haou,
                            pay_cost_allocation_keyflex pcak_org,
                            pay_cost_allocations_f pcaf,
                            pay_cost_allocation_keyflex pcak_asg,
                            fnd_flex_values_vl ffvv
                      WHERE
--  papf.business_group_id IN (325,326,1517,1839)
  --papf.business_group_id  = NVL(325, papf.business_group_id)
                            papf.business_group_id <> 0
                        AND papf.person_id = paaf.person_id
                        AND paaf.organization_id = haou.organization_id
                        AND haou.cost_allocation_keyflex_id =
                                           pcak_org.cost_allocation_keyflex_id
                        AND paaf.assignment_id = pcaf.assignment_id
                        AND pcaf.cost_allocation_keyflex_id =
                                           pcak_asg.cost_allocation_keyflex_id
                        AND pcak_asg.segment2 = ffvv.flex_value
                        AND ffvv.flex_value_set_id = '1002611'
                        AND papf.current_employee_flag = 'Y'
                        AND papf.person_id = p_person_id
                        AND SYSDATE BETWEEN papf.effective_start_date
                                        AND papf.effective_end_date
                        AND SYSDATE BETWEEN paaf.effective_start_date
                                        AND paaf.effective_end_date
                        AND SYSDATE BETWEEN pcaf.effective_start_date
                                        AND pcaf.effective_end_date;
         EXCEPTION
            WHEN OTHERS
            THEN
               v_department := NULL;
         END;

         IF v_department IS NULL
         THEN
            SELECT DISTINCT segment1, segment3
                       INTO v_location, v_department
                       --FROM hr.pay_cost_allocation_keyflex kff,			-- Commented code by IXPRAVEEN-ARGANO,15-May-2023
                       FROM apps.pay_cost_allocation_keyflex kff,           --  code Added by IXPRAVEEN-ARGANO,   15-May-2023
                            per_assignments_x asg,
                            hr_organization_units org
                      WHERE kff.cost_allocation_keyflex_id =
                                                org.cost_allocation_keyflex_id
                        AND org.organization_id = asg.organization_id
                        AND asg.person_id = p_person_id;
         END IF;
      EXCEPTION
         WHEN OTHERS
         THEN
            RETURN NULL;
      END;

      RETURN v_department;
   EXCEPTION
      WHEN OTHERS
      THEN
         RETURN NULL;
   END getdepartmentnumber;

------------------------------------------------------
-------------------------------------------------------------
   FUNCTION getlocationid (p_person_id NUMBER)
      RETURN VARCHAR2
   IS
      v_locationid       VARCHAR2 (30);
      v_locationname     VARCHAR2 (100);
      v_corplocations    VARCHAR2 (100)
                            := fnd_profile.VALUE ('TTEC_CORPORATE_LOCATIONS');
      v_templocationid   VARCHAR2 (100);
      v_t                v_t_type;
   BEGIN
      BEGIN
         SELECT DISTINCT
                         -- pcak_org.segment3||pcak_asg.segment2 department_id,
                         pcak_asg.segment1 LOCATION
--  pcak_asg.segment3 department_code
         INTO            v_locationid                          --,v_department
                    FROM per_all_people_f papf,
                         per_all_assignments_f paaf,
                         hr_all_organization_units haou,
                         pay_cost_allocation_keyflex pcak_org,
                         pay_cost_allocations_f pcaf,
                         pay_cost_allocation_keyflex pcak_asg,
                         fnd_flex_values_vl ffvv
                   WHERE
--  papf.business_group_id IN (325,326,1517,1839)
  --papf.business_group_id  = NVL(325, papf.business_group_id)
                         papf.business_group_id <> 0
                     AND papf.person_id = paaf.person_id
                     AND paaf.organization_id = haou.organization_id
                     AND haou.cost_allocation_keyflex_id =
                                           pcak_org.cost_allocation_keyflex_id
                     AND paaf.assignment_id = pcaf.assignment_id
                     AND pcaf.cost_allocation_keyflex_id =
                                           pcak_asg.cost_allocation_keyflex_id
                     AND pcak_asg.segment2 = ffvv.flex_value
                     AND ffvv.flex_value_set_id = '1002611'
                     AND papf.current_employee_flag = 'Y'
                     AND papf.person_id = p_person_id
                     AND SYSDATE BETWEEN papf.effective_start_date
                                     AND papf.effective_end_date
                     AND SYSDATE BETWEEN paaf.effective_start_date
                                     AND paaf.effective_end_date
                     AND SYSDATE BETWEEN pcaf.effective_start_date
                                     AND pcaf.effective_end_date;

         IF v_locationid IS NULL
         THEN
            SELECT                                            --l.location_id
                   attribute2
              INTO v_locationid
              FROM hr_locations l, per_all_assignments_f a
             WHERE l.location_id = a.location_id
               AND a.person_id = p_person_id
               AND SYSDATE BETWEEN a.effective_start_date AND a.effective_end_date;
         ELSE
            NULL;
/*
SELECT --l.location_id   -- FUTUARE CHANGEANO
      attribute2
  INTO v_tempLocationId
  FROM HR_LOCATIONS l, per_all_assignments_f A
 WHERE l.location_id = A.location_id
   AND A.person_id = p_person_id
   AND SYSDATE BETWEEN A.effective_start_date AND A.effective_end_date;
*/
         END IF;
      EXCEPTION
         WHEN OTHERS
         THEN
            NULL;
      END;

      v_t := getstrings (v_corplocations, ':');

      IF INSTR (v_corplocations, ':' || v_locationid || ':') > 0
      THEN
         NULL;
      END IF;

/*

   ELSE



       IF  INSTR(v_corpLocations,':'||v_tempLocationId||':') >0 THEN
          v_locationId :=v_tempLocationId;
      END IF;

   END IF;
*/
      IF g_hcm_role_description = NULL
      THEN
         g_hcm_role_description := 'HCM Approver Role ';
      END IF;

      IF g_locationname = NULL
      THEN
         g_locationname := getlocationname (getlocationid (v_locationid));

         IF g_locationname IS NULL
         THEN
            g_locationname := getlocationnamepid (p_person_id);
         END IF;
      END IF;

      RETURN v_locationid;
   EXCEPTION
      WHEN OTHERS
      THEN
         RETURN NULL;
   END getlocationid;

------------------------------------------------------
   FUNCTION getlocationglcode (p_person_id NUMBER)
      RETURN NUMBER
   IS
      v_attribute2   hr_locations.attribute2%TYPE;
   BEGIN
      SELECT l.attribute2
        INTO v_attribute2
        FROM hr_locations l, per_all_assignments_f a
       WHERE l.location_id = a.location_id
         AND a.person_id = p_person_id
         AND SYSDATE BETWEEN a.effective_start_date AND a.effective_end_date;

      RETURN v_attribute2;
   EXCEPTION
      WHEN OTHERS
      THEN
         RETURN NULL;
   END getlocationglcode;

------------------------------------------------------
   FUNCTION getlocationname (p_location_id NUMBER)
      RETURN VARCHAR2
   IS
      v_locationcode   hr_locations.location_code%TYPE;
   BEGIN
      SELECT location_code
        INTO v_locationcode
        FROM hr_locations l
       WHERE l.location_id = p_location_id
         AND NVL (inactive_date, SYSDATE + 1) > SYSDATE;

      RETURN v_locationcode;
   EXCEPTION
      WHEN OTHERS
      THEN
         RETURN TO_CHAR (p_location_id);
   END getlocationname;

------------------------------------------------------
   FUNCTION getlocationnamepid (p_person_id NUMBER)
      RETURN VARCHAR2
   IS
      v_locationcode   hr_locations.location_code%TYPE;
   BEGIN
      SELECT location_code
        INTO v_locationcode
        FROM hr_locations l
       WHERE l.location_id =
                (SELECT location_id
                   FROM per_all_assignments_f
                  WHERE person_id = p_person_id
                    AND SYSDATE BETWEEN effective_start_date
                                    AND NVL (effective_end_date, SYSDATE + 1))
         AND NVL (inactive_date, SYSDATE + 1) > SYSDATE;

      RETURN v_locationcode;
   EXCEPTION
      WHEN OTHERS
      THEN
         RETURN 'Empl:' || p_person_id;
   END getlocationnamepid;

------------------------------------------------------
   FUNCTION getpersonlocationcode (p_person_id NUMBER)
      RETURN VARCHAR2
   IS
      v_attribute2   hr_locations.attribute2%TYPE;
      v_location     VARCHAR2 (100);
   BEGIN
      BEGIN
         SELECT DISTINCT segment1
                    INTO v_location
                    --FROM hr.pay_cost_allocation_keyflex kff,						-- Commented code by IXPRAVEEN-ARGANO,15-May-2023
                    FROM apps.pay_cost_allocation_keyflex kff,                        --  code Added by IXPRAVEEN-ARGANO,   15-May-2023
                         per_assignments_x asg,
                         hr_organization_units org
                   WHERE kff.cost_allocation_keyflex_id =
                                                org.cost_allocation_keyflex_id
                     AND org.organization_id = asg.organization_id
                     AND asg.person_id = p_person_id;
      EXCEPTION
         WHEN OTHERS
         THEN
            NULL;
            v_location := NULL;
      END;

      IF TRIM (v_location) IS NULL
      THEN
         SELECT l.attribute2
           INTO v_location
           FROM hr_locations l, per_all_assignments_f a
          WHERE l.location_id = a.location_id
            AND a.person_id = p_person_id
            AND SYSDATE BETWEEN a.effective_start_date AND a.effective_end_date;
      END IF;

      RETURN v_location;
   EXCEPTION
      WHEN OTHERS
      THEN
         RETURN NULL;
   END getpersonlocationcode;

------------------------------------------------------
   FUNCTION getcountry (p_person_id NUMBER)
      RETURN VARCHAR2
   IS
      v_country   hr_locations.country%TYPE;
   BEGIN
      SELECT country
        INTO v_country
        FROM hr_locations l, per_all_assignments_f a
       WHERE l.location_id = a.location_id
         AND a.person_id = p_person_id
         AND SYSDATE BETWEEN a.effective_start_date AND a.effective_end_date;

      RETURN v_country;
   EXCEPTION
      WHEN OTHERS
      THEN
         RETURN NULL;
   END getcountry;

------------------------------------------------------------------
   FUNCTION getlocationcountry (p_location_id NUMBER)
      RETURN VARCHAR2
   IS
      v_country   hr_locations.country%TYPE;
   BEGIN
      SELECT country
        INTO v_country
        FROM hr_locations l
       WHERE l.location_id = p_location_id;

      RETURN v_country;
   EXCEPTION
      WHEN OTHERS
      THEN
         RETURN NULL;
   END getlocationcountry;

-------------------------------------------------------------------
   PROCEDURE generateadhocrolehr (
      p_item_type   IN              VARCHAR2,
      p_item_key    IN              VARCHAR2,
      p_act_id      IN              NUMBER,
      funmode       IN              VARCHAR2,
      RESULT        OUT NOCOPY      VARCHAR2
   )
   IS
      v_process_name            VARCHAR2 (100);
      v_person_id               NUMBER;
      v_country                 hr_locations.country%TYPE;
      v_userslist               VARCHAR2 (1000);
      v_rolename                VARCHAR2 (100);
      v_locationid              NUMBER;
      v_glcode                  VARCHAR2 (100);
      v_generalresponsibility   fnd_lookup_values.meaning%TYPE   := '';
      v_localresponsibility     fnd_lookup_values.meaning%TYPE   := '';
      v_localboolean            BOOLEAN                          := FALSE;
      role_name                 VARCHAR2 (100);
      role_display_name         VARCHAR2 (200);
      p_calledfrom              VARCHAR2 (200);
      v_lookuprecord            lookuprecord_type;
      lookuprecord_table        lookuprecord_tabletype;
      ilookupcount              NUMBER                           := 0;
      tempresponsibilityname    VARCHAR2 (100);
   BEGIN
      v_process_name :=
         wf_engine.getitemattrtext (itemtype      => p_item_type,
                                    itemkey       => p_item_key,
                                    aname         => 'PROCESS_NAME'
                                   );
      getlookupvalues (lookuprecord_table, 'TTEC_WORKFLOW_HCM_APPROVER_RSP');

      IF v_process_name IN
            ('TTEC_HR_MANAGER_JSP_PRC', 'TELETEC_HR_TERMINATION_JSP_PRC',
             'TTEC_HR_TERMINATION_JSP_PRC')
      THEN
-- Generate HR Locals List
         p_calledfrom :=
            wf_engine.getitemattrtext (itemtype      => p_item_type,
                                       itemkey       => p_item_key,
                                       aname         => 'P_CALLED_FROM'
                                      );
         v_person_id :=
            wf_engine.getitemattrtext (itemtype      => p_item_type,
                                       itemkey       => p_item_key,
                                       aname         => 'SUPERVISOR_ID'
                                      );
         v_locationid := getlocationid (v_person_id);
         v_country := getcountry (v_person_id);
         v_glcode := getlocationglcode (v_person_id);
         mydebug (   'Country='
                  || v_country
                  || ' '
                  || v_person_id
                  || '<'
                  || v_locationid
                  || '<'
                 );
         -- replace country token
         v_localboolean := FALSE;

         FOR j IN lookuprecord_table.FIRST .. lookuprecord_table.LAST
         LOOP
            v_lookuprecord := lookuprecord_table (j);
            v_lookuprecord.meaning :=
               REPLACE (UPPER (v_lookuprecord.meaning),
                        '##COUNTRY',
                        v_country
                       );
            mydebug (v_lookuprecord.meaning);
            lookuprecord_table (j) := v_lookuprecord;

            IF v_lookuprecord.lookup_code = '*'
            THEN
               v_generalresponsibility := v_lookuprecord.meaning;
            END IF;

            IF TRIM (v_lookuprecord.lookup_code) = TO_CHAR (v_glcode)
            THEN
               v_localresponsibility := v_lookuprecord.meaning;
               v_localboolean := TRUE;
            END IF;
         END LOOP;

         --
         -- Identify the location related HCM responsibility for Approvers
         IF v_localboolean = TRUE
         THEN
            NULL;
         ELSE
            v_localresponsibility := v_generalresponsibility;
         END IF;

         mydebug ('Step 5');
         v_userslist :=
                      ttec_adhoc_hr_local (v_person_id, v_localresponsibility);
         v_userslist := RTRIM (v_userslist, ',');
         mydebug ('D12=' || v_userslist);

         IF LENGTH (v_userslist) > 3
         THEN
            -- create adhoc role

            /*       select responsibility_name
           into tempResponsibilityName
         from fnd_responsibility_tl
            where responsibility_id in (
         select responsibility_id from    fnd_responsibility
         where responsibility_key = v_localResponsibility)
         and language='US';
*/
            tempresponsibilityname := gethcmroledescription (p_item_key);
            g_locationname := getlocationname (getlocationid (v_locationid));

            IF TRIM (LENGTH (g_locationname)) = 0
            THEN
               g_locationname := getlocationnamepid (v_person_id);
            END IF;

            role_display_name :=
                  tempresponsibilityname
               || '('
               || g_locationname
               || '-'
               || p_item_key
               || ')';
            wf_directory.createadhocrole
               (role_name,                 --          in out nocopy varchar2,
                role_display_name,           --       in out nocopy  varchar2,
                'AMERICAN',
                          --language                in  varchar2 default null,
                '',       --territory               in  varchar2 default null,
                '',       --role_description        in  varchar2 default null,
                'MAILHTML',
                     --notification_preference in varchar2 default 'MAILHTML',
                v_userslist,
                          --role_users              in  varchar2 default null,
                '',       --email_address           in  varchar2 default null,
                '',       --fax                     in  varchar2 default null,
                'ACTIVE',
                      --status                  in  varchar2 default 'ACTIVE',
                TRUNC (SYSDATE + 14),
                              --expiration_date         in  date default null,
                '',       -- parent_orig_system      in varchar2 default null,
                '',         -- parent_orig_system_id   in number default null,
                ''         --owner_tag               in  varchar2 default null
               );
            v_rolename := role_name;
            hr_approval_wf.create_item_attrib_if_notexist
                                          (p_item_type      => p_item_type,
                                           p_item_key       => p_item_key,
                                           p_name           => 'TTEC_HR_LOCAL_APPROVALS'
                                          );
            wf_engine.setitemattrtext (itemtype      => p_item_type,
                                       itemkey       => p_item_key,
                                       aname         => 'TTEC_HR_LOCAL_APPROVALS',
                                       avalue        => v_rolename
                                      );
         END IF;
      END IF;

      RESULT := 'COMPLETE:Y';
   END;

-------------------------------------------------------------------------

   ------------------------------------------------------
   PROCEDURE generatesuptransferfyilist (
      p_item_type   IN              VARCHAR2,
      p_item_key    IN              VARCHAR2,
      p_act_id      IN              NUMBER,
      funmode       IN              VARCHAR2,
      RESULT        OUT NOCOPY      VARCHAR2
   )
   IS
      v_process_name           VARCHAR2 (100);
      v_new_sup_id             NUMBER;
      v_old_sup_id             NUMBER;
      v_country                hr_locations.country%TYPE;
      v_olduserslist           VARCHAR2 (1000);
      v_newuserslist           VARCHAR2 (1000);
      v_oldrolename            VARCHAR2 (100);
      v_newrolename            VARCHAR2 (100);
      role_name                VARCHAR2 (100);
      role_display_name        VARCHAR2 (200);
      p_calledfrom             VARCHAR2 (200);
      tempresponsibilityname   VARCHAR2 (100);
   BEGIN
      v_process_name :=
         wf_engine.getitemattrtext (itemtype      => p_item_type,
                                    itemkey       => p_item_key,
                                    aname         => 'PROCESS_NAME'
                                   );

      IF v_process_name IN ('TTEC_HR_MANAGER_JSP_PRC')
      THEN
-- Generate HR Locals List
         p_calledfrom :=
            wf_engine.getitemattrtext (itemtype      => p_item_type,
                                       itemkey       => p_item_key,
                                       aname         => 'P_CALLED_FROM'
                                      );
         v_old_sup_id :=
            gettransactionvalue (p_item_type,
                                 p_item_key,
                                 'P_SELECTED_PERSON_OLD_SUP_ID',
                                 p_calledfrom
                                );
         v_new_sup_id :=
            gettransactionvalue (p_item_type,
                                 p_item_key,
                                 'P_SELECTED_PERSON_SUP_ID',
                                 p_calledfrom
                                );
         v_country := getcountry (v_old_sup_id);
         v_olduserslist :=
            ttec_adhoc_hr_local (v_old_sup_id,
                                 'TTEC_' || v_country || '_OSC_USER'
                                );
         v_olduserslist :=
                  v_olduserslist || ',' || v_old_sup_id || ',' || v_new_sup_id;

         IF getlocationid (v_new_sup_id) != getlocationid (v_old_sup_id)
         THEN
            v_country := getcountry (v_new_sup_id);
            v_newuserslist :=
               ttec_adhoc_hr_local (v_new_sup_id,
                                    'TTEC_' || v_country || '_OSC_USER'
                                   );
         END IF;

         IF LENGTH (v_newuserslist) > 3
         THEN
            -- create adhoc role
            v_newuserslist := RTRIM (v_newuserslist, ',');
            g_locationname := getlocationname (getlocationid (v_new_sup_id));

            IF TRIM (LENGTH (g_locationname)) = 0
            THEN
               g_locationname := getlocationnamepid (v_new_sup_id);
            END IF;

            role_display_name :=
                  'Teletech Local OSC approvers('
               || g_locationname
               || '-'
               || p_item_key
               || ')';
            wf_directory.createadhocrole
               (role_name,                 --          in out nocopy varchar2,
                role_display_name,           --       in out nocopy  varchar2,
                '',       --language                in  varchar2 default null,
                '',       --territory               in  varchar2 default null,
                '',       --role_description        in  varchar2 default null,
                'MAILHTML',
                     --notification_preference in varchar2 default 'MAILHTML',
                v_newuserslist,
                          --role_users              in  varchar2 default null,
                '',       --email_address           in  varchar2 default null,
                '',       --fax                     in  varchar2 default null,
                'ACTIVE',
                      --status                  in  varchar2 default 'ACTIVE',
                TRUNC (SYSDATE + 14),
                              --expiration_date         in  date default null,
                '',       -- parent_orig_system      in varchar2 default null,
                '',         -- parent_orig_system_id   in number default null,
                ''         --owner_tag               in  varchar2 default null
               );
            v_newrolename := role_name;
            hr_approval_wf.create_item_attrib_if_notexist
                                     (p_item_type      => p_item_type,
                                      p_item_key       => p_item_key,
                                      p_name           => 'TTEC_REC_OSC_LOCAL_APPROVALS'
                                     );
            wf_engine.setitemattrtext
                                     (itemtype      => p_item_type,
                                      itemkey       => p_item_key,
                                      aname         => 'TTEC_REC_OSC_LOCAL_APPROVALS',
                                      avalue        => v_newrolename
                                     );
         END IF;

         IF LENGTH (v_olduserslist) > 3
         THEN
            -- create adhoc role
            v_olduserslist := RTRIM (v_olduserslist, ',');
            g_locationname := getlocationname (getlocationid (v_old_sup_id));

            IF TRIM (LENGTH (g_locationname)) = 0
            THEN
               g_locationname := getlocationnamepid (v_old_sup_id);
            END IF;

            role_display_name :=
                  'Teletech Local OSC approvers('
               || g_locationname
               || '-'
               || p_item_key
               || ')';
            wf_directory.createadhocrole
               (role_name,                 --          in out nocopy varchar2,
                role_display_name,           --       in out nocopy  varchar2,
                '',       --language                in  varchar2 default null,
                '',       --territory               in  varchar2 default null,
                '',       --role_description        in  varchar2 default null,
                'MAILHTML',
                     --notification_preference in varchar2 default 'MAILHTML',
                v_olduserslist,
                          --role_users              in  varchar2 default null,
                '',       --email_address           in  varchar2 default null,
                '',       --fax                     in  varchar2 default null,
                'ACTIVE',
                      --status                  in  varchar2 default 'ACTIVE',
                TRUNC (SYSDATE + 10),
                              --expiration_date         in  date default null,
                '',       -- parent_orig_system      in varchar2 default null,
                '',         -- parent_orig_system_id   in number default null,
                ''         --owner_tag               in  varchar2 default null
               );
            v_oldrolename := role_name;
            hr_approval_wf.create_item_attrib_if_notexist
                                     (p_item_type      => p_item_type,
                                      p_item_key       => p_item_key,
                                      p_name           => 'TTEC_OLD_OSC_LOCAL_APPROVALS'
                                     );
            wf_engine.setitemattrtext
                                     (itemtype      => p_item_type,
                                      itemkey       => p_item_key,
                                      aname         => 'TTEC_OLD_OSC_LOCAL_APPROVALS',
                                      avalue        => v_oldrolename
                                     );
         END IF;
      END IF;

      RESULT := 'COMPLETE:Y';
   END;

-------------------------------------------------------------------
   PROCEDURE createadhocuser (
      p_item_type   IN              VARCHAR2,
      p_item_key    IN              VARCHAR2,
      p_act_id      IN              NUMBER,
      funmode       IN              VARCHAR2,
      RESULT        OUT NOCOPY      VARCHAR2
   )
   IS
      adhocuser      VARCHAR2 (50);
      NAME           VARCHAR2 (43);
      display_name   VARCHAR2 (43);
   BEGIN
      wf_directory.createadhocuser
                     (NAME,
                      display_name,
                      '', --language                in  varchar2 default null,
                      '', --territory               in  varchar2 default null,
                      '', --role_description        in  varchar2 default null,
                      'MAILHTML',
                      'mmestetskiy@xcelicor.com',         -- email           ,
                      '',                          --fax                     ,
                      '',                          --status                  ,
                      '',                          --expiration_date         ,
                      'HCM',                       --parent_orig_system      ,
                      ''
                     );                            --parent_orig_system_id ) ;
      hr_approval_wf.create_item_attrib_if_notexist
                                              (p_item_type      => p_item_type,
                                               p_item_key       => p_item_key,
                                               p_name           => 'TTEC_TERM_DIST_LIST'
                                              );
      wf_engine.setitemattrtext (itemtype      => p_item_type,
                                 itemkey       => p_item_key,
                                 aname         => 'TTEC__TERM_DIST_LIST',
                                 avalue        => NAME
                                );
      RESULT := 'COMPLETE:Y';
   END createadhocuser;

-------------------------------------------------------------------
   PROCEDURE ttech_next_approver (
      p_item_type   IN              VARCHAR2,
      p_item_key    IN              VARCHAR2,
      p_act_id      IN              NUMBER,
      funmode       IN              VARCHAR2,
      RESULT        OUT NOCOPY      VARCHAR2
   )
   IS
      newsupid                   per_all_people_f.person_id%TYPE;
      newsupname                 per_all_people_f.full_name%TYPE;
      newsupusername             fnd_user.user_name%TYPE;
      nextapproverid             per_all_people_f.person_id%TYPE;
      nextapproverfullname       per_all_people_f.full_name%TYPE;
      nextusername               fnd_user.user_name%TYPE;
      currentpersonid            per_all_people_f.person_id%TYPE;
      currentpersondisplayname   per_all_people_f.full_name%TYPE;
      currentpersonusername      fnd_user.user_name%TYPE;
      p_calledfrom               VARCHAR2 (300);
      DEBUG                      VARCHAR2 (100);
   BEGIN
      p_calledfrom :=
         wf_engine.getitemattrtext (itemtype      => p_item_type,
                                    itemkey       => p_item_key,
                                    aname         => 'P_CALLED_FROM'
                                   );
      newsupid :=
         gettransactionvalue (p_item_type,
                              p_item_key,
                              'P_SELECTED_PERSON_SUP_ID',
                              p_calledfrom
                             );
      currentpersonid :=
         wf_engine.getitemattrnumber (itemtype      => p_item_type,
                                      itemkey       => p_item_key,
                                      aname         => 'FORWARD_TO_PERSON_ID'
                                     );

      SELECT full_name
        INTO currentpersondisplayname
        FROM per_all_people_f
       WHERE person_id = currentpersonid
         AND SYSDATE BETWEEN effective_start_date AND effective_end_date;

      SELECT user_name
        INTO currentpersonusername
        FROM fnd_user
       WHERE employee_id = currentpersonid
         AND SYSDATE < NVL (end_date, SYSDATE + 1);

/*         wf_engine.setItemAttrNumber (
            itemtype => p_item_type
           ,itemkey  => p_item_Key
           ,aname    => 'FORWARD_FROM_PERSON_ID'
           ,avalue   => currentPersonId );


           wf_engine.setItemAttrText (
            itemtype => p_item_type
           ,itemkey  => p_item_Key
           ,aname    => 'FORWARD_FROM_DISPLAY_NAME'
           ,avalue   => currentPersonDisplayName );


           wf_engine.setItemAttrText (
            itemtype => p_item_type
           ,itemkey  => p_item_Key
           ,aname    => 'FORWARD_FROM_USERNAME'
           ,avalue   => currentPersonUserName );

*/
      nextapproverid := getsupervisor (currentpersonid);
      nextapproverfullname := getpersonfullname (nextapproverid);

      SELECT user_name
        INTO nextusername
        FROM fnd_user
       WHERE employee_id = nextapproverid
         AND SYSDATE < NVL (end_date, SYSDATE + 1)
         AND ROWNUM < 2;

      wf_engine.setitemattrnumber (itemtype      => p_item_type,
                                   itemkey       => p_item_key,
                                   aname         => 'FORWARD_TO_PERSON_ID',
                                   avalue        => nextapproverid
                                  );
      wf_engine.setitemattrtext (itemtype      => p_item_type,
                                 itemkey       => p_item_key,
                                 aname         => 'FORWARD_TO_DISPLAY_NAME',
                                 avalue        => nextapproverfullname
                                );
      wf_engine.setitemattrtext (itemtype      => p_item_type,
                                 itemkey       => p_item_key,
                                 aname         => 'FORWARD_TO_USERNAME',
                                 avalue        => nextusername
                                );
      RESULT := 'COMPLETE:';
       --commit;
/*
   */

   --commit;
   EXCEPTION
      WHEN OTHERS
      THEN
         DEBUG := DEBUG || ' ' || SUBSTR (SQLERRM, 1, 70);
         mydebug ('Exception ' || DEBUG);
         --commit;
         RESULT := 'ERROR';
   END ttech_next_approver;

-------------------------------------------------------------------
   FUNCTION getpayruledescription (
      p_business_group_id   NUMBER,
      p_location_id         VARCHAR2,
      p_department          VARCHAR2,
      p_table               VARCHAR2
   )
      RETURN VARCHAR2
   IS
      v_lookuprecord       lookuprecord_type;
      lookuprecord_table   lookuprecord_tabletype;
      ilookupcount         NUMBER                 := 0;
      temptable            v_t_type;
      meaningtable         v_t_type;
      descriptiontable     v_t_type;
      retline              VARCHAR2 (500);
      v_lr                 lookuprecord_type;
      b                    VARCHAR2 (50)        := TRIM (p_business_group_id);
      l                    VARCHAR2 (50)          := TRIM (p_location_id);
      d                    VARCHAR2 (50)          := TRIM (p_department);
      s                    VARCHAR2 (1)           := '*';
   BEGIN
      getlookupvalues (lookuprecord_table, p_table);
      temptable (1) := b || ':' || l || ':' || d;
      temptable (2) := b || ':' || s || ':' || d;
      temptable (3) := s || ':' || s || ':' || d;
      temptable (4) := s || ':' || l || ':' || d;
      temptable (5) := b || ':' || l || ':' || s;
      temptable (6) := b || ':' || s || ':' || s;
      temptable (7) := s || ':' || s || ':' || s;
      meaningtable (1) := '';
      meaningtable (2) := '';
      meaningtable (3) := '';
      meaningtable (4) := '';
      meaningtable (5) := '';
      meaningtable (6) := '';
      meaningtable (7) := '';
      descriptiontable (1) := '';
      descriptiontable (2) := '';
      descriptiontable (3) := '';
      descriptiontable (4) := '';
      descriptiontable (5) := '';
      descriptiontable (6) := '';
      descriptiontable (7) := '';

      FOR j IN lookuprecord_table.FIRST .. lookuprecord_table.LAST
      LOOP
         v_lr := lookuprecord_table (j);

         FOR k IN 1 .. temptable.LAST
         LOOP
            mydebug ('D1:=' || v_lr.lookup_code || '-' || temptable (k));

            IF v_lr.lookup_code = temptable (k)
            THEN
               mydebug ('Found:' || v_lr.lookup_code || ' '
                        || v_lr.description
                       );
               meaningtable (k) := v_lr.description;
               descriptiontable (k) := v_lr.meaning;
               retline := v_lr.description;
               g_wf_role_description := descriptiontable (k);
            END IF;
         END LOOP;
      END LOOP;

      RETURN retline;
   END getpayruledescription;

-------------------------------------------------------------------
   PROCEDURE getpayapproverrulesgrades (
      p_lookup_records     IN       lookuprecord_tabletype,
      p_paygradepercent             NUMBER,
      p_paysalarypercent            NUMBER,
      p_results            OUT      lookuprecord_tabletype
   )
   IS
      v_tempgrades         v_t_type;
      v_tempcomponents     v_t_type;
      v_lookuprecord       lookuprecord_type;
      v_lowgrade           NUMBER;
      v_highgrade          NUMBER;
      v_lowsalary          NUMBER;
      v_highsalary         NUMBER;
      v_count              NUMBER                 := 0;
      v_gradecomponent     VARCHAR2 (50);
      v_salarycomponent    VARCHAR2 (50);
      v_rettable           lookuprecord_tabletype;
      v_paygradepercent    NUMBER                 := p_paygradepercent;
      v_paysalarypercent   NUMBER                 := p_paysalarypercent;
   BEGIN
      mydebug ('Start 1001 ' || p_paygradepercent || '-' || p_paysalarypercent
              );
      mydebug ('Table lookup has ' || p_lookup_records.COUNT || ' records');

      FOR j IN p_lookup_records.FIRST .. p_lookup_records.LAST
      LOOP
         v_lookuprecord := p_lookup_records (j);
         v_tempcomponents :=
            teltec_custom_wf_utility.getstrings (v_lookuprecord.lookup_code,
                                                 '.'
                                                );
         v_gradecomponent := v_tempcomponents (1);
         v_salarycomponent := v_tempcomponents (2);
         mydebug ('SVP ' || v_gradecomponent || '-' || v_salarycomponent);
         v_tempcomponents :=
                   teltec_custom_wf_utility.getstrings (v_gradecomponent, '-');
         mydebug (v_tempcomponents (1) || '===' || v_tempcomponents (2));
         v_lowgrade := TO_NUMBER (v_tempcomponents (1));
         v_highgrade := TO_NUMBER (v_tempcomponents (2));

         IF v_highgrade = 100
         THEN
            v_highgrade := 100000;
         END IF;

         v_tempcomponents :=
                  teltec_custom_wf_utility.getstrings (v_salarycomponent, '-');
         v_lowsalary := TO_NUMBER (v_tempcomponents (1));
         v_highsalary := TO_NUMBER (v_tempcomponents (2));

         IF v_highsalary = 100
         THEN
            v_highsalary := 100000;
         END IF;

         mydebug (   'Percent SALARY'
                  || v_lowsalary
                  || '-'
                  || v_highsalary
                  || ' p_salPerc'
                  || p_paysalarypercent
                  || '<'
                 );
         mydebug (   'Perccent Grade'
                  || v_lowgrade
                  || '-'
                  || v_highgrade
                  || ' p_salGrade: '
                  || p_paygradepercent
                  || '<'
                 );

         IF v_paygradepercent <= 0
         THEN
            v_paygradepercent := 0.1;
         END IF;

         IF v_paysalarypercent <= 0
         THEN
            v_paysalarypercent := 0.1;
         END IF;

         IF     (    (CEIL (v_paygradepercent) >= v_lowgrade)
                 AND (v_paygradepercent <= v_highgrade)
                )
            AND (    (CEIL (v_paysalarypercent) >= v_lowsalary)
                 AND (v_paysalarypercent <= v_highsalary)
                )
         THEN
            mydebug (   'SVP found rule'
                     || v_lowsalary
                     || '-'
                     || v_highsalary
                     || ' p_salPerc'
                     || p_paysalarypercent
                     || '<'
                     || v_paygradepercent
                    );
            v_count := v_count + 1;
            v_rettable (v_count) := v_lookuprecord;
            EXIT;
         ELSE
            mydebug (   'NO MATC Salary:'
                     || v_lowsalary
                     || '-'
                     || v_highsalary
                     || ' Grade '
                     || v_lowgrade
                     || '-'
                     || v_highgrade
                     || '->'
                     || p_paysalarypercent
                    );
         END IF;
      END LOOP;

      p_results := v_rettable;
      mydebug ('dONE 201');
   END getpayapproverrulesgrades;

-------------------------------------------------------------------
   PROCEDURE generatecurrentosc (
      p_item_type   IN              VARCHAR2,
      p_item_key    IN              VARCHAR2,
      p_act_id      IN              NUMBER,
      funmode       IN              VARCHAR2,
      RESULT        OUT NOCOPY      VARCHAR2
   )
   IS
   BEGIN
      NULL;
   END generatecurrentosc;

-- bulds the second layer of approvals- called from Workflow
-------------------------------------------------------------------
   PROCEDURE buildpaychangeapproversrole (
      p_item_type   IN              VARCHAR2,
      p_item_key    IN              VARCHAR2,
      p_act_id      IN              NUMBER,
      funmode       IN              VARCHAR2,
      RESULT        OUT NOCOPY      VARCHAR2
   )
   IS
      v_process_name            VARCHAR2 (100);
      v_person_id               NUMBER;
      v_country                 hr_locations.country%TYPE;
      v_userslist               VARCHAR2 (1000);
      v_userssrhrlist           VARCHAR2 (1000);
      v_rolename                VARCHAR2 (100);
      v_locationid              NUMBER;
      v_glcode                  VARCHAR2 (100);
      v_generalresponsibility   fnd_lookup_values.meaning%TYPE   := '';
      v_localresponsibility     fnd_lookup_values.meaning%TYPE   := '';
      v_localboolean            BOOLEAN                          := FALSE;
      role_name                 VARCHAR2 (100);
      role_display_name         VARCHAR2 (200);
      p_calledfrom              VARCHAR2 (200);
      v_lookuprecord            lookuprecord_type;
      lookuprecord_table        lookuprecord_tabletype;
      ilookupcount              NUMBER                           := 0;
      v_table1                  v_t_type;
      v_table2                  v_t_type;
      v_tempuser                VARCHAR2 (30);
      v_srusers                 VARCHAR2 (1000);
      v_insert                  BOOLEAN                          := FALSE;
      v_count                   NUMBER                           := 0;
      v_attributeroutevalue     VARCHAR2 (100);
      v_tempstring              VARCHAR2 (1000)                  := '';
      v_tempnumber              NUMBER;
      v_number                  NUMBER;
      v_varchar                 VARCHAR2 (200);
      v_nextdisplayname         VARCHAR2 (100);
      v_personid                NUMBER;
--futl utl_file.file_type;
   BEGIN
      mydebug ('Start Pay CHange 1');
      -- futl :=utl_file.fopen('/usr/tmp','wf-3','a');

      -- utl_file.put_line(futl,'PayAhcngeBuilder '||p_item_type||'-'||p_item_key);
      v_process_name :=
         wf_engine.getitemattrtext (itemtype      => p_item_type,
                                    itemkey       => p_item_key,
                                    aname         => 'PROCESS_NAME'
                                   );
      -- utl_file.put_line(futl,'PayAhcngeBuilder 1 '||p_item_type||'-'||p_item_key);
      mydebug (p_item_key || ' Start Pay Change approvers role ');

      -- utl_file.put_line(futl,'PayAhcngeBuilder 2 '||p_item_type||'-'||p_item_key);
      -- utl_file.put_line(futl,'PayAhcngeBuilder 2A '||v_process_name||' '||p_item_type||'-'||p_item_key);

      --    getLookupValues(LookupRecord_Table,'TTEC_WORKFLOW_HCM_APPROVER_RSP');
      IF v_process_name IN
            ('TTEC_HR_P_RATE_JSP_PRC', 'TELTEC_HR_P_RATE_JSP_PRC',
             'TELETECH_HR_P_RATE_JSP_PRC', 'TELETECH_HR_EMP_S_CHG_JSP_PRC')
      THEN
-- Generate HR Locals List
         p_calledfrom :=
            wf_engine.getitemattrtext (itemtype      => p_item_type,
                                       itemkey       => p_item_key,
                                       aname         => 'P_CALLED_FROM'
                                      );
         v_person_id :=
            wf_engine.getitemattrnumber (itemtype      => p_item_type,
                                         itemkey       => p_item_key,
                                         aname         => 'CURRENT_PERSON_ID'
                                        );
         mydebug (p_item_key || ' Step 106 ' || v_userslist);

         -- utl_file.put_line(futl,'PayAhcngeBuilder 4 '||p_item_type||'-'||p_item_key);
         BEGIN
            v_userslist := findnextpersonorgrouppay (p_item_type, p_item_key);
         EXCEPTION
            WHEN OTHERS
            THEN
               -- utl_file.put_line(futl,'Exception 4 '||p_item_type||'-'||p_item_key||' '||substr(SQLERRM,1,100));
                --   utl_file.fclose(futl);
               NULL;
         END;

         mydebug (p_item_key || ' Step 105 ' || v_userslist);
         --  utl_file.put_line(futl,p_item_key|| ' Step 105 '||v_usersList);

         --       v_attributeRouteValue := substr(v_usersList,1,instr(v_usersList,':')-1);
         v_attributeroutevalue := v_userslist;
         --v_usersList := substr(v_usersList,instr(v_usersList,':')+1);
         hr_approval_wf.create_item_attrib_if_notexist
                                        (p_item_type      => p_item_type,
                                         p_item_key       => p_item_key,
                                         p_name           => 'TTEC_HR_TERMINATION_ROUTE'
                                        );
         wf_engine.setitemattrtext (itemtype      => p_item_type,
                                    itemkey       => p_item_key,
                                    aname         => 'TTEC_HR_TERMINATION_ROUTE',
                                    avalue        => v_attributeroutevalue
                                   );
-- Process users list and find SR level Human Capital
         v_table1 := getstrings (v_userslist, ',');
         mydebug (   '250 '
                  || p_item_key
                  || ' '
                  || v_userslist
                  || ' table count '
                  || v_table1.COUNT
                 );
         -- utl_file.put_line(futl,'250 '||p_item_key||' '||v_usersList||' table count '||v_table1.count);
         v_srusers := '';
         mydebug ('Value ' || v_table1 (1));

         FOR u IN 1 .. v_table1.LAST
         LOOP
            --v_tempNumber :=to_number(v_table1(u));
            mydebug (p_item_key || ' ' || 'D10=' || v_table1 (u));
            v_srusers := v_srusers || v_table1 (u) || ',';
            v_tempstring := '';
         END LOOP;

-- Identify Sr Human Capitals
-- Remove duplicated users and current person id
--       v_table1 := getStrings(v_srUsers,',');
         v_srusers := RTRIM (v_srusers, ',');
         mydebug ('D55=' || v_srusers);
-- 1128 mark
         v_table1 := getstrings (v_srusers, ',');
         v_tempstring := v_table1 (1);

         SELECT user_id, user_name
           INTO v_number, v_tempuser
           FROM fnd_user
          WHERE user_name = v_tempstring
            AND SYSDATE < NVL (end_date, SYSDATE + 1);

         v_tempstring := '';
         mydebug (' D56=' || v_number || '-' || v_tempuser);
          -- utl_file.put_Line(futl,'PayChange userId='||v_number);
/*
    wf_engine.setItemAttrText (
            itemtype => p_item_type
           ,itemkey  => p_item_Key
           ,aname    => 'FORWARD_TO_USERNAME'
           ,avalue   => v_tempUser );
*/
         mydebug ('PayChange userId=' || v_number);

         SELECT COUNT (1)
           INTO v_count
           FROM ttec_temp_wf
          WHERE item_type = p_item_type
            AND item_key = p_item_key
            AND ROWNUM < 2
            AND KEY = 'APPROVAL2';

         IF v_count = 0
         THEN
            INSERT INTO ttec_temp_wf
                        (item_type, item_key, VALUE, line_number, KEY
                        )
                 VALUES (p_item_type, p_item_key, v_number, 1, 'APPROVAL2'
                        );
         END IF;

--   setup initial forward attributes
         SELECT u.employee_id, u.user_name, a.VALUE
           INTO v_number, v_varchar, v_tempstring
           FROM ttec_temp_wf a, fnd_user u
          WHERE a.item_type = p_item_type
            AND a.KEY = 'APPROVAL1'
            AND a.item_key = p_item_key
--               and a.line_number=1
            AND u.user_id = a.VALUE
            AND ROWNUM < 2;

         -- utl_file.put_Line(futl,'PayChange emplId='||v_number||' uId='||v_tempString||' uName='||v_varchar);
         wf_engine.setitemattrtext (itemtype      => p_item_type,
                                    itemkey       => p_item_key,
                                    aname         => 'FORWARD_TO_USERNAME',
                                    avalue        => v_varchar
                                   );

         SELECT full_name
           INTO v_varchar
           FROM per_all_people_f
          WHERE SYSDATE BETWEEN effective_start_date AND effective_end_date
            AND person_id = v_number;

         -- utl_file.put_Line(futl,'PayChange FUllName='||v_varchar);

         --                utl_file.fclose(futl);
         wf_engine.setitemattrnumber (itemtype      => p_item_type,
                                      itemkey       => p_item_key,
                                      aname         => 'FORWARD_TO_PERSON_ID',
                                      avalue        => v_number
                                     );
         wf_engine.setitemattrtext (itemtype      => p_item_type,
                                    itemkey       => p_item_key,
                                    aname         => 'FORWARD_TO_DISPLAY_NAME',
                                    avalue        => v_varchar
                                   );
         v_number :=
            wf_engine.getitemattrnumber (itemtype      => p_item_type,
                                         itemkey       => p_item_key,
                                         aname         => 'CREATOR_PERSON_ID'
                                        );

         SELECT user_name
           INTO v_varchar
           FROM fnd_user
          WHERE employee_id = v_number
            AND SYSDATE < NVL (end_date, SYSDATE + 1)
            AND ROWNUM < 2;

         wf_engine.setitemattrnumber (itemtype      => p_item_type,
                                      itemkey       => p_item_key,
                                      aname         => 'FORWARD_FROM_PERSON_ID',
                                      avalue        => v_number
                                     );
         wf_engine.setitemattrtext (itemtype      => p_item_type,
                                    itemkey       => p_item_key,
                                    aname         => 'FORWARD_FROM_USERNAME',
                                    avalue        => v_varchar
                                   );

         SELECT full_name
           INTO v_varchar
           FROM per_all_people_f
          WHERE SYSDATE BETWEEN effective_start_date AND effective_end_date
            AND person_id = v_number;

         wf_engine.setitemattrtext (itemtype      => p_item_type,
                                    itemkey       => p_item_key,
                                    aname         => 'FORWARD_FROM_DISPLAY_NAME',
                                    avalue        => v_varchar
                                   );
/*
      Begin

      select full_name,person_id
      into v_nextDisplayName,v_personId
      from per_all_people_f
      where person_id = (select employee_id from fnd_user
                         where user_name = v_srUsers
                     and sysdate < nvl(end_date,sysdate+1))
         and sysdate between effective_start_date and effective_end_date;



      Exception
      When Others Then
         NULL;
        End;



         myDebug(p_item_key||' '||'D11='||v_srUsers);

         if length(v_srUsers)>3 Then
  -- create adhoc role
             WF_DIRECTORY.CreateAdHocRole(role_name ,--          in out nocopy varchar2,
                      role_display_name, --       in out nocopy  varchar2,
                      'AMERICAN',--language                in  varchar2 default null,
                      '',--territory               in  varchar2 default null,
                      '',--role_description        in  varchar2 default null,

                      'MAILHTML',--notification_preference in varchar2 default 'MAILHTML',
                      v_srUsers, --role_users              in  varchar2 default null,
                      '', --email_address           in  varchar2 default null,
                      '',--fax                     in  varchar2 default null,
                      'ACTIVE', --status                  in  varchar2 default 'ACTIVE',
                      trunc(sysdate+1), --expiration_date         in  date default null,
                      '',-- parent_orig_system      in varchar2 default null,
                      '',-- parent_orig_system_id   in number default null,
                      '' --owner_tag               in  varchar2 default null
                 );
            myDebug(p_item_key||' '||'D12='||v_srUsers||' '||role_name);
           v_roleName:=role_name;

         Hr_Approval_Wf.create_item_attrib_if_notexist
                  (p_item_type  => p_item_type
                  ,p_item_key   => p_item_key
                  ,p_name   => 'TTEC_HR_LOCAL_APPROVALS');

          wf_engine.SetItemAttrText ( itemtype  => p_item_type,
                                itemkey     => p_item_key,
                                aname       => 'TTEC_HR_LOCAL_APPROVALS',
                                avalue      => rtrim(v_srUsers,',') );




       wf_engine.getItemAttrNumber (
            itemtype => p_item_type
           ,itemkey  => p_item_Key
           ,aname    => 'FORWARD_TO_PERSON_ID');



             wf_engine.setItemAttrNumber (
            itemtype => p_item_type
           ,itemkey  => p_item_Key
           ,aname    => 'FORWARD_FROM_PERSON_ID'
           ,avalue   => v_number );


         v_varchar := wf_engine.getItemAttrText (
            itemtype => p_item_type
           ,itemkey  => p_item_Key
           ,aname    => 'FORWARD_TO_USER_NAME');

          wf_engine.setItemAttrText (
            itemtype => p_item_type
           ,itemkey  => p_item_Key
           ,aname    => 'FORWARD_FROM_USER_NAME',
          avalue => v_varchar);

         v_varchar := wf_engine.getItemAttrText (
            itemtype => p_item_type
           ,itemkey  => p_item_Key
           ,aname    => 'FORWARD_TO_DISPLAY_NAME');

          wf_engine.setItemAttrText (
            itemtype => p_item_type
           ,itemkey  => p_item_Key
           ,aname    => 'FORWARD_FROM_DISPLAY_NAME',
          avalue => v_varchar);




      mydebug('Before update '||wf_engine.GetItemAttrText ( itemtype => p_item_type,
                                itemkey     => p_item_key,
                               aname       => 'FORWARD_TO_DISPLAY_NAME'));

         wf_engine.SetItemAttrText ( itemtype  => p_item_type,
                                itemkey     => p_item_key,
                                aname       => 'FORWARD_TO_DISPLAY_NAME',
                                avalue      => v_nextDisplayName );


         End If;
    */
      END IF;

      mydebug ('Complete ');
      RESULT := 'COMPLETE:Y';
   -- utl_file.fclose(futl);
   EXCEPTION
      WHEN OTHERS
      THEN
         mydebug ('Exce in buildPayChange ' || SUBSTR (SQLERRM, 1, 150));
/*if utl_file.is_open(futl) Then

utl_file.put_line(futl,'Exce in buildPayChange '||substr(SQLERRM,1,150));
Else
futl :=utl_file.fopen('/usr/tmp','wf-3','a');
utl_file.put_line(futl,'Exce in buildPayChange '||substr(SQLERRM,1,150));

utl_file.fclose(futl);
End If;
*/
   END buildpaychangeapproversrole;

-- find next person that are secnd level apprvoals
-- called from Build routine
-------------------------------------------------------------------
   FUNCTION findnextpersonorgrouppay (p_item_type VARCHAR2, p_item_key VARCHAR2)
      RETURN VARCHAR2
   IS
      retvalue                VARCHAR2 (50);
      v_location              VARCHAR2 (100);
      v_businessgroupid       NUMBER;
      v_payruledescription    VARCHAR2 (150);
      --v_department            hr.pay_cost_allocation_keyflex.segment3%TYPE;				-- Commented code by IXPRAVEEN-ARGANO,15-May-2023
      v_department            apps.pay_cost_allocation_keyflex.segment3%TYPE;                 --  code Added by IXPRAVEEN-ARGANO,   15-May-2023
      v_lr                    lookuprecord_type;
      v_country               VARCHAR2 (30);
      v_meaning               fnd_lookup_values.meaning%TYPE;
      v_lookupcode            fnd_lookup_values.lookup_code%TYPE;
      v_description           fnd_lookup_values.description%TYPE;
      v_recordidentified      BOOLEAN                                := FALSE;

      TYPE temptabletype IS TABLE OF VARCHAR2 (100)
         INDEX BY BINARY_INTEGER;

      temptable               temptabletype;
      meaningtable            temptabletype;
      v_temptable             v_t_type;
      v_templocations         v_t_type;
      v_hierarchy             VARCHAR2 (200);
      v_rulelookup            VARCHAR2 (200);
      v_responsibility        BOOLEAN                                := FALSE;
      v_job_code              BOOLEAN                                := FALSE;
      v_supervisor            BOOLEAN                                := FALSE;
      v_jobcodevalue          VARCHAR2 (50);
      v_responsibilityvalue   VARCHAR2 (50);
      v_approversstring       VARCHAR2 (1000);
      v_attributeroutevalue   VARCHAR2 (100)                            := '';
      v_lookuprecord          teltec_custom_wf_utility.lookuprecord_type;
      lookuprecord_table      lookuprecord_tabletype;
      v_approversruletable    lookuprecord_tabletype;
      v_approversrulerecord   lookuprecord_type;
      ilookupcount            NUMBER                                     := 0;
      v_personid              NUMBER;
      p_person_id             NUMBER;
      v_supervisorid          NUMBER;
      v_supervisorusername    VARCHAR2 (50);
      v_salarypercentchange   NUMBER                                     := 0;
      v_gradepercentchange    NUMBER                                     := 0;
      v_routedescription      VARCHAR2 (1000);
      v_routeid               VARCHAR2 (100);
      v_transactionid         NUMBER;
      p_paygradepercent       NUMBER;
      p_paysalarypercent      NUMBER;
      v_userslist             VARCHAR2 (1000);
      v_userid                NUMBER;
--futl utl_file.file_type;
      v_debug                 VARCHAR2 (100)                         := '101';
      p_table                 VARCHAR2 (100);
      v_processname           VARCHAR2 (100);
      p_originalgradeid       VARCHAR2 (100);
      p_newgradeid            VARCHAR2 (100);
      p_effectivedate         DATE;
      p_graderecord           gradeinfo_type;
      p_personjobname         VARCHAR2 (100);
      v_userstable_temp       v_t_type;
      v_count                 NUMBER                                     := 0;
      v_tempstring            VARCHAR2 (100);
      v_newjob                VARCHAR2 (20);
      v_oldjob                VARCHAR2 (30);
      v_oldgradejobcode       VARCHAR2 (30);
      v_newgradejobcode       VARCHAR2 (30);
      v_oldlocationname       VARCHAR2 (50);
      v_newlocationname       VARCHAR2 (50);
      v_oldlocationid         VARCHAR2 (50);
      v_newlocationid         VARCHAR2 (50);
      v_oldgradename          VARCHAR2 (50);
      v_newgradename          VARCHAR2 (50);
   BEGIN
      --  futl :=utl_file.fopen('/usr/tmp','wf-findNP','a');
      -- utl_file.put_line(futl,'Start findN');
      v_transactionid :=
              getnumtransactionvaluefromitem (p_item_key, 'P_CHANGE_PERCENT');
      -- utl_file.put_line(futl,'Transaction '||v_transactionId);
      v_personid :=
         wf_engine.getitemattrnumber (itemtype      => p_item_type,
                                      itemkey       => p_item_key,
                                      aname         => 'CURRENT_PERSON_ID'
                                     );
      v_processname :=
         wf_engine.getitemattrtext (itemtype      => p_item_type,
                                    itemkey       => p_item_key,
                                    aname         => 'PROCESS_NAME'
                                   );
      mydebug ('FindNextPersonOrGroupPay Transaction Id ' || v_transactionid);
      p_paysalarypercent :=
         NVL (getnumtransactionvaluefromitem (p_item_key, 'P_CHANGE_PERCENT'),
              0
             );
      v_newjob :=
              NVL (getnumtransactionvaluefromitem (p_item_key, 'P_JOB_ID'), 0);
      v_oldjob := NVL (getoriginalnumtransvalue (p_item_key, 'P_JOB_ID'), 0);
      v_newlocationid :=
         NVL (getnumtransactionvaluefromitem (p_item_key, 'P_LOCATION_ID'), 0);
      v_oldlocationid :=
               NVL (getoriginalnumtransvalue (p_item_key, 'P_LOCATION_ID'), 0);
      -- utl_file.put_line(futl,'p_paySalaryPercent '||p_paySalaryPercent);
      p_paygradepercent := 0;
      p_effectivedate := getdatetransvalue (p_item_key, 'P_EFFECTIVE_DATE');
      mydebug ('Eff_Date=' || p_effectivedate);
      v_businessgroupid :=
         NVL (getnumtransactionvaluefromitem (p_item_key,
                                              'P_BUSINESS_GROUP_ID'
                                             ),
              0
             );

      BEGIN
         p_originalgradeid :=
                          getoriginalnumtransvalue (p_item_key, 'P_GRADE_ID');
         p_newgradeid :=
                    getnumtransactionvaluefromitem (p_item_key, 'P_GRADE_ID');
-- verify the grade throuhj jobcode and location
------  mark   01032007
         mydebug (v_oldjob || '-' || v_newjob);
         v_oldgradejobcode := getjobname (v_oldjob);
         v_newgradejobcode := getjobname (v_newjob);
         mydebug (v_oldgradejobcode || '-' || v_newgradejobcode);
         v_oldlocationname := getlocationname (v_oldlocationid);
         v_newlocationname := getlocationname (v_newlocationid);
         v_oldgradename := v_oldgradejobcode || '.' || v_oldlocationname;
         v_newgradename := v_newgradejobcode || '.' || v_newlocationname;
         mydebug (v_oldgradename || '-' || v_newgradename);
         p_originalgradeid := getgradeid (v_oldgradename, v_businessgroupid);
         p_newgradeid := getgradeid (v_newgradename, v_businessgroupid);

-- verify the grade throuhj jobcode and location
         UPDATE hr_api_transaction_values
            SET number_value = p_newgradeid
          WHERE transaction_step_id IN (
                           SELECT transaction_step_id
                             FROM hr_api_transaction_steps
                            WHERE item_type = 'HRSSA'
                                  AND item_key = p_item_key)
            AND NAME = 'P_GRADE_ID';

         UPDATE hr_api_transaction_values
            SET varchar2_value = v_newgradename
          WHERE transaction_step_id IN (
                           SELECT transaction_step_id
                             FROM hr_api_transaction_steps
                            WHERE item_type = 'HRSSA'
                                  AND item_key = p_item_key)
            AND NAME = 'P_GRADE_NAME';

------  mark   01032007
         IF NVL (p_newgradeid, -100) = -100
         THEN
            p_newgradeid := p_originalgradeid;
         END IF;
      EXCEPTION
         WHEN OTHERS
         THEN
            p_originalgradeid := 0;
            p_newgradeid := 0;
      END;

      mydebug ('orig Grade =' || p_originalgradeid);
      mydebug ('new Grade =' || p_newgradeid);

      IF p_originalgradeid = p_newgradeid
      THEN
         p_paygradepercent := 0;
      ELSE
         p_paygradepercent :=
            getgradepercentchange (p_originalgradeid,
                                   p_newgradeid,
                                   p_effectivedate
                                  );
      END IF;

      mydebug ('new Grade Percent Change =' || p_paygradepercent);
      p_person_id := v_personid;

      SELECT NAME
        INTO p_personjobname
        FROM per_jobs j, per_assignments_x x
       WHERE x.person_id = p_person_id
         AND j.job_id = x.job_id
         AND SYSDATE BETWEEN x.effective_start_date AND x.effective_end_date
         AND ROWNUM < 2;

-- tHIS IS THE PROCESS FOR THE SALARY CHANGE
-- PAG pay action guidelines
-- see in the functional document
      IF v_processname =
                  'TELETECH_HR_P_RATE_JSP_PRC'
                                              -- in case of salary change only
      THEN
         -- off cycle changes
         p_table := 'TTEC_WF_PAG_AGT_OFFCYCLE';
      ELSIF v_processname = 'TELETECH_HR_EMP_S_CHG_JSP_PRC'
      THEN
         -- USE THIS WHEN NO PROMOTION JUST SALARY INCREASE
          -- define the lookup tables
         IF v_newjob = v_oldjob AND p_paysalarypercent != 0
         THEN
            p_table := 'TTEC_WF_PAG_AGT_OFFCYCLE';
         ELSE
            -- regular changes
            p_table := 'TTEC_WF_PAG_AGT';
         END IF;
      END IF;

      mydebug ('Determined PAG - ' || p_table);
      -- populate the collecton based on the lookup
      getlookupvalues (lookuprecord_table, p_table);
      mydebug ('findnext : getLookupValues ');
          -- utl_file.put_line(futl,'100 findnext : getLookupValues ');
      -- define person dept and location
      v_department := getdepartmentnumber (p_person_id);
--    v_location   := getLocationId_1(p_person_id);
      v_location := getlocationid (p_person_id);

      -- special rules for site director, has to be approved by Corporate
      IF p_personjobname LIKE '20005%'
      THEN
         -- over write the location for site manager
         v_templocations :=
             getstrings (fnd_profile.VALUE ('TTEC_CORPORATE_LOCATIONS'), ':');

         FOR j IN 1 .. v_templocations.LAST
         LOOP
            v_tempstring := v_templocations (j);

            IF LENGTH (NVL (v_tempstring, 'X')) > 1
            THEN
               v_location := v_tempstring;
            END IF;
         END LOOP;
      END IF;

      -- define business group
      v_businessgroupid := getbusinessgroupid (p_person_id);
      mydebug (   'findnext :  '
               || v_department
               || '-'
               || v_location
               || '-'
               || v_businessgroupid
              );
      -- utl_file.put_line(futl,'101  :  '||v_department||'-'||v_location||'-'||v_businessGroupId);

      -- defined the the rule based on the above, location business group etc
      -- see the details in the functional document
      -- define next level of approval
      v_payruledescription :=
         getpayruledescription (v_businessgroupid,
                                v_location,
                                v_department,
                                p_table
                               );
      mydebug (v_payruledescription);
      -- utl_file.put_line(futl,'payDecr ='||v_payRuleDescription);

      -- jnext set of lookup values, get new collection
      getlookupvalues (lookuprecord_table, v_payruledescription);
      -- utl_file.put_line(futl,'102  :  '||LookupRecord_Table.count||'<');
      p_paygradepercent := NVL (p_paygradepercent, 0);
      -- have to choose the rules to use for this
      getpayapproverrulesgrades (lookuprecord_table,
                                 p_paygradepercent,
                                 p_paysalarypercent,
                                 v_approversruletable
                                );
      -- gives us the next approver
      v_country := getcountry (p_person_id);
      mydebug (' 202 ' || v_approversruletable.COUNT);

      -- utl_file.put_line (futl,' 202 '||v_approversRuleTable.COUNT);

      -- determine the branch for approvers
      FOR j IN v_approversruletable.FIRST .. v_approversruletable.LAST
      LOOP
         mydebug (   '203 Going through rules '
                  || v_approversruletable (j).description
                 );
         v_debug := '104';
-- utl_file.put_line(futl,'203 Going through rules '||v_approversRuleTable(j).description);
         v_approversrulerecord := v_approversruletable (j);
         mydebug ('Rule ' || v_approversrulerecord.description);

         -- utl_file.put_line(futl,'Rule '||v_approversRuleRecord.description);
         IF v_approversrulerecord.description LIKE '%JOBCD%'
         THEN
            v_debug := '105 ';
            -- based          if job code then
            v_routeid :=
                  'JOBCD-'
               || getjobcodeforpaychanges (v_approversrulerecord.description);
            mydebug ('JOBCD route ' || v_routeid);
            -- utl_file.put_line(futl,'JOBCD route '||v_routeId);
            v_debug := '106';
            -- second layer of approval
            v_userslist :=
               finduserinjobhierarchy (REPLACE (v_routeid, 'JOBCD-'),
                                       p_person_id
                                      );
-- Find OC member in case of SVP is missing in hierarchy
            mydebug ('S106 ' || v_userslist || '<');

            IF LENGTH (NVL (v_userslist, 'X')) < 4
            THEN
               v_userslist := findocinjobhierarchy (p_person_id);
            END IF;

            mydebug ('JOBCD route users ' || v_userslist);
            -- utl_file.put_line(futl,'JOBCD route users '||v_usersList);
            v_debug := '107';
            v_userslist := LTRIM (v_userslist, ',');
            v_userslist := RTRIM (v_userslist, ',');
            v_userstable_temp := getstrings (v_userslist, ',');
            v_userslist := '';

            FOR k IN 1 .. v_userstable_temp.LAST
            LOOP
               IF LENGTH (v_userstable_temp (k)) > 1
               THEN
                  v_tempstring := findusername (v_userstable_temp (k));
                  v_userslist := v_userslist || ',' || v_tempstring;
               END IF;
            END LOOP;

            v_userslist := LTRIM (v_userslist, ',');
            v_userslist := RTRIM (v_userslist, ',');
            mydebug ('Found approval users ' || v_userslist || '<');
         --  v_userId := to_number(rtrim(v_usersList,','));
         --   v_usersList := findUserName(v_userId);
         END IF;

-- if a perosn ID then do following
         v_debug := '107';

         IF v_approversrulerecord.description LIKE '%PERID%'
         THEN
            v_routeid :=
                  'PERID-'
               || getpersonidforpaychanges (v_approversrulerecord.description);
            mydebug (v_routeid);
            v_userslist :=
                          finduserfrompersonid (REPLACE (v_routeid, 'PERID-'));
            mydebug (v_userslist);
         -- v_userId := to_number(rtrim(v_usersList,','));

         -- v_usersList := findUserName(v_userId);
         END IF;

-- managment level
         v_debug := '108';

         IF v_approversrulerecord.description LIKE '%MLVL%'
         THEN
            v_routeid :=
                  'MLVL-'
               || getmanagerlevelforpaychanges
                                            (v_approversrulerecord.description);
            mydebug ('MLVL route ' || v_routeid || ' ' || p_person_id);
            -- utl_file.put_line(futl,'Rule '||'MLVL route '||v_routeId||' '||p_person_id);

            -- give us list of user names that are for approval
            v_userslist :=
               finduserinmgrlevelhierarchy (REPLACE (v_routeid, 'MLVL-'),
                                            p_person_id
                                           );
            mydebug ('MLVL route ' || v_userslist);
         -- utl_file.put_line(futl,'Rule 303 '||'MLVL route '||v_usersList);

         -- v_userId := to_number(rtrim(v_usersList,','));

         --v_usersList := findUserName(v_userId);
         END IF;

         mydebug ('Pay change ' || v_userslist);
      END LOOP;

      mydebug ('Result=' || v_hierarchy);
      -- utl_file.put_line(futl,v_debug||':'||'find NP Result='||V_usersList);
----------------------------------------------------
-----New Lookup Defined for the person------------------------
--------------------------------------------------------

      --utl_file.fclose(futl);
      RETURN v_userslist;
   EXCEPTION
      WHEN OTHERS
      THEN
-- utl_file.put_line(futl,'exception in fiundNP '||substr(SQLERRM,1,150));
-- utl_file.fclose(futl);
         NULL;
   END findnextpersonorgrouppay;

---------------------------------------------------------------------
-------------------------------------------------------------------
   FUNCTION getmanagerlevelforpaychanges (p_rulestring VARCHAR2)
      RETURN VARCHAR2
   IS
      retvalue       VARCHAR2 (100);
      v_temptable    v_t_type;
      v_finaltable   v_t_type;
   BEGIN
      mydebug (p_rulestring);
      v_temptable := getstrings (p_rulestring, '=');
      v_finaltable := getstrings (v_temptable (1), ':');
      retvalue := v_finaltable (2);
      RETURN retvalue;
   END getmanagerlevelforpaychanges;

-------------------------------------------------------------------
   FUNCTION getbusinessgroupid (p_person_id NUMBER)
      RETURN NUMBER
   IS
      retvalue   NUMBER;
   BEGIN
      SELECT business_group_id
        INTO retvalue
        FROM per_assignments_x
       WHERE person_id = p_person_id;

      RETURN retvalue;
   END getbusinessgroupid;

----------------------------------------------------------------------
   FUNCTION getoriginaltexttransvalue (p_item_key NUMBER, p_name VARCHAR2)
      RETURN VARCHAR2
   IS
      retvalue   VARCHAR2 (400);
   BEGIN
      SELECT original_varchar2_value
        INTO retvalue
        FROM hr_api_transaction_values
       WHERE transaction_step_id IN (
                           SELECT transaction_step_id
                             FROM hr_api_transaction_steps
                            WHERE item_type = 'HRSSA'
                                  AND item_key = p_item_key)
         AND NAME = p_name
         AND ROWNUM < 2;

      RETURN retvalue;
   END getoriginaltexttransvalue;

----------------------------------------------------------------------
   FUNCTION getoriginalnumtransvalue (p_item_key NUMBER, p_name VARCHAR2)
      RETURN NUMBER
   IS
      retvalue   NUMBER;
   BEGIN
      SELECT original_number_value
        INTO retvalue
        FROM hr_api_transaction_values
       WHERE transaction_step_id IN (
                           SELECT transaction_step_id
                             FROM hr_api_transaction_steps
                            WHERE item_type = 'HRSSA'
                                  AND item_key = p_item_key)
         AND NAME = p_name
         AND ROWNUM < 2;

      RETURN retvalue;
   EXCEPTION
      WHEN OTHERS
      THEN
         RETURN 0;
   END getoriginalnumtransvalue;

----------------------------------------------------------------------
   FUNCTION gettexttransactionvalue (p_item_key NUMBER, p_name VARCHAR2)
      RETURN VARCHAR2
   IS
      retvalue   VARCHAR2 (400);
   BEGIN
      SELECT varchar2_value
        INTO retvalue
        FROM hr_api_transaction_values
       WHERE transaction_step_id IN (
                           SELECT transaction_step_id
                             FROM hr_api_transaction_steps
                            WHERE item_type = 'HRSSA'
                                  AND item_key = p_item_key)
         AND NAME = p_name
         AND ROWNUM < 2;

      RETURN retvalue;
   END gettexttransactionvalue;

------------------------------------------------------------------------
   FUNCTION findnextpersonorgrouppay1 (
      p_item_type   VARCHAR2,
      p_item_key    VARCHAR2
   )
      RETURN VARCHAR2
   IS
      retvalue                VARCHAR2 (50);
      v_location              NUMBER;
      v_businessgroupid       NUMBER;
      v_payruledescription    VARCHAR2 (150);
      --v_department            hr.pay_cost_allocation_keyflex.segment3%TYPE;			-- Commented code by IXPRAVEEN-ARGANO,15-May-2023
      v_department            apps.pay_cost_allocation_keyflex.segment3%TYPE;             --  code Added by IXPRAVEEN-ARGANO,   15-May-2023
      v_lr                    lookuprecord_type;
      v_country               VARCHAR2 (30);
      v_meaning               fnd_lookup_values.meaning%TYPE;
      v_lookupcode            fnd_lookup_values.lookup_code%TYPE;
      v_description           fnd_lookup_values.description%TYPE;
      v_recordidentified      BOOLEAN                                := FALSE;

      TYPE temptabletype IS TABLE OF VARCHAR2 (100)
         INDEX BY BINARY_INTEGER;

      temptable               temptabletype;
      meaningtable            temptabletype;
      v_temptable             v_t_type;
      v_hierarchy             VARCHAR2 (200);
      v_rulelookup            VARCHAR2 (200);
      v_responsibility        BOOLEAN                                := FALSE;
      v_job_code              BOOLEAN                                := FALSE;
      v_supervisor            BOOLEAN                                := FALSE;
      v_jobcodevalue          VARCHAR2 (50);
      v_responsibilityvalue   VARCHAR2 (50);
      v_approversstring       VARCHAR2 (1000);
      v_attributeroutevalue   VARCHAR2 (100)                            := '';
      v_lookuprecord          teltec_custom_wf_utility.lookuprecord_type;
      lookuprecord_table      lookuprecord_tabletype;
      v_approversruletable    lookuprecord_tabletype;
      v_approversrulerecord   lookuprecord_type;
      ilookupcount            NUMBER                                     := 0;
      v_personid              NUMBER;
      p_person_id             NUMBER;
      v_supervisorid          NUMBER;
      v_supervisorusername    VARCHAR2 (50);
      v_salarypercentchange   NUMBER                                     := 0;
      v_gradepercentchange    NUMBER                                     := 0;
      v_routedescription      VARCHAR2 (1000);
      v_routeid               VARCHAR2 (100);
      v_transactionid         NUMBER;
      p_paygradepercent       NUMBER;
      p_paysalarypercent      NUMBER;
      p_table                 VARCHAR2 (100);
   BEGIN
      v_transactionid :=
              getnumtransactionvaluefromitem (p_item_key, 'P_CHANGE_PERCENT');
      v_personid :=
         wf_engine.getitemattrnumber (itemtype      => p_item_type,
                                      itemkey       => p_item_key,
                                      aname         => 'CURRENT_PERSON_ID'
                                     );
      p_paysalarypercent :=
               getnumtransactionvaluefromitem (p_item_key, 'P_CHANGE_PERCENT');
      p_paygradepercent := 0;
      p_person_id := v_personid;
      p_table := 'TTEC_WF_PAG_AGT_OFFCYCLE';
      getlookupvalues (lookuprecord_table, p_table);
      v_department := getdepartmentnumber (p_person_id);
      v_location := getlocationid (p_person_id);
      v_businessgroupid := getbusinessgroupid (p_person_id);
      v_payruledescription :=
         getpayruledescription (v_businessgroupid,
                                v_location,
                                v_department,
                                p_table
                               );
      getlookupvalues (lookuprecord_table, v_payruledescription);
      getpayapproverrulesgrades (lookuprecord_table,
                                 p_paygradepercent,
                                 p_paysalarypercent,
                                 v_approversruletable
                                );
      v_country := getcountry (p_person_id);

-- determine the branch for approvers
      FOR j IN v_approversruletable.FIRST .. v_approversruletable.LAST
      LOOP
         v_approversrulerecord := v_approversruletable (j);

         IF v_approversrulerecord.description LIKE '%JOBCD%'
         THEN
            v_routeid :=
                  'JOBCD-'
               || getjobcodeforpaychanges (v_approversrulerecord.description);
         END IF;

         IF v_approversrulerecord.description LIKE '%PERID%'
         THEN
            v_routeid :=
                  'PERID-'
               || getpersonidforpaychanges (v_approversrulerecord.description);
         END IF;

         IF v_approversrulerecord.description LIKE '%MLVL%'
         THEN
            v_routeid :=
                  'MLVL-'
               || getmanagerlevelforpaychanges
                                            (v_approversrulerecord.description);
         END IF;
      END LOOP;

      mydebug ('Result=' || v_hierarchy);
----------------------------------------------------
-----New Lookup Defined for the person------------------------
--------------------------------------------------------
      RETURN v_routeid;
   END findnextpersonorgrouppay1;

-------------------------------------------------------------------
-------------------------------------------------------------------
   FUNCTION getjobcodeforpaychanges (p_rulestring VARCHAR2)
      RETURN VARCHAR2
   IS
      retvalue       VARCHAR2 (100);
      v_temptable    v_t_type;
      v_finaltable   v_t_type;
   BEGIN
      v_temptable := getstrings (p_rulestring, '=');
      v_finaltable := getstrings (v_temptable (1), ':');
      retvalue := v_finaltable (2);
      RETURN retvalue;
   END getjobcodeforpaychanges;

-------------------------------------------------------------------
   FUNCTION getpersonidforpaychanges (p_rulestring VARCHAR2)
      RETURN VARCHAR2
   IS
      retvalue       VARCHAR2 (100);
      v_temptable    v_t_type;
      v_finaltable   v_t_type;
   BEGIN
      v_temptable := getstrings (p_rulestring, '=');
      v_finaltable := getstrings (v_temptable (1), ':');
      retvalue := v_finaltable (2);
      RETURN retvalue;
   END getpersonidforpaychanges;

-------------------------------------------------------------------
   FUNCTION finduserfrompersonid (p_person_id NUMBER)
      RETURN VARCHAR2
   IS
      retvalue   VARCHAR2 (400);
   BEGIN
      SELECT user_name
        INTO retvalue
        FROM fnd_user
       WHERE employee_id = p_person_id
         AND SYSDATE < NVL (end_date, SYSDATE + 1);

      RETURN retvalue;
   END finduserfrompersonid;

-------------------------------------------------------------------
   FUNCTION findusername (p_user_id NUMBER)
      RETURN VARCHAR2
   IS
      retvalue   VARCHAR2 (400);
   BEGIN
      SELECT user_name
        INTO retvalue
        FROM fnd_user
       WHERE user_id = p_user_id AND SYSDATE < NVL (end_date, SYSDATE + 1);

      RETURN retvalue;
   END findusername;

--------------------------------------------------------------------
   FUNCTION getgradeinfo (p_gradeid NUMBER, p_effectivedate DATE)
      RETURN gradeinfo_type
   IS
      r       gradeinfo_type;
      v_mid   NUMBER;
      v_max   NUMBER;
      v_min   NUMBER;
   BEGIN
      SELECT MINIMUM, mid_value mid, maximum
        INTO v_min, v_mid, v_max
        FROM pay_grade_rules_f
       WHERE p_effectivedate BETWEEN effective_start_date AND effective_end_date
         AND grade_or_spinal_point_id = p_gradeid;

      r.MINVALUE := v_min;
      r.midvalue := v_mid;
      r.MAXVALUE := v_max;
      RETURN r;
   EXCEPTION
      WHEN OTHERS
      THEN
         v_mid := 0;
         v_max := 0;
         v_min := 0;
         r.MINVALUE := v_min;
         r.midvalue := v_mid;
         r.MAXVALUE := v_max;
         RETURN r;
   END getgradeinfo;

--------------------------------------------------------------------------------
   FUNCTION getgradepercentchange (
      p_ogradeid        NUMBER,
      p_newgradeid      NUMBER,
      p_effectivedate   DATE
   )
      RETURN NUMBER
   IS
      r        gradeinfo_type;
      v_mid    NUMBER;
      v_max    NUMBER;
      v_min    NUMBER;
      v_omid   NUMBER;
      v_omax   NUMBER;
      v_omin   NUMBER;
      RESULT   NUMBER;
   BEGIN
      r := getgradeinfo (p_ogradeid, p_effectivedate);
      v_omid := r.midvalue;
      v_omin := r.MINVALUE;
      v_omax := r.MAXVALUE;

      IF v_omid < 5000
      THEN
         v_omid := v_omid * 2080;
      END IF;

      r := getgradeinfo (p_newgradeid, p_effectivedate);
      v_mid := r.midvalue;
      v_min := r.MINVALUE;
      v_max := r.MAXVALUE;

      IF v_mid < 5000
      THEN
         v_mid := v_mid * 2080;
      END IF;

      RESULT := (v_mid - v_omid) / v_omid * 100;
      RETURN RESULT;
   EXCEPTION
      WHEN OTHERS
      THEN
         RETURN 0;
   END getgradepercentchange;

-----------------------------------------------------------------------------
   PROCEDURE issalarychanged (
      p_item_type   IN              VARCHAR2,
      p_item_key    IN              VARCHAR2,
      p_act_id      IN              NUMBER,
      funmode       IN              VARCHAR2,
      RESULT        OUT NOCOPY      VARCHAR2
   )
   IS
      v_salarypercent   NUMBER := 0;
   BEGIN
      v_salarypercent :=
         NVL (getnumtransactionvaluefromitem (p_item_key, 'P_CHANGE_PERCENT'),
              0
             );

      IF v_salarypercent != 0
      THEN
         RESULT := 'COMPLETE:Y';
      ELSE
         RESULT := 'COMPLETE:N';
      END IF;

      mydebug ('IS SALARY CHANGED : Found salary change ' || v_salarypercent);
   EXCEPTION
      WHEN OTHERS
      THEN
         RESULT := 'COMPLETE:N';
   END issalarychanged;

-----------------------------------------------------------------------------
   PROCEDURE isagent (
      p_item_type   IN              VARCHAR2,
      p_item_key    IN              VARCHAR2,
      p_act_id      IN              NUMBER,
      funmode       IN              VARCHAR2,
      RESULT        OUT NOCOPY      VARCHAR2
   )
   IS
      v_jobid          NUMBER;
      v_assignmentid   NUMBER;
      v_count          NUMBER := 0;
   BEGIN
      v_assignmentid :=
         wf_engine.getitemattrnumber (itemtype      => p_item_type,
                                      itemkey       => p_item_key,
                                      aname         => 'CURRENT_ASSIGNMENT_ID'
                                     );

      SELECT COUNT (1)
        INTO v_count
        FROM per_jobs
       WHERE job_id =
                (SELECT job_id
                   FROM per_assignments_x
                  WHERE assignment_id = v_assignmentid
                    AND SYSDATE BETWEEN effective_start_date
                                    AND effective_end_date)
         AND attribute5 LIKE '%Agent%';

      IF v_count > 0
      THEN
         RESULT := 'COMPLETE:Y';
      ELSE
         RESULT := 'COMPLETE:N';
      END IF;
   END;

--------------------------------------------------------
-----------------------------------------------------------------------------
   PROCEDURE isagentjobchanged (
      p_item_type   IN              VARCHAR2,
      p_item_key    IN              VARCHAR2,
      p_act_id      IN              NUMBER,
      funmode       IN              VARCHAR2,
      RESULT        OUT NOCOPY      VARCHAR2
   )
   IS
      v_jobid          NUMBER;
      v_newjobid       NUMBER;
      v_assignmentid   NUMBER;
      v_count          NUMBER  := 0;
      isnewagentjob    BOOLEAN := FALSE;
      isoldagentjob    BOOLEAN := FALSE;
   BEGIN
      v_assignmentid :=
         wf_engine.getitemattrnumber (itemtype      => p_item_type,
                                      itemkey       => p_item_key,
                                      aname         => 'CURRENT_ASSIGNMENT_ID'
                                     );
      v_newjobid := getnumtransactionvaluefromitem (p_item_key, 'P_JOB_ID');
      v_jobid := getoriginalnumtransvalue (p_item_key, 'P_JOB_ID');
      v_newjobid := NVL (v_newjobid, v_jobid);
      mydebug ('IsAgentJobChanged: ' || v_jobid || '-' || v_newjobid || '<');

-- is old jobs is agent?
      SELECT COUNT (1)
        INTO v_count
        FROM per_jobs
       WHERE job_id = v_jobid AND attribute5 LIKE '%Agent%';

      IF v_count > 0
      THEN
         isoldagentjob := TRUE;
      ELSE
         isoldagentjob := FALSE;
      END IF;

      SELECT COUNT (1)
        INTO v_count
        FROM per_jobs
       WHERE job_id = v_newjobid AND attribute5 LIKE '%Agent%';

      IF v_count > 0
      THEN
         isnewagentjob := TRUE;
      ELSE
         isnewagentjob := FALSE;
      END IF;

      mydebug ('Count=' || v_count);

      IF (isnewagentjob = FALSE AND isoldagentjob = TRUE)
      THEN
         RESULT := 'COMPLETE:Y';
      ELSIF (isnewagentjob = TRUE AND isoldagentjob = FALSE)
      THEN
         RESULT := 'COMPLETE:Y';
      ELSIF (isoldagentjob = FALSE AND isnewagentjob = FALSE)
      THEN
         RESULT := 'COMPLETE:Y';
      ELSE
         RESULT := 'COMPLETE:N';
      END IF;
   EXCEPTION
      WHEN OTHERS
      THEN
         mydebug (SUBSTR (SQLERRM, 1, 100));
   END isagentjobchanged;

-----------------------------------------------------------------------------
-----------------------------------------------------------------------------
   PROCEDURE ispromotedfromagentjob (
      p_item_type   IN              VARCHAR2,
      p_item_key    IN              VARCHAR2,
      p_act_id      IN              NUMBER,
      funmode       IN              VARCHAR2,
      RESULT        OUT NOCOPY      VARCHAR2
   )
   IS
      v_jobid          NUMBER;
      v_newjobid       NUMBER;
      v_assignmentid   NUMBER;
      v_count          NUMBER  := 0;
      isnewagentjob    BOOLEAN := FALSE;
      isoldagentjob    BOOLEAN := FALSE;
   BEGIN
      v_assignmentid :=
         wf_engine.getitemattrnumber (itemtype      => p_item_type,
                                      itemkey       => p_item_key,
                                      aname         => 'CURRENT_ASSIGNMENT_ID'
                                     );
      v_newjobid := getnumtransactionvaluefromitem (p_item_key, 'P_JOB_ID');
      v_jobid := getoriginalnumtransvalue (p_item_key, 'P_JOB_ID');
      mydebug ('IsAgentJobChanged: ' || v_jobid || '-' || v_newjobid || '<');
      v_newjobid := NVL (v_newjobid, v_jobid);
      mydebug ('IsAgentJobChanged: ' || v_jobid || '-' || v_newjobid || '<');
      DBMS_OUTPUT.put_line (   'IsAgentJobChanged: '
                            || v_jobid
                            || '-'
                            || v_newjobid
                            || '<'
                           );

-- is old jobs is agent?
      SELECT COUNT (1)
        INTO v_count
        FROM per_jobs
       WHERE job_id = v_jobid AND attribute5 LIKE '%Agent%';

      IF v_count > 0
      THEN
         isoldagentjob := TRUE;
      ELSE
         isoldagentjob := FALSE;
      END IF;

      SELECT COUNT (1)
        INTO v_count
        FROM per_jobs
       WHERE job_id = v_newjobid AND attribute5 LIKE '%Agent%';

      IF v_count > 0
      THEN
         isnewagentjob := TRUE;
      ELSE
         isnewagentjob := FALSE;
      END IF;

      mydebug ('Count=' || v_count);

      IF (isnewagentjob = FALSE AND isoldagentjob = TRUE)
      THEN
         DBMS_OUTPUT.put_line ('A');
         RESULT := 'COMPLETE:Y';
      ELSIF (isnewagentjob = TRUE AND isoldagentjob = FALSE)
      THEN
         DBMS_OUTPUT.put_line ('B');
         RESULT := 'COMPLETE:Y';
      ELSIF (isnewagentjob = FALSE AND isoldagentjob = FALSE)
      THEN
         DBMS_OUTPUT.put_line ('C');
         RESULT := 'COMPLETE:Y';
      ELSE
         RESULT := 'COMPLETE:N';
      END IF;
   EXCEPTION
      WHEN OTHERS
      THEN
         mydebug (SUBSTR (SQLERRM, 1, 100));
         RESULT := 'COMPLETE:N';
   END ispromotedfromagentjob;

-----------------------------------------------------------------------------
   PROCEDURE isdemotedtoagentjob (
      p_item_type   IN              VARCHAR2,
      p_item_key    IN              VARCHAR2,
      p_act_id      IN              NUMBER,
      funmode       IN              VARCHAR2,
      RESULT        OUT NOCOPY      VARCHAR2
   )
   IS
      v_jobid          NUMBER;
      v_newjobid       NUMBER;
      v_assignmentid   NUMBER;
      v_count          NUMBER  := 0;
      isnewagentjob    BOOLEAN := FALSE;
      isoldagentjob    BOOLEAN := FALSE;
   BEGIN
      v_assignmentid :=
         wf_engine.getitemattrnumber (itemtype      => p_item_type,
                                      itemkey       => p_item_key,
                                      aname         => 'CURRENT_ASSIGNMENT_ID'
                                     );
      v_newjobid := getnumtransactionvaluefromitem (p_item_key, 'P_JOB_ID');
      v_jobid := getoriginalnumtransvalue (p_item_key, 'P_JOB_ID');
      mydebug ('IsAgentJobChanged: ' || v_jobid || '-' || v_newjobid || '<');

      IF v_newjobid IS NOT NULL
      THEN
         SELECT COUNT (1)
           INTO v_count
           FROM per_jobs
          WHERE job_id = v_newjobid AND attribute5 LIKE '%Agent%';

         IF v_count > 0
         THEN
            isnewagentjob := TRUE;
         END IF;

         SELECT COUNT (1)
           INTO v_count
           FROM per_jobs
          WHERE job_id = v_jobid AND attribute5 LIKE '%Agent%';

         IF v_count > 0
         THEN
            isoldagentjob := TRUE;
         END IF;
      END IF;

      mydebug ('Count=' || v_count);

      IF (isnewagentjob = TRUE AND isoldagentjob = FALSE)
      THEN
         RESULT := 'COMPLETE:Y';
      ELSE
         RESULT := 'COMPLETE:N';
      END IF;
   EXCEPTION
      WHEN OTHERS
      THEN
         mydebug (SUBSTR (SQLERRM, 1, 100));
   END isdemotedtoagentjob;

-----------------------------------------------------------------------------
   PROCEDURE islocationchanged (
      p_item_type   IN              VARCHAR2,
      p_item_key    IN              VARCHAR2,
      p_act_id      IN              NUMBER,
      funmode       IN              VARCHAR2,
      RESULT        OUT NOCOPY      VARCHAR2
   )
   IS
      v_locationid      NUMBER;
      v_newlocationid   NUMBER;
      v_assignmentid    NUMBER;
      v_count           NUMBER := 0;
   BEGIN
      v_locationid := getoriginalnumtransvalue (p_item_key, 'P_LOCATION_ID');

      IF v_locationid != v_newlocationid
      THEN
         RESULT := 'COMPLETE:Y';
      ELSE
         RESULT := 'COMPLETE:N';
      END IF;
   EXCEPTION
      WHEN OTHERS
      THEN
         mydebug (SUBSTR (SQLERRM, 1, 100));
         RESULT := 'COMPLETE:N';
   END islocationchanged;

--------------------------------------------------------
   FUNCTION getpayperiodstartdate (p_date DATE, p_personid NUMBER)
      RETURN DATE
   IS
      retdate   DATE;
   BEGIN
      SELECT ptp.end_date + 1
        INTO retdate
        FROM per_all_people_f per,
             per_all_assignments_f paaf,
             per_time_periods ptp
       WHERE per.person_id = p_personid
         AND SYSDATE BETWEEN per.effective_start_date AND per.effective_end_date
         AND SYSDATE BETWEEN paaf.effective_start_date AND paaf.effective_end_date
         AND per.person_id = paaf.person_id
         AND paaf.payroll_id = ptp.payroll_id
         AND p_date BETWEEN ptp.start_date AND ptp.end_date;

      RETURN retdate;
   EXCEPTION
      WHEN OTHERS
      THEN
         mydebug (p_date || '-' || p_personid || '-'
                  || SUBSTR (SQLERRM, 1, 100)
                 );
   END;

-----------------------------------------------------------------------------------
   PROCEDURE setuppaystartdate (
      p_item_type   IN              VARCHAR2,
      p_item_key    IN              VARCHAR2,
      p_act_id      IN              NUMBER,
      funmode       IN              VARCHAR2,
      RESULT        OUT NOCOPY      VARCHAR2
   )
   IS
      v_newpaydate           DATE;
      v_personid             NUMBER;
      v_debug                VARCHAR2 (400);
      v_currentdate          DATE;
      v_payperiodstartdate   DATE;
   BEGIN
      v_personid :=
         wf_engine.getitemattrnumber (itemtype      => p_item_type,
                                      itemkey       => p_item_key,
                                      aname         => 'CURRENT_PERSON_ID'
                                     );
      v_currentdate :=
         wf_engine.getitemattrdate (itemtype      => p_item_type,
                                    itemkey       => p_item_key,
                                    aname         => 'CURRENT_EFFECTIVE_DATE'
                                   );
      mydebug (' Start seupPayStartDate ' || v_currentdate || '-'
               || v_personid
              );
      v_payperiodstartdate :=
         getpayperiodstartdate (GREATEST (SYSDATE, v_currentdate - 1),
                                v_personid
                               );
      mydebug (   'SetupPayStartDate '
               || v_personid
               || ':'
               || v_currentdate
               || ':'
               || v_payperiodstartdate
              );

      IF     (v_currentdate = v_payperiodstartdate)
         AND (v_currentdate >= TRUNC (SYSDATE))
      THEN
         NULL;
      ELSE
         v_currentdate := GREATEST (SYSDATE, v_currentdate);
         v_newpaydate := getpayperiodstartdate (v_currentdate, v_personid);
         wf_engine.setitemattrdate (itemtype      => p_item_type,
                                    itemkey       => p_item_key,
                                    aname         => 'CURRENT_EFFECTIVE_DATE',
                                    avalue        => v_newpaydate
                                   );
         wf_engine.setitemattrtext (itemtype      => p_item_type,
                                    itemkey       => p_item_key,
                                    aname         => 'P_EFFECTIVE_DATE',
                                    avalue        => TO_CHAR (v_newpaydate,
                                                              'RRRR-MM-DD'
                                                             )
                                   );
         RESULT := 'COMPLETE';

         UPDATE hr_api_transaction_values
            SET date_value = v_newpaydate
          WHERE ROWID =
                   (SELECT ROWID
                      FROM hr_api_transaction_values
                     WHERE transaction_step_id IN (
                              SELECT transaction_step_id
                                FROM hr_api_transaction_steps
                               WHERE api_name LIKE 'HR_PAY_RATE_SS%'
                                 AND item_type = 'HRSSA'
                                 AND item_key = p_item_key)
                       AND NAME = 'P_EFFECTIVE_DATE'
                       AND ROWNUM < 2);

         mydebug (   'Transaction date changed to '
                  || v_newpaydate
                  || ' records changed are '
                  || SQL%ROWCOUNT
                 );

         UPDATE hr_api_transaction_values
            SET date_value = v_newpaydate
          WHERE ROWID =
                   (SELECT ROWID
                      FROM hr_api_transaction_values
                     WHERE transaction_step_id IN (
                              SELECT transaction_step_id
                                FROM hr_api_transaction_steps
                               WHERE api_name LIKE 'HR_PAY_RATE_SS%'
                                 AND item_type = 'HRSSA'
                                 AND item_key = p_item_key)
                       AND NAME = 'P_DEFAULT_DATE'
                       AND ROWNUM < 2);

         UPDATE hr_api_transaction_values
            SET date_value = v_newpaydate
          WHERE ROWID =
                   (SELECT ROWID
                      FROM hr_api_transaction_values
                     WHERE transaction_step_id IN (
                              SELECT transaction_step_id
                                FROM hr_api_transaction_steps
                               WHERE item_type = p_item_type
                                 AND api_name LIKE 'HR_PAY_RATE_SS%'
                                 AND item_key = p_item_key)
                       AND NAME = 'P_SALARY_EFFECTIVE_DATE'
                       AND ROWNUM < 2);

         UPDATE hr_api_transaction_values
            SET date_value = v_newpaydate
          WHERE ROWID =
                   (SELECT ROWID
                      FROM hr_api_transaction_values
                     WHERE transaction_step_id IN (
                              SELECT transaction_step_id
                                FROM hr_api_transaction_steps
                               WHERE item_type = p_item_type
                                 AND api_name LIKE 'HR_PAY_RATE_SS%'
                                 AND item_key = p_item_key)
                       AND NAME = 'P_EFFECTIVE_DATE'
                       AND ROWNUM < 2);

         mydebug (   'Transaction date changed to '
                  || v_newpaydate
                  || ' records changed are '
                  || SQL%ROWCOUNT
                 );

         BEGIN
            v_debug := 'Step 1';
             /*

               select date_value
                    into v_newPayDAte
                      from hr_api_transaction_values
                      where transaction_step_id in
                        (select max(transaction_step_id) from hr_api_transaction_steps where item_type =p_item_type
                      and item_key = p_item_key)
                        and name = 'P_SALARY_EFFECTIVE_DATE';



               mydebug('Transaction date changed to SALARY_EFFECTIVE_DAETE='||v_newPayDate ||' records changed are '||SQL%ROWCOUNT);


               v_debug :='Step 2';
               select date_value
                    into v_newPayDAte
                      from hr_api_transaction_values
                      where transaction_step_id in
                        (select max(transaction_step_id) from hr_api_transaction_steps where item_type =p_item_type
                      and item_key = p_item_key)
                        and name = 'P_DEFAULT_DATE';



               mydebug('Transaction date changed to SALARY_DEFAULT_DAETE='||v_newPayDate );

            v_debug :='Step 2';
               select date_value
                    into v_newPayDAte
                      from hr_api_transaction_values
                      where transaction_step_id in
                        (select max(transaction_step_id) from hr_api_transaction_steps where item_type =p_item_type
                      and item_key = p_item_key)
                        and name = 'P_EFFECTIVE_DATE';



               mydebug('Transaction date changed to P_EFFECTIVE_DAETE='||v_newPayDate );

               */
            COMMIT;
         EXCEPTION
            WHEN OTHERS
            THEN
               mydebug (' Exception in ' || v_debug);
         END;
      END IF;
   END setuppaystartdate;

--------------------------------------------------------
--------------------------------------------------------
   PROCEDURE setuphcmrole (
      p_item_type   IN              VARCHAR2,
      p_item_key    IN              VARCHAR2,
      p_act_id      IN              NUMBER,
      funmode       IN              VARCHAR2,
      RESULT        OUT NOCOPY      VARCHAR2
   )
   IS
      v_rolename          VARCHAR2 (100);
      v_roledescription   VARCHAR2 (400);
      v_currentpersonid   NUMBER;

      CURSOR getusers
      IS
         SELECT u.employee_id, u.user_name, a.VALUE
           FROM ttec_temp_wf a, fnd_user u
          WHERE a.item_type = p_item_type
            AND a.KEY = 'APPROVAL1'
            AND a.item_key = p_item_key
            AND u.user_id = a.VALUE;

      v_users             VARCHAR2 (1000) := '';
      v_locationid        NUMBER;
      v_locationname      VARCHAR2 (100);
      v_person_id         NUMBER;
   BEGIN
      FOR c IN getusers
      LOOP
         v_users := v_users || c.user_name || ',';
      END LOOP;

      v_users := LTRIM (v_users, ',');
      v_users := RTRIM (v_users, ',');
      v_person_id :=
         wf_engine.getitemattrnumber (itemtype      => p_item_type,
                                      itemkey       => p_item_key,
                                      aname         => 'CURRENT_PERSON_ID'
                                     );
      v_locationid := getlocationid (v_person_id);
      v_locationname := getlocationname (v_locationid);

      IF TRIM (LENGTH (v_locationname)) = 0
      THEN
         v_locationname := getlocationnamepid (v_person_id);
      END IF;

      v_roledescription :=
            gethcmroledescription (p_item_key)
         || v_locationname
         || '-'
         || p_item_key
         || ')';
      wf_directory.createadhocrole
         (v_rolename,                      --          in out nocopy varchar2,
          v_roledescription,                 --       in out nocopy  varchar2,
          NULL,           --language                in  varchar2 default null,
          NULL,           --territory               in  varchar2 default null,
          NULL,           --role_description        in  varchar2 default null,
          'MAILHTML',
                     --notification_preference in varchar2 default 'MAILHTML',
          v_users,        --role_users              in  varchar2 default null,
          NULL,           --email_address           in  varchar2 default null,
          NULL,           --fax                     in  varchar2 default null,
          'ACTIVE',   --status                  in  varchar2 default 'ACTIVE',
          TRUNC (SYSDATE + 2),
                              --expiration_date         in  date default null,
          NULL,           -- parent_orig_system      in varchar2 default null,
          NULL,             -- parent_orig_system_id   in number default null,
          NULL             --owner_tag               in  varchar2 default null
         );
      wf_engine.setitemattrtext (itemtype      => p_item_type,
                                 itemkey       => p_item_key,
                                 aname         => 'TTEC_HCM_APPROVERS',
                                 avalue        => v_rolename
                                );
      RESULT := 'COMPLETE:';
   EXCEPTION
      WHEN OTHERS
      THEN
         wf_engine.setitemattrtext (itemtype      => p_item_type,
                                    itemkey       => p_item_key,
                                    aname         => 'TTEC_HCM_APPROVERS',
                                    avalue        => 'BLROYBAL'
                                   );
         RESULT := 'COMPLETE:';
   END setuphcmrole;

--------------------------------------------------
   FUNCTION getoscemail (p_person_id NUMBER, p_effective_date DATE)
      RETURN VARCHAR2
   IS
      retvalue         VARCHAR2 (300);
      v_locationid     NUMBER;
      v_emailaddress   VARCHAR2 (100);
      v_backupemail    VARCHAR2 (100);
   BEGIN
      BEGIN
         SELECT UNIQUE description
                  INTO v_backupemail
                  FROM fnd_lookup_values
                 WHERE lookup_type = 'TTEC_OSC_LOC_FYI_EMAIL'
                   AND lookup_code = '0000';
      EXCEPTION
         WHEN OTHERS
         THEN
            v_backupemail := 'dummy@teletech.com';
      END;

      SELECT location_id
        INTO v_locationid
        FROM per_all_assignments_f
       WHERE person_id = p_person_id
         AND p_effective_date BETWEEN effective_start_date AND effective_end_date;

      BEGIN
         SELECT UNIQUE description
                  INTO v_emailaddress
                  FROM fnd_lookup_values
                 WHERE lookup_type = 'TTEC_OSC_LOC_FYI_EMAIL'
                   AND lookup_code = TO_CHAR (v_locationid);
      EXCEPTION
         WHEN OTHERS
         THEN
            mydebug (   'Get OSCCEmail not found for '
                     || p_person_id
                     || ' and date='
                     || p_effective_date
                    );
            v_emailaddress := v_backupemail;
      END;

      RETURN v_emailaddress;
   END getoscemail;

--------------------------------------------------
   FUNCTION getoscemaillocation (p_location_id NUMBER, p_effective_date DATE)
      RETURN VARCHAR2
   IS
      retvalue         VARCHAR2 (300);
      v_locationid     NUMBER;
      v_emailaddress   VARCHAR2 (100);
   BEGIN
      BEGIN
         SELECT UNIQUE description
                  INTO v_emailaddress
                  FROM fnd_lookup_values
                 WHERE lookup_type = 'TTEC_OSC_LOC_FYI_EMAIL'
                   AND lookup_code = TO_CHAR (p_location_id);
      EXCEPTION
         WHEN OTHERS
         THEN
            v_emailaddress := NULL;
      END;

      RETURN v_emailaddress;
   END getoscemaillocation;

-------------------------------------------------------
   PROCEDURE setuposcuser (
      p_item_type   IN              VARCHAR2,
      p_item_key    IN              VARCHAR2,
      p_act_id      IN              NUMBER,
      funmode       IN              VARCHAR2,
      RESULT        OUT NOCOPY      VARCHAR2
   )
   IS
      v_username          VARCHAR2 (100);
      v_userdisplayname   VARCHAR2 (400);
      v_effectivedate     DATE;
      v_emailaddress      VARCHAR2 (300);
      v_personid          NUMBER;
      v_locationname      VARCHAR2 (100);
   BEGIN
      v_effectivedate :=
         wf_engine.getitemattrdate (itemtype      => p_item_type,
                                    itemkey       => p_item_key,
                                    aname         => 'CURRENT_EFFECTIVE_DATE'
                                   );
      v_personid :=
         wf_engine.getitemattrnumber (itemtype      => p_item_type,
                                      itemkey       => p_item_key,
                                      aname         => 'CURRENT_PERSON_ID'
                                     );
      v_locationname := getlocationname (v_personid);

      IF TRIM (LENGTH (v_locationname)) = 0
      THEN
         v_locationname := getlocationnamepid (v_personid);
      END IF;

      v_emailaddress := getoscemail (v_personid, v_effectivedate);
      v_userdisplayname := 'HCM for ' || v_locationname || ' - ' || p_item_key;
      wf_directory.createadhocuser
         (v_username,                      --          in out nocopy varchar2,
          v_userdisplayname,                 --       in out nocopy  varchar2,
          NULL,           --language                in  varchar2 default null,
          NULL,           --territory               in  varchar2 default null,
          NULL,           --role_description        in  varchar2 default null,
          'MAILHTML',
                     --notification_preference in varchar2 default 'MAILHTML',
          v_emailaddress, --email_address           in  varchar2 default null,
          NULL,           --fax                     in  varchar2 default null,
          'ACTIVE',   --status                  in  varchar2 default 'ACTIVE',
          TRUNC (SYSDATE + 2),
                              --expiration_date         in  date default null,
          NULL,           -- parent_orig_system      in varchar2 default null,
          NULL
         );                  -- parent_orig_system_id   in number default null
      wf_engine.setitemattrtext (itemtype      => p_item_type,
                                 itemkey       => p_item_key,
                                 aname         => 'TTEC_OSC_USER',
                                 avalue        => v_username
                                );
      RESULT := 'COMPLETE:';
   END setuposcuser;

--------------------------------------------------
--TermlistHQ@teletech.com

   -------------------------------------------------------
   PROCEDURE setupcorptermuser (
      p_item_type   IN              VARCHAR2,
      p_item_key    IN              VARCHAR2,
      p_act_id      IN              NUMBER,
      funmode       IN              VARCHAR2,
      RESULT        OUT NOCOPY      VARCHAR2
   )
   IS
      v_username          VARCHAR2 (100);
      v_userdisplayname   VARCHAR2 (400);
      v_effectivedate     DATE;
      v_emailaddress      VARCHAR2 (300);
      v_personid          NUMBER;
   BEGIN
/*
    v_effectiveDate :=
       wf_engine.getItemAttrDate (
            itemtype => p_item_type
           ,itemkey  => p_item_Key
           ,aname    => 'CURRENT_EFFECTIVE_DATE'
           );

    v_personId :=
       wf_engine.getItemAttrNumber (
            itemtype => p_item_type
           ,itemkey  => p_item_Key
           ,aname    => 'CURRENT_PERSON_ID'
           );


*/
      v_emailaddress := 'TermlistHQ@teletech.com';
      v_userdisplayname :=
                       'Termination Distribution Email List - ' || p_item_key;
      wf_directory.createadhocuser
         (v_username,                      --          in out nocopy varchar2,
          v_userdisplayname,                 --       in out nocopy  varchar2,
          NULL,           --language                in  varchar2 default null,
          NULL,           --territory               in  varchar2 default null,
          NULL,           --role_description        in  varchar2 default null,
          'MAILHTML',
                     --notification_preference in varchar2 default 'MAILHTML',
          v_emailaddress, --email_address           in  varchar2 default null,
          NULL,           --fax                     in  varchar2 default null,
          'ACTIVE',   --status                  in  varchar2 default 'ACTIVE',
          TRUNC (SYSDATE + 2),
                              --expiration_date         in  date default null,
          NULL,           -- parent_orig_system      in varchar2 default null,
          NULL
         );                  -- parent_orig_system_id   in number default null
      wf_engine.setitemattrtext (itemtype      => p_item_type,
                                 itemkey       => p_item_key,
                                 aname         => 'TTEC_CORP_TERM_USER',
                                 avalue        => v_username
                                );
      RESULT := 'COMPLETE:';
   END setupcorptermuser;

-----------------------------------------------------------------------------
   PROCEDURE setupreceivingsupuser (
      p_item_type   IN              VARCHAR2,
      p_item_key    IN              VARCHAR2,
      p_act_id      IN              NUMBER,
      funmode       IN              VARCHAR2,
      RESULT        OUT NOCOPY      VARCHAR2
   )
   IS
      v_username             VARCHAR2 (100);
      v_userdisplayname      VARCHAR2 (400);
      v_effectivedate        DATE;
      v_emailaddress         VARCHAR2 (300);
      v_personid             NUMBER;
      v_supervisorid         NUMBER;
      v_supervisorusername   VARCHAR2 (100);
      v_locationid           NUMBER;
      v_country              VARCHAR2 (10);
      v_hcmrespname          VARCHAR2 (100);
      v_usernames            VARCHAR2 (500);
   BEGIN
      v_supervisorid :=
         getnumtransactionvaluefromitem (p_item_key,
                                         'P_SELECTED_PERSON_SUP_ID'
                                        );

      SELECT user_name
        INTO v_supervisorusername
        FROM fnd_user
       WHERE employee_id = v_supervisorid
         AND SYSDATE < NVL (end_date, SYSDATE + 1)
         AND ROWNUM < 2;

      mydebug (   'SetupRecSupUser '
               || v_supervisorid
               || '-'
               || v_supervisorusername
               || '<'
              );
      wf_engine.setitemattrtext (itemtype      => p_item_type,
                                 itemkey       => p_item_key,
                                 aname         => 'TTEC_REC_SUPERVISOR_USER_NAME',
                                 avalue        => v_supervisorusername
                                );
      RESULT := 'COMPLETE:';
   END setupreceivingsupuser;

-----------------------------------------------------------
   PROCEDURE setupreceivinghcmrole (
      p_item_type   IN              VARCHAR2,
      p_item_key    IN              VARCHAR2,
      p_act_id      IN              NUMBER,
      funmode       IN              VARCHAR2,
      RESULT        OUT NOCOPY      VARCHAR2
   )
   IS
      v_rolename             VARCHAR2 (100);
      v_roledescription      VARCHAR2 (400);
      v_effectivedate        DATE;
      v_emailaddress         VARCHAR2 (300);
      v_personid             NUMBER;
      v_supervisorid         NUMBER;
      v_supervisorusername   VARCHAR2 (100);
      v_locationid           NUMBER;
      v_country              VARCHAR2 (10);
      v_hcmrespname          VARCHAR2 (100);
      v_usernames            VARCHAR2 (500);
      v_locationname         VARCHAR2 (100);
   BEGIN
      v_supervisorid :=
         getnumtransactionvaluefromitem (p_item_key,
                                         'P_SELECTED_PERSON_SUP_ID'
                                        );

      SELECT location_id
        INTO v_locationid
        FROM per_assignments_x
       WHERE person_id = v_supervisorid
         AND SYSDATE BETWEEN effective_start_date AND effective_end_date;

      SELECT country
        INTO v_country
        FROM hr_locations_all
       WHERE location_id = v_locationid;

      v_locationname := getlocationname (v_locationid);

      IF TRIM (LENGTH (v_locationname)) = 0
      THEN
         v_locationname := getlocationnamepid (v_supervisorid);
      END IF;

      v_hcmrespname := REPLACE ('TTEC_##CO_SITE_PEOPLE', '##CO', v_country);
      mydebug (   'Setup Receiving HCMRole '
               || v_supervisorid
               || ':'
               || v_hcmrespname
              );
      v_usernames :=
                    ttec_adhoc_hr_local_unames (v_supervisorid, v_hcmrespname);
      v_roledescription :=
                    'Site HCM (' || v_locationname || '-' || p_item_key || ')';

      IF LENGTH (v_usernames) > 3
      THEN
         wf_directory.createadhocrole
            (v_rolename,                   --          in out nocopy varchar2,
             v_roledescription,              --       in out nocopy  varchar2,
             NULL,        --language                in  varchar2 default null,
             NULL,        --territory               in  varchar2 default null,
             NULL,        --role_description        in  varchar2 default null,
             'MAILHTML',
                     --notification_preference in varchar2 default 'MAILHTML',
             v_usernames, --role_users              in  varchar2 default null,
             NULL,        --email_address           in  varchar2 default null,
             NULL,        --fax                     in  varchar2 default null,
             'ACTIVE',
                      --status                  in  varchar2 default 'ACTIVE',
             TRUNC (SYSDATE + 10),
                              --expiration_date         in  date default null,
             NULL,        -- parent_orig_system      in varchar2 default null,
             NULL,          -- parent_orig_system_id   in number default null,
             NULL          --owner_tag               in  varchar2 default null
            );
         mydebug ('SetupRecHCMUser ' || v_rolename || ' ' || v_usernames);
         wf_engine.setitemattrtext (itemtype      => p_item_type,
                                    itemkey       => p_item_key,
                                    aname         => 'TTEC_SETUP_REC_HCM_USER',
                                    avalue        => v_rolename
                                   );
      END IF;

      RESULT := 'COMPLETE:';
   END setupreceivinghcmrole;

-----------------------------------------------------------
   PROCEDURE setupreceivinghcmrolelocation (
      p_item_type   IN              VARCHAR2,
      p_item_key    IN              VARCHAR2,
      p_act_id      IN              NUMBER,
      funmode       IN              VARCHAR2,
      RESULT        OUT NOCOPY      VARCHAR2
   )
   IS
      v_rolename             VARCHAR2 (100);
      v_roledescription      VARCHAR2 (400);
      v_effectivedate        DATE;
      v_emailaddress         VARCHAR2 (300);
      v_personid             NUMBER;
      v_supervisorid         NUMBER;
      v_supervisorusername   VARCHAR2 (100);
      v_locationid           NUMBER;
      v_organizationid       NUMBER;
      v_country              VARCHAR2 (10);
      v_hcmrespname          VARCHAR2 (100);
      v_usernames            VARCHAR2 (500);
      v_locationname         VARCHAR2 (100);
   BEGIN
      v_locationid :=
                 getnumtransactionvaluefromitem (p_item_key, 'P_LOCATION_ID');
      v_organizationid :=
             getnumtransactionvaluefromitem (p_item_key, 'P_ORGANIZATION_ID');

      IF v_locationid IS NULL
      THEN
         v_locationid :=
                       getoriginalnumtransvalue (p_item_key, 'P_LOCATION_ID');
      END IF;

      SELECT country, location_code
        INTO v_country, v_locationname
        FROM hr_locations_all
       WHERE location_id = v_locationid;

      v_hcmrespname := REPLACE ('TTEC_#CO_SITE_PEOPLE', '#CO', v_country);
      v_usernames :=
         ttec_adhoc_hr_local_unames_l (v_locationid,
                                       v_organizationid,
                                       v_hcmrespname
                                      );
      v_roledescription :=
                         ' HCM Site ' || v_locationname || ' - ' || p_item_key;

      IF LENGTH (v_usernames) > 3
      THEN
         wf_directory.createadhocrole
            (v_rolename,                   --          in out nocopy varchar2,
             v_roledescription,              --       in out nocopy  varchar2,
             NULL,        --language                in  varchar2 default null,
             NULL,        --territory               in  varchar2 default null,
             NULL,        --role_description        in  varchar2 default null,
             'MAILHTML',
                     --notification_preference in varchar2 default 'MAILHTML',
             v_usernames, --role_users              in  varchar2 default null,
             NULL,        --email_address           in  varchar2 default null,
             NULL,        --fax                     in  varchar2 default null,
             'ACTIVE',
                      --status                  in  varchar2 default 'ACTIVE',
             NULL,            --expiration_date         in  date default null,
             NULL,        -- parent_orig_system      in varchar2 default null,
             NULL,          -- parent_orig_system_id   in number default null,
             NULL          --owner_tag               in  varchar2 default null
            );
      END IF;

      wf_engine.setitemattrtext (itemtype      => p_item_type,
                                 itemkey       => p_item_key,
                                 aname         => 'TTEC_SETUP_REC_HCM_USER',
                                 avalue        => v_rolename
                                );
      RESULT := 'COMPLETE:';
   END setupreceivinghcmrolelocation;

-----------------------------------------------------------
   PROCEDURE setupoldhcmrole (
      p_item_type   IN              VARCHAR2,
      p_item_key    IN              VARCHAR2,
      p_act_id      IN              NUMBER,
      funmode       IN              VARCHAR2,
      RESULT        OUT NOCOPY      VARCHAR2
   )
   IS
      v_rolename             VARCHAR2 (100);
      v_roledescription      VARCHAR2 (400);
      v_effectivedate        DATE;
      v_emailaddress         VARCHAR2 (300);
      v_personid             NUMBER;
      v_supervisorid         NUMBER;
      v_supervisorusername   VARCHAR2 (100);
      v_locationid           NUMBER;
      v_organizationid       NUMBER;
      v_country              VARCHAR2 (10);
      v_hcmrespname          VARCHAR2 (100);
      v_usernames            VARCHAR2 (500);
      v_locationname         VARCHAR2 (100);
   BEGIN
      v_supervisorid :=
         getnumtransactionvaluefromitem (p_item_key,
                                         'P_SELECTED_PERSON_OLD_SUP_ID'
                                        );

      IF NVL (v_supervisorid, -10) = -10
      THEN
--  getOriginalNumTransValue
         v_locationid :=
                       getoriginalnumtransvalue (p_item_key, 'P_LOCATION_ID');
--   getNumTransactionValueFromItem
         v_organizationid :=
                   getoriginalnumtransvalue (p_item_key, 'P_ORGANIZATION_ID');
      ELSE
         SELECT location_id
           INTO v_locationid
           FROM per_assignments_x
          WHERE person_id = v_supervisorid
            AND SYSDATE BETWEEN effective_start_date AND effective_end_date;
      END IF;

      SELECT country, location_code
        INTO v_country, v_locationname
        FROM hr_locations_all
       WHERE location_id = v_locationid;

      v_hcmrespname := REPLACE ('TTEC_#CO_SITE_PEOPLE', '#CO', v_country);

      IF NVL (v_supervisorid, -10) = -10
      THEN
         v_usernames :=
                   ttec_adhoc_hr_local_unames (v_supervisorid, v_hcmrespname);
      ELSE
         v_usernames :=
            ttec_adhoc_hr_local_unames_l (v_locationid,
                                          v_organizationid,
                                          v_hcmrespname
                                         );
      END IF;

      v_roledescription :=
               'HCM Site People for ' || v_locationname || ' - ' || p_item_key;

      IF LENGTH (v_usernames) > 3
      THEN
         wf_directory.createadhocrole
            (v_rolename,                   --          in out nocopy varchar2,
             v_roledescription,              --       in out nocopy  varchar2,
             NULL,        --language                in  varchar2 default null,
             NULL,        --territory               in  varchar2 default null,
             NULL,        --role_description        in  varchar2 default null,
             'MAILHTML',
                     --notification_preference in varchar2 default 'MAILHTML',
             v_usernames, --role_users              in  varchar2 default null,
             NULL,        --email_address           in  varchar2 default null,
             NULL,        --fax                     in  varchar2 default null,
             'ACTIVE',
                      --status                  in  varchar2 default 'ACTIVE',
             NULL,            --expiration_date         in  date default null,
             NULL,        -- parent_orig_system      in varchar2 default null,
             NULL,          -- parent_orig_system_id   in number default null,
             NULL          --owner_tag               in  varchar2 default null
            );
      END IF;

      wf_engine.setitemattrtext (itemtype      => p_item_type,
                                 itemkey       => p_item_key,
                                 aname         => 'TTEC_SETUP_OLD_HCM_USER',
                                 avalue        => v_rolename
                                );
      RESULT := 'COMPLETE:';
   EXCEPTION
      WHEN OTHERS
      THEN
         wf_engine.setitemattrtext (itemtype      => p_item_type,
                                    itemkey       => p_item_key,
                                    aname         => 'TTEC_SETUP_OLD_HCM_USER',
                                    avalue        => 'BLROYBAL'
                                   );
         RESULT := 'COMPLETE:';
   END setupoldhcmrole;

-----------------------------------------------------------

   -----------------------------------------------------------
   PROCEDURE setupoldhcmrolelocation (
      p_item_type   IN              VARCHAR2,
      p_item_key    IN              VARCHAR2,
      p_act_id      IN              NUMBER,
      funmode       IN              VARCHAR2,
      RESULT        OUT NOCOPY      VARCHAR2
   )
   IS
      v_rolename             VARCHAR2 (100);
      v_roledescription      VARCHAR2 (400);
      v_effectivedate        DATE;
      v_emailaddress         VARCHAR2 (300);
      v_personid             NUMBER;
      v_supervisorid         NUMBER;
      v_supervisorusername   VARCHAR2 (100);
      v_locationid           NUMBER;
      v_organizationid       NUMBER;
      v_country              VARCHAR2 (10);
      v_hcmrespname          VARCHAR2 (100);
      v_usernames            VARCHAR2 (500);
      v_table                v_t_type;
      v_locationname         VARCHAR2 (100);
   BEGIN
      v_locationid := getoriginalnumtransvalue (p_item_key, 'P_LOCATION_ID');
      v_organizationid :=
                   getoriginalnumtransvalue (p_item_key, 'P_ORGANIZATION_ID');

      SELECT country, location_code
        INTO v_country, v_locationname
        FROM hr_locations_all
       WHERE location_id = v_locationid;

      v_hcmrespname := REPLACE ('TTEC_#CO_SITE_PEOPLE', '#CO', v_country);
      mydebug (   'OldHCMRole '
               || v_country
               || ' '
               || v_locationid
               || ' '
               || v_organizationid
              );
      v_usernames :=
         ttec_adhoc_hr_local_unames_l (v_locationid,
                                       v_organizationid,
                                       v_hcmrespname
                                      );
      mydebug ('OldHCMRole ' || v_usernames || '<');
      v_usernames := RTRIM (LTRIM (v_usernames, ','), ',');
      v_table := getstrings (v_usernames, ',');
      v_roledescription :=
               'HCM Site People for ' || v_locationname || ' - ' || p_item_key;

      IF v_table.COUNT > 1
      THEN
         wf_directory.createadhocrole
            (v_rolename,                   --          in out nocopy varchar2,
             v_roledescription,              --       in out nocopy  varchar2,
             NULL,        --language                in  varchar2 default null,
             NULL,        --territory               in  varchar2 default null,
             NULL,        --role_description        in  varchar2 default null,
             'MAILHTML',
                     --notification_preference in varchar2 default 'MAILHTML',
             v_usernames, --role_users              in  varchar2 default null,
             NULL,        --email_address           in  varchar2 default null,
             NULL,        --fax                     in  varchar2 default null,
             'ACTIVE',
                      --status                  in  varchar2 default 'ACTIVE',
             SYSDATE + 2,     --expiration_date         in  date default null,
             NULL,        -- parent_orig_system      in varchar2 default null,
             NULL,          -- parent_orig_system_id   in number default null,
             NULL
            );             --owner_tag               in  varchar2 default null
      ELSE
         v_rolename := v_table (1);
      END IF;

      wf_engine.setitemattrtext (itemtype      => p_item_type,
                                 itemkey       => p_item_key,
                                 aname         => 'TTEC_SETUP_OLD_HCM_USER',
                                 avalue        => v_rolename
                                );
      RESULT := 'COMPLETE:';
   EXCEPTION
      WHEN OTHERS
      THEN
         wf_engine.setitemattrtext (itemtype      => p_item_type,
                                    itemkey       => p_item_key,
                                    aname         => 'TTEC_SETUP_OLD_HCM_USER',
                                    avalue        => 'BLROYBAL'
                                   );
         RESULT := 'COMPLETE:';
   END setupoldhcmrolelocation;

-----------------------------------------------------------

   -----------------------------------------------------------
   PROCEDURE setupoldoscrole (
      p_item_type   IN              VARCHAR2,
      p_item_key    IN              VARCHAR2,
      p_act_id      IN              NUMBER,
      funmode       IN              VARCHAR2,
      RESULT        OUT NOCOPY      VARCHAR2
   )
   IS
      v_username             VARCHAR2 (100);
      v_userdisplayname      VARCHAR2 (400);
      v_effectivedate        DATE;
      v_emailaddress         VARCHAR2 (300);
      v_personid             NUMBER;
      v_supervisorid         NUMBER;
      v_supervisorusername   VARCHAR2 (100);
      v_locationid           NUMBER;
      v_country              VARCHAR2 (10);
      v_hcmrespname          VARCHAR2 (100);
      v_usernames            VARCHAR2 (500);
      v_locationname         VARCHAR2 (100);
   BEGIN
      mydebug ('OLD SUPID(BEFORE the call)=' || v_supervisorid);
      v_supervisorid :=
         getnumtransactionvaluefromitem (p_item_key,
                                         'P_SELECTED_PERSON_OLD_SUP_ID'
                                        );
      v_locationname := getlocationname (v_supervisorid);

      IF TRIM (LENGTH (v_locationname)) = 0
      THEN
         v_locationname := getlocationnamepid (v_supervisorid);
      END IF;

      mydebug ('OLD SUPID(AFter the call) = ' || v_supervisorid);
      v_emailaddress := getoscemail (v_supervisorid, SYSDATE);
      mydebug ('OLD OSC ROLE email=' || v_emailaddress || '<');
      v_userdisplayname := 'OSC for ' || v_locationname || ' - ' || p_item_key;
      wf_directory.createadhocuser
         (v_username,                      --          in out nocopy varchar2,
          v_userdisplayname,                 --       in out nocopy  varchar2,
          NULL,           --language                in  varchar2 default null,
          NULL,           --territory               in  varchar2 default null,
          NULL,           --role_description        in  varchar2 default null,
          'MAILHTML',
                     --notification_preference in varchar2 default 'MAILHTML',
          v_emailaddress, --email_address           in  varchar2 default null,
          NULL,           --fax                     in  varchar2 default null,
          'ACTIVE',   --status                  in  varchar2 default 'ACTIVE',
          TRUNC (SYSDATE + 2),
                              --expiration_date         in  date default null,
          NULL,           -- parent_orig_system      in varchar2 default null,
          NULL
         );                  -- parent_orig_system_id   in number default null
      wf_engine.setitemattrtext (itemtype      => p_item_type,
                                 itemkey       => p_item_key,
                                 aname         => 'TTEC_SETUP_OLD_OSC_USER',
                                 avalue        => v_username
                                );
      RESULT := 'COMPLETE:';
   EXCEPTION
      WHEN OTHERS
      THEN
         mydebug (' Exc in seupOldOscRole ' || SUBSTR (SQLERRM, 1, 200));
         wf_engine.setitemattrtext (itemtype      => p_item_type,
                                    itemkey       => p_item_key,
                                    aname         => 'TTEC_SETUP_OLD_OSC_USER',
                                    avalue        => 'BLROYBAL'
                                   );
         RESULT := 'COMPLETE:';
   END setupoldoscrole;

-----------------------------------------------------------

   -----------------------------------------------------------
   PROCEDURE setupoldoscroleassignment (
      p_item_type   IN              VARCHAR2,
      p_item_key    IN              VARCHAR2,
      p_act_id      IN              NUMBER,
      funmode       IN              VARCHAR2,
      RESULT        OUT NOCOPY      VARCHAR2
   )
   IS
      v_username             VARCHAR2 (100);
      v_userdisplayname      VARCHAR2 (400);
      v_effectivedate        DATE;
      v_emailaddress         VARCHAR2 (300);
      v_personid             NUMBER;
      v_assignmentid         NUMBER;
      v_supervisorusername   VARCHAR2 (100);
      v_locationid           NUMBER;
      v_country              VARCHAR2 (10);
      v_hcmrespname          VARCHAR2 (100);
      v_usernames            VARCHAR2 (500);
      v_locationname         VARCHAR2 (100);
   BEGIN
      v_assignmentid :=
                     getoriginalnumtransvalue (p_item_key, 'P_ASSIGNMENT_ID');

      SELECT person_id
        INTO v_personid
        FROM per_assignments_f
       WHERE assignment_id = v_assignmentid
         AND SYSDATE BETWEEN effective_start_date AND effective_end_date;

      v_locationname := getlocationname (v_personid);

      IF TRIM (LENGTH (v_locationname)) = 0
      THEN
         v_locationname := getlocationnamepid (v_personid);
      END IF;

      v_emailaddress := getoscemail (v_personid, SYSDATE);
      v_userdisplayname := 'OSC for ' || v_locationname || ' - ' || p_item_key;
      wf_directory.createadhocuser
         (v_username,                      --          in out nocopy varchar2,
          v_userdisplayname,                 --       in out nocopy  varchar2,
          NULL,           --language                in  varchar2 default null,
          NULL,           --territory               in  varchar2 default null,
          NULL,           --role_description        in  varchar2 default null,
          'MAILHTML',
                     --notification_preference in varchar2 default 'MAILHTML',
          v_emailaddress, --email_address           in  varchar2 default null,
          NULL,           --fax                     in  varchar2 default null,
          'ACTIVE',   --status                  in  varchar2 default 'ACTIVE',
          TRUNC (SYSDATE + 2),
                              --expiration_date         in  date default null,
          NULL,           -- parent_orig_system      in varchar2 default null,
          NULL
         );                  -- parent_orig_system_id   in number default null
      wf_engine.setitemattrtext (itemtype      => p_item_type,
                                 itemkey       => p_item_key,
                                 aname         => 'TTEC_SETUP_OLD_OSC_USER',
                                 avalue        => v_username
                                );
      RESULT := 'COMPLETE:';
   EXCEPTION
      WHEN OTHERS
      THEN
         wf_engine.setitemattrtext (itemtype      => p_item_type,
                                    itemkey       => p_item_key,
                                    aname         => 'TTEC_SETUP_OLD_OSC_USER',
                                    avalue        => 'BLROYBAL'
                                   );
         RESULT := 'COMPLETE:';
   END setupoldoscroleassignment;

-----------------------------------------------------------
-----------------------------------------------------------
   PROCEDURE setupnewoscroleassignment (
      p_item_type   IN              VARCHAR2,
      p_item_key    IN              VARCHAR2,
      p_act_id      IN              NUMBER,
      funmode       IN              VARCHAR2,
      RESULT        OUT NOCOPY      VARCHAR2
   )
   IS
      v_username             VARCHAR2 (100);
      v_userdisplayname      VARCHAR2 (400);
      v_effectivedate        DATE;
      v_emailaddress         VARCHAR2 (300);
      v_personid             NUMBER;
      v_assignmentid         NUMBER;
      v_supervisorusername   VARCHAR2 (100);
      v_locationid           NUMBER;
      v_country              VARCHAR2 (10);
      v_hcmrespname          VARCHAR2 (100);
      v_usernames            VARCHAR2 (500);
      v_locationname         VARCHAR2 (100);
   BEGIN
      v_assignmentid :=
               getnumtransactionvaluefromitem (p_item_key, 'P_ASSIGNMENT_ID');

      SELECT person_id
        INTO v_personid
        FROM per_assignments_f
       WHERE assignment_id = v_assignmentid
         AND SYSDATE BETWEEN effective_start_date AND effective_end_date;

      v_locationname := getlocationnamepid (v_personid);
      v_emailaddress := getoscemail (v_personid, SYSDATE);
      v_userdisplayname := 'OSC for ' || v_locationname || ' - ' || p_item_key;
      wf_directory.createadhocuser
         (v_username,                      --          in out nocopy varchar2,
          v_userdisplayname,                 --       in out nocopy  varchar2,
          NULL,           --language                in  varchar2 default null,
          NULL,           --territory               in  varchar2 default null,
          NULL,           --role_description        in  varchar2 default null,
          'MAILHTML',
                     --notification_preference in varchar2 default 'MAILHTML',
          v_emailaddress, --email_address           in  varchar2 default null,
          NULL,           --fax                     in  varchar2 default null,
          'ACTIVE',   --status                  in  varchar2 default 'ACTIVE',
          TRUNC (SYSDATE + 2),
                              --expiration_date         in  date default null,
          NULL,           -- parent_orig_system      in varchar2 default null,
          NULL
         );                  -- parent_orig_system_id   in number default null
      wf_engine.setitemattrtext (itemtype      => p_item_type,
                                 itemkey       => p_item_key,
                                 aname         => 'TTEC_SETUP_NEW_OSC_USER',
                                 avalue        => v_username
                                );
      RESULT := 'COMPLETE:';
   EXCEPTION
      WHEN OTHERS
      THEN
         wf_engine.setitemattrtext (itemtype      => p_item_type,
                                    itemkey       => p_item_key,
                                    aname         => 'TTEC_SETUP_OLD_OSC_USER',
                                    avalue        => 'BLROYBAL'
                                   );
         RESULT := 'COMPLETE:';
   END setupnewoscroleassignment;

-----------------------------------------------------------
   PROCEDURE setupnewoscrole (
      p_item_type   IN              VARCHAR2,
      p_item_key    IN              VARCHAR2,
      p_act_id      IN              NUMBER,
      funmode       IN              VARCHAR2,
      RESULT        OUT NOCOPY      VARCHAR2
   )
   IS
      v_username             VARCHAR2 (100);
      v_userdisplayname      VARCHAR2 (400);
      v_effectivedate        DATE;
      v_emailaddress         VARCHAR2 (300);
      v_personid             NUMBER;
      v_supervisorid         NUMBER;
      v_supervisorusername   VARCHAR2 (100);
      v_locationid           NUMBER;
      v_country              VARCHAR2 (10);
      v_hcmrespname          VARCHAR2 (100);
      v_usernames            VARCHAR2 (500);
      v_locationname         VARCHAR2 (100);
   BEGIN
      v_supervisorid :=
         getnumtransactionvaluefromitem (p_item_key,
                                         'P_SELECTED_PERSON_SUP_ID'
                                        );
      v_locationname := getlocationname (getlocationid (v_supervisorid));
      v_userdisplayname :=
               'Receiving OSC (' || v_locationname || '-' || p_item_key || ')';
      mydebug ('setupNewOSCRole :' || v_supervisorid);
      v_emailaddress := getoscemail (v_supervisorid, SYSDATE);
      mydebug ('email found setupNewOSCRole :' || v_supervisorid);
      wf_directory.createadhocuser
         (v_username,                      --          in out nocopy varchar2,
          v_userdisplayname,                 --       in out nocopy  varchar2,
          NULL,           --language                in  varchar2 default null,
          NULL,           --territory               in  varchar2 default null,
          NULL,           --role_description        in  varchar2 default null,
          'MAILHTML',
                     --notification_preference in varchar2 default 'MAILHTML',
          v_emailaddress, --email_address           in  varchar2 default null,
          NULL,           --fax                     in  varchar2 default null,
          'ACTIVE',   --status                  in  varchar2 default 'ACTIVE',
          TRUNC (SYSDATE + 2),
                              --expiration_date         in  date default null,
          NULL,           -- parent_orig_system      in varchar2 default null,
          NULL
         );                  -- parent_orig_system_id   in number default null
      wf_engine.setitemattrtext (itemtype      => p_item_type,
                                 itemkey       => p_item_key,
                                 aname         => 'TTEC_SETUP_REC_OSC_USER',
                                 avalue        => v_username
                                );
      RESULT := 'COMPLETE:';
   EXCEPTION
      WHEN OTHERS
      THEN
         wf_engine.setitemattrtext (itemtype      => p_item_type,
                                    itemkey       => p_item_key,
                                    aname         => 'TTEC_SETUP_REC_OSC_USER',
                                    avalue        => 'BLROYBAL'
                                   );
         RESULT := 'COMPLETE:';
   END setupnewoscrole;

-----------------------------------------------------------
   PROCEDURE setupnewoscrolelocation (
      p_item_type   IN              VARCHAR2,
      p_item_key    IN              VARCHAR2,
      p_act_id      IN              NUMBER,
      funmode       IN              VARCHAR2,
      RESULT        OUT NOCOPY      VARCHAR2
   )
   IS
      v_username             VARCHAR2 (100);
      v_userdisplayname      VARCHAR2 (400);
      v_effectivedate        DATE;
      v_emailaddress         VARCHAR2 (300);
      v_personid             NUMBER;
      v_locationid           NUMBER;
      v_supervisorusername   VARCHAR2 (100);
      v_country              VARCHAR2 (10);
      v_hcmrespname          VARCHAR2 (100);
      v_usernames            VARCHAR2 (500);
      v_locationname         VARCHAR2 (100);
   BEGIN
      v_locationid :=
                 getnumtransactionvaluefromitem (p_item_key, 'P_LOCATION_ID');
      v_emailaddress := getoscemaillocation (v_locationid, SYSDATE);

      SELECT location_code
        INTO v_locationname
        FROM hr_locations_all
       WHERE location_id = v_locationid;

      v_userdisplayname :=
               'Receiving OSC (' || v_locationname || '-' || p_item_key || ')';
      wf_directory.createadhocuser
         (v_username,                      --          in out nocopy varchar2,
          v_userdisplayname,                 --       in out nocopy  varchar2,
          NULL,           --language                in  varchar2 default null,
          NULL,           --territory               in  varchar2 default null,
          NULL,           --role_description        in  varchar2 default null,
          'MAILHTML',
                     --notification_preference in varchar2 default 'MAILHTML',
          v_emailaddress, --email_address           in  varchar2 default null,
          NULL,           --fax                     in  varchar2 default null,
          'ACTIVE',   --status                  in  varchar2 default 'ACTIVE',
          TRUNC (SYSDATE + 2),
                              --expiration_date         in  date default null,
          NULL,           -- parent_orig_system      in varchar2 default null,
          NULL
         );                  -- parent_orig_system_id   in number default null
      wf_engine.setitemattrtext (itemtype      => p_item_type,
                                 itemkey       => p_item_key,
                                 aname         => 'TTEC_SETUP_REC_OSC_USER',
                                 avalue        => v_username
                                );
      RESULT := 'COMPLETE:';
   EXCEPTION
      WHEN OTHERS
      THEN
         wf_engine.setitemattrtext (itemtype      => p_item_type,
                                    itemkey       => p_item_key,
                                    aname         => 'TTEC_SETUP_REC_OSC_USER',
                                    avalue        => 'BLROYBAL'
                                   );
         RESULT := 'COMPLETE:';
   END setupnewoscrolelocation;

-----------------------------------------------------------
   PROCEDURE setupoldoscrolelocation (
      p_item_type   IN              VARCHAR2,
      p_item_key    IN              VARCHAR2,
      p_act_id      IN              NUMBER,
      funmode       IN              VARCHAR2,
      RESULT        OUT NOCOPY      VARCHAR2
   )
   IS
      v_username             VARCHAR2 (100);
      v_userdisplayname      VARCHAR2 (400);
      v_effectivedate        DATE;
      v_emailaddress         VARCHAR2 (300);
      v_personid             NUMBER;
      v_locationid           NUMBER;
      v_supervisorusername   VARCHAR2 (100);
      v_country              VARCHAR2 (10);
      v_hcmrespname          VARCHAR2 (100);
      v_usernames            VARCHAR2 (500);
      v_locationname         VARCHAR2 (100);
   BEGIN
      v_locationid := getoriginalnumtransvalue (p_item_key, 'P_LOCATION_ID');
      v_locationname := getlocationname (v_locationid);
      v_emailaddress := getoscemaillocation (v_locationid, SYSDATE);
      v_userdisplayname :=
                        'OSC (' || v_locationname || '-' || p_item_key || ')';
      wf_directory.createadhocuser
         (v_username,                      --          in out nocopy varchar2,
          v_userdisplayname,                 --       in out nocopy  varchar2,
          NULL,           --language                in  varchar2 default null,
          NULL,           --territory               in  varchar2 default null,
          NULL,           --role_description        in  varchar2 default null,
          'MAILHTML',
                     --notification_preference in varchar2 default 'MAILHTML',
          v_emailaddress, --email_address           in  varchar2 default null,
          NULL,           --fax                     in  varchar2 default null,
          'ACTIVE',   --status                  in  varchar2 default 'ACTIVE',
          TRUNC (SYSDATE + 2),
                              --expiration_date         in  date default null,
          NULL,           -- parent_orig_system      in varchar2 default null,
          NULL
         );                  -- parent_orig_system_id   in number default null
      wf_engine.setitemattrtext (itemtype      => p_item_type,
                                 itemkey       => p_item_key,
                                 aname         => 'TTEC_SETUP_OLD_OSC_USER',
                                 avalue        => v_username
                                );
      RESULT := 'COMPLETE:';
   EXCEPTION
      WHEN OTHERS
      THEN
         wf_engine.setitemattrtext (itemtype      => p_item_type,
                                    itemkey       => p_item_key,
                                    aname         => 'TTEC_SETUP_OLD_OSC_USER',
                                    avalue        => 'BLROYBAL'
                                   );
         RESULT := 'COMPLETE:';
   END setupoldoscrolelocation;

-----------------------------------------------------------
   FUNCTION ttec_adhoc_hr_local_unames (
      p_person_id         NUMBER,
      responsibilitykey   VARCHAR2
   )
      RETURN VARCHAR2
   IS
      hruserslist         VARCHAR2 (1000) := '';
      v_organization_id   NUMBER;
      v_location_id       NUMBER;

      CURSOR getlocalapprovers_c (loc_id NUMBER, org_id NUMBER)
      IS
         SELECT user_id, user_name
           FROM fnd_user fu
          WHERE user_id IN (
                   SELECT user_id
                     FROM fnd_user_resp_groups
                    WHERE SYSDATE BETWEEN start_date
                                      AND NVL (end_date, SYSDATE + 1)
                      AND responsibility_id IN (
                                  SELECT responsibility_id
                                    FROM fnd_responsibility
                                   WHERE responsibility_key =
                                                             responsibilitykey))
            AND EXISTS (
                   SELECT 'x'
                     FROM per_all_people_f pp, per_all_assignments_f pa
                    WHERE SYSDATE BETWEEN pp.effective_start_date
                                      AND pp.effective_end_date
                      AND SYSDATE BETWEEN pa.effective_start_date
                                      AND pa.effective_end_date
                      AND pp.person_id = pa.person_id
                      AND pp.person_id = fu.employee_id
                      AND pa.location_id = loc_id)
            AND SYSDATE < NVL (end_date, SYSDATE + 1);
   --and pa.organization_id = org_id);
   BEGIN
      mydebug ('Start ad_hoc_hr_local_unames');

---        Find person location and org
      SELECT pa.location_id, pa.organization_id
        INTO v_location_id, v_organization_id
        FROM per_all_people_f pp, per_all_assignments_f pa
       WHERE pp.person_id = pa.person_id
         AND pp.person_id = p_person_id
         AND SYSDATE BETWEEN pp.effective_start_date AND pp.effective_end_date
         AND SYSDATE BETWEEN pa.effective_start_date AND pa.effective_end_date;

      -- Build the users list
      mydebug ('Step 102 #' || v_location_id || ':' || v_organization_id);

      FOR c IN getlocalapprovers_c (v_location_id, v_organization_id)
      LOOP
         hruserslist := hruserslist || c.user_name || ',';
      END LOOP;

      hruserslist := RTRIM (hruserslist, ',');

      IF LENGTH (hruserslist) = 0
      THEN
         RAISE NO_DATA_FOUND;
         hruserslist := ' ';
      END IF;

      RETURN hruserslist;
   EXCEPTION
      WHEN OTHERS
      THEN
         RAISE NO_DATA_FOUND;
   END ttec_adhoc_hr_local_unames;

-------------------------

   -----------------------------------------------------------
   FUNCTION ttec_adhoc_hr_local_unames_l (
      p_location_id       NUMBER,
      p_organization_id   NUMBER,
      responsibilitykey   VARCHAR2
   )
      RETURN VARCHAR2
   IS
      hruserslist         VARCHAR2 (1000) := '';
      v_organization_id   NUMBER;
      v_location_id       NUMBER;

      CURSOR getlocalapprovers_c (loc_id NUMBER, org_id NUMBER)
      IS
         SELECT user_id, user_name
           FROM fnd_user fu
          WHERE user_id IN (
                   SELECT user_id
                     FROM fnd_user_resp_groups
                    WHERE SYSDATE BETWEEN start_date
                                      AND NVL (end_date, SYSDATE + 1)
                      AND responsibility_id IN (
                                  SELECT responsibility_id
                                    FROM fnd_responsibility
                                   WHERE responsibility_key =
                                                             responsibilitykey))
            AND EXISTS (
                   SELECT 'x'
                     FROM per_all_people_f pp, per_all_assignments_f pa
                    WHERE SYSDATE BETWEEN pp.effective_start_date
                                      AND pp.effective_end_date
                      AND SYSDATE BETWEEN pa.effective_start_date
                                      AND pa.effective_end_date
                      AND pp.person_id = pa.person_id
                      AND pp.person_id = fu.employee_id
                      AND pa.location_id = p_location_id)
            AND SYSDATE < NVL (end_date, SYSDATE + 1);
   --and pa.organization_id = org_id);
   BEGIN
      mydebug ('Start ad_hoc_hr_local_unames_l');
---        Find person location and org
      mydebug ('Step 102 #' || v_location_id || ':' || v_organization_id);

      FOR c IN getlocalapprovers_c (p_location_id, p_organization_id)
      LOOP
         hruserslist := hruserslist || c.user_name || ',';
      END LOOP;

      hruserslist := RTRIM (hruserslist, ',');

      IF LENGTH (hruserslist) = 0
      THEN
         RAISE NO_DATA_FOUND;
         hruserslist := ' ';
      END IF;

      RETURN hruserslist;
   EXCEPTION
      WHEN OTHERS
      THEN
         RAISE NO_DATA_FOUND;
   END ttec_adhoc_hr_local_unames_l;

-------------------------

   -----------------------------------------------------------
   PROCEDURE setupnewsupusername (
      p_item_type   IN              VARCHAR2,
      p_item_key    IN              VARCHAR2,
      p_act_id      IN              NUMBER,
      funmode       IN              VARCHAR2,
      RESULT        OUT NOCOPY      VARCHAR2
   )
   IS
      v_username             VARCHAR2 (100);
      v_userdisplayname      VARCHAR2 (400);
      v_effectivedate        DATE;
      v_emailaddress         VARCHAR2 (300);
      v_personid             NUMBER;
      v_supervisorid         NUMBER;
      v_supervisorusername   VARCHAR2 (100);
      v_locationid           NUMBER;
      v_country              VARCHAR2 (10);
      v_hcmrespname          VARCHAR2 (100);
      v_usernames            VARCHAR2 (500);
   BEGIN
      v_supervisorid :=
         getnumtransactionvaluefromitem (p_item_key,
                                         'P_SELECTED_PERSON_SUP_ID'
                                        );

      SELECT user_name
        INTO v_supervisorusername
        FROM fnd_user
       WHERE employee_id = v_supervisorid
         AND SYSDATE < NVL (end_date, SYSDATE + 1);

      mydebug ('SetupNewSupUserName ' || v_supervisorusername);
      wf_engine.setitemattrtext (itemtype      => p_item_type,
                                 itemkey       => p_item_key,
                                 aname         => 'TTEC_NEW_SUPERVISOR_USER_NAME',
                                 avalue        => v_supervisorusername
                                );
      wf_engine.setitemattrtext (itemtype      => p_item_type,
                                 itemkey       => p_item_key,
                                 aname         => 'TTEC_REC_SUPERVISOR_USER_NAME',
                                 avalue        => v_supervisorusername
                                );
      RESULT := 'COMPLETE:';
   END setupnewsupusername;

-----------------------------------------------------------
-----------------------------------------------------------
   PROCEDURE setupoldsupusername (
      p_item_type   IN              VARCHAR2,
      p_item_key    IN              VARCHAR2,
      p_act_id      IN              NUMBER,
      funmode       IN              VARCHAR2,
      RESULT        OUT NOCOPY      VARCHAR2
   )
   IS
      v_username             VARCHAR2 (100);
      v_userdisplayname      VARCHAR2 (400);
      v_effectivedate        DATE;
      v_emailaddress         VARCHAR2 (300);
      v_personid             NUMBER;
      v_supervisorid         NUMBER;
      v_supervisorusername   VARCHAR2 (100);
      v_locationid           NUMBER;
      v_country              VARCHAR2 (10);
      v_hcmrespname          VARCHAR2 (100);
      v_usernames            VARCHAR2 (500);
   BEGIN
      v_supervisorid :=
         getnumtransactionvaluefromitem (p_item_key,
                                         'P_SELECTED_PERSON_OLD_SUP_ID'
                                        );

      SELECT user_name
        INTO v_supervisorusername
        FROM fnd_user
       WHERE employee_id = v_supervisorid
         AND SYSDATE < NVL (end_date, SYSDATE + 1);

      mydebug ('SetupOldSupUserName ' || v_supervisorusername);
      wf_engine.setitemattrtext (itemtype      => p_item_type,
                                 itemkey       => p_item_key,
                                 aname         => 'TTEC_OLD_SUPERVISOR_USER_NAME',
                                 avalue        => v_supervisorusername
                                );
      RESULT := 'COMPLETE:';
   END setupoldsupusername;

-----------------------------------------------------------
   PROCEDURE ispaybasishastobechanged (
      p_item_type   IN              VARCHAR2,
      p_item_key    IN              VARCHAR2,
      p_act_id      IN              NUMBER,
      funmode       IN              VARCHAR2,
      RESULT        OUT NOCOPY      VARCHAR2
   )
   IS
      v_originalpb        NUMBER;
      v_newpb             NUMBER;
      v_originaljobid     NUMBER;
      v_newjobid          NUMBER;
      v_personid          NUMBER;
      v_j3                VARCHAR2 (50);
      v_origj3            VARCHAR2 (50);
      v_attribute9        VARCHAR2 (50);
      v_paybasisname      VARCHAR2 (100);
      v_paybasisnamen     VARCHAR2 (100);
      v_businessgroupid   NUMBER;
      v_paybasisid        NUMBER;
      v_rowid             VARCHAR2 (50);
--pragma AUTONOMOUS_TRANSACTION;
   BEGIN
      v_personid :=
         wf_engine.getitemattrnumber (itemtype      => p_item_type,
                                      itemkey       => p_item_key,
                                      aname         => 'CURRENT_PERSON_ID'
                                     );
      v_newpb := getnumtransactionvaluefromitem (p_item_key, 'P_PAY_BASIS_ID');
      v_originalpb := getoriginalnumtransvalue (p_item_key, 'P_PAY_BASIS_ID');
      v_newjobid := getnumtransactionvaluefromitem (p_item_key, 'P_JOB_ID');
      v_originaljobid := getoriginalnumtransvalue (p_item_key, 'P_JOB_ID');
      v_newjobid := NVL (v_newjobid, v_originaljobid);
      v_newpb := NVL (v_newpb, v_originalpb);
      v_businessgroupid :=
            getnumtransactionvaluefromitem (p_item_key, 'P_BUSINESS_GROUP_ID');

      SELECT ROWID
        INTO v_rowid
        FROM hr_api_transaction_values
       WHERE transaction_step_id IN (
                           SELECT transaction_step_id
                             FROM hr_api_transaction_steps
                            WHERE item_type = 'HRSSA'
                                  AND item_key = p_item_key)
         AND NAME = 'P_PAY_BASIS_ID'
         AND ROWNUM < 2;

      SELECT NVL (job_information3, 'X')
        INTO v_j3
        FROM per_jobs
       WHERE job_id = v_newjobid;

      SELECT NVL (job_information3, 'X')
        INTO v_origj3
        FROM per_jobs
       WHERE job_id = v_originaljobid;

      IF v_j3 = 'EX'
      THEN
         v_paybasisname := 'ANNUAL';
      END IF;

      IF v_j3 = 'NEX'
      THEN
         v_paybasisname := 'HOURLY';
      END IF;

      IF v_j3 = 'SNE'
      THEN
         v_paybasisname := 'ANNUAL';
      END IF;

      /*
         if v_OrigJ3 = 'EX' Then v_payBasisNameN := 'Salary/Exempt'; End If;

         if v_OrigJ3 = 'NEX' Then v_payBasisNameN := 'Hourly/Non-Exempt'; End If;

         if v_OrigJ3 = 'SNE' Then v_payBasisNameN := 'Salary/Non-Exempt'; End If;
      */
      mydebug (   'Pay bases diff '
               || v_newpb
               || '-'
               || v_origj3
               || '-'
               || v_j3
               || '-'
               || v_origj3
              );

         /*

         select rate_basis
          into v_payBasisName
          from per_pay_bases
          where business_group_id= v_businessGroupid
          and pay_basis_id  = v_originalPB;
      */
      SELECT rate_basis
        INTO v_paybasisnamen
        FROM per_pay_bases
       WHERE business_group_id = v_businessgroupid AND pay_basis_id = v_newpb;

      DBMS_OUTPUT.put_line (v_paybasisnamen || '-' || v_paybasisname);

      IF v_paybasisname != v_paybasisnamen
      THEN
         RESULT := 'COMPLETE:Y';
      ELSE
         RESULT := 'COMPLETE:N';
      END IF;

         /*
               update hr_api_transaction_values
                set number_value=v_payBasisId
                where rowid = v_rowid;

                  commit;
      */
      mydebug ('Change Pay Basis ' || v_paybasisid);
   EXCEPTION
      WHEN OTHERS
      THEN
         NULL;
         RESULT := 'COMPLETE:N';
   END;

-----------------------------------------------------------
   PROCEDURE setupactualapprover (
      p_item_type   IN              VARCHAR2,
      p_item_key    IN              VARCHAR2,
      p_act_id      IN              NUMBER,
      funmode       IN              VARCHAR2,
      RESULT        OUT NOCOPY      VARCHAR2
   )
   IS
      v_actualusername     fnd_user.user_name%TYPE;
      v_person_id          NUMBER;
      v_actualpersonname   VARCHAR2 (100);
      v_originalapprover   VARCHAR2 (100);
   BEGIN
      v_actualusername :=
         wf_engine.getitemattrtext (itemtype      => 'HRSSA',
                                    itemkey       => p_item_key,
                                    aname         => 'HR_CONTEXT_USER_ATTR'
                                   );
      v_originalapprover :=
         wf_engine.getitemattrtext (itemtype      => 'HRSSA',
                                    itemkey       => p_item_key,
                                    aname         => 'HR_CONTEXT_ORIG_RECIPIENT_ATTR'
                                   );
      mydebug ('ActualUserName=' || v_actualusername);
      mydebug ('OriginalApproverUserName=' || v_originalapprover);

      IF v_originalapprover LIKE '~WF%'
      THEN
         v_person_id := getpersonidbyusername (v_actualusername);
         v_actualpersonname := getpersonfullname (v_person_id);
         mydebug ('ActualUserId=' || v_person_id);
         mydebug ('ActualPersonName=' || v_actualpersonname);
         wf_engine.setitemattrtext (itemtype      => p_item_type,
                                    itemkey       => p_item_key,
                                    aname         => 'FORWARD_TO_USERNAME',
                                    avalue        => v_actualusername
                                   );
         wf_engine.setitemattrnumber (itemtype      => p_item_type,
                                      itemkey       => p_item_key,
                                      aname         => 'FORWARD_TO_PERSON_ID',
                                      avalue        => v_person_id
                                     );
         wf_engine.setitemattrtext (itemtype      => p_item_type,
                                    itemkey       => p_item_key,
                                    aname         => 'FORWARD_TO_DISPLAY_NAME',
                                    avalue        => v_actualpersonname
                                   );
      END IF;

      RESULT := 'COMPLETE:Y';
   EXCEPTION
      WHEN OTHERS
      THEN
         NULL;
         RESULT := 'COMPLETE:Y';
   END setupactualapprover;

-----------------------------------------------------------
   FUNCTION getpersonidbyusername (p_user_name VARCHAR2)
      RETURN NUMBER
   IS
      retvalue   VARCHAR2 (150);
   BEGIN
      SELECT employee_id
        INTO retvalue
        FROM fnd_user
       WHERE SYSDATE < NVL (end_date, SYSDATE + 1) AND user_name = p_user_name;

      RETURN retvalue;
   EXCEPTION
      WHEN OTHERS
      THEN
         RETURN NULL;
   END;

-----------------------------------------------------------
   FUNCTION getjobname (p_jobid NUMBER)
      RETURN VARCHAR2
   IS
      retvalue      VARCHAR2 (150);
      debugstring   VARCHAR2 (200);
   BEGIN
      mydebug ('GetJobname ' || p_jobid);

      SELECT NAME
        INTO retvalue
        FROM per_jobs
       WHERE job_id = p_jobid
         AND SYSDATE BETWEEN date_from AND NVL (date_to, SYSDATE + 1);

      mydebug (' Job code part found ' || retvalue);
      retvalue := SUBSTR (retvalue, 1, INSTR (retvalue, '.') - 1);
      mydebug (' Job code part found ' || retvalue);
      RETURN retvalue;
   EXCEPTION
      WHEN OTHERS
      THEN
         debugstring := SUBSTR (SQLERRM, 1, 200);
         mydebug (debugstring);
         RETURN NULL;
   END getjobname;

-----------------------------------------------------------
-----------------------------------------------------------
   FUNCTION getgradeid (p_gradename VARCHAR2, p_bid NUMBER)
      RETURN NUMBER
   IS
      retvalue   NUMBER;
   BEGIN
      mydebug (' Find grade ' || p_gradename || '-' || p_bid);

      SELECT grade_id
        INTO retvalue
        FROM per_grades
       WHERE NAME = p_gradename
         AND business_group_id = p_bid
         AND SYSDATE BETWEEN date_from AND NVL (date_to, SYSDATE + 1);

      mydebug (' Job code part found ' || retvalue);
--     retValue := substr(retValue,1,instr(retValue,'.')-1);
      RETURN retvalue;
   EXCEPTION
      WHEN OTHERS
      THEN
         RETURN NULL;
   END getgradeid;

--------------------------------------------------------------
   FUNCTION gethcmroledescription (p_item_key VARCHAR2)
      RETURN VARCHAR2
   IS
      retvalue   VARCHAR2 (100);
   BEGIN
      SELECT description
        INTO retvalue
        FROM ttec_temp_wf
       WHERE item_key = p_item_key AND KEY = 'APPROVAL1' AND ROWNUM < 2;

      RETURN retvalue;
   EXCEPTION
      WHEN OTHERS
      THEN
         retvalue := 'HCM approval role ';
         RETURN retvalue;
   END;
--------------------------------------------------------------
END teltec_custom_wf_utility;
/
show errors;
/
