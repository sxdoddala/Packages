create or replace PACKAGE BODY      TTEC_MEX_HR_PAYSLIP_PK IS
/*== START ==========================================================*\
  Author:      Blanca Zamarripa
  Date:        November 29, 2010
  Call From:   Concurrent Program => "TTEC Mex Upload PaySlip SUA"
  Description: This package for the purpose of uploading extra deductions
               for TTEC Mex Payslip Report

  PROCEDURE MAIN : This is the main procedure.

  Parameter Description:

               p_file_name       - File name
               p_utl_dir         - File directory where the file will be located.
  Modification History:

  Version    Date     Author            Description (Include Ticket#)
  -----     --------  ----------------  ------------------------------
  1.0       11292010  Blanca Zamarripa  Create package
\*== END ============================================================*/

  -- +=================================================================+
  -- | The function "obtain_person_id" get person_id from NSS number   |
  -- |                                                                 |
  -- |                                                                 |
  -- | PARAMETERS                                                      |
  -- |   p_nss_id: NSS number               .                          |
  -- |   p_business_id: Business Group Id                              |
  -- |                                                                 |
  -- | CREATED BY                                                      |
  -- |   Blanca Zamarripa   (05/12/2010)                               |
  -- |                                                                 |
  -- +=================================================================+
  g_application_code   cust.ttec_error_handling.application_code%TYPE  := 'HR';
  g_interface          cust.ttec_error_handling.INTERFACE%TYPE         := 'PaySlip';
  g_package            cust.ttec_error_handling.program_name%TYPE      := 'TTEC_MEX_HR_PAYSLIP_PK';

  g_warning_status     cust.ttec_error_handling.status%TYPE            := 'WARNING';
  g_error_status       cust.ttec_error_handling.status%TYPE            := 'ERROR';
  g_failure_status     cust.ttec_error_handling.status%TYPE            := 'FAILURE';

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


  ----------------------------------------
  -- Making the debug for the exception.--
  ----------------------------------------

   PROCEDURE debug_exceptions_pr(v_module VARCHAR2, p_sqlerr VARCHAR2) IS
   BEGIN

      TTEC_ERROR_LOGGING.PROCESS_ERROR
          ( g_application_code, g_interface, g_package
          , v_module, g_error_status
          , SQLCODE, p_sqlerr
           );

   END debug_exceptions_pr;

   FUNCTION obtain_person_id ( p_nss_id            IN VARCHAR2
                             , p_business_group_id IN NUMBER ) RETURN NUMBER IS

   l_person_id         NUMBER;
   l_effective_date    DATE;

   BEGIN


      SELECT PERSON_ID, MAX(EFFECTIVE_START_DATE)
        INTO l_person_id, l_effective_date
        FROM  per_people_f
       WHERE REPLACE(PER_INFORMATION3,'-','') = p_nss_id
         AND business_group_id = p_business_group_id
       GROUP BY PERSON_ID;

      RETURN l_person_id;


   EXCEPTION
      WHEN NO_DATA_FOUND THEN
        l_person_id := null;
        RETURN l_person_id;
      WHEN OTHERS THEN
        debug_exceptions_pr('Error in function Obtain Person Id', SQLERRM);
        fnd_file.put_line(fnd_file.log,' Error en funcion obtain_person_id = '||SQLERRM);
        l_person_id := null;
        RETURN l_person_id;

   END obtain_person_id;

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
                        ,p_mode       IN VARCHAR2 DEFAULT 'R') RETURN BOOLEAN IS

  BEGIN

    p_x_fh := utl_file.fopen(p_location, p_name, p_mode, 32767);

    RETURN TRUE;

  EXCEPTION
    WHEN utl_file.invalid_path THEN
      debug_exceptions_pr('Atention! The Location (' || p_location || ') or name (' || p_name || ') File is invalid.', SQLERRM);
      fnd_file.put_line(fnd_file.log,'Atention! The Location (' || p_location || ') or name (' || p_name || ') File is invalid.');
      RETURN FALSE;

    WHEN utl_file.invalid_operation OR utl_file.invalid_filename THEN
      debug_exceptions_pr('Atention! Could not find the file '|| p_name ||' in directory ' || p_location, SQLERRM);
      fnd_file.put_line(fnd_file.log,'Atention! Could not find the file '|| p_name ||' in directory ' || p_location);
      RETURN FALSE;

    WHEN OTHERS THEN
      debug_exceptions_pr('Atention! Another error ', SQLERRM);
      fnd_file.put_line(fnd_file.log,'Atention! Another error '|| SQLERRM);
      RETURN FALSE;

  END open_file;

  ----------------------------------------------------------------------------------------------------------------------------------
  -- +=================================================================+
  -- | The function "lenght_file" lenght the file name.                |
  -- |                                                                 |
  -- |                                                                 |
  -- | PARAMETERS                                                      |
  -- |   p_name: Name of the file.                                     |
  -- |                                                                 |
  -- | CREATED BY                                                      |
  -- |   Blanca Zamarripa   (09/12/2010)                               |
  -- |                                                                 |
  -- +=================================================================+
  FUNCTION length_file( p_name IN VARCHAR2) RETURN BOOLEAN IS

  BEGIN

    IF LENGTH(p_name) >= 10 THEN
      RETURN TRUE;
    ELSE
      debug_exceptions_pr('Atention! The File Name (' || p_name || ') is invalid.', NULL);
      fnd_file.put_line(fnd_file.log,'Atention! The File Name (' || p_name || ') is invalid.');
      RETURN FALSE;
    END IF;

  EXCEPTION
    WHEN OTHERS THEN
      debug_exceptions_pr('Atention! Another issue on the file name :', SQLERRM);
      fnd_file.put_line(fnd_file.log,'Atention! Another issue on the file name :' ||SQLERRM);
      RETURN FALSE;

  END length_file;

  ----------------------------------------------------------------------------------------------------------------------------------
  -- +=================================================================+
  -- | The function "Get Payroll Start date" build the start date.     |
  -- |                                                                 |
  -- |                                                                 |
  -- | PARAMETERS                                                      |
  -- |   p_name: Name of the file.                                     |
  -- |                                                                 |
  -- | CREATED BY                                                      |
  -- |   Blanca Zamarripa   (09/12/2010)                               |
  -- |                                                                 |
  -- +=================================================================+
  FUNCTION get_payroll_start_date(p_name IN Varchar2) RETURN DATE IS
    v_payroll_start_date                       Date;
  BEGIN

    v_payroll_start_date := TO_DATE(SUBSTR(p_name, 5, 6),'DDMMRR');

    RETURN (v_payroll_start_date);

  EXCEPTION
    WHEN NO_DATA_FOUND THEN
      RETURN (NULL);
    WHEN OTHERS THEN
      debug_exceptions_pr('Atention! Another issue on Payroll Start Date :' ,SQLERRM);
      fnd_file.put_line(fnd_file.log,'Atention! Another issue on Payroll Start Date :' ||SQLERRM);
      RETURN (NULL);

  END get_payroll_start_date;

  ----------------------------------------------------------------------------------------------------------------------------------
  -- +=================================================================+
  -- | The procedure "close_file" close the file.                      |
  -- |                                                                 |
  -- |                                                                 |
  -- | PARAMETERS                                                      |
  -- |   p_x_fh: FileHandle of the open file.                          |
  -- |   p_error_log: Error log.                                       |
  -- |                                                                 |
  -- | CREATED BY                                                      |
  -- |   Laura M Romero   (14/09/2010)                                 |
  -- |                                                                 |
  -- +=================================================================+
  PROCEDURE close_file( p_x_fh      IN OUT NOCOPY utl_file.file_type
                       ,p_error_log IN BOOLEAN DEFAULT FALSE ) IS

  BEGIN

    IF utl_file.is_open(p_x_fh) THEN

      utl_file.fclose(p_x_fh);

    END IF;

  END close_file;

  ----------------------------------------------------------------------------------------------------------------------------------
  -- +=================================================================+
  -- | The procedure "delete_table" deletes from TEMP table            |
  -- |                                                                 |
  -- |                                                                 |
  -- | PARAMETERS                                                      |
  -- |   N/A                                .                          |
  -- |                                                                 |
  -- | CREATED BY                                                      |
  -- |   Blanca Zamarripa   (01/12/2010)                                |
  -- |                                                                 |
  -- +=================================================================+
  PROCEDURE delete_table IS

  BEGIN

    DELETE FROM TTEC_MEX_PAYSLIP_TEMP;

    fnd_file.put_line(fnd_file.log,' Delete Records ');
    fnd_file.put_line(fnd_file.log,' Number of employees deleted: ' || TO_CHAR(SQL%ROWCOUNT));
    fnd_file.put_line(fnd_file.log,' ***************************************************************** ');

    COMMIT;

  EXCEPTION
    WHEN NO_DATA_FOUND THEN
      fnd_file.put_line(fnd_file.log,' No se encontraron datos para eliminar ');
    WHEN OTHERS THEN
      debug_exceptions_pr(' Another excepcion: ', SQLERRM);
      fnd_file.put_line(fnd_file.log,' Otra excepcion: '||SQLERRM);
  END delete_table;

  ----------------------------------------------------------------------------------------------------------------------------------
  -- +=================================================================+
  -- | Main procedure                                                  |
  -- |                                                                 |
  -- |                                                                 |
  -- | PARAMETERS                                                      |
  -- |   p_organization_id: Organization Id                            |
  -- |   p_file_name: File name to get the information                 |
  -- |   p_utl_dir: Full path to get the file                          |
  -- |                                                                 |
  -- | CREATED BY                                                      |
  -- |   Blanca Zamarripa   (01/12/2010)                               |
  -- |                                                                 |
  -- +=================================================================+

  PROCEDURE Main (errbuf            OUT NOCOPY VARCHAR2
                 ,retcode           OUT NOCOPY VARCHAR2
                 ,p_organization_id IN NUMBER
                 ,p_file_name       IN Varchar2
                 ,p_utl_dir         IN Varchar2) IS

    l_file               utl_file.file_type;

    l_result             VARCHAR2(32767);
    l_contador           NUMBER := 0;

    l_business_group_id  NUMBER := fnd_profile.VALUE('PER_BUSINESS_GROUP_ID');
    l_user_id            NUMBER := fnd_profile.VALUE('USER_ID');
    l_msg_error          VARCHAR2(4000);

    l_directory          VARCHAR2(2000) := p_utl_dir;
    l_file_name          VARCHAR2(20)   := p_file_name;
    l_org_name           VARCHAR2(250);
    l_line               VARCHAR2(2000);

    l_person_id                     ttec_mex_payslip_temp.person_id%TYPE;
    l_payroll_start_date            ttec_mex_payslip_temp.payroll_start_date%TYPE;
    l_clave                         ttec_mex_payslip_temp.clave%TYPE;
    l_nss_id                        ttec_mex_payslip_temp.nss_id%TYPE;
    l_retire_value                  ttec_mex_payslip_temp.retire_value%TYPE;
    l_cesanty_value                 ttec_mex_payslip_temp.cesanty_value%TYPE;
    l_employer_contribution_value   ttec_mex_payslip_temp.employer_contribution_value%TYPE;
    l_payment_value                 ttec_mex_payslip_temp.payment_value%TYPE;
    l_posi_1			            Number;
    l_posi_8			            Number;
    l_posi_9			            Number;
    l_posi_12			            Number;
    l_posi_15			            Number;

    e_payroll_file_length           EXCEPTION;

    e_constraint_violated			EXCEPTION;
    PRAGMA EXCEPTION_INIT(e_constraint_violated, -00001);

  BEGIN


    errbuf  := '';
    retcode := '0';

    l_payroll_start_date := get_payroll_start_date(l_file_name);

    fnd_file.put_line(fnd_file.log,' File               = '||l_file_name);
    fnd_file.put_line(fnd_file.log,' Business Group Id  = '||l_business_group_id);
    fnd_file.put_line(fnd_file.log,' ***************************************************************** ');
    fnd_file.put_line(fnd_file.log,' Payroll Start Date = '||l_payroll_start_date);
    fnd_file.put_line(fnd_file.log,' ***************************************************************** ');

    IF length_file(p_file_name) THEN

      delete_table;

      IF open_file ( l_file, l_directory, l_file_name, 'R') THEN

        LOOP
          BEGIN

          l_person_id := NULL;
          utl_file.get_line(l_file, l_line);

    	  l_posi_1  := INSTR(l_line, ',', 1,  1) + 1;
    	  l_posi_8  := INSTR(l_line, ',', 1,  8) + 1;
    	  l_posi_9  := INSTR(l_line, ',', 1,  9) + 1;
    	  l_posi_12 := INSTR(l_line, ',', 1, 12) + 1;
    	  l_posi_15 := INSTR(l_line, ',', 1, 15) + 1;

  		  l_clave                         := NVL(SUBSTR(l_line, 1, INSTR(l_line, ',', 1, 1) - 1), ' ');
  		  l_nss_id                        := SUBSTR(l_line, l_posi_1, (INSTR(l_line,',', 1, 2) - 1) - (l_posi_1 - 1));
  		  l_retire_value                  := NVL(TRIM(REPLACE(SUBSTR(l_line, l_posi_8, (INSTR(l_line,',', 1, 9) - 1) - (l_posi_8 - 1)), '"', '')),0);
  		  l_cesanty_value                 := NVL(TRIM(REPLACE(SUBSTR(l_line, l_posi_9, (INSTR(l_line,',', 1,10) - 1) - (l_posi_9 - 1)), '"', '')),0);
  		  l_employer_contribution_value   := NVL(TRIM(REPLACE(SUBSTR(l_line, l_posi_12,(INSTR(l_line,',', 1,13) - 1) - (l_posi_12 - 1)), '"', '')),0);
  		  l_payment_value                 := NVL(TRIM(REPLACE(SUBSTR(l_line, l_posi_15,(INSTR(l_line,',', 1,16) - 1) - (l_posi_15 - 1)), '"', '')),0);

          l_person_id := obtain_person_id ( l_nss_id, l_business_group_id );

            IF l_person_id IS NOT NULL THEN

              BEGIN
                INSERT INTO TTEC_MEX_PAYSLIP_TEMP
		        ( person_id
                , payroll_start_date
                , clave
                , nss_id
                , business_group_id
                , retire_value
                , cesanty_value
                , employer_contribution_value
                , payment_value
                , creation_date
                , created_by)
                VALUES
		        ( l_person_id
                , l_payroll_start_date
                , l_clave
                , l_nss_id
                , l_business_group_id
                , l_retire_value
                , l_cesanty_value
                , l_employer_contribution_value
                , l_payment_value
                , SYSDATE
                , l_user_id);

              EXCEPTION
                WHEN e_constraint_violated THEN
                  debug_exceptions_pr('Duplicity record: '||l_nss_id||' please review it ', NULL);
                  fnd_file.put_line(fnd_file.log,' Duplicidad en Indice de Tabla para el registro NSS Id = '||l_nss_id||' revisalo ');
                  fnd_file.put_line(fnd_file.log,' El registro = '||l_person_id||' '||l_nss_id||' '||l_clave||' '||l_retire_value||' '||l_cesanty_value||' '||l_employer_contribution_value||' '||l_payment_value);
                WHEN others THEN
                  -- Log SQLERRM error
                  debug_exceptions_pr('Another issue for inserting record: '||l_nss_id, SQLERRM);
                  fnd_file.put_line (fnd_file.log, SQLCODE || ': ' || SQLERRM);
                  fnd_file.put_line(fnd_file.log,' El registro = '||l_person_id||' '||l_nss_id||' '||l_clave||' '||l_retire_value||' '||l_cesanty_value||' '||l_employer_contribution_value||' '||l_payment_value);
              END;
            ELSE

              debug_exceptions_pr('NSS = '||l_nss_id||' does not has record from the application ', NULL);
              fnd_file.put_line(fnd_file.log,' El NSS = '||l_nss_id||' no tiene registro en la aplicacion ');

            END IF;

          END;

        END LOOP;

        COMMIT;

      END IF;

      close_file(l_file);

    ELSE
      RAISE e_payroll_file_length;
    END IF;

  EXCEPTION
      WHEN e_payroll_file_length THEN
         debug_exceptions_pr(' File name = '||p_file_name||' is incorrect, it has more 14 chars!!', NULL);
         fnd_file.put_line(fnd_file.log,' El nombre del archivo = '||p_file_name||' es incorrento pues tiene mas de 14 caracteres!!');
         fnd_file.put_line(fnd_file.log,' La estructura del nombre del archivo debe ser XXX_DDMMRR_IN.csv donde XXX es SAB o SSI y DDMMRR la fecha inicial de nomina ');
      WHEN OTHERS THEN
         -- Log SQLERRM error
         debug_exceptions_pr('Another issue: ', SQLERRM);
         fnd_file.put_line (fnd_file.log, SQLCODE || ': ' || SQLERRM);

  END main;

END TTEC_MEX_HR_PAYSLIP_PK;
