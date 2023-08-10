create or replace PACKAGE BODY TTEC_HR_EDC_NA_REPORT AS





 /************************************************************************************
        Program Name:     TTEC_HR_EDC_NA_REPORT

        Description:   

        Developed by : 
        Date         :  

       Modification Log
       Name                  Version #    Date            Description
       -----                 --------     -----           -------------
    RXNETHI(ARGANO)            1.0      30-JUN-2023      R12.2 Upgrade Remediation
    ****************************************************************************************/









l_creation_date date;
l_update_date date;
l_full_name varchar2(100);
l_business_group_id number;
l_person_id number;
l_previous_person_id number;
l_change_since_date date;


PROCEDURE get_edc_info(errcode varchar2, errbuff varchar2, P_OUTPUT_DIR IN VARCHAR2,p_change_since_this_date IN DATE) IS


  -- Filehandle Variables
  p_FileDir VARCHAR2(60) :=  p_output_dir;
  p_FileName VARCHAR2(50):= 'HR_NA_EDC_DAILY.out';
  v_daily_file UTL_FILE.FILE_TYPE;

  -- Declare variables
  l_rec 	VARCHAR2(1000);
  emp_full_name VARCHAR2(100);
  emp_Person_Type VARCHAR2(30);
  emp_JOB         VARCHAR2(1000);
  emp_Previous_JOB   VARCHAR2(1000);
  emp_Location_Name VARCHAR2(100);
  emp_Prev_Loc_Name VARCHAR2(100);
  emp_STATUS        VARCHAR2(100);
  emp_Supervisor    VARCHAR2(100);
  emp_Prev_Supervisor VARCHAR2(100);
  emp_SOB           VARCHAR2(100);
  emp_Expense_Account  VARCHAR2(100);
  emp_Email_Address    VARCHAR2(300);
  emp_emp_creation_date VARCHAR2(50);
  emp_emp_last_update_date VARCHAR2(50);
  emp_asg_creation_date    VARCHAR2(50);
  emp_asg_last_update_date  VARCHAR2(50);

cursor c_run_date is
select  decode( substr(to_char(SYSDATE,'DAY'),1,6),'MONDAY',TRUNC(SYSDATE) - 3,TRUNC(SYSDATE))
from dual;

cursor c_change_info is
select e.full_name, e.person_id,e.business_group_id,TRUNC(e.creation_date) creation_date,TRUNC(e.last_update_date) updated_date
--from hr.per_all_people_f e   --code commented by RXNETHI-ARGANO,30/06/23
from apps.per_all_people_f e   --code added by RXNETHI-ARGANO,30/06/23
where (  TRUNC(e.last_update_date) >= l_change_since_date
      or TRUNC(e.creation_date)    >= l_change_since_date
)
and e.business_group_id in ( 325,326)
 UNION
select p.full_name,a.person_id,a.business_group_id, TRUNC(a.creation_date) creation_date,TRUNC(a.last_update_date) updated_date
--from hr.per_all_assignments_f a,hr.per_all_people_f p      --code commented by RXNETHI-ARGANO,30/06/23
from apps.per_all_assignments_f a,apps.per_all_people_f p    --code added by RXNETHI-ARGANO,30/06/23
where (  TRUNC(a.last_update_date) >= l_change_since_date
      or TRUNC(a.creation_date)    >= l_change_since_date
)
and a.business_group_id in ( 325,326)
and a.person_id = p.person_id
AND trunc(sysdate) between p.effective_start_date and p.effective_end_date;

