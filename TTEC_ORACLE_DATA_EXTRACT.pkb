create or replace PACKAGE BODY TTEC_ORACLE_DATA_EXTRACT AS



 /************************************************************************************
        Program Name: TTEC_ORACLE_DATA_EXTRACT 

        Description:   

        Developed by : 
        Date         :  

       Modification Log
       Name                  Version #    Date            Description
       -----                 --------     -----           -------------
    RXNETHI(ARGANO)            1.0      17-May-2023      R12.2 Upgrade Remediation
    ****************************************************************************************/

----------------------------------------------------------------------
----------------------------< write_data >----------------------------
----------------------------------------------------------------------
-- Private procedure to simplify the writing of data to output
-- and log files (timestamp added for log file)
-- Called only from within cust.ttec_oracle_data_extract package
----------------------------------------------------------------------

PROCEDURE write_data (p_where IN VARCHAR2,
                      p_text IN VARCHAR2)

IS

BEGIN

-----------------------------------------------------------------------
-- Add time stamp to incoming text and write to log file

IF p_where = 'L' OR p_where = 'B'
  THEN apps.fnd_file.put_line(apps.fnd_file.LOG,TO_CHAR(SYSDATE,'HH24:MI:SS')||'  '||p_text);
END IF;


-----------------------------------------------------------------------
-- Write incoming text to output file

IF p_where = 'O' OR p_where = 'B'
  THEN apps.fnd_file.put_line(apps.fnd_file.output,p_text);
END IF;


END write_data;


----------------------------------------------------------------------
--------------------------< get_job_title >---------------------------
----------------------------------------------------------------------
-- Private function to accurately identify and return the job title
-- as of the input effective date
-- Called only from within cust.ttec_oracle_data_extract package
----------------------------------------------------------------------

FUNCTION get_job_title (p_assignment_id IN NUMBER, p_effective_date IN DATE)
  RETURN VARCHAR2 IS

v_job_id        NUMBER;
v_job_title     VARCHAR2(200);
v_asg_date      DATE;

BEGIN

  ---------------------------------------------------------------------
  -- Identify job ID from accurately dated assignment record

  SELECT effective_start_date, job_id
  INTO v_asg_date, v_job_id
  FROM apps.per_all_assignments_f
  WHERE assignment_id = p_assignment_id
    AND p_effective_date BETWEEN effective_start_date AND effective_end_date;

  ---------------------------------------------------------------------
  -- Using job ID identified above, set job title to output parameter

  SELECT pjd.segment2
  INTO v_job_title
  FROM apps.per_jobs pj,
       apps.per_job_definitions pjd
  WHERE pj.job_definition_id = pjd.job_definition_id
    AND pj.job_id = v_job_id
    AND v_asg_date BETWEEN date_from AND NVL(date_to,'31-DEC-4712');

  RETURN v_job_title;

  ---------------------------------------------------------------------
  -- Exception rule for when no job title is found meeting criteria

  EXCEPTION WHEN NO_DATA_FOUND THEN v_job_title := '<none>';

  RETURN v_job_title;

END get_job_title;


----------------------------------------------------------------------
-----------------------< get_oracle_balances >------------------------
----------------------------------------------------------------------
-- Private procedure to get payroll balances from oracle tables
-- primarily pay_run_balances
-- Called only from within cust.ttec_oracle_data_extract package
----------------------------------------------------------------------

PROCEDURE get_oracle_balances (i_assignment_action_id IN NUMBER,
                               o_gross_pay OUT NUMBER,
                               o_hours_worked OUT NUMBER,
                               o_ot_hours OUT NUMBER,
                               o_other_hours OUT NUMBER,
                               o_gross_by_hours OUT NUMBER,
                               o_retro_pay OUT NUMBER,
                               o_retro_base_wage OUT NUMBER)

IS

