/************************************************************************************
        Program Name:  ttec_salary_breakup_pkg

       Modification Log
       Name                  Version #    Date            Description
       -----                 --------     -----           -------------
    IXPRAVEEN(ARGANO)            1.0     29-June-2023     R12.2 Upgrade Remediation
    ****************************************************************************************/
	
create or replace PACKAGE BODY ttec_salary_breakup_pkg IS

    PROCEDURE main (

        errbuf    OUT VARCHAR2,

        retcode   OUT NUMBER

    ) IS


        v_date_to                     DATE;

        v_previous_date_from          DATE;

        v_pea_object_version_number   NUMBER;
        p_ctc varchar2(200);

        v_id_flex_num                 fnd_id_flex_structures_vl.id_flex_num%TYPE;

        v_person_analysis_id          per_person_analyses.person_analysis_id%TYPE;

        v_analysis_criteria_id        per_analysis_criteria.analysis_criteria_id%TYPE;



              p_change_date per_pay_proposals.change_date%TYPE;

            p_annual_sal  per_pay_proposals.proposed_salary_n%TYPE;

        v_basic                       NUMBER(10,2) := 0;

        v_hra                         NUMBER(10,2) := 0;

        v_bonus                        NUMBER(10,2) := 0;

        v_education_allowance         NUMBER(10,2) := 0;

        v_prof_allowance              NUMBER(10,2) := 0;

        v_lta                         NUMBER(10,2) := 0; /*This is also applicable to Ahemadabad*/

        v_books_and_periodicals       NUMBER(10,2) := 0; /*This is also applicable to Ahemadabad*/

        v_advance                     NUMBER(10,2) := 0;/*This is also applicable to Ahemadabad, basic salary is <21000*/

        v_sodexo                      NUMBER(10,2) := 0; /*This is also applicable to Ahemadabad*/

        v_pf                          NUMBER(10,2) := 0;

        v_esi_employee_contribution   NUMBER(10,2) := 0; /*Applicable for Ahemadabad Location*/

        v_esi_employer_contribution  NUMBER(10,2) := 0; /*Applicable for Ahemadabad Location*/

        v_internet_allowance          NUMBER(10,2) := 0; /*Applicable for Hyderabad Location, derive from lookup*/

        v_ema                         NUMBER(10,2) := 0; /*Applicable for Hyderabad Location*/

        v_pf_employee                 NUMBER(10,2) := 0; /*Applicable for Ahemadabad Location, where both will be deducted from fixed salary */

        v_pf_employer                 NUMBER(10,2) := 0; /*Applicable for Ahemadabad Location, where both will be deducted from fixed salary*/

        l_sodexo                      NUMBER(10,2) := 0; /*This is also applicable to Ahemadabad*/

        l_meal_allowance              NUMBER(10,2) := 0;/*This is applicable only to Hyderabad*/

        v_gross                       NUMBER(10,2) := 0;

        v_reconciliation              NUMBER(10,2) := 0;

        v_remaining                   NUMBER(10,2) := 0;
        pf_advance_net                NUMBER(10,2) := 0;

        V_ERR VARCHAR2(3000):=NULL;


        pf_allowance NUMBER(10,2) := 0;

        prof_allowance_net NUMBER(10,2) := 0;

        pf_advance_bonus NUMBER(10,2) := 0;

        v_min NUMBER(10,2) := 0;
         v_prof_tax NUMBER(10,2) := 0;

        v_date_cp varchar2(500);

        v_date_sit varchar2(500);

        l_sit_exists number:=0; -- To check wether SIT exists or not
        l_sit_end_dated number:=0; -- To Check wether SIT end-dated or not.

        CURSOR sal_changes IS

   /*New Salary +

     Updating Existing Salary during BPA +

     Future dated hires New Salary



   This cursor will take care of current and future dated hires, including existing employees.

   who has new salary created or Updated their salary during BPA or offcycle.

   */ SELECT

            papf.person_id,

            PAPF.EMPLOYEE_NUMBER,

            ppp.change_date,

            ppp.proposed_salary_n * 12 AS ANNUAL_SAL,

            (

                SELECT

                    hla.attribute2

                FROM

                    apps.hr_locations_all hla

                WHERE

                    hla.location_id = paaf.location_id

                    AND   ROWNUM = 1

            ) AS LOCATION_CODE

                              FROM

            apps.per_all_people_f papf,

            apps.per_all_assignments_f paaf,

            apps.per_pay_proposals ppp,

            apps.per_periods_of_service ppos

                              WHERE

            papf.current_employee_flag = 'Y'

            AND   papf.person_id = paaf.person_id

          /*The below condition will ensure future dated hires

             ppos.date_start can be future date as well.

          */

            AND   ppos.date_start BETWEEN papf.effective_start_date (+) AND papf.effective_end_date (+)

            AND   ppos.date_start BETWEEN paaf.effective_start_date (+) AND paaf.effective_end_date (+)

            AND   paaf.period_of_service_id = ppos.period_of_service_id

            AND   papf.person_id = ppos.person_id

            AND   papf.business_group_id = 48558

            AND   ppp.business_group_id = 48558

        --  AND   PAPF.PERSON_ID IN ('2199179')
            AND   ppos.period_of_service_id = (

                SELECT

                    MAX(period_of_service_id)

                FROM

                    apps.per_periods_of_service ppos1

                WHERE

                    ppos1.period_of_service_id = paaf.period_of_service_id

                    AND   ppos1.actual_termination_date IS NULL

            )

          --and papf.employee_number='7504238'

            AND   paaf.location_id IN (

            select a.location_id from apps.hr_locations a

where a.country='IN'

and upper(a.TOWN_OR_CITY) IN ('AHMEDABAD'))--,'HYDERABAD'))

            --)--As of now hardcoded only for Hyderabad and Ahmedabad. Please maintain a lookup. In Case if we need*/

         -- to add any more location, we can simply add in that lookup

          --TTEC-Digital-Analytics-India-Hyderabad (Location Code: 02640)

          --TTEC-IND-Ahmedabad IT Hub (Location Code: 02631)

        --    AND   papf.email_address ='ahmedhabadtest2@ttec.com'--'hyderabadtest1@ttec.com'--'ahmedhabadtest2@ttec.com'--'hyderabadtest1@ttec.com'--'ahmedhabadtest2@ttec.com'-- 'ahmedhabadtest1@ttec.com'--'hyderabadtest1@ttec.com' --'ahmedhabadtest1@ttec.com'--'ahmedhabadtest2@ttec.com'---

       --   and to_date(LAST_UPDATE_DATE,'DD-MON-YYYY Hhyderabadtest1@ttec.comH24:MI:SS')

         -- AND ppp.LAST_UPDATE_DATE > TO_DATE('11-OCT-2022 22:10:10','DD-MON-YYYY HH24:MI:SS') -- PROGRAM LAST SUCCESSFUL DATE

         --   and ppp.proposed_salary_n > 25000
            AND   date_to = TO_DATE('31-12-4712','DD-MM-YYYY')

          --  AND PAPF.EMPLOYEE_NUMBER='7500024'

           -- AND 1=2

     /* For the first run, it will pick up everything and from second run onwards

     it would pick up the salaries updated after first run, that way we are doing incremental coverage

     */

    /*    and

      (  (ppp.LAST_UPDATE_DATE >=

       (select fcr.ACTUAL_COMPLETION_DATE from apps.fnd_concurrent_requests fcr, apps.fnd_concurrent_programs_vl fcpv

        where fcr.concurrent_program_id = fcpv.concurrent_program_id

        and fcpv.CONCURRENT_PROGRAM_NAME ='TTEC_SAL_BREAK_UP'

        and request_id = (

        select max(request_id) from TTEC_SALARY_BREAKUP_CP_DETAILS)

 )
 or
 (
 ppp.LAST_UPDATE_DATE >=
 (select DECODE(count(1),0,to_date('01-JAN-1951','DD-MON-YYYY')
 ) FROM TTEC_SALARY_BREAKUP_CP_DETAILS)
 )
)
OR
PAPF.EMPLOYEE_NUMBER IN
(select EMPLOYEE_NUMBER from TTEC_SAL_BREAKUP_STG TSBS where status='E'
AND TSBS.REQUEST_ID=
 (SELECT MAX(REQUEST_ID) FROM TTEC_SALARY_BREAKUP_CP_DETAILS)
)
)*/

         -- and sysdate between date_from and nvl(date_to,'31-12-4712')
              
            AND   ppp.assignment_id = paaf.assignment_id
            and papf.employee_number='7511268';