cursor c_emp is
select distinct emp.full_name Full_Name
, ptypes.user_person_type Person_Type
, job.name||'|'||asg.effective_start_date||'|'||asg.effective_end_date JOB
,(select job.name||'|'||asg.effective_start_date||'|'||asg.effective_end_date
--from hr.per_all_assignments_f asg   --code commented by RXNETHI-ARGANO,30/06/23
from apps.per_all_assignments_f asg   --code added by RXNETHI-ARGANO,30/06/23
   --, hr.per_jobs job                --code commented by RXNETHI-ARGANO,30/06/23
   , apps.per_jobs job                --code added by RXNETHI-ARGANO,30/06/23
where asg.person_id = emp.person_id
and asg.effective_end_date = (select MAX(effective_end_Date)
--from hr.per_all_assignments_f   --code commented by RXNETHI-ARGANO,30/06/23
from apps.per_all_assignments_f   --code added by RXNETHI-ARGANO,30/06/23
where effective_end_Date != '31-DEC-4712'
and person_id = emp.person_id)
and asg.job_id = job.job_id
and rownum = 1
)PREVIOUS_JOB
, loc.location_code Location_Name
,(select loc.location_code
--from hr.per_all_assignments_f asg     --code commented by RXNETHI-ARGANO,30/06/23
from apps.per_all_assignments_f asg     --code added by RXNETHI-ARGANO,30/06/23
   --, hr.hr_locations_all loc          --code commented by RXNETHI-ARGANO,30/06/23
   , apps.hr_locations_all loc          --code added by RXNETHI-ARGANO,30/06/23
where asg.person_id = emp.person_id
and asg.effective_end_date = (select MAX(effective_end_Date)
--from hr.per_all_assignments_f         --code commented by RXNETHI-ARGANO,30/06/23
from apps.per_all_assignments_f         --code added by RXNETHI-ARGANO,30/06/23
where effective_end_Date != '31-DEC-4712'
and person_id = emp.person_id)
and asg.location_id = loc.location_id
and rownum = 1
) Prev_location
, NVL(AMDTL.USER_STATUS, STTL.USER_STATUS) STATUS
, sup.full_name Supervisor
,(select sup.full_name
--from hr.per_all_assignments_f asg        --code commented by RXNETHI-ARGANO,30/06/23
from apps.per_all_assignments_f asg        --code added by RXNETHI-ARGANO,30/06/23
   --, hr.per_all_people_f sup             --code commented by RXNETHI-ARGANO,30/06/23
   , apps.per_all_people_f sup             --code added by RXNETHI-ARGANO,30/06/23
where asg.person_id = emp.person_id
and asg.effective_end_date = (select MAX(effective_end_Date)
--from hr.per_all_assignments_f            --code commented by RXNETHI-ARGANO,30/06/23
from apps.per_all_assignments_f            --code added by RXNETHI-ARGANO,30/06/23
where effective_end_Date != '31-DEC-4712'
and person_id = emp.person_id)
and asg.supervisor_id = sup.person_id
and rownum = 1
) Prev_Asg_Supervisor
, gl.name SOB
, (glc.segment1||'.'||glc.segment2||'.'||glc.segment3||'.'||glc.segment4||'.'||'NONE'||'.'||'NONE') Expense_Account
--, u.user_name UserID
, emp.email_address Email_Address
, emp.creation_date emp_creation_date
, emp.last_update_date emp_last_update_date
, asg.creation_date asg_creation_date
, asg.last_update_date asg_last_update_date
/*
START R12.2 Upgrade Remediation
code commented by RXNETHI-ARGANO,30/06/23
from hr.per_all_people_f emp
, hr.per_all_assignments_f asg
, hr.per_all_people_f sup
, hr.per_jobs job
, hr.per_person_types ptypes
, hr.hr_locations_all loc
, hr.hr_all_organization_units org
, apps.gl_sets_of_books gl
, apps.gl_code_combinations glc
, applsys.fnd_user u
, hr.per_ass_status_type_amends_tl amdtl
, hr.per_assignment_status_types_tl sttl
, hr.per_assignment_status_types st
, hr.per_ass_status_type_amends amd
*/
--code added by RXNETHI-ARGANO,30/06/23
from apps.per_all_people_f emp
, apps.per_all_assignments_f asg
, apps.per_all_people_f sup
, apps.per_jobs job
, apps.per_person_types ptypes
, apps.hr_locations_all loc
, apps.hr_all_organization_units org
, apps.gl_sets_of_books gl
, apps.gl_code_combinations glc
, apps.fnd_user u
, apps.per_ass_status_type_amends_tl amdtl
, apps.per_assignment_status_types_tl sttl
, apps.per_assignment_status_types st
, apps.per_ass_status_type_amends amd
--END R12.2 Upgrade Remediation
where emp.person_id = asg.person_id
and asg.supervisor_id = sup.person_id (+)
and emp.person_id = u.employee_id (+)
AND trunc(sysdate) between sup.effective_start_date(+) and sup.effective_end_date (+)
and asg.job_id = job.job_id (+)
and ptypes.system_person_type in ('EMP','EMP_APL','EX_EMP','EX_EMP_APL','RETIREE')
and asg.default_code_comb_id = glc.code_combination_id (+)
and asg.set_of_books_id = gl.set_of_books_id (+)
and asg.assignment_status_type_id = st.assignment_status_type_id
and asg.assignment_status_type_id = amd.assignment_status_type_id (+)
and asg.business_group_id + 0 = amd.business_group_id (+) + 0
AND ST.assignment_status_type_id = STTL.assignment_status_type_id
AND STTL.language = userenv('LANG')
AND AMD.ass_status_type_amend_id = AMDTL.ass_status_type_amend_id (+)
and emp.person_type_id = ptypes.person_type_id
and loc.location_id = asg.location_id
and org.organization_id = asg.organization_id
AND trunc(sysdate) between u.start_date(+) and NVL(u.end_date(+),trunc(sysdate))
AND trunc(sysdate) between emp.effective_start_date and emp.effective_end_date
and trunc(sysdate) between asg.effective_start_date AND asg.effective_end_date
AND emp.business_group_id = l_business_group_id
AND emp.person_id = l_person_id;


