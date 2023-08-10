create or replace PACKAGE BODY      ttec_rsu_rec_02
IS
   /* $Header: TTEC_RSU_REC_02.pkb 1.3 2012/04/10 mdodge ship $ */

   /*== START ================================================================================================*\
      Author:
        Date:
   Call From: TeleTech Merrill Lynch RSU 02 File Create
        Desc: This program generates out file for Merrill Lynch

     Modification History:

    Version    Date     Author       Description (Include Ticket#)
    -------  --------  ------------  ------------------------------------------------------------------------------
        1.0  ?         ?             Initial Version
        1.1  02/12/09  Elango Pandu  Bob's request regarding  upd term date,update term flag and grant prior
                                       1-jan-09 changes
        1.2  02/26/09  Elango Pandu  Bob's request regarding  social security with held change
        1.3  04/10/12  MDodge        R #1363070 - Rertrofit directory paths for R12 and ALL instances.  Modified
                                       main query fo better performance by moving the pay_action_information
                                       subquery to a seperate query.
        1.5  12/17/12  Chan C.       R#1927070 - Adding YTD Medicare Paid/Update the associated flag to 'Y' if there is an amount for 2013
        1.6  05/02/14  C.Chan        INC0218306 -  Feed stopped transmitting (dropped the actual amount and transmitted -0- ) the Medicare YTD on 04/01/14 thru 04/11/14.
        1.7  05/06/14  C.Chan        INC0167396/INC0167271 - Our nightly feed to Merrilly Lynch equity is not updating an employee address when there is a change to the address.
        1.8  05/06/14  C.Chan        INC0258222 for equity update flags for Field #168 & #169 are currently populated with "N". These fields need to be populated with "Y". Plese update. T
        1.9  08/21/15  Lalitha       Rehosting changes for smtp
        2.0  10/07/15  C.Chan        SFTP Solution
        3.0  10/07/15  A Aslam       changes Specific for 3188920 .
        3.1  11/01/16  C.Chan        INC2481775 - Fix for rehiring withinthe same BG
		1.0  12/MAY/2023 RXNETHI-ARGANO R12.2 Upgrade Remediation
   \*== END ==================================================================================================*/

   g_run_date            CONSTANT DATE                     := TRUNC (SYSDATE);
   g_oracle_start_date   CONSTANT DATE             := TO_DATE ('01-JAN-1950');
   g_oracle_end_date     CONSTANT DATE             := TO_DATE ('31-DEC-4712');
   trunc_stat                     VARCHAR2 (100)
                                  := 'truncate table cust.ttec_rsu_rec_2_tbl';
      /*
   START R12.2 Upgrade Remediation
   code commented by RXNETHI-ARGANO,12/05/23
   g_rec2_wr                      cust.ttec_rsu_rec_2_tbl%ROWTYPE;
   -- record to write to file
   g_rec2_db                      cust.ttec_rsu_rec_2_db%ROWTYPE;
   ggg_tail                       cust.ttec_rsu_rec_2_trl%ROWTYPE;
   ggg_head                       cust.ttec_rsu_rec_2_hdr%ROWTYPE;
   g_emp_no                       hr.per_all_people_f.employee_number%TYPE; /*1.5 
   e_program_run_status           NUMBER                                 := 0;
   -- record to get match data from query
   e_initial_status               cust.ttec_error_handling.status%TYPE
                                                                 := 'INITIAL';
   e_warning_status               cust.ttec_error_handling.status%TYPE
                                                                 := 'WARNING';
   e_failure_status               cust.ttec_error_handling.status%TYPE
                                                                 := 'FAILURE';
   g_len_64                       NUMBER                                := 64;
   e_application_code             cust.ttec_error_handling.application_code%TYPE
                                                                      := 'HR';
   e_interface                    cust.ttec_error_handling.INTERFACE%TYPE
                                                                := 'TTEC_RSU';
   e_program_name                 cust.ttec_error_handling.program_name%TYPE
                                                         := 'TTEC_RSU_REC_02';
   e_module_name                  cust.ttec_error_handling.module_name%TYPE
                                                                      := NULL;
   e_conc                         cust.ttec_error_handling.concurrent_request_id%TYPE
                                                                         := 0;
   e_execution_date               cust.ttec_error_handling.execution_date%TYPE
                                                                   := SYSDATE;
   e_status                       cust.ttec_error_handling.status%TYPE
                                                                      := NULL;
   e_error_code                   cust.ttec_error_handling.ERROR_CODE%TYPE
                                                                         := 0;
   e_error_message                cust.ttec_error_handling.error_message%TYPE
                                                                      := NULL;
   e_label1                       cust.ttec_error_handling.label1%TYPE
                                                                      := NULL;
   e_reference1                   cust.ttec_error_handling.reference1%TYPE
                                                                      := NULL;
   e_label2                       cust.ttec_error_handling.label2%TYPE
                                                                      := NULL;
   e_reference2                   cust.ttec_error_handling.reference2%TYPE
                                                                      := NULL;
   e_label3                       cust.ttec_error_handling.label3%TYPE
                                                                      := NULL;
   e_reference3                   cust.ttec_error_handling.reference3%TYPE
                                                                      := NULL;
   e_label4                       cust.ttec_error_handling.label4%TYPE
                                                                      := NULL;
   e_reference4                   cust.ttec_error_handling.reference4%TYPE
                                                                      := NULL;
   e_label5                       cust.ttec_error_handling.label5%TYPE
                                                                      := NULL;
   e_reference5                   cust.ttec_error_handling.reference5%TYPE
                                                                      := NULL;
   e_label6                       cust.ttec_error_handling.label6%TYPE
                                                                      := NULL;
   e_reference6                   cust.ttec_error_handling.reference6%TYPE
                                                                      := NULL;
   e_label7                       cust.ttec_error_handling.label7%TYPE
                                                                      := NULL;
   e_reference7                   cust.ttec_error_handling.reference7%TYPE
                                                                      := NULL;
   e_label8                       cust.ttec_error_handling.label8%TYPE
                                                                      := NULL;
   e_reference8                   cust.ttec_error_handling.reference8%TYPE
                                                                      := NULL;
   e_label9                       cust.ttec_error_handling.label9%TYPE
                                                                      := NULL;
   e_reference9                   cust.ttec_error_handling.reference9%TYPE
                                                                      := NULL;
   e_label10                      cust.ttec_error_handling.label10%TYPE
                                                                      := NULL;
   e_reference10                  cust.ttec_error_handling.reference10%TYPE
                                                                      := NULL;
   e_label11                      cust.ttec_error_handling.label11%TYPE
                                                                      := NULL;
   e_reference11                  cust.ttec_error_handling.reference11%TYPE
                                                                      := NULL;
   e_label12                      cust.ttec_error_handling.label12%TYPE
                                                                      := NULL;
   e_reference12                  cust.ttec_error_handling.reference12%TYPE
                                                                      := NULL;
   e_label13                      cust.ttec_error_handling.label13%TYPE
                                                                      := NULL;
   e_reference13                  cust.ttec_error_handling.reference13%TYPE
                                                                      := NULL;
   e_label14                      cust.ttec_error_handling.label14%TYPE
                                                                      := NULL;
   e_reference14                  cust.ttec_error_handling.reference14%TYPE
                                                                      := NULL;
   e_label15                      cust.ttec_error_handling.label15%TYPE
                                                                      := NULL;
   e_reference15                  cust.ttec_error_handling.reference15%TYPE
                                                                      := NULL;
   e_last_update_date             cust.ttec_error_handling.last_update_date%TYPE
                                                                      := NULL;
   e_last_updated_by              cust.ttec_error_handling.last_updated_by%TYPE
                                                                      := NULL;
   e_last_update_logi             cust.ttec_error_handling.last_update_login%TYPE
                                                                      := NULL;
   e_creation_date                cust.ttec_error_handling.creation_date%TYPE
                                                                      := NULL;
   e_created_by                   cust.ttec_error_handling.created_by%TYPE
                                                                      := NULL;
	*/
	--code added by RXNETHI-ARGANO,12/05/23
   g_rec2_wr                      apps.ttec_rsu_rec_2_tbl%ROWTYPE;
   -- record to write to file
   g_rec2_db                      apps.ttec_rsu_rec_2_db%ROWTYPE;
   ggg_tail                       apps.ttec_rsu_rec_2_trl%ROWTYPE;
   ggg_head                       apps.ttec_rsu_rec_2_hdr%ROWTYPE;
   g_emp_no                       apps.per_all_people_f.employee_number%TYPE; /*1.5 */
   e_program_run_status           NUMBER                                 := 0;
   -- record to get match data from query
   e_initial_status               apps.ttec_error_handling.status%TYPE
                                                                 := 'INITIAL';
   e_warning_status               apps.ttec_error_handling.status%TYPE
                                                                 := 'WARNING';
   e_failure_status               apps.ttec_error_handling.status%TYPE
                                                                 := 'FAILURE';
   g_len_64                       NUMBER                                := 64;
   e_application_code             apps.ttec_error_handling.application_code%TYPE
                                                                      := 'HR';
   e_interface                    apps.ttec_error_handling.INTERFACE%TYPE
                                                                := 'TTEC_RSU';
   e_program_name                 apps.ttec_error_handling.program_name%TYPE
                                                         := 'TTEC_RSU_REC_02';
   e_module_name                  apps.ttec_error_handling.module_name%TYPE
                                                                      := NULL;
   e_conc                         apps.ttec_error_handling.concurrent_request_id%TYPE
                                                                         := 0;
   e_execution_date               apps.ttec_error_handling.execution_date%TYPE
                                                                   := SYSDATE;
   e_status                       apps.ttec_error_handling.status%TYPE
                                                                      := NULL;
   e_error_code                   apps.ttec_error_handling.ERROR_CODE%TYPE
                                                                         := 0;
   e_error_message                apps.ttec_error_handling.error_message%TYPE
                                                                      := NULL;
   e_label1                       apps.ttec_error_handling.label1%TYPE
                                                                      := NULL;
   e_reference1                   apps.ttec_error_handling.reference1%TYPE
                                                                      := NULL;
   e_label2                       apps.ttec_error_handling.label2%TYPE
                                                                      := NULL;
   e_reference2                   apps.ttec_error_handling.reference2%TYPE
                                                                      := NULL;
   e_label3                       apps.ttec_error_handling.label3%TYPE
                                                                      := NULL;
   e_reference3                   apps.ttec_error_handling.reference3%TYPE
                                                                      := NULL;
   e_label4                       apps.ttec_error_handling.label4%TYPE
                                                                      := NULL;
   e_reference4                   apps.ttec_error_handling.reference4%TYPE
                                                                      := NULL;
   e_label5                       apps.ttec_error_handling.label5%TYPE
                                                                      := NULL;
   e_reference5                   apps.ttec_error_handling.reference5%TYPE
                                                                      := NULL;
   e_label6                       apps.ttec_error_handling.label6%TYPE
                                                                      := NULL;
   e_reference6                   apps.ttec_error_handling.reference6%TYPE
                                                                      := NULL;
   e_label7                       apps.ttec_error_handling.label7%TYPE
                                                                      := NULL;
   e_reference7                   apps.ttec_error_handling.reference7%TYPE
                                                                      := NULL;
   e_label8                       apps.ttec_error_handling.label8%TYPE
                                                                      := NULL;
   e_reference8                   apps.ttec_error_handling.reference8%TYPE
                                                                      := NULL;
   e_label9                       apps.ttec_error_handling.label9%TYPE
                                                                      := NULL;
   e_reference9                   apps.ttec_error_handling.reference9%TYPE
                                                                      := NULL;
   e_label10                      apps.ttec_error_handling.label10%TYPE
                                                                      := NULL;
   e_reference10                  apps.ttec_error_handling.reference10%TYPE
                                                                      := NULL;
   e_label11                      apps.ttec_error_handling.label11%TYPE
                                                                      := NULL;
   e_reference11                  apps.ttec_error_handling.reference11%TYPE
                                                                      := NULL;
   e_label12                      apps.ttec_error_handling.label12%TYPE
                                                                      := NULL;
   e_reference12                  apps.ttec_error_handling.reference12%TYPE
                                                                      := NULL;
   e_label13                      apps.ttec_error_handling.label13%TYPE
                                                                      := NULL;
   e_reference13                  apps.ttec_error_handling.reference13%TYPE
                                                                      := NULL;
   e_label14                      apps.ttec_error_handling.label14%TYPE
                                                                      := NULL;
   e_reference14                  apps.ttec_error_handling.reference14%TYPE
                                                                      := NULL;
   e_label15                      apps.ttec_error_handling.label15%TYPE
                                                                      := NULL;
   e_reference15                  apps.ttec_error_handling.reference15%TYPE
                                                                      := NULL;
   e_last_update_date             apps.ttec_error_handling.last_update_date%TYPE
                                                                      := NULL;
   e_last_updated_by              apps.ttec_error_handling.last_updated_by%TYPE
                                                                      := NULL;
   e_last_update_logi             apps.ttec_error_handling.last_update_login%TYPE
                                                                      := NULL;
   e_creation_date                apps.ttec_error_handling.creation_date%TYPE
                                                                      := NULL;
   e_created_by                   apps.ttec_error_handling.created_by%TYPE
                                                                      := NULL;
	--END R12.2 Upgrade Remediation