BEGIN

  ---------------------------------------------------------------------
  -- Obtain value for gross pay (if any) for current check record

  BEGIN

    SELECT NVL(balance_value,0)
    INTO o_gross_pay
    FROM apps.pay_run_balances prb,
         apps.pay_defined_balances pdb,
         apps.pay_balance_types pbt
    WHERE prb.defined_balance_id = pdb.defined_balance_id
      AND pdb.balance_type_id = pbt.balance_type_id
      AND pbt.balance_name = 'Gross Earnings'
      AND (pbt.legislation_code = 'US' OR pbt.business_group_id = 325)
      AND prb.assignment_action_id = i_assignment_action_id;

    EXCEPTION WHEN NO_DATA_FOUND THEN o_gross_pay := 0;

  END;

  write_data('L','  Gross Pay: '||o_gross_pay);

  ---------------------------------------------------------------------
  -- Obtain value for hours worked (if any) for current check record

  BEGIN

    SELECT NVL(SUM(balance_value),0)
    INTO o_hours_worked
    FROM apps.pay_run_balances prb,
         apps.pay_defined_balances pdb,
         apps.pay_balance_types pbt
    WHERE prb.defined_balance_id = pdb.defined_balance_id
      AND pdb.balance_type_id = pbt.balance_type_id
      AND (pbt.legislation_code = 'US' OR pbt.business_group_id = 325)
      AND prb.assignment_action_id = i_assignment_action_id
      AND pbt.balance_name IN (/*'Regular Hours Worked',*/
                               'Coaching Hours',
                               'Nesting Hours',
                               'Regular Hours Hours',
                               'TT Time Entry Wages Hours',
                               'TempProj Rate Hours',
                               'Training Assistant Hours',
                               'Training Hours',
                               'US Regular Salary Hours',
                               'Up_Training Hours');

    EXCEPTION WHEN NO_DATA_FOUND THEN o_hours_worked := 0;

  END;

  write_data('L','  Hours Worked: '||o_hours_worked);

  ---------------------------------------------------------------------
  -- Obtain value for overtime hours (if any) for current check record

  BEGIN

    SELECT NVL(SUM(balance_value),0)
    INTO o_ot_hours
    FROM apps.pay_run_balances prb,
         apps.pay_defined_balances pdb,
         apps.pay_balance_types pbt
    WHERE prb.defined_balance_id = pdb.defined_balance_id
      AND pdb.balance_type_id = pbt.balance_type_id
      AND (pbt.legislation_code = 'US' OR pbt.business_group_id = 325)
      AND prb.assignment_action_id = i_assignment_action_id
      AND pbt.balance_name IN ('Overtime 1_5 Hours',
                               'Overtime_2x Hours');

    EXCEPTION WHEN NO_DATA_FOUND THEN o_ot_hours := 0;

  END;

  write_data('L','  Hours Overtime: '||o_ot_hours);


  ---------------------------------------------------------------------
  -- Obtain value for other hours (if any) for current check record

  BEGIN

    SELECT NVL(SUM(balance_value),0)
    INTO o_other_hours
    FROM apps.pay_run_balances prb,
         apps.pay_defined_balances pdb,
         apps.pay_balance_types pbt
    WHERE prb.defined_balance_id = pdb.defined_balance_id
      AND pdb.balance_type_id = pbt.balance_type_id
      AND (pbt.legislation_code = 'US' OR pbt.business_group_id = 325)
      AND prb.assignment_action_id = i_assignment_action_id
      AND pbt.balance_name IN ('Bereavement Hours',
                               'Bereavement Pay Hours',
                               'Holiday Hours',
                               'Holiday Pay Hours',
                               'Hours Paid but not Worked Hours',
                               'Jury Duty Hours',
                               'Jury Hours',
                               'PTO Hours',
                               'PTO Payout Hours',
                               'Personal Holiday Taken Hours',
                               'Severance Hours',
                               'Sick Bank Hours',
                               'Sick Bank Payout Hours',
                               'Sick Payout Hours',
                               'Sick Taken Hours',
                               'Vacation Payout Hours',
                               'Vacation Taken Hours');

    EXCEPTION WHEN NO_DATA_FOUND THEN o_other_hours := 0;

  END;

  write_data('L','  Hours Other: '||o_other_hours);


  ---------------------------------------------------------------------
  -- Calculate gross pay divided by hours worked, account for divide by 0

  IF o_hours_worked <> 0
    THEN o_gross_by_hours := ROUND(o_gross_pay / o_hours_worked,2);
    ELSE o_gross_by_hours := 0;
  END IF;

  write_data('L','  Gross / Hours: '||o_gross_by_hours);

  ---------------------------------------------------------------------
  -- Obtain value for retro pay (if any) for current check record

  BEGIN

    SELECT NVL(balance_value,0)
    INTO o_retro_pay
    FROM apps.pay_run_balances prb,
         apps.pay_defined_balances pdb,
         apps.pay_balance_types pbt
    WHERE prb.defined_balance_id = pdb.defined_balance_id
      AND pdb.balance_type_id = pbt.balance_type_id
      AND pbt.balance_name = 'Retroactive Pay'
      AND prb.assignment_action_id = i_assignment_action_id;

    EXCEPTION WHEN NO_DATA_FOUND THEN o_retro_pay := 0;

  END;

  write_data('L','  Retro Pay: '||o_retro_pay);


  ---------------------------------------------------------------------
  -- Obtain value for retro base wage (if any) for current check record

  BEGIN

    SELECT NVL(balance_value,0)
    INTO o_retro_base_wage
    FROM apps.pay_run_balances prb,
         apps.pay_defined_balances pdb,
         apps.pay_balance_types pbt
    WHERE prb.defined_balance_id = pdb.defined_balance_id
      AND pdb.balance_type_id = pbt.balance_type_id
      AND pbt.balance_name = 'Retro Base Wage'
      AND prb.assignment_action_id = i_assignment_action_id;

    EXCEPTION WHEN NO_DATA_FOUND THEN o_retro_base_wage := 0;

  END;

  write_data('L','  Retro Base Wage: '||o_retro_base_wage);

