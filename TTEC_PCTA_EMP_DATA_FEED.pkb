create or replace PACKAGE BODY      TTEC_PCTA_EMP_DATA_FEED AS
--
-- Program Name:  TTEC_PCTA_EMP_DATA_FEED
--
-- Description:  This program generates employee data feed to Percepta
-- Input/Output Parameters:
--
--
--
-- Tables Modified:  N/A
--
--
-- Created By:  Christiane Chan
-- Date: Nov 9, 2006
--
-- Modification Log:
-- Developer        Date        Description
-- ----------       --------    --------------------------------------------------------------------
--  C. Chan         1/31/2008   TT#883414 -- The file feed they receive for payroll does not have
--                                           an indicator to pay the employee as Hourly or Salaried.
--                                           This needs to be fixed.
--
--  C. Chan         4/30/2008   TT#934825 -- Missing employees due to some of the Percepta Location
--                                           code does not contain PCTA. Percepta Location should be
--                                           derived from Payroll + exclude FORD Locations.
--  Modification History:
--
--  Version    Date       Author   Description (Include Ticket--)
--  -------  ----------  --------  ------------------------------------------------------------------------------
--      1.1  01/02/2012   CChan    R12 Retrofit with ttec_library.get_directory('CUST_TOP')||'/data/
--      1.2  05/18/2015   CChan    Need to pick up employees who got term, not just active employees
--      1.3  06/17/2015   CChan    Change date into 4 digits year + address fix + latest hire date
--      1.4  08/13/2015   CChan     Adding Ken Tuchman to the list
--      1.0  03/MAY/2023   RXNETHI-ARGANO  R12.2 Upgrade Remediation
-- Global Variables ---------------------------------------------------------------------------------

PROCEDURE gen_pcta_emp_file(errcode varchar2, errbuff varchar2, p_pull_term_since varchar2) IS

--  Program to write out Employee data feed per Percepta specifications
--
-- Created By:  Christiane Chan
-- Date: Nov 9, 2006
--
-- Filehandle Variables
p_FileDir                      varchar2(200);
p_FileName                     varchar2(50);
p_Country                      varchar2(10);
v_emp_file                    UTL_FILE.FILE_TYPE;

-- Declare variables
l_msg                          varchar2(2000);
l_stage	                       varchar2(400);
l_element                      varchar2(400);
l_rec 	                       varchar2(400);
l_key                          varchar2(400);


l_test_indicator               varchar2(4):= '  ';
l_bank_account                 varchar2(100);
l_file_num                     varchar2(4) := '01';


l_tot_rec_count                number;
l_sum_pos_pay_amount           number;
l_check_number_hash_total      number;
l_seq                          number;

l_file_seq                    number;
l_next_file_seq               number;
l_test_flag                   varchar2(4);
l_pull_term_since             date;

l_program                     ap_card_programs_all.card_program_name%TYPE;
l_load_num                    ap_card_programs_all.attribute1%TYPE;
l_cid												  ap_card_programs_all.attribute2%TYPE;
l_book_num									  ap_card_programs_all.attribute3%TYPE;


-- set directory destination for output file

cursor c_directory_path is
select  ttec_library.get_directory('CUST_TOP')||'/data/Percepta/'
||decode(FND_PROFILE.VALUE_SPECIFIC('PER_BUSINESS_GROUP_ID'), 325,'US',326,'CA','US' ) directory_path
,'TTEC_' ||decode(FND_PROFILE.VALUE_SPECIFIC('PER_BUSINESS_GROUP_ID'), 325,'US',326,'CA','US' )
||'_DATA_FEED'
|| to_char(sysdate,'_YYYYMMDD')||   '.out' file_name,
decode(FND_PROFILE.VALUE_SPECIFIC('PER_BUSINESS_GROUP_ID'), 325,'US',326,'CANADA','US' ) Country
from V$DATABASE;

-- get requireed info for transmission
cursor c_detail_record is
select distinct
papf.national_identifier
,papf.first_name --"First Name",
,papf.last_name --"Last Name",
,papf.middle_names --"Middle Name",
,addy.address_line1 --"Address Line 1",
,addy.address_line2 --"Address Line 2",
,addy.town_or_city --"Town or City",
,addy.region_2 --"US State",
,addy.postal_code --"Postal Code",
,decode(asg.assignment_type,'E',hr_general.decode_lookup('EMP_CAT',asg.employment_category)) employment_category --"Employement Category",
--,papf.CURRENT_EMPLOYEE_FLAG --"Eligibility Status",
             , CASE WHEN emps.actual_termination_date IS NULL   THEN 'Y'
                    /* Since not all location process Leave Of Abscence, we will treat EMP on any type of leave as currently active */
                    ELSE 'N'
               END Eligibility_Status --"Eligibility Status",
