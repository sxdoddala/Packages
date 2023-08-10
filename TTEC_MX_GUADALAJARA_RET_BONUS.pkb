create or replace PACKAGE BODY      TTEC_MX_GUADALAJARA_RET_BONUS
IS
 /* $Header: TTEC_MX_GUADALAJARA_RET_BONUS.pkb 1.0  06/14/12  damolina  ship $ */

/*== START ================================================================================================*\
Author: Daniel Molina

Date: 14-APR-12

Call From: TTEC_MX_GUADALAJARA_RET_BONUS

Desc: This package generates the Guadalajara retention bonus Report as an output file of the concurrent program.
     This report is in order to administrate the Retention Bonus in Guadalajara.

Modification History:

Version    Date     Author      Description (Include Ticket#)
-------  --------  -----------  ------------------------------------------------------------------------------
    1.0  14-APR-12  damolina     Creation  of a report to administrate the
                                 Retention Bonus in Guadalajara.
                                 It will be paid to new hires
                                 as of 20-MAR-2012 and will be split
                                 in three payments, as follows:
                                 - 1st pay will be at the 3rd month.
                                 - 2nd pay will be at the 6th month.
                                 - 3rd pay will be at the 9th month.

    1.1 27-APR-12 damolina      TTSD request: #1285187
                                Added current date as default value for p_as_of_date parameter

    1.2 26-JUL-12 damolina      TTSD request: #1686532
                                Added parameter p_start_date
								
	1.0	02-MAY-23 RXNETHI-ARGANO	R12.2 Upgrade Remediation					
\*== END ==================================================================================================*/

/************************************************************************************************
 *      PROCEDURE main                                                              			*
 *      Description: This is the main procedure to be called directly from the      			*
 *                   Concurrent Manager.                                            			*
 *                   It will generate the Guadalajara retention bonus report        			*
 *                   as an output file of the concurrent program.                   			*
 *                                                                                  			*
 *      Input/Output Parameters:                                                    			*
 *                                 IN: p_as_of_date - data retrieval constraint     			*
 *                                     p_start_date - data retrieval constraint                 *
 *                                                                                  			*
 ************************************************************************************************/

