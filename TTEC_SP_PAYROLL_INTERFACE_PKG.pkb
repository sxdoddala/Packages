create or replace PACKAGE BODY Ttec_Sp_Payroll_Interface_Pkg AS
--------------------------------------------------------------------
--                                                                --
--     Name:  ttech_spain_payroll_inteface_pkg       (Package)              --
--                                                                --
--     Description:   Spain payroll Data to the Payroll Vendor	  --
--                    						  --
--                                                                --
--                                                                --
--     Change History                                             --
--                                                                --
--     Changed By        Date        Reason for Change            --
--     ----------        ----        -----------------            --
--     Dibyendu Roy   22-MAY-2005  Initial Creation For SPAIN    --
--                                                                --
--     C. Chan        09-SEP-2005  TT#404712-Spain Payroll Interface picking up old records
--
--     C.Chan         22-NOV-2005  TT#411517 - Spain's user tried to generate the daily extract in Spanish
--                                             language (like usually do) and the process returned an error.
--
--     C.Chan         03-FEB-2006  WO#163242  - Spain HR/Payroll extract have to picks up all employees with Legacy Number.
--
--     C.Chan         04-AUG-2006  WO#212636  - Spain HR/Payroll extract - CIN record field #4 needs to show
--                                              the date of the element for a term emp, not incident date
--    P.Elango        01-DEC-2006  Incident# 608136 - Getting duplicate assignment record
--		                      added max asg date condition on second query.
--   RXNETHI-ARGANO   15-MAY-2023  R12.2 Upgrade Remediation
--------------------------------------------------------------------
PROCEDURE print_line(iv_data          IN VARCHAR2) IS
BEGIN
  Fnd_File.put_line(Fnd_File.output,iv_data || ';');
-- Ken Mod 8/24/05 took out log file printing, due to element (CIN) control total section in log file.
--  Fnd_File.put_line(Fnd_File.LOG,iv_data || ';');
END; -- print_line
FUNCTION scrub_to_number    (iv_text        IN VARCHAR2) RETURN VARCHAR2 IS
v_number        VARCHAR2(255);
v_length        NUMBER;
i               NUMBER;
BEGIN
  v_length := LENGTH(iv_text);
  IF v_length > 0 THEN
    -- look at each character in text and remove any non-numbers
    FOR i IN 1 .. v_length LOOP
	  IF ASCII(SUBSTR(iv_text,i,1)) BETWEEN 48 AND 57 THEN
	    v_number := v_number || SUBSTR(iv_text,i,1);
	  END IF; -- ascii between 48 and 57
  	END LOOP; -- i
  END IF; -- v_length
  RETURN v_number;
EXCEPTION
  WHEN OTHERS THEN
    RETURN iv_text;
END; -- function scrub_to_number
PROCEDURE set_business_group_id (iv_business_group IN VARCHAR2 DEFAULT 'TeleTech Holdings - ESP') IS
BEGIN
  SELECT organization_id
  INTO         g_business_group_id
  FROM       hr_all_organization_units
  WHERE  NAME = iv_business_group;
EXCEPTION
  WHEN OTHERS THEN
    Fnd_File.put_line(Fnd_File.LOG,'Unable to Determine Business Group ID');
	Fnd_File.put_line(Fnd_File.LOG,SUBSTR(SQLERRM,1,255));
	g_errbuf  := SUBSTR(SQLERRM,1,255);
	g_retcode := SQLCODE;
	RAISE g_e_abort;
END;  -- procedure set_business_group_id
FUNCTION  pad_data_output(iv_field_type   IN VARCHAR2,
                                                            iv_pad_length   IN NUMBER,
                                                            iv_field_value   IN VARCHAR2) RETURN VARCHAR2
  IS
  v_length_var  NUMBER;
  v_varchar_pad VARCHAR2(1)   := ' ';
  v_number_pad  VARCHAR2(1)      := ' ';
  v_length_diff NUMBER  := 0;
  BEGIN
    /*IF UPPER(iv_field_type) = 'VARCHAR2' AND iv_pad_length > 0 --and iv_field_value is not null
      THEN
         RETURN SUBSTRB(RPAD( NVL(iv_field_value,' '), iv_pad_length, v_varchar_pad ),1,iv_pad_length);
      ELSIF  UPPER(iv_field_type) = 'NUMBER' AND iv_pad_length > 0 --AND iv_field_value IS NOT NULL
       THEN
          RETURN LPAD( iv_field_value, iv_pad_length, v_number_pad );
    END IF;
    EXCEPTION
      WHEN OTHERS THEN
    	  RETURN NULL;*/
    IF UPPER(iv_field_type) = 'VARCHAR2' AND iv_pad_length > 0 --and iv_field_value is not null
      THEN
         RETURN LTRIM(RTRIM( NVL(iv_field_value,' ')));
      ELSIF  UPPER(iv_field_type) = 'NUMBER' AND iv_pad_length > 0 --AND iv_field_value IS NOT NULL
       THEN
          RETURN LPAD( iv_field_value, iv_pad_length, v_number_pad );
    END IF;
    EXCEPTION
      WHEN OTHERS THEN
    	  RETURN NULL;
  END;  -- Function  pad_data_output
  ---=============================
  --PROCEDURE insert_interface_mst (ir_interface_mst    cust.ttec_sp_payroll_interface_mst%ROWTYPE) IS --code commented by RXNETHI-ARGANO,15/05/23
  PROCEDURE insert_interface_mst (ir_interface_mst    apps.ttec_sp_payroll_interface_mst%ROWTYPE) IS --code added by RXNETHI-ARGANO,15/05/23