/*
------------------------------------------------------------------------------------------------
print a line to the log
------------------------------------------------------------------------------------------------
*/
   PROCEDURE print_line (v_data IN VARCHAR2)
   IS
   BEGIN
      fnd_file.put_line (fnd_file.LOG, v_data);
   END;
/*
------------------------------------------------------------------------------------------------
file header
------------------------------------------------------------------------------------------------
*/
   PROCEDURE rec_02_header (l_rec OUT VARCHAR2)
   IS
   BEGIN
      e_module_name := 'REC_02_Header';
      ggg_head.hconstant := 'STKOPTHDR';
      ggg_head.filler1 := ' ';
      ggg_head.file_creation_date := TO_CHAR (SYSDATE, 'YYYYMMDDHH24MISS');
      ggg_head.filler2 := ' ';
      ggg_head.plan_number := 'XOP1446';
      ggg_head.filler := ' ';
      -- write it
      l_rec :=
            ggg_head.hconstant
         || ggg_head.filler1
         || ggg_head.file_creation_date
         || ggg_head.filler2
         || ggg_head.plan_number
         || ggg_head.filler;
   EXCEPTION
      WHEN OTHERS
      THEN
         log_error ('Routine', 'REC_02_Header', NULL, NULL);
         print_line ('Error in module: ' || e_module_name);
         e_program_run_status := 1;
   END;
/*
------------------------------------------------------------------------------------------------
file trailer record
------------------------------------------------------------------------------------------------
*/
   PROCEDURE rec_02_trailer (rec_count IN NUMBER, l_rec OUT VARCHAR2)
   IS
   BEGIN
      e_module_name := ' REC_02_Trailer';
      ggg_tail.tconstant := 'STKOPTTRL';
      ggg_tail.filler1 := ' ';
      ggg_tail.codesrecordcount := LPAD ('0', 10, '0');
      ggg_tail.filler2 := ' ';
      ggg_tail.optionee_record_count := LPAD (TO_CHAR (rec_count), 10, '0');
      ggg_tail.filler3 := ' ';
      ggg_tail.grant_record_count := LPAD ('0', 10, '0');
      ggg_tail.filler4 := ' ';
      ggg_tail.vesting_schedule_record_count := LPAD ('0', 10, '0');
      ggg_tail.filler5 := ' ';
      ggg_tail.cancel_record_count := LPAD ('0', 10, '0');
      ggg_tail.filler6 := ' ';
      ggg_tail.tax_rate_record_count := LPAD ('0', 10, '0');
      ggg_tail.filler7 := ' ';
      ggg_tail.ml1 := LPAD ('0', 10, '0');
      ggg_tail.filler8 := ' ';
      ggg_tail.ml2 := LPAD ('0', 10, '0');
      ggg_tail.filler9 := ' ';
      ggg_tail.ml3 := LPAD ('0', 10, '0');
      ggg_tail.filler10 := ' ';
      ggg_tail.ml4 := LPAD ('0', 10, '0');
      ggg_tail.filler11 := ' ';
      ggg_tail.roll_forward_record_count := LPAD ('0', 10, '0');
      ggg_tail.filler12 := ' ';
      ggg_tail.ml5 := LPAD ('0', 10, '0');
      ggg_tail.filler13 := ' ';
      ggg_tail.ml6 := LPAD ('0', 10, '0');
      ggg_tail.filler14 := ' ';
      ggg_tail.ml7 := LPAD ('0', 10, '0');
      ggg_tail.filler15 := ' ';
      ggg_tail.performance_id_record_count := LPAD ('0', 10, '0');
      ggg_tail.filler16 := ' ';
      l_rec :=
            ggg_tail.tconstant
         || ggg_tail.filler1
         || ggg_tail.codesrecordcount
         || ggg_tail.filler2
         || ggg_tail.optionee_record_count
         || ggg_tail.filler3
         || ggg_tail.grant_record_count
         || ggg_tail.filler4
         || ggg_tail.vesting_schedule_record_count
         || ggg_tail.filler5
         || ggg_tail.cancel_record_count
         || ggg_tail.filler6
         || ggg_tail.tax_rate_record_count
         || ggg_tail.filler7
         || ggg_tail.ml1
         || ggg_tail.filler8
         || ggg_tail.ml2
         || ggg_tail.filler9
         || ggg_tail.ml3
         || ggg_tail.filler10
         || ggg_tail.ml4
         || ggg_tail.filler11
         || ggg_tail.roll_forward_record_count
         || ggg_tail.filler12
         || ggg_tail.ml5
         || ggg_tail.filler13
         || ggg_tail.ml6
         || ggg_tail.filler14
         || ggg_tail.ml7
         || ggg_tail.filler15
         || ggg_tail.performance_id_record_count
         || ggg_tail.filler16;
   EXCEPTION
      WHEN OTHERS
      THEN
         log_error ('Routine', 'REC_02_Trailer', NULL, NULL);
         print_line ('Error in module: ' || e_module_name);
         e_program_run_status := 1;
   END;
