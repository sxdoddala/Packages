create or replace PACKAGE BODY      TTEC_METLIFE_DISABILITY_INT AS
--
--
-- Program Name:  TTEC_METLIFE_DISABILITY_INT
-- /* $Header: TTEC_METLIFE_DISABILITY_INT.pkb 1.0 2013/08/20  chchan ship $ */
--
-- /*== START ================================================================================================*\
--    Author: Christiane Chan
--      Date: 20-AUG-2013

-- Call From: Concurrent Program ->TeleTech MetLife LT/ST Disability Outbound Interface
--      Desc: This program generates TeleTech employees information mandated by MetLife LT/ST Disability Standard Layout
--
--     Parameter Description:
--
--         p_business_group_id       :  Business Group ID
--         p_client_number           :  TeleTech Client Number assigned by MetLife
--         p_ltd_plan_id             :  Long Term Plan ID
--         p_vol_ltd_ft_plan_id      :  Vol. LTD FT Plan ID  /* 1.1 */
--         p_vol_ltd_pt_plan_id      :  Vol. LTD PT Plan ID  /* 1.1 */
--         p_std_plan1_id            :  Short Term Plan 1 ID
--         p_std_plan2_id            :  Short Term Plan 2 ID
--         p_std_plan1_id            :  Short Term Plan 1 ID
--         p_sub_div_code            :  Subdivision Code
--         p_branch_code1            :  Branch Code 1
--         p_branch_code2            :  Branch Code 2
--         p_branch_code3            :  Branch Code 3
--         p_branch_code5            :  Branch Code 5
--         p_branch_code6            :  Branch Code 6
--         p_branch_code9            :  Branch Code 9
--
--       Oracle Standard Parameters:
--
--   Modification History:
--
--  Version    Date     Author   Description (Include Ticket--)
--  -------  --------  --------  ------------------------------------------------------------------------------
--      1.0  08/20/13   CChan     Initial Version TTSD R#2645787 - MetLife Disability File Extract
--
--      1.1  11/05/13   CChan     Adding 2014 Voluntary LDT plan for Full Time and Part Time employees
--
--      1.4  04/14/22   C.Chan    Adding LOGIC for AVTEX employee to use the 'Adjusted Service Date' to derive the STD Branch Code
--                                                   If location code contains AVTEX, then we will derived the service date using 'Adjusted Service Date'.
--                                                  And if 'Adjusted Service Date'  is not available, we will use the start date
--
--     1.5  07/20/22   C. Chan  TASK3547441- Adding LOGIC for Faneuil employee to use the 'Adjusted Service Date' to derive the STD Branch Code.
--                                                   So the file considers the adjusted service date for all the Faneuil locations.
--                                                  This will determine if the coverage is Tenured or non tenured
--     1.0  05/MAY/23   RXNETHI-ARGANO  R12.2 Upgrade Remediation
-- \*== END ===============================================================================


    --v_module                         cust.ttec_error_handling.module_name%TYPE := 'Main';    --code commented by RXNETHI-ARGANO,05/05/23
    v_module                         apps.ttec_error_handling.module_name%TYPE := 'Main';      --code added by RXNETHI-ARGANO,05/05/23
    v_loc                            varchar2(10);
    v_msg                            varchar2(2000);
    v_rec                            varchar2(5000);

    /************************************************************************************/
    /*                                  MAIN                                */
    /************************************************************************************/