cursor sal_low(p_ctc varchar2)
is
select
CTC ,
BASIC ,
HRA,
EDUCATION ,
LTA ,
BOOKS_AND_PERIODICALS ,
PROFESSIONAL ,
ADV_BONUS ,
GROSS ,
PF ,
PT ,
ESIC ,
NET_SALARY ,
BONUS ,
employeer_PF ,
employer_ESIC ,
RECONCILIATION ,
NET_PROFESSIONAL ,
PF_ALLOWANCE ,
NET_ADV_BONUS ,
PF_ADV_BONUS ,
EFFECTIVE_START_DATE
--FROM CUST.TTEC_SBS_MANUAL_BREAKUP SBMB				 -- Commented code by IXPRAVEEN-ARGANO,30-June-2023
FROM apps.TTEC_SBS_MANUAL_BREAKUP SBMB                   --  code Added by IXPRAVEEN-ARGANO,   30-June-2023
WHERE SBMB.CTC = p_ctc
and sysdate between effective_start_date and effective_end_date;


        CURSOR c_id_flex IS SELECT

            id_flex_num

                            FROM

            fnd_id_flex_structures_vl

                            WHERE

            id_flex_structure_code = 'TTEC_SALARY_CONFLUENCE';



        CURSOR c_pre_contract (

            p_person_id     IN VARCHAR2,

            p_id_flex_num   IN VARCHAR2

        ) IS SELECT

            pa.person_analysis_id,

            ac.analysis_criteria_id,

            pa.date_from,

            pa.object_version_number,

            ac.segment10 AS SODEXO

             FROM
			--START R12.2 Upgrade Remediation
            /*hr.per_person_analyses pa,			-- Commented code by IXPRAVEEN-ARGANO,30-June-2023			

            hr.per_analysis_criteria ac -- It will hold all segment values, check last updated date from this table.*/
			apps.per_person_analyses pa,			--  code Added by IXPRAVEEN-ARGANO,   30-June-2023

            apps.per_analysis_criteria ac -- It will hold all segment values, check last updated date from this table.
			--END R12.2.12 Upgrade remediation
             WHERE

            pa.analysis_criteria_id = ac.analysis_criteria_id

            AND   pa.id_flex_num = p_id_flex_num

            AND   pa.person_id = p_person_id

            AND   date_from = (

                SELECT

                    MAX(pa1.date_from)

                FROM

                    --hr.per_person_analyses pa1			-- Commented code by IXPRAVEEN-ARGANO,30-June-2023
                    apps.per_person_analyses pa1            --  code Added by IXPRAVEEN-ARGANO,   30-June-2023

                WHERE

                    pa1.id_flex_num = p_id_flex_num

                    AND   pa1.person_id = p_person_id

            );


    BEGIN

        FOR i IN sal_changes  -- This will run for each employee, whose salary is updated, since last successful run of program.

         LOOP

