create or replace PACKAGE BODY TTEC_HR_SAVING_FUNDS_PK IS


/*== START ==========================================================*\
  Author:  Laura M Romero
    Date:  12/10/2010
Call From: Concurrent Program => "TTEC Generate Savings Fund ING Files"
    Desc:  Program that contain the functions and procedures that will
           be used for Saving Funds Interface.


    PROCEDURE MAIN : This is the main procedure.

    Parameter Description:

                 p_organization_id  - A valid mexican organization number.
                 p_payroll_id       - A valid Payroll id.
                 p_period_id        - A valid payroll period.
                 p_full_emp_list    - Full employee list (Yes - No).
                 p_full_term_list   - Full termination list (Yes - No).
                 p_file_directory   - File directory where the file will be located.



  Modification History:

Version    Date     Author             Description (Include Ticket#)
 -----  --------  --------           ----------------------------------
  1.0  08-11-10  Ariotti Florencia   Improve queries and apply
                                     best practices in the code.
  1.1  01-28-11  Parimal Pardikar	 Fix for EEs hired in the Pay Period
  1.2 12-17-2018 Sreenivasula Reddy B	fix to restric the dupolicate record issue
  1.3 16-SEP-2022 Hemani Puri(Emicon) To fetch the records for Salary Basis 'MX Monthly Salary'
  1.0 15-MAY-2023 RXNETHI-ARGANO      R12.2 Upgrade Remediation
\*== END ============================================================*/



  -------------------------------------------------------------------------------
  -- Structure where the read data will be saved in the file.                  --
  -------------------------------------------------------------------------------

  TYPE t_nh_rec IS RECORD(     -- Start sequence
     text_line         VARCHAR2(300)
    ,employee_number   VARCHAR2(32)
    ,employee_name     VARCHAR2(30)
    ,paternal_name     VARCHAR2(30)
    ,maternal_name     VARCHAR2(20)
    ,bank_number       NUMBER
    ,branch            VARCHAR2(5)
    ,plaza             VARCHAR2(5)
    ,bank_account      VARCHAR2(16)
    ,company           NUMBER
    ,employee_num      NUMBER
    ,payroll           VARCHAR2(1)
    ,hiring_date       VARCHAR2(10)
    ,clabe             VARCHAR2(18)
    ,motive            VARCHAR2(2)
    ,record_type       NUMBER
    ,amount            NUMBER
    ,constant          NUMBER
    ,loan_amount       NUMBER
    ,term              NUMBER
    ,periodicity       VARCHAR2(1)
    ,control           NUMBER
    ,reference         VARCHAR2(30)
    ,first_pay_date    VARCHAR2(10)
    ,payment_amount    NUMBER
    ,loan_number       NUMBER
    ,interest          NUMBER
    );


  /*
  START R12.2 Upgrade Remediation
  code commented by RXNETHI-ARGANO,15/05/23
  g_application_code   cust.ttec_error_handling.application_code%TYPE  := 'HR';
  g_interface          cust.ttec_error_handling.INTERFACE%TYPE         := 'Saving Funds';
  g_package            cust.ttec_error_handling.program_name%TYPE      := 'TTEC_HR_SAVING_FUNDS_PK';

  g_warning_status     cust.ttec_error_handling.status%TYPE            := 'WARNING';
  g_error_status       cust.ttec_error_handling.status%TYPE            := 'ERROR';
  g_failure_status     cust.ttec_error_handling.status%TYPE            := 'FAILURE';
  */
  --code added by RXNETHI-ARGANO,15/05/23
  g_application_code   apps.ttec_error_handling.application_code%TYPE  := 'HR';
  g_interface          apps.ttec_error_handling.INTERFACE%TYPE         := 'Saving Funds';
  g_package            apps.ttec_error_handling.program_name%TYPE      := 'TTEC_HR_SAVING_FUNDS_PK';

  g_warning_status     apps.ttec_error_handling.status%TYPE            := 'WARNING';
  g_error_status       apps.ttec_error_handling.status%TYPE            := 'ERROR';
  g_failure_status     apps.ttec_error_handling.status%TYPE            := 'FAILURE';
  --END R12.2 Upgrade Remediation

  ------------------------------------------------------------------------------
  -- Error buffer where the procedures and functions will save the errors.    --
  ------------------------------------------------------------------------------
  g_errbuf VARCHAR2(32767);

  -----------------------------------------------------------------------------
  -- Number of the line in the file that is being processing.                --
  -----------------------------------------------------------------------------
  g_line_num NUMBER;

  -----------------------------------------------------------------------------
  -- Maximum quantity of processing rows before doing commit.                --
  -----------------------------------------------------------------------------
  g_commit_limit NUMBER := 5000;

  -----------------------------------------------------------------------------
  -- Number of the line in the rejected file.                                --
  -----------------------------------------------------------------------------
  g_line_err NUMBER;



  ----------------------------------------------------------------------------------------------------------------------------------
  ----------------------------------------
  -- Making the debug for the exception.--
  ----------------------------------------

  PROCEDURE debug_exceptions_pr(v_module VARCHAR2, p_sqlerr VARCHAR2) IS
  --l_label1             cust.ttec_error_handling.label1%TYPE            := 'Err Location'; --code commented by RXNETHI-ARGANO,15/05/23
  --l_label2             cust.ttec_error_handling.label1%TYPE            := 'Emp_Number';   --code commented by RXNETHI-ARGANO,15/05/23
  l_label1             apps.ttec_error_handling.label1%TYPE            := 'Err Location'; --code added by RXNETHI-ARGANO,15/05/23
  l_label2             apps.ttec_error_handling.label1%TYPE            := 'Emp_Number';   --code added by RXNETHI-ARGANO,15/05/23

  BEGIN

      TTEC_ERROR_LOGGING.PROCESS_ERROR
          ( g_application_code, g_interface, g_package
          , v_module, g_error_status
          , SQLCODE, p_sqlerr
          --, l_label1, ' '
          --, l_label2, g_kr_emp_data.employee_number
          --, 'Location ID', g_kr_emp_data.location_id
           );

  END debug_exceptions_pr;

  ----------------------------------------------------------------------------------------------------------------------------------

  -- +=================================================================+
  -- | The function "open_file" opens the file.                        |
  -- |                                                                 |
  -- |                                                                 |
  -- | PARAMETERS                                                      |
  -- |   p_x_fh: FileHandle of the open file.                          |
  -- |   p_location: Directory of the file in the server.              |
  -- |   p_name: Name of the file.                                     |
  -- |   p_mode: Mode to open the file.                                |
  -- |            - 'A' Append                                         |
  -- |            - 'R' Read Only (Default)                            |
  -- |            - 'W' Write                                          |
  -- |                                                                 |
  -- | CREATED BY                                                      |
  -- |   Laura M Romero   (14/09/2010)                                 |
  -- |                                                                 |
  -- +=================================================================+

  FUNCTION open_file   ( p_x_fh       IN OUT NOCOPY utl_file.file_type
                        ,p_location   IN VARCHAR2
                        ,p_name       IN VARCHAR2
                        ,p_mode       IN VARCHAR2 DEFAULT 'W') RETURN BOOLEAN IS

  BEGIN

    p_x_fh := utl_file.fopen(p_location, p_name, p_mode, 32767);

    RETURN TRUE;

  EXCEPTION
    WHEN utl_file.invalid_path THEN
      g_errbuf := 'Atention! The Location (' || p_location || ') or name (' ||
                  p_name || ') File is invalid.';
      RETURN FALSE;

    WHEN utl_file.invalid_operation OR utl_file.invalid_filename THEN
      g_errbuf := 'Atention! Could not find the file '|| p_name ||
                  ' in directory ' || p_location;
      RETURN FALSE;

    WHEN OTHERS THEN
      g_errbuf := SQLERRM;
      RETURN FALSE;

  END open_file;



  ----------------------------------------------------------------------------------------------------------------------------------

   FUNCTION obtain_org_name ( p_organization_id_f IN NUMBER) RETURN VARCHAR2 IS

   l_organization_name   VARCHAR2(250);

   BEGIN

      SELECT org.name
        INTO l_organization_name
        FROM HR_ALL_ORGANIZATION_UNITS ORG
       WHERE org.organization_id = p_organization_id_f;

        --dbms_output.put_line('Organization Name'|| l_organization_name);

      RETURN l_organization_name;


   EXCEPTION
      WHEN NO_DATA_FOUND THEN
          l_organization_name := null;
          RETURN l_organization_name;
      WHEN OTHERS THEN
          debug_exceptions_pr('Function Obtain Organization name', SQLERRM);


   END obtain_org_name;

  ----------------------------------------------------------------------------------------------------------------------------------

  FUNCTION generate_line (p_x_fh        IN OUT NOCOPY utl_file.file_type
                         ,p_location  IN VARCHAR2
                         ,p_name      IN VARCHAR2
                         ,p_rec       IN t_nh_rec
                         ,p_msg_error IN VARCHAR2) RETURN VARCHAR2 IS


  BEGIN

    IF NOT utl_file.is_open(p_x_fh) THEN

      IF NOT open_file(p_x_fh, p_location, p_name, 'W') THEN

        g_errbuf := 'Atention! Could not create file ' || p_name;

        RAISE utl_file.invalid_filename;

      END IF;

    END IF;

    utl_file.put_line(p_x_fh,p_rec.text_line);

    RETURN 'File Generate. ';

  END generate_line;

  ----------------------------------------------------------------------------------------------------------------------------------

  PROCEDURE close_file( p_x_fh        IN OUT NOCOPY utl_file.file_type
                       ,p_error_log IN BOOLEAN DEFAULT FALSE ) IS
    --This procedure close the file.

  BEGIN

    IF utl_file.is_open(p_x_fh) THEN

      utl_file.fclose(p_x_fh);

    END IF; -- utl_file.is_open(p_x_fh)

  END close_file;

  ----------------------------------------------------------------------------------------------------------------------------------

  -- +=================================================================+
  -- | The procedure make_line create the lines to save in the output  |
  -- | file.                                                           |
  -- |                                                                 |
  -- | CREATED BY                                                      |
  -- |   Laura M Romero   (14/09/2010)                                 |
  -- |                                                                 |
  -- +=================================================================+

  PROCEDURE make_line (p_archivo     IN NUMBER
                      ,p_x_nh_rec    IN OUT t_nh_rec) IS


    l_return_status   VARCHAR2(1024);
    l_msg_count       NUMBER;
    l_msg_data        VARCHAR2(32767);
    l_app_msg         VARCHAR2(1024);
    l_msg_name        VARCHAR2(1024);



  BEGIN