PROCEDURE main(
          errcode                     OUT VARCHAR2,
          errbuff                     OUT VARCHAR2,
          p_as_of_date                IN varchar2,
          p_business_group_id          IN NUMBER,
          p_client_number              IN VARCHAR2,
          p_ltd_plan_id               IN NUMBER,
          p_vol_ltd_ft_plan_id        IN NUMBER, /* 1.1 */
          p_vol_ltd_pt_plan_id        IN NUMBER, /* 1.1 */
          p_std_plan1_id              IN NUMBER,
          p_std_plan2_id              IN NUMBER,
--          p_ltd_group_no              IN VARCHAR2,
--          p_std_group1_no             IN VARCHAR2,
--          p_std_group2_no             IN VARCHAR2,
          p_sub_div_code              IN VARCHAR2,
          p_branch_code1              IN VARCHAR2,
          p_branch_code2              IN VARCHAR2,
          p_branch_code3              IN VARCHAR2,
          p_branch_code5              IN VARCHAR2,
          p_branch_code6              IN VARCHAR2,
          p_branch_code9              IN VARCHAR2, /* 1.1 */
          p_termed_since_no_days      IN number
    ) IS

        -- Declare variables

    --v_bg_name               hr.hr_all_organization_units.name%TYPE; --code commented by RXNETHI-ARGANO, 05/05/23

    --v_std_pl_id             ben.ben_prtt_enrt_rslt_f.pl_id%TYPE; --code commented by RXNETHI-ARGANO, 05/05/23
	
	v_bg_name               apps.hr_all_organization_units.name%TYPE; --code added by RXNETHI-ARGANO, 05/05/23

    v_std_pl_id             apps.ben_prtt_enrt_rslt_f.pl_id%TYPE;  --code added by RXNETHI-ARGANO, 05/05/23
    v_std_bnft_amt              VARCHAR2(10);
    v_std_ORGNL_ENRT_DT         VARCHAR2(10);
    v_std_enrt_cvg_thru_dt      VARCHAR2(10);
    v_std_pre_tx_ind            VARCHAR2(10);
    v_std_er_pln_pct            VARCHAR2(10);
    v_std_ee_pre_tx_pct         VARCHAR2(10);

    --v_ltd_pl_id             ben.ben_prtt_enrt_rslt_f.pl_id%TYPE; --code commented by RXNETHI-ARGANO,05/05/23
    v_ltd_pl_id             apps.ben_prtt_enrt_rslt_f.pl_id%TYPE; --code added by RXNETHI-ARGANO,05/05/23
	v_ltd_bnft_amt              VARCHAR2(10);
    v_ltd_ORGNL_ENRT_DT         VARCHAR2(10);
    v_ltd_enrt_cvg_thru_dt      VARCHAR2(10);
    v_ltd_pre_tx_ind            VARCHAR2(10);
    v_ltd_er_pln_pct            VARCHAR2(10);
    v_ltd_ee_pre_tx_pct         VARCHAR2(10);


    v_emp_count             number:=0;

   BEGIN
    v_loc := '01';
    v_module := 'c_param';
        Fnd_File.put_line(Fnd_File.LOG, v_loc||' '||v_module);
    Fnd_File.put_line(Fnd_File.LOG, '');
    Fnd_File.put_line(Fnd_File.LOG,'--------------------------------------------------------------------------------------------------------------------------------------------------');
    Fnd_File.put_line(Fnd_File.LOG, '');
    Fnd_File.put_line(Fnd_File.LOG,'Concurrent Program -> TeleTech MetLife ST/LT Disability Outbound Interface');
    Fnd_File.put_line(Fnd_File.LOG, '');
    Fnd_File.put_line(Fnd_File.LOG,'Parameters:                  ');
    Fnd_File.put_line(Fnd_File.LOG,'             Business Group ID: '||p_business_group_id);
    Fnd_File.put_line(Fnd_File.LOG,'                 Client Number: '||p_client_number);
    Fnd_File.put_line(Fnd_File.LOG,'             Long Term Plan ID: '||p_ltd_plan_id);
    Fnd_File.put_line(Fnd_File.LOG,'           Vol. LTD FT Plan ID: '||p_vol_ltd_ft_plan_id);
    Fnd_File.put_line(Fnd_File.LOG,'           Vol. LTD PT Plan ID: '||p_vol_ltd_pt_plan_id);
    Fnd_File.put_line(Fnd_File.LOG,'          Short Term Plan 1 ID: '||p_std_plan1_id);
    Fnd_File.put_line(Fnd_File.LOG,'          Short Term Plan 2 ID: '||p_std_plan2_id);