,loc.location_code --"Location",
,loc.country
,papf.date_of_birth --"Date Of Birth",
,pps.date_start --"Latest Start Date"
,emps.rehire_date
,NVL(emps.actual_termination_date,emps.rehire_date) eligibility_change_date --"Eligibility Change Date",
--
-- Added by C. Chan 1/13/2008 TT#883414
--
,(select hl.meaning
from hr_lookups hl,per_pay_bases pb
where hl.lookup_type='PAY_BASIS'
and hl.lookup_code=pb.pay_basis
and business_group_id+0= 325
and pb.pay_basis_id = asg.pay_basis_id) SALARY_INDICATOR
from
/*
--START Upgrade Remediation
--code commented by RXNETHI-ARGANO, 03/MAY/2023

hr.per_periods_of_service pps,
hr.per_addresses addy,
hr.hr_locations_all loc,
hr.per_all_assignments_f asg,
hr.per_assignment_status_types past ,/* CC */
--hr.per_all_people_f papf */
--code added by RXNEHTI-ARGANO,03/MAY/2023
apps.per_periods_of_service pps,
apps.per_addresses addy,
apps.hr_locations_all loc,
apps.per_all_assignments_f asg,
apps.per_assignment_status_types past ,/* CC */
apps.per_all_people_f papf
--END R12.2 Upgrade Remediation
             , (   SELECT ppos.person_id, actual_termination_date,
                          CASE SIGN (date_start - TRUNC (SYSDATE))
                             WHEN -1
                                THEN                      -- Past Start Date
                                    CASE SIGN (  TRUNC (SYSDATE)
                                               - NVL (actual_termination_date,
                                                      TRUNC (SYSDATE) + 1
                                                     )
                                              )
                                       WHEN 1
                                          THEN actual_termination_date
                                                              -- Past Termination Date
                                       ELSE TRUNC
                                              (SYSDATE)
                                                   -- Current / Future or No Term Date
                                    END
                             ELSE date_start           -- Future or Current Start Date
                          END asg_date,
                          NVL (ppos.adjusted_svc_date, ppos.date_start) rehire_date
                     --FROM hr.per_periods_of_service ppos --code commented by RXNETHI-ARGANO, 03/MAY/2023
					 FROM apps.per_periods_of_service ppos -- code added by RXNEHTI-ARGANO, 03/MAY/2023
                    WHERE ppos.date_start =
                             (SELECT MAX (ppos2.date_start)
                                --FROM hr.per_periods_of_service ppos2 --code commented by RXNEHTI-ARGANO, 03/MAY/2023
								FROM apps.per_periods_of_service ppos2 --code added by RXNEHTI-ARGANO, 03/MAY/2023
                               WHERE ppos2.date_start <= SYSDATE
                                 AND ppos.person_id = ppos2.person_id)
                      and nvl(ppos.actual_termination_date,to_date('31-DEC-4712')) >= l_pull_term_since
                                 ) emps
where papf.business_group_id = 325
--and papf.CURRENT_EMPLOYEE_FLAG = 'Y'
and papf.person_id = asg.person_id
and asg.location_id = loc.location_id
--and loc.location_code like '%PCTA%'
and (  (     loc.attribute8 = 'Percepta (V76)'  -- Added by C.Chan TT#934825
         and loc.location_code not like 'FORD%' -- Added by C.Chan TT#934825
       )
     or employee_number = '3012468'-- Ken Tuckman's employee number /* 1.3 */
    )
and papf.person_id = addy.person_id
and papf.person_id = pps.person_id
and addy.primary_flag = 'Y'
--and addy.date_to is null /* 1.3 */
and emps.asg_date between addy.DATE_FROM and nvl(addy.date_to,'31-DEC-4712') /* 1.3 */
--and papf.national_identifier IS NOT NULL -- 1.2 exclude employee hired but no show
--and asg.employment_category IS NOT NULL -- 1.2 exclude employee hired but no show
AND emps.rehire_date <> NVL(emps.actual_termination_date,'31-DEC-4712') -- 1.2 exclude employee hired but no show
/* 1.2  begin*/
AND pps.date_start =(SELECT MAX(date_start)
                               FROM hr.per_periods_of_service pps1
                              WHERE pps1.PERSON_ID = pps.PERSON_ID)
AND asg.assignment_status_type_id = past.assignment_status_type_id
AND asg.person_id = emps.person_id
AND emps.asg_date BETWEEN asg.effective_start_date
                     AND asg.effective_end_date
