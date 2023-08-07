 /************************************************************************************
        Program Name:  APPS.TTEC_ASSIGNED_CLIENT_DSCR

        Description:   

        Developed by : 
        Date         :  

       Modification Log
       Name                  Version #    Date            Description
       -----                 --------     -----           -------------
    IXPRAVEEN(ARGANO)            1.0     17-May-2023     R12.2 Upgrade Remediation
    ****************************************************************************************/
create or replace PACKAGE BODY TTEC_ASSIGNED_CLIENT_DSCR AS

PROCEDURE main (errcode varchar2, errbuff varchar2) IS

--  Program to write out discrpencies in AUS employee client assignment
--
--    Wasim Manasfi    Jan  25 2007
--
-- Filehandle Variables
p_FileDir                      varchar2(200);
p_FileName                     varchar2(50);
p_Country                      varchar2(10);
v_bank_file                    UTL_FILE.FILE_TYPE;

-- Declare variables
l_msg                          varchar2(2000);
l_stage	                       varchar2(400);
l_element                      varchar2(400);
l_rec 	                       varchar2(400);
l_key                          varchar2(400);



l_tot_rec_count                number;






-- get requireed info for transmission
cursor c_detail_record is
SELECT DISTINCT papf.full_name || '|' ||
				papf.employee_number || '|' ||
                pcak.segment2  || '|' ||
				hou.NAME || '|' ||
			-- 	COST.segment1 || '|' ||
        COST.segment2 || '|' ||
				COST.description || '|' ||
                COST.proportion   description
           FROM apps.per_all_people_f papf,
                apps.per_all_assignments_f paaf,
                apps.per_jobs pj,
                --hr.hr_all_organization_units hou,			-- Commented code by IXPRAVEEN-ARGANO,17-May-2023
                APPS.hr_all_organization_units hou,         --  code Added by IXPRAVEEN-ARGANO,   17-May-2023
                apps.pay_cost_allocation_keyflex pcak,
                (SELECT DISTINCT pcak.segment1, pcak.segment2, pcak.segment3,
                                 paaf.person_id, paaf.assignment_id,
                                 ffvv.description, pcaf.proportion,
                                 pcaf.effective_start_date,
                                 pcaf.effective_end_date
                            FROM apps.per_all_people_f papf,
                                 apps.per_all_assignments_f paaf,
                                 apps.pay_cost_allocation_keyflex pcak,
                                 apps.pay_cost_allocations_f pcaf            --
                                                                 ,
                                 apps.fnd_flex_values_vl ffvv
                           WHERE papf.business_group_id <> 0
                             AND papf.person_id = paaf.person_id
                             AND paaf.assignment_id = pcaf.assignment_id
                             AND pcaf.cost_allocation_keyflex_id =
                                               pcak.cost_allocation_keyflex_id
                             AND ffvv.flex_value = pcak.segment2
                             AND papf.current_employee_flag = 'Y'
                             AND SYSDATE BETWEEN papf.effective_start_date
                                             AND papf.effective_end_date
                             AND SYSDATE BETWEEN paaf.effective_start_date
                                             AND paaf.effective_end_date
                             AND SYSDATE BETWEEN pcaf.effective_start_date
                                             AND pcaf.effective_end_date
                        GROUP BY pcak.segment1,
                                 pcak.segment2,
                                 pcak.segment3,
                                 paaf.person_id,
                                 paaf.assignment_id,
                                 ffvv.description,
                                 pcaf.proportion,
                                 pcaf.effective_start_date,
                                 pcaf.effective_end_date) COST
          WHERE papf.business_group_id <> 0
            AND papf.person_id = paaf.person_id
            AND paaf.job_id = pj.job_id
            AND papf.current_employee_flag = 'Y'
            AND SYSDATE BETWEEN papf.effective_start_date
                            AND papf.effective_end_date
            AND SYSDATE BETWEEN paaf.effective_start_date
                            AND paaf.effective_end_date
            AND paaf.person_id = COST.person_id
            AND paaf.assignment_id = COST.assignment_id
            AND paaf.organization_id = hou.organization_id
            AND hou.cost_allocation_keyflex_id =
                                               pcak.cost_allocation_keyflex_id
            AND pcak.segment2 != COST.segment2
            AND paaf.business_group_id = 1839
	ORDER BY 1;

BEGIN


	-- Fnd_File.put_line(Fnd_File.LOG, '3');

 	-- get seeded file number
    	l_tot_rec_count          := 0;

	-- Fnd_File.put_line(Fnd_File.LOG, '5');
       l_rec := 'Employee Name|Employee Number|Client Code|Organization Name|Costing Client Code |Costing Client Code|Proportion';
  	   apps.fnd_file.put_line(apps.fnd_file.output, l_rec);

	     For pos_pay in c_detail_record loop
		      l_rec := pos_pay.description;

    			    apps.fnd_file.put_line(apps.fnd_file.output,l_rec);


     	End Loop; /* pay */

EXCEPTION
    WHEN UTL_FILE.INVALID_OPERATION THEN
		RAISE_APPLICATION_ERROR(-20051, p_FileName ||':  Invalid Operation');
--		ROLLBACK;

    WHEN UTL_FILE.INVALID_FILEHANDLE THEN

		RAISE_APPLICATION_ERROR(-20052, p_FileName ||':  Invalid File Handle');
--		ROLLBACK;

    WHEN UTL_FILE.READ_ERROR THEN

		RAISE_APPLICATION_ERROR(-20053, p_FileName ||':  Read Error');


    WHEN UTL_FILE.INVALID_PATH THEN

		RAISE_APPLICATION_ERROR(-20054, p_FileDir ||':  Invalid Path');


    WHEN UTL_FILE.INVALID_MODE THEN

		RAISE_APPLICATION_ERROR(-20055, p_FileName ||':  Invalid Mode');

    WHEN UTL_FILE.WRITE_ERROR THEN

		RAISE_APPLICATION_ERROR(-20056, p_FileName ||':  Write Error');

    WHEN UTL_FILE.INTERNAL_ERROR THEN

  		RAISE_APPLICATION_ERROR(-20057, p_FileName ||':  Internal Error');
		ROLLBACK;
    WHEN UTL_FILE.INVALID_MAXLINESIZE THEN

  		RAISE_APPLICATION_ERROR(-20058, p_FileName ||':  Maxlinesize Error');

    WHEN OTHERS THEN




	    l_msg := SQLERRM;

        RAISE_APPLICATION_ERROR(-20003,'Exception OTHERS in Program : '||l_msg);
		ROLLBACK;

END main;

END TTEC_ASSIGNED_CLIENT_DSCR;
/
show errors;
/