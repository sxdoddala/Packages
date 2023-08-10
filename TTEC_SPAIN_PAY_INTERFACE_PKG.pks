create or replace PACKAGE Ttec_Spain_Pay_Interface_Pkg AS
--------------------------------------------------------------------
--                                                                --
--     Name:  ttech_spain_pay_inteface_pkg       (Package)              --
--                                                                --
--     Description:   Data extraction - Spain HR Data for the   Payroll Vendor ( META4)  --
--
--     Change History                                             --
--                                                                --
--     Changed By        Date        Reason for Change            --
--     ----------        ----        -----------------            --
--     Dibyendu Roy   22-Mar-2005    Initial Creation For Spain  --
--     RXNETHI-ARGANO 16-May-2023    R12.2 Upgrade Remediation                                                    --
--                                                                --
--------------------------------------------------------------------
PROCEDURE extract_spain_emps (ov_errbuf       OUT VARCHAR2,
                              ov_retcode      OUT NUMBER,
                              iv_cut_off_Date  IN VARCHAR2      --  Modified by C.Chan on 27-DEC-2005 for TT#411517
							  --baseline_indicator IN VARCHAR2
							  );  --  Modified by C.Chan on 01-FEB-2005 for TT#456121
FUNCTION scrub_to_number    (iv_text        IN VARCHAR2) RETURN VARCHAR2;
FUNCTION  pad_data_output(iv_field_type   IN VARCHAR2,
                            iv_pad_length   IN NUMBER,
                            iv_field_value   IN VARCHAR2) RETURN VARCHAR2 ;
PRAGMA RESTRICT_REFERENCES(scrub_to_number,WNDS,WNPS,RNPS);
FUNCTION Record_Changed_V (P_Column_Name IN VARCHAR2,
			 P_Person_Id IN NUMBER,
			 P_Assignment_Id IN NUMBER,
			 p_g_sysdate IN DATE) RETURN VARCHAR2;

FUNCTION Record_Changed_rehire
                        ( p_Person_Id IN NUMBER,
                          p_g_sysdate IN DATE
                        )  RETURN VARCHAR2;
PROCEDURE Record_Changed_term_his
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
                         p_term_his                  OUT VARCHAR2);
PROCEDURE populate_interface_tables;
PROCEDURE extract_hires;
PROCEDURE extract_emp_info_change;
PROCEDURE extract_emp_address_change; -- MDD
PROCEDURE extract_emp_assignment1_change; -- MAP
PROCEDURE extract_emp_assignment2_change; -- MAR
PROCEDURE extract_termination;  -- NBE
PROCEDURE extract_emp_bankdata_change; --- MDB
PROCEDURE extract_emp_salary_change; --- MDS
-- global variable definitions
g_cut_off_date           	  DATE;
g_start_cut_off_date          DATE;
g_max_cut_off_date            DATE;
g_date_interval               NUMBER;
g_sysdate                     	 DATE                      := TRUNC(SYSDATE);
g_retcode                        NUMBER               := 0;
g_errbuf                            VARCHAR2(500) := NULL;
g_business_group_id      NUMBER;
--
g_payroll_name                    VARCHAR2(150);
g_period_name                     VARCHAR2(150);
g_start_date                            DATE;
g_end_date                             DATE;
g_pay_advice_date             DATE;
g_regular_payment_date   DATE;
--
--paaf_effective_start_date       hr.per_all_assignments_f.effective_start_date%TYPE;  --code commented by RXNETHI-ARGANO,16/05/23
paaf_effective_start_date       apps.per_all_assignments_f.effective_start_date%TYPE;  --code added by RXNETHI-ARGANO,16/05/23
g_e_abort                      EXCEPTION;
g_e_future_date          EXCEPTION;
END; -- Package ttec_spain_pay_interface_pkg
/
show errors;
/