END get_oracle_balances;


----------------------------------------------------------------------
------------------------< get_kbace_balances >------------------------
----------------------------------------------------------------------
-- Private procedure to get payroll balances from KBACE tables
-- primarily xkb_balance_details
-- Called only from within cust.ttec_oracle_data_extract package
----------------------------------------------------------------------

PROCEDURE get_kbace_balances (i_assignment_action_id IN NUMBER,
                              o_gross_pay OUT NUMBER,
                              o_hours_worked OUT NUMBER,
                              o_ot_hours OUT NUMBER,
                              o_other_hours OUT NUMBER,
                              o_gross_by_hours OUT NUMBER,
                              o_retro_pay OUT NUMBER,
                              o_retro_base_wage OUT NUMBER)

IS

BEGIN

  ---------------------------------------------------------------------
  -- Obtain value for gross pay (if any) for current check record

  BEGIN

    SELECT NVL(xbd.balance_value,0)
	INTO o_gross_pay
	--FROM kbace.xkb_balance_details xbd,    --code commented by RXNETHI,17/05/23
	FROM apps.xkb_balance_details xbd,       --code added by RXNETHI,17/05/23
	     apps.pay_balance_types pbt
	WHERE xbd.assignment_action_id = i_assignment_action_id
	  AND xbd.balance_type_id = pbt.balance_type_id
	  AND pbt.balance_name = 'Gross Earnings';

	EXCEPTION WHEN NO_DATA_FOUND THEN o_gross_pay := 0;

  END;

  write_data('L','  Gross Pay: '||o_gross_pay);

  ---------------------------------------------------------------------
  -- Obtain value for hours worked (if any) for current check record

  BEGIN

    SELECT NVL(SUM(xbd.balance_value),0)
	INTO o_hours_worked
	--FROM kbace.xkb_balance_details xbd,     --code commented by RXNETHI,17/05/23
	FROM apps.xkb_balance_details xbd,        --code added by RXNETHI,17/05/23
	     apps.pay_balance_types pbt
	WHERE xbd.assignment_action_id = i_assignment_action_id
	  AND xbd.balance_type_id = pbt.balance_type_id
	  AND pbt.balance_name IN (/*'Regular Hours Worked',*/
                               'Coaching Hours',
                               'Nesting Hours',
                               'Regular Hours Hours',
                               'TT Time Entry Wages Hours',
                               'TempProj Rate Hours',
                               'Training Assistant Hours',
                               'Training Hours',
                               'US Regular Salary Hours',
                               'Up_Training Hours');

	EXCEPTION WHEN NO_DATA_FOUND THEN o_hours_worked := 0;

  END;

  write_data('L','  Hours Worked: '||o_hours_worked);

  ---------------------------------------------------------------------
  -- Obtain value for overtmie hours (if any) for current check record

  BEGIN

    SELECT NVL(SUM(xbd.balance_value),0)
	INTO o_ot_hours
	--FROM kbace.xkb_balance_details xbd,     --code commented by RXNETHI,17/05/23
	FROM apps.xkb_balance_details xbd,        --code added by RXNETHI,17/05/23
	     apps.pay_balance_types pbt
	WHERE xbd.assignment_action_id = i_assignment_action_id
	  AND xbd.balance_type_id = pbt.balance_type_id
	  AND pbt.balance_name IN ('Overtime 1_5 Hours',
                               'Overtime_2x Hours');

	EXCEPTION WHEN NO_DATA_FOUND THEN o_ot_hours := 0;

  END;

  write_data('L','  Hours Overtime: '||o_ot_hours);

  ---------------------------------------------------------------------
  -- Obtain value for other hours (if any) for current check record

  BEGIN

    SELECT NVL(SUM(xbd.balance_value),0)
	INTO o_other_hours
	--FROM kbace.xkb_balance_details xbd,     --code commented by RXNETHI,17/05/23
	FROM apps.xkb_balance_details xbd,        --code added by RXNETHI,17/05/23
	     apps.pay_balance_types pbt
	WHERE xbd.assignment_action_id = i_assignment_action_id
	  AND xbd.balance_type_id = pbt.balance_type_id
	  AND pbt.balance_name IN ('Bereavement Hours',
                               'Bereavement Pay Hours',
                               'Holiday Hours',
                               'Holiday Pay Hours',
                               'Hours Paid but not Worked Hours',
                               'Jury Duty Hours',
                               'Jury Hours',
                               'PTO Hours',
                               'PTO Payout Hours',
                               'Personal Holiday Taken Hours',
                               'Severance Hours',
                               'Sick Bank Hours',
                               'Sick Bank Payout Hours',
                               'Sick Payout Hours',
                               'Sick Taken Hours',
                               'Vacation Payout Hours',
                               'Vacation Taken Hours');

	EXCEPTION WHEN NO_DATA_FOUND THEN o_other_hours := 0;

  END;

  write_data('L','  Hours Other: '||o_other_hours);

  ---------------------------------------------------------------------
  -- Calculate gross pay divided by hours worked, account for divide by 0

  IF o_hours_worked <> 0
    THEN o_gross_by_hours := ROUND(o_gross_pay / o_hours_worked,2);
    ELSE o_gross_by_hours := 0;
  END IF;

  write_data('L','  Gross / Hours: '||o_gross_by_hours);

  ---------------------------------------------------------------------
  -- Obtain value for retro pay (if any) for current check record

  BEGIN

    SELECT NVL(xbd.balance_value,0)
	INTO o_retro_pay
	--FROM kbace.xkb_balance_details xbd,     --code commented by RXNETHI,17/05/23
	FROM apps.xkb_balance_details xbd,        --code added by RXNETHI,17/05/23
	     apps.pay_balance_types pbt
	WHERE xbd.assignment_action_id = i_assignment_action_id
	  AND xbd.balance_type_id = pbt.balance_type_id
	  AND pbt.balance_name = 'Retroactive Pay';

	EXCEPTION WHEN NO_DATA_FOUND THEN o_retro_pay := 0;

  END;

  write_data('L','  Retro Pay: '||o_retro_pay);

  ---------------------------------------------------------------------
  -- Obtain value for retro base wage (if any) for current check record

  BEGIN

    SELECT NVL(xbd.balance_value,0)
	INTO o_retro_base_wage
	--FROM kbace.xkb_balance_details xbd,    --code commented by RXNETHI,17/05/23
	FROM apps.xkb_balance_details xbd,       --code added by RXNETHI,17/05/23
	     apps.pay_balance_types pbt
	WHERE xbd.assignment_action_id = i_assignment_action_id
	  AND xbd.balance_type_id = pbt.balance_type_id
	  AND pbt.balance_name = 'Retro Base Wage';

	EXCEPTION WHEN NO_DATA_FOUND THEN o_retro_base_wage := 0;

  END;

  write_data('L','  Retro Base Wage: '||o_retro_base_wage);