/*
------------------------------------------------------------------------------------------------
not used currently
------------------------------------------------------------------------------------------------
*/
   PROCEDURE rec_set_location_code (
      ggg        IN       c_rec2_q%ROWTYPE,
      loc_code   OUT      VARCHAR2
   )
   IS
      l_country   VARCHAR2 (100);
   BEGIN
      e_module_name := 'REC_SET_LOCATION_CODE';
      l_country := UPPER (ggg.country);

      CASE
         WHEN l_country = 'AUSTRALIA'
         THEN
            loc_code := 'AUS';
         WHEN l_country = 'Argentina'
         THEN
            loc_code := 'ARG';
         WHEN l_country = 'Brazil'
         THEN
            loc_code := 'BRZ';
         WHEN l_country = 'Canada'
         THEN
            loc_code := 'CAN';
         WHEN l_country = 'SPAIN'
         THEN
            loc_code := 'ESP';
         WHEN l_country = 'HONG KONG'
         THEN
            loc_code := 'AUS';
         WHEN l_country = 'MALAYSIA'
         THEN
            loc_code := 'MAL';
         WHEN l_country = 'MEXICO'
         THEN
            loc_code := 'MEX';
         WHEN l_country = 'NEW ZEALAND'
         THEN
            loc_code := 'NZ';
         WHEN l_country = 'PHILIPPINES'
         THEN
            loc_code := 'PHL';
         WHEN l_country = 'SINGAPORE'
         THEN
            loc_code := 'SGP';
         WHEN l_country = 'UNITED KINGDOM'
         THEN
            loc_code := 'UK';
         WHEN l_country = 'UNITED STATES'
         THEN
            loc_code := 'US';
         WHEN l_country = 'COSTA RICA'
         THEN
            loc_code := 'CR';
         WHEN l_country = 'SOUTH AFRICA'
         THEN
            loc_code := 'SA';
         ELSE
            loc_code := ' ';
      END CASE;
   EXCEPTION
      WHEN OTHERS
      THEN
         log_error ('Loc_code', loc_code, NULL, NULL);
         print_line ('Error in module: ' || e_module_name);
         print_line (   ' Error on employee: ' || g_emp_no); /* 1.5 */
         print_line (   '           Country: ' || ggg.country); /* 1.5 */
         e_program_run_status := 1;
   END;
   /*
   format input field into 9numbers and 6 decimal numbers   input 123456789.12  return 123456789120000
   */
   FUNCTION frmt_num96 (in_num NUMBER)
   RETURN VARCHAR2
   IS
     l_num_f VARCHAR2 (20);
   l_first VARCHAR2 (20);
   l_last VARCHAR2 (20);
   l_result VARCHAR2 (20);
   l_n     NUMBER;

   BEGIN


   -- remove blanks and commas
   l_num_f := REPLACE(REPLACE(TO_CHAR(in_num), ' ', ''), ',', '');

   l_n := INSTR(l_num_f, '.', 1, 1);

   IF l_n = 0 THEN
        l_first :=    l_num_f;
        l_last := '000000'; -- 6 zeros
   ELSE
        l_first := SUBSTR(l_num_f, 1, l_n-1);

        l_last := SUBSTR (l_num_f, l_n+1)||'0000';

   END IF;
   l_num_f := l_first || l_last;

   l_result := LPAD (l_num_f,  15, '0');
   return l_result;

   END;

 /* MOD #003
   format input field to remove decimals
   */
FUNCTION frmt_decimal_out (in_num NUMBER,in_field VARCHAR2)
RETURN VARCHAR2
   IS
   l_num_d    NUMBER(15);
   l_result_d NUMBER(15);


Begin

 e_module_name := 'frmt_decimal_out';
-- remove decimal

l_num_d := in_num * 100;

l_result_d := LPAD(TO_CHAR(l_num_d),15,'0');

return l_result_d;
   EXCEPTION
      WHEN OTHERS
      THEN
         log_error ('Routine', e_module_name, NULL, NULL);
         print_line ('***************Error in module: ' || e_module_name);
         print_line (   '       Failed to with Error: ' ||  SQLCODE || '|' || SUBSTR (SQLERRM, 1, 80));
         print_line (   '          Error on employee: ' || g_emp_no); /* 1.5 */
         print_line (   '                Amount Type: ' ||in_field); /* 1.5 */
         print_line (   '            Original Amount: ' ||in_num);
         print_line (   'Amount sent to Merril Lynch: 000000000000000');
         e_program_run_status := 1;
         RETURN '000000000000000';
   END;
--MOD #003
/* 1.6 Begin */
FUNCTION get_YTD_balance (
      p_person_id        IN    NUMBER,
      p_balance_name     IN   VARCHAR2,
      p_dimension_name   IN   VARCHAR2,
      p_legislation_code IN   VARCHAR2,
      p_currency_code    IN   VARCHAR2,
      p_effective_date   IN   DATE
   )
      RETURN NUMBER IS
      l_value   NUMBER;
   BEGIN
        l_value := 0;
        SELECT  LPAD(LTRIM(REPLACE(TO_CHAR(SUM(a.balance_value),'99999999.00'),'.','')),11,0) balance
        INTO l_value
        FROM (SELECT prb.assignment_id, prb.balance_value,
                     pdb.defined_balance_id, pdb.balance_type_id,
                     pdb.balance_dimension_id
                FROM (SELECT defined_balance_id, assignment_id,
                             effective_date, balance_value
                        --FROM hr.pay_run_balances --code commented by RXNETHI-ARGANO,12/05/23
						FROM apps.pay_run_balances --code added by RXNETHI-ARGANO,12/05/23
                       WHERE effective_date between to_date('01-JAN-'||to_char(p_effective_date,'YYYY')) and p_effective_date
                         AND assignment_id IS NOT NULL
                       --  AND assignment_id = p_assignment_id ) prb, /* 3.1 */
                         AND assignment_id  IN (select assignment_id
                                                from apps.per_all_assignments_f
                                                where person_id = p_person_id
                                                 and (   trunc(sysdate,'YYYY') between effective_start_date and nvl(effective_end_date,'31-DEC-4712')
                                                      or trunc(sysdate) between effective_start_date and nvl(effective_end_date,'31-DEC-4712')))) prb, /* 3.1 */
                     --hr.pay_defined_balances pdb --code commented by RXNETHI-ARGANO,12/05/23
					 apps.pay_defined_balances pdb --code added by RXNETHI-ARGANO,12/05/23
               WHERE prb.defined_balance_id = pdb.defined_balance_id) a,
             --hr.pay_balance_types pbt,     --code commented by RXNETHI-ARGANO,12/05/23
             --hr.pay_balance_dimensions pbd --code commented by RXNETHI-ARGANO,12/05/23
			 apps.pay_balance_types pbt,     --code added by RXNETHI-ARGANO,12/05/23
             apps.pay_balance_dimensions pbd --code added by RXNETHI-ARGANO,12/05/23
       WHERE a.balance_type_id = pbt.balance_type_id
         AND pbt.balance_name LIKE p_balance_name
         AND pbt.legislation_code = p_legislation_code -- 'US'
         AND pbt.currency_code = p_currency_code --'USD'
         AND a.balance_dimension_id = pbd.balance_dimension_id
         AND pbd.database_item_suffix = p_dimension_name; --'_ASG_GRE_RUN';

      RETURN l_value;
   EXCEPTION
      WHEN OTHERS
      THEN
         l_value := 0;
         RETURN l_value;
   END get_YTD_balance;