/* Initializing for every one, irrespective of location*/

            v_basic := 0;

            v_hra := 0;

            v_education_allowance := 0;

            v_prof_allowance := 0; -- Fixed amount - remaining amount.

            v_lta := 0;

            v_bonus:=0;

            v_books_and_periodicals := 0;

            v_advance := 0;

            v_sodexo := 0;

            v_pf := 0;

            v_esi_employee_contribution := 0;

            v_esi_employer_contribution :=0;

            v_internet_allowance := 0;

            prof_allowance_net:=0;

            v_ema := 0;

            v_pf_employee := 0;

            v_pf_employer := 0;

            v_person_analysis_id := 0;

            v_analysis_criteria_id := 0;

            pf_advance_bonus:=0;

 --  v_previous_date_from:=0;

            v_pea_object_version_number := 0;

            pf_allowance:=0;
            v_remaining:=0;

            pf_advance_net:=0;

            l_sodexo := 0;
            v_prof_tax:=0;

     -- Cursor if for getting the flex number for  TTEC_SALARY_CONFLUENCE
            OPEN c_id_flex;

            FETCH c_id_flex INTO v_id_flex_num;

            CLOSE c_id_flex;


   -- The below cursor is for getting the person_analysis_id and analysis criteria id, if person has existing SIT.
   -- the below values would help us in end-dating the existing SIT values.
            OPEN c_pre_contract(i.person_id,v_id_flex_num);

            FETCH c_pre_contract INTO v_person_analysis_id,v_analysis_criteria_id,v_previous_date_from,v_pea_object_version_number,l_sodexo;

            CLOSE c_pre_contract;

         /*   fnd_file.put_line(fnd_file.log,'I.person_id'

            || i.person_id);

            fnd_file.put_line(fnd_file.log,'v_person_analysis_id'

            || v_person_analysis_id);
*/
       /*     IF

                i.location_code IN (

                  '02621',

'02620',

'02622',

'02621',

'02623',

'02624',

'02626',

'02625',

'02628',

'02627',

'02631'

                )

            THEN*/
fnd_file.put_line(fnd_file.log,'Before if condition: salary greater than 37500');
if i.annual_sal/12 > 37500
then
fnd_file.put_line(fnd_file.log,'After if condition: salary greater than 37500');
                -- Generally Basic is 40% Annual salary

                v_basic := ((i.annual_sal/12) * 40 )/ 100;

                   -- v_basic := 9888 * 12; -- Here we are updating it annually

                IF -- if Monthly CTC is <= 37500 then we need to use lookup to derive basic.

                   i.annual_sal / 12 <= 37500-- v_basic / 12 < 9888 -- while comparision we are doing basic monthly salary

                THEN

                  --  v_basic := 13000; /* Converting to monthly : 02-JAN-2023-- 13000 * 12;*/

                  begin

            select tag into v_basic from apps.fnd_lookup_values_vl

            where lookup_type='TTEC_SALARY_BASIC_DERIVATION'

            and (i.annual_sal/12) between meaning and description

             and enabled_flag='Y';

             exception when others

            then

            v_basic:=9888;

            end;

                END IF;



/* HRA Calculation

if monthly salary > 37500

then  50% ( 40 % Fixed salary)

else

40 % (40% Fixed salary)

end if

*/

                IF

                    i.annual_sal / 12 > 37500  -- if Monthly Salary is > 37500, then HRA is 50% of basic otherwise it is 40% basic

                THEN

                    v_hra := round(v_basic * 50 / 100);

                ELSE

                    v_hra := round(v_basic * 40 / 100);

                END IF;



