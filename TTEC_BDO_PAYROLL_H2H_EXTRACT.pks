create or replace PACKAGE      TTEC_BDO_PAYROLL_H2H_EXTRACT AS
--
-- Program Name:  TTTEC_BDO_PAYROLL_H2H_EXTRACT
--
-- Description:  This program generates Payroll File Format for HOST TO HOST (H2H) file format mandated by:
--               BDO's BOB document issued on December 04, 2017
--
-- Input/Output Parameters:
--
--
--
-- Tables Modified:  N/A
--
--
-- Created By:  Christiane Chan
-- Date: Dec 12, 2017
--
-- Modification Log:
-- Developer        Date        Description
-- ----------       --------    --------------------------------------------------------------------
-- Global Variables ---------------------------------------------------------------------------------
PROCEDURE gen_payment_file(errbuf OUT VARCHAR2, retcode OUT NUMBER,
                           p_output_directory       IN       VARCHAR2,
                           p_filename_prefix        IN       VARCHAR2,
                           p_payroll_id             IN       NUMBER,
                           p_employee_number        IN       VARCHAR2,
                           p_pay_date               IN       VARCHAR2,
                           p_bank_trx_time          IN       VARCHAR2,
						   p_org_bank_number        IN       VARCHAR2,
                           p_org_bank_name          IN       VARCHAR2,
                           p_ORG_PYMT_METHOD_NAME   IN       VARCHAR2,
                           p_action_info_cat_name   IN       VARCHAR2,
                           p_manual_upload          IN       VARCHAR2
						 );
END TTEC_BDO_PAYROLL_H2H_EXTRACT;