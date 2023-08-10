create or replace PACKAGE BODY      ttec_pto_upd_pkg
AS
-- Program Name:  ttec_pto_upd_pkg
-- /* $Header: ttec_pto_upd_pkg.pks 1.0 2016/04/14  MLarsen $ */
--
-- /*== START ================================================================================================*\
--    Author: Manuel F. Larsen
--      Date: 15-ABR-2016
--
--      Desc: The Procedure GENERATE_VAC_BALANCE_TRANSFER generates either PTO or TTECH Vacation Balance Transfer entries
--            whenever there is a change of payroll.
--            The Procedure GENERATE_ENTRIES_PTO_PCTA generates TeleTech PTO, Personal Holiday PCTA and Sick Plan PCTA entries
--            for PCTA new hires.
--
--     Parameter Description:
--
--         p_effective_date            : DATE
--
--       Oracle Standard Parameters:
--
--   Modification History:
--
--  Version    Date     Author   Description (Include Ticket--)
--  -------  --------  --------  ------------------------------------------------------------------------------------------
--      1.0  04/15/16   MLarsen  Initial Version
--      1.0  05/MAY/23   RXNETHI-ARGANO  R12.2 Upgrade Remediation
-- \*== END =====================================
--
PROCEDURE print_line (p_data IN VARCHAR2)
IS
BEGIN
  --
  Fnd_File.put_line (Fnd_File.output, p_data);
  --
END;   -- print_line

PROCEDURE GENERATE_VAC_BALANCE_TRANSFER ( errcode                 OUT VARCHAR2,
                                          errbuff                 OUT VARCHAR2,
                                          p_effective_date        IN VARCHAR2)
IS
l_element_entry_id           NUMBER := 0;
l_pto_element_entry_id       NUMBER := 0;
l_elem_transfer_link_id      NUMBER := 0;
l_vac_transfer_link_id       NUMBER := 15816;
l_pto_transfer_link_id       NUMBER := 8127;
l_wel_transfer_link_id       NUMBER := 15817;
l_sick_transfer_link_id      NUMBER := 623;
l_num_entry_values           NUMBER := 2;
l_vacation_plan_id           NUMBER := 1356;
l_wellness_plan_id           NUMBER := 1357;
l_pto_plan_id                NUMBER := 134;
l_sick_plan_id               NUMBER := 236;
l_accrual_start_date         DATE := '01-JAN-1980';
l_effective_end_date         DATE := '31-DEC-4712';
l_creator_type               VARCHAR2(10) := 'H';
l_entry_type                 VARCHAR2(10) := 'E';
l_elem_name                  VARCHAR2(50);
l_effective_date             DATE;
l_input_value_id_tbl         hr_entry.number_table;
l_entry_value_tbl            hr_entry.varchar2_table;
l_last_accrual_date          DATE;
l_accrual_end_date           DATE;
l_start_date                 DATE;
l_end_date                   DATE;
l_accrual                    NUMBER;
l_net_entitlement_old        NUMBER;
l_net_entitlement_new        NUMBER;
l_accrual_latest_balance     NUMBER :=0;
l_error_count                NUMBER :=0;
l_read_count                 NUMBER :=0;
l_written_count              NUMBER :=0;

BEGIN

  IF p_effective_date IS NOT NULL THEN
     l_effective_date := to_date(p_effective_date);
  ELSE
     l_effective_date := TRUNC(SYSDATE);
  END IF;

  apps.Fnd_File.put_line (apps.Fnd_File.log,'Stage 30');
  -- Out put header information
  print_line('');
  print_line(' PAYROLL-PROCESS - Payroll Change TTECH Vacation Balance Transfer');
  print_line('');
  print_line(' EFFECTIVE DATE: '|| l_effective_date);
  print_line('');
  print_line(' Assignment Number |          Element                |      Hours   | Effective Date');
  print_line(' ===================================================================================');


  FOR cursor_record IN (SELECT DISTINCT OLD.ASSIGNMENT_ID,
                                  OLD.PAYROLL_ID OLD_PAYROLL_ID,
                                  NEW.PAYROLL_ID NEW_PAYROLL_ID,
                                  NEW.ASSIGNMENT_NUMBER,
                                  TO_DATE(PEEVF1.SCREEN_ENTRY_VALUE, 'yyyy/mm/dd hh24:mi:ss') OLD_CONTINUOUS_SVC_DATE,
                                  PEE1.element_entry_id old_element_entry_id,
                                  PEE2.element_entry_id new_element_entry_id,
                                  pee2.effective_start_date new_entry_effective_start_date,
                                  OLD.EFFECTIVE_END_DATE OLD_EFFECTIVE_END_DATE,
                                  NEW.EFFECTIVE_START_DATE NEW_EFFECTIVE_START_DATE,
                                  NVL(DECODE(OLD.PAYROLL_ID, 46, (SELECT element_entry_id FROM PAY_ELEMENT_ENTRIES_F WHERE element_type_id = 8126 AND assignment_id = OLD.assignment_id and OLD.EFFECTIVE_END_DATE BETWEEN effective_start_date AND effective_end_date)) , 0) Holiday_PCTA_Entry_ID,
                                  NVL(DECODE(OLD.PAYROLL_ID, 46, (SELECT element_entry_id FROM PAY_ELEMENT_ENTRIES_F WHERE element_type_id = 8106 AND assignment_id = OLD.assignment_id and OLD.EFFECTIVE_END_DATE BETWEEN effective_start_date AND effective_end_date)) , 0) Sick_PCTA_Entry_ID
                             FROM PER_ALL_ASSIGNMENTS_F OLD,
                                  PER_ALL_ASSIGNMENTS_F NEW,
                                  PAY_ELEMENT_ENTRIES_F PEE1,
                                  PAY_ELEMENT_ENTRIES_F PEE2,
                                  PAY_ELEMENT_ENTRY_VALUES_F PEEVF1,
                                  PAY_INPUT_VALUES_F PIVF1
                            WHERE OLD.BUSINESS_GROUP_ID = 325
                              AND NEW.BUSINESS_GROUP_ID = 325
                              AND OLD.EFFECTIVE_END_DATE = (NEW.EFFECTIVE_START_DATE - 1)
                              AND NEW.ASSIGNMENT_STATUS_TYPE_ID = 1
                              AND OLD.ASSIGNMENT_ID = NEW.ASSIGNMENT_ID
                              AND OLD.PAYROLL_ID <> NEW.PAYROLL_ID
                              AND pee1.element_type_id = DECODE(OLD.PAYROLL_ID, 46 , 3207, 14738)
                              AND pee1.assignment_id = OLD.assignment_id
                              AND OLD.EFFECTIVE_END_DATE BETWEEN pee1.effective_start_date AND pee1.effective_end_date
                              AND pee2.element_type_id(+) = DECODE(NEW.PAYROLL_ID, 46 , 3207, 14738)
                              AND pee2.assignment_id(+) = NEW.assignment_id
                              AND pee2.effective_start_date(+) = NEW.EFFECTIVE_START_DATE
                              AND (pee2.element_type_id IS NOT NULL OR NEW.PAYROLL_ID = 46)
                              AND PEE1.ELEMENT_ENTRY_ID = PEEVF1.ELEMENT_ENTRY_ID
                              AND PEEVF1.INPUT_VALUE_ID = PIVF1.INPUT_VALUE_ID
                              AND PIVF1.NAME = 'Continuous Service Date'
                              AND TRUNC(NEW.LAST_UPDATE_DATE) = TRUNC(l_effective_date))
           LOOP
             BEGIN
             l_read_count := l_read_count + 1;

             IF cursor_record.old_payroll_id = 46 THEN
                hr_entry_api.delete_element_entry (
                p_dt_delete_mode           => 'DELETE',
                p_session_date             => cursor_record.old_effective_end_date,
                p_element_entry_id         => cursor_record.old_element_entry_id
                ); -- END DATE PTO

               IF cursor_record.Holiday_PCTA_Entry_ID <> 0 THEN
                  hr_entry_api.delete_element_entry (
                  p_dt_delete_mode           => 'DELETE',
                  p_session_date             => cursor_record.old_effective_end_date,
                  p_element_entry_id         => cursor_record.Holiday_PCTA_Entry_ID
                  ); -- END DATE HOLIDAY
               END IF;

               IF cursor_record.Sick_PCTA_Entry_ID <> 0 THEN
                  hr_entry_api.delete_element_entry (
                  p_dt_delete_mode           => 'DELETE',
                  p_session_date             => cursor_record.old_effective_end_date,
                  p_element_entry_id         => cursor_record.Sick_PCTA_Entry_ID
                  ); -- END DATE SICK
               END IF;

            END IF; -- cursor_record.old_payroll_id = 46

            IF cursor_record.new_payroll_id = 46 THEN  -- Insert PTO Elements for PCTA

                 hr_entry_api.insert_element_entry
                (p_effective_start_date => cursor_record.NEW_EFFECTIVE_START_DATE,
                 p_effective_end_date   => l_effective_end_date,
                 p_element_entry_id     => l_pto_element_entry_id,
                 p_assignment_id        => cursor_record.assignment_id,
                 p_element_link_id      => 7587, -- TeleTech PTO
                 p_creator_type         => l_creator_type,
                 p_entry_type           => l_entry_type,
                 p_num_entry_values     => 0,
                 p_input_value_id_tbl   => l_input_value_id_tbl,
                 p_entry_value_tbl      => l_entry_value_tbl);

                 hr_entry_api.insert_element_entry
                (p_effective_start_date => cursor_record.NEW_EFFECTIVE_START_DATE,
                 p_effective_end_date   => l_effective_end_date,
                 p_element_entry_id     => l_element_entry_id,
                 p_assignment_id        => cursor_record.assignment_id,
                 p_element_link_id      => 7548, -- Personal Holiday PCTA
                 p_creator_type         => l_creator_type,
                 p_entry_type           => l_entry_type,
                 p_num_entry_values     => 0,
                 p_input_value_id_tbl   => l_input_value_id_tbl,
                 p_entry_value_tbl      => l_entry_value_tbl);

                 hr_entry_api.insert_element_entry
                (p_effective_start_date => cursor_record.NEW_EFFECTIVE_START_DATE,
                 p_effective_end_date   => l_effective_end_date,
                 p_element_entry_id     => l_element_entry_id,
                 p_assignment_id        => cursor_record.assignment_id,
                 p_element_link_id      => 7547, -- Sick Plan PCTA
                 p_creator_type         => l_creator_type,
                 p_entry_type           => l_entry_type,
                 p_num_entry_values     => 0,
                 p_input_value_id_tbl   => l_input_value_id_tbl,
                 p_entry_value_tbl      => l_entry_value_tbl);

            END IF; -- -- cursor_record.new_payroll_id = 46

			-- Get the vacation net entitlement before the change of payroll
             l_last_accrual_date         := NULL;
             l_accrual_end_date          := NULL;
             l_start_date                := NULL;
             l_end_date                  := NULL;
             l_accrual                   := NULL;
             l_net_entitlement_old       := NULL;
             l_accrual_latest_balance    := 0;
             l_accrual_start_date        := '01-JAN-1980';

             IF cursor_record.old_payroll_id <> 46 THEN
                l_net_entitlement_old := per_utility_functions.get_net_accrual(cursor_record.assignment_id, cursor_record.old_payroll_id, 325 ,0 , cursor_record.old_effective_end_date, l_vacation_plan_id, NULL, 0);
             ELSE
                l_net_entitlement_old := per_utility_functions.get_net_accrual(cursor_record.assignment_id, cursor_record.old_payroll_id, 325 ,0 , cursor_record.old_effective_end_date, l_pto_plan_id, NULL, 0);
             END IF;

			-- Get the vacation net entitlement after the change of payroll
             l_last_accrual_date         := NULL;
             l_accrual_end_date          := NULL;
             l_start_date                := NULL;
             l_end_date                  := NULL;
             l_accrual                   := NULL;
             l_net_entitlement_new       := NULL;
             l_accrual_latest_balance    := 0;
             l_accrual_start_date        := '01-JAN-1980';

             IF cursor_record.new_payroll_id <> 46 THEN
			          l_net_entitlement_new := per_utility_functions.get_net_accrual(cursor_record.assignment_id, cursor_record.new_payroll_id, 325 ,0 ,cursor_record.new_effective_start_date, l_vacation_plan_id, NULL, 0);
             ELSE
			          l_net_entitlement_new := per_utility_functions.get_net_accrual(cursor_record.assignment_id, cursor_record.new_payroll_id, 325 ,0 ,cursor_record.new_effective_start_date, l_pto_plan_id, NULL, 0);
             END IF;

             -- Generate Vacation ENTRY
             IF  l_net_entitlement_old > l_net_entitlement_new THEN

                 IF cursor_record.new_payroll_id <> 46 THEN
                    l_input_value_id_tbl(1) := 37669;                --Hours
                    l_input_value_id_tbl(2) := 37670;                --Entry effective date
                    l_elem_transfer_link_id := l_vac_transfer_link_id;
                    l_elem_name := 'TTECH Vacation Balance Transfer';
                 ELSE
                    l_input_value_id_tbl(1) := 13710;                --Hours
                    l_input_value_id_tbl(2) := 13711;                --Entry effective date
                    l_elem_transfer_link_id := l_pto_transfer_link_id;
                    l_elem_name := 'PTO Balance Transfer';
                 END IF;

                 l_entry_value_tbl(1) := to_char(l_net_entitlement_old, '999999.99');
                 l_entry_value_tbl(2) := to_char(cursor_record.new_effective_start_date, 'DD-MON-YYYY');

                 hr_entry_api.insert_element_entry
                (p_effective_start_date => cursor_record.new_effective_start_date,
                 p_date_earned          => cursor_record.new_effective_start_date,
                 p_effective_end_date   => l_effective_end_date,
                 p_element_entry_id     => l_element_entry_id,
                 p_assignment_id        => cursor_record.assignment_id,
                 p_element_link_id      => l_elem_transfer_link_id,
                 p_creator_type         => l_creator_type,
                 p_entry_type           => l_entry_type,
                 p_num_entry_values     => l_num_entry_values,
                 p_input_value_id_tbl   => l_input_value_id_tbl,
                 p_entry_value_tbl      => l_entry_value_tbl);

                 print_line(lpad(cursor_record.assignment_number, 19, ' ') || '|' || rpad(l_elem_name, 33, ' ') || '| '|| to_char(l_net_entitlement_old, '999999.99') || '   | '||to_char(cursor_record.new_effective_start_date, 'DD-MON-YYYY'));
                 l_written_count := l_written_count + 1;
             END IF;

			-- Get the wellness net entitlement before the change of payroll
             l_last_accrual_date         := NULL;
             l_accrual_end_date          := NULL;
             l_start_date                := NULL;
             l_end_date                  := NULL;
             l_accrual                   := NULL;
             l_net_entitlement_old       := NULL;
             l_accrual_latest_balance    := 0;
             l_accrual_start_date        := '01-JAN-1980';

             IF cursor_record.old_payroll_id <> 46 THEN
                l_net_entitlement_old := per_utility_functions.get_net_accrual(cursor_record.assignment_id, cursor_record.old_payroll_id, 325 ,0 ,cursor_record.old_effective_end_date, l_wellness_plan_id, NULL, 0);
             ELSE
                l_net_entitlement_old := per_utility_functions.get_net_accrual(cursor_record.assignment_id, cursor_record.old_payroll_id, 325 ,0 ,cursor_record.old_effective_end_date, l_sick_plan_id, NULL, 0);
             END IF;

			-- Get the wellness net entitlement after the change of payroll
             l_last_accrual_date         := NULL;
             l_accrual_end_date          := NULL;
             l_start_date                := NULL;
             l_end_date                  := NULL;
             l_accrual                   := NULL;
             l_net_entitlement_new       := NULL;
             l_accrual_latest_balance    := 0;
             l_accrual_start_date        := '01-JAN-1980';

             IF cursor_record.new_payroll_id <> 46 THEN
                l_net_entitlement_new := per_utility_functions.get_net_accrual(cursor_record.assignment_id, cursor_record.new_payroll_id, 325 ,0 , cursor_record.new_effective_start_date, l_wellness_plan_id, NULL, 0);
             ELSE
                l_net_entitlement_new := per_utility_functions.get_net_accrual(cursor_record.assignment_id, cursor_record.new_payroll_id, 325 ,0 , cursor_record.new_effective_start_date, l_sick_plan_id, NULL, 0);
             END IF;

             -- Generate Sick ENTRY
             IF  l_net_entitlement_old > l_net_entitlement_new THEN

                 IF cursor_record.new_payroll_id <> 46 THEN
                    l_input_value_id_tbl(1) := 37671;                --Hours
                    l_input_value_id_tbl(2) := 37672;                --Entry effective date
                    l_elem_transfer_link_id := l_wel_transfer_link_id;
                    l_elem_name             := 'TTECH Wellness Balance Transfer';
                 ELSE
                    l_input_value_id_tbl(1) := 5968;                --Hours
                    l_input_value_id_tbl(2) := 5969;                --Entry effective date
                    l_elem_transfer_link_id := l_sick_transfer_link_id;
                    l_elem_name             := 'Sick Balance Transfer';
                 END IF;

                 l_entry_value_tbl(1) := to_char(l_net_entitlement_old, '999999.99');
                 l_entry_value_tbl(2) := to_char(cursor_record.new_effective_start_date, 'DD-MON-YYYY');

                 hr_entry_api.insert_element_entry
                (p_effective_start_date => cursor_record.new_effective_start_date,
                 p_date_earned          => cursor_record.new_effective_start_date,
                 p_effective_end_date   => l_effective_end_date,
                 p_element_entry_id     => l_element_entry_id,
                 p_assignment_id        => cursor_record.assignment_id,
                 p_element_link_id      => l_elem_transfer_link_id,
                 p_creator_type         => l_creator_type,
                 p_entry_type           => l_entry_type,
                 p_num_entry_values     => l_num_entry_values,
                 p_input_value_id_tbl   => l_input_value_id_tbl,
                 p_entry_value_tbl      => l_entry_value_tbl);

                 print_line(lpad(cursor_record.assignment_number, 19, ' ') || '|' || rpad(l_elem_name, 33, ' ') || '| ' || to_char(l_net_entitlement_old, '999999.99')  || '   | '||to_char(cursor_record.new_effective_start_date, 'DD-MON-YYYY'));
                 l_written_count := l_written_count + 1;
             END IF;

            -- Update Continuous_service_date
            IF cursor_record.OLD_CONTINUOUS_SVC_DATE IS NOT NULL THEN

               IF cursor_record.new_payroll_id <> 46 THEN
                  l_input_value_id_tbl(1) := 37657;                --SVC DATE TTECH Vacation
               ELSE
                  l_input_value_id_tbl(1) := 13629;                --SVC DATE PTO
               END IF;

                l_entry_value_tbl(1) := to_char(cursor_record.OLD_CONTINUOUS_SVC_DATE, 'DD-MON-YYYY');

                 hr_entry_api.update_element_entry
               (
                p_dt_update_mode           => 'CORRECTION',
                p_session_date             => nvl(cursor_record.new_entry_effective_start_date, cursor_record.NEW_EFFECTIVE_START_DATE),
                p_element_entry_id         => nvl(cursor_record.new_element_entry_id, l_pto_element_entry_id),
                p_num_entry_values         => 1,
                p_input_value_id_tbl       => l_input_value_id_tbl,
                p_entry_value_tbl          => l_entry_value_tbl
               );
            END IF;

         	  EXCEPTION
    			  WHEN OTHERS THEN
		        		 l_error_count := l_error_count + 1;
				         print_line(' ' || cursor_record.assignment_number || ' Error:' || SQLERRM);
		        END;

         END LOOP;

         COMMIT;

        print_line('');
     		print_line(' PROCESS END TIMESTAMP = '  || TO_CHAR(SYSDATE, 'DD-MON-RR HH:MI:SS'));
		    print_line('');
		    print_line('-------------------------------------------------');
		    print_line(' TOTAL RECORDS READ          = '  || TO_CHAR(l_read_count));
		    print_line(' TOTAL WRITTEN               = '  || TO_CHAR(l_written_count));
		    print_line(' TOTAL ERRORS                = '  || TO_CHAR(l_error_count));
		    print_line('-------------------------------------------------');
END;

PROCEDURE GENERATE_ENTRIES_PTO_PCTA     ( errcode                 OUT VARCHAR2,
                                          errbuff                 OUT VARCHAR2,
                                          p_effective_date        IN VARCHAR2)
IS
l_element_entry_id           NUMBER := 0;
l_elem_transfer_link_id      NUMBER := 0;
l_num_entry_values           NUMBER := 0;
l_effective_end_date         DATE := '31-DEC-4712';
l_creator_type               VARCHAR2(10) := 'H';
l_entry_type                 VARCHAR2(10) := 'E';
l_effective_date             DATE;
l_entry_effective_date       DATE;
l_input_value_id_tbl         hr_entry.number_table;
l_entry_value_tbl            hr_entry.varchar2_table;
l_error_count                NUMBER :=0;
l_read_count                 NUMBER :=0;
l_written_count              NUMBER :=0;
l_eligible                   CHAR(1) := 'Y';

BEGIN

  IF p_effective_date IS NOT NULL THEN
     l_effective_date := to_date(p_effective_date);
  ELSE
     l_effective_date := TRUNC(SYSDATE);
  END IF;

  apps.Fnd_File.put_line (apps.Fnd_File.log,'Stage 30');
  -- Out put header information
  print_line('');
  print_line(' PAYROLL-PROCESS - Generate PTO Entries for PERCEPTA');
  print_line('');
  print_line(' EFFECTIVE DATE: '|| l_effective_date);
  print_line('');
  print_line(' Assignment Number |          Name                            | Original Date of Hire | Date Start | Entry Start Date');
  print_line(' ====================================================================================================================');

     FOR cursor_record IN (
        SELECT emp.employee_number, emp.full_name, emp.original_date_of_hire, asg.assignment_id,
              emp.person_id, ppos.date_start, ppos.actual_termination_date, asg.employment_category,
              asg.location_id, loc.location_code, JOB.attribute5, JOB.NAME job_name, asg.assignment_number
		FROM per_all_assignments_f asg,
			 per_all_people_f emp,
			 per_periods_of_service ppos,
			 --hr.hr_locations_all loc, --code commented by RXNETHI-ARGANO,05/05/23
			 apps.hr_locations_all loc, --code added by RXNETHI-ARGANO,05/05/23
			 per_jobs JOB
		WHERE  asg.assignment_status_type_id = 1
		AND asg.payroll_id = 46
		AND emp.person_id = asg.person_id
		AND asg.location_id = loc.location_id
		AND asg.person_id = ppos.person_id
		AND l_effective_date BETWEEN ppos.date_start AND nvl(actual_termination_date, '31-dec-4712')
		AND l_effective_date BETWEEN asg.effective_start_date AND asg.effective_end_date
		AND l_effective_date BETWEEN emp.effective_start_date AND emp.effective_end_date
		AND asg.job_id = JOB.job_id
		AND greatest(ppos.DATE_START, emp.ORIGINAL_DATE_OF_HIRE) = l_effective_date /*- 30*/ --For INC6284365 on 27-MAR-2020
        AND l_effective_date between JOB.date_from AND NVL(JOB.date_to, '31-dec-4712')
		AND NOT EXISTS  (SELECT * FROM pay_element_entries_f pee1
						 WHERE pee1.element_type_id IN (3207, 8106, 8126)
						 AND pee1.assignment_id = asg.assignment_id
						 AND l_effective_date BETWEEN pee1.effective_start_date AND pee1.effective_end_date))

          LOOP
             BEGIN
             l_read_count := l_read_count + 1;

             l_entry_effective_date := greatest(cursor_record.DATE_START, cursor_record.ORIGINAL_DATE_OF_HIRE) ; /*+ 30;*/ --For INC6284365 on 27-MAR-2020

             IF (cursor_record.attribute5 <> 'Agent' OR cursor_record.employment_category <> 'PR' --'Variable'
                OR cursor_record.location_code = 'USA-At Home') THEN

                 hr_entry_api.insert_element_entry
                (p_effective_start_date => l_entry_effective_date,
                 p_effective_end_date   => l_effective_end_date,
                 p_element_entry_id     => l_element_entry_id,
                 p_assignment_id        => cursor_record.assignment_id,
                 p_element_link_id      => 7587, -- TeleTech PTO
                 p_creator_type         => l_creator_type,
                 p_entry_type           => l_entry_type,
                 p_num_entry_values     => l_num_entry_values,
                 p_input_value_id_tbl   => l_input_value_id_tbl,
                 p_entry_value_tbl      => l_entry_value_tbl);

                 hr_entry_api.insert_element_entry
                (p_effective_start_date => l_entry_effective_date,
                 p_effective_end_date   => l_effective_end_date,
                 p_element_entry_id     => l_element_entry_id,
                 p_assignment_id        => cursor_record.assignment_id,
                 p_element_link_id      => 7548, -- Personal Holiday PCTA
                 p_creator_type         => l_creator_type,
                 p_entry_type           => l_entry_type,
                 p_num_entry_values     => l_num_entry_values,
                 p_input_value_id_tbl   => l_input_value_id_tbl,
                 p_entry_value_tbl      => l_entry_value_tbl);

                 hr_entry_api.insert_element_entry
                (p_effective_start_date => l_entry_effective_date,
                 p_effective_end_date   => l_effective_end_date,
                 p_element_entry_id     => l_element_entry_id,
                 p_assignment_id        => cursor_record.assignment_id,
                 p_element_link_id      => 7547, -- Sick Plan PCTA
                 p_creator_type         => l_creator_type,
                 p_entry_type           => l_entry_type,
                 p_num_entry_values     => l_num_entry_values,
                 p_input_value_id_tbl   => l_input_value_id_tbl,
                 p_entry_value_tbl      => l_entry_value_tbl);

                 print_line(lpad(cursor_record.assignment_number, 19, ' ') || '|' || rpad(cursor_record.full_name, 42, ' ')
                            || '|      ' || to_char(cursor_record.original_date_of_hire, 'DD-MON-YYYY')
                            || '      | ' || to_char(cursor_record.date_start, 'DD-MON-YYYY') || '|   ' || TO_CHAR(l_entry_effective_date, 'DD-MON-YYYY'));
                 l_written_count := l_written_count + 1;
            END IF;

			EXCEPTION
    		  WHEN OTHERS THEN
		      		 l_error_count := l_error_count + 1;
			         print_line(' ' || cursor_record.assignment_number || ' Error:' || SQLERRM);
		    END;

        END LOOP;

        COMMIT;

        print_line('');
        print_line(' PROCESS END TIMESTAMP = '  || TO_CHAR(SYSDATE, 'DD-MON-RR HH:MI:SS'));
        print_line('');
        print_line('-------------------------------------------------');
        print_line(' TOTAL RECORDS READ          = '  || TO_CHAR(l_read_count));
        print_line(' TOTAL WRITTEN               = '  || TO_CHAR(l_written_count));
        print_line(' TOTAL ERRORS                = '  || TO_CHAR(l_error_count));
        print_line('-------------------------------------------------');
END;

END ttec_pto_upd_pkg;
/
show errors;
/