--    fnd_file.put_line(fnd_file.log,'******** Start to make the line ********');

    IF p_archivo = 1 THEN

       p_x_nh_rec.text_line := p_x_nh_rec.employee_number ||','|| p_x_nh_rec.employee_name ||','||
                               p_x_nh_rec.paternal_name   ||','|| p_x_nh_rec.maternal_name ||','||
                               p_x_nh_rec.bank_number     ||','|| p_x_nh_rec.branch        ||','||
                               p_x_nh_rec.plaza           ||','|| p_x_nh_rec.bank_account  ||','||
                               p_x_nh_rec.company         ||','|| p_x_nh_rec.employee_num  ||','||
                               p_x_nh_rec.payroll         ||','|| p_x_nh_rec.hiring_date;
    ELSIF p_archivo = 2 THEN

       p_x_nh_rec.text_line := p_x_nh_rec.employee_number; -- ||','|| p_x_nh_rec.motive;

    ELSIF p_archivo = 3 THEN

       p_x_nh_rec.text_line := p_x_nh_rec.employee_number ||','|| p_x_nh_rec.record_type ||','||
                               p_x_nh_rec.amount;

    ELSIF p_archivo = 4 THEN

       P_X_NH_REC.TEXT_LINE := P_X_NH_REC.EMPLOYEE_NUMBER ||','|| P_X_NH_REC.CONSTANT      ||','||
                               p_x_nh_rec.loan_amount     ||','||p_x_nh_rec.TERM    ||','||
                               p_x_nh_rec.periodicity     ||','|| p_x_nh_rec.control       ||','||
                               p_x_nh_rec.reference       ||','|| p_x_nh_rec.first_pay_date;

    ELSIF p_archivo = 5 THEN

       P_X_NH_REC.TEXT_LINE := P_X_NH_REC.EMPLOYEE_NUMBER ||','|| P_X_NH_REC.CONSTANT      ||','||
                               P_X_NH_REC.PAYMENT_AMOUNT  ||','|| P_X_NH_REC.LOAN_NUMBER;
                              -- ||','|| p_x_nh_rec.interest;

    ELSIF p_archivo = 6 THEN

       p_x_nh_rec.text_line := p_x_nh_rec.employee_number ||','|| p_x_nh_rec.constant      ||','||
                               p_x_nh_rec.interest        ||','|| p_x_nh_rec.constant;

    END IF;