BEGIN
  --INSERT INTO cust.ttec_sp_payroll_interface_mst ( --code commented by RXNETHI-ARGANO,15/05/23
  INSERT INTO apps.ttec_sp_payroll_interface_mst ( --code added by RXNETHI-ARGANO,15/05/23
  		 	  employee_id
			  ,period_ordinal
			  ,incidence_date
			  ,payroll_payment_date
			  ,cost_center
			  ,payment_type_code
			  ,payment_type_value
			  ,ElementName
			  ,InputName
			  ,person_creation_date
			  ,person_update_date
			  ,assignment_id
			  ,assignment_creation_date
			  ,assignment_update_date
			  ,person_id
			  ,person_type_id
			 ,system_person_type
			  ,user_person_type
			  ,creation_date
			  ,last_extract_date
			  ,last_extract_file_type
			  ,cut_off_date
			  ,ass_effective_st_dt
			  ,BG_ID
			  ,EntryEffectiveStartDate
			  ,EntryEffectiveEndDate
			  ,IncidenceID
			  ,AbsenceStartDate
			  ,AbsenceEndDate
			  ,RelapseDate
			  ,TipoUnidad
			  ,Unidad
			  ,OracleEmployeeId
                          ,peef_element_entry_id
)
VALUES (
  		  	   ir_interface_mst.employee_id
			   ,ir_interface_mst.period_ordinal
			  ,ir_interface_mst.incidence_date
			  ,ir_interface_mst.payroll_payment_date
			  ,ir_interface_mst.cost_center
			  ,ir_interface_mst.payment_type_code
			  ,ir_interface_mst.payment_type_value
			  ,ir_interface_mst.ElementName
			  ,ir_interface_mst.InputName
			  ,ir_interface_mst.person_creation_date
			  ,ir_interface_mst.person_update_date
			  ,ir_interface_mst.assignment_id
			  ,ir_interface_mst.assignment_creation_date
			  ,ir_interface_mst.assignment_update_date
			  ,ir_interface_mst.person_id
			  ,ir_interface_mst.person_type_id
			  ,ir_interface_mst.system_person_type
			  ,ir_interface_mst.user_person_type
			  ,ir_interface_mst.creation_date
			  ,ir_interface_mst.last_extract_date
			  ,ir_interface_mst.last_extract_file_type
			  ,ir_interface_mst.cut_off_date
			   ,ir_interface_mst.ass_effective_st_dt
			  ,ir_interface_mst.BG_ID
			  ,ir_interface_mst.EntryEffectiveStartDate
			  ,ir_interface_mst.EntryEffectiveEndDate
			  ,ir_interface_mst.IncidenceID
			  ,ir_interface_mst.AbsenceStartDate
			  ,ir_interface_mst.AbsenceEndDate
			  ,ir_interface_mst.RelapseDate
			  ,ir_interface_mst.TipoUnidad
			  ,ir_interface_mst.Unidad
			  ,ir_interface_mst.OracleEmployeeId
                          ,ir_interface_mst.peef_element_entry_id
			 );
END; -- procedure insert_interface_mst
FUNCTION delimit_text ( iv_number_of_fields       IN NUMBER,
                       iv_field1                 IN VARCHAR2,
					   iv_field2                 IN VARCHAR2 DEFAULT NULL,
					   iv_field3                 IN VARCHAR2 DEFAULT NULL,
					   iv_field4                 IN VARCHAR2 DEFAULT NULL,
					   iv_field5                 IN VARCHAR2 DEFAULT NULL,
					   iv_field6                 IN VARCHAR2 DEFAULT NULL,
					   iv_field7                 IN VARCHAR2 DEFAULT NULL,
					   iv_field8                 IN VARCHAR2 DEFAULT NULL,
					   iv_field9                 IN VARCHAR2 DEFAULT NULL,
					   iv_field10                IN VARCHAR2 DEFAULT NULL,
					   iv_field11                IN VARCHAR2 DEFAULT NULL,
					   iv_field12                IN VARCHAR2 DEFAULT NULL,
					   iv_field13                IN VARCHAR2 DEFAULT NULL,
					   iv_field14                IN VARCHAR2 DEFAULT NULL,
					   iv_field15                IN VARCHAR2 DEFAULT NULL,
					   iv_field16                IN VARCHAR2 DEFAULT NULL,
					   iv_field17                IN VARCHAR2 DEFAULT NULL,
					   iv_field18                IN VARCHAR2 DEFAULT NULL,
					   iv_field19                IN VARCHAR2 DEFAULT NULL,
					   iv_field20                IN VARCHAR2 DEFAULT NULL,
   					   iv_field21                IN VARCHAR2 DEFAULT NULL,
					   iv_field22                IN VARCHAR2 DEFAULT NULL,
					   iv_field23                IN VARCHAR2 DEFAULT NULL,
					   iv_field24                IN VARCHAR2 DEFAULT NULL,
					   iv_field25                IN VARCHAR2 DEFAULT NULL,
					   iv_field26                IN VARCHAR2 DEFAULT NULL,
					   iv_field27                IN VARCHAR2 DEFAULT NULL,
					   iv_field28                IN VARCHAR2 DEFAULT NULL,
					   iv_field29                IN VARCHAR2 DEFAULT NULL,
					   iv_field30                IN VARCHAR2 DEFAULT NULL,
					   iv_field31                IN VARCHAR2 DEFAULT NULL,
					   iv_field32                IN VARCHAR2 DEFAULT NULL,
					   iv_field33                IN VARCHAR2 DEFAULT NULL,
					   iv_field34                IN VARCHAR2 DEFAULT NULL,
					   iv_field35                IN VARCHAR2 DEFAULT NULL,
					   iv_field36                IN VARCHAR2 DEFAULT NULL,
					   iv_field37                IN VARCHAR2 DEFAULT NULL,
					   iv_field38                IN VARCHAR2 DEFAULT NULL,
					   iv_field39                IN VARCHAR2 DEFAULT NULL,
					   iv_field40                IN VARCHAR2 DEFAULT NULL,
   					   iv_field41                IN VARCHAR2 DEFAULT NULL,
					   iv_field42                IN VARCHAR2 DEFAULT NULL,
					   iv_field43                IN VARCHAR2 DEFAULT NULL,
					   iv_field44                IN VARCHAR2 DEFAULT NULL,
					   iv_field45                IN VARCHAR2 DEFAULT NULL,
					   iv_field46                IN VARCHAR2 DEFAULT NULL,
					   iv_field47                IN VARCHAR2 DEFAULT NULL,
					   iv_field48                IN VARCHAR2 DEFAULT NULL,
					   iv_field49                IN VARCHAR2 DEFAULT NULL,
					   iv_field50                IN VARCHAR2 DEFAULT NULL,
					   iv_field51                IN VARCHAR2 DEFAULT NULL,
					   iv_field52                IN VARCHAR2 DEFAULT NULL,
					   iv_field53                IN VARCHAR2 DEFAULT NULL,
					   iv_field54                IN VARCHAR2 DEFAULT NULL,
					   iv_field55                IN VARCHAR2 DEFAULT NULL,
					   iv_field56                IN VARCHAR2 DEFAULT NULL,
					   iv_field57                IN VARCHAR2 DEFAULT NULL,
					   iv_field58                IN VARCHAR2 DEFAULT NULL,
					   iv_field59                IN VARCHAR2 DEFAULT NULL,
					   iv_field60                IN VARCHAR2 DEFAULT NULL,
                       iv_field61                IN VARCHAR2 DEFAULT NULL,
					   iv_field62                IN VARCHAR2 DEFAULT NULL,
					   iv_field63                IN VARCHAR2 DEFAULT NULL,
					   iv_field64                IN VARCHAR2 DEFAULT NULL,
					   iv_field65                IN VARCHAR2 DEFAULT NULL,
					   iv_field66                IN VARCHAR2 DEFAULT NULL,
					   iv_field67                IN VARCHAR2 DEFAULT NULL,
					   iv_field68                IN VARCHAR2 DEFAULT NULL,
					   iv_field69                IN VARCHAR2 DEFAULT NULL,
					   iv_field70                IN VARCHAR2 DEFAULT NULL,
					   iv_field71                IN VARCHAR2 DEFAULT NULL,
					   iv_field72                IN VARCHAR2 DEFAULT NULL,
					   iv_field73                IN VARCHAR2 DEFAULT NULL,
					   iv_field74                IN VARCHAR2 DEFAULT NULL,
					   iv_field75                IN VARCHAR2 DEFAULT NULL,
					   iv_field76                IN VARCHAR2 DEFAULT NULL,
					   iv_field77                IN VARCHAR2 DEFAULT NULL,
					   iv_field78                IN VARCHAR2 DEFAULT NULL,
					   iv_field79                IN VARCHAR2 DEFAULT NULL,
					   iv_field80                IN VARCHAR2 DEFAULT NULL,
   					   iv_field81                IN VARCHAR2 DEFAULT NULL,
					   iv_field82                IN VARCHAR2 DEFAULT NULL,
					   iv_field83                IN VARCHAR2 DEFAULT NULL,
					   iv_field84                IN VARCHAR2 DEFAULT NULL,
					   iv_field85                IN VARCHAR2 DEFAULT NULL,
					   iv_field86                IN VARCHAR2 DEFAULT NULL,
					   iv_field87                IN VARCHAR2 DEFAULT NULL,
					   iv_field88                IN VARCHAR2 DEFAULT NULL,
					   iv_field89                IN VARCHAR2 DEFAULT NULL,
					   iv_field90                IN VARCHAR2 DEFAULT NULL,
					   iv_field91                IN VARCHAR2 DEFAULT NULL,
					   iv_field92                IN VARCHAR2 DEFAULT NULL,
					   iv_field93                IN VARCHAR2 DEFAULT NULL,
					   iv_field94                IN VARCHAR2 DEFAULT NULL,
					   iv_field95                IN VARCHAR2 DEFAULT NULL,
					   iv_field96                IN VARCHAR2 DEFAULT NULL,
					   iv_field97                IN VARCHAR2 DEFAULT NULL,
					   iv_field98                IN VARCHAR2 DEFAULT NULL,
					   iv_field99                IN VARCHAR2 DEFAULT NULL,
					   iv_field100               IN VARCHAR2 DEFAULT NULL
   					   ) RETURN VARCHAR2 IS
v_delimiter          VARCHAR2(1)    := ';';
v_replacement_char   VARCHAR2(1)    := ' ';
v_delimited_text     VARCHAR2(20000);
BEGIN
  -- Removes the Delimiter from the fields and replaces it with
  -- Replacement Char, then concatenates the fields together
  -- separated by the delimiter
                      v_delimited_text := REPLACE(iv_field1,v_delimiter,v_replacement_char)       || v_delimiter ||
	                  REPLACE(iv_field2,v_delimiter,v_replacement_char)       || v_delimiter ||
			          REPLACE(iv_field3,v_delimiter,v_replacement_char)       || v_delimiter ||
	        		  REPLACE(iv_field4,v_delimiter,v_replacement_char)       || v_delimiter ||
					  REPLACE(iv_field5,v_delimiter,v_replacement_char)       || v_delimiter ||
					  REPLACE(iv_field6,v_delimiter,v_replacement_char)       || v_delimiter ||
					  REPLACE(iv_field7,v_delimiter,v_replacement_char)       || v_delimiter ||
					  REPLACE(iv_field8,v_delimiter,v_replacement_char)       || v_delimiter ||
					  REPLACE(iv_field9,v_delimiter,v_replacement_char)       || v_delimiter ||
					  REPLACE(iv_field10,v_delimiter,v_replacement_char)      || v_delimiter ||
					  REPLACE(iv_field11,v_delimiter,v_replacement_char)      || v_delimiter ||
					  REPLACE(iv_field12,v_delimiter,v_replacement_char)      || v_delimiter ||
					  REPLACE(iv_field13,v_delimiter,v_replacement_char)      || v_delimiter ||
					  REPLACE(iv_field14,v_delimiter,v_replacement_char)      || v_delimiter ||
					  REPLACE(iv_field15,v_delimiter,v_replacement_char)      || v_delimiter ||
					  REPLACE(iv_field16,v_delimiter,v_replacement_char)      || v_delimiter ||
					  REPLACE(iv_field17,v_delimiter,v_replacement_char)      || v_delimiter ||
					  REPLACE(iv_field18,v_delimiter,v_replacement_char)      || v_delimiter ||
					  REPLACE(iv_field19,v_delimiter,v_replacement_char)      || v_delimiter ||
					  REPLACE(iv_field20,v_delimiter,v_replacement_char)      || v_delimiter ||
					  REPLACE(iv_field21,v_delimiter,v_replacement_char)      || v_delimiter ||
					  REPLACE(iv_field22,v_delimiter,v_replacement_char)      || v_delimiter ||
					  REPLACE(iv_field23,v_delimiter,v_replacement_char)      || v_delimiter ||
					  REPLACE(iv_field24,v_delimiter,v_replacement_char)      || v_delimiter ||
					  REPLACE(iv_field25,v_delimiter,v_replacement_char)      || v_delimiter ||
					  REPLACE(iv_field26,v_delimiter,v_replacement_char)      || v_delimiter ||
					  REPLACE(iv_field27,v_delimiter,v_replacement_char)      || v_delimiter ||
					  REPLACE(iv_field28,v_delimiter,v_replacement_char)      || v_delimiter ||
					  REPLACE(iv_field29,v_delimiter,v_replacement_char)      || v_delimiter ||
					  REPLACE(iv_field30,v_delimiter,v_replacement_char)      || v_delimiter ||
					  REPLACE(iv_field31,v_delimiter,v_replacement_char)      || v_delimiter ||
					  REPLACE(iv_field32,v_delimiter,v_replacement_char)      || v_delimiter ||
					  REPLACE(iv_field33,v_delimiter,v_replacement_char)      || v_delimiter ||
					  REPLACE(iv_field34,v_delimiter,v_replacement_char)      || v_delimiter ||
					  REPLACE(iv_field35,v_delimiter,v_replacement_char)      || v_delimiter ||
					  REPLACE(iv_field36,v_delimiter,v_replacement_char)      || v_delimiter ||
					  REPLACE(iv_field37,v_delimiter,v_replacement_char)      || v_delimiter ||
					  REPLACE(iv_field38,v_delimiter,v_replacement_char)      || v_delimiter ||
					  REPLACE(iv_field39,v_delimiter,v_replacement_char)      || v_delimiter ||
					  REPLACE(iv_field40,v_delimiter,v_replacement_char)      || v_delimiter ||
					  REPLACE(iv_field41,v_delimiter,v_replacement_char)      || v_delimiter ||
					  REPLACE(iv_field42,v_delimiter,v_replacement_char)      || v_delimiter ||
					  REPLACE(iv_field43,v_delimiter,v_replacement_char)      || v_delimiter ||
					  REPLACE(iv_field44,v_delimiter,v_replacement_char)      || v_delimiter ||
					  REPLACE(iv_field45,v_delimiter,v_replacement_char)      || v_delimiter ||
					  REPLACE(iv_field46,v_delimiter,v_replacement_char)      || v_delimiter ||
					  REPLACE(iv_field47,v_delimiter,v_replacement_char)      || v_delimiter ||
					  REPLACE(iv_field48,v_delimiter,v_replacement_char)      || v_delimiter ||
					  REPLACE(iv_field49,v_delimiter,v_replacement_char)      || v_delimiter ||
					  REPLACE(iv_field50,v_delimiter,v_replacement_char)      || v_delimiter ||
					  REPLACE(iv_field51,v_delimiter,v_replacement_char)      || v_delimiter ||
					  REPLACE(iv_field52,v_delimiter,v_replacement_char)      || v_delimiter ||
					  REPLACE(iv_field53,v_delimiter,v_replacement_char)      || v_delimiter ||
					  REPLACE(iv_field54,v_delimiter,v_replacement_char)      || v_delimiter ||
					  REPLACE(iv_field55,v_delimiter,v_replacement_char)      || v_delimiter ||
					  REPLACE(iv_field56,v_delimiter,v_replacement_char)      || v_delimiter ||
					  REPLACE(iv_field57,v_delimiter,v_replacement_char)      || v_delimiter ||
					  REPLACE(iv_field58,v_delimiter,v_replacement_char)      || v_delimiter ||
					  REPLACE(iv_field59,v_delimiter,v_replacement_char)      || v_delimiter ||
                      REPLACE(iv_field60,v_delimiter,v_replacement_char)      || v_delimiter ||
                      REPLACE(iv_field61,v_delimiter,v_replacement_char)      || v_delimiter ||
	                  REPLACE(iv_field62,v_delimiter,v_replacement_char)      || v_delimiter ||
			          REPLACE(iv_field63,v_delimiter,v_replacement_char)      || v_delimiter ||
	        		  REPLACE(iv_field64,v_delimiter,v_replacement_char)      || v_delimiter ||
					  REPLACE(iv_field65,v_delimiter,v_replacement_char)      || v_delimiter ||
					  REPLACE(iv_field66,v_delimiter,v_replacement_char)      || v_delimiter ||
					  REPLACE(iv_field67,v_delimiter,v_replacement_char)      || v_delimiter ||
					  REPLACE(iv_field68,v_delimiter,v_replacement_char)      || v_delimiter ||
					  REPLACE(iv_field69,v_delimiter,v_replacement_char)      || v_delimiter ||
					  REPLACE(iv_field70,v_delimiter,v_replacement_char)      || v_delimiter ||
					  REPLACE(iv_field71,v_delimiter,v_replacement_char)      || v_delimiter ||
					  REPLACE(iv_field72,v_delimiter,v_replacement_char)      || v_delimiter ||
					  REPLACE(iv_field73,v_delimiter,v_replacement_char)      || v_delimiter ||
					  REPLACE(iv_field74,v_delimiter,v_replacement_char)      || v_delimiter ||
					  REPLACE(iv_field75,v_delimiter,v_replacement_char)      || v_delimiter ||
					  REPLACE(iv_field76,v_delimiter,v_replacement_char)      || v_delimiter ||
					  REPLACE(iv_field77,v_delimiter,v_replacement_char)      || v_delimiter ||
					  REPLACE(iv_field78,v_delimiter,v_replacement_char)      || v_delimiter ||
					  REPLACE(iv_field79,v_delimiter,v_replacement_char)      || v_delimiter ||
					  REPLACE(iv_field80,v_delimiter,v_replacement_char)      || v_delimiter ||
					  REPLACE(iv_field81,v_delimiter,v_replacement_char)      || v_delimiter ||
					  REPLACE(iv_field82,v_delimiter,v_replacement_char)      || v_delimiter ||
					  REPLACE(iv_field83,v_delimiter,v_replacement_char)      || v_delimiter ||
					  REPLACE(iv_field84,v_delimiter,v_replacement_char)      || v_delimiter ||
					  REPLACE(iv_field85,v_delimiter,v_replacement_char)      || v_delimiter ||
					  REPLACE(iv_field86,v_delimiter,v_replacement_char)      || v_delimiter ||
					  REPLACE(iv_field87,v_delimiter,v_replacement_char)      || v_delimiter ||
					  REPLACE(iv_field88,v_delimiter,v_replacement_char)      || v_delimiter ||
					  REPLACE(iv_field89,v_delimiter,v_replacement_char)      || v_delimiter ||
					  REPLACE(iv_field90,v_delimiter,v_replacement_char)      || v_delimiter ||
					  REPLACE(iv_field91,v_delimiter,v_replacement_char)      || v_delimiter ||
					  REPLACE(iv_field92,v_delimiter,v_replacement_char)      || v_delimiter ||
					  REPLACE(iv_field93,v_delimiter,v_replacement_char)      || v_delimiter ||
					  REPLACE(iv_field94,v_delimiter,v_replacement_char)      || v_delimiter ||
					  REPLACE(iv_field95,v_delimiter,v_replacement_char)      || v_delimiter ||
					  REPLACE(iv_field96,v_delimiter,v_replacement_char)      || v_delimiter ||
					  REPLACE(iv_field97,v_delimiter,v_replacement_char)      || v_delimiter ||
					  REPLACE(iv_field98,v_delimiter,v_replacement_char)      || v_delimiter ||
					  REPLACE(iv_field99,v_delimiter,v_replacement_char)      || v_delimiter ||
					  REPLACE(iv_field100,v_delimiter,v_replacement_char);
  -- return only the number of fields as requested by
  -- the iv_number_of_fields parameter
  	 	 			v_delimited_text := SUBSTR(v_delimited_text,1,INSTR(v_delimited_text,v_delimiter,1,iv_number_of_fields)-1);
  RETURN v_delimited_text;
EXCEPTION
  WHEN OTHERS THEN
    RETURN NULL;
END; -- delimit_text
-- ken_rec
-- Ken Mod 7/26/05
PROCEDURE Record_Changed_term_his_x
                       ( p_Person_Id IN NUMBER,
                         p_g_sysdate IN DATE,
                         p_papf_effective_start_date OUT DATE,
                         p_papf_effective_end_date   OUT DATE,
                         p_paaf_assignment_id        OUT NUMBER,
                         p_paaf_effective_start_date OUT DATE,
                         p_paaf_effective_end_date   OUT DATE,
                         p_PERIOD_OF_SERVICE_ID      OUT NUMBER,
                         p_ACTUAL_TERMINATION_DATE   OUT DATE,
                         p_FINAL_PROCESS_DATE        OUT DATE,
                         p_LEAVING_REASON            OUT VARCHAR2,
                         p_date_start                OUT DATE,
                         p_term_his                  OUT VARCHAR2
) IS  -- RETURN VARCHAR2 IS
CURSOR curr_pps (cv_person_id NUMBER, cv_extract_date DATE)IS
SELECT *
  --FROM cust.ttec_spain_pay_interface_pps --code commented by RXNETHI-ARGANO,15/05/23
  FROM apps.ttec_spain_pay_interface_pps --code added by RXNETHI-ARGANO,15/05/23
 WHERE person_id = cv_person_id
-- Ken Mod 8/11/05 changed extract_date to cut_off_date and g_cut_off_date, there will be only set of pps extract for each run with
-- cut_off_date
--   AND trunc(extract_date) = trunc(cv_extract_date)
   AND TRUNC(cut_off_date) = TRUNC(g_cut_off_date)
ORDER BY date_start;
CURSOR past_pps (cv_person_id NUMBER, cv_extract_date DATE)IS
SELECT *
  --FROM cust.ttec_spain_pay_interface_pps --code commented by RXNETHI-ARGANO,15/05/23
  FROM apps.ttec_spain_pay_interface_pps --code added by RXNETHI-ARGANO,15/05/23
 WHERE person_id = cv_person_id
--   AND trunc(extract_date) = (select max(trunc(extract_date))
--                                from cust.ttec_spain_pay_interface_pps
--                               where person_id = cv_person_id
--                                 and trunc(extract_date) < trunc(cv_extract_date))
   AND TRUNC(cut_off_date) = (SELECT MAX(TRUNC(cut_off_date))
                                --FROM cust.ttec_spain_pay_interface_pps --code commented by RXNETHI-ARGANO,15/05/23
								FROM apps.ttec_spain_pay_interface_pps --code added by RXNETHI-ARGANO,15/05/23
                               WHERE person_id = cv_person_id
                                 AND TRUNC(cut_off_date) < TRUNC(g_cut_off_date))
ORDER BY date_start;
i BINARY_INTEGER :=0;
l_v_index BINARY_INTEGER;
l_v_value_to_compare VARCHAR2(240);
curr_record_count NUMBER :=0;
past_record_count NUMBER :=0;
--TYPE pps_rectabtype IS TABLE OF cust.ttec_spain_pay_interface_pps%ROWTYPE --code commented by RXNETHI-ARGANO,15/05/23
TYPE pps_rectabtype IS TABLE OF apps.ttec_spain_pay_interface_pps%ROWTYPE --code added by RXNETHI-ARGANO,15/05/23
INDEX BY BINARY_INTEGER;
curr_pps_table pps_rectabtype;
past_pps_table pps_rectabtype;
v_extract_date                 DATE                 := p_g_sysdate;
v_person_id                    NUMBER(10)           := p_person_id;
v_term_his                     VARCHAR2(1)          := NULL;
v_papf_effective_start_date    DATE                 := NULL;
v_papf_effective_end_date      DATE                 := NULL;
v_paaf_assignment_id           NUMBER(10)           := NULL;
v_paaf_effective_start_date    DATE                 := NULL;
v_paaf_effective_end_date      DATE                 := NULL;
v_PERIOD_OF_SERVICE_ID         NUMBER(9)            := NULL;
v_ACTUAL_TERMINATION_DATE      DATE                 := NULL;
v_FINAL_PROCESS_DATE           DATE                 := NULL;
v_LEAVING_REASON               VARCHAR2(30)         := NULL;
v_date_start                   DATE                 := NULL;
BEGIN
i := 0;
FOR curr_pps_rec IN curr_pps(v_person_id, v_extract_date)
 LOOP
   i := i+1;
   curr_pps_table(i) := curr_pps_rec;
 END LOOP;
curr_record_count := curr_pps_table.COUNT;
i := 0;
FOR past_pps_rec IN  past_pps(v_person_id, v_extract_date)
 LOOP
   i := i+1;
   past_pps_table(i) := past_pps_rec;
 END LOOP;
past_record_count := past_pps_table.COUNT;
IF (past_record_count != 0) THEN   -- do not find term for baseline audit table establishment time.
   FOR i IN past_pps_table.FIRST .. past_pps_table.LAST LOOP
      IF (    TRUNC(past_pps_table(i).DATE_START) = TRUNC(curr_pps_table(i).DATE_START)
          AND past_pps_table(i).PERIOD_OF_SERVICE_ID = curr_pps_table(i).PERIOD_OF_SERVICE_ID
          AND past_pps_table(i).ACTUAL_TERMINATION_DATE IS NULL
          AND curr_pps_table(i).ACTUAL_TERMINATION_DATE IS NOT NULL
          -- and trunc(curr_pps_table(i).FINAL_PROCESS_DATE) <= trunc(p_g_sysdate)
          AND TRUNC(curr_pps_table(i).FINAL_PROCESS_DATE) <= TRUNC(g_cut_off_date)
          AND TRUNC(curr_pps_table(i).ACTUAL_TERMINATION_DATE) = TRUNC(curr_pps_table(i).FINAL_PROCESS_DATE)
          ) THEN
          -- find termination and final processed before or on today(sysdate) and actual term date equal to final process date
          v_term_his                         := 'Y';
          v_papf_effective_start_date        := curr_pps_table(i).papf_effective_start_date;
          v_papf_effective_end_date          := curr_pps_table(i).papf_effective_end_date;
          v_paaf_assignment_id               := curr_pps_table(i).paaf_assignment_id;
          v_paaf_effective_start_date        := curr_pps_table(i).paaf_effective_start_date;
          v_paaf_effective_end_date          := curr_pps_table(i).paaf_effective_end_date;
          v_PERIOD_OF_SERVICE_ID             := curr_pps_table(i).PERIOD_OF_SERVICE_ID;
          v_ACTUAL_TERMINATION_DATE          := curr_pps_table(i).ACTUAL_TERMINATION_DATE;
          v_FINAL_PROCESS_DATE               := curr_pps_table(i).FINAL_PROCESS_DATE;
          v_LEAVING_REASON                   := curr_pps_table(i).LEAVING_REASON;
          v_date_start                       := curr_pps_table(i).DATE_START;
          p_term_his                         := v_term_his;
          p_papf_effective_start_date        := v_papf_effective_start_date;
          p_papf_effective_end_date          := v_papf_effective_end_date;
          p_paaf_assignment_id               := v_paaf_assignment_id;
          p_paaf_effective_start_date        := v_paaf_effective_start_date;
          p_paaf_effective_end_date          := v_paaf_effective_end_date;
          p_PERIOD_OF_SERVICE_ID             := v_PERIOD_OF_SERVICE_ID;
          p_ACTUAL_TERMINATION_DATE          := v_ACTUAL_TERMINATION_DATE;
          p_FINAL_PROCESS_DATE               := v_FINAL_PROCESS_DATE;
          p_LEAVING_REASON                   := v_LEAVING_REASON;
          p_date_start                       := v_date_start;
          EXIT;  /* exits the loop */
      END IF;
      IF (    TRUNC(past_pps_table(i).DATE_START) = TRUNC(curr_pps_table(i).DATE_START)
          AND past_pps_table(i).PERIOD_OF_SERVICE_ID = curr_pps_table(i).PERIOD_OF_SERVICE_ID
          AND past_pps_table(i).ACTUAL_TERMINATION_DATE IS NULL
          AND curr_pps_table(i).ACTUAL_TERMINATION_DATE IS NOT NULL
          -- and trunc(curr_pps_table(i).FINAL_PROCESS_DATE) <= trunc(p_g_sysdate)
          AND TRUNC(curr_pps_table(i).FINAL_PROCESS_DATE) <= TRUNC(g_cut_off_date)
          AND TRUNC(curr_pps_table(i).ACTUAL_TERMINATION_DATE) != TRUNC(curr_pps_table(i).FINAL_PROCESS_DATE)
          ) THEN
          -- find termination and final processed before or on today(sysdate) and actual term date NOT equal to final process date
          v_term_his                         := 'X';
          v_papf_effective_start_date        := curr_pps_table(i).papf_effective_start_date;
          v_papf_effective_end_date          := curr_pps_table(i).papf_effective_end_date;
          v_paaf_assignment_id               := curr_pps_table(i).paaf_assignment_id;
          v_paaf_effective_start_date        := curr_pps_table(i).paaf_effective_start_date;
          v_paaf_effective_end_date          := curr_pps_table(i).paaf_effective_end_date;
          v_PERIOD_OF_SERVICE_ID             := curr_pps_table(i).PERIOD_OF_SERVICE_ID;
          v_ACTUAL_TERMINATION_DATE          := curr_pps_table(i).ACTUAL_TERMINATION_DATE;
          v_FINAL_PROCESS_DATE               := curr_pps_table(i).FINAL_PROCESS_DATE;
          v_LEAVING_REASON                   := curr_pps_table(i).LEAVING_REASON;
          v_date_start                       := curr_pps_table(i).DATE_START;
          p_term_his                         := v_term_his;
          p_papf_effective_start_date        := v_papf_effective_start_date;
          p_papf_effective_end_date          := v_papf_effective_end_date;
          p_paaf_assignment_id               := v_paaf_assignment_id;
          p_paaf_effective_start_date        := v_paaf_effective_start_date;
          p_paaf_effective_end_date          := v_paaf_effective_end_date;
          p_PERIOD_OF_SERVICE_ID             := v_PERIOD_OF_SERVICE_ID;
          p_ACTUAL_TERMINATION_DATE          := v_ACTUAL_TERMINATION_DATE;
          p_FINAL_PROCESS_DATE               := v_FINAL_PROCESS_DATE;
          p_LEAVING_REASON                   := v_LEAVING_REASON;
          p_date_start                       := v_date_start;
          EXIT;  /* exits the loop */
      END IF;
   END LOOP;
END IF;
EXCEPTION WHEN OTHERS THEN
Fnd_File.put_line(Fnd_File.LOG,'IN Record_Changed_term_his_x loc=600 exception error...');
Fnd_File.put_line(Fnd_File.LOG,SQLCODE || ' XXX ' || SUBSTR(SQLERRM,1,255));
v_term_his := 'N';
p_term_his := v_term_his;
END;  -- procedure Record_Changed_term_his_x
 PROCEDURE  get_employee_element_info(iv_person_id IN NUMBER)  IS
CURSOR c_emp IS
   SELECT   *
     --FROM   cust.ttec_sp_payroll_interface_mst tbpim --code commented by RXNETHI-ARGANO,15/05/23
	 FROM   apps.ttec_sp_payroll_interface_mst tbpim --code added by RXNETHI-ARGANO,15/05/23
    WHERE   tbpim.person_id = iv_person_id
      AND   LTRIM(RTRIM(tbpim.last_extract_file_type)) = 'CIN'
	  AND   tbpim.cut_off_date = TRUNC(g_cut_off_date)  -- TT#404712 By C. Chan 09/22/2005
	  AND   NOT EXISTS (SELECT 1                                                      -- TT#404712 By C. Chan 09/22/2005
                        --FROM   cust.ttec_sp_payroll_interface_mst tbpim2              -- TT#404712 By C. Chan 09/22/2005
				        --code commented by RXNETHI-ARGANO,15/05/23
						FROM   apps.ttec_sp_payroll_interface_mst tbpim2              -- TT#404712 By C. Chan 09/22/2005
				        --code added by RXNETHI-ARGANO,15/05/23
						WHERE  person_id = tbpim.person_id                            -- TT#404712 By C. Chan 09/22/2005
						AND    tbpim.peef_element_entry_id = tbpim2.peef_element_entry_id
				        AND    LTRIM(RTRIM(tbpim2.last_extract_file_type)) = 'CIN'    -- TT#404712 By C. Chan 09/22/2005
                        AND    tbpim2.creation_date = (SELECT MAX(creation_date)
         			                                   --FROM   cust.ttec_sp_payroll_interface_mst tbpim1
			      	                                   --code commented by RXNETHI-ARGANO,15/05/23
													   FROM   apps.ttec_sp_payroll_interface_mst tbpim1
			      	                                   --code added by RXNETHI-ARGANO,15/05/23
													   WHERE  tbpim.person_id = tbpim1.person_id
													   AND  tbpim.peef_element_entry_id = tbpim1.peef_element_entry_id
				                                       AND  LTRIM(RTRIM(tbpim1.last_extract_file_type)) = 'CIN'
										      		  AND  tbpim1.creation_date < TRUNC(g_cut_off_date))); -- TT#404712 By C. Chan 09/22/2005
v_output   VARCHAR2(4000);
BEGIN
  FOR r_emp IN c_emp LOOP
	                         v_output := delimit_text(iv_number_of_fields  => 8
				 , iv_field1           =>  pad_data_output('VARCHAR2',16,'CIN')
				 , iv_field2            => pad_data_output('VARCHAR2',30,r_emp.employee_id)
				 , iv_field3            => pad_data_output('VARCHAR2',30,r_emp.period_ordinal )
				 , iv_field4            => TO_CHAR(r_emp.incidence_date,'yyyy-mm-dd')
				 , iv_field5            => TO_CHAR(r_emp.cut_off_date,'yyyy-mm') || '-25'
			--  , iv_field5            => TO_CHAR(r_emp.payroll_payment_date,'yyyy-mm-dd')
         			 , iv_field6            => pad_data_output('VARCHAR2',30,r_emp.cost_center)
				 , iv_field7            => pad_data_output('VARCHAR2',30,r_emp.payment_type_code)
				 , iv_field8            => r_emp.payment_type_value
				 );
  --DBMS_OUTPUT.PUT_LINE(LENGTH(v_output));
  --DBMS_OUTPUT.PUT_LINE(v_output);
 -- print_line('3');
  print_line(v_output);
-- Ken Mod 8/24/05 Store data into temp table cust.ttec_sp_payroll_iface_ele_tmp
-- the above table is used to genernate control totals (CIN)
    --INSERT INTO cust.ttec_sp_payroll_iface_ele_tmp ( --code commented by RXNETHI-ARGANO,15/05/23
	INSERT INTO apps.ttec_sp_payroll_iface_ele_tmp ( --code added by RXNETHI-ARGANO,15/05/23
          emp_attribute12,
          ele_attribute1,
          payment_type_value)
    VALUES (
      r_emp.employee_id,
      r_emp.payment_type_code,
      ROUND(r_emp.payment_type_value,2)
    );
  END LOOP; -- c_emp
END; -- procedure get_employee_element_info
--==================*****
--------------------------------------------------------------------
--                                                                --
-- Name:  extract_elements_ctl_tot      (Procedure)               --
--                                                                --
--     Description:     To product control totals from            --
--                     table cust.ttec_arg_pay_interface_ele_tmp  --
--                                                                --
--                                                                --
--     Change History                                             --
--                                                                --
--     Changed By        Date        Reason for Change            --
--     ----------        ----        -----------------            --
--                                                                --
--                                                                --
--------------------------------------------------------------------
PROCEDURE extract_elements_ctl_tot  IS
CURSOR t_elements_ctl_tot IS
SELECT
       ele_attribute1,
       SUM (payment_type_value) s_payment_type_value
  --FROM cust.ttec_sp_payroll_iface_ele_tmp --code commented by RXNETHI-ARGANO,15/05/23
  FROM apps.ttec_sp_payroll_iface_ele_tmp --code added by RXNETHI-ARGANO,15/05/23
 GROUP BY ele_attribute1;
v_output        VARCHAR2(4000);
BEGIN
Fnd_File.put_line(Fnd_File.LOG,'                           ');
Fnd_File.put_line(Fnd_File.LOG,'########################################################');
Fnd_File.put_line(Fnd_File.LOG,'##### PAY CODES CONTROL TOTAL (CIN) SECTION - BEGIN ####');
Fnd_File.put_line(Fnd_File.LOG,'#### Output format --> Pay_code;payment_type_value  ####');
FOR r_elements_ctl_tot IN t_elements_ctl_tot LOOP
v_output := delimit_text(iv_number_of_fields          => 2,
                         iv_field1                => r_elements_ctl_tot.ele_attribute1,
                         iv_field2                => ROUND(r_elements_ctl_tot.s_payment_type_value,2)
                        );
Fnd_File.put_line(Fnd_File.LOG,v_output);
-- print_line(v_output);
END LOOP; -- t_elements_ctl_tot
Fnd_File.put_line(Fnd_File.LOG,'##### PAY CODES CONTROL TOTAL (CIN) SECTION - END   ####');
Fnd_File.put_line(Fnd_File.LOG,'########################################################');
Fnd_File.put_line(Fnd_File.LOG,'                           ');
EXCEPTION
  WHEN OTHERS THEN
        g_retcode := SQLCODE;
        g_errbuf  := SUBSTR(SQLERRM,1,255);
        Fnd_File.put_line(Fnd_File.LOG,'extract_elements_ctl_tot Failed');
        Fnd_File.put_line(Fnd_File.LOG,SUBSTR(SQLERRM,1,255));
        RAISE g_e_abort;
END; -- extract_elements_ctl_tot
---============================
PROCEDURE  extract_spain_element  IS
     CURSOR c_hire IS
     	 SELECT DISTINCT person_id
      	   --FROM   cust.ttec_sp_payroll_interface_mst a --code commented by RXNETHI-ARGANO,15/05/23
		   FROM   apps.ttec_sp_payroll_interface_mst a --code added by RXNETHI-ARGANO,15/05/23
      	  WHERE  TRUNC(a.creation_date) = TRUNC(g_cut_off_date)
	    AND   LTRIM(RTRIM(a.last_extract_file_type)) = 'CIN';
       	     --AND    system_person_type = 'EMP';
       	     /*AND    NOT EXISTS (SELECT 'x'
             	  FROM   cust.ttec_sp_payroll_interface_mst s
               	  WHERE  s.person_id = a.person_id
	 	  AND    TRUNC(s.creation_date) != TRUNC(g_cut_off_date));*/
v_output                 VARCHAR2(4000);
ov_retcode NUMBER;
ov_errbuf   VARCHAR2(1000);
BEGIN
  FOR r_hire IN c_hire LOOP
  --print_line(r_hire.person_id);
  get_employee_element_info(r_hire.person_id);
  END LOOP; -- c_hire
  EXCEPTION
    WHEN OTHERS THEN
    Fnd_File.put_line(Fnd_File.LOG,'Error from Extract_spain_element');
	ov_retcode := SQLCODE;
	ov_errbuf  := SUBSTR(SQLERRM,1,255);
END; -- procedure extract_spain_element
PROCEDURE  extract_absence_new  IS
     CURSOR c_absence_new  IS
         SELECT *
      	   --FROM   cust.ttec_sp_payroll_interface_mst a --code commented by RXNETHI-ARGANO,15/05/23
		   FROM   apps.ttec_sp_payroll_interface_mst a --code added by RXNETHI-ARGANO,15/05/23
      	  WHERE  TRUNC(a.cut_off_date) = TRUNC(g_cut_off_date)
	    AND   LTRIM(RTRIM(a.last_extract_file_type)) = 'NAUS';
v_output                 VARCHAR2(4000);
ov_retcode NUMBER;
ov_errbuf   VARCHAR2(1000);
Cnt               NUMBER;
NewEntryYorN  VARCHAR2(10) := 'Y' ;
v_output1   VARCHAR2(4000);
BEGIN
  FOR r_absence_new  IN c_absence_new LOOP
  --print_line(r_hire.person_id);
             NewEntryYorN := 'Y' ;
			 Cnt := 0;
	         SELECT COUNT(*)
			 INTO        Cnt
			 --FROM      cust.ttec_sp_payroll_interface_mst past --code commented by RXNETHI-ARGANO,15/05/23
			 FROM      apps.ttec_sp_payroll_interface_mst past --code added by RXNETHI-ARGANO,15/05/23
			 WHERE  LTRIM(RTRIM(past.last_extract_file_type)) = 'NAUS'
			 AND         past.person_id =    r_absence_new.person_id
			 AND         past.assignment_id = r_absence_new.assignment_id
			 AND         TRUNC(past.EntryEffectiveStartDate) = TRUNC(r_absence_new.EntryEffectiveStartDate)
			 AND        TRUNC(past.EntryEffectiveEndDate) = TRUNC(r_absence_new.EntryEffectiveEndDate)
			 --AND        TRUNC(past.AbsenceStartDate) = TRUNC(r_absence_new.AbsenceStartDate)
			 --AND        TRUNC(past.AbsenceEndDate) = TRUNC(r_absence_new.AbsenceEndDate)
			 AND         TRUNC(past.cut_off_date) <  TRUNC(r_absence_new.cut_off_date);
			 IF Cnt = 0 THEN
			      NewEntryYorN := 'Y' ;
			 ELSE
			      NewEntryYorN := 'N' ;
		     END IF;
			 IF NewEntryYorN = 'Y'  THEN
			      v_output1 := delimit_text(iv_number_of_fields  => 9
				 , iv_field1           =>  pad_data_output('VARCHAR2',16,'NAUS')
				 , iv_field2            => pad_data_output('VARCHAR2',30,r_absence_new.employee_id)
				 , iv_field3            => pad_data_output('VARCHAR2',30,r_absence_new.period_ordinal )
				 , iv_field4            => r_absence_new.IncidenceID
				 , iv_field5            => TO_CHAR(r_absence_new.AbsenceStartDate,'yyyy-mm-dd')
				 , iv_field6            => TO_CHAR(r_absence_new.AbsenceEndDate,'yyyy-mm-dd')
				 , iv_field7            => TO_CHAR(r_absence_new.RelapseDate,'yyyy-mm-dd')
				 , iv_field8            => r_absence_new.TipoUnidad
				 , iv_field9            =>r_absence_new.Unidad
				 );
                     print_line(v_output1);
			 END IF;
  END LOOP; -- c_absence_new
  EXCEPTION
    WHEN OTHERS THEN
    Fnd_File.put_line(Fnd_File.LOG,'Error from Extract_absence_new');
	ov_retcode := SQLCODE;
	ov_errbuf  := SUBSTR(SQLERRM,1,255);
END; -- procedure extract_absence_new
PROCEDURE  extract_absence_mod  IS
     CURSOR c_absence_new  IS
        SELECT *
     	--FROM   cust.ttec_sp_payroll_interface_mst a --code commented by RXNETHI-ARGANO,15/05/23
		FROM   apps.ttec_sp_payroll_interface_mst a --code added by RXNETHI-ARGANO,15/05/23
      	WHERE  TRUNC(a.cut_off_date) = TRUNC(g_cut_off_date)
	AND   LTRIM(RTRIM(a.last_extract_file_type)) = 'NAUS';
v_output                 VARCHAR2(4000);
ov_retcode NUMBER;
ov_errbuf   VARCHAR2(1000);
Cnt               NUMBER;
NewEntryYorN  VARCHAR2(10) := 'Y' ;
v_output1   VARCHAR2(4000);
v_AbsenceStartDate  DATE;
v_AbsenceEndDate DATE;
v_RelapseDate  DATE;
v_TipoUnidad  VARCHAR2(60);
v_Unidad		NUMBER ;
past_AbsenceStartDate  DATE;
past_AbsenceEndDate DATE;
past_RelapseDate  DATE;
past_TipoUnidad  VARCHAR2(60);
past_Unidad		NUMBER ;
BEGIN
  FOR r_absence_new  IN c_absence_new LOOP
  --print_line(r_hire.person_id);
             NewEntryYorN := 'Y' ;
			 Cnt := 0;
			/*IF 		r_absence_new.person_id = 228976 THEN
			         Fnd_File.put_line(Fnd_File.LOG,'message :section 1');
			END IF;			*/
	        SELECT COUNT(*)
			 INTO        Cnt
			 --FROM      cust.ttec_sp_payroll_interface_mst past --code commented by RXNETHI-ARGANO,15/05/23
			 FROM      apps.ttec_sp_payroll_interface_mst past --code added by RXNETHI-ARGANO,15/05/23
			 WHERE  LTRIM(RTRIM(past.last_extract_file_type)) = 'NAUS'
			 AND         past.person_id =    r_absence_new.person_id
			 AND         past.assignment_id = r_absence_new.assignment_id
			 AND         TRUNC(past.EntryEffectiveStartDate) = TRUNC(r_absence_new.EntryEffectiveStartDate)
			 AND        TRUNC(past.EntryEffectiveEndDate) = TRUNC(r_absence_new.EntryEffectiveEndDate)
			 --AND        TRUNC(past.AbsenceStartDate) = TRUNC(r_absence_new.AbsenceStartDate)
			 --AND        TRUNC(past.AbsenceEndDate) = TRUNC(r_absence_new.AbsenceEndDate)
			 AND         TRUNC(past.cut_off_date) <  TRUNC(r_absence_new.cut_off_date);
			/*IF 		r_absence_new.person_id = 228976 THEN
			          Fnd_File.put_line(Fnd_File.LOG,'message :section 2');
					   Fnd_File.put_line(Fnd_File.LOG,'message : section3 ' || TO_CHAR(cnt) );
		    END IF;		*/
			 IF Cnt = 0 THEN
			      NewEntryYorN := 'Y' ;
			 ELSE
			      NewEntryYorN := 'N' ;
		     END IF;
			IF NewEntryYorN = 'N'  THEN
			      SELECT AbsenceStartDate
	                           , AbsenceEndDate
				   ,RelapseDate
				   ,TipoUnidad
				   ,Unidad
			      INTO  past_AbsenceStartDate
				   ,past_AbsenceEndDate
				   ,past_RelapseDate
				   ,past_TipoUnidad
                                   ,past_Unidad
			      --FROM      cust.ttec_sp_payroll_interface_mst past --code commented by RXNETHI-ARGANO,15/05/23
				  FROM      apps.ttec_sp_payroll_interface_mst past --code added by RXNETHI-ARGANO,15/05/23
			      WHERE  LTRIM(RTRIM(past.last_extract_file_type)) = 'NAUS'
			      AND         past.person_id =    r_absence_new.person_id
			      AND         TRUNC(past.cut_off_date) = (SELECT MAX(TRUNC(cut_off_date))
                        					      --FROM   cust.ttec_sp_payroll_interface_mst --code commented by RXNETHI-ARGANO,15/05/23
												  FROM   apps.ttec_sp_payroll_interface_mst --code added by RXNETHI-ARGANO,15/05/23
								  WHERE  person_id = r_absence_new.person_id
								  AND    assignment_id = r_absence_new.assignment_id
								  AND    LTRIM(RTRIM(last_extract_file_type)) = 'NAUS'
								  AND    TRUNC(EntryEffectiveStartDate) = TRUNC(r_absence_new.EntryEffectiveStartDate)
								  AND    TRUNC(EntryEffectiveEndDate) = TRUNC(r_absence_new.EntryEffectiveEndDate)
								  AND    TRUNC(cut_off_date) < TRUNC(g_cut_off_date));
				IF  r_absence_new.AbsenceStartDate <> past_AbsenceStartDate  THEN
				      v_AbsenceStartDate := r_absence_new.AbsenceStartDate;
					   v_AbsenceEndDate := r_absence_new.AbsenceEndDate;
				ELSE
				     v_AbsenceStartDate := NULL;
					  v_AbsenceEndDate := NULL;
				END IF;
				IF  r_absence_new.AbsenceEndDate <> NVL(past_AbsenceEndDate,TO_DATE('12-31-4712','mm-dd-yyyy'))  THEN
				      v_AbsenceEndDate := r_absence_new.AbsenceEndDate;
					  v_AbsenceStartDate := r_absence_new.AbsenceStartDate;
				ELSE
				     v_AbsenceEndDate := NULL;
					  v_AbsenceStartDate := NULL;
				END IF;
				IF  r_absence_new.RelapseDate <> past_RelapseDate  THEN
				      v_RelapseDate := r_absence_new.RelapseDate;
				ELSE
				     v_RelapseDate := NULL;
				END IF;
				IF  r_absence_new.TipoUnidad <> past_TipoUnidad  THEN
				      v_TipoUnidad := r_absence_new.TipoUnidad;
				ELSE
				     v_TipoUnidad := NULL;
				END IF;
				IF  r_absence_new.Unidad <> past_Unidad THEN
				      v_Unidad := r_absence_new.Unidad;
				ELSE
				     v_Unidad := NULL;
				END IF;
				IF  r_absence_new.AbsenceStartDate <> past_AbsenceStartDate   OR
				     r_absence_new.AbsenceEndDate <> NVL(past_AbsenceEndDate,TO_DATE('12-31-4712','mm-dd-yyyy'))       OR
					 r_absence_new.RelapseDate <> past_RelapseDate          OR
					 r_absence_new.TipoUnidad <> past_TipoUnidad   OR
					 r_absence_new.Unidad <> past_Unidad   THEN
			      v_output1 := delimit_text(iv_number_of_fields  => 9
				 , iv_field1           =>  pad_data_output('VARCHAR2',16,'MAUS')
				 , iv_field2            => pad_data_output('VARCHAR2',30,r_absence_new.employee_id)
				 , iv_field3            => pad_data_output('VARCHAR2',30,r_absence_new.period_ordinal )
				 , iv_field4            => r_absence_new.IncidenceID
				 , iv_field5            => TO_CHAR(v_AbsenceStartDate,'yyyy-mm-dd')
				 , iv_field6            => TO_CHAR(v_AbsenceEndDate,'yyyy-mm-dd')
				 , iv_field7            => TO_CHAR(v_RelapseDate,'yyyy-mm-dd')
				 , iv_field8            => v_TipoUnidad
				 , iv_field9            => v_Unidad
				 );
                     print_line(v_output1);
				END IF;
			 END IF;
  END LOOP; -- c_absence_new
  EXCEPTION
    WHEN OTHERS THEN
    Fnd_File.put_line(Fnd_File.LOG,'Error from Extract_absence_mod');
	ov_retcode := SQLCODE;
	ov_errbuf  := SUBSTR(SQLERRM,1,255);
END; -- procedure extract_absence_mod
PROCEDURE  extract_absence_baus  IS
     CURSOR c_absence_baus  IS
     SELECT *
      	--FROM   cust.ttec_sp_payroll_interface_mst a --code commented by RXNETHI-ARGANO,15/05/23
		FROM   apps.ttec_sp_payroll_interface_mst a --code added by RXNETHI-ARGANO,15/05/23
 	WHERE  TRUNC(a.cut_off_date) = TRUNC(g_cut_off_date)
	AND   LTRIM(RTRIM(a.last_extract_file_type)) = 'BAUS';
v_output                 VARCHAR2(4000);
ov_retcode NUMBER;
ov_errbuf   VARCHAR2(1000);
Cnt               NUMBER;
NewEntryYorN  VARCHAR2(10) := 'Y' ;
v_output1   VARCHAR2(4000);
BEGIN
  FOR r_absence_baus  IN c_absence_baus LOOP
  --print_line(r_hire.person_id);
             NewEntryYorN := 'Y' ;
			 Cnt := 0;
	         SELECT COUNT(*)
			 INTO        Cnt
			 --FROM      cust.ttec_sp_payroll_interface_mst past --code commented by RXNETHI-ARGANO,15/05/23
			 FROM      apps.ttec_sp_payroll_interface_mst past --code added by RXNETHI-ARGANO,15/05/23
			 WHERE  LTRIM(RTRIM(past.last_extract_file_type)) = 'BAUS'
			 AND         past.person_id =    r_absence_baus.person_id
			 AND         past.assignment_id = r_absence_baus.assignment_id
			 AND         TRUNC(past.EntryEffectiveStartDate) = TRUNC(r_absence_baus.EntryEffectiveStartDate)
			 AND        TRUNC(past.EntryEffectiveEndDate) = TRUNC(r_absence_baus.EntryEffectiveEndDate)
			 --AND        TRUNC(past.AbsenceStartDate) = TRUNC(r_absence_new.AbsenceStartDate)
			 --AND        TRUNC(past.AbsenceEndDate) = TRUNC(r_absence_new.AbsenceEndDate)
			 AND         TRUNC(past.cut_off_date) <  TRUNC(r_absence_baus.cut_off_date);
			 IF Cnt = 0 THEN
			      NewEntryYorN := 'Y' ;
			 ELSE
			      NewEntryYorN := 'N' ;
		     END IF;
			 IF NewEntryYorN = 'Y'  THEN
			      v_output1 := delimit_text(iv_number_of_fields  => 7
				 , iv_field1           =>  pad_data_output('VARCHAR2',16,'BAUS')
				 , iv_field2            => pad_data_output('VARCHAR2',30,r_absence_baus.employee_id)
				 , iv_field3            => pad_data_output('VARCHAR2',30,r_absence_baus.period_ordinal )
				 , iv_field4            => r_absence_baus.IncidenceID
				 , iv_field5            => TO_CHAR(r_absence_baus.AbsenceStartDate,'yyyy-mm-dd')
				 , iv_field6            => TO_CHAR(r_absence_baus.AbsenceEndDate,'yyyy-mm-dd')
				 , iv_field7            => TO_CHAR(r_absence_baus.RelapseDate,'yyyy-mm-dd')
				-- , iv_field8            => r_absence_baus.TipoUnidad
				--  , iv_field9            =>r_absence_baus.Unidad
				 );
                     print_line(v_output1);
			 END IF;
  END LOOP; -- c_absence_baus
  EXCEPTION
    WHEN OTHERS THEN
    Fnd_File.put_line(Fnd_File.LOG,'Error from Extract_absence_baus');
	ov_retcode := SQLCODE;
	ov_errbuf  := SUBSTR(SQLERRM,1,255);
END; -- procedure extract_absence_baus
PROCEDURE populate_interface_tables IS
CURSOR c_emp_data IS
SELECT
  papf.employee_number			OracleEmployeeId
--  modified by C. Chan for WO#163242
--  ,DECODE( SIGN(TRUNC(papf.original_date_of_hire) - TO_DATE('01-08-2005','DD-MM-YYYY')) ,
--	                       -1 , papf.attribute12 , papf.employee_number)   employee_id
,papf.attribute12                                                                 employee_id
  ,papf.attribute6		    period_ordinal
-- Ken Mod 8/19/05 to preserv value of peef_element_entry_id
  ,peef.element_entry_id            peef_element_entry_id
  ,peef.effective_start_date 	    incidence_date
  ,peef.effective_end_date 	    payroll_payment_date
  ,petf.attribute1 	            payment_type_code
  ,peevf.screen_entry_value         payment_type_value
  ,petf.element_name	            ElementName
  ,pivf.NAME                        InputName
  ,DECODE(pcak1.segment1,NULL,hla.attribute2,pcak1.segment1) ||
                        pcak1.segment2 ||
                        DECODE(pcak1.segment3,NULL,pcak.segment3,pcak1.segment3)   cost_center
  ,papf.creation_date	  	     person_creation_date
  ,papf.last_update_date             person_update_date
  ,paaf.assignment_id		     assignment_id
  ,paaf.creation_date		     assignment_creation_date
  ,paaf.last_update_date	     assignment_update_date
  ,papf.person_id                    person_id
  ,ppt.person_type_id                person_type_id
  ,ppt.system_person_type            system_person_type
  ,ppt.user_person_type              user_person_type
  ,paaf.effective_start_date         ass_effective_st_dt
  ,paaf.BUSINESS_GROUP_ID  BG_ID
 /*
 START R12.2 Upgrade Remediation
 code commented by RXNETHI-ARGANO,15/05/23
 FROM hr.per_all_people_f                   papf
     ,hr.per_all_assignments_f              paaf
     ,hr.per_person_types                   ppt
     ,hr.per_periods_of_service             pps
     ,hr.per_person_type_usages_f           pptuf
*/
--code added by RXNETHI-ARGANO,15/05/23
 FROM apps.per_all_people_f                   papf
     ,apps.per_all_assignments_f              paaf
     ,apps.per_person_types                   ppt
     ,apps.per_periods_of_service             pps
     ,apps.per_person_type_usages_f           pptuf
--END R12.2 Upgrade Remediation
     ,pay_cost_allocation_keyflex           pcak
     ,hr_all_organization_units             haou
     ,hr_locations_all                      hla
     ,pay_cost_allocations_f                pcaf
     ,pay_cost_allocation_keyflex           pcak1
     ,pay_element_entries_f                 peef
     ,pay_element_types_f                   petf
     ,pay_input_values_f                    pivf
     ,pay_element_entry_values_f            peevf
WHERE   papf.business_group_id = 1804
AND     papf.person_id               = paaf.person_id
AND     TRUNC(g_cut_off_date) BETWEEN papf.effective_start_date AND papf.effective_end_date
AND     papf.business_group_id       = paaf.business_group_id
AND     paaf.effective_start_date    = (SELECT    MAX(effective_start_date)
                         	          FROM     per_assignments_f
-- k                                     WHERE    assignment_id = paaf.assignment_id
                                         WHERE    person_id = papf.person_id                  -- mod by Ken_XX
   		                           AND      effective_start_date <= TRUNC(g_cut_off_date))
-- Ken Mod 8/17/05 it should be from pptuf then ppt
-- k AND     papf.person_type_id          = ppt.person_type_id
AND     papf.business_group_id       = ppt.business_group_id
AND     papf.person_id               = pps.person_id
AND     pps.date_start               = (SELECT MAX(date_start)
                                          FROM   per_periods_of_service
					  WHERE  person_id = pps.person_id
                                          AND    date_start <=  TRUNC(TRUNC(g_cut_off_date)))
-- Ken Mod 8/17/05 it should be from pptuf then ppt
-- k AND     papf.person_type_id          = pptuf.person_type_id
AND     papf.person_id               = pptuf.person_id
AND     TRUNC(g_cut_off_date) BETWEEN pptuf.effective_start_date AND pptuf.effective_end_date
AND     pptuf.person_type_id = ppt.person_type_id     -- -- Ken Mod 8/17/05 it should be from pptuf then ppt added  by Ken
AND     haou.organization_id = paaf.organization_id
AND     haou.COST_ALLOCATION_KEYFLEX_ID = pcak.COST_ALLOCATION_KEYFLEX_ID
AND     paaf.location_id = hla.location_id
AND     paaf.assignment_id = pcaf.assignment_id
AND     paaf.effective_start_date BETWEEN pcaf.effective_start_date AND pcaf.effective_end_date
AND     pcaf.COST_ALLOCATION_KEYFLEX_ID = pcak1.COST_ALLOCATION_KEYFLEX_ID
AND     peef.assignment_id = paaf.assignment_id
AND     TRUNC(g_cut_off_date)  BETWEEN peef.effective_start_date AND peef.effective_end_date
AND     peef.element_type_id = petf.element_type_id
AND     peef.effective_start_date BETWEEN petf.effective_start_date AND petf.effective_end_date
AND     pivf.element_type_id = petf.element_type_id
AND     petf.effective_start_date BETWEEN pivf.effective_start_date AND pivf.effective_end_date
AND     peevf.input_value_id = pivf.input_value_id
AND     peevf.element_entry_id = peef.element_entry_id
AND     peef.effective_start_date  BETWEEN peevf.effective_start_date AND peevf.effective_end_date
AND     petf.attribute1 IS NOT  NULL
AND     peevf.screen_entry_value IS NOT NULL
AND     UPPER(pivf.NAME) IN ( 'CANTIDAD', 'HORAS' , 'UNIDADES')
UNION
SELECT
  papf.employee_number			OracleEmployeeId
--  modified by C. Chan for WO#163242
--  ,DECODE( SIGN(TRUNC(papf.original_date_of_hire) - TO_DATE('01-08-2005','DD-MM-YYYY')) ,
--	                       -1 , papf.attribute12 , papf.employee_number)   employee_id
,papf.attribute12                                                                 employee_id
  ,papf.attribute6		    period_ordinal
  ,peef.element_entry_id            peef_element_entry_id
  ,peef.effective_start_date 	    incidence_date
  ,peef.effective_end_date 	    payroll_payment_date
  ,petf.attribute1 	            payment_type_code
  ,peevf.screen_entry_value         payment_type_value
  ,petf.element_name	            ElementName
  ,pivf.NAME                        InputName
  ,DECODE(pcak1.segment1,NULL,hla.attribute2,pcak1.segment1) ||
                        pcak1.segment2 ||
                        DECODE(pcak1.segment3,NULL,pcak.segment3,pcak1.segment3)   cost_center
  ,papf.creation_date	  	     person_creation_date
  ,papf.last_update_date             person_update_date
  ,paaf.assignment_id		     assignment_id
  ,paaf.creation_date		     assignment_creation_date
  ,paaf.last_update_date	     assignment_update_date
  ,papf.person_id                    person_id
  ,ppt.person_type_id                person_type_id
  ,ppt.system_person_type            system_person_type
  ,ppt.user_person_type              user_person_type
  ,paaf.effective_start_date         ass_effective_st_dt
  ,paaf.BUSINESS_GROUP_ID  BG_ID
 /*
 START R12.2 Upgrade Remediation
 code commented by RXNETHI-ARGANO,15/05/23
 FROM hr.per_all_people_f                   papf
     ,hr.per_all_assignments_f              paaf
     ,hr.per_person_types                   ppt
     ,hr.per_periods_of_service             pps
	 ,hr.per_time_periods  ptp
     ,hr.per_person_type_usages_f           pptuf
	 */
 --code added by RXNETHI-ARGANO,15/05/23
 FROM apps.per_all_people_f                   papf
     ,apps.per_all_assignments_f              paaf
     ,apps.per_person_types                   ppt
     ,apps.per_periods_of_service             pps
	 ,apps.per_time_periods  ptp
     ,apps.per_person_type_usages_f           pptuf
 --END R12.2 Upgrade Remediation
     ,pay_cost_allocation_keyflex           pcak
     ,hr_all_organization_units             haou
     ,hr_locations_all                      hla
     ,pay_cost_allocations_f                pcaf
     ,pay_cost_allocation_keyflex           pcak1
     ,pay_element_entries_f                 peef
     ,pay_element_types_f                   petf
     ,pay_input_values_f                    pivf
     ,pay_element_entry_values_f            peevf
WHERE   papf.business_group_id = 1804
AND     papf.person_id               = paaf.person_id
AND     g_cut_off_date BETWEEN papf.effective_start_date AND papf.effective_end_date
AND     papf.business_group_id       = paaf.business_group_id
AND     papf.business_group_id       = ppt.business_group_id
AND     papf.person_id               = pps.person_id
AND     papf.person_id               = pptuf.person_id
AND     g_cut_off_date BETWEEN pptuf.effective_start_date AND pptuf.effective_end_date
AND     pptuf.person_type_id = ppt.person_type_id
AND     paaf.payroll_id = ptp.payroll_id
AND     pps.final_process_date IS NOT NULL
AND     paaf.effective_end_date BETWEEN ptp.start_date AND ptp.end_date
AND     pps.final_process_date BETWEEN ptp.start_date AND ptp.end_date
AND     g_cut_off_date BETWEEN ptp.start_date AND ptp.end_date
AND     haou.organization_id = paaf.organization_id
AND     haou.COST_ALLOCATION_KEYFLEX_ID = pcak.COST_ALLOCATION_KEYFLEX_ID
AND     paaf.location_id = hla.location_id
AND     paaf.assignment_id = pcaf.assignment_id
AND     paaf.effective_start_date BETWEEN pcaf.effective_start_date AND pcaf.effective_end_date
AND     pcaf.COST_ALLOCATION_KEYFLEX_ID = pcak1.COST_ALLOCATION_KEYFLEX_ID
AND     peef.assignment_id = paaf.assignment_id
AND     peef.effective_start_date BETWEEN ptp.start_date AND ptp.end_date
AND     peef.element_type_id = petf.element_type_id
AND     peef.effective_start_date BETWEEN petf.effective_start_date AND petf.effective_end_date
AND     pivf.element_type_id = petf.element_type_id
AND     petf.effective_start_date BETWEEN pivf.effective_start_date AND pivf.effective_end_date
AND     peevf.input_value_id = pivf.input_value_id
AND     peevf.element_entry_id = peef.element_entry_id
AND     peef.effective_start_date  BETWEEN peevf.effective_start_date AND peevf.effective_end_date
AND     petf.attribute1 IS NOT  NULL
AND     peevf.screen_entry_value IS NOT NULL
AND     UPPER(pivf.NAME) IN ( 'CANTIDAD', 'HORAS' , 'UNIDADES')
AND     paaf.effective_start_date    = (SELECT    MAX(effective_start_date)
                         	          FROM     per_assignments_f
--                                      WHERE    assignment_id = paaf.assignment_id
                                         WHERE    person_id = papf.person_id                  -- mod by Ken_XX
   		                           AND      effective_start_date <= TRUNC(g_cut_off_date))
--AND      papf.employee_number = '4000085'
ORDER  BY 1;   --papf.employee_number
CURSOR c_emp_absence IS
SELECT DISTINCT
	  papf.employee_number			OracleEmployeeId
--  modified by C. Chan for WO#163242
--	  ,DECODE( SIGN(TRUNC(papf.original_date_of_hire) - TO_DATE('01-08-2005','DD-MM-YYYY')) ,  --  Modified by C.Chan on 28-DEC-2005 for TT#411517
--		                       -1 , papf.attribute12 , papf.employee_number)   employee_id
,papf.attribute12                                                                 employee_id
	  ,papf.attribute6		     period_ordinal
	  ,NULL 	   		     incidence_date
	  ,NULL				     payroll_payment_date
	  ,NULL                		     payment_type_code
	  ,NULL                              payment_type_value
	  ,petf.element_name		     ElementName
	  ,petf.element_type_id
	  ,NULL 			     InputName
	  ,NULL                              cost_center
	  ,papf.creation_date	  	     person_creation_date
          ,papf.last_update_date             person_update_date
          ,paaf.assignment_id		     assignment_id
          ,paaf.creation_date		     assignment_creation_date
          ,paaf.last_update_date	     assignment_update_date
         ,papf.person_id                     person_id
         ,ppt.person_type_id                 person_type_id
         ,ppt.system_person_type             system_person_type
         ,ppt.user_person_type               user_person_type
	 ,paaf.effective_start_date          ass_effective_st_dt
	 ,paaf.BUSINESS_GROUP_ID  BG_ID
-- Ken Mod 8/19/05 to preserv value of peef_element_entry_id
  ,peef.element_entry_id            peef_element_entry_id
	 ,peef.effective_start_date	     EntryEffectiveStartDate
	 ,peef.effective_end_date	     EntryEffectiveEndDate
	 ,petf.attribute2                    IncidenceID
	 ,NULL				     RelapseDate
	 ,NULL				     TipoUnidad
	 ,NULL				     Unidad
	 ,pivf.input_value_id
 /*
 START R12.2 Upgrade Remediation
 code commented by RXNETHI-ARGANO,15/05/23
 FROM hr.per_all_people_f                    papf
     ,hr.per_all_assignments_f               paaf
     ,hr.per_person_types                    ppt
     ,hr.per_periods_of_service              pps
     ,hr.per_person_type_usages_f            pptuf
	 */
 --code adde dby RXNETHI-ARGANO,15/05/23
 FROM apps.per_all_people_f                    papf
     ,apps.per_all_assignments_f               paaf
     ,apps.per_person_types                    ppt
     ,apps.per_periods_of_service              pps
     ,apps.per_person_type_usages_f            pptuf
 --END R12.2 Upgrade Remediation
     ,pay_element_entries_f                  peef
     ,pay_element_types_f                    petf
     ,pay_input_values_f                     pivf
     ,pay_element_entry_values_f             peevf
WHERE   papf.business_group_id = 1804
AND     papf.person_id               = paaf.person_id
AND     TRUNC(g_cut_off_date) BETWEEN papf.effective_start_date AND papf.effective_end_date
AND     papf.business_group_id       = paaf.business_group_id
AND     paaf.effective_start_date    = (SELECT    MAX(effective_start_date)
                                           FROM     per_assignments_f
-- k                                       WHERE    assignment_id = paaf.assignment_id
                                           WHERE    person_id = papf.person_id                  -- mod by Ken_XX
   		                           AND      effective_start_date <= TRUNC(g_cut_off_date))
-- Ken Mod 8/17/05 it should be from pptuf then ppt
-- k AND     papf.person_type_id          = ppt.person_type_id
AND     papf.business_group_id       = ppt.business_group_id
AND     papf.person_id               = pps.person_id
AND     pps.date_start               = (SELECT MAX(date_start)
                                          FROM   per_periods_of_service
					  WHERE  person_id = pps.person_id
                                          AND    date_start <=  TRUNC(TRUNC(g_cut_off_date)))
-- Ken Mod 8/17/05 it should be from pptuf then ppt
-- k AND     papf.person_type_id          = pptuf.person_type_id
AND     papf.person_id               = pptuf.person_id
AND     TRUNC(g_cut_off_date) BETWEEN pptuf.effective_start_date AND pptuf.effective_end_date
AND     pptuf.person_type_id = ppt.person_type_id     -- -- Ken Mod 8/17/05 it should be from pptuf then ppt added  by Ken
AND     peef.assignment_id = paaf.assignment_id
AND     TRUNC(g_cut_off_date)  BETWEEN peef.effective_start_date AND peef.effective_end_date
AND     peef.element_type_id = petf.element_type_id
AND     peef.effective_start_date BETWEEN petf.effective_start_date AND petf.effective_end_date
AND     pivf.element_type_id = petf.element_type_id
AND     petf.effective_start_date BETWEEN pivf.effective_start_date AND pivf.effective_end_date
AND     peevf.input_value_id = pivf.input_value_id
AND     peevf.element_entry_id = peef.element_entry_id
AND     peef.effective_start_date  BETWEEN peevf.effective_start_date AND peevf.effective_end_date
AND     petf.attribute2 IS NOT  NULL
--AND     UPPER(pivf.NAME) IN ( 'FECHA INICIO') --, 'FECHA FIN')
-- Ken Mod 7/19/05 included fecha de inicio
AND     UPPER(pivf.NAME) IN ( 'FECHA INICIO', 'FECHA DE INICIO') --, 'FECHA FIN')
--AND      papf.employee_number = '4000085'
ORDER  BY papf.employee_number;
CURSOR  c_emp_baus IS
         SELECT *
           FROM ttec_sp_payroll_interface_mst
          WHERE LTRIM(RTRIM(last_extract_file_type)) = 'NAUS'
            AND       TRUNC(cut_off_date) = (SELECT MAX(TRUNC(cut_off_date))
               		   	               FROM   ttec_sp_payroll_interface_mst
					      WHERE TRUNC(cut_off_date) < TRUNC(g_cut_off_date));