PROCEDURE main ( errcode           VARCHAR2
                ,errbuff           VARCHAR2
                ,p_as_of_date   IN VARCHAR2
                ,p_start_date   IN VARCHAR2)
   IS

      /** Declare local variables **/
      v_rec            VARCHAR2 (10000) := NULL;
      v_header         VARCHAR2 (1000) := NULL;
      v_error_step     VARCHAR2 (1000);
      v_msg            VARCHAR2 (2000);
      v_as_of_date     DATE := NULL;
      v_start_date     DATE := NULL;

      /** Declare Cursors **/
      CURSOR c_emps(l_as_of_date   IN   DATE,
                    l_start_date   IN   DATE)
      IS

        SELECT  DISTINCT
                papf.full_name                  fullName,
                papf.employee_number            oracleID,
                loc.location_code               location,
                pj.attribute5                   jobFamily,
                pj.NAME                         position,
                ffv_client.description          clientName,
                ppos.date_start                 hireDate,
                ROUND(MONTHS_BETWEEN (NVL(l_as_of_date,TRUNC(SYSDATE)) - 1,ppos.date_start),2)     months,
                CASE
                WHEN MONTHS_BETWEEN (NVL(l_as_of_date,TRUNC(SYSDATE)) - 1,ppos.date_start) >= 3
                AND MONTHS_BETWEEN  (NVL(l_as_of_date,TRUNC(SYSDATE)) - 1,ppos.date_start) < 4 THEN '1st pay'
                WHEN MONTHS_BETWEEN (NVL(l_as_of_date,TRUNC(SYSDATE)) - 1,ppos.date_start) >= 6
                AND MONTHS_BETWEEN  (NVL(l_as_of_date,TRUNC(SYSDATE)) - 1,ppos.date_start) < 7 THEN '2nd pay'
                WHEN MONTHS_BETWEEN (NVL(l_as_of_date,TRUNC(SYSDATE)) - 1,ppos.date_start) >= 9
                AND MONTHS_BETWEEN  (NVL(l_as_of_date,TRUNC(SYSDATE)) - 1,ppos.date_start) < 10 THEN '3rd pay'
                END AS     payment
        
                /*
				START R12.2 Upgrade Remediation -- code commented by RXNETHI-ARGANO, 02-MAY-23
				
		FROM	hr.per_all_people_f papf,
                hr.per_jobs pj,
                apps.fnd_flex_values_vl ffv_client,
                hr.per_periods_of_service ppos,
                hr.pay_cost_allocation_keyflex pcak,
                hr.pay_cost_allocations_f pcaf,
                hr.hr_locations_all loc,
                hr.per_all_assignments_f paaf*/
				
				--code added by RXNETHI, 02/MAY/2023
		FROM	apps.per_all_people_f papf,
                apps.per_jobs pj,
                apps.fnd_flex_values_vl ffv_client,
                apps.per_periods_of_service ppos,
                apps.pay_cost_allocation_keyflex pcak,
                apps.pay_cost_allocations_f pcaf,
                apps.hr_locations_all loc,
                apps.per_all_assignments_f paaf
        -- END R12.2 Upgrade Remediation				
        WHERE papf.person_id = paaf.person_id
            AND paaf.job_id = pj.job_id
            AND papf.person_id = ppos.person_id
            AND ppos.period_of_service_id = paaf.period_of_service_id
            AND papf.current_employee_flag = 'Y'
            AND NVL(l_as_of_date,TRUNC(SYSDATE)) BETWEEN papf.effective_start_date AND papf.effective_end_date
            AND NVL(l_as_of_date,TRUNC(SYSDATE)) BETWEEN paaf.effective_start_date AND paaf.effective_end_date
            AND papf.business_group_id = 1633
            AND paaf.assignment_type = 'E'
            AND paaf.primary_flag = 'Y'
            AND paaf.location_id = loc.location_id(+)
            AND loc.location_id = '35255'
            /* V 1.2 Begin - This would apply to new hires as of v_start_date */
            AND ppos.date_start >= l_start_date
            /* V 1.2 End */
            AND (MONTHS_BETWEEN (NVL(l_as_of_date,TRUNC(SYSDATE)) - 1,ppos.date_start) >= 3
            AND MONTHS_BETWEEN (NVL(l_as_of_date,TRUNC(SYSDATE)) - 1,ppos.date_start) < 4
            OR MONTHS_BETWEEN (NVL(l_as_of_date,TRUNC(SYSDATE)) - 1,ppos.date_start) >= 6
            AND MONTHS_BETWEEN (NVL(l_as_of_date,TRUNC(SYSDATE)) - 1,ppos.date_start) < 7
            OR MONTHS_BETWEEN (NVL(l_as_of_date,TRUNC(SYSDATE)) - 1,ppos.date_start) >= 9
            AND MONTHS_BETWEEN (NVL(l_as_of_date,TRUNC(SYSDATE)) - 1,ppos.date_start) < 10)
            AND pcaf.assignment_id(+) = paaf.assignment_id
            AND NVL(l_as_of_date,TRUNC(SYSDATE)) BETWEEN pcaf.effective_start_date(+) AND pcaf.effective_end_date(+)
            AND pcaf.cost_allocation_keyflex_id = pcak.cost_allocation_keyflex_id(+)
            AND ffv_client.flex_value_meaning(+) = pcak.segment2
            AND ffv_client.flex_value_set_id(+) = '1002611'
        GROUP BY papf.full_name,
                papf.employee_number,
                pj.attribute5,
                pj.NAME,
                ffv_client.description,
                ppos.date_start,
                loc.location_code
        ORDER BY 7;

   BEGIN

      v_error_step   := 'Step 1: Create header';

      /* V 1.1 Begin */
      IF p_as_of_date IS NOT NULL
      THEN
         v_as_of_date := apps.fnd_date.canonical_to_date(p_as_of_date);
      ELSE
         v_as_of_date := TO_CHAR (TRUNC(SYSDATE), 'DD-MON-YYYY');
      END IF;
      /* V 1.1 End */

      IF p_start_date IS NOT NULL
      THEN
         v_start_date := apps.fnd_date.canonical_to_date(p_start_date);
      ELSE
         v_start_date := TO_CHAR (TRUNC(SYSDATE), 'DD-MON-YYYY');
      END IF;

      /** Log header **/
      apps.fnd_file.put_line (fnd_file.log,'TeleTech HR Report Name: TTEC Guadalajara new retention bonus - As of: '|| v_as_of_date);

      /** Create header for the output **/

      v_header       :=
            'AS OF DATE'
         || '|'
         || 'FULL NAME'
		 || '|'
         || 'ORACLE ID'
		 || '|'
         || 'LOCATION'
		 || '|'
         || 'JOB FAMILY'
		 || '|'
         || 'POSITION'
		 || '|'
         || 'CLIENT NAME'
		 || '|'
		 || 'HIRE DATE'
		 || '|'
		 || 'MONTHS'
		 || '|'
		 || 'PAYMENT';

      apps.fnd_file.put_line (fnd_file.output, v_header);

      v_error_step   := 'Step 2: End create header, entering Loop';

      /** Loop Records **/
      FOR r_emp IN c_emps(v_as_of_date,v_start_date) LOOP

         v_error_step   := 'Step 3: Inside Loop';

         v_rec :=   v_as_of_date
                 || '|'
                 || r_emp.fullName
                 || '|'
                 || r_emp.oracleID
                 || '|'
                 || r_emp.location
                 || '|'
                 || r_emp.jobFamily
                 || '|'
                 || r_emp.position
                 || '|'
                 || r_emp.clientName
                 || '|'
                 || r_emp.hireDate
                 || '|'
                 || r_emp.months
                 || '|'
                 || r_emp.payment;

         apps.fnd_file.put_line (fnd_file.output, v_rec);

      END LOOP;


   EXCEPTION
      WHEN OTHERS
      THEN
         fnd_file.put_line (fnd_file.LOG, 'Operation fails on ' || v_error_step);
   END main;
END TTEC_MX_GUADALAJARA_RET_BONUS;
/
show errors;
/