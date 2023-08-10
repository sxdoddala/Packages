create or replace PACKAGE BODY      TTEC_UPD_EMP_PAYMENT_METHOD AS
--
-- Program Name:  TTEC_UPD_EMP_PAYMENT_METHOD
-- /* $Header: TTEC_UPD_EMP_PAYMENT_METHOD.pkb 1.0 2010/05/12 chchan ship $ */
--
-- /*== START ================================================================================================*/
--    Author: Christiane Chan
--      Date: 12-MAY-2010
--
--  Call From: Concurrent Program ->TeleTech Update Employee Personal Payment Method
--       Desc: This program updates employee 's payment method using Oracle seeded API.
--             The employee(s) who need(s) to be updated will be uploaded via an external
--             Custom table -> CUST.TTEC_EMP_PAY_METHOD_UPD_LOAD.
--
--             CUST.TTEC_EMP_PAY_METHOD_UPD_LOAD
--             (
--               EMPLOYEE_NUMBER               VARCHAR2(30 BYTE),
--               CURRENT_BANK_ACCOUNT_NUMBER   VARCHAR2(100 BYTE),
--               CURRENT_TRANSIT_CODE          VARCHAR2(100 BYTE),
--               CURRENT_BANK_BRANCH           VARCHAR2(100 BYTE),
--               NEW_BANK_ACCOUNT_NUMBER       VARCHAR2(100 BYTE),
--               NEW_TRANSIT_CODE              VARCHAR2(100 BYTE),
--               NEW_BANK_BRANCH               VARCHAR2(100 BYTE)
--             )
--
--
--          Parameter Description:
--     Oracle Standard Parameters:
--
--           p_business_group_id - Business group to be processed
--
--   Modification History:
--
--  Version    Date       Author   Description (Include Ticket--)
--  -------  ----------  --------  ------------------------------------------------------------------------------
--      1.0  05/12/2010   CChan    Initial Version (TTECH #R 189995)
--      1.0  17/MAY/2023  RXNETHI-ARGANO  R12.2 Upgrade Remediation
-- /*== END =====================================================================================================*/
   PROCEDURE main (
      errcode                          VARCHAR2
    , errbuff                          VARCHAR2
    , p_business_group_id         IN   NUMBER
   )
   IS

      -- Declare variables
      v_msg                      VARCHAR2 (2000);
      v_stage                    VARCHAR2 (100);
      v_element                  VARCHAR2 (100);
      v_rec                      VARCHAR2 (500);
      v_key                      VARCHAR2 (100);

      v_update_status            VARCHAR2 (400);
      v_validate                 BOOLEAN:= FALSE;
      v_update_mode              VARCHAR2 (10):= 'UPDATE';
      v_effective_start_date         DATE;
      v_effective_end_date           DATE;
      v_comment_id                   NUMBER;
      v_external_account_id          NUMBER;

      v_tot_rec_count            NUMBER:=0;
      v_tot_rec_success          NUMBER:=0;
      v_tot_rec_fail             NUMBER:=0;
      v_tot_rec_api_error        NUMBER:=0;

      /*
	  START R12.2 Upgrade Remediation
	  code commented by RXNETHI-ARGANO,17/05/23
	  v_personal_payment_method_id   hr.pay_personal_payment_methods_f.personal_payment_method_id%TYPE;
      v_obj_ver                      hr.pay_personal_payment_methods_f.object_version_number%TYPE;
	  */
	  --code added by RXNETHI-ARGANO,17/05/23
	  v_personal_payment_method_id   apps.pay_personal_payment_methods_f.personal_payment_method_id%TYPE;
      v_obj_ver                      apps.pay_personal_payment_methods_f.object_version_number%TYPE;
	  --END R12.2 Upgrade Remediation

      CURSOR c_emp_load
      IS
         SELECT *
         FROM TTEC_EMP_PAY_METHOD_UPD_LOAD;
      --
      --  Main query to obtain participant data from HR tables
      --
      CURSOR c_emp_cur  (p_employee_number      IN per_all_people_f.employee_number%TYPE,
                         /*
						 START R12.2 Upgrade Remediation
						 code commented by RXNETHI-ARGANO,17/05/23
						 p_bank_account_number  IN hr.pay_external_accounts.segment3%TYPE,
                         p_bank_transit_number  IN hr.pay_external_accounts.segment4%TYPE,
                         p_bank_branch          IN hr.pay_external_accounts.segment6%TYPE
						 */
						 --code added by RXNETHI-ARGANO,17/05/23
						 p_bank_account_number  IN apps.pay_external_accounts.segment3%TYPE,
                         p_bank_transit_number  IN apps.pay_external_accounts.segment4%TYPE,
                         p_bank_branch          IN apps.pay_external_accounts.segment6%TYPE
						 --END R12.2 Upgrade Remediation
                        )
      IS
         SELECT pppm.personal_payment_method_id
              , pppm.object_version_number
         /*
		 FROM   hr.per_all_people_f papf
              , hr.per_all_assignments_f paaf
              , hr.pay_personal_payment_methods_f pppm
              , hr.pay_external_accounts pea
         */
		 --code added by RXNETHI-ARGANO,17/05/23
		 FROM   apps.per_all_people_f papf
              , apps.per_all_assignments_f paaf
              , apps.pay_personal_payment_methods_f pppm
              , apps.pay_external_accounts pea
		 --END R12.2 Upgrade Remediation
		  WHERE papf.business_group_id = p_business_group_id
            AND papf.person_id         = paaf.person_id
            AND paaf.assignment_type   = 'E'
            AND paaf.pay_basis_id IS NOT NULL
            AND TRUNC (SYSDATE) BETWEEN papf.effective_start_date
                                    AND papf.effective_end_date
            AND TRUNC (SYSDATE) BETWEEN paaf.effective_start_date
                                    AND paaf.effective_end_date
            AND paaf.assignment_id       = pppm.assignment_id
            AND pppm.external_account_id = pea.external_account_id
            AND TRUNC (SYSDATE) BETWEEN pppm.effective_start_date
                                    AND pppm.effective_end_date
            AND pea.segment3         = p_bank_account_number
            AND pea.segment4         = p_bank_transit_number
            AND pea.segment6         = p_bank_branch
            AND papf.employee_number = p_employee_number;

   BEGIN
      v_stage := 'Writing to Output file';
      --
      -- This is required for the API to work (known BUG)
      --
      INSERT INTO fnd_sessions (SESSION_ID,effective_date)
      values(userenv('SESSIONID'),SYSDATE);

      COMMIT;
      --
      -- Writing to Output file
      --

      FND_FILE.put_line
         (FND_FILE.output
        , '             Concurrent Program: TeleTech Update Employee Personal Payment Method'
         );
      FND_FILE.put_line (FND_FILE.output
                       ,    '                Processing Date: '
                         || TO_CHAR (SYSDATE, 'DD-MON-RRRR HH24:MI:SS')
                        );
      FND_FILE.put_line (FND_FILE.output, '');
      FND_FILE.put_line
                        (FND_FILE.output
                       ,    'Employee Number'
                         || ','
                         || 'Current Account Number'
                         || ','
                         || 'Current Transit Code'
                         || ','
                         || 'Current Bank Branch'
                         || ','
                         || 'New Account Number'
                         || ','
                         || 'New Transit Code'
                         || ','
                         || 'New Bank Branch'
                         || ','
                         || 'Update Status'
                        );
      --
      -- Printing Parameters to Log file
      --

      FND_FILE.put_line (FND_FILE.log
                       ,    'PARAMETERS:'
                        );
      FND_FILE.put_line (FND_FILE.log
                       ,    '  Business Group Id              : '
                         || TO_CHAR(p_business_group_id)
                        );
      v_stage := 'c_emp_load';

      FOR emp_rec IN c_emp_load
      LOOP
         BEGIN
            OPEN c_emp_cur (emp_rec.employee_number,
                            emp_rec.current_bank_account_number,
                            emp_rec.current_transit_code,
                            emp_rec.current_bank_branch
                            );

            FETCH c_emp_cur
             INTO v_personal_payment_method_id
                , v_obj_ver;

            IF c_emp_cur%NOTFOUND
            THEN
               v_personal_payment_method_id := '';
               v_obj_ver                  := '';
               v_update_status              := 'Cannot be Updated: Please review the current employee personal payment method setup in Oracle; It is either Not Found or with Future Entry...';
               v_tot_rec_fail               := v_tot_rec_fail + 1;
            ELSE
               IF   emp_rec.new_bank_account_number IS NOT NULL AND
                    emp_rec.new_transit_code IS NOT NULL AND
                    emp_rec.new_bank_branch IS NOT NULL
               THEN
                  BEGIN
                    v_stage := 'c_upd_personal_pay_method_API';

                    hr_personal_pay_method_api.update_personal_pay_method
                    (  p_validate                      => v_validate
                      ,p_effective_date                => SYSDATE
                      ,p_datetrack_update_mode         => v_update_mode
                      ,p_personal_payment_method_id    => v_personal_payment_method_id
                      ,p_segment3                      => emp_rec.new_bank_account_number
                      ,p_segment4                      => emp_rec.new_transit_code
                      ,p_segment6                      => emp_rec.new_bank_branch
                      --IN OUT Parameters
                      ,p_object_version_number         => v_obj_ver
                      --OUT Parameters
                      ,p_comment_id                    => v_comment_id
                      ,p_external_account_id           => v_external_account_id
                      ,p_effective_start_date          => v_effective_start_date
                      ,p_effective_end_date            => v_effective_end_date
                      );

                      v_update_status := 'Success';
                      v_tot_rec_success := v_tot_rec_success + 1;

                  EXCEPTION WHEN OTHERS
                  THEN
                     FND_FILE.put_line(FND_FILE.log,'Operation fails on '||v_stage||' Employee Number: '||emp_rec.employee_number);
	                 v_msg := SQLERRM;
                     v_update_status := 'API Error :'||v_msg;
                     FND_FILE.put_line(FND_FILE.log,'Error Message: '||v_msg);
                     v_tot_rec_api_error := v_tot_rec_api_error + 1;
                  END;
               END IF;
            END IF;

            FND_FILE.put_line
                        (FND_FILE.output
                       ,    emp_rec.employee_number
                     ||','''||emp_rec.current_bank_account_number
                     ||','''||emp_rec.current_transit_code
                     ||','''||emp_rec.current_bank_branch
                     ||','''||emp_rec.new_bank_account_number
                     ||','''||emp_rec.new_transit_code
                     ||','''||emp_rec.new_bank_branch
                     ||','||REPLACE(v_update_status,',',' ')
                        );
            CLOSE c_emp_cur;

         EXCEPTION
            WHEN OTHERS
            THEN
               v_tot_rec_fail               := v_tot_rec_fail + 1;
               v_msg := SQLERRM;
               v_update_status := 'Emp Fetch :'||v_msg;
               FND_FILE.put_line(FND_FILE.log,'Error Message: '||v_msg);
               NULL;
         END;

         v_tot_rec_count := v_tot_rec_count + 1;

      END LOOP;  /* emp */

      FND_FILE.put_line (FND_FILE.output, '');
      FND_FILE.put_line (FND_FILE.output
                         , 'Total Employee(s) Processed:,'
                         || TO_CHAR (v_tot_rec_count, '9,999,999,999')
                        );
      FND_FILE.put_line (FND_FILE.output
                         , 'Total Employee(s) Successfully Updated:, '
                         || TO_CHAR (v_tot_rec_success, '9,999,999,999')
                        );
      FND_FILE.put_line (FND_FILE.output
                         , 'Total Employee Record(s) Cannot be Updated:, '
                         || TO_CHAR (v_tot_rec_fail, '9,999,999,999')
                        );
      FND_FILE.put_line (FND_FILE.output
                         , 'Total Employee API Error(s):,'
                         || TO_CHAR (v_tot_rec_api_error, '9,999,999,999')
                        );
   EXCEPTION
      WHEN OTHERS
      THEN
         v_msg := 'Operation fails on '
                               || v_stage
                               || ' '
                               || v_element
                               || ' '
                               || v_key
                               || SQLERRM;

         FND_FILE.put_line(FND_FILE.log,v_msg);

         raise_application_error (-20003
                                ,    'Exception OTHERS in gen_benefit_file: '
                                  || v_msg
                                 );
         ROLLBACK;
   END main;
END TTEC_UPD_EMP_PAYMENT_METHOD;
/
show errors;
/