--    fnd_file.put_line(fnd_file.log,'******** End line ********');

  EXCEPTION
      WHEN OTHERS THEN
        debug_exceptions_pr('Prc make_line',
                            SQLERRM);

  END make_line;


  PROCEDURE Main (errbuf            OUT NOCOPY VARCHAR2
                 ,retcode           OUT NOCOPY VARCHAR2
                 ,p_organization_id IN NUMBER
                 ,p_payroll_id      IN NUMBER
                 ,p_period_id       IN NUMBER
                 ,p_full_emp_list   IN VARCHAR2
                 ,p_full_term_list  IN VARCHAR2
                 ,p_file_directory  IN VARCHAR2) IS

    l_nh_file            utl_file.file_type;
    l_r_nh                 t_nh_rec;

    l_result             VARCHAR2(32767);
    l_person_id          PER_ALL_PEOPLE_F.PERSON_ID%TYPE;

    l_contador           NUMBER := 0;

    l_business_group_id  NUMBER := fnd_profile.VALUE('PER_BUSINESS_GROUP_ID');
    l_msg_error          VARCHAR2(4000);

    l_directory          VARCHAR2(2000) := p_file_directory;
    l_file_name          VARCHAR2(2000) ;
    l_charge_account     VARCHAR2(16);
    l_account_number     VARCHAR2(16);
    l_amount             NUMBER:= 0;
    l_payroll            VARCHAR2(250);
    l_payroll_time       VARCHAR2(250);
    l_org_name           VARCHAR2(250);

    -- Cursores

    CURSOR c_new_hires IS
      select PAP.EMPLOYEE_NUMBER,
             TRANSLATE(TRIM(PAP.FIRST_NAME||' '||PAP.MIDDLE_NAMES),'ï¿½ï¿½ï¿½ï¿½ï¿½ï¿½ï¿½ï¿½ï¿½ï¿½ï¿½ï¿½ï¿½ï¿½ï¿½ï¿½ï¿½ï¿½ï¿½ï¿½ï¿½ï¿½ï¿½ï¿½ï¿½ï¿½ï¿½ï¿½ï¿½ï¿½ï¿½ï¿½ï¿½ï¿½ï¿½ï¿½ï¿½ï¿½ï¿½ï¿½ï¿½ï¿½ï¿½ï¿½ï¿½ï¿½ï¿½ï¿½ï¿½ï¿½ï¿½ï¿½ï¿½ï¿½ï¿½ï¿½"ï¿½.,-|/','AAAAAACEEEEIIIINOOOOOUUUUYaaaaaaceeeeiiiinoooooouuuuyy         ') EMPLOYEE_NAME,
             TRANSLATE(PAP.LAST_NAME,'ï¿½ï¿½ï¿½ï¿½ï¿½ï¿½ï¿½ï¿½ï¿½ï¿½ï¿½ï¿½ï¿½ï¿½ï¿½ï¿½ï¿½ï¿½ï¿½ï¿½ï¿½ï¿½ï¿½ï¿½ï¿½ï¿½ï¿½ï¿½ï¿½ï¿½ï¿½ï¿½ï¿½ï¿½ï¿½ï¿½ï¿½ï¿½ï¿½ï¿½ï¿½ï¿½ï¿½ï¿½ï¿½ï¿½ï¿½ï¿½ï¿½ï¿½ï¿½ï¿½ï¿½ï¿½ï¿½ï¿½"ï¿½.,-|/','AAAAAACEEEEIIIINOOOOOUUUUYaaaaaaceeeeiiiinoooooouuuuyy         ') PATERNAL_NAME,
             TRANSLATE(NVL(PAP.PER_INFORMATION1,'X'),'ï¿½ï¿½ï¿½ï¿½ï¿½ï¿½ï¿½ï¿½ï¿½ï¿½ï¿½ï¿½ï¿½ï¿½ï¿½ï¿½ï¿½ï¿½ï¿½ï¿½ï¿½ï¿½ï¿½ï¿½ï¿½ï¿½ï¿½ï¿½ï¿½ï¿½ï¿½ï¿½ï¿½ï¿½ï¿½ï¿½ï¿½ï¿½ï¿½ï¿½ï¿½ï¿½ï¿½ï¿½ï¿½ï¿½ï¿½ï¿½ï¿½ï¿½ï¿½ï¿½ï¿½ï¿½ï¿½ï¿½"ï¿½.,-|/','AAAAAACEEEEIIIINOOOOOUUUUYaaaaaaceeeeiiiinoooooouuuuyy         ') MATERNAL_NAME,
             '6' BANK_NUMBER,
             SUBSTR(PEA.SEGMENT2,1,5) BRANCH,
             '0' PLAZA,
             SUBSTR(PEA.SEGMENT3,1,16) BANK_ACCOUNT,
             '1' COMPANY,
             PAP.EMPLOYEE_NUMBER EMPLOYEE_NUM,
             'Q' PAYROLL,
             to_char(PPS.DATE_START,'DD/MM/YYYY') HIRING_DATE,
             SUBSTR(PEA.SEGMENT5,1,18)  CLABE
        FROM PER_ALL_PEOPLE_F PAP,
             PER_ALL_ASSIGNMENTS_F ASG,
             PER_PERIODS_OF_SERVICE PPS,
             PAY_PERSONAL_PAYMENT_METHODS_F PPM,
             PER_TIME_PERIODS PTP,
             PAY_ALL_PAYROLLS_F PAY,
             PAY_EXTERNAL_ACCOUNTS PEA,
             HR_ALL_ORGANIZATION_UNITS ORG
       WHERE PAP.BUSINESS_GROUP_ID = ASG.BUSINESS_GROUP_ID
         AND PAP.BUSINESS_GROUP_ID = PPS.BUSINESS_GROUP_ID
         AND ASG.ASSIGNMENT_ID = PPM.ASSIGNMENT_ID(+)
         AND ASG.BUSINESS_GROUP_ID = PPM.BUSINESS_GROUP_ID(+)
         AND PTP.END_DATE  BETWEEN PPM.EFFECTIVE_START_DATE AND NVL(PPM.EFFECTIVE_END_DATE,'31-DEC-4712')
         AND PPM.EXTERNAL_ACCOUNT_ID = PEA.EXTERNAL_ACCOUNT_ID(+)
         AND PAP.PERSON_ID = ASG.PERSON_ID
         AND ASG.PAYROLL_ID = PAY.PAYROLL_ID
         AND (PAY.PAYROLL_NAME = 'MX_SAB_Payroll' OR ASG.pay_basis_id IN (SELECT PPB.pay_basis_id from per_pay_bases PPB WHERE PPB.name='MX Monthly Salary')) --1.3
		 AND TRUNC(SYSDATE) BETWEEN PAY.EFFECTIVE_START_DATE AND NVL(PAY.EFFECTIVE_END_DATE,'31-DEC-4712') --  1.2  added by sreenivasula reddy
         AND ASG.PERIOD_OF_SERVICE_ID = PPS.PERIOD_OF_SERVICE_ID
         AND PPS.ACTUAL_TERMINATION_DATE IS NULL
         AND LEAST(PTP.END_DATE,NVL(PPS.ACTUAL_TERMINATION_DATE,'31-DEC-4712')) BETWEEN ASG.EFFECTIVE_START_DATE AND ASG.EFFECTIVE_END_DATE
         AND LEAST(PTP.END_DATE,NVL(PPS.ACTUAL_TERMINATION_DATE,'31-DEC-4712')) BETWEEN PAP.EFFECTIVE_START_DATE AND PAP.EFFECTIVE_END_DATE
         AND LEAST(PTP.END_DATE,NVL(PPS.ACTUAL_TERMINATION_DATE,'31-DEC-4712')) BETWEEN PPS.DATE_START AND NVL(PPS.FINAL_PROCESS_DATE, TRUNC(SYSDATE))
         AND PPS.DATE_START BETWEEN DECODE(NVL(p_full_emp_list,'N'),'N',PTP.START_DATE, 'Y','01-JAN-1951') AND PTP.END_DATE                              -- 1.1
         AND PTP.TIME_PERIOD_ID = P_PERIOD_ID
         AND ORG.ORGANIZATION_ID IN (SELECT ORGANIZATION_ID
                                        FROM HR_ALL_ORGANIZATION_UNITS
                                        WHERE ORGANIZATION_ID = NVL(P_ORGANIZATION_ID,99999)
                                        UNION
                                        SELECT HAOU.ORGANIZATION_ID
                                        FROM HR_ALL_ORGANIZATION_UNITS HAOU, PER_BUSINESS_GROUPS PBG
                                        WHERE HAOU.BUSINESS_GROUP_ID = PBG.BUSINESS_GROUP_ID
                                        AND PBG.NAME = 'TeleTech Holdings - MEX'
                                        AND NOT EXISTS (SELECT ORGANIZATION_ID
                                        FROM HR_ALL_ORGANIZATION_UNITS
                                        WHERE ORGANIZATION_ID = NVL(P_ORGANIZATION_ID,99999))
                                        )
         AND PAP.BUSINESS_GROUP_ID = ORG.BUSINESS_GROUP_ID
         AND ORG.ORGANIZATION_ID = ASG.ORGANIZATION_ID;


    CURSOR c_terminations IS
      SELECT PAP.EMPLOYEE_NUMBER,
             ' ' MOTIVE
        FROM PER_ALL_PEOPLE_F PAP,
             PER_ALL_ASSIGNMENTS_F ASG,
             PER_PERIODS_OF_SERVICE PPS,
             PER_TIME_PERIODS PTP,
             PAY_ALL_PAYROLLS_F PAY,
             HR_ALL_ORGANIZATION_UNITS ORG
       WHERE PAP. BUSINESS_GROUP_ID = ASG.BUSINESS_GROUP_ID
         AND PAP. BUSINESS_GROUP_ID = PPS. BUSINESS_GROUP_ID
         AND PAP.PERSON_ID = ASG.PERSON_ID
         AND ASG.PAYROLL_ID = PAY.PAYROLL_ID
         AND (PAY.PAYROLL_NAME = 'MX_SAB_Payroll' OR ASG.pay_basis_id IN (SELECT PPB.pay_basis_id from per_pay_bases PPB WHERE name='MX Monthly Salary'))--1.3
		 AND TRUNC(SYSDATE) BETWEEN PAY.EFFECTIVE_START_DATE AND NVL(PAY.EFFECTIVE_END_DATE,'31-DEC-4712') --  1.2  added by sreenivasula reddy
         AND ASG.PERIOD_OF_SERVICE_ID = PPS.PERIOD_OF_SERVICE_ID
         AND PPS.ACTUAL_TERMINATION_DATE BETWEEN PTP.START_DATE AND PTP.END_DATE
         AND LEAST(PTP.END_DATE,NVL(PPS.ACTUAL_TERMINATION_DATE,'31-DEC-4712')) BETWEEN ASG.EFFECTIVE_START_DATE AND ASG.EFFECTIVE_END_DATE
         AND LEAST(PTP.END_DATE,NVL(PPS.ACTUAL_TERMINATION_DATE,'31-DEC-4712')) BETWEEN PAP.EFFECTIVE_START_DATE AND PAP.EFFECTIVE_END_DATE
         AND LEAST(PTP.END_DATE,NVL(PPS.ACTUAL_TERMINATION_DATE,'31-DEC-4712')) BETWEEN PPS.DATE_START AND NVL(PPS.FINAL_PROCESS_DATE, TRUNC(SYSDATE))
         AND PTP.TIME_PERIOD_ID = P_PERIOD_ID
         AND ORG.ORGANIZATION_ID IN (SELECT ORGANIZATION_ID
                                        FROM HR_ALL_ORGANIZATION_UNITS
                                        WHERE ORGANIZATION_ID = NVL(P_ORGANIZATION_ID,99999)
                                        UNION
                                        SELECT HAOU.ORGANIZATION_ID
                                        FROM HR_ALL_ORGANIZATION_UNITS HAOU, PER_BUSINESS_GROUPS PBG
                                        WHERE HAOU.BUSINESS_GROUP_ID = PBG.BUSINESS_GROUP_ID
                                        AND PBG.NAME = 'TeleTech Holdings - MEX'
                                        AND NOT EXISTS (SELECT ORGANIZATION_ID
                                        FROM HR_ALL_ORGANIZATION_UNITS
                                        WHERE ORGANIZATION_ID = NVL(P_ORGANIZATION_ID,99999))
                                        )
         AND PAP.BUSINESS_GROUP_ID = ORG.BUSINESS_GROUP_ID
         AND ORG.ORGANIZATION_ID = ASG.ORGANIZATION_ID;


    CURSOR c_contributions IS
      SELECT PAP.EMPLOYEE_NUMBER,
            DECODE(BTYP.BALANCE_NAME,'MX_B_RE_SAVINGS_FUND',1,'MX_SF_EMP_DED',2) RECORD_TYPE,
            SUM(BRUN.BALANCE_VALUE) AMOUNT
       /*
	   START R12.2 Upgrade Remediation
	   code commented by RXNETHI-ARGANO,15/05/23
	   FROM HR.PAY_RUN_BALANCES BRUN,
            HR.PAY_DEFINED_BALANCES BDEF,
            HR.PAY_BALANCE_TYPES BTYP,
            HR.PAY_BALANCE_CATEGORIES_F PBC,
            HR.PAY_ASSIGNMENT_ACTIONS PAA,
            HR.PAY_PAYROLL_ACTIONS PPA,
            HR.PAY_BALANCE_DIMENSIONS DIM, /*ITC 
            HR.PER_ALL_PEOPLE_F PAP,
            HR.PER_ALL_ASSIGNMENTS_F ASG,
            HR.PER_TIME_PERIODS PTP,
			*/
	   --code added by RXNETHI-ARGANO,15/05/23
	   FROM APPS.PAY_RUN_BALANCES BRUN,
            APPS.PAY_DEFINED_BALANCES BDEF,
            APPS.PAY_BALANCE_TYPES BTYP,
            APPS.PAY_BALANCE_CATEGORIES_F PBC,
            APPS.PAY_ASSIGNMENT_ACTIONS PAA,
            APPS.PAY_PAYROLL_ACTIONS PPA,
            APPS.PAY_BALANCE_DIMENSIONS DIM, /*ITC */
            APPS.PER_ALL_PEOPLE_F PAP,
            APPS.PER_ALL_ASSIGNMENTS_F ASG,
            APPS.PER_TIME_PERIODS PTP,
	   --END R12.2 Upgrade Remediation
            HR_ALL_ORGANIZATION_UNITS ORG,
            PER_PERIODS_OF_SERVICE PPS
      WHERE PAP.BUSINESS_GROUP_ID = ASG.BUSINESS_GROUP_ID
        AND PAP. BUSINESS_GROUP_ID = PPS. BUSINESS_GROUP_ID
        AND PAP.PERSON_ID = ASG.PERSON_ID
        AND LEAST(PTP.END_DATE,NVL(PPS.ACTUAL_TERMINATION_DATE,'31-DEC-4712')) BETWEEN ASG.EFFECTIVE_START_DATE AND ASG.EFFECTIVE_END_DATE
        AND LEAST(PTP.END_DATE,NVL(PPS.ACTUAL_TERMINATION_DATE,'31-DEC-4712')) BETWEEN PAP.EFFECTIVE_START_DATE AND PAP.EFFECTIVE_END_DATE
        AND LEAST(PTP.END_DATE,NVL(PPS.ACTUAL_TERMINATION_DATE,'31-DEC-4712')) BETWEEN PPS.DATE_START AND NVL(PPS.FINAL_PROCESS_DATE, TRUNC(SYSDATE))
        AND PTP.TIME_PERIOD_ID = P_PERIOD_ID /*FROM PARAMETERS*/
        AND PPA.PAYROLL_ID = P_PAYROLL_ID /*FROM PARAMETERS*/
        AND ASG.ASSIGNMENT_ID = PAA.ASSIGNMENT_ID
        AND PPA.EFFECTIVE_DATE  BETWEEN  PTP.START_DATE AND PTP.END_DATE
        AND PPA.ACTION_TYPE IN ('R', 'Q', 'B', 'I', 'V')
        AND PAA.PAYROLL_ACTION_ID         = PPA.PAYROLL_ACTION_ID
        AND BRUN.ASSIGNMENT_ACTION_ID     = PAA.ASSIGNMENT_ACTION_ID
        AND BDEF.DEFINED_BALANCE_ID     = BRUN.DEFINED_BALANCE_ID
        AND BTYP.BALANCE_TYPE_ID        = BDEF.BALANCE_TYPE_ID
        AND BTYP.BALANCE_UOM            = 'M'
        AND PBC.BALANCE_CATEGORY_ID     = BTYP.BALANCE_CATEGORY_ID
        AND UPPER(PBC.CATEGORY_NAME)   In ('DEDUCTIONS','EARNINGS')
        AND UPPER(BTYP.BALANCE_NAME) IN ('MX_B_RE_SAVINGS_FUND','MX_SF_EMP_DED')
        AND ORG.ORGANIZATION_ID IN (SELECT ORGANIZATION_ID
                                        FROM HR_ALL_ORGANIZATION_UNITS
                                        WHERE ORGANIZATION_ID = NVL(P_ORGANIZATION_ID,99999)
                                        UNION
                                        SELECT HAOU.ORGANIZATION_ID
                                        FROM HR_ALL_ORGANIZATION_UNITS HAOU, PER_BUSINESS_GROUPS PBG
                                        WHERE HAOU.BUSINESS_GROUP_ID = PBG.BUSINESS_GROUP_ID
                                        AND PBG.NAME = 'TeleTech Holdings - MEX'
                                        AND NOT EXISTS (SELECT ORGANIZATION_ID
                                        FROM HR_ALL_ORGANIZATION_UNITS
                                        WHERE ORGANIZATION_ID = NVL(P_ORGANIZATION_ID,99999))
                                        )
        AND PAP.BUSINESS_GROUP_ID = ORG.BUSINESS_GROUP_ID
        AND PPA.TIME_PERIOD_ID = PTP.TIME_PERIOD_ID /*ITC*/
        AND BDEF.BALANCE_DIMENSION_ID = DIM.BALANCE_DIMENSION_ID /*ITC*/
        AND DIM.DATABASE_ITEM_SUFFIX = '_ASG_GRE_RUN' /*ITC*/
        AND ORG.ORGANIZATION_ID = ASG.ORGANIZATION_ID
        AND PPS.PERIOD_OF_SERVICE_ID = ASG.PERIOD_OF_SERVICE_ID
 group by PAP.EMPLOYEE_NUMBER, DECODE(BTYP.BALANCE_NAME,'MX_B_RE_SAVINGS_FUND',1,'MX_SF_EMP_DED',2);


    CURSOR c_loans IS
          SELECT  PAP.EMPLOYEE_NUMBER EMPLOYEE_NUMBER,
                '1' CONSTANT,
                NVL(PRRV.RESULT_VALUE, 0) LOAN_AMOUNT,
                NVL(PRRV1.RESULT_VALUE, '6') LOAN_NUMBER,
                NVL(PRRV1.RESULT_VALUE, '6') TERM,
                'Q' PERIODICITY,
                PTP.PERIOD_NUM CONTROL,
                'PRESTAMOS' REFERENCE,
              TO_CHAR(PTP1.END_DATE, 'DD/MM/YYYY') FIRST_PAY_DATE
         /*
		 START R12.2 Upgrade Remediation
		 code commented by RXNETHI-ARGANO,15/05/23
		 from   HR.PAY_ELEMENT_TYPES_F PET,
                HR.PAY_ELEMENT_ENTRIES_F ENT,
                HR.PAY_RUN_RESULTS PRR,
                HR.PAY_RUN_RESULT_VALUES PRRV,
                HR.PAY_RUN_RESULT_VALUES PRRV1,
                HR.PAY_INPUT_VALUES_F PIV,
                HR.PAY_INPUT_VALUES_F PIV1,
                HR.PAY_ASSIGNMENT_ACTIONS ASSACT,
                HR.PER_ALL_ASSIGNMENTS_F PAA,
                HR.PAY_PAYROLL_ACTIONS PAYROLL,
                HR.PER_TIME_PERIODS PTP,
                HR.PER_TIME_PERIODS PTP1,
                */
		 --code added by RXNETHI-ARGANO,15/05/23
		 from   APPS.PAY_ELEMENT_TYPES_F PET,
                APPS.PAY_ELEMENT_ENTRIES_F ENT,
                APPS.PAY_RUN_RESULTS PRR,
                APPS.PAY_RUN_RESULT_VALUES PRRV,
                APPS.PAY_RUN_RESULT_VALUES PRRV1,
                APPS.PAY_INPUT_VALUES_F PIV,
                APPS.PAY_INPUT_VALUES_F PIV1,
                APPS.PAY_ASSIGNMENT_ACTIONS ASSACT,
                APPS.PER_ALL_ASSIGNMENTS_F PAA,
                APPS.PAY_PAYROLL_ACTIONS PAYROLL,
                APPS.PER_TIME_PERIODS PTP,
                APPS.PER_TIME_PERIODS PTP1,
		 --END R12.2 Upgrade Remediation
				PER_ALL_PEOPLE_F PAP,
                PER_PERIODS_OF_SERVICE PPS,
                HR_ALL_ORGANIZATION_UNITS ORG
         WHERE  PET.ELEMENT_TYPE_ID = PRR.ELEMENT_TYPE_ID
           AND  PRR.RUN_RESULT_ID = PRRV.RUN_RESULT_ID
           AND  PIV.INPUT_VALUE_ID = PRRV.INPUT_VALUE_ID
           AND  ASSACT.ASSIGNMENT_ACTION_ID = PRR.ASSIGNMENT_ACTION_ID
           AND  PAA.ASSIGNMENT_ID = ASSACT.ASSIGNMENT_ID
           and  PIV.name = 'Total Owed'
           and PIV1.name = 'No Payments'
           and  PIV1.INPUT_VALUE_ID = PRRV1.INPUT_VALUE_ID
           and  PRR.RUN_RESULT_ID = PRRV1.RUN_RESULT_ID
           AND  PAYROLL.PAYROLL_ACTION_ID = ASSACT.PAYROLL_ACTION_ID
           AND  PTP.TIME_PERIOD_ID = PAYROLL.TIME_PERIOD_ID
           AND  PET.ELEMENT_NAME = 'MX_SF_LOANS'
           AND  PTP.END_DATE BETWEEN PET.EFFECTIVE_START_DATE AND PET.EFFECTIVE_END_DATE
           AND  PTP.END_DATE BETWEEN PAA.EFFECTIVE_START_DATE AND PAA.EFFECTIVE_END_DATE
           and  PTP.END_DATE between PIV.EFFECTIVE_START_DATE and PIV.EFFECTIVE_END_DATE
           and  PTP.END_DATE between PIV1.EFFECTIVE_START_DATE and PIV1.EFFECTIVE_END_DATE
           and  PTP1.PAYROLL_ID = PAYROLL.PAYROLL_ID
           and ENT.ASSIGNMENT_ID = PAA.ASSIGNMENT_ID
           and ENT.ELEMENT_TYPE_ID = PET.ELEMENT_TYPE_ID
           and  ENT.EFFECTIVE_START_DATE BETWEEN PTP1.START_DATE AND PTP1.END_DATE
           AND  LEAST(PTP.END_DATE,NVL(PPS.ACTUAL_TERMINATION_DATE,'31-dec-4712')) BETWEEN PAP.EFFECTIVE_START_DATE AND PAP.EFFECTIVE_END_DATE
           AND  LEAST(PTP.END_DATE,NVL(PPS.ACTUAL_TERMINATION_DATE,'31-dec-4712')) BETWEEN PPS.DATE_START AND NVL(PPS.FINAL_PROCESS_DATE, TRUNC(SYSDATE))
           AND  PPS.PERIOD_OF_SERVICE_ID = PAA.PERIOD_OF_SERVICE_ID
           AND  PAA.PAYROLL_ID = P_PAYROLL_ID
           AND  PAYROLL.PAYROLL_ID = PAA.PAYROLL_ID
           AND  PAYROLL.TIME_PERIOD_ID = P_PERIOD_ID
           AND  PAP.BUSINESS_GROUP_ID = PAA.BUSINESS_GROUP_ID
           AND  PAP.PERSON_ID = PAA.PERSON_ID
           AND  ORG.ORGANIZATION_ID IN (SELECT ORGANIZATION_ID
                                        FROM HR_ALL_ORGANIZATION_UNITS
                                        UNION
                                        SELECT HAOU.ORGANIZATION_ID
                                        FROM HR_ALL_ORGANIZATION_UNITS HAOU, PER_BUSINESS_GROUPS PBG
                                        WHERE HAOU.BUSINESS_GROUP_ID = PBG.BUSINESS_GROUP_ID
                                        AND PBG.NAME = 'TeleTech Holdings - MEX'
                                        AND NOT EXISTS (SELECT ORGANIZATION_ID
                                        FROM HR_ALL_ORGANIZATION_UNITS
                                        WHERE ORGANIZATION_ID = NVL(P_ORGANIZATION_ID,99999))
                                        )
           AND  PAP.BUSINESS_GROUP_ID = ORG.BUSINESS_GROUP_ID
           AND  ORG.ORGANIZATION_ID = PAA.ORGANIZATION_ID;


    CURSOR c_payments IS
     SELECT PAP.EMPLOYEE_NUMBER,
            '6' CONSTANT,
            SUM(BRUN.BALANCE_VALUE) PAYMENT_AMOUNT,
            TO_NUMBER('1') LOAN_NUMBER,
            NULL INTEREST
       /*
	   START R12.2 Upgrade Remediation
	   code commented by RXNETHI-ARGANO,15/05/23
	   FROM HR.PAY_RUN_BALANCES BRUN,
            HR.PAY_DEFINED_BALANCES BDEF,
            HR.PAY_BALANCE_TYPES BTYP,
            HR.PAY_BALANCE_CATEGORIES_F PBC,
            HR.PAY_ASSIGNMENT_ACTIONS PAA,
            HR.PAY_PAYROLL_ACTIONS PPA,
            HR.PAY_BALANCE_DIMENSIONS DIM, /*ITC 
            HR.PER_ALL_PEOPLE_F PAP,
            HR.PER_ALL_ASSIGNMENTS_F ASG,
            HR.PER_TIME_PERIODS PTP,
			*/
	  --code added by RXNETHI-ARGANO,15/05/23
	   FROM APPS.PAY_RUN_BALANCES BRUN,
            APPS.PAY_DEFINED_BALANCES BDEF,
            APPS.PAY_BALANCE_TYPES BTYP,
            APPS.PAY_BALANCE_CATEGORIES_F PBC,
            APPS.PAY_ASSIGNMENT_ACTIONS PAA,
            APPS.PAY_PAYROLL_ACTIONS PPA,
            APPS.PAY_BALANCE_DIMENSIONS DIM, /*ITC */
            APPS.PER_ALL_PEOPLE_F PAP,
            APPS.PER_ALL_ASSIGNMENTS_F ASG,
            APPS.PER_TIME_PERIODS PTP,
	  --END R12.2 Upgrade Remediation
            HR_ALL_ORGANIZATION_UNITS ORG,
            PER_PERIODS_OF_SERVICE PPS
      WHERE PAP. BUSINESS_GROUP_ID = ASG.BUSINESS_GROUP_ID
        AND PAP.PERSON_ID = ASG.PERSON_ID
        AND PPS.PERIOD_OF_SERVICE_ID = ASG.PERIOD_OF_SERVICE_ID
        AND LEAST(PTP.END_DATE,NVL(PPS.ACTUAL_TERMINATION_DATE,'31-DEC-4712')) BETWEEN ASG.EFFECTIVE_START_DATE AND ASG.EFFECTIVE_END_DATE
        AND LEAST(PTP.END_DATE,NVL(PPS.ACTUAL_TERMINATION_DATE,'31-DEC-4712')) BETWEEN PAP.EFFECTIVE_START_DATE AND PAP.EFFECTIVE_END_DATE
        AND LEAST(PTP.END_DATE,NVL(PPS.ACTUAL_TERMINATION_DATE,'31-DEC-4712')) BETWEEN PPS.DATE_START AND NVL(PPS.FINAL_PROCESS_DATE, TRUNC(SYSDATE))
        AND PTP.TIME_PERIOD_ID = P_PERIOD_ID /*FROM PARAMETERS*/
        AND PPA.PAYROLL_ID = P_PAYROLL_ID /*FROM PARAMETERS*/
        AND ASG.ASSIGNMENT_ID = PAA.ASSIGNMENT_ID
        AND PPA.EFFECTIVE_DATE  BETWEEN  PTP.START_DATE AND PTP.END_DATE
        AND PPA.ACTION_TYPE IN ('R', 'Q', 'B', 'I', 'V')
        AND PAA.PAYROLL_ACTION_ID         = PPA.PAYROLL_ACTION_ID
        AND BRUN.ASSIGNMENT_ACTION_ID     = PAA.ASSIGNMENT_ACTION_ID
        AND BDEF.DEFINED_BALANCE_ID     = BRUN.DEFINED_BALANCE_ID
        AND BTYP.BALANCE_TYPE_ID        = BDEF.BALANCE_TYPE_ID
        AND BTYP.BALANCE_UOM            = 'M'
        AND PBC.BALANCE_CATEGORY_ID    = BTYP.BALANCE_CATEGORY_ID
        AND UPPER(PBC.CATEGORY_NAME)   = 'DEDUCTIONS'
        AND UPPER(BTYP.BALANCE_NAME) IN ('MX_SF_LOANS')
        AND PPA.TIME_PERIOD_ID = PTP.TIME_PERIOD_ID /*ITC*/
        AND BDEF.BALANCE_DIMENSION_ID = DIM.BALANCE_DIMENSION_ID /*ITC*/
        AND DIM.DATABASE_ITEM_SUFFIX = '_ASG_GRE_RUN' /*ITC*/
        AND ORG.ORGANIZATION_ID IN (SELECT ORGANIZATION_ID
                                        FROM HR_ALL_ORGANIZATION_UNITS
                                        WHERE ORGANIZATION_ID = NVL(P_ORGANIZATION_ID,99999)
                                        UNION
                                        SELECT HAOU.ORGANIZATION_ID
                                        FROM HR_ALL_ORGANIZATION_UNITS HAOU, PER_BUSINESS_GROUPS PBG
                                        WHERE HAOU.BUSINESS_GROUP_ID = PBG.BUSINESS_GROUP_ID
                                        AND PBG.NAME = 'TeleTech Holdings - MEX'
                                        AND NOT EXISTS (SELECT ORGANIZATION_ID
                                        FROM HR_ALL_ORGANIZATION_UNITS
                                        WHERE ORGANIZATION_ID = NVL(P_ORGANIZATION_ID,99999))
                                        )
        AND PAP.BUSINESS_GROUP_ID = ORG.BUSINESS_GROUP_ID
        AND ORG.ORGANIZATION_ID = ASG.ORGANIZATION_ID
        AND PPS.PERIOD_OF_SERVICE_ID = ASG.PERIOD_OF_SERVICE_ID
      group by PAP.EMPLOYEE_NUMBER
      HAVING SUM(BRUN.BALANCE_VALUE) >= 1;


    CURSOR c_interest_payments IS
     SELECT PAP.EMPLOYEE_NUMBER,
            '1' CONSTANT,
            SUM(BRUN.BALANCE_VALUE)INTEREST
       /*FROM HR.PAY_RUN_BALANCES BRUN,
            HR.PAY_DEFINED_BALANCES BDEF,
            HR.PAY_BALANCE_TYPES BTYP,
            HR.PAY_BALANCE_CATEGORIES_F PBC,
            HR.PAY_ASSIGNMENT_ACTIONS PAA,
            HR.PAY_PAYROLL_ACTIONS PPA,
            HR.PAY_BALANCE_DIMENSIONS DIM, /*ITC 
            HR.PER_ALL_PEOPLE_F PAP,
            HR.PER_ALL_ASSIGNMENTS_F ASG,
            HR.PER_TIME_PERIODS PTP,
			*/
	  --code added by RXNETHI-ARGANO,15/05/23
	   FROM APPS.PAY_RUN_BALANCES BRUN,
            APPS.PAY_DEFINED_BALANCES BDEF,
            APPS.PAY_BALANCE_TYPES BTYP,
            APPS.PAY_BALANCE_CATEGORIES_F PBC,
            APPS.PAY_ASSIGNMENT_ACTIONS PAA,
            APPS.PAY_PAYROLL_ACTIONS PPA,
            APPS.PAY_BALANCE_DIMENSIONS DIM, /*ITC */
            APPS.PER_ALL_PEOPLE_F PAP,
            APPS.PER_ALL_ASSIGNMENTS_F ASG,
            APPS.PER_TIME_PERIODS PTP,
	  --END R12.2 Upgrade Remediation
            HR_ALL_ORGANIZATION_UNITS ORG,
            PER_PERIODS_OF_SERVICE PPS
      WHERE PAP. BUSINESS_GROUP_ID = ASG.BUSINESS_GROUP_ID
        AND PAP.PERSON_ID = ASG.PERSON_ID
        AND LEAST(PTP.END_DATE,NVL(PPS.ACTUAL_TERMINATION_DATE,'31-DEC-4712')) BETWEEN ASG.EFFECTIVE_START_DATE AND ASG.EFFECTIVE_END_DATE
        AND LEAST(PTP.END_DATE,NVL(PPS.ACTUAL_TERMINATION_DATE,'31-DEC-4712')) BETWEEN PAP.EFFECTIVE_START_DATE AND PAP.EFFECTIVE_END_DATE
        AND LEAST(PTP.END_DATE,NVL(PPS.ACTUAL_TERMINATION_DATE,'31-DEC-4712')) BETWEEN PPS.DATE_START AND NVL(PPS.FINAL_PROCESS_DATE, TRUNC(SYSDATE))
        AND PTP.TIME_PERIOD_ID = P_PERIOD_ID /*FROM PARAMETERS*/
        AND PPA.PAYROLL_ID     = P_PAYROLL_ID /*FROM PARAMETERS*/
        AND ASG.ASSIGNMENT_ID = PAA.ASSIGNMENT_ID
        AND PPA.EFFECTIVE_DATE  BETWEEN  PTP.START_DATE AND PTP.END_DATE
        AND PPA.ACTION_TYPE IN ('R', 'Q', 'B', 'I', 'V')
        AND PAA.PAYROLL_ACTION_ID         = PPA.PAYROLL_ACTION_ID
        AND BRUN.ASSIGNMENT_ACTION_ID     = PAA.ASSIGNMENT_ACTION_ID
        AND BDEF.DEFINED_BALANCE_ID     = BRUN.DEFINED_BALANCE_ID
        AND BTYP.BALANCE_TYPE_ID         = BDEF.BALANCE_TYPE_ID
        AND BTYP.BALANCE_UOM            = 'M'
        AND PBC.BALANCE_CATEGORY_ID     = BTYP.BALANCE_CATEGORY_ID
        AND UPPER(PBC.CATEGORY_NAME)    = 'DEDUCTIONS'
        AND UPPER(BTYP.BALANCE_NAME) IN ('MX_SF_INTERESTS')
        AND PPA.TIME_PERIOD_ID = PTP.TIME_PERIOD_ID /*ITC*/
        AND BDEF.BALANCE_DIMENSION_ID = DIM.BALANCE_DIMENSION_ID /*ITC*/
        AND DIM.DATABASE_ITEM_SUFFIX = '_ASG_GRE_RUN' /*ITC*/
        AND ORG.ORGANIZATION_ID IN (SELECT ORGANIZATION_ID
                                        FROM HR_ALL_ORGANIZATION_UNITS
                                        WHERE ORGANIZATION_ID = NVL(P_ORGANIZATION_ID,99999)
                                        UNION
                                        SELECT HAOU.ORGANIZATION_ID
                                        FROM HR_ALL_ORGANIZATION_UNITS HAOU, PER_BUSINESS_GROUPS PBG
                                        WHERE HAOU.BUSINESS_GROUP_ID = PBG.BUSINESS_GROUP_ID
                                        AND PBG.NAME = 'TeleTech Holdings - MEX'
                                        AND NOT EXISTS (SELECT ORGANIZATION_ID
                                        FROM HR_ALL_ORGANIZATION_UNITS
                                        WHERE ORGANIZATION_ID = NVL(P_ORGANIZATION_ID,99999))
                                        )
        AND PAP.BUSINESS_GROUP_ID = ORG.BUSINESS_GROUP_ID
        AND ORG.ORGANIZATION_ID = ASG.ORGANIZATION_ID
        AND PPS.PERIOD_OF_SERVICE_ID = ASG.PERIOD_OF_SERVICE_ID
      GROUP BY PAP.EMPLOYEE_NUMBER;

  BEGIN


    errbuf  := '';
    retcode := '0';

    l_org_name := obtain_org_name (p_organization_id);

    BEGIN

        SELECT payroll_name
          INTO l_payroll
          FROM pay_all_payrolls_f
         WHERE payroll_id = p_payroll_id;

    EXCEPTION
       WHEN NO_DATA_FOUND THEN
          l_charge_account := NULL;

       WHEN OTHERS THEN
          debug_exceptions_pr('Prc Main - ','Can Not Find Payroll - '|| SQLERRM);
    END;

    BEGIN

        SELECT period_name
          INTO l_payroll_time
          FROM PER_TIME_PERIODS
         WHERE time_period_id = p_period_id;

    EXCEPTION
       WHEN NO_DATA_FOUND THEN
          l_payroll_time := NULL;

       WHEN OTHERS THEN
          debug_exceptions_pr('Prc Main - ','Can not Find Time Period - '|| SQLERRM);
    END;

    fnd_file.put_line(fnd_file.output,' Company = '||l_org_name);
    fnd_file.put_line(fnd_file.output,' Payroll = '||l_payroll);
    fnd_file.put_line(fnd_file.output,' Payroll Period = '||l_payroll_time);
    fnd_file.put_line(fnd_file.output,' Full Employee List(Yes/No)    = '||p_full_emp_list);
    fnd_file.put_line(fnd_file.output,' Full Termination List(Yes/No) = '||p_full_term_list);
    fnd_file.put_line(fnd_file.output,' Files processed record count ');

    l_file_name := '1156-'||to_char(sysdate,'YYYYMMDD')||'Altas.csv';