/* Education Allowance is constant 200 and fixed for all employees*/



 IF

      i.annual_sal / 12 > 37500

                    then

                v_education_allowance := 200; /* Converting to monthly : 02-JAN-2023200 * 12;*/

             else

             v_education_allowance :=0;

             end if;





                IF

                    i.annual_sal / 12 > 37500  -- if Monthly Salary is > 37500, then LTA is 15% Basic otherwise no LTA

                THEN

                    v_lta := round(v_basic * 15 / 100);

                ELSE

                    v_lta := 0;   -- No LTA for person less than 37500 Salary.

                END IF;



                IF

                  i.annual_sal / 12 <= 52500  -- v_basic / 12 <= 21000  -- if Monthly basic is <= 21000, then employee is elligible for 85% Bonus

                THEN

                   -- v_advance := 1681; /* Converting to monthly : 02-JAN-20231681 * 12;--v_basic * 85 / 100;*/
                   -- v_bonus := 297;
                   BEGIN
                   select TO_NUMBER(MEANING) INTO v_advance from apps.fnd_lookup_values
                   where lookup_type='TTEC_ADVANCE_WAGES'
                   and language='US'
                   AND LOOKUP_CODE='ADV_BONUS';
                   EXCEPTION WHEN
OTHERS
THEN
V_ERR:=SUBSTR(SQLERRM,1,2900);
INSERT INTO TTEC_SAL_BREAKUP_STG
(REQUEST_ID,
EMPLOYEE_NUMBER,
TRANSACTION_LOG,
STATUS,
MESSAGE,
LAST_UPDATED_BY ,
LAST_UPDATE_DATE ,
CREATED_BY,
CREATION_DATE
)
VALUES
(fnd_global.CONC_REQUEST_ID,
I.EMPLOYEE_NUMBER,
'Error during deriving advance bonus',
'E',
V_ERR
,fnd_profile.value('USER_ID')
,SYSDATE
,fnd_profile.value('USER_ID')
,SYSDATE
);

COMMIT;

END;

     BEGIN
                   select TO_NUMBER(MEANING) INTO v_bonus from apps.fnd_lookup_values
                   where lookup_type='TTEC_ADVANCE_WAGES'
                   and language='US'
                   AND LOOKUP_CODE='BONUS';

                 EXCEPTION WHEN
OTHERS
THEN
V_ERR:=SUBSTR(SQLERRM,1,2900);
INSERT INTO TTEC_SAL_BREAKUP_STG
(REQUEST_ID,
EMPLOYEE_NUMBER,
TRANSACTION_LOG,
STATUS,
MESSAGE,
LAST_UPDATED_BY ,
LAST_UPDATE_DATE ,
CREATED_BY,
CREATION_DATE
)
VALUES
(fnd_global.CONC_REQUEST_ID,
I.EMPLOYEE_NUMBER,
'Error during deriving  bonus',
'E',
V_ERR
,fnd_profile.value('USER_ID')
,SYSDATE
,fnd_profile.value('USER_ID')
,SYSDATE
);

COMMIT;

END;

                ELSE

                    v_advance := 0;   -- No Advance for person more than 21000 Salary.

                END IF;





/*If Monthly CTS >= 37500  and Monthly CTS <= 40,000

then BNP = 1000

if Monthly CTS >  40,000

then BNP = 1500

else

BNP = 0

end if*/



                IF

                    i.annual_sal / 12 >= 37500 AND i.annual_sal / 12 <= 40000  -- if Monthly CTS  <= 21000, then employee is elligible for 85% Bonus

                THEN

                    v_books_and_periodicals := 1000; /* Converting to monthly : 02-JAN-20231000 * 12;*/

                ELSIF i.annual_sal / 12 > 40000 THEN

                    v_books_and_periodicals := 1500; /* Converting to monthly : 02-JAN-2023 1500 * 12; */

                ELSE

                    v_books_and_periodicals := 0;

                END IF;



                v_sodexo := 0;-- This should be deducted from professional allownace.



if i.annual_sal / 12 <= 37500--v_prof_allowance < 0

then

v_gross:= v_basic + v_hra +  v_lta   + v_education_allowance + v_books_and_periodicals + v_advance;

v_min:=round(v_gross-v_hra);

end if;



/* Employee PF*/

                IF

                    i.annual_sal / 12 > 37500  -- if Monthly Salary is >= 37500, then Employee PF is 12%Basic

                THEN

                    v_pf_employee := round(v_basic * 12/ 100); /* Converting to monthly : 02-JAN-2023 v_basic * 12 / 100; */

                ELSE

                    v_pf_employee := round(least(v_min,1800)); /* Converting to monthly : 02-JAN-2023 1800 * 12;*/

                END IF;



/* Employer PF*/



                IF

                    i.annual_sal / 12 >= 37500  -- if Monthly Salary is >= 37500, then Employer PF is 12%Basic

                THEN

                    v_pf_employer := round(v_basic * 12/ 100); /* Converting to monthly : 02-JAN-2023 v_basic * 12 / 100; */

                ELSE

                    v_pf_employer := round(least(v_min,1800));--1800; /*1800 * 12;*/

                END IF;



/*

if monthly salary < 21001

then  3.25% Fixed salary

else

No ESI

*/





