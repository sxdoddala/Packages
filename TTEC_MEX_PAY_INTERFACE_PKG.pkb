create or replace package body      ttec_mex_pay_interface_pkg as
--------------------------------------------------------------------
--                                                                --
-- NAME:  ttec_mex_pay_interface_pkg       (Package)              --
--                                                                --
--     DESCRIPTION:  Mexico HR Data to the Payroll VENDor	  --
--                    						  --
--                                                                --
--                                                                --
--     CHANGE HISTORY                                             --
--                                                                --
--     CHANGED BY        Date        REASON FOR CHANGE           --
--     ----------        ----        -----------------            --
--     Vijay Mayadam   17-Jan-2005  Initial Creation             --
--     CHANGED BY        Date        REASON FOR CHANGE           --
--     ----------        ----        -----------------            --
--    Arun Jayaraman   24-Jan-2005  COuntry specIFic creation     --
--                                                                --
--                                                                --
--------------------------------------------------------------------
--------------------------------------------------------------------
--                                                                --
-- NAME:  print_line                   (PROCEDURE)                --
--                                                                --
--     DESCRIPTION:         PROCEDURE called by other PROCEDUREs  --
--                           to extract data                      --
--                                                                --
--     CHANGE HISTORY                                             --
--                                                                --
--     CHANGED BY        Date        REASON FOR CHANGE           --
--     ----------        ----        -----------------            --
--     Vijay Mayadam   17-Jan-2005  Initial Creation             --
--     CHANGED BY        Date        REASON FOR CHANGE           --
--     ----------        ----        -----------------            --
--    Arun Jayaraman   24-Jan-2005  COuntry specIFic creation     --
--                                                                --
--    Christiane Chan  25-Jan-2006  WO#159215 Adding new code to  --
--                                  field 31 Payroll_Process.     --
--                                  Set the code to '008''        --
--                                  if Employee Category = '      --
--                                     PERSONAL ADMINISTRATIVO'   --
--                                  and GRE = "SSI"               --
--                                                                --
--    Christiane Chan  09-Jun-2006  TT#508809 Issue with Termination
--                                  /Rehire the next day          --
--
--    C.Chan           11-DEC-2007  Add tracking table to monitor
--                                  each process step's run time
--
--------------------------------------------------------------------
PROCEDURE print_line(iv_data          in varchar2) is
BEGIN
  fnd_file.put_line(fnd_file.output,iv_data);
END; -- print_line
--------------------------------------------------------------------
--                                                                --
-- NAME:  delimit_text                 (FUNCTION)                 --
--                                                                --
--     DESCRIPTION:         FUNCTION called by other PROCEDUREs   --
--                           to scrub AND delimite data           --
--                                                                --
--     CHANGE HISTORY                                             --
--                                                                --
--     CHANGED BY        Date        REASON FOR CHANGE           --
--     ----------        ----        -----------------            --
--     Vijay Mayadam   17-Jan-2005  Initial Creation             --
--                                                                --
--     CHANGED BY        Date        REASON FOR CHANGE           --
--     ----------        ----        -----------------            --
--    Arun Jayaraman   24-Jan-2005  COuntry specIFic creation     --
--                                                                --
--------------------------------------------------------------------
/************************************************************************************
        Program Name: TTEC_PO_TSG_INTERFACE 

       Modification Log
       Name                  Version #    Date            Description
       -----                 --------     -----           -------------
    IXPRAVEEN(ARGANO)            1.0      02-May-2023      R12.2 Upgrade Remediation
    ****************************************************************************************/
FUNCTION delimit_text (iv_number_of_fields       in number,
                       iv_field1                 in varchar2,
					   iv_field2                 in varchar2 default null,
					   iv_field3                 in varchar2 default null,
					   iv_field4                 in varchar2 default null,
					   iv_field5                 in varchar2 default null,
					   iv_field6                 in varchar2 default null,
					   iv_field7                 in varchar2 default null,
					   iv_field8                 in varchar2 default null,
					   iv_field9                 in varchar2 default null,
					   iv_field10                in varchar2 default null,
					   iv_field11                in varchar2 default null,
					   iv_field12                in varchar2 default null,
					   iv_field13                in varchar2 default null,
					   iv_field14                in varchar2 default null,
					   iv_field15                in varchar2 default null,
					   iv_field16                in varchar2 default null,
					   iv_field17                in varchar2 default null,
					   iv_field18                in varchar2 default null,
					   iv_field19                in varchar2 default null,
					   iv_field20                in varchar2 default null,
   					   iv_field21                in varchar2 default null,
					   iv_field22                in varchar2 default null,
					   iv_field23                in varchar2 default null,
					   iv_field24                in varchar2 default null,
					   iv_field25                in varchar2 default null,
					   iv_field26                in varchar2 default null,
					   iv_field27                in varchar2 default null,
					   iv_field28                in varchar2 default null,
					   iv_field29                in varchar2 default null,
					   iv_field30                in varchar2 default null,
					   iv_field31                in varchar2 default null,
					   iv_field32                in varchar2 default null,
					   iv_field33                in varchar2 default null,
					   iv_field34                in varchar2 default null,
					   iv_field35                in varchar2 default null,
					   iv_field36                in varchar2 default null,
					   iv_field37                in varchar2 default null,
					   iv_field38                in varchar2 default null,
					   iv_field39                in varchar2 default null,
					   iv_field40                in varchar2 default null,
   					   iv_field41                in varchar2 default null,
					   iv_field42                in varchar2 default null,
					   iv_field43                in varchar2 default null,
					   iv_field44                in varchar2 default null,
					   iv_field45                in varchar2 default null,
					   iv_field46                in varchar2 default null,
					   iv_field47                in varchar2 default null,
					   iv_field48                in varchar2 default null,
					   iv_field49                in varchar2 default null,
					   iv_field50                in varchar2 default null,
					   iv_field51                in varchar2 default null,
					   iv_field52                in varchar2 default null,
					   iv_field53                in varchar2 default null,
					   iv_field54                in varchar2 default null,
					   iv_field55                in varchar2 default null,
					   iv_field56                in varchar2 default null,
					   iv_field57                in varchar2 default null,
					   iv_field58                in varchar2 default null,
					   iv_field59                in varchar2 default null,
					   iv_field60                in varchar2 default null ) return varchar2 is
v_delimiter          varchar2(1)    := '@';
v_replacement_char   varchar2(1)    := ' ';
v_delimited_text     varchar2(2000);
BEGIN
  -- Removes the Delimiter FROM the fields AND replaces it with
  -- Replacement Char, THEN concatenates the fields together
  -- separated by the delimiter
  v_delimited_text := replace(iv_field1,v_delimiter,v_replacement_char)       || v_delimiter ||
	                  	          replace(iv_field2,v_delimiter,v_replacement_char)       || v_delimiter ||
			                  replace(iv_field3,v_delimiter,v_replacement_char)       || v_delimiter ||
	        		          replace(iv_field4,v_delimiter,v_replacement_char)       || v_delimiter ||
					  replace(iv_field5,v_delimiter,v_replacement_char)       || v_delimiter ||
					  replace(iv_field6,v_delimiter,v_replacement_char)       || v_delimiter ||
					  replace(iv_field7,v_delimiter,v_replacement_char)       || v_delimiter ||
					  replace(iv_field8,v_delimiter,v_replacement_char)       || v_delimiter ||
					  replace(iv_field9,v_delimiter,v_replacement_char)       || v_delimiter ||
					  replace(iv_field10,v_delimiter,v_replacement_char)      || v_delimiter ||
					  replace(iv_field11,v_delimiter,v_replacement_char)      || v_delimiter ||
					  replace(iv_field12,v_delimiter,v_replacement_char)      || v_delimiter ||
					  replace(iv_field13,v_delimiter,v_replacement_char)      || v_delimiter ||
					  replace(iv_field14,v_delimiter,v_replacement_char)      || v_delimiter ||
					  replace(iv_field15,v_delimiter,v_replacement_char)      || v_delimiter ||
					  replace(iv_field16,v_delimiter,v_replacement_char)      || v_delimiter ||
					  replace(iv_field17,v_delimiter,v_replacement_char)      || v_delimiter ||
					  replace(iv_field18,v_delimiter,v_replacement_char)      || v_delimiter ||
					  replace(iv_field19,v_delimiter,v_replacement_char)      || v_delimiter ||
					  replace(iv_field20,v_delimiter,v_replacement_char)      || v_delimiter ||
					  replace(iv_field21,v_delimiter,v_replacement_char)      || v_delimiter ||
					  replace(iv_field22,v_delimiter,v_replacement_char)      || v_delimiter ||
					  replace(iv_field23,v_delimiter,v_replacement_char)      || v_delimiter ||
					  replace(iv_field24,v_delimiter,v_replacement_char)      || v_delimiter ||
					  replace(iv_field25,v_delimiter,v_replacement_char)      || v_delimiter ||
					  replace(iv_field26,v_delimiter,v_replacement_char)      || v_delimiter ||
					  replace(iv_field27,v_delimiter,v_replacement_char)      || v_delimiter ||
					  replace(iv_field28,v_delimiter,v_replacement_char)      || v_delimiter ||
					  replace(iv_field29,v_delimiter,v_replacement_char)      || v_delimiter ||
					  replace(iv_field30,v_delimiter,v_replacement_char)      || v_delimiter ||
					  replace(iv_field31,v_delimiter,v_replacement_char)      || v_delimiter ||
					  replace(iv_field32,v_delimiter,v_replacement_char)      || v_delimiter ||
					  replace(iv_field33,v_delimiter,v_replacement_char)      || v_delimiter ||
					  replace(iv_field34,v_delimiter,v_replacement_char)      || v_delimiter ||
					  replace(iv_field35,v_delimiter,v_replacement_char)      || v_delimiter ||
					  replace(iv_field36,v_delimiter,v_replacement_char)      || v_delimiter ||
					  replace(iv_field37,v_delimiter,v_replacement_char)      || v_delimiter ||
					  replace(iv_field38,v_delimiter,v_replacement_char)      || v_delimiter ||
					  replace(iv_field39,v_delimiter,v_replacement_char)      || v_delimiter ||
					  replace(iv_field40,v_delimiter,v_replacement_char)      || v_delimiter ||
					  replace(iv_field41,v_delimiter,v_replacement_char)      || v_delimiter ||
					  replace(iv_field42,v_delimiter,v_replacement_char)      || v_delimiter ||
					  replace(iv_field43,v_delimiter,v_replacement_char)      || v_delimiter ||
					  replace(iv_field44,v_delimiter,v_replacement_char)      || v_delimiter ||
					  replace(iv_field45,v_delimiter,v_replacement_char)      || v_delimiter ||
					  replace(iv_field46,v_delimiter,v_replacement_char)      || v_delimiter ||
					  replace(iv_field47,v_delimiter,v_replacement_char)      || v_delimiter ||
					  replace(iv_field48,v_delimiter,v_replacement_char)      || v_delimiter ||
					  replace(iv_field49,v_delimiter,v_replacement_char)      || v_delimiter ||
					  replace(iv_field50,v_delimiter,v_replacement_char)      || v_delimiter ||
					  replace(iv_field51,v_delimiter,v_replacement_char)      || v_delimiter ||
					  replace(iv_field52,v_delimiter,v_replacement_char)      || v_delimiter ||
					  replace(iv_field53,v_delimiter,v_replacement_char)      || v_delimiter ||
					  replace(iv_field54,v_delimiter,v_replacement_char)      || v_delimiter ||
					  replace(iv_field55,v_delimiter,v_replacement_char)      || v_delimiter ||
					  replace(iv_field56,v_delimiter,v_replacement_char)      || v_delimiter ||
					  replace(iv_field57,v_delimiter,v_replacement_char)      || v_delimiter ||
					  replace(iv_field58,v_delimiter,v_replacement_char)      || v_delimiter ||
					  replace(iv_field59,v_delimiter,v_replacement_char)      || v_delimiter ||
					  replace(iv_field60,v_delimiter,v_replacement_char);
  -- return only the number of fields as requested by
  -- the iv_number_of_fields parameter
  v_delimited_text := substr(v_delimited_text,1,instr(v_delimited_text,'@',1,iv_number_of_fields)-1);
  return v_delimited_text;
EXCEPTION
  when others THEN
    return null;
END; -- delimit_text
--------------------------------------------------------------------
--                                                                --
-- NAME:  scrub_to_number            (FUNCTION)                   --
--                                                                --
--     DESCRIPTION:         FUNCTION called by other PROCEDUREs   --
--                           to strip special characters          --
--                                                                --
--     CHANGE HISTORY                                             --
--                                                                --
--     CHANGED BY        Date        REASON FOR CHANGE           --
--     ----------        ----        -----------------            --
--     Vijay Mayadam   17-Jan-2005  Initial Creation             --
--                                                                --
--     CHANGED BY        Date        REASON FOR CHANGE           --
--     ----------        ----        -----------------            --
--    Arun Jayaraman   24-Jan-2005  COuntry specIFic creation     --
--                                                                --
--------------------------------------------------------------------
FUNCTION scrub_to_number    (iv_text        in varchar2) return varchar2 is
v_number        varchar2(255);
v_length        number;
i               number;
BEGIN
  v_length := length(iv_text);
  IF v_length > 0 THEN
    -- look at each character in text AND remove any non-numbers
    FOR i in 1 .. v_length loop
	  IF ascii(substr(iv_text,i,1)) between 48 AND 57 THEN
	    v_number := v_number || substr(iv_text,i,1);
	  END IF; -- ascii between 48 AND 57
  	END loop; -- i
  END IF; -- v_length
  return v_number;
EXCEPTION
  when others THEN
    return iv_text;
END; -- FUNCTION scrub_to_number
FUNCTION get_hire_date   (iv_person_id  in NUMBER) return DATE is
l_hire_date DATE := NULL;
BEGIN
 SELECT max(date_start)
 INTO   l_hire_date
 FROM   per_periods_of_service
 WHERE  person_id = iv_person_id
 AND    trunc(date_start) <= trunc(g_cut_off_date);
  return l_hire_date;
 EXCEPTION
  when others THEN
    return l_hire_date;
END; -- FUNCTION get_hire_date
--------------------------------------------------------------------
--                                                                --
-- NAME:  set_business_group_id        (PROCEDURE)                --
--                                                                --
--     DESCRIPTION:         PROCEDURE called by other PROCEDUREs  --
--                           to set global business_group_id      --
--                                                                --
--     CHANGE HISTORY                                             --
--                                                                --
--     CHANGED BY        Date        REASON FOR CHANGE           --
--     ----------        ----        -----------------            --
--     Vijay Mayadam   17-Jan-2005  Initial Creation             --
--                                                                --
--     CHANGED BY        Date        REASON FOR CHANGE           --
--     ----------        ----        -----------------            --
--    Arun Jayaraman   24-Jan-2005  COuntry specIFic creation     --
--                                                                --
--------------------------------------------------------------------
PROCEDURE set_business_group_id (iv_business_group in varchar2 default 'TeleTech Holdings - MEX') is
BEGIN
  SELECT organization_id
  INTO   g_business_group_id
  FROM   hr_all_organization_units
  WHERE  NAME = iv_business_group;
EXCEPTION
  WHEN OTHERS THEN
    fnd_File.put_line(fnd_file.log,'Unable to Determine Business Group ID');
	fnd_file.put_line(fnd_file.log,substr(SQLERRM,1,255));
	g_errbuf  := substr(SQLERRM,1,255);
	g_retcode := SQLCODE;
	RAISE g_e_abort;
END;  -- PROCEDURE set_business_group_id
/*===========================================================================
  PROCEDURE NAME:       validate date
  DESCRIPTION:
                        Validates and converts a char datatype date string
                        to a date datatype that the user has entered
                        is in a valid format based on the NLS_DATE_FORMAT
                        as 'DD-MON-RRRR'.
============================================================================*/
PROCEDURE validate_date (p_char_date IN VARCHAR2,
                         p_date_date OUT NOCOPY DATE,
                         p_valid_date OUT NOCOPY BOOLEAN) IS
l_nls_date_format   VARCHAR2(80);
l_date_date         DATE;
BEGIN
   /*
   ** Set the l_date_date to null
   */
   l_date_date := NULL;
   l_nls_date_format := 'DD-MON-RRRR';
   /*
   ** Now try to convert the char date string to a date datatype.  If any
   ** exception occurs then tell the caller that it is not valid date.
   */
   p_valid_date := TRUE;
   BEGIN
      SELECT nvl(TO_DATE(p_char_date, l_nls_date_format),TRUNC(SYSDATE))
      INTO   l_date_date
      FROM   dual;
   EXCEPTION
      WHEN OTHERS THEN
         p_valid_date := FALSE;
   END;
   p_date_date := l_date_date;
   EXCEPTION
   WHEN OTHERS THEN
      p_valid_date := FALSE;