--    IF NOT open_file(l_nh_file, l_directory, l_file_name,'W') THEN
--      errbuf := g_errbuf;
--      RAISE utl_file.invalid_path;
--    END IF; -- open_file(...)

    FOR reg1 IN c_new_hires LOOP

      l_r_nh := NULL;

      l_contador := l_contador + 1;
      l_r_nh.employee_number := reg1.EMPLOYEE_NUMBER;
      l_r_nh.employee_name   := reg1.EMPLOYEE_NAME;
      l_r_nh.paternal_name   := reg1.PATERNAL_NAME;
      l_r_nh.maternal_name   := reg1.MATERNAL_NAME;
      l_r_nh.bank_number     := reg1.BANK_NUMBER;
      l_r_nh.branch          := reg1.BRANCH;
      l_r_nh.plaza           := reg1.PLAZA;
      l_r_nh.bank_account    := reg1.BANK_ACCOUNT;
      l_r_nh.company         := reg1.COMPANY;
      l_r_nh.employee_num    := reg1.EMPLOYEE_NUM;
      l_r_nh.payroll         := reg1.PAYROLL;
      l_r_nh.hiring_date     := reg1.HIRING_DATE;
      l_r_nh.clabe           := reg1.CLABE;

      make_line(1,l_r_nh);
      l_result:= generate_line (l_nh_file, l_directory, l_file_name, l_r_nh,l_msg_error);

    END LOOP;

    fnd_file.put_line(fnd_file.output,'             *    New Hires = '||l_contador);
    close_file(l_nh_file);

    l_file_name := '1156-'||to_char(sysdate,'YYYYMMDD')||'Bajas.csv';

    l_contador := 0;

