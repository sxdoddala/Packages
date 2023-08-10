create or replace PACKAGE BODY      TTEC_HR_GNA_EMP_WITHOUT_EMAIL
IS
    /* $Header: TTEC_HR_GNA_EMP_WITHOUT_EMAIL.pkb 1.0 damolina ship */

    /*== START ================================================================================================*\
         Author: Daniel Molina
           Date: 07/06/2012
      Call From: TTEC G&A Employees Without Email Address
    Description: Inform to IT and HC that there are G&A employees who still have no TTEC email address.

    Modification History:

    Version    Date     Author       Description (Include Ticket#)
    -------  --------   -----------  ----------------------------------------------------------------------------
        1.0  07/06/2012 damolina     REQ#1431202 - Initial version.
		1.1  10/26/2012 refigini	 REQ#1901535 - Updated version, add new field (oracleID) into the query.
        1.2  01/10/2013 refigini     REQ#1873082 - Remove parameter p_business_group_id. Add hard condition requested by user.
        1.0  05/15/2023     MXKEERTHI(ARGANO)             R12.2 Upgrade Remediation
    \*== END ==================================================================================================*/

    PROCEDURE main ( errcode                    VARCHAR2
                    ,errbuff                    VARCHAR2
                   -- ,p_business_group_id   IN   VARCHAR2 -REQ#1873082 -Ricardo Figini
                    )
    IS

    /* ************************************************************************************************************************
     *      PROCEDURE main                                                                                                                   *
     *      Description: This is the main procedure to be called directly from the                                             *
     *                   Concurrent Manager                                                                                                     *
     *                   Inform to IT and HC that there are G&A employees who still have no TTEC email address   *
     *                                                                                                                                                      *
     *      Input/Output Parameters:                                                                                                           *
     *                                 IN: p_business_group_id  -- Disabled since  --REQ#1873082 -Ricardo Figini        *
     *                                                                                                                                                      *
     **************************************************************************************************************************/

    /** Declare local variables **/
    v_rec            VARCHAR2 (10000) := NULL;
    v_header         VARCHAR2 (1000)  := 'OracleId|Fullname|Job Title|Site HR/Location|Payroll Group'; --REQ#1901535 -Ricardo Figini
    v_error_step     VARCHAR2 (1000)  := 'Step 1: Create header';

    /** Declare Cursors **/
    CURSOR c_emps
    IS

    SELECT
        papf.employee_number                        oracleId, --REQ#1901535 -Ricardo Figini
        papf.full_name                              fullName,
        SUBSTR (pj.name, INSTR (pj.name, '.') + 1)  jobTitle,
        hla.location_code                           siteLocation,
        pap.payroll_name                            payrollGroup
    FROM
	   --START R12.2 Upgrade Remediation
	  /*
	    	Commented code by MXKEERTHI-ARGANO, 05/15/2023
          hr.per_all_people_f        papf
        ,hr.per_all_assignments_f   paaf
        ,hr.hr_locations_all        hla
        ,hr.per_jobs                pj
        ,hr.pay_all_payrolls_f      pap
	   */
	  --code Added  by MXKEERTHI-ARGANO, 05/15/2023
         apps.per_all_people_f        papf
        ,apps.per_all_assignments_f   paaf
        ,apps.hr_locations_all        hla
        ,apps.per_jobs                pj
        ,apps.pay_all_payrolls_f      pap
	  --END R12.2.10 Upgrade remediation


    WHERE TRUNC(SYSDATE) BETWEEN papf.effective_start_date AND  papf.effective_end_date
      /* Active employees */
      AND papf.current_employee_flag = 'Y'
      -- AND papf.business_group_id IN (p_business_group_id) --REQ#1873082 -Ricardo Figini
      AND papf.business_group_id IN (325,326,1517,1631,1632,1633,1761,1804,1839,2287,2311,2327,2328,5054) --REQ#1873082 -Ricardo Figini
      /* Assignment */
      AND paaf.person_id = papf.person_id
      /* Assignment Type: Employee */
      AND paaf.assignment_type = 'E'
      /* Primary Assignment in case there are more than one */
      AND paaf.primary_flag = 'Y'
      AND TRUNC(SYSDATE) BETWEEN paaf.effective_start_date AND  paaf.effective_end_date
      /* Payroll group */
      AND pap.payroll_id(+) = paaf.payroll_id
      AND TRUNC (SYSDATE) BETWEEN pap.effective_start_date(+) AND pap.effective_end_date(+)
      /* HR Location / Site and Country */
      AND hla.location_id(+) = paaf.location_id
      /* Job */
      AND pj.job_id = paaf.job_id
      /* G&A employees */
      AND pj.attribute5 = 'G' || CHR(38) || 'A'
      /* NULL TTEC Email Address */
      AND papf.email_address IS NULL
    ORDER BY
          hla.location_code ASC;

   BEGIN

      /** Log header **/
      apps.fnd_file.put_line (fnd_file.LOG,'TeleTech HR Report Name: TTEC G&A Employees Without Email Address - As of: '|| TO_CHAR (TRUNC(SYSDATE), 'DD-MON-YYYY'));

      apps.fnd_file.put_line (fnd_file.output, v_header);

      v_error_step   := 'Step 2: End create header, entering Loop';

      /** Loop Records **/
      FOR r_emp IN c_emps() LOOP

         v_error_step   := 'Step 3: Inside Loop';

         v_rec := r_emp.oracleId|| '|' ||  r_emp.fullName || '|' || r_emp.jobTitle || '|' || r_emp.siteLocation || '|' || r_emp.payrollGroup; --REQ#1901535 -Ricardo Figini

         apps.fnd_file.put_line (fnd_file.output, v_rec);

      END LOOP;

   EXCEPTION
      WHEN OTHERS
      THEN
         fnd_file.put_line (fnd_file.LOG, 'Operation fails on ' || v_error_step);
   END main;
END TTEC_HR_GNA_EMP_WITHOUT_EMAIL;
/
show errors;
/