set define off;
create or replace PACKAGE BODY      TTEC_TROWE_401K_OUTBOUND_INT AS
--
-- Program Name:  TTEC_TROWE_401K_OUTBOUND_INT
-- /* $Header: TTEC_TROWE_401K_OUTBOUND_INT.pkb 1.0 2011/10/14  chchan ship $ */
--
-- /*== START ================================================================================================*\
--    Author: Christiane Chan
--      Date: 14-OCT-2011

-- Call From: Concurrent Program ->TeleTech TRM Benefit 401K Outbound Interface
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
--      1.5  03/28/13   Kgonuguntla TTSD R 2161944 - Fixed 1 & 2 issues mentioned on the ticket.
--      1.6  04/25/2013 Kgonuguntla TTSD I#2366133 - To pull future terms and also to pull based on the check date not by pay date
--      1.9  06/26/13   CChan     TTSD  2512847 - Fix on missing rehire + modify the to pull Termed employee all the way to 12/1 of prior year
--                                                In Addition, remove future hires/rehires in the file. and to not include those who never actually worked (term before hire) who had zero comp.
--                                                Heather's update on 6/28/2013 : I did verify with Merrill Lynch and they are on board with keeping the rehire date in the field even after termination.
--      2.0  12/09/2013 CChan     PEO integration Project
--      2.3  07/10/2014 CChan     INC0379039 - BAML interface to combine those with multiple assigments to one row on the file for the year
--      2.4  09/29/2014 CChan     INC0560420 - Rehires and terms with future date - need to use the pay period end date rather than the paydate
--      3.0  08/06/2015  Amir Aslam          1.3       changes for Re hosting Project
--      4.0  08/21/2015  Lalitha       changes for Re hosting Project for smtp server name
--      5.0  12/07/2015 CChan     INC2493117 - Dec 07, 2016 5.1 - Divorce Code - No Fix
--                                                          5.2 - Negative Mapping
--                                                          5.3 - Special Character - Fix
--                                                          5.4 - December Term - No Fix put in yet
--                                                          5.5 - Advice Salary - Fix
--                                                          5.6 - Modified the default Vested Date to Hire date instead of rehire date
--      6.0  02/21/2017 CChan     DMND0008093 - Feb 21,2017 6.1 - Currently incorrect mapping of codes for marital statuses (causes issues for participants when they manage their accounts and results in a poor customer experience); Not an issue cancelled
--                                                          6.2 - A table to exclude certain individuals that should not pass over on the file but are currently being generated on the file due to their file in Oracle (because of which we are currently paying a per-head fee for multiple individuals that should not be in the plan - wasted dollars), in particular those with multiple records in Oracle or those who were entered into Oracle but terminated prior to employment. This fix would also prevent employees that are not being enrolled in Merrill Lynch's system when they should be because they have multiple Oracle IDs that are creating errors - causes compliance gaps with plan;
--                                                          6.3 - Add the capability to define the date parameters of the report, which needs to be accessible for an event where we'd need to manipulate the dates (particularly end-of-year payrolls) and reporting purposes.
--      7.0  02/21/2018 CChan     2018 requirements: -  adding Pre Tax 401K Bonus + Pre Tax 401K Flat Dollar and Balance Dimension Parameter
--      7.1  05/09/2018 CChan     Rehired employees need to be sent with 97, not 06, or BAML will not overide the termed staus code ->30 , number has to be greater than 31, therefore ->97
--      7.2  05/11/2018 CChan     Need to add "Pre Tax 401K Bonus Eligible Comp" to existing Eligible Comp
--      7.3  08/24/2018 CChan     Fix for the compensation fields, Field 46, 54 and 69, it looks like we use to send the eligible YTD balance feed.  Currently, it appears that just the current payroll amount is being passed.
--      7.4  09/05/2018 CChan     Fix on remove non-ascii charater
--      7.5  01/16/2019 CChan    Fix on Year End missing employees on the extract
--      7.6  01/18/2019 CChan    Email from Beth Cygan Sent: Friday, January 18, 2019 3:47 PM - ELIGIBILITY FLAG field in column 65, space 465 that is off by one position.  All those on the file have a code "N" and should have one additional space in front of the code.
--                               If utilizing EZ Enrollment, enter a "Y".  Otherwise, enter a space.
--      7.7  05/20/2019 CChan    Adding US_401K_Discrimination_Testing balance to Field 54 "NON-DISCRIM TESTING COMP"
--      9.0  10/11/2019 CChan    create T Rowe specific request
--                               1. modified 610115 to 106263
--                               2. 03-active 30-term  36-deceased
--                               3. Modified Field 15   PAYROLL FREQUENCY  from B to 6
--                               4. Modified Field 24   SOURCE 2 LABEL- Z  to $ for Pre Tax 401K Catchup
--                               5. Modified Field 15   Header Record PAYCHECK DATE from DDMMRRRR to RRRRMMDD
--                               6. Adding Phone number to Field 84 for TRP look for H1 (Home), if none then M (Mobile)
--      9.1  12/02/2019 CChan   Changing the email addresses to be left Justified
--      9.2  12/05/2019 CChan   Exclude No Shows where hire date = Term Date
--     11.0  01/18/2022 CChan    2022 requirements: - Adding 401K Roth:  'Base 401k Roth' and  'Base 401K Catch Up Roth'
--     12.0  12/12/2022 VKollai  Adding GCA Code, Job Family, Match Entry Date and Match Accrual amount.
--     12.1  04/11/2023 VKollai  Adding PAY PERIOD COMPENSATION to send monthly pay period.
--     1.0   05/15/2023 RXNETHI-ARGANO   R12.2 Upgrade Remediation
-- \*== END =====================================

    --v_module                         cust.ttec_error_handling.module_name%TYPE := 'Main'; --code commented by RXNETHI-ARGANO,15/05/23
	v_module                         apps.ttec_error_handling.module_name%TYPE := 'Main'; --code added by RXNETHI-ARGANO,15/05/23
    v_loc                            NUMBER;
    v_msg                            varchar2(2000);
    v_rec                            varchar2(5000);

    /*********************************************************
     **  Private Procedures and Functions
    *********************************************************/
    PROCEDURE print_header_column_name IS
    BEGIN

        v_rec :=      'Field 1    CONSTANT - UHDR '
               ||'|'||'Field 2     BLANK'
               ||'|'||'Field 3    CURRENT PROCESSING DATE(JULIAN)'
               ||'|'||'Field 4    ML PLAN NUMBER '
               ||'|'||'Field 5    FILE DESCRIPTION - Plan Name'
               ||'|'||'Field 6    PROCESSING TIME - HHMMSS'
               ||'|'||'Field 7    CYCLE DATE-  MMDDYY'
               ||'|'||'Field 8    BLANK'
               ||'|'||'Field 9    BLANK'
               ||'|'||'Field 10   BLANK'
               ||'|'||'Field 11   PAYROLL CREATOR'
               ||'|'||'Field 12   PAYROLL START DATE (JULIAN)'
               ||'|'||'Field 13   PAYROLL INDICATOR'
               ||'|'||'Field 14   PAYROLL END DATE'
               ||'|'||'Field 15   PAYCHECK DATE (JULIAN)'
               ||'|'||'Field 16   CONTACT NAME '
               ||'|'||'Field 17   CONTACT TELEPHONE NUMBER '
               ||'|'||'Field 18   BLANK'
          ;
        apps.fnd_file.put_line(apps.fnd_file.output,v_rec);
    END;
    PROCEDURE print_detail_column_name IS
    BEGIN

                v_rec :=  'Field 1    RECORD TYPE'
                   ||'|'||'Field 2    BLANK'
                   ||'|'||'Field 3    SOCIAL SECURITY NUMBER '
                   ||'|'||'Field 4    PARTICIPANT STATUS CODE'
                   ||'|'||'Field 5    DIVISION/SUBSIDIARY'
                   ||'|'||'Field 6    EMPLOYEE NUMBER'
                   ||'|'||'Field 6.5  EMPLOYEE GL LOCATION'
                   ||'|'||'Field 7    JOB FAMILY '              --12.0
                   ||'|'||'Field 8    GCA CODE'                 --12.0
                   ||'|'||'Field 9    FULL NAME'
                   ||'|'||'Field 10   DATE OF BIRTH YYMMDD'
                   ||'|'||'Field 11   DATE OF HIRE '
                   ||'|'||'Field 12   MATCH ENTRY DATE'         --12.0
                   ||'|'||'Field 13   DATE OF TERMINATION'
                   ||'|'||'Field 14   ALTERNATE VEST DATE '
                   ||'|'||'Field 15   PAYROLL FREQUENCY '
                   ||'|'||'Field 16   SECTION 16 INDICATOR'
                   ||'|'||'Field 17   ADDRESS LINE 1 '
                   ||'|'||'Field 18   ADDRESS LINE 2 '
                   ||'|'||'Field 19   CITY '
                   ||'|'||'Field 20   STATE'
                   ||'|'||'Field 21   ZIP'
                   ||'|'||'Field 22   SOURCE 1 LABEL- A '
                   ||'|'||'Field 23   SOURCE 1 AMOUNT - Pre Tax 401K'
                   ||'|'||'Field 24   SOURCE 2 LABEL- Z '
                   ||'|'||'Field 25   SOURCE 2 AMOUNT -  Pre Tax 401K Catchup'
                   ||'|'||'Field 26   SOURCE 3 LABEL- S'
                   ||'|'||'Field 27   SOURCE 3 AMOUNT - Base 401k Roth'
                   ||'|'||'Field 28   SOURCE 4 LABEL- #'
                   ||'|'||'Field 29   SOURCE 4 AMOUNT - Base 401K Catch Up Roth'
                   ||'|'||'Field 30   SOURCE 5 LABEL- Send Blank'
                   ||'|'||'Field 31   SOURCE 5 AMOUNT - Match Accrual Amount'          --12.0
                   ||'|'||'Field 32   SOURCE 6 LABEL- Send Blank'
                   ||'|'||'Field 33   SOURCE 6 AMOUNT - Send 0'
                   ||'|'||'Field 34   PAY PERIOD COMPENSATION'         --12.1 sending value
                   ||'|'||'Field 35   ML LOAN # - Send 0'
                   ||'|'||'Field 36   LOAN REPAYMENT AMOUNT - Loan 1_401k element'
                   ||'|'||'Field 37   ML LOAN # - corresponds to ml loan number - Send 0'
                   ||'|'||'Field 38   LOAN REPAYMENT AMOUNT - Send 0'
                   ||'|'||'Field 39   ML LOAN # - corresponds to ml loan number - Send 0'
                   ||'|'||'Field 40   LOAN REPAYMENT AMOUNT - Send 0'
                   ||'|'||'Field 41   ML LOAN # - corresponds to ml loan number - Send 0'
                   ||'|'||'Field 42   LOAN REPAYMENT AMOUNT - Send 0'
                   ||'|'||'Field 43   ML LOAN # - corresponds to ml loan number - Send 0'
                   ||'|'||'Field 44   LOAN REPAYMENT AMOUNT - Send 0'
                   ||'|'||'Field 45   CURRENT BASE PAY - Send 0'
                   ||'|'||'Field 46   PLAN COMP -Pre Tax 401K Eligible Comp Balance'
                   ||'|'||'Field 47   NON-RECURRING COMP  - Send Blanks'
                   ||'|'||'Field 48   YTD SEC 125 CONTRIB - Send Blanks'
                   ||'|'||'Field 49   BEFORE-TAX DEFERRAL % - Send Blanks'
                   ||'|'||'Field 50   AFTER-TAX CONTRIB % - Send Blanks'
                   ||'|'||'Field 51   PROFIT SHARING COMP - Send Blanks'
                   ||'|'||'Field 52   PLAN YTD MATCH COMP - Send Blanks'
                   ||'|'||'Field 53   PERIOD MATCH COMP - Send Blanks'
                   ||'|'||'Field 54   NON-DISCRIM TESTING COMP - Send 0'
                   ||'|'||'Field 55   ADVICE ANNUAL SALARY'
                   ||'|'||'Field 56   SALARY INCR EFFECTIVE DATE - Send Blanks'
                   ||'|'||'Field 57   ROTH AT DEFERRAL % - Send Blanks'
                   ||'|'||'Field 58   LPART INDICATOR '
                   ||'|'||'Field 59   PLAN YEAR-TO-DATE HOURS - Send Blanks'
                   ||'|'||'Field 60   OFFICER / 5% OWNER'
                   ||'|'||'Field 61   KEY EMPLOYEE - Send 0'
                   ||'|'||'Field 62   EXCLUDABLE TOP 20%- Send Blanks'
                   ||'|'||'Field 63   HIGHLY COMPENSATED EMPLOYEE - Send 0'
                   ||'|'||'Field 64   UNION/NON-UNION - Send Blanks'
                   ||'|'||'Field 65   ELIGIBILITY FLAG - If utilizing EZ Enrollment, enter a "Y".  Otherwise, enter a space' /* 7.5 */
                   ||'|'||'Field 66   ELIGIBLE HOURS - hours for eligibity tracking - Send 0'
                   ||'|'||'Field 67   PAYROLL DIVISION - Send Blanks'
                   ||'|'||'Field 68   RULE 144 INDICATOR - Send 0'
                   ||'|'||'Field 69   415 TEST COMP -Pre Tax 401K Eligible Comp'
                   ||'|'||'Field 70   RESIDENT OF PUERTO RICO '
                   ||'|'||'Field 71   EMPLOYER FLAG - Send Blanks'
                   ||'|'||'Field 72   REHIRE DATE '
                   ||'|'||'Field 73   LEAVE OF ABSENCE TYPE - Send Blanks'
                   ||'|'||'Field 74   SEX'
                   ||'|'||'Field 75   MARITAL STATUS '
                   ||'|'||'Field 76   FSE LSE INDICATOR - Send Blanks'
                   ||'|'||'Field 77   ROTH SAVE RATE USAGE INDICATOR - Send Blanks'
                   ||'|'||'Field 78   ELIGIBILITY DATE - Send Blanks'
                   ||'|'||'Field 79   BUSINESS E-MAIL ADDRESS '
                   ||'|'||'Field 80   USERRA START DATE - Send Blanks'
                   ||'|'||'Field 81   USERRA END DATE - Send Blanks'
                   ||'|'||'Field 82   LOA START DATE - Send Blanks'
                   ||'|'||'Field 83   LOA END DATE - Send Blanks'
                   ||'|'||'Field 84   FILLER - Employee home phone if none Mobile'
                   ;
       apps.fnd_file.put_line(apps.fnd_file.output,v_rec);

    END;

    PROCEDURE print_trailer_column_name IS
    BEGIN

    v_rec :=       'Field 1    RECORD TYPE'
           ||'|'|| 'Field 2    BLANK'
           ||'|'|| 'Field 3    TOTAL RECORD COUNT'
           ||'|'|| 'Field 4    ML PLAN NUMBER '
           ||'|'|| 'Field 5    BLANK'
           ||'|'|| 'Field 6    SOURCE 1 LABEL- A for Employee Deferrals + Catchup'
           ||'|'|| 'Field 7    #1 SOURCE CONTRIB DOLLAR TOTALS - Pre Tax 401K'
           ||'|'|| 'Field 8    BLANK'
           ||'|'|| 'Field 9    SOURCE 2 LABEL- Z Z for Catchup'
           ||'|'|| 'Field 10   SOURCE 2  SOURCE CONTRIB DOLLAR TOTALS - Pre Tax 401K Catchup'
           ||'|'|| 'Field 11   BLANK'
--           ||'|'|| 'Field 12   SOURCE 3 LABEL- X for ER Match'
--           ||'|'|| 'Field 13   SOURCE 3  SOURCE CONTRIB DOLLAR TOTALS -  Pre Tax 401K ER'
           ||'|'|| 'Field 12   SOURCE 3 LABEL- S for Base 401k Roth (TRP) ' /* 11.0 */
           ||'|'|| 'Field 13   SOURCE 3  SOURCE CONTRIB DOLLAR TOTALS -  Base 401k Roth(TRP)' /* 11.0 */
           ||'|'|| 'Field 14   BLANK'