/* 1.6 End*/
/* 1.6 Begin */
FUNCTION get_suppl_compensation (p_person_id NUMBER)
      RETURN NUMBER IS
      l_value   NUMBER;
   BEGIN
        l_value := 0;

       SELECT SUM (prb.balance_value) run_ded
       INTO l_value
        FROM pay_defined_balances pdb,
             pay_balance_dimensions pbd,
             pay_run_balances prb,
             pay_balance_types pbt
       WHERE pdb.balance_type_id = 68
         AND pdb.balance_dimension_id =
                                  pbd.balance_dimension_id
         AND prb.defined_balance_id =
                                    pdb.defined_balance_id
         AND prb.effective_date BETWEEN    '01-JAN-'
                                        || TO_CHAR
                                                 (SYSDATE,
                                                  'YYYY'
                                                 )
                                    AND    '31-DEC'
                                        || TO_CHAR
                                                 (SYSDATE,
                                                  'YYYY'
                                                 )
         AND pbt.balance_type_id = pdb.balance_type_id
         --AND prb.assignment_id = asg.assignment_id) /* 3.1 */
         AND prb.assignment_id  IN (select assignment_id
                                from apps.per_all_assignments_f
                                where person_id = p_person_id
                                  and (   trunc(sysdate,'YYYY') between effective_start_date and nvl(effective_end_date,'31-DEC-4712')
                                        or trunc(sysdate) between effective_start_date and nvl(effective_end_date,'31-DEC-4712')));

      RETURN l_value;
   EXCEPTION
      WHEN OTHERS
      THEN
         l_value := 0;
         RETURN l_value;
   END get_suppl_compensation;
