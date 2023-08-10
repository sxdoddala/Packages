create or replace PACKAGE BODY      TTEC_WALMART_DEPOSITS_PKG IS

/*== START ==========================================================*\
  Author:  Ariotti Santoro Maria Florencia
    Date:  07/10/2010
Call From: Concurrent Program => "TTEC Generate Walmart Deposits File"
    Desc:  Program that contain the functions and procedures that will
           be used for Wal*Mart Interface.


    PROCEDURE SAVE_FILE : This is the main procedure.

    Parameter Description:
     		 p_payroll_id    -  Select a correct Payrrol to filter
                                the information.
             p_location_id   -  A valid mexican location must be
                                selected in the value set to filter
                                the information.
             p_payroll       -  Select a valid payroll time period
                                to filter de information in the file.


  Modification History:

Version    Date     Author             Description (Include Ticket#)
 -----  --------  --------           ----------------------------------
1.0     11/MAY/23 RXNETHI-ARGANO     R12.2 Upgrade Remediation

\*== END ============================================================*/



  g_errbuf   VARCHAR2(32767);
  g_line_err NUMBER;


  /*
  START R12.2 Upgrade Remediation
  code commented by RXNETHI-ARGANO,11/05/23
  g_application_code   cust.ttec_error_handling.application_code%TYPE  := 'HR';
  g_interface          cust.ttec_error_handling.INTERFACE%TYPE         := 'MX WalmartInt';
  g_package            cust.ttec_error_handling.program_name%TYPE      := 'TTEC_WALMART_DEPOSITS_PKG';

  g_warning_status     cust.ttec_error_handling.status%TYPE            := 'WARNING';
  g_error_status       cust.ttec_error_handling.status%TYPE            := 'ERROR';
  g_failure_status     cust.ttec_error_handling.status%TYPE            := 'FAILURE';
  */
  --code added by RXNETHI-ARGANO,11/05/23
  g_application_code   apps.ttec_error_handling.application_code%TYPE  := 'HR';
  g_interface          apps.ttec_error_handling.INTERFACE%TYPE         := 'MX WalmartInt';
  g_package            apps.ttec_error_handling.program_name%TYPE      := 'TTEC_WALMART_DEPOSITS_PKG';

  g_warning_status     apps.ttec_error_handling.status%TYPE            := 'WARNING';
  g_error_status       apps.ttec_error_handling.status%TYPE            := 'ERROR';
  g_failure_status     apps.ttec_error_handling.status%TYPE            := 'FAILURE';
  --END R12.2 Upgrade Remediation


  /* ------------------------------------------------------
 # Function: f_open_file
 # Purpose:  Opens the file to save the New Hire Employees
 # ---------------------------------------------------- */


  FUNCTION f_open_file(p_x_fh       IN OUT NOCOPY utl_file.file_type
                        ,p_location IN VARCHAR2
                        ,p_name     IN VARCHAR2
                        ,p_mode     IN VARCHAR2 DEFAULT 'W') RETURN BOOLEAN IS

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

  END f_open_file;


 /* ------------------------------------------------------
 # Procedure: f_close_file
 # Purpose:  Close the file after save the data.
 # ---------------------------------------------------- */


  PROCEDURE f_close_file(p_x_fh        IN OUT NOCOPY utl_file.file_type
                          ,p_error_log IN BOOLEAN DEFAULT FALSE) IS
    --Este procedimiento cierra el archivo.

  BEGIN

    IF utl_file.is_open(p_x_fh) THEN

      IF p_error_log THEN

        utl_file.put_line(p_x_fh,
                          'R' || to_char(SYSDATE, 'YYYYMMDDHH24MISS') ||
                           lpad(g_line_err, 8, '0'));

        utl_file.fflush(p_x_fh);

      END IF; -- p_error_log

      utl_file.fclose(p_x_fh);

    END IF; -- utl_file.is_open(p_x_fh)

  END f_close_file;


 /* ------------------------------------------------------
 # Procedure: debug_exceptions_pr
 # Purpose:  Procedure for exceptions
 # ---------------------------------------------------- */


  PROCEDURE debug_exceptions_pr(v_module VARCHAR2, p_sqlerr VARCHAR2) IS

  BEGIN

      TTEC_ERROR_LOGGING.PROCESS_ERROR
          ( g_application_code
          , g_interface
          , g_package
          , v_module
          , g_error_status
          , SQLCODE, p_sqlerr );

  END debug_exceptions_pr;


 /* ------------------------------------------------------------
 # Function: obtain_payroll
 # Purpose:  Obtain the payroll name to print it in the log
 # ------------------------------------------------------------- */

  FUNCTION obtain_payroll ( p_payroll_id_f IN NUMBER)
      RETURN VARCHAR2
   IS
      l_payroll_name   VARCHAR2(250);
   BEGIN

       SELECT payroll_name
         INTO l_payroll_name
        FROM  pay_all_payrolls_f
        WHERE payroll_id = p_payroll_id_f;

        dbms_output.put_line('Payroll'|| l_payroll_name);

      RETURN l_payroll_name;


      EXCEPTION
         WHEN NO_DATA_FOUND
          THEN
            l_payroll_name := null;
            RETURN l_payroll_name;
         WHEN OTHERS THEN
             debug_exceptions_pr('Function Obtain Payroll name', SQLERRM);


   END obtain_payroll;



 /* ------------------------------------------------------------
 # Function: obtain_payroll_period
 # Purpose:  Obtain the payroll time period to print it in the log
 # ------------------------------------------------------------- */

  FUNCTION obtain_payroll_period ( p_payroll_f IN NUMBER)
      RETURN VARCHAR2
   IS
      l_payroll_period   VARCHAR2(250);
   BEGIN

        SELECT period_name
          INTO l_payroll_period
          FROM PER_TIME_PERIODS
         WHERE time_period_id = p_payroll_f;


        dbms_output.put_line('Payroll'|| l_payroll_period);

      RETURN l_payroll_period;


      EXCEPTION
         WHEN NO_DATA_FOUND
          THEN
            l_payroll_period := null;
            RETURN l_payroll_period;
         WHEN OTHERS THEN
             debug_exceptions_pr('Function Obtain Payroll Period', SQLERRM);


   END obtain_payroll_period;



 /* ----------------------------------------------------------
 # Function: obtain_location_name
 # Purpose:  Obtain the location name to print it in the log
 # ---------------------------------------------------------- */

   FUNCTION obtain_location_name ( p_location_id_f IN NUMBER)
      RETURN VARCHAR2
   IS
      l_location_name   VARCHAR2(250);
   BEGIN

        SELECT loc.location_code
          INTO l_location_name
          FROM HR_LOCATIONS_ALL LOC
         WHERE loc.location_id = p_location_id_f;

        dbms_output.put_line('Location Name'|| l_location_name);

      RETURN l_location_name;


      EXCEPTION
         WHEN NO_DATA_FOUND
          THEN
            l_location_name := null;
            RETURN l_location_name;
         WHEN OTHERS THEN
             debug_exceptions_pr('Funtion Obtain location name', SQLERRM);

   END obtain_location_name;



 /* ------------------------------------------------------
 # Procedure: SAVE_FILE
 # Purpose:  Save in a csv file the required data
 # ---------------------------------------------------- */



  PROCEDURE SAVE_FILE ( errbuf            OUT NOCOPY VARCHAR2,
                        retcode           OUT NOCOPY VARCHAR2,
                        p_payroll_id      IN NUMBER,
                        p_location_id     IN NUMBER,
                        p_payroll         IN NUMBER,
                        p_organization_id IN NUMBER,
                        p_directory       IN VARCHAR2 DEFAULT NULL,
                        p_file_name       IN VARCHAR2 DEFAULT NULL
                         ) IS

     l_x_fh      utl_file.file_type;

     l_location_name      VARCHAR2(250);
     l_payroll_name       VARCHAR2(250);
     L_PAYROLL_PERIOD     VARCHAR2(250);
--     l_directory          VARCHAR2(2000) := ttec_library.get_directory('CUST_TOP')||'/data/EBS/HC/Payroll/Walmart';
--     l_file_name          VARCHAR2(2000) := 'WalmartDeposit.csv';
     l_directory          VARCHAR2(250) := p_directory;
     l_file_name          VARCHAR2(100) := p_file_name;

     l_business_group_id  NUMBER := fnd_profile.VALUE('PER_BUSINESS_GROUP_ID');


     CURSOR C_DEPOSIT IS
       SELECT   FLV.LOOKUP_CODE CUSTOMER_NUMBER,
                PAP.EMPLOYEE_NUMBER ASSIGNMENT_NUMBER,
                NVL(PRRV.RESULT_VALUE, 0) GROCERY_COUPON_DEPOSIT
         /*
		 START R12.2 Upgrade Remediation
		 code commented by RXNETHI-ARGANO,11/05/23
		 FROM   HR.PAY_ELEMENT_TYPES_F PET,
                HR.PAY_RUN_RESULTS PRR,
                APPS.FND_LOOKUP_VALUES FLV,
                HR.HR_LOCATIONS_ALL LOC,
                HR.PAY_RUN_RESULT_VALUES PRRV,
                HR.PAY_INPUT_VALUES_F PIV,
                HR.PAY_ASSIGNMENT_ACTIONS ASSACT,
                HR.PER_ALL_ASSIGNMENTS_F PAA,
                HR.PAY_PAYROLL_ACTIONS PAYROLL,
                HR.PER_TIME_PERIODS PTP,
				*/
				--code added by RXNETHI-ARGANO,11/05/23
		 FROM   APPS.PAY_ELEMENT_TYPES_F PET,
                APPS.PAY_RUN_RESULTS PRR,
                APPS.FND_LOOKUP_VALUES FLV,
                APPS.HR_LOCATIONS_ALL LOC,
                APPS.PAY_RUN_RESULT_VALUES PRRV,
                APPS.PAY_INPUT_VALUES_F PIV,
                APPS.PAY_ASSIGNMENT_ACTIONS ASSACT,
                APPS.PER_ALL_ASSIGNMENTS_F PAA,
                APPS.PAY_PAYROLL_ACTIONS PAYROLL,
                APPS.PER_TIME_PERIODS PTP,
		  --END R12.2 Upgrade Remediation
                PER_ALL_PEOPLE_F PAP,
                PER_PERIODS_OF_SERVICE PPS,
                HR_ALL_ORGANIZATION_UNITS ORG
         WHERE  PET.ELEMENT_TYPE_ID = PRR.ELEMENT_TYPE_ID
           AND  PRR.RUN_RESULT_ID = PRRV.RUN_RESULT_ID
           AND  PIV.INPUT_VALUE_ID = PRRV.INPUT_VALUE_ID
           AND  ASSACT.ASSIGNMENT_ACTION_ID = PRR.ASSIGNMENT_ACTION_ID
           AND  PAA.ASSIGNMENT_ID = ASSACT.ASSIGNMENT_ID
           AND  PIV.NAME = 'Pay Value'
           AND  PAYROLL.PAYROLL_ACTION_ID = ASSACT.PAYROLL_ACTION_ID
           AND  PTP.TIME_PERIOD_ID = PAYROLL.TIME_PERIOD_ID
           AND  PET.ELEMENT_NAME = 'MX_GROSERY_COUPONS'
           AND  PTP.END_DATE BETWEEN PET.EFFECTIVE_START_DATE AND PET.EFFECTIVE_END_DATE
           AND  PTP.END_DATE BETWEEN PAA.EFFECTIVE_START_DATE AND PAA.EFFECTIVE_END_DATE
           AND  PTP.END_DATE BETWEEN PIV.EFFECTIVE_START_DATE AND PIV.EFFECTIVE_END_DATE
           AND  LEAST(PTP.END_DATE,NVL(PPS.ACTUAL_TERMINATION_DATE,'31-dec-4712')) BETWEEN PAP.EFFECTIVE_START_DATE AND PAP.EFFECTIVE_END_DATE
           AND  LEAST(PTP.END_DATE,NVL(PPS.ACTUAL_TERMINATION_DATE,'31-dec-4712')) BETWEEN PPS.DATE_START AND NVL(PPS.FINAL_PROCESS_DATE, TRUNC(SYSDATE))
           AND  PPS.PERIOD_OF_SERVICE_ID = PAA.PERIOD_OF_SERVICE_ID
           AND  PAA.PAYROLL_ID = P_PAYROLL_ID
		   AND  PAA.LOCATION_ID = LOC.LOCATION_ID /* ITC 12-NOV-2010 */
           AND  FLV.LOOKUP_TYPE = 'TTEC_MEX_WALMART_CUSTOMER'
           AND  FLV.MEANING = LOC.LOCATION_CODE
           AND  LOC.LOCATION_ID IN ((SELECT LOCATION_ID
                                        FROM HR_LOCATIONS_ALL
                                        WHERE LOCATION_ID = P_LOCATION_ID
                                        UNION
                                        SELECT HAL.LOCATION_ID
                                        FROM HR_LOCATIONS_ALL HAL
                                        WHERE HAL.COUNTRY = 'MX'
                                        AND NOT EXISTS (SELECT LOCATION_ID
                                        FROM HR_LOCATIONS_ALL
                                        WHERE LOCATION_ID = NVL(P_LOCATION_ID,99999))
                                        ))
           AND  FLV.ENABLED_FLAG = 'Y'
           AND  FLV.LANGUAGE = USERENV('LANG')
           AND  PAYROLL.PAYROLL_ID = PAA.PAYROLL_ID
           AND  PAYROLL.TIME_PERIOD_ID = P_PAYROLL
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


     BEGIN

            errbuf  := '';
            retcode := '0';


            l_location_name := obtain_location_name(p_location_id);
            l_payroll_name := obtain_payroll(p_payroll_id);
            l_payroll_period := obtain_payroll_period(p_payroll);


            IF NOT utl_file.is_open(l_x_fh) THEN

                IF NOT f_open_file(l_x_fh, l_directory, l_file_name, 'W') THEN

                    g_errbuf := 'Atention! Could not create file ' || l_file_name;

                    debug_exceptions_pr('Could not create file: ', g_errbuf);

                    errbuf := g_errbuf;

                    retcode := '2';

                RAISE utl_file.invalid_filename;

                END IF;


            g_line_err := 0;

            END IF;




            FOR C1 IN C_DEPOSIT LOOP



               utl_file.put_line(l_x_fh, C1.CUSTOMER_NUMBER || ',' || C1.ASSIGNMENT_NUMBER || ',' || C1.GROCERY_COUPON_DEPOSIT);

               g_line_err := g_line_err + 1;



            END LOOP;


           f_close_file(l_x_fh);



            fnd_file.put_line(fnd_file.output,' Payroll: '||l_payroll_name);
            fnd_file.put_line(fnd_file.output,' Location: '||l_location_name);
            fnd_file.put_line(fnd_file.output,' Payroll Period: '||l_payroll_period);

            fnd_file.put_line(fnd_file.output,' Total record processed: ' ||g_line_err);



     END SAVE_FILE;




END TTEC_WALMART_DEPOSITS_PKG;
/
show errors;
/