BEGIN
   if p_change_since_this_date is null then
      open c_run_date;
      fetch c_run_date into l_change_since_date;
      close c_run_date;
   else
      l_change_since_date := p_change_since_this_date;
   end if;

   v_daily_file := UTL_FILE.FOPEN(p_FileDir, p_FileName, 'w');

   l_rec := 'Report Name : TeleTech HR - North America Employee Data Change'; --||chr(13)||chr(10);
   utl_file.put_line(v_daily_file, l_rec);
   l_rec := 'Report Date : '||TRUNC(SYSDATE); --||chr(13)||chr(10);
   utl_file.put_line(v_daily_file, l_rec);
   l_rec := 'Change Since : '||l_change_since_date; --||chr(13)||chr(10);
   utl_file.put_line(v_daily_file, l_rec);
   l_rec := ''; --||chr(13)||chr(10);
   utl_file.put_line(v_daily_file, l_rec);
   l_rec := ''; --||chr(13)||chr(10);
   utl_file.put_line(v_daily_file, l_rec);
   l_rec := ''; --||chr(13)||chr(10);
   utl_file.put_line(v_daily_file, l_rec);
   l_rec := 'Full Name|Rec Creation Date|Rec Updated Date|Status|Person Types|Current Job Title|Current Asg Start Date|Current Asg End Date|Previous Asg Job Title|Prev Asg Start Date|Prev Asg End Date|Current Asg Location|Previous Asg Location|Current Supervisor|Prev Asg Supervisor|Sets Of Books|Default Expense Account|Email Address|Employee Creation Date|Employee Last Update Date|Assignment Creation Date|Assignment Last Update Date|'; --||chr(13)||chr(10);
   utl_file.put_line(v_daily_file, l_rec);


   apps.fnd_file.put_line(apps.fnd_file.output,'Report Name : TeleTech HR - North America Employee Data Change');
   apps.fnd_file.put_line(apps.fnd_file.output,'Report Date : '||TRUNC(SYSDATE));
   apps.fnd_file.put_line(apps.fnd_file.output,'Change Since : '||l_change_since_date);
   apps.fnd_file.new_line(apps.fnd_file.output,3);
   apps.fnd_file.put_line(apps.fnd_file.output,'Full Name|Rec Creation Date|Rec Updated Date|Status|Person Types|Current Job Title|Current Asg Start Date|Current Asg End Date|Previous Asg Job Title|Prev Asg Start Date|Prev Asg End Date|Current Asg Location|Previous Asg Location|Current Supervisor|Prev Asg Supervisor|Sets Of Books|Default Expense Account|Email Address|Employee Creation Date|Employee Last Update Date|Assignment Creation Date|Assignment Last Update Date|');
   apps.fnd_file.new_line(apps.fnd_file.output,2);
  l_previous_person_id := -1;
  open c_change_info;
  loop
    FETCH c_change_info into l_full_name
                            ,l_person_id
                            ,l_business_group_id
                            ,l_creation_date
                            ,l_update_date;

    EXIT when  c_change_info%NOTFOUND;

    if l_previous_person_id != l_person_id then


      Open c_emp;
         fetch c_emp into  emp_full_name
                         , emp_Person_Type
                         , emp_JOB
						 , emp_Previous_JOB
                         , emp_Location_Name
						 , emp_Prev_Loc_Name
                         , emp_STATUS
                         , emp_Supervisor
                         , emp_Prev_Supervisor
                         , emp_SOB
                         , emp_Expense_Account
                         , emp_Email_Address
                         , emp_emp_creation_date
                         , emp_emp_last_update_date
                         , emp_asg_creation_date
                         , emp_asg_last_update_date;

          if c_emp%NOTFOUND then

              null;

          /*   Do not show per Kha Le and Juanita Ozuna 09/21/2004

               apps.fnd_file.put_line(apps.fnd_file.output, l_full_name
                         ||'|'|| l_creation_date
                         ||'|'|| l_update_date
                         ||'|'|| 'No Valid Assignment. Business group id ->'||l_business_group_id);
               l_rec := l_full_name
                         ||'|'|| l_creation_date
                         ||'|'|| l_update_date
                         ||'|'|| 'No Valid Assignment. Business group id ->'||l_business_group_id;
               utl_file.put_line(v_daily_file, l_rec);
          */
          else



                l_rec :=  emp_Full_Name
                                            ||'|'|| l_creation_date
                                            ||'|'|| l_update_date
                                            ||'|'|| emp_STATUS
                                            ||'|'|| emp_Person_Type
                                            ||'|'|| nvl(emp_JOB,'||')
                                            ||'|'|| nvl(emp_Previous_JOB,'||')
                                            ||'|'|| emp_Location_Name
											||'|'|| emp_Prev_Loc_Name
                                            ||'|'|| emp_Supervisor
                                            ||'|'|| emp_Prev_Supervisor
                                            ||'|'|| emp_SOB
                                            ||'|'|| emp_Expense_Account
                                            ||'|'|| emp_Email_Address
                                            ||'|'|| emp_emp_creation_date
                                            ||'|'|| emp_emp_last_update_date
                                            ||'|'|| emp_asg_creation_date
                                            ||'|'|| emp_asg_last_update_date;
                                            --||chr(13)||chr(10);
              utl_file.put_line(v_daily_file, l_rec);
  	      apps.fnd_file.put_line(apps.fnd_file.output,--l_chart_seq
                                            --||'|'|| l_org_chart
                                            --||'|'||
                                                    emp_Full_Name
                                            ||'|'|| l_creation_date
                                            ||'|'|| l_update_date
                                            ||'|'|| emp_STATUS
                                            ||'|'|| emp_Person_Type
                                            ||'|'|| nvl(emp_JOB,'||')
                                            ||'|'|| nvl(emp_Previous_JOB,'||')
                                            ||'|'|| emp_Location_Name
											||'|'|| emp_Prev_Loc_Name
                                            ||'|'|| emp_Supervisor
                                            ||'|'|| emp_Prev_Supervisor
                                            ||'|'|| emp_SOB
                                            ||'|'|| emp_Expense_Account
                                            ||'|'|| emp_Email_Address
                                            ||'|'|| emp_emp_creation_date
                                            ||'|'|| emp_emp_last_update_date
                                            ||'|'|| emp_asg_creation_date
                                            ||'|'|| emp_asg_last_update_date
				);

           end if;
     close c_emp;
    End if;

    l_previous_person_id := l_person_id;
  End Loop;
  close c_change_info;
  UTL_FILE.FCLOSE(v_daily_file);

