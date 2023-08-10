create or replace PACKAGE BODY      TTEC_HR_LEAVE_WITHOUT_PAY
IS
    /* $Header: TTEC_HR_LEAVE_WITHOUT_PAY.pks 1.0 damolina ship */

    /*== START ================================================================================================*\
         Author: Daniel Molina
           Date: 09/3/2012
      Call From: TTEC HR Leave Without Pay
    Description: Identify employees on leave without pay status

    Modification History:

    Version    Date     Author       Description (Include Ticket#)
    -------  --------   -----------  ----------------------------------------------------------------------------
        1.0  09/3/2012 damolina     REQ#1782128 - Initial version.
	    1.0 05/10/2023 MXKEERTHI(ARGANO)    R12.2 Upgrade Remediation

    \*== END ==================================================================================================*/

    PROCEDURE main ( errcode                    VARCHAR2
                    ,errbuff                    VARCHAR2)
    IS

    /************************************************************************************************************
    *      PROCEDURE main                                                                                       *
    *      Description: This is the main procedure to be called directly from the Concurrent Manager.           *                                                           *
    *                   Identify employees on leave without pay status                                          *
    *                                                                                                           *
    *************************************************************************************************************/


    /* Declare local variables */
    v_rec            VARCHAR2 (10000) := NULL;

    v_header         VARCHAR2 (1000)  :=    'As of Date'
                                         || '|'
                                         || 'Oracle ID'
                                         || '|'
                                         || 'Full Name'
                                         || '|'
                                         || 'Job Title'
                                         || '|'
                                         || 'Location Code'
                                         || '|'
                                         || 'Assignment Status'
                                         || '|'
                                         || 'Start Date'
                                         || '|'
                                         || 'Assign Start Date';

    v_error_step     VARCHAR2 (1000)  := 'Step 1: Running Query';
    v_data           BOOLEAN          := FALSE;

    /* Declare  Explicit Cursor */
    CURSOR c_emps
    IS
    SELECT   DISTINCT
             papf.employee_number                       oracleId
           , papf.full_name                             fullName
           , SUBSTR (pj.name, INSTR (pj.name, '.') + 1) jobTitle
           , hla.location_code                          locationCode
           , NVL (pasta.user_status,past.user_status)   assignmentStatus
           , papf.original_date_of_hire                 startDate
           , paaf.effective_start_date                  assignStartDate
    FROM
	  	  --START R12.2 Upgrade Remediation
	  /*
		Commented code by MXKEERTHI-ARGANO, 05/11/2023
             hr.per_all_people_f                        papf
           , hr.per_all_assignments_f                   paaf
           , per_periods_of_service                     ppos
           , hr.hr_locations_all                        hla
           , hr.per_jobs                                pj
           , hr.per_assignment_status_types             past
           , hr.per_ass_status_type_amends              pasta
  	   */
	  --code Added  by MXKEERTHI-ARGANO, 05/11/2023
             apps.per_all_people_f                        papf
           , apps.per_all_assignments_f                   paaf
           , per_periods_of_service                     ppos
           , apps.hr_locations_all                        hla
           , apps.per_jobs                                pj
           , apps.per_assignment_status_types             past
           , apps.per_ass_status_type_amends              pasta
  
	  --END R12.2.10 Upgrade remediation
  WHERE
      /* Active employees */
      papf.current_employee_flag = 'Y'
      AND TRUNC(SYSDATE) BETWEEN papf.effective_start_date AND  papf.effective_end_date
      /* Leave without Pay */
      AND paaf.assignment_status_type_id = 32
      /* Modification made on actual date */
      AND paaf.effective_start_date BETWEEN TRUNC(SYSDATE) - 7 AND TRUNC(SYSDATE)
      /* Assignment */
      AND paaf.person_id = papf.person_id
      /* Assignment Type: Employee */
      AND paaf.assignment_type = 'E'
      /* Primary Assignment in case there are more than one */
      AND paaf.primary_flag = 'Y'
      /* Period of Service */
      AND ppos.person_id = papf.person_id
      AND ppos.period_of_service_id = paaf.period_of_service_id
      /* HR Location / Site and Country */
      AND hla.location_id(+) = paaf.location_id
      /* Job */
      AND pj.job_id(+) = paaf.job_id
      /* Employee Status */
      AND past.assignment_status_type_id(+) = paaf.assignment_status_type_id
      AND pasta.assignment_status_type_id(+) = paaf.assignment_status_type_id
      AND pasta.business_group_id(+) = paaf.business_group_id;

      /* Create record */
      emp_rec c_emps%ROWTYPE;

   BEGIN

    /* Log header */
    apps.fnd_file.put_line (fnd_file.LOG,'TeleTech HR Report Name: TTEC HR Leave Without Pay - As of: '|| TO_CHAR (TRUNC(SYSDATE), 'DD-MON-YYYY'));

    /* Open cursor */
    IF NOT c_emps%ISOPEN THEN
        OPEN c_emps;
    END IF;

    v_error_step := 'Step 2: Entering Loop';

    /* Loop records */
    LOOP
        /* Fetch rows */
        FETCH c_emps INTO emp_rec;

        /* No data found */
        IF c_emps%NOTFOUND AND v_data = FALSE THEN
            apps.fnd_file.put_line (fnd_file.output,'No Data Returned');
        END IF;

        EXIT WHEN c_emps%NOTFOUND;

        /* Header */
        IF c_emps%FOUND AND v_data = FALSE THEN
            apps.fnd_file.put_line (fnd_file.output,v_header);
        END IF;

        v_error_step   := 'Step 3: Inside Loop';

        v_rec :=   TRUNC(SYSDATE)
                || '|'
                || emp_rec.oracleId
                || '|'
                || emp_rec.fullName
                || '|'
                || emp_rec.jobTitle
                || '|'
                || emp_rec.locationCode
                || '|'
                || emp_rec.assignmentStatus
                || '|'
                || emp_rec.startDate
                || '|'
                || emp_rec.assignStartDate;

                apps.fnd_file.put_line (fnd_file.output, v_rec);

            v_data := TRUE;

    END LOOP;

    /* Close cursor */
    CLOSE c_emps;

   EXCEPTION
      WHEN OTHERS
      THEN
         fnd_file.put_line (fnd_file.LOG, 'Operation fails on ' || v_error_step);
   END main;

END TTEC_HR_LEAVE_WITHOUT_PAY;
/
show errors;
/