/*Professional allowance is adjustable allowance and it is

fixed - rest of components

*/



                v_prof_allowance := round(i.annual_sal/12) - ( v_basic + v_hra + v_education_allowance + v_lta + v_advance + v_books_and_periodicals + v_sodexo

                + v_pf_employee

              --  + v_pf_employer

+ v_esi_employee_contribution ); /*Converted to monthly i.annual_sal/12 02-JAN-2023*/



             /*   fnd_file.put_line(fnd_file.log,'before v_person_analysis_id IS NOT NULL ');

                fnd_file.put_line(fnd_file.log,'v_person_analysis_id'

                || v_person_analysis_id);*/

                v_sodexo := l_sodexo;



              l_sit_exists:=0; -- initializing SIT does not exists
              l_sit_end_dated:=0; -- initializing whether SIT end-dated or not.

                IF

                    ( v_person_analysis_id <> 0 AND v_person_analysis_id IS NOT NULL )
                    then

                    v_sodexo := l_sodexo;

                    l_sit_exists:=1;  -- SIT For Person Does exists.

               --  fnd_file.put_line(fnd_file.log,'v_sodexo:'|| v_sodexo);

                    v_prof_allowance := i.annual_sal/12 - ( v_basic + v_hra+v_education_allowance + v_lta + v_advance + v_books_and_periodicals + v_sodexo + v_pf_employee + v_pf_employer

+ v_esi_employee_contribution );




                    v_date_to := i.change_date - 1;

                   -- IF

                     --   v_previous_date_from >= v_date_to

                    --THEN
BEGIN

 IF v_previous_date_from < v_date_to
 THEN
    hr_sit_api.update_sit
    (p_validate => false,
    p_person_analysis_id => v_person_analysis_id,
    p_pea_object_version_number => v_pea_object_version_number
    ,p_analysis_criteria_id => v_analysis_criteria_id,
    p_date_from => v_previous_date_from,
    p_date_to => v_date_to);

    l_sit_end_dated:=1;
end if;

EXCEPTION WHEN
OTHERS
THEN
--V_ERR:=SUBSTR(SQLERRM,1,2900);
V_ERR:=SUBSTR(SQLERRM,1,2100)||' v_previous_date_from:'||v_previous_date_from||' v_date_to:'||v_date_to;
INSERT INTO TTEC_SAL_BREAKUP_STG
(REQUEST_ID,
EMPLOYEE_NUMBER,
TRANSACTION_LOG,
STATUS,
MESSAGE,
LAST_UPDATED_BY ,
LAST_UPDATE_DATE ,
CREATED_BY,
CREATION_DATE
)
VALUES
(fnd_global.CONC_REQUEST_ID,
I.EMPLOYEE_NUMBER,
'Error during End-dating SIT',
'E',
V_ERR
,fnd_profile.value('USER_ID')
,SYSDATE
,fnd_profile.value('USER_ID')
,SYSDATE
);

COMMIT;

END;

                END IF;



                v_analysis_criteria_id := NULL; -- Without initializing it new SIT will not be created.

                v_sodexo := l_sodexo; -- taking Sodexo from previous SIT and loading in new SIT.

                v_prof_allowance := i.annual_sal/12 - ( v_basic + v_hra+v_education_allowance + v_lta + v_advance
                + v_bonus
                + v_books_and_periodicals + v_sodexo + v_pf_employee

                --+ v_pf_employer

+ v_esi_employee_contribution );



-- fnd_file.put_line(fnd_file.log,'before actual v_prof_allowance '

  --              || v_prof_allowance);



/* Adjustment during negative professional allowance */

if i.annual_sal / 12 <= 37500--v_prof_allowance < 0

then

v_gross:= v_basic + v_hra +  v_lta   + v_education_allowance + v_books_and_periodicals + v_advance;



--22681:= 15000 + 6000 + 0 + 0+ 1681



v_reconciliation:= v_gross +  297 + v_pf_employee + v_esi_employer_contribution;

 --   24,778:=                22681  +  297 + 1800 + 0;



v_remaining:= i.annual_sal / 12 - v_reconciliation;

      --     =  31237  -  24778



v_prof_allowance:= v_remaining;

end if;





-- fnd_file.put_line(fnd_file.log,'After actual v_prof_allowance '

  --              || v_prof_allowance);



v_gross:= v_basic + v_hra +  v_lta   + v_education_allowance + v_prof_allowance+v_books_and_periodicals + v_advance;

                IF i.annual_sal / 12 < 23100  -- if Monthly Salary is < 21001, then 3.25% Fixed salary
                THEN
                    v_esi_employer_contribution := Round((3.25 * v_gross)/100); /* Converting to monthly */
                ELSE
                    v_esi_employer_contribution := 0; -- No ESI
                END IF;


                IF i.annual_sal / 12 < 23100  -- if Monthly Salary is < 21001, then 0.75% Fixed salary
                THEN
                    v_esi_employee_contribution := Round((0.75 * v_gross)/100); /* Converting to monthly */
                ELSE
                    v_esi_employee_contribution := 0; -- No ESI
                END IF;


if i.annual_sal / 12 > 12000
then
v_prof_tax:=200;
else

v_prof_tax:=0;
end if;


/*PF Allowance*/
If v_basic < 15000
then
if (v_basic + v_prof_allowance) >=15000
then
pf_allowance:= v_prof_allowance - (v_basic + v_prof_allowance - 15000);
else
pf_allowance:=v_prof_allowance;
end if;
else
pf_allowance:=0;
end if;

/*Profession allowance Net =  v_prof_allowance - pf_allowance*/