END get_kbace_balances;

----------------------------------------------------------------------
------------------------------< hr_data >-----------------------------
----------------------------------------------------------------------
-- procedure for spooling through HR records for input location and
-- finding all assignment and/or pay proposal table changes that
-- occurred during the input date range
----------------------------------------------------------------------


PROCEDURE hr_data (o_errbuf     OUT  VARCHAR2,
                   o_retcode    OUT  NUMBER,
                   p_location   IN   VARCHAR2,
                   p_date_from  IN   VARCHAR2,
                   p_date_to    IN   VARCHAR2)

IS


-----------------------------------------------------------------------
-- Declare local constants

vc_delimiter         CONSTANT   VARCHAR2(10)  := '|';


-----------------------------------------------------------------------
-- Declare local variables

v_date_from          DATE; --VARCHAR2(20);
v_date_to            DATE; --VARCHAR2(20);
v_header             VARCHAR2(2000);
v_message            VARCHAR2(2000);
v_eff_date           VARCHAR2(200);
v_change_reason      VARCHAR2(200);
v_salary             apps.per_pay_proposals.proposed_salary_n%TYPE;
v_asg_line_created   VARCHAR2(1) := 'N';
v_asg_line_written   VARCHAR2(1) := 'N';
v_valid_asg          VARCHAR2(1) := 'N';
v_valid_pay          VARCHAR2(1) := 'N';
v_sal_loop           VARCHAR2(1) := 'N';
v_current_asg_id     apps.per_all_assignments_f.assignment_id%TYPE := -1;
v_job_title          VARCHAR2(200);


-----------------------------------------------------------------------
-- cursor for gathering HR data from Oracle

CURSOR c_get_HR_asg_data IS