END validate_date;
/*
--------------------------------------------------------------------
--                                                                --
-- NAME:  set_security_group_id        (PROCEDURE)                --
--                                                                --
--     DESCRIPTION:         PROCEDURE called by other PROCEDUREs  --
--                           to set global business_group_id      --
--                                                                --
--     CHANGE HISTORY                                             --
--                                                                --
--     CHANGED BY        Date        REASON FOR CHANGE           --
--     ----------        ----        -----------------            --
--     Vijay Mayadam   17-Jan-2005  Initial Creation             --
--                                                                --
--     CHANGED BY        Date        REASON FOR CHANGE           --
--     ----------        ----        -----------------            --
--    Arun Jayaraman   24-Jan-2005  COuntry specIFic creation     --
--                                                                --
--------------------------------------------------------------------
PROCEDURE set_security_group_id --(iv_security_group in varchar2 default 'TeleTech Holdings - MEX')
is
BEGIN
  SELECT security_group_id
  INTO   g_security_group_id
  FROM   fnd_security_groups_vl
  WHERE  security_group_name = 'TeleTech Holdings - MEX';
EXCEPTION
  WHEN OTHERS THEN
    fnd_File.put_line(fnd_file.log,'Unable to Determine Security Group ID');
	fnd_file.put_line(fnd_file.log,substr(SQLERRM,1,255));
	g_errbuf  := substr(SQLERRM,1,255);
	g_retcode := SQLCODE;
	RAISE g_e_abort;
END;  -- PROCEDURE set_security_group_id
*/
--------------------------------------------------------------------
--                                                                --
-- NAME:  set_payroll_dates            (PROCEDURE)                --
--                                                                --
--     DESCRIPTION:         PROCEDURE called by other PROCEDUREs  --
--                           to return payroll dates              --
--                                                                --
--     CHANGE HISTORY                                             --
--                                                                --
--     CHANGED BY        Date        REASON FOR CHANGE           --
--     ----------        ----        -----------------            --
--     Vijay Mayadam   17-Jan-2005  Initial Creation             --
--                                                                --
--     CHANGED BY        Date        REASON FOR CHANGE           --
--     ----------        ----        -----------------            --
--    Arun Jayaraman   24-Jan-2005  COuntry specIFic creation     --
--                                                                --
--------------------------------------------------------------------
PROCEDURE set_payroll_dates (iv_pay_period_id          in  varchar2) is
BEGIN
null; --not using payroll cut-off dates FOR mex payroll interface--
/*
  SELECT pay.payroll_NAME,
         ptp.period_NAME,
         ptp.start_date,
	     ptp.END_date,
	     ptp.cut_off_date,
	     ptp.pay_advice_date,
	     ptp.regular_payment_date
  INTO   g_payroll_NAME,
         g_period_NAME,
         g_start_date,
         g_END_date,
         g_cut_off_date,
         g_pay_advice_date,
         g_regular_payment_date
  FROM   pay_payrolls_f pay,
         per_time_periods ptp
  WHERE  pay.business_group_id = g_business_group_id
  AND    pay.payroll_id = ptp.payroll_id
  AND    ptp.time_period_id = iv_pay_period_id
  AND    trunc(g_cut_off_date) between pay.effective_start_date AND pay.effective_END_date;
*/
EXCEPTION
  WHEN OTHERS THEN
/*
    g_payroll_NAME           := 'NO PAYROLL FOUND';
    g_period_NAME            := 'NO PERIOD FOUND';
    g_start_date             := to_date('01JAN2004','DDMONYYYY');
    g_END_date               := to_date('31DEC4712','DDMONYYYY');
    g_cut_off_date           := trunc(sysdate);
    g_pay_advice_date        := trunc(sysdate);
    g_regular_payment_date   := trunc(sysdate);
*/
    g_cut_off_date           := sysdate;
END; -- PROCEDURE set_payroll_dates
--------------------------------------------------------------------
--                                                                --
-- NAME:  get_salary        (PROCEDURE)                           --
--                                                                --
--     DESCRIPTION:         PROCEDURE called by other PROCEDUREs  --
--                           to return salary AND change date     --
--                                                                --
--     CHANGE HISTORY                                             --
--                                                                --
--     CHANGED BY        Date        REASON FOR CHANGE           --
--     ----------        ----        -----------------            --
--     Vijay Mayadam   17-Jan-2005  Initial Creation             --
--                                                                --
--     CHANGED BY        Date        REASON FOR CHANGE           --
--     ----------        ----        -----------------            --
--    Arun Jayaraman   24-Jan-2005  COuntry specIFic creation     --
--                                                                --
--------------------------------------------------------------------
PROCEDURE get_salary (iv_assignment_id in  varchar2,
                      ov_salary        out number,
                      ov_change_date   out date,
	       	      ov_change_reason out varchar2) is
BEGIN
  SELECT ppp.proposed_salary_n,
	     ppp.change_date,
		 ppp.proposal_reason
  INTO   ov_salary,
         ov_change_date,
		 ov_change_reason
  FROM   per_pay_proposals ppp
  WHERE  assignment_id = iv_assignment_id
  AND    approved = 'Y'
  AND    change_date = (SELECT max(change_date)
                        FROM   per_pay_proposals
                        WHERE  assignment_id = iv_assignment_id
                        AND    approved = 'Y'
                        AND    change_date <= trunc(g_cut_off_date));
EXCEPTION
  WHEN OTHERS THEN
    	ov_salary          := 0;
    	ov_change_date     := to_date(null);
	ov_change_reason   := null;
END;  -- PROCEDURE get_salary
--------------------------------------------------------------------
--                                                                --
-- NAME:  get_cost_allocation          (PROCEDURE)                --
--                                                                --
--     DESCRIPTION:         PROCEDURE called by other PROCEDUREs  --
--                           to return cost allocation segments   --
--                                                                --
--     CHANGE HISTORY                                             --
--                                                                --
--     CHANGED BY        Date        REASON FOR CHANGE           --
--     ----------        ----        -----------------            --
--     Vijay Mayadam   17-Jan-2005  Initial Creation              --
--                                                                --
--     CHANGED BY        Date        REASON FOR CHANGE           --
--     ----------        ----        -----------------            --
--    Arun Jayaraman   24-Jan-2005  COuntry specIFic creation     --
--                                                                --
--------------------------------------------------------------------
PROCEDURE get_cost_allocation(iv_assignment_id         in number,
 			      ov_client		       out varchar2
      			--    ov_location	       out varchar2
                              )  is
-- Ken Mod 8/22/05 changed to OV_DEPT2 and OV_DEPT1 variables as varchar2(60)
--          OV_DEPT2 number := NULL;
--          OV_DEPT1 NUMBER := NULL;
          OV_DEPT2 varchar2(60) := NULL;
          OV_DEPT1 varchar2(60) := NULL;
BEGIN
	  SELECT CAKF.segment2
	  INTO   OV_DEPT2
	 -- FROM	 hr.pay_cost_allocations_f PCAF,		-- Commented code by IXPRAVEEN-ARGANO, 02-May-2023
	 --        hr.pay_cost_allocation_keyflex CAKF		-- Commented code by IXPRAVEEN-ARGANO, 02-May-2023
	  FROM	 apps.pay_cost_allocations_f PCAF,			--  code Added by IXPRAVEEN-ARGANO, 02-May-2023
	         apps.pay_cost_allocation_keyflex CAKF		--  code Added by IXPRAVEEN-ARGANO, 02-May-2023
	  WHERE  PCAF.cost_allocation_keyflex_id = CAKF.cost_allocation_keyflex_id
	  AND 	 trunc(g_cut_off_date) BETWEEN PCAF.effective_start_date AND PCAF.effective_END_date
	  AND 	 PCAF.assignment_id = iv_assignment_id;
	  OV_DEPT1 := OV_DEPT2 ;
	IF   (ov_dept2='9500')  or (ov_dept2='0000') THEN
	SELECT CAKF.segment3
	INTO   OV_DEPT1
        -- FROM	 hr.pay_cost_allocations_f PCAF,		-- Commented code by IXPRAVEEN-ARGANO, 02-May-2023
	 --        hr.pay_cost_allocation_keyflex CAKF		-- Commented code by IXPRAVEEN-ARGANO, 02-May-2023
	  FROM	 apps.pay_cost_allocations_f PCAF,			--  code Added by IXPRAVEEN-ARGANO, 02-May-2023
	         apps.pay_cost_allocation_keyflex CAKF		--  code Added by IXPRAVEEN-ARGANO, 02-May-2023
	WHERE  PCAF.cost_allocation_keyflex_id = CAKF.cost_allocation_keyflex_id
	AND    trunc(g_cut_off_date) BETWEEN PCAF.effective_start_date AND PCAF.effective_END_date
	AND    PCAF.assignment_id = iv_assignment_id;
        END IF;
	 IF ov_dept1 IS NOT NULL THEN
           OV_CLIENT := OV_DEPT1;
	  ELSE
	  SELECT CAKF.segment3
	  INTO 	 OV_DEPT1
	  --START R12.2 Upgrade Remediation
          /*FROM   hr.per_all_assignments_f paaf,			-- Commented code by IXPRAVEEN-ARGANO, 02-May-2023
	         hr.pay_cost_allocation_keyflex CAKF,*/
			 FROM   apps.per_all_assignments_f paaf,			--  code Added by IXPRAVEEN-ARGANO, 02-May-2023
	         apps.pay_cost_allocation_keyflex CAKF,
			 --END R12.2.10 Upgrade remediation
	         hr_all_organization_units  HAOU
          WHERE  haou.organization_id = paaf.organization_id
	  AND 	 trunc(g_cut_off_date) BETWEEN  paaf.effective_start_date AND paaf.effective_END_date
	  AND    cakf.cost_allocation_keyflex_id = HAOU.cost_allocation_keyflex_id
	  AND 	 Paaf.assignment_id = iv_assignment_id;
  		IF OV_DEPT1 IS NOT NULL THEN
  	  	   OV_CLIENT := OV_DEPT1;
                 END IF;
	 END IF;
EXCEPTION
  when too_many_rows then
--  ov_client := 'More than one Costing record exists';
--  ov_cost_segment3 := 'More than one Costing record exists';
	ov_client:='9500';
  WHEN OTHERS THEN
    --     ov_client   := null;
    --    OV_location := null;
	OV_CLIENT := OV_DEPT2;
END;  -- PROCEDURE  get_cost_allocation
--------------------------------------------------------------------
--                                                                --
-- NAME:  get_location          (PROCEDURE)                       --
--                                                                --
--     DESCRIPTION:         PROCEDURE called by other PROCEDUREs  --
--                           to return cost allocation segments   --
--                                                                --
--     CHANGE HISTORY                                             --
--                                                                --
--     CHANGED BY        Date        REASON FOR CHANGE            --
--     ----------        ----        -----------------            --
--     Vijay Mayadam   17-Jan-2005  Initial Creation              --
--                                                                --
--     CHANGED BY        Date        REASON FOR CHANGE            --
--     ----------        ----        -----------------            --
--    Arun Jayaraman   24-Jan-2005  COuntry specIFic creation     --
--                                                                --
--------------------------------------------------------------------
PROCEDURE get_location(iv_assignment_id         in number,
      			      ov_location	       out varchar2
					  					   	   			)  is
		ov_soft_code_id			 number;
		ov_segment1				 VARCHAR2(150);
	BEGIN
					  SELECT PAAF.SOFT_CODING_KEYFLEX_ID,
					  		 HSCK.SEGMENT1
				  INTO  OV_SOFT_CODE_ID,
				  		OV_SEGMENT1
					  FROM PER_ALL_ASSIGNMENTS_F PAAF,
					  	   HR_SOFT_CODING_KEYFLEX HSCK
					  WHERE PAAF.ASSIGNMENT_ID=IV_ASSIGNMENT_ID
					  AND    trunc(g_cut_off_date) BETWEEN
			 					   PAAF.effective_start_date AND PAAF.effective_END_date
					  AND PAAF.SOFT_CODING_KEYFLEX_ID= HSCK.SOFT_CODING_KEYFLEX_ID;
	IF OV_SEGMENT1='1637' THEN
	  		SELECT HLA.attribute4
	  		INTO ov_location
	  		FROM hr_locations_all 	   	HLA,
	             per_all_Assignments_f PAAF
	  	    WHERE
	  		  	    PAAF.assignment_id= iv_assignment_id
	  		 AND    trunc(g_cut_off_date) BETWEEN
			 					   PAAF.effective_start_date AND PAAF.effective_END_date
	         AND	 PAAF.location_id=HLA.location_id ;
	ELSIF OV_SEGMENT1='1651' THEN
	  		SELECT HLA.attribute6
	  		INTO ov_location
	  		FROM hr_locations_all 	   	HLA,
	             per_all_Assignments_f PAAF
	  	    WHERE
	  		  	    PAAF.assignment_id= iv_assignment_id
	  		 AND    trunc(g_cut_off_date) BETWEEN
			 					   PAAF.effective_start_date AND PAAF.effective_END_date
	         AND	 PAAF.location_id=HLA.location_id ;
	ELSIF OV_SEGMENT1='1654' THEN
	  		SELECT HLA.attribute9
	  		INTO ov_location
	  		FROM hr_locations_all 	   	HLA,
	             per_all_Assignments_f PAAF
	  	    WHERE
	  		  	    PAAF.assignment_id= iv_assignment_id
	  		 AND    trunc(g_cut_off_date) BETWEEN
			 					   PAAF.effective_start_date AND PAAF.effective_END_date
	         AND	 PAAF.location_id=HLA.location_id ;
END IF;
EXCEPTION
  WHEN OTHERS THEN
    OV_location := null;
END;  -- PROCEDURE  get_location
--------------------------------------------------------------------
--                                                                --
-- NAME:  get_cost_allocation department         (PROCEDURE)                --
--                                                                --
--     DESCRIPTION:         PROCEDURE called by other PROCEDUREs  --
--                           to return cost allocation segments   --
--                                                                --
--     CHANGE HISTORY                                             --
--                                                                --
--     CHANGED BY        Date        REASON FOR CHANGE           --
--     ----------        ----        -----------------            --
--     Vijay Mayadam   17-Jan-2005  Initial Creation              --
--                                                                --
--     CHANGED BY        Date        REASON FOR CHANGE           --
--     ----------        ----        -----------------            --
--    Arun Jayaraman   24-Jan-2005  COuntry specIFic creation     --
--                                                                --
--------------------------------------------------------------------
PROCEDURE get_dept (iv_assignment_id         in number,
 		    ov_department	     out varchar2)
      			      is
BEGIN
	  SELECT
		CAKF.segment3
	 INTO
	     ov_department
	  FROM
	  --START R12.2 Upgrade Remediation
	  /*hr.pay_cost_allocations_f PCAF,		-- Commented code by IXPRAVEEN-ARGANO, 02-May-2023
	  hr.pay_cost_allocation_keyflex CAKF*/
	  apps.pay_cost_allocations_f PCAF,		--  code Added by IXPRAVEEN-ARGANO, 02-May-2023
	  apps.pay_cost_allocation_keyflex CAKF
	  --END R12.2.10 Upgrade remediation
	  WHERE
	  	PCAF.cost_allocation_keyflex_id = CAKF.cost_allocation_keyflex_id
	  AND 	trunc(g_cut_off_date) BETWEEN
		PCAF.effective_start_date AND PCAF.effective_END_date
	  AND 	PCAF.assignment_id = iv_assignment_id;
EXCEPTION
  WHEN OTHERS THEN
    ov_department:=null;
END;  -- PROCEDURE  get_cost_a_dept
--------------------------------------------------------------------
--                                                                --
-- NAME:  get_bank          (PROCEDURE)                           --
--                                                                --
--     DESCRIPTION:         FUNCTION called by other PROCEDUREs   --
--                           to return bank inFORmation           --
--                                                                --
--     CHANGE HISTORY                                             --
--                                                                --
--     CHANGED BY        Date        REASON FOR CHANGE           --
--     ----------        ----        -----------------            --
--     Vijay Mayadam   17-Jan-2005  Initial Creation             --
--                                                                --
--     CHANGED BY        Date        REASON FOR CHANGE           --
--     ----------        ----        -----------------            --
--    Arun Jayaraman   24-Jan-2005  COuntry specIFic creation     --
--                                                                --
--------------------------------------------------------------------
PROCEDURE get_bank(iv_assignment_id   in  number,
		    ov_org_payment_method_id out varchar2 ) is
BEGIN
  SELECT
	DECODE (POPMF.org_payment_method_id, '153','001',
   						   '152','002',
   							 '001')org_payment_method_id
  INTO
	ov_org_payment_method_id
	FROM
	--START R12.2 Upgrade Remediation
	/*hr.pay_personal_payment_methods_f PPPMF,  -- Commented code by IXPRAVEEN-ARGANO, 02-May-2023
        hr.pay_external_accounts PEA,
	hr.pay_org_payment_methods_f POPMF*/
	apps.pay_personal_payment_methods_f PPPMF,		--  code Added by IXPRAVEEN-ARGANO, 02-May-2023
        apps.pay_external_accounts PEA,
	apps.pay_org_payment_methods_f POPMF
	--END R12.2.10 Upgrade remediation
  WHERE
	PPPMF.assignment_id = iv_assignment_id
  AND   trunc(g_cut_off_date) between PPPMF.effective_start_date AND PPPMF.effective_END_date
  AND   PPPMF.external_account_id = PEA.external_account_Id(+)
  AND   PPPMF.org_payment_method_id = POPMF.org_payment_method_id
  AND   trunc(g_cut_off_date) between POPMF.effective_start_date AND POPMF.effective_END_date
  AND   POPMF.business_group_id=g_business_group_id;
EXCEPTION
when too_many_rows then
  	ov_org_payment_method_id		:= 'More than one Pay Method record exists';
   WHEN OTHERS THEN
	ov_org_payment_method_id			:= '001';