--          p_ltd_group_no              IN VARCHAR2,
--          p_std_group1_no             IN VARCHAR2,
--          p_std_group2_no             IN VARCHAR2,
    Fnd_File.put_line(Fnd_File.LOG,'              Subdivision Code: '||p_sub_div_code);
    Fnd_File.put_line(Fnd_File.LOG,'                 Branch Code 1: '||p_branch_code1);
    Fnd_File.put_line(Fnd_File.LOG,'                 Branch Code 2: '||p_branch_code2);
    Fnd_File.put_line(Fnd_File.LOG,'                 Branch Code 3: '||p_branch_code3);
    Fnd_File.put_line(Fnd_File.LOG,'                 Branch Code 5: '||p_branch_code5);
    Fnd_File.put_line(Fnd_File.LOG,'                 Branch Code 6: '||p_branch_code6);
    Fnd_File.put_line(Fnd_File.LOG,'                 Branch Code 9: '||p_branch_code9);
    Fnd_File.put_line(Fnd_File.LOG,'--------------------------------------------------------------------------------------------------------------------------------------------------');

    v_loc := '02';
    v_module := 'c_global';
        Fnd_File.put_line(Fnd_File.LOG, v_loc||' '||v_module);

    g_business_group_id := p_business_group_id;
    g_client_number     := p_client_number;
    g_ltd_plan_id       := p_ltd_plan_id;
    g_vol_ltd_ft_plan_id:= p_vol_ltd_ft_plan_id; /* 1.1 */
    g_vol_ltd_pt_plan_id:= p_vol_ltd_pt_plan_id; /* 1.1 */
    g_std_plan1_id      := p_std_plan1_id;
    g_std_plan2_id      := p_std_plan2_id;
    g_termed_since_no_days := p_termed_since_no_days;

    /* 1.1 Begin */
    IF p_as_of_date = 'DD-MON-RRRR' THEN
     g_as_of_date := to_char(sysdate,'DD-MON-RRRR');
    ELSE
     g_as_of_date := p_as_of_date;
    END IF;
    /* 1.1 End */

    v_loc := '03';
    v_module := 'c_session';
        Fnd_File.put_line(Fnd_File.LOG, v_loc||' '||v_module);
    INSERT INTO FND_SESSIONS VALUES (USERENV('SESSIONID'), trunc(sysdate)); /* 1.1 */
    v_loc := '10';
    v_module := 'c_bg';
        Fnd_File.put_line(Fnd_File.LOG, v_loc||' '||v_module);
    open c_bg;
    fetch c_bg into v_bg_name;
    close c_bg;

    v_module := 'c_directory_path';
    v_loc := '20';
        Fnd_File.put_line(Fnd_File.LOG, v_loc||' '||v_module);
    open c_directory_path;
    fetch c_directory_path into v_file_path,v_filename;
    close c_directory_path;

    v_loc := '30';
    Fnd_File.put_line(Fnd_File.LOG, '');
    Fnd_File.put_line(Fnd_File.LOG,'--------------------------------------------------------------------------------------------------------------------------------------------------');
    Fnd_File.put_line(Fnd_File.LOG, '');
    Fnd_File.put_line(Fnd_File.LOG,'               g_client_number: '||g_client_number);
    Fnd_File.put_line(Fnd_File.LOG,'                 g_ltd_plan_id: '||g_ltd_plan_id);
    Fnd_File.put_line(Fnd_File.LOG,'          g_vol_ltd_ft_plan_id: '||g_vol_ltd_ft_plan_id);
    Fnd_File.put_line(Fnd_File.LOG,'          g_vol_ltd_pt_plan_id: '||g_vol_ltd_pt_plan_id);
    Fnd_File.put_line(Fnd_File.LOG,'                g_std_plan1_id: '||g_std_plan1_id);
    Fnd_File.put_line(Fnd_File.LOG,'                g_std_plan2_id: '||g_std_plan2_id);
    Fnd_File.put_line(Fnd_File.LOG,'--------------------------------------------------------------------------------------------------------------------------------------------------');

    v_loc := '40';
    v_module := 'Open File';
    Fnd_File.put_line(Fnd_File.LOG, v_loc||' '||v_module);
    v_output_file := UTL_FILE.FOPEN(v_file_path, v_filename, 'w');

    v_loc := '50';
    v_module := 'Header Rec';
    Fnd_File.put_line(Fnd_File.LOG, v_loc||' '||v_module);
    v_rec :=  'A'
            || NVL(substr(g_client_number,1,7),LPAD('0',7,'0'))
            ||to_char(SYSDATE,'MMDDYYYY')
            ||RPAD(v_bg_name,50,' ')
            ||'N';

    apps.fnd_file.put_line(apps.fnd_file.output,v_rec);
    utl_file.put_line(v_output_file, v_rec);


    v_loc := '60';
    v_module := 'Emp Rec';
    Fnd_File.put_line(Fnd_File.LOG, v_loc||' '||v_module);
    --print_detail_column_name;

    FOR emp_rec IN c_emp_cur
    LOOP

        --Fnd_File.put_line(Fnd_File.LOG, v_loc||v_module||' Person_id'||emp_rec.person_id);
        g_emp_no := emp_rec.person_id;
        v_loc := 70;
        v_module := 'Emp Basic';
        v_rec :=  emp_rec.emp_basic_info;                                                              -- Field 1    CLIENT NUMBER

        v_loc := 80;
        v_module := 'Emp Rec';

        v_std_pl_id             := '';
        v_std_bnft_amt          := '';
        v_std_ORGNL_ENRT_DT     := '';
        v_std_enrt_cvg_thru_dt  := '';

        v_ltd_pl_id             := '';
        v_ltd_bnft_amt          := '';
        v_ltd_ORGNL_ENRT_DT     := '';
        v_ltd_enrt_cvg_thru_dt  := '';