/*CURSOR c_emp_absence_baus ( PersonID NUMBER,
                              ElementTypeId  NUMBER,
			      AssignmentId NUMBER,
			      ActiveEntryEffectiveStartDate DATE,
			      InputValueID  NUMBER )
			   IS*/
CURSOR c_emp_absence_baus ( PersonID NUMBER,
                            ElementName  VARCHAR2,
		 	    AssignmentId NUMBER,
			    CutOffDate DATE
			  )
			IS
SELECT DISTINCT
  papf.employee_number			OracleEmployeeId
--  modified by C. Chan for WO#163242
--  ,DECODE( SIGN(TRUNC(papf.original_date_of_hire) - TO_DATE('01-08-2005','DD-MM-YYYY')) ,  --  Modified by C.Chan on 28-DEC-2005 for TT#411517
--          -1 , papf.attribute12 , papf.employee_number)   employee_id
,papf.attribute12                                                                 employee_id
  ,papf.attribute6	   period_ordinal
  ,NULL 	   	   incidence_date
  ,NULL			   payroll_payment_date
  ,NULL                	   payment_type_code
  ,NULL                    payment_type_value
  ,petf.element_name	   ElementName
  ,NULL 		   InputName
  ,NULL                    cost_center
  ,papf.creation_date	   person_creation_date
  ,papf.last_update_date   person_update_date
  ,paaf.assignment_id	   assignment_id
  ,paaf.creation_date	   assignment_creation_date
  ,paaf.last_update_date   assignment_update_date
  ,papf.person_id          person_id
  ,ppt.person_type_id      person_type_id
  ,ppt.system_person_type  system_person_type
  ,ppt.user_person_type    user_person_type
  ,paaf.effective_start_date ass_effective_st_dt
  ,paaf.BUSINESS_GROUP_ID  BG_ID
