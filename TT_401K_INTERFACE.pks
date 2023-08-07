create or replace package TT_401K_INTERFACE AUTHID CURRENT_USER is

/***********************************************************************************/
-- Program Name:  FIRST_UNION_401K
--
-- Description:  This program will provide an extract of the Oracle HR and Payroll system
-- to be provided to First Union. The extracted data will contain employment, load and
-- 401K information for employees.
--
-- Input/Output Parameters:
--
-- Oracle Tables Accessed:  HR_LOCATIONS_ALL
--                          PAY_BLANCE_TYPES
--                          PER_ALL_PEOPLE_F
--                          PER_ADDRESSES
--                          PER_ALL_ASSIGNMENTS_F
--                          PER_ANALYSIS_CRITERIA
--                          PER_PERSON_ANALSES
--                          PER_PERSON_TYPES
--				            PER_PERIODS_OF_SERVICE
--                          XKB_BALANCES
--                          XKB_BALANCE_DETAILS
--
-- Tables Modified:  N/A
--
-- Procedures Called:  TTEC_PROCESS_ERROR
--
-- Created By:  C.Boehmer
-- Date: August 13, 2002
--
-- Modification Log:
-- Developer    Date       Description
-- ----------  --------   --------------------
-- CBoehmer    03-SEP-02  Remove unused procedures
-- CBoehmer    01-OCT-02  Added calls to call_Balance_user_exit_401k to get ytd comp results
-- CBoehmer    03-OCT-02  Converted code to use XKB (Kbace) tables for pay balance amounts
-- IKONAK      01-JAN-03  Rewrote program, changed into package
-- IKONAK      11-APR-03  Change compensation balance to YTD
-- RXNETHI-ARGANO  29-JUN-23  R12.2 Upgrade Remediation
/************************************************************************************/


-- Global Variables ---------------------------------------------------------------------------------
g_plan_1 VARCHAR2(50):= 'wachovia';

g_transaction_type				 varchar2(1) := 'P';
g_header_type					 varchar2(1) := 'H';
g_trailer_type					 varchar2(1) := 'T';
g_plan_id  						 varchar2(8) := '00000TTI';

-- Variables used by Common Error Procedure
/*
START R12.2 Upgrade Remediation
code commented by RXNETHI-ARGANO,29/06/23
g_application_code               CUST.TTEC_error_handling.application_code%TYPE := '401';
g_interface                      CUST.TTEC_error_handling.interface%TYPE := 'PAY-INT-01';
g_program_name                   CUST.TTEC_error_handling.program_name%TYPE := 'WACHOVIA_401K';
g_initial_status                 CUST.TTEC_error_handling.status%TYPE := 'INITIAL';
g_warning_status                 CUST.TTEC_error_handling.status%TYPE := 'WARNING';
g_failure_status                 CUST.TTEC_error_handling.status%TYPE := 'FAILURE';
*/
--code added by RXNETHI-ARGANO,29/06/23
g_application_code               APPS.TTEC_error_handling.application_code%TYPE := '401';
g_interface                      APPS.TTEC_error_handling.interface%TYPE := 'PAY-INT-01';
g_program_name                   APPS.TTEC_error_handling.program_name%TYPE := 'WACHOVIA_401K';
g_initial_status                 APPS.TTEC_error_handling.status%TYPE := 'INITIAL';
g_warning_status                 APPS.TTEC_error_handling.status%TYPE := 'WARNING';
g_failure_status                 APPS.TTEC_error_handling.status%TYPE := 'FAILURE';
--END R12.2 Upgrade Remediation

--g_effective_date				 DATE := to_date(P_END_DATE,'DD-MON-YYYY');

-- Filehandle Variables
-- p_FileDir VARCHAR2(100)          := '/d01/oravis/visappl/teletech/11.5.0/data/BenefitInterface';  --'/usr/tmp';
--'/d01/oracle/prodappl/teletech/11.5.0/data/BenefitInterface';  'CUST_TOP/data/BenefitInterface'
p_FileName VARCHAR2(50)          := 'wachovia_401k_'||to_char(sysdate, 'YYYYMMDD_HH24MISS')||'.txt';
v_daily_file UTL_FILE.FILE_TYPE;


PROCEDURE main (ERRBUF OUT VARCHAR2, RETCODE OUT NUMBER,
                          P_BEGIN_DATE IN DATE, P_END_DATE IN DATE,
						  P_OUTPUT_DIR IN VARCHAR2 );


PROCEDURE get_balance_amount (v_person_id IN NUMBER, v_balance_type IN VARCHAR2,
                              v_begin_date IN DATE, v_end_date IN DATE,
                              v_balance OUT NUMBER);



end TT_401K_INTERFACE;
/
show errors;
/