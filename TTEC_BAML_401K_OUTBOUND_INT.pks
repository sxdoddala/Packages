create or replace PACKAGE      TTEC_BAML_401K_OUTBOUND_INT AUTHID CURRENT_USER AS
--
-- Program Name:  TTEC_BAML_401K_OUTBOUND_INT
-- /* $Header: TTEC_BAML_401K_OUTBOUND_INT.pks 1.0 2011/10/14  chchan ship $ */
--
-- /*== START ================================================================================================*\
--    Author: Christiane Chan
--      Date: 14-OCT-2011

-- Call From: Concurrent Program ->TeleTech BAML Benefit 401K Outbound Interface
--      Desc: This program generates TeleTech employees information mandated by BOA Merril Lynch 401(k) Standard Layout
--
--     Parameter Description:
--
--         p_check_date             :Check/Pay Date Default to 'DD-MON-RRRR' or user input with Check Date
--         p_date_earned            :Date Earned - End Date of Pay period Default to 'DD-MOM-RRRR' or user input with Date Earned for the check date above
--         p_401k_bal_name          :'Pre Tax 401K'
--         p_401k_catchup_bal__name :'Pre Tax 401K Catchup
--         p_401k_loan1_bal__name   :'Loan 1_401k'
--         p_payroll_name           :(HIDDEN from END User) Payroll Name defaulted to 'TeleTech' to obtain Pay Date and Date Earned, with the assumption that all other US payroll
--                                   having the same pay period.
--
--       Oracle Standard Parameters:
--
--   Modification History:
--
--  Version    Date     Author   Description (Include Ticket--)
--  -------  --------  --------  ------------------------------------------------------------------------------
--      1.0  10/14/11   CChan     Initial Version R#971563 - BOA-Merril Lynch 401K Project
--      1.1  01/06/12   CChan     Fix after 1st load to BAML Live data
--      1.2  02/09/12   CChan     Fix on Future hire
--      1.3  04/04/12   CChan     TTSD I#1413541 - Fix on Old Address got picked + exclude GL Locations with hardcode
--      1.4  05/01/12   CChan     TTSD I#1476258 - Fix on Salary Info
--      1.5  25/09/12   CChan     TTSD I#1856016 - Adding Field 14   ALTERNATE VEST DATE
--      1.6  03/28/13   Kgonuguntla TTSD R 2161944 - Fixed 3 & 4 issues mentioned on the ticket.
--      1.7  04/25/2013 Kgonuguntla TTSD I#2366133 - To pull future terms and also to pull based on the check date not by pay date
--      1.8  06/06/13   RRPASULA  TTSD 2451234 missing term code fix
--      1.9  06/26/13   CChan     TTSD  2512847 - Fix on missing rehire + modify the to pull Termed employee all the way to 12/1 of prior year
--                                                In Addition, remove future hires/rehires in the file. and to not include those who never actually worked (term before hire) who had zero comp.
--      2.0  12/09/2013 CChan     PEO integration Project
--      2.1  02/12/2014 CChan     Fix on code 30 not showing for termed employee
--      2.3  07/10/2014 CChan     INC0379039 - BAML interface to combine those with multiple assigments to one row on the file for the year
--      2.4  09/29/2014 CChan     INC0560420 - During the last migration we were told that there was a rule that if anyone terminated within 14 days of hire they were excluded from the file.
--                                             If they have ever received compensation they must remain on the file
--      2.5  05/11/2015 CChan     INC1227772 - Need to be able to datetrack on Location + include employees with future hire who came back within a year that has enrolled
--      3.0  08/06/2015 CChan     INC1558786 - Oct 05, 2015 Changes for Re hosting Project
--      5.0  12/07/2015 CChan     INC2493117 - Dec 07, 2016 5.1 - Divorce Code - No Fix
--                                                          5.2 - Negative Mapping
--                                                          5.3 - Special Character - Fix
--                                                          5.4 - December Term - No Fix put in yet
--                                                          5.5 - Advice Salary - Fix
--      6.0  02/21/2017 CChan     DMND0008093 - Feb 21,2017 6.1 - Currently incorrect mapping of codes for marital statuses (causes issues for participants when they manage their accounts and results in a poor customer experience); Not an issue cancelled
--                                                          6.2 - A table to exclude certain individuals that should not pass over on the file but are currently being generated on the file due to their file in Oracle (because of which we are currently paying a per-head fee for multiple individuals that should not be in the plan - wasted dollars), in particular those with multiple records in Oracle or those who were entered into Oracle but terminated prior to employment. This fix would also prevent employees that are not being enrolled in Merrill Lynch's system when they should be because they have multiple Oracle IDs that are creating errors - causes compliance gaps with plan;
--                                                          6.3 - Add the capability to define the date parameters of the report, which needs to be accessible for an event where we'd need to manipulate the dates (particularly end-of-year payrolls) and reporting purposes.
--      7.0  02/21/2018 CChan     2018 requirements: -  adding Pre Tax 401K Bonus + Pre Tax 401K Flat Dollar and Balance Dimension Parameter
--      7.1 05/09/2018 CChan     Rehired employees need to be sent with 97, not 06, or BAML will not overide the termed staus code ->30 , number has to be greater than 31, therefore ->97
--      7.2 05/11/2018 CChan     Need to add "Pre Tax 401K Bonus Eligible Comp" to existing Eligible Comp
--      7.3  08/24/2018 CChan     Fix for the compensation fields, Field 46, 54 and 69, it looks like we use to send the eligible YTD balance feed.  Currently, it appears that just the current payroll amount is being passed.
--      7.4  09/05/2018 CChan     Fix on remove non-ascii charater
--      7.5  01/16/2019 CChan    Fix on Year End missing employees on the extract
--      7.6  02/05/2019 CChan    Change look back date to 01-OCT insteat of 01-DEC
--      7.7  02/07/2019 CChan    Fix on Employee Status Code
--      7.8  02/07/2019 CChan    Fix on duplicate employee records
--      8.0  08/20/2019 CChan    Fix on term emp not getting picked up
--		1.0	09-May-2023 IXPRAVEEN(ARGANO)   		R12.2 Upgrade Remediation
-- \*== END =====================================
    -- Error Constants
	--START R12.2 Upgrade Remediation
    /*g_application_code   cust.ttec_error_handling.application_code%TYPE := 'BEN';				-- Commented code by IXPRAVEEN-ARGANO,09-May-2023
    g_interface          cust.ttec_error_handling.INTERFACE%TYPE        := 'BOA 401K Intf';
    g_package            cust.ttec_error_handling.program_name%TYPE     := 'TTEC_BAML_401K_OUTBOUND_INT';
    g_label1             cust.ttec_error_handling.label1%TYPE           := 'Err Location';
    g_label2             cust.ttec_error_handling.label1%TYPE           := 'Emp_Number';
    g_warning_status     cust.ttec_error_handling.status%TYPE           := 'WARNING';
    g_error_status       cust.ttec_error_handling.status%TYPE           := 'ERROR';
    g_failure_status     cust.ttec_error_handling.status%TYPE           := 'FAILURE';

    g_bal_type_id_401K                  hr.pay_balance_types.BALANCE_TYPE_ID%TYPE :=NULL;
    g_bal_type_id_401K_FD               hr.pay_balance_types.BALANCE_TYPE_ID%TYPE :=NULL;
    g_bal_type_id_401K_Bonus            hr.pay_balance_types.BALANCE_TYPE_ID%TYPE :=NULL;
    g_bal_type_id_401K_Catchup          hr.pay_balance_types.BALANCE_TYPE_ID%TYPE :=NULL;
    g_bal_type_id_401K_Catchup_FD       hr.pay_balance_types.BALANCE_TYPE_ID%TYPE :=NULL;
    g_bal_type_id_401K_Loan1            hr.pay_balance_types.BALANCE_TYPE_ID%TYPE :=NULL;
    g_bal_type_id_401K_Elig_Comp        hr.pay_balance_types.BALANCE_TYPE_ID%TYPE :=NULL;
    g_bal_type_id_401K_BonusElComp      hr.pay_balance_types.BALANCE_TYPE_ID%TYPE :=NULL; /* 7.2 */
    /*g_bal_type_id_401K_DiscrTest        hr.pay_balance_types.BALANCE_TYPE_ID%TYPE :=NULL; /* 7.7 */

    /*g_bal_dimension_id                  hr.pay_balance_dimensions.BALANCE_DIMENSION_ID%TYPE :=NULL;*/
	
	g_application_code   apps.ttec_error_handling.application_code%TYPE := 'BEN';				--  code Added by IXPRAVEEN-ARGANO,09-May-2023
    g_interface          apps.ttec_error_handling.INTERFACE%TYPE        := 'BOA 401K Intf';
    g_package            apps.ttec_error_handling.program_name%TYPE     := 'TTEC_BAML_401K_OUTBOUND_INT';
    g_label1             apps.ttec_error_handling.label1%TYPE           := 'Err Location';
    g_label2             apps.ttec_error_handling.label1%TYPE           := 'Emp_Number';
    g_warning_status     apps.ttec_error_handling.status%TYPE           := 'WARNING';
    g_error_status       apps.ttec_error_handling.status%TYPE           := 'ERROR';
    g_failure_status     apps.ttec_error_handling.status%TYPE           := 'FAILURE';

    g_bal_type_id_401K                  apps.pay_balance_types.BALANCE_TYPE_ID%TYPE :=NULL;
    g_bal_type_id_401K_FD               apps.pay_balance_types.BALANCE_TYPE_ID%TYPE :=NULL;
    g_bal_type_id_401K_Bonus            apps.pay_balance_types.BALANCE_TYPE_ID%TYPE :=NULL;
    g_bal_type_id_401K_Catchup          apps.pay_balance_types.BALANCE_TYPE_ID%TYPE :=NULL;
    g_bal_type_id_401K_Catchup_FD       apps.pay_balance_types.BALANCE_TYPE_ID%TYPE :=NULL;
    g_bal_type_id_401K_Loan1            apps.pay_balance_types.BALANCE_TYPE_ID%TYPE :=NULL;
    g_bal_type_id_401K_Elig_Comp        apps.pay_balance_types.BALANCE_TYPE_ID%TYPE :=NULL;
    g_bal_type_id_401K_BonusElComp      apps.pay_balance_types.BALANCE_TYPE_ID%TYPE :=NULL; /* 7.2 */
    g_bal_type_id_401K_DiscrTest        apps.pay_balance_types.BALANCE_TYPE_ID%TYPE :=NULL; /* 7.7 */

    g_bal_dimension_id                  apps.pay_balance_dimensions.BALANCE_DIMENSION_ID%TYPE :=NULL;
	--END R12.2.10 Upgrade remediation
    -- Process FAILURE variables
    g_fail_flag                   BOOLEAN := FALSE;

    -- Filehandle Variables
    p_FileDir                      varchar2(400);
    p_FileName                     varchar2(100);
    p_Country                      varchar2(10);

    v_401k_file                    UTL_FILE.FILE_TYPE;

    -- Declare variables
    g_check_date                   date;
    g_date_earned                  date;
    g_date_earn_start              date;
    g_jan_01_date                  varchar2(11);
    g_payroll_start_date           date;
    g_payroll_end_date             date;
    g_adjusted_start_date          date; /* 6.3 */
    g_emp_no                       varchar2(20);
    g_flex_num                     number(15); -- 1.5


  -- declare cursors

      l_host_name                 VARCHAR2 (256);

    CURSOR c_host IS
    SELECT host_name,instance_name FROM v$instance;

    cursor c_directory_path is
    select ttec_library.get_directory('CUST_TOP')||'/data/401K/Outbound' file_path
    , 'TELESRVCS_TRIN_PYRL1_610115'
    ||    (select decode(apps.TTEC_GET_INSTANCE,'PROD','','_TEST') -- 3.0
    from dual)
    ||  '.DAT' file_name
    from V$DATABASE;

    /* main query to obtain US employees data from HR tables */
    cursor c_emp_cur(p_start_date IN DATE, p_end_date IN DATE)  is
        SELECT distinct /* 7.8 */
