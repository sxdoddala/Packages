create or replace PACKAGE      TTEC_BAML_401K_LOAN_INT AUTHID CURRENT_USER AS
--
-- Program Name:  TTEC_BAML_401K_LOAN_INT
-- /* $Header: TTEC_BAML_401K_LOAN_INT.pks 1.0 2011/11/04  chchan ship $ */
--
-- /*== START ================================================================================================*\
--    Author: Christiane Chan
--      Date: 04-NOV-2011

-- Call From: Concurrent Program ->TeleTech BAML 401K Loan1 Update
--      Desc: Copy from the Old sql code ->ttec_401k_newloan_load.sql
--            This program will accomplish the following:
--            Read employee information which was supplied by BAML
--            from a temporary table
--            The program checks if a new loan setup is sent by BAML
--           for a former employee (terminated or deceased status) - then
--           an Oracle termination report is generated.
--
--           If a new loan setup is sent by BAML with an invalid SSN
--           or if there is already an active loan existing
--           an error log report is generated.
--           Report is generated for all new valid loans
--
--          For new 401K loan  call
--                  PAY_ELEMENT_ENTRY_API.CREATE_ELEMENT_ENTRY
--
--Input/Output Parameters
--
--Tables Accessed: CUST.ttec_us_401k_newloan_tbl def
--                 hr.per_all_people_f emp
--                 per_all_assignments_f asg
--                 hr.hr_locations_all loc
--                 hr.per_person_types
--                 hr.pay_element_links_f
--                 hr.pay_element_types_f
--                 hr.pay_element_entry_values_f
--                 hr.pay_input_values_f
--                 sys.v$database
--
--
--Tables Modified: PAY_ELEMENT_ENTRY_VALUES_F
--
--Procedures Called: PY_ELEMENT_ENTRY.create_element_entry
--                  PAY_ELEMENT_ENTRY_API.UPDATE_ELEMENT_ENTRY
--     Parameter Description:
--
--      p_process_date: Process Date
--
--       Oracle Standard Parameters:
--
--   Modification History:
--
--  Version    Date     Author   Description (Include Ticket--)
--  -------  --------  --------  ------------------------------------------------------------------------------
--      1.0  11/04/11   CChan     Initial Version R#971563 - BOA-Merril Lynch 401K Project
--      2.0  05/21/11   Ravi Pasula    R#1506713
--      2.1  03/10/14   CChan     INC0088400 - Need to be modified to include the assignment status "TTEC Awaiting Integration"
--      1.0	09-May-2023 IXPRAVEEN(ARGANO)   		R12.2 Upgrade Remediation
    -- Error Constants
	--START R12.2 Upgrade Remediation
    /*g_application_code   cust.ttec_error_handling.application_code%TYPE := 'BEN';			-- Commented code by IXPRAVEEN-ARGANO,09-May-2023
    g_interface          cust.ttec_error_handling.INTERFACE%TYPE        := 'BAML Loan Intf';
    g_package            cust.ttec_error_handling.program_name%TYPE     := 'TTEC_BAML_401K_LOAN_INT';
    g_label1             cust.ttec_error_handling.label1%TYPE           := 'Err Location';
    g_label2             cust.ttec_error_handling.label1%TYPE           := 'Emp_Number';
    g_warning_status     cust.ttec_error_handling.status%TYPE           := 'WARNING';
    g_error_status       cust.ttec_error_handling.status%TYPE           := 'ERROR';
    g_failure_status     cust.ttec_error_handling.status%TYPE           := 'FAILURE';*/
	g_application_code   apps.ttec_error_handling.application_code%TYPE := 'BEN';			--  code Added by IXPRAVEEN-ARGANO,09-May-2023
    g_interface          apps.ttec_error_handling.INTERFACE%TYPE        := 'BAML Loan Intf';
    g_package            apps.ttec_error_handling.program_name%TYPE     := 'TTEC_BAML_401K_LOAN_INT';
    g_label1             apps.ttec_error_handling.label1%TYPE           := 'Err Location';
    g_label2             apps.ttec_error_handling.label1%TYPE           := 'Emp_Number';
    g_warning_status     apps.ttec_error_handling.status%TYPE           := 'WARNING';
    g_error_status       apps.ttec_error_handling.status%TYPE           := 'ERROR';
    g_failure_status     apps.ttec_error_handling.status%TYPE           := 'FAILURE';
	--END R12.2.10 Upgrade remediation
    -- Process FAILURE variables
    g_fail_flag                   BOOLEAN := FALSE;
    g_emp_no                       varchar2(20);
/***Variables used by Common Error Procedure***/
g_validate               boolean          := false;
g_entry_type             varchar2(1)     := 'E';
g_newloan_date           date;

p_newloan_active        VARCHAR2(50)          := 'NewLoan_Wachovia_Active.txt';
--p_newloan_comparison    VARCHAR2(50)          := 'NewLoan_Comparison.txt';
p_newloan_errorlog      VARCHAR2(50)          := 'NewLoan_ErrorLog.txt';
p_newloan_oratermed     VARCHAR2(50)          := 'NewLoan_Oracle_Termed.txt';


l_errorlog_output  varchar2(3020);         --CHAR(400);
l_updated_output    varchar2(3020);       -- CHAR(400);
l_update_status     varchar2(25):= 'Did Not Update';
l_isthere_newloan    varchar2(25):= 'NO';