--           ||'|'|| 'Field 15   SOURCE 4 CONTRIB DOLLAR TOTALS - Send Blank'
--           ||'|'|| 'Field 16   SOURCE 4 AMOUNT - Send 0'
           ||'|'|| 'Field 15   SOURCE 4 CONTRIB DOLLAR TOTALS - # for Base 401K Catch Up Roth (TRP)'/* 11.0 */
           ||'|'|| 'Field 16   SOURCE 4 AMOUNT - Base 401K Catch Up Roth (TRP)' /* 11.0 */
           ||'|'|| 'Field 17   BLANK'
           ||'|'|| 'Field 18   SOURCE 5 CONTRIB DOLLAR TOTALS - Send Blank'
           ||'|'|| 'Field 19   SOURCE 5 AMOUNT - Send 0'
           ||'|'|| 'Field 20   TOTAL CONTRIBUTIONS - ALL sources'
           ||'|'|| 'Field 21   TOTAL LOAN REPAYMENTS -  ALL loans'
           ||'|'|| 'Field 22   FILLER - Send Blanks'
           ||'|'|| 'Field 23   TOTAL PAYROLL DEPOSITS (EAA) - The sum of Fields 20 & 21'
           ||'|'|| 'Field 24   COMPANY NUMBER - Send Blanks'
           ||'|'|| 'Field 25   BLANK'
           ;
       apps.fnd_file.put_line(apps.fnd_file.output,v_rec);

    END;
    /************************************************************************************/
    /*                                  GET_EMP_ADDRESS                                 */
    /************************************************************************************/

    PROCEDURE get_emp_address(p_person_id IN NUMBER,
                             p_effective_start_date DATE, /* V1.2 */
                             p_address_line1 OUT VARCHAR2,
                             p_address_line2 OUT VARCHAR2, p_town_or_city OUT VARCHAR2,
                             p_region_2 OUT VARCHAR2, p_postal_code OUT VARCHAR2,
                             p_country_code OUT VARCHAR2,
                             p_phone  OUT VARCHAR2 /* 9.0.6 */
                             ) IS

    BEGIN


      SELECT --pad.address_line1, pad.address_line2, /* 5.3 */
             --REGEXP_REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(pad.address_line1,CHR(10)),CHR(12)),CHR(13)),CHR(27)),'~'), '#,-[^[:alnum:] ]*', '#,-') address_line1, /* 5.3 */
             --REGEXP_REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(pad.address_line2,CHR(10)),CHR(12)),CHR(13)),CHR(27)),'~'), '#,-[^[:alnum:] ]*', '#,-') address_line2, /* 5.3 */
             TRANSLATE (
                   REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(pad.address_line1,CHR(10)),CHR(12)),CHR(13)),CHR(27)),'~') ,
                   'Ã?Ã?Ã?Ã?Ã?Ã?Ã?Ã?Ã?Ã?Ã?Ã?Ã?Ã?Ã?Ã?Ã?Ã?Ã?Ã?Ã?Ã?Ã?Ã?Ã?Ã?Ã Ã¡Ã¢Ã£Ã¤Ã¥Ã§Ã¨Ã©ÃªÃ«Ã¬Ã­Ã®Ã¯Ã±Ã²Ã³Ã´ÃµÃ¶Ã¸Ã¹ÃºÃ»Ã¼Ã½Ã¿ÂºÂª"Â°',
                   'AAAAAACEEEEIIIINOOOOOUUUUYaaaaaaceeeeiiiinoooooouuuuyy    ')  address_line1, /* 5.3 */
              --ttec_library.remove_non_ascii(pad.address_line1)       address_line1,
             TRANSLATE (
                   REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(pad.address_line2,CHR(10)),CHR(12)),CHR(13)),CHR(27)),'~') ,
                   'Ã?Ã?Ã?Ã?Ã?Ã?Ã?Ã?Ã?Ã?Ã?Ã?Ã?Ã?Ã?Ã?Ã?Ã?Ã?Ã?Ã?Ã?Ã?Ã?Ã?Ã?Ã Ã¡Ã¢Ã£Ã¤Ã¥Ã§Ã¨Ã©ÃªÃ«Ã¬Ã­Ã®Ã¯Ã±Ã²Ã³Ã´ÃµÃ¶Ã¸Ã¹ÃºÃ»Ã¼Ã½Ã¿ÂºÂª"Â°',
                   'AAAAAACEEEEIIIINOOOOOUUUUYaaaaaaceeeeiiiinoooooouuuuyy    ')  address_line2, /* 5.3 */
             TRANSLATE (
                   REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(pad.town_or_city,CHR(10)),CHR(12)),CHR(13)),CHR(27)),'~') ,
                   'Ã?Ã?Ã?Ã?Ã?Ã?Ã?Ã?Ã?Ã?Ã?Ã?Ã?Ã?Ã?Ã?Ã?Ã?Ã?Ã?Ã?Ã?Ã?Ã?Ã?Ã?Ã Ã¡Ã¢Ã£Ã¤Ã¥Ã§Ã¨Ã©ÃªÃ«Ã¬Ã­Ã®Ã¯Ã±Ã²Ã³Ã´ÃµÃ¶Ã¸Ã¹ÃºÃ»Ã¼Ã½Ã¿ÂºÂª"Â°',
                   'AAAAAACEEEEIIIINOOOOOUUUUYaaaaaaceeeeiiiinoooooouuuuyy    ') town_or_city,
             TRANSLATE (
                   REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(pad.region_2,CHR(10)),CHR(12)),CHR(13)),CHR(27)),'~') ,
                   'Ã?Ã?Ã?Ã?Ã?Ã?Ã?Ã?Ã?Ã?Ã?Ã?Ã?Ã?Ã?Ã?Ã?Ã?Ã?Ã?Ã?Ã?Ã?Ã?Ã?Ã?Ã Ã¡Ã¢Ã£Ã¤Ã¥Ã§Ã¨Ã©ÃªÃ«Ã¬Ã­Ã®Ã¯Ã±Ã²Ã³Ã´ÃµÃ¶Ã¸Ã¹ÃºÃ»Ã¼Ã½Ã¿ÂºÂª"Â°',
                   'AAAAAACEEEEIIIINOOOOOUUUUYaaaaaaceeeeiiiinoooooouuuuyy    ') region_2,
             REPLACE(pad.postal_code,'-','') ,
             pad.country   -- V 1.5
        INTO p_address_line1, p_address_line2, p_town_or_city,
             p_region_2,  p_postal_code,  p_country_code
        --FROM hr.per_addresses pad --code commented by RXNETHI-ARGANO,15/05/23
		FROM apps.per_addresses pad --code added by RXNETHI-ARGANO,15/05/23
        WHERE pad.person_id = p_person_id
        AND pad.primary_flag = 'Y'
        AND p_effective_start_date BETWEEN pad.date_from AND NVL(pad.date_to,'31-DEC-4712');

      /* 7.4 Begin */
      p_address_line1:= TRIM(REGEXP_REPLACE(ttec_library.remove_non_ascii(p_address_line1),'[^' || CHR(1) || '-' || CHR(127) || ']',''));
      p_address_line2:= TRIM(REGEXP_REPLACE(ttec_library.remove_non_ascii(p_address_line2),'[^' || CHR(1) || '-' || CHR(127) || ']',''));
      p_town_or_city:= TRIM(REGEXP_REPLACE(ttec_library.remove_non_ascii(p_town_or_city),'[^' || CHR(1) || '-' || CHR(127) || ']',''));
      p_region_2:= TRIM(REGEXP_REPLACE(ttec_library.remove_non_ascii(p_region_2),'[^' || CHR(1) || '-' || CHR(127) || ']',''));
      p_postal_code:= TRIM(REGEXP_REPLACE(ttec_library.remove_non_ascii(p_postal_code),'[^' || CHR(1) || '-' || CHR(127) || ']',''));
      p_country_code:= TRIM(REGEXP_REPLACE(ttec_library.remove_non_ascii(p_country_code),'[^' || CHR(1) || '-' || CHR(127) || ']',''));
      /* 7.4 End  */

      /* 9.0.6  Begin */
      BEGIN

          p_phone := NULL;

          SELECT DECODE(INSTR(DECODE(INSTR(TRIM(TRANSLATE(UPPER(pp.phone_number),
                                                          '+,/,(,),.,=,-,_,#,NA,SAME,NONE,YES,SKYPE,*,\,`,'' ',
                                                          ' ')),
                                           0),
                                     1,
                                     '',
                                     TRIM(TRANSLATE(UPPER(pp.phone_number),
                                                    '+,/,(,),.,=,-,_,#,NA,SAME,NONE,YES,SKYPE,*,\,`,'' ',
                                                    ' '))),
                              1),
                        1,
                        SUBSTRB(TRIM(TRANSLATE(UPPER(pp.phone_number),
                                               '+,/,(,),.,=,-,_,#,NA,SAME,NONE,YES,SKYPE,*,\,`,'' ',
                                               ' ')),
                                2,
                                10),
                        '',
                        '',
                        TRIM(TRANSLATE(UPPER(pp.phone_number),
                                       '+,/,(,),.,=,-,_,#,NA,SAME,NONE,YES,SKYPE,*,\,`,'' ',
                                       ' '))) phone_num
                 --pp.phone_type
            INTO p_phone
            --FROM hr.per_phones  pp --code commented by RXNETHI-ARGANO,15/05/23
			FROM apps.per_phones  pp --code added by RXNETHI-ARGANO,15/05/23
            WHERE pp.phone_type(+) = 'H1'
            AND pp.parent_id = p_person_id
            AND p_effective_start_date BETWEEN pp.date_from(+) AND NVL(pp.date_to(+),p_effective_start_date )
            AND ROWNUM < 2;

        EXCEPTION

         WHEN NO_DATA_FOUND THEN /* get Mobile */

              BEGIN
                      SELECT DECODE(INSTR(DECODE(INSTR(TRIM(TRANSLATE(UPPER(pp.phone_number),
                                                                      '+,/,(,),.,=,-,_,#,NA,SAME,NONE,YES,SKYPE,*,\,`,'' ',
                                                                      ' ')),
                                                       0),
                                                 1,
                                                 '',
                                                 TRIM(TRANSLATE(UPPER(pp.phone_number),
                                                                '+,/,(,),.,=,-,_,#,NA,SAME,NONE,YES,SKYPE,*,\,`,'' ',
                                                                ' '))),
                                          1),
                                    1,
                                    SUBSTRB(TRIM(TRANSLATE(UPPER(pp.phone_number),
                                                           '+,/,(,),.,=,-,_,#,NA,SAME,NONE,YES,SKYPE,*,\,`,'' ',
                                                           ' ')),
                                            2,
                                            10),
                                    '',
                                    '',
                                    TRIM(TRANSLATE(UPPER(pp.phone_number),
                                                   '+,/,(,),.,=,-,_,#,NA,SAME,NONE,YES,SKYPE,*,\,`,'' ',
                                                   ' '))) phone_num
                             --pp.phone_type
                        INTO p_phone
                        --FROM hr.per_phones  pp --code commented by RXNETHI-ARGANO,15/05/23
						FROM apps.per_phones  pp --code added by RXNETHI-ARGANO,15/05/23
                        WHERE pp.phone_type(+) = 'M'
                        AND pp.parent_id = p_person_id
                        AND p_effective_start_date BETWEEN pp.date_from(+) AND NVL(pp.date_to(+),p_effective_start_date )
                        AND ROWNUM < 2;

              EXCEPTION WHEN OTHERS
                   THEN NULL;
              END;

     WHEN TOO_MANY_ROWS THEN
     apps.Fnd_File.put_line (apps.Fnd_File.log,' Too Many Phones Found in Get Emp PhoneFor Employee Person ID: ' ||to_char(p_person_id)  );
        NULL;

     WHEN OTHERS THEN
     apps.Fnd_File.put_line (apps.Fnd_File.log,' Error in Get Emp Phone For Employee Person ID: ' ||to_char(p_person_id)  );
        RAISE;


      END;
      /* 9.0.6 End */
    EXCEPTION

             WHEN NO_DATA_FOUND THEN
             --apps.Fnd_File.put_line (apps.Fnd_File.log,' No Address Found in Get Emp Address For Employee Person ID: ' ||to_char(p_person_id)  );
                NULL;

             WHEN TOO_MANY_ROWS THEN
             apps.Fnd_File.put_line (apps.Fnd_File.log,' Too Many Addresses Found in Get Emp Address For Employee Person ID: ' ||to_char(p_person_id)  );
                NULL;

             WHEN OTHERS THEN
             apps.Fnd_File.put_line (apps.Fnd_File.log,' Error in Get Emp Address For Employee Person ID: ' ||to_char(p_person_id)  );
                RAISE;

    END;

    /************************************************************************************/
    /*                                  GET_EMP_SALARY                                  */
    /************************************************************************************/
    /* V1.4  Begin */
    PROCEDURE get_emp_salary(p_person_id IN NUMBER,
                             p_assignment_id IN NUMBER,
                             p_pay_basis_id IN NUMBER,
                             p_effective_date DATE, /* V1.2 */
                             p_actual_termination_date DATE,
                             p_salary OUT NUMBER) IS

    BEGIN