AND emps.asg_date BETWEEN papf.effective_start_date
                     AND papf.effective_end_date;
/* 1.2  end */

/* 1.2 Begin
select distinct
papf.national_identifier
,papf.first_name --"First Name",
,papf.last_name --"Last Name",
,papf.middle_names --"Middle Name",
,addy.address_line1 --"Address Line 1",
,addy.address_line2 --"Address Line 2",
,addy.town_or_city --"Town or City",
,addy.region_2 --"US State",
,addy.postal_code --"Postal Code",
,decode(asg.assignment_type,'E',hr_general.decode_lookup('EMP_CAT',asg.employment_category)) employment_category --"Employement Category",
,papf.CURRENT_EMPLOYEE_FLAG --"Eligibility Status",
,loc.location_code --"Location",
,loc.country
,papf.date_of_birth --"Date Of Birth",
,pps.date_start --"Latest Start Date"
--
-- Added by C. Chan 1/13/2008 TT#883414
--
,(select hl.meaning
from hr_lookups hl,per_pay_bases pb
where hl.lookup_type='PAY_BASIS'
and hl.lookup_code=pb.pay_basis
and business_group_id+0= 325
and pb.pay_basis_id = asg.pay_basis_id) SALARY_INDICATOR
from
hr.per_periods_of_service pps,
hr.per_addresses addy,
hr.hr_locations_all loc,
hr.per_all_assignments_f asg,
hr.per_all_people_f papf
where papf.business_group_id = 325
and papf.CURRENT_EMPLOYEE_FLAG = 'Y'
and papf.person_id = asg.person_id
and asg.location_id = loc.location_id
--and loc.location_code like '%PCTA%'
and loc.attribute8 = 'Percepta (V76)'  -- Added by C.Chan TT#934825
and loc.location_code not like 'FORD%' -- Added by C.Chan TT#934825
and papf.person_id = addy.person_id
and papf.person_id = pps.person_id
and addy.primary_flag = 'Y'
and addy.date_to is null
and asg.effective_start_date = (select max(effective_start_date) from hr.per_all_assignments_f paf2 where asg.person_id = paf2.person_id)
and trunc(sysdate) between papf.effective_start_date and papf.effective_end_date
and ((papf.employee_number is null) or (papf.employee_number is not null and pps.date_start = (select max(pps1.date_start) from hr.per_periods_of_service pps1 where pps1.person_id = papf.person_id and pps1.date_start <= papf.effective_end_date)));
1.2 end  */
BEGIN

  l_stage := 'c_directory_path';
 -- l_test_indicator := 'TT';    -- remove when done testing
	-- Fnd_File.put_line(Fnd_File.LOG, '1');
  open c_directory_path;
  fetch c_directory_path into p_FileDir,p_FileName,p_Country;
  close c_directory_path;

   IF p_pull_term_since is null then
      l_pull_term_since := trunc(SYSDATE) - 31;
   ELSE
      l_pull_term_since :=  to_date(p_pull_term_since);
   END IF;

	l_stage := 'c_open_file';

  	v_emp_file := UTL_FILE.FOPEN(p_FileDir, p_FileName, 'w');

  	Fnd_File.put_line(Fnd_File.LOG, '**********************************');
	Fnd_File.put_line(Fnd_File.LOG, 'Output file created >>> ' ||p_FileDir ||'/' || p_FileName);
	Fnd_File.put_line(Fnd_File.LOG, 'Pull Terms Since    >>> ' ||l_pull_term_since);
	Fnd_File.put_line(Fnd_File.LOG, '**********************************');

 	--
      	l_tot_rec_count          := 0;


	-- Fnd_File.put_line(Fnd_File.LOG, '5');

 	     For emp_rec in c_detail_record loop


        -------------------------------------------------------------------------------------------------------------------------

        --
       --
       --  Fnd_File.put_line(Fnd_File.LOG, '7');

      -- l_rec := '10'||'-'||nvl(replace(replace(to_char(pos_pay.amount,'S000000000.00'),'+','0'),'.',''),lpad('0',12,'0'))||substr(pos_pay.description, 1, 15)||lpad ( ' ', 69, ' ')||'01'||lpad(' ', 117,' ');

      l_rec :=  emp_rec.national_identifier --"National Identifier",
        ||'~~'||emp_rec.first_name --"First Name",
        ||'~~'||emp_rec.middle_names --"Middle Name",
        ||'~~'||emp_rec.last_name --"Last Name",
        ||'~~'||emp_rec.address_line1 --"Address Line 1",
        ||'~~'||emp_rec.address_line2 --"Address Line 2",
        ||'~~'||emp_rec.town_or_city --"Town or City",
        ||'~~'||emp_rec.region_2 --"US State",
        ||'~~'||emp_rec.country --"Country Code",
        ||'~~'||emp_rec.postal_code --"Postal Code",
        ||'~~'||emp_rec.employment_category --"Employement Category",
        ||'~~'||emp_rec.location_code --"emp_location",
       -- ||'~~'||emp_rec.CURRENT_EMPLOYEE_FLAG --"Eligibility Status", /* 1.2 commented out */
        ||'~~'||emp_rec.Eligibility_Status --"Eligibility Status",      /* 1.2 */
        ||'~~'||to_char(emp_rec.date_of_birth,'DD-MON-RRRR') --"Date Of Birth", /* 1.3 */
       -- ||'~~'||emp_rec.date_start --"Latest Start Date" /* 1.3 */
        ||'~~'||to_char(emp_rec.rehire_date,'DD-MON-RRRR') --"Latest Start Date" /* 1.3 */
        ||'~~'||emp_rec.SALARY_INDICATOR -- Added by C. Chan 1/13/2008 TT#883414
        ||'~~'||to_char(emp_rec.eligibility_change_date,'DD-MON-RRRR') --"Eligibility Change Date", /* 1.3 */
		;
			-- 									nvl(replace(to_char(9999.99       ,'S000000000.00'),'+','0'), lpad('0', 12,'0'))
    l_stage := 'c_amount record';
        utl_file.put_line(v_emp_file, l_rec);

        apps.fnd_file.put_line(apps.fnd_file.output,l_rec);

      	-- get totals
        l_tot_rec_count := l_tot_rec_count + 1;



    -- Fnd_File.put_line(Fnd_File.LOG, '8');

     End Loop; /* pay */

	Fnd_File.put_line(Fnd_File.LOG,'Total Rec Generated >>> '||l_tot_rec_count);
  	Fnd_File.put_line(Fnd_File.LOG, '**********************************');
  UTL_FILE.FCLOSE(v_emp_file);