--    IF NOT open_file(l_nh_file, l_directory, l_file_name,'W') THEN
--      errbuf := g_errbuf;
--      RAISE utl_file.invalid_path;
--    END IF; -- open_file(...)

    FOR reg1 IN c_terminations LOOP

      l_r_nh := NULL;

      l_contador := l_contador + 1;
      l_r_nh.employee_number := reg1.EMPLOYEE_NUMBER;
      l_r_nh.motive          := reg1.MOTIVE;

      make_line(2,l_r_nh);
      l_result:= generate_line (l_nh_file, l_directory, l_file_name, l_r_nh,l_msg_error);

    END LOOP;

    fnd_file.put_line(fnd_file.output,'             *    Terminations = '||l_contador);
    close_file(l_nh_file);

    l_file_name := '1156-'||to_char(sysdate,'YYYYMMDD')||'Aportaciones.csv';

    l_contador := 0;

--    IF NOT open_file(l_nh_file, l_directory, l_file_name,'W') THEN
--      errbuf := g_errbuf;
--      RAISE utl_file.invalid_path;
--    END IF; -- open_file(...)

    FOR reg1 IN c_contributions LOOP

      l_r_nh := NULL;

      l_contador := l_contador + 1;
      l_r_nh.employee_number := reg1.EMPLOYEE_NUMBER;
      l_r_nh.record_type     := reg1.RECORD_TYPE;
      l_r_nh.amount          := reg1.AMOUNT;

      make_line(3,l_r_nh);
      l_result:= generate_line (l_nh_file, l_directory, l_file_name, l_r_nh,l_msg_error);

    END LOOP;

    fnd_file.put_line(fnd_file.output,'             *    Contributions = '||l_contador);
    close_file(l_nh_file);

    l_file_name := '1156-'||to_char(sysdate,'YYYYMMDD')||'Prestamos.csv';

    l_contador := 0;