-- Ken Mod 8/19/05 to preserv value of peef_element_entry_id
  ,peef.element_entry_id            peef_element_entry_id
  ,peef.effective_start_date 	EntryEffectiveStartDate
  ,peef.effective_end_date      EntryEffectiveEndDate
  ,petf.attribute2              IncidenceID
  ,NULL			        RelapseDate
  ,NULL			        TipoUnidad
  ,NULL			        Unidad
/*
START R12.2 Upgrade Remediation
code commented by RXNETHI-ARGANO,15/05/23
FROM hr.per_all_people_f                    papf
    ,hr.per_all_assignments_f               paaf
    ,hr.per_person_types                    ppt
    ,hr.per_periods_of_service              pps
    ,hr.per_person_type_usages_f            pptuf
	*/
	--code added by RXNETHI-ARGANO,15/05/23
FROM apps.per_all_people_f                    papf
    ,apps.per_all_assignments_f               paaf
    ,apps.per_person_types                    ppt
    ,apps.per_periods_of_service              pps
    ,apps.per_person_type_usages_f            pptuf
	--END R12.2 Upgrade Remediation
    ,pay_element_entries_f                  peef
    ,pay_element_types_f                    petf
    ,pay_input_values_f                     pivf
    ,pay_element_entry_values_f             peevf
WHERE   papf.business_group_id = 1804
AND     papf.person_id = PersonId
AND     papf.person_id = paaf.person_id
AND     paaf.assignment_id = AssignmentId
AND     TRUNC(g_cut_off_date) BETWEEN papf.effective_start_date AND papf.effective_end_date
AND     papf.business_group_id       = paaf.business_group_id
AND     paaf.effective_start_date    = (SELECT    MAX(effective_start_date)
        				  FROM     per_assignments_f
-- k                                     WHERE    assignment_id = paaf.assignment_id
                                         WHERE    person_id = papf.person_id                  -- mod by Ken_XX
   		                           AND      effective_start_date <= TRUNC(g_cut_off_date))
-- Ken Mod 8/17/05 it should be from pptuf then ppt
-- k AND     papf.person_type_id          = ppt.person_type_id
AND     papf.business_group_id       = ppt.business_group_id
AND     papf.person_id               = pps.person_id
AND     pps.date_start               = (SELECT MAX(date_start)
                                          FROM   per_periods_of_service
					  WHERE  person_id = pps.person_id
                                          AND    date_start <=  TRUNC(g_cut_off_date))
-- Ken Mod 8/17/05 it should be from pptuf then ppt
-- k AND     papf.person_type_id          = pptuf.person_type_id
AND     papf.person_id               = pptuf.person_id
AND     TRUNC(g_cut_off_date) BETWEEN pptuf.effective_start_date AND pptuf.effective_end_date
AND     pptuf.person_type_id = ppt.person_type_id     -- -- Ken Mod 8/17/05 it should be from pptuf then ppt added  by Ken
AND     peef.assignment_id = paaf.assignment_id
--AND     TRUNC(peef.effective_end_date) = TRUNC(ActiveEntryEffectiveStartDate) - 1
AND     TRUNC(peef.effective_end_date) BETWEEN TRUNC(CutOffDate) AND TRUNC(g_cut_off_date)
AND     peef.element_type_id = petf.element_type_id
AND     UPPER(petf.element_name) = UPPER(ElementName)
--AND     petf.element_type_id = ElementTypeID
AND     peef.effective_start_date BETWEEN petf.effective_start_date AND petf.effective_end_date
AND     pivf.element_type_id = petf.element_type_id
AND     petf.effective_start_date BETWEEN pivf.effective_start_date AND pivf.effective_end_date
AND     peevf.input_value_id = pivf.input_value_id
--AND      pivf.input_value_id = InputValueId
AND     peevf.element_entry_id = peef.element_entry_id
AND     peef.effective_start_date  BETWEEN peevf.effective_start_date AND peevf.effective_end_date
AND     petf.attribute2 IS NOT  NULL
-- AND     UPPER(pivf.NAME) IN ( 'FECHA INICIO') --, 'FECHA FIN')
-- Ken Mod 7/19/05 included fecha de inicio
AND     UPPER(pivf.NAME) IN ( 'FECHA INICIO', 'FECHA DE INICIO') --, 'FECHA FIN')
--AND      papf.employee_number = '4000085'
ORDER  BY papf.employee_number;
-- AAA starting.. Ken Mod 7/25/05 to pull data term and final processed on or before today (interface run sysdate)
CURSOR c_emp_data_term     (cv_person_id                 NUMBER,
                            cv_papf_effective_start_date DATE,
                            cv_papf_effective_end_date   DATE,
                            cv_paaf_effective_start_date DATE,
                            cv_paaf_effective_end_date   DATE,
                            cv_date_start                DATE,
                            cv_paaf_assignment_id        NUMBER) IS
SELECT
  papf.employee_number			OracleEmployeeId
--  modified by C. Chan for WO#163242
--  ,DECODE( SIGN(TRUNC(papf.original_date_of_hire) - TO_DATE('01-08-2005','DD-MM-YYYY')) ,--  Modified by C.Chan on 28-DEC-2005 for TT#411517
--	                       -1 , papf.attribute12 , papf.employee_number)   employee_id
  ,papf.attribute12                                                                 employee_id
  ,papf.attribute6		    period_ordinal
-- Ken Mod 8/19/05 to preserv value of peef_element_entry_id
  ,peef.element_entry_id            peef_element_entry_id
  ,peef.effective_start_date 	    incidence_date
  ,peef.effective_end_date 	    payroll_payment_date
  ,petf.attribute1 	            payment_type_code
  ,peevf.screen_entry_value         payment_type_value
  ,petf.element_name	            ElementName
  ,pivf.NAME                        InputName
  ,DECODE(pcak1.segment1,NULL,hla.attribute2,pcak1.segment1) ||
                        pcak1.segment2 ||
                        DECODE(pcak1.segment3,NULL,pcak.segment3,pcak1.segment3)   cost_center
  ,papf.creation_date	  	     person_creation_date
  ,papf.last_update_date             person_update_date
  ,paaf.assignment_id		     assignment_id
  ,paaf.creation_date		     assignment_creation_date
  ,paaf.last_update_date	     assignment_update_date
  ,papf.person_id                    person_id
  ,ppt.person_type_id                person_type_id
  ,ppt.system_person_type            system_person_type
  ,ppt.user_person_type              user_person_type
  ,paaf.effective_start_date         ass_effective_st_dt
  ,paaf.BUSINESS_GROUP_ID  BG_ID
 /*
 START R12.2 Upgrade Remediation
 code commented by RXNETHI-ARGANO,15/05/23
 FROM hr.per_all_people_f                   papf
     ,hr.per_all_assignments_f              paaf
     ,hr.per_person_types                   ppt
     ,hr.per_periods_of_service             pps
     ,hr.per_person_type_usages_f           pptuf
	 */
 --code added by RXNETHI-ARGANO,15/05/23
 FROM apps.per_all_people_f                   papf
     ,apps.per_all_assignments_f              paaf
     ,apps.per_person_types                   ppt
     ,apps.per_periods_of_service             pps
     ,apps.per_person_type_usages_f           pptuf
 --END R12.2 Upgrade Remediation
     ,pay_cost_allocation_keyflex           pcak
     ,hr_all_organization_units             haou
     ,hr_locations_all                      hla
     ,pay_cost_allocations_f                pcaf
     ,pay_cost_allocation_keyflex           pcak1
     ,pay_element_entries_f                 peef
     ,pay_element_types_f                   petf
     ,pay_input_values_f                    pivf
     ,pay_element_entry_values_f            peevf
WHERE   papf.business_group_id = 1804
AND     papf.person_id                = cv_person_id    -- difference from normal cursor
-- AND     TRUNC(g_cut_off_date) BETWEEN papf.effective_start_date AND papf.effective_end_date
AND     TRUNC(papf.effective_start_date)    = TRUNC(cv_papf_effective_start_date)     -- difference from normal cursor
AND     TRUNC(papf.effective_end_date)    = TRUNC(cv_papf_effective_end_date)         -- difference from normal cursor
AND     papf.business_group_id       = paaf.business_group_id
-- AND     paaf.effective_start_date    = (SELECT    MAX(effective_start_date)
--                          	          FROM     per_assignments_f
--                                       WHERE    assignment_id = paaf.assignment_id
--                                       AND      effective_start_date <= TRUNC(g_cut_off_date))
AND     TRUNC(paaf.effective_start_date)    = TRUNC(cv_paaf_effective_start_date)          -- difference from normal cursor
AND     paaf.assignment_id                  = cv_paaf_assignment_id                        -- difference from normal cursor
-- Ken Mod 8/17/05 it should be from pptuf then ppt
-- k AND     papf.person_type_id          = ppt.person_type_id
AND     papf.business_group_id       = ppt.business_group_id
AND     papf.person_id               = pps.person_id
-- AND     pps.date_start               = (SELECT MAX(date_start)
--                                           FROM   per_periods_of_service
--                                          WHERE  person_id = pps.person_id
--                                          AND    date_start <=  TRUNC(TRUNC(g_cut_off_date)))
AND     TRUNC(pps.date_start)      = TRUNC(cv_date_start)                                 -- difference from normal cursor
-- Ken Mod 8/17/05 it should be from pptuf then ppt
-- k AND     papf.person_type_id          = pptuf.person_type_id
AND     papf.person_id               = pptuf.person_id
-- AND     TRUNC(g_cut_off_date) BETWEEN pptuf.effective_start_date AND pptuf.effective_end_date
AND     TRUNC(pptuf.effective_start_date) = TRUNC(cv_papf_effective_start_date)          -- difference from normal cursor
AND     TRUNC(pptuf.effective_end_date) = TRUNC(cv_papf_effective_end_date)              -- difference from normal cursor
AND     pptuf.person_type_id = ppt.person_type_id     -- -- Ken Mod 8/17/05 it should be from pptuf then ppt added  by Ken
AND     haou.organization_id = paaf.organization_id
AND     haou.COST_ALLOCATION_KEYFLEX_ID = pcak.COST_ALLOCATION_KEYFLEX_ID
AND     paaf.location_id = hla.location_id
AND     paaf.assignment_id = pcaf.assignment_id
-- AND     paaf.effective_start_date BETWEEN pcaf.effective_start_date AND pcaf.effective_end_date
-- for the case term and final processed on or before today, but final process date is later than actual term date need to use
-- cv_paaf_effective_end_date for pcaf table
AND     (    (TRUNC(pcaf.effective_end_date) = TRUNC(cv_papf_effective_end_date))
          OR (TRUNC(pcaf.effective_end_date) = TRUNC(cv_paaf_effective_end_date))     )  -- difference from normal cursor
AND     pcaf.COST_ALLOCATION_KEYFLEX_ID = pcak1.COST_ALLOCATION_KEYFLEX_ID
AND     peef.assignment_id = paaf.assignment_id
-- AND     TRUNC(g_cut_off_date)  BETWEEN peef.effective_start_date AND peef.effective_end_date
AND     TRUNC(peef.effective_end_date) = TRUNC(cv_paaf_effective_end_date)              -- difference from normal cursor
AND     peef.element_type_id = petf.element_type_id
AND     peef.effective_start_date BETWEEN petf.effective_start_date AND petf.effective_end_date
AND     pivf.element_type_id = petf.element_type_id
AND     petf.effective_start_date BETWEEN pivf.effective_start_date AND pivf.effective_end_date
AND     peevf.input_value_id = pivf.input_value_id
AND     peevf.element_entry_id = peef.element_entry_id
-- AND     peef.effective_start_date  BETWEEN peevf.effective_start_date AND peevf.effective_end_date
AND     TRUNC(peevf.effective_end_date) = TRUNC(cv_paaf_effective_end_date)              -- difference from normal cursor
AND     petf.attribute1 IS NOT  NULL
AND     peevf.screen_entry_value IS NOT NULL
AND     UPPER(pivf.NAME) IN ( 'CANTIDAD', 'HORAS' , 'UNIDADES')
--AND      papf.employee_number = '4000085'
ORDER  BY papf.employee_number;
CURSOR c_emp_absence_term (cv_person_id                 NUMBER,
                            cv_papf_effective_start_date DATE,
                            cv_papf_effective_end_date   DATE,
                            cv_paaf_effective_start_date DATE,
                            cv_paaf_effective_end_date   DATE,
                            cv_date_start                DATE,
                            cv_paaf_assignment_id        NUMBER) IS
SELECT DISTINCT
	  papf.employee_number			OracleEmployeeId
--  modified by C. Chan for WO#163242
--	  ,DECODE( SIGN(TRUNC(papf.original_date_of_hire) - TO_DATE('01-08-2005','DD-MM-YYYY')) , --  Modified by C.Chan on 28-DEC-2005 for TT#411517
--		                       -1 , papf.attribute12 , papf.employee_number)   employee_id
,papf.attribute12                                                                 employee_id
	  ,papf.attribute6		     period_ordinal
	  ,NULL 	   		     incidence_date
	  ,NULL				     payroll_payment_date
	  ,NULL                		     payment_type_code
	  ,NULL                              payment_type_value
	  ,petf.element_name		     ElementName
	  ,petf.element_type_id
	  ,NULL 			     InputName
	  ,NULL                              cost_center
	  ,papf.creation_date	  	     person_creation_date
          ,papf.last_update_date             person_update_date
          ,paaf.assignment_id		     assignment_id
          ,paaf.creation_date		     assignment_creation_date
          ,paaf.last_update_date	     assignment_update_date
         ,papf.person_id                     person_id
         ,ppt.person_type_id                 person_type_id
         ,ppt.system_person_type             system_person_type
         ,ppt.user_person_type               user_person_type
	 ,paaf.effective_start_date          ass_effective_st_dt
	 ,paaf.BUSINESS_GROUP_ID  BG_ID
-- Ken Mod 8/19/05 to preserv value of peef_element_entry_id
  ,peef.element_entry_id            peef_element_entry_id
	 ,peef.effective_start_date	     EntryEffectiveStartDate
	 ,peef.effective_end_date	     EntryEffectiveEndDate
	 ,petf.attribute2                    IncidenceID
	 ,NULL				     RelapseDate
	 ,NULL				     TipoUnidad
	 ,NULL				     Unidad
	 ,pivf.input_value_id
 /*
 START R12.2 Upgrade Remediation
 code commented by RXNETHI-ARGANO,15/05/23
 FROM hr.per_all_people_f                    papf
     ,hr.per_all_assignments_f               paaf
     ,hr.per_person_types                    ppt
     ,hr.per_periods_of_service              pps
     ,hr.per_person_type_usages_f            pptuf
	 */
 --code added by RXNETHI-ARGANO,15/05/23
 FROM apps.per_all_people_f                    papf
     ,apps.per_all_assignments_f               paaf
     ,apps.per_person_types                    ppt
     ,apps.per_periods_of_service              pps
     ,apps.per_person_type_usages_f            pptuf
 --END R12.2 Upgrade Remediation
     ,pay_element_entries_f                  peef
     ,pay_element_types_f                    petf
     ,pay_input_values_f                     pivf
     ,pay_element_entry_values_f             peevf
WHERE   papf.business_group_id = 1804
-- AND     papf.person_id               = paaf.person_id
AND     papf.person_id               = cv_person_id    -- difference from normal cursor
-- AND     TRUNC(g_cut_off_date) BETWEEN papf.effective_start_date AND papf.effective_end_date
AND     TRUNC(papf.effective_start_date)    = TRUNC(cv_papf_effective_start_date)     -- difference from normal cursor
AND     TRUNC(papf.effective_end_date)    = TRUNC(cv_papf_effective_end_date)         -- difference from normal cursor
AND     papf.business_group_id       = paaf.business_group_id
-- AND     paaf.effective_start_date    = (SELECT    MAX(effective_start_date)
--                                            FROM     per_assignments_f
--                                           WHERE    assignment_id = paaf.assignment_id
--                                             AND      effective_start_date <= TRUNC(g_cut_off_date))
AND     TRUNC(paaf.effective_start_date)    = TRUNC(cv_paaf_effective_start_date)          -- difference from normal cursor
AND     paaf.assignment_id                  = cv_paaf_assignment_id                        -- difference from normal cursor
-- Ken Mod 8/17/05 it should be from pptuf then ppt
-- k AND     papf.person_type_id          = ppt.person_type_id
AND     papf.business_group_id       = ppt.business_group_id
AND     papf.person_id               = pps.person_id
-- AND     pps.date_start               = (SELECT MAX(date_start)
--                                           FROM   per_periods_of_service
--                                          WHERE  person_id = pps.person_id
--                                          AND    date_start <=  TRUNC(TRUNC(g_cut_off_date)))
AND     TRUNC(pps.date_start)      = TRUNC(cv_date_start)                                 -- difference from normal cursor
-- Ken Mod 8/17/05 it should be from pptuf then ppt
-- k AND     papf.person_type_id          = pptuf.person_type_id
AND     papf.person_id               = pptuf.person_id
-- AND     TRUNC(g_cut_off_date) BETWEEN pptuf.effective_start_date AND pptuf.effective_end_date
AND     TRUNC(pptuf.effective_start_date) = TRUNC(cv_papf_effective_start_date)          -- difference from normal cursor
AND     TRUNC(pptuf.effective_end_date) = TRUNC(cv_papf_effective_end_date)              -- difference from normal cursor
AND     pptuf.person_type_id = ppt.person_type_id     -- -- Ken Mod 8/17/05 it should be from pptuf then ppt added  by Ken
AND     peef.assignment_id = paaf.assignment_id
-- AND     TRUNC(g_cut_off_date)  BETWEEN peef.effective_start_date AND peef.effective_end_date
AND     TRUNC(peef.effective_end_date) = TRUNC(cv_paaf_effective_end_date)              -- difference from normal cursor
AND     peef.element_type_id = petf.element_type_id
AND     peef.effective_start_date BETWEEN petf.effective_start_date AND petf.effective_end_date
AND     pivf.element_type_id = petf.element_type_id
AND     petf.effective_start_date BETWEEN pivf.effective_start_date AND pivf.effective_end_date
AND     peevf.input_value_id = pivf.input_value_id
AND     peevf.element_entry_id = peef.element_entry_id
-- AND     peef.effective_start_date  BETWEEN peevf.effective_start_date AND peevf.effective_end_date
AND     TRUNC(peevf.effective_end_date) = TRUNC(cv_paaf_effective_end_date)              -- difference from normal cursor
AND     petf.attribute2 IS NOT  NULL
--AND     UPPER(pivf.NAME) IN ( 'FECHA INICIO') --, 'FECHA FIN')
-- Ken Mod 7/19/05 included fecha de inicio
AND     UPPER(pivf.NAME) IN ( 'FECHA INICIO', 'FECHA DE INICIO') --, 'FECHA FIN')
--AND      papf.employee_number = '4000085'
ORDER  BY papf.employee_number;
CURSOR  c_emp_baus_term (cv_person_id                 NUMBER,
                            cv_papf_effective_start_date DATE,
                            cv_papf_effective_end_date   DATE,
                            cv_paaf_effective_start_date DATE,
                            cv_paaf_effective_end_date   DATE,
                            cv_date_start                DATE,
                            cv_paaf_assignment_id        NUMBER) IS
         SELECT *
           FROM ttec_sp_payroll_interface_mst
          WHERE LTRIM(RTRIM(last_extract_file_type)) = 'NAUS'
            AND       TRUNC(cut_off_date) = (SELECT MAX(TRUNC(cut_off_date))
               		   	               FROM   ttec_sp_payroll_interface_mst
					      WHERE TRUNC(cut_off_date) < TRUNC(g_cut_off_date));
