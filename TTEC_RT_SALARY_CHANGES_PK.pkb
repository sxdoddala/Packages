create or replace PACKAGE BODY      TTEC_RT_SALARY_CHANGES_PK AS
/*== START ==========================================================*\
  Author:  German Ernst Casaretto
    Date:  29-SEP-2008
    Desc:  Package to load Salary Changes and Headcount information in
           Custom tables for the time period and business group
           selected.

  Modification History:

 Mod#  Date         Author           Description (Include Ticket#)
 ----  -----------  ---------------  --------------------------------------
 001   29-SEP-2008  GERMANCASARETTO  TT #989040 - Creation
 1.0   30-JUN-2023  RXNETHI-ARGANO   R12.2 Upgrade Remediation
\*== END ============================================================*/

	PROCEDURE P_SALARY_CHANGES	(p_date_from		date,
    							 p_date_to			date,
                                 p_business_group	number) IS
/*== START ==========================================================*\
  Author:  German Ernst Casaretto
    Date:  29-SEP-2008
    Desc:  Loads Salary Changes data into CUST.TTEC_RT_SALARY_CHANGES
           custom table for the time period and business group
           selected.

    Parameter Description:
      p_date_from      - Start date of the time period to be informed
      p_date_to        - End date of the time period to be informed
      p_business_group - Business Group to be infomed.

\*== END ============================================================*/

	CURSOR salary_changes_c(v_date_from date, v_date_to date, v_business_group number) IS

    /*
    Returns employee, salary changes and grades information for the business
    group and time period selected.
    */
    select	v_date_from 					"DATE_FROM",
            v_date_to						"DATE_TO",
            sal_changes.CHANGE_DATE			"CHANGE_DATE",
            sal_changes.ASSIGNMENT_ID		"ASSIGNMENT_ID",
            sal_changes.LOS					"LOS",
            sal_changes.BUSINESS_GROUP_ID	"BUSINESS_GROUP_ID",
            sal_changes.BUSINESS_GROUP		"BUSINESS_GROUP",
            sal_changes.LOCATION_ID			"LOCATION_ID",
            sal_changes.LOCATION_CODE		"LOCATION",
            sal_changes.JOB_FAMILY			"JOB_FAMILY",
            sal_changes.PROPOSAL_REASON		"PROPOSAL_REASON",
            sal_changes.ACTUAL_PROPOSAL		"ACTUAL_PROPOSAL",
            sal_changes.OLD_PROPOSAL		"OLD_PROPOSAL",
            sal_changes.PERC_INCREASE		"PERC_INCREASE",
            grades.MINIMUM					"GRADE_MIN",
            grades.MAXIMUM					"GRADE_MAX",
            ROUND(
                CASE
                    WHEN ((grades.MAXIMUM - grades.MINIMUM) = 0 OR grades.MAXIMUM is NULL OR grades.MINIMUM is NULL)
                    THEN 0
                    ELSE (sal_changes.ACTUAL_PROPOSAL - grades.MINIMUM) / (grades.MAXIMUM - grades.MINIMUM) * 100
                END
                ,3) RANGE_PENETRATION
                /*
                Range Penetration formula specified by end user with validations
                in case there are no Valid Grades or Grade Max equals Grade Min
                */
    from	(
            /*
            Returns employee information joined with Salary Change information
            */
            select	DISTINCT
                    pay_proposals.CHANGE_DATE,
                    pay_proposals.ASSIGNMENT_ID,
                    trunc((months_between(pay_proposals.CHANGE_DATE,ppos.DATE_START)/12),1) LOS,
                    pbg.BUSINESS_GROUP_ID,
                    pbg.NAME "BUSINESS_GROUP",
                    hla.LOCATION_ID,
                    hla.LOCATION_CODE,
                    pj.ATTRIBUTE5 "JOB_FAMILY",
                    flv.MEANING "PROPOSAL_REASON",
                    pay_proposals.PERC_INCREASE,
                    pay_proposals.ACTUAL_PROPOSAL,
                    pay_proposals.OLD_PROPOSAL,
                    (substr(pj.name,1,instr(pj.name,'.')-1) || '.' || hla.location_code) GRADE
            /*
			START R12.2 Upgrade Remediation
			code commented by RXNETHI-ARGANO,30/06/23
			from	hr.per_all_assignments_f	paaf,
                    hr.per_all_people_f			papf,
                    apps.per_business_groups	pbg,
                    hr.per_jobs					pj,
                    apps.fnd_lookup_values 		flv,
                    hr.hr_locations_all			hla,
                    hr.per_periods_of_service	ppos,
                    hr.pay_all_payrolls_f		ppf,
                    (
	        */
			--code added by RXNETHI-ARGANO,30/06/23
			from	apps.per_all_assignments_f	paaf,
                    apps.per_all_people_f			papf,
                    apps.per_business_groups	pbg,
                    apps.per_jobs					pj,
                    apps.fnd_lookup_values 		flv,
                    apps.hr_locations_all			hla,
                    apps.per_periods_of_service	ppos,
                    apps.pay_all_payrolls_f		ppf,
                    (
			--END R12.2 Upgrade Remediation
                    /*
                    Get all salary change records for the business group within the time period selected
                    by assignment Id.
                    To be joined with employee information by the Assignment Id.
                    */
                    SELECT	ppp_act.change_date,
                            ppp_act.assignment_id,
                            ppp_act.business_group_id,
                            ppp_act.proposal_reason,
                            decode(ppb_act.pay_basis,'ANNUAL',ppp_act.proposed_salary_n,'MONTHLY',ppp_act.proposed_salary_n * 12,'PERIOD',ppp_act.proposed_salary_n * 24,(ppp_act.proposed_salary_n * 2080)) ACTUAL_PROPOSAL,
                            decode(ppb_old.pay_basis,'ANNUAL', ppp_old.proposed_salary_n,'MONTHLY',ppp_old.proposed_salary_n * 12,'PERIOD', ppp_old.proposed_salary_n * 24,(ppp_old.proposed_salary_n * 2080)) OLD_PROPOSAL,
                            ROUND(((
                            decode(ppb_act.pay_basis,'ANNUAL',ppp_act.proposed_salary_n,'MONTHLY',ppp_act.proposed_salary_n * 12,'PERIOD',ppp_act.proposed_salary_n * 24,(ppp_act.proposed_salary_n * 2080)) /
                            decode(ppb_old.pay_basis,'ANNUAL', ppp_old.proposed_salary_n,'MONTHLY',ppp_old.proposed_salary_n * 12,'PERIOD', ppp_old.proposed_salary_n * 24,(ppp_old.proposed_salary_n * 2080)) * 100
                            ) - 100),3) "PERC_INCREASE"
                            /*
                            All salary amounts are normalized to Annual amounts.
                            */
                    /*
					START R12.2 Upgrade Remediation
					code commented by RXNETHI-ARGANO,30/06/23
					FROM	hr.per_pay_proposals		ppp_act,
                            hr.per_pay_proposals		ppp_old,
                            hr.per_all_assignments_f	paaf_act,
                            hr.per_all_assignments_f	paaf_old,
                            hr.per_pay_bases			ppb_act,
                            hr.per_pay_bases			ppb_old
					*/
					--code added by RXNETHI-ARGANO,30/06/23
					FROM	apps.per_pay_proposals		ppp_act,
                            apps.per_pay_proposals		ppp_old,
                            apps.per_all_assignments_f	paaf_act,
                            apps.per_all_assignments_f	paaf_old,
                            apps.per_pay_bases			ppb_act,
                            apps.per_pay_bases			ppb_old
					--END R12.2 Upgrade Remediation
                    WHERE	ppp_act.business_group_id = v_business_group
                            AND ppp_act.change_date between v_date_from AND v_date_to
                            AND ppp_act.change_date > (
                                                    SELECT	MIN (ppp1.change_date)
                                                    --FROM	per_pay_proposals ppp1 --code commented by RXNETHI-ARGANO,30/06/23        
                                                    FROM	apps.per_pay_proposals ppp1 --code added by RXNETHI-ARGANO,30/06/23
                                                    WHERE	ppp1.assignment_id = ppp_act.assignment_id
                                                  ) /*
                                                    Make sure the record I'm getting it's not the user's first salary,
                                                    but a Salary Change after the first one.
                                                    */
                            and ppp_old.assignment_id = ppp_act.assignment_id
                            and ppp_old.change_date = (
                                                        select	max(ppp_aux.change_date)
                                                        --from	hr.per_pay_proposals ppp_aux  --code commented by RXNETHI-ARGANO,30/06/23
                                                        from	apps.per_pay_proposals ppp_aux  --code added by RXNETHI-ARGANO,30/06/23
                                                        where	ppp_aux.assignment_id = ppp_act.assignment_id
                                                        and		ppp_aux.change_date < ppp_act.change_date
                                                     ) /*
                                                       Max change date before actual proposal; i.e. previous salary.
                                                       */
                            and paaf_act.ASSIGNMENT_ID = ppp_act.ASSIGNMENT_ID
                            and	ppb_act.PAY_BASIS_ID = paaf_act.PAY_BASIS_ID
                            and ppp_act.CHANGE_DATE between paaf_act.EFFECTIVE_START_DATE and paaf_act.EFFECTIVE_END_DATE
                            and paaf_old.ASSIGNMENT_ID = ppp_old.ASSIGNMENT_ID
                            and	ppb_old.PAY_BASIS_ID = paaf_old.PAY_BASIS_ID
                            and ppp_old.CHANGE_DATE between paaf_old.EFFECTIVE_START_DATE and paaf_old.EFFECTIVE_END_DATE
                    )pay_proposals
            where	papf.current_employee_flag = 'Y'
                    and v_date_to between papf.EFFECTIVE_START_DATE and papf.EFFECTIVE_END_DATE
                    and paaf.PERSON_ID = papf.PERSON_ID
                    and paaf.ASSIGNMENT_TYPE = 'E'
                    and paaf.PRIMARY_FLAG = 'Y'
                    and pay_proposals.ASSIGNMENT_ID = paaf.ASSIGNMENT_ID
                    and pay_proposals.change_date between paaf.effective_start_date and paaf.effective_end_date
                    and pbg.BUSINESS_GROUP_ID = pay_proposals.BUSINESS_GROUP_ID
                    and pj.JOB_ID = paaf.JOB_ID
                    and not (
                            pj.NAME like 'D%'
                            OR
                            pj.NAME like 'P%'
                            OR
                            pj.NAME like 'N%'
                            ) /*
                              Jobs starting with D, P or N correspond to DAC, Percepta and Newgen.
                              Should not be included in the report.
                              */
                    and v_date_to between pj.DATE_FROM and nvl(pj.DATE_TO,v_date_to)
                    and ppf.PAYROLL_ID = paaf.PAYROLL_ID
                    and ppf.PAYROLL_NAME not in ('Newgen',
                                                 'NewGen Canada',
                                                 'Newgen Canada Biweekly',
                                                 'Direct Alliance Corporation',
                                                 'Percepta (V76)')
                    /*
                    DAC, Percepta and Newgen employees should not be included in the report.
                    */
                    and flv.security_group_id (+) = decode (pay_proposals.BUSINESS_GROUP_ID,325,2,326,3,2)
                    and flv.lookup_code (+) = pay_proposals.PROPOSAL_REASON
                    and flv.lookup_type (+) = 'PROPOSAL_REASON'
                    and flv.language (+) = USERENV('LANG')
                    and hla.LOCATION_ID = paaf.LOCATION_ID
                    and ppos.PERSON_ID = papf.PERSON_ID
                    and pay_proposals.change_date between ppos.DATE_START and nvl(ppos.ACTUAL_TERMINATION_DATE,trunc(sysdate))
            ) sal_changes,
            /*
            Get all the valid grades for the user's business group.
            If the amount is lower than 1000, we consider hourly basis and
            convert it to annual basis.
            If greater, annual basis and we don't convert it.
            */
            (
            select	distinct
                    pg.BUSINESS_GROUP_ID,
                    pg.name "GRADE",
                    pg.DATE_FROM "GRADE_DATE_FROM",
                    nvl(pg.DATE_TO,trunc(sysdate)) "GRADE_DATE_TO",
                    pgrf.EFFECTIVE_START_DATE "RULE_EFFECTIVE_START_DATE",
                    pgrf.EFFECTIVE_END_DATE "RULE_EFFECTIVE_END_DATE",
                    case
                        when to_number(pgrf.MINIMUM) >= 1000
                        then to_number(pgrf.MINIMUM)
                        else to_number(pgrf.MINIMUM) * 2080
                    end "MINIMUM",
                    to_number(pgrf.MINIMUM) MIN,
                    case
                        when to_number(pgrf.MAXIMUM) >= 1000
                        then to_number(pgrf.MAXIMUM)
                        else to_number(pgrf.MAXIMUM) * 2080
                    end "MAXIMUM"
            --from	hr.per_grades 			pg,        --code commented by RXNETHI-ARGANO,30/06/23
            from	apps.per_grades 			pg,    --code added by RXNETHI-ARGANO,30/06/23
                    --hr.pay_grade_rules_f	pgrf       --code commented by RXNETHI-ARGANO,30/06/23
                    apps.pay_grade_rules_f	pgrf       --code added by RXNETHI-ARGANO,30/06/23
            where	pg.grade_id = pgrf.grade_or_spinal_point_id
                    and pg.BUSINESS_GROUP_ID = v_business_group
            ) grades
    where	grades.GRADE (+) = sal_changes.GRADE
            and grades.BUSINESS_GROUP_ID (+) = sal_changes.BUSINESS_GROUP_ID
            and sal_changes.CHANGE_DATE between grades.GRADE_DATE_FROM (+) and grades.GRADE_DATE_TO (+)
            and sal_changes.CHANGE_DATE between grades.RULE_EFFECTIVE_START_DATE (+) and grades.RULE_EFFECTIVE_END_DATE (+);

	BEGIN

    	/*
        Delete data from the previous execution of the package.
        */
        EXECUTE IMMEDIATE('TRUNCATE TABLE CUST.TTEC_RT_SALARY_CHANGES REUSE STORAGE');

    	FOR salary_change_r IN salary_changes_c(p_date_from,p_date_to,p_business_group) LOOP

            BEGIN

                --INSERT INTO CUST.TTEC_RT_SALARY_CHANGES(      --code commented by RXNETHI-ARGANO,30/06/23
                INSERT INTO APPS.TTEC_RT_SALARY_CHANGES(        --code added by RXNETHI-ARGANO,30/06/23
                    DATE_FROM,
                    DATE_TO,
                    CHANGE_DATE,
                    ASSIGNMENT_ID,
                    LOS,
                    BUSINESS_GROUP_ID,
                    BUSINESS_GROUP,
                    LOCATION_ID,
                    LOCATION,
                    JOB_FAMILY,
                    ACTUAL_PROPOSAL,
                    OLD_PROPOSAL,
                    PROPOSAL_REASON,
                    PERC_INCREASE,
                    RANGE_MIN,
                    RANGE_MAX,
                    RANGE_PENETRATION
                    )
                VALUES(
                    salary_change_r.DATE_FROM,
                    salary_change_r.DATE_TO,
                    salary_change_r.CHANGE_DATE,
                    salary_change_r.ASSIGNMENT_ID,
                    salary_change_r.LOS,
                    salary_change_r.BUSINESS_GROUP_ID,
                    salary_change_r.BUSINESS_GROUP,
                    salary_change_r.LOCATION_ID,
                    salary_change_r.LOCATION,
                    salary_change_r.JOB_FAMILY,
                    salary_change_r.ACTUAL_PROPOSAL,
                    salary_change_r.OLD_PROPOSAL,
                    salary_change_r.PROPOSAL_REASON,
                    salary_change_r.PERC_INCREASE,
                    salary_change_r.GRADE_MIN,
                    salary_change_r.GRADE_MAX,
                    salary_change_r.RANGE_PENETRATION
                    );
            END;
        END LOOP;

        COMMIT;

    EXCEPTION
    	WHEN OTHERS
        THEN raise_application_error (-20009, sqlerrm);

 	END P_SALARY_CHANGES;

     PROCEDURE P_HEADCOUNT	(p_as_of_date 		date,
     						 p_business_group	number) IS
/*== START ==========================================================*\
  Author:  German Ernst Casaretto
    Date:  29-SEP-2008
    Desc:  Loads Headcount data into CUST.TTEC_RT_HEADCOUNT custom
           table for the as of date and business group selected.

    Parameter Description:
      p_as_of_date     - As of date for the Headcount to be calculated
      p_business_group - Business Group to be infomed.

\*== END ============================================================*/

	CURSOR headcount_c(v_as_of_date date, v_business_group number) IS

        select		papf.BUSINESS_GROUP_ID,
                    paaf.LOCATION_ID,
                    pj.ATTRIBUTE5 "JOB_FAMILY",
                    p_as_of_date "AS_OF_DATE",
                    count(distinct papf.EMPLOYEE_NUMBER)  HEADCOUNT
        /*
		START R12.2 Upgrade Remediation
		code commented by RXNETHI-ARGANO,30/06/23
		from		hr.per_all_people_f			papf,
                    hr.per_all_assignments_f	paaf,
                    hr.per_jobs					pj,
                    hr.pay_all_payrolls_f		ppf
		*/
		--code added by RXNETHI-ARGANO,30/06/23
		from		apps.per_all_people_f			papf,
                    apps.per_all_assignments_f	paaf,
                    apps.per_jobs					pj,
                    apps.pay_all_payrolls_f		ppf
		--END R12.2 Upgrade Remediation
        where		papf.BUSINESS_GROUP_ID = v_business_group
                    and papf.CURRENT_EMPLOYEE_FLAG = 'Y'
                    and p_as_of_date between papf.EFFECTIVE_START_DATE (+) and papf.EFFECTIVE_END_DATE (+)
                    and paaf.PERSON_ID = papf.PERSON_ID
                    and paaf.ASSIGNMENT_TYPE = 'E'
                    and paaf.PRIMARY_FLAG = 'Y'
                    and p_as_of_date between paaf.EFFECTIVE_START_DATE (+) and paaf.EFFECTIVE_END_DATE (+)
                    and pj.JOB_ID (+) = paaf.JOB_ID
                    and p_as_of_date between pj.DATE_FROM (+) and nvl(pj.DATE_TO (+),p_as_of_date)
                    and not (
                            pj.NAME like 'D%'
                            OR
                            pj.NAME like 'P%'
                            OR
                            pj.NAME like 'N%'
                            ) /*
                              Jobs starting with D, P or N correspond to DAC, Percepta and Newgen.
                              Should not be included in the report.
                              */
                    and ppf.PAYROLL_ID = paaf.PAYROLL_ID
                    and ppf.PAYROLL_NAME not in ('Newgen',
                                                 'NewGen Canada',
                                                 'Newgen Canada Biweekly',
                                                 'Direct Alliance Corporation',
                                                 'Percepta (V76)')
                    /*
                    DAC, Percepta and Newgen employees should not be included in the report.
                    */
        group by	papf.BUSINESS_GROUP_ID,
                    paaf.LOCATION_ID,
                    pj.ATTRIBUTE5;

    BEGIN

    	/*
        Delete data from the previous execution of the package.
        */
    	EXECUTE IMMEDIATE('TRUNCATE TABLE CUST.TTEC_RT_HEADCOUNT REUSE STORAGE');

    	FOR headcount_r IN headcount_c(p_as_of_date,p_business_group) LOOP

            BEGIN

                --INSERT INTO CUST.TTEC_RT_HEADCOUNT(    --code commented by RXNETHI-ARGANO,30/06/23
                INSERT INTO APPS.TTEC_RT_HEADCOUNT(      --code added by RXNETHI-ARGANO,30/06/23
                	BUSINESS_GROUP_ID,
                    LOCATION_ID,
                    JOB_FAMILY,
                    AS_OF_DATE,
                    HEADCOUNT
                )
                VALUES(
                	headcount_r.BUSINESS_GROUP_ID,
                    headcount_r.LOCATION_ID,
                    headcount_r.JOB_FAMILY,
                    headcount_r.AS_OF_DATE,
                    headcount_r.HEADCOUNT
                );
            END;
        END LOOP;

        COMMIT;

    EXCEPTION
    	WHEN OTHERS
        THEN raise_application_error (-20009, sqlerrm);
 	END P_HEADCOUNT;

     PROCEDURE P_SALARY_CHANGES_HEADCOUNT	(errbuf 			OUT VARCHAR2,
     										 retcode 			OUT VARCHAR2,
                                             p_date_from		IN VARCHAR2,
                                             p_date_to		 	IN VARCHAR2,
                                             p_business_group	IN NUMBER) IS
/*== START ==========================================================*\
  Author:  German Ernst Casaretto
    Date:  29-SEP-2008
    Desc:  Procedure to be executed from a Concurrent Request that
           executes both P_SALARY_CHANGES and P_HEADCOUNT.

    Parameter Description:
      p_date_from      - Start date of the time period to be informed
      p_date_to        - End date of the time period to be informed
      p_business_group - Business Group to be infomed.

\*== END ============================================================*/

    BEGIN

        TTEC_RT_SALARY_CHANGES_PK.P_SALARY_CHANGES
        (
        p_date_from      => to_date(p_date_from,'YYYY/MM/DD HH24:Mi:SS'),
        p_date_to        => to_date(p_date_to,'YYYY/MM/DD HH24:Mi:SS'),
        p_business_group => p_business_group
        );
        TTEC_RT_SALARY_CHANGES_PK.P_HEADCOUNT
        (
        p_as_of_date     => to_date(p_date_to,'YYYY/MM/DD HH24:Mi:SS'),
        p_business_group => p_business_group
        );
    END P_SALARY_CHANGES_HEADCOUNT;

END TTEC_RT_SALARY_CHANGES_PK;
/
show errors;
/