--      apps.Fnd_File.put_line (apps.Fnd_File.log,'p_assignment_id ->'||p_assignment_id);
--      apps.Fnd_File.put_line (apps.Fnd_File.log,'p_effective_date ->'||p_effective_date);
--      apps.Fnd_File.put_line (apps.Fnd_File.log,'p_pay_basis_id ->'||p_pay_basis_id);
--      apps.Fnd_File.put_line (apps.Fnd_File.log,'p_actual_termination_date ->'||p_actual_termination_date);

     IF p_actual_termination_date IS NOT NULL THEN

        SELECT NVL(ROUND (DECODE(ppb.pay_basis, 'ANNUAL',
                                 ppp.proposed_salary_n, 'HOURLY',
                                 ppp.proposed_salary_n * 2080, 0), 2),0) salary
        INTO p_salary
        --FROM   hr.per_pay_proposals ppp --code commented by RXNETHI-ARGANO,15/05/23
		FROM   apps.per_pay_proposals ppp --code added by RXNETHI-ARGANO,15/05/23
            ,  per_pay_bases ppb
            ,  per_all_assignments_f paaf
        WHERE paaf.person_id = p_person_id
        and ppp.assignment_id = paaf.assignment_id  -- Joshua 925915 --p_assignment_id
        and paaf.ASSIGNMENT_ID = p_assignment_id -- /* 7.0 added by C.C due to Salary return more than one row and is putting the wrong Salary*/
        and g_check_date between paaf.effective_start_date and paaf.effective_end_date
        AND ppb.pay_basis_id    = p_pay_basis_id
        AND ppp.change_date     = (SELECT MAX(ppp1.change_date)
                                   --FROM hr.per_pay_proposals ppp1 --code commented by RXNETHI-ARGANO,15/05/23
								   FROM apps.per_pay_proposals ppp1 --code added by RXNETHI-ARGANO,15/05/23
                                   WHERE ppp1.assignment_id = ppp.assignment_id
                                   AND   g_check_date   >=  ppp1.change_date
                                   );
      ELSE



        SELECT NVL(ROUND (DECODE(ppb.pay_basis, 'ANNUAL',
                                 ppp.proposed_salary_n, 'HOURLY',
                                 ppp.proposed_salary_n * 2080, 0), 2),0) salary
        INTO p_salary
        --FROM   hr.per_pay_proposals ppp --code commented by RXNETHI-ARGANO,15/05/23
		FROM   apps.per_pay_proposals ppp --code added by RXNETHI-ARGANO,15/05/23
            ,  per_pay_bases ppb
        WHERE ppp.assignment_id = p_assignment_id
        AND ppb.pay_basis_id    = p_pay_basis_id
        AND ppp.change_date     = (SELECT MAX(ppp1.change_date)
                                   --FROM hr.per_pay_proposals ppp1 --code commented by RXNETHI-ARGANO,15/05/23
								   FROM apps.per_pay_proposals ppp1 --code added by RXNETHI-ARGANO,15/05/23
                                   WHERE ppp1.assignment_id = ppp.assignment_id
                                   AND   p_effective_date  >=  ppp1.change_date);
      END IF;

    EXCEPTION

             WHEN NO_DATA_FOUND THEN
             --apps.Fnd_File.put_line (apps.Fnd_File.log,' No Salary Found in Get Emp Salary For Employee Assignment ID: ' ||to_char(p_assignment_id)  );
                NULL;

             WHEN TOO_MANY_ROWS THEN
              apps.Fnd_File.put_line (apps.Fnd_File.log,' Too Many Salary Found in Get Emp Address For Employee Person ID: ' ||to_char(p_person_id)  );
              apps.Fnd_File.put_line (apps.Fnd_File.log,'p_assignment_id ->'||p_assignment_id);
              apps.Fnd_File.put_line (apps.Fnd_File.log,'p_effective_date ->'||p_effective_date);
              apps.Fnd_File.put_line (apps.Fnd_File.log,'p_pay_basis_id ->'||p_pay_basis_id);
              apps.Fnd_File.put_line (apps.Fnd_File.log,'p_actual_termination_date ->'||p_actual_termination_date);
                NULL;

             WHEN OTHERS THEN
             apps.Fnd_File.put_line (apps.Fnd_File.log,' Error in Get Emp Salary For Employee Person ID: ' ||to_char(p_person_id)  );
                RAISE;

    END;
    /* V1.4  End */
    /* 1.1 Begin */
    /************************************************************************************/
    /*                    get_balance_new                                                   */
    /************************************************************************************/
    FUNCTION get_balance_new (
       p_assignment_id     in    NUMBER
     , p_balance_name        IN   VARCHAR2
     , p_dimension_name      IN   VARCHAR2
     ,p_effective_date   IN Date
     , p_business_group_id   IN   NUMBER
    )
    RETURN VARCHAR2
    IS
       l_tax_unit_id            NUMBER;
       l_defined_balance_id     NUMBER;
       l_balance_type_id        NUMBER;
       l_balance_dimension_id   NUMBER;
       l_value                  VARCHAR2 (100);
       l_legislation_code       VARCHAR2 (10)  := 'US';
       vtable                   VARCHAR2 (60);

       -- this cursor selects check dates between check date and last check date, using 13 because payrolls are bi weekly (14 days)
       CURSOR csr_assignment_actions (p_assignment_id IN NUMBER, p_check_date IN DATE)
        IS
                select ppa.effective_date, paa.assignment_action_id
                from apps.pay_payroll_actions ppa,
                apps.pay_assignment_actions paa
                where ppa.PAYROLL_ACTION_ID = paa.PAYROLL_ACTION_ID
                and   paa.ASSIGNMENT_ID = p_assignment_id
                and ppa.ACTION_TYPE in('R','Q','V')
                --and ppa.effective_date between p_check_date-13 and p_check_date /* 6.3 */
                and ppa.effective_date between NVL(g_adjusted_start_date,p_check_date-13) and p_check_date --NVL(g_check_end_date,p_check_date) /* 6.3 */
                and paa.run_type_id is not null;


    BEGIN
       l_value := '0';
       ----  GET THE BALANCE TYPE ID -----------
       vtable := 'PAY_BALANCE_TYPES';

       SELECT balance_type_id
         INTO l_balance_type_id
         --FROM hr.pay_balance_types --code commented by RXNETHI-ARGANO,15/05/23
		 FROM apps.pay_balance_types --code added by RXNETHI-ARGANO,15/05/23
        WHERE  balance_name = p_balance_name
          --AND NVL (business_group_id, p_business_group_id) = p_business_group_id -- BG is null
          --AND legislation_code = l_legislation_code; ** Make sure the line below stayed the way it is
          AND NVL (legislation_code, l_legislation_code) = l_legislation_code;

       --apps.Fnd_File.put_line (apps.Fnd_File.log,'L_BALANCE_TYPE_ID:' || l_balance_type_id);
       -----  GET DIMENSION ID -----------
       vtable := 'PAY_BALANCE_DIMENSIONS';

       SELECT balance_dimension_id
         INTO l_balance_dimension_id
         --FROM hr.pay_balance_dimensions --code commented by RXNETHI-ARGANO,15/05/23
		 FROM apps.pay_balance_dimensions --code added by RXNETHI-ARGANO,15/05/23
        WHERE dimension_name = p_dimension_name
          AND legislation_code = l_legislation_code;

       --apps.Fnd_File.put_line (apps.Fnd_File.log,'L_BALANCE_DIMENSION_ID:' || l_balance_dimension_id);
       ----- GET DEFEINED BALANCE ID ---------------
       vtable := 'PAY_DEFINED_BALANCES';

       SELECT defined_balance_id
         INTO l_defined_balance_id
         --FROM hr.pay_defined_balances --code commented  by RXNETHI-ARGANO,15/05/23
		 FROM apps.pay_defined_balances --code added  by RXNETHI-ARGANO,15/05/23
        WHERE balance_type_id = l_balance_type_id
          AND balance_dimension_id = l_balance_dimension_id;

       --apps.Fnd_File.put_line (apps.Fnd_File.log,'L_DEFINED_BALANCE_ID:' || l_defined_balance_id);
       vtable := 'PAY_BALANCE_PKG';
       --L_TAX_UNIT_ID := 521;
       l_tax_unit_id :=
                pay_us_bal_upload.get_tax_unit (p_assignment_id, p_effective_date);
       --apps.Fnd_File.put_line (apps.Fnd_File.log,'L_TAX_UNIT_ID:' || l_tax_unit_id);
       pay_balance_pkg.set_context ('ASSIGNMENT_ID', p_assignment_id);
       pay_balance_pkg.set_context ('TAX_UNIT_ID', l_tax_unit_id);
      --apps.Fnd_File.put_line (apps.Fnd_File.log,''Before Pay Balance');

      l_value := 0;
      for i in csr_assignment_actions (p_assignment_id, p_effective_date)
      Loop

       apps.Fnd_File.put_line (apps.Fnd_File.log,'i.assignment_action_id >>> '||i.assignment_action_id );
       apps.Fnd_File.put_line (apps.Fnd_File.log,'pay_balance.get_value >>> '||pay_balance_pkg.get_value (l_defined_balance_id
                                   , i.assignment_action_id
                                   )
                               );

       l_value :=l_value +
          pay_balance_pkg.get_value (l_defined_balance_id
                                   , i.assignment_action_id
                                   );

         apps.Fnd_File.put_line (apps.Fnd_File.log,'l_value '||l_value );
       END LOOP;

       RETURN l_value;
    EXCEPTION
      WHEN NO_DATA_FOUND THEN

            --apps.Fnd_File.put_line (apps.Fnd_File.log,' No Data Found in Get Balance For Employee Assignment ID:  ' ||to_char(p_assignment_id) ||' Element Type: '|| p_balance_name );
            l_value := 0;
            RETURN l_value;
      WHEN OTHERS THEN

            apps.Fnd_File.put_line (apps.Fnd_File.log,' Error in Get Balance For Employee Assignment ID:  ' ||to_char(p_assignment_id) ||' Element Type: '|| p_balance_name );
            ttec_error_logging.process_error( g_application_code -- 'BEN'
                                             , g_interface        -- 'BOA Deduction Interface'
                                             , g_package          -- 'TTEC_BOA_BEN_401K_OUTBOUND_INT'
                                             , v_module
                                             , g_failure_status
                                             , SQLCODE
                                             , SQLERRM
                                             , g_label1
                                             , v_loc
                                             , g_label2
                                             , g_emp_no );
            l_value := 0;
            RETURN l_value;
    END get_balance_new;
    /************************************************************************************/
    /*                    get_balance                                                   */
    /************************************************************************************/
    FUNCTION get_balance (
       p_assignment_id            NUMBER
     , p_balance_name        IN   VARCHAR2
     , p_dimension_name      IN   VARCHAR2
     , p_effective_date      IN   DATE
     , p_business_group_id   IN   NUMBER
    )
    RETURN VARCHAR2
    IS
       l_tax_unit_id            NUMBER;
       l_defined_balance_id     NUMBER;
       l_balance_type_id        NUMBER;
       l_balance_dimension_id   NUMBER;
       l_value                  VARCHAR2 (100);
       l_legislation_code       VARCHAR2 (10)  := 'US';
       vtable                   VARCHAR2 (60);
    BEGIN
       l_value := '0';
       ----  GET THE BALANCE TYPE ID -----------
       vtable := 'PAY_BALANCE_TYPES';

       SELECT balance_type_id
         INTO l_balance_type_id
         --FROM hr.pay_balance_types --code commented by RXNETHI-ARGANO,15/05/23
		 FROM apps.pay_balance_types --code added by RXNETHI-ARGANO,15/05/23
        WHERE  balance_name = p_balance_name
          --AND NVL (business_group_id, p_business_group_id) = p_business_group_id -- BG is null
          --AND legislation_code = l_legislation_code; ** Make sure the line below stayed the way it is
          AND NVL (legislation_code, l_legislation_code) = l_legislation_code;

       --apps.Fnd_File.put_line (apps.Fnd_File.log,'L_BALANCE_TYPE_ID:' || l_balance_type_id);
       -----  GET DIMENSION ID -----------
       vtable := 'PAY_BALANCE_DIMENSIONS';

       SELECT balance_dimension_id
         INTO l_balance_dimension_id
         --FROM hr.pay_balance_dimensions --code commented by RXNETHI-ARGANO,15/05/23
		 FROM apps.pay_balance_dimensions --code added by RXNETHI-ARGANO,15/05/23
        WHERE dimension_name = p_dimension_name
          AND legislation_code = l_legislation_code;

       --apps.Fnd_File.put_line (apps.Fnd_File.log,'L_BALANCE_DIMENSION_ID:' || l_balance_dimension_id);
       ----- GET DEFEINED BALANCE ID ---------------
       vtable := 'PAY_DEFINED_BALANCES';

       SELECT defined_balance_id
         INTO l_defined_balance_id
         --FROM hr.pay_defined_balances --code commented by RXNETHI-ARGANO,15/05/23
		 FROM apps.pay_defined_balances --code added by RXNETHI-ARGANO,15/05/23
        WHERE balance_type_id = l_balance_type_id
          AND balance_dimension_id = l_balance_dimension_id;

       --apps.Fnd_File.put_line (apps.Fnd_File.log,'L_DEFINED_BALANCE_ID:' || l_defined_balance_id);
       vtable := 'PAY_BALANCE_PKG';
       --L_TAX_UNIT_ID := 521;
       l_tax_unit_id :=
                pay_us_bal_upload.get_tax_unit (p_assignment_id, p_effective_date);
       --apps.Fnd_File.put_line (apps.Fnd_File.log,'L_TAX_UNIT_ID:' || l_tax_unit_id);
       pay_balance_pkg.set_context ('ASSIGNMENT_ID', p_assignment_id);
       pay_balance_pkg.set_context ('TAX_UNIT_ID', l_tax_unit_id);
      --apps.Fnd_File.put_line (apps.Fnd_File.log,''Before Pay Balance');
       l_value :=
          pay_balance_pkg.get_value (l_defined_balance_id
                                   , p_assignment_id
                                   , p_effective_date
                                    );
       RETURN l_value;
    EXCEPTION
      WHEN NO_DATA_FOUND THEN

            --apps.Fnd_File.put_line (apps.Fnd_File.log,' No Data Found in Get Balance For Employee Assignment ID:  ' ||to_char(p_assignment_id) ||' Element Type: '|| p_balance_name );
            l_value := 0;
            RETURN l_value;
      WHEN OTHERS THEN

            apps.Fnd_File.put_line (apps.Fnd_File.log,' Error in Get Balance For Employee Assignment ID:  ' ||to_char(p_assignment_id) ||' Element Type: '|| p_balance_name );
            ttec_error_logging.process_error( g_application_code -- 'BEN'
                                             , g_interface        -- 'BOA Deduction Interface'
                                             , g_package          -- 'TTEC_BOA_BEN_401K_OUTBOUND_INT'
                                             , v_module
                                             , g_failure_status
                                             , SQLCODE
                                             , SQLERRM
                                             , g_label1
                                             , v_loc
                                             , g_label2
                                             , g_emp_no );
            l_value := 0;
            RETURN l_value;
    END get_balance;

    /* 1.1 Begin */
    /************************************************************************************/
    /*                    get_balance_2018                                                 */
    /************************************************************************************/
    FUNCTION get_balance_2018 ( p_assignment_id    IN NUMBER
                              , p_balance_id       IN NUMBER
                              , p_effective_date   IN DATE
                              , p_ytd_flag         IN VARCHAR2 DEFAULT 'N'
    )
    RETURN NUMBER
    IS
       l_value                  NUMBER (15,2):=0;
       l_defined_balance_id     NUMBER:=NULL;
       l_balance_name           VARCHAR2(100):='';

    BEGIN

        SELECT pdb.defined_balance_id
          INTO l_defined_balance_id
          --FROM hr.pay_defined_balances pdb --code commented by RXNETHI-ARGANO,15/05/23
		  FROM apps.pay_defined_balances pdb --code added by RXNETHI-ARGANO,15/05/23
         WHERE 1 = 1                                     --pdb.LEGISLATION_CODE = 'US'
           AND pdb.balance_dimension_id = g_bal_dimension_id
           AND pdb.balance_type_id = p_balance_id;

        /* Bebug Only */
        SELECT  pbt.balance_name
          INTO l_balance_name
          --FROM hr.pay_balance_types pbt --code commented by RXNETHI-ARGANO,15/05/23
		  FROM apps.pay_balance_types pbt --code added by RXNETHI-ARGANO,15/05/23
         WHERE pbt.balance_type_id = p_balance_id
           AND pbt.business_group_id = 325;


--        apps.Fnd_File.put_line (apps.Fnd_File.log,'  Get Balance For Employee Assignment ID:  ' ||to_char(p_assignment_id) ||' Defined Balance: '|| l_defined_balance_id
--                                                      ||' Effective Date: '|| p_effective_date);
         IF p_ytd_flag = 'Y' /* 7.3 */
         THEN
             SELECT SUM(NVL(prb.balance_value,0))
               INTO l_value
              --FROM hr.pay_run_balances prb --code commented by RXNETHI-ARGANO,15/05/23
			  FROM apps.pay_run_balances prb --code added by RXNETHI-ARGANO,15/05/23
             WHERE --prb.effective_date between p_effective_date - 13 and p_effective_date /* 7.3 */
                   prb.effective_date between TO_DATE('01-JAN-'||to_char(p_effective_date ,'YYYY')) and p_effective_date
               AND prb.defined_balance_id = l_defined_balance_id
               AND prb.assignment_id = p_assignment_id;
         ELSE /* 7.3 */
             SELECT SUM(NVL(prb.balance_value,0))
               INTO l_value
              --FROM hr.pay_run_balances prb --code commented by RXNETHI-ARGANO,15/05/23
			  FROM apps.pay_run_balances prb --code added by RXNETHI-ARGANO,15/05/23
             WHERE prb.effective_date between p_effective_date - 13 and p_effective_date /* 7.3 */
                   --prb.effective_date between TO_DATE('01-JAN-'||to_char(p_effective_date ,'YYYY')) and p_effective_date
               AND prb.defined_balance_id = l_defined_balance_id
               AND prb.assignment_id = p_assignment_id;
         END IF;  /* 7.3 */

        apps.Fnd_File.put_line (apps.Fnd_File.log,'Balance Name: '|| RPAD(l_balance_name,40,' ')||' Value ->['|| l_value||']');

        RETURN l_value;

    EXCEPTION
      WHEN NO_DATA_FOUND THEN

            apps.Fnd_File.put_line (apps.Fnd_File.log,' No Data Found in Get Balance For Employee Assignment ID:  ' ||to_char(p_assignment_id) ||' Element Type: '|| p_balance_id||' Defined Balance: '|| l_defined_balance_id ||' Effective Date: '|| p_effective_date);

            l_value := 0;
            RETURN l_value;
      WHEN OTHERS THEN

            apps.Fnd_File.put_line (apps.Fnd_File.log,' Error in Get Balance For Employee Assignment ID:  ' ||to_char(p_assignment_id) ||' Element Type: '|| p_balance_id );
            ttec_error_logging.process_error( g_application_code -- 'BEN'
                                             , g_interface        -- 'BOA Deduction Interface'
                                             , g_package          -- 'TTEC_BOA_BEN_401K_OUTBOUND_INT'
                                             , v_module
                                             , g_failure_status
                                             , SQLCODE
                                             , SQLERRM
                                             , g_label1
                                             , v_loc
                                             , g_label2
                                             , g_emp_no );
            l_value := 0;
            RETURN l_value;
    END get_balance_2018;

FUNCTION get_balance_2015 (
   p_person_id           in    NUMBER
 , p_balance_name        IN   VARCHAR2
 , p_dimension_name      IN   VARCHAR2
 , p_effective_date      IN   Date
 , p_business_group_id   IN   NUMBER
)
RETURN VARCHAR2
    IS
       l_tax_unit_id            NUMBER;
       l_defined_balance_id     NUMBER;
       l_balance_type_id        NUMBER;
       l_balance_dimension_id   NUMBER;
       l_value                  VARCHAR2 (100);
       l_legislation_code       VARCHAR2 (10)  := 'US';
       vtable                   VARCHAR2 (60);

    BEGIN
       l_value := '0';
       ----  GET THE BALANCE TYPE ID -----------
       vtable := 'PAY_BALANCE_TYPES';

       SELECT balance_type_id
         INTO l_balance_type_id
         --FROM hr.pay_balance_types --code commented by RXNETHI-ARGANO,15/05/23
		 FROM apps.pay_balance_types --code added by RXNETHI-ARGANO,15/05/23
        WHERE  balance_name = p_balance_name
          --AND NVL (business_group_id, p_business_group_id) = p_business_group_id -- BG is null
          --AND legislation_code = l_legislation_code; ** Make sure the line below stayed the way it is
          AND NVL (legislation_code, l_legislation_code) = l_legislation_code;

       --apps.Fnd_File.put_line (apps.Fnd_File.log,'L_BALANCE_TYPE_ID:' || l_balance_type_id);
       -----  GET DIMENSION ID -----------
       vtable := 'PAY_BALANCE_DIMENSIONS';

       SELECT balance_dimension_id
         INTO l_balance_dimension_id
         --FROM hr.pay_balance_dimensions --code commented by RXNETHI-ARGANO,15/05/23
		 FROM apps.pay_balance_dimensions --code added by RXNETHI-ARGANO,15/05/23
        WHERE dimension_name = p_dimension_name
          AND legislation_code = l_legislation_code;

       --apps.Fnd_File.put_line (apps.Fnd_File.log,'L_BALANCE_DIMENSION_ID:' || l_balance_dimension_id);

  SELECT  SUM( i.balance_value )
   INTO   l_value
   FROM    pay_run_balances            i,
           pay_defined_balances        j,
           pay_balance_types           r
    WHERE  i.assignment_id in (select a.assignment_id
                                FROM   per_all_assignments_f  a
                                where a.person_id = p_person_id
                                )
    AND    i.defined_balance_id = j.defined_balance_id
    AND    j.balance_dimension_id = l_balance_dimension_id
    AND    j.balance_type_id = r.balance_type_id
    AND    r.balance_type_id = l_balance_type_id
    AND    i.effective_date BETWEEN TO_DATE('01-JAN-'||to_char(p_effective_date ,'YYYY')) AND p_effective_date;

       RETURN l_value;
    EXCEPTION
      WHEN NO_DATA_FOUND THEN

            --apps.Fnd_File.put_line (apps.Fnd_File.log,' No Data Found in Get Balance For Employee Assignment ID:  ' ||to_char(p_assignment_id) ||' Element Type: '|| p_balance_name );
            l_value := 0;
            RETURN l_value;
      WHEN OTHERS THEN

            apps.Fnd_File.put_line (apps.Fnd_File.log,' Error in Get Balance For Employee Person ID:  ' ||to_char(p_person_id) ||' Element Type: '|| p_balance_name );
            ttec_error_logging.process_error( g_application_code -- 'BEN'
                                             , g_interface        -- 'BOA Deduction Interface'
                                             , g_package          -- 'TTEC_BOA_BEN_401K_OUTBOUND_INT'
                                             , v_module
                                             , g_failure_status
                                             , SQLCODE
                                             , SQLERRM
                                             , g_label1
                                             , v_loc
                                             , g_label2
                                             , g_emp_no );
            l_value := 0;
            RETURN l_value;
    END get_balance_2015;
/* 2.6 End */
    /************************************************************************************/
    /*                                  GET_ALTERNATE_VEST_DATE                                */
    /************************************************************************************/
/* !.5 Begin */
    FUNCTION get_alternative_vest_date(p_person_id IN NUMBER) RETURN DATE IS

    l_alternative_vest_date DATE:=NULL;

    BEGIN

        SELECT ppa.date_from
        INTO l_alternative_vest_date
        FROM per_person_analyses ppa, per_analysis_criteria pac
        WHERE ppa.analysis_criteria_id = pac.analysis_criteria_id
        AND TRUNC (SYSDATE) BETWEEN NVL (pac.start_date_active, TRUNC (SYSDATE))
                               AND NVL (pac.end_date_active, TRUNC (SYSDATE))
        AND TRUNC (SYSDATE) BETWEEN NVL (ppa.date_from, TRUNC (SYSDATE))
                               AND NVL (ppa.date_to, TRUNC (SYSDATE))
        AND ppa.id_flex_num = g_flex_num
        AND ppa.person_id = p_person_id;

        RETURN l_alternative_vest_date;

    EXCEPTION

             WHEN NO_DATA_FOUND THEN
             --apps.Fnd_File.put_line (apps.Fnd_File.log,' No Alternative Vest Date Found in GET_ALTERNATE_VEST_DATE For Employee Person ID: ' ||to_char(p_person_id)  );
                RETURN NULL;

             WHEN TOO_MANY_ROWS THEN
             apps.Fnd_File.put_line (apps.Fnd_File.log,' Too Many Alternative Vest Date Found in GET_ALTERNATE_VEST_DATE For Employee Person ID: ' ||to_char(p_person_id)  );
                RETURN NULL;

             WHEN OTHERS THEN
             apps.Fnd_File.put_line (apps.Fnd_File.log,' Error in GET_ALTERNATE_VEST_DATE For Employee Person ID: ' ||to_char(p_person_id)  );
                RAISE;

    END;
/* !.5 END */

/************************************************************************************/
/*                                  GET_MATCH_ENTRY_DATE                            */
/************************************************************************************/
/* 12.0 Begin */
    FUNCTION get_match_eligibility_date(p_person_id IN NUMBER) RETURN DATE IS

    l_match_eligibility_date DATE:=NULL;

    BEGIN

        SELECT ppa.date_from
        INTO l_match_eligibility_date
        FROM per_person_analyses ppa, per_analysis_criteria pac
        WHERE ppa.analysis_criteria_id = pac.analysis_criteria_id
        AND TRUNC (SYSDATE) BETWEEN NVL (pac.start_date_active, TRUNC (SYSDATE))
                               AND NVL (pac.end_date_active, TRUNC (SYSDATE))
        AND TRUNC (SYSDATE) BETWEEN NVL (ppa.date_from, TRUNC (SYSDATE))
                               AND NVL (ppa.date_to, TRUNC (SYSDATE))
        AND ppa.id_flex_num = g_flex_num2
        AND ppa.person_id = p_person_id;

        RETURN l_match_eligibility_date;

    EXCEPTION

             WHEN NO_DATA_FOUND THEN
             --apps.Fnd_File.put_line (apps.Fnd_File.log,' No Alternative Vest Date Found in GET_MATCH_ENTRY_DATE For Employee Person ID: ' ||to_char(p_person_id)  );
                RETURN NULL;

             WHEN TOO_MANY_ROWS THEN
             apps.Fnd_File.put_line (apps.Fnd_File.log,' Too Many match eligibility Date Found in GET_MATCH_ENTRY_DATE For Employee Person ID: ' ||to_char(p_person_id)  );
                RETURN NULL;

             WHEN OTHERS THEN
             apps.Fnd_File.put_line (apps.Fnd_File.log,' Error in GET_MATCH_ENTRY_DATE For Employee Person ID: ' ||to_char(p_person_id)  );
                RAISE;

    END;
/* 12.0 END */

    /************************************************************************************/
    /*                                  format_amount                                   */
    /************************************************************************************/
    FUNCTION format_amount(p_amount IN NUMBER,
                           p_length IN NUMBER)
    RETURN VARCHAR2
    IS
      l_amount             VARCHAR2 (100);
      l_amount_s           VARCHAR2 (100); /* 5.2 */

    BEGIN

      --apps.Fnd_File.put_line (apps.Fnd_File.log,'p_amount->'||p_amount);
      /* 5.2  Begin */
      SELECT to_char(p_amount,'999999999.99')
        INTO l_amount_s
        FROM DUAL;

     --apps.Fnd_File.put_line (apps.Fnd_File.log,'p_amount_s->'||l_amount_s);
     l_amount_s := TRIM(l_amount_s);

       --apps.Fnd_File.put_line (apps.Fnd_File.log,'TRIM(p_amount_s)->'||l_amount_s);

--      SELECT  TRIM(DECODE(sign(NVL(p_amount,0)),-1, SUBSTR (LPAD(translate(substr(to_char(NVL(p_amount,0)),1,length(NVL(p_amount,0)) - 1)
--              || translate(substr(to_char(NVL(p_amount,0)),length(NVL(p_amount,0)),1),'1234567890','JKLMNOPQR}'),'-.','0'),p_length,'0'),1,p_length)
--                                                                    ,  REPLACE(TO_CHAR(NVL(p_amount,0),LPAD('.99',p_length +1,'0')
--                                                                      ),'.','')))
           /* 5.2  End */

      SELECT  TRIM(DECODE(sign(NVL(p_amount,0)),-1, SUBSTR (LPAD(translate(substr(NVL(l_amount_s,0),1,length(NVL(l_amount_s,0)) - 1)
              || translate(substr(NVL(l_amount_s,0),length(NVL(l_amount_s,0)),1),'1234567890','JKLMNOPQR}'),'-.','0'),p_length,'0'),1,p_length)
                                                                    ,  REPLACE(TO_CHAR(NVL(p_amount,0),LPAD('.99',p_length +1,'0')
                                                                      ),'.','')))
        INTO l_amount
        FROM DUAL;

      RETURN l_amount;

    EXCEPTION
      WHEN OTHERS
      THEN
           RETURN(LPAD('0',11,'0'));

    END;
    /* 1.1 End */

    PROCEDURE send_PEO_email(v_email_recipients IN varchar2) IS
      l_email_from                VARCHAR2 (256)
                                     := '@teletech.com';
      l_email_to                  VARCHAR2 (256) := v_email_recipients; --'christiane.chan@teletech.com, heathersuperchi@teletech.com';
      l_email_dir                 VARCHAR2 (256) := NULL;
      l_email_subj                VARCHAR2 (256)
         := 'ALERT ALERT! Notice of 401K Outbound Interface failure. Missing PEO 401K Inbound file!!!!!  ';
      l_email_body1               VARCHAR2 (256)
         := 'Please contact Benefit Team and G/A Partner.';
      l_email_body2               VARCHAR2 (256)
         := ' 401K is aborted, due to missing PEO 401K File.';
      l_email_body3               VARCHAR2 (256)
         := 'Benefit needs to resubmit the Concurrent Program with the value <<Yes>> on parameter <<Ignore PEO missing>> only if we want to process without the file.';
      l_email_body4               VARCHAR2 (256)
         := 'If you have any questions, please contact the Benefit/Oracle ERP Development team.';
      crlf                        CHAR (2) := CHR (10) || CHR (13);
      l_host_name                 VARCHAR2 (256);
      l_instance_name             VARCHAR2 (256);
      w_mesg                      VARCHAR2 (256);
      p_status                    NUMBER;

    BEGIN
                 OPEN c_host;
                 FETCH c_host INTO l_host_name,l_instance_name;
                 CLOSE c_host;

/*       -- commented for ver 3.0
                 IF l_host_name <> 'den-erp046' THEN
                     IF l_host_name = 'den-erp042' THEN
                        l_email_subj := l_host_name|| ' PRE'||l_instance_name||' TESTING!! Please ignore... '||l_email_subj;
                     ELSIF l_host_name = 'den-erp092' and SUBSTR(l_instance_name,1,3) = 'DEV' THEN
                        l_email_subj := l_host_name|| ' IT'||l_instance_name||' TESTING!! Please ignore... '||l_email_subj;
                     ELSE
                        l_email_subj := l_host_name|| ' '||l_instance_name||' TESTING!! Please ignore... '||l_email_subj;
                     END IF;
                 END IF;
*/

                 IF l_host_name <> ttec_library.XX_TTEC_PROD_HOST_NAME THEN

                        l_email_subj := l_host_name|| '  '|| l_instance_name||' TESTING!! Please ignore... '||l_email_subj;
                 END IF;


                  send_email (
                     ttec_library.XX_TTEC_SMTP_SERVER, /*l_host_name,*/
                     l_host_name||l_email_from,
                     l_email_to,
                     NULL,
                     NULL,
                     l_email_subj,
                        crlf
                     || l_email_body1
                     || l_email_body2
                     || crlf
                     || l_email_body3
                     || crlf
                     || l_email_body4, -- NULL, --                        v_line1,
                     NULL,
                     NULL,
                     NULL,
                     NULL,
                     NULL,                             -- v_file_name,
                     NULL,
                     NULL,
                     NULL,
                     NULL,
                     p_status,
                     w_mesg);
    END;
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
          p_401k_roth_bal_name              IN varchar2, /* 11.0 */
          p_401k_catchup_roth_bal_name      IN varchar2,  /* 11.0 */
          p_401k_bonus_roth_bal_name           IN varchar2, /* 11.0 */
          p_payroll_name               IN varchar2,
          p_Ignore_PEO_missing         IN varchar2,
          p_email_recipients           IN varchar2
    ) IS

        -- Declare variables



    v_tot_amount                     number;
    v_emp_salary                     number;    /* V1.4 */
 --   v_ytd_gross_earning_amount       number;
    l_401k_amount                    number;
    l_401K_catchup_amount            number;
    l_401K_loan1_amount              number;

    v_401k_amount                    number;
    v_401k_tot_amount                number;
    v_401K_catchup_amount            number;
    v_401K_ER_amount                 number;
    v_401K_loan1_amount              number;
    v_Pre_Tax_401K_Elig_Comp_Amt     number;
	v_401K_Elig_Comp_PerPayPeriod    number;     --12.1
    v_401K_DiscrTest                 number; /* 7.7 */
    v_401k_roth_amt                  number;   /* 11.0 */
    v_401K_roth_catchup_amt          number;   /* 11.0 */
	v_401K_match_accrual_amount      number:=0;            --12.0

    v_emp_count                      number:=0;
    v_tot_401k_amount                number:=0;
    v_tot_401K_catchup_amount        number:=0;
    v_tot_401K_loan1_amount          number:=0;
    v_PEO_emp_to_process             number:=0; /* 2.0 */
    v_tot_401k_roth_amt                         number:=0; /* 11.0 */
    v_tot_401K_roth_catchup_amt        number:=0; /* 11.0 */
	--v_tot_401K_match_accrual_amount  number:=0;       --12.0




    v_officer_flag                   varchar2(1);
    v_PuertoRico_resident_flag       varchar2(2);

    v_emp_rehire_date                date;

    /*
	START R12.2 Upgrade Remediation
	code commented by RXNETHI-ARGANO,15/05/23
	v_emp_addr_line1        hr.per_addresses.address_line1%TYPE;
    v_emp_addr_line2        hr.per_addresses.address_line2%TYPE;
    v_emp_city              hr.per_addresses.town_or_city%TYPE;
    v_emp_state             hr.per_addresses.region_2%TYPE;
    v_emp_country           hr.per_addresses.country%TYPE;
    v_emp_zip_code          hr.per_addresses.postal_code%TYPE;

    v_emp_phone             hr.per_phones.PHONE_NUMBER%TYPE; /* 9.0.6 */
    
	--code added by RXNETHI-ARGANO,15/05/23
	v_emp_addr_line1        apps.per_addresses.address_line1%TYPE;
    v_emp_addr_line2        apps.per_addresses.address_line2%TYPE;
    v_emp_city              apps.per_addresses.town_or_city%TYPE;
    v_emp_state             apps.per_addresses.region_2%TYPE;
    v_emp_country           apps.per_addresses.country%TYPE;
    v_emp_zip_code          apps.per_addresses.postal_code%TYPE;

    v_emp_phone             apps.per_phones.PHONE_NUMBER%TYPE; /* 9.0.6 */
	--END R12.2 Upgrade Remediation
	l_check_date          date; /* 1.1 */
    v_alternative_vest_date DATE:=NULL;  /* 1.5 */
	v_match_eligibility_date DATE:=NULL;  --12.0

    /* 2.0  Begin */
    FUNCTION get_balance_PEO (
       p_emp_ssn             in   VARCHAR2
     , p_balance_name        IN   VARCHAR2
    )
    RETURN VARCHAR2
    IS
       l_value                  VARCHAR2 (100);
    BEGIN
       l_value := '0';

       IF p_balance_name = p_401k_bal_name THEN

            SELECT f23_source1_401kpretax
              INTO l_value
              --FROM cust.ttec_peo_401k_load --code commented by RXNETHI-ARGANO,15/05/23
			  FROM apps.ttec_peo_401k_load --code added by RXNETHI-ARGANO,15/05/23
             WHERE social_security_number = p_emp_ssn;

       ELSIF p_balance_name = p_401k_catchup_bal_name THEN

            SELECT F25_SOURCE2_401KPRETAX_CATCHUP
              INTO l_value
              --FROM cust.ttec_peo_401k_load --code commented by RXNETHI-ARGANO,15/05/23
			  FROM apps.ttec_peo_401k_load --code added by RXNETHI-ARGANO,15/05/23
             WHERE social_security_number = p_emp_ssn;

       ELSIF p_balance_name = p_401k_loan1_bal_name THEN

            SELECT F36_LOAN_REPAYMENT
              INTO l_value
              --FROM cust.ttec_peo_401k_load --code commented by RXNETHI-ARGANO,15/05/23
			  FROM apps.ttec_peo_401k_load --code added by RXNETHI-ARGANO,15/05/23
             WHERE social_security_number = p_emp_ssn;

       ELSIF p_balance_name = p_pre_tax_elig_comp_bal_name THEN

            SELECT F46_PRE_TAX_401K_ELIG_COMP_BAL
              INTO l_value
              --FROM cust.ttec_peo_401k_load --code commented by RXNETHI-ARGANO,15/05/23
              FROM apps.ttec_peo_401k_load --code added by RXNETHI-ARGANO,15/05/23
			 WHERE social_security_number = p_emp_ssn;

       END IF;

       RETURN l_value;
    EXCEPTION
      WHEN NO_DATA_FOUND THEN

            IF p_balance_name = p_401k_bal_name THEN
               apps.Fnd_File.put_line (apps.Fnd_File.log,' No Data Found in Get Balance For PEO Employee:  ' || g_emp_no|| ' SSN ->' ||p_emp_ssn );
            END IF;

            l_value := 0;
            RETURN l_value;

      WHEN TOO_MANY_ROWS THEN

             IF p_balance_name = p_401k_bal_name THEN
               apps.Fnd_File.put_line (apps.Fnd_File.log,' Too Many Row Found in GET_BALANCE_PEO For Employee Person ID: ' || g_emp_no|| ' SSN ->' ||p_emp_ssn );
             END IF;

            l_value := 0;
            RETURN l_value;

      WHEN OTHERS THEN

            IF p_balance_name = p_401k_bal_name THEN
               apps.Fnd_File.put_line (apps.Fnd_File.log,' Error in Get Balance For PEO Employee:  ' || g_emp_no|| ' SSN ->' ||p_emp_ssn );
            END IF;

            ttec_error_logging.process_error( g_application_code -- 'BEN'
                                             , g_interface        -- 'BOA Deduction Interface'
                                             , g_package          -- 'TTEC_BOA_BEN_401K_OUTBOUND_INT'
                                             , v_module
                                             , g_failure_status
                                             , SQLCODE
                                             , SQLERRM
                                             , g_label1
                                             , v_loc
                                             , g_label2
                                             , g_emp_no );
            l_value := 0;
            RETURN l_value;
    END get_balance_PEO;
/* 2.0  END */
   BEGIN

    BEGIN
        select count(*)
        into v_PEO_emp_to_process
        --FROM cust.ttec_peo_401k_load; --code commented by RXNETHI-ARGANO,15/05/23
		FROM apps.ttec_peo_401k_load; --code added by RXNETHI-ARGANO,15/05/23

        IF v_PEO_emp_to_process = 0 and p_Ignore_PEO_missing = 'N' THEN
--           apps.Fnd_File.put_line (apps.Fnd_File.log,' 1 No PEO Employee to PROCESS......');
--
--           send_PEO_email(p_email_recipients);
           RAISE_APPLICATION_ERROR(-20003,'No PEO Employee to PROCESS......');
        END IF;

    EXCEPTION
    WHEN NO_DATA_FOUND THEN
          IF p_Ignore_PEO_missing = 'N' THEN
           apps.Fnd_File.put_line (apps.Fnd_File.log,'No PEO Employee to PROCESS......');
           send_PEO_email(p_email_recipients);
           RAISE_APPLICATION_ERROR(-20003,'No PEO Employee to PROCESS......');
           END IF;
    WHEN OTHERS THEN
           apps.Fnd_File.put_line (apps.Fnd_File.log,'Please verify ttec_peo_401kload.csv in CUST_TOP/data/EBS/HC/HR/PEO/inbound......');
           send_PEO_email(p_email_recipients);
           RAISE_APPLICATION_ERROR(-20003,'FATAL error on PEO 401K Inbound file!!!');
    END;

    v_module := 'Obtain check Date';
    IF p_check_date = 'DD-MON-RRRR' THEN

    v_loc := 10;

    SELECT regular_payment_date,start_date,end_date,regular_payment_date    -- v1.6
      INTO g_check_date, g_payroll_start_date,g_payroll_end_date,g_date_earned
      FROM per_time_periods ptp, pay_all_payrolls_f papf
     WHERE ptp.payroll_id = papf.payroll_id
       AND trunc(SYSDATE) BETWEEN papf.effective_start_date AND papf.effective_end_date
       AND papf.payroll_name = p_payroll_name
       AND trunc(SYSDATE) - 18 BETWEEN start_date AND end_date; --V 1.1


    ELSE

      g_check_date := to_date(p_check_date);
      v_module := 'ObtainDateEarned';
        v_loc := 20;
        BEGIN
            v_loc := 25;
            SELECT start_date,end_date,regular_payment_date             -- v1.6
              INTO g_payroll_start_date,g_payroll_end_date,g_date_earned
              FROM per_time_periods ptp, pay_all_payrolls_f papf
             WHERE ptp.payroll_id = papf.payroll_id
               AND SYSDATE BETWEEN papf.effective_start_date AND papf.effective_end_date
               AND papf.payroll_name = p_payroll_name
               AND regular_payment_date = p_check_date;
        EXCEPTION WHEN OTHERS
        THEN
            v_loc := 30;
            SELECT start_date,end_date,regular_payment_date             -- v1.6
              INTO g_payroll_start_date,g_payroll_end_date,g_date_earned
              FROM per_time_periods ptp, pay_all_payrolls_f papf
             WHERE ptp.payroll_id = papf.payroll_id
               AND SYSDATE BETWEEN papf.effective_start_date AND papf.effective_end_date
               AND papf.payroll_name = p_payroll_name
               AND to_date(p_check_date) between start_date and end_date;

        END;

        v_loc := 35;
    END IF;

    -- V 1.5
    BEGIN
     v_loc := 36;
        IF TO_CHAR(TO_DATE(g_date_earned),'MON') = 'JAN'
        THEN
            g_date_earn_start := TRUNC(TO_DATE(g_date_earned),'YYYY') - 92;
        ELSE
            g_date_earn_start := TRUNC(TO_DATE(g_date_earned),'YYYY');
        END IF;
    END;
    -- V 1.5

    IF p_adjusted_start_date IS NOT NULL THEN  /* 6.3 */
       v_loc := 35;
       g_adjusted_start_date   := to_date(p_adjusted_start_date);
    ELSE
       g_adjusted_start_date   :='';
    END IF;
    v_loc := 40;
    g_jan_01_date := '01-JAN-'||to_char(g_check_date,'RRRR');



    /* 1.5 Begin */
    v_module := 'ObtainFlexNum';
    BEGIN
        v_loc := 42;

    SELECT id_flex_num
      INTO g_flex_num
      FROM fnd_id_flex_structures_vl
     WHERE id_flex_structure_name = '401K Alternate Vesting Date';

    EXCEPTION WHEN OTHERS
    THEN
        v_loc := 42;
        g_flex_num := NULL;
    END;
    /* 1.5 End */

	/* 12.0 Begin */
    v_module := 'ObtainFlexNum2';
    BEGIN
        v_loc := 43;

    SELECT id_flex_num
      INTO g_flex_num2
      FROM fnd_id_flex_structures_vl
     WHERE id_flex_structure_name = '401K Match Eligibility Date';

    EXCEPTION WHEN OTHERS
    THEN
        v_loc := 43;
        g_flex_num2 := NULL;
    END;
    /* 12.0 End */

    Fnd_File.put_line(Fnd_File.LOG, '');
    Fnd_File.put_line(Fnd_File.LOG,'--------------------------------------------------------------------------------------------------------------------------------------------------');
    Fnd_File.put_line(Fnd_File.LOG, '');
    Fnd_File.put_line(Fnd_File.LOG,'Concurrent Program -> TeleTech BOA Benefit 401K Outbound Interface');
    Fnd_File.put_line(Fnd_File.LOG, '');
    Fnd_File.put_line(Fnd_File.LOG,'Parameters:                  ');
    Fnd_File.put_line(Fnd_File.LOG,'                       Check Date: '||g_check_date);
    Fnd_File.put_line(Fnd_File.LOG,'              Adjusted Start Date: '||g_adjusted_start_date);
    Fnd_File.put_line(Fnd_File.LOG,'                       Date Start: '||g_date_earn_start);
    Fnd_File.put_line(Fnd_File.LOG,'                         Date End: '||g_payroll_end_date);
    Fnd_File.put_line(Fnd_File.LOG,'                   Bal. Dimension: '||p_bal_dimension);
    Fnd_File.put_line(Fnd_File.LOG,'           Pre Tax 401K bal. name: '||p_401k_bal_name);
    Fnd_File.put_line(Fnd_File.LOG,'        Pre Tax 401K FD bal. name: '||p_401k_FD_bal_name);
    Fnd_File.put_line(Fnd_File.LOG,'   Pre Tax 401K Catchup bal. name: '||p_401k_catchup_bal_name);
    Fnd_File.put_line(Fnd_File.LOG,'Pre Tax 401K Catchup FD bal. name: '||p_401k_catchup_FD_bal_name);
    Fnd_File.put_line(Fnd_File.LOG,'     Pre Tax 401K Loan1 bal. name: '||p_401k_loan1_bal_name);
    Fnd_File.put_line(Fnd_File.LOG,'     Pre Tax 401K Bonus bal. name: '||p_401k_bonus );
    Fnd_File.put_line(Fnd_File.LOG,'Base 401K Roth bal. namee: '||p_401k_roth_bal_name ); /* 11.0 */
    Fnd_File.put_line(Fnd_File.LOG,'   Base 401K Catchup Roth bal. name: '||p_401k_catchup_roth_bal_name);    /* 11.0 */
    Fnd_File.put_line(Fnd_File.LOG,'   Base  401K Bonus Roth bal. name: '||p_401k_bonus_roth_bal_name ); /* 11.0 */
    Fnd_File.put_line(Fnd_File.LOG,'Pre Tax 401K Elig. Comp bal. name: '||p_pre_tax_elig_comp_bal_name);
    Fnd_File.put_line(Fnd_File.LOG,'               Ignore PEO missing: '||p_Ignore_PEO_missing);
    --Fnd_File.put_line(Fnd_File.LOG,'                  Payroll Name: '||p_payroll_name);    -- Must be HIDDEN from End User not to confuse that only pick up employee under this payroll
    Fnd_File.put_line(Fnd_File.LOG,'--------------------------------------------------------------------------------------------------------------------------------------------------');

    v_module := 'Get Dimension';
    BEGIN
        v_loc := 45;

        SELECT pbd.balance_dimension_id
          INTO g_bal_dimension_id
          --FROM hr.pay_balance_dimensions pbd --code commented by RXNETHI-ARGANO,15/05/23
		  FROM apps.pay_balance_dimensions pbd --code added by RXNETHI-ARGANO,15/05/23
         WHERE pbd.legislation_code = 'US' AND pbd.dimension_name = p_bal_dimension;

    EXCEPTION WHEN OTHERS
    THEN

      errcode  := SQLCODE;
      errbuff  := SUBSTR (SQLERRM, 1, 255);
      RAISE_APPLICATION_ERROR(-20003,'Exception unable to obtain Balance Dimension ID for  -> '||p_bal_dimension||' '||v_module||' [' ||v_loc||'] ERROR:'||errcode||':'||errbuff);
    END;

    v_module := 'Get 401K';
    BEGIN
        v_loc := 46;

        SELECT pbt.balance_type_id
          INTO g_bal_type_id_401K
          --FROM hr.pay_balance_types pbt --code commented by RXNETHI-ARGANO,15/05/23
		  FROM apps.pay_balance_types pbt --code added by RXNETHI-ARGANO,15/05/23
         WHERE pbt.balance_name = p_401k_bal_name --'Pre Tax 401K'
           AND pbt.business_group_id = 325;

    EXCEPTION WHEN OTHERS
    THEN

      errcode  := SQLCODE;
      errbuff  := SUBSTR (SQLERRM, 1, 255);
      RAISE_APPLICATION_ERROR(-20003,'Exception unable to obtain Balance Type ID for Balance Name -> '||p_401k_bal_name||' ' ||v_module||' [' ||v_loc||'] ERROR:'||errcode||':'||errbuff);
    END;

    v_module := 'Get 401K Bonus';
    BEGIN
        v_loc := 47;

        SELECT pbt.balance_type_id
          INTO g_bal_type_id_401K_Bonus
          --FROM hr.pay_balance_types pbt --code commented by RXNETHI-ARGANO,15/05/23
		  FROM apps.pay_balance_types pbt --code added by RXNETHI-ARGANO,15/05/23
         WHERE pbt.balance_name = p_401k_bonus --'Pre Tax 401K Bonus'
           AND pbt.business_group_id = 325;

    EXCEPTION WHEN OTHERS
    THEN

      errcode  := SQLCODE;
      errbuff  := SUBSTR (SQLERRM, 1, 255);
      RAISE_APPLICATION_ERROR(-20003,'Exception unable to obtain Balance Type ID for Balance Name -> '||p_401k_bonus||' ' ||v_module||' [' ||v_loc||'] ERROR:'||errcode||':'||errbuff);
    END;

    v_module := 'Get 401K FD';
    BEGIN
        v_loc := 48;

        SELECT pbt.balance_type_id
          INTO g_bal_type_id_401K_FD
          --FROM hr.pay_balance_types pbt --code commented by RXNETHI-ARGANO,15/05/23
		  FROM apps.pay_balance_types pbt --code added by RXNETHI-ARGANO,15/05/23
         WHERE pbt.balance_name = p_401k_FD_bal_name --'Pre Tax 401K Flat Dollar'
           AND pbt.business_group_id = 325;

    EXCEPTION WHEN OTHERS
    THEN

      errcode  := SQLCODE;
      errbuff  := SUBSTR (SQLERRM, 1, 255);
      RAISE_APPLICATION_ERROR(-20003,'Exception unable to obtain Balance Type ID for Balance Name -> '||p_401k_FD_bal_name||' ' ||v_module||' [' ||v_loc||'] ERROR:'||errcode||':'||errbuff);
    END;

    v_module := 'Get 401K Catchup';
    BEGIN
        v_loc := 49;

        SELECT pbt.balance_type_id
          INTO g_bal_type_id_401K_Catchup
          --FROM hr.pay_balance_types pbt --code commented by RXNETHI-ARGANO,15/05/23
		  FROM apps.pay_balance_types pbt --code added by RXNETHI-ARGANO,15/05/23
         WHERE pbt.balance_name = p_401k_catchup_bal_name --'Pre Tax 401K Catchup'
           AND pbt.business_group_id = 325;

    EXCEPTION WHEN OTHERS
    THEN

      errcode  := SQLCODE;
      errbuff  := SUBSTR (SQLERRM, 1, 255);
      RAISE_APPLICATION_ERROR(-20003,'Exception unable to obtain Balance Type ID for Balance Name ->'||p_401k_catchup_bal_name||' ' ||v_module||' [' ||v_loc||'] ERROR:'||errcode||':'||errbuff);
    END;

    v_module := 'Get 401K Catchup FD';
    BEGIN
        v_loc := 50;

        SELECT pbt.balance_type_id
          INTO g_bal_type_id_401K_Catchup_FD
          --FROM hr.pay_balance_types pbt --code commented by RXNETHI-ARGANO,15/05/23
		  FROM apps.pay_balance_types pbt --code added by RXNETHI-ARGANO,15/05/23
         WHERE pbt.balance_name = p_401k_catchup_FD_bal_name -- 'Pre Tax 401K Catch Up Flat Dollar'
           AND pbt.business_group_id = 325;

    EXCEPTION WHEN OTHERS
    THEN

      errcode  := SQLCODE;
      errbuff  := SUBSTR (SQLERRM, 1, 255);
      RAISE_APPLICATION_ERROR(-20003,'Exception unable to obtain Balance Type ID for Balance Name -> '||p_401k_catchup_FD_bal_name||' '||v_module||' [' ||v_loc||'] ERROR:'||errcode||':'||errbuff);
    END;

    v_module := 'Get 401K Loan1';

    BEGIN
        v_loc := 51;

        SELECT pbt.balance_type_id
          INTO g_bal_type_id_401K_Loan1
          --FROM hr.pay_balance_types pbt --code commented by RXNETHI-ARGANO,15/05/23
		  FROM apps.pay_balance_types pbt --code added by RXNETHI-ARGANO,15/05/23
         WHERE pbt.balance_name = p_401k_loan1_bal_name  --'Loan 1_401k'
           AND pbt.business_group_id = 325;

    EXCEPTION WHEN OTHERS
    THEN

      errcode  := SQLCODE;
      errbuff  := SUBSTR (SQLERRM, 1, 255);
      RAISE_APPLICATION_ERROR(-20003,'Exception unable to obtain Balance Type ID for Balance Name -> '||p_401k_loan1_bal_name||' ' ||v_module||' [' ||v_loc||'] ERROR:'||errcode||':'||errbuff);
    END;

    v_module := 'Get 401K EligComp';

    BEGIN
        v_loc := 52;

        SELECT pbt.balance_type_id
          INTO g_bal_type_id_401K_Elig_Comp
          --FROM hr.pay_balance_types pbt --code commented by RXNETHI-ARGANO,15/05/23
		  FROM apps.pay_balance_types pbt --code added by RXNETHI-ARGANO,15/05/23
         WHERE pbt.balance_name = p_pre_tax_elig_comp_bal_name --'Pre Tax 401K Eligible Comp'
           AND pbt.business_group_id = 325;

    EXCEPTION WHEN OTHERS
    THEN

      errcode  := SQLCODE;
      errbuff  := SUBSTR (SQLERRM, 1, 255);
      RAISE_APPLICATION_ERROR(-20003,'Exception unable to obtain Balance Type ID for Balance Name -> '||p_pre_tax_elig_comp_bal_name||' ' ||v_module||' [' ||v_loc||'] ERROR:'||errcode||':'||errbuff);
    END;

    v_module := 'Get 401K Bonus EligComp'; /* 7.2 */

    /* 7.2 */
    BEGIN
        v_loc := 53;

        SELECT pbt.balance_type_id
          INTO g_bal_type_id_401K_BonusElComp /* 7.2 */
          --FROM hr.pay_balance_types pbt --code commented by RXNETHI-ARGANO,15/05/23
		  FROM apps.pay_balance_types pbt --code added by RXNETHI-ARGANO,15/05/23
         WHERE pbt.balance_name = p_pre_tax_elig_BEC_bal_name --'Pre Tax 401K Bonus Eligible Comp' /* 7.2 */
           AND pbt.business_group_id = 325;

    EXCEPTION WHEN OTHERS
    THEN

      errcode  := SQLCODE;
      errbuff  := SUBSTR (SQLERRM, 1, 255);
      RAISE_APPLICATION_ERROR(-20003,'Exception unable to obtain Balance Type ID for Balance Name -> '||p_pre_tax_elig_BEC_bal_name||' ' ||v_module||' [' ||v_loc||'] ERROR:'||errcode||':'||errbuff);
    END;

    v_module := 'Get US_401K_Discr_Testing'; /* 7.7 */

    /* 7.7 */
    BEGIN
        v_loc := 54;

        SELECT pbt.balance_type_id
          INTO g_bal_type_id_401K_DiscrTest /* 7.7 */
          --FROM hr.pay_balance_types pbt ---code commented by RXNETHI-ARGANO,15/05/23
		  FROM apps.pay_balance_types pbt ---code added by RXNETHI-ARGANO,15/05/23
         WHERE pbt.balance_name =  'US_401K_Discrimination_Testing' /* 7.7 */
           AND pbt.business_group_id = 325;

    EXCEPTION WHEN OTHERS
    THEN

      errcode  := SQLCODE;
      errbuff  := SUBSTR (SQLERRM, 1, 255);
      RAISE_APPLICATION_ERROR(-20003,'Exception unable to obtain Balance Type ID for Balance Name -> US_401K_Discrimination_Testing ' ||v_module||' [' ||v_loc||'] ERROR:'||errcode||':'||errbuff);
    END;
/* 11.0 Begin */
    v_module := 'Get 401K Roth';
    BEGIN
        v_loc := 55;

        SELECT pbt.balance_type_id
          INTO g_bal_type_id_401K_Roth
          --FROM hr.pay_balance_types pbt --code commented by RXNETHI-ARGANO,15/05/23
		  FROM apps.pay_balance_types pbt --code added by RXNETHI-ARGANO,15/05/23
         WHERE pbt.balance_name = p_401k_roth_bal_name  --'Base 401k Roth'
           AND pbt.business_group_id = 325;

    EXCEPTION WHEN OTHERS
    THEN

      errcode  := SQLCODE;
      errbuff  := SUBSTR (SQLERRM, 1, 255);
      RAISE_APPLICATION_ERROR(-20003,'Exception unable to obtain Balance Type ID for Balance Name -> '||p_401k_roth_bal_name ||' ' ||v_module||' [' ||v_loc||'] ERROR:'||errcode||':'||errbuff);
    END;

    v_module := 'Get 401K Catchup Roth';
    BEGIN
        v_loc := 56;

        SELECT pbt.balance_type_id
          INTO g_bal_type_id_401K_CatchupRoth
          --FROM hr.pay_balance_types pbt --code commented by RXNETHI-ARGANO,15/05/23
		  FROM apps.pay_balance_types pbt --code added by RXNETHI-ARGANO,15/05/23
         WHERE pbt.balance_name = p_401k_catchup_roth_bal_name --'Base 401K Catch Up Roth'
           AND pbt.business_group_id = 325;

    EXCEPTION WHEN OTHERS
    THEN

      errcode  := SQLCODE;
      errbuff  := SUBSTR (SQLERRM, 1, 255);
      RAISE_APPLICATION_ERROR(-20003,'Exception unable to obtain Balance Type ID for Balance Name -> '||p_401k_catchup_roth_bal_name||' ' ||v_module||' [' ||v_loc||'] ERROR:'||errcode||':'||errbuff);
    END;

    v_module := 'Get 401K Bonus Roth';
    BEGIN
        v_loc := 57;

        SELECT pbt.balance_type_id
          INTO g_bal_type_id_401K_Bonus_Roth
          --FROM hr.pay_balance_types pbt --code commented by RXNETHI-ARGANO,15/05/23
		  FROM apps.pay_balance_types pbt --code added by RXNETHI-ARGANO,15/05/23
         WHERE pbt.balance_name = p_401k_bonus_roth_bal_name  --'Base 401k Bonus Roth'
           AND pbt.business_group_id = 325;

    EXCEPTION WHEN OTHERS
    THEN

      errcode  := SQLCODE;
      errbuff  := SUBSTR (SQLERRM, 1, 255);
      RAISE_APPLICATION_ERROR(-20003,'Exception unable to obtain Balance Type ID for Balance Name -> '||p_401k_bonus_roth_bal_name ||' ' ||v_module||' [' ||v_loc||'] ERROR:'||errcode||':'||errbuff);
    END;
/* 11.0 End */

/* Begin 12.0 */
v_module := 'Get Base 401k Roth ER';

    BEGIN
        v_loc := 58;

        SELECT pbt.balance_type_id
          INTO g_bal_type_id_401K_Roth_ER
          --FROM hr.pay_balance_types pbt --code commented by RXNETHI-ARGANO,15/05/23
		  FROM apps.pay_balance_types pbt --code added by RXNETHI-ARGANO,15/05/23
         WHERE pbt.balance_name =  'Base 401k Roth ER'
           AND pbt.business_group_id = 325;

    EXCEPTION WHEN OTHERS
    THEN

      errcode  := SQLCODE;
      errbuff  := SUBSTR (SQLERRM, 1, 255);
      RAISE_APPLICATION_ERROR(-20003,'Exception unable to obtain Balance Type ID for Balance Name -> Base 401k Roth ER ' ||v_module||' [' ||v_loc||'] ERROR:'||errcode||':'||errbuff);
    END;

	v_module := 'Base 401k Bonus Roth ER';
	BEGIN
        v_loc := 581;

        SELECT pbt.balance_type_id
          INTO g_bal_type_id_401K_BonusRothER
          --FROM hr.pay_balance_types pbt --code commented by RXNETHI-ARGANO,15/05/23
		  FROM apps.pay_balance_types pbt --code added by RXNETHI-ARGANO,15/05/23
         WHERE pbt.balance_name =  'Base 401k Bonus Roth ER'
           AND pbt.business_group_id = 325;

    EXCEPTION WHEN OTHERS
    THEN

      errcode  := SQLCODE;
      errbuff  := SUBSTR (SQLERRM, 1, 255);
      RAISE_APPLICATION_ERROR(-20003,'Exception unable to obtain Balance Type ID for Balance Name -> Base 401k Bonus Roth ER ' ||v_module||' [' ||v_loc||'] ERROR:'||errcode||':'||errbuff);
    END;

	v_module := 'Base 401K Catch Up Roth ER';
	BEGIN
        v_loc := 582;

        SELECT pbt.balance_type_id
          INTO g_bal_type_id_401K_CatUpRothER
          --FROM hr.pay_balance_types pbt --code commented by RXNETHI-ARGANO,15/05/23
		  FROM apps.pay_balance_types pbt --code added by RXNETHI-ARGANO,15/05/23
         WHERE pbt.balance_name =  'Base 401K Catch Up Roth ER'
           AND pbt.business_group_id = 325;

    EXCEPTION WHEN OTHERS
    THEN

      errcode  := SQLCODE;
      errbuff  := SUBSTR (SQLERRM, 1, 255);
      RAISE_APPLICATION_ERROR(-20003,'Exception unable to obtain Balance Type ID for Balance Name -> Base 401K Catch Up Roth ER ' ||v_module||' [' ||v_loc||'] ERROR:'||errcode||':'||errbuff);
    END;

	v_module := 'Base 401k Bonus ER';
	BEGIN
        v_loc := 583;

        SELECT pbt.balance_type_id
          INTO g_bal_type_id_401K_Bonus_ER
          --FROM hr.pay_balance_types pbt --code commented by RXNETHI-ARGANO,15/05/23
		  FROM apps.pay_balance_types pbt --code added by RXNETHI-ARGANO,15/05/23
         WHERE pbt.balance_name =  'Base 401k Bonus ER'
           AND pbt.business_group_id = 325;

    EXCEPTION WHEN OTHERS
    THEN

      errcode  := SQLCODE;
      errbuff  := SUBSTR (SQLERRM, 1, 255);
      RAISE_APPLICATION_ERROR(-20003,'Exception unable to obtain Balance Type ID for Balance Name -> Base 401k Bonus ER ' ||v_module||' [' ||v_loc||'] ERROR:'||errcode||':'||errbuff);
    END;

	v_module := 'Base 401k Catchup ER';
	BEGIN
        v_loc := 584;

        SELECT pbt.balance_type_id
          INTO g_bal_type_id_401K_Catchup_ER
          --FROM hr.pay_balance_types pbt --code commented by RXNETHI-ARGANO,15/05/23
		  FROM apps.pay_balance_types pbt --code added by RXNETHI-ARGANO,15/05/23
         WHERE pbt.balance_name =  'Base 401k Catchup ER'
           AND pbt.business_group_id = 325;

    EXCEPTION WHEN OTHERS
    THEN

      errcode  := SQLCODE;
      errbuff  := SUBSTR (SQLERRM, 1, 255);
      RAISE_APPLICATION_ERROR(-20003,'Exception unable to obtain Balance Type ID for Balance Name -> Base 401k Catchup ER ' ||v_module||' [' ||v_loc||'] ERROR:'||errcode||':'||errbuff);
    END;

	v_module := 'Base 401k ER';
	BEGIN
        v_loc := 585;

        SELECT pbt.balance_type_id
          INTO g_bal_type_id_401K_ER
          --FROM hr.pay_balance_types pbt --code commented by RXNETHI-ARGANO,15/05/23
		  FROM apps.pay_balance_types pbt --code added by RXNETHI-ARGANO,15/05/23
         WHERE pbt.balance_name =  'Base 401k ER'
           AND pbt.business_group_id = 325;

    EXCEPTION WHEN OTHERS
    THEN

      errcode  := SQLCODE;
      errbuff  := SUBSTR (SQLERRM, 1, 255);
      RAISE_APPLICATION_ERROR(-20003,'Exception unable to obtain Balance Type ID for Balance Name -> Base 401k ER ' ||v_module||' [' ||v_loc||'] ERROR:'||errcode||':'||errbuff);
    END;

	v_module := 'Pre Tax 401k ER';
	BEGIN
        v_loc := 586;

        SELECT pbt.balance_type_id
          INTO g_bal_type_id_Pre_Tax_401k_ER
          --FROM hr.pay_balance_types pbt --code commented by RXNETHI-ARGANO,15/05/23
		  FROM apps.pay_balance_types pbt --code added by RXNETHI-ARGANO,15/05/23
         WHERE pbt.balance_name =  'Pre Tax 401K ER'
           AND pbt.business_group_id = 325;

    EXCEPTION WHEN OTHERS
    THEN

      errcode  := SQLCODE;
      errbuff  := SUBSTR (SQLERRM, 1, 255);
      RAISE_APPLICATION_ERROR(-20003,'Exception unable to obtain Balance Type ID for Balance Name -> Pre Tax 401K ER ' ||v_module||' [' ||v_loc||'] ERROR:'||errcode||':'||errbuff);
    END;
/* End 12.0 */

    v_module := 'c_directory_path';
    v_loc := 59;
    open c_directory_path;
    fetch c_directory_path into p_FileDir,p_FileName;
    close c_directory_path;
    v_loc := 60;

    v_module := 'Header Rec';

    v_401k_file := UTL_FILE.FOPEN(p_FileDir, p_FileName, 'w');

    print_header_column_name;

    v_rec :=  'UHDR'                                                                      -- Field 1    CONSTANT -Value of "UHDR" (constant)
           ||'|'|| SUBSTR (' ',1,1)                                                       -- Field 2    FILLER - Space filled or BLANK
           ||'|'|| TO_CHAR(SYSDATE,'J')                                                   -- Field 3    CURRENT PROCESSING DATE(JULIAN)
           ||'|'|| SUBSTR (LPAD('106263',6,'0'),1,6)                                      -- Field 4    ML PLAN NUMBER - Six-digit plan number (assigned by Merrill Lynch) /* 9.0.1 */
           ||'|'|| SUBSTR (RPAD(UPPER('TeleTech 401k Plan'),20,' '),1,20)                 -- Field 5    FILE DESCRIPTION - Plan Name
           ||'|'|| TO_CHAR(SYSDATE,'HH24MISS')                                            -- Field 6    PROCESSING TIME - Time the file was run HHMMSS
           ||'|'|| TO_CHAR( g_check_date,'MMDDYY')                                -- Field 7    CYCLE DATE- TThe current pay period check date - MMDDYY
           ||'|'|| SUBSTR (RPAD(' ',2,' '),1,2)                                           -- Field 8    FILLER - Space filled or BLANK
           ||'|'|| SUBSTR (RPAD(' ',4,' '),1,4)                                           -- Field 9    FILLER - Space filled or BLANK
           ||'|'|| SUBSTR (RPAD(' ',6,' '),1,6)                                           -- Field 10   FILLER - Space filled or BLANK
           ||'|'|| SUBSTR (RPAD('IN HOUSE',20,' '),1,20)                                  -- Field 11   PAYROLL CREATOR - Hardcode payroll provider; if client should be IN HOUSE
           ||'|'|| SUBSTR (TO_CHAR( g_payroll_start_date,'MMDDRRRR'),1,8)         -- Field 12   PAYROLL START DATE (JULIAN)- The payroll effective start date
           ||'|'|| SUBSTR (RPAD(' ',4,' '),1,4)                                           -- Field 13   PAYROLL INDICATOR - Space filled or BLANK
           ||'|'|| TO_CHAR( g_payroll_end_date,'MMDDRRRR')                        -- Field 14   PAYROLL END DATE -  The payroll end date
           --||'|'|| TO_CHAR( g_check_date,'MMDDRRRR')                              -- Field 15   PAYCHECK DATE (JULIAN)- The payroll effective start date /* 9.0.5 */
           ||'|'|| TO_CHAR( g_check_date,'RRRRMMDD')                              -- Field 15   PAYCHECK DATE (JULIAN)- The payroll effective start date /* 9.0.5 */
           ||'|'|| SUBSTR (RPAD(UPPER('Global Benefits'),30,' '),1,30)                    -- Field 16   CONTACT NAME -  Client contact for any issues on payroll file
           ||'|'|| SUBSTR (RPAD('8005032626',10,' '),1,10)                                -- Field 17   CONTACT TELEPHONE NUMBER -  Client contact for any issues on payroll file
           ||'|'|| SUBSTR (RPAD(' ',450,' '),1,450)                                       -- Field 18   FILLER - Space filled or BLANK
      ;

    apps.fnd_file.put_line(apps.fnd_file.output,v_rec);

    v_rec :=  'UHDR'                                                                 -- Field 1    CONSTANT -Value of "UHDR" (constant)
           || SUBSTR (' ',1,1)                                                       -- Field 2    FILLER - Space filled or BLANK
           || TO_CHAR(SYSDATE,'J')                                                   -- Field 3    CURRENT PROCESSING DATE(JULIAN)
           || SUBSTR (LPAD('106263',6,'0'),1,6)                                      -- Field 4    ML PLAN NUMBER - Six-digit plan number (assigned by Merrill Lynch) * 9.0.1 */
           || SUBSTR (RPAD(UPPER('TeleTech 401k Plan'),20,' '),1,20)                 -- Field 5    FILE DESCRIPTION - Plan Name
           || TO_CHAR(SYSDATE,'HH24MISS')                                            -- Field 6    PROCESSING TIME - Time the file was run HHMMSS
           || TO_CHAR((g_check_date),'MMDDYY')                                -- Field 7    CYCLE DATE- TThe current pay period check date - MMDDYY
           || SUBSTR (RPAD(' ',2,' '),1,2)                                           -- Field 8    FILLER - Space filled or BLANK
           || SUBSTR (RPAD(' ',4,' '),1,4)                                           -- Field 9    FILLER - Space filled or BLANK
           || SUBSTR (RPAD(' ',6,' '),1,6)                                           -- Field 10   FILLER - Space filled or BLANK
           || SUBSTR (RPAD('IN HOUSE',20,' '),1,20)                                  -- Field 11   PAYROLL CREATOR - Hardcode payroll provider; if client should be IN HOUSE
           || SUBSTR (TO_CHAR((g_payroll_start_date),'MMDDRRRR'),1,8)         -- Field 12   PAYROLL START DATE (JULIAN)- The payroll effective start date
           || SUBSTR (RPAD(' ',4,' '),1,4)                                           -- Field 13   PAYROLL INDICATOR - Space filled or BLANK
           || TO_CHAR( (g_payroll_end_date),'MMDDRRRR')                        -- Field 14   PAYROLL END DATE -  The payroll end date
           --|| TO_CHAR( (g_check_date),'MMDDRRRR')                              -- Field 15   PAYCHECK DATE (JULIAN)- The payroll effective start date /* 9.0.5 */
           || TO_CHAR( (g_check_date),'RRRRMMDD')                              -- Field 15   PAYCHECK DATE (JULIAN)- The payroll effective start date /* 9.0.5 */
           || SUBSTR (RPAD(UPPER('Global Benefits'),30,' '),1,30)                    -- Field 16   CONTACT NAME -  Client contact for any issues on payroll file
           || SUBSTR (RPAD('8005032626',10,' '),1,10)                                -- Field 17   CONTACT TELEPHONE NUMBER -  Client contact for any issues on payroll file
           || SUBSTR (RPAD(' ',450,' '),1,450)                                       -- Field 18   FILLER - Space filled or BLANK
      ;

    utl_file.put_line(v_401k_file, v_rec);

    v_module := 'Emp Rec';

    print_detail_column_name;

    --FOR emp_rec IN c_emp_cur(g_date_earn_start,g_date_earned)       -- V 1.5 --2.4 commented out
    FOR emp_rec IN c_emp_cur(g_date_earn_start,g_payroll_end_date) -- 2.4
    LOOP

            Fnd_File.put_line(Fnd_File.LOG, ' =========================== Processing Employee ->'||emp_rec.employee_number);

            g_emp_no := emp_rec.employee_number;

            v_loc := 30;
            v_module := 'Emp Rec Loop';

            --
            -- Verify if emp no match to be qualified as Officer
            --
            IF emp_rec.employee_number = '3012468'
            THEN
                v_officer_flag := '1';
            ELSE
                v_officer_flag := '0';
            END IF;


            --
            -- Verify if emp is rehire or not, if yes send rehire date, otherwise blanks
            --
/* 9.0.2 Begin */
--            IF emp_rec.participant_status_code = '97'
--            THEN
--                v_emp_rehire_date := emp_rec.rehire_date;
--            ELSIF emp_rec.participant_status_code = '06'
--            THEN
--                IF emp_rec.rehire_date != emp_rec.hire_date THEN
--                    v_emp_rehire_date := emp_rec.rehire_date;
--                ELSE
--                    v_emp_rehire_date := '';
--                END IF;
--            /* 1.9 Begin  Heather's update on 6/28/2013 : I did verify with Merrill Lynch and they are on board with keeping the rehire date in the field even after termination. */
--            ELSIF emp_rec.participant_status_code = '30'
--            THEN
--                IF emp_rec.rehire_date != emp_rec.hire_date THEN
--                    v_emp_rehire_date := emp_rec.rehire_date;
--                ELSE
--                    v_emp_rehire_date := '';
--                END IF;
--            /* 1.9 End */
--            ELSE
--                v_emp_rehire_date := '';
--            END IF;

            IF emp_rec.rehire_date != emp_rec.hire_date THEN
                v_emp_rehire_date := emp_rec.rehire_date;
            ELSE
                v_emp_rehire_date := '';
            END IF;

/* 9.0.2 End */

            --v_ytd_gross_earning_amount  := 0;
            v_401K_amount 		        := 0;
            v_401K_tot_amount           := 0;
            v_401K_loan1_amount 		:= 0;
            v_401K_catchup_amount		:= 0;
            v_Pre_Tax_401K_Elig_Comp_Amt:= 0;
			v_401K_Elig_Comp_PerPayPeriod := 0;     --12.1
            v_401K_DiscrTest            := 0; /* 7.7 */
            v_401k_roth_amt             := 0;   /* 11.0 */
            v_401K_roth_catchup_amt     := 0;  /* 11.0 */
			v_401K_match_accrual_amount := 0;         --12.0

             /* 2.0  Begin */

            IF      emp_rec.emp_type = 'PEO Employee'
               OR  (emp_rec.emp_type = 'Ex-employee' and emp_rec.division_code = '01905' )
            THEN

                --Fnd_File.put_line(Fnd_File.LOG,'PEO Employee');
                /* 401K  */
                v_module := '401K';

                v_401K_amount :=  GET_BALANCE_PEO (emp_rec.national_identifier,
                                                   p_401k_bal_name  --'Pre Tax 401K',
                                                   );
                 v_tot_401k_amount :=  v_tot_401k_amount + v_401K_amount;

                /* 401K  Catchup*/
                v_module := '401K Catchup';
                v_401K_catchup_amount :=  GET_BALANCE_PEO (emp_rec.national_identifier,
                                                   p_401k_catchup_bal_name -- 'Pre Tax 401K Catchup',
                                                   );

                v_tot_401K_catchup_amount := v_tot_401K_catchup_amount + v_401K_catchup_amount;

                /* 401K  Loan 1 */
                v_module := '401K Loan1';

                v_401K_loan1_amount :=  GET_BALANCE_PEO (emp_rec.national_identifier,
                                                         p_401k_loan1_bal_name --'Loan 1_401k',
                                                   );

                v_tot_401K_loan1_amount := v_tot_401K_loan1_amount + v_401K_loan1_amount;

                /* Elig Comp 401K*/
                v_module := 'Elig Comp 401K';

                v_Pre_Tax_401K_Elig_Comp_Amt :=  GET_BALANCE_PEO (emp_rec.national_identifier,
                                                         p_pre_tax_elig_comp_bal_name  --'Pre Tax 401K Eligible Comp',
                                                   );
				--Begin - 12.1
				v_401K_Elig_Comp_PerPayPeriod :=  GET_BALANCE_PEO (emp_rec.national_identifier,
                                                         p_pre_tax_elig_comp_bal_name  --'Pre Tax 401K Eligible Comp',
                                                   );
				--End - 12.1
--                    Fnd_File.put_line(Fnd_File.LOG, ' PEO emp_rec.employee_number->'||emp_rec.employee_number);
--                    Fnd_File.put_line(Fnd_File.LOG, '           emp_rec.person_id->'||emp_rec.person_id);
--                    Fnd_File.put_line(Fnd_File.LOG, ' emp_rec.national_identifier->'||emp_rec.national_identifier);
--                    Fnd_File.put_line(Fnd_File.LOG, 'v_Pre_Tax_401K_Elig_Comp_Amt->'||v_Pre_Tax_401K_Elig_Comp_Amt);
--                    Fnd_File.put_line(Fnd_File.LOG, '--------------------------------------------');

            ELSE              /* 2.0  End */

                --Fnd_File.put_line(Fnd_File.LOG,'TTEC Employee');
--                    Fnd_File.put_line(Fnd_File.LOG, '-------------------  employee_number->'||emp_rec.employee_number);
--                    Fnd_File.put_line(Fnd_File.LOG, '-------------------  p_bal_dimension->'||p_bal_dimension);
                v_module := '401K';
--                Fnd_File.put_line(Fnd_File.LOG,'====>'||v_module);
--                Fnd_File.put_line(Fnd_File.LOG,'      Balance_name ====>'||p_401k_bal_name);
--                Fnd_File.put_line(Fnd_File.LOG,'         g_check_date ====>'||g_check_date );
--                Fnd_File.put_line(Fnd_File.LOG,'emp_rec.assignment_id ====>'||emp_rec.assignment_id );

                --Fnd_File.put_line(Fnd_File.LOG,'====>'||v_module);

                v_401K_amount :=  NVL(GET_BALANCE_2018 (emp_rec.assignment_id,
                                           g_bal_type_id_401K, -- 'Pre Tax 401K',
                                           g_check_date),0)
                                + NVL(GET_BALANCE_2018 (emp_rec.assignment_id,
                                           g_bal_type_id_401K_Bonus, --'Pre Tax 401K Bonus',
                                           g_check_date),0)
                                + NVL(GET_BALANCE_2018 (emp_rec.assignment_id,
                                           g_bal_type_id_401K_FD, --'Pre Tax 401K Flat Dollar',
                                           g_check_date),0)
                                           ;

                  v_tot_401k_amount :=  v_tot_401k_amount + v_401K_amount;

                /* 401K  Catchup*/
                v_module := '401K Catchup';
                --Fnd_File.put_line(Fnd_File.LOG,'====>'||v_module);
                v_401K_catchup_amount :=  NVL(GET_BALANCE_2018 (emp_rec.assignment_id,
                                        g_bal_type_id_401K_Catchup, --'Pre Tax 401K Catchup',
                                        g_check_date),0)
                                    +     NVL(GET_BALANCE_2018 (emp_rec.assignment_id,
                                        g_bal_type_id_401K_Catchup_FD, --'Pre Tax 401K Catch Up Flat Dollar',
                                        g_check_date),0)
                                       ;

                v_tot_401K_catchup_amount := v_tot_401K_catchup_amount + NVL(v_401K_catchup_amount,0);

              /* 11.0 Begin*/
                v_module := '401K Roth';

                --Fnd_File.put_line(Fnd_File.LOG,'====>'||v_module);

                v_401K_roth_amt  :=  NVL(GET_BALANCE_2018 (emp_rec.assignment_id,
                                           g_bal_type_id_401K_Roth, -- 'Base 401k Roth',
                                           g_check_date),0)
                                + NVL(GET_BALANCE_2018 (emp_rec.assignment_id,
                                           g_bal_type_id_401K_Bonus_Roth, --'Base 401k Bonus Roth',
                                           g_check_date),0)
                                           ;

                  v_tot_401k_roth_amt :=  v_tot_401k_roth_amt + v_401K_roth_amt;

                v_module := '401K Roth Catchup';

                --Fnd_File.put_line(Fnd_File.LOG,'====>'||v_module);

                v_401K_roth_catchup_amt  :=  NVL(GET_BALANCE_2018 (emp_rec.assignment_id,
                                           g_bal_type_id_401K_CatchupRoth, -- 'Base 401K Catch Up Roth',
                                           g_check_date),0)
                                           ;

                  v_tot_401K_roth_catchup_amt :=  v_tot_401K_roth_catchup_amt + v_401K_roth_catchup_amt;

                /* 11.0 End */

/* Begin - 12.0 */
                v_module := '401K Match Accrual Amount';

                --Fnd_File.put_line(Fnd_File.LOG,'====>'||v_module);

                v_401K_match_accrual_amount :=  NVL(GET_BALANCE_2018 (emp_rec.assignment_id,
                                           g_bal_type_id_401K_Roth_ER,                -- 'Base 401k Roth ER',
                                           g_check_date),0)
                                + NVL(GET_BALANCE_2018 (emp_rec.assignment_id,
                                           g_bal_type_id_401K_BonusRothER,            --'Base 401k Bonus Roth ER',
                                           g_check_date),0)
                                + NVL(GET_BALANCE_2018 (emp_rec.assignment_id,
                                           g_bal_type_id_401K_CatUpRothER,            --'Base 401K Catch Up Roth ER',
                                           g_check_date),0)
                                + NVL(GET_BALANCE_2018 (emp_rec.assignment_id,
                                           g_bal_type_id_401K_Bonus_ER,               --'Base 401k Bonus ER',
                                           g_check_date),0)
                                + NVL(GET_BALANCE_2018 (emp_rec.assignment_id,
                                           g_bal_type_id_401K_Catchup_ER,             --'Base 401k Catchup ER',
                                           g_check_date),0)
                                + NVL(GET_BALANCE_2018 (emp_rec.assignment_id,
                                           g_bal_type_id_401K_ER,                     --'Base 401k ER',
                                           g_check_date),0)
								+ NVL(GET_BALANCE_2018 (emp_rec.assignment_id,
                                           g_bal_type_id_Pre_Tax_401k_ER,             --'Pre Tax 401K ER',
                                           g_check_date),0)
                                           ;

                  --v_tot_401K_match_accrual_amount :=  v_tot_401K_match_accrual_amount + v_401K_match_accrual_amount;
/* End - 12.0 */

                /* 401K  Loan 1 */
                v_module := '401K Loan1';
--                Fnd_File.put_line(Fnd_File.LOGGET_BALANCE_2018,'====>'||v_module);
--                Fnd_File.put_line(Fnd_File.LOG,'      Balance_name ====>'|| p_401k_loan1_bal_name);

                v_401K_loan1_amount := NVL(GET_BALANCE_2018 (emp_rec.assignment_id,
                                       g_bal_type_id_401K_Loan1, --'Loan 1_401k',
                                       --p_bal_dimension, /* 7.0 */ --'Assignment within Government Reporting Entity Run',--'Assignment Period to Date', /* 1.1 */
                                       g_check_date),0);

                v_tot_401K_loan1_amount := v_tot_401K_loan1_amount + v_401K_loan1_amount;

               /* CC Begin */
                v_Pre_Tax_401K_Elig_Comp_Amt := 0; /* 2.3 */
				v_401K_Elig_Comp_PerPayPeriod :=0;       --12.1
                --Fnd_File.put_line(Fnd_File.LOG,'c_emp_asg_cur');
--                FOR asg_rec in c_emp_asg_cur(emp_rec.person_id, g_check_date) /* 2.3 */
--                LOOP
                    /* Elig Comp 401K*/
                    v_module := 'Elig Comp 401K';

                    --Fnd_File.put_line(Fnd_File.LOG,'====>'||v_module);
                    v_Pre_Tax_401K_Elig_Comp_Amt := v_Pre_Tax_401K_Elig_Comp_Amt + NVL(GET_BALANCE_2018 (emp_rec.assignment_id, /* 2.3 */
                                                                                                g_bal_type_id_401K_Elig_Comp, --'Pre Tax 401K Eligible Comp',
                                                                                               -- p_bal_dimension, /* 7.0 */ --'Assignment within Government Reporting Entity Run',
                                                                                                g_check_date
                                                                                                ,'Y' /* 7.3 */
                                                                                                ),0)
                                                                                 + NVL(GET_BALANCE_2018 (emp_rec.assignment_id, /* 2.3 */
                                                                                                g_bal_type_id_401K_BonusElComp, --'Pre Tax 401K Bonus Eligible Comp', /* 7.2 */
                                                                                               -- p_bal_dimension, /* 7.0 */ --'Assignment within Government Reporting Entity Run',
                                                                                                g_check_date
                                                                                                ,'Y' /* 7.3 */
                                                                                                ),0);
					--Begin - 12.1
					v_401K_Elig_Comp_PerPayPeriod := NVL(GET_BALANCE_2018 (emp_rec.assignment_id, /* 2.3 */
                                                                                                g_bal_type_id_401K_Elig_Comp, --'Pre Tax 401K Eligible Comp',
                                                                                               -- p_bal_dimension, /* 7.0 */ --'Assignment within Government Reporting Entity Run',
                                                                                                g_check_date
                                                                                                ,'N' /* 7.3 */
                                                                                                ),0)
                                                                                 + NVL(GET_BALANCE_2018 (emp_rec.assignment_id, /* 2.3 */
                                                                                                g_bal_type_id_401K_BonusElComp, --'Pre Tax 401K Bonus Eligible Comp', /* 7.2 */
                                                                                               -- p_bal_dimension, /* 7.0 */ --'Assignment within Government Reporting Entity Run',
                                                                                                g_check_date
                                                                                                ,'N' /* 7.3 */
                                                                                                ),0);
					--End - 12.1

--                    v_Pre_Tax_401K_Elig_Comp_Amt := v_Pre_Tax_401K_Elig_Comp_Amt + GET_BALANCE_2015 (emp_rec.person_id, /* 2.3 */
--                                                                                                p_pre_tax_elig_comp_bal_name , --'Pre Tax 401K Eligible Comp',
--                                                                                                p_bal_dimension, /* 7.0 */ --'Assignment within Government Reporting Entity Run',
--                                                                                                g_check_date,
--                                                                                                emp_rec.business_group_id);

--                    v_Pre_Tax_401K_Elig_Comp_Amt := v_Pre_Tax_401K_Elig_Comp_Amt + GET_BALANCE_NEW (asg_rec.assignment_id, /* 2.3 */
--                                                                                                p_pre_tax_elig_comp_bal_name , --'Pre Tax 401K Eligible Comp',
--                                                                                               'Assignment within Government Reporting Entity Run',
--                                                                                                g_check_date,
--                                                                                                emp_rec.business_group_id);

--                        Fnd_File.put_line(Fnd_File.LOG, '     emp_rec.employee_number->'||emp_rec.employee_number);
--                        Fnd_File.put_line(Fnd_File.LOG, '           emp_rec.person_id->'||emp_rec.person_id);
--                        Fnd_File.put_line(Fnd_File.LOG, '       asg_rec.assignment_id->'||asg_rec.assignment_id);
--                        Fnd_File.put_line(Fnd_File.LOG, 'v_Pre_Tax_401K_Elig_Comp_Amt->'||v_Pre_Tax_401K_Elig_Comp_Amt);
--                        Fnd_File.put_line(Fnd_File.LOG, '--------------------------------------------');


--                END LOOP;
                /* 7.7 Begin */
                /* 401K  DiscrTest */
                v_module := '401K DiscrTest';
--                Fnd_File.put_line(Fnd_File.LOGGET_BALANCE_2018,'====>'||v_module);
--                Fnd_File.put_line(Fnd_File.LOG,'      Balance_name ====>'|| 'US_401K_Discrimination_Testing');

                v_401K_DiscrTest := NVL(GET_BALANCE_2018 (emp_rec.assignment_id,
                                       g_bal_type_id_401K_DiscrTest, --'US_401K_Discrimination_Testing',
                                       --p_bal_dimension, /* 7.0 */ --'Assignment within Government Reporting Entity Run',--'Assignment Period to Date', /* 1.1 */
                                       g_check_date
                                       ,'Y'
                                       ),0);
                /* 7.7 End */

            END IF;

        --IF NVL(v_Pre_Tax_401K_Elig_Comp_Amt,0) > 0 THEN
--         IF   (   NVL(v_Pre_Tax_401K_Elig_Comp_Amt,0) > 0
--            and (     emp_rec.emp_type <> 'PEO Employee'
--                 OR  (emp_rec.emp_type != 'Ex-employee' and emp_rec.division_code != '01905' )
--                 ) )
--         THEN
            v_module := 'emp_address';

            /* V1.3  Begin*/
            IF emp_rec.effective_start_date > g_date_earned THEN
            get_emp_address(emp_rec.person_id,
                            emp_rec.effective_start_date,
                            v_emp_addr_line1,
                            v_emp_addr_line2,
                            v_emp_city,
                            v_emp_state,
                            v_emp_zip_code,
                            v_emp_country,
                            v_emp_phone /* 9.0.6 */
                            );
             /* V1.4  Begin*/
            get_emp_salary( emp_rec.person_id,
                            emp_rec.assignment_id,
                            emp_rec.pay_basis_id,
                            g_payroll_end_date, /* Aug 21, 2015 */
                            emp_rec.actual_termination_date,
                            v_emp_salary) ;
            /* V1.4  End*/
            ELSE
            get_emp_address(emp_rec.person_id,
                            g_date_earned,
                            v_emp_addr_line1,
                            v_emp_addr_line2,
                            v_emp_city,
                            v_emp_state,
                            v_emp_zip_code,
                            v_emp_country,
                            v_emp_phone /* 9.0.6 */
                            ) ;
            /* V1.4  Begin*/
--            get_emp_salary( emp_rec.assignment_id,
--                            emp_rec.pay_basis_id,
--                            g_date_earned,
--                            v_emp_salary) ;
            get_emp_salary( emp_rec.person_id,
                            emp_rec.assignment_id,
                            emp_rec.pay_basis_id,
                            g_payroll_end_date, /* Aug 21, 2015 */
                            emp_rec.actual_termination_date,
                            v_emp_salary) ;
            /* V1.4  End*/
            END IF;
            /* V1.3  End*/

           /* V1.5 Begin */

           IF g_flex_num is not NULL THEN
              v_alternative_vest_date := get_alternative_vest_date(emp_rec.person_id);
           ELSE
              v_alternative_vest_date := NULL;
           END IF;

           /* V1.5 End*/

		   /* 12.0 Begin */
           IF g_flex_num2 is not NULL THEN
              v_match_eligibility_date := get_match_eligibility_date(emp_rec.person_id);
           ELSE
              v_match_eligibility_date := NULL;
           END IF;
           /* 12.0 End*/

            --
            -- Verify if emp is Puerto Rico resident
            --
            IF v_emp_country = 'PR'
            THEN
                v_PuertoRico_resident_flag := 'PR';
            ELSE
                v_PuertoRico_resident_flag := '  ';
            END IF;

          IF NVL(emp_rec.hire_date,to_date('31-DEC-4712')) != NVL(emp_rec.actual_termination_date,to_date('31-DEC-4712'))  /* 9.2 */
          THEN
            v_module := 'Emp OUTPUT';
            v_rec :=  '71'                                                                        -- Field 1    RECORD TYPE-Populate 71
                   ||'|'|| SUBSTR (LPAD('106263',6,'0'),1,6)                                      -- Field 2    FILLER - Space filled or BLANK * 9.0.1 */
                   ||'|'|| NVL(SUBSTR (LPAD(replace(emp_rec.national_identifier,'-',''),9,'0'),1,9),RPAD(' ',9,' '))   -- Field 3    SOCIAL SECURITY NUMBER - SSN with no dashes
                   ||'|'|| NVL(SUBSTR (RPAD(emp_rec.participant_status_code,2,' '),1,2),RPAD(' ',2,' '))               -- Field 4    PARTICIPANT STATUS CODE
                   ||'|'|| RPAD(' ',4,' ')                                                        -- Field 5    DIVISION/SUBSIDIARY - SEND SPACES
                   ||'|'|| NVL(SUBSTR (RPAD(emp_rec.employee_number,13,' '),1,13),RPAD(' ',13,' '))                     -- Field 6    EMPLOYEE NUMBER - Employee Number
                   ||'|'|| emp_rec.division_code                                                  -- Field 6.5   EMLOYEE GL LOCATION
                   ||'|'|| NVL(SUBSTR (RPAD(emp_rec.GCA_Code,15,' '),1,15),RPAD(' ',15,' '))      -- Field 7    GCA CODE                    --12.0
                   ||'|'|| NVL(SUBSTR (RPAD(emp_rec.Job_Familiy,15,' '),1,15),RPAD(' ',15,' '))   -- Field 8    JOB FAMILY                  --12.0
                   ||'|'|| SUBSTR (RPAD( UPPER(ttec_library.remove_non_ascii(emp_rec.full_name)),30,' '),1,30)                   -- Field 9    FULL NAME - PER_ALL_PEOPLE_F.FULL_NAME
                   ||'|'|| NVL(TO_CHAR( (emp_rec.date_of_birth),'RRRRMMDD')
                           ,RPAD(' ',8,' '))                                                      -- Field 10   DATE OF BIRTH - Employees date of Birth(YYMMDD)
                   ||'|'|| NVL(TO_CHAR( (emp_rec.hire_date),'RRRRMMDD')
                           ,RPAD(' ',8,' '))                                                      -- Field 11   DATE OF HIRE - Employee's Original Hire Date -PER_ALL_PEOPLE_F.START_DATE
                   ||'|'|| NVL(TO_CHAR((v_match_eligibility_date),'RRRRMMDD'),RPAD(' ',8,' '))    -- Field 12   MATCH ENTRY DATE     --12.0
                   ||'|'|| NVL(TO_CHAR( (emp_rec.actual_termination_date),'RRRRMMDD')
                           ,RPAD(' ',8,' '))                                                      -- Field 13   DATE OF TERMINATION - Required. Employee's Actual Termination Date
--                   ||'|'|| NVL(TO_CHAR( (v_alternative_vest_date),'RRRRMMDD') -- V1.5
--                           ,NVL(TO_CHAR( (emp_rec.rehire_date),'RRRRMMDD'), TO_CHAR( (emp_rec.hire_date),'RRRRMMDD') -- V1.5
--                           ))                                                                     -- Field 14   ALTERNATE VEST DATE -  Not Required. Send Blank
                   ||'|'|| NVL(TO_CHAR( (v_alternative_vest_date),'RRRRMMDD') -- 5.6
                           ,TO_CHAR( (emp_rec.hire_date),'RRRRMMDD')   -- 5.6
                           )                                                                      -- Field 14   ALTERNATE VEST DATE -  Not Required. Send Blank
                -- /* 9.0.3 */   ||'|'|| 'B'                                                                    -- Field 15   PAYROLL FREQUENCY - Required. Indicates frequency of participant's paycheck; W=weekly, B= bi-weekly, S=semi-monthly, M=monthly; will be used to amortize loans
                   ||'|'|| '6'                                                                    -- Field 15   PAYROLL FREQUENCY - Required. Indicates frequency of participant's paycheck; W=weekly, B= bi-weekly, S=semi-monthly, M=monthly; will be used to amortize loans
                   ||'|'|| RPAD('0',1,'0')                                                        -- Field 16   SECTION 16 INDICATOR - Not Required. Send Blank
                   ||'|'|| NVL(SUBSTR(RPAD(REPLACE(REPLACE(UPPER( v_emp_addr_line1),',',''),'.',''),30,' '),1,30),RPAD(' ',30,' '))  -- Field 17   ADDRESS LINE 1 -  First line of Employee's permanent street address
                   ||'|'|| NVL(SUBSTR(RPAD(REPLACE(REPLACE(UPPER(v_emp_addr_line2),',',''),'.',''),30,' '),1,30),RPAD(' ',30,' '))  -- Field 18   ADDRESS LINE 2 -  PER_ADDRESSES.ADDRESS_LINE2
                   ||'|'|| NVL(SUBSTR(RPAD(UPPER(v_emp_city),18,' '),1,18),RPAD(' ',18,' '))      -- Field 19   CITY -  PER_ADDRESSES.TOWN_OR_CITY
                   ||'|'|| NVL(SUBSTR(RPAD(UPPER(v_emp_state),2,' '),1,2),RPAD(' ',2,' '))        -- Field 20   STATE -  PER_ADDRESSES .REGION_2
                   ||'|'|| NVL(SUBSTR(RPAD(v_emp_zip_code,9,' '),1,9),RPAD(' ',9,' '))            -- Field 21   ZIP -  PER_ADDRESSES .POSTAL_CODE
                   ||'|'|| 'A'                                                                    -- Field 22   SOURCE 1 LABEL- A for Employee Deferrals + Catchup; if catch up is combined with regular deferral
                   ||'|'|| format_amount(v_401K_amount,9)                                         -- Field 23   SOURCE 1 AMOUNT - Required. Element Name is Pre Tax 401K
               /* 9.0.4 */    --||'|'|| 'Z'                                                                    -- Field 24   SOURCE 2 LABEL- Z Z for Catchup; if catchup is reported separately
                   ||'|'|| '$'                                                                    -- Field 24   SOURCE 2 LABEL- Z Z for Catchup; if catchup is reported separately
                   ||'|'|| format_amount(v_401K_catchup_amount,9)                                 -- Field 25   SOURCE 2 AMOUNT - Required. Element Name is Pre Tax 401K Catchup
--                   ||'|'|| 'X'                                                                  -- Field 26   SOURCE 3 LABEL- X for ER Match
--                   ||'|'|| NVL(SUBSTR (LPAD(REPLACE(REPLACE(REPLACE(TO_CHAR(v_401K_ER_amount,'000000.99S'),'.',''),'+','{'),'-','{'),9,'0'),1,9),RPAD(' ',9,' '))                               -- Field 27   SOURCE 3 AMOUNT - Required. Element Name is Pre Tax 401K ER
                   ||'|'|| 'S'                                                                    -- Field 26   SOURCE 3 LABEL- S for Base 401k Roth (TRP)  /* 11.0 */
                   ||'|'|| format_amount(v_401k_roth_amt ,9)           -- Field 27   SOURCE 3 AMOUNT - Required. Element Name is 'Base 401k Roth'  /* 11.0 */
                   ||'|'|| '#'                                                                    -- Field 28   SOURCE 4 LABEL- - # for 'Base 401K Catch Up Roth' (TRP)  /* 11.0 */
                   ||'|'|| format_amount(v_401K_roth_catchup_amt,9)                -- Field 29   SOURCE 4 AMOUNT - Required. Element Name is 'Base 401K Catch Up Roth' (TRP) /* 11.0 */
                   ||'|'|| ' '                                                                    -- Field 30   SOURCE 5 LABEL- Send Blank
                   ||'|'|| format_amount(v_401K_match_accrual_amount,9)                           -- Field 31   MATCH ACCRUAL AMOUNT             --12.0
                   ||'|'|| ' '                                                                    -- Field 32   SOURCE 6 LABEL- Send Blank
                   ||'|'|| '000000000'                                                            -- Field 33   SOURCE 6 AMOUNT - Send 0's
                   ||'|'|| format_amount(v_401K_Elig_Comp_PerPayPeriod,9)             -- Field 34   PAY PERIOD COMPENSATION          --12.1
                   ||'|'|| RPAD('0',2,'0')                                                        -- Field 35   ML LOAN # - corresponds to ml loan number - ml loan # transmitted on outbound file - Send 0's
                   ||'|'|| format_amount(v_401K_loan1_amount,7)                                   -- Field 36   LOAN REPAYMENT AMOUNT - Select the Pay Value from the run_result_values table for Loan 1_401k element.
                   ||'|'|| RPAD('0',2,'0')                                                        -- Field 37   ML LOAN # - corresponds to ml loan number - Send 0's
                   ||'|'|| '0000000'                                                              -- Field 38   LOAN REPAYMENT AMOUNT - Send 0's
                   ||'|'|| RPAD('0',2,'0')                                                        -- Field 39   ML LOAN # - corresponds to ml loan number - Send 0's
                   ||'|'|| '0000000'                                                              -- Field 40   LOAN REPAYMENT AMOUNT - Send 0's
                   ||'|'|| RPAD('0',2,'0')                                                        -- Field 41   ML LOAN # - corresponds to ml loan number - Send 0's
                   ||'|'|| '0000000'                                                              -- Field 42   LOAN REPAYMENT AMOUNT - Send 0's
                   ||'|'|| RPAD('0',2,'0')                                                        -- Field 43   ML LOAN # - corresponds to ml loan number - Send 0's
                   ||'|'|| '0000000'                                                              -- Field 44   LOAN REPAYMENT AMOUNT - Send 0's
                   ||'|'|| '000000000'                                                            -- Field 45   CURRENT BASE PAY - Send 0's
                   ||'|'|| format_amount(v_Pre_Tax_401K_Elig_Comp_Amt,9)                          -- Field 46   PLAN COMP - Compliance testing- Required - Pre Tax 401K Eligible Comp Balance.
                   ||'|'|| '000000000'                                                            -- Field 47   NON-RECURRING COMP  - Send Blanks
                   ||'|'|| '000000000'                                                            -- Field 48   YTD SEC 125 CONTRIB - Send Blanks
                   ||'|'|| RPAD(' ',4,' ')                                                        -- Field 49   BEFORE-TAX DEFERRAL % - Send Blanks
                   ||'|'|| RPAD(' ',4,' ')                                                        -- Field 50   AFTER-TAX CONTRIB % - Send Blanks
                   ||'|'|| RPAD(' ',11,' ')                                                       -- Field 51   PROFIT SHARING COMP - Send Blanks
                   ||'|'|| RPAD(' ',11,' ')                                                       -- Field 52   PLAN YTD MATCH COMP - Send Blanks
                   ||'|'|| RPAD(' ',11,' ')                                                       -- Field 53   PERIOD MATCH COMP - Send Blanks
                   --||'|'|| format_amount(v_Pre_Tax_401K_Elig_Comp_Amt,11)                         -- Field 54   NON-DISCRIM TESTING COMP - Send 0's /* 7.7 */
                   ||'|'|| format_amount(v_401K_DiscrTest,11)                                     -- Field 54   NON-DISCRIM TESTING COMP - Send 0's /* 7.7 */
                   ||'|'|| format_amount(v_emp_salary,10 )  /* V1.4 */                            -- Field 55   ADVICE ANNUAL SALARY - Required - Annual salary for salaried employees; projected annual salary for hourly employees (hourly rate * 2080 hours)
                   ||'|'|| RPAD(' ',8,' ')                                                        -- Field 56   SALARY INCR EFFECTIVE DATE - Send Blanks
                   ||'|'|| RPAD(' ',4,' ')                                                        -- Field 57   ROTH AT DEFERRAL % - Send Blanks
                   ||'|'|| 'R'                                                                    -- Field 58   LPART INDICATOR ( FULL FILE OR CHANGE FILE ACTION) - Populate R
                   ||'|'|| RPAD(' ',7,' ')                                                        -- Field 59   PLAN YEAR-TO-DATE HOURS - Send Blanks
                   ||'|'|| v_officer_flag                                                         -- Field 60   OFFICER / 5% OWNER - Send 1 for emp no 3012468 and send 0 for rest all employees.
--                   ||'|'|| v_officer_flag                                                       -- Field 61   OKEY EMPLOYEE - Send 1 for emp no 3012468 and send 0 for rest all employees.
                   ||'|'|| '0'                                                                    -- Field 61   KEY EMPLOYEE -  send 0 for  all employees.
                   ||'|'|| RPAD(' ',1,' ')                                                        -- Field 62   EXCLUDABLE TOP 20%- Send Blanks
                   ||'|'|| '0'                                                                    -- Field 63   HIGHLY COMPENSATED EMPLOYEE - Send Blanks
                   ||'|'|| RPAD(' ',1,' ')                                                        -- Field 64   UNION/NON-UNION - Send Blanks
                  -- ||'|'|| RPAD('N',1,' ')                                                        -- Field 65   ELIGIBILITY FLAG - Populate N /* 7.6 */
                   ||'|'|| RPAD(' ',1,' ')                                                        -- Field 65   ELIGIBILITY FLAG - If utilizing EZ Enrollment, enter a "Y".  Otherwise, enter a space./* 7.6 */
                   ||'|'|| '0000000'                                                              -- Field 66   ELIGIBLE HOURS - hours for eligibity tracking - Send 0's
                   ||'|'|| RPAD(' ',1,' ')                                                        -- Field 67   PAYROLL DIVISION - Send Blanks
                   ||'|'|| '0'                                                                    -- Field 68   RULE 144 INDICATOR - Send 0
                   ||'|'|| format_amount(v_Pre_Tax_401K_Elig_Comp_Amt,9)                          -- Field 69   415 TEST COMP - Access the balance Pre Tax 401K Eligible Comp    ????
                   ||'|'|| v_PuertoRico_resident_flag                                             -- Field 70   RESIDENT OF PUERTO RICO - Check employees address and if resident of Puerto Rico send PR
                   ||'|'|| RPAD(' ',2,' ')                                                        -- Field 71   EMPLOYER FLAG - Send Blanks
                   ||'|'|| NVL(TO_CHAR(v_emp_rehire_date,'RRRRMMDD'),RPAD(' ',8,' '))             -- Field 72   REHIRE DATE - Required if utilizing Auto Rehire - Per_all_people_f.start_date
                   ||'|'|| RPAD(' ',2,' ')                                                        -- Field 73   LEAVE OF ABSENCE TYPE - Send Blanks
                   ||'|'|| NVL(SUBSTR (RPAD(emp_rec.sex,1,' '),1,1),RPAD(' ',1,' '))                                   -- Field 74   SEX - Required
                   ||'|'|| NVL(SUBSTR (RPAD(emp_rec.marital_status,1,' '),1,1),RPAD(' ',1,' '))                        -- Field 75   MARITAL STATUS - Required
                   ||'|'|| RPAD(' ',1,' ')                                                        -- Field 76   FSE LSE INDICATOR ( Full or Part time indicator) - Send Blanks
                   ||'|'|| RPAD(' ',1,' ')                                                        -- Field 77   ROTH SAVE RATE USAGE INDICATOR - Send Blanks
                   ||'|'|| RPAD(' ',8,' ')                                                        -- Field 78   ELIGIBILITY DATE - Send Blanks
                   ||'|'|| NVL(SUBSTR (RPAD(UPPER( emp_rec.email_address),50,' '),1,50),RPAD(' ',50,' '))     -- Field 79   BUSINESS E-MAIL ADDRESS - Per_all_people_f.email_address /* 9.1 */
                   ||'|'|| RPAD(' ',8,' ')                                                        -- Field 80   USERRA START DATE - Send Blanks
                   ||'|'|| RPAD(' ',8,' ')                                                        -- Field 81   USERRA END DATE - Send Blanks
                   ||'|'|| RPAD(' ',8,' ')                                                        -- Field 82   LOA START DATE - Send Blanks
                   ||'|'|| RPAD(' ',8,' ')                                                        -- Field 83   LOA END DATE - Send Blanks
                   --||'|'|| RPAD(' ',9,' ')                                                        -- Field 84   FILLER- Send Blanks /* 9.0.6 */
                   ||'|'|| NVL(SUBSTR (RPAD(ttec_library.remove_non_ascii(v_emp_phone),10,' '),1,10),RPAD(' ',10,' '))             -- Field 84   FILLER - Employee home phone if none Mobile /* 9.0.6 */ chanhe from 9 character to 10 characters
                   ;

            apps.fnd_file.put_line(apps.fnd_file.output,v_rec);

            v_module := 'Emp FILE';
            v_rec :=  '71'                                                                   -- Field 1    RECORD TYPE-Populate 71 * 9.0.1 */
                   || SUBSTR (LPAD('106263',6,'0'),1,6)                                      -- Field 2    FILLER - Space filled or BLANK
                   || NVL(SUBSTR (LPAD(replace(emp_rec.national_identifier,'-',''),9,'0'),1,9),RPAD(' ',9,' '))   -- Field 3    SOCIAL SECURITY NUMBER - SSN with no dashes
                   || NVL(SUBSTR (RPAD(emp_rec.participant_status_code,2,' '),1,2),RPAD(' ',2,' '))               -- Field 4    PARTICIPANT STATUS CODE
                   || RPAD(' ',4,' ')                                                        -- Field 5    DIVISION/SUBSIDIARY - SEND SPACES
                   || NVL(SUBSTR (RPAD(emp_rec.employee_number||'-'||emp_rec.division_code,13,' '),1,13),RPAD(' ',13,' '))    -- Field 6    EMPLOYEE NUMBER - Employee Number
                   ||NVL(SUBSTR (RPAD(emp_rec.GCA_Code,15,' '),1,15),RPAD(' ',15,' '))      -- Field 7    GCA CODE                    --12.0
                   ||NVL(SUBSTR (RPAD(emp_rec.Job_Familiy,15,' '),1,15),RPAD(' ',15,' '))   -- Field 8    JOB FAMILY                  --12.0
                   || SUBSTR (RPAD( UPPER(ttec_library.remove_non_ascii(emp_rec.full_name)),30,' '),1,30)                   -- Field 9    FULL NAME - PER_ALL_PEOPLE_F.FULL_NAME
                   || NVL(TO_CHAR( (emp_rec.date_of_birth),'RRRRMMDD')
                           ,RPAD(' ',8,' '))                                                      -- Field 10   DATE OF BIRTH - Employees date of Birth(YYMMDD)
                   || NVL(TO_CHAR( (emp_rec.hire_date),'RRRRMMDD')
                           ,RPAD(' ',8,' '))                                                      -- Field 11   DATE OF HIRE - Employee's Original Hire Date -PER_ALL_PEOPLE_F.START_DATE
                   || NVL(TO_CHAR((v_match_eligibility_date),'RRRRMMDD'),RPAD(' ',8,' '))    -- Field 12   MATCH ENTRY DATE     --12.0
                   || NVL(TO_CHAR( (emp_rec.actual_termination_date),'RRRRMMDD')
                           ,RPAD(' ',8,' '))                                                 -- Field 13   DATE OF TERMINATION - Required. Employee's Actual Termination Date
--                   || NVL(TO_CHAR( (v_alternative_vest_date),'RRRRMMDD') -- V1.5
--                           ,NVL(TO_CHAR( (emp_rec.rehire_date),'RRRRMMDD'), TO_CHAR( (emp_rec.hire_date),'RRRRMMDD') -- V1.5
--                           ))                                                                -- Field 14   ALTERNATE VEST DATE -  Not Required. Send Blank
                   || NVL(TO_CHAR( (v_alternative_vest_date),'RRRRMMDD') -- 5.6
                           ,TO_CHAR( (emp_rec.hire_date),'RRRRMMDD')   -- 5.6
                           )
                   /* 9.0.3 */--|| 'B'                                                                    -- Field 15   PAYROLL FREQUENCY - Required. Indicates frequency of participant's paycheck; W=weekly, B= bi-weekly, S=semi-monthly, M=monthly; will be used to amortize loans
                   || '6'                                                                    -- Field 15   PAYROLL FREQUENCY - Required. Indicates frequency of participant's paycheck; W=weekly, B= bi-weekly, S=semi-monthly, M=monthly; will be used to amortize loans
                   || RPAD('0',1,'0')                                                        -- Field 16   SECTION 16 INDICATOR - Not Required. Send Blank
                   || NVL(SUBSTR(RPAD(REPLACE(REPLACE(UPPER(v_emp_addr_line1),',',''),'.',''),30,' '),1,30),RPAD(' ',30,' '))  -- Field 17   ADDRESS LINE 1 -  First line of Employee's permanent street address
                   || NVL(SUBSTR(RPAD(REPLACE(REPLACE(UPPER(v_emp_addr_line2),',',''),'.',''),30,' '),1,30),RPAD(' ',30,' '))  -- Field 18   ADDRESS LINE 2 -  PER_ADDRESSES.ADDRESS_LINE2
                   || NVL(SUBSTR(RPAD(UPPER(v_emp_city),18,' '),1,18),RPAD(' ',18,' '))      -- Field 19   CITY -  PER_ADDRESSES.TOWN_OR_CITY
                   || NVL(SUBSTR(RPAD(UPPER(v_emp_state),2,' '),1,2),RPAD(' ',2,' '))        -- Field 20   STATE -  PER_ADDRESSES .REGION_2
                   || NVL(SUBSTR(RPAD(v_emp_zip_code,9,' '),1,9),RPAD(' ',9,' '))            -- Field 21   ZIP -  PER_ADDRESSES .POSTAL_CODE
                   || 'A'                                                                    -- Field 22   SOURCE 1 LABEL- A for Employee Deferrals + Catchup; if catch up is combined with regular deferral
                   || format_amount(v_401K_amount,9)                                         -- Field 23   SOURCE 1 AMOUNT - Required. Element Name is Pre Tax 401K
                /* 9.0.4 */   --|| 'Z'                                                                    -- Field 24   SOURCE 2 LABEL- Z Z for Catchup; if catchup is reported separately
                   || '$'                                                                    -- Field 24   SOURCE 2 LABEL- Z Z for Catchup; if catchup is reported separately
                   || format_amount(v_401K_catchup_amount,9)                                 -- Field 25   SOURCE 2 AMOUNT - Required. Element Name is Pre Tax 401K Catchup
--                   || 'X'                                                                  -- Field 26   SOURCE 3 LABEL- X for ER Match
--                   || NVL(SUBSTR (LPAD(REPLACE(REPLACE(REPLACE(TO_CHAR(v_401K_ER_amount,'000000.99S'),'.',''),'+','{'),'-','{'),9,'0'),1,9),RPAD(' ',9,' '))                               -- Field 27   SOURCE 3 AMOUNT - Required. Element Name is Pre Tax 401K ER
                   ||  'S'                                                                    -- Field 26   SOURCE 3 LABEL- S for Base 401k Roth (TRP)  /* 11.0 */
                   || format_amount(v_401k_roth_amt ,9)           -- Field 27   SOURCE 3 AMOUNT - Required. Element Name is 'Base 401k Roth'  /* 11.0 */
                   ||  '#'                                                                    -- Field 28   SOURCE 4 LABEL- - # for 'Base 401K Catch Up Roth' (TRP)  /* 11.0 */
                   ||format_amount(v_401K_roth_catchup_amt,9)                -- Field 29   SOURCE 4 AMOUNT - Required. Element Name is 'Base 401K Catch Up Roth' (TRP) /* 11.0 */
                   || ' '                                                                    -- Field 30   SOURCE 5 LABEL- Send Blank
                   || format_amount(v_401K_match_accrual_amount,9)                           -- Field 31   MATCH ACCRUAL AMOUNT             --12.0
                   || ' '                                                                    -- Field 32   SOURCE 6 LABEL- Send Blank
                   || '000000000'                                                            -- Field 33   SOURCE 6 AMOUNT - Send 0's
                   || format_amount(v_401K_Elig_Comp_PerPayPeriod,9)             -- Field 34   PAY PERIOD COMPENSATION -   --12.1 sending value  now
                   || RPAD('0',2,'0')                                                        -- Field 35   ML LOAN # - corresponds to ml loan number - ml loan # transmitted on outbound file - Send 0's
                   || format_amount(v_401K_loan1_amount,7)                                   -- Field 36   LOAN REPAYMENT AMOUNT - Select the Pay Value from the run_result_values table for Loan 1_401k element.
                   || RPAD('0',2,'0')                                                        -- Field 37   ML LOAN # - corresponds to ml loan number - Send 0's
                   || '0000000'                                                              -- Field 38   LOAN REPAYMENT AMOUNT - Send 0's
                   || RPAD('0',2,'0')                                                        -- Field 39   ML LOAN # - corresponds to ml loan number - Send 0's
                   || '0000000'                                                              -- Field 40   LOAN REPAYMENT AMOUNT - Send 0's
                   || RPAD('0',2,'0')                                                        -- Field 41   ML LOAN # - corresponds to ml loan number - Send 0's
                   || '0000000'                                                              -- Field 42   LOAN REPAYMENT AMOUNT - Send 0's
                   || RPAD('0',2,'0')                                                        -- Field 43   ML LOAN # - corresponds to ml loan number - Send 0's
                   || '0000000'                                                              -- Field 44   LOAN REPAYMENT AMOUNT - Send 0's
                   || '000000000'                                                            -- Field 45   CURRENT BASE PAY - Send 0's
                   || format_amount(v_Pre_Tax_401K_Elig_Comp_Amt,9)                          -- Field 46   PLAN COMP - Compliance testing- Required - Pre Tax 401K Eligible Comp Balance.
                   || '000000000'                                                            -- Field 47   NON-RECURRING COMP  - Send Blanks
                   || '000000000'                                                            -- Field 48   YTD SEC 125 CONTRIB - Send Blanks
                   || RPAD(' ',4,' ')                                                        -- Field 49   BEFORE-TAX DEFERRAL % - Send Blanks
                   || RPAD(' ',4,' ')                                                        -- Field 50   AFTER-TAX CONTRIB % - Send Blanks
                   || RPAD(' ',11,' ')                                                       -- Field 51   PROFIT SHARING COMP - Send Blanks
                   || RPAD(' ',11,' ')                                                       -- Field 52   PLAN YTD MATCH COMP - Send Blanks
                   || RPAD(' ',11,' ')                                                       -- Field 53   PERIOD MATCH COMP - Send Blanks
                   --|| format_amount(v_Pre_Tax_401K_Elig_Comp_Amt,11)                         -- Field 54   NON-DISCRIM TESTING COMP - Send 0's /* 7.7 */
                   || format_amount(v_401K_DiscrTest,11)                                     -- Field 54   NON-DISCRIM TESTING COMP - Send 0's /* 7.7 */
                   || format_amount(v_emp_salary,10 )  /* V1.4 */                            -- Field 55   ADVICE ANNUAL SALARY - Required - Annual salary for salaried employees; projected annual salary for hourly employees (hourly rate * 2080 hours)
                   || RPAD(' ',8,' ')                                                        -- Field 56   SALARY INCR EFFECTIVE DATE - Send Blanks
                   || RPAD(' ',4,' ')                                                        -- Field 57   ROTH AT DEFERRAL % - Send Blanks
                   || 'R'                                                                    -- Field 58   LPART INDICATOR ( FULL FILE OR CHANGE FILE ACTION) - Populate R
                   || RPAD(' ',7,' ')                                                        -- Field 59   PLAN YEAR-TO-DATE HOURS - Send Blanks
                   || v_officer_flag                                                         -- Field 60   OFFICER / 5% OWNER - Send 1 for emp no 3012468 and send 0 for rest all employees.
--                   || v_officer_flag                                                       -- Field 61   OKEY EMPLOYEE - Send 1 for emp no 3012468 and send 0 for rest all employees.
                   || '0'                                                                    -- Field 61   KEY EMPLOYEE -  send 0 for  all employees.
                   || RPAD(' ',1,' ')                                                        -- Field 62   EXCLUDABLE TOP 20%- Send Blanks
                   || '0'                                                                    -- Field 63   HIGHLY COMPENSATED EMPLOYEE - Send Blanks
                   || RPAD(' ',1,' ')                                                        -- Field 64   UNION/NON-UNION - Send Blanks
                 --  || RPAD('N',1,' ')                                                        -- Field 65   ELIGIBILITY FLAG - Populate N /* 7.6 */
                   || RPAD(' ',1,' ')                                                        -- Field 65   ELIGIBILITY FLAG - If utilizing EZ Enrollment, enter a "Y".  Otherwise, enter a space. /* 7.6 */
                   || '0000000'                                                              -- Field 66   ELIGIBLE HOURS - hours for eligibity tracking - Send 0's
                   || RPAD(' ',1,' ')                                                        -- Field 67   PAYROLL DIVISION - Send Blanks
                   || '0'                                                                    -- Field 68   RULE 144 INDICATOR - Send 0
                   || format_amount(v_Pre_Tax_401K_Elig_Comp_Amt,9)                          -- Field 69   415 TEST COMP - Access the balance Pre Tax 401K Eligible Comp    ????
                   || v_PuertoRico_resident_flag                                             -- Field 70   RESIDENT OF PUERTO RICO - Check employees address and if resident of Puerto Rico send PR
                   || RPAD(' ',2,' ')                                                        -- Field 71   EMPLOYER FLAG - Send Blanks
                   || NVL(TO_CHAR(v_emp_rehire_date,'RRRRMMDD'),RPAD(' ',8,' '))             -- Field 72   REHIRE DATE - Required if utilizing Auto Rehire - Per_all_people_f.start_date
                   || RPAD(' ',2,' ')                                                        -- Field 73   LEAVE OF ABSENCE TYPE - Send Blanks
                   || NVL(SUBSTR (RPAD(emp_rec.sex,1,' '),1,1),RPAD(' ',1,' '))                                   -- Field 74   SEX - Required
                   || NVL(SUBSTR (RPAD(emp_rec.marital_status,1,' '),1,1),RPAD(' ',1,' '))                        -- Field 75   MARITAL STATUS - Required
                   || RPAD(' ',1,' ')                                                        -- Field 76   FSE LSE INDICATOR ( Full or Part time indicator) - Send Blanks
                   || RPAD(' ',1,' ')                                                        -- Field 77   ROTH SAVE RATE USAGE INDICATOR - Send Blanks
                   || RPAD(' ',8,' ')                                                        -- Field 78   ELIGIBILITY DATE - Send Blanks
                   || NVL(SUBSTR (RPAD(UPPER( emp_rec.email_address),50,' '),1,50),RPAD(' ',50,' '))       -- Field 79   BUSINESS E-MAIL ADDRESS - Per_all_people_f.email_address /* 9.1 */
                   || RPAD(' ',8,' ')                                                        -- Field 80   USERRA START DATE - Send Blanks
                   || RPAD(' ',8,' ')                                                        -- Field 81   USERRA END DATE - Send Blanks
                   || RPAD(' ',8,' ')                                                        -- Field 82   LOA START DATE - Send Blanks
                   || RPAD(' ',8,' ')                                                        -- Field 83   LOA END DATE - Send Blanks
                   --|| RPAD(' ',9,' ')                                                      -- Field 84   FILLER - Send Blanks
                   || NVL(SUBSTR (RPAD(ttec_library.remove_non_ascii(v_emp_phone),10,' '),1,10),RPAD(' ',10,' '))             -- Field 84   FILLER - Employee home phone if none Mobile /* 9.0.6 */ chanhe from 9 character to 10 characters
                   ;

            utl_file.put_line(v_401k_file, v_rec);

            v_emp_count := v_emp_count + 1;
          END IF;  /* 9.2 */

        --END IF; --if NVL(v_Pre_Tax_401K_Elig_Comp_Amt,0) > 0 /* 2.3 */

    END LOOP; /* Employees */

    v_module := 'TRL Header';
    print_trailer_column_name;
    v_module := 'TRL OUTPUT';
    v_rec :=  'UTRL'                                                                      -- Field 1    RECORD TYPE-Populate UTRL
           ||'|'|| RPAD(' ',1,' ')                                                        -- Field 2    FILLER - Space filled or BLANK
           ||'|'|| SUBSTR (LPAD(v_emp_count + 2,8,'0'),1,8)                               -- Field 3    TOTAL RECORD COUNT - Total record count must include header and trailer
           ||'|'|| SUBSTR (LPAD('106263',6,'0'),1,6)                                      -- Field 4    ML PLAN NUMBER - Six-digit plan number (assigned by Merrill Lynch) -Populate 610115 * 9.0.1 */
           ||'|'|| RPAD(' ',79,' ')                                                       -- Field 5    FILLER - SEND SPACES
           ||'|'|| RPAD('A',3,' ')                                                        -- Field 6    SOURCE 1 LABEL- A for Employee Deferrals + Catchup; if catch up is combined with regular deferral
           ||'|'|| format_amount(v_tot_401K_amount ,11)                                   -- Field 7    #1 SOURCE CONTRIB DOLLAR TOTALS - Required. Element Name is Pre Tax 401K
           ||'|'|| RPAD(' ',4,' ')                                                        -- Field 8    FILLER - Send Blanks
          /* 9.0.4 */ --||'|'|| RPAD('Z',3,' ')                                                        -- Field 9    SOURCE 2 LABEL- Z Z for Catchup; if catchup is reported separately
           ||'|'|| RPAD('$',3,' ')                                                        -- Field 9    SOURCE 2 LABEL- Z Z for Catchup; if catchup is reported separately /* 9.0.4 */
           ||'|'|| format_amount(v_tot_401K_catchup_amount,11)                            -- Field 10   SOURCE 2  SOURCE CONTRIB DOLLAR TOTALS- Required. Element Name is Pre Tax 401K Catchup
           ||'|'|| RPAD(' ',4,' ')                                                        -- Field 11   FILLER - Send Blanks
--           ||'|'|| RPAD(' ',3,' ')                                                        -- Field 12   SOURCE 3 LABEL- X for ER Match
--           ||'|'|| '00000000000'                                                          -- Field 13   SOURCE 3  SOURCE CONTRIB DOLLAR TOTALS - Required. Element Name is Pre Tax 401K ER
           ||'|'|| RPAD('S ',3,' ')                                                     -- Field 12   SOURCE 3 LABEL- S for Base 401k Roth (TRP)  /* 11.0 */
           ||'|'|| format_amount(v_tot_401k_roth_amt ,11)    -- Field 13   SOURCE 3  SOURCE CONTRIB DOLLAR TOTALS - Required. Element Name is  'Base 401k Roth'  /* 11.0 */
           ||'|'|| RPAD(' ',4,' ')                                                        -- Field 14   FILLER - Send Blanks
--           ||'|'|| RPAD(' ',3,' ')                                                        -- Field 15   SOURCE 4 CONTRIB DOLLAR TOTALS - Send Blank
--           ||'|'|| '00000000000'                                                          -- Field 16   SOURCE 4 AMOUNT - Send 0's
           ||'|'|| RPAD('# ',3,' ')                                                        -- Field 15   SOURCE 4 CONTRIB DOLLAR TOTALS -  # for 'Base 401K Catch Up Roth' (TRP)  /* 11.0 */
           ||'|'|| format_amount(v_tot_401K_roth_catchup_amt ,11)          -- Field 16   SOURCE 4 AMOUNT - Required. Element Name is  'Base 401K Catch Up Roth' (TRP) /* 11.0 */
           ||'|'|| RPAD(' ',4,' ')                                                        -- Field 17   FILLER - Send Blanks
           ||'|'|| RPAD(' ',3,' ')                                                        -- Field 18   SOURCE 5 CONTRIB DOLLAR TOTALS - Send Blank
           ||'|'|| '00000000000'                                                          -- Field 19   SOURCE 5 AMOUNT - Send 0's
           ||'|'|| format_amount(v_tot_401K_amount
                               + v_tot_401K_catchup_amount
                               + v_tot_401k_roth_amt  /* 11.0 */
                               + v_tot_401K_roth_catchup_amt /* 11.0 */
                                 ,11)                                                     -- Field 20   TOTAL CONTRIBUTIONS - Total contributions amount, includes ALL sources; two implied decimals
           ||'|'|| format_amount(v_tot_401K_loan1_amount ,11)                             -- Field 21   TOTAL LOAN REPAYMENTS - Total loan amount; include ALL loans; two implied decimals
           ||'|'|| RPAD(' ',11,' ')                                                       -- Field 22   FILLER - Send Blanks
           ||'|'|| format_amount(v_tot_401K_amount
                         + v_tot_401K_catchup_amount
                               + v_tot_401k_roth_amt  /* 11.0 */
                               + v_tot_401K_roth_catchup_amt /* 11.0 */
                         + v_tot_401K_loan1_amount
                           ,11)                                                           -- Field 23   TOTAL PAYROLL DEPOSITS (EAA) - The TOTAL amount of contributions and loans on the file; should be the sum of Fields 20 & 21; two implied decimals
           ||'|'|| RPAD(' ',4,' ')                                                        -- Field 24   COMPANY NUMBER - If multiple files transmitted geographically, populate; if not should be space filled or BLANK -Send Blanks
           ||'|'|| RPAD(' ',368,' ')                                                      -- Field 25   FILLER - Send Blanks
           ;

    apps.fnd_file.put_line(apps.fnd_file.output,v_rec);
    v_module := 'TRL File';
    v_rec :=  'UTRL'                                                                 -- Field 1    RECORD TYPE-Populate UTRL
           || RPAD(' ',1,' ')                                                        -- Field 2    FILLER - Space filled or BLANK
           || SUBSTR (LPAD(v_emp_count + 2,8,'0'),1,8)                               -- Field 3    TOTAL RECORD COUNT - Total record count must include header and trailer
           || SUBSTR (LPAD('106263',6,'0'),1,6)                                      -- Field 4    ML PLAN NUMBER - Six-digit plan number (assigned by Merrill Lynch) -Populate 106263 /* 9.0.1 */
           || RPAD(' ',79,' ')                                                       -- Field 5    FILLER - SEND SPACES
           || RPAD('A',3,' ')                                                        -- Field 6    SOURCE 1 LABEL- A for Employee Deferrals + Catchup; if catch up is combined with regular deferral
           || format_amount(v_tot_401K_amount ,11)                                   -- Field 7    #1 SOURCE CONTRIB DOLLAR TOTALS - Required. Element Name is Pre Tax 401K
           || RPAD(' ',4,' ')                                                        -- Field 8    FILLER - Send Blanks
        /* 9.0.4 */   --|| RPAD('Z',3,' ')                                                        -- Field 9    SOURCE 2 LABEL- Z Z for Catchup; if catchup is reported separately
           || RPAD('$',3,' ')                                                        -- Field 9    SOURCE 2 LABEL- Z $ for Catchup; if catchup is reported separately /* 9.0.4 */
           || format_amount(v_tot_401K_catchup_amount,11)                            -- Field 10   SOURCE 2  SOURCE CONTRIB DOLLAR TOTALS- Required. Element Name is Pre Tax 401K Catchup
           || RPAD(' ',4,' ')                                                        -- Field 11   FILLER - Send Blanks
--           || RPAD(' ',3,' ')                                                        -- Field 12   SOURCE 3 LABEL- X for ER Match
--           || '00000000000'                                                          -- Field 13   SOURCE 3  SOURCE CONTRIB DOLLAR TOTALS - Required. Element Name is Pre Tax 401K ER
           || RPAD('S ',3,' ')                                                     -- Field 12   SOURCE 3 LABEL- S for Base 401k Roth (TRP)  /* 11.0 */
           || format_amount(v_tot_401k_roth_amt ,11)    -- Field 13   SOURCE 3  SOURCE CONTRIB DOLLAR TOTALS - Required. Element Name is  'Base 401k Roth'  /* 11.0 */
           || RPAD(' ',4,' ')                                                        -- Field 14   FILLER - Send Blanks
--           || RPAD(' ',3,' ')                                                        -- Field 15   SOURCE 4 CONTRIB DOLLAR TOTALS - Send Blank
--           || '00000000000'                                                          -- Field 16   SOURCE 4 AMOUNT - Send 0's
           ||  RPAD('# ',3,' ')                                                        -- Field 15   SOURCE 4 CONTRIB DOLLAR TOTALS -  # for 'Base 401K Catch Up Roth' (TRP)  /* 11.0 */
           || format_amount(v_tot_401K_roth_catchup_amt ,11)          -- Field 16   SOURCE 4 AMOUNT - Required. Element Name is  'Base 401K Catch Up Roth' (TRP) /* 11.0 */
           || RPAD(' ',4,' ')                                                        -- Field 17   FILLER - Send Blanks
           || RPAD(' ',3,' ')                                                        -- Field 18   SOURCE 5 CONTRIB DOLLAR TOTALS - Send Blank
           || '00000000000'                                                          -- Field 19   SOURCE 5 AMOUNT - Send 0's
           || format_amount(v_tot_401K_amount
                               + v_tot_401K_catchup_amount
                               + v_tot_401k_roth_amt  /* 11.0 */
                               + v_tot_401K_roth_catchup_amt /* 11.0 */
                                 ,11)                                                -- Field 20   TOTAL CONTRIBUTIONS - Total contributions amount, includes ALL sources; two implied decimals
           || format_amount(v_tot_401K_loan1_amount ,11)                             -- Field 21   TOTAL LOAN REPAYMENTS - Total loan amount; include ALL loans; two implied decimals
           || RPAD(' ',11,' ')                                                       -- Field 22   FILLER - Send Blanks
           || format_amount(v_tot_401K_amount
                         + v_tot_401K_catchup_amount
                               + v_tot_401k_roth_amt  /* 11.0 */
                               + v_tot_401K_roth_catchup_amt /* 11.0 */
                         + v_tot_401K_loan1_amount
                           ,11)                                                      -- Field 23   TOTAL PAYROLL DEPOSITS (EAA) - The TOTAL amount of contributions and loans on the file; should be the sum of Fields 20 & 21; two implied decimals
           || RPAD(' ',4,' ')                                                        -- Field 24   COMPANY NUMBER - If multiple files transmitted geographically, populate; if not should be space filled or BLANK -Send Blanks
           || RPAD(' ',368,' ')                                                      -- Field 25   FILLER - Send Blanks
           ;

    utl_file.put_line(v_401k_file, v_rec);

    UTL_FILE.FCLOSE(v_401k_file);

    EXCEPTION
    WHEN UTL_FILE.INVALID_OPERATION THEN
        UTL_FILE.FCLOSE(v_401k_file);
        RAISE_APPLICATION_ERROR(-20051, p_FileName ||':  Invalid Operation');

    WHEN UTL_FILE.INVALID_FILEHANDLE THEN
        UTL_FILE.FCLOSE(v_401k_file);
        RAISE_APPLICATION_ERROR(-20052, p_FileName ||':  Invalid File Handle');

    WHEN UTL_FILE.READ_ERROR THEN
        UTL_FILE.FCLOSE(v_401k_file);
        RAISE_APPLICATION_ERROR(-20053, p_FileName ||':  Read Error');
        ROLLBACK;
    WHEN UTL_FILE.INVALID_PATH THEN
        UTL_FILE.FCLOSE(v_401k_file);
        RAISE_APPLICATION_ERROR(-20054, p_FileDir ||':  Invalid Path');

    WHEN UTL_FILE.INVALID_MODE THEN
        UTL_FILE.FCLOSE(v_401k_file);
        RAISE_APPLICATION_ERROR(-20055, p_FileName ||':  Invalid Mode');

    WHEN UTL_FILE.WRITE_ERROR THEN
        UTL_FILE.FCLOSE(v_401k_file);
        RAISE_APPLICATION_ERROR(-20056, p_FileName ||':  Write Error');

    WHEN UTL_FILE.INTERNAL_ERROR THEN
        UTL_FILE.FCLOSE(v_401k_file);
        RAISE_APPLICATION_ERROR(-20057, p_FileName ||':  Internal Error');

    WHEN UTL_FILE.INVALID_MAXLINESIZE THEN
         UTL_FILE.FCLOSE(v_401k_file);
         RAISE_APPLICATION_ERROR(-20058, p_FileName ||':  Maxlinesize Error');

    WHEN INVALID_CURSOR
    THEN

         UTL_FILE.FCLOSE(v_401k_file);

         ttec_error_logging.process_error( g_application_code -- 'BEN'
                                         , g_interface        -- 'BOA 401K Intf';
                                         , g_package          -- 'TTEC_TROWE_401K_OUTBOUND_INT'
                                         , v_module
                                         , g_failure_status
                                         , SQLCODE
                                         , SQLERRM
                                         , g_label1
                                         , v_loc
                                         , g_label2
                                         , g_emp_no );

          errcode  := SQLCODE;
          errbuff  := SUBSTR (SQLERRM, 1, 255);

    WHEN OTHERS
    THEN
         UTL_FILE.FCLOSE(v_401k_file);

         ttec_error_logging.process_error( g_application_code -- 'BEN'
                                         , g_interface        -- 'BOA 401K Intf';
                                         , g_package          -- 'TTEC_TROWE_401K_OUTBOUND_INT'
                                         , v_module
                                         , g_failure_status
                                         , SQLCODE
                                         , SQLERRM
                                         , g_label1
                                         , v_loc
                                         , g_label2
                                         , g_emp_no );

          errcode  := SQLCODE;
          errbuff  := SUBSTR (SQLERRM, 1, 255);

        RAISE_APPLICATION_ERROR(-20003,'Exception OTHERS in TTEC_TROWE_401K_OUTBOUND_INT.main: '||'Module >-' ||v_module||' ['||g_label1||']['||v_loc||']['||g_label2||']['||g_emp_no|| '] ERROR:'||errbuff);
    END main;

END TTEC_TROWE_401K_OUTBOUND_INT;
/
show errors;
/