CURSOR c_emp_absence_baus_term ( PersonID NUMBER,
                            ElementName  VARCHAR2,
		 	    AssignmentId NUMBER,
			    CutOffDate DATE,
                            cv_person_id                 NUMBER,
                            cv_papf_effective_start_date DATE,
                            cv_papf_effective_end_date   DATE,
                            cv_paaf_effective_start_date DATE,
                            cv_paaf_effective_end_date   DATE,
                            cv_date_start                DATE,
                            cv_paaf_assignment_id        NUMBER
			  )
			IS
SELECT DISTINCT
  papf.employee_number			OracleEmployeeId
--  modified by C. Chan for WO#163242
--  ,DECODE( SIGN(TRUNC(papf.original_date_of_hire) - TO_DATE('01-MM-2005','DD-MM-YYYY')) ,  --  Modified by C.Chan on 28-DEC-2005 for TT#411517
--          -1 , papf.attribute12 , papf.employee_number)   employee_id
  ,papf.attribute12                                                                 employee_id
  ,papf.attribute6	   period_ordinal
  ,NULL 	   	   incidence_date
  ,NULL			   payroll_payment_date
  ,NULL                	   payment_type_code
  ,NULL                    payment_type_value
  ,petf.element_name	   ElementName
  ,NULL 		   InputName
  ,NULL                    cost_center
  ,papf.creation_date	   person_creation_date
  ,papf.last_update_date   person_update_date
  ,paaf.assignment_id	   assignment_id
  ,paaf.creation_date	   assignment_creation_date
  ,paaf.last_update_date   assignment_update_date
  ,papf.person_id          person_id
  ,ppt.person_type_id      person_type_id
  ,ppt.system_person_type  system_person_type
  ,ppt.user_person_type    user_person_type
  ,paaf.effective_start_date ass_effective_st_dt
  ,paaf.BUSINESS_GROUP_ID  BG_ID
-- Ken Mod 8/19/05 to preserv value of peef_element_entry_id
  ,peef.element_entry_id            peef_element_entry_id
  ,peef.effective_start_date 	EntryEffectiveStartDate
  ,peef.effective_end_date      EntryEffectiveEndDate
  ,petf.attribute2              IncidenceID
  ,NULL			        RelapseDate
  ,NULL			        TipoUnidad
  ,NULL			        Unidad
/*
START R12.2 Upgrade Remediation
code commented by RXNETHI-ARGANO,15/05/23
FROM hr.per_all_people_f                    papf
     ,hr.per_all_assignments_f               paaf
     ,hr.per_person_types                    ppt
     ,hr.per_periods_of_service              pps
     ,hr.per_person_type_usages_f            pptuf
	 */
--code added by RXNETHI-ARGANO,15/05/23
FROM apps.per_all_people_f                    papf
     ,apps.per_all_assignments_f               paaf
     ,apps.per_person_types                    ppt
     ,apps.per_periods_of_service              pps
     ,apps.per_person_type_usages_f            pptuf
--END R12.2 Upgrade Remediation
    ,pay_element_entries_f                  peef
    ,pay_element_types_f                    petf
    ,pay_input_values_f                     pivf
    ,pay_element_entry_values_f             peevf
WHERE   papf.business_group_id = 1804
AND     papf.person_id = PersonId
AND     papf.person_id = paaf.person_id
AND     paaf.assignment_id = AssignmentId
-- AND     TRUNC(g_cut_off_date) BETWEEN papf.effective_start_date AND papf.effective_end_date
AND     TRUNC(papf.effective_start_date)    = TRUNC(cv_papf_effective_start_date)     -- difference from normal cursor
AND     TRUNC(papf.effective_end_date)    = TRUNC(cv_papf_effective_end_date)         -- difference from normal cursor
AND     papf.business_group_id       = paaf.business_group_id
-- AND     paaf.effective_start_date    = (SELECT    MAX(effective_start_date)
--        				  FROM     per_assignments_f
--                                       WHERE    assignment_id = paaf.assignment_id
--                                        AND      effective_start_date <= TRUNC(g_cut_off_date))
AND     TRUNC(paaf.effective_start_date)    = TRUNC(cv_paaf_effective_start_date)          -- difference from normal cursor
-- Ken Mod 8/17/05 it should be from pptuf then ppt
-- k AND     papf.person_type_id          = ppt.person_type_id
AND     papf.business_group_id       = ppt.business_group_id
AND     papf.person_id               = pps.person_id
-- AND     pps.date_start               = (SELECT MAX(date_start)
--                                           FROM   per_periods_of_service
--                                          WHERE  person_id = pps.person_id
--                                          AND    date_start <=  TRUNC(g_cut_off_date))
AND     TRUNC(pps.date_start)      = TRUNC(cv_date_start)                                 -- difference from normal cursor
-- Ken Mod 8/17/05 it should be from pptuf then ppt
-- k AND     papf.person_type_id          = pptuf.person_type_id
AND     papf.person_id               = pptuf.person_id
-- AND     TRUNC(g_cut_off_date) BETWEEN pptuf.effective_start_date AND pptuf.effective_end_date
AND     TRUNC(pptuf.effective_start_date) = TRUNC(cv_papf_effective_start_date)          -- difference from normal cursor
AND     TRUNC(pptuf.effective_end_date) = TRUNC(cv_papf_effective_end_date)              -- difference from normal cursor
AND     pptuf.person_type_id = ppt.person_type_id     -- -- Ken Mod 8/17/05 it should be from pptuf then ppt added  by Ken
AND     peef.assignment_id = paaf.assignment_id
--0 AND     TRUNC(peef.effective_end_date) = TRUNC(ActiveEntryEffectiveStartDate) - 1
-- AND     TRUNC(peef.effective_end_date) BETWEEN TRUNC(CutOffDate) AND TRUNC(g_cut_off_date)
AND     TRUNC(peevf.effective_end_date) = TRUNC(cv_paaf_effective_end_date)              -- difference from normal cursor
AND     peef.element_type_id = petf.element_type_id
AND     UPPER(petf.element_name) = UPPER(ElementName)
--0 AND     petf.element_type_id = ElementTypeID
AND     peef.effective_start_date BETWEEN petf.effective_start_date AND petf.effective_end_date
AND     pivf.element_type_id = petf.element_type_id
AND     petf.effective_start_date BETWEEN pivf.effective_start_date AND pivf.effective_end_date
AND     peevf.input_value_id = pivf.input_value_id
--0 AND      pivf.input_value_id = InputValueId
AND     peevf.element_entry_id = peef.element_entry_id
-- AND     peef.effective_start_date  BETWEEN peevf.effective_start_date AND peevf.effective_end_date
AND     TRUNC(peevf.effective_end_date) = TRUNC(cv_paaf_effective_end_date)              -- difference from normal cursor
AND     petf.attribute2 IS NOT  NULL
--0  AND     UPPER(pivf.NAME) IN ( 'FECHA INICIO') --, 'FECHA FIN')
-- Ken Mod 7/19/05 included fecha de inicio
AND     UPPER(pivf.NAME) IN ( 'FECHA INICIO', 'FECHA DE INICIO') --, 'FECHA FIN')
--0 AND      papf.employee_number = '4000085'
ORDER  BY papf.employee_number;
CURSOR c_pps_emp_data IS
SELECT DISTINCT pps.PERSON_ID
 --FROM  hr.per_periods_of_service            pps --code commented by RXNETHI-ARGANO,15/05/23
 FROM  apps.per_periods_of_service            pps --code added by RXNETHI-ARGANO,15/05/23
ORDER BY pps.PERSON_ID;
v_extract_date                 DATE                 := SYSDATE;
v_term_his                     VARCHAR2(1)          := NULL;
v_papf_effective_start_date    DATE                 := NULL;
v_papf_effective_end_date      DATE                 := NULL;
v_paaf_assignment_id           NUMBER(10)           := NULL;
v_paaf_effective_start_date    DATE                 := NULL;
v_paaf_effective_end_date      DATE                 := NULL;
v_PERIOD_OF_SERVICE_ID         NUMBER(9)            := NULL;
v_ACTUAL_TERMINATION_DATE      DATE                 := NULL;
v_FINAL_PROCESS_DATE           DATE                 := NULL;
v_LEAVING_REASON               VARCHAR2(30)         := NULL;
v_date_start                   DATE                 := NULL;
v_incidence_date_char          VARCHAR2(60);
v_incidence_date               DATE;
-- AAA ending..
--r_interface_mst          cust.ttec_sp_payroll_interface_mst%ROWTYPE; --code commented by RXNETHI-ARGANO,15/05/23
r_interface_mst          apps.ttec_sp_payroll_interface_mst%ROWTYPE; --code added by RXNETHI-ARGANO,15/05/23
AbsenceStartDate VARCHAR2(60);
AbsenceEndDate VARCHAR2(60);
v_RelapseDate   VARCHAR2(60);
v_TipoUnidad VARCHAR2(60);
v_Unidad VARCHAR2(60);
BEGIN
	 --DELETE FROM cust.ttec_sp_payroll_interface_mst del --code commented by RXNETHI-ARGANO,15/05/23
	 DELETE FROM apps.ttec_sp_payroll_interface_mst del --code added by RXNETHI-ARGANO,15/05/23
	 WHERE TRUNC(del.cut_off_date) = TRUNC(g_cut_off_date);
-- Ken Mod 8/24/05 delete temp table cust.ttec_sp_payroll_iface_ele_tmp entries.
-- the above table is used to generate control totals (CIN) in log file
    --DELETE FROM cust.ttec_sp_payroll_iface_ele_tmp; --code commented by RXNETHI-ARGANO,15/05/23
	DELETE FROM apps.ttec_sp_payroll_iface_ele_tmp; --code added by RXNETHI-ARGANO,15/05/23
    FOR r_emp_data IN c_emp_data LOOP
-- Ken Mod 8/18/05 to overide incidence_date field with screen_entry_value of input value name Fecha, starting...
     v_incidence_date_char := NULL;
  BEGIN
/*  Commented out by C. Chan on 8/4/2006 for WO#212636
    SELECT peevf.screen_entry_value
      INTO v_incidence_date_char
      FROM
           pay_element_entries_f         peef
          ,pay_element_types_f           petf
          ,pay_input_values_f            pivf
          ,pay_element_entry_values_f    peevf
     WHERE
           peef.assignment_id = r_emp_data.assignment_id
       AND TRUNC(g_cut_off_date) BETWEEN peef.effective_start_date AND peef.effective_end_date
       AND peef.element_type_id = petf.element_type_id
       AND peef.element_entry_id = r_emp_data.peef_element_entry_id
       AND peef.effective_start_date BETWEEN petf.effective_start_date AND petf.effective_end_date
       AND petf.element_name = r_emp_data.ElementName
       AND pivf.element_type_id = petf.element_type_id
       AND petf.effective_start_date BETWEEN pivf.effective_start_date AND pivf.effective_end_date
       AND peevf.input_value_id = pivf.input_value_id
       AND peevf.element_entry_id = peef.element_entry_id
       AND peef.effective_start_date BETWEEN peevf.effective_start_date AND peevf.effective_end_date
       AND UPPER(pivf.NAME) = 'FECHA';
*/
--
-- Added by C. Chan on 8/4/2006 for WO#212636
--
    SELECT peevf.screen_entry_value
      INTO v_incidence_date_char
      FROM
           pay_element_entries_f         peef
          ,pay_element_types_f           petf
          ,pay_input_values_f            pivf
          ,pay_element_entry_values_f    peevf
		  ,per_all_assignments_f          paaf
		  ,per_periods_of_service        ppos
     WHERE
           peef.assignment_id = r_emp_data.assignment_id
--       AND TRUNC(g_cut_off_date) BETWEEN peef.effective_start_date AND peef.effective_end_date
       AND NVL(ppos.actual_termination_date,trunc(g_cut_off_date)) BETWEEN peef.effective_start_date AND peef.effective_end_date
       AND peef.element_type_id = petf.element_type_id
       AND peef.element_entry_id = r_emp_data.peef_element_entry_id
       AND peef.effective_start_date BETWEEN petf.effective_start_date AND petf.effective_end_date
       AND petf.element_name = r_emp_data.ElementName
       AND pivf.element_type_id = petf.element_type_id
       AND petf.effective_start_date BETWEEN pivf.effective_start_date AND pivf.effective_end_date
       AND peevf.input_value_id = pivf.input_value_id
       AND peevf.element_entry_id = peef.element_entry_id
       AND peef.effective_start_date BETWEEN peevf.effective_start_date AND peevf.effective_end_date
       AND UPPER(pivf.NAME) = 'FECHA'
	   AND peef.assignment_id  = paaf.assignment_id
	   AND paaf.period_of_service_id = ppos.period_of_service_id
	   AND NVL(ppos.actual_termination_date,trunc(g_cut_off_date)) between paaf.effective_start_date and paaf.effective_end_date;
   IF (v_incidence_date_char IS NULL) THEN
      v_incidence_date := r_emp_data.incidence_date;
   ELSE
      v_incidence_date := TO_DATE(SUBSTR(v_incidence_date_char,1,10),'YYYY/MM/DD');
   END IF;
   EXCEPTION WHEN OTHERS THEN
         v_incidence_date := r_emp_data.incidence_date;
  END;
-- Ken Mod 8/18/05 to overide incidence_date field with screen_entry_value of input value name Fecha, ending...
 	r_interface_mst.employee_id	         := r_emp_data.employee_id;
	r_interface_mst.period_ordinal		 := r_emp_data.period_ordinal;
-- Ken Mod 8/18/05 to overide incidence_date field with screen_entry_value of input value name Fecha
--      r_interface_mst.incidence_date		 := r_emp_data.incidence_date;
        r_interface_mst.incidence_date           := v_incidence_date;
	r_interface_mst.payroll_payment_date	 := r_emp_data.payroll_payment_date;
	r_interface_mst.cost_center		 := r_emp_data.cost_center;
	r_interface_mst.payment_type_code	 := r_emp_data.payment_type_code;
	r_interface_mst.payment_type_value	 := r_emp_data.payment_type_value;
	r_interface_mst.ElementName		 := r_emp_data.ElementName;
	r_interface_mst.InputName		 := r_emp_data.InputName;
	r_interface_mst.person_creation_date	 := r_emp_data.person_creation_date;
        r_interface_mst.person_update_date	 := r_emp_data.person_update_date;
        r_interface_mst.assignment_id		 := r_emp_data.assignment_id;
        r_interface_mst.assignment_creation_date := r_emp_data.assignment_creation_date;
        r_interface_mst.assignment_update_date   := r_emp_data.assignment_update_date;
        r_interface_mst.person_id		 := r_emp_data.person_id;
        r_interface_mst.person_type_id		 := r_emp_data.person_type_id;
        r_interface_mst.system_person_type	 := r_emp_data.system_person_type;
        r_interface_mst.user_person_type	 := r_emp_data.user_person_type;
        r_interface_mst.creation_date            := g_cut_off_date;
        r_interface_mst.last_extract_date        := SYSDATE;
        r_interface_mst.last_extract_file_type   :=' CIN';
        r_interface_mst.cut_off_date		 := g_cut_off_date;
	r_interface_mst.ass_effective_st_dt	 := r_emp_data.ass_effective_st_dt;
	r_interface_mst.BG_ID                    := r_emp_data.BG_ID ;
	r_interface_mst.EntryEffectiveStartDate  := r_emp_data.incidence_date;
	r_interface_mst.EntryEffectiveEndDate    := r_emp_data.payroll_payment_date;
	r_interface_mst.IncidenceID              := NULL;
	r_interface_mst.AbsenceStartDate         := NULL;
	r_interface_mst.AbsenceEndDate           := NULL;
	r_interface_mst.RelapseDate              := NULL;
	r_interface_mst.TipoUnidad               := NULL;
	r_interface_mst.Unidad                   := NULL;
	r_interface_mst.OracleEmployeeId         := r_emp_data.OracleEmployeeId;
        r_interface_mst.peef_element_entry_id    := r_emp_data.peef_element_entry_id;
insert_interface_mst(ir_interface_mst     => r_interface_mst);
  END LOOP;  -- c_emp_data
  FOR r_emp_data IN  c_emp_absence LOOP
  BEGIN
     SELECT F.SCREEN_ENTRY_VALUE
       INTO AbsenceStartDate
       FROM PAY_ELEMENT_TYPES_F A,
	    PAY_ELEMENT_ENTRIES_F B,
	    PAY_INPUT_VALUES_F C,
	    PER_ALL_ASSIGNMENTS_F D,
	    PER_ALL_PEOPLE_F E,
	    PAY_ELEMENT_ENTRY_VALUES_F F
      WHERE A.ELEMENT_NAME = LTRIM(RTRIM(r_emp_data.ElementName))
	AND         TRUNC(g_cut_off_date)  BETWEEN a.effective_start_date AND a.effective_end_date
	AND         TRUNC(g_cut_off_date)  BETWEEN b.effective_start_date AND b.effective_end_date
	AND        B.ELEMENT_TYPE_ID = A.ELEMENT_TYPE_ID
	AND        A.ELEMENT_TYPE_ID = C.ELEMENT_TYPE_ID
-- Ken Mod 8/22/05 bug fix to pull override data based on peef.element_entry_id (without it, multiple rows may return and go to exception)
        AND B.element_entry_id = r_emp_data.peef_element_entry_id
	AND       TRUNC(g_cut_off_date)  BETWEEN C.effective_start_date AND C.effective_end_date
--	AND       UPPER(C.NAME) =  'FECHA INICIO'
-- Ken Mod 7/19/05 inclucd fecha de incio
        AND       UPPER(C.NAME) IN ( 'FECHA INICIO', 'FECHA DE INICIO')
	AND       B.ASSIGNMENT_ID = D.ASSIGNMENT_ID
	AND       D.PRIMARY_FLAG = 'Y'
	AND		  D.ASSIGNMENT_ID = r_emp_data.assignment_id
	AND       B.EFFECTIVE_START_DATE  BETWEEN D.effective_start_date AND D.effective_end_date
	AND       E.PERSON_ID = D.PERSON_ID
	AND       E.EMPLOYEE_NUMBER  = LTRIM(RTRIM(r_emp_data.OracleEmployeeID))
	AND       TRUNC(g_cut_off_date)  BETWEEN E.effective_start_date AND E.effective_end_date
	AND       TRUNC(g_cut_off_date)  BETWEEN F.effective_start_date AND F.effective_end_date
	AND       F.INPUT_VALUE_ID = C.INPUT_VALUE_ID
	AND       F.ELEMENT_ENTRY_ID = B.ELEMENT_ENTRY_ID;
   EXCEPTION WHEN OTHERS THEN
         AbsenceStartDate := NULL;
  END;
 BEGIN
   SELECT F.SCREEN_ENTRY_VALUE
     INTO AbsenceEndDate
     FROM PAY_ELEMENT_TYPES_F A,
	  PAY_ELEMENT_ENTRIES_F B,
	  PAY_INPUT_VALUES_F C,
	  PER_ALL_ASSIGNMENTS_F D,
	  PER_ALL_PEOPLE_F E,
	  PAY_ELEMENT_ENTRY_VALUES_F F
	WHERE  A.ELEMENT_NAME = r_emp_data.ElementName
	AND         TRUNC(g_cut_off_date)  BETWEEN a.effective_start_date AND a.effective_end_date
	AND         TRUNC(g_cut_off_date)  BETWEEN b.effective_start_date AND b.effective_end_date
	AND        B.ELEMENT_TYPE_ID = A.ELEMENT_TYPE_ID
	AND        A.ELEMENT_TYPE_ID = C.ELEMENT_TYPE_ID
-- Ken Mod 8/22/05 bug fix to pull override data based on peef.element_entry_id (without it, multiple rows may return and go to exception)
        AND B.element_entry_id = r_emp_data.peef_element_entry_id
	AND       TRUNC(g_cut_off_date)  BETWEEN C.effective_start_date AND C.effective_end_date
	AND       UPPER(C.NAME) =  'FECHA FIN'
	AND       B.ASSIGNMENT_ID = D.ASSIGNMENT_ID
	AND       D.PRIMARY_FLAG = 'Y'
	AND		  D.ASSIGNMENT_ID = r_emp_data.assignment_id
	AND       B.EFFECTIVE_START_DATE  BETWEEN D.effective_start_date AND D.effective_end_date
	AND       E.PERSON_ID = D.PERSON_ID
	AND       E.EMPLOYEE_NUMBER  = r_emp_data.OracleEmployeeID
	AND       TRUNC(g_cut_off_date)  BETWEEN E.effective_start_date AND E.effective_end_date
	AND         TRUNC(g_cut_off_date)  BETWEEN F.effective_start_date AND F.effective_end_date
	AND       F.INPUT_VALUE_ID = C.INPUT_VALUE_ID
	AND       F.ELEMENT_ENTRY_ID = B.ELEMENT_ENTRY_ID;
   EXCEPTION WHEN OTHERS THEN
       AbsenceEndDate := NULL;
   END;
   BEGIN
      SELECT F.SCREEN_ENTRY_VALUE
        INTO v_RelapseDate
	FROM PAY_ELEMENT_TYPES_F A,
	     PAY_ELEMENT_ENTRIES_F B,
	     PAY_INPUT_VALUES_F C,
	     PER_ALL_ASSIGNMENTS_F D,
	     PER_ALL_PEOPLE_F E,
	     PAY_ELEMENT_ENTRY_VALUES_F F
       WHERE A.ELEMENT_NAME = r_emp_data.ElementName
	AND       TRUNC(g_cut_off_date)  BETWEEN a.effective_start_date AND a.effective_end_date
	AND       TRUNC(g_cut_off_date)  BETWEEN b.effective_start_date AND b.effective_end_date
	AND       B.ELEMENT_TYPE_ID = A.ELEMENT_TYPE_ID
	AND       A.ELEMENT_TYPE_ID = C.ELEMENT_TYPE_ID
-- Ken Mod 8/22/05 bug fix to pull override data based on peef.element_entry_id (without it, multiple rows may return and go to exception)
        AND B.element_entry_id = r_emp_data.peef_element_entry_id
	AND       TRUNC(g_cut_off_date)  BETWEEN C.effective_start_date AND C.effective_end_date
	AND       C.NAME =  'Fecha Reca¿'
	AND       B.ASSIGNMENT_ID = D.ASSIGNMENT_ID
	AND       D.PRIMARY_FLAG = 'Y'
	AND	  D.ASSIGNMENT_ID = r_emp_data.assignment_id
	AND       B.EFFECTIVE_START_DATE  BETWEEN D.effective_start_date AND D.effective_end_date
	AND       E.PERSON_ID = D.PERSON_ID
	AND       E.EMPLOYEE_NUMBER  = r_emp_data.OracleEmployeeID
	AND       TRUNC(g_cut_off_date)  BETWEEN E.effective_start_date AND E.effective_end_date
	AND       TRUNC(g_cut_off_date)  BETWEEN F.effective_start_date AND F.effective_end_date
	AND       F.INPUT_VALUE_ID = C.INPUT_VALUE_ID
	AND       F.ELEMENT_ENTRY_ID = B.ELEMENT_ENTRY_ID;
     EXCEPTION WHEN OTHERS THEN
          v_RelapseDate := NULL;
   END;
   BEGIN
      SELECT F.SCREEN_ENTRY_VALUE
       INTO  v_TipoUnidad
       FROM PAY_ELEMENT_TYPES_F A,
            PAY_ELEMENT_ENTRIES_F B,
	    PAY_INPUT_VALUES_F C,
	    PER_ALL_ASSIGNMENTS_F D,
	    PER_ALL_PEOPLE_F E,
	    PAY_ELEMENT_ENTRY_VALUES_F F
      WHERE A.ELEMENT_NAME = r_emp_data.ElementName
	AND       TRUNC(g_cut_off_date)  BETWEEN a.effective_start_date AND a.effective_end_date
	AND       TRUNC(g_cut_off_date)  BETWEEN b.effective_start_date AND b.effective_end_date
	AND       B.ELEMENT_TYPE_ID = A.ELEMENT_TYPE_ID
	AND       A.ELEMENT_TYPE_ID = C.ELEMENT_TYPE_ID