EXCEPTION
    WHEN UTL_FILE.INVALID_OPERATION THEN
		UTL_FILE.FCLOSE(v_daily_file);
		RAISE_APPLICATION_ERROR(-20051, p_FileName ||':  Invalid Operation');
    WHEN UTL_FILE.INVALID_FILEHANDLE THEN
		UTL_FILE.FCLOSE(v_daily_file);
		RAISE_APPLICATION_ERROR(-20052, p_FileName ||':  Invalid File Handle');
    WHEN UTL_FILE.READ_ERROR THEN
		UTL_FILE.FCLOSE(v_daily_file);
		RAISE_APPLICATION_ERROR(-20053, p_FileName ||':  Read Error');
    WHEN UTL_FILE.INVALID_PATH THEN
		UTL_FILE.FCLOSE(v_daily_file);
		RAISE_APPLICATION_ERROR(-20054, p_FileDir ||':  Invalid Path');
    WHEN UTL_FILE.INVALID_MODE THEN
		UTL_FILE.FCLOSE(v_daily_file);
		RAISE_APPLICATION_ERROR(-20055, p_FileName ||':  Invalid Mode');
    WHEN UTL_FILE.WRITE_ERROR THEN
		UTL_FILE.FCLOSE(v_daily_file);
		RAISE_APPLICATION_ERROR(-20056, p_FileName ||':  Write Error');
    WHEN UTL_FILE.INTERNAL_ERROR THEN
		UTL_FILE.FCLOSE(v_daily_file);
  		RAISE_APPLICATION_ERROR(-20057, p_FileName ||':  Internal Error');
    WHEN UTL_FILE.INVALID_MAXLINESIZE THEN
    		UTL_FILE.FCLOSE(v_daily_file);
  		RAISE_APPLICATION_ERROR(-20058, p_FileName ||':  Maxlinesize Error');
    WHEN OTHERS THEN
  		UTL_FILE.FCLOSE(v_daily_file);
  		RAISE;
END GET_EDC_INFO;
END TTEC_HR_EDC_NA_REPORT;
/
show errors;
/