SELECT DISTINCT
  papf.employee_number,
  papf.full_name,
  papf.national_identifier AS SSN,
  paaf.job_id,
  pps.date_start AS hire_date,
  pps.actual_termination_date AS term_date,
  paaf.effective_start_date AS effective_date,
  NVL(apps.hr_general.decode_lookup('EMP_ASSIGN_REASON',paaf.change_reason),'Assignment Change (Unknown)') AS change_reason,
  paaf.effective_start_date,
  paaf.effective_end_date,
  paaf.assignment_id
FROM apps.per_all_people_f papf,
     apps.per_all_assignments_f paaf,
     apps.per_periods_of_service pps
WHERE papf.person_id = paaf.person_id
  AND paaf.period_of_service_id = pps.period_of_service_id
  AND paaf.effective_start_date BETWEEN papf.effective_start_date AND papf.effective_end_date
  AND paaf.location_id = p_location
  AND papf.business_group_id = 325
--  and papf.person_id = 149767  -- TEMPORARY RESTRICTION FOR TESTING
ORDER BY 2,7;


-----------------------------------------------------------------------
-- cursor for cycling through per_pay_proposals and finding current pay record

CURSOR c_get_HR_sal_data (p_asg_id IN NUMBER) IS

SELECT DISTINCT
  ppp.change_date,
  ppp.proposal_reason AS change_reason,
  ppp.proposed_salary_n AS pay_rate
FROM apps.per_pay_proposals ppp
WHERE ppp.assignment_id = p_asg_id
ORDER BY 1;

r_get_HR_sal_data c_get_HR_sal_data%ROWTYPE;

BEGIN

-----------------------------------------------------------------------
-- Error message and code for successful run

o_errbuf   := 'Request completed successfully';
o_retcode  := 0;


write_data('L','Beginning ttec_oracle_data_pull.hr_data');

-----------------------------------------------------------------------
-- Write input parameters to log file

write_data('L','Input Parameters');
write_data('L',' ');
write_data('L','Location:  '||p_location);
write_data('L','Date From: '||p_date_from);
write_data('L','Date To:   '||p_date_to);
write_data('L','+---------------------------------------------------------------------------+');

-----------------------------------------------------------------------
-- Convert input dates (input as VARCHAR2) to DATE

v_date_from      := apps.fnd_date.canonical_to_date(p_date_from);
v_date_to        := apps.fnd_date.canonical_to_date(p_date_to);

-----------------------------------------------------------------------
-- Define header row and write to output file

v_header := 'Employee ID'     ||  vc_delimiter  ||
            'Name'            ||  vc_delimiter  ||
            'SSN'             ||  vc_delimiter  ||
            'Job Title'       ||  vc_delimiter  ||
            'Comp Rate'       ||  vc_delimiter  ||
            'Hire Date'       ||  vc_delimiter  ||
            'Term Date'       ||  vc_delimiter  ||
            'Effective Date'  ||  vc_delimiter  ||
            'Change Reason';

write_data('O',v_header);

-----------------------------------------------------------------------
-- Loop through HR data

write_data('L','Starting employee loop');