--        papf.person_id, paaf.assignment_id, paaf.organization_id, paaf.pay_basis_id
--             , paaf.payroll_id, paaf.period_of_service_id, paaf.location_id,papf.business_group_id
        papf.person_id, paaf1.assignment_id, paaf1.organization_id, paaf1.pay_basis_id
             , paaf1.payroll_id, paaf.period_of_service_id, paaf.location_id,papf.business_group_id
             , paaf.effective_start_date, paaf.effective_end_date
             , paaf.assignment_type
             , papf.employee_number
             , hla.ATTRIBUTE2 division_code
             , paaf.work_at_home
             , papf.national_identifier --papf.full_name --papf.first_name, papf.last_name
            -- , REGEXP_REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(papf.full_name,CHR(10)),CHR(12)),CHR(13)),CHR(27)),'~'), ',-[^[:alnum:] ]*', ',-') full_name /* 5.3 */
/* 7.4 Begin */
--             , TRANSLATE (
--                   REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(papf.full_name,CHR(10)),CHR(12)),CHR(13)),CHR(27)),'~') ,
--                   'ÀÁÂÃÄÅÇÈÉÊËÌÍÎÏÑÒÓÔÕÖÙÚÛÜÝàáâãäåçèéêëìíîïñòóôõöøùúûüýÿºª"°',
--                   'AAAAAACEEEEIIIINOOOOOUUUUYaaaaaaceeeeiiiinoooooouuuuyy    ')  full_name /* 5.3 */
             , TRIM(REGEXP_REPLACE(TRANSLATE (
                   REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(papf.full_name,CHR(10)),CHR(12)),CHR(13)),CHR(27)),'~') ,
                   'ÀÁÂÃÄÅÇÈÉÊËÌÍÎÏÑÒÓÔÕÖÙÚÛÜÝàáâãäåçèéêëìíîïñòóôõöøùúûüýÿºª"°',
                   'AAAAAACEEEEIIIINOOOOOUUUUYaaaaaaceeeeiiiinoooooouuuuyy    '),'[^' || CHR(1) || '-' || CHR(127) || ']',''))  full_name
