create or replace PACKAGE BODY ttec_med_election_list AS

  /*-----------------------------------------------------

  Desc : This package is used to print the list
                of active plans for employees.

   Modification History:

  Version    Date       Author      Description
  -----     --------    --------   ---------------
  1.0     01/29/2015   Arun Kumar     Draft version
  1.0     05/10/2023   RXNETHI-ARGANO R12.2 Upgrade Remediation

  ------------------------------------------------------*/

  PROCEDURE main_list(retcode        OUT NUMBER,
                      errbuf         OUT VARCHAR2,
                      p_env_cov_date IN VARCHAR2,
                      p_med_plan_id  IN NUMBER,
                      p_emp_num      IN VARCHAR2,
                      p_ssn          IN VARCHAR2,
                      p_first_name   IN VARCHAR2,
                      p_last_name    IN VARCHAR2,
                      p_location     IN NUMBER) AS

    v_code   NUMBER;
    v_errm   VARCHAR2(255);
    v_header VARCHAR2(1000);
    v_record VARCHAR2(1000);
    v_flag   BOOLEAN := TRUE;

    CURSOR cur_med_list IS
    /*SELECT pap.employee_number  EMPLOYEE_NUMBER,
                 pap.full_name        EMPLOYEE_NAME,
                 pap.start_date       HIRE_DATE,
                 hrl.location_code    LOCATION,
                 pen.enrt_cvg_strt_dt COVERAGE_START_DATE, ---Coverage Start Date---
                 pen.LAST_UPDATE_DATE LAST_UPDATE_DATE,
                 pen.CREATION_DATE    CREATION_DATE,
                 bpl.NAME             PLAN,
                 opt.NAME             OPTION_FLD
            FROM hr.per_all_people_f pap,
                 ben.ben_prtt_enrt_rslt_f pen,
                 hr.hr_locations_all hrl,
                 hr.per_all_assignments_f paa,
                 (SELECT *
                    FROM ben.ben_pl_f bp
                   WHERE TRUNC(fnd_date.canonical_to_date(p_env_cov_date)) BETWEEN
                         bp.effective_start_date AND bp.effective_end_date
                     AND pl_typ_id = (SELECT bpf.pl_typ_id
                                        FROM apps.ben_pl_typ_f bpf
                                       WHERE UPPER(bpf.name) = 'MEDICAL'
                                         AND TRUNC(fnd_date.canonical_to_date(p_env_cov_date)) BETWEEN
                                             bpf.effective_start_date AND
                                             bpf.effective_end_date)) bpl,
                 (SELECT *
                    FROM ben.ben_opt_f
                   WHERE TRUNC(fnd_date.canonical_to_date(p_env_cov_date)) BETWEEN
                         effective_start_date AND effective_end_date) opt,
                 ben.ben_oipl_f opl
           WHERE opl.opt_id = opt.opt_id(+)
             AND pen.sspndd_flag = 'N'
             AND pen.oipl_id = opl.oipl_id(+)
             AND pen.pl_id = bpl.pl_id
             AND pap.current_employee_flag = 'Y'
             AND TRUNC(ADD_MONTHS(fnd_date.canonical_to_date(p_env_cov_date),
                                  12),
                       'YYYY') BETWEEN pen.enrt_cvg_strt_dt AND
                 pen.enrt_cvg_thru_dt
             AND TRUNC(ADD_MONTHS(fnd_date.canonical_to_date(p_env_cov_date),
                                  12),
                       'YYYY') BETWEEN pen.effective_start_date AND
                 pen.effective_end_date
             AND pen.prtt_enrt_rslt_stat_cd IS NULL
             AND pen.person_id = pap.person_id
             AND TRUNC(ADD_MONTHS(fnd_date.canonical_to_date(p_env_cov_date),
                                  12),
                       'YYYY') BETWEEN pap.effective_start_date AND
                 pap.effective_end_date
             AND pap.person_id = paa.person_id
             AND paa.location_id = hrl.location_id
             AND TRUNC(ADD_MONTHS(fnd_date.canonical_to_date(p_env_cov_date),
                                  12),
                       'YYYY') BETWEEN paa.effective_start_date AND
                 paa.effective_end_date
                -- Parameter section
             AND pen.pl_id = p_med_plan_id -- Medical Plan
             AND pen.enrt_cvg_strt_dt >=
                 TRUNC(ADD_MONTHS(fnd_date.canonical_to_date(p_env_cov_date), 12), 'YYYY') -- Coverage Start Date
             AND pap.employee_number = NVL(p_emp_num, pap.employee_number) -- Employee Number
             AND pap.national_identifier = NVL(p_ssn, pap.national_identifier) -- SSN
             AND pap.first_name = NVL(p_first_name, pap.first_name) -- First Name
             AND pap.last_name = NVL(p_last_name, pap.last_name) -- Last Name
             AND hrl.location_id = NVL(p_location, hrl.location_id) -- Location
           order by 2, 4;*/

      SELECT pap.employee_number  EMPLOYEE_NUMBER,
             pap.full_name        EMPLOYEE_NAME,
             pap.start_date       HIRE_DATE,
             hrl.location_code    LOCATION,
             pen.enrt_cvg_strt_dt COVERAGE_START_DATE, ---Coverage Start Date---
             pen.LAST_UPDATE_DATE LAST_UPDATE_DATE,
             pen.CREATION_DATE    CREATION_DATE,
             bpl.NAME             PLAN,
             opt.NAME             OPTION_FLD
        /*
		START R12.2 Upgrade Remediation
		code commented by RXNETHI-ARGANO
		FROM hr.per_all_people_f pap,
             ben.ben_prtt_enrt_rslt_f pen,
             hr.hr_locations_all hrl,
             hr.per_all_assignments_f paa, 
			 */
		--code added by RXNETHI-ARGANO
		FROM apps.per_all_people_f pap,
             apps.ben_prtt_enrt_rslt_f pen,
             apps.hr_locations_all hrl,
             apps.per_all_assignments_f paa,
		--END R12.2 Upgrade Remediation
             (SELECT *
                --FROM ben.ben_pl_f bp --code commented by RXNETHI-ARGANO,10/05/23
				FROM apps.ben_pl_f bp --code added by RXNETHI-ARGANO,10/05/23
               WHERE TRUNC(fnd_date.canonical_to_date(p_env_cov_date)) BETWEEN
                     bp.effective_start_date AND bp.effective_end_date
                 AND pl_typ_id = (SELECT bpf.pl_typ_id
                                    FROM apps.ben_pl_typ_f bpf
                                   WHERE UPPER(bpf.name) = 'MEDICAL'
                                     AND TRUNC(fnd_date.canonical_to_date(p_env_cov_date)) BETWEEN
                                         bpf.effective_start_date AND
                                         bpf.effective_end_date)) bpl,
             (SELECT *
                --FROM ben.ben_opt_f --code commented by RXNETHI-ARGANO,10/05/23
				FROM apps.ben_opt_f --code added by RXNETHI-ARGANO,10/05/23
               WHERE TRUNC(fnd_date.canonical_to_date(p_env_cov_date)) BETWEEN
                     effective_start_date AND effective_end_date) opt,
             --ben.ben_oipl_f opl   --code commented by RXNETHI-ARGANO,10/05/23
             apps.ben_oipl_f opl    --code added by RXNETHI-ARGANO,10/05/23
       WHERE opl.opt_id = opt.opt_id(+)
         AND pen.sspndd_flag = 'N'
         AND pen.oipl_id = opl.oipl_id(+)
         AND pen.pl_id = bpl.pl_id
         AND pap.current_employee_flag = 'Y'
         AND fnd_date.canonical_to_date(p_env_cov_date) BETWEEN
             pen.enrt_cvg_strt_dt AND pen.enrt_cvg_thru_dt
         AND fnd_date.canonical_to_date(p_env_cov_date) BETWEEN
             pen.effective_start_date AND pen.effective_end_date
         AND pen.prtt_enrt_rslt_stat_cd IS NULL
         AND pen.person_id = pap.person_id
         AND fnd_date.canonical_to_date(p_env_cov_date) BETWEEN
             pap.effective_start_date AND pap.effective_end_date
         AND pap.person_id = paa.person_id
         AND paa.location_id = hrl.location_id
         AND fnd_date.canonical_to_date(p_env_cov_date) BETWEEN
             paa.effective_start_date AND paa.effective_end_date
            -- Parameter section
         AND pen.pl_id = p_med_plan_id -- Medical Plan
         AND pen.enrt_cvg_strt_dt >=
             fnd_date.canonical_to_date(p_env_cov_date) -- Coverage Start Date
         AND pap.employee_number = NVL(p_emp_num, pap.employee_number) -- Employee Number
         AND pap.national_identifier = NVL(p_ssn, pap.national_identifier) -- SSN
         AND pap.first_name = NVL(p_first_name, pap.first_name) -- First Name
         AND pap.last_name = NVL(p_last_name, pap.last_name) -- Last Name
         AND hrl.location_id = NVL(p_location, hrl.location_id) -- Location
       order by 2, 4;

  BEGIN

    v_header := 'Employee Number|Employee Name|Hire Date|Location|Coverage Start Date|Last Update Date|Creation Date|Plan|Option';
    FND_FILE.PUT_LINE(FND_FILE.OUTPUT, v_header);

    FOR cur_med_list_data IN cur_med_list LOOP

      v_record := cur_med_list_data.employee_number || '|' ||
                  cur_med_list_data.employee_name || '|' ||
                  cur_med_list_data.hire_date || '|' ||
                  cur_med_list_data.location || '|' ||
                  cur_med_list_data.coverage_start_date || '|' ||
                  cur_med_list_data.last_update_date || '|' ||
                  cur_med_list_data.creation_date || '|' ||
                  cur_med_list_data.plan || '|' ||
                  cur_med_list_data.option_fld;

      FND_FILE.PUT_LINE(FND_FILE.OUTPUT, v_record);

      v_flag := FALSE;

    END LOOP;

    IF v_flag THEN
      FND_FILE.PUT_LINE(FND_FILE.OUTPUT, 'No Data Available');
      FND_FILE.PUT_LINE(FND_FILE.LOG, 'No Data Available');
    END IF;

  EXCEPTION
    WHEN OTHERS THEN
      v_code := SQLCODE;
      v_errm := SUBSTR(SQLERRM, 1, 255);
      FND_FILE.PUT_LINE(FND_FILE.LOG,
                        'Program failed due to following error(s)');
      FND_FILE.PUT_LINE(FND_FILE.LOG, v_code || ' - ' || v_errm);

  END main_list;
END ttec_med_election_list;
/
show errors;
/