EXCEPTION
    WHEN UTL_FILE.INVALID_OPERATION THEN
		UTL_FILE.FCLOSE(v_emp_file);
		RAISE_APPLICATION_ERROR(-20051, p_FileName ||':  Invalid Operation');
		ROLLBACK;
    WHEN UTL_FILE.INVALID_FILEHANDLE THEN
		UTL_FILE.FCLOSE(v_emp_file);
		RAISE_APPLICATION_ERROR(-20052, p_FileName ||':  Invalid File Handle');
		ROLLBACK;
    WHEN UTL_FILE.READ_ERROR THEN
		UTL_FILE.FCLOSE(v_emp_file);
		RAISE_APPLICATION_ERROR(-20053, p_FileName ||':  Read Error');
		ROLLBACK;
    WHEN UTL_FILE.INVALID_PATH THEN
		UTL_FILE.FCLOSE(v_emp_file);
		RAISE_APPLICATION_ERROR(-20054, p_FileDir ||':  Invalid Path');
		ROLLBACK;
    WHEN UTL_FILE.INVALID_MODE THEN
		UTL_FILE.FCLOSE(v_emp_file);
		RAISE_APPLICATION_ERROR(-20055, p_FileName ||':  Invalid Mode');
		ROLLBACK;
    WHEN UTL_FILE.WRITE_ERROR THEN
		UTL_FILE.FCLOSE(v_emp_file);
		RAISE_APPLICATION_ERROR(-20056, p_FileName ||':  Write Error');
		ROLLBACK;
    WHEN UTL_FILE.INTERNAL_ERROR THEN
		UTL_FILE.FCLOSE(v_emp_file);
  		RAISE_APPLICATION_ERROR(-20057, p_FileName ||':  Internal Error');
		ROLLBACK;
    WHEN UTL_FILE.INVALID_MAXLINESIZE THEN
    		UTL_FILE.FCLOSE(v_emp_file);
  		RAISE_APPLICATION_ERROR(-20058, p_FileName ||':  Maxlinesize Error');
		ROLLBACK;
    WHEN OTHERS THEN
        UTL_FILE.FCLOSE(v_emp_file);

        DBMS_OUTPUT.PUT_LINE('Operation fails on '||l_stage);

	    l_msg := SQLERRM;

        RAISE_APPLICATION_ERROR(-20003,'Exception OTHERS in TTEC_PCTA_EMP_DATA_FEED: '||l_msg);
		ROLLBACK;

END gen_pcta_emp_file;

END TTEC_PCTA_EMP_DATA_FEED;
/
show errors;
/