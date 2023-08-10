create or replace PACKAGE BODY ttec_hr_santander_deposit_pk IS

/*== START ==========================================================*\
  Author:  Romero Laura M.
    Date:  14/09/2010
Call From: Concurrent Program => "TTEC Generate Santander Deposit File"
    Desc:  Program that contain the functions and procedures that will
           be used for Santander Interface.

    PROCEDURE main : This is the main procedure.

    Parameter Description:

        p_payroll_id  - Select a correct Payrrol to filter
                            the information.
            p_period_id   - Select a valid payroll time period
                            to filter de information in the file.
            p_date        - Application Date.


  Modification History:

Version    Date     Author             Description (Include Ticket#)
 -----  --------  --------           ----------------------------------
1.1     04-FEB-2011 Parimal Pardikar    Use Total Pay Balance to include
                                        Non-Payroll Payments. Modify File name.
1.2     26-APR-2011 Bob Shanks          Queries in Main procedure modified to
                                        support the return of a single bank
                                        account record when mutiple records
                                        exist.
1.3    25-SEP-2012   Julie Keener     Removed blank lines from output file.
1.4    25-Jun-2021   Narasimhulu Yellam  employer account number to be reflected based on pay period end date
1.5    15-Sep-2022   Neelofar  Mexico Percepta New GRE Payroll Project.
1.0    16-May-2023   RXNETHI-ARGANO     R12.2 Upgrade Remediation
\*== END ============================================================*/

  -------------------------------------------------------------------------------
  -- Structure where the read data will be saved in the file text.             --
  -------------------------------------------------------------------------------

    TYPE t_nh_rec IS RECORD (     --          Seq. In?o   Fin Tam. Descripcion                 Valor
        text_line          VARCHAR2(2500),
        header             BOOLEAN,
        footer             BOOLEAN,
        record_type        NUMBER        --   1      1      1   1  Reg Type
        ,
        seq_number         VARCHAR2(5)   --   2      2      6   5  Sequence number
        ,
        constant           VARCHAR2(1)   --   3      7      7   1  Constant                   *HEADER*
        ,
        employee_number    VARCHAR2(10)   --   3      7     13   7  Employee number            *DETAIL *
        ,
        total_records      VARCHAR2(8)   --   3      7     11   5  Reg Total
        ,
        creation_date      VARCHAR2(8)   --   4      8     15   8  Creation date MMDDYYYY     *HEADER*
        ,
        paternal_name      VARCHAR2(40)  --   4     14     43  30  Paternal name               *DETAIL*
        ,
        total_amount       VARCHAR2(25)  --   4      7     11   5  Total deposit amount
        ,
        charge_account     VARCHAR2(20)  --   5     16     31  16  Charge Account                *HEADER*
        ,
        maternal_name      VARCHAR2(40)  --   5     44     63  20  maternal name                 *DETAIL *
        ,
        application_date   VARCHAR2(8)   --   6     32     39   8  Application date    MMDDYYYY  *HEADER *
        ,
        names              VARCHAR2(50)  --   6     64     93  30  First and last name
        ,
        account_number     VARCHAR2(25)  --   7     94    109  16
        ,
        deposit_amount     VARCHAR2(25)  --   8    527    542  16
    );
    /*
	START R12.2 Upgrade Remediation
	code commented by RXNETHI-ARGANO,16/05/23
	g_application_code   cust.ttec_error_handling.application_code%TYPE := 'HR';
    g_interface          cust.ttec_error_handling.interface%TYPE := 'MX SantanderDep';
    g_package            cust.ttec_error_handling.program_name%TYPE := 'TTEC_HR_SANTANDER_DEPOSIT_PK';
    g_warning_status     cust.ttec_error_handling.status%TYPE := 'WARNING';
    g_error_status       cust.ttec_error_handling.status%TYPE := 'ERROR';
    g_failure_status     cust.ttec_error_handling.status%TYPE := 'FAILURE';
    */
	--code added by RXNETHI-ARGANO,16/05/23
	g_application_code   apps.ttec_error_handling.application_code%TYPE := 'HR';
    g_interface          apps.ttec_error_handling.interface%TYPE := 'MX SantanderDep';
    g_package            apps.ttec_error_handling.program_name%TYPE := 'TTEC_HR_SANTANDER_DEPOSIT_PK';
    g_warning_status     apps.ttec_error_handling.status%TYPE := 'WARNING';
    g_error_status       apps.ttec_error_handling.status%TYPE := 'ERROR';
    g_failure_status     apps.ttec_error_handling.status%TYPE := 'FAILURE';
	--END R12.2 Upgrade Remediation
  ------------------------------------------------------------------------------
  -- Error buffer where the procedures and functions will save the errors.    --                                                    --
  ------------------------------------------------------------------------------
    g_errbuf             VARCHAR2(32767);

  -----------------------------------------------------------------------------
  -- Number of the line in the file that is being processing.                --
  -----------------------------------------------------------------------------
    g_line_num           NUMBER;

  -----------------------------------------------------------------------------
  -- Maximum quantity of processing rows before doing commit.                --
  -----------------------------------------------------------------------------
    g_commit_limit       NUMBER := 5000;

  -----------------------------------------------------------------------------
  -- Number of the line in the rejected file.                                --
  -----------------------------------------------------------------------------
    g_line_err           NUMBER;


  ----------------------------------------------------------------------------------------------------------------------------------
  ----------------------------------------
  -- Making the debug for the exception.--
  ----------------------------------------

    PROCEDURE debug_exceptions_pr (
        v_module   VARCHAR2,
        p_sqlerr   VARCHAR2
    ) IS

        /*
		START R12.2 Upgrade Remediation
		code commente by RXNETHI-ARGANO,16/05/23
		g_label1   cust.ttec_error_handling.label1%TYPE := 'Err Location';
        g_label2   cust.ttec_error_handling.label1%TYPE := 'Emp_Number';
        */
		--code added by RXNETHI-ARGANO,16/05/23
		g_label1   apps.ttec_error_handling.label1%TYPE := 'Err Location';
        g_label2   apps.ttec_error_handling.label1%TYPE := 'Emp_Number';
		--END R12.2 Upgrade Remediation
	BEGIN
        ttec_error_logging.process_error(g_application_code, g_interface, g_package, v_module, g_error_status,
                                         sqlcode, p_sqlerr
          --, g_label1, ' '
          --, g_label2, g_kr_emp_data.employee_number
          --, 'Location ID', g_kr_emp_data.location_id
                                         );
    END debug_exceptions_pr;

  ----------------------------------------------------------------------------------------------------------------------------------

  -- +=================================================================+
  -- | The function "abrir_archivo" opens the file.                    |
  -- |                                                                 |
  -- |                                                                 |
  -- | PARAMETERS                                                      |
  -- |   p_x_fh: FileHandle of the open file.                          |
  -- |   p_location: Directory of the file in the server.              |
  -- |   p_name: Name of the file.                                     |
  -- |   p_mode: Mode to open the file.                                |
  -- |            - 'A' Modo Append                                    |
  -- |            - 'R' Modo Read Only (Valor por Defecto)             |
  -- |            - 'W' Modo Write                                     |
  -- |                                                                 |
  -- | CREATED BY                                                      |
  -- |   Laura M Romero   (14/09/2010)                                 |
  -- |                                                                 |
  -- +=================================================================+

    FUNCTION abrir_archivo (
        p_x_fh IN OUT NOCOPY utl_file.file_type,
        p_location   IN   VARCHAR2,
        p_name       IN   VARCHAR2,
        p_mode       IN   VARCHAR2 DEFAULT 'W'
    ) RETURN BOOLEAN IS
    BEGIN
        p_x_fh := utl_file.fopen(p_location, p_name, p_mode, 32767);
        RETURN true;
    EXCEPTION
        WHEN utl_file.invalid_path THEN
            g_errbuf := 'Atention! The Location ('
                        || p_location
                        || ') or name ('
                        || p_name
                        || ') File is invalid.';
            RETURN false;
        WHEN utl_file.invalid_operation OR utl_file.invalid_filename THEN
            g_errbuf := 'Atention! Could not find the file '
                        || p_name
                        || ' in directory '
                        || p_location;
            RETURN false;
        WHEN OTHERS THEN
            g_errbuf := sqlerrm;
            RETURN false;
    END abrir_archivo;

  -- ------------------------------------------------------------------------
  -- Funtion to show the text on the screen
  -- ------------------------------------------------------------------------

    PROCEDURE print (
        texto IN VARCHAR2
    ) IS
    BEGIN
        dbms_output.put_line(texto);
    END;

  -- ------------------------------------------------------------------------
  -- Funtion to justify the text to the left and put blank spaces into
  -- the right.
  -- ------------------------------------------------------------------------

    FUNCTION string_pad_left (
        texto      IN   VARCHAR2,
        longitud   IN   NUMBER
    ) RETURN VARCHAR2 IS
        texto_final VARCHAR2(240);
    BEGIN
        texto_final := rpad(nvl(texto, ' '), longitud, ' ');
        RETURN texto_final;
    END;

  -- ------------------------------------------------------------------------
  -- Funtion to justify the text to the right and put blank spaces into
  -- the left.
  -- ------------------------------------------------------------------------

    FUNCTION string_pad_right (
        texto      IN   VARCHAR2,
        longitud   IN   NUMBER
    ) RETURN VARCHAR2 IS
        texto_final VARCHAR2(240);
    BEGIN
        texto_final := lpad(nvl(texto, ' '), longitud, ' ');
        RETURN texto_final;
    END;

  -- ------------------------------------------------------------------------
  -- Funtion to justify the text to the right and put blank spaces into
  -- the left.
  -- ------------------------------------------------------------------------

    FUNCTION num_pad_right (
        texto      IN   NUMBER,
        longitud   IN   NUMBER
    ) RETURN VARCHAR2 IS
        texto_final VARCHAR2(240);
    BEGIN
        texto_final := lpad(nvl(texto, NULL), longitud, '0');
        RETURN texto_final;
    END;

  -- ------------------------------------------------------------------------
  -- Funtion that return a string with X spaces
  -- ------------------------------------------------------------------------

    FUNCTION tab_space (
        longitud IN NUMBER
    ) RETURN VARCHAR2 IS
        texto_final VARCHAR2(240);
    BEGIN
        texto_final := '.'
                       || substr('                                        ' || '                                        ', 1, longitud
                       - 1);

        RETURN texto_final;
    END;

  ----------------------------------------------------------------------------------------------------------------------------------

    FUNCTION generar_linea (
        p_x_fh IN OUT NOCOPY utl_file.file_type,
        p_location    IN   VARCHAR2,
        p_name        IN   VARCHAR2,
        p_rec         IN   t_nh_rec,
        p_msg_error   IN   VARCHAR2
    ) RETURN VARCHAR2 IS
    BEGIN
        IF NOT utl_file.is_open(p_x_fh) THEN
            IF NOT abrir_archivo(p_x_fh, p_location, p_name, 'W') THEN
                g_errbuf := 'Atention! Could not create file ' || p_name;
                RAISE utl_file.invalid_filename;
            END IF;

            utl_file.put_line(p_x_fh, '' || to_char(sysdate, 'YYYYMMDDHH24MISS'));
            g_line_err := 0;
        END IF;

        utl_file.put_line(p_x_fh, p_rec.text_line);
        g_line_err := g_line_err + 1;
        RETURN 'File Generate. ';
    END generar_linea;

  ----------------------------------------------------------------------------------------------------------------------------------

    PROCEDURE cerrar_archivo (
        p_x_fh IN OUT NOCOPY utl_file.file_type,
        p_error_log IN BOOLEAN DEFAULT false
    ) IS
    --Este procedimiento cierra el archivo.
    BEGIN
        IF utl_file.is_open(p_x_fh) THEN
            IF p_error_log THEN
                utl_file.put_line(p_x_fh, 'R'
                                          || to_char(sysdate, 'YYYYMMDDHH24MISS')
                                          || lpad(g_line_err, 8, '0'));

                utl_file.fflush(p_x_fh);
            END IF; -- p_error_log

            utl_file.fclose(p_x_fh);
        END IF; -- utl_file.is_open(p_x_fh)
    END cerrar_archivo;

  ----------------------------------------------------------------------------------------------------------------------------------

 -- +=================================================================+
  -- | The procedure ARMAR_LINEA create the lines to save in the output|
  -- | file.                                                           |
  -- |                                                                 |
  -- | CREATED BY                                                      |
  -- |   Laura M Romero   (14/09/2010)                                 |
  -- |                                                                 |
  -- +=================================================================+

    PROCEDURE armar_linea (
        p_count    IN      NUMBER,
        p_amount   IN      NUMBER,
        x_nh_rec   IN OUT  t_nh_rec
    ) IS

        l_return_status   VARCHAR2(1024);
        l_msg_count       NUMBER;
        l_msg_data        VARCHAR2(32767);
        l_app_msg         VARCHAR2(1024);
        l_msg_name        VARCHAR2(1024);
        tmp               NUMBER;
        l_contador        NUMBER := 0;
        l_location        hr_locations_all.location_code%TYPE;
        l_campo           VARCHAR2(50);
    BEGIN

   -- fnd_file.put_line(fnd_file.log,'******** Comienzo Armar Linea ********');
        IF x_nh_rec.header THEN
            x_nh_rec.record_type := 1;
            x_nh_rec.seq_number := '00001';
            l_campo := 'Seq_Number';
            x_nh_rec.constant := 'E';
            l_campo := 'Constant';
            x_nh_rec.creation_date := to_char(sysdate, 'MMDDYYYY');
            l_campo := 'Creation_Date';
            x_nh_rec.text_line := x_nh_rec.record_type
                                  || x_nh_rec.seq_number
                                  || x_nh_rec.constant
                                  || x_nh_rec.creation_date
                                  || x_nh_rec.charge_account
                                  || x_nh_rec.application_date;

            fnd_file.put_line(fnd_file.output, x_nh_rec.text_line);
        ELSIF x_nh_rec.footer THEN
            x_nh_rec.record_type := 3;
            x_nh_rec.seq_number := num_pad_right(p_count + 1, 5);
            l_campo := 'Seq_Number';
            x_nh_rec.total_records := num_pad_right(p_count - 1, 5);
            l_campo := 'Total_records';
            x_nh_rec.total_amount := num_pad_right(p_amount, 18);
            l_campo := 'Total_amount';
            x_nh_rec.text_line := x_nh_rec.record_type
                                  || x_nh_rec.seq_number
                                  || x_nh_rec.total_records
                                  || x_nh_rec.total_amount;

            fnd_file.put_line(fnd_file.output, x_nh_rec.text_line);
        ELSE

       --fnd_file.put_line(fnd_file.log,'llega');
            BEGIN
                x_nh_rec.record_type := 2;
                x_nh_rec.seq_number := num_pad_right(p_count + 1, 5);
                l_campo := 'Seq_Number';
                x_nh_rec.employee_number := string_pad_left(x_nh_rec.employee_number, 7);
                l_campo := 'employee_number';
                x_nh_rec.paternal_name := string_pad_left(x_nh_rec.paternal_name, 30);
                l_campo := 'paternal_name';
                x_nh_rec.maternal_name := string_pad_left(x_nh_rec.maternal_name, 20);
                l_campo := 'maternal_name';
                x_nh_rec.names := string_pad_left(x_nh_rec.names, 30);
                l_campo := 'names';
                x_nh_rec.account_number := string_pad_left(x_nh_rec.account_number, 16);
                l_campo := 'account_number';
                x_nh_rec.deposit_amount := num_pad_right(x_nh_rec.deposit_amount, 18);
                l_campo := 'deposit_amount';
                x_nh_rec.text_line := x_nh_rec.record_type
                                      || x_nh_rec.seq_number
                                      || x_nh_rec.employee_number
                                      || x_nh_rec.paternal_name
                                      || x_nh_rec.maternal_name
                                      || x_nh_rec.names
                                      || x_nh_rec.account_number
                                      || x_nh_rec.deposit_amount;

                fnd_file.put_line(fnd_file.output, x_nh_rec.text_line);
            EXCEPTION
                WHEN OTHERS THEN
                    debug_exceptions_pr('Prc Armar_linea ', 'Campo: '
                                                            || l_campo
                                                            || sqlerrm);
            END;