/* 7.4 End */
             , papf.date_of_birth
             , DECODE(papf.marital_status,'M','2','1')  marital_status
             , papf.sex
             , NVL(papf.original_date_of_hire,ppos.date_start) hire_date
             , ppos.date_start rehire_date
             , papf.benefit_group_id
             , papf.email_address
--             , ppos.actual_termination_date
--             ,past.USER_STATUS
             , to_date(DECODE(SIGN(p_end_date - ppos.actual_termination_date),-1,NULL,ppos.actual_termination_date)) actual_termination_date
             --, CASE WHEN past.USER_STATUS = 'Active Assignment'   THEN CASE WHEN (select count(*) from hr.per_periods_of_service ppos2 where ppos2.person_id = papf.person_id) = 1 THEN '06' /* 7.1 take out the > from >= 1*/ /* 7.0 adding > before = 1 */					-- Commented code by IXPRAVEEN-ARGANO,09-May-2023
			 , CASE WHEN past.USER_STATUS = 'Active Assignment'   THEN CASE WHEN (select count(*) from apps.per_periods_of_service ppos2 where ppos2.person_id = papf.person_id) = 1 THEN '06' /* 7.1 take out the > from >= 1*/ /* 7.0 adding > before = 1 */                  --  code Added by IXPRAVEEN-ARGANO,09-May-2023
                                                                        ELSE '97'
                                                                       END
                    WHEN past.USER_STATUS = 'Terminate - Process' THEN --'30'
                                                                    (SELECT DECODE(SIGN(instr(UPPER(flv.meaning),'DECEASED')),1,'36','30')
                                                                       FROM  per_periods_of_service ppos1
                                                                              ,fnd_lookup_values flv
                                                                      WHERE  ppos1.PERIOD_OF_SERVICE_ID = paaf1.PERIOD_OF_SERVICE_ID
                                                                      AND flv.LOOKUP_CODE(+) = ppos1.LEAVING_REASON
                                                                      and flv.LOOKUP_TYPE(+) = 'LEAV_REAS'
                                                                      and flv.language(+) = 'US'
                                                                      AND flv.security_group_id(+) = 2
                                                                                    )
                    /* Since not all location process Leave Of Abscence, we will treat EMP on any type of leave as currently active */
                    --ELSE CASE WHEN (select count(*) from hr.per_periods_of_service ppos2 where ppos2.person_id = papf.person_id) = 1 THEN '06' /* 7.1 take out the > from >= 1*/ /* 7.0 adding > before = 1 */				-- Commented code by IXPRAVEEN-ARGANO,09-May-2023
					ELSE CASE WHEN (select count(*) from apps.per_periods_of_service ppos2 where ppos2.person_id = papf.person_id) = 1 THEN '06' /* 7.1 take out the > from >= 1*/ /* 7.0 adding > before = 1 */              --  code Added by IXPRAVEEN-ARGANO,09-May-2023
                         ELSE '97'
                         END
               END participant_status_code
             -- , hr_person_type_usage_info.get_user_person_type ( TRUNC(papf.effective_start_date), papf.person_id ) emp_type /* 2.0 */
             , hr_person_type_usage_info.get_user_person_type ( p_end_date, papf.person_id ) emp_type /* CC */
          --START R12.2 Upgrade Remediatio
		  /*FROM hr.per_periods_of_service ppos		-- Commented code by IXPRAVEEN-ARGANO,09-May-2023
             , hr.per_all_assignments_f paaf        
             , hr.per_all_assignments_f paaf1
             , hr.per_all_assignments_f paaf2
             , hr.per_all_people_f papf
             , hr.per_assignment_status_types past
             , hr.hr_locations_all hla*/
		  FROM apps.per_periods_of_service ppos		--  code Added by IXPRAVEEN-ARGANO,09-May-2023
             , apps.per_all_assignments_f paaf
             , apps.per_all_assignments_f paaf1
             , apps.per_all_assignments_f paaf2
             , apps.per_all_people_f papf
             , apps.per_assignment_status_types past
             , apps.hr_locations_all hla