-- Ken Mod 8/22/05 bug fix to pull override data based on peef.element_entry_id (without it, multiple rows may return and go to exception)
        AND B.element_entry_id = r_emp_data.peef_element_entry_id
	AND       TRUNC(g_cut_off_date)  BETWEEN C.effective_start_date AND C.effective_end_date
	AND       C.NAME =  'Tipo Unidad'
	AND       B.ASSIGNMENT_ID = D.ASSIGNMENT_ID
	AND       D.PRIMARY_FLAG = 'Y'
	AND	  D.ASSIGNMENT_ID = r_emp_data.assignment_id
	AND       B.EFFECTIVE_START_DATE  BETWEEN D.effective_start_date AND D.effective_end_date
	AND       E.PERSON_ID = D.PERSON_ID
	AND       E.EMPLOYEE_NUMBER  = r_emp_data.OracleEmployeeID
	AND       TRUNC(g_cut_off_date)  BETWEEN E.effective_start_date AND E.effective_end_date
	AND       TRUNC(g_cut_off_date)  BETWEEN F.effective_start_date AND F.effective_end_date
	AND       F.INPUT_VALUE_ID = C.INPUT_VALUE_ID
	AND       F.ELEMENT_ENTRY_ID = B.ELEMENT_ENTRY_ID;
   EXCEPTION WHEN OTHERS THEN
        v_TipoUnidad := NULL;
   END;
   BEGIN
      SELECT F.SCREEN_ENTRY_VALUE
	INTO v_Unidad
	FROM PAY_ELEMENT_TYPES_F A,
	     PAY_ELEMENT_ENTRIES_F B,
	     PAY_INPUT_VALUES_F C,
	     PER_ALL_ASSIGNMENTS_F D,
	     PER_ALL_PEOPLE_F E,
	     PAY_ELEMENT_ENTRY_VALUES_F F
       WHERE A.ELEMENT_NAME = r_emp_data.ElementName
	AND       TRUNC(g_cut_off_date)  BETWEEN a.effective_start_date AND a.effective_end_date
	AND       TRUNC(g_cut_off_date)  BETWEEN b.effective_start_date AND b.effective_end_date
	AND       B.ELEMENT_TYPE_ID = A.ELEMENT_TYPE_ID
	AND       A.ELEMENT_TYPE_ID = C.ELEMENT_TYPE_ID
-- Ken Mod 8/22/05 bug fix to pull override data based on peef.element_entry_id (without it, multiple rows may return and go to exception)
        AND B.element_entry_id = r_emp_data.peef_element_entry_id
	AND       TRUNC(g_cut_off_date)  BETWEEN C.effective_start_date AND C.effective_end_date
	AND       C.NAME =  'Unidad'
	AND       B.ASSIGNMENT_ID = D.ASSIGNMENT_ID
	AND       D.PRIMARY_FLAG = 'Y'
	AND	  D.ASSIGNMENT_ID = r_emp_data.assignment_id
	AND       B.EFFECTIVE_START_DATE  BETWEEN D.effective_start_date AND D.effective_end_date
	AND       E.PERSON_ID = D.PERSON_ID
	AND       E.EMPLOYEE_NUMBER  = r_emp_data.OracleEmployeeID
	AND       TRUNC(g_cut_off_date)  BETWEEN E.effective_start_date AND E.effective_end_date
	AND       TRUNC(g_cut_off_date)  BETWEEN F.effective_start_date AND F.effective_end_date
	AND       F.INPUT_VALUE_ID = C.INPUT_VALUE_ID
	AND       F.ELEMENT_ENTRY_ID = B.ELEMENT_ENTRY_ID;
   EXCEPTION WHEN OTHERS THEN
        v_Unidad := NULL;
   END;
  -- Fnd_File.put_line(Fnd_File.LOG, 'test' || AbsenceStartDate );
  -- Fnd_File.put_line(Fnd_File.LOG, 'test1' || TO_CHAR(AbsenceEndDate ,'dd-mon-yyyy') );
    r_interface_mst.employee_id		          := r_emp_data.employee_id;
    r_interface_mst.period_ordinal		  := r_emp_data.period_ordinal;
    r_interface_mst.incidence_date	          := r_emp_data.incidence_date;
    r_interface_mst.payroll_payment_date          := r_emp_data.payroll_payment_date;
    r_interface_mst.cost_center			  := r_emp_data.cost_center;
    r_interface_mst.payment_type_code		  := r_emp_data.payment_type_code;
    r_interface_mst.payment_type_value		  := r_emp_data.payment_type_value;
    r_interface_mst.ElementName			  := r_emp_data.ElementName;
    r_interface_mst.InputName			  := r_emp_data.InputName;
    r_interface_mst.person_creation_date	  := r_emp_data.person_creation_date;
    r_interface_mst.person_update_date		  := r_emp_data.person_update_date;
    r_interface_mst.assignment_id		  := r_emp_data.assignment_id;
    r_interface_mst.assignment_creation_date      := r_emp_data.assignment_creation_date;
    r_interface_mst.assignment_update_date        := r_emp_data.assignment_update_date;
    r_interface_mst.person_id			  := r_emp_data.person_id;
    r_interface_mst.person_type_id		  := r_emp_data.person_type_id;
    r_interface_mst.system_person_type		  := r_emp_data.system_person_type;
    r_interface_mst.user_person_type		  := r_emp_data.user_person_type;
    r_interface_mst.creation_date                 := g_cut_off_date;
    r_interface_mst.last_extract_date             := SYSDATE;
    r_interface_mst.last_extract_file_type        :=' NAUS';
    r_interface_mst.cut_off_date		  := g_cut_off_date;
    r_interface_mst.ass_effective_st_dt		  := r_emp_data.ass_effective_st_dt;
    r_interface_mst.BG_ID                         := r_emp_data.BG_ID ;
    r_interface_mst.EntryEffectiveStartDate       := r_emp_data.EntryEffectiveStartDate;
    r_interface_mst.EntryEffectiveEndDate         := r_emp_data.EntryEffectiveEndDate;
    r_interface_mst.IncidenceID                   := r_emp_data.IncidenceID;
    r_interface_mst.AbsenceStartDate              := TO_DATE(SUBSTR(AbsenceStartDate,1,10),'yyyy/mm/dd');
    r_interface_mst.AbsenceEndDate                := TO_DATE(SUBSTR(AbsenceEndDate,1,10),'yyyy/mm/dd');
    r_interface_mst.RelapseDate                   := TO_DATE(SUBSTR(v_RelapseDate,1,10),'yyyy/mm/dd');
    r_interface_mst.TipoUnidad                    := v_TipoUnidad;
    r_interface_mst.Unidad                        := v_Unidad;
    r_interface_mst.OracleEmployeeId              := r_emp_data.OracleEmployeeId;
    r_interface_mst.peef_element_entry_id         := r_emp_data.peef_element_entry_id;
insert_interface_mst(ir_interface_mst     => r_interface_mst);
  END LOOP;  -- c_emp_data
  --FOR  x  IN  c_emp_absence
  FOR  x  IN  c_emp_baus
  LOOP
     FOR    r_emp_data  IN  c_emp_absence_baus ( x.Person_ID ,
                                                 x.ElementName,
				                 x.assignment_id,
					         x.cut_off_date)
					     --  x.input_value_id )
	LOOP
          BEGIN
             SELECT F.SCREEN_ENTRY_VALUE
	       INTO AbsenceStartDate
               FROM PAY_ELEMENT_TYPES_F A,
		    PAY_ELEMENT_ENTRIES_F B,
		    PAY_INPUT_VALUES_F C,
		    PER_ALL_ASSIGNMENTS_F D,
		    PER_ALL_PEOPLE_F E,
		    PAY_ELEMENT_ENTRY_VALUES_F F
	      WHERE A.ELEMENT_NAME = r_emp_data.ElementName
		AND       TRUNC(g_cut_off_date)  BETWEEN a.effective_start_date AND a.effective_end_date
		AND       b.effective_end_date  = TRUNC(r_emp_data.EntryEffectiveEndDate)
		AND       b.effective_start_date  = TRUNC(r_emp_data.EntryEffectiveStartDate)
		AND       B.ELEMENT_TYPE_ID = A.ELEMENT_TYPE_ID
		AND       A.ELEMENT_TYPE_ID = C.ELEMENT_TYPE_ID
-- Ken Mod 8/22/05 bug fix to pull override data based on peef.element_entry_id (without it, multiple rows may return and go to exception)
        AND B.element_entry_id = r_emp_data.peef_element_entry_id
		AND       TRUNC(g_cut_off_date)  BETWEEN C.effective_start_date AND C.effective_end_date
	-- 	AND       UPPER(C.NAME) =  'FECHA INICIO'
        -- Ken Mod 7/19/05 inclucd fecha de incio
                AND       UPPER(C.NAME) IN ( 'FECHA INICIO', 'FECHA DE INICIO')
		AND       B.ASSIGNMENT_ID = D.ASSIGNMENT_ID
		AND       D.PRIMARY_FLAG = 'Y'
		AND	  D.ASSIGNMENT_ID = r_emp_data.assignment_id
		AND       B.EFFECTIVE_START_DATE  BETWEEN D.effective_start_date AND D.effective_end_date
		AND       E.PERSON_ID = D.PERSON_ID
		AND       E.EMPLOYEE_NUMBER  = r_emp_data.OracleEmployeeID
		AND       TRUNC(g_cut_off_date)  BETWEEN E.effective_start_date AND E.effective_end_date
                AND       TRUNC(b.effective_start_date)  BETWEEN F.effective_start_date AND F.effective_end_date
		AND       F.INPUT_VALUE_ID = C.INPUT_VALUE_ID
		AND       F.ELEMENT_ENTRY_ID = B.ELEMENT_ENTRY_ID;
	   EXCEPTION WHEN OTHERS THEN
               AbsenceStartDate := NULL;
	  END;
         BEGIN
            SELECT F.SCREEN_ENTRY_VALUE
              INTO AbsenceEndDate
	      FROM PAY_ELEMENT_TYPES_F A,
		   PAY_ELEMENT_ENTRIES_F B,
		   PAY_INPUT_VALUES_F C,
		   PER_ALL_ASSIGNMENTS_F D,
		   PER_ALL_PEOPLE_F E,
		   PAY_ELEMENT_ENTRY_VALUES_F F
             WHERE A.ELEMENT_NAME = r_emp_data.ElementName
	       AND         TRUNC(g_cut_off_date)  BETWEEN a.effective_start_date AND a.effective_end_date
		AND         b.effective_end_date  = TRUNC(r_emp_data.EntryEffectiveEndDate)
		AND         b.effective_start_date  = TRUNC(r_emp_data.EntryEffectiveStartDate)
		AND        B.ELEMENT_TYPE_ID = A.ELEMENT_TYPE_ID
		AND        A.ELEMENT_TYPE_ID = C.ELEMENT_TYPE_ID
-- Ken Mod 8/22/05 bug fix to pull override data based on peef.element_entry_id (without it, multiple rows may return and go to exception)
        AND B.element_entry_id = r_emp_data.peef_element_entry_id
		AND       TRUNC(g_cut_off_date)  BETWEEN C.effective_start_date AND C.effective_end_date
		AND       UPPER(C.NAME) =  'FECHA FIN'
		AND       B.ASSIGNMENT_ID = D.ASSIGNMENT_ID
		AND       D.PRIMARY_FLAG = 'Y'
		AND		  D.ASSIGNMENT_ID = r_emp_data.assignment_id
		AND       B.EFFECTIVE_START_DATE  BETWEEN D.effective_start_date AND D.effective_end_date
		AND       E.PERSON_ID = D.PERSON_ID
		AND       E.EMPLOYEE_NUMBER  = r_emp_data.OracleEmployeeID
		AND       TRUNC(g_cut_off_date)  BETWEEN E.effective_start_date AND E.effective_end_date
		AND       TRUNC(b.effective_start_date)  BETWEEN F.effective_start_date AND F.effective_end_date
		AND       F.INPUT_VALUE_ID = C.INPUT_VALUE_ID
		AND       F.ELEMENT_ENTRY_ID = B.ELEMENT_ENTRY_ID;
       EXCEPTION WHEN OTHERS THEN
               AbsenceEndDate := NULL;
       END;
       BEGIN
          SELECT F.SCREEN_ENTRY_VALUE
	    INTO v_RelapseDate
            FROM PAY_ELEMENT_TYPES_F A,
		 PAY_ELEMENT_ENTRIES_F B,
		 PAY_INPUT_VALUES_F C,
		 PER_ALL_ASSIGNMENTS_F D,
		 PER_ALL_PEOPLE_F E,
		 PAY_ELEMENT_ENTRY_VALUES_F F
           WHERE A.ELEMENT_NAME = r_emp_data.ElementName
	     AND       TRUNC(g_cut_off_date)  BETWEEN a.effective_start_date AND a.effective_end_date
	     AND       TRUNC(g_cut_off_date)  BETWEEN b.effective_start_date AND b.effective_end_date
	     AND       B.ELEMENT_TYPE_ID = A.ELEMENT_TYPE_ID
	     AND       A.ELEMENT_TYPE_ID = C.ELEMENT_TYPE_ID
-- Ken Mod 8/22/05 bug fix to pull override data based on peef.element_entry_id (without it, multiple rows may return and go to exception)
        AND B.element_entry_id = r_emp_data.peef_element_entry_id
	     AND       TRUNC(g_cut_off_date)  BETWEEN C.effective_start_date AND C.effective_end_date
	     AND       C.NAME =  'Fecha Reca¿'
	     AND       B.ASSIGNMENT_ID = D.ASSIGNMENT_ID
	     AND       D.PRIMARY_FLAG = 'Y'
	     AND       D.ASSIGNMENT_ID = r_emp_data.assignment_id
	     AND       B.EFFECTIVE_START_DATE  BETWEEN D.effective_start_date AND D.effective_end_date
	     AND       E.PERSON_ID = D.PERSON_ID
	     AND       E.EMPLOYEE_NUMBER  = r_emp_data.OracleEmployeeID
	     AND       TRUNC(g_cut_off_date)  BETWEEN E.effective_start_date AND E.effective_end_date
	     AND       TRUNC(g_cut_off_date)  BETWEEN F.effective_start_date AND F.effective_end_date
	     AND       F.INPUT_VALUE_ID = C.INPUT_VALUE_ID
	     AND       F.ELEMENT_ENTRY_ID = B.ELEMENT_ENTRY_ID;
       EXCEPTION WHEN OTHERS THEN
               v_RelapseDate := NULL;
       END;
       BEGIN
          SELECT F.SCREEN_ENTRY_VALUE
            INTO v_TipoUnidad
            FROM PAY_ELEMENT_TYPES_F A,
		 PAY_ELEMENT_ENTRIES_F B,
		 PAY_INPUT_VALUES_F C,
		 PER_ALL_ASSIGNMENTS_F D,
		 PER_ALL_PEOPLE_F E,
		 PAY_ELEMENT_ENTRY_VALUES_F F
           WHERE A.ELEMENT_NAME = r_emp_data.ElementName
             AND       TRUNC(g_cut_off_date)  BETWEEN a.effective_start_date AND a.effective_end_date
	     AND       TRUNC(g_cut_off_date)  BETWEEN b.effective_start_date AND b.effective_end_date
	     AND       B.ELEMENT_TYPE_ID = A.ELEMENT_TYPE_ID
	     AND       A.ELEMENT_TYPE_ID = C.ELEMENT_TYPE_ID
-- Ken Mod 8/22/05 bug fix to pull override data based on peef.element_entry_id (without it, multiple rows may return and go to exception)
        AND B.element_entry_id = r_emp_data.peef_element_entry_id
	     AND       TRUNC(g_cut_off_date)  BETWEEN C.effective_start_date AND C.effective_end_date
	     AND       C.NAME =  'Tipo Unidad'
	     AND       B.ASSIGNMENT_ID = D.ASSIGNMENT_ID
	     AND       D.PRIMARY_FLAG = 'Y'
	     AND       D.ASSIGNMENT_ID = r_emp_data.assignment_id
	     AND       B.EFFECTIVE_START_DATE  BETWEEN D.effective_start_date AND D.effective_end_date
	     AND       E.PERSON_ID = D.PERSON_ID
	     AND       E.EMPLOYEE_NUMBER  = r_emp_data.OracleEmployeeID
	     AND       TRUNC(g_cut_off_date)  BETWEEN E.effective_start_date AND E.effective_end_date
	     AND       TRUNC(g_cut_off_date)  BETWEEN F.effective_start_date AND F.effective_end_date
	     AND       F.INPUT_VALUE_ID = C.INPUT_VALUE_ID
	     AND       F.ELEMENT_ENTRY_ID = B.ELEMENT_ENTRY_ID;
	 EXCEPTION WHEN OTHERS THEN
               v_TipoUnidad := NULL;
         END;
        BEGIN
           SELECT F.SCREEN_ENTRY_VALUE
             INTO v_Unidad
             FROM PAY_ELEMENT_TYPES_F A,
		  PAY_ELEMENT_ENTRIES_F B,
		  PAY_INPUT_VALUES_F C,
		  PER_ALL_ASSIGNMENTS_F D,
		  PER_ALL_PEOPLE_F E,
		  PAY_ELEMENT_ENTRY_VALUES_F F
            WHERE A.ELEMENT_NAME = r_emp_data.ElementName
	      AND       TRUNC(g_cut_off_date)  BETWEEN a.effective_start_date AND a.effective_end_date
	      AND       TRUNC(g_cut_off_date)  BETWEEN b.effective_start_date AND b.effective_end_date
	      AND       B.ELEMENT_TYPE_ID = A.ELEMENT_TYPE_ID
	      AND       A.ELEMENT_TYPE_ID = C.ELEMENT_TYPE_ID
-- Ken Mod 8/22/05 bug fix to pull override data based on peef.element_entry_id (without it, multiple rows may return and go to exception)
        AND B.element_entry_id = r_emp_data.peef_element_entry_id
	      AND       TRUNC(g_cut_off_date)  BETWEEN C.effective_start_date AND C.effective_end_date
              AND       C.NAME =  'Unidad'
	      AND       B.ASSIGNMENT_ID = D.ASSIGNMENT_ID
	      AND       D.PRIMARY_FLAG = 'Y'
	      AND       D.ASSIGNMENT_ID = r_emp_data.assignment_id
	      AND       B.EFFECTIVE_START_DATE  BETWEEN D.effective_start_date AND D.effective_end_date
	      AND       E.PERSON_ID = D.PERSON_ID
	      AND       E.EMPLOYEE_NUMBER  = r_emp_data.OracleEmployeeID
	      AND       TRUNC(g_cut_off_date)  BETWEEN E.effective_start_date AND E.effective_end_date
	      AND       TRUNC(g_cut_off_date)  BETWEEN F.effective_start_date AND F.effective_end_date
	      AND       F.INPUT_VALUE_ID = C.INPUT_VALUE_ID
	      AND       F.ELEMENT_ENTRY_ID = B.ELEMENT_ENTRY_ID;
	 EXCEPTION WHEN OTHERS THEN
	          v_Unidad := NULL;
	 END;
	r_interface_mst.employee_id		  := r_emp_data.employee_id;
	r_interface_mst.period_ordinal		  := r_emp_data.period_ordinal;
	r_interface_mst.incidence_date		  := r_emp_data.incidence_date;
	r_interface_mst.payroll_payment_date	  := r_emp_data.payroll_payment_date;
	r_interface_mst.cost_center		  := r_emp_data.cost_center;
	r_interface_mst.payment_type_code	  := r_emp_data.payment_type_code;
	r_interface_mst.payment_type_value	  := r_emp_data.payment_type_value;
	r_interface_mst.ElementName		  := r_emp_data.ElementName;
	r_interface_mst.InputName		  := r_emp_data.InputName;
	r_interface_mst.person_creation_date	  := r_emp_data.person_creation_date;
        r_interface_mst.person_update_date	  := r_emp_data.person_update_date;
        r_interface_mst.assignment_id		  := r_emp_data.assignment_id;
        r_interface_mst.assignment_creation_date  := r_emp_data.assignment_creation_date;
        r_interface_mst.assignment_update_date    := r_emp_data.assignment_update_date;
        r_interface_mst.person_id		  := r_emp_data.person_id;
        r_interface_mst.person_type_id		  := r_emp_data.person_type_id;
        r_interface_mst.system_person_type	  := r_emp_data.system_person_type;
        r_interface_mst.user_person_type	  := r_emp_data.user_person_type;
        r_interface_mst.creation_date             := g_cut_off_date;
        r_interface_mst.last_extract_date         := SYSDATE;
        r_interface_mst.last_extract_file_type    :=' BAUS';
        r_interface_mst.cut_off_date		  := g_cut_off_date;
	r_interface_mst.ass_effective_st_dt	  := r_emp_data.ass_effective_st_dt;
	r_interface_mst.BG_ID                     := r_emp_data.BG_ID ;
	r_interface_mst.EntryEffectiveStartDate   := r_emp_data.EntryEffectiveStartDate;
	r_interface_mst.EntryEffectiveEndDate     := r_emp_data.EntryEffectiveEndDate;
	r_interface_mst.IncidenceID               := r_emp_data.IncidenceID;
	r_interface_mst.AbsenceStartDate          := TO_DATE(SUBSTR(AbsenceStartDate,1,10),'yyyy/mm/dd');
	r_interface_mst.AbsenceEndDate            := TO_DATE(SUBSTR(AbsenceEndDate,1,10),'yyyy/mm/dd');
	r_interface_mst.RelapseDate               := TO_DATE(SUBSTR(v_RelapseDate,1,10),'yyyy/mm/dd');
	r_interface_mst.TipoUnidad                := v_TipoUnidad;
	r_interface_mst.Unidad                    := v_Unidad;
	r_interface_mst.OracleEmployeeId          := r_emp_data.OracleEmployeeId;
        r_interface_mst.peef_element_entry_id     := r_emp_data.peef_element_entry_id;
	insert_interface_mst(ir_interface_mst     => r_interface_mst);
         END LOOP;  -- c_emp_absence_baus
  END LOOP; -- c_emp_baus
-- BBB starting.. Ken Mod 7/25/05 to pull data term and final processed on or before today (interface run sysdate)
FOR r_pps_emp_data IN c_pps_emp_data LOOP
    v_term_his                     := NULL;
    v_papf_effective_start_date    := NULL;
    v_papf_effective_end_date      := NULL;
    v_paaf_assignment_id           := NULL;
    v_paaf_effective_start_date    := NULL;
    v_paaf_effective_end_date      := NULL;
    v_PERIOD_OF_SERVICE_ID         := NULL;
    v_ACTUAL_TERMINATION_DATE      := NULL;
    v_FINAL_PROCESS_DATE           := NULL;
    v_LEAVING_REASON               := NULL;
    v_date_start                   := NULL;
    Record_Changed_term_his_x
                            (r_pps_emp_data.person_id,
                             v_extract_date,           -- is sysdate value retrived at program execution
                             v_papf_effective_start_date,
                             v_papf_effective_end_date,
                             v_paaf_assignment_id,
                             v_paaf_effective_start_date,
                             v_paaf_effective_end_date,
                             v_PERIOD_OF_SERVICE_ID,
                             v_ACTUAL_TERMINATION_DATE,
                             v_FINAL_PROCESS_DATE,
                             v_LEAVING_REASON,
                             v_date_start,
                             v_term_his);
     IF (v_term_his = 'Y' OR v_term_his = 'X') THEN   -- first
     -- to pull EX_EMP record in cust.ttec_spain_pay_interface_mst table
     -- for term and rehired and final processed on or before today, the above table will have 2 records with same cut_off_date (EMP and EX_EMP)
     -- EMP rec from c_emp_data cursor, EX_EMP rec from c_term_his_emp_data  cursor
     --  Fnd_File.put_line(Fnd_File.LOG,'FIND TERM HIS loc=100 person_id=' || r_pps_emp_data.person_id  );         -- delete_later
    FOR r_emp_data IN c_emp_data_term (r_pps_emp_data.person_id,
                                              v_papf_effective_start_date,
                                              v_papf_effective_end_date,
                                              v_paaf_effective_start_date,
                                              v_paaf_effective_end_date,
                                              v_date_start,
                                              v_paaf_assignment_id ) LOOP
-- Ken Mod 8/18/05 to overide incidence_date field with screen_entry_value of input value name Fecha, starting...
-- NOTICE 2 lines of  v_paaf_effective_end_date in WHERE clause...
      v_incidence_date_char := NULL;
  BEGIN