--        For STD and LTD - group number, subdivision code(s) and branch codes.
--             Plans:
--          i.      Long Term Disability - All Active Full Time Employees (except Corp)                 0143329 0001 0001
--         ii.      Long Term Disability - All Corp Employees                                           0143329 0001 0001
--        iii.      Long Term Disability - VP Employees                                                 0143329 0001 0002
--         iv.      Short Term Disability - FT EEs Not NY DBL and Not Corp                              0143329 0001 0001
--          v.      Short Term Disability - Voluntary NY STD NOT the NY DBL                             0143447 0001 0001
--         vi.      Short Term Disability - FT Corporate EEs less than 2 yrs                            0143329 0001 0005
--        vii.      Short Term Disability - FT Corp EEs 2 or more yrs of service                        0143329 0001 0006

--        If an employee resides in NY then they are the only ones that go to the plan                  0143447 0001 0001
--        If an employee resides in any other state but is not a corp employee then they would go to    0143329 0001 0001


        v_loc := '80';
        v_module := 'Emp STD';
        --Fnd_File.put_line(Fnd_File.LOG, v_loc||v_module||' Person_id'||emp_rec.person_id);

        open c_std_plan_cur(emp_rec.person_id,emp_rec.emp_process_date);

        fetch c_std_plan_cur into v_std_pl_id,v_std_bnft_amt,v_std_ORGNL_ENRT_DT,v_std_enrt_cvg_thru_dt,v_std_pre_tx_ind,v_std_er_pln_pct,v_std_ee_pre_tx_pct;
        close c_std_plan_cur;

        IF v_std_pl_id IS NOT NULL THEN
            v_rec := v_rec || 'ST'
                           || NVL(substr(v_std_ORGNL_ENRT_DT,1,8),RPAD(' ',8,' '))
                           || NVL(substr(v_std_enrt_cvg_thru_dt,1,8),RPAD(' ',8,' '));
        ELSE
            v_rec := v_rec || '  '
                           || RPAD(' ',8,' ')
                           || RPAD(' ',8,' ');
        END IF;
        --
        -- For STD, assigning group number and subdivision code
        --
        IF v_std_pl_id = p_std_plan1_id THEN   -- Corp STD Plan

           v_rec := v_rec || NVL(substr(g_client_number,1,7),RPAD(' ',7,' '))
                          || NVL(substr(p_sub_div_code ,1,4),RPAD(' ',4,' '));

           /* 1.4 Begin */
           IF         UPPER(emp_rec.location_code) LIKE '%AVTEX%'
                OR  UPPER(emp_rec.location_code) LIKE '%FANEUIL%'  -- 1.5
           THEN
                      IF emp_rec.adjusted_svc_date IS NOT NULL THEN
                            IF emp_rec.emp_adj_year_of_service >= 2 THEN
                                 v_rec := v_rec || NVL(substr(p_branch_code6 ,1,4),RPAD(' ',4,' '));   -- assigning subdivision code
                            ELSE
                                 v_rec := v_rec || NVL(substr(p_branch_code5 ,1,4),RPAD(' ',4,' '));
                             END IF; --adj_servoce_date
                        ELSE
                            IF emp_rec.emp_year_of_service >= 2 THEN
                                 v_rec := v_rec || NVL(substr(p_branch_code6 ,1,4),RPAD(' ',4,' '));   -- assigning subdivision code
                            ELSE
                                 v_rec := v_rec || NVL(substr(p_branch_code5 ,1,4),RPAD(' ',4,' '));
                             END IF; --start_date
                      END IF;
                      /* 1.4 End */
           ELSE -- All non AVTEX
                  IF emp_rec.emp_year_of_service >= 2 THEN
                 --
                 -- assigning subdivision code
                 --
                 v_rec := v_rec || NVL(substr(p_branch_code6 ,1,4),RPAD(' ',4,' '));

                ELSE
                  --
                  -- assigning subdivision code
                  --
                  v_rec := v_rec || NVL(substr(p_branch_code5 ,1,4),RPAD(' ',4,' '));
               END IF;
           END IF;

        ELSIF v_std_pl_id = p_std_plan2_id THEN -- NY STD Plan

           v_rec := v_rec || NVL(substr(g_client_number,1,7),RPAD(' ',7,' '))
                          || NVL(substr(p_sub_div_code ,1,4),RPAD(' ',4,' '));

           IF emp_rec.emp_residence_state = 'NY' THEN

               --
               -- assigning subdivision code
               --
               v_rec := v_rec || NVL(substr(p_branch_code3 ,1,4),RPAD(' ',4,' '));

           ELSE

               --
               -- assigning subdivision code
               --
               v_rec := v_rec || NVL(substr(p_branch_code1 ,1,4),RPAD(' ',4,' '));
           END IF;

        ELSE
            v_rec := v_rec || RPAD(' ',7,' ')
                           || RPAD(' ',4,' ')
                           || RPAD(' ',4,' ');
        END IF;

        IF v_std_pl_id IS NOT NULL THEN

            v_rec := v_rec || '  '
                           || NVL(substr(v_std_bnft_amt   ,1,8),RPAD(' ',8,' '))
                           || NVL(substr(v_std_pre_tx_ind ,1,1),' ')
                           || NVL(substr(v_std_er_pln_pct ,1,3),RPAD(' ',3,' '))
                           || NVL(substr(v_std_ee_pre_tx_pct ,1,3),RPAD(' ',3,' '));
        ELSE

            v_rec := v_rec || '  '
                           || RPAD(' ',8,' ')
                           || ' '
                           || RPAD(' ',3,' ')
                           || RPAD(' ',3,' ');

        END IF;

        v_loc := 90;
        v_module := 'Emp LTD';
        --Fnd_File.put_line(Fnd_File.LOG, v_loc||v_module||' Person_id'||emp_rec.person_id);

        open c_ltd_plan_cur(emp_rec.person_id,emp_rec.emp_process_date);
        fetch c_ltd_plan_cur into v_ltd_pl_id,v_ltd_bnft_amt,v_ltd_ORGNL_ENRT_DT,v_ltd_enrt_cvg_thru_dt,v_ltd_pre_tx_ind,v_ltd_er_pln_pct,v_ltd_ee_pre_tx_pct;
        close c_ltd_plan_cur;


        IF v_ltd_pl_id IS NOT NULL THEN
            v_rec := v_rec || 'LT'
                           || NVL(substr(v_ltd_ORGNL_ENRT_DT,1,8),RPAD(' ',8,' '))
                           || NVL(substr(v_ltd_enrt_cvg_thru_dt,1,8),RPAD(' ',8,' '))
                           || NVL(substr(g_client_number,1,7),RPAD(' ',7,' '))
                           || NVL(substr(p_sub_div_code ,1,4),RPAD(' ',4,' '));
        ELSE
            v_rec := v_rec || '  '
                           || RPAD(' ',8,' ')
                           || RPAD(' ',8,' ')
                           || RPAD(' ',7,' ')
                           || RPAD(' ',4,' ');
        END IF;
        IF v_ltd_pl_id IS NOT NULL THEN
            IF emp_rec.VP_indicator = 'Y' THEN
               v_rec := v_rec || NVL(substr(p_branch_code2 ,1,4),RPAD(' ',4,' '));
            ELSIF v_ltd_pl_id = p_ltd_plan_id THEN
               v_rec := v_rec || NVL(substr(p_branch_code1 ,1,4),RPAD(' ',4,' '));
            ELSE
               v_rec := v_rec || NVL(substr(p_branch_code9 ,1,4),RPAD(' ',4,' '));
            END IF;

            v_rec := v_rec || '  '
                           || NVL(substr(v_ltd_bnft_amt   ,1,8),RPAD(' ',8,' '))
                           || NVL(substr(v_ltd_pre_tx_ind ,1,1),' ')
                           || NVL(substr(v_ltd_er_pln_pct ,1,3),RPAD(' ',3,' '))
                           || NVL(substr(v_ltd_ee_pre_tx_pct ,1,3),RPAD(' ',3,' '));
        ELSE
            v_rec := v_rec || RPAD(' ',4,' ')
                           || '  '
                           || RPAD(' ',8,' ')
                           || ' '
                           || RPAD(' ',3,' ')
                           || RPAD(' ',3,' ');

        END IF;



        apps.fnd_file.put_line(apps.fnd_file.output,v_rec);
        utl_file.put_line(v_output_file, v_rec);

        v_emp_count := v_emp_count + 1;

    END LOOP; /* Employees */

    v_loc := '70';
    v_module := 'Trailer Rec';
    v_rec :=  'Z'
            || NVL(substr(g_client_number,1,7),LPAD('0',7,'0'))
            || LPAD(v_emp_count,8,'0')
            ;

    apps.fnd_file.put_line(apps.fnd_file.output,v_rec);
    utl_file.put_line(v_output_file, v_rec);

    v_loc := 80;
    v_module := 'Close File';

    UTL_FILE.FCLOSE(v_output_file);

    EXCEPTION
    WHEN UTL_FILE.INVALID_OPERATION THEN
        UTL_FILE.FCLOSE(v_output_file);
        RAISE_APPLICATION_ERROR(-20051, v_filename ||':  Invalid Operation');

    WHEN UTL_FILE.INVALID_FILEHANDLE THEN
        UTL_FILE.FCLOSE(v_output_file);
        RAISE_APPLICATION_ERROR(-20052, v_filename ||':  Invalid File Handle');

    WHEN UTL_FILE.READ_ERROR THEN
        UTL_FILE.FCLOSE(v_output_file);
        RAISE_APPLICATION_ERROR(-20053, v_filename ||':  Read Error');
        ROLLBACK;
    WHEN UTL_FILE.INVALID_PATH THEN
        UTL_FILE.FCLOSE(v_output_file);
        RAISE_APPLICATION_ERROR(-20054, v_file_path ||':  Invalid Path');

    WHEN UTL_FILE.INVALID_MODE THEN
        UTL_FILE.FCLOSE(v_output_file);
        RAISE_APPLICATION_ERROR(-20055, v_filename ||':  Invalid Mode');

    WHEN UTL_FILE.WRITE_ERROR THEN
        UTL_FILE.FCLOSE(v_output_file);
        RAISE_APPLICATION_ERROR(-20056, v_filename ||':  Write Error');

    WHEN UTL_FILE.INTERNAL_ERROR THEN
        UTL_FILE.FCLOSE(v_output_file);
        RAISE_APPLICATION_ERROR(-20057, v_filename ||':  Internal Error');

    WHEN UTL_FILE.INVALID_MAXLINESIZE THEN
         UTL_FILE.FCLOSE(v_output_file);
         RAISE_APPLICATION_ERROR(-20058, v_filename ||':  Maxlinesize Error');

    WHEN INVALID_CURSOR
    THEN

         UTL_FILE.FCLOSE(v_output_file);

         ttec_error_logging.process_error( g_application_code -- 'HR'
                                         , g_interface        -- 'MetLife Dis Intf';
                                         , g_package          -- 'TTEC_METLIFE_DISABILITY_INT'
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
          Fnd_File.put_line(Fnd_File.LOG, v_loc||' Module'||v_module||' Emp No'||g_emp_no ||' Err Code'||errcode|| 'Err MSG'||errbuff);

    WHEN OTHERS
    THEN
         UTL_FILE.FCLOSE(v_output_file);

         ttec_error_logging.process_error( g_application_code -- 'HR'
                                         , g_interface        -- 'MetLife Dis Intf';
                                         , g_package          -- 'TTEC_METLIFE_DISABILITY_INT'
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
          Fnd_File.put_line(Fnd_File.LOG, v_loc||' Module'||v_module||' Emp No'||g_emp_no||' Err Code'||errcode|| 'Err MSG'||errbuff);

        RAISE_APPLICATION_ERROR(-20003,'Exception OTHERS in TTEC_METLIFE_DISABILITY_INT.main: '||'Module >-' ||v_module||' ['||g_label1||']['||v_loc||']['||g_label2||']['||g_emp_no|| '] ERROR:'||errbuff);

    END main;

END TTEC_METLIFE_DISABILITY_INT;
/
show errors;
/