FOR c_emp IN c_get_HR_asg_data LOOP

  write_data('L','Person Name: '||C_emp.full_name);

  ---------------------------------------------------------------------
  -- Determine if current loop is for same assigment as previous loop

  IF v_current_asg_id <> c_emp.assignment_id
    THEN v_current_asg_id := c_emp.assignment_id;
         v_sal_loop     := 'N';
  END IF;

  ---------------------------------------------------------------------
  -- Initialize/reset variables for determining output line status

  v_asg_line_created := 'N';
  v_asg_line_written := 'N';

  ---------------------------------------------------------------------
  -- Determine if current assignment record meets date criteria

  IF c_emp.effective_date BETWEEN v_date_from AND v_date_to
    THEN v_valid_asg := 'Y';
    ELSE v_valid_asg := 'N';
  END IF;

  write_data('L','  Assignment Dates: '||c_emp.effective_start_date||' - '||c_emp.effective_end_date||'  Valid: '||v_valid_asg);

  ---------------------------------------------------------------------
  -- Loop through salary cursor to get current rate then output line

  IF v_valid_asg = 'Y'
    THEN FOR c_emp_pay IN c_get_HR_sal_data (c_emp.assignment_id) LOOP

     ------------------------------------------------------------------
     -- LOOP logic
     -- if pay change date is less than assignment date
     --   then set variables
     --   else write info to output file

     IF c_emp_pay.change_date <= c_emp.effective_start_date

       THEN v_eff_date      := c_emp_pay.change_date;
            v_change_reason := NVL(apps.hr_general.decode_lookup('PROPOSAL_REASON',c_emp_pay.change_reason),'Pay Change (Unknown)');
            v_salary        := c_emp_pay.pay_rate;

            write_data('L','IF 1: '||v_eff_date||' '||v_change_reason||' '||v_salary||'  NOT WRITTEN YET');

       ELSE v_job_title := get_job_title(c_emp.assignment_id, c_emp.effective_date);

            v_message := c_emp.employee_number     ||  vc_delimiter  ||
                         c_emp.full_name           ||  vc_delimiter  ||
                         c_emp.SSN                 ||  vc_delimiter  ||
                         v_job_title               ||  vc_delimiter  ||
                         v_salary                  ||  vc_delimiter  ||
                         c_emp.hire_date           ||  vc_delimiter  ||
                         c_emp.term_date           ||  vc_delimiter  ||
                         c_emp.effective_date      ||  vc_delimiter  ||
                         'Asg - '||c_emp.change_reason;

            IF v_valid_asg = 'Y' AND v_asg_line_written <> 'Y'
              THEN write_data('B',v_message);
                   write_data('L','FIRST LOOP WRITE STATEMENT');
                   v_asg_line_written := 'Y';
            END IF;

     END IF;        /** c_emp_pay.change_date <= c_emp.effective_start_date **/

    END LOOP;       /** FOR c_emp_pay IN c_get_HR_sal_data **/

  END IF;           /** IF v_valid_asg = 'Y' **/


  ---------------------------------------------------------------------
  -- If salary loop has not been run yet for this employee, start
  -- salary loop (loop runs just once for each employee to avoid
  -- duplicate data)

  IF v_sal_loop = 'N' THEN FOR c_emp_pay2 IN c_get_HR_sal_data (c_emp.assignment_id) LOOP

    -------------------------------------------------------------------
    -- If salary change date is between input parameters, write to
    -- output file

    IF c_emp_pay2.change_date BETWEEN v_date_from AND v_date_to
      THEN v_job_title := get_job_title(c_emp.assignment_id, c_emp_pay2.change_date);

           v_message := c_emp.employee_number    ||  vc_delimiter  ||
                        c_emp.full_name          ||  vc_delimiter  ||
                        c_emp.SSN                ||  vc_delimiter  ||
                        v_job_title              ||  vc_delimiter  ||
                        c_emp_pay2.pay_rate      ||  vc_delimiter  ||
                        c_emp.hire_date          ||  vc_delimiter  ||
                        c_emp.term_date          ||  vc_delimiter  ||
                        c_emp_pay2.change_date   ||  vc_delimiter  ||
                        'Pay - '||NVL(apps.hr_general.decode_lookup('PROPOSAL_REASON',c_emp_pay2.change_reason),'Pay Change (Unknown)');

           v_asg_line_created := 'Y';

           write_data('B',v_message);
           write_data('L','SECOND LOOP WRITE STATEMENT   '||c_emp_pay2.change_date);
           v_asg_line_written := 'Y';
           v_sal_loop := 'Y';

    END IF;  /** IF c_emp_pay.change_date BETWEEN v_date_from AND v_date_to  **/

   END LOOP;  /** FOR c_emp_pay2 IN IN c_get_HR_sal_data  **/

  END IF;     /** IF v_sal_loop = 'N' **/

--     END IF;        /** c_emp_pay.change_date <= c_emp.effective_start_date **/


  write_data('L','Out of loop, written = '||v_asg_line_written||', created = '||v_asg_line_created||', valid = '||v_valid_asg);

  ---------------------------------------------------------------------
  -- Confirm current line has been written to output file, if not write line

  IF v_asg_line_written = 'N' AND v_valid_asg = 'Y'

    THEN IF v_asg_line_created = 'Y'

           THEN write_data('O',v_message);
                write_data('L','After salary loop if, N Y');

           ELSE IF v_asg_line_created = 'N'
                  THEN v_job_title := get_job_title(c_emp.assignment_id, c_emp.effective_date);

                       v_message := c_emp.employee_number     ||'|'||
                                    c_emp.full_name           ||'|'||
                                    c_emp.SSN                 ||'|'||
                                    v_job_title               ||'|'||
                                    v_salary                  ||'|'||
                                    c_emp.hire_date           ||'|'||
                                    c_emp.term_date           ||'|'||
                                    c_emp.effective_date      ||'|'||
                                    'Asg - '||c_emp.change_reason;

                write_data('O',v_message);
                write_data('L','After salary loop if, N N');

                END IF;  /** IF v_asg_line_created = 'N' **/

          END IF;        /** IF v_asg_line_created = 'Y' **/

  END IF;                /** IF v_asg_line_written = 'N' **/

END LOOP;                /** FOR c_emp IN c_get_HR_asg_data **/