END;  -- PROCEDURE get_bank
--------------------------------------------------------------------
--                                                                --
-- NAME:  get_payroll_process          (PROCEDURE)                --
--                                                                --
--     DESCRIPTION:         FUNCTION called by other PROCEDUREs   --
--                           to return bank inFORmation           --
--                                                                --
--     CHANGE HISTORY                                             --
--                                                                --
--     CHANGED BY        Date        REASON FOR CHANGE           --
--     ----------        ----        -----------------            --
--     Vijay Mayadam   17-Jan-2005  Initial Creation             --
--                                                                --
--     CHANGED BY        Date        REASON FOR CHANGE           --
--     ----------        ----        -----------------            --
--    Arun Jayaraman   24-Jan-2005  COuntry specIFic creation     --
--                                                                --
--------------------------------------------------------------------
PROCEDURE get_payroll_process(iv_assignment_id   in  number,
		    ov_payroll_process out varchar2 ) is
			t_employee_category	   		varchar2(150);
			t_name						varchar2(150);
			t_meaning					varchar2(150);
	 BEGIN
	 SELECT
--	 PAAF.employee_category,
--	 HAOU.NAME,
 decode( haou.name,
	Decode(ltrim(rtrim(flv.meaning,' '),' '),'PERSONAL DE OPERACIONES','SSI'),'007',
	Decode(ltrim(rtrim(flv.meaning,' '),' '),'PERSONAL ADMINISTRATIVO','SSI'),'008', --WO#159215  Added By C. Chan on Jan 25,2006
Decode(ltrim(rtrim(flv.meaning,' '),' '),'PERSONAL DE OPERACIONES','SERVICIOS Y ADMINISTRACIONES DEL BAJIO'),'004',
Decode(ltrim(rtrim(flv.meaning,' '),' '),'PERSONAL DE OPERACIONES','APOYO EMPRESARIAL DE SERVICIOS'),'001',
Decode(ltrim(rtrim(flv.meaning,' '),' '),'PERSONAL ADMINISTRATIVO','SERVICIOS Y ADMINISTRACIONES DEL BAJIO'),'005',
Decode(ltrim(rtrim(flv.meaning,' '),' '),'PERSONAL ADMINISTRATIVO','APOYO EMPRESARIAL DE SERVICIOS'),'002',
'000'
) t_payroll_process
	INTO
--	t_employee_Category,
--	t_name,
	ov_payroll_process
		FROM
	PER_ALL_ASSIGNMENTS_F	PAAF,
   	HR_ALL_ORGANIZATION_UNITS  HAOU,
	FND_lOOKUP_VALUES          FLV,
	HR_SOFT_CODING_KEYFLEX     HSCK
  WHERE
	 PAAF.assignment_id = iv_assignment_id
  AND   trunc(G_CUT_OFF_dATE) between PAAF.effective_start_date AND PAAF.effective_END_date
  AND	 FLV.lookup_code = paaf.employee_category
AND     FLV.SECURITY_GROUP_ID=(SELECT security_group_id
									  FROM   fnd_security_groups_vl
									  WHERE  security_group_name = 'TeleTech Holdings - MEX')
-- '25'  g_security_group_id
AND FLV.LOOKUP_TYPE='EMPLOYEE_CATG'
AND FLV.LANGUAGE='ESA'
AND FLV.TAG='+MX'
AND PAAF.SOFT_CODING_KEYFLEX_ID=HSCK.SOFT_CODING_KEYFLEX_ID
AND HSCK.SEGMENT1=HAOU.ORGANIZATION_ID ;
 -- fnd_file.put_line(fnd_file.log,'payroll process'||ov_payroll_process);
EXCEPTION
WHEN OTHERS THEN
ov_payroll_process:='000';
END;  -- PROCEDURE get_payroll_process
/*
--------------------------------------------------------------------
--                                                                --
-- NAME:  get_person_extra_info         (PROCEDURE)               --
--                                                                --
--     DESCRIPTION:         FUNCTION called by other PROCEDUREs   --
--                           to return person extra inFORmation   --
--                                                                --
--     CHANGE HISTORY                                             --
--                                                                --
--     CHANGED BY        Date        REASON FOR CHANGE           --
--     ----------        ----        -----------------            --
--     Vijay Mayadam   17-Jan-2005  Initial Creation             --
--                                                                --
--     CHANGED BY        Date        REASON FOR CHANGE           --
--     ----------        ----        -----------------            --
--    Arun Jayaraman   24-Jan-2005  COuntry specIFic creation     --
--                                                                --
--------------------------------------------------------------------
PROCEDURE  get_person_extra_info
		   			(iv_person_id   in number,
 					ov_pei_attribute1 out varchar2) is
BEGIN
SELECT p.pei_attribute1 INTO ov_pei_attribute1
FROM hr.per_people_extra_info p
WHERE p.person_extra_info_id in
	  (SELECT max(person_extra_info_id)
	  FROM hr.per_people_extra_info s
	  WHERE s.person_id=iv_person_id
	  AND s.pei_attribute_category='TTE_AR_HR_AFILIACION_ENTIDADES');
EXCEPTION
   WHEN OTHERS THEN
	ov_pei_attribute1	:= null;
END;  -- FUNCTION get_person_extra_info
*/
/*
--------------------------------------------------------------------
--                                                                --
-- NAME:  get_contract_info         (PROCEDURE)                   --
--                                                                --
--     DESCRIPTION:         FUNCTION called by other PROCEDUREs   --
--                           to return contract inFORmation       --
--                                                                --
--     CHANGE HISTORY                                             --
--                                                                --
--     CHANGED BY        Date        REASON FOR CHANGE           --
--     ----------        ----        -----------------            --
--     Vijay Mayadam   17-Jan-2005  Initial Creation             --
--                                                                --
--     CHANGED BY        Date        REASON FOR CHANGE           --
--     ----------        ----        -----------------            --
--    Arun Jayaraman   24-Jan-2005  COuntry specIFic creation     --
--                                                                --
--------------------------------------------------------------------
PROCEDURE  get_contract_info
		   			(iv_person_id   in  number,
					iv_start_date  in date,
 					ov_contract_type out varchar2,
					ov_sijp_vig	out date ) is
v_start_date date;
v_duration	 varchar2(60);
v_duration_units varchar2(60);
BEGIN
SELECT type,
	   duration,
	   duration_units
	   INTO
	   ov_contract_type,
	   v_duration,
	   v_duration_units
	   FROM hr.per_contracts_f pc
	   WHERE pc.person_id = iv_person_id
	   AND trunc(g_cut_off_date) between pc.effective_start_date AND pc.effective_END_date;
	   BEGIN
	   v_start_date := iv_start_date;
	   IF v_duration is not null AND v_duration_units is not null
	   THEN
	   	 		  BEGIN
				  	  IF v_duration_units = 'Y'
			  		  THEN v_duration := v_duration*12;
			       	  ov_sijp_vig := add_months(v_start_date, v_duration);
			  		  ELSIF v_duration_units = 'M'
			  		  THEN ov_sijp_vig := add_months(v_start_date, v_duration);
			  		  ELSIF v_duration_units = 'W'
			  		  THEN v_duration := v_duration*7;
			       	  ov_sijp_vig := (ov_sijp_vig + v_duration);
			  		  END IF;
			  		  END;
		END IF;
		END;
EXCEPTION
	   WHEN OTHERS THEN
	ov_cONtract_type	:= null;
	ov_sijp_vig	:= null;
END;  -- PROCEDURE get_contract_info
*/
--------------------------------------------------------------------
--  Section 1                                                              --
-- NAME:  extract_new_hires            (PROCEDURE)                --
--                                                                --
--     DESCRIPTION:         PROCEDURE called by the main          --
--               PROCEDURE to extract Basic Employee Data Changes --
--                                                                --
--                                                                --
--     CHANGE HISTORY                                             --
--                                                                --
--     CHANGED BY        Date        REASON FOR CHANGE           --
--     ----------        ----        -----------------            --
--     Vijay Mayadam   17-Jan-2005  Initial Creation              --
--                                                                --
--     CHANGED BY        Date        REASON FOR CHANGE           --
--     ----------        ----        -----------------            --
--    Arun Jayaraman   24-Jan-2005  COuntry specIFic creation     --
--                                                                --
--------------------------------------------------------------------
--new_hires--
PROCEDURE new_hire is
CURSOR n_chg is
SELECT *
--FROM   cust.ttec_mex_pay_interface_mst a		-- Commented code by IXPRAVEEN-ARGANO, 02-May-2023
FROM   apps.ttec_mex_pay_interface_mst a		--  code Added by IXPRAVEEN-ARGANO, 02-May-2023
WHERE  trunc(a.CUT_OFF_DATE) = trunc(g_cut_off_date)
AND    system_person_type = 'EMP'
and not exists (select 'x'
                  -- from   cust.ttec_mex_pay_interface_mst s		-- Commented code by IXPRAVEEN-ARGANO, 02-May-2023
				   from   apps.ttec_mex_pay_interface_mst s			--  code Added by IXPRAVEEN-ARGANO, 02-May-2023
                   where  person_id = a.person_id
				   and    trunc(s.cut_off_date) != (select max(trunc(cut_off_date))
				                           from   cust.ttec_mex_pay_interface_mst
										   where  person_id = s.person_id
										   and    trunc(cut_off_date) < trunc(g_cut_off_date)))
union
--rehires-
SELECT *
--FROM   cust.ttec_mex_pay_interface_mst a		-- Commented code by IXPRAVEEN-ARGANO, 02-May-2023
FROM   apps.ttec_mex_pay_interface_mst a		--  code Added by IXPRAVEEN-ARGANO, 02-May-2023
WHERE  trunc(a.CUT_OFF_DATE) = trunc(g_cut_off_date)
AND    system_person_type = 'EMP'
AND    exists (SELECT 'x'
				-- from   cust.ttec_mex_pay_interface_mst s		-- Commented code by IXPRAVEEN-ARGANO, 02-May-2023
                   FROM   apps.ttec_mex_pay_interface_mst s		--  code Added by IXPRAVEEN-ARGANO, 02-May-2023
                   WHERE  s.person_id = a.person_id
				   AND    s.system_person_type = 'EX_EMP'
				   AND    trunc(s.CUT_OFF_DATE) < trunc(g_cut_off_date))
  -- ;
 AND apps.ttec_mex_intf_util.Record_Changed_V ('REHIRE', a.person_id, a.assignment_id, trunc(g_cut_off_date)) = 'Y'
union
--Term/rehires next day
SELECT *
--FROM   cust.ttec_mex_pay_interface_mst a		-- Commented code by IXPRAVEEN-ARGANO, 02-May-2023
FROM   apps.ttec_mex_pay_interface_mst a		--  code Added by IXPRAVEEN-ARGANO, 02-May-2023
WHERE  trunc(a.CUT_OFF_DATE) = trunc(g_cut_off_date)
AND    system_person_type = 'EMP'
AND    exists (SELECT 'x'
					-- from   cust.ttec_mex_pay_interface_mst s		-- Commented code by IXPRAVEEN-ARGANO, 02-May-2023
                   FROM   apps.ttec_mex_pay_interface_mst s			--  code Added by IXPRAVEEN-ARGANO, 02-May-2023
                   WHERE  s.person_id = a.person_id
				   AND    s.system_person_type = 'EMP'
				   AND    trunc(s.CUT_OFF_DATE) < trunc(g_cut_off_date))
  -- ;
 AND apps.ttec_mex_intf_util.Record_Changed_n ('ASSIGNMENT', a.person_id, a.assignment_id, trunc(g_cut_off_date)) = 'Y' ;
v_output                 varchar2(4000);
BEGIN
--  Print_line('** Extract FOR  New Hires,  Rehires ( Section 1)**');
  FOR r_chg in n_chg
	LOOP
	  v_output := delimit_text(iv_number_of_fields  => 42,
	iv_field1	         =>    	r_chg.Employee_code	,
	iv_field2	         =>    	r_chg.Active		,
	iv_field3	         =>    	r_chg.Paternal_name	,
	iv_field4	         =>    	r_chg.Maternal_name	,
	iv_field5	         =>    	r_chg.First_name	,
-- Ken Mod 6/24/05 take out dashes in RFC
	iv_field6	         =>    	replace(r_chg.RFC,'-')  ,
	iv_field7	         =>    	r_chg.Sex		,
	iv_field8	         =>    	r_chg.Marital_status	,
	iv_field9	         =>    	r_chg.street		,
--	iv_field10	         =>    	r_chg.Ext_int_number	,   Change by PH per Andy's note 04/27
	iv_field10	         =>    	r_chg.Residential_district,
	iv_field11	         =>    	r_chg.Zip_code		,
--	iv_field12	         =>    	r_chg.Residential_district, Change by PH per Andy's note 04/27
	iv_field12	         =>    	r_chg.Ext_int_number	,
	iv_field13	         =>    	r_chg.City		,
	iv_field14	         =>    	r_chg.State		,
	iv_field15	         =>    	r_chg.Telefone		,
	iv_field16	         =>    	replace(r_chg.nationality,'PQH_'),--r_chg.Nationality	,
	iv_field17	         =>    	r_chg.Place_of_birth	,
	iv_field18	         =>    	r_chg.State_of_birth	,
	iv_field19	         =>    	r_chg.IMSS_number	,
	iv_field20	         =>    	r_chg.CURP		,
	iv_field21	         =>    	r_chg.Family_Medical_Center	,
	iv_field22	         =>    	r_chg.Work_day		,
	iv_field23	         =>    	r_chg.Compensation_type	,
	iv_field24	         =>    	r_chg.Pay_tables	,
	iv_field25	         =>    	r_chg.Table_levels	,
	iv_field26	         =>    	r_chg.Shift		,
	iv_field27	         =>    	r_chg.Contract_type	,
	iv_field28	         =>    	to_char(r_chg.Contract_start_date,'dd/mm/yyyy'),
	iv_field29	         =>    	to_char(r_chg.Contract_end_date	,'dd/mm/yyyy'),
	iv_field30	         =>    	r_chg.Salary_type	,
	iv_field31	         =>    	r_chg.Payroll_process	,
	iv_field32	         =>    	r_chg.Work_force	,
	iv_field33	         =>    	to_char(r_chg.Hire_date	,'dd/mm/yyyy'),
	iv_field34	         =>    	to_char(r_chg.Seniority_date,'dd/mm/yyyy')	,
	iv_field35	         =>    	r_chg.Salary		,
	iv_field36	         =>    	r_chg.job		,
	iv_field37	         =>    	r_chg.client		,
	iv_field38	         =>    	r_chg.Location		,
	iv_field39	         =>    	r_chg.Accounting_equivalence	,
	iv_field40	         =>    	r_chg.Oracle_number	,
	iv_field41	         =>    	r_chg.Organization_level
				  );
      print_line(v_output);
	--  fnd_file.put_line(fnd_file.log,'New hire ='	|| r_chg.Employee_code);  -- Test case
  END loop; -- c_curr