--END R12.2.10 Upgrade remediation			 
             /* 2.5 Begin */
             , (   SELECT ppos.person_id, actual_termination_date,
                          /* 7.0 Begin */
                          CASE SIGN (date_start - p_end_date)
                             WHEN -1
                                THEN                      -- Past Start Date
                                    CASE SIGN (  p_end_date
                                               - NVL (actual_termination_date,
                                                      p_end_date + 1
                                                     )
                                              )
                                       WHEN 1
                                          THEN actual_termination_date
                                                              -- Past Termination Date
                                       ELSE  p_end_date
                                                   -- Current / Future or No Term Date
                                    END
                             ELSE date_start           -- Future or Current Start Date
                          END asg_date,
                           /* 7.0 End */
                          NVL (ppos.adjusted_svc_date, ppos.date_start) rehire_date
                     --FROM hr.per_periods_of_service ppos				-- Commented code by IXPRAVEEN-ARGANO,09-May-2023
					 FROM apps.per_periods_of_service ppos              --  code Added by IXPRAVEEN-ARGANO,09-May-2023
                    WHERE ppos.date_start =
                             (SELECT MAX (ppos2.date_start)
                               -- FROM hr.per_periods_of_service ppos2		-- Commented code by IXPRAVEEN-ARGANO,09-May-2023
								FROM apps.per_periods_of_service ppos2        --  code Added by IXPRAVEEN-ARGANO,09-May-2023
                              -- WHERE ppos2.date_start <= SYSDATE /* 5.5 */
                               WHERE ppos2.date_start <= p_end_date /* 5.5 */
                                 and  ppos2.date_start =  (SELECT MAX (ppos3.date_start)
                                        -- FROM hr.per_periods_of_service ppos3		-- Commented code by IXPRAVEEN-ARGANO,09-May-2023
										 FROM apps.per_periods_of_service ppos3       --  code Added by IXPRAVEEN-ARGANO,09-May-2023
                                         where ppos3.PERSON_ID = ppos2.person_id
                                         and ppos3.date_start <= p_end_date /* 5.5 */
                                         )
                                 AND ppos.person_id = ppos2.person_id)
/* 7.5 */--                      and nvl(ppos.actual_termination_date,to_date('30-NOV-'||to_char(p_end_date,'YYYY')))  between to_date('01-DEC-'||to_char(to_number(to_char(p_end_date,'YYYY')) -1))
/* 7.5 */--                                                                                                                --and to_date('30-NOV-'||to_char(p_end_date ,'YYYY')) ) emps
/* 7.5 */--                                                                                                                and to_date('31-DEC-'||to_char(p_end_date ,'YYYY'))
/* 7.5  BEGIN */                 and (   (     ppos.actual_termination_date is not null
                                           and ppos.actual_termination_date
                                           between to_date('01-OCT-'||to_char(to_number(to_char(p_end_date,'YYYY')) -1)) /* 7.3 */
                                               and to_date('31-DEC-'||to_char(p_end_date ,'YYYY'))
                                         )
                                       OR ppos.actual_termination_date is null
                                       OR (ppos.actual_termination_date is not null AND ppos.actual_termination_date > p_end_date )
                                     ) /* 7.5  End */
                                                                                                                 ) emps /* 5.4 */
             /* 2.5 End */
         WHERE ppos.period_of_service_id(+) = paaf1.period_of_service_id
           /* 7.0 Begin */
           and paaf.effective_start_date =  (SELECT MAX(paaf2.effective_start_date)
                                           -- FROM hr.per_all_assignments_f paaf2			-- Commented code by IXPRAVEEN-ARGANO,09-May-2023
											FROM apps.per_all_assignments_f paaf2             --  code Added by IXPRAVEEN-ARGANO,09-May-2023
                                           where paaf2.person_id = emps.person_id
                                             AND emps.asg_date BETWEEN paaf2.effective_start_date
                                                                     AND paaf2.effective_end_date  )
           AND ppos.date_start =(SELECT MAX(date_start)
                                           --FROM hr.per_periods_of_service pps1			-- Commented code by IXPRAVEEN-ARGANO,09-May-2023
										   FROM apps.per_periods_of_service pps1              --  code Added by IXPRAVEEN-ARGANO,09-May-2023
                                          WHERE pps1.PERSON_ID = ppos.PERSON_ID
                                          AND emps.asg_date BETWEEN pps1.DATE_START AND NVL(pps1.ACTUAL_TERMINATION_DATE,'31-DEC-4712') )
          /* 7.0 End */