-----------------------------------------------------------------------
-- Error message and code for unsuccessful run

EXCEPTION
  WHEN OTHERS THEN
   o_errbuf   := 'Request encountered unexpected error: '||SQLERRM;
   o_retcode  := 2;


END hr_data;


----------------------------------------------------------------------
----------------------------< payroll_data >--------------------------
----------------------------------------------------------------------
-- procedure for spooling through payroll records and retrieving all
-- pay records for the input location whose check date falls between
-- the input date range
----------------------------------------------------------------------

PROCEDURE payroll_data (o_errbuf     OUT  VARCHAR2,
                        o_retcode    OUT  NUMBER,
                        p_location   IN   VARCHAR2,
                        p_date_from  IN   VARCHAR2,
                        p_date_to    IN   VARCHAR2)

IS


-----------------------------------------------------------------------
-- Declare local constants

vc_retro_base_wage   CONSTANT   VARCHAR2(200) := NULL;
vc_delimiter         CONSTANT   VARCHAR2(10)  := '|';

-----------------------------------------------------------------------
-- Declare local variables

v_date_from        VARCHAR2(20);
v_date_to          VARCHAR2(20);
v_header           VARCHAR2(2000);
v_message          VARCHAR2(2000);
v_gross_pay        NUMBER;
v_hours_worked     NUMBER;
v_hours_ot         NUMBER;
v_hours_other      NUMBER;
v_gross_by_hours   NUMBER;
v_retro_pay        NUMBER;
v_retro_base_wage  NUMBER;
v_hourly_rate      NUMBER;
v_total            NUMBER;


-----------------------------------------------------------------------
-- cursor for gathering base payroll data from Oracle

CURSOR c_get_payroll_data IS

SELECT DISTINCT
  papf.full_name,
  papf.employee_number,
  hla.location_id AS location_code,
  ppa.effective_date AS check_date,
  paa.assignment_action_id,
  ppa.date_earned AS payroll_period,
  paaf.assignment_id
FROM apps.per_all_people_f papf,
     apps.per_all_assignments_f paaf,
	 apps.pay_assignment_actions paa,
	 apps.pay_payroll_actions ppa,
	 apps.hr_locations_all hla
WHERE papf.person_id = paaf.person_id
  AND paaf.assignment_id = paa.assignment_id
  AND paa.payroll_action_id = ppa.payroll_action_id
  AND paaf.location_id = hla.location_id
  AND paaf.location_id = p_location
  AND paa.run_type_id IS NOT NULL
  AND ppa.effective_date BETWEEN papf.effective_start_date AND papf.effective_end_date
  AND ppa.effective_date BETWEEN paaf.effective_start_date AND paaf.effective_end_date
--  AND papf.person_id = 38933
  AND papf.business_group_id = 325
  AND ppa.effective_date BETWEEN v_date_from AND v_date_to
ORDER BY papf.full_name, ppa.effective_date;


-----------------------------------------------------------------------
-- cursor for getting accurate pay rate as of check date

CURSOR c_hourly_rate_at_check_date (p_assignment_id IN NUMBER) IS

SELECT DISTINCT
  ppp.change_date,
  ROUND((ppp.proposed_salary_n * ppb.pay_annualization_factor) / 2080, 2) AS hourly_rate
FROM apps.per_pay_proposals ppp,
     apps.per_all_assignments_f paaf,
     apps.per_pay_bases ppb
WHERE ppp.assignment_id = p_assignment_id
  AND ppp.assignment_id = paaf.assignment_id
  AND paaf.pay_basis_id = ppb.pay_basis_id
  AND ppp.change_date BETWEEN paaf.effective_start_date AND paaf.effective_end_date
ORDER BY ppp.change_date;


BEGIN

-----------------------------------------------------------------------
-- Error message and code for successful run

o_errbuf   := 'Request completed successfully';
o_retcode  := 0;


write_data('L','Beginning ttec_oracle_data_pull.payroll_data');

-----------------------------------------------------------------------
-- Write input parameters to log file

write_data('L','Input Parameters');
write_data('L',' ');
write_data('L','Location:  '||p_location);
write_data('L','Date From: '||p_date_from);
write_data('L','Date To:   '||p_date_to);
write_data('L','+---------------------------------------------------------------------------+');


-----------------------------------------------------------------------
-- Convert input dates (input as VARCHAR2) to DATE

v_date_from := apps.fnd_date.canonical_to_date(p_date_from);
v_date_to   := apps.fnd_date.canonical_to_date(p_date_to);


-----------------------------------------------------------------------
-- Define header row and write to output file

