create or replace PACKAGE BODY      ttec_hmo_rpt_dpnt_ageout
IS
   /*---------------------------------------------------------------------------------------
    Objective    : Interface to extract data for all PHL employees to send to Asian Life Insurance Vendor enrolled in Life Insurance Plan
   Package spec :APPS.ttec_phl_LifeIns_intf_pkg
   Parameters:
              p_start_date  -- Optional start paramters to run the report if the data is missing for particular dates
              p_end_date  -- Optional end paramters to run the report if the data is missing for particular dates
     MODIFICATION HISTORY
     Person               Version  Date        Comments
     ------------------------------------------------
     CTS Prachi             1.0    07/18/2017 Created
	   MXKEERTHI(ARGANO)    1.0 05/17/2023            R12.2 Upgrade Remediation
  *== END ==================================================================================================*/
  PROCEDURE main_proc (
    errbuf                OUT       VARCHAR2
   ,retcode               OUT       NUMBER
   ,p_output_directory    IN        VARCHAR2
   ,p_start_date          IN        VARCHAR2
   ,p_end_date            IN        VARCHAR2
  )
  IS
    CURSOR c_emp_dep_ageout (
      p_start_date        DATE
     ,p_end_date    DATE
    )
    IS
    SELECT
               ppf.last_name emp_last_name
              ,ppf.first_name emp_first_name
              ,decode(ppf.marital_status,'S','Single','M','Married','Others') emp_marital_status
              ,hla.location_code emp_location
              ,ppf.employee_number employee_number
              ,ppf.date_of_birth emp_dob
              ,sup.full_name sup_name
              ,sup.email_address sup_email_addr
              ,ppf.last_name dpnt_last_name
              ,ppf.first_name dpnt_first_name
              ,'Self' Relationship
             ,ppf.date_of_birth dpnt_dob
           ,trunc((trunc(sysdate)-ppf.date_of_birth)/(365)) dpnt_age
          FROM ben_pl_f pln
              ,ben_prtt_enrt_rslt_f pen
              ,ben_per_in_ler pil
              ,per_all_people_f ppf
              ,ben_opt_f opt
              ,ben_oipl_f oipl
              ,per_all_assignments_f paaf
              ,hr_locations_all hla
              ,per_all_people_f sup
         WHERE paaf.person_id = pen.person_id
         and paaf.supervisor_id = sup.person_id
           AND paaf.location_id = hla.location_id
           AND hla.inactive_date IS NULL
           AND p_end_date BETWEEN pln.effective_start_date AND pln.effective_end_date
           AND p_end_date BETWEEN ppf.effective_start_date AND ppf.effective_end_date
           AND p_end_date BETWEEN paaf.effective_start_date AND paaf.effective_end_date
           AND p_end_date BETWEEN sup.effective_start_date AND sup.effective_end_date
           AND pen.oipl_id = oipl.oipl_id
           AND oipl.pl_id = pln.pl_id
           AND oipl.opt_id = opt.opt_id
           AND pen.person_id = ppf.person_id
           AND pln.business_group_id = 1517
           AND pln.pl_stat_cd = 'A'
           AND pln.pl_id = pen.pl_id(+)
           AND pen.prtt_enrt_rslt_stat_cd IS NULL
           AND pen.business_group_id(+) = 1517
           AND NVL (pen.enrt_cvg_thru_dt, p_end_date) <= NVL (pen.effective_end_date, p_end_date)
           --AND pen.sspndd_flag(+) = 'N'
           AND pil.per_in_ler_id(+) = pen.per_in_ler_id
           --AND pen.person_id = p_person_id
           AND (   pil.per_in_ler_stat_cd IN ('STRTD', 'PROCD')
                OR pil.per_in_ler_stat_cd IS NULL)
           AND (   p_start_date BETWEEN pen.enrt_cvg_strt_dt AND pen.enrt_cvg_thru_dt
                OR p_end_date BETWEEN pen.enrt_cvg_strt_dt AND pen.enrt_cvg_thru_dt
                OR (    p_start_date >= pen.enrt_cvg_strt_dt
                    AND p_end_date <= pen.enrt_cvg_thru_dt)
                OR (    p_start_date <= pen.enrt_cvg_strt_dt
                    AND p_end_date >= pen.enrt_cvg_thru_dt)
                OR     pen.enrt_cvg_strt_dt IS NULL
                   AND pen.enrt_cvg_thru_dt IS NULL
               )
           AND pln.pl_id IN (SELECT pl_id
                               FROM ben_pl_f
                              WHERE business_group_id = 1517
                                AND name IN ('PhilCare HMO'))
           AND p_end_date BETWEEN oipl.effective_start_date AND oipl.effective_end_date
           /*AND NOT EXISTS (SELECT 1
                             FROM ben_prtt_enrt_rslt_f pen1
                            WHERE pen.person_id = pen1.person_id
                              AND pen1.prtt_enrt_rslt_stat_cd IS NULL
                              AND pen1.prtt_enrt_rslt_id <> pen.prtt_enrt_rslt_id
                              AND pen1.business_group_id(+) = 1517
                              AND pen.enrt_cvg_strt_dt < pen1.enrt_cvg_strt_dt
                              AND NVL (pen.bnft_amt, -1) = NVL (pen1.bnft_amt, -1)
                              AND pen.pl_id = pen1.pl_id
                              AND (   p_start_date BETWEEN pen1.enrt_cvg_strt_dt AND pen1.enrt_cvg_thru_dt
                                   OR p_end_date BETWEEN pen1.enrt_cvg_strt_dt AND pen1.enrt_cvg_thru_dt
                                   OR (    p_start_date >= pen1.enrt_cvg_strt_dt
                                       AND p_end_date <= pen1.enrt_cvg_thru_dt)
                                   OR (    p_start_date <= pen1.enrt_cvg_strt_dt
                                       AND p_end_date >= pen1.enrt_cvg_thru_dt)
                                   OR     pen1.enrt_cvg_strt_dt IS NULL
                                      AND pen1.enrt_cvg_thru_dt IS NULL
                                  ))*/
            AND (ADD_MONTHS (ppf.date_of_birth, 70 * 12) between p_start_date and p_end_date)
 UNION
      SELECT      ppf.last_name emp_last_name
            ,ppf.first_name emp_first_name
            ,decode(ppf.marital_status,'S','Single','M','Married','Others') emp_marital_status
            ,hla.location_code emp_location
            ,ppf.employee_number employee_number
            ,ppf.date_of_birth emp_dob
            ,sup.full_name sup_name
            ,sup.email_address sup_email_addr
            ,con.last_name dpnt_last_name
            ,con.first_name dpnt_first_name
            ,(
              select meaning from fnd_lookup_values flv
              where flv.lookup_code = pcr.contact_type
              and flv.language = 'US'
              and flv.lookup_type = 'CONTACT'
              and flv.SECURITY_GROUP_ID = 0
             ) Relationship
             ,con.date_of_birth dpnt_dob
           -- ,ppf.person_id
            --,dpnt.dpnt_person_id bnft_person_id
          --  ,pen.ORGNL_ENRT_DT
          --  ,con.last_name mem_last_name
          --  ,con.first_name mem_first_name
           -- ,con.middle_names mem_middle_name
           -- ,con.sex sex_code
           -- ,dpnt.cvg_strt_dt enrt_cvg_strt_dt
           -- ,dpnt.cvg_thru_dt enrt_cvg_thru_dt
           -- ,ppf.original_date_of_hire emp_dt_of_hire
          --  ,ppf.employee_number emp_number
          --  ,ppf.current_employee_flag cur_emp_flag
           ,trunc((trunc(sysdate)-con.date_of_birth)/(365)) dpnt_age
          --  pen.pl_id
	 --START R12.2 Upgrade Remediation
	  /*
	    	Commented code by MXKEERTHI-ARGANO, 05/17/2023
      FROM   ben.ben_pl_f pln
            ,ben.ben_prtt_enrt_rslt_f pen
            ,ben.ben_elig_cvrd_dpnt_f dpnt
	   */
	  --code Added  by MXKEERTHI-ARGANO, 05/17/2023
     FROM   apps.ben_pl_f pln
            ,apps.ben_prtt_enrt_rslt_f pen
            ,apps.ben_elig_cvrd_dpnt_f dpnt
	  --END R12.2.10 Upgrade remediation

 
            ,apps.per_all_people_f ppf
            ,apps.per_all_assignments_f paf
            ,apps.hr_locations_all hla
            ,apps.per_all_people_f sup
			    --START R12.2 Upgrade Remediation
	  /*
	    	Commented code by MXKEERTHI-ARGANO, 05/17/2023
            ,ben.ben_opt_f opt
            ,ben.ben_oipl_f oipl
	   */
	  --code Added  by MXKEERTHI-ARGANO, 05/17/2023
           ,apps.ben_opt_f opt
            ,apps.ben_oipl_f oipl
	  --END R12.2.10 Upgrade remediation
          ,apps.per_all_people_f con
            ,apps.per_contact_relationships pcr
       WHERE p_end_date BETWEEN pln.effective_start_date AND pln.effective_end_date
       and p_end_date BETWEEN oipl.effective_start_date AND oipl.effective_end_date
       and p_end_date BETWEEN opt.effective_start_date AND opt.effective_end_date
       AND p_end_date BETWEEN ppf.effective_start_date AND ppf.effective_end_date
       AND p_end_date BETWEEN paf.effective_start_date AND paf.effective_end_date
         AND p_end_date BETWEEN con.effective_start_date AND con.effective_end_date
        AND p_end_date BETWEEN sup.effective_start_date AND sup.effective_end_date
         and (p_start_date between pen.effective_start_date and pen.effective_end_Date)
         and paf.person_id = ppf.person_id
         and paf.location_id = hla.location_id
         and paf.supervisor_id = sup.person_id
         AND pen.person_id = ppf.person_id
         AND pen.prtt_enrt_rslt_id = dpnt.prtt_enrt_rslt_id
         AND con.person_id = dpnt.dpnt_person_id
         and pcr.person_id = pen.person_id
         and hla.inactive_date is null
         and pcr.contact_type <> 'EMRG'
         and pcr.contact_person_id = dpnt.dpnt_person_id
         AND pln.business_group_id = 1517
         AND pln.pl_stat_cd = 'A'
         AND pln.pl_id = pen.pl_id(+)
         AND pen.oipl_id = oipl.oipl_id
         AND oipl.pl_id = pen.pl_id
         AND oipl.opt_id = opt.opt_id
         AND pen.prtt_enrt_rslt_stat_cd IS NULL
         and nvl(pcr.date_end,p_start_date) <= p_end_date
         AND pen.business_group_id(+) = 1517
         AND (   NVL (dpnt.cvg_thru_dt, dpnt.effective_end_date) <= dpnt.effective_end_date
              OR dpnt.effective_end_date = TO_DATE ('31-DEC-4712', 'DD-MON-RRRR'))
         and pen.person_id in (SELECT  distinct
                                  person_id
                                  FROM per_periods_of_service ppos
                                 WHERE business_group_id = 1517
                                   AND (   (    TRUNC (ppos.last_update_date) BETWEEN p_start_date AND p_end_date
                                            AND ppos.actual_termination_date IS NOT NULL)
                                        OR (    ppos.actual_termination_date IS NULL
                                            AND ppos.person_id IN (SELECT DISTINCT person_id
                                                                              FROM per_all_people_f papf
                                                                             WHERE papf.current_employee_flag = 'Y'))
                                        OR (    ppos.actual_termination_date = (SELECT MAX (actual_termination_date)
                                                                                  FROM per_periods_of_service
                                                                                 WHERE person_id = ppos.person_id
                                                                                   AND actual_termination_date IS NOT NULL)
                                            AND ppos.actual_termination_date >= p_end_date))
                                            )
         AND EXISTS (SELECT dep.per_in_ler_id
                       FROM ben_per_in_ler dep
                      WHERE dep.per_in_ler_id = pen.per_in_ler_id
                        AND dep.business_group_id = 1517
                        AND (   dep.per_in_ler_stat_cd IN ('STRTD', 'PROCD')
                             OR dep.per_in_ler_stat_cd IS NULL))
         AND pen.sspndd_flag(+) = 'N'
         AND dpnt.cvg_strt_dt <= p_end_date
         AND NVL (dpnt.cvg_thru_dt, p_end_date) >= p_start_date
         AND dpnt.cvg_strt_dt <= NVL (dpnt.cvg_thru_dt, p_end_date)   --Added for v1.4
         --AND opt.name <> 'Waive'
         AND pln.pl_id IN (SELECT pl_id
                             FROM ben_pl_f
                            WHERE business_group_id = 1517
                              AND name IN ('PhilCare HMO'))
         AND ( ((ADD_MONTHS (con.date_of_birth, 22 * 12) between p_start_date and p_end_date)
               and pcr.contact_type NOT IN  ('S','D' ))
               or
               ((ADD_MONTHS (con.date_of_birth, 70 * 12) between p_start_date and p_end_date)
               AND PCR.CONTACT_TYPE IN ('S','D'))
             )
         order by employee_number,emp_dob;

    CURSOR c_host
    IS
      SELECT host_name
            ,instance_name
        FROM v$instance;

    v_text                    VARCHAR (32765)                 DEFAULT '';
    v_file_extn               VARCHAR2 (200)                  DEFAULT '';
    v_time                    VARCHAR2 (20);
    l_hmo_dpnt_age_out    VARCHAR2 (200)                  DEFAULT '';
    v_hmo_dpnd_file_type      UTL_FILE.FILE_TYPE;
    v_cut_off_date            DATE;
    v_current_run_date        DATE;
    v_dpnt_hmo_age_out         NUMBER;
  --  l_trans_type              VARCHAR2 (1);
 --   l_enrt_cvg_thru_dt        VARCHAR2 (11);
    l_host_name               v$instance.host_name%TYPE;
    l_instance_name           v$instance.instance_name%TYPE;
    l_identifier              VARCHAR2 (10);
     --l_opt_name      BEN_opt_f.name%TYPE;
    -- l_bnft_grp_name BEN_BENFTS_GRP.name%TYPE;
    -- l_mgr_type      BEN_BENFTS_GRP.name%TYPE;
    l_error_step              VARCHAR2 (10);
  BEGIN
    IF    p_end_date IS NULL

    THEN
      v_current_run_date   := TRUNC (SYSDATE);
    ELSE
      -- v_cut_off_date     := TO_DATE(p_start_date, 'YYYY/MM/DD HH24:MI:SS');
      v_current_run_date   := TO_DATE (p_end_date, 'YYYY/MM/DD HH24:MI:SS');
    END IF;

     IF    p_start_date IS NULL

    THEN
      v_cut_off_date   := TRUNC (SYSDATE,'RRRR');
    ELSE
      -- v_cut_off_date     := TO_DATE(p_start_date, 'YYYY/MM/DD HH24:MI:SS');
      v_cut_off_date   := TO_DATE (p_start_date, 'YYYY/MM/DD HH24:MI:SS');
    END IF;


    v_dpnt_hmo_age_out        := 0;

    OPEN c_host;

    FETCH c_host
     INTO l_host_name
         ,l_instance_name;

    CLOSE c_host;

    IF l_host_name NOT IN (ttec_library.xx_ttec_prod_host_name)
    THEN
      l_identifier   := 'TEST';
    ELSE
      l_identifier   := 'PROD';
    END IF;

    FND_FILE.PUT_LINE (FND_FILE.LOG, 'Host Name:');

    BEGIN
      SELECT '.CSV'
            ,TO_CHAR (SYSDATE, 'MMDDYYYY_HH24MI')
        INTO v_file_extn
            ,v_time
        FROM v$instance;
    EXCEPTION
      WHEN OTHERS
      THEN
        v_file_extn   := '.csv';
    END;

    FND_FILE.PUT_LINE (FND_FILE.LOG, 'extension name:');
    l_hmo_dpnt_age_out   := l_identifier || '_HMODependentAgeOut_' || v_time || v_file_extn;
    FND_FILE.PUT_LINE (FND_FILE.LOG, 'FILE name:');
    v_hmo_dpnd_file_type     := UTL_FILE.FOPEN (p_output_directory, l_hmo_dpnt_age_out, 'w', 32765);
    --Header for the File
    v_text                   := 'Employee No|First Name|Last Name|Emp DOB|Marital Status|Location|Supervisor Name|Supervisor Email Address|Dpnt First Name|Dpnt Last Name|Contact Type|Dpnt DOB|Dpnt Age';
    UTL_FILE.PUT_LINE (v_hmo_dpnd_file_type, v_text);
    FND_FILE.PUT_LINE (FND_FILE.OUTPUT, v_text);




      --fnd_file.put_line(fnd_file.output, 'r_emp_rec.person_id'||r_emp_rec.person_id);
      FOR r_bnft_info IN c_emp_dep_ageout ( v_cut_off_date, v_current_run_date)
      LOOP
        v_text   := '';

          BEGIN
            v_text              := r_bnft_info.employee_number ||
                                   '|' ||
                                   replace(r_bnft_info.emp_first_name,',') ||
                                   '|' ||
                                   replace(r_bnft_info.emp_last_name,',') ||
                                   '|' ||
                                   r_bnft_info.emp_dob ||
                                   '|' ||
                                   r_bnft_info.emp_marital_status ||
                                   '|' ||
                                   r_bnft_info.emp_location ||
                                   '|' ||
                                   replace(r_bnft_info.sup_name,',') ||
                                   '|' ||
                                   r_bnft_info.sup_email_addr ||
                                   '|' ||
                                   replace(r_bnft_info.dpnt_first_name,',') ||
                                   '|' ||
                                   replace(r_bnft_info.dpnt_last_name,',') ||
                                   '|' ||
                                   r_bnft_info.Relationship||
                                   '|' ||
                                   r_bnft_info.dpnt_dob ||
                                   '|' ||
                                   r_bnft_info.dpnt_age
                                   ;
            UTL_FILE.PUT_LINE (v_hmo_dpnd_file_type, v_text);
            v_dpnt_hmo_age_out   := v_dpnt_hmo_age_out + 1;
            FND_FILE.PUT_LINE (FND_FILE.OUTPUT, v_text);
          END;

    END LOOP;

    FND_FILE.PUT_LINE (FND_FILE.LOG, 'Total Count:' || v_dpnt_hmo_age_out);
    UTL_FILE.FCLOSE (v_hmo_dpnd_file_type);
  EXCEPTION
    WHEN OTHERS
    THEN
      UTL_FILE.FCLOSE (v_hmo_dpnd_file_type);
      FND_FILE.PUT_LINE (FND_FILE.LOG, 'Error out of main loop main_proc -' || SQLERRM);
  END main_proc;
END ttec_hmo_rpt_dpnt_ageout;
/
show errors;
/