--           AND ppos.date_start =(SELECT MAX(date_start)
--                                           FROM hr.per_periods_of_service pps1
--                                          WHERE pps1.PERSON_ID = ppos.PERSON_ID)
           AND  paaf1.person_id = paaf.person_id
           AND  paaf1.assignment_id = paaf.assignment_id /* 7.8 */
           AND  paaf2.person_id = paaf.person_id  /* 7.7 */
           AND  paaf2.assignment_id = paaf.assignment_id /* 7.8 */
           AND  paaf2.assignment_status_type_id = past.assignment_status_type_id /* 7.7 */
           --and  p_end_date  BETWEEN paaf2.effective_start_date AND paaf2.effective_end_date /* 7.7 */ /* 8.0 */
           and NVL(to_date(DECODE(SIGN(p_end_date - ppos.actual_termination_date),-1,NULL,ppos.actual_termination_date)) + 1,p_end_date )  BETWEEN paaf2.effective_start_date AND paaf2.effective_end_date /* 8.0 */
           and emps.asg_date  BETWEEN paaf1.effective_start_date AND paaf1.effective_end_date /* 7.5 */
           AND paaf.person_id = papf.person_id
           AND paaf.assignment_type = 'E'
           AND paaf.primary_flag = 'Y'
           AND papf.business_group_id = 325
