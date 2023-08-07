 /************************************************************************************
        Program Name:  Tt_Internet_null_Profile

       Modification Log
       Name                  Version #    Date            Description
       -----                 --------     -----           -------------
    IXPRAVEEN(ARGANO)            1.0     24-May-2023     R12.2 Upgrade Remediation
    ****************************************************************************************/
create or replace PACKAGE BODY Tt_Internet_null_Profile IS

PROCEDURE dml_record  (p_rowid IN ROWID,
                       p_last_update_date IN DATE,
                       p_last_updated_by IN NUMBER,
                       p_last_update_login IN NUMBER)  IS

BEGIN
            /* D E L E T E */

IF p_rowid IS NOT NULL THEN
         DELETE FROM fnd_profile_option_values v WHERE v.rowid = p_rowid;
       cnt := cnt + 1;
END IF;

EXCEPTION
           WHEN OTHERS THEN
		 apps.Fnd_File.put_line(2,'Error at updating Profile option :'||SQLCODE||'-'||SQLERRM);
           RAISE;
END dml_record;

PROCEDURE  profile_null_set(ERRBUF OUT VARCHAR2,
                            RETCODE OUT NUMBER,
                            p_location_id IN NUMBER) IS

   x_prof_appl_id            NUMBER := 0;
   x_web_profile_id          NUMBER := 2353;   --Applications Web Agent
   x_web_profile_value       VARCHAR2(120)  := 'https://erp.teletech.com/pls/PROD';
   x_framework_profile_id    NUMBER := 3942;   --Application Framework Agent
   x_framework_profile_value VARCHAR2(120)  := 'https://erp.teletech.com';
   x_servlet_profile_id      NUMBER := 3804;    --Apps Servlet Agent
   x_servlet_profile_value   VARCHAR2(120)  := 'https://erp.teletech.com/oa_servlets';

   x_level_id             NUMBER := 10004;   -- User
   x_level_value          NUMBER ;
   x_level_value_appl_id  NUMBER := NULL;
   x_last_update_date     DATE;
   x_last_updated_by      NUMBER;
   x_last_update_login    NUMBER;
   profile_level          VARCHAR2(60);
   old_profile_option_value VARCHAR2(120);


--  Andy provided this query
--  He wants to update profile option value to null for
--  open enrollment on November,04th 2005

    CURSOR  c_agent IS
	SELECT a.rowid,c.employee_number
	--START R12.2 Upgrade Remediation
	/*FROM apps.FND_PROFILE_OPTION_VALUES a,				-- Commented code by IXPRAVEEN-ARGANO,09-May-2023
	     apps.fnd_user b,                                   
	     hr.per_all_people_f c,
	     hr.per_all_assignments_f d,
             hr.hr_locations_all e*/
	FROM apps.FND_PROFILE_OPTION_VALUES a,					--  code Added by IXPRAVEEN-ARGANO,09-May-2023
	     apps.fnd_user b,
	     apps.per_all_people_f c,
	     apps.per_all_assignments_f d,
         apps.hr_locations_all e
		 --END R12.2.10 Upgrade remediation
       WHERE profile_option_id in ('3942','2353','3804')
       AND level_id = '10004'
       AND a.level_value = b.user_id
       AND b.employee_id = c.person_id
       AND c.person_id = d.person_id
       AND d.location_id = e.location_id
       AND e.location_id = p_location_id
       AND SYSDATE BETWEEN c.effective_start_date AND c.effective_end_date
       AND SYSDATE BETWEEN d.effective_start_date AND d.effective_end_date
       ORDER BY c.full_name;

 BEGIN

   apps.Fnd_File.put_line(2,'Starting Profile Update program');
   apps.Fnd_File.put_line(2,'location is '||p_location_id);

   x_last_update_date := SYSDATE;
   x_last_updated_by := -1;
   x_last_update_login := -1;
  IF p_location_id IS NOT NULL THEN

   FOR r_agent IN c_agent LOOP

       BEGIN

         dml_record  (r_agent.rowid,
                        x_last_update_date,
                        x_last_updated_by,
                        x_last_update_login) ;

	EXCEPTION
          WHEN OTHERS THEN
            Fnd_File.put_line(2,'Error while processing Employee Number: '|| r_agent.employee_number );
        END;

   END LOOP;
   apps.Fnd_File.put_line(2,'Count is '||cnt);
   COMMIT;
  apps.Fnd_File.put_line(2,'End Profile Update program');
 ELSE
   apps.Fnd_File.put_line(2,'Location should be entered');
 END IF;


 END profile_null_set;


END Tt_Internet_null_Profile;
/
show errors;
/