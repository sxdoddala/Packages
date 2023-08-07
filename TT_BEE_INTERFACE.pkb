create or replace package body TT_BEE_INTERFACE is






/************************************************************************************
        Program Name:     TT_BEE_INTERFACE

        Description:   

        Developed by : 
        Date         :  

       Modification Log
       Name                  Version #    Date            Description
       -----                 --------     -----           -------------
    RXNETHI(ARGANO)            1.0      29-JUN-2023      R12.2 Upgrade Remediation
    ****************************************************************************************/








  /************************************************************************************/
  /*                                   IS_NUMBER                                      */
  /************************************************************************************/
    FUNCTION is_number(p_value IN VARCHAR2) RETURN VARCHAR2 IS

    p_is_num VARCHAR2(10):= NULL;
    l_number NUMBER := NULL;

    BEGIN
      -- set global module name for error handling
	    g_module_name := 'is_number';

      l_number := to_number(nvl(p_value,'0'));

      p_is_num := 'TRUE';
      RETURN p_is_num;

    EXCEPTION
             WHEN INVALID_NUMBER THEN
			          p_is_num := 'FALSE';
                RETURN p_is_num;

             WHEN VALUE_ERROR THEN
			          p_is_num := 'FALSE';
                RETURN p_is_num;

             WHEN OTHERS THEN
			          g_error_message := SQLERRM;
                RAISE;

    END;

  /************************************************************************************/
  /*                                 GET_LOOKUP_CODE                                  */
  /************************************************************************************/
    FUNCTION get_lookup_code(p_lookup_type IN VARCHAR2, p_meaning IN VARCHAR2) RETURN VARCHAR2 IS

    p_lookup_code VARCHAR2(30):= NULL;

    BEGIN
      -- set global module name for error handling
	    g_module_name := 'get_lookup_code';

      SELECT fcl.lookup_code
	    INTO p_lookup_code
	    FROM apps.fnd_common_lookups fcl
	    WHERE fcl.lookup_type = p_lookup_type
      AND fcl.meaning = p_meaning;

    RETURN p_lookup_code;

    EXCEPTION

             WHEN NO_DATA_FOUND THEN
			          g_error_message := 'No Data Found when attempting to determine '||p_lookup_type||'.';
                RAISE ERROR_SETTING_DEFAULTS;

             WHEN TOO_MANY_ROWS THEN
			          g_error_message := 'Too Many Rows when attempting to determine '||p_lookup_type||'.';
                RAISE ERROR_SETTING_DEFAULTS;

             WHEN OTHERS THEN
			          g_error_message := 'Other Error for '||p_lookup_type||': '||SQLERRM;
                RAISE ERROR_SETTING_DEFAULTS;

    END;

  /************************************************************************************/
  /*                                 GET_ELEMENT_VALUE_NAME                           */
  /************************************************************************************/
    FUNCTION get_element_value_name(p_element_name IN VARCHAR2
                                   ,p_element_type_id IN NUMBER
                                   ,p_display_seq IN NUMBER
                                   ,p_effective_date IN DATE DEFAULT SYSDATE) RETURN VARCHAR2 IS

    --l_element_value_name hr.pay_input_values_f.name%TYPE := NULL;   --code commented by RXNETHI-ARGANO,29/06/23
    l_element_value_name apps.pay_input_values_f.name%TYPE := NULL;   --code added by RXNETHI-ARGANO,29/06/23
    l_loop_count NUMBER := 0;

    CURSOR csr_name_list IS
      SELECT pivf.name
      --FROM hr.pay_element_types_f petf , hr.pay_input_values_f pivf   --code commented by RXNETHI-ARGANO,29/06/23
      FROM apps.pay_element_types_f petf , apps.pay_input_values_f pivf --code added by RXNETHI-ARGANO,29/06/23
      WHERE petf.element_type_id = pivf.element_type_id
      AND petf.element_name = p_element_name
      AND petf.element_type_id = p_element_type_id
      AND p_effective_date BETWEEN pivf.effective_start_date AND pivf.effective_end_date
      ORDER BY pivf.display_sequence, pivf.name;

    BEGIN
      -- set global module name for error handling
	    g_module_name := 'get_element_value_name';

      -- close cursor if open
      IF csr_name_list%ISOPEN THEN
          CLOSE csr_name_list;
      END IF;

      FOR sel IN csr_name_list LOOP
          -- update counter
          l_loop_count := l_loop_count +1;
          -- set element name
          l_element_value_name := sel.name;
          -- check sequence, if correct display sequence, return value
          IF l_loop_count = p_display_seq THEN
             RETURN l_element_value_name;
          END IF;
      END LOOP;

      -- did not find correct sequence number or no values
      l_element_value_name := null;
      RETURN l_element_value_name;

    EXCEPTION
             WHEN NO_DATA_FOUND THEN
               l_element_value_name := NULL;
               RETURN l_element_value_name;

             WHEN OTHERS THEN
               g_error_message := SQLERRM;
               RAISE;

    END;

  /************************************************************************************/
  /*                            GET_UNPROCESSED_BATCH_COUNT                           */
  /************************************************************************************/
    PROCEDURE get_unprocessed_batch_count(p_count OUT NUMBER) IS

    BEGIN
      -- set global module name for error handling
	    g_module_name := 'get_unprocessed_batch_count';

      SELECT count(distinct tbis.batch_name)
	    INTO p_count
	    --FROM cust.tt_bee_interface_stage tbis   --code commented by RXNETHI-ARGANO,29/06/23
	    FROM apps.tt_bee_interface_stage tbis     --code added by RXNETHI-ARGANO,29/06/23
	    WHERE tbis.record_processed = 'N';

    EXCEPTION
             WHEN OTHERS THEN
               g_error_message := SQLERRM;
               RAISE;

    END;

  /************************************************************************************/
  /*                              VALIDATE_EMPLOYEE_NUMBER                            */
  /************************************************************************************/
    PROCEDURE validate_employee_number(p_emp_num IN VARCHAR2, p_business_group_id IN NUMBER
                                      ,p_count OUT NUMBER) IS

    BEGIN
      -- set global module name for error handling
	    g_module_name := 'validate_employee_num';

      SELECT count(*)
	    INTO p_count
	    --FROM hr.per_all_people_f papf    --code commented by RXNETHI-ARGANO,29/06/23
	    FROM apps.per_all_people_f papf    --code added by RXNETHI-ARGANO,29/06/23
	    WHERE papf.employee_number = p_emp_num
      AND papf.business_group_id = p_business_group_id;

    EXCEPTION
             WHEN NO_DATA_FOUND THEN
			          g_error_message := 'No Data Found';
                RAISE;

             WHEN TOO_MANY_ROWS THEN
			          g_error_message := 'Too Many Rows';
                RAISE;

             WHEN OTHERS THEN
			          g_error_message := SQLERRM;
                RAISE;
    END;

  /************************************************************************************/
  /*                                  GET_BATCH_ID                                    */
  /************************************************************************************/
    PROCEDURE get_batch_id(p_batch_id OUT NUMBER) IS

    BEGIN
      -- set global module name for error handling
  	  g_module_name := 'get_batch_id';

      --SELECT hr.pay_batch_headers_s.nextval  --code commented by RXNETHI-ARGANO,29/06/23
      SELECT apps.pay_batch_headers_s.nextval  --code added by RXNETHI-ARGANO,29/06/23
      INTO p_batch_id
      FROM dual;

    EXCEPTION
             WHEN OTHERS THEN
      			   g_error_message := SQLERRM;
               RAISE;

    END;

  /************************************************************************************/
  /*                                GET_BATCH_LINE_ID                                 */
  /************************************************************************************/
    PROCEDURE get_batch_line_id(p_batch_line_id OUT NUMBER) IS

    BEGIN
      -- set global module name for error handling
	    g_module_name := 'get_batch_line_id';

      --SELECT hr.pay_batch_lines_s.nextval   --code commented by RXNETHI-ARGANO,29/06/23
      SELECT apps.pay_batch_lines_s.nextval   --code added by RXNETHI-ARGANO,29/06/23
      INTO p_batch_line_id
      FROM dual;

    EXCEPTION
             WHEN OTHERS THEN
      			   g_error_message := SQLERRM;
               RAISE;

    END;

  /************************************************************************************/
  /*                                GET_ASSIGNMENT_INFO                               */
  /************************************************************************************/
    PROCEDURE get_assignment_info(p_employee_number IN VARCHAR2, p_business_group_id IN NUMBER
                                 ,p_effective_date IN DATE, p_assignment_id OUT NUMBER
                                 ,p_assignment_number OUT VARCHAR2, p_payroll_id OUT NUMBER) IS

    BEGIN
      -- set global module name for error handling
  	  g_module_name := 'get_assign_info';
  	  g_label2 := 'Bus Grp ID';
  	  g_secondary_column := p_business_group_id;

      SELECT b.assignment_id, b.assignment_number, b.payroll_id
      INTO p_assignment_id, p_assignment_number, p_payroll_id
      --FROM hr.per_all_people_f a, hr.per_all_assignments_f b     --code commented by RXNETHI-ARGANO,29/06/23
      FROM apps.per_all_people_f a, apps.per_all_assignments_f b   --code added by RXNETHI-ARGANO,29/06/23
      WHERE a.person_id = b.person_id
      AND a.business_group_id = b.business_group_id
      AND a.business_group_id = p_business_group_id
      AND p_effective_date BETWEEN a.effective_start_date AND NVL(a.effective_end_date, g_oracle_end_date)
      AND p_effective_date BETWEEN b.effective_start_date AND NVL(b.effective_end_date, g_oracle_end_date)
      AND b.primary_flag = 'Y'
      AND a.employee_number = p_employee_number;

    EXCEPTION

             WHEN NO_DATA_FOUND THEN
			         g_error_message := 'No Data Found when getting assignment information';
               RAISE SKIP_RECORD;

             WHEN TOO_MANY_ROWS THEN
			         g_error_message := 'Too Many Rows returned when getting assignment information';
               RAISE SKIP_RECORD;

             WHEN OTHERS THEN
			         g_error_message := SQLERRM;
               RAISE SKIP_RECORD;

    END;

  /************************************************************************************/
  /*                                GET_EMPLOYEE_NAME                                 */
  /************************************************************************************/
    PROCEDURE get_employee_name(p_employee_number IN VARCHAR2, p_business_group_id IN NUMBER
                               ,p_effective_date IN DATE, p_employee_name OUT VARCHAR2) IS

    BEGIN
      -- set global module name for error handling
	    g_module_name := 'get_emp_name';
  	  g_label2 := 'Bus Grp ID';
  	  g_secondary_column := p_business_group_id;

      SELECT papf.full_name
      INTO p_employee_name
      --FROM hr.per_all_people_f papf   --code commented by RXNETHI-ARGANO,29/06/23
      FROM apps.per_all_people_f papf   --code added by RXNETHI-ARGANO,29/06/23
      WHERE papf.employee_number = p_employee_number
      AND papf.business_group_id = p_business_group_id
      AND p_effective_date BETWEEN papf.effective_start_date AND papf.effective_end_date;

    EXCEPTION

             WHEN NO_DATA_FOUND THEN
			         g_error_message := 'No Data Found when getting employee name';
               RAISE SKIP_RECORD;

             WHEN TOO_MANY_ROWS THEN
			         g_error_message := 'Too Many Rows returned when getting employee name';
               RAISE SKIP_RECORD;

             WHEN OTHERS THEN
			         g_error_message := SQLERRM;
               RAISE SKIP_RECORD;

    END;

  /************************************************************************************/
  /*                                GET_ELEMENT_TYPE_ID                               */
  /************************************************************************************/
    PROCEDURE get_element_type_id(p_element_name IN VARCHAR2, p_business_group_id IN NUMBER
                                 ,p_effective_date IN DATE, p_element_type_id OUT NUMBER) IS

    BEGIN
      -- set global module name for error handling
	    g_module_name := 'get_element_type_id';
  	  g_label2 := 'Element Name';
  	  g_secondary_column := p_element_name;

      SELECT petf.element_type_id
      INTO p_element_type_id
      --FROM hr.pay_element_types_f petf   --code commented by RXNETHI-ARGANO,29/06/23
      FROM apps.pay_element_types_f petf   --code added by RXNETHI-ARGANO,29/06/23
      WHERE petf.business_group_id = p_business_group_id
      AND p_effective_date BETWEEN petf.effective_start_date AND petf.effective_end_date
      AND UPPER(petf.element_name) = UPPER(p_element_name);

    EXCEPTION

             WHEN NO_DATA_FOUND THEN
			         g_error_message := 'No Data Found when getting element type id';
               RAISE SKIP_RECORD;

             WHEN TOO_MANY_ROWS THEN
			         g_error_message := 'Too Many Rows returned when getting element type id';
               RAISE SKIP_RECORD;

             WHEN OTHERS THEN
			         g_error_message := SQLERRM;
               RAISE SKIP_RECORD;

    END;

  /************************************************************************************/
  /*                                CREATE_BEE_HEADER                                 */
  /************************************************************************************/
    PROCEDURE create_bee_header(p_batch_id IN NUMBER,p_business_group_id IN NUMBER
                               ,p_batch_status IN VARCHAR2
                               ,p_action_if_exists IN VARCHAR2
                               ,p_purge_after_transfer IN VARCHAR2
                               ,p_reject_if_future_changes IN VARCHAR2) IS

    BEGIN
      -- set global module name for error handling
	    g_module_name := 'create_bee_header';

      INSERT
      --INTO hr.pay_batch_headers(batch_id, business_group_id, batch_name, batch_status, action_if_exists  --code commented by RXNETHI-ARGANO,29/06/23
      INTO apps.pay_batch_headers(batch_id, business_group_id, batch_name, batch_status, action_if_exists  --code added by RXNETHI-ARGANO,29/06/23
          ,batch_reference, batch_source, purge_after_transfer, reject_if_future_changes)
	    VALUES (p_batch_id, p_business_group_id, g_batch_name, p_batch_status, p_action_if_exists
          ,c_batch_reference, c_batch_source, p_purge_after_transfer, p_reject_if_future_changes);

    EXCEPTION
             WHEN OTHERS THEN
      			   g_error_message := SQLERRM;
               RAISE;

    END;

  /************************************************************************************/
  /*                                CREATE_BEE_LINE                                   */
  /************************************************************************************/
    PROCEDURE create_bee_line(p_batch_id IN NUMBER, p_batch_line_id IN NUMBER
                             ,p_element_type_id IN NUMBER, p_assignment_id IN NUMBER
                             ,p_batch_status IN VARCHAR2, p_assignment_number IN VARCHAR2
                             ,p_batch_sequence IN NUMBER, p_effective_date IN DATE
                             ,p_element_name IN VARCHAR2, p_entry_type IN VARCHAR2
                             ,p_value1 IN VARCHAR2 DEFAULT NULL
                             ,P_value2 IN VARCHAR2 DEFAULT NULL
                             ,p_value3 IN VARCHAR2 DEFAULT NULL
                             ,p_value4 IN VARCHAR2 DEFAULT NULL
                             ,p_value5 IN VARCHAR2 DEFAULT NULL
                             ,p_value6 IN VARCHAR2 DEFAULT NULL
                             ,p_value7 IN VARCHAR2 DEFAULT NULL
                             ,p_value8 IN VARCHAR2 DEFAULT NULL
                             ,p_value9 IN VARCHAR2 DEFAULT NULL
                             ,p_value10 IN VARCHAR2 DEFAULT NULL
                             ,p_value11 IN VARCHAR2 DEFAULT NULL
                             ,p_value12 IN VARCHAR2 DEFAULT NULL
                             ,p_value13 IN VARCHAR2 DEFAULT NULL
                             ,p_value14 IN VARCHAR2 DEFAULT NULL
                             ,p_value15 IN VARCHAR2 DEFAULT NULL) IS

    BEGIN
      -- set global module name for error handling
  	  g_module_name := 'create_bee_line';
  	  g_label2 := 'Batch Line ID';
  	  g_secondary_column := p_batch_line_id;

      INSERT
      --INTO hr.pay_batch_lines(batch_line_id, element_type_id, assignment_id, batch_id    --code commented by RXNETHI-ARGANO,29/06/23
      INTO apps.pay_batch_lines(batch_line_id, element_type_id, assignment_id, batch_id    --code added by RXNETHI-ARGANO,29/06/23
        ,batch_line_status, assignment_number, batch_sequence, effective_date, element_name
        ,entry_type, value_1, value_2, value_3, value_4, value_5, value_6, value_7
        ,value_8, value_9, value_10, value_11, value_12, value_13, value_14, date_earned
        ,effective_start_date)
  	  VALUES (p_batch_line_id, p_element_type_id, p_assignment_id, p_batch_id
        ,p_batch_status, p_assignment_number, p_batch_sequence, p_effective_date, p_element_name
        ,p_entry_type, p_value1, p_value2, p_value3, p_value4, p_value5, p_value6, p_value7
        ,p_value8, p_value9, p_value10, p_value11, p_value12, p_value13, p_value14, p_value15
        ,p_effective_date);

    EXCEPTION
             WHEN OTHERS THEN
      			   g_error_message := SQLERRM;
               RAISE SKIP_RECORD;

    END;

  /************************************************************************************/
  /*                               UPDATE_STAGE_TABLE                                 */
  /************************************************************************************/
    PROCEDURE update_stage_table(p_rowid IN VARCHAR2, p_emp_num IN VARCHAR2
                                ,p_rec_process IN VARCHAR2, p_error_flag IN VARCHAR2
                                ,p_error_message IN VARCHAR2 DEFAULT NULL) IS

    BEGIN
      -- set global module name for error handling
  	  g_module_name := 'update_stage_table';
  	  g_label2 := NULL;
  	  g_secondary_column := NULL;

      --UPDATE cust.tt_bee_interface_stage tbis    --code commented by RXNETHI-ARGANO,29/06/23
      UPDATE apps.tt_bee_interface_stage tbis      --code added by RXNETHI-ARGANO,29/06/23
      SET tbis.record_processed = p_rec_process, tbis.error_flag = p_error_flag,
          tbis.error_message = p_error_message,
		  tbis.last_update_date = sysdate,
		  tbis.last_updated_by = apps.fnd_global.USER_ID,
		  tbis.update_request_id = apps.fnd_global.CONC_REQUEST_ID
  	  WHERE tbis.rowid = p_rowid;  --DT; 01/07/2003

	  --tbis.batch_name = g_batch_name
      --AND tbis.employee_number = p_emp_num
      --AND tbis.rowid = p_rowid;

    EXCEPTION
             WHEN NO_DATA_FOUND THEN
      			   g_error_message := 'No Data Found';
               RAISE SKIP_RECORD;

             WHEN TOO_MANY_ROWS THEN
			         g_error_message := 'Too Many Rows';
               RAISE SKIP_RECORD;

             WHEN OTHERS THEN
			         g_error_message := SQLERRM;
               RAISE SKIP_RECORD;
    END;


  /************************************************************************************/
  /*                            OUTPUT_BEE_SUMMARY_BY_LOC                             */
  /************************************************************************************/
    PROCEDURE output_bee_summary_by_loc(p_batch_name IN VARCHAR2 DEFAULT NULL
                                       ,p_batch_reference IN VARCHAR2 DEFAULT NULL
                                       ,p_batch_source IN VARCHAR2 DEFAULT NULL
                                       ,p_batch_id IN NUMBER DEFAULT NULL
                                       ,ERRBUF OUT VARCHAR2, RETCODE OUT NUMBER) IS

    CURSOR csr_bee_tble_data_loc IS
      SELECT hla.location_code, pbl.element_name, pbl.element_type_id
		   ,sum(DECODE(cust.tt_bee_interface.is_number(pbl.value_1), 'TRUE'
                ,to_number(pbl.value_1), 0)) "VALUE_1"
           ,sum(DECODE(cust.tt_bee_interface.is_number(pbl.value_2), 'TRUE'
                ,to_number(pbl.value_2), 0)) "VALUE_2"
           ,sum(DECODE(cust.tt_bee_interface.is_number(pbl.value_3), 'TRUE'
                ,to_number(pbl.value_3), 0)) "VALUE_3"
           ,sum(DECODE(cust.tt_bee_interface.is_number(pbl.value_4), 'TRUE'
                ,to_number(pbl.value_4), 0)) "VALUE_4"
           ,sum(DECODE(cust.tt_bee_interface.is_number(pbl.value_5), 'TRUE'
                ,to_number(pbl.value_5), 0)) "VALUE_5"

      --FROM hr.pay_batch_headers pba, hr.pay_batch_lines pbl, hr.per_all_assignments_f paaf       --code commented by RXNETHI-ARGANO,29/06/23
      FROM apps.pay_batch_headers pba, apps.pay_batch_lines pbl, apps.per_all_assignments_f paaf   --code added by RXNETHI-ARGANO,29/06/23
          --,hr.hr_locations_all hla    --code commented by RXNETHI-ARGANO,29/06/23
          ,apps.hr_locations_all hla    --code added by RXNETHI-ARGANO,29/06/23
      WHERE pba.batch_id = pbl.batch_id
      AND pbl.assignment_id = paaf.assignment_id
      AND sysdate BETWEEN paaf.effective_start_date AND paaf.effective_end_date
      AND paaf.location_id = hla.location_id
      AND pba.batch_name = p_batch_name
      AND pba.batch_reference = p_batch_reference
      AND pba.batch_source = p_batch_source
      AND pba.batch_id = p_batch_id
      GROUP BY hla.location_code, pbl.element_name, pbl.element_type_id
      ORDER BY hla.location_code asc, pbl.element_name asc;

      l_completion_code BOOLEAN := NULL;

    BEGIN
       -- set global module name for error handling
	     g_module_name := 'output_bee_summary_by_loc';

       -- output header
       apps.fnd_file.put_line(2,'');
       apps.fnd_file.put_line(2,'');
       apps.fnd_file.put_line(2,'-----------------------------------------------------------------------------------------------------');
       apps.fnd_file.put_line(2,'RECONCILIATION REPORT (BY LOCATION) OF ELEMENTS INSERTED INTO BEE TABLES FOR BATCH: '||g_batch_name);
       apps.fnd_file.put_line(2,'-----------------------------------------------------------------------------------------------------');
       apps.fnd_file.put_line(2,'');
       apps.fnd_file.put_line(2,'   LOCATION       ELEMENT NAME    VALUE1 NAME   VALUE1 TOTAL  VALUE2 NAME   VALUE2 TOTAL  VALUE3 NAME   '
          ||'VALUE3 TOTAL  VALUE4 NAME   VALUE4 TOTAL  VALUE5 NAME   VALUE5 TOTAL');
       apps.fnd_file.put_line(2,'--------------- ---------------- -------------- ------------ -------------- ------------ -------------- '
          ||'------------ -------------- ------------ -------------- ------------');

       IF csr_bee_tble_data_loc%ISOPEN THEN
          CLOSE csr_bee_tble_data_loc;
       END IF;

       FOR sel IN csr_bee_tble_data_loc LOOP
          apps.fnd_file.put(2,rpad(nvl(sel.location_code,' '),15));
          apps.fnd_file.put(2,' ');
          apps.fnd_file.put(2,rpad(nvl(sel.element_name,' '),16));
          apps.fnd_file.put(2,' ');
          apps.fnd_file.put(2,rpad(nvl(get_element_value_name(sel.element_name, sel.element_type_id
            , 1,sysdate), ' '),14));
   	      g_module_name := 'output_bee_summary_by_loc';
          apps.fnd_file.put(2,' ');
          apps.fnd_file.put(2,lpad(nvl(to_char(sel.value_1),' ' ),12));
          apps.fnd_file.put(2,' ');
          apps.fnd_file.put(2,rpad(nvl(get_element_value_name(sel.element_name, sel.element_type_id
            , 2,sysdate), ' '),14));
   	      g_module_name := 'output_bee_summary_by_loc';
          apps.fnd_file.put(2,' ');
          apps.fnd_file.put(2,lpad(nvl(to_char(sel.value_2),' ' ),12));
          apps.fnd_file.put(2,' ');
          apps.fnd_file.put(2,rpad(nvl(get_element_value_name(sel.element_name, sel.element_type_id
            , 3,sysdate), ' '),14));
   	      g_module_name := 'output_bee_summary_by_loc';
          apps.fnd_file.put(2,' ');
          apps.fnd_file.put(2,lpad(nvl(to_char(sel.value_3),' ' ),12));
          apps.fnd_file.put(2,' ');
          apps.fnd_file.put(2,rpad(nvl(get_element_value_name(sel.element_name, sel.element_type_id
            , 4,sysdate), ' '),14));
   	      g_module_name := 'output_bee_summary_by_loc';
          apps.fnd_file.put(2,' ');
          apps.fnd_file.put(2,lpad(nvl(to_char(sel.value_4),' ' ),12));
          apps.fnd_file.put(2,' ');
          apps.fnd_file.put(2,rpad(nvl(get_element_value_name(sel.element_name, sel.element_type_id
            , 5,sysdate), ' '),14));
   	      g_module_name := 'output_bee_summary_by_loc';
          apps.fnd_file.put(2,' ');
          apps.fnd_file.put(2,lpad(nvl(to_char(sel.value_5),' ' ),12));
          apps.fnd_file.put_line(2,' ');

       END LOOP;
       apps.fnd_file.put_line(2,'');
       apps.fnd_file.put_line(2,'-----------------------------------------------------------------------------');
       apps.fnd_file.put_line(2,'---------------------------------- REPORT END  ------------------------------');
       apps.fnd_file.put_line(2,'-----------------------------------------------------------------------------');
       apps.fnd_file.put_line(2,'');
       apps.fnd_file.put_line(2,'NOTE:  IF THE VALUES DO NOT RECONCILE, PLEASE CHECK THE VALUES IN THE BATCH.');
       apps.fnd_file.put_line(2,'       THERE MAY BE SOME VALUES THAT ARE NOT NUMERIC. NON-NUMERIC VALUES ARE ');
       apps.fnd_file.put_line(2,'       ACCOUNTED FOR AS ZERO VALUES.');
       apps.fnd_file.put_line(2,'');

    EXCEPTION
             WHEN OTHERS THEN
               apps.fnd_file.put_line(1,'ERROR:  COULD NOT COMPLETE THE PRODUCTION OF THE RECONCILIATION REPORT.');
               apps.fnd_file.put_line(1,'        PLEASE CONTACT THE SYSTEM ADMINISTRATOR TO HELP DETERMINE');
               apps.fnd_file.put_line(1,'        THE ERROR.');
               apps.fnd_file.put_line(1,'');
               apps.fnd_file.put_line(1,'NOTE:   BATCH HAS BEEN LOADED INTO THE BEE TABLES.');
               apps.fnd_file.put_line(2,'ERROR:  COULD NOT COMPLETE THE PRODUCTION OF THE RECONCILIATION REPORT.');
               apps.fnd_file.put_line(2,'        PLEASE CONTACT THE SYSTEM ADMINISTRATOR TO HELP DETERMINE');
               apps.fnd_file.put_line(2,'        THE ERROR.');
               apps.fnd_file.put_line(2,'');
               apps.fnd_file.put_line(2,'NOTE:   BATCH HAS BEEN LOADED INTO THE BEE TABLES.');
               --CUST.TTEC_PROCESS_ERROR (c_application_code, c_interface, c_program_name, g_module_name  --code commented by RXNETHI-ARGANO,29/06/23
               APPS.TTEC_PROCESS_ERROR (c_application_code, c_interface, c_program_name, g_module_name    --code added by RXNETHI-ARGANO,29/06/23
                                  ,c_failure_status, SQLCODE, SQLERRM);
               l_completion_code := apps.fnd_concurrent.set_completion_status('ERROR', 'COULD NOT COMPLETE RECONCILIATION REPORT.');
               RAISE;

    END;


  /************************************************************************************/
  /*                            OUTPUT_BEE_SUMMARY                                    */
  /************************************************************************************/
    PROCEDURE output_bee_summary(p_batch_name IN VARCHAR2 DEFAULT NULL
                                ,p_batch_reference IN VARCHAR2 DEFAULT NULL
                                ,p_batch_source IN VARCHAR2 DEFAULT NULL
                                ,p_batch_id IN NUMBER DEFAULT NULL
                                ,ERRBUF OUT VARCHAR2, RETCODE OUT NUMBER) IS

    CURSOR csr_bee_tble_data_sum IS
      SELECT pbl.element_name, pbl.element_type_id
		   ,sum(DECODE(cust.tt_bee_interface.is_number(pbl.value_1), 'TRUE'
                ,to_number(pbl.value_1), 0)) "VALUE_1"
           ,sum(DECODE(cust.tt_bee_interface.is_number(pbl.value_2), 'TRUE'
                ,to_number(pbl.value_2), 0)) "VALUE_2"
           ,sum(DECODE(cust.tt_bee_interface.is_number(pbl.value_3), 'TRUE'
                ,to_number(pbl.value_3), 0)) "VALUE_3"
           ,sum(DECODE(cust.tt_bee_interface.is_number(pbl.value_4), 'TRUE'
                ,to_number(pbl.value_4), 0)) "VALUE_4"
           ,sum(DECODE(cust.tt_bee_interface.is_number(pbl.value_5), 'TRUE'
                ,to_number(pbl.value_5), 0)) "VALUE_5"
      --FROM hr.pay_batch_headers pba, hr.pay_batch_lines pbl     --code commented by RXNETHI-ARGANO,29/06/23
      FROM apps.pay_batch_headers pba, apps.pay_batch_lines pbl   --code added by RXNETHI-ARGANO,29/06/23
      WHERE pba.batch_id = pbl.batch_id
      AND pba.batch_name = p_batch_name
      AND pba.batch_reference = p_batch_reference
      AND pba.batch_source = p_batch_source
      AND pba.batch_id = p_batch_id
      GROUP BY pbl.element_name, pbl.element_type_id
      ORDER BY pbl.element_name asc;

      l_completion_code BOOLEAN := NULL;

    BEGIN
       -- set global module name for error handling
	     g_module_name := 'output_bee_summary';

       -- output header
       apps.fnd_file.put_line(2,'');
       apps.fnd_file.put_line(2,'');
       apps.fnd_file.put_line(2,'--------------------------------------------------------------------------------------------');
       apps.fnd_file.put_line(2,'RECONCILIATION REPORT OF ELEMENTS INSERTED INTO BEE TABLES FOR BATCH: '||g_batch_name);
       apps.fnd_file.put_line(2,'--------------------------------------------------------------------------------------------');
       apps.fnd_file.put_line(2,'');
       apps.fnd_file.put_line(2,'          ELEMENT NAME            VALUE1 NAME   VALUE1 TOTAL  VALUE2 NAME   VALUE2 TOTAL  VALUE3 NAME   '
          ||'VALUE3 TOTAL  VALUE4 NAME   VALUE4 TOTAL  VALUE5 NAME   VALUE5 TOTAL');
       apps.fnd_file.put_line(2,'-------------------------------- -------------- ------------ -------------- ------------ -------------- '
          ||'------------ -------------- ------------ -------------- ------------');

       IF csr_bee_tble_data_sum%ISOPEN THEN
          CLOSE csr_bee_tble_data_sum;
       END IF;

       FOR sel IN csr_bee_tble_data_sum LOOP
          apps.fnd_file.put(2,rpad(nvl(sel.element_name,' '),32));
          apps.fnd_file.put(2,' ');
          apps.fnd_file.put(2,rpad(nvl(get_element_value_name(sel.element_name, sel.element_type_id
            , 1,sysdate), ' '),14));
   	      g_module_name := 'output_bee_summary';
          apps.fnd_file.put(2,' ');
          apps.fnd_file.put(2,lpad(nvl(to_char(sel.value_1),' ' ),12));
          apps.fnd_file.put(2,' ');
          apps.fnd_file.put(2,rpad(nvl(get_element_value_name(sel.element_name, sel.element_type_id
            , 2,sysdate), ' '),14));
   	      g_module_name := 'output_bee_summary';
          apps.fnd_file.put(2,' ');
          apps.fnd_file.put(2,lpad(nvl(to_char(sel.value_2),' ' ),12));
          apps.fnd_file.put(2,' ');
          apps.fnd_file.put(2,rpad(nvl(get_element_value_name(sel.element_name, sel.element_type_id
            , 3,sysdate), ' '),14));
   	      g_module_name := 'output_bee_summary';
          apps.fnd_file.put(2,' ');
          apps.fnd_file.put(2,lpad(nvl(to_char(sel.value_3),' ' ),12));
          apps.fnd_file.put(2,' ');
          apps.fnd_file.put(2,rpad(nvl(get_element_value_name(sel.element_name, sel.element_type_id
            , 4,sysdate), ' '),14));
   	      g_module_name := 'output_bee_summary';
          apps.fnd_file.put(2,' ');
          apps.fnd_file.put(2,lpad(nvl(to_char(sel.value_4),' ' ),12));
          apps.fnd_file.put(2,' ');
          apps.fnd_file.put(2,rpad(nvl(get_element_value_name(sel.element_name, sel.element_type_id
            , 5,sysdate), ' '),14));
   	      g_module_name := 'output_bee_summary';
          apps.fnd_file.put(2,' ');
          apps.fnd_file.put(2,lpad(nvl(to_char(sel.value_5),' ' ),12));
          apps.fnd_file.put_line(2,' ');

       END LOOP;
       apps.fnd_file.put_line(2,'');
       apps.fnd_file.put_line(2,'-----------------------------------------------------------------------------');
       apps.fnd_file.put_line(2,'---------------------------------- REPORT END  ------------------------------');
       apps.fnd_file.put_line(2,'-----------------------------------------------------------------------------');
       apps.fnd_file.put_line(2,'');
       apps.fnd_file.put_line(2,'NOTE:  IF THE VALUES DO NOT RECONCILE, PLEASE CHECK THE VALUES IN THE BATCH.');
       apps.fnd_file.put_line(2,'       THERE MAY BE SOME VALUES THAT ARE NOT NUMERIC. NON-NUMERIC VALUES ARE ');
       apps.fnd_file.put_line(2,'       ACCOUNTED FOR AS ZERO VALUES.');
       apps.fnd_file.put_line(2,'');

    EXCEPTION
             WHEN OTHERS THEN
               apps.fnd_file.put_line(1,'ERROR:  COULD NOT COMPLETE THE PRODUCTION OF THE RECONCILIATION REPORT.');
               apps.fnd_file.put_line(1,'        PLEASE CONTACT THE SYSTEM ADMINISTRATOR TO HELP DETERMINE');
               apps.fnd_file.put_line(1,'        THE ERROR.');
               apps.fnd_file.put_line(1,'');
               apps.fnd_file.put_line(1,'NOTE:   BATCH HAS BEEN LOADED INTO THE BEE TABLES.');
               apps.fnd_file.put_line(2,'ERROR:  COULD NOT COMPLETE THE PRODUCTION OF THE RECONCILIATION REPORT.');
               apps.fnd_file.put_line(2,'        PLEASE CONTACT THE SYSTEM ADMINISTRATOR TO HELP DETERMINE');
               apps.fnd_file.put_line(2,'        THE ERROR.');
               apps.fnd_file.put_line(2,'');
               apps.fnd_file.put_line(2,'NOTE:   BATCH HAS BEEN LOADED INTO THE BEE TABLES.');
               --CUST.TTEC_PROCESS_ERROR (c_application_code, c_interface, c_program_name, g_module_name  --code commented by RXNETHI-ARGANO,29/06/23
               APPS.TTEC_PROCESS_ERROR (c_application_code, c_interface, c_program_name, g_module_name--code added by RXNETHI-ARGANO,29/06/23
                                  ,c_failure_status, SQLCODE, SQLERRM);
               l_completion_code := apps.fnd_concurrent.set_completion_status('ERROR', 'COULD NOT COMPLETE RECONCILIATION REPORT.');
               RAISE;

    END;


  /************************************************************************************/
  /*                               MAIN PROGRAM PROCEDURE                             */
  /************************************************************************************/

    PROCEDURE main (ERRBUF OUT VARCHAR2, RETCODE OUT NUMBER, l_element_effective_date IN DATE,
	                                                         l_parameter_business_group_id IN NUMBER ) IS

    -- declare local variables
    l_business_group_id		  NUMBER;
	  l_business_group_name   VARCHAR2(100);
    l_operating_unit_id     NUMBER;
    l_unprocessed_batch_count NUMBER;
	  l_val_batch_count NUMBER := 0;
    l_batch_status   VARCHAR2(30);
    l_action_if_exists   VARCHAR2(30);
    l_purge_after_transfer   VARCHAR2(30);
    l_reject_if_future_changes   VARCHAR2(30);
    l_batch_id   NUMBER;
    l_batch_line_id  NUMBER;
    l_employee_name VARCHAR2(240);
    l_assignment_id  NUMBER;
	  l_assignment_number VARCHAR2(10);
	  l_payroll_id   NUMBER;
    l_batch_sequence NUMBER;
    l_element_type_id NUMBER;
    l_entry_type VARCHAR2(30);
    l_completion_code BOOLEAN;

    -- declare local control total variables
    l_records_read            NUMBER := NULL;
    l_records_processed       NUMBER := NULL;
    l_records_errored         NUMBER := NULL;
    l_commit_count            NUMBER := NULL;
    l_records_read_lp1        NUMBER := NULL;
    l_records_processed_lp1   NUMBER := NULL;
    l_records_errored_lp1     NUMBER := NULL;
    l_invalid_number          NUMBER := NULL;
    l_unprocessed_records     NUMBER := NULL;

    BEGIN
         g_module_name := 'main';

         -- DETERMINE THE UNPROCESSED BATCH NAME IN STAGING TABLE.
         -- determine the count of batches that have not been processed.
         get_unprocessed_batch_count(l_unprocessed_batch_count);
apps.fnd_file.put_line(1,'Determined Total Number of unprocessed batch names as: '||l_unprocessed_batch_count);
apps.fnd_file.put_line(1,'');

         -- OUT HEADER INFORMATION
         apps.fnd_file.put_line(2,'');
         apps.fnd_file.put_line(2,' BATCH ELEMENT ENTRY INTERFACE');
         apps.fnd_file.put_line(2,' INTERFACE TIMESTAMP = '  || to_char(SYSDATE, 'dd-mon-yy hh:mm:ss'));

		 begin
		   select name into g_param_business_group_name
		      --from hr_organization_units  --code commented by RXNETHI-ARGANO,29/06/23
              from apps.hr_organization_units  --code commented by RXNETHI-ARGANO,29/06/23
			  where organization_id =  l_parameter_business_group_id;

		 end;

         IF csr_stage_unprocessed_batches%ISOPEN THEN
            CLOSE csr_stage_unprocessed_batches;
         END IF;

         FOR sel_loop1 IN csr_stage_unprocessed_batches(g_param_business_group_name) LOOP

            -- initialize variables
            l_records_read            := 0;
            l_records_processed       := 0;
            l_records_errored         := 0;
            l_commit_count            := 0;
            l_records_read_lp1        := 0;
            l_records_processed_lp1   := 0;
            l_records_errored_lp1     := 0;
            g_batch_name := sel_loop1.batch_name;
            l_business_group_id := sel_loop1.business_group_id;
            l_business_group_name := sel_loop1.name;
            g_module_name := 'main_loop1';
            apps.fnd_file.put_line(1,'Start Batch: '||g_batch_name||' /Business Group Name: '||l_business_group_name);

            -- output header
            apps.fnd_file.put_line(2,'***********************************************************************************************************************');
            apps.fnd_file.put_line(2,'START OF BATCH: '||g_batch_name);
            apps.fnd_file.put_line(2,'BUSINESS GROUP: '||l_business_group_name);
            apps.fnd_file.put_line(2,'');

            -- Create batch header record
            --  get default common lookups
            l_batch_status:=get_lookup_code(c_batch_status_lt, c_batch_status_deflt);
            l_action_if_exists:=get_lookup_code(c_action_if_exists_lt, c_action_if_exists_deflt);
            l_purge_after_transfer:=get_lookup_code(c_purge_after_transfer_lt, c_purge_after_transfer_deflt);
            l_reject_if_future_changes:=get_lookup_code(c_rjt_future_chg_lt, c_rjt_future_chg_deflt);
            g_module_name := 'main_loop1';

            -- get next Batch ID
            get_batch_id(l_batch_id);
            g_module_name := 'main_loop1';

            -- insert record into BEE Header
            create_bee_header(l_batch_id, l_business_group_id, l_batch_status
                             ,l_action_if_exists, l_purge_after_transfer, l_reject_if_future_changes);
            g_module_name := 'main_loop1';

apps.fnd_file.put_line(1,'Batch Header Record Created: Batch ID = '||l_batch_id);

            -- After batch header is created, start creating line values
            -- check to see if cursor is open
            IF csr_bee_int_stage_data%ISOPEN THEN
               close csr_bee_int_stage_data;
            END IF;

            -- Error output header during BEE table insertion -- 2 is for output, 1 is for log
            apps.fnd_file.put_line(2,'');
            apps.fnd_file.put_line(2,'ERROR REPORT WHILE LOADING BEE TABLES');
            apps.fnd_file.put_line(2,'-------------------------------------');
            apps.fnd_file.put_line(2,'');
            apps.fnd_file.put_line(2,'Employee Name     Emp Num    Element Name      Value1  Value2  Error Message');
            apps.fnd_file.put_line(2,'----------------- ---------- ----------------- ------- ------- ---------------------------------------------------');

    		     -- retrieve batch data from cursor
            FOR sel_loop2 IN csr_bee_int_stage_data(g_batch_name, l_business_group_id, g_param_business_group_name) LOOP
               BEGIN
                  -- update records read counter
                  l_records_read := l_records_read + 1;

                  -- initialize variables
                  l_assignment_id := NULL;
                  l_assignment_number := NULL;
                  l_payroll_id := NULL;
                  l_batch_line_id := NULL;
                  l_element_type_id := NULL;
                  l_entry_type := NULL;
                  l_employee_name := NULL;
                  l_batch_sequence := l_batch_sequence +1;
			            g_error_message := NULL;
   	              g_module_name := 'main_loop2';
                  g_primary_column := sel_loop2.employee_number;

                  -- set the batch line id
                  get_batch_line_id(l_batch_line_id);
	                g_module_name := 'main_loop2';

                  -- get employee name
                  get_employee_name(sel_loop2.employee_number, l_business_group_id
                                   ,l_element_effective_date, l_employee_name);
	                g_module_name := 'main_loop2';

                  -- get assignment information
                  get_assignment_info(sel_loop2.employee_number, l_business_group_id
                    ,l_element_effective_date, l_assignment_id,  l_assignment_number
                    ,l_payroll_id);
	                g_module_name := 'main_loop2';

                  -- get element type id
                  get_element_type_id(sel_loop2.element_name, l_business_group_id
                    ,l_element_effective_date, l_element_type_id);
	                g_module_name := 'main_loop2';

                  -- get entry type
                  l_entry_type:=get_lookup_code(c_entry_type_lt, c_entry_type_deflt);
                  g_module_name := 'main_loop2';

                  -- check for elements that need to Entry Effective Date Added
                  IF sel_loop2.element_name IN (c_vacation_taken, c_sick_taken
                      ,c_personal_holiday_taken, c_vacation_payout) THEN
                    -- create bee line with Entry Effective Date
                    create_bee_line(l_batch_id, l_batch_line_id, l_element_type_id
                      ,l_assignment_id, l_batch_status, l_assignment_number, l_batch_sequence
                      ,l_element_effective_date, sel_loop2.element_name, l_entry_type, sel_loop2.value1
                      ,sel_loop2.value2, to_char(l_element_effective_date, 'YYYY/MM/DD HH:MM:SS')
                      ,sel_loop2.value4, sel_loop2.value5, sel_loop2.value6, sel_loop2.value7
                      ,sel_loop2.value8, sel_loop2.value9, sel_loop2.value10, sel_loop2.value11
                      ,sel_loop2.value12, sel_loop2.value13, sel_loop2.value14, sel_loop2.value15);
                    g_module_name := 'main_loop2';
                  ELSE
                    -- create bee line
                    create_bee_line(l_batch_id, l_batch_line_id, l_element_type_id
                      ,l_assignment_id, l_batch_status, l_assignment_number, l_batch_sequence
                      ,l_element_effective_date, sel_loop2.element_name, l_entry_type
                      ,sel_loop2.value1, sel_loop2.value2, sel_loop2.value3, sel_loop2.value4
                      ,sel_loop2.value5, sel_loop2.value6, sel_loop2.value7, sel_loop2.value8
                      ,sel_loop2.value9, sel_loop2.value10, sel_loop2.value11, sel_loop2.value12
                      ,sel_loop2.value13, sel_loop2.value14, sel_loop2.value15);
                    g_module_name := 'main_loop2';
                  END IF;

                  -- update staging table
                  update_stage_table(sel_loop2.rowid, sel_loop2.employee_number,c_processed_trsfr_flag,'N');
	                g_module_name := 'main_loop2';

                  -- update successful counter
                  l_records_processed := l_records_processed + 1;

                  -- check commit counter
                  IF l_commit_count = g_commit_count THEN
                     COMMIT;
                     l_commit_count := 0;
                  ELSE
                     l_commit_count := l_commit_count +1;
                  END IF;

               EXCEPTION
                    WHEN SKIP_RECORD THEN
                       --cust.ttec_process_error(c_application_code, c_interface, c_program_name  --code commented by RXNETHI-ARGANO,29/06/23
                       apps.ttec_process_error(c_application_code, c_interface, c_program_name    --code added by RXNETHI-ARGANO,29/06/23
                         ,g_module_name, c_warning_status, SQLCODE, g_error_message, g_label1
                         ,g_primary_column, g_label2, g_secondary_column);
                       l_records_errored := l_records_errored + 1;
                       update_stage_table(sel_loop2.rowid, sel_loop2.employee_number,c_processed_trsfr_flag,'Y'
                         ,g_error_message);
                       apps.fnd_file.put_line(2,rpad(nvl(l_employee_name,' '),17)
                         ||' '||lpad(nvl(sel_loop2.employee_number,' '),10)
                         ||' '||rpad(nvl(sel_loop2.element_name, ' '),17)
                         ||' '||lpad(nvl(sel_loop2.value1,' '),7)
                         ||' '||lpad(nvl(sel_loop2.value2,' '),7)
                         ||' '||rpad(g_error_message, 50));

                    WHEN OTHERS THEN
       				         --cust.ttec_process_error(c_application_code, c_interface, c_program_name   --code commented by RXNETHI-ARGANO,29/06/23
       				         apps.ttec_process_error(c_application_code, c_interface, c_program_name     --code added by RXNETHI-ARGANO,29/06/23
   					            ,g_module_name, c_warning_status, SQLCODE, SQLERRM, g_label1
		   				          ,g_primary_column);
                       l_records_errored := l_records_errored + 1;
                       update_stage_table(sel_loop2.rowid, sel_loop2.employee_number,c_processed_trsfr_flag,'Y'
                         ,SQLERRM);
                       apps.fnd_file.put_line(2,rpad(nvl(l_employee_name,' '),17)
                         ||' '||lpad(nvl(sel_loop2.employee_number,' '),10)
                         ||' '||rpad(nvl(sel_loop2.element_name, ' '),17)
                         ||' '||lpad(nvl(sel_loop2.value1,' '),7)
                         ||' '||lpad(nvl(sel_loop2.value2,' '),7)
                         ||' '||rpad(SQLERRM, 50));

               END;
            END LOOP;
            g_module_name := 'main_loop1';
apps.fnd_file.put_line(1,'Batch Line Records Created.');

            IF l_records_errored = 0 THEN
               apps.fnd_file.put_line(2,'NONE');
            END IF;


            COMMIT;

            -- display control totals
            apps.fnd_file.put_line(2,'');
            apps.fnd_file.put_line(2,'');
            apps.fnd_file.put_line(2,'-------------------------------------------------------------------');
            apps.fnd_file.put_line(2,' TOTAL RECORDS FOR INSERTION INTO BEE TABLES READ          = '  || to_char(l_records_read));
            apps.fnd_file.put_line(2,' TOTAL RECORDS FOR INSERTION INTO BEE TABLES PROCESSED     = '  || to_char(l_records_processed));
            apps.fnd_file.put_line(2,' TOTAL RECORDS FOR INSERTION INTO BEE TABLES REJECTED      = '  || to_char(l_records_errored));
            apps.fnd_file.put_line(2,'-------------------------------------------------------------------');

            -- AFTER THE RECORDS HAVE BEEN ENTERED INTO THE BEE TABLES, THE SUMMARY REPORT BY LOCATION
            -- PER ELEMENT NEEDS TO BE CREATED
            output_bee_summary_by_loc(g_batch_name, c_batch_reference, c_batch_source
                                     ,l_batch_id, ERRBUF, RETCODE);

apps.fnd_file.put_line(1,'Output summary report by location complete.');

            -- NOW EXECUTE THE SAME FOR TOTAL
            output_bee_summary(g_batch_name, c_batch_reference, c_batch_source
                              ,l_batch_id, ERRBUF, RETCODE);

apps.fnd_file.put_line(1,'Output total summary report complete.');
apps.fnd_file.put_line(1,'Batch '||g_batch_name||' complete.');
            -- output footer for batch
            apps.fnd_file.put_line(2,'');
            apps.fnd_file.put_line(2,'END OF BATCH: '||g_batch_name);
            apps.fnd_file.put_line(2,'BUSINESS GROUP: '||l_business_group_name);
            apps.fnd_file.put_line(2,'***********************************************************************************************************************');
            apps.fnd_file.put_line(2,'');
            apps.fnd_file.put_line(2,'');
            apps.fnd_file.put_line(2,'');
            apps.fnd_file.put_line(2,'');

         END LOOP;

apps.fnd_file.put_line(1,'Outputing unprocessed records due to invalid employee numbers.');
         -- OUTPUT RECORDS THAT HAVE NOT BEEN PROCESSED DUE TO INVALID EMPLOYEE NUMBERS
         apps.fnd_file.put_line(2,'');
         apps.fnd_file.put_line(2,'UNPROCESSED RECORDS DUE TO INVALID EMPLOYEE NUMBERS');
         apps.fnd_file.put_line(2,'---------------------------------------------------');
         apps.fnd_file.put_line(2,'');
         apps.fnd_file.put_line(2,'Batch Name      Emp Num   Element Name         Value1  Value2  Value3  Value4  Value5');
         apps.fnd_file.put_line(2,'--------------- --------- -------------------- ------- ------- ------- ------- -------');

         l_unprocessed_records := 0;
         IF csr_unprocessed_records%ISOPEN THEN
            close csr_unprocessed_records;
         END IF;

         FOR sel_unprocess IN csr_unprocessed_records(g_param_business_group_name) LOOP
            l_unprocessed_records := l_unprocessed_records +1;
            apps.fnd_file.put_line(2,rpad(sel_unprocess.batch_name, 15)||' '||
                                     rpad(sel_unprocess.employee_number,9)||' '||
                                     rpad(sel_unprocess.element_name,20)||' '||
                                     rpad(sel_unprocess.value1,7)||' '||
                                     rpad(sel_unprocess.value2,7)||' '||
                                     rpad(sel_unprocess.value3,7)||' '||
                                     rpad(sel_unprocess.value4,7)||' '||
                                     rpad(sel_unprocess.value5,7));
            -- error records with invalid employee numbers
            update_stage_table(sel_unprocess.rowid, sel_unprocess.employee_number
                              ,'Y','Y','Invalid Employee Number');

         END LOOP;

		 commit; --DT; Final commit 01/07/03

         IF l_unprocessed_records = 0 THEN
            apps.fnd_file.put_line(2,'NONE');
         END IF;


apps.fnd_file.put_line(1,'Outputing unprocessed records due to invalid employee numbers COMPLETE.');

         -- SET PROGRAM RESULTS TO DEFINE THE PROGRAM DETAILS
         IF l_records_errored > 0 AND l_unprocessed_records <> 0THEN
            l_completion_code := apps.fnd_concurrent.set_completion_status('WARNING', 'Errors produced during program execution and there are unprocessed'
               ||' records.  Check Output File');
         ELSIF l_records_errored > 0 THEN
            l_completion_code := apps.fnd_concurrent.set_completion_status('WARNING', 'Errors produced during program execution.  Check Output File');
         ELSIF l_unprocessed_records <> 0 THEN
            l_completion_code := apps.fnd_concurrent.set_completion_status('WARNING', 'Program completed, however, there were unprocessed records.'
               ||' Check Output File');
         ELSIF l_records_errored = 0 THEN
            l_completion_code := apps.fnd_concurrent.set_completion_status('NORMAL', 'Program completed successfully without errors.');
         ELSE
            l_completion_code := apps.fnd_concurrent.set_completion_status('ERROR','Error count malfunction.  Check error count within code.');
         END IF;

    EXCEPTION
          /*** CUSTOM EXCEPTIONS ***/
          WHEN NO_BATCH_NAMES THEN
                  apps.fnd_file.put_line(1,'ERROR:  COULD NOT FIND AN UNPROCESSED BATCH NAME WITHIN THE STAGING TABLE.');
                  apps.fnd_file.put_line(1,'        PLEASE CONTACT THE SYSTEM ADMINISTRATOR TO HELP DETERMINE');
                  apps.fnd_file.put_line(1,'        THE BATCH NAME WITHIN THE STAGING TABLE.');
                  apps.fnd_file.put_line(1,'');
                  apps.fnd_file.put_line(1,'NOTE:   BATCH HAS NOT BEEN LOADED INTO THE BEE TABLES.');
                  apps.fnd_file.put_line(2,'ERROR:  COULD NOT FIND A BATCH NAME WITHIN THE STAGING TABLE.');
                  apps.fnd_file.put_line(2,'        PLEASE CONTACT THE SYSTEM ADMINISTRATOR TO HELP DETERMINE');
                  apps.fnd_file.put_line(2,'        THE BATCH NAME WITHIN THE STAGING TABLE.');
                  apps.fnd_file.put_line(2,'');
                  apps.fnd_file.put_line(2,'NOTE:   BATCH HAS NOT BEEN LOADED INTO THE BEE TABLES.');
                  --CUST.TTEC_PROCESS_ERROR (c_application_code, c_interface, c_program_name, g_module_name  --code commented by RXNETHI-ARGANO,29/06/23
                  APPS.TTEC_PROCESS_ERROR (c_application_code, c_interface, c_program_name, g_module_name   --code added by RXNETHI-ARGANO,29/06/23
                                  ,c_failure_status, SQLCODE, 'No batch names found in staging table.');
                  l_completion_code := apps.fnd_concurrent.set_completion_status('ERROR', 'COULD NOT DETERMINE VALID BATCHES FOR PROCESSING');
                  RAISE;

          WHEN TOO_MANY_BATCHES THEN
                  apps.fnd_file.put_line(1,'ERROR:  TOO MANY UNPROCESSED BATCHES WERE FOUND WITHIN THE STAGING TABLE.');
                  apps.fnd_file.put_line(1,'        PLEASE CONTACT THE SYSTEM ADMINISTRATOR TO HELP DETERMINE');
                  apps.fnd_file.put_line(1,'        THE BATCH NAME WITHIN THE STAGING TABLE.');
                  apps.fnd_file.put_line(1,'');
                  apps.fnd_file.put_line(1,'NOTE:   BATCH HAS NOT BEEN LOADED INTO THE BEE TABLES.');
                  apps.fnd_file.put_line(2,'ERROR:  TOO MANY UNPROCESSED BATCHES WERE FOUND WITHIN THE STAGING TABLE.');
                  apps.fnd_file.put_line(2,'        PLEASE CONTACT THE SYSTEM ADMINISTRATOR TO HELP DETERMINE');
                  apps.fnd_file.put_line(2,'        THE BATCH NAME WITHIN THE STAGING TABLE.');
                  apps.fnd_file.put_line(2,'');
                  apps.fnd_file.put_line(2,'NOTE:   BATCH HAS NOT BEEN LOADED INTO THE BEE TABLES.');
                  --CUST.TTEC_PROCESS_ERROR (c_application_code, c_interface, c_program_name, g_module_name   --code commented by RXNETHI-ARGANO,29/06/23
                  APPS.TTEC_PROCESS_ERROR (c_application_code, c_interface, c_program_name, g_module_name     --code added by RXNETHI-ARGANO,29/06/23
                                  ,c_failure_status, SQLCODE, 'Too many batches found in staging table.');
                  l_completion_code := apps.fnd_concurrent.set_completion_status('ERROR', 'COULD NOT DEFINE BATCH NAME');
                  RAISE;

          WHEN ERRORS_IN_STAGE THEN
                  apps.fnd_file.put_line(1,'ERROR:  THERE WERE INVALID EMPLOYEE NUMBERS WITHIN THE BATCH.');
                  apps.fnd_file.put_line(1,'        PLEASE CONTACT THE SYSTEM ADMINISTRATOR TO HELP CORRECT');
                  apps.fnd_file.put_line(1,'        THE ERRORS WITHIN THE BATCH.');
                  apps.fnd_file.put_line(1,'');
                  apps.fnd_file.put_line(1,'NOTE:   BATCH HAS NOT BEEN LOADED INTO THE BEE TABLES.');
                  apps.fnd_file.put_line(2,'ERROR:  THERE WERE INVALID EMPLOYEE NUMBERS WITHIN THE BATCH.');
                  apps.fnd_file.put_line(2,'        PLEASE CONTACT THE SYSTEM ADMINISTRATOR TO HELP CORRECT');
                  apps.fnd_file.put_line(2,'        THE ERRORS WITHIN THE BATCH.');
                  apps.fnd_file.put_line(2,'');
                  apps.fnd_file.put_line(2,'NOTE:   BATCH HAS NOT BEEN LOADED INTO THE BEE TABLES.');
                  --CUST.TTEC_PROCESS_ERROR (c_application_code, c_interface, c_program_name, g_module_name   --code commented by RXNETHI-ARGANO,29/06/23
                  APPS.TTEC_PROCESS_ERROR (c_application_code, c_interface, c_program_name, g_module_name     --code added by RXNETHI-ARGANO,29/06/23
                                  ,c_failure_status, SQLCODE, 'Errors found in batch emp numbers.');
                  l_completion_code := apps.fnd_concurrent.set_completion_status('ERROR', 'ERROR IN EMP NUMBERS IN STAGING TABLE.');
                  RAISE;

          WHEN ERROR_SETTING_DEFAULTS THEN
                  apps.fnd_file.put_line(1,'ERROR:  UNABLE TO DET THE DEFAULT VALUES FOR BATCH HEADER RECORD.');
                  apps.fnd_file.put_line(1,'        PLEASE CONTACT THE SYSTEM ADMINISTRATOR TO VALIDATE');
                  apps.fnd_file.put_line(1,'        THE LOOKUP CODES FOR THE DEFAULT VALUES.');
                  apps.fnd_file.put_line(1,'');
                  apps.fnd_file.put_line(1,'NOTE:   BATCH HAS NOT BEEN LOADED INTO THE BEE TABLES.');
                  apps.fnd_file.put_line(2,'ERROR:  UNABLE TO DET THE DEFAULT VALUES FOR BATCH HEADER RECORD.');
                  apps.fnd_file.put_line(2,'        PLEASE CONTACT THE SYSTEM ADMINISTRATOR TO VALIDATE');
                  apps.fnd_file.put_line(2,'        THE LOOKUP CODES FOR THE DEFAULT VALUES.');
                  apps.fnd_file.put_line(2,'');
                  apps.fnd_file.put_line(2,'NOTE:   BATCH HAS NOT BEEN LOADED INTO THE BEE TABLES.');
                  --CUST.TTEC_PROCESS_ERROR (c_application_code, c_interface, c_program_name, g_module_name  --code commented by RXNETHI-ARGANO,29/06/23
                  APPS.TTEC_PROCESS_ERROR (c_application_code, c_interface, c_program_name, g_module_name    --code added by RXNETHI-ARGANO,29/06/23
                                  ,c_failure_status, SQLCODE, g_error_message);
                  l_completion_code := apps.fnd_concurrent.set_completion_status('ERROR', 'ERROR IN EMP NUMBERS IN STAGING TABLE.');
                  RAISE;

          WHEN NO_BUSINESS_ORG_ID THEN
                  apps.fnd_file.put_line(1,'ERROR:  ERROR ATTEMPTING TO DETERMINE THE BUSINESS GROUP ID');
                  apps.fnd_file.put_line(1,'        PLEASE CONTACT THE SYSTEM ADMINISTRATOR.');
                  apps.fnd_file.put_line(1,'');
                  apps.fnd_file.put_line(1,'NOTE:   BATCH HAS NOT BEEN LOADED INTO THE BEE TABLES.');
                  apps.fnd_file.put_line(2,'ERROR:  ERROR ATTEMPTING TO DETERMINE THE BUSINESS GROUP ID');
                  apps.fnd_file.put_line(2,'        PLEASE CONTACT THE SYSTEM ADMINISTRATOR.');
                  apps.fnd_file.put_line(2,'');
                  apps.fnd_file.put_line(2,'NOTE:   BATCH HAS NOT BEEN LOADED INTO THE BEE TABLES.');
                  --CUST.TTEC_PROCESS_ERROR(c_application_code, c_interface, c_program_name   --code commented by RXNETHI-ARGANO,29/06/23
                  APPS.TTEC_PROCESS_ERROR(c_application_code, c_interface, c_program_name     --code added by RXNETHI-ARGANO,29/06/23
                                  ,g_module_name, c_failure_status, SQLCODE, g_error_message);
                  l_completion_code := apps.fnd_concurrent.set_completion_status('ERROR', 'Unable to determine business group ID.');
                  RAISE;

          /** OTHER EXCEPTION **/
		      WHEN OTHERS THEN
                  apps.fnd_file.put_line(1,'Other Exception within the Main Procedure');
                  apps.fnd_file.put_line(2,'Other Exception within the Main Procedure');
                  apps.fnd_file.put_line(2,'NOTE:   BATCH HAS NOT BEEN LOADED INTO THE BEE TABLES.');
                  --CUST.TTEC_PROCESS_ERROR(c_application_co/de, c_interface, c_program_name   --code commented by RXNETHI-ARGANO,29/06/23
                  APPS.TTEC_PROCESS_ERROR(c_application_code, c_interface, c_program_name     --code added by RXNETHI-ARGANO,29/06/23
                                  ,g_module_name, c_failure_status, SQLCODE, SQLERRM,'Records read', l_records_read);
                  l_completion_code := apps.fnd_concurrent.set_completion_status('ERROR', 'Other exception in program.  Check logs.');
                  RAISE;

    END; /*** END MAIN ***/

END TT_BEE_INTERFACE;
/
show errors;
/