/*-- Commented out by C. Chan on 8/4/2006 for WO#212636
    SELECT peevf.screen_entry_value
      INTO v_incidence_date_char
      FROM
           pay_element_entries_f         peef
          ,pay_element_types_f           petf
          ,pay_input_values_f            pivf
          ,pay_element_entry_values_f    peevf
     WHERE
           peef.assignment_id = r_emp_data.assignment_id
--     AND TRUNC(g_cut_off_date) BETWEEN peef.effective_start_date AND peef.effective_end_date
       AND TRUNC(peef.effective_end_date) = TRUNC(v_paaf_effective_end_date)      -- for historical term
       AND peef.element_type_id = petf.element_type_id
       AND peef.element_entry_id = r_emp_data.peef_element_entry_id
       AND peef.effective_start_date BETWEEN petf.effective_start_date AND petf.effective_end_date
       AND petf.element_name = r_emp_data.ElementName
       AND pivf.element_type_id = petf.element_type_id
       AND petf.effective_start_date BETWEEN pivf.effective_start_date AND pivf.effective_end_date
       AND peevf.input_value_id = pivf.input_value_id
       AND peevf.element_entry_id = peef.element_entry_id
--     AND peef.effective_start_date BETWEEN peevf.effective_start_date AND peevf.effective_end_date
-- Commented out by C. Chan on 8/4/2006 for WO#212636
       AND TRUNC(peevf.effective_end_date) = TRUNC(v_paaf_effective_end_date)  -- for historical term
       AND UPPER(pivf.NAME) = 'FECHA';
*/
    --
	-- added by C.Chan on 8/4/2006 for WO#212636
	--
    SELECT peevf.screen_entry_value
      INTO v_incidence_date_char
      FROM
           pay_element_entries_f         peef
          ,pay_element_types_f           petf
          ,pay_input_values_f            pivf
          ,pay_element_entry_values_f    peevf
		  ,per_all_assignments_f          paaf
		  ,per_periods_of_service        ppos
     WHERE
           peef.assignment_id = r_emp_data.assignment_id
--       AND TRUNC(g_cut_off_date) BETWEEN peef.effective_start_date AND peef.effective_end_date
       AND NVL(ppos.actual_termination_date,trunc(g_cut_off_date)) BETWEEN peef.effective_start_date AND peef.effective_end_date
       AND peef.element_type_id = petf.element_type_id
       AND peef.element_entry_id = r_emp_data.peef_element_entry_id
       AND peef.effective_start_date BETWEEN petf.effective_start_date AND petf.effective_end_date
       AND petf.element_name = r_emp_data.ElementName
       AND pivf.element_type_id = petf.element_type_id
       AND petf.effective_start_date BETWEEN pivf.effective_start_date AND pivf.effective_end_date
       AND peevf.input_value_id = pivf.input_value_id
       AND peevf.element_entry_id = peef.element_entry_id
       AND peef.effective_start_date BETWEEN peevf.effective_start_date AND peevf.effective_end_date
       AND UPPER(pivf.NAME) = 'FECHA'
	   AND peef.assignment_id  = paaf.assignment_id
	   AND paaf.period_of_service_id = ppos.period_of_service_id
	   AND NVL(ppos.actual_termination_date,trunc(g_cut_off_date)) between paaf.effective_start_date and paaf.effective_end_date;
   IF (v_incidence_date_char IS NULL) THEN
      v_incidence_date := r_emp_data.incidence_date;
 -- Fnd_File.put_line(Fnd_File.LOG,'FIND TERM HIS ***** found date =' || v_incidence_date  );
   ELSE
      v_incidence_date := TO_DATE(SUBSTR(v_incidence_date_char,1,10),'YYYY/MM/DD');
 --Fnd_File.put_line(Fnd_File.LOG,'FIND TERM HIS ***** not found date =' || v_incidence_date  );
   END IF;
   EXCEPTION WHEN OTHERS THEN
         v_incidence_date := r_emp_data.incidence_date;
 --Fnd_File.put_line(Fnd_File.LOG,'FIND TERM HIS ***** Exception date =' || v_incidence_date  );
  END;
-- Ken Mod 8/18/05 to overide incidence_date field with screen_entry_value of input value name Fecha, ending...
	r_interface_mst.employee_id	         := r_emp_data.employee_id;
	r_interface_mst.period_ordinal		 := r_emp_data.period_ordinal;
-- Ken Mod 8/18/05 to overide incidence_date field with screen_entry_value of input value name Fecha
--      r_interface_mst.incidence_date		 := r_emp_data.incidence_date;
        r_interface_mst.incidence_date           := v_incidence_date;
	r_interface_mst.payroll_payment_date	 := r_emp_data.payroll_payment_date;
	r_interface_mst.cost_center		 := r_emp_data.cost_center;
	r_interface_mst.payment_type_code	 := r_emp_data.payment_type_code;
	r_interface_mst.payment_type_value	 := r_emp_data.payment_type_value;
	r_interface_mst.ElementName		 := r_emp_data.ElementName;
	r_interface_mst.InputName		 := r_emp_data.InputName;
	r_interface_mst.person_creation_date	 := r_emp_data.person_creation_date;
        r_interface_mst.person_update_date	 := r_emp_data.person_update_date;
        r_interface_mst.assignment_id		 := r_emp_data.assignment_id;
        r_interface_mst.assignment_creation_date := r_emp_data.assignment_creation_date;
        r_interface_mst.assignment_update_date   := r_emp_data.assignment_update_date;
        r_interface_mst.person_id		 := r_emp_data.person_id;
        r_interface_mst.person_type_id		 := r_emp_data.person_type_id;
        r_interface_mst.system_person_type	 := r_emp_data.system_person_type;
        r_interface_mst.user_person_type	 := r_emp_data.user_person_type;
        r_interface_mst.creation_date            := g_cut_off_date;
        r_interface_mst.last_extract_date        := SYSDATE;
        r_interface_mst.last_extract_file_type   :=' CIN';
        r_interface_mst.cut_off_date		 := g_cut_off_date;
	r_interface_mst.ass_effective_st_dt	 := r_emp_data.ass_effective_st_dt;
	r_interface_mst.BG_ID                    := r_emp_data.BG_ID ;
	r_interface_mst.EntryEffectiveStartDate  := r_emp_data.incidence_date;
	r_interface_mst.EntryEffectiveEndDate    := r_emp_data.payroll_payment_date;
	r_interface_mst.IncidenceID              := NULL;
	r_interface_mst.AbsenceStartDate         := NULL;
	r_interface_mst.AbsenceEndDate           := NULL;
	r_interface_mst.RelapseDate              := NULL;
	r_interface_mst.TipoUnidad               := NULL;
	r_interface_mst.Unidad                   := NULL;
	r_interface_mst.OracleEmployeeId         := r_emp_data.OracleEmployeeId;
        r_interface_mst.peef_element_entry_id    := r_emp_data.peef_element_entry_id;
-- Fnd_File.put_line(Fnd_File.LOG,'FIND TERM HIS loc=110 elementname=' || r_emp_data.ElementName  );         -- delete_later
insert_interface_mst(ir_interface_mst     => r_interface_mst);
-- Fnd_File.put_line(Fnd_File.LOG,'FIND TERM HIS loc=120 after called insett_interface_mst');                -- delete_later
  END LOOP;  -- c_emp_data_term
-- Fnd_File.put_line(Fnd_File.LOG,'FIND TERM HIS loc=130 going into c_emp_absence_term loop'      );         -- delete_later
  FOR r_emp_data IN  c_emp_absence_term (r_pps_emp_data.person_id,
                                              v_papf_effective_start_date,
                                              v_papf_effective_end_date,
                                              v_paaf_effective_start_date,
                                              v_paaf_effective_end_date,
                                              v_date_start,
                                              v_paaf_assignment_id ) LOOP
  BEGIN
     SELECT F.SCREEN_ENTRY_VALUE
       INTO AbsenceStartDate
       FROM PAY_ELEMENT_TYPES_F A,
	    PAY_ELEMENT_ENTRIES_F B,
	    PAY_INPUT_VALUES_F C,
	    PER_ALL_ASSIGNMENTS_F D,
	    PER_ALL_PEOPLE_F E,
	    PAY_ELEMENT_ENTRY_VALUES_F F
      WHERE A.ELEMENT_NAME = LTRIM(RTRIM(r_emp_data.ElementName))
	AND         TRUNC(g_cut_off_date)  BETWEEN a.effective_start_date AND a.effective_end_date
	-- AND         TRUNC(g_cut_off_date)  BETWEEN b.effective_start_date AND b.effective_end_date
        AND        TRUNC(b.effective_end_date) = TRUNC(v_paaf_effective_end_date)           -- difference
	AND        B.ELEMENT_TYPE_ID = A.ELEMENT_TYPE_ID
	AND        A.ELEMENT_TYPE_ID = C.ELEMENT_TYPE_ID
-- Ken Mod 8/22/05 bug fix to pull override data based on peef.element_entry_id (without it, multiple rows may return and go to exception)
        AND B.element_entry_id = r_emp_data.peef_element_entry_id
	AND       TRUNC(g_cut_off_date)  BETWEEN C.effective_start_date AND C.effective_end_date
--	AND       UPPER(C.NAME) =  'FECHA INICIO'
-- Ken Mod 7/19/05 inclucd fecha de incio
        AND       UPPER(C.NAME) IN ( 'FECHA INICIO', 'FECHA DE INICIO')
	AND       B.ASSIGNMENT_ID = D.ASSIGNMENT_ID
	AND       D.PRIMARY_FLAG = 'Y'
	-- AND	  D.ASSIGNMENT_ID = r_emp_data.assignment_id
        AND       D.ASSIGNMENT_ID = v_paaf_assignment_id                                    -- difference
	-- AND       B.EFFECTIVE_START_DATE  BETWEEN D.effective_start_date AND D.effective_end_date
        AND       TRUNC(D.effective_end_date) = TRUNC(v_paaf_effective_end_date)           -- difference
	AND       E.PERSON_ID = D.PERSON_ID
	AND       E.EMPLOYEE_NUMBER  = LTRIM(RTRIM(r_emp_data.OracleEmployeeID))
	-- AND       TRUNC(g_cut_off_date)  BETWEEN E.effective_start_date AND E.effective_end_date
        AND       TRUNC(E.effective_end_date) = TRUNC(v_papf_effective_end_date)                  -- difference
	-- AND       TRUNC(g_cut_off_date)  BETWEEN F.effective_start_date AND F.effective_end_date
        AND       TRUNC(F.effective_end_date) = TRUNC(v_paaf_effective_end_date)                  -- difference
	AND       F.INPUT_VALUE_ID = C.INPUT_VALUE_ID
	AND       F.ELEMENT_ENTRY_ID = B.ELEMENT_ENTRY_ID;
   EXCEPTION WHEN OTHERS THEN
         AbsenceStartDate := NULL;
  END;
 BEGIN
   SELECT F.SCREEN_ENTRY_VALUE
     INTO AbsenceEndDate
     FROM PAY_ELEMENT_TYPES_F A,
	  PAY_ELEMENT_ENTRIES_F B,
	  PAY_INPUT_VALUES_F C,
	  PER_ALL_ASSIGNMENTS_F D,
	  PER_ALL_PEOPLE_F E,
	  PAY_ELEMENT_ENTRY_VALUES_F F
	WHERE  A.ELEMENT_NAME = r_emp_data.ElementName
	AND         TRUNC(g_cut_off_date)  BETWEEN a.effective_start_date AND a.effective_end_date
	-- AND         TRUNC(g_cut_off_date)  BETWEEN b.effective_start_date AND b.effective_end_date
        AND        TRUNC(b.effective_end_date) = TRUNC(v_paaf_effective_end_date)           -- difference
	AND        B.ELEMENT_TYPE_ID = A.ELEMENT_TYPE_ID
	AND        A.ELEMENT_TYPE_ID = C.ELEMENT_TYPE_ID
-- Ken Mod 8/22/05 bug fix to pull override data based on peef.element_entry_id (without it, multiple rows may return and go to exception)
        AND B.element_entry_id = r_emp_data.peef_element_entry_id
	AND       TRUNC(g_cut_off_date)  BETWEEN C.effective_start_date AND C.effective_end_date
	AND       UPPER(C.NAME) =  'FECHA FIN'
	AND       B.ASSIGNMENT_ID = D.ASSIGNMENT_ID
	AND       D.PRIMARY_FLAG = 'Y'
	-- AND	  D.ASSIGNMENT_ID = r_emp_data.assignment_id
        AND       D.ASSIGNMENT_ID = v_paaf_assignment_id                                    -- difference
	-- AND       B.EFFECTIVE_START_DATE  BETWEEN D.effective_start_date AND D.effective_end_date
        AND       TRUNC(D.effective_end_date) = TRUNC(v_paaf_effective_end_date)           -- difference
	AND       E.PERSON_ID = D.PERSON_ID
	AND       E.EMPLOYEE_NUMBER  = r_emp_data.OracleEmployeeID
	-- AND       TRUNC(g_cut_off_date)  BETWEEN E.effective_start_date AND E.effective_end_date
        AND       TRUNC(E.effective_end_date) = TRUNC(v_papf_effective_end_date)                  -- difference
	-- AND         TRUNC(g_cut_off_date)  BETWEEN F.effective_start_date AND F.effective_end_date
        AND       TRUNC(F.effective_end_date) = TRUNC(v_paaf_effective_end_date)                  -- difference
	AND       F.INPUT_VALUE_ID = C.INPUT_VALUE_ID
	AND       F.ELEMENT_ENTRY_ID = B.ELEMENT_ENTRY_ID;
   EXCEPTION WHEN OTHERS THEN
       AbsenceEndDate := NULL;
   END;
   BEGIN
      SELECT F.SCREEN_ENTRY_VALUE
        INTO v_RelapseDate
	FROM PAY_ELEMENT_TYPES_F A,
	     PAY_ELEMENT_ENTRIES_F B,
	     PAY_INPUT_VALUES_F C,
	     PER_ALL_ASSIGNMENTS_F D,
	     PER_ALL_PEOPLE_F E,
	     PAY_ELEMENT_ENTRY_VALUES_F F
       WHERE A.ELEMENT_NAME = r_emp_data.ElementName
	AND       TRUNC(g_cut_off_date)  BETWEEN a.effective_start_date AND a.effective_end_date
	-- AND       TRUNC(g_cut_off_date)  BETWEEN b.effective_start_date AND b.effective_end_date
        AND        TRUNC(b.effective_end_date) = TRUNC(v_paaf_effective_end_date)           -- difference
	AND       B.ELEMENT_TYPE_ID = A.ELEMENT_TYPE_ID
	AND       A.ELEMENT_TYPE_ID = C.ELEMENT_TYPE_ID
-- Ken Mod 8/22/05 bug fix to pull override data based on peef.element_entry_id (without it, multiple rows may return and go to exception)
        AND B.element_entry_id = r_emp_data.peef_element_entry_id
	AND       TRUNC(g_cut_off_date)  BETWEEN C.effective_start_date AND C.effective_end_date
	AND       C.NAME =  'Fecha Reca¿'
	AND       B.ASSIGNMENT_ID = D.ASSIGNMENT_ID
	AND       D.PRIMARY_FLAG = 'Y'
	-- AND	  D.ASSIGNMENT_ID = r_emp_data.assignment_id
        AND       D.ASSIGNMENT_ID = v_paaf_assignment_id                                    -- difference
	-- AND       B.EFFECTIVE_START_DATE  BETWEEN D.effective_start_date AND D.effective_end_date
        AND       TRUNC(D.effective_end_date) = TRUNC(v_paaf_effective_end_date)           -- difference
	AND       E.PERSON_ID = D.PERSON_ID
	AND       E.EMPLOYEE_NUMBER  = r_emp_data.OracleEmployeeID
	-- AND       TRUNC(g_cut_off_date)  BETWEEN E.effective_start_date AND E.effective_end_date
        AND       TRUNC(E.effective_end_date) = TRUNC(v_papf_effective_end_date)                  -- difference
	-- AND       TRUNC(g_cut_off_date)  BETWEEN F.effective_start_date AND F.effective_end_date
        AND       TRUNC(F.effective_end_date) = TRUNC(v_paaf_effective_end_date)                  -- difference
	AND       F.INPUT_VALUE_ID = C.INPUT_VALUE_ID
	AND       F.ELEMENT_ENTRY_ID = B.ELEMENT_ENTRY_ID;
     EXCEPTION WHEN OTHERS THEN
          v_RelapseDate := NULL;
   END;
   BEGIN
      SELECT F.SCREEN_ENTRY_VALUE
       INTO  v_TipoUnidad
       FROM PAY_ELEMENT_TYPES_F A,
            PAY_ELEMENT_ENTRIES_F B,
	    PAY_INPUT_VALUES_F C,
	    PER_ALL_ASSIGNMENTS_F D,
	    PER_ALL_PEOPLE_F E,
	    PAY_ELEMENT_ENTRY_VALUES_F F
      WHERE A.ELEMENT_NAME = r_emp_data.ElementName
	AND       TRUNC(g_cut_off_date)  BETWEEN a.effective_start_date AND a.effective_end_date
	-- AND       TRUNC(g_cut_off_date)  BETWEEN b.effective_start_date AND b.effective_end_date
        AND        TRUNC(b.effective_end_date) = TRUNC(v_paaf_effective_end_date)           -- difference
	AND       B.ELEMENT_TYPE_ID = A.ELEMENT_TYPE_ID
	AND       A.ELEMENT_TYPE_ID = C.ELEMENT_TYPE_ID
-- Ken Mod 8/22/05 bug fix to pull override data based on peef.element_entry_id (without it, multiple rows may return and go to exception)
        AND B.element_entry_id = r_emp_data.peef_element_entry_id
	AND       TRUNC(g_cut_off_date)  BETWEEN C.effective_start_date AND C.effective_end_date
	AND       C.NAME =  'Tipo Unidad'
	AND       B.ASSIGNMENT_ID = D.ASSIGNMENT_ID
	AND       D.PRIMARY_FLAG = 'Y'
	-- AND	  D.ASSIGNMENT_ID = r_emp_data.assignment_id
        AND       D.ASSIGNMENT_ID = v_paaf_assignment_id                                    -- difference
	-- AND       B.EFFECTIVE_START_DATE  BETWEEN D.effective_start_date AND D.effective_end_date
        AND       TRUNC(D.effective_end_date) = TRUNC(v_paaf_effective_end_date)           -- difference
	AND       E.PERSON_ID = D.PERSON_ID
	AND       E.EMPLOYEE_NUMBER  = r_emp_data.OracleEmployeeID
	-- AND       TRUNC(g_cut_off_date)  BETWEEN E.effective_start_date AND E.effective_end_date
        AND       TRUNC(E.effective_end_date) = TRUNC(v_papf_effective_end_date)                  -- difference
	-- AND       TRUNC(g_cut_off_date)  BETWEEN F.effective_start_date AND F.effective_end_date
        AND       TRUNC(F.effective_end_date) = TRUNC(v_paaf_effective_end_date)                  -- difference
	AND       F.INPUT_VALUE_ID = C.INPUT_VALUE_ID
	AND       F.ELEMENT_ENTRY_ID = B.ELEMENT_ENTRY_ID;
   EXCEPTION WHEN OTHERS THEN
        v_TipoUnidad := NULL;
   END;
   BEGIN
      SELECT F.SCREEN_ENTRY_VALUE
	INTO v_Unidad
	FROM PAY_ELEMENT_TYPES_F A,
	     PAY_ELEMENT_ENTRIES_F B,
	     PAY_INPUT_VALUES_F C,
	     PER_ALL_ASSIGNMENTS_F D,
	     PER_ALL_PEOPLE_F E,
	     PAY_ELEMENT_ENTRY_VALUES_F F
       WHERE A.ELEMENT_NAME = r_emp_data.ElementName
	AND       TRUNC(g_cut_off_date)  BETWEEN a.effective_start_date AND a.effective_end_date
	-- AND       TRUNC(g_cut_off_date)  BETWEEN b.effective_start_date AND b.effective_end_date
        AND        TRUNC(b.effective_end_date) = TRUNC(v_paaf_effective_end_date)           -- difference
	AND       B.ELEMENT_TYPE_ID = A.ELEMENT_TYPE_ID
	AND       A.ELEMENT_TYPE_ID = C.ELEMENT_TYPE_ID
-- Ken Mod 8/22/05 bug fix to pull override data based on peef.element_entry_id (without it, multiple rows may return and go to exception)
        AND B.element_entry_id = r_emp_data.peef_element_entry_id
	AND       TRUNC(g_cut_off_date)  BETWEEN C.effective_start_date AND C.effective_end_date
	AND       C.NAME =  'Unidad'
	AND       B.ASSIGNMENT_ID = D.ASSIGNMENT_ID
	AND       D.PRIMARY_FLAG = 'Y'
	-- AND	  D.ASSIGNMENT_ID = r_emp_data.assignment_id
        AND       D.ASSIGNMENT_ID = v_paaf_assignment_id                                    -- difference
	-- AND       B.EFFECTIVE_START_DATE  BETWEEN D.effective_start_date AND D.effective_end_date
        AND       TRUNC(D.effective_end_date) = TRUNC(v_paaf_effective_end_date)           -- difference
	AND       E.PERSON_ID = D.PERSON_ID
	AND       E.EMPLOYEE_NUMBER  = r_emp_data.OracleEmployeeID
	-- AND       TRUNC(g_cut_off_date)  BETWEEN E.effective_start_date AND E.effective_end_date
        AND       TRUNC(E.effective_end_date) = TRUNC(v_papf_effective_end_date)                  -- difference
	-- AND       TRUNC(g_cut_off_date)  BETWEEN F.effective_start_date AND F.effective_end_date
        AND       TRUNC(F.effective_end_date) = TRUNC(v_paaf_effective_end_date)                  -- difference
	AND       F.INPUT_VALUE_ID = C.INPUT_VALUE_ID
	AND       F.ELEMENT_ENTRY_ID = B.ELEMENT_ENTRY_ID;
   EXCEPTION WHEN OTHERS THEN
        v_Unidad := NULL;
   END;
  -- Fnd_File.put_line(Fnd_File.LOG, 'test' || AbsenceStartDate );
  -- Fnd_File.put_line(Fnd_File.LOG, 'test1' || TO_CHAR(AbsenceEndDate ,'dd-mon-yyyy') );
    r_interface_mst.employee_id		          := r_emp_data.employee_id;
    r_interface_mst.period_ordinal		  := r_emp_data.period_ordinal;
    r_interface_mst.incidence_date	          := r_emp_data.incidence_date;
    r_interface_mst.payroll_payment_date          := r_emp_data.payroll_payment_date;
    r_interface_mst.cost_center			  := r_emp_data.cost_center;
    r_interface_mst.payment_type_code		  := r_emp_data.payment_type_code;
    r_interface_mst.payment_type_value		  := r_emp_data.payment_type_value;
    r_interface_mst.ElementName			  := r_emp_data.ElementName;
    r_interface_mst.InputName			  := r_emp_data.InputName;
    r_interface_mst.person_creation_date	  := r_emp_data.person_creation_date;
    r_interface_mst.person_update_date		  := r_emp_data.person_update_date;
    r_interface_mst.assignment_id		  := r_emp_data.assignment_id;
    r_interface_mst.assignment_creation_date      := r_emp_data.assignment_creation_date;
    r_interface_mst.assignment_update_date        := r_emp_data.assignment_update_date;
    r_interface_mst.person_id			  := r_emp_data.person_id;
    r_interface_mst.person_type_id		  := r_emp_data.person_type_id;
    r_interface_mst.system_person_type		  := r_emp_data.system_person_type;
    r_interface_mst.user_person_type		  := r_emp_data.user_person_type;
    r_interface_mst.creation_date                 := g_cut_off_date;
    r_interface_mst.last_extract_date             := SYSDATE;
    r_interface_mst.last_extract_file_type        :=' NAUS';
    r_interface_mst.cut_off_date		  := g_cut_off_date;
    r_interface_mst.ass_effective_st_dt		  := r_emp_data.ass_effective_st_dt;
    r_interface_mst.BG_ID                         := r_emp_data.BG_ID ;
    r_interface_mst.EntryEffectiveStartDate       := r_emp_data.EntryEffectiveStartDate;
    r_interface_mst.EntryEffectiveEndDate         := r_emp_data.EntryEffectiveEndDate;
    r_interface_mst.IncidenceID                   := r_emp_data.IncidenceID;
    r_interface_mst.AbsenceStartDate              := TO_DATE(SUBSTR(AbsenceStartDate,1,10),'yyyy/mm/dd');
    r_interface_mst.AbsenceEndDate                := TO_DATE(SUBSTR(AbsenceEndDate,1,10),'yyyy/mm/dd');
    r_interface_mst.RelapseDate                   := TO_DATE(SUBSTR(v_RelapseDate,1,10),'yyyy/mm/dd');
    r_interface_mst.TipoUnidad                    := v_TipoUnidad;
    r_interface_mst.Unidad                        := v_Unidad;
    r_interface_mst.OracleEmployeeId              := r_emp_data.OracleEmployeeId;
    r_interface_mst.peef_element_entry_id         := r_emp_data.peef_element_entry_id;