--    IF NOT open_file(l_nh_file, l_directory, l_file_name,'W') THEN
--      errbuf := g_errbuf;
--      RAISE utl_file.invalid_path;
--    END IF; -- open_file(...)

    FOR reg1 IN c_loans LOOP

      l_r_nh := NULL;

      l_contador := l_contador + 1;
      l_r_nh.employee_number := reg1.EMPLOYEE_NUMBER;
      l_r_nh.constant        := reg1.CONSTANT;
      l_r_nh.loan_amount     := reg1.LOAN_AMOUNT;
      l_r_nh.term            := reg1.TERM;
      l_r_nh.periodicity     := reg1.PERIODICITY;
      l_r_nh.control         := reg1.CONTROL;
      l_r_nh.reference       := reg1.REFERENCE;
      l_r_nh.first_pay_date  := reg1.FIRST_PAY_DATE;

      make_line(4,l_r_nh);
      l_result:= generate_line (l_nh_file, l_directory, l_file_name, l_r_nh,l_msg_error);

    END LOOP;

    fnd_file.put_line(fnd_file.output,'             *    Loans = '||l_contador);
    close_file(l_nh_file);

    l_file_name := '1156-'||to_char(sysdate,'YYYYMMDD')||'Pagos.csv';

    l_contador := 0;

