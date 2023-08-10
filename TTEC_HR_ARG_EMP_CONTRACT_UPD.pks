create or replace PACKAGE      ttec_hr_arg_emp_contract_upd
AUTHID CURRENT_USER AS
/* $Header: ttec_hr_emp_contract_upd_pkg.pkb 1.0 2011/06/21 kbabu $ */
/*== START ================================================================================================*\
  Author:  Kaushik Babu
    Date:  June 21, 2011
    Desc:  An automated process needs to be created in order to update the contract type in ARG when certain conditions are met.
          "When an employee�s contract is set to "14 - Nuevo Periodo de Prueba" and more than
           90 days have passed since the hire date ("date_start" column on "per_periods_of_service" table), the employees
           record should be updated to "8 - Indeterminado" effective 91 days after hire date."
  Modification History:

 Mod#  Person         Date     Comments
---------------------------------------------------------------------------
 1.0  Kaushik Babu  21-June-11 Created new package TTSD R 569640
 1.0    MXKEERTHI(ARGANO)  17-JUN-2023              R12.2 Upgrade Remediation
\*== END ==================================================================================================*/
-- Error Constants
    --START R12.2 Upgrade Remediation
	  /*
	  g_application_code   cust.ttec_error_handling.application_code%TYPE   := 'HR';
   g_interface          cust.ttec_error_handling.INTERFACE%TYPE          := 'EmpContractUpd';
   g_package            cust.ttec_error_handling.program_name%TYPE       := 'TTEC_HR_EMP_CONTRACT_UPD';
	   */
	  --code Added  by MXKEERTHI-ARGANO, 07/17/2023
	 g_application_code APPS.ttec_error_handling.application_code%TYPE   := 'HR';
   g_interface          APPS.ttec_error_handling.INTERFACE%TYPE          := 'EmpContractUpd';
   g_package            APPS.ttec_error_handling.program_name%TYPE       := 'TTEC_HR_EMP_CONTRACT_UPD';
	  --END R12.2.10 Upgrade remediation


   g_status_warning     VARCHAR2 (7)                                     := 'WARNING';
   g_status_failure     VARCHAR2 (7)                                     := 'FAILURE';
   g_fail_msg           VARCHAR2 (240)                                   DEFAULT NULL;
    --   g_module             cust.ttec_error_handling.module_name%TYPE        DEFAULT NULL; --Commented code by MXKEERTHI-ARGANO,07/17/2023
   g_module             APPS.ttec_error_handling.module_name%TYPE        DEFAULT NULL; --code added by MXKEERTHI-ARGANO, 07/17/2023



   PROCEDURE main_proc (
      p_errbuf            IN   VARCHAR2,
      p_errcode           IN   NUMBER,
      p_business_grp_id   IN   NUMBER,
      p_person_id         IN   NUMBER,
      p_contract_type     IN   VARCHAR2
   );
END ttec_hr_arg_emp_contract_upd;
/
show errors;
/