END; -- END PROCEDURE new_hire
--------------------------------------------------------------------
--  Section 2                                                              --
-- NAME:  extract_emp_changes          (PROCEDURE)                --
--                                                                --
--     DESCRIPTION:         PROCEDURE called by the main          --
--               PROCEDURE to extract Basic Employee Data Changes --
--                                                                --
--                                                                --
--     CHANGE HISTORY                                             --
--                                                                --
--     CHANGED BY        Date        REASON FOR CHANGE           --
--     ----------        ----        -----------------            --
--     Vijay Mayadam   17-Jan-2005  Initial Creation              --
--                                                                --
--     CHANGED BY        Date        REASON FOR CHANGE           --
--     ----------        ----        -----------------            --
--    Arun Jayaraman   24-Jan-2005  COuntry specIFic creation     --
--                                                                --
--------------------------------------------------------------------
PROCEDURE  extract_emp_changes is
CURSOR e_chg is
SELECT z.*
--,replace(z.nationality,'PQH_') chg_nationality
FROM
(SELECT *
--FROM   cust.ttec_mex_pay_interface_mst a		-- Commented code by IXPRAVEEN-ARGANO, 02-May-2023
FROM   apps.ttec_mex_pay_interface_mst a		--  code Added by IXPRAVEEN-ARGANO, 02-May-2023
WHERE  trunc(a.cut_off_date) = g_cut_off_date
AND    system_person_type = 'EMP'
AND
(
 apps.ttec_mex_intf_util.Record_Changed_V  ('EMPLOYEE_CODE' , a.person_id, a.assignment_id, trunc(g_cut_off_date)) = 'Y'
    OR
apps.ttec_mex_intf_util.Record_Changed_V  ('PATERNAL_NAME' , a.person_id, a.assignment_id, trunc(g_cut_off_date)) = 'Y'
	or
apps.ttec_mex_intf_util.Record_Changed_V  ('MATERNAL_NAME' , a.person_id, a.assignment_id, trunc(g_cut_off_date)) = 'Y'
	or
apps.ttec_mex_intf_util.Record_Changed_V  ('FIRST_NAME' , a.person_id, a.assignment_id, trunc(g_cut_off_date)) = 'Y'
	or
apps.ttec_mex_intf_util.Record_Changed_V  ('RFC' , a.person_id, a.assignment_id, trunc(g_cut_off_date)) = 'Y'
	or
apps.ttec_mex_intf_util.Record_Changed_V  ('SEX' , a.person_id, a.assignment_id, trunc(g_cut_off_date)) = 'Y'
	or
apps.ttec_mex_intf_util.Record_Changed_V  ('MARITAL_STATUS' , a.person_id, a.assignment_id, trunc(g_cut_off_date)) = 'Y'
	or
apps.ttec_mex_intf_util.Record_Changed_V  ('STREET' , a.person_id, a.assignment_id, trunc(g_cut_off_date)) = 'Y'
	or
apps.ttec_mex_intf_util.Record_Changed_V  ('EXT_INT_NUMBER' , a.person_id, a.assignment_id, trunc(g_cut_off_date)) = 'Y'
	or
apps.ttec_mex_intf_util.Record_Changed_V  ('ZIP_CODE' , a.person_id, a.assignment_id, trunc(g_cut_off_date)) = 'Y'
	or
apps.ttec_mex_intf_util.Record_Changed_V  ('RESIDENTIAL_DISTRICT' , a.person_id, a.assignment_id, trunc(g_cut_off_date)) = 'Y'
	or
apps.ttec_mex_intf_util.Record_Changed_V  ('CITY' , a.person_id, a.assignment_id, trunc(g_cut_off_date)) = 'Y'
	or
apps.ttec_mex_intf_util.Record_Changed_V  ('STATE' , a.person_id, a.assignment_id, trunc(g_cut_off_date)) = 'Y'
	or
apps.ttec_mex_intf_util.Record_Changed_V  ('TELEFONE' , a.person_id, a.assignment_id, trunc(g_cut_off_date)) = 'Y'
	or
apps.ttec_mex_intf_util.Record_Changed_V  ('NATIONALITY' , a.person_id, a.assignment_id, trunc(g_cut_off_date)) = 'Y'
	or
apps.ttec_mex_intf_util.Record_Changed_V  ('PLACE_OF_BIRTH' , a.person_id, a.assignment_id, trunc(g_cut_off_date)) = 'Y'
	or
apps.ttec_mex_intf_util.Record_Changed_V ('STATE_OF_BIRTH' , a.person_id, a.assignment_id, trunc(g_cut_off_date)) = 'Y'
	or
apps.ttec_mex_intf_util.Record_Changed_V  ('IMSS_NUMBER' , a.person_id, a.assignment_id, trunc(g_cut_off_date)) = 'Y'
	or
apps.ttec_mex_intf_util.Record_Changed_V  ('CURP' , a.person_id, a.assignment_id, trunc(g_cut_off_date)) = 'Y'
	or
apps.ttec_mex_intf_util.Record_Changed_V  ('FAMILY_MEDICAL_CENTER' , a.person_id, a.assignment_id, trunc(g_cut_off_date)) = 'Y'
	or
apps.ttec_mex_intf_util.Record_Changed_V  ('SHIFT' , a.person_id, a.assignment_id, trunc(g_cut_off_date)) = 'Y'
	or
	apps.ttec_mex_intf_util.Record_Changed_V  ('CONTRACT_TYPE' , a.person_id, a.assignment_id, trunc(g_cut_off_date)) = 'Y'
	or
	apps.ttec_mex_intf_util.Record_Changed_D ('CONTRACT_END_DATE' , a.person_id, a.assignment_id, trunc(g_cut_off_date)) = 'Y'
	or
	apps.ttec_mex_intf_util.Record_Changed_V  ('SALARY_TYPE' , a.person_id, a.assignment_id, trunc(g_cut_off_date)) = 'Y'
	or
	apps.ttec_mex_intf_util.Record_Changed_V ('WORK_FORCE' , a.person_id, a.assignment_id, trunc(g_cut_off_date)) = 'Y'
	or
	apps.ttec_mex_intf_util.Record_Changed_D ('SENIORITY_DATE' , a.person_id, a.assignment_id, trunc(g_cut_off_date)) = 'Y'
)
) z;
   -- order by z.attribute12;
v_output                 varchar2(4000);
BEGIN
--  Print_line('** Extract FOR  Basic Employee Data Changes (Section 2)**');
  FOR r_chg in e_chg loop
	  v_output := delimit_text(iv_number_of_fields  => 32,
		iv_field1	         =>    	r_chg.Employee_code		,
		iv_field2	         =>    	r_chg.Active			,
		iv_field3	         =>    	r_chg.Paternal_name		,
		iv_field4	         =>    	r_chg.Maternal_name		,
		iv_field5	         =>    	r_chg.First_name		,
-- Ken Mod 6/24/05 take out dashes in RFC
		iv_field6	         =>    	replace(r_chg.RFC, '-')         ,
		iv_field7	         =>    	r_chg.Sex			,
		iv_field8	         =>    	r_chg.Marital_status		,
		iv_field9	         =>    	r_chg.street			,
--	        iv_field10	         =>    	r_chg.Ext_int_number	,   Change by PH per Andy's note 04/27
        	iv_field10	         =>    	r_chg.Residential_district,
		iv_field11	         =>    	r_chg.Zip_code			,
--      	iv_field12	         =>    	r_chg.Residential_district, Change by PH per Andy's note 04/27
        	iv_field12	         =>    	r_chg.Ext_int_number	,
		iv_field13	         =>    	r_chg.City			,
		iv_field14	         =>    	r_chg.State			,
		iv_field15	         =>    	r_chg.Telefone			,
		iv_field16	         =>    	replace(r_chg.nationality,'PQH_'), --r_chg.chg_Nationality		,
		iv_field17	         =>    	r_chg.Place_of_birth		,
		iv_field18	         =>    	r_chg.State_of_birth		,
		iv_field19	         =>    	r_chg.IMSS_number		,
		iv_field20	         =>    	r_chg.CURP			,
		iv_field21	         =>    	r_chg.Family_Medical_Center	,
		iv_field22	         =>    	r_chg.Work_day			,
		iv_field23	         =>    	r_chg.Shift			,
		iv_field24	         =>    	r_chg.Contract_type		,
		iv_field25	         =>    	to_char(r_chg.Contract_start_date	,'dd/mm/yyyy'),
		iv_field26	         =>    	to_char(r_chg.Contract_end_date		,'dd/mm/yyyy'),
		iv_field27	         =>    	r_chg.Salary_type		,
		iv_field28	         =>    	r_chg.Work_force		,
		iv_field29	         =>    	to_char(r_chg.Hire_date,'dd/mm/yyyy'),
		iv_field30	         =>    	to_char(r_chg.Seniority_date,'dd/mm/yyyy'),
		iv_field31	         =>    	r_chg.Accounting_equivalence
							   );
--fnd_file.put_line(fnd_file.log,'emp changes for  ='	|| r_chg.Employee_code);  -- Test case
      print_line(v_output);
  END loop; -- c_curr
END; -- PROCEDURE extract_emp_changes
-------------------------------------------------------------------
--  Section 3                                                              --
-- NAME:  extract_asg_changes          (PROCEDURE)                --
--                                                                --
--     DESCRIPTION:         PROCEDURE called by the main          --
--               PROCEDURE to extract Employee Assignment Data Changes --
--                                                                --
--                                                                --
--     CHANGE HISTORY                                             --
--                                                                --
--     CHANGED BY        Date        REASON FOR CHANGE           --
--     ----------        ----        -----------------            --
--     Vijay Mayadam   17-Jan-2005  Initial Creation              --
--                                                                --
--     CHANGED BY        Date        REASON FOR CHANGE           --
--     ----------        ----        -----------------            --
--    Arun Jayaraman   24-Jan-2005  COuntry specIFic creation     --
--                                                                --
--------------------------------------------------------------------
PROCEDURE  extract_asg_changes is
CURSOR a_chg is
SELECT *
--FROM   cust.ttec_mex_pay_interface_mst a		-- Commented code by IXPRAVEEN-ARGANO, 02-May-2023
FROM   apps.ttec_mex_pay_interface_mst a		--  code Added by IXPRAVEEN-ARGANO, 02-May-2023
WHERE  trunc(a.cut_off_Date) = g_cut_off_date
AND    a.system_person_type = 'EMP'
AND
	(
apps.ttec_mex_intf_util.Record_Changed_V  ('JOB' , a.person_id, a.assignment_id, trunc(g_cut_off_date)) = 'Y'
	OR
apps.ttec_mex_intf_util.Record_Changed_V  ('DEPARTMENT_CODE' , a.person_id, a.assignment_id, trunc(g_cut_off_date)) = 'Y'
	OR
apps.ttec_mex_intf_util.Record_Changed_V  ('LOCATION' , a.person_id, a.assignment_id, trunc(g_cut_off_date)) = 'Y'
	OR
apps.ttec_mex_intf_util.Record_Changed_V  ('PAYROLL_PROCESS' , a.person_id, a.assignment_id, trunc(g_cut_off_date)) = 'Y'
	)  ;
	-- order by a.attribute12;
v_output                 varchar2(1000);
l_department_code        cust.ttec_mex_pay_interface_mst.department_code%TYPE;
BEGIN
--  Print_line('** Extract FOR  Employee assignment Data Changes (Section 3)**');
  FOR r_chg in a_chg loop
        /* Masking of Department_code to '000' if the length is less the 3. Per Andy's note on 18-Apr-05 */
         select decode(sign(length(r_chg.department_code)-3),-1,lpad(r_chg.department_code,3,'0'),r_chg.department_code)
         into   l_department_code
         from   dual;
	  v_output := delimit_text(iv_number_of_fields   => 8,
                                   iv_field1             =>    	r_chg.Employee_code		,
                                   iv_field2	         =>    	to_char(r_chg.Date_change_asg,'dd/mm/yyyy')		,
                                -- iv_field3	         =>    	r_chg.Job_code			,
                                   iv_field3	         =>    	r_chg.Job			,
                                -- iv_field4	         =>    	r_chg.Department_code		,   -- Change by PH per Andy's note on 18-Apr-2005
                                   iv_field4	         =>    	l_Department_code		,
                                   iv_field5	         =>    	r_chg.Location			,
                                   iv_field6	         =>    	r_chg.Organization_level	,
                                   iv_field7	         =>    	r_chg.Payroll_process
                                   );
      print_line(v_output);
  END loop; -- c_curr
END; -- PROCEDURE extract_ASG_changes
--------------------------------------------------------------------
--     Section 4                                                           --
-- NAME:  extract_salary_changes          (PROCEDURE)             --
--                                                                --
--     DESCRIPTION:         PROCEDURE called by the main          --
--                            PROCEDURE to extract salary         --
--                            changes                             --
--                                                                --
--                                                                --
--     CHANGE HISTORY                                             --
--                                                                --
--     CHANGED BY        Date        REASON FOR CHANGE           --
--     ----------        ----        -----------------            --
--     Vijay Mayadam   17-Jan-2005  Initial Creation             --
--                                                                --
--     CHANGED BY        Date        REASON FOR CHANGE           --
--     ----------        ----        -----------------            --
--    Arun Jayaraman   24-Jan-2005  COuntry specIFic creation     --
--                                                                --
--------------------------------------------------------------------
PROCEDURE  extract_salary_changes is
CURSOR c_chg is
SELECT *
--FROM   cust.ttec_mex_pay_interface_mst a		-- Commented code by IXPRAVEEN-ARGANO, 02-May-2023
FROM   apps.ttec_mex_pay_interface_mst a		--  code Added by IXPRAVEEN-ARGANO, 02-May-2023
WHERE  trunc(a.cut_off_Date) = trunc(g_cut_off_date)
and    a.system_person_type = 'EMP'
AND
( apps.ttec_mex_intf_util.Record_Changed_D  ('DATE_CHANGE_PAY' , a.person_id, a.assignment_id, trunc(g_cut_off_date)) = 'Y'
	OR
apps.ttec_mex_intf_util.Record_Changed_V  ('TYPE_CHANGE' , a.person_id, a.assignment_id, trunc(g_cut_off_date)) = 'Y'
	OR
apps.ttec_mex_intf_util.Record_Changed_N ('SALARY' , a.person_id, a.assignment_id, trunc(g_cut_off_date)) = 'Y'
	) ;
-- order by a.attribute12;
v_output                 varchar2(1000);
BEGIN
--  Print_line('** Extract FOR  Salary Data Changes (Section 4)**');
  FOR r_chg in c_chg loop
	  v_output := delimit_text(iv_number_of_fields  => 8,
		iv_field1	         =>    	r_chg.Employee_code	,
		iv_field2	         =>    	to_char(r_chg.Date_change_pay,'dd/mm/yyyy')	,
		iv_field3	         =>    	r_chg.Type_change	,
		iv_field4	         =>    	r_chg.Type_compensation	,
		iv_field5	         =>    	r_chg.Pay_tables	,
		iv_field6	         =>    	r_chg.Table_levels	,
		iv_field7	         =>    	r_chg.salary
							);
      print_line(v_output);
  END loop; -- c_curr
END; -- PROCEDURE extract_salary_changes
--------------------------------------------------------------------
--   Section 5                                                            --
-- NAME:  retrieve_terminations         (PROCEDURE)                --
--                                                                --
--     DESCRIPTION:         PROCEDURE called by the main          --
--               PROCEDURE to extract Basic Employee Data Changes --
--                                                                --
--                                                                --
--     CHANGE HISTORY                                             --
--                                                                --
--     CHANGED BY        Date        REASON FOR CHANGE           --
--     ----------        ----        -----------------            --
--     Vijay Mayadam   17-Jan-2005  Initial Creation              --
--                                                                --
--     CHANGED BY        Date        REASON FOR CHANGE           --
--     ----------        ----        -----------------            --
--    Arun Jayaraman   24-Jan-2005  COuntry specific creation     --
--                                                                --
--------------------------------------------------------------------
--Terminated employees--
PROCEDURE retrieve_terminations is
CURSOR t_chg is
SELECT *
--FROM   cust.ttec_mex_pay_interface_mst a		-- Commented code by IXPRAVEEN-ARGANO, 02-May-2023
FROM   apps.ttec_mex_pay_interface_mst a		--  code Added by IXPRAVEEN-ARGANO, 02-May-2023
WHERE  trunc(a.cut_off_date) = trunc(g_cut_off_date)
AND    SYSTEM_PERSON_TYPE='EX_EMP'
AND apps.ttec_mex_intf_util.Record_Changed_V ('SYSTEM_PERSON_TYPE' , a.person_id, a.assignment_id, trunc(g_cut_off_date)) = 'Y' ;
v_output                 varchar2(4000);
BEGIN
--  Print_line('** Extract FOR   Terminations (Section 5)**');
  FOR r_chg in t_chg loop
	  v_output := delimit_text(iv_number_of_fields  => 4,
		iv_field1	         =>    	r_chg.	Employee_code	,
		iv_field2	         =>    	r_chg.	Type_leave	,
		iv_field3	         =>    	to_char(r_chg.Date_leave,'dd/mm/yyyy')
			   );
      print_line(v_output);
  END loop; -- c_curr
END;  -- END PROCEDURE terminations
   -- ELEMENT
--------------------------------------------------------------------
--                                                                --
-- Name:  extract_elements_new      (Procedure)                   --
--                                                                --
--     Description:         Procedure called by the concurrent    --
--                            manager to extract elements         --
--                                                                --
--                                                                --
--     Change History                                             --
--                                                                --
--     Changed By        Date        Reason for Change            --
--     ----------        ----        -----------------            --
--     Vijay Mayadam   27-Jan-2005  Initial Creation             --
--                                                                --
--     Changed By        Date        Reason for Change            --
--     ----------        ----        -----------------            --
--     Arun Jayaraman  02-Feb-2005  Country Specific             --
--                                                                --
--                                                                --
--------------------------------------------------------------------
procedure extract_elements_new (iv_assignment_id       in number,
							iv_include_salary      in varchar2 ) is
cursor c_element(cv_assignment_id      number,
				 cv_include_salary     varchar2 ) is
-- Retrieves New element entries
select eletab.employee_code,
	   eletab.date_incidence,
	   eletab.hire_Date,
	   eletab.element_code,
	   eletab.department,
	 --  eletab.units,
	 --  eletab.amount,
	   eletab.screen_entry_value,
	   Decode(eletab.input_value_name, 'Hours', eletab.screen_entry_value) units,
	   Decode(eletab.input_value_name,'Pay Value', eletab.screen_entry_value) Amount,
	   null old_screen_entry_value,
	   'NEW' new_or_change
--from   cust.ttec_mex_pay_interface_ele eletab		-- Commented code by IXPRAVEEN-ARGANO, 02-May-2023
from   apps.ttec_mex_pay_interface_ele eletab		--  code Added by IXPRAVEEN-ARGANO, 02-May-2023
where  assignment_id = nvl(cv_assignment_id,assignment_id)
and    trunc(cut_off_Date) = trunc(g_cut_off_date)
and    eletab.element_code IS NOT NULL
 and    input_value_name in ('Hours','Pay Value')
/*
  and    (
 	    (nvl(creator_type,'XX') != 'SP' and iv_include_salary = 'N')
        or
 AND		(iv_include_salary = 'Y')
       )
*/
and    not exists (select 1
                   --from   cust.ttec_mex_pay_interface_ele eletab2		-- Commented code by IXPRAVEEN-ARGANO, 02-May-2023
				   from   apps.ttec_mex_pay_interface_ele eletab2		--  code Added by IXPRAVEEN-ARGANO, 02-May-2023
				   where  person_id = eletab.person_id
				   and    element_type_id = eletab.element_type_id
                                   and    element_entry_id = eletab.element_entry_id
                                   and    element_entry_value_id = eletab.element_entry_value_id
				   and    trunc(cut_off_date) = (select max(trunc(cut_off_Date))
				                                 --from   cust.ttec_mex_pay_interface_ele		-- Commented code by IXPRAVEEN-ARGANO, 02-May-2023
												 from   apps.ttec_mex_pay_interface_ele			--  code Added by IXPRAVEEN-ARGANO, 02-May-2023
								 where  person_id = eletab2.person_id
								 and    trunc(cut_off_Date) < trunc(g_cut_off_date)));