/* 1.6 End*/
   /*
------------------------------------------------------------------------------------------------
main record 2 population routine
------------------------------------------------------------------------------------------------
*/

   PROCEDURE rec_02_fill (ggg IN c_rec2_q%ROWTYPE,l_rec OUT VARCHAR)
                                                  -- record to get match data from query

   IS
      ev_val          CHAR (2);
      l_loc_code      VARCHAR2 (100);
      l_address_tmp   VARCHAR2 (240);
      org_hire_dt     date;
      hire_dt         date;
      sysdt_2         date;
   BEGIN
      e_module_name := 'rec_02_fill';
      -- rec_set_location_code (ggg, l_loc_code);
      --print_line ('Start Processing Optionee '|| ggg.last_name);
      g_rec2_wr.rec_type := '02';
      g_rec2_wr.op_id := LPAD (NVL (ggg.optionee_id, ' '), 9, '0');
      g_rec2_wr.ss := LPAD (NVL (ggg.ssnumber, ' '), 9, '0');
      g_rec2_wr.LAST := NVL (SUBSTR (ggg.last_name, 1, 40), ' ');
      g_rec2_wr.FIRST := NVL (SUBSTR (ggg.first_name, 1, 15), ' ');
      g_rec2_wr.mid := NVL (ggg.middle_initial, ' ');
      g_rec2_wr.email := ' ';


      IF LENGTH (ggg.country) > 0
      THEN
         g_rec2_wr.address1 := NVL (SUBSTR (ggg.address_line1, 1, 40), ' ');
         g_rec2_wr.address2 := NVL (SUBSTR (ggg.address_line2, 1, 40), ' ');
         g_rec2_wr.address3 := NVL (SUBSTR (ggg.address_line3, 1, 40), ' ');
         g_rec2_wr.address_line4 := ' ';
         g_rec2_wr.address_line5 := ' ';
         g_rec2_wr.city := NVL (SUBSTR (ggg.country, 1, 20), ' ');
      ELSE
         l_address_tmp :=
                  ggg.address_line1 || ggg.address_line2 || ggg.address_line3;
         g_rec2_wr.address1 := NVL (SUBSTR (l_address_tmp, 1, 39), ' ');
         g_rec2_wr.address2 := NVL (SUBSTR (l_address_tmp, 40, 79), ' ');
         g_rec2_wr.address3 := NVL (SUBSTR (l_address_tmp, 80, 119), ' ');
         g_rec2_wr.address_line4 :=
                                  NVL (SUBSTR (l_address_tmp, 120, 159), ' ');
         g_rec2_wr.address_line5 :=
                                  NVL (SUBSTR (l_address_tmp, 160, 200), ' ');
         g_rec2_wr.city := NVL (SUBSTR (ggg.city, 1, 20), ' ');
      END IF;


      g_rec2_wr.state := NVL (SUBSTR (ggg.state, 1, 2), ' ');
      g_rec2_wr.zip := NVL (SUBSTR (ggg.postal_code, 1, 10), '          ');
      g_rec2_wr.country := NVL (SUBSTR (ggg.country, 1, 20), ' ');

      g_rec2_wr.subs_code := ' ';
      g_rec2_wr.location_code := ' ';              -- substr(l_loc_code, 1,  ;
      g_rec2_wr.title_code := ' ';
      g_rec2_wr.officer_code := NVL (SUBSTR (ggg.officer_code, 1, 8), ' ');
      g_rec2_wr.tax_code := NVL (SUBSTR (ggg.tax_code, 1, 8), ' ');
      g_rec2_wr.fica := ' ';                --<<<<<<<<<<<<<<<XXXXXXXXX<<<check
      g_rec2_wr.birth_date := NVL (ggg.birth_date, ' ');
      g_rec2_wr.hire_date := NVL (ggg.hire_date, ' ');
      g_rec2_wr.term_date := NVL (ggg.termination_date, ' ');
      g_rec2_wr.term_id := NVL (SUBSTR (ggg.termination_id, 1, 10), ' ');
      g_rec2_wr.nickname := ' ';               -- blanked out per Julie Master
      -- Elango Added the user code1 for Bob's request on Jan 23 2009

      --g_rec2_wr.user_code1 := 'q';                      --<<<<<<<<<XXXXXXXXXXX
      --print_line ('ggg.ucode1 '||ggg.ucode1);
      IF ggg.ucode1 IS NOT NULL THEN
         g_rec2_wr.user_code1 := LPAD(ggg.ucode1,8,' ');
      ELSE
         g_rec2_wr.user_code1 := '        ';
      END IF;
      --g_rec2_wr.user_code1 := LPAD (nvl(ggg.ucode1,' '), 8, '0');
           -- print_line ('g_rec2_wr.user_code1 '||g_rec2_wr.user_code1);
      g_rec2_wr.user_code2 := ' ';

      g_rec2_wr.user_code3 := ' ';
      g_rec2_wr.user_num := ' ';
      g_rec2_wr.ytd_tax := ' ';
      g_rec2_wr.salary := ' ';
      g_rec2_wr.broker_code := ' ';
      g_rec2_wr.user_text1 := NVL (SUBSTR (ggg.user_text_1, 1, 20), ' ');

      g_rec2_wr.user_text2 := ' ';
      g_rec2_wr.user_date := ' ';
--      g_rec2_wr.ytd_fica :=
--                          LPAD (NVL (frmt_num96(ggg.ss_withheld), '0'), 15, '0');
      IF ggg.ss_withheld IS NULL THEN
         g_rec2_wr.ytd_fica := '000000000000000';
      ELSE
         g_rec2_wr.ytd_fica := ggg.ss_withheld||'0000';
      END IF;
      --g_rec2_wr.ytd_fica := g_rec2_wr.ytd_fica;



      --print_line('YTD Fica '||g_rec2_wr.ytd_fica);

      g_rec2_wr.phone := NVL (SUBSTR (ggg.phone_number, 1, 20), ' ');

      g_rec2_wr.fax := ' ';
      g_rec2_wr.not_for_use1 := ' ';
      g_rec2_wr.not_for_use2 := '0';
      g_rec2_wr.not_for_use3 := '0';
      g_rec2_wr.upd_last := ggg.upd_last_name_flag;
      g_rec2_wr.upd_first := ggg.upd_first_name_flag;
      g_rec2_wr.upd_middle := 'N';
      g_rec2_wr.upd_email := 'N' ; --ggg.upd_email_address_flag;
      g_rec2_wr.upd_address1 := ggg.upd_address_line_1_flag;
      g_rec2_wr.upd_address2 := ggg.upd_address_line_2_flag;
      g_rec2_wr.upd_address3 := ggg.upd_address_line_3_flag;
      g_rec2_wr.upd_city := ggg.upd_city_flag;
      g_rec2_wr.upd_state := ggg.upd_state_flag;
      --g_rec2_wr.upd_zip := 'N'; -- 1.7
      g_rec2_wr.upd_zip := ggg.upd_zip_flag;   -- 1.7
      g_rec2_wr.upd_country := ggg.upd_country_flag;
      g_rec2_wr.upd_subs := 'N';
      g_rec2_wr.upd_loc := 'N';
      g_rec2_wr.upd_title := 'N';
      g_rec2_wr.upd_officer := ggg.upd_officer_code_flag;

      g_rec2_wr.upd_tax := 'N';             -------------- XXXXXXXXXXXXXXXXXXX
      g_rec2_wr.upd_fica := 'N';
      g_rec2_wr.upd_birth := 'N';
      g_rec2_wr.upd_hire := 'N';
    -- Terminations
      g_rec2_wr.upd_term_date := ggg.upd_termination_date_flag;
      g_rec2_wr.upd_term_id := ggg.upd_termination_flag;
      g_rec2_wr.upd_nickname := 'N';
      g_rec2_wr.upd_user1 := 'N';
      g_rec2_wr.upd_user2 := 'N';
      g_rec2_wr.upd_user3 := 'N';
      g_rec2_wr.upd_user := 'N';
      g_rec2_wr.upd_ytd_taxable := 'N';
      g_rec2_wr.upd_salary := 'N';
      g_rec2_wr.upd_broker := 'N';
      g_rec2_wr.upd_user_text1 := ggg.upd_user_text_1_flag;

      g_rec2_wr.upd_user_text2 := 'N';
      g_rec2_wr.upd_user_date := 'N';
      g_rec2_wr.upd_ytd_fica := 'Y';
      g_rec2_wr.upd_phone := 'N';
      g_rec2_wr.upd_fax := 'N';
      g_rec2_wr.upd_filler1 := ' ';
      g_rec2_wr.upd_filler2 := ' ';
      g_rec2_wr.upd_filler3 := ' ';
      g_rec2_wr.region := ' ';
      g_rec2_wr.country_of_resid := ' ';
      --     <<<<<<<<<<<<ask  substr(ggg.COUNTRY,        ;
      g_rec2_wr.country_of_citizen := ' ';
      g_rec2_wr.tax_juris := 'N';
      g_rec2_wr.bank_account := ' ';
      g_rec2_wr.empl_level_restc := ' ';
      g_rec2_wr.lang := ' ';
      g_rec2_wr.affiliate := ' ';

       g_rec2_wr.mail := ggg.mail_code;

        org_hire_dt := to_date (ggg.org_hire_date, 'YYYYMMDD');
      hire_dt     := to_date ( ggg.hire_date, 'YYYYMMDD');

      sysdt_2  := trunc(sysdate -14); ---- MOD #002
-- apps.fnd_file.put_line (apps.fnd_file.output,'org_hire_dt ->'|| org_hire_dt);
-- apps.fnd_file.put_line (apps.fnd_file.output,'    hire_dt ->'|| hire_dt);
-- apps.fnd_file.put_line (apps.fnd_file.output,'    sysdt_2 ->'|| sysdt_2);

    IF ( ( org_hire_dt != hire_dt )AND (hire_dt > sysdt_2 ) )
     THEN

     g_rec2_wr.rehire := 'Y';
-- apps.fnd_file.put_line (apps.fnd_file.output,' rehire ->   Y'  );

    ELSE

       g_rec2_wr.rehire := ' ';
-- apps.fnd_file.put_line (apps.fnd_file.output,' rehire ->   N'  );
     END IF;

      /* Begin 1.5 */
      --g_rec2_wr.ytd_medicare := ' ';

      IF ggg.medicare_withheld IS NULL THEN
         g_rec2_wr.ytd_medicare := '000000000000000';
         g_rec2_wr.upd_ytd_medicare := 'N';
      ELSE
         g_rec2_wr.ytd_medicare := ggg.medicare_withheld||'0000';
         g_rec2_wr.upd_ytd_medicare := 'Y';
      END IF;
      /* End 1.5 */

      g_rec2_wr.ytd_tax1 := ' ';
      g_rec2_wr.ytd_tax2 := ' ';
      g_rec2_wr.ytd_tax3 := ' ';
      g_rec2_wr.ytd_tax4 := ' ';
      g_rec2_wr.ytd_tax5 := ' ';
      g_rec2_wr.ytd_tax6 := ' ';
      g_rec2_wr.ytd_tax7 := ' ';
      g_rec2_wr.ytd_tax8 := ' ';

      IF LENGTH (ggg.country) > 0
      THEN
         ev_val := '00';
      ELSE
         ev_val := 'EV';
      END IF;

-- Chnaged by Amir as Part of the change request

     IF g_emp_no = '3188920'
     THEN
        ev_val := '00';
     END IF;

      g_rec2_wr.grant_types := ev_val;
      g_rec2_wr.grant_medicare := ev_val;
      g_rec2_wr.msop := ' ';
      g_rec2_wr.empl_indicator := ggg.employeeindicator;

      g_rec2_wr.employee_effective_date := ' ';
      g_rec2_wr.population_code := ' ';
      g_rec2_wr.special_mail_handling := ' ';
      g_rec2_wr.loctrac_country := ' ';
      g_rec2_wr.loctrac_loc := ' ';
      g_rec2_wr.loctrac_subsid := ' ';
      g_rec2_wr.loctrac_user1 := ' ';
      g_rec2_wr.loctrac_user2 := ' ';
      g_rec2_wr.loctrac_user3 := ' ';
      g_rec2_wr.last_date_exer := ' ';
      g_rec2_wr.new_optionee_id := ' ';
      g_rec2_wr.use_new_optionee := ' ';
      g_rec2_wr.retiree_elg_date := ' ';

      g_rec2_wr.email_address := NVL (SUBSTR (ggg.email_address, 1, 100), ' ');
      --MOD# 003

      g_rec2_wr.suppl_comp := LPAD (nvl(frmt_decimal_out(ggg.supplemental_compensation,'supplemental_compensation'), '0'), 15,'0');

      --MOD# 003
      g_rec2_wr.filler_268 := ' ';
      g_rec2_wr.filler_1 := ' ';
      g_rec2_wr.upd_region_flag := 'N';
      g_rec2_wr.upd_address_line_4 := 'N';
      g_rec2_wr.upd_address_line_5 := 'N';
      g_rec2_wr.upd_country_of_residency := 'N';
      g_rec2_wr.upd_country_of_citizenship := 'N';
      g_rec2_wr.upd_tax_jurisdiction := 'N';
      g_rec2_wr.upd_bank_account_field := 'N';
      g_rec2_wr.upd_empl_level_rest := 'N';
      g_rec2_wr.upd_language_code := 'N';
      g_rec2_wr.upd_affiliate_code := 'N';
      g_rec2_wr.upd_mail_code := 'N';
      g_rec2_wr.filler_2 := ' ';
      --g_rec2_wr.upd_ytd_medicare := 'N'; /* 1.5 Logic is move up to medicare_withheld condition */
      g_rec2_wr.upd_ytd_tax_field_1 := 'N';
      g_rec2_wr.upd_ytd_tax_field_2 := 'N';
      g_rec2_wr.upd_ytd_tax_field_3 := 'N';
      g_rec2_wr.upd_ytd_tax_field_4 := 'N';
      g_rec2_wr.upd_ytd_tax_field_5 := 'N';
      g_rec2_wr.upd_ytd_tax_field_6 := 'N';
      g_rec2_wr.upd_ytd_tax_field_7 := 'N';
      g_rec2_wr.upd_ytd_tax_field_8 := 'N';
/* 1.8 Begin */
--      g_rec2_wr.upd_grant_types_fica := 'N';
--      g_rec2_wr.upd_grant_types_medicare := 'N';
      g_rec2_wr.upd_grant_types_fica := 'Y';
      g_rec2_wr.upd_grant_types_medicare := 'Y';
/* 1.8 End */
      g_rec2_wr.upd_msop_ind := 'N';
      g_rec2_wr.upd_emp_non_emp := 'N';
      g_rec2_wr.upd_emp_eff_date := 'N';
      g_rec2_wr.upd_pop_code := 'N';
      g_rec2_wr.upd_loctrac_efft_country := 'N';
      g_rec2_wr.upd_loctrac_code := 'N';
      g_rec2_wr.upd_loctrac_subsidia := 'N';
      g_rec2_wr.upd_loctrac_user_1 := 'N';
      g_rec2_wr.upd_loctrac_user_2 := 'N';
      g_rec2_wr.upd_loctrac_user_3 := 'N';
      g_rec2_wr.upd_date_to_exercise := 'N';
      g_rec2_wr.upd_new_optionee := ' ';
      g_rec2_wr.upd_use_new_opt_id := 'N';
      g_rec2_wr.upd_retiree_eligible_date := 'N';
      g_rec2_wr.upd_supplemental_compensation := 'Y';
      g_rec2_wr.filler_last := ' ';
             --print_line ('Completed Processing Optionee '|| ggg.last_name);
   EXCEPTION
      WHEN OTHERS
      THEN
         log_error ('Routine', e_module_name, NULL, NULL);
         print_line ('********Error in module: ' || e_module_name);
         print_line (   'Failed to with Error: ' ||  SQLCODE || '|' || SUBSTR (SQLERRM, 1, 80));
         print_line (   '   Error on employee: ' || g_emp_no); /* 1.5 */
         e_program_run_status := 1;
   END;

   /*
------------------------------------------------------------------------------------------------
not used at present
------------------------------------------------------------------------------------------------
*/
   PROCEDURE errvar_null (p_status OUT NUMBER)
   IS
   BEGIN
      e_module_name := 'ERRVAR_NULL';
      e_label1 := NULL;
      e_reference1 := NULL;
      e_label2 := NULL;
      e_reference2 := NULL;
      e_label3 := NULL;
      e_reference3 := NULL;
      e_label4 := NULL;
      e_reference4 := NULL;
      e_label5 := NULL;
      e_reference5 := NULL;
      e_label6 := NULL;
      e_reference6 := NULL;
      e_label7 := NULL;
      e_reference7 := NULL;
      e_label8 := NULL;
      e_reference8 := NULL;
      e_label9 := NULL;
      e_reference9 := NULL;
      e_label10 := NULL;
      e_reference10 := NULL;
      e_label11 := NULL;
      e_reference11 := NULL;
      e_label12 := NULL;
      e_reference12 := NULL;
      e_label13 := NULL;
      e_reference13 := NULL;
      p_status := 0;                                             -- if needed
   EXCEPTION
      WHEN OTHERS
      THEN
         log_error ('Routine', e_module_name, NULL, NULL);
         print_line ('********Error in module: ' || e_module_name);
         print_line (   'Failed to with Error: ' ||  SQLCODE || '|' || SUBSTR (SQLERRM, 1, 80));
         e_program_run_status := 1;
   END;

/*---------------------------------------------------------------------------------------------------------
    Name:  Log error  PROCEDURE
    Description:  PROCEDURE standardizes concurrent program EXCEPTION handling
    error reporting routine.
   ---------------------------------------------------------------------------------------------------------*/
   PROCEDURE log_error (
      label1       IN   VARCHAR2,
      reference1   IN   VARCHAR2,
      label2       IN   VARCHAR2,
      reference2   IN   VARCHAR2
   )
   IS
   BEGIN
      e_error_code := SQLCODE;
      e_error_message := SUBSTR (SQLERRM, 1, 240);
      --cust.ttec_process_error (e_application_code, --code commented by RXNETHI-ARGANO,12/05/23
	  apps.ttec_process_error (e_application_code, --code added by RXNETHI-ARGANO,12/05/23
                               e_interface,
                               e_program_name,
                               e_module_name,
                               e_warning_status,
                               e_error_code,
                               e_error_message,
                               label1,
                               reference1,
                               label2,
                               reference2,
                               e_label3,
                               e_reference3,
                               e_label4,
                               e_reference4,
                               e_label5,
                               e_reference5,
                               e_label6,
                               e_reference6,
                               e_label7,
                               e_reference7,
                               e_label8,
                               e_reference8,
                               e_label9,
                               e_reference9,
                               e_label10,
                               e_reference10,
                               e_label1,
                               e_reference11,
                               e_label12,
                               e_reference12,
                               e_label13,
                               e_reference13,
                               e_label14,
                               e_reference14,
                               e_label15,
                               e_reference15
                              );
   EXCEPTION
      WHEN OTHERS
      THEN
         log_error ('Routine', e_module_name, NULL, NULL);
         print_line ('******Error in module: ' || e_module_name);
         print_line (   'Failed to with Error: ' ||  SQLCODE || '|' || SUBSTR (SQLERRM, 1, 80));
         print_line ('    Error on employee: ' || g_emp_no);
         e_program_run_status := 1;
   END;

/*
------------------------------------------------------------------------------------------------
put the different record data in one large text buffer
------------------------------------------------------------------------------------------------
*/
 PROCEDURE rec_02_write_to (l_rec IN OUT VARCHAR2)
   IS
   BEGIN
      e_module_name := 'REC_02_WRITE';
      l_rec :=
            g_rec2_wr.rec_type
         || g_rec2_wr.op_id
         || g_rec2_wr.ss
         || g_rec2_wr.LAST
         || g_rec2_wr.FIRST
         || g_rec2_wr.mid
         || g_rec2_wr.email
         || g_rec2_wr.address1
         || g_rec2_wr.address2
         || g_rec2_wr.address3
         || g_rec2_wr.city
         || g_rec2_wr.state
         || g_rec2_wr.zip
         || g_rec2_wr.country
         || g_rec2_wr.subs_code
         || g_rec2_wr.location_code
         || g_rec2_wr.title_code
         || g_rec2_wr.officer_code
         || g_rec2_wr.tax_code
         || g_rec2_wr.fica
         || g_rec2_wr.birth_date
         || g_rec2_wr.hire_date
         || g_rec2_wr.term_date
         || g_rec2_wr.term_id
         || g_rec2_wr.nickname
         || g_rec2_wr.user_code1
         || g_rec2_wr.user_code2
         || g_rec2_wr.user_code3
         || g_rec2_wr.user_num
         || g_rec2_wr.ytd_tax
         || g_rec2_wr.salary
         || g_rec2_wr.broker_code
         || g_rec2_wr.user_text1
         || g_rec2_wr.user_text2
         || g_rec2_wr.user_date
         || g_rec2_wr.ytd_fica
         || g_rec2_wr.phone
         || g_rec2_wr.fax
         || g_rec2_wr.not_for_use1
         || g_rec2_wr.not_for_use2
         || g_rec2_wr.not_for_use3
         || g_rec2_wr.upd_last
         || g_rec2_wr.upd_first
         || g_rec2_wr.upd_middle
         || g_rec2_wr.upd_email
         || g_rec2_wr.upd_address1
         || g_rec2_wr.upd_address2
         || g_rec2_wr.upd_address3
         || g_rec2_wr.upd_city
         || g_rec2_wr.upd_state
         || g_rec2_wr.upd_zip
         || g_rec2_wr.upd_country
         || g_rec2_wr.upd_subs
         || g_rec2_wr.upd_loc
         || g_rec2_wr.upd_title
         || g_rec2_wr.upd_officer
         || g_rec2_wr.upd_tax
         || g_rec2_wr.upd_fica
         || g_rec2_wr.upd_birth
         || g_rec2_wr.upd_hire
         || g_rec2_wr.upd_term_date
         || g_rec2_wr.upd_term_id
         || g_rec2_wr.upd_nickname
         || g_rec2_wr.upd_user1
         || g_rec2_wr.upd_user2
         || g_rec2_wr.upd_user3
         || g_rec2_wr.upd_user
         || g_rec2_wr.upd_ytd_taxable
         || g_rec2_wr.upd_salary
         || g_rec2_wr.upd_broker
         || g_rec2_wr.upd_user_text1
         || g_rec2_wr.upd_user_text2
         || g_rec2_wr.upd_user_date
         || g_rec2_wr.upd_ytd_fica
         || g_rec2_wr.upd_phone
         || g_rec2_wr.upd_fax
         || g_rec2_wr.upd_filler1
         || g_rec2_wr.upd_filler2
         || g_rec2_wr.upd_filler3
         || g_rec2_wr.region
         || g_rec2_wr.address_line4
         || g_rec2_wr.address_line5
         || g_rec2_wr.country_of_resid
         || g_rec2_wr.country_of_citizen
         || g_rec2_wr.tax_juris
         || g_rec2_wr.bank_account
         || g_rec2_wr.empl_level_restc
         || g_rec2_wr.lang
         || g_rec2_wr.affiliate
         || g_rec2_wr.mail
         || g_rec2_wr.rehire
         || g_rec2_wr.ytd_medicare
         || g_rec2_wr.ytd_tax1
         || g_rec2_wr.ytd_tax2
         || g_rec2_wr.ytd_tax3
         || g_rec2_wr.ytd_tax4
         || g_rec2_wr.ytd_tax5
         || g_rec2_wr.ytd_tax6
         || g_rec2_wr.ytd_tax7
         || g_rec2_wr.ytd_tax8
         || g_rec2_wr.grant_types
         || g_rec2_wr.grant_medicare
         || g_rec2_wr.msop
         || g_rec2_wr.empl_indicator
         || g_rec2_wr.employee_effective_date
         || g_rec2_wr.population_code
         || g_rec2_wr.special_mail_handling
         || g_rec2_wr.loctrac_country
         || g_rec2_wr.loctrac_loc
         || g_rec2_wr.loctrac_subsid
         || g_rec2_wr.loctrac_user1
         || g_rec2_wr.loctrac_user2
         || g_rec2_wr.loctrac_user3
         || g_rec2_wr.last_date_exer
         || g_rec2_wr.new_optionee_id
         || g_rec2_wr.use_new_optionee
         || g_rec2_wr.retiree_elg_date
         || g_rec2_wr.email_address
         || g_rec2_wr.suppl_comp
         || g_rec2_wr.filler_268
         || g_rec2_wr.filler_1
         || g_rec2_wr.upd_region_flag
         || g_rec2_wr.upd_address_line_4
         || g_rec2_wr.upd_address_line_5
         || g_rec2_wr.upd_country_of_residency
         || g_rec2_wr.upd_country_of_citizenship
         || g_rec2_wr.upd_tax_jurisdiction
         || g_rec2_wr.upd_bank_account_field
         || g_rec2_wr.upd_empl_level_rest
         || g_rec2_wr.upd_language_code
         || g_rec2_wr.upd_affiliate_code
         || g_rec2_wr.upd_mail_code
         || g_rec2_wr.filler_2
         || g_rec2_wr.upd_ytd_medicare
         || g_rec2_wr.upd_ytd_tax_field_1
         || g_rec2_wr.upd_ytd_tax_field_2
         || g_rec2_wr.upd_ytd_tax_field_3
         || g_rec2_wr.upd_ytd_tax_field_4
         || g_rec2_wr.upd_ytd_tax_field_5
         || g_rec2_wr.upd_ytd_tax_field_6
         || g_rec2_wr.upd_ytd_tax_field_7
         || g_rec2_wr.upd_ytd_tax_field_8
         || g_rec2_wr.upd_grant_types_fica
         || g_rec2_wr.upd_grant_types_medicare
         || g_rec2_wr.upd_msop_ind
         || g_rec2_wr.upd_emp_non_emp
         || g_rec2_wr.upd_emp_eff_date
         || g_rec2_wr.upd_pop_code
         || g_rec2_wr.upd_loctrac_efft_country
         || g_rec2_wr.upd_loctrac_code
         || g_rec2_wr.upd_loctrac_subsidia
         || g_rec2_wr.upd_loctrac_user_1
         || g_rec2_wr.upd_loctrac_user_2
         || g_rec2_wr.upd_loctrac_user_3
         || g_rec2_wr.upd_date_to_exercise
         || g_rec2_wr.upd_new_optionee
         || g_rec2_wr.upd_use_new_opt_id
         || g_rec2_wr.upd_retiree_eligible_date
         || g_rec2_wr.upd_supplemental_compensation
         || g_rec2_wr.filler_last;
   EXCEPTION
      WHEN OTHERS
      THEN
         log_error ('Routine', e_module_name, NULL, NULL);
         print_line ('*******Error in module: ' || e_module_name);
         print_line ('  Failed to with Error: ' ||  SQLCODE || '|' || SUBSTR (SQLERRM, 1, 80)); /* 1.5 */
         print_line ('     Error on employee: ' || g_emp_no);
         e_program_run_status := 1;
   END;
/*
------------------------------------------------------------------------------------------------
this is for debugging only. data is inserted in database table for ease of debugging
------------------------------------------------------------------------------------------------
*/
   PROCEDURE rec_02_insert_db
   IS
   BEGIN
      e_module_name := 'REC_02_INSERT_DB';

      --INSERT INTO cust.ttec_rsu_rec_2_tbl --code commented by RXNETHI-ARGANO,12/05/23
	  INSERT INTO apps.ttec_rsu_rec_2_tbl --code added by RXNETHI-ARGANO,12/05/23
           VALUES g_rec2_wr;
   EXCEPTION
      WHEN OTHERS
      THEN
         log_error ('Routine', e_module_name, NULL, NULL);
         print_line ('*******Error in module: ' || e_module_name);
         print_line ('  Failed to with Error: ' || SQLCODE || '|' || SUBSTR (SQLERRM, 1, 80)); /* 1.5 */
         print_line ('     Error on employee: ' || g_emp_no);
         e_program_run_status := 1;
   END;
/*
------------------------------------------------------------------------------------------------
main processing program
------------------------------------------------------------------------------------------------
*/
   PROCEDURE main (
      errcode              VARCHAR2,
      errbuff              VARCHAR2,
      email_to_list   IN   VARCHAR2,
      email_cc_list   IN   VARCHAR2
   )
   IS
--  Program to write out RSU record 02 file
-- Individual bill/company data transmission
--    Wasim Manasfi    Nov 22 2007
--
-- Filehandle Variables
      p_filedir         VARCHAR2 (200);
      p_filename        VARCHAR2 (50);
      p_country         VARCHAR2 (10);
      l_stage           VARCHAR2 (100);
      v_output_file     UTL_FILE.file_type;
      p_status          NUMBER;
      crlf              CHAR (2)           := CHR (10) || CHR (13);
      cr                CHAR (2)           := CHR (13);
      /* email variables */
      l_email_from      VARCHAR2 (256)     := 'EBS_Development@Teletech.com';
      l_email_to        VARCHAR2 (400)     := NULL;
      l_email_subj      VARCHAR2 (256)
                         := 'TeleTech Merril Lynch RSU RECORD 02 File Write ';
      l_email_body1     VARCHAR2 (256)
         := 'Running Concurrent Program: TeleTech Merril Lynch RSU RECORD 02 ';
      l_email_body2     VARCHAR2 (256)
         :=    crlf
            || 'Run Date: '
            || TO_CHAR (SYSDATE, 'MM/DD/YYYY HH24:MM' || '.');
      l_email_body3     VARCHAR2 (256)
                           := 'TeleTech Merril Lynch RSU RECORD 02 File Write';
      l_email_body4     VARCHAR2 (256)
             := 'If you have any questions, please contact the HR Department.';
      l_prcs_fail1      VARCHAR2 (256)
           := '* * * WARNING - Program failed. Check Program log: ';
      l_prcs_fail2      VARCHAR2 (256)
                         := '* * * WARNING - Error in record on line number: ';
      l_host_name       VARCHAR2 (256);
      l_body            VARCHAR2 (8000)
                                       := ' Please review log and output file';
      w_mesg            VARCHAR2 (256);
      l_msg             VARCHAR2 (256);
     -- Declare program variables
      l_rec             VARCHAR2 (4000);
      l_key             VARCHAR2 (400);
      l_file_num        VARCHAR2 (4)       := '01';
      l_tot_rec_count   NUMBER;
      l_seq             NUMBER;
      l_ss_withheld     VARCHAR2(11);
      l_medicare_withheld     VARCHAR2(11); /* 1.5 */

      CURSOR c_host
      IS
         SELECT SUBSTR (host_name, 1, 10)
           FROM v$instance;

      -- get directory path

      -- set directory destination for output file
      -- 1.3 Added CUST_TOP logic to dynamically build path.
      CURSOR c_directory_path
      IS
           SELECT ttec_library.get_directory('CUST_TOP')
               --   || '/data/BenefitInterface/RSU' directory_path
                  || '/data/EBS/HC/Payroll/RSU/Outbound' directory_path     /* 2.0 */
                   , decode(apps.TTEC_GET_INSTANCE,'PROD','TTEC_RSU_RECORD02','TTEC_RSU_RECORD02_TEST')
                  || TO_CHAR (SYSDATE, '_MMDDYYYY_HHMMSS')
                  || '.out' file_name
           FROM dual;

      CURSOR c_rec_02_header
      IS
         SELECT SYSDATE
           FROM DUAL;

      CURSOR c_rec_02_trailer
      IS
         SELECT SYSDATE
           FROM DUAL;

      CURSOR c_get_pay_action ( l_assignment_id NUMBER,
                                l_withheld_type VARCHAR2 /* 1.5 */
                                ) IS
        SELECT DISTINCT
               LPAD(LTRIM(REPLACE(TO_CHAR(pai.action_information9,'99999999.00'),'.','')),11,0) ss_withheld
          FROM pay_action_information pai
         WHERE pai.assignment_id = l_assignment_id
           AND pai.action_information_category = 'AC DEDUCTIONS'
           AND pai.action_information1 = 'Tax Deductions'
           AND pai.action_information10 = l_withheld_type /* 1.5 */
           AND pai.effective_date IN ( SELECT MAX (effective_date)
                                         FROM pay_action_information pai2
                                        WHERE pai2.assignment_id = pai.assignment_id
                                          AND pai2.action_information10 = l_withheld_type /* 1.5 */
                                      );


   BEGIN
      OPEN c_host;

      FETCH c_host
       INTO l_host_name;

      CLOSE c_host;

      e_module_name := 'main';

      EXECUTE IMMEDIATE trunc_stat;

      l_stage := 'c_directory_path';

      OPEN c_directory_path;

      FETCH c_directory_path
       INTO p_filedir, p_filename;

      CLOSE c_directory_path;

      l_stage := 'c_open_file';
      v_output_file := UTL_FILE.fopen (p_filedir, p_filename, 'w', 32000);
      fnd_file.put_line (fnd_file.LOG, '**********************************');
      fnd_file.put_line (fnd_file.LOG,
                            'Output file created >>> '
                         || p_filedir
                         || '/'
                         || p_filename
                        );
      fnd_file.put_line (fnd_file.LOG, '**********************************');
      fnd_file.put_line (fnd_file.output,
                            'Output file created >>> '
                         || p_filedir
                         || '/'
                         || p_filename
                        );
      fnd_file.put_line (fnd_file.output,
                         '**********************************');
      --
      l_tot_rec_count := 0;
      -- set record type 1 all records 220 char long
      l_rec := 'Start Processimg ';
      l_stage := 'Header Record';
      apps.fnd_file.put_line (apps.fnd_file.output, l_rec);
      -- loop on all records
      rec_02_header (l_rec);
      UTL_FILE.put_line (v_output_file, l_rec);

      FOR l_rec2 IN c_rec2_q
      LOOP

        g_emp_no := l_rec2.user_text_1;
        -- Reset to NULL to avoid carryover from previous record

/* 1.6 Begin */
--        l_ss_withheld := NULL;

--        OPEN c_get_pay_action (l_rec2.assignment_id
--                              , 'SS EE Withheld' /* 1.5 */
--                              );
--        FETCH c_get_pay_action
--         INTO l_ss_withheld;
--        CLOSE c_get_pay_action;

--        l_rec2.ss_withheld := l_ss_withheld;
/* 1.6 End */
        l_rec2.ss_withheld := get_YTD_balance (l_rec2.person_id,'SS EE Withheld','_ASG_GRE_RUN','US','USD',TRUNC(SYSDATE));

/* 1.6 Begin */
        /* 1.5 Begin */
        -- Reset to NULL to avoid carryover from previous record
--        l_medicare_withheld := NULL;

--        OPEN c_get_pay_action (l_rec2.assignment_id,'Medicare EE Withheld');
--        FETCH c_get_pay_action
--         INTO l_medicare_withheld;
--        CLOSE c_get_pay_action;

--        l_rec2.medicare_withheld := l_medicare_withheld;

        /* 1.5 End  */
/* 1.6 End */
        l_rec2.medicare_withheld := get_YTD_balance (l_rec2.person_id,'Medicare EE Withheld','_ASG_GRE_RUN','US','USD',TRUNC(SYSDATE));

        l_stage := 'rec_02_fill';
        rec_02_fill (l_rec2, l_rec);
        l_stage := 'rec_02_insert_db';
        rec_02_insert_db;
        l_stage := 'rec_02_write_to';
        rec_02_write_to (l_rec);
        l_stage := 'writing to output file';
        UTL_FILE.put_line (v_output_file, l_rec);
        UTL_FILE.fflush (v_output_file);
        -- get totals
        l_tot_rec_count := l_tot_rec_count + 1;
        apps.fnd_file.put_line (apps.fnd_file.output,
                                   'Processing Record Number: '
                                   || TO_CHAR (l_tot_rec_count)
                                );
      END LOOP;

-------------------------------------------------------------------------------------------------------------------------
      --
      --  Account Trailer Record
      --
      l_stage := 'Trailer Record';

      l_rec := LPAD ('0', 18, '0') || LPAD (' ', 180, ' ');
      rec_02_trailer (l_tot_rec_count, l_rec);
      UTL_FILE.put_line (v_output_file, l_rec);
      UTL_FILE.fclose (v_output_file);
      --
      l_body := 'RSU Record 2 Processed: ';

      IF e_program_run_status = 0
      THEN
         l_email_subj := 'SUCCESS - ' || l_email_subj;
         l_body :=
               'Run Result: * * * SUCCESS * * * '
            || crlf
            || l_email_body3
            || crlf
            || 'Created Output File'
            || p_filedir
            || '/'
            || p_filename
            || crlf
            || l_email_body4
            || crlf
            || 'Total number of employee(s) processed:'
            || l_tot_rec_count
            ;
      ELSE
         l_email_subj := 'FAILURE - ' || l_email_subj;
         l_body :=
               ' Run Result: * * * FAILURE * * * '
            || crlf
            || l_email_body3
            || crlf
            || 'Output File Creation Error: '
            || p_filedir
            || '/'
            || p_filename
            || crlf
            || l_email_body4
            || crlf
            || l_prcs_fail1
            || crlf
            || 'Total number of employee(s) processed:'
            || l_tot_rec_count
            ;

      END IF;

      send_email (ttec_library.XX_TTEC_SMTP_SERVER, /*Rehosting changes in smtp */
                  --l_host_name,
                  l_email_from,
                  email_to_list,
                  email_cc_list,
                  NULL,
                  l_email_subj,                                  -- v_subject,
                  crlf || l_email_body1 || l_email_body2 || crlf,
                                   -- NULL, --                        v_line1,
                  l_body,
                  NULL,
                  NULL,
                  NULL,
                  NULL,
                  -- file_to_send,                                 -- v_file_name,
                  NULL,
                  NULL,
                  NULL,
                  NULL,
                  p_status,
                  w_mesg
                 );
      --print_line ('p_status after email ' || p_status);
      --print_line ('p_status after email ' || w_mesg);
      print_line('');
      print_line('Total number of employee(s) processed:'|| l_tot_rec_count);

   EXCEPTION
      WHEN UTL_FILE.invalid_operation
      THEN
         UTL_FILE.fclose (v_output_file);
         raise_application_error (-20051,
                                  p_filename || ':  Invalid Operation'
                                 );
         print_line ('Error in module: ' || e_module_name);
         ROLLBACK;
      WHEN UTL_FILE.invalid_filehandle
      THEN
         UTL_FILE.fclose (v_output_file);
         raise_application_error (-20052,
                                  p_filename || ':  Invalid File Handle'
                                 );
         print_line ('Error in module: ' || e_module_name);
         ROLLBACK;
      WHEN UTL_FILE.read_error
      THEN
         UTL_FILE.fclose (v_output_file);
         raise_application_error (-20053, p_filename || ':  Read Error');
         print_line ('Error in module: ' || e_module_name);
         ROLLBACK;
      WHEN UTL_FILE.invalid_path
      THEN
         UTL_FILE.fclose (v_output_file);
         raise_application_error (-20054, p_filedir || ':  Invalid Path');
         print_line ('Error in module: ' || e_module_name);
         ROLLBACK;
      WHEN UTL_FILE.invalid_mode
      THEN
         UTL_FILE.fclose (v_output_file);
         raise_application_error (-20055, p_filename || ':  Invalid Mode');
         print_line ('Error in module: ' || e_module_name);
         ROLLBACK;
      WHEN UTL_FILE.write_error
      THEN
         UTL_FILE.fclose (v_output_file);
         raise_application_error (-20056, p_filename || ':  Write Error');
         print_line ('Error in module: ' || e_module_name);
         ROLLBACK;
      WHEN UTL_FILE.internal_error
      THEN
         UTL_FILE.fclose (v_output_file);
         raise_application_error (-20057, p_filename || ':  Internal Error');
         print_line ('Error in module: ' || e_module_name);
         ROLLBACK;
      WHEN UTL_FILE.invalid_maxlinesize
      THEN
         UTL_FILE.fclose (v_output_file);
         raise_application_error (-20058,
                                  p_filename || ':  Maxlinesize Error'
                                 );
         print_line ('Error in module: ' || e_module_name);
         ROLLBACK;
      WHEN OTHERS
      THEN
         UTL_FILE.fclose (v_output_file);
         print_line ('Error in module: ' || e_module_name);
         DBMS_OUTPUT.put_line ('Operation fails on ' || l_stage);
         l_msg := SQLERRM;
         raise_application_error
            (-20003,
                'Exception OTHERS in TeleTech Merrill Lynch RSU Record 02 File Create: '
             || l_msg
            );
         ROLLBACK;
   END main;
END ttec_rsu_rec_02;
/
show errors;
/