v_header := 'Full Name'                  ||  vc_delimiter  ||
            'Employee Number'            ||  vc_delimiter  ||
            'Location Code'              ||  vc_delimiter  ||
            'Check Date'                 ||  vc_delimiter  ||
            'Payroll Period'             ||  vc_delimiter  ||
            'Gross Earnings'             ||  vc_delimiter  ||
            'Hours Worked'               ||  vc_delimiter  ||
            'Gross Div By Hours Worked'  ||  vc_delimiter  ||
            'Overtime Hours'             ||  vc_delimiter  ||
            'Other Hours'                ||  vc_delimiter  ||
            'Hourly Rate'                ||  vc_delimiter  ||
            'Retro Pay'                  ||  vc_delimiter  ||
            'Retro Base Wage';


write_data('O',v_header);


-----------------------------------------------------------------------
-- Loop through payroll data

FOR c_emp IN c_get_payroll_data LOOP

  write_data('L','Emp Name: '||c_emp.full_name);
  write_data('L','  Check Date: '||c_emp.check_date);
  write_data('L','  Asg Action ID: '||c_emp.assignment_action_id);

  ---------------------------------------------------------------------
  -- Obtain hourly rate as of check date

  BEGIN

    FOR c_pay IN c_hourly_rate_at_check_date (c_emp.assignment_id) LOOP

       IF c_pay.change_date <= c_emp.check_date
         THEN v_hourly_rate := c_pay.hourly_rate;
       END IF;

    END LOOP;  /** FOR c_pay IN c_hourly_rate_at_check_date (c_emp.assignment_id) **/

  END;

  write_data('L','  Hourly Rate: '||v_hourly_rate);

  ---------------------------------------------------------------------
  -- Based on pay date, call proper procedure to retrieve payroll
  -- balances (cehck dates prior to 2005 use Kbace, 2005 and later use
  -- Oracle

  IF c_emp.check_date >= '01-JAN-2005'

	THEN get_oracle_balances (i_assignment_action_id  =>  c_emp.assignment_action_id,
                                  o_gross_pay             =>  v_gross_pay,
                                  o_hours_worked          =>  v_hours_worked,
                                  o_ot_hours              =>  v_hours_ot,
                                  o_other_hours           =>  v_hours_other,
                                  o_gross_by_hours        =>  v_gross_by_hours,
                                  o_retro_pay             =>  v_retro_pay,
                                  o_retro_base_wage       =>  v_retro_base_wage);

	ELSE get_kbace_balances (i_assignment_action_id  =>  c_emp.assignment_action_id,
                                 o_gross_pay             =>  v_gross_pay,
                                 o_hours_worked          =>  v_hours_worked,
                                 o_ot_hours              =>  v_hours_ot,
                                 o_other_hours           =>  v_hours_other,
                                 o_gross_by_hours        =>  v_gross_by_hours,
                                 o_retro_pay             =>  v_retro_pay,
                                 o_retro_base_wage       =>  v_retro_base_wage);

  END IF;  /** IF c_emp.check_date >= '01-JAN-2005' **/

  ---------------------------------------------------------------------
  -- Calculate total for all payroll variables

  v_total := v_gross_pay    +
             v_hours_worked +
             v_hours_ot     +
             v_hours_other  +
             v_retro_pay    +
             v_retro_base_wage;
  write_data('L','  Total Pay: '||v_total);

  ---------------------------------------------------------------------
  -- If total for all payroll variables is not zero (therefore it is a
  -- valid check record) concatenate values and write to output file

  IF v_total <> 0
    THEN v_message := c_emp.full_name        ||  vc_delimiter  ||
                      c_emp.employee_number  ||  vc_delimiter  ||
                      c_emp.location_code    ||  vc_delimiter  ||
                      c_emp.check_date       ||  vc_delimiter  ||
                      c_emp.payroll_period   ||  vc_delimiter  ||
                      v_gross_pay            ||  vc_delimiter  ||
                      v_hours_worked         ||  vc_delimiter  ||
                      v_gross_by_hours       ||  vc_delimiter  ||
                      v_hours_ot             ||  vc_delimiter  ||
                      v_hours_other          ||  vc_delimiter  ||
                      v_hourly_rate          ||  vc_delimiter  ||
                      v_retro_pay            ||  vc_delimiter  ||
                      v_retro_base_wage;

           write_data('B',v_message);

  END IF;  /** IF v_total <> 0 **/

END LOOP;


-----------------------------------------------------------------------
-- Error message and code for unsuccessful run

EXCEPTION
  WHEN OTHERS THEN
   o_errbuf   := 'Request encountered unexpected error: '||SQLERRM;
   o_retcode  := 2;


END payroll_data;


END ttec_oracle_data_extract;
/
show errors;
/