-- Ensuring that New Hire Elements get pulled just once
/*
and (    (cv_assignment_id is not null )
      or
	(cv_assignment_id is null and not exists (select 1
	                                      from cust.ttec_mex_pay_interface_mst
				      where  person_id = eletab.person_id and trunc(creation_date) < trunc(g_cut_off_date))
         )
     );
*/
v_output        varchar2(4000);
begin
  for r_element in c_element(iv_assignment_id,
							 iv_include_salary ) loop
      v_output := delimit_text(iv_number_of_fields      => 7,
	                           iv_field1                => r_element.employee_code,
	                           iv_field2                => r_element.element_code,
			  	   iv_field3                => to_char(r_element.date_incidence,'dd/mm/yyyy'),
                           --      iv_field4                => r_element.department,
				   iv_field4                => NULL,   -- Change by PH per Andy Becker's Mail on 13-APR-05
				   iv_field5                => r_element.units,
				   iv_field6                => r_element.amount
							   );
  	  print_line(v_output);

-- Ken Mod 8/24/05 Store data into temp table cust.ttec_mex_pay_interface_ele_tmp
-- the above table is used to genernate control totals
    insert into cust.ttec_mex_pay_interface_ele_tmp (
          emp_attribute12,
          ele_attribute1,
          units,
          Amount)
    values (
      r_element.employee_code,
      r_element.element_code,
      round(to_number(r_element.units),2),
      round(to_number(r_element.Amount),2)
    );

  end loop; -- c_element
end; -- extract_elements_new
--------------------------------------------------------------------
--                                                                --
-- Name:  extract_elements_chg      (Procedure)                   --
--                                                                --
--     Description:         Procedure called by the concurrent    --
--                            manager to extract elements         --
--                                                                --
--                                                                --
--     Change History                                             --
--                                                                --
--     Changed By        Date        Reason for Change            --
--     ----------        ----        -----------------            --
--     Vijay Mayadam   27-Jan-2005  Initial Creation             --
--                                                                --
--     Changed By        Date        Reason for Change            --
--     ----------        ----        -----------------            --
--     Arun Jayaraman  02-Feb-2005  Country Specific             --
--                                                                --
--------------------------------------------------------------------
procedure extract_elements_chg (iv_assignment_id       in number,
				iv_include_salary      in varchar2 ) is
cursor c_element(cv_assignment_id      number,
				 cv_include_salary     varchar2 ) is
-- retrieves changes to element entries
select eletab_curr.employee_code,
	   eletab_curr.oracle_number,
	   eletab_curr.date_incidence,
	   eletab_Curr.hire_Date,
	   eletab_curr.element_code,
	   eletab_curr.department,
	--   eletab.units,
	--   eletab.amount,
	   eletab_curr.screen_entry_value,
	   Decode(eletab_curr.INPUT_VALUE_NAME, 'Hours', eletab_curr.screen_entry_value) units,
	   Decode(eletab_curr.INPUT_VALUE_NAME,'Pay Value', eletab_curr.screen_entry_value) Amount,
	   eletab_past.screen_entry_value old_screen_entry_value,
	   'CHANGE' new_or_change
	   --START R12.2 Upgrade Remediation
/*from   cust.ttec_mex_pay_interface_ele eletab_curr,		-- Commented code by IXPRAVEEN-ARGANO, 02-May-2023
       cust.ttec_mex_pay_interface_ele eletab_past*/
from   apps.ttec_mex_pay_interface_ele eletab_curr,			--  code Added by IXPRAVEEN-ARGANO, 02-May-2023
       apps.ttec_mex_pay_interface_ele eletab_past	 
--END R12.2.10 Upgrade remediation	   
where  eletab_curr.assignment_id = nvl(cv_assignment_id,eletab_curr.assignment_id)
and    eletab_curr.input_value_name in ('Hours','Pay Value')
and    eletab_curr.person_id = eletab_past.person_id
and    eletab_curr.element_type_id = eletab_past.element_type_id
and    eletab_curr.input_value_id = eletab_past.input_value_id
and    eletab_curr.element_entry_id = eletab_past.element_entry_id
and    eletab_curr.element_entry_value_id  = eletab_past.element_entry_value_id
and    trunc(eletab_curr.cut_off_Date) = trunc(g_cut_off_date)
and    eletab_curr.element_code IS NOT NULL
and    eletab_past.element_code IS NOT NULL
/*
and    (   (nvl(eletab_curr.creator_type,'XX') != 'SP' and iv_include_salary = 'N'
           )
        or ( iv_include_salary = 'Y'
		   )
	   )
*/
and    trunc(eletab_past.cut_off_Date) = (select max(trunc(cut_off_Date))
                                          --from   cust.ttec_mex_pay_interface_ele		-- Commented code by IXPRAVEEN-ARGANO, 02-May-2023
												 from   apps.ttec_mex_pay_interface_ele			--  code Added by IXPRAVEEN-ARGANO, 02-May-2023
					  where  person_id = eletab_curr.person_id
					  and    trunc(cut_off_Date) < trunc(g_cut_off_date))
and    (eletab_curr.screen_entry_value != eletab_past.screen_entry_value
                              OR
        eletab_curr.date_incidence != eletab_past.date_incidence
        );
 -- or eletab_curr.ele_attribute1 != eletab_past.ele_attribute1);
v_output        varchar2(4000);
begin
--  Print_line('** Extract for Employee Change Element Entries Section(6) **');
  for r_element in c_element(iv_assignment_id,
							 iv_include_salary) loop
      v_output := delimit_text(iv_number_of_fields      => 7,
	                        iv_field1                => r_element.employee_code,
	                        iv_field2                => r_element.element_code,
			  	iv_field3                => to_char(r_element.date_incidence,'dd/mm/yyyy'),
			--	iv_field4                => r_element.department,
                                iv_field4                => NULL,   -- Change by PH per Andy Becker's Mail on 13-APR-05
				iv_field5                => r_element.units,
				iv_field6                => r_element.amount
							   );
  	  print_line(v_output);

-- Ken Mod 8/24/05 Store data into temp table cust.ttec_mex_pay_interface_ele_tmp
-- the above table is used to genernate control totals
    insert into cust.ttec_mex_pay_interface_ele_tmp (
          emp_attribute12,
          ele_attribute1,
          units,
          Amount)
    values (
      r_element.employee_code,
      r_element.element_code,
      round(to_number(r_element.units),2),
      round(to_number(r_element.Amount),2)
    );

  end loop; -- c_element
end; -- extract_elements_chg

--------------------------------------------------------------------
--                                                                --
-- Name:  extract_elements_ctl_tot      (Procedure)               --
--                                                                --
--     Description:     To product control totals from            --
--                     table cust.ttec_mex_pay_interface_ele_tmp  --
--                                                                --
--                                                                --
--     Change History                                             --
--                                                                --
--     Changed By        Date        Reason for Change            --
--     ----------        ----        -----------------            --
--                                                                --
--                                                                --
--------------------------------------------------------------------
procedure extract_elements_ctl_tot  is

cursor t_elements_ctl_tot is
Select
       ele_attribute1,
       sum (units) s_units,
       sum (Amount) s_Amount
  --from cust.ttec_mex_pay_interface_ele_tmp    -- Commented code by IXPRAVEEN-ARGANO, 02-May-2023
  from apps.ttec_mex_pay_interface_ele_tmp		--  code Added by IXPRAVEEN-ARGANO, 02-May-2023
 group by ele_attribute1;

v_output        varchar2(4000);

begin

fnd_file.put_line(fnd_file.log,'                           ');
fnd_file.put_line(fnd_file.log,'#######################################################');
fnd_file.put_line(fnd_file.log,'####### PAY CODES CONTROL TOTAL SECTION - BEGIN #######');
fnd_file.put_line(fnd_file.log,'##### Output format --> Pay_code@units@Amount     #####');

FOR r_elements_ctl_tot IN t_elements_ctl_tot LOOP

v_output := delimit_text(iv_number_of_fields          => 3,
                         iv_field1                => r_elements_ctl_tot.ele_attribute1,
                         iv_field2                => round(r_elements_ctl_tot.s_units,2),
                         iv_field3                => round(r_elements_ctl_tot.s_Amount,2)
                        );

fnd_file.put_line(fnd_file.log,v_output);

-- print_line(v_output);

END LOOP; -- t_elements_ctl_tot

fnd_file.put_line(fnd_file.log,'####### PAY CODES CONTROL TOTAL SECTION - END   #######');
fnd_file.put_line(fnd_file.log,'#######################################################');
fnd_file.put_line(fnd_file.log,'                           ');

EXCEPTION
  when others then
        g_retcode := SQLCODE;
        g_errbuf  := substr(SQLERRM,1,255);

        fnd_file.put_line(fnd_file.log,'extract_elements_ctl_tot Failed');
        fnd_file.put_line(fnd_file.log,substr(SQLERRM,1,255));

        raise g_e_abort;

end; -- extract_elements_ctl_tot