v_active_file         UTL_FILE.FILE_TYPE;
--v_comparison_file     UTL_FILE.FILE_TYPE;
v_errorlog_file       UTL_FILE.FILE_TYPE;
v_oratermed_file      UTL_FILE.FILE_TYPE;


v_errorlog_count    number := 0;
--v_updated_count    number := 0;
--*****************************************************************************************************

g_element_name VARCHAR2(50):= 'Loan 1_401k';
g_input_name VARCHAR2(50) := 'Amount';

ERRBUF  VARCHAR2(50);
RETCODE  NUMBER;
P_OUTPUT_DIR   VARCHAR2(400);
/***Exceptions***/

SKIP_RECORD       EXCEPTION;
SKIP_RECORD2       EXCEPTION;
SKIP_RECORD3       EXCEPTION;

/***Cursor declaration***/

    -- Filehandle Variables
    p_FileDir                      varchar2(400);
    p_FileName                     varchar2(100);
    p_Country                      varchar2(10);

cursor csr_newloan is
select distinct papf.first_name||' '||papf.last_name full_name,substr(field1,1,3)||'-'||substr(field1,4,2)||'-'||substr(field1,6,4) social_number,
       field2 emp_no,
       to_number(field5)/100 payment_amt,
       to_number(field9)/100 goal_amt
from TTEC_401K_BAML_LOAN_STG t,
        per_all_people_f papf
where t.rec_type not in ('UH','UT')
and t.field2  = papf.employee_number
and papf.effective_start_date = (select max(effective_start_date) from per_all_people_f where
                                            employee_number = papf.employee_number); -- version 2.0

/*
select t_type
, ss_number                        social_number
, last_name                  last_name
, first_name              first_name
, loan_effective_date      newloan_date
, payment_amount          payment_amt
, goal_amount              goal_amt
, unit_division              unit_division
, attribute1              plan_type_id
, attribute2              report_date
from CUST.ttec_tti_newloan_tbl
where t_type = '2'
--and ss_number = '541-04-7692';
order by attribute1 desc,last_name,first_name asc; --desc;
*/

 --************************************************************************************--
  --*                          GET ASSIGNMENT ID                                       *--
  --************************************************************************************--

    PROCEDURE get_assignment_id
                                (v_ssn  IN VARCHAR2
                                ,v_employee_number OUT VARCHAR2
                                ,p_assignment_id       OUT NUMBER
                                ,p_business_group_id   OUT NUMBER
                                ,p_payroll_id          OUT      NUMBER  /* 2.1 */
                                ,p_location_id         OUT      NUMBER  /* 2.1 */
                                ,p_effective_start_date OUT DATE
                                ,p_effective_end_date   OUT DATE
                                ,p_process_status       OUT VARCHAR2
                                );

PROCEDURE  get_location (v_ssn IN VARCHAR2
                        ,v_location_code OUT VARCHAR2
                        ,p_process_status  OUT VARCHAR2
                        );

--***************************************************************
--*****                  GET PERSON TYPE                *****
--***************************************************************
 --get_person_type(sel.employee_number, l_system_person_type);
PROCEDURE  get_person_type (v_ssn IN VARCHAR2
                              ,v_person_id OUT NUMBER
                           ,v_assignment_id IN NUMBER
                           ,v_pay_basis_id OUT NUMBER
                           ,v_employment_category OUT VARCHAR2
                           ,v_people_group_id OUT NUMBER
                             ,v_system_person_type OUT VARCHAR2
                            ,p_process_status  OUT VARCHAR2  );
---**************************************************************************************

PROCEDURE  get_employee_status (v_ssn IN VARCHAR2
                                ,v_system_person_status OUT VARCHAR2
                                ,p_process_status  OUT VARCHAR2
                                );

PROCEDURE get_element_entry_id (v_ssn IN VARCHAR2
                               ,v_element_entry_id OUT NUMBER
                               ,p_isthere_newloan IN OUT VARCHAR2
                               ,p_process_status  OUT VARCHAR2
                                );

--***************************************************************
--*****                  GET Element Link ID                *****
--***************************************************************

PROCEDURE get_element_link_id (v_ssn IN VARCHAR2
                                ,v_element_name IN VARCHAR2
                                ,v_business_group_id IN NUMBER
                              ,v_pay_basis_id IN NUMBER
                              ,v_employment_category IN VARCHAR2
                              ,v_people_group_id IN NUMBER
                              ,v_payroll_id      IN NUMBER  /* 2.1 */
                              ,v_location_id     IN NUMBER  /* 2.1 */
                              ,v_element_link_id OUT NUMBER
                              ,p_process_status  OUT VARCHAR2
                              );

--***************************************************************
--*****               Create Element Entry            *****
--***************************************************************

PROCEDURE do_create_element_entry (v_ssn IN VARCHAR2
                       ,l_validate IN boolean
                         ,l_loan_effective_date IN DATE
                       ,l_business_group_id IN NUMBER
                       ,l_assignment_id IN NUMBER
                       ,l_element_link_id IN NUMBER
                       ,l_input_value_id_amount IN NUMBER
                       ,l_payment_amt IN NUMBER
                       ,l_input_value_id_owed IN NUMBER
                       ,l_goal_amt IN NUMBER
                       ,l_update_status IN OUT VARCHAR2);

--*****                  MAIN Program                       *****
--***************************************************************
    PROCEDURE main(
          errcode        OUT VARCHAR2,
          errbuff        OUT VARCHAR2,
          P_PROCESS_DATE IN  VARCHAR2);

END TTEC_BAML_401K_LOAN_INT;
/
show errors;
/