prof_allowance_net:= round(v_prof_allowance - pf_allowance);


if (v_basic + v_prof_allowance) < 15000
then
--FND_FILE.PUT_LINE(FND_FILE.LOG,'(v_basic + v_prof_allowance) < 15000');

   if (v_basic + v_prof_allowance + v_advance) >= 15000
   then
--FND_FILE.PUT_LINE(FND_FILE.LOG,'(v_basic + v_prof_allowance + v_advance) >= 15000');
   pf_advance_bonus:= v_advance - ((v_basic + v_prof_allowance + v_advance) - 15000);
--FND_FILE.PUT_LINE(FND_FILE.LOG,'pf_advance_bonus'||pf_advance_bonus);
   else

   pf_advance_bonus:= v_advance;

   end if;

else

  pf_advance_bonus:=0;

end if;

/*pf_advance_net: = v_advance - pf_advance_bonus */
pf_advance_net:= v_advance - pf_advance_bonus ;

 IF ( (l_sit_exists=0 and l_sit_end_dated=0)  -- Either SIT does not exists and not end-dated in this case new SIT is entered.
     or
     (l_sit_exists=1 and l_sit_end_dated=1)   -- Either SIT exists and end-dated, in this case we enter new SIT feild.
     )
     -- But if SIT exists and not-endated, then in that case we are not going to insert a new SIT record.
then
 --This is to avoid un-necessary reprocessing of employees because of any reason,
 --  where salary does not get changed, but employee has been picked to end-date the current SIT value.


                BEGIN

                    hr_sit_api.create_sit(p_person_id => i.person_id,

                    p_business_group_id => 48558,

                    p_id_flex_num => v_id_flex_num,

                    p_effective_date => i.change_date

                    ,p_date_from => i.change_date,

                    p_segment1 => round(v_basic),

                    p_segment2 => round(v_hra),

                    p_segment3 => round(v_prof_allowance),--v_education_allowance, v_prof_allowance,

                    p_segment4 => round(v_lta),--v_prof_allowance,

                    p_segment5 => v_pf_employee,--v_lta,

                    p_segment6 => round(v_esi_employee_contribution),--v_books_and_periodicals,

                    p_segment7 => v_education_allowance,--v_books_and_periodicals-- + v_education_allowance),--v_advance,

                    p_segment8 => v_books_and_periodicals,--v_advance,--l_sodexo,

		    	    p_segment9  => round(v_advance),-- v_advance,

                    p_segment10 => l_sodexo,--(l_meal_allowance + v_internet_allowance),-- v_esi_employee_contribution,

                    p_segment11 => l_meal_allowance, -- v_internet_allowance,

                    p_segment12 => v_internet_allowance,--v_ema,

                    p_segment13 => round(pf_allowance),-- pf allowance

                    p_segment14 => round(pf_advance_bonus),-- v_pf_employee, -- pf advance bonus

                    p_segment15 => round(v_prof_tax),-- professional tax

                    p_segment16 => round(v_pf_employer),

                    p_segment17 => round(v_esi_employer_contribution),

                    p_segment18 => round(prof_allowance_net),

                    p_segment19 => round(pf_advance_net),

                    p_segment20 => round(v_gross),

                    p_segment21 => round(v_bonus),
                  --  p_segment15 => l_meal_allowance,

                    p_analysis_criteria_id => v_analysis_criteria_id,



                    p_person_analysis_id => v_person_analysis_id

                    ,p_pea_object_version_number => v_pea_object_version_number);


INSERT INTO TTEC_SAL_BREAKUP_STG
(REQUEST_ID,
EMPLOYEE_NUMBER,
TRANSACTION_LOG,
STATUS,
MESSAGE,
LAST_UPDATED_BY ,
LAST_UPDATE_DATE ,
CREATED_BY,
CREATION_DATE,
CTC ,
BASIC ,
HRA,
PROFESSIONAL ,
LTA ,
PF ,
ESIC ,
EDUCATION ,
BOOKS_AND_PERIODICALS ,
ADV_BONUS ,
SODEXO ,
INTERNT_ALLOWANCE ,
MEAL_ALLOWANCE ,
PF_ALLOWANCE ,
PF_ADV_BONUS ,
PT ,
employeer_PF ,
employer_ESIC ,
NET_PROFESSIONAL ,
NET_ADV_BONUS ,
GROSS ,
BONUS
)
VALUES
(fnd_global.CONC_REQUEST_ID,
I.EMPLOYEE_NUMBER,
'Successfully Created Breakup',
'S',
NULL
,fnd_profile.value('USER_ID')
,SYSDATE
,fnd_profile.value('USER_ID')
,SYSDATE
,i.annual_sal / 12
,v_basic
,v_hra
,v_prof_allowance
,v_lta
,v_pf_employee
,v_esi_employee_contribution
,v_education_allowance
,v_books_and_periodicals
,v_advance
,l_sodexo
,l_meal_allowance
,v_internet_allowance
,pf_allowance
,pf_advance_bonus
,v_prof_tax
,v_pf_employer
,v_esi_employer_contribution
,prof_allowance_net
,pf_advance_net
,v_gross
,v_bonus
);