--    IF NOT open_file(l_nh_file, l_directory, l_file_name,'W') THEN
--      errbuf := g_errbuf;
--      RAISE utl_file.invalid_path;
--    END IF; -- open_file(...)

    FOR reg1 IN c_payments LOOP

      l_r_nh := NULL;

      l_contador := l_contador + 1;
      l_r_nh.employee_number := reg1.EMPLOYEE_NUMBER;
      l_r_nh.constant        := reg1.CONSTANT;
      l_r_nh.payment_amount  := reg1.PAYMENT_AMOUNT;
      l_r_nh.loan_number     := reg1.LOAN_NUMBER;
      l_r_nh.interest        := reg1.INTEREST;

      make_line(5,l_r_nh);
      l_result:= generate_line (l_nh_file, l_directory, l_file_name, l_r_nh,l_msg_error);

    END LOOP;

    fnd_file.put_line(fnd_file.output,'             *    Loan payments = '||l_contador);
    close_file(l_nh_file);

    l_file_name := '1156-'||to_char(sysdate,'YYYYMMDD')||'Descuentos.csv';

    l_contador := 0;

--    IF NOT open_file(l_nh_file, l_directory, l_file_name,'W') THEN
--      errbuf := g_errbuf;
--      RAISE utl_file.invalid_path;
--    END IF; -- open_file(...)

    FOR reg1 IN c_interest_payments LOOP

      l_r_nh := NULL;

      l_contador := l_contador + 1;
      l_r_nh.employee_number := reg1.EMPLOYEE_NUMBER;
      l_r_nh.constant        := reg1.CONSTANT;
      l_r_nh.interest        := reg1.INTEREST;

      make_line(6,l_r_nh);
      l_result:= generate_line (l_nh_file, l_directory, l_file_name, l_r_nh,l_msg_error);

    END LOOP;

    fnd_file.put_line(fnd_file.output,'             *    Loan payments = '||l_contador);
    close_file(l_nh_file);



  EXCEPTION
    WHEN utl_file.invalid_path THEN

      close_file(l_nh_file);

      errbuf  := nvl(errbuf, g_errbuf);
      retcode := '2';

      ROLLBACK;

    WHEN OTHERS THEN

      close_file(l_nh_file);

      errbuf  := SQLERRM;
      retcode := '2';

      ROLLBACK;

  END Main;

  ----------------------------------------------------------------------------------------------------------------------------------

END TTEC_HR_SAVING_FUNDS_PK;
/
show errors;
/