--------------------------------------------------------------------
--                                                                --
-- NAME:  INSERT_interface_table               (PROCEDURE)        --
--                                                                --
--     DESCRIPTION:         PROCEDURE called by the other         --
--                            PROCEDUREs to INSERT                --
--                            table ttec_mex_pay_interface_mst    --
--                                                                --
--                                                                --
--     CHANGE HISTORY                                             --
--                                                                --
--     CHANGED BY        Date        REASON FOR CHANGE           --
--     ----------        ----        -----------------            --
--     Vijay Mayadam   17-Jan-2005  Initial Creation              --
--                                                                --
--     CHANGED BY        Date        REASON FOR CHANGE           --
--     ----------        ----        -----------------            --
--    Arun Jayaraman   24-Jan-2005  COuntry specIFic creation     --
--                                                                --
--------------------------------------------------------------------
--PROCEDURE INSERT_interface_table (ir_interface    cust.ttec_mex_pay_interface_mst%rowtype) is		-- Commented code by IXPRAVEEN-ARGANO, 02-May-2023
PROCEDURE INSERT_interface_table (ir_interface    apps.ttec_mex_pay_interface_mst%rowtype) is		--  code Added by IXPRAVEEN-ARGANO, 02-May-2023
BEGIN
    --INSERT into cust.ttec_mex_pay_interface_mst (		-- Commented code by IXPRAVEEN-ARGANO, 02-May-2023
	INSERT into apps.ttec_mex_pay_interface_mst (		--  code Added by IXPRAVEEN-ARGANO, 02-May-2023
  payroll_id	,
 payroll_name                	,
 person_id                   	,
 person_creation_date        	,
 person_update_date          	,
 assignment_id               	,
 assignment_creation_date    	,
 assignment_update_date      	,
cut_off_date					,
 PAY_PERIOD_ID 	,
 person_type_id              	,
 PERIOD_OF_SERVICE_ID	,
 system_person_type          	,
 user_person_type            	,
 per_system_status           	,
creation_Date                         	,
last_extract_date                   	,
last_extract_file_type                 	,
status                              	,
Employee_code ,
Active	,
Paternal_name	,
Maternal_name	,
First_name	,
RFC	,
Sex	,
Marital_status	,
street	,
Ext_int_number	,
Zip_code	,
Residential_district	,
City	,
State	,
Telefone	,
Nationality	,
Place_of_birth	,
State_of_birth	,
IMSS_number	,
CURP	,
Family_Medical_Center	,
Work_day	,
Compensation_type	,
Pay_tables	,
Table_levels	,
Shift	,
Contract_type	,
Contract_start_date	,
Contract_END_date	,
Salary_type	,
Payroll_process	,
Work_force	,
Hire_date	,
Seniority_date	,
job	,
client	,
Location	,
Accounting_equivalence	,
Oracle_number	,
Organization_level	,
Date_change_asg	,
Job_code	,
department_code	,
Date_change_pay	,
Type_change	,
Type_compensation	,
salary	,
Type_leave	,
Date_leave
	)
	VALUES
	(
	ir_interface.payroll_id				,
ir_interface.payroll_name                	,
ir_interface.person_id                   	,
ir_interface.person_creation_date        	,
ir_interface.person_update_date          	,
ir_interface.assignment_id               	,
ir_interface.assignment_creation_date    	,
ir_interface.assignment_update_date      	,
g_cut_off_date								,
ir_interface.pay_period_id			  ,
ir_interface.person_type_id              	,
ir_interface.period_of_service_id	 		,
ir_interface.system_person_type          	,
ir_interface.user_person_type            	,
ir_interface.per_system_status        ,
ir_interface.creation_Date            ,
ir_interface.last_extract_date        ,
ir_interface.last_extract_file_type   ,
ir_interface.status                   ,
ir_interface.Employee_code 			   		,
ir_interface.active		   	 		  ,
ir_interface.Paternal_name			   		,
ir_interface.Maternal_name					,
ir_interface.First_name						,
ir_interface.RFC							,
ir_interface.Sex							,
ir_interface.Marital_status					,
ir_interface.street							,
ir_interface.Ext_int_number					,
ir_interface.Zip_code						,
ir_interface.Residential_district			,
ir_interface.City							,
ir_interface.State							,
ir_interface.Telefone						,
ir_interface.Nationality					,
ir_interface.Place_of_birth					,
ir_interface.state_of_birth			,
ir_interface.IMSS_number					,
ir_interface.CURP							,
ir_interface.Family_Medical_Center			,
ir_interface.Work_day				,
ir_interface.Compensation_type		,
ir_interface.Pay_tables				,
ir_interface.Table_levels			,
ir_interface.Shift							,
ir_interface.contract_type			,
ir_interface.Contract_start_date			,
ir_interface.contract_end_date		,
ir_interface.Salary_type			,
ir_interface.Payroll_process		,
ir_interface.Work_force				,
ir_interface.hire_Date				 		,
ir_interface.Seniority_date 				,
ir_interface.job							,
ir_interface.client					,
ir_interface.Location				,
ir_interface.Accounting_equivalence	,
ir_interface.Oracle_number			,
ir_interface.Organization_level		,
ir_interface.Date_change_asg				,
ir_interface.Job_code						,
ir_interface.department_code					,
ir_interface.Date_change_pay	,
ir_interface.Type_change	,
ir_interface.Type_compensation ,
ir_interface.salary,
ir_interface.Type_leave	,
ir_interface.Date_leave
	);
END;
--------------------------------------------------------------------
--                                                                --
-- Name:  insert_interface_ele               (Procedure)          --
--                                                                --
--     Description:         Procedure called by the other         --
--                            procedures to insert                --
--                            table ttec_mex_pay_interface_ele    --
--                                                                --
--                                                                --
--     Change History                                             --
--                                                                --
--     Changed By        Date        Reason for Change            --
--     ----------        ----        -----------------            --
--     Vijay Mayadam   24-Jan-2005  Initial Creation             --
--                                                                --
--                                                                --
--------------------------------------------------------------------
--procedure insert_interface_ele (ir_interface_ele       cust.ttec_mex_pay_interface_ele%rowtype) is  -- Commented code by IXPRAVEEN-ARGANO, 02-May-2023
procedure insert_interface_ele (ir_interface_ele       apps.ttec_mex_pay_interface_ele%rowtype) is   --  code Added by IXPRAVEEN-ARGANO, 02-May-2023
begin
  --insert into cust.ttec_mex_pay_interface_ele (		 -- Commented code by IXPRAVEEN-ARGANO, 02-May-2023
  insert into apps.ttec_mex_pay_interface_ele (			 --  code Added by IXPRAVEEN-ARGANO, 02-May-2023
	PAYROLL_ID,
	payroll_name,
--	PAY_PERIOD_ID,
	cut_off_date,
	PERSON_ID,
	ASSIGNMENT_ID,
	EMPLOYEE_CODE,
	ORACLE_NUMBER,
	ELEMENT_CODE,
	DEPARTMENT,
	DATE_INCIDENCE,
	HIRE_DATE,
	ELEMENT_NAME,
--	REPORTING_NAME,
	PROCESSING_TYPE,
	CLASSIFICATION_NAME,
	ELEMENT_TYPE_ID,
	ELEMENT_LINK_ID,
	ELEMENT_ENTRY_ID,
	ELEMENT_ENTRY_VALUE_ID,
uom,
uom_meaning,
	INPUT_VALUE_ID,
	INPUT_VALUE_NAME,
	SCREEN_ENTRY_VALUE,
	creator_type,
	ENTRY_EFFECTIVE_START_DATE,
	ENTRY_EFFECTIVE_END_DATE,
	CREATION_DATE,
	LAST_EXTRACT_DATE,
	LAST_EXTRACT_FILE_TYPE)
  values
  (
    ir_interface_ele.PAYROLL_ID,
	ir_interface_ele.payroll_name,
--	ir_interface_ele.PAY_PERIOD_ID,
	ir_interface_ele.cut_off_date,
	ir_interface_ele.PERSON_ID,
	ir_interface_ele.ASSIGNMENT_ID,
	ir_interface_ele.EMPLOYEE_code,
	ir_interface_ele.ORACLE_NUMBER,
	ir_interface_ele.ELEMENT_CODE,
    ir_interface_ele.DEPARTMENT,
	ir_interface_ele.DATE_INCIDENCE,
	ir_interface_ele.HIRE_DATE,
	ir_interface_ele.ELEMENT_NAME,
--	ir_interface_ele.REPORTING_NAME,
	ir_interface_ele.PROCESSING_TYPE,
	ir_interface_ele.CLASSIFICATION_NAME,
	ir_interface_ele.ELEMENT_TYPE_ID,
	ir_interface_ele.ELEMENT_LINK_ID,
	ir_interface_ele.ELEMENT_ENTRY_ID,
	ir_interface_ele.ELEMENT_ENTRY_VALUE_ID,
	ir_interface_ele.uom,
	ir_interface_ele.uom_meaning,
	ir_interface_ele.INPUT_VALUE_ID,
	ir_interface_ele.INPUT_VALUE_NAME,
	ir_interface_ele.SCREEN_ENTRY_VALUE,
	ir_interface_ele.creator_type,
	ir_interface_ele.ENTRY_EFFECTIVE_START_DATE,
	ir_interface_ele.ENTRY_EFFECTIVE_END_DATE,
	ir_interface_ele.CREATION_DATE,
	ir_interface_ele.LAST_EXTRACT_DATE,
	ir_interface_ele.LAST_EXTRACT_FILE_TYPE
	);
end; -- insert_interface_ele
-- ---------------------------------------------------------------------------
 -- Program to load TTEC Mexico Employee info  for Interface
 -- --------------------------------------------------------------------------
 -- Program Name       : load_interface_table
 -- Author             : Arun Jayaraman - AJ
 -- Creation Date      : 01/28/04
 --
 --		Modification log :
 --
 -- Updated by         : Arun Jayaraman
 -- Updated on         :
 -- Updates made       :
 -- ---------------------------------------------------------------------------
 -- ---------------------------------------------------------------------------
 -- ---------------------------------------------------------------------------
  Procedure load_interface_table is
 cursor c_emp is
select /*+ index(ppf) ordered use_nl(PPT) use_nl(paf) use_nl(PPAYF) use_nl(PPS) use_nl(past) use_nl(pj) use_nl(pjd) use_nl(haou) use_nl(hl)*/
                 PAPF.person_id			t_person_id
	,	 PAPF.creation_date 		t_person_creation_date
	,	 PAPF.last_update_date 		t_person_update_date
       	,        PAAF.assignment_id		t_assignment_id
	,	 PAAF.creation_date 		t_assignment_creation_date
	,	 PAAF.last_update_date 		t_assignment_update_date
--	,	 PPAYF.payroll_id		t_payroll_id
--	,	 PPAYF.payroll_name		t_payroll_name
  	,        PPT.person_type_id		t_person_type_id
        ,        PPT.system_person_type		t_system_person_type
        ,        PPT.user_person_type		t_user_person_type
        ,        PAST.per_system_status 	t_per_system_status
     --  Employee_info
	,	lpad(PAPF.attribute12,7,'0')        	t_Employee_code
	,	PAPF.Last_name	            		t_Paternal_name
	,	PAPF.Per_information1	            	t_Maternal_name
	,	PAPF.First_name||' '||papf.middle_names	t_First_name
	,	PAPF.Per_information2	            	t_RFC
	,	PAPF.sex	            		t_Sex
	,	DECODE(PAPF.Marital_status, 'M','C',
					    'D','D',
					    'BE_LIV_TOG','O',
					    'S','S',
					    'UL','U',
					    'W','V'  )	t_Marital_status
	,	PA.address_Line1	            	t_street
	,	PA.address_Line2	            	t_Ext_int_number
	,	PA.Postal_code	            		t_Zip_code
	,	PA.address_Line3	            	t_Residential_district
	,	PA.Town_or_city	            		t_City
	,	PA.Region_1	            		t_State
	,	PA.Telephone_number_1	            	t_Telefone
	,	PAPF.Nationality	            	t_Nationality
	,	PAPF.Town_of_birth	            	t_Place_of_birth
   	,	DECODE(PAPF.attribute7,
		       'AGS'  ,'001','BC'   ,'002','BCS'  ,'003','CAMP' ,'004','CHIH' ,'008',
                       'CHIS' ,'007','COAH' ,'005','COL'  ,'006','DF'   ,'009','DGO'  ,'010',
                       'GRO'  ,'012','GTO'  ,'011','HGO'  ,'013','JAL'  ,'014','MEX'  ,'015',
                       'MICH' ,'016','MOR'  ,'017','NAY'  ,'018','NL'   ,'019','OAX'  ,'020',
                       'PUE'  ,'021','QRO'  ,'022','QROO' ,'023','SIN'  ,'025','SLP'  ,'024',
                       'SON'  ,'026','TAB'  ,'027','TAMPS','028','TLAX' ,'029','VER'  ,'030',
                       'YUC'  ,'031','ZAC'  ,'032',NULL) t_State_of_birth
	,	PAPF.Per_information3	            	t_IMSS_number
	,	PAPF.National_identifier	        t_CURP
	,	PAPF.Per_information4		        t_Family_Medical_Center
   --	,	     --  Work_day	            	    t_Work_day		  -- Fixed '0'
   --	,	     --  Compensation_type	            t_Compensation_type	  -- Fixed 'A'
   --	,	     --   Pay_tables	            	    t_Pay_tables	  -- Blank
   --	,	    --   Table_levels	            	    t_Table_levels  	  -- Blank
	,	DECODE(PAAF.Ass_attribute7, 'Día','001',
					    'Noche', '003',
					    'Asalariado','004',
					    'Mixto', '005','000') t_Shift
   	, 	PAAF.Ass_attribute11	            t_Contract_type	  --  Need to confirm
--	,	PAPF.Start_date	            		t_Contract_start_date
	,	to_date(paaf.ass_attribute14,'yyyy/mm/dd hh24:mi:ss')   t_Contract_start_date
	,	to_date(paaf.ass_attribute12,'yyyy/mm/dd hh24:mi:ss') 	t_Contract_end_date  -- changed on 09-jun-2005 as per Andy
   --	,	DECODE(PPPMF.Org_payment_method_id '153','001',
   --						   '152','002',
   --							 '001') t_Salary_type     --  Look for procedure get_bank
   /*
   	,	     DECODE(PAAF.employee_category,		'PERSONAL DE OPERACIONES', '001',
			 									'PERSONAL ADMINISTRATIVO', '002',
												'PERSONAL DE OPERACIONES', '004',
												'PERSONAL ADMINISTRATIVO', '005',
												'PERSONAL DE OPERACIONES', '007',
														  	 			   '000') t_Payroll_process
   */
   	,	PAAF.Ass_attribute13 		t_Work_force		  --  Need to confirm
	,	PAPF.Start_date	            		t_Hire_date
	,	TO_DATE(PAAF.Ass_attribute10,'yyyy/mm/dd hh24:mi:ss')	    t_Seniority_date
	,	PJD.Segment1	            		t_job
   	--	,	CAKF.Segment2	            		t_client	--  Look for procedure get_cost_allocation
   	--	,	CAKF.Segment1	            		t_Location	--  Look for procedure get_cost_allocation
   --	,	    --Accounting_equivalence	            t_Accounting_equivalence
	,	PAPF.Employee_number	            	t_Oracle_number
   	,	DECODE(PJ.Attribute6,	'Vice-President 1','001',
					'Director 1',      '002',
					'Manager 2',	   '003',
					'Manager 1',	   '004',
					'Supervisor 1',    '005',
					'Non-Manager',	   '008',
							   '000') t_Organization_level
      --  Assignment_changes_job_changes
	,	PAAF.Effective_start_date	        t_Date_change_asg
	,	PAAF.Job_id	            		t_Job_code
   	--	,	CAKF.Segment2	            		t_Department_code    -- Look for procedure fet_cost_allocation
   	--	,	CAKF.Segment1	            		t_Location	     --  Look for procedure fet_cost_allocation
   --	,	   -- PJ.Attribute6	            		t_Organization_level --  Duplicate value
   --	,	   -- PAAF.payroll_process	            	t_Payroll_process	     --  Duplicate value
     --   Salary Changes
--	,	PPP.Change_date				t_Date_change_pay
--	,	PPP.Proposal_reason			t_Type_change		  -- Need to check with Delsip
   --	,	   --Type_of_compensation		    t_Type_compensation	  -- Fixed 'A'
--	,	PPP.Proposed_salary_n	            	t_salary
     --  Termination_info
	,	PPS.Leaving_reason	            	t_Type_leave	       	  -- Need to check with Delsip
	,	PPS.Actual_termination_date	        t_Date_leave
	,	PPS.period_of_service_id 			t_period_of_service_id
FROM
   		per_all_people_f 		PAPF
	,       per_person_types 		PPT
	,	per_all_assignments_f 		PAAF
	--,	hr.pay_all_payrolls_f 		ppayf				-- Commented code by IXPRAVEEN-ARGANO, 02-May-2023
	,	apps.pay_all_payrolls_f 		ppayf           --  code Added by IXPRAVEEN-ARGANO, 02-May-2023
	,	per_periods_of_service 		PPS
	,	per_assignment_status_types 	PAST
	,	per_jobs 			PJ
	,       per_job_definitions		PJD
	,	hr_all_organization_units 	HAOU
	,	per_addresses 			PA
       WHERE
	PAPF.business_group_id = G_BUSINESS_GROUP_ID
--	AND    PAPF.person_id = 186056    -- Test case
        AND    trunc(G_CUT_OFF_DATE) between PAPF.effective_start_date AND PAPF.effective_end_date
  	AND    PAPF.person_type_id = PPT.person_type_id
  	AND    PAPF.business_group_id = PPT.business_group_id
  	AND    PAPF.person_id = PAAF.person_id
    	AND    PAAF.assignment_type='E'
  and    paaf.payroll_id = ppayf.payroll_id(+)
  and    trunc(G_CUT_OFF_DATE) between ppayf.effective_start_date(+) and ppayf.effective_end_date(+)
  	AND    PAPF.person_id = PPS.person_id
  	AND    PPS.period_of_service_id = PAAF.period_of_service_id
  	AND    PPS.date_start = (select max(date_start)
                                from   per_periods_of_service
   				where  person_id = PAPF.person_id
  				AND    date_start <=  trunc(G_CUT_OFF_dATE))
  	AND    PAAF.assignment_status_type_id = PAST.assignment_status_type_id
  	AND    PAAF.job_id = pj.job_id(+)
  	and 	 pj.job_definition_id = pjd.job_definition_id(+)
   --        AND    trunc(G_CUT_OFF_dATE) between PAAF.effective_start_date AND PAAF.effective_end_date--
	AND    PAAF.effective_start_date = (select max(effective_start_date)
                                            from   per_assignments_f
   -- k                                        where  assignment_id = PAAF.assignment_id
                                            where person_id = PAPF.person_id                  -- Mod by Ken
					    AND    effective_start_date <= trunc(G_CUT_OFF_DATE))
  	AND    PAAF.organization_id = HAOU.organization_id
  	AND    PAPF.person_id = PA.person_id(+)
        AND    trunc(g_cut_off_date) between pa.date_from(+) and nvl(pa.date_to(+),trunc(g_cut_off_date))
	AND    PA.primary_flag(+) ='Y'
	ORDER BY PAPF.employee_number;
	CURSOR c_ele is
	select 	   /*+ ordered use_nl(papf) use_Nl(paaf) use_nl(ppayf) use_nl(peef) use_nl(peevf) use_nl(pelf) use_nl(petf) use_nl(pivf) use_nl(pec) */
       papf.person_id,
       lpad(PAPF.attribute12,7,'0')	   employee_code,
       papf.employee_number		   oracle_number,
       papf.start_date			   hire_date,
	   paaf.assignment_id,
	   ppayf.payroll_id,
	   ppayf.payroll_name,
	   petf.element_type_id,
       petf.processing_type,
	   petf.attribute1			    element_code,
	--   pcak.segment3			    department,
	   nvl(x.entry_effective_date,peef.effective_start_date)	date_incidence,
       petf.element_name,
       petf.description,
	   pelf.element_link_id,
	   pec.classification_name,
	   petf.reporting_name,
       pivf.uom,
	   hl.meaning uom_meaning,
	   pivf.input_value_id,
	   pivf.name 		   	   		input_value_name,
	   peevf.element_entry_value_id,
	   peevf.screen_entry_value,
	   peef.element_entry_id,
	   peef.creator_type,
	   peef.effective_end_date 		entry_effective_end_date
from   	per_all_people_f 				papf,
       	per_all_assignments_f 		    paaf,
       	pay_payrolls_f 				    ppayf,
       	pay_element_entries_f 		    peef,
       	pay_element_entry_values_f 	    peevf,
       	pay_element_links_f 		    pelf,
       	pay_element_types_f 		    petf,
       	pay_input_values_f 			    pivf,
	pay_element_classifications 	    pec,
	hr_lookups 			    hl,
        ( select to_date(screen_entry_value,'YYYY/MM/DD hh24:mi:ss') entry_effective_date,a.element_entry_id
          from   pay_element_entry_values_f a
                ,pay_input_values_f         b
          where a.input_value_id = b.input_value_id
          and   b.name = 'Entry Effective Date'
          and   trunc(g_cut_off_date) between a.effective_start_date and a.effective_end_date
          and   trunc(g_cut_off_date) between b.effective_start_date and b.effective_end_date
	) x
where  papf.business_group_id = g_business_Group_id
and    trunc(g_cut_off_date) between papf.effective_start_date and papf.effective_end_date
and    papf.person_id = paaf.person_id
and    trunc(g_cut_off_date) between paaf.effective_start_date and paaf.effective_end_date
and    paaf.payroll_id = ppayf.payroll_id(+)
and    trunc(g_cut_off_date) between ppayf.effective_start_date(+) and ppayf.effective_end_date(+)
and    paaf.assignment_id = peef.assignment_id
and    trunc(g_cut_off_date) between peef.effective_start_date and peef.effective_end_date
and    peef.element_entry_id = peevf.element_entry_id
and    trunc(g_cut_off_date) between peevf.effective_start_date and peevf.effective_end_date
and    peef.element_link_id = pelf.element_link_id
and    trunc(g_cut_off_date) between pelf.effective_start_date and pelf.effective_end_date
and    pelf.element_type_id = petf.element_type_id
and    trunc(g_cut_off_date) between petf.effective_start_date and petf.effective_end_date
and    peevf.input_value_id = pivf.input_value_id
and    trunc(g_cut_off_date) between pivf.effective_start_date and pivf.effective_end_date
and    peevf.screen_entry_value is not null
and    petf.classification_id = pec.classification_id
and    pivf.uom = hl.lookup_code
and    hl.lookup_type='UNITS'
and    x.element_entry_id(+) = peef.element_entry_id;
	-- fnd_file.put_line(fnd_file.log,c_ele.element_code);
/*
	v_salary                 number;
	v_sal_change_date        date;
	v_sal_change_reason      varchar2(30);
*/
  	 v_employee_code 		 varchar2(20);
	 e_employee_code	 	 varchar2(60);
	 e_department			 varchar2(60);
	 v_salary_type	     	 varchar2(150);
	v_client		     	 varchar2(150);
	v_location		     	 varchar2(150);
	v_classification         varchar2(30);
	v_count					 number(30)	:=0;
	v_payroll_process		 varchar2(150);
	v_salary				 number :=0;
	v_sal_change_date		 date;
	v_sal_change_reason		 varchar2(30);
/*
	v_pei_attribute1			 varchar2(150);
	v_contract_type				 varchar2(60);
	v_contract_end_date			 date;
*/
--START R12.2 Upgrade Remediation
	/*r_interface         cust.ttec_mex_pay_interface_mst%rowtype;			-- Commented code by IXPRAVEEN-ARGANO, 02-May-2023	
    r_interface_ele     cust.ttec_mex_pay_interface_ele%rowtype;*/          
	r_interface         apps.ttec_mex_pay_interface_mst%rowtype;				--  code Added by IXPRAVEEN-ARGANO, 02-May-2023
    r_interface_ele     apps.ttec_mex_pay_interface_ele%rowtype;
	--END R12.2.12 Upgrade remediation
	
BEGIN
--	DBMS_OUTPUT.PUT_LINE('BEFORE LOOP ');
	 --delete from cust.ttec_mex_pay_interface_mst del			-- Commented code by IXPRAVEEN-ARGANO, 02-May-2023
	 delete from apps.ttec_mex_pay_interface_mst del            --  code Added by IXPRAVEEN-ARGANO, 02-May-2023
	 where trunc(del.cut_off_date) = trunc(g_cut_off_date);
	-- fnd_file.put_line(fnd_file.log,'BEFORE LOOP');


fnd_file.put_line(fnd_file.log,'Start Populating cust.ttec_mex_pay_interface_mst');

  for r_emp in c_emp
  loop
  	 v_count:=v_count+1;
 --  fnd_file.put_line(fnd_file.log,'AFTER LOOP');
 --  DBMS_OUTPUT.PUT_LINE('AFTER LOOP');
	get_cost_allocation(iv_assignment_id   => r_emp.t_assignment_id,
 			     ov_client => v_client
		--	    ,ov_location => v_location
				   			   	  			  );
	get_location(iv_assignment_id   => r_emp.t_assignment_id,
 									ov_location => v_location );
	get_payroll_process(iv_assignment_id   => r_emp.t_assignment_id,
				   ov_payroll_process => v_payroll_process);
/*
 DBMS_OUTPUT.PUT_LINE( 'assignment_id    ='|| r_emp.t_assignment_id) ;	-- Test case
 DBMS_OUTPUT.PUT_LINE(' client	 =' ||v_client);
  DBMS_OUTPUT.PUT_LINE(' location	 =' ||v_location);
  DBMS_OUTPUT.PUT_LINE(' payroll_process	 =' ||v_payroll_process);
*/
    	get_bank(iv_assignment_id   => r_emp.t_assignment_id,
	     	ov_org_payment_method_id    =>v_salary_type );
	get_salary(iv_assignment_id   => r_emp.t_assignment_id,
               ov_salary          => v_salary,
               ov_change_date     => v_sal_change_date,
	   ov_change_reason   => v_sal_change_reason);
--			 DBMS_OUTPUT.PUT_LINE( 'assignment_id    ='|| r_emp.t_assignment_id) ;	-- Test case
--	----------------------------------------------------------------------------
--
--	Check for employee_number
--
--	----------------------------------------------------------------------------
	BEGIN
	IF  NVL(get_hire_date(r_emp.t_person_id),r_emp.t_hire_date) < to_date('01-MAR-2005','dd-mon-yyyy') --Change by PH per Andy's Note 04/27
	THEN
	v_employee_code		:= r_emp.t_employee_code;
	ELSE
	v_employee_code		:=r_emp.t_oracle_number ;
	END IF ;
	END;
--	DBMS_OUTPUT.PUT_LINE( 'hire date    ='|| r_emp.t_hire_date ) ;	-- Test case
--	DBMS_OUTPUT.PUT_LINE( 'employee code    ='|| v_employee_code ) ;	-- Test case
--	---------------------------------------------------------------------------
--
--	----------------------------------------------------------------------------
	r_interface.payroll_id                  	    :=	null	;
	r_interface.payroll_name                	    :=	null             ;
	r_interface.pay_period_id               	    :=	NULL             ;
	r_interface.cut_off_date                	    :=	g_cut_off_date              ;
	r_interface.person_id                   	    :=	r_emp.t_person_id                 ;
	r_interface.person_creation_date        	    :=	r_emp.t_person_creation_date      ;
	r_interface.person_update_date          	    :=	r_emp.t_person_update_date        ;
	r_interface.assignment_id               	    :=	r_emp.t_assignment_id             ;
	r_interface.assignment_creation_date    	    :=	r_emp.t_assignment_creation_date  ;
	r_interface.assignment_update_date      	    :=	r_emp.t_assignment_update_date    ;
	r_interface.person_type_id              	    :=	r_emp.t_person_type_id		;
	r_interface.period_of_service_id        	    :=	r_emp.t_period_of_service_id      ;
	r_interface.system_person_type          	    :=	r_emp.t_system_person_type        ;
	r_interface.user_person_type            	    :=	r_emp.t_user_person_type          ;
	r_interface.per_system_status           	    :=	r_emp.t_per_system_status         ;
	r_interface.creation_date               	    :=	g_sysdate			;
	r_interface.last_extract_date           	    :=	to_date(null)          		;
	r_interface.last_extract_file_type      	    :=	'PAYROLL RUN'			;
	  r_interface.status	    			    :=	null		;
	r_interface.Employee_code	    	:=	v_Employee_code			;
	r_interface.Active	    		:=	'A'					;
	r_interface.Paternal_name	    	:=	r_emp.t_Paternal_name			;
	r_interface.Maternal_name	    	:=	r_emp.t_Maternal_name			;
	r_interface.First_name	    		:=	r_emp.t_First_name			;
	r_interface.RFC	    			:=	r_emp.t_RFC				;
	r_interface.Sex	    			:=	r_emp.t_Sex				;
	r_interface.Marital_status	    	:=	r_emp.t_Marital_status			;
	r_interface.street	    		:=	r_emp.t_street				;
	r_interface.Ext_int_number	    	:=	r_emp.t_Ext_int_number			;
	r_interface.Zip_code	    		:=	r_emp.t_Zip_code			;
	r_interface.Residential_district	:=	r_emp.t_Residential_district		;
	r_interface.City	    		:=	r_emp.t_City				;
	r_interface.State	    		:=	r_emp.t_State				;
	r_interface.Telefone	    		:=	r_emp.t_Telefone			;
	r_interface.Nationality	    		:=	r_emp.t_Nationality			;
	r_interface.Place_of_birth	    	:=	r_emp.t_Place_of_birth			;
        r_interface.State_of_birth	    	:=	r_emp.t_State_of_birth			;
	r_interface.IMSS_number	    		:=	r_emp.t_IMSS_number			;
	r_interface.CURP	    		:=	r_emp.t_CURP				;
	r_interface.Family_Medical_Center	:=	r_emp.t_Family_Medical_Center		;
	r_interface.Work_day	    		:=	'0'					;
	r_interface.Compensation_type	    	:=	'A'					;
	r_interface.Pay_tables	    		:=	null					;
	r_interface.Table_levels	    	:=	null					;
	r_interface.Shift	    		:=	r_emp.t_Shift				;
 --	r_interface.Contract_type	    	:= Null						;			-- Test Case
  	r_interface.Contract_type	    	:=	r_emp.t_Contract_type			;
  	r_interface.Contract_start_date	    	:=	nvl(r_emp.t_Contract_start_date,NVL(get_hire_date(r_emp.t_person_id),r_emp.t_hire_date))		;
 --	r_interface.Contract_end_date	    	:=	null					;  -- Test case
    r_interface.Contract_end_date	    	:=	r_emp.t_Contract_end_date			;
  	r_interface.Salary_type	    		:=	v_Salary_type				;	--  Get_bank
  --  	r_interface.Payroll_process	    	:=	null		;			-- Test case
  --	r_interface.Work_force	    		:=	null			;			-- Test case
  	r_interface.Payroll_process	    	:=	v_Payroll_process			;   -- Get payroll_process
    r_interface.Work_force	    		:=	r_emp.t_Work_force			;
--	r_interface.Hire_date	    		:=	r_emp.t_Hire_date;  -- Change by PH per Andy's Note 04/27/05
	r_interface.Hire_date	    		:=	NVL(get_hire_date(r_emp.t_person_id),r_emp.t_hire_date);
        r_interface.Seniority_date	    	:=	r_emp.t_Seniority_date			;
	r_interface.Salary	    		:=	v_Salary				;
	r_interface.job	    			:=	r_emp.t_job				;
	r_interface.client	    		:=	v_client				;	--  get_cost_allocation
  	r_interface.Location	    		:=	v_location				;	--  get_location
  	r_interface.Accounting_equivalence	:=	null					;
    r_interface.Oracle_number	    	:=	r_emp.t_Oracle_number			;
	r_interface.Organization_level	    	:=	r_emp.t_Organization_level		;
	r_interface.Date_change_asg	    	:=	r_emp.t_Date_change_asg			;
	r_interface.Job_code	    		:=	r_emp.t_Job_code				;
	r_interface.Department_code	    	:=	v_client				;	--  get_cost_allocation
 -- 	r_interface.Location	    		:=	v_Location				;	--  get_location Duplicate
	r_interface.Date_change_pay	    	:=	v_sal_change_date		;
	r_interface.Type_change	    		:=	v_sal_change_reason			;
	r_interface.Type_compensation	    	:=	'A'					;
	r_interface.salary	    		:=	v_salary				;
	r_interface.Type_leave		    	:=	r_emp.t_type_leave		;
	r_interface.Date_leave		    	:=	r_emp.t_date_leave		;
	--  DBMS_OUTPUT.PUT_LINE('BEFORE  call of insert');  -- test case
 	insert_interface_table (ir_interface     => r_interface);
--	    DBMS_OUTPUT.PUT_LINE('Total employee inserted		=' ||v_count);
--  	 	DBMS_OUTPUT.PUT_LINE('BEFORE END LOOP');
--	fnd_file.put_line(fnd_file.log,v_employee_code);
--    fnd_file.put_line(fnd_file.log,'Insert Interface Succeeded    ' || g_retcode ||g_errbuf);
--	fnd_file.put_line(fnd_file.log,substr(SQLERRM,1,255));
 END loop;


fnd_file.put_line(fnd_file.log,'End Populating cust.ttec_mex_pay_interface_mst');


 -- ELEMENT
      --delete from cust.ttec_mex_pay_interface_ele ele			-- Commented code by IXPRAVEEN-ARGANO, 02-May-2023
      delete from apps.ttec_mex_pay_interface_ele ele           --  code Added by IXPRAVEEN-ARGANO, 02-May-2023
	  where trunc(ele.cut_off_Date) = trunc(g_cut_off_date);

-- Ken Mod 8/24/05 delete temp table cust.ttec_mex_pay_interface_ele_tmp entries.
-- the above table is used to generate control totals in log file
          --delete from cust.ttec_mex_pay_interface_ele_tmp;				-- Commented code by IXPRAVEEN-ARGANO, 02-May-2023
          delete from apps.ttec_mex_pay_interface_ele_tmp;                  --  code Added by IXPRAVEEN-ARGANO, 02-May-2023

fnd_file.put_line(fnd_file.log,'Start Populating cust.ttec_mex_pay_interface_ele');

  for r_ele in c_ele loop
	BEGIN
	get_dept (iv_assignment_id   => r_ele.assignment_id,
 			    ov_department => e_department);
	IF  NVL(get_hire_date(r_ele.person_id),r_ele.hire_date) < to_date('01-MAR-2005','dd-mon-yyyy')  --Change by PH per Andy's Note 04/27
	THEN
	e_employee_code		:= r_ele.employee_code;
	ELSE
	e_employee_code		:=r_ele.oracle_number ;
	END IF ;
	END;
  /*
      get_cost_allocation(iv_assignment_id   => ele_data.assignment_id,
 			      ov_cost_segment2 => v_cost_segment2,
      			      ov_cost_segment3 => v_cost_segment3);
  */
/*- not required--
    if upper(ele_data.element_name) like '%LOAN%' then
	  v_classification := 'LOAN';
	elsif ele_data.classification_name in ('Earnings','Imputed Earnings', 'Non-payroll Payments','Supplemental Earnings', 'Tax Credit') then
      v_classification := 'EARNINGS';
	elsif
	  ele_data.classification_name in ('Involuntary Deductions', 'Pre-Tax Deductions','Tax Deductions', 'Taxable Benefits','Voluntary Deductions') then
	  v_classification := 'DEDUCTIONS';
    end if;
*/
     r_interface_ele.PAYROLL_ID                   := r_ele.payroll_id;
	r_interface_ele.payroll_name                 := r_ele.payroll_name;
--	r_interface_ele.PAY_PERIOD_ID                := null;
	r_interface_ele.cut_off_date                 := g_cut_off_date;
	r_interface_ele.PERSON_ID                    := r_ele.PERSON_ID;
	r_interface_ele.ASSIGNMENT_ID                := r_ele.ASSIGNMENT_ID;
	r_interface_ele.EMPLOYEE_CODE                := e_EMPLOYEE_CODE;
	r_interface_ele.DATE_INCIDENCE		     :=r_ele.DATE_INCIDENCE;
--	r_interface_ele.hire_Date		     :=r_ele.hire_date;  Change by PH per Andy's note 04/27
	r_interface_ele.hire_Date		     :=NVL(get_hire_date(r_ele.person_id),r_ele.hire_date);
	r_interface_ele.department		     :=e_department;
	r_interface_ele.ELEMENT_CODE			 	 := r_ele.ELEMENT_CODE;
	r_interface_ele.ELEMENT_NAME                 := r_ele.ELEMENT_NAME;
--	r_interface_ele.REPORTING_NAME               := r_ele.REPORTING_NAME;
	r_interface_ele.PROCESSING_TYPE              := r_ele.PROCESSING_TYPE;
	r_interface_ele.CLASSIFICATION_NAME          := v_CLASSIFICATION;
	r_interface_ele.ELEMENT_TYPE_ID              := r_ele.ELEMENT_TYPE_ID;
	r_interface_ele.ELEMENT_LINK_ID              := r_ele.ELEMENT_LINK_ID;
	r_interface_ele.ELEMENT_ENTRY_ID             := r_ele.ELEMENT_ENTRY_ID;
	r_interface_ele.creator_type                 := r_ele.creator_type;
	r_interface_ele.ELEMENT_ENTRY_VALUE_ID       := r_ele.ELEMENT_ENTRY_VALUE_ID;
	r_interface_ele.UOM               	     := r_ele.UOM;
	r_interface_ele.UOM_MEANING                  := r_ele.UOM_MEANING;
	r_interface_ele.INPUT_VALUE_ID               := r_ele.INPUT_VALUE_ID;
	r_interface_ele.INPUT_VALUE_NAME             := r_ele.INPUT_VALUE_NAME;
	r_interface_ele.SCREEN_ENTRY_VALUE           := r_ele.SCREEN_ENTRY_VALUE;
	r_interface_ele.ENTRY_EFFECTIVE_END_DATE     := r_ele.ENTRY_EFFECTIVE_END_DATE;
	r_interface_ele.CREATION_DATE                := g_sysdate;
	r_interface_ele.LAST_EXTRACT_DATE            := to_date(null);
	r_interface_ele.LAST_EXTRACT_FILE_TYPE      := 'PAYROLL RUN';
	insert_interface_ele(ir_interface_ele     => r_interface_ele);
  end loop;  -- c_ele
fnd_file.put_line(fnd_file.log,'End Populating cust.ttec_mex_pay_interface_ele');
	COMMIT;
		EXCEPTION
		  when others then
	--	  DBMS_OUTPUT.PUT_LINE('error in employee' || g_retcode	|| g_errbuf  );	  -- Test case
	--	   DBMS_OUTPUT.PUT_LINE('Total employee inserted		=' ||v_count);
			ROLLBACK;
	g_retcode := SQLCODE;
	g_errbuf  := substr(SQLERRM,1,255);
	fnd_file.put_line(fnd_file.log,'Populate Interface Failed');
	fnd_file.put_line(fnd_file.log,substr(SQLERRM,1,255));
	raise g_e_abort;
END; -- procedure populate_interface_tables
--------------------------------------------------------------------
--                                                                --
-- NAME:  extract_mex_emps                  (PROCEDURE)                --
--                                                                --
--     DESCRIPTION:         PROCEDURE called by the concurrent    --
--                            manager to extract new hire data    --
--                                                                --
--                                                                --
--     CHANGE HISTORY                                             --
--                                                                --
--     CHANGED BY        Date        REASON FOR CHANGE           --
--     ----------        ----        -----------------            --
--     Vijay Mayadam   17-Jan-2005  Initial Creation             --
--                                                                --
--     CHANGED BY        Date        REASON FOR CHANGE           --
--     ----------        ----        -----------------            --
--    Arun Jayaraman   24-Jan-2005  COuntry specIFic creation     --
--                                                                --
--------------------------------------------------------------------
PROCEDURE extract_mex_emps (ov_errbuf        out varchar2,
                            ov_retcode       out number,
                            iv_cut_off_date   in varchar2) is
l_date            DATE;
l_valid_date      BOOLEAN;
l_e_invalid_date  EXCEPTION;
l_cut_off_date    DATE;
l_extract_start_time      DATE;
l_extract_end_time        DATE;
l_start_time      DATE;
l_end_time        DATE;
l_diff_day        number;
l_diff_hour       number;
l_diff_min        number;
l_diff_sec        number;

BEGIN
  validate_date (iv_cut_off_date, l_date ,l_valid_date);
  IF NOT l_valid_date THEN
   RAISE l_e_invalid_date;
  ELSE
   l_cut_off_date   := l_date;
  END IF;
  set_business_group_id(iv_business_group => 'TeleTech Holdings - MEX');
  fnd_file.put_line(fnd_file.log,'Business Group ID = ' || to_char(g_business_group_id));
 -- DBMS_OUTPUT.PUT_LINE('Business group ID = ' || to_char(g_business_group_id));
--  set_payroll_dates (iv_pay_period_id          => iv_pay_period);
   IF 	l_cut_off_date is not null and trunc(l_cut_off_date) <= trunc(sysdate)
	then g_cut_off_date :=to_date(l_cut_off_date,'DD-MON-RRRR'); -- to_date(iv_cut_off_date,'YYYY/MM/DD HH24:MI:SS');
	else raise g_e_future_date;
   END IF;
 -- g_cut_off_date := trunc(sysdate); -- Test case
 -- DBMS_OUTPUT.PUT_LINE('Cut off Date =' || to_char(g_cut_off_date,'MM/DD/YYYY'));
  fnd_file.put_line(fnd_file.log,'Cut Off Date      = ' || g_cut_off_date);
  --
  -- Added by C. Chan on Dec 11,2007
  --
  l_extract_start_time := SYSDATE;
  --insert into CUST.TTEC_MEX_PAY_INTERFACE_STATUS			-- Commented code by IXPRAVEEN-ARGANO, 02-May-2023
  insert into apps.TTEC_MEX_PAY_INTERFACE_STATUS            --  code Added by IXPRAVEEN-ARGANO, 02-May-2023
  values (l_extract_start_time,'MEX HR Extract','Step 00','ttec_mex_pay_interface_pkg.extract_mex_emps with Cut Off Date = ' || g_cut_off_date);
  fnd_file.put_line(fnd_file.log,'Start populating audit tables');
  commit;
  --
  -- Added by C. Chan on Dec 11,2007
  --
  l_start_time := SYSDATE;
  --insert into CUST.TTEC_MEX_PAY_INTERFACE_STATUS				-- Commented code by IXPRAVEEN-ARGANO, 02-May-2023
  insert into apps.TTEC_MEX_PAY_INTERFACE_STATUS                --  code Added by IXPRAVEEN-ARGANO, 02-May-2023
  values (l_start_time,'MEX HR Extract','Step 01','load_interface_table Start');
  commit;
  load_interface_table ;

  --
  -- Added by C. Chan on Dec 11,2007
  --
  l_end_time := SYSDATE;
  tt_calc_time_diff(l_start_time,l_end_time,l_diff_day,l_diff_hour,l_diff_min,l_diff_sec);
  --insert into CUST.TTEC_MEX_PAY_INTERFACE_STATUS					-- Commented code by IXPRAVEEN-ARGANO, 02-May-2023
  insert into apps.TTEC_MEX_PAY_INTERFACE_STATUS                    --  code Added by IXPRAVEEN-ARGANO, 02-May-2023
  values (l_end_time,'MEX HR Extract','Step 02','load_interface_table Complete'||' Run Time -> '||' Day:'||l_diff_day||' Hour:'||l_diff_hour||' Min:'||l_diff_min||' Sec:'||l_diff_sec);
  commit;
  fnd_file.put_line(fnd_file.log,'Ended populating audit tables');

  Print_line('**EMPLEADOS**');  -- **New Hire information**
  fnd_file.put_line(fnd_file.log,'Start Extracting new hires');
  --
  -- Added by C. Chan on Dec 11,2007
  --
  l_start_time := SYSDATE;
  --insert into CUST.TTEC_MEX_PAY_INTERFACE_STATUS			-- Commented code by IXPRAVEEN-ARGANO, 02-May-2023
  insert into apps.TTEC_MEX_PAY_INTERFACE_STATUS            --  code Added by IXPRAVEEN-ARGANO, 02-May-2023
  values (l_start_time,'MEX HR Extract','Step 03','new_hire Start');
  commit;
 new_hire;

  --
  -- Added by C. Chan on Dec 11,2007
  --
  l_end_time := SYSDATE;
  tt_calc_time_diff(l_start_time,l_end_time,l_diff_day,l_diff_hour,l_diff_min,l_diff_sec);
  --insert into CUST.TTEC_MEX_PAY_INTERFACE_STATUS		-- Commented code by IXPRAVEEN-ARGANO, 02-May-2023
  insert into apps.TTEC_MEX_PAY_INTERFACE_STATUS        --  code Added by IXPRAVEEN-ARGANO, 02-May-2023
  values (l_end_time,'MEX HR Extract','Step 04','new_hire Complete'||' Run Time -> '||' Day:'||l_diff_day||' Hour:'||l_diff_hour||' Min:'||l_diff_min||' Sec:'||l_diff_sec);
  commit;
fnd_file.put_line(fnd_file.log,'Ended Extracting new hires');

fnd_file.put_line(fnd_file.log,'Start Extracting employee changes');
 Print_line('**ACTUALIZA EMPLEADOS**');  -- **Employee personal data updates**
  --
  -- Added by C. Chan on Dec 11,2007
  --
  l_start_time := SYSDATE;
  --insert into CUST.TTEC_MEX_PAY_INTERFACE_STATUS		-- Commented code by IXPRAVEEN-ARGANO, 02-May-2023
  insert into apps.TTEC_MEX_PAY_INTERFACE_STATUS        --  code Added by IXPRAVEEN-ARGANO, 02-May-2023
  values (l_start_time,'MEX HR Extract','Step 05','extract_emp_changes Start');
  commit;
 extract_emp_changes;

  --
  -- Added by C. Chan on Dec 11,2007
  --
  l_end_time := SYSDATE;
  tt_calc_time_diff(l_start_time,l_end_time,l_diff_day,l_diff_hour,l_diff_min,l_diff_sec);
  --insert into CUST.TTEC_MEX_PAY_INTERFACE_STATUS			-- Commented code by IXPRAVEEN-ARGANO, 02-May-2023
  insert into apps.TTEC_MEX_PAY_INTERFACE_STATUS            --  code Added by IXPRAVEEN-ARGANO, 02-May-2023
  values (l_end_time,'MEX HR Extract','Step 06','extract_emp_changes Complete'||' Run Time -> '||' Day:'||l_diff_day||' Hour:'||l_diff_hour||' Min:'||l_diff_min||' Sec:'||l_diff_sec);
  commit;
fnd_file.put_line(fnd_file.log,'Ended Extracting employee changes');

fnd_file.put_line(fnd_file.log,'Start Extracting assignment changes');
 Print_line('**PLAZAS**');  -- **Job, Cost, Payroll, Location updates**

  --
  -- Added by C. Chan on Dec 11,2007
  --
  l_start_time := SYSDATE;
  --insert into CUST.TTEC_MEX_PAY_INTERFACE_STATUS			-- Commented code by IXPRAVEEN-ARGANO, 02-May-2023
  insert into apps.TTEC_MEX_PAY_INTERFACE_STATUS            --  code Added by IXPRAVEEN-ARGANO, 02-May-2023
  values (l_start_time,'MEX HR Extract','Step 07','extract_asg_changes Start');
  commit;
  extract_asg_changes ;

  --
  -- Added by C. Chan on Dec 11,2007
  --
  l_end_time := SYSDATE;
  tt_calc_time_diff(l_start_time,l_end_time,l_diff_day,l_diff_hour,l_diff_min,l_diff_sec);
  --insert into CUST.TTEC_MEX_PAY_INTERFACE_STATUS			-- Commented code by IXPRAVEEN-ARGANO, 02-May-2023
  insert into apps.TTEC_MEX_PAY_INTERFACE_STATUS            --  code Added by IXPRAVEEN-ARGANO, 02-May-2023
  values (l_end_time,'MEX HR Extract','Step 08','extract_asg_changes Complete'||' Run Time -> '||' Day:'||l_diff_day||' Hour:'||l_diff_hour||' Min:'||l_diff_min||' Sec:'||l_diff_sec);
  commit;
fnd_file.put_line(fnd_file.log,'Ended Extracting assignment changes');

fnd_file.put_line(fnd_file.log,'Start Extracting salary changes');
 Print_line('**CAMBIOS SUELDOS**');  -- **Salary Change**
  --
  -- Added by C. Chan on Dec 11,2007
  --
  l_start_time := SYSDATE;
  --insert into CUST.TTEC_MEX_PAY_INTERFACE_STATUS		-- Commented code by IXPRAVEEN-ARGANO, 02-May-2023
  insert into apps.TTEC_MEX_PAY_INTERFACE_STATUS        --  code Added by IXPRAVEEN-ARGANO, 02-May-2023
  values (l_start_time,'MEX HR Extract','Step 09','extract_salary_changes Start');
  commit;
  extract_salary_changes;

  --
  -- Added by C. Chan on Dec 11,2007
  --
  l_end_time := SYSDATE;
  tt_calc_time_diff(l_start_time,l_end_time,l_diff_day,l_diff_hour,l_diff_min,l_diff_sec);
  --insert into CUST.TTEC_MEX_PAY_INTERFACE_STATUS			-- Commented code by IXPRAVEEN-ARGANO, 02-May-2023
  insert into apps.TTEC_MEX_PAY_INTERFACE_STATUS            --  code Added by IXPRAVEEN-ARGANO, 02-May-2023
  values (l_end_time,'MEX HR Extract','Step 10','extract_salary_changes Complete'||' Run Time -> '||' Day:'||l_diff_day||' Hour:'||l_diff_hour||' Min:'||l_diff_min||' Sec:'||l_diff_sec);
  commit;
fnd_file.put_line(fnd_file.log,'Ended Extracting salary changes');

fnd_file.put_line(fnd_file.log,'Start Extracting terminations');
 Print_line('**BAJAS**');  -- **Termination**
  --
  -- Added by C. Chan on Dec 11,2007
  --
  l_start_time := SYSDATE;
  --insert into CUST.TTEC_MEX_PAY_INTERFACE_STATUS			-- Commented code by IXPRAVEEN-ARGANO, 02-May-2023
  insert into apps.TTEC_MEX_PAY_INTERFACE_STATUS            --  code Added by IXPRAVEEN-ARGANO, 02-May-2023
  values (l_start_time,'MEX HR Extract','Step 11','retrieve_terminations Start');
  commit;
  retrieve_terminations ;

  --
  -- Added by C. Chan on Dec 11,2007
  --
  l_end_time := SYSDATE;
  tt_calc_time_diff(l_start_time,l_end_time,l_diff_day,l_diff_hour,l_diff_min,l_diff_sec);
  --insert into CUST.TTEC_MEX_PAY_INTERFACE_STATUS				-- Commented code by IXPRAVEEN-ARGANO, 02-May-2023
  insert into apps.TTEC_MEX_PAY_INTERFACE_STATUS                --  code Added by IXPRAVEEN-ARGANO, 02-May-2023
  values (l_end_time,'MEX HR Extract','Step 12','retrieve_terminations Complete'||' Run Time -> '||' Day:'||l_diff_day||' Hour:'||l_diff_hour||' Min:'||l_diff_min||' Sec:'||l_diff_sec);
  commit;
fnd_file.put_line(fnd_file.log,'Ended Extracting terminations');

-- Elements
fnd_file.put_line(fnd_file.log,'Start Extracting elements new');
Print_line('**INCIDENCIAS**');  -- **Element Information**
  --
  -- Added by C. Chan on Dec 11,2007
  --
  l_start_time := SYSDATE;
  --insert into CUST.TTEC_MEX_PAY_INTERFACE_STATUS			-- Commented code by IXPRAVEEN-ARGANO, 02-May-2023
  insert into apps.TTEC_MEX_PAY_INTERFACE_STATUS            --  code Added by IXPRAVEEN-ARGANO, 02-May-2023
  values (l_start_time,'MEX HR Extract','Step 13','extract_elements_new Start');
  commit;
  extract_elements_new (iv_assignment_id      => null,
			 iv_include_salary      => 'N');

  --
  -- Added by C. Chan on Dec 11,2007
  --
  l_end_time := SYSDATE;
  tt_calc_time_diff(l_start_time,l_end_time,l_diff_day,l_diff_hour,l_diff_min,l_diff_sec);
  --insert into CUST.TTEC_MEX_PAY_INTERFACE_STATUS		-- Commented code by IXPRAVEEN-ARGANO, 02-May-2023
  insert into apps.TTEC_MEX_PAY_INTERFACE_STATUS        --  code Added by IXPRAVEEN-ARGANO, 02-May-2023
  values (l_end_time,'MEX HR Extract','Step 14','extract_elements_new Complete'||' Run Time -> '||' Day:'||l_diff_day||' Hour:'||l_diff_hour||' Min:'||l_diff_min||' Sec:'||l_diff_sec);
  commit;
fnd_file.put_line(fnd_file.log,'Ended Extracting elements new');

fnd_file.put_line(fnd_file.log,'Start Extracting elements change');
  --
  -- Added by C. Chan on Dec 11,2007
  --
  l_start_time := SYSDATE;
  --insert into CUST.TTEC_MEX_PAY_INTERFACE_STATUS			-- Commented code by IXPRAVEEN-ARGANO, 02-May-2023
  insert into apps.TTEC_MEX_PAY_INTERFACE_STATUS            --  code Added by IXPRAVEEN-ARGANO, 02-May-2023
  values (l_start_time,'MEX HR Extract','Step 15','extract_elements_chg Start');
  commit;
  extract_elements_chg (iv_assignment_id      => null,
			 iv_include_salary      => 'N');

  --
  -- Added by C. Chan on Dec 11,2007
  --
  l_end_time := SYSDATE;
  tt_calc_time_diff(l_start_time,l_end_time,l_diff_day,l_diff_hour,l_diff_min,l_diff_sec);
  --insert into CUST.TTEC_MEX_PAY_INTERFACE_STATUS				-- Commented code by IXPRAVEEN-ARGANO, 02-May-2023
  insert into apps.TTEC_MEX_PAY_INTERFACE_STATUS                --  code Added by IXPRAVEEN-ARGANO, 02-May-2023
  values (l_end_time,'MEX HR Extract','Step 16','extract_elements_chg Complete'||' Run Time -> '||' Day:'||l_diff_day||' Hour:'||l_diff_hour||' Min:'||l_diff_min||' Sec:'||l_diff_sec);
  commit;
fnd_file.put_line(fnd_file.log,'Ended Extracting elements change');

-- Ken Mod 8/24/05 added to pruduct pay code control totals in current log file.
  fnd_file.put_line(fnd_file.log,'Start extract_elements_ctl_tot');
  --
  -- Added by C. Chan on Dec 11,2007
  --
  l_start_time := SYSDATE;
  --insert into CUST.TTEC_MEX_PAY_INTERFACE_STATUS				-- Commented code by IXPRAVEEN-ARGANO, 02-May-2023
  insert into apps.TTEC_MEX_PAY_INTERFACE_STATUS                --  code Added by IXPRAVEEN-ARGANO, 02-May-2023
  values (l_start_time,'MEX HR Extract','Step 17','extract_elements_ctl_tot Start');
  commit;
  extract_elements_ctl_tot;

  --
  -- Added by C. Chan on Dec 11,2007
  --
  l_end_time := SYSDATE;
  tt_calc_time_diff(l_start_time,l_end_time,l_diff_day,l_diff_hour,l_diff_min,l_diff_sec);
 -- insert into CUST.TTEC_MEX_PAY_INTERFACE_STATUS		-- Commented code by IXPRAVEEN-ARGANO, 02-May-2023
  insert into apps.TTEC_MEX_PAY_INTERFACE_STATUS        --  code Added by IXPRAVEEN-ARGANO, 02-May-2023
  values (l_end_time,'MEX HR Extract','Step 18','extract_elements_ctl_tot Complete'||' Run Time -> '||' Day:'||l_diff_day||' Hour:'||l_diff_hour||' Min:'||l_diff_min||' Sec:'||l_diff_sec);
  commit;
  fnd_file.put_line(fnd_file.log,'Ended extract_elements_ctl_tot');

--  print_line('** C. One Time Transactions **');
--  extract_nonrecurring;
--  print_line('** D. Loans **');
--  extract_loans;
--  extract_END_recurring (iv_classIFication => 'LOAN');
--  print_line('** E. Recurring Income/Deductions to be Discontinued **');
--  extract_END_recurring (iv_classIFication => 'EARNINGS');
--  extract_END_recurring (iv_classIFication => 'DEDUCTIONS');
--  print_line('** F. Other Instructions **');
--  extract_other;
    ov_retcode := g_retcode;
	ov_errbuf  := g_errbuf;

  l_extract_end_time := SYSDATE;
  tt_calc_time_diff(l_extract_start_time,l_extract_end_time,l_diff_day,l_diff_hour,l_diff_min,l_diff_sec);
  --insert into CUST.TTEC_MEX_PAY_INTERFACE_STATUS		-- Commented code by IXPRAVEEN-ARGANO, 02-May-2023
  insert into apps.TTEC_MEX_PAY_INTERFACE_STATUS        --  code Added by IXPRAVEEN-ARGANO, 02-May-2023
  values (l_extract_end_time,'MEX HR Extract','Step 19','Mexico Extract Completed'||' Run Time -> '||' Day:'||l_diff_day||' Hour:'||l_diff_hour||' Min:'||l_diff_min||' Sec:'||l_diff_sec);
  commit;
EXCEPTION
   when l_e_invalid_date  then
    fnd_File.put_line(fnd_file.log,'Process Aborted - Invalid Format of  "Cut_off_date"');
    ov_retcode := g_retcode;
	ov_errbuf  := g_errbuf;
  --
  -- Added by C. Chan on Dec 11,2007
  --
  --insert into CUST.TTEC_MEX_PAY_INTERFACE_STATUS			-- Commented code by IXPRAVEEN-ARGANO, 02-May-2023
  insert into apps.TTEC_MEX_PAY_INTERFACE_STATUS            --  code Added by IXPRAVEEN-ARGANO, 02-May-2023
  values (SYSDATE,'MEX HR Extract','Process Aborted - 1',ov_retcode||'-'||ov_errbuf);
  commit;
    when g_e_future_date then
    fnd_File.put_line(fnd_file.log,'Process Aborted - Enter "Cut_off_date" which is not in future');
    ov_retcode := g_retcode;
	ov_errbuf  := g_errbuf;
  --
  -- Added by C. Chan on Dec 11,2007
  --
  --insert into CUST.TTEC_MEX_PAY_INTERFACE_STATUS			-- Commented code by IXPRAVEEN-ARGANO, 02-May-2023
  insert into apps.TTEC_MEX_PAY_INTERFACE_STATUS            --  code Added by IXPRAVEEN-ARGANO, 02-May-2023
  values (SYSDATE,'MEX HR Extract','Process Aborted - 2',ov_retcode||'-'||ov_errbuf);
  commit;
  when g_e_abort THEN
    fnd_File.put_line(fnd_file.log,'Process Aborted - Contact Teletech Help Desk');
    ov_retcode := g_retcode;
	ov_errbuf  := g_errbuf;
  --
  -- Added by C. Chan on Dec 11,2007
  --
  ---insert into CUST.TTEC_MEX_PAY_INTERFACE_STATUS			-- Commented code by IXPRAVEEN-ARGANO, 02-May-2023
  insert into apps.TTEC_MEX_PAY_INTERFACE_STATUS            --  code Added by IXPRAVEEN-ARGANO, 02-May-2023
  values (SYSDATE,'MEX HR Extract','Process Aborted - 3',ov_retcode||'-'||ov_errbuf);
  commit;
  when others THEN
    fnd_file.put_line(fnd_file.log,'When Others EXCEPTION - Contact Teletech Help Desk');
	ov_retcode := SQLCODE;
	ov_errbuf  := substr(SQLERRM,1,255);
  --
  -- Added by C. Chan on Dec 11,2007
  --
  --insert into CUST.TTEC_MEX_PAY_INTERFACE_STATUS		-- Commented code by IXPRAVEEN-ARGANO, 02-May-2023
  insert into apps.TTEC_MEX_PAY_INTERFACE_STATUS        --  code Added by IXPRAVEEN-ARGANO, 02-May-2023
  values (SYSDATE,'MEX HR Extract','Process Aborted - 4',ov_retcode||'-'||ov_errbuf);
  commit;
END; -- PROCEDURE extract_mex_emps
END; -- Package Body																						  
/
show errors;
/