insert_interface_mst(ir_interface_mst     => r_interface_mst);
  END LOOP;  -- c_emp_absence_term
  FOR  x  IN  c_emp_baus_term (r_pps_emp_data.person_id,
                                              v_papf_effective_start_date,
                                              v_papf_effective_end_date,
                                              v_paaf_effective_start_date,
                                              v_paaf_effective_end_date,
                                              v_date_start,
                                              v_paaf_assignment_id ) LOOP
    v_term_his                     := NULL;
    v_papf_effective_start_date    := NULL;
    v_papf_effective_end_date      := NULL;
    v_paaf_assignment_id           := NULL;
    v_paaf_effective_start_date    := NULL;
    v_paaf_effective_end_date      := NULL;
    v_PERIOD_OF_SERVICE_ID         := NULL;
    v_ACTUAL_TERMINATION_DATE      := NULL;
    v_FINAL_PROCESS_DATE           := NULL;
    v_LEAVING_REASON               := NULL;
    v_date_start                   := NULL;
    Record_Changed_term_his_x
                            (x.person_id,
                             v_extract_date,           -- is sysdate value retrived at program execution
                             v_papf_effective_start_date,
                             v_papf_effective_end_date,
                             v_paaf_assignment_id,
                             v_paaf_effective_start_date,
                             v_paaf_effective_end_date,
                             v_PERIOD_OF_SERVICE_ID,
                             v_ACTUAL_TERMINATION_DATE,
                             v_FINAL_PROCESS_DATE,
                             v_LEAVING_REASON,
                             v_date_start,
                             v_term_his);
     IF (v_term_his = 'Y' OR v_term_his = 'X') THEN   -- second
     -- to pull EX_EMP record in cust.ttec_spain_pay_interface_mst table
     -- for term and rehired and final processed on or before today, the above table will have 2 records with same cut_off_date (EMP and EX_EMP)
     -- EMP rec from c_emp_data cursor, EX_EMP rec from c_term_his_emp_data  cursor
     -- Fnd_File.put_line(Fnd_File.LOG,'FIND TERM HIS loc=200 person_id=' || r_pps_emp_data.person_id  );         -- delete_later
     FOR    r_emp_data  IN  c_emp_absence_baus_term ( x.Person_ID ,
                                                 x.ElementName,
				                 x.assignment_id,
					         x.cut_off_date,
                                                 r_pps_emp_data.person_id,
                                              v_papf_effective_start_date,
                                              v_papf_effective_end_date,
                                              v_paaf_effective_start_date,
                                              v_paaf_effective_end_date,
                                              v_date_start,
                                              v_paaf_assignment_id ) LOOP
          BEGIN
             SELECT F.SCREEN_ENTRY_VALUE
	       INTO AbsenceStartDate
               FROM PAY_ELEMENT_TYPES_F A,
		    PAY_ELEMENT_ENTRIES_F B,
		    PAY_INPUT_VALUES_F C,
		    PER_ALL_ASSIGNMENTS_F D,
		    PER_ALL_PEOPLE_F E,
		    PAY_ELEMENT_ENTRY_VALUES_F F
	      WHERE A.ELEMENT_NAME = r_emp_data.ElementName
		AND       TRUNC(g_cut_off_date)  BETWEEN a.effective_start_date AND a.effective_end_date
		-- AND       b.effective_end_date  = TRUNC(r_emp_data.EntryEffectiveEndDate)
                AND        TRUNC(b.effective_end_date) = TRUNC(v_paaf_effective_end_date)           -- difference
		-- AND       b.effective_start_date  = TRUNC(r_emp_data.EntryEffectiveStartDate)       -- difference
		AND       B.ELEMENT_TYPE_ID = A.ELEMENT_TYPE_ID
		AND       A.ELEMENT_TYPE_ID = C.ELEMENT_TYPE_ID
-- Ken Mod 8/22/05 bug fix to pull override data based on peef.element_entry_id (without it, multiple rows may return and go to exception)
        AND B.element_entry_id = r_emp_data.peef_element_entry_id
		AND       TRUNC(g_cut_off_date)  BETWEEN C.effective_start_date AND C.effective_end_date
	-- 	AND       UPPER(C.NAME) =  'FECHA INICIO'
        -- Ken Mod 7/19/05 inclucd fecha de incio
                AND       UPPER(C.NAME) IN ( 'FECHA INICIO', 'FECHA DE INICIO')
		AND       B.ASSIGNMENT_ID = D.ASSIGNMENT_ID
		AND       D.PRIMARY_FLAG = 'Y'
		-- AND	  D.ASSIGNMENT_ID = r_emp_data.assignment_id
                AND       D.ASSIGNMENT_ID = v_paaf_assignment_id                                      -- difference
		-- AND       B.EFFECTIVE_START_DATE  BETWEEN D.effective_start_date AND D.effective_end_date
                AND       TRUNC(D.effective_end_date) = TRUNC(v_paaf_effective_end_date)           -- difference
		AND       E.PERSON_ID = D.PERSON_ID
		AND       E.EMPLOYEE_NUMBER  = r_emp_data.OracleEmployeeID
		-- AND       TRUNC(g_cut_off_date)  BETWEEN E.effective_start_date AND E.effective_end_date
                AND       TRUNC(E.effective_end_date) = TRUNC(v_papf_effective_end_date)                  -- difference
                -- AND       TRUNC(b.effective_start_date)  BETWEEN F.effective_start_date AND F.effective_end_date
                AND       TRUNC(F.effective_end_date) = TRUNC(v_paaf_effective_end_date)                  -- difference
		AND       F.INPUT_VALUE_ID = C.INPUT_VALUE_ID
		AND       F.ELEMENT_ENTRY_ID = B.ELEMENT_ENTRY_ID;
	   EXCEPTION WHEN OTHERS THEN
               AbsenceStartDate := NULL;
	  END;
         BEGIN
            SELECT F.SCREEN_ENTRY_VALUE
              INTO AbsenceEndDate
	      FROM PAY_ELEMENT_TYPES_F A,
		   PAY_ELEMENT_ENTRIES_F B,
		   PAY_INPUT_VALUES_F C,
		   PER_ALL_ASSIGNMENTS_F D,
		   PER_ALL_PEOPLE_F E,
		   PAY_ELEMENT_ENTRY_VALUES_F F
             WHERE A.ELEMENT_NAME = r_emp_data.ElementName
	        AND         TRUNC(g_cut_off_date)  BETWEEN a.effective_start_date AND a.effective_end_date
		-- AND         b.effective_end_date  = TRUNC(r_emp_data.EntryEffectiveEndDate)
                AND        TRUNC(b.effective_end_date) = TRUNC(v_paaf_effective_end_date)           -- difference
		-- AND         b.effective_start_date  = TRUNC(r_emp_data.EntryEffectiveStartDate)     -- difference
		AND        B.ELEMENT_TYPE_ID = A.ELEMENT_TYPE_ID
		AND        A.ELEMENT_TYPE_ID = C.ELEMENT_TYPE_ID
-- Ken Mod 8/22/05 bug fix to pull override data based on peef.element_entry_id (without it, multiple rows may return and go to exception)
        AND B.element_entry_id = r_emp_data.peef_element_entry_id
		AND       TRUNC(g_cut_off_date)  BETWEEN C.effective_start_date AND C.effective_end_date
		AND       UPPER(C.NAME) =  'FECHA FIN'
		AND       B.ASSIGNMENT_ID = D.ASSIGNMENT_ID
		AND       D.PRIMARY_FLAG = 'Y'
		-- AND	  D.ASSIGNMENT_ID = r_emp_data.assignment_id
                AND       D.ASSIGNMENT_ID = v_paaf_assignment_id                                      -- difference
		-- AND       B.EFFECTIVE_START_DATE  BETWEEN D.effective_start_date AND D.effective_end_date
                AND       TRUNC(D.effective_end_date) = TRUNC(v_paaf_effective_end_date)           -- difference
		AND       E.PERSON_ID = D.PERSON_ID
		AND       E.EMPLOYEE_NUMBER  = r_emp_data.OracleEmployeeID
		-- AND       TRUNC(g_cut_off_date)  BETWEEN E.effective_start_date AND E.effective_end_date
                AND       TRUNC(E.effective_end_date) = TRUNC(v_papf_effective_end_date)                  -- difference
		-- AND       TRUNC(b.effective_start_date)  BETWEEN F.effective_start_date AND F.effective_end_date
                AND       TRUNC(F.effective_end_date) = TRUNC(v_paaf_effective_end_date)                  -- difference
		AND       F.INPUT_VALUE_ID = C.INPUT_VALUE_ID
		AND       F.ELEMENT_ENTRY_ID = B.ELEMENT_ENTRY_ID;
       EXCEPTION WHEN OTHERS THEN
               AbsenceEndDate := NULL;
       END;
       BEGIN
          SELECT F.SCREEN_ENTRY_VALUE
	    INTO v_RelapseDate
            FROM PAY_ELEMENT_TYPES_F A,
		 PAY_ELEMENT_ENTRIES_F B,
		 PAY_INPUT_VALUES_F C,
		 PER_ALL_ASSIGNMENTS_F D,
		 PER_ALL_PEOPLE_F E,
		 PAY_ELEMENT_ENTRY_VALUES_F F
           WHERE A.ELEMENT_NAME = r_emp_data.ElementName
	     AND       TRUNC(g_cut_off_date)  BETWEEN a.effective_start_date AND a.effective_end_date
	     -- AND       TRUNC(g_cut_off_date)  BETWEEN b.effective_start_date AND b.effective_end_date
             AND        TRUNC(b.effective_end_date) = TRUNC(v_paaf_effective_end_date)           -- difference
	     AND       B.ELEMENT_TYPE_ID = A.ELEMENT_TYPE_ID
	     AND       A.ELEMENT_TYPE_ID = C.ELEMENT_TYPE_ID
-- Ken Mod 8/22/05 bug fix to pull override data based on peef.element_entry_id (without it, multiple rows may return and go to exception)
        AND B.element_entry_id = r_emp_data.peef_element_entry_id
	     AND       TRUNC(g_cut_off_date)  BETWEEN C.effective_start_date AND C.effective_end_date
	     AND       C.NAME =  'Fecha Reca¿'
	     AND       B.ASSIGNMENT_ID = D.ASSIGNMENT_ID
	     AND       D.PRIMARY_FLAG = 'Y'
	     -- AND       D.ASSIGNMENT_ID = r_emp_data.assignment_id
             AND       D.ASSIGNMENT_ID = v_paaf_assignment_id                                      -- difference
	     -- AND       B.EFFECTIVE_START_DATE  BETWEEN D.effective_start_date AND D.effective_end_date
             AND       TRUNC(D.effective_end_date) = TRUNC(v_paaf_effective_end_date)           -- difference
	     AND       E.PERSON_ID = D.PERSON_ID
	     AND       E.EMPLOYEE_NUMBER  = r_emp_data.OracleEmployeeID
	     -- AND       TRUNC(g_cut_off_date)  BETWEEN E.effective_start_date AND E.effective_end_date
             AND       TRUNC(E.effective_end_date) = TRUNC(v_papf_effective_end_date)                  -- difference
	     -- AND       TRUNC(g_cut_off_date)  BETWEEN F.effective_start_date AND F.effective_end_date
             AND       TRUNC(F.effective_end_date) = TRUNC(v_paaf_effective_end_date)                  -- difference
	     AND       F.INPUT_VALUE_ID = C.INPUT_VALUE_ID
	     AND       F.ELEMENT_ENTRY_ID = B.ELEMENT_ENTRY_ID;
       EXCEPTION WHEN OTHERS THEN
               v_RelapseDate := NULL;
       END;
       BEGIN
          SELECT F.SCREEN_ENTRY_VALUE
            INTO v_TipoUnidad
            FROM PAY_ELEMENT_TYPES_F A,
		 PAY_ELEMENT_ENTRIES_F B,
		 PAY_INPUT_VALUES_F C,
		 PER_ALL_ASSIGNMENTS_F D,
		 PER_ALL_PEOPLE_F E,
		 PAY_ELEMENT_ENTRY_VALUES_F F
           WHERE A.ELEMENT_NAME = r_emp_data.ElementName
             AND       TRUNC(g_cut_off_date)  BETWEEN a.effective_start_date AND a.effective_end_date
	     --AND       TRUNC(g_cut_off_date)  BETWEEN b.effective_start_date AND b.effective_end_date
             AND        TRUNC(b.effective_end_date) = TRUNC(v_paaf_effective_end_date)           -- difference
	     AND       B.ELEMENT_TYPE_ID = A.ELEMENT_TYPE_ID
	     AND       A.ELEMENT_TYPE_ID = C.ELEMENT_TYPE_ID
-- Ken Mod 8/22/05 bug fix to pull override data based on peef.element_entry_id (without it, multiple rows may return and go to exception)
        AND B.element_entry_id = r_emp_data.peef_element_entry_id
	     AND       TRUNC(g_cut_off_date)  BETWEEN C.effective_start_date AND C.effective_end_date
	     AND       C.NAME =  'Tipo Unidad'
	     AND       B.ASSIGNMENT_ID = D.ASSIGNMENT_ID
	     AND       D.PRIMARY_FLAG = 'Y'
	     -- AND       D.ASSIGNMENT_ID = r_emp_data.assignment_id
             AND       D.ASSIGNMENT_ID = v_paaf_assignment_id                                      -- difference
	     -- AND       B.EFFECTIVE_START_DATE  BETWEEN D.effective_start_date AND D.effective_end_date
             AND       TRUNC(D.effective_end_date) = TRUNC(v_paaf_effective_end_date)           -- difference
	     AND       E.PERSON_ID = D.PERSON_ID
	     AND       E.EMPLOYEE_NUMBER  = r_emp_data.OracleEmployeeID
	     -- AND       TRUNC(g_cut_off_date)  BETWEEN E.effective_start_date AND E.effective_end_date
             AND       TRUNC(E.effective_end_date) = TRUNC(v_papf_effective_end_date)                  -- difference
	     -- AND       TRUNC(g_cut_off_date)  BETWEEN F.effective_start_date AND F.effective_end_date
             AND       TRUNC(F.effective_end_date) = TRUNC(v_paaf_effective_end_date)                  -- difference
	     AND       F.INPUT_VALUE_ID = C.INPUT_VALUE_ID
	     AND       F.ELEMENT_ENTRY_ID = B.ELEMENT_ENTRY_ID;
	 EXCEPTION WHEN OTHERS THEN
               v_TipoUnidad := NULL;
         END;
        BEGIN
           SELECT F.SCREEN_ENTRY_VALUE
             INTO v_Unidad
             FROM PAY_ELEMENT_TYPES_F A,
		  PAY_ELEMENT_ENTRIES_F B,
		  PAY_INPUT_VALUES_F C,
		  PER_ALL_ASSIGNMENTS_F D,
		  PER_ALL_PEOPLE_F E,
		  PAY_ELEMENT_ENTRY_VALUES_F F
            WHERE A.ELEMENT_NAME = r_emp_data.ElementName
	      AND       TRUNC(g_cut_off_date)  BETWEEN a.effective_start_date AND a.effective_end_date
	      -- AND       TRUNC(g_cut_off_date)  BETWEEN b.effective_start_date AND b.effective_end_date
              AND        TRUNC(b.effective_end_date) = TRUNC(v_paaf_effective_end_date)           -- difference
	      AND       B.ELEMENT_TYPE_ID = A.ELEMENT_TYPE_ID
	      AND       A.ELEMENT_TYPE_ID = C.ELEMENT_TYPE_ID
-- Ken Mod 8/22/05 bug fix to pull override data based on peef.element_entry_id (without it, multiple rows may return and go to exception)
        AND B.element_entry_id = r_emp_data.peef_element_entry_id
	      AND       TRUNC(g_cut_off_date)  BETWEEN C.effective_start_date AND C.effective_end_date
              AND       C.NAME =  'Unidad'
	      AND       B.ASSIGNMENT_ID = D.ASSIGNMENT_ID
	      AND       D.PRIMARY_FLAG = 'Y'
	      -- AND       D.ASSIGNMENT_ID = r_emp_data.assignment_id
              AND       D.ASSIGNMENT_ID = v_paaf_assignment_id                                      -- difference
	      -- AND       B.EFFECTIVE_START_DATE  BETWEEN D.effective_start_date AND D.effective_end_date
              AND       TRUNC(D.effective_end_date) = TRUNC(v_paaf_effective_end_date)           -- difference
	      AND       E.PERSON_ID = D.PERSON_ID
	      AND       E.EMPLOYEE_NUMBER  = r_emp_data.OracleEmployeeID
	      -- AND       TRUNC(g_cut_off_date)  BETWEEN E.effective_start_date AND E.effective_end_date
              AND       TRUNC(E.effective_end_date) = TRUNC(v_papf_effective_end_date)                  -- difference
	      -- AND       TRUNC(g_cut_off_date)  BETWEEN F.effective_start_date AND F.effective_end_date
              AND       TRUNC(F.effective_end_date) = TRUNC(v_paaf_effective_end_date)                  -- difference
	      AND       F.INPUT_VALUE_ID = C.INPUT_VALUE_ID
	      AND       F.ELEMENT_ENTRY_ID = B.ELEMENT_ENTRY_ID;
	 EXCEPTION WHEN OTHERS THEN
	          v_Unidad := NULL;
	 END;
	r_interface_mst.employee_id		  := r_emp_data.employee_id;
	r_interface_mst.period_ordinal		  := r_emp_data.period_ordinal;
	r_interface_mst.incidence_date		  := r_emp_data.incidence_date;
	r_interface_mst.payroll_payment_date	  := r_emp_data.payroll_payment_date;
	r_interface_mst.cost_center		  := r_emp_data.cost_center;
	r_interface_mst.payment_type_code	  := r_emp_data.payment_type_code;
	r_interface_mst.payment_type_value	  := r_emp_data.payment_type_value;
	r_interface_mst.ElementName		  := r_emp_data.ElementName;
	r_interface_mst.InputName		  := r_emp_data.InputName;
	r_interface_mst.person_creation_date	  := r_emp_data.person_creation_date;
        r_interface_mst.person_update_date	  := r_emp_data.person_update_date;
        r_interface_mst.assignment_id		  := r_emp_data.assignment_id;
        r_interface_mst.assignment_creation_date  := r_emp_data.assignment_creation_date;
        r_interface_mst.assignment_update_date    := r_emp_data.assignment_update_date;
        r_interface_mst.person_id		  := r_emp_data.person_id;
        r_interface_mst.person_type_id		  := r_emp_data.person_type_id;
        r_interface_mst.system_person_type	  := r_emp_data.system_person_type;
        r_interface_mst.user_person_type	  := r_emp_data.user_person_type;
        r_interface_mst.creation_date             := g_cut_off_date;
        r_interface_mst.last_extract_date         := SYSDATE;
        r_interface_mst.last_extract_file_type    :=' BAUS';
        r_interface_mst.cut_off_date		  := g_cut_off_date;
	r_interface_mst.ass_effective_st_dt	  := r_emp_data.ass_effective_st_dt;
	r_interface_mst.BG_ID                     := r_emp_data.BG_ID ;
	r_interface_mst.EntryEffectiveStartDate   := r_emp_data.EntryEffectiveStartDate;
	r_interface_mst.EntryEffectiveEndDate     := r_emp_data.EntryEffectiveEndDate;
	r_interface_mst.IncidenceID               := r_emp_data.IncidenceID;
	r_interface_mst.AbsenceStartDate          := TO_DATE(SUBSTR(AbsenceStartDate,1,10),'yyyy/mm/dd');
	r_interface_mst.AbsenceEndDate            := TO_DATE(SUBSTR(AbsenceEndDate,1,10),'yyyy/mm/dd');
	r_interface_mst.RelapseDate               := TO_DATE(SUBSTR(v_RelapseDate,1,10),'yyyy/mm/dd');
	r_interface_mst.TipoUnidad                := v_TipoUnidad;
	r_interface_mst.Unidad                    := v_Unidad;
	r_interface_mst.OracleEmployeeId          := r_emp_data.OracleEmployeeId;
        r_interface_mst.peef_element_entry_id     := r_emp_data.peef_element_entry_id;
	insert_interface_mst(ir_interface_mst     => r_interface_mst);
         END LOOP;  -- c_emp_absence_baus_term
      END IF;  -- for IF (v_term_his = 'Y' OR v_term_his = 'X') -- second
  END LOOP; -- c_emp_baus_term
END IF; -- for IF (v_term_his = 'Y' OR v_term_his = 'X') -- first
END LOOP;  -- c_pps_emp_data
-- BBB ending..
  COMMIT;
EXCEPTION
  WHEN OTHERS THEN
    ROLLBACK;
	g_retcode := SQLCODE;
	g_errbuf  := SUBSTR(SQLERRM ,1,255);
	Fnd_File.put_line(Fnd_File.LOG,'Populate Interface Failed' );
	Fnd_File.put_line(Fnd_File.LOG,SUBSTR(SQLERRM,1,255));
	RAISE g_e_abort;
END; -- procedure populate_interface_tables
--================================================================================
PROCEDURE extract_element (ov_errbuf        OUT VARCHAR2,
            		   ov_retcode       OUT NUMBER,
          		   iv_cut_off_date   IN VARCHAR2) IS
BEGIN
  --  Added by C.Chan on 28-DEC-2005 for TT#411517
  dbms_session.set_nls('nls_date_format','''dd/mm/rrrr''');
  set_business_group_id(iv_business_group => 'TeleTech Holdings - ESP');
  Fnd_File.put_line(Fnd_File.LOG,'Business Group ID = ' || TO_CHAR(g_business_group_id));
  --  Modified by C.Chan on 28-DEC-2005 for TT#411517
--   IF 	iv_cut_off_date IS NOT NULL AND TO_DATE(iv_cut_off_date,'DD-MON-RRRR') <= TRUNC(SYSDATE)
-- 	THEN g_cut_off_date :=TO_DATE(iv_cut_off_date,'DD-MON-RRRR');
-- 	ELSE RAISE g_e_future_date;
--   END IF;
  IF 	iv_cut_off_date IS NOT NULL AND TO_DATE(iv_cut_off_date,'DD-MM-RRRR') <= TRUNC(SYSDATE)
	THEN g_cut_off_date :=TO_DATE(iv_cut_off_date,'DD-MM-RRRR');
	ELSE RAISE g_e_future_date;
  END IF;
  Fnd_File.put_line(Fnd_File.LOG,'Cut Off Date      = ' || TO_CHAR(g_cut_off_date,'MM/DD/YYYY'));
     Fnd_File.put_line(Fnd_File.LOG,'Starting to populate_interface_tables...' );
   populate_interface_tables;
     Fnd_File.put_line(Fnd_File.LOG,'Finished to populate_interface_tables...' );
--  Print_line
     Fnd_File.put_line(Fnd_File.LOG,'Starting to extract_absence_new...' );
   extract_absence_new;
     Fnd_File.put_line(Fnd_File.LOG,'Finished to extract_absence_new...' );
     Fnd_File.put_line(Fnd_File.LOG,'Starting to extract_absence_mod...' );
   extract_absence_mod;
     Fnd_File.put_line(Fnd_File.LOG,'Finished to extract_absence_mod...' );
     Fnd_File.put_line(Fnd_File.LOG,'Starting to extract_absence_baus...' );
   extract_absence_baus;
     Fnd_File.put_line(Fnd_File.LOG,'Finished to extract_absence_baus...' );
     Fnd_File.put_line(Fnd_File.LOG,'Starting to extract_spain_element...' );
   extract_spain_element;
     Fnd_File.put_line(Fnd_File.LOG,'Finished to extract_spain_element...' );
-- Ken Mod 8/24/05 added to pruduct pay code control totals in current log file.
  Fnd_File.put_line(Fnd_File.LOG,'Starting to extract_elements_ctl_tot');
  extract_elements_ctl_tot;
  Fnd_File.put_line(Fnd_File.LOG,'Finished to extract_elements_ctl_tot');
EXCEPTION
  WHEN g_e_abort THEN
    Fnd_File.put_line(Fnd_File.LOG,'Process Aborted - Contact Teletech Help Desk');
    ov_retcode := g_retcode;
	ov_errbuf  := g_errbuf;
   WHEN g_e_future_date THEN
    Fnd_File.put_line(Fnd_File.LOG,'Process Aborted - Enter "Cut_off_date" which is not in future');
    ov_retcode := g_retcode;
	ov_errbuf  := g_errbuf;
	--dbms_output.put_line('Process Aborted - Enter "Cut_off_date" which is not in future');
  WHEN OTHERS THEN
    Fnd_File.put_line(Fnd_File.LOG,'When Others Exception - Contact Teltech Help Desk');
	ov_retcode := SQLCODE;
	ov_errbuf  := SUBSTR(SQLERRM,1,255);
END; -- procedure extract_element
--============================================================
--------------------------------------------------------------------
END; -- Package Body ttec_sp_payroll_interface_pkg
/
show errors;
/