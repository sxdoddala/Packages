create or replace PACKAGE Tt_401k_Interface_2005  AUTHID CURRENT_USER IS

/***********************************************************************************/
-- Program Name: WACHOVIA_401K
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
-- Elango      28-DEC-05  Eliminate duplicate employees (Exclude FEMA and full time and partime temp. employees )
-- C. Chan     22-FEB-06  Modify the logic to call the package TT_HR.get_401K_plan_type to avoid maintaining
--                       the same logic in 2 different packages.
-- RXNETHI-ARGANO 29-JUN-2023 R12.2 Upgrade Remediation
/************************************************************************************/


-- Global Variables ---------------------------------------------------------------------------------

g_transaction_type				  VARCHAR2(1) := 'P';
g_header_type					    VARCHAR2(1) := 'H';
g_trailer_type					        VARCHAR2(1) := 'T';

g_plan_id_TTI  						 VARCHAR2(8) := '00000TTI';
g_plan_id_TT2  						VARCHAR2(8) := '00000TT2';

g_year_begin                DATE := TO_DATE('27-dec-2004')  ;

skip_record                      EXCEPTION;

-- Variables used by Common Error Procedure
/*
START R12.2 Upgrade Remediation
code commented by RXNETHI-ARGANO,29/06/23
g_application_code                   CUST.TTEC_ERROR_HANDLING.application_code%TYPE := '401';
g_interface                          CUST.TTEC_ERROR_HANDLING.INTERFACE%TYPE := 'PAY-INT-01';
g_program_name                       CUST.TTEC_ERROR_HANDLING.program_name%TYPE := 'WACHOVIA_401K';
g_initial_status                     CUST.TTEC_ERROR_HANDLING.status%TYPE := 'INITIAL';
g_warning_status                     CUST.TTEC_ERROR_HANDLING.status%TYPE := 'WARNING';
g_failure_status                     CUST.TTEC_ERROR_HANDLING.status%TYPE := 'FAILURE';
*/
--code added by RXNETHI-ARGANO,29/06/23
g_application_code                   APPS.TTEC_ERROR_HANDLING.application_code%TYPE := '401';
g_interface                          APPS.TTEC_ERROR_HANDLING.INTERFACE%TYPE := 'PAY-INT-01';
g_program_name                       APPS.TTEC_ERROR_HANDLING.program_name%TYPE := 'WACHOVIA_401K';
g_initial_status                     APPS.TTEC_ERROR_HANDLING.status%TYPE := 'INITIAL';
g_warning_status                     APPS.TTEC_ERROR_HANDLING.status%TYPE := 'WARNING';
g_failure_status                     APPS.TTEC_ERROR_HANDLING.status%TYPE := 'FAILURE';
--END R12.2 Upgrade Remediation


p_FileName_TTI   VARCHAR2(50)          := 'wachovia_401k_TTI_'||TO_CHAR(SYSDATE, 'YYYYMMDD_HH24MISS')||'.txt';
p_FileName_TT2  VARCHAR2(50)         := 'wachovia_401k_TT2_'||TO_CHAR(SYSDATE, 'YYYYMMDD_HH24MISS')||'.txt';
v_daily_file_TTI  UTL_FILE.FILE_TYPE;
v_daily_file_TT2  UTL_FILE.FILE_TYPE;



TYPE T_TRAILER_INFO IS RECORD
(
  trl_transaction_type   VARCHAR2(1) := 'T'
, trl_hours_ytd          VARCHAR2(10) := NULL
, trl_cum_hours          VARCHAR2(10) := NULL
, trl_prior_months       VARCHAR2(10) := 0
, trl_money_type1        VARCHAR2(10) := NULL
, trl_money_type2        VARCHAR2(10) := NULL
, trl_money_type3        VARCHAR2(10) := NULL
, trl_money_type4        VARCHAR2(10) := NULL
, trl_money_type5        VARCHAR2(10) := NULL
, trl_money_type6        VARCHAR2(10) := NULL
, trl_money_type7        VARCHAR2(10) := NULL
, trl_money_type8        VARCHAR2(10) := NULL
, trl_money_type9        VARCHAR2(10) := NULL
, trl_money_type10        VARCHAR2(10) := NULL
, trl_money_type11        VARCHAR2(10) := NULL
, trl_money_type12        VARCHAR2(10) := NULL
, trl_money_type13        VARCHAR2(10) := NULL
, trl_money_type14        VARCHAR2(10) := NULL
, trl_money_type15        VARCHAR2(10) := NULL
, trl_loan1               VARCHAR2(10) := NULL
, trl_loan2               VARCHAR2(10) := NULL
, trl_loan3               VARCHAR2(10) := NULL
, trl_loan4               VARCHAR2(10) := NULL
, trl_loan5               VARCHAR2(10) := NULL
, trl_loan6               VARCHAR2(10) := NULL
, trl_loan7               VARCHAR2(10) := NULL
, trl_loan8               VARCHAR2(10) := NULL
, trl_loan9               VARCHAR2(10) := NULL
, trl_loan10              VARCHAR2(10) := NULL
, trl_comp_amount0        VARCHAR2(100) := NULL
, trl_comp_amount1        VARCHAR2(100) := NULL
, trl_comp_amount5        VARCHAR2(100) := NULL
, trl_salary                   VARCHAR2(100) := NULL
, trl_elig_months        VARCHAR2(100) := NULL
);




PROCEDURE main (ERRBUF OUT VARCHAR2, RETCODE OUT NUMBER,
                          P_BEGIN_DATE IN DATE, P_END_DATE IN DATE, P_ELIGIBLE_DATE IN DATE,
						  P_OUTPUT_DIR IN VARCHAR2 );


PROCEDURE get_balance_amount (v_person_id IN NUMBER, v_balance_type IN VARCHAR2,
                              v_begin_date IN DATE, v_end_date IN DATE,
                              v_balance OUT NUMBER);



END Tt_401k_Interface_2005;
/
show errors;
/