--           AND papf.employee_number in ('3001789' ,'3260140','3287520')
--           AND papf.employee_number in  ('3266009','3153036','3266009','3248855','3280569','3285355','3010695' ) /* 7.5 */
--           AND papf.employee_number in  (''3239771','3133789','3119638'      )
--           AND (papf.person_id in (85498,129949,1494129,98151)
--                           or papf.employee_number in ('3262811','3235247','3244623','3156319','3149112') --in ('3149112', '3155208' )-- in  ('3210473','3196392') -- ('3207999','3171089','3221503','3221502') -- ( '3162573','3197234','3197428','3062143','3145784')
--                           )
           AND hla.location_id = paaf.location_id
           AND hla.attribute2 NOT IN ( SELECT lookup_code
                                        -- FROM applsys.fnd_lookup_values		-- Commented code by IXPRAVEEN-ARGANO,09-May-2023
										 FROM apps.fnd_lookup_values              --  code Added by IXPRAVEEN-ARGANO,09-May-2023
                                        WHERE lookup_type = 'TTEC_IGNORE_BENEFIT_LOCATION' AND LANGUAGE = 'US'
                                          AND p_end_date BETWEEN start_date_active and NVL(end_date_active,'31-DEC-4712'))
           /* 6.2 Begin */
           AND papf.employee_number NOT IN ( SELECT lookup_code
                                               --FROM applsys.fnd_lookup_values		-- Commented code by IXPRAVEEN-ARGANO,09-May-2023
											   FROM apps.fnd_lookup_values            --  code Added by IXPRAVEEN-ARGANO,09-May-2023
                                              WHERE lookup_type = 'TTEC_EXCLUDE_EMP_BAML401K_FEED' AND LANGUAGE = 'US'
                                                AND p_end_date BETWEEN start_date_active and NVL(end_date_active,'31-DEC-4712'))
           /* 6.2 End */
           AND paaf.person_id = emps.person_id
           AND emps.asg_date BETWEEN paaf.effective_start_date
                                 AND paaf.effective_end_date
           AND emps.asg_date BETWEEN papf.effective_start_date
                                 AND papf.effective_end_date ;


-- 2.5            AND hla.attribute2 NOT IN ( SELECT lookup_code
-- 2.5                                          FROM applsys.fnd_lookup_values
-- 2.5                                         WHERE lookup_type = 'TTEC_IGNORE_BENEFIT_LOCATION' AND LANGUAGE = 'US')     -- V 1.6
-- 2.5            AND (
-- 2.5            (   -- Current employee
-- 2.5                to_date(DECODE(SIGN(p_end_date - ppos.actual_termination_date),-1,NULL,ppos.actual_termination_date)) is null
          -- AND ppos.date_start >= TO_DATE('20-JUN-2013')
-- 2.5            AND p_end_date BETWEEN papf.effective_start_date and papf.effective_end_date   /* 2.3 */
-- 2.5     AND p_end_date BETWEEN paaf.effective_start_date and paaf.effective_end_date   /* 2.3 */
           -- Remove future hires/rehires in the file.
           --AND ppos.date_start <= p_end_date -- CCnew Oct2
-- 2.5             )
-- 2.5             OR
-- 2.5             (   -- Include Term Since Beginning of the year only + future term
-- 2.5                 to_date(DECODE(SIGN(p_end_date - ppos.actual_termination_date),-1,NULL,ppos.actual_termination_date)) is not null
-- 2.5             AND ppos.actual_termination_date between  to_date('01-DEC-'||to_char(to_number(to_char(p_end_date,'YYYY')) -1))
-- 2.5                                                 and to_date('30-NOV-'||to_char( p_end_date,'YYYY'))
           --AND (ppos.actual_termination_date - ppos.date_start) > 14
-- 2.5             AND ppos.actual_termination_date + 1 BETWEEN papf.effective_start_date and papf.effective_end_date   -- 1.8
-- 2.5             AND ppos.actual_termination_date + 1 BETWEEN paaf.effective_start_date and paaf.effective_end_date  -- 1.8
-- 2.5             )
-- 2.5             );


--           AND (
--           (   -- Current employee + Future Hire
--               ppos.actual_termination_date is null
--          -- AND ppos.date_start >= TO_DATE('20-JUN-2013')
--           AND p_end_date BETWEEN papf.effective_start_date and papf.effective_end_date   /* 2.3 */
--           AND p_end_date BETWEEN paaf.effective_start_date and paaf.effective_end_date   /* 2.3 */
--           )
--           OR
--           (   -- Include Term Since Beginning of the year only + future term
--               ppos.actual_termination_date is not null
--           AND ppos.actual_termination_date between  to_date('01-DEC-'||to_char(to_number(to_char(p_end_date,'YYYY')) -1))
--                                                and to_date('30-NOV-'||to_char( p_end_date,'YYYY'))
--           AND (ppos.actual_termination_date - ppos.date_start) > 14
--           AND ppos.actual_termination_date + 1 BETWEEN papf.effective_start_date and papf.effective_end_date   -- 1.8
--           AND ppos.actual_termination_date + 1 BETWEEN paaf.effective_start_date and paaf.effective_end_date  -- 1.8
--           )
--           --  to not include those who never actually worked (term before hire) who had zero comp.
--           AND ( (     ppos.date_start =(SELECT MAX(date_start)
--                                           FROM hr.per_periods_of_service pps1
--                                          WHERE pps1.PERSON_ID = ppos.PERSON_ID)
--                   AND ppos.actual_termination_date is not null
--                   --and ppos.actual_termination_date <=  p_end_date
--                   and (ppos.actual_termination_date - ppos.date_start) > 14
--                  )
--                  -- Remove future hires/rehires in the file.
--                   OR (ppos.date_start <= p_end_date AND ppos.actual_termination_date is null )
--               )
--           );



--           AND hla.attribute2 NOT IN ( SELECT lookup_code
--                                         FROM fnd_lookup_values
--                                        WHERE lookup_type = 'TTEC_IGNORE_BENEFIT_LOCATION' AND LANGUAGE = 'US')     -- V 1.6
--           AND NVL (ppos.actual_termination_date + 1, p_end_date) BETWEEN papf.effective_start_date and papf.effective_end_date   -- 1.8
--           AND NVL (ppos.actual_termination_date + 1, p_end_date) BETWEEN paaf.effective_start_date and paaf.effective_end_date  -- 1.8
--           /* 1.9  Begin */
--           -- AND NVL (ppos.actual_termination_date + 1, p_end_date) BETWEEN p_start_date and GREATEST(NVL(ppos.actual_termination_date + 1,p_end_date),p_end_date); -- V 1.7  -- 1.8
--           AND NVL (ppos.actual_termination_date, '31-DEC-4712') >=  to_date('01-DEC-'||to_char(to_number(to_char(p_end_date,'YYYY')) -1))
--           -- Remove future hires/rehires in the file. Also to not include those who never actually worked (term before hire) who had zero comp.
--           AND ( (     ppos.date_start =(SELECT MAX(date_start)
--                                           FROM hr.per_periods_of_service pps1
--                                          WHERE pps1.PERSON_ID = ppos.PERSON_ID)
--                                            AND ppos.actual_termination_date is not null
--                                            and ppos.actual_termination_date <=  p_end_date
--                                            and (ppos.actual_termination_date - ppos.date_start) > 14
--                  )
--                   OR (ppos.date_start <= p_end_date AND ppos.actual_termination_date is null )
--               );
--            /* 1.9  End */
    /* 2.3 Begin */
    cursor c_emp_asg_cur(p_person_id IN NUMBER,p_end_date IN DATE)  is
    select assignment_id
    from per_all_assignments_f
    where person_id = p_person_id
    and effective_start_date between to_date('01-JAN-'||to_char(p_end_date,'YYYY')) and p_end_date
    UNION
    select assignment_id
    from per_all_assignments_f
    where person_id = p_person_id
    and effective_start_date = (select MAX(effective_start_date)
                                    from per_all_assignments_f
                                    where person_id = p_person_id);
    /* 2.3 End */
FUNCTION get_balance (
   p_assignment_id            NUMBER
 , p_balance_name        IN   VARCHAR2
 , p_dimension_name      IN   VARCHAR2
 , p_effective_date      IN   DATE
 , p_business_group_id   IN   NUMBER
)
RETURN VARCHAR2;
/* 1.1 Begin */
FUNCTION get_balance_new (
   p_assignment_id     in    NUMBER
 , p_balance_name        IN   VARCHAR2
 , p_dimension_name      IN   VARCHAR2
 ,p_effective_date   IN Date
 , p_business_group_id   IN   NUMBER
)
RETURN VARCHAR2;
/* 1.1  End */
    FUNCTION get_balance_2018 ( p_assignment_id    IN NUMBER
                              , p_balance_id       IN NUMBER
                              , p_effective_date   IN DATE
                              , p_ytd_flag         IN VARCHAR2 DEFAULT 'N'
)
RETURN NUMBER;
/* 2.6 Begin */
FUNCTION get_balance_2015 (
   p_person_id     in    NUMBER
 , p_balance_name        IN   VARCHAR2
 , p_dimension_name      IN   VARCHAR2
 , p_effective_date   IN Date
 , p_business_group_id   IN   NUMBER
)
RETURN VARCHAR2;
/* 2.6 End */
FUNCTION format_amount(p_amount IN NUMBER,
                       p_length IN NUMBER)
RETURN VARCHAR2;
PROCEDURE main(
          errcode                     OUT VARCHAR2,
          errbuff                     OUT VARCHAR2,
          p_check_date                 IN varchar2,
          p_adjusted_start_date        IN varchar2, /* 6.3 */
          p_bal_dimension              IN varchar2, /* 7.0 */
          p_401k_bal_name              IN varchar2,
          p_401k_FD_bal_name           IN varchar2,
          p_401k_catchup_bal_name      IN varchar2,
          p_401k_catchup_FD_bal_name   IN varchar2,
          p_401k_loan1_bal_name        IN varchar2,
          p_pre_tax_elig_comp_bal_name IN varchar2,
          p_pre_tax_elig_BEC_bal_name  IN varchar2, /* 7.2 */
          p_401k_bonus                 IN varchar2,
          p_payroll_name               IN varchar2,
          p_Ignore_PEO_missing         IN varchar2,
          p_email_recipients           IN varchar2
);
END TTEC_BAML_401K_OUTBOUND_INT;
/
show errors;
/