COMMIT;

                EXCEPTION
                 WHEN OTHERS
                     THEN
V_ERR:=SUBSTR(SQLERRM,1,2900);
              INSERT INTO TTEC_SAL_BREAKUP_STG
(REQUEST_ID,
EMPLOYEE_NUMBER,
TRANSACTION_LOG,
STATUS,
MESSAGE,
LAST_UPDATED_BY ,
LAST_UPDATE_DATE ,
CREATED_BY,
CREATION_DATE
)
VALUES
(fnd_global.CONC_REQUEST_ID,
I.EMPLOYEE_NUMBER,
'Error while creating SIT',
'E',
V_ERR
,fnd_profile.value('USER_ID')
,SYSDATE
,fnd_profile.value('USER_ID')
,SYSDATE
);

COMMIT;

                END;

                end if;--end of SIT

else  -- Salary is less than 25000

fnd_file.put_line(fnd_file.log,'Entered into else, Salary less than 37500');
--fnd_file.put_line(fnd_file.log,'Entered into Loop Salary less than 25000');

p_ctc:=i.annual_sal / 12;

l_sit_exists:=0; -- initializing SIT does not exists
l_sit_end_dated:=0; -- initializing whether SIT end-dated or not.
for s1 in sal_low(p_ctc)
loop
v_sodexo:=0;

fnd_file.put_line(fnd_file.log,'Entered into Loop Salary less than 37500');
/*If there is any existing SIT, first we need to end-date it*/
 IF ( v_person_analysis_id <> 0 AND v_person_analysis_id IS NOT NULL )
then

BEGIN
v_sodexo := l_sodexo;

 v_date_to := i.change_date - 1;

 l_sit_exists:=1;-- sit exists

 --This is to avoid un-necessary reprocessing of employees because of any reason,
 --  where salary does not get changed, but employee has been picked to end-date the current SIT value.
 -- in this case p_date_from will be greater than v_date_to
 IF v_previous_date_from < v_date_to
 THEN
  hr_sit_api.update_sit
    (p_validate => false,
    p_person_analysis_id => v_person_analysis_id,
    p_pea_object_version_number => v_pea_object_version_number
    ,p_analysis_criteria_id => v_analysis_criteria_id,
    p_date_from => v_previous_date_from,
    p_date_to => v_date_to);

    l_sit_end_dated:=1;
  END IF;

 EXCEPTION
 WHEN OTHERS
 THEN

 V_ERR:=SUBSTR(SQLERRM,1,2100)||' v_previous_date_from:'||v_previous_date_from||' v_date_to:'||v_date_to;
INSERT INTO TTEC_SAL_BREAKUP_STG
(REQUEST_ID,
EMPLOYEE_NUMBER,
TRANSACTION_LOG,
STATUS,
MESSAGE,
LAST_UPDATED_BY ,
LAST_UPDATE_DATE ,
CREATED_BY,
CREATION_DATE
)
VALUES
(fnd_global.CONC_REQUEST_ID,
I.EMPLOYEE_NUMBER,
'Error during End-dating SIT',
'E',
V_ERR
,fnd_profile.value('USER_ID')
,SYSDATE
,fnd_profile.value('USER_ID')
,SYSDATE
);

COMMIT;

 END;

 end if;



 IF ( (l_sit_exists=0 and l_sit_end_dated=0)  -- Either SIT does not exists and not end-dated in this case new SIT is entered.
     or
     (l_sit_exists=1 and l_sit_end_dated=1)   -- Either SIT exists and end-dated, in this case we enter new SIT feild.
     )
     -- But if SIT exists and not-endated, then in that case we are not going to insert a new SIT record.
then
 --This is to avoid un-necessary reprocessing of employees because of any reason,
 --  where salary does not get changed, but employee has been picked to end-date the current SIT value.
  BEGIN

fnd_file.put_line(fnd_file.log,'Before executing API, Salary less than 37500');
 v_analysis_criteria_id:=NULL;
 v_person_analysis_id:=NULL;

                    hr_sit_api.create_sit(p_person_id => i.person_id,

                    p_business_group_id => 48558,

                    p_id_flex_num => v_id_flex_num,

                    p_effective_date => i.change_date

                    ,p_date_from => i.change_date,

                    p_segment1 => s1.BASIC,

                    p_segment2 => s1.HRA,

                    p_segment3 => (s1.PROFESSIONAL - v_sodexo),--v_education_allowance, v_prof_allowance,

                    p_segment4 => s1.LTA,--v_prof_allowance,

                    p_segment5 => s1.PF,--v_lta,

                    p_segment6 => s1.ESIC,--v_books_and_periodicals,

                    p_segment7 => s1.EDUCATION,--v_books_and_periodicals-- + v_education_allowance),--v_advance,

                    p_segment8 => s1.BOOKS_AND_PERIODICALS,--v_advance,--l_sodexo,

		    	    p_segment9  => s1.ADV_BONUS,-- v_advance,

                    p_segment10 => v_sodexo,--(l_meal_allowance + v_internet_allowance),-- v_esi_employee_contribution,

                    p_segment11 => 0, -- v_internet_allowance,

                    p_segment12 => 0,--v_ema,

                    p_segment13 => s1.PF_ALLOWANCE,-- pf allowance

                    p_segment14 => s1.PF_ADV_BONUS,-- v_pf_employee, -- pf advance bonus

                    p_segment15 => s1.PT,-- professional tax

                    p_segment16 => s1.employeer_PF,

                    p_segment17 => s1.employer_ESIC,

                    p_segment18 => s1.NET_PROFESSIONAL,

                    p_segment19 => s1.NET_ADV_BONUS,

                    p_segment20 => s1.GROSS,

                    p_segment21 => s1.bonus,
                  --  p_segment15 => l_meal_allowance,

                    p_analysis_criteria_id => v_analysis_criteria_id,



                    p_person_analysis_id => v_person_analysis_id

                    ,p_pea_object_version_number => v_pea_object_version_number);

 INSERT INTO TTEC_SAL_BREAKUP_STG
(REQUEST_ID,
EMPLOYEE_NUMBER,
TRANSACTION_LOG,
STATUS,
MESSAGE,
LAST_UPDATED_BY ,
LAST_UPDATE_DATE ,
CREATED_BY,
CREATION_DATE,
CTC ,
BASIC ,
HRA,
PROFESSIONAL ,
LTA ,
PF ,
ESIC ,
EDUCATION ,
BOOKS_AND_PERIODICALS ,
ADV_BONUS ,
SODEXO ,
INTERNT_ALLOWANCE ,
MEAL_ALLOWANCE ,
PF_ALLOWANCE ,
PF_ADV_BONUS ,
PT ,
employeer_PF ,
employer_ESIC ,
NET_PROFESSIONAL ,
NET_ADV_BONUS ,
GROSS ,
BONUS
)
VALUES
(fnd_global.CONC_REQUEST_ID,
I.EMPLOYEE_NUMBER,
'Successfully Created Breakup',
'S',
NULL
,fnd_profile.value('USER_ID')
,SYSDATE
,fnd_profile.value('USER_ID')
,SYSDATE
,i.annual_sal / 12
,s1.BASIC
,s1.HRA
,(s1.PROFESSIONAL - v_sodexo)
,s1.LTA
,s1.PF
,s1.ESIC
,s1.EDUCATION
,s1.BOOKS_AND_PERIODICALS
,s1.ADV_BONUS
,v_sodexo
,0
,0
,s1.PF_ALLOWANCE
,s1.PF_ADV_BONUS
,s1.PT
,s1.employeer_PF
,s1.employer_ESIC
,s1.NET_PROFESSIONAL
,s1.NET_ADV_BONUS
,s1.GROSS
,s1.bonus
);


COMMIT;



                EXCEPTION
                 WHEN OTHERS
                     THEN

                     V_ERR:=SUBSTR(SQLERRM,1,2900); -- FIRST STORE IT VARIABLE AND THEN ASSING IT IN TABLE, OTHER WISE IT WILL THROW COLUMN NOT ALLOWED ERROR.

                        INSERT INTO TTEC_SAL_BREAKUP_STG
(REQUEST_ID,
EMPLOYEE_NUMBER,
TRANSACTION_LOG,
STATUS,
MESSAGE,
LAST_UPDATED_BY ,
LAST_UPDATE_DATE ,
CREATED_BY,
CREATION_DATE
)
VALUES
(fnd_global.CONC_REQUEST_ID,
I.EMPLOYEE_NUMBER,
'Error while creating SIT',
'E',
V_ERR
,fnd_profile.value('USER_ID')
,SYSDATE
,fnd_profile.value('USER_ID')
,SYSDATE
);

COMMIT;

                END;
                end if; -- end of SIT conditions.
END LOOP;

 END IF; -- ONE FOR SAL < 25000
-- END IF;--ONE FOR LOCATION


        END LOOP;

--END IF;



/* Coding Starts for SIT Changes, incase if there are any changes to Sodexo */



/*for SIT in SIT_Changes

loop



end loop;*/




/* The below insert statement should be in the last

   Because if we keep at the begining, it will insert current running request id before we call cursors.

   Now cursor will make use of max of request id from the below table, which is nothing but current running program

   and this would lead to getting null value as actuall completion time.

   because we are checking on current program

*/

 BEGIN

    insert into TTEC_SALARY_BREAKUP_CP_DETAILS

     (REQUEST_ID  ,

     REQUEST_DATE ,

     CONCURRENT_PROG_NAME

     )

       select fcr.request_id,fcr.request_date,'TTEC Salary Break Up Structure'

 from apps.fnd_concurrent_requests fcr, apps.fnd_concurrent_programs_vl fcpv

 where fcr.concurrent_program_id = fcpv.concurrent_program_id

 and fcpv.CONCURRENT_PROGRAM_NAME ='TTEC_SAL_BREAK_UP'

 and request_id = (

 select max(fcr.request_id) from apps.fnd_concurrent_requests fcr, apps.fnd_concurrent_programs_vl fcpv

 where fcr.concurrent_program_id = fcpv.concurrent_program_id

 and fcpv.CONCURRENT_PROGRAM_NAME ='TTEC_SAL_BREAK_UP'

 );

 commit;

 END;



    END;
END ttec_salary_breakup_pkg;
/
show errors;
/