--         fnd_file.put_line(fnd_file.log,'Pasa 2');
        END IF;

    --fnd_file.put_line(fnd_file.log,'******** Fin Armar Linea ********');
    EXCEPTION
        WHEN OTHERS THEN
            debug_exceptions_pr('Prc Armar_linea', 'Campo: '
                                                   || l_campo
                                                   || sqlerrm);
    END armar_linea;

    PROCEDURE main (
        errbuf OUT NOCOPY VARCHAR2,
        retcode OUT NOCOPY VARCHAR2,
        p_payroll_id   IN   NUMBER,
        p_period_id    IN   NUMBER,
        p_date         IN   DATE
    ) IS

        l_nh_file             utl_file.file_type;
        r_nh                  t_nh_rec;
        l_result              VARCHAR2(32767);
        l_person_id           per_all_people_f.person_id%TYPE;
        l_contador            NUMBER := 0;
        l_business_group_id   NUMBER := fnd_profile.value('PER_BUSINESS_GROUP_ID');
        l_msg_error           VARCHAR2(4000);
        l_directory           VARCHAR2(2000) := ttec_library.get_directory('CUST_TOP')
                                      || '/data/EBS/HC/Payroll/Santander';
        l_file_name           VARCHAR2(2000) := 'SantanderDeposit'
                                      || to_char(sysdate, 'YYYYMMDDHHMISS')
                                      || '.txt'; --1.1
        l_charge_account      VARCHAR2(16);
        l_account_number      VARCHAR2(16);
        l_amount              NUMBER := 0;
        l_amount_wd           NUMBER := 0;
        l_payroll             VARCHAR2(250);
        l_payroll_time        VARCHAR2(250);
        lv_effective_date     date;  -- added as part of 1.4

    -- Cursores
        CURSOR c_deposits IS
        SELECT
            pap.employee_number,
            upper(pap.last_name) last_name,
            upper(pap.per_information1) per_information1,
            upper(first_name
                  || ' '
                  || middle_names) employee_names,
            SUM(brun.balance_value) deposit_amount,
            ppa.payroll_id,
            paa.assignment_id,
            pap.person_id,
            ppa.effective_date  -- added 1,2
        FROM
            /*
			hr.pay_run_balances              brun,
            hr.pay_defined_balances          bdef,
            hr.pay_balance_types             btyp,
            hr.pay_balance_categories_f      pbc,
            hr.pay_assignment_actions        paa,
            hr.pay_payroll_actions           ppa,
            hr.per_all_people_f              pap,
            hr.pay_balance_dimensions        dim, /*ITC 
            hr.per_all_assignments_f         asg,
            hr.per_assignment_status_types   pas,
            hr.per_time_periods              ptp
			*/
		--code added by RXNETHI-ARGANO,16/05/23
		    apps.pay_run_balances              brun,
            apps.pay_defined_balances          bdef,
            apps.pay_balance_types             btyp,
            apps.pay_balance_categories_f      pbc,
            apps.pay_assignment_actions        paa,
            apps.pay_payroll_actions           ppa,
            apps.per_all_people_f              pap,
            apps.pay_balance_dimensions        dim, /*ITC */
            apps.per_all_assignments_f         asg,
            apps.per_assignment_status_types   pas,
            apps.per_time_periods              ptp
		--END R12.2 Upgrade Remediation
        WHERE
            pap.business_group_id = l_business_group_id /*(FROM CONTEXT)*/
            AND pap.business_group_id = asg.business_group_id
            AND pap.person_id = asg.person_id
            AND trunc(sysdate) BETWEEN pap.effective_start_date AND pap.effective_end_date
            AND ptp.time_period_id = p_period_id
    --AND PTP.DESCRIPTION = :PAYROLL_PERIOD /*FROM PARAMETERS*/
            AND ppa.payroll_id = p_payroll_id /*FROM PARAMETERS*/
            AND asg.assignment_id = paa.assignment_id
            AND ppa.effective_date BETWEEN ptp.start_date AND ptp.end_date
            AND ptp.time_period_id = ppa.time_period_id
            AND ppa.action_type IN (
                'R',
                'Q',
                'B',
                'I',
                'V'
            )
            AND ptp.end_date BETWEEN asg.effective_start_date AND asg.effective_end_date
            AND asg.assignment_status_type_id = pas.assignment_status_type_id
            AND pas.per_system_status = 'ACTIVE_ASSIGN'
            AND paa.payroll_action_id = ppa.payroll_action_id
            AND brun.assignment_action_id = paa.assignment_action_id
            AND bdef.defined_balance_id = brun.defined_balance_id
            AND btyp.balance_type_id = bdef.balance_type_id
            AND bdef.balance_dimension_id = dim.balance_dimension_id /*ITC*/
            AND dim.database_item_suffix = '_ASG_GRE_RUN' /*ITC*/ -- 1.1
            AND btyp.balance_uom = 'M'
            AND pbc.balance_category_id = btyp.balance_category_id
            AND upper(btyp.balance_name) IN (
                'MX_TOTAL_PAY'
            ) --1.1
        GROUP BY
            pap.employee_number,
            pap.person_id,
            ppa.payroll_id,
            paa.assignment_id,
            pap.last_name,
            pap.per_information1,
            upper(first_name
                  || ' '
                  || middle_names),
            btyp.balance_name,
            ppa.effective_date;  -- added 1.2

    BEGIN
        errbuf := '';
        retcode := '0';
        BEGIN
            SELECT
                payroll_name
            INTO l_payroll
            FROM
                pay_all_payrolls_f
            WHERE
                payroll_id = p_payroll_id;

        EXCEPTION
            WHEN no_data_found THEN
                l_charge_account := NULL;
            WHEN OTHERS THEN
                debug_exceptions_pr('Prc Main - ', 'Can Not Find Payroll - ' || sqlerrm);
        END;

        BEGIN
            SELECT
                period_name
            INTO l_payroll_time
            FROM
                per_time_periods
            WHERE
                time_period_id = p_period_id;

        EXCEPTION
            WHEN no_data_found THEN
                l_payroll_time := NULL;
            WHEN OTHERS THEN
                debug_exceptions_pr('Prc Main - ', 'Can not Find Time Period - ' || sqlerrm);
        END;

        fnd_file.put_line(fnd_file.log, ' Payroll: ' || l_payroll);
        fnd_file.put_line(fnd_file.log, ' Payroll Time Periods: ' || l_payroll_time);
        fnd_file.put_line(fnd_file.log, ' Application date: ' || p_date);
        fnd_file.put_line(fnd_file.output, 'File Name: ' || l_file_name); --1.1
        IF NOT abrir_archivo(l_nh_file, l_directory, l_file_name, 'W') THEN
            errbuf := g_errbuf;
            RAISE utl_file.invalid_path;
        END IF; -- abrir_archivo(...)

        r_nh.header := true;
        BEGIN       -- added as part of 1.4
            SELECT
                effective_date into lv_effective_date
            FROM
                pay_payroll_actions ppa
            WHERE
                ppa.payroll_id = p_payroll_id
                AND ppa.business_group_id = l_business_group_id
                AND ppa.time_period_id = p_period_id
                AND ROWNUM = 1;
                EXCEPTION
            WHEN no_data_found THEN
                lv_effective_date := NULL;
            WHEN OTHERS THEN
                debug_exceptions_pr('Prc Main - ', 'Can not Find Time Period - ' || sqlerrm);

        END;

        BEGIN
            SELECT
                substr(pa.segment3, 1, 16) charge_account
            INTO l_charge_account
            FROM
                pay_org_pay_method_usages_f   pmu,
                pay_org_payment_methods_f     pm,
                pay_external_accounts         pa,
                pay_payment_types             ppt
            WHERE
                pmu.payroll_id = p_payroll_id
                AND pmu.org_payment_method_id = pm.org_payment_method_id
                AND lv_effective_date BETWEEN pmu.effective_start_date AND pmu.effective_end_date   -- added date track condition 1.4
                AND lv_effective_date BETWEEN pm.effective_start_date AND pm.effective_end_date   -- added date track condition 1.4
                AND pm.external_account_id = pa.external_account_id
                AND pm.payment_type_id = ppt.payment_type_id
                AND pm.org_payment_method_name IN (
                    'Deposit SAB',
                    'Deposit SSI',
                    'Deposit PCTA'   --added for 1.5
                    )
                AND ppt.payment_type_name = 'Mexican Direct Deposit';

        EXCEPTION
            WHEN no_data_found THEN
                l_charge_account := NULL;
            WHEN OTHERS THEN
                debug_exceptions_pr('Prc Main - ', 'Can Not Find Charge Account - ' || sqlerrm);
        END;

        r_nh.charge_account := string_pad_left(l_charge_account, 16);
        r_nh.application_date := to_char(p_date, 'MMDDYYYY');
        armar_linea(NULL, NULL, r_nh);
        l_result := generar_linea(l_nh_file, l_directory, l_file_name, r_nh, l_msg_error);
        FOR reg1 IN c_deposits LOOP

      --fnd_file.put_line(fnd_file.log,'EMPLEADO '||reg1.EMPLOYEE_NUMBER);
            r_nh := NULL;
            r_nh.employee_number := reg1.employee_number;
            r_nh.paternal_name := translate(reg1.last_name, 'ÀÁÂÃÄÅÇÈÉÊËÌÍÎÏÑÒÓÔÕÖÙÚÛÜÝàáâãäåçèéêëìíîïñòóôõöøùúûüýÿºª"°.,-|/', 'AAAAAACEEEEIIIINOOOOOUUUUYaaaaaaceeeeiiiinoooooouuuuyy         '
            );
            r_nh.maternal_name := translate(reg1.per_information1, 'ÀÁÂÃÄÅÇÈÉÊËÌÍÎÏÑÒÓÔÕÖÙÚÛÜÝàáâãäåçèéêëìíîïñòóôõöøùúûüýÿºª"°.,-|/'
            , 'AAAAAACEEEEIIIINOOOOOUUUUYaaaaaaceeeeiiiinoooooouuuuyy         ');
            r_nh.names := translate(reg1.employee_names, 'ÀÁÂÃÄÅÇÈÉÊËÌÍÎÏÑÒÓÔÕÖÙÚÛÜÝàáâãäåçèéêëìíîïñòóôõöøùúûüýÿºª"°.,-|/', 'AAAAAACEEEEIIIINOOOOOUUUUYaaaaaaceeeeiiiinoooooouuuuyy         '
            );
            BEGIN
                SELECT
                    substr(pea.segment3, 1, 16) account_number
                INTO l_account_number
                FROM
                    pay_personal_payment_methods_f   ppm,
                    pay_external_accounts            pea
                WHERE
                    business_group_id = l_business_group_id
                    AND ppm.external_account_id = pea.external_account_id
                    AND assignment_id = reg1.assignment_id
           -- Added 1.2, retrieve only active account record
                    AND reg1.effective_date BETWEEN ppm.effective_start_date AND ppm.effective_end_date;

            EXCEPTION
                WHEN no_data_found THEN
                    l_account_number := NULL;
                WHEN OTHERS THEN
                    debug_exceptions_pr('Prc Main - ', 'Can Not Find Account Number - ' || sqlerrm);
                    l_account_number := NULL;  -- Added 1.2, reset var based on too many values
            END;

            r_nh.account_number := l_account_number;
            IF reg1.deposit_amount > 0 THEN
                r_nh.deposit_amount := to_number(replace(to_char(reg1.deposit_amount, '9999999.99'), '.'));
            ELSE
                r_nh.deposit_amount := 0;
            END IF;

            l_amount_wd := reg1.deposit_amount;
            IF l_account_number IS NOT NULL THEN
                IF reg1.deposit_amount > 0 THEN
                    l_contador := l_contador + 1;
                    l_amount := l_amount + reg1.deposit_amount;
                    armar_linea(l_contador, NULL, r_nh);
                    fnd_file.put_line(fnd_file.log, r_nh.deposit_amount
                                                    || ' '
                                                    || reg1.deposit_amount
                                                    || ' '
                                                    || l_amount);

                    l_result := generar_linea(l_nh_file, l_directory, l_file_name, r_nh, l_msg_error);             ----1.3
                END IF;
            END IF;

     -- l_result:= generar_linea (l_nh_file, l_directory, l_file_name, r_nh,l_msg_error);            ----  1.3

        END LOOP;

        r_nh := NULL;
        r_nh.footer := true;
        l_contador := l_contador + 1;
--    fnd_file.put_line(fnd_file.LOG,'cont '||l_contador);
        l_amount := replace(l_amount, '.');
        fnd_file.put_line(fnd_file.log, 'L_AMOUNT :' || l_amount);
        armar_linea(l_contador, l_amount, r_nh);
        l_result := generar_linea(l_nh_file, l_directory, l_file_name, r_nh, l_msg_error);
        fnd_file.put_line(fnd_file.output, 'File Name: ' || l_file_name); --1.1
        cerrar_archivo(l_nh_file);
    EXCEPTION
        WHEN e_invalid_value THEN
            cerrar_archivo(l_nh_file);
            errbuf := nvl(errbuf, g_errbuf);
            retcode := '2';
            ROLLBACK;
        WHEN utl_file.invalid_path THEN
            cerrar_archivo(l_nh_file);
            errbuf := nvl(errbuf, g_errbuf);
            retcode := '2';
            ROLLBACK;
        WHEN OTHERS THEN
            cerrar_archivo(l_nh_file);
            errbuf := sqlerrm;
            retcode := '2';
            ROLLBACK;
    END main;

  ----------------------------------------------------------------------------------------------------------------------------------

END ttec_hr_santander_deposit_pk;
/
show errors;
/