create or replace PACKAGE BODY      ttec_ben_3plan_metlife_intf
IS
  /*---------------------------------------------------------------------------------------
    Objective    : Interface to extract data for all US employees to send to Metlife Vendor
                  enrolled in Critical Illness Coverage,AIG Coverage, MetLaw Coverage
   Package spec :TTEC_BEN_3PLAN_METLIFE_INTF
   Parameters:
              p_start_date  -- Optional start paramters to run the report if the data is missing for particular dates
              p_end_date  -- Optional end paramters to run the report if the data is missing for particular dates
     MODIFICATION HISTORY
     Person               Version  Date        Comments
     ------------------------------------------------
     Kaushik Babu         1.0      1/20/2014  New package for sending on going employee enrollments
     C.Chan               1.1      01/07/2015  Comment out Location Exclusion
     Prachi R             1.2      05/26/2017 Changes for high plan low plan and branch code
     Prachi R             1.3      11/30/2017 Changes for Hospital Indemnity Plan TASK0619722
     Prachi R             1.4      01/29/2018  Metlife sending duplicate dependent
     Prachi R             1.5      02/20/2018  Metlife Format changes
     C.Chan               1.6      09/13/2018  INC4117114 - Fix for MetLife Vendor Interface file called TeleTech US Benefits 3Plan MetLife Set has the critical illness codes backwards
                                                Position 522-525
                                                Code for Basic Critical Illness (low plan) should be 0001 = 15K;
                                                Code for Enhanced Critical Illness (high Plan) should be 0003 = 30K
	IXPRAVEEN(ARGANO)		1.0		11-May-2023 R12.2 Upgrade Remediation											
  *== END ==================================================================================================*/
  FUNCTION get_plan_id (
    p_person_id                  NUMBER
   ,p_pl_name                    VARCHAR2
   ,p_pl_for                     VARCHAR2
   ,p_actual_termination_date    DATE
  )
    RETURN NUMBER
  AS
    v_pl_id    NUMBER;
  BEGIN
    v_pl_id   := 0;

    IF     p_pl_name = 'MLAW'
       AND p_pl_for = 'E'
    THEN
      SELECT DISTINCT pl_id
                 INTO v_pl_id
                 FROM (SELECT DISTINCT bper.pl_id
                                  --START R12.2 Upgrade Remediation
								  /*FROM ben.ben_prtt_enrt_rslt_f bper				-- Commented code by IXPRAVEEN-ARGANO,11-May-2023
                                      ,ben.ben_ler_f ler                            
                                      ,ben.ben_per_in_ler pil*/
								  FROM apps.ben_prtt_enrt_rslt_f bper				--  code Added by IXPRAVEEN-ARGANO,   11-May-2023
                                      ,apps.ben_ler_f ler
                                      ,apps.ben_per_in_ler pil	
										--END R12.2.11 Upgrade remediation
                                 WHERE bper.person_id = p_person_id
                                   AND bper.business_group_id = 325
                                   AND pil.ler_id = ler.ler_id
                                   AND bper.per_in_ler_id = pil.per_in_ler_id
                                   AND p_actual_termination_date BETWEEN bper.enrt_cvg_strt_dt AND bper.enrt_cvg_thru_dt
                                   AND bper.sspndd_flag = 'N'
                                   AND bper.pl_id IN (7875)
                                   AND bper.prtt_enrt_rslt_stat_cd IS NULL
                                   AND p_actual_termination_date BETWEEN bper.effective_start_date AND bper.effective_end_date
                                   AND p_actual_termination_date BETWEEN ler.effective_start_date AND ler.effective_end_date
                                   AND ler.effective_end_date = '31-DEC-4712'
                       UNION
                       SELECT DISTINCT bper.pl_id
                                 --START R12.2 Upgrade Remediatio
								 /* FROM ben.ben_ler_f ler							-- Commented code by IXPRAVEEN-ARGANO,11-May-2023
                                      ,ben.ben_per_in_ler pil                      
                                      ,ben.ben_prtt_enrt_rslt_f bper*/
								  FROM apps.ben_ler_f ler							 --  code Added by IXPRAVEEN-ARGANO,   11-May-2023
                                      ,apps.ben_per_in_ler pil
                                      ,apps.ben_prtt_enrt_rslt_f bper
										--END R12.2.11 Upgrade remediation
                                 WHERE bper.person_id = p_person_id
                                   AND bper.business_group_id = 325
                                   AND pil.ler_id = ler.ler_id
                                   AND bper.per_in_ler_id = pil.per_in_ler_id
                                   AND bper.enrt_cvg_strt_dt = (SELECT MAX (enrt_cvg_strt_dt)
                                                                  FROM ben_prtt_enrt_rslt_f
                                                                 WHERE person_id = bper.person_id
                                                                   AND pl_id IN (7875)
                                                                   AND prtt_enrt_rslt_stat_cd IS NULL
                                                                   AND sspndd_flag = 'N')
                                   AND bper.sspndd_flag = 'N'
                                   AND bper.pl_id IN (7875)
                                   AND p_actual_termination_date BETWEEN bper.enrt_cvg_strt_dt AND bper.enrt_cvg_thru_dt
                                   AND bper.prtt_enrt_rslt_stat_cd IS NULL
                                   AND p_actual_termination_date BETWEEN bper.effective_start_date AND bper.effective_end_date
                                   AND p_actual_termination_date BETWEEN ler.effective_start_date AND ler.effective_end_date
                                   AND ler.effective_end_date = '31-DEC-4712') qry
                WHERE pl_id IS NOT NULL;
    ELSIF     p_pl_name = 'CRITICAL'
          AND p_pl_for = 'E'
    THEN
      SELECT DISTINCT pl_id
                 INTO v_pl_id
                 FROM (SELECT DISTINCT bper.pl_id                            
										--START R12.2 Upgrade Remediation
								  /*FROM ben.ben_prtt_enrt_rslt_f bper				-- Commented code by IXPRAVEEN-ARGANO,11-May-2023
                                      ,ben.ben_ler_f ler                            
                                      ,ben.ben_per_in_ler pil*/
								  FROM apps.ben_prtt_enrt_rslt_f bper				--  code Added by IXPRAVEEN-ARGANO,   11-May-2023
                                      ,apps.ben_ler_f ler
                                      ,apps.ben_per_in_ler pil	
										--END R12.2.11 Upgrade remediation
                                 WHERE bper.person_id = p_person_id
                                   AND bper.business_group_id = 325
                                   AND pil.ler_id = ler.ler_id
                                   AND bper.per_in_ler_id = pil.per_in_ler_id
                                   AND p_actual_termination_date BETWEEN bper.enrt_cvg_strt_dt AND bper.enrt_cvg_thru_dt
                                   AND bper.sspndd_flag = 'N'
                                   AND bper.pl_id IN (7873, 7874)
                                   AND bper.prtt_enrt_rslt_stat_cd IS NULL
                                   AND p_actual_termination_date BETWEEN bper.effective_start_date AND bper.effective_end_date
                                   AND p_actual_termination_date BETWEEN ler.effective_start_date AND ler.effective_end_date
                                   AND ler.effective_end_date = '31-DEC-4712'
                       UNION
                       SELECT DISTINCT bper.pl_id
									   --START R12.2 Upgrade Remediatio
								 /* FROM ben.ben_ler_f ler							-- Commented code by IXPRAVEEN-ARGANO,11-May-2023
                                      ,ben.ben_per_in_ler pil                      
                                      ,ben.ben_prtt_enrt_rslt_f bper*/
								  FROM apps.ben_ler_f ler							 --  code Added by IXPRAVEEN-ARGANO,   11-May-2023
                                      ,apps.ben_per_in_ler pil
                                      ,apps.ben_prtt_enrt_rslt_f bper
										--END R12.2.11 Upgrade remediation
                                 WHERE bper.person_id = p_person_id
                                   AND bper.business_group_id = 325
                                   AND pil.ler_id = ler.ler_id
                                   AND bper.per_in_ler_id = pil.per_in_ler_id
                                   AND bper.enrt_cvg_strt_dt = (SELECT MAX (enrt_cvg_strt_dt)
                                                                  FROM ben_prtt_enrt_rslt_f
                                                                 WHERE person_id = bper.person_id
                                                                   AND pl_id IN (7873, 7874)
                                                                   AND prtt_enrt_rslt_stat_cd IS NULL
                                                                   AND sspndd_flag = 'N')
                                   AND bper.sspndd_flag = 'N'
                                   AND bper.pl_id IN (7873, 7874)
                                   AND p_actual_termination_date BETWEEN bper.enrt_cvg_strt_dt AND bper.enrt_cvg_thru_dt
                                   AND bper.prtt_enrt_rslt_stat_cd IS NULL
                                   AND p_actual_termination_date BETWEEN bper.effective_start_date AND bper.effective_end_date
                                   AND p_actual_termination_date BETWEEN ler.effective_start_date AND ler.effective_end_date
                                   AND ler.effective_end_date = '31-DEC-4712') qry
                WHERE pl_id IS NOT NULL;
    ELSIF     p_pl_name = 'CRITICAL'
          AND p_pl_for = 'D'
    THEN
      SELECT DISTINCT pl_id
                 INTO v_pl_id
                 FROM (SELECT DISTINCT bper.pl_id
                                  --START R12.2 Upgrade Remediation
								  /*FROM ben.ben_ler_f ler
                                      ,ben.ben_per_in_ler pil				-- Commented code by IXPRAVEEN-ARGANO,11-May-2023
                                      ,ben.ben_prtt_enrt_rslt_f bper        
                                      ,ben.ben_elig_cvrd_dpnt_f dpnt*/
								  FROM apps.ben_ler_f ler
                                      ,apps.ben_per_in_ler pil					--  code Added by IXPRAVEEN-ARGANO,   11-May-2023
                                      ,apps.ben_prtt_enrt_rslt_f bper
                                      ,apps.ben_elig_cvrd_dpnt_f dpnt	
										--END R12.2.11 Upgrade remediation
                                 WHERE dpnt.dpnt_person_id = p_person_id
                                   AND bper.prtt_enrt_rslt_id = dpnt.prtt_enrt_rslt_id
                                   AND bper.business_group_id = 325
                                   AND pil.ler_id = ler.ler_id
                                   AND bper.per_in_ler_id = pil.per_in_ler_id
                                   AND p_actual_termination_date BETWEEN bper.enrt_cvg_strt_dt AND bper.enrt_cvg_thru_dt
                                   AND p_actual_termination_date BETWEEN dpnt.cvg_strt_dt AND dpnt.cvg_thru_dt
                                   AND bper.per_in_ler_id = dpnt.per_in_ler_id
                                   AND bper.sspndd_flag = 'N'
                                   AND bper.pl_id IN (7873, 7874)
                                   AND bper.prtt_enrt_rslt_stat_cd IS NULL
                                   AND p_actual_termination_date BETWEEN bper.effective_start_date AND bper.effective_end_date
                                   AND p_actual_termination_date BETWEEN dpnt.effective_start_date AND dpnt.effective_end_date
                                   AND p_actual_termination_date BETWEEN ler.effective_start_date AND ler.effective_end_date
                                   AND ler.effective_end_date = '31-DEC-4712'
                       UNION
                       SELECT DISTINCT bper.pl_id
									  --START R12.2 Upgrade Remediation
								  /*FROM ben.ben_ler_f ler
                                      ,ben.ben_per_in_ler pil				-- Commented code by IXPRAVEEN-ARGANO,11-May-2023
                                      ,ben.ben_prtt_enrt_rslt_f bper        
                                      ,ben.ben_elig_cvrd_dpnt_f dpnt*/
								  FROM apps.ben_ler_f ler
                                      ,apps.ben_per_in_ler pil					--  code Added by IXPRAVEEN-ARGANO,   11-May-2023
                                      ,apps.ben_prtt_enrt_rslt_f bper
                                      ,apps.ben_elig_cvrd_dpnt_f dpnt	
										--END R12.2.11 Upgrade remediation
                                 WHERE dpnt.dpnt_person_id = p_person_id
                                   AND bper.prtt_enrt_rslt_id = dpnt.prtt_enrt_rslt_id
                                   AND bper.business_group_id = 325
                                   AND pil.ler_id = ler.ler_id
                                   AND bper.per_in_ler_id = pil.per_in_ler_id
                                   AND bper.sspndd_flag = 'N'
                                   AND dpnt.elig_cvrd_dpnt_id = (SELECT MAX (b.elig_cvrd_dpnt_id)
                                                                   FROM ben_prtt_enrt_rslt_f a
                                                                       --,ben.ben_elig_cvrd_dpnt_f b				-- Commented code by IXPRAVEEN-ARGANO,11-May-2023
                                                                       ,apps.ben_elig_cvrd_dpnt_f b					--  code Added by IXPRAVEEN-ARGANO,   11-May-2023
                                                                  WHERE a.prtt_enrt_rslt_id = b.prtt_enrt_rslt_id
                                                                    AND a.sspndd_flag = 'N'
                                                                    AND a.prtt_enrt_rslt_stat_cd IS NULL
                                                                    AND a.person_id = bper.person_id
                                                                    AND b.dpnt_person_id = dpnt.dpnt_person_id
                                                                    AND a.pl_id = bper.pl_id)
                                   AND bper.pl_id IN (7873, 7874)
                                   AND bper.prtt_enrt_rslt_stat_cd IS NULL
                                   AND p_actual_termination_date BETWEEN bper.enrt_cvg_strt_dt AND bper.enrt_cvg_thru_dt
                                   AND p_actual_termination_date BETWEEN dpnt.cvg_strt_dt AND dpnt.cvg_thru_dt
                                   AND p_actual_termination_date BETWEEN dpnt.effective_start_date AND dpnt.effective_end_date
                                   AND p_actual_termination_date BETWEEN ler.effective_start_date AND ler.effective_end_date
                                   AND ler.effective_end_date = '31-DEC-4712') qry
                WHERE pl_id IS NOT NULL;
    ELSIF     p_pl_name = 'AIG'
          AND p_pl_for = 'E'
    THEN
      SELECT DISTINCT pl_id
                 INTO v_pl_id
                 FROM (SELECT DISTINCT bper.pl_id
                                  --START R12.2 Upgrade Remediation
								  /*FROM ben.ben_prtt_enrt_rslt_f bper				-- Commented code by IXPRAVEEN-ARGANO,11-May-2023
                                      ,ben.ben_ler_f ler                            
                                      ,ben.ben_per_in_ler pil*/
								  FROM apps.ben_prtt_enrt_rslt_f bper				--  code Added by IXPRAVEEN-ARGANO,   11-May-2023
                                      ,apps.ben_ler_f ler
                                      ,apps.ben_per_in_ler pil
										--END R12.2.11 Upgrade remediation
                                 WHERE bper.person_id = p_person_id
                                   AND bper.business_group_id = 325
                                   AND pil.ler_id = ler.ler_id
                                   AND bper.per_in_ler_id = pil.per_in_ler_id
                                   AND p_actual_termination_date BETWEEN bper.enrt_cvg_strt_dt AND bper.enrt_cvg_thru_dt
                                   AND bper.sspndd_flag = 'N'
                                   AND bper.pl_id IN (275, 7871)
                                   AND bper.prtt_enrt_rslt_stat_cd IS NULL
                                   AND p_actual_termination_date BETWEEN bper.effective_start_date AND bper.effective_end_date
                                   AND p_actual_termination_date BETWEEN ler.effective_start_date AND ler.effective_end_date
                                   AND ler.effective_end_date = '31-DEC-4712'
                       UNION
                       SELECT DISTINCT bper.pl_id
                                  --START R12.2 Upgrade Remediation
								  /*FROM ben.ben_ler_f ler								-- Commented code by IXPRAVEEN-ARGANO,11-May-2023
                                      ,ben.ben_per_in_ler pil
                                      ,ben.ben_prtt_enrt_rslt_f bper*/
								  FROM apps.ben_ler_f ler								--  code Added by IXPRAVEEN-ARGANO,   11-May-2023
                                      ,apps.ben_per_in_ler pil
                                      ,apps.ben_prtt_enrt_rslt_f bper
										--END R12.2.11 Upgrade remediation
                                 WHERE bper.person_id = p_person_id
                                   AND bper.business_group_id = 325
                                   AND pil.ler_id = ler.ler_id
                                   AND bper.per_in_ler_id = pil.per_in_ler_id
                                   AND bper.enrt_cvg_strt_dt = (SELECT MAX (enrt_cvg_strt_dt)
                                                                  FROM ben_prtt_enrt_rslt_f
                                                                 WHERE person_id = bper.person_id
                                                                   AND pl_id IN (275, 7871)
                                                                   AND prtt_enrt_rslt_stat_cd IS NULL
                                                                   AND sspndd_flag = 'N')
                                   AND bper.sspndd_flag = 'N'
                                   AND bper.pl_id IN (275, 7871)
                                   AND bper.prtt_enrt_rslt_stat_cd IS NULL
                                   AND p_actual_termination_date BETWEEN bper.enrt_cvg_strt_dt AND bper.enrt_cvg_thru_dt
                                   AND p_actual_termination_date BETWEEN bper.effective_start_date AND bper.effective_end_date
                                   AND p_actual_termination_date BETWEEN ler.effective_start_date AND ler.effective_end_date
                                   AND ler.effective_end_date = '31-DEC-4712') qry
                WHERE pl_id IS NOT NULL;
    ELSIF     p_pl_name = 'AIG'
          AND p_pl_for = 'D'
    THEN
      SELECT DISTINCT pl_id
                 INTO v_pl_id
                 FROM (SELECT DISTINCT bper.pl_id
                                  --START R12.2 Upgrade Remediation
								  /*FROM ben.ben_ler_f ler						-- Commented code by IXPRAVEEN-ARGANO,11-May-2023
                                      ,ben.ben_per_in_ler pil                   
                                      ,ben.ben_prtt_enrt_rslt_f bper
                                      ,ben.ben_elig_cvrd_dpnt_f dpnt*/
								  FROM apps.ben_ler_f ler						--  code Added by IXPRAVEEN-ARGANO,   11-May-2023
                                      ,apps.ben_per_in_ler pil
                                      ,apps.ben_prtt_enrt_rslt_f bper
                                      ,apps.ben_elig_cvrd_dpnt_f dpnt
									--END R12.2.11 Upgrade remediation									  
                                 WHERE dpnt.dpnt_person_id = p_person_id								 
                                   AND bper.prtt_enrt_rslt_id = dpnt.prtt_enrt_rslt_id
                                   AND bper.business_group_id = 325
                                   AND pil.ler_id = ler.ler_id
                                   AND bper.per_in_ler_id = pil.per_in_ler_id
                                   AND p_actual_termination_date BETWEEN bper.enrt_cvg_strt_dt AND bper.enrt_cvg_thru_dt
                                   AND p_actual_termination_date BETWEEN dpnt.cvg_strt_dt AND dpnt.cvg_thru_dt
                                   AND bper.per_in_ler_id = dpnt.per_in_ler_id
                                   AND bper.sspndd_flag = 'N'
                                   AND bper.pl_id IN (275, 7871)
                                   AND bper.prtt_enrt_rslt_stat_cd IS NULL
                                   AND p_actual_termination_date BETWEEN bper.effective_start_date AND bper.effective_end_date
                                   AND p_actual_termination_date BETWEEN dpnt.effective_start_date AND dpnt.effective_end_date
                                   AND p_actual_termination_date BETWEEN ler.effective_start_date AND ler.effective_end_date
                                   AND ler.effective_end_date = '31-DEC-4712'
                       UNION
                       SELECT DISTINCT bper.pl_id
									   --START R12.2 Upgrade Remediation
								  /*FROM ben.ben_ler_f ler						-- Commented code by IXPRAVEEN-ARGANO,11-May-2023
                                      ,ben.ben_per_in_ler pil                   
                                      ,ben.ben_prtt_enrt_rslt_f bper
                                      ,ben.ben_elig_cvrd_dpnt_f dpnt*/
								  FROM apps.ben_ler_f ler						--  code Added by IXPRAVEEN-ARGANO,   11-May-2023
                                      ,apps.ben_per_in_ler pil
                                      ,apps.ben_prtt_enrt_rslt_f bper
                                      ,apps.ben_elig_cvrd_dpnt_f dpnt
									--END R12.2.11 Upgrade remediation	
                                 WHERE dpnt.dpnt_person_id = p_person_id
                                   AND bper.prtt_enrt_rslt_id = dpnt.prtt_enrt_rslt_id
                                   AND bper.business_group_id = 325
                                   AND pil.ler_id = ler.ler_id
                                   AND bper.per_in_ler_id = pil.per_in_ler_id
                                   AND bper.sspndd_flag = 'N'
                                   AND dpnt.elig_cvrd_dpnt_id = (SELECT MAX (b.elig_cvrd_dpnt_id)
                                                                   FROM ben_prtt_enrt_rslt_f a
                                                                       --,ben.ben_elig_cvrd_dpnt_f b			-- Commented code by IXPRAVEEN-ARGANO,11-May-2023
                                                                       ,apps.ben_elig_cvrd_dpnt_f b             --  code Added by IXPRAVEEN-ARGANO,   11-May-2023
                                                                  WHERE a.prtt_enrt_rslt_id = b.prtt_enrt_rslt_id
                                                                    AND a.sspndd_flag = 'N'
                                                                    AND a.prtt_enrt_rslt_stat_cd IS NULL
                                                                    AND a.person_id = bper.person_id
                                                                    AND b.dpnt_person_id = dpnt.dpnt_person_id
                                                                    AND a.pl_id = bper.pl_id)
                                   AND bper.pl_id IN (275, 7871)
                                   AND p_actual_termination_date BETWEEN bper.enrt_cvg_strt_dt AND bper.enrt_cvg_thru_dt
                                   AND p_actual_termination_date BETWEEN dpnt.cvg_strt_dt AND dpnt.cvg_thru_dt
                                   AND bper.prtt_enrt_rslt_stat_cd IS NULL
                                   AND p_actual_termination_date BETWEEN dpnt.effective_start_date AND dpnt.effective_end_date
                                   AND p_actual_termination_date BETWEEN ler.effective_start_date AND ler.effective_end_date
                                   AND ler.effective_end_date = '31-DEC-4712') qry
                WHERE pl_id IS NOT NULL;
    --Added for metlife changes 2018 1.3 hospital indemnity plan---------------
    ELSIF     p_pl_name = 'HOSPITAL'
          AND p_pl_for = 'E'
    THEN
      SELECT DISTINCT pl_id
                 INTO v_pl_id
                 FROM (SELECT DISTINCT bper.pl_id
						--START R12.2 Upgrade Remediation							-- Commented code by IXPRAVEEN-ARGANO,11-May-2023
                                  /*FROM ben.ben_prtt_enrt_rslt_f bper              
                                      ,ben.ben_ler_f ler
                                      ,ben.ben_per_in_ler pil*/
								  FROM apps.ben_prtt_enrt_rslt_f bper				--  code Added by IXPRAVEEN-ARGANO,   11-May-2023
                                      ,apps.ben_ler_f ler
                                      ,apps.ben_per_in_ler pil
						--END R12.2.11 Upgrade remediation									  
                                 WHERE bper.person_id = p_person_id
                                   AND bper.business_group_id = 325
                                   AND pil.ler_id = ler.ler_id
                                   AND bper.per_in_ler_id = pil.per_in_ler_id
                                   AND p_actual_termination_date BETWEEN bper.enrt_cvg_strt_dt AND bper.enrt_cvg_thru_dt
                                   AND bper.sspndd_flag = 'N'
                                   AND bper.pl_id IN (17871, 17872)
                                   AND bper.prtt_enrt_rslt_stat_cd IS NULL
                                   AND p_actual_termination_date BETWEEN bper.effective_start_date AND bper.effective_end_date
                                   AND p_actual_termination_date BETWEEN ler.effective_start_date AND ler.effective_end_date
                                   AND ler.effective_end_date = '31-DEC-4712'
                       UNION
                       SELECT DISTINCT bper.pl_id
					   --START R12.2 Upgrade Remediation
                                  /*FROM ben.ben_ler_f ler						-- Commented code by IXPRAVEEN-ARGANO,11-May-2023
                                      ,ben.ben_per_in_ler pil
                                      ,ben.ben_prtt_enrt_rslt_f bper*/
								  FROM apps.ben_ler_f ler						--  code Added by IXPRAVEEN-ARGANO,   11-May-2023
                                      ,apps.ben_per_in_ler pil
                                      ,apps.ben_prtt_enrt_rslt_f bper
						--END R12.2.11 Upgrade remediation			  
                                 WHERE bper.person_id = p_person_id
                                   AND bper.business_group_id = 325
                                   AND pil.ler_id = ler.ler_id
                                   AND bper.per_in_ler_id = pil.per_in_ler_id
                                   AND bper.enrt_cvg_strt_dt = (SELECT MAX (enrt_cvg_strt_dt)
                                                                  FROM ben_prtt_enrt_rslt_f
                                                                 WHERE person_id = bper.person_id
                                                                   AND pl_id IN (17871, 17872)
                                                                   AND prtt_enrt_rslt_stat_cd IS NULL
                                                                   AND sspndd_flag = 'N')
                                   AND bper.sspndd_flag = 'N'
                                   AND bper.pl_id IN (17871, 17872)
                                   AND bper.prtt_enrt_rslt_stat_cd IS NULL
                                   AND p_actual_termination_date BETWEEN bper.enrt_cvg_strt_dt AND bper.enrt_cvg_thru_dt
                                   AND p_actual_termination_date BETWEEN bper.effective_start_date AND bper.effective_end_date
                                   AND p_actual_termination_date BETWEEN ler.effective_start_date AND ler.effective_end_date
                                   AND ler.effective_end_date = '31-DEC-4712') qry
                WHERE pl_id IS NOT NULL;
    ELSIF     p_pl_name = 'HOSPITAL'
          AND p_pl_for = 'D'
    THEN
      SELECT DISTINCT pl_id
                 INTO v_pl_id
                 FROM (SELECT DISTINCT bper.pl_id
                                  --START R12.2 Upgrade Remediation
								  /*FROM ben.ben_ler_f ler						-- Commented code by IXPRAVEEN-ARGANO,11-May-2023
                                      ,ben.ben_per_in_ler pil                   
                                      ,ben.ben_prtt_enrt_rslt_f bper
                                      ,ben.ben_elig_cvrd_dpnt_f dpnt*/
								  FROM apps.ben_ler_f ler						--  code Added by IXPRAVEEN-ARGANO,   11-May-2023
                                      ,apps.ben_per_in_ler pil
                                      ,apps.ben_prtt_enrt_rslt_f bper
                                      ,apps.ben_elig_cvrd_dpnt_f dpnt
										--END R12.2.11 Upgrade remediation
                                 WHERE dpnt.dpnt_person_id = p_person_id
                                   AND bper.prtt_enrt_rslt_id = dpnt.prtt_enrt_rslt_id
                                   AND bper.business_group_id = 325
                                   AND pil.ler_id = ler.ler_id
                                   AND bper.per_in_ler_id = pil.per_in_ler_id
                                   AND p_actual_termination_date BETWEEN bper.enrt_cvg_strt_dt AND bper.enrt_cvg_thru_dt
                                   AND p_actual_termination_date BETWEEN dpnt.cvg_strt_dt AND dpnt.cvg_thru_dt
                                   AND bper.per_in_ler_id = dpnt.per_in_ler_id
                                   AND bper.sspndd_flag = 'N'
                                   AND bper.pl_id IN (17871, 17872)
                                   AND bper.prtt_enrt_rslt_stat_cd IS NULL
                                   AND p_actual_termination_date BETWEEN bper.effective_start_date AND bper.effective_end_date
                                   AND p_actual_termination_date BETWEEN dpnt.effective_start_date AND dpnt.effective_end_date
                                   AND p_actual_termination_date BETWEEN ler.effective_start_date AND ler.effective_end_date
                                   AND ler.effective_end_date = '31-DEC-4712'
                       UNION
                       SELECT DISTINCT bper.pl_id
                                  --START R12.2 Upgrade Remediation
								  /*FROM ben.ben_ler_f ler						-- Commented code by IXPRAVEEN-ARGANO,11-May-2023
                                      ,ben.ben_per_in_ler pil                   
                                      ,ben.ben_prtt_enrt_rslt_f bper
                                      ,ben.ben_elig_cvrd_dpnt_f dpnt*/
								  FROM apps.ben_ler_f ler						--  code Added by IXPRAVEEN-ARGANO,   11-May-2023
                                      ,apps.ben_per_in_ler pil
                                      ,apps.ben_prtt_enrt_rslt_f bper
                                      ,apps.ben_elig_cvrd_dpnt_f dpnt
										--END R12.2.11 Upgrade remediation
                                 WHERE dpnt.dpnt_person_id = p_person_id
                                   AND bper.prtt_enrt_rslt_id = dpnt.prtt_enrt_rslt_id
                                   AND bper.business_group_id = 325
                                   AND pil.ler_id = ler.ler_id
                                   AND bper.per_in_ler_id = pil.per_in_ler_id
                                   AND bper.sspndd_flag = 'N'
                                   AND dpnt.elig_cvrd_dpnt_id = (SELECT MAX (b.elig_cvrd_dpnt_id)
                                                                   FROM ben_prtt_enrt_rslt_f a
                                                                       --,ben.ben_elig_cvrd_dpnt_f b		-- Commented code by IXPRAVEEN-ARGANO,11-May-2023
                                                                       ,apps.ben_elig_cvrd_dpnt_f b         --  code Added by IXPRAVEEN-ARGANO,   11-May-2023
                                                                  WHERE a.prtt_enrt_rslt_id = b.prtt_enrt_rslt_id
                                                                    AND a.sspndd_flag = 'N'
                                                                    AND a.prtt_enrt_rslt_stat_cd IS NULL
                                                                    AND a.person_id = bper.person_id
                                                                    AND b.dpnt_person_id = dpnt.dpnt_person_id
                                                                    AND a.pl_id = bper.pl_id)
                                   AND bper.pl_id IN (17871, 17872)
                                   AND p_actual_termination_date BETWEEN bper.enrt_cvg_strt_dt AND bper.enrt_cvg_thru_dt
                                   AND p_actual_termination_date BETWEEN dpnt.cvg_strt_dt AND dpnt.cvg_thru_dt
                                   AND bper.prtt_enrt_rslt_stat_cd IS NULL
                                   AND p_actual_termination_date BETWEEN dpnt.effective_start_date AND dpnt.effective_end_date
                                   AND p_actual_termination_date BETWEEN ler.effective_start_date AND ler.effective_end_date
                                   AND ler.effective_end_date = '31-DEC-4712') qry
                WHERE pl_id IS NOT NULL;
     --Added for metlife --changes 2018 1.3 hospital indemnity plan---------------
    END IF;

    RETURN (v_pl_id);
  EXCEPTION
    WHEN NO_DATA_FOUND
    THEN
      v_pl_id   := 0;
      FND_FILE.PUT_LINE (FND_FILE.LOG, v_pl_id || '-' || p_person_id || '-' || p_pl_name || '-' || p_pl_for);
      RETURN (v_pl_id);
    WHEN OTHERS
    THEN
      v_pl_id   := 0;
      FND_FILE.PUT_LINE (FND_FILE.LOG, v_pl_id || '-' || p_person_id || '-' || p_pl_name || '-' || p_pl_for);
      RETURN (v_pl_id);
  END;

  PROCEDURE main_proc (
    errbuf                OUT       VARCHAR2
   ,retcode               OUT       NUMBER
   ,p_output_directory    IN        VARCHAR2
   ,p_start_date          IN        VARCHAR2
   ,p_end_date            IN        VARCHAR2
  )
  IS
    CURSOR c_emp_rec (
      p_cut_off_date        DATE
     ,p_current_run_date    DATE
    )
    IS
      SELECT   MAX (date_start) date_start
              ,MAX (NVL (actual_termination_date, p_current_run_date)) actual_termination_date
              ,person_id
          FROM per_periods_of_service ppos
         WHERE business_group_id = 325
           AND (   (    TRUNC (ppos.last_update_date) BETWEEN p_cut_off_date AND p_current_run_date
                    AND ppos.actual_termination_date IS NOT NULL)
                OR (    ppos.actual_termination_date IS NULL
                    AND ppos.person_id IN (SELECT DISTINCT person_id
                                                      FROM per_all_people_f papf
                                                     WHERE papf.current_employee_flag = 'Y'))
                OR (    ppos.actual_termination_date = (SELECT MAX (actual_termination_date)
                                                          FROM per_periods_of_service
                                                         WHERE person_id = ppos.person_id
                                                           AND actual_termination_date IS NOT NULL)
                    AND ppos.actual_termination_date >= p_cut_off_date)
               )
      GROUP BY person_id;

    CURSOR c_emp_info (
      p_person_id                  NUMBER
     ,p_actual_termination_date    DATE
    )
    IS
      SELECT DISTINCT papf.person_id
                     ,NULL contact_person_id
                     ,paaf.assignment_id
                     ,papf.employee_number
                     ,DECODE (papf.national_identifier
                             ,'', ''
                             , '00' || papf.national_identifier
                             ) national_identifier
                     ,DECODE (papf.national_identifier
                             ,'', ''
                             , '00' || papf.national_identifier
                             ) member_ssn
                     ,papf.first_name
                     ,papf.last_name
                     ,papf.email_address
                     ,papf.middle_names
                     ,TO_CHAR (papf.date_of_birth, 'MMDDYYYY') dob
                     ,NVL (TRANSLATE (papf.marital_status, 'DP', 'M'), 'U') marital_status
                     ,TO_CHAR (papf.start_date, 'MMDDYYYY') start_date
                     ,papf.sex
                     ,DECODE (INSTR (DECODE (INSTR (TRIM (TRANSLATE (UPPER (pp.phone_number), '+,/,(,),.,=,-,_,#,NA,SAME,NONE,YES,SKYPE,*,\,`,'' ', ' ')), 0)
                                            ,1, ''
                                            ,TRIM (TRANSLATE (UPPER (pp.phone_number), '+,/,(,),.,=,-,_,#,NA,SAME,NONE,YES,SKYPE,*,\,`,'' ', ' '))
                                            )
                                    ,1)
                             ,1, SUBSTRB (TRIM (TRANSLATE (UPPER (pp.phone_number), '+,/,(,),.,=,-,_,#,NA,SAME,NONE,YES,SKYPE,*,\,`,'' ', ' ')), 2, 10)
                             ,'', ''
                             ,TRIM (TRANSLATE (UPPER (pp.phone_number), '+,/,(,),.,=,-,_,#,NA,SAME,NONE,YES,SKYPE,*,\,`,'' ', ' '))
                             ) phone_num
                     ,DECODE (pad.country
                             ,'BR', pad.region_2
                             ,'CA', pad.region_1
                             ,'CR', pad.region_1
                             ,'ES', pad.region_1
                             ,'UK', ''
                             ,'MX', pad.region_1
                             ,'PH', pad.region_1
                             ,'US', pad.region_2
                             ,'NZ', ''
                             ) state
                     ,pad.address_line1
                     ,NVL (pad.address_line2, pad.address_line2) address_line2
                     ,pad.town_or_city
                     ,SUBSTRB (pad.postal_code, 1, 5) postal_code
                     ,
                      --                         TO_CHAR (ppp.last_change_date,
                      --                                  'MMDDYYYY'
                      --                                 ) last_change_date,
                      --                         ppp.proposed_salary_n,
                      --                         UPPER (SUBSTR (ppb.NAME, 1, 1)) pay_bases,
                      past.user_status
                     ,ppt.user_person_type
                     ,ppos.actual_termination_date actual_term_date
                     ,paaf.employment_category
                     ,'E' per_type
                     ,'E' contact_type
                     ,papf.registered_disabled_flag
                 FROM apps.per_all_people_f papf
                     ,apps.per_all_assignments_f paaf
                     ,apps.per_periods_of_service ppos
                     ,apps.per_person_type_usages_f pptuf
                     ,apps.per_person_types ppt
                     ,apps.per_addresses pad
                     ,apps.per_phones pp
                     ,
                      --                         apps.per_pay_proposals ppp,
                      --                         apps.per_pay_bases ppb,
                      apps.per_assignment_status_types past
                WHERE papf.person_id = paaf.person_id
                  AND paaf.person_id = ppos.person_id
                  AND pptuf.person_id = papf.person_id
                  AND papf.person_id = pad.person_id(+)
                  AND ppt.person_type_id = pptuf.person_type_id
                  AND UPPER (ppt.system_person_type) = 'EMP'
                  AND ppos.period_of_service_id = paaf.period_of_service_id
                  AND paaf.primary_flag = 'Y'
                  AND papf.business_group_id <> 0
                  AND papf.business_group_id = 325
                  --AND paaf.location_id NOT IN (131337, 134268) /* 1.1 */
                  AND past.user_status NOT IN ('Detail NTE', 'End', 'TTEC Awaiting integration')
                  AND papf.current_employee_flag = 'Y'
                  AND pad.primary_flag(+) = 'Y'
                  AND papf.person_id = pp.parent_id(+)
                  AND pp.phone_type(+) = 'H1'
                  --                     AND paaf.pay_basis_id = ppb.pay_basis_id
                  --                     AND paaf.assignment_id = ppp.assignment_id
                  AND paaf.assignment_status_type_id = past.assignment_status_type_id
                  AND papf.person_id = p_person_id
                  --                     AND ppp.approved = 'Y'
                  AND past.active_flag = 'Y'
                  --                     AND p_actual_termination_date BETWEEN ppp.change_date
                  --                                                       AND NVL
                  --                                                             (ppp.date_to,
                  --                                                              p_actual_termination_date
                  --                                                             )
                  AND p_actual_termination_date BETWEEN pp.date_from(+) AND NVL (pp.date_to(+), p_actual_termination_date)
                  AND p_actual_termination_date BETWEEN pptuf.effective_start_date AND pptuf.effective_end_date
                  AND p_actual_termination_date BETWEEN papf.effective_start_date AND papf.effective_end_date
                  AND p_actual_termination_date BETWEEN paaf.effective_start_date AND paaf.effective_end_date
                  AND p_actual_termination_date BETWEEN pad.date_from(+) AND NVL (pad.date_to(+), p_actual_termination_date)
                  AND p_actual_termination_date BETWEEN ppos.date_start AND NVL (ppos.actual_termination_date, p_actual_termination_date)
      UNION
      SELECT DISTINCT papf.person_id
                     ,pcr.contact_person_id
                     ,paaf.assignment_id
                     ,NULL employee_number
                     ,DECODE (papf.national_identifier
                             ,'', ''
                             , '00' || papf.national_identifier
                             ) national_identifier
                     ,DECODE (papfc.national_identifier
                             ,'', ''
                             , '00' || papfc.national_identifier
                             ) member_ssn
                     ,papfc.first_name
                     ,papfc.last_name
                     ,papf.email_address
                     ,papfc.middle_names
                     ,TO_CHAR (papfc.date_of_birth, 'MMDDYYYY') dob
                     ,NVL (TRANSLATE (papf.marital_status, 'DP', 'M'), 'U') marital_status
                     ,NULL start_date
                     ,papfc.sex
                     ,NULL phone_num
                     ,NULL state
                     ,NULL address_line1
                     ,NULL address_line2
                     ,NULL town_or_city
                     ,NULL postal_code
                     ,
                      --                         TO_CHAR (ppp.last_change_date,
                      --                                  'MMDDYYYY'
                      --                                 ) last_change_date,
                      --                         ppp.proposed_salary_n,
                      --                         UPPER (SUBSTR (ppb.NAME, 1, 1)) pay_bases,
                      NULL user_status
                     ,ppt.user_person_type
                     ,ppos.actual_termination_date actual_term_date
                     ,paaf.employment_category
                     ,'D' per_type
                     ,pcr.contact_type
                     ,papfc.registered_disabled_flag
                 FROM apps.per_all_people_f papf
                     ,apps.per_all_assignments_f paaf
                     ,apps.per_periods_of_service ppos
                     ,apps.per_person_type_usages_f pptuf
                     ,apps.per_person_types ppt
                     ,apps.per_addresses pad
                     ,apps.per_phones pp
                     ,
                      --                         apps.per_pay_proposals ppp,
                      --                         apps.per_pay_bases ppb,
                      apps.per_assignment_status_types past
                     ,apps.per_contact_relationships pcr
                     ,apps.per_all_people_f papfc
                WHERE papf.person_id = paaf.person_id
                  AND paaf.person_id = ppos.person_id
                  AND pptuf.person_id = papf.person_id
                  AND papf.person_id = pad.person_id(+)
                  AND ppt.person_type_id = pptuf.person_type_id
                  AND UPPER (ppt.system_person_type) = 'EMP'
                  AND ppos.period_of_service_id = paaf.period_of_service_id
                  AND paaf.primary_flag = 'Y'
                  AND papf.business_group_id <> 0
                  AND papf.business_group_id = 325
                  AND paaf.location_id NOT IN (131337, 134268)
                  AND past.user_status NOT IN ('Detail NTE', 'End', 'TTEC Awaiting integration')
                  AND papf.current_employee_flag = 'Y'
                  AND pad.primary_flag(+) = 'Y'
                  AND papf.person_id = pp.parent_id(+)
                  AND pp.phone_type(+) = 'H1'
                  --                     AND paaf.pay_basis_id = ppb.pay_basis_id
                  --                     AND paaf.assignment_id = ppp.assignment_id
                  AND paaf.assignment_status_type_id = past.assignment_status_type_id
                  AND papf.person_id = p_person_id
                  --                     AND ppp.approved = 'Y'
                  AND past.active_flag = 'Y'
                  --                     AND p_actual_termination_date BETWEEN ppp.change_date
                  --                                                       AND NVL
                  --                                                             (ppp.date_to,
                  --                                                              p_actual_termination_date
                  --                                                             )
                  AND p_actual_termination_date BETWEEN pp.date_from(+) AND NVL (pp.date_to(+), p_actual_termination_date)
                  AND p_actual_termination_date BETWEEN pptuf.effective_start_date AND pptuf.effective_end_date
                  AND p_actual_termination_date BETWEEN papf.effective_start_date AND papf.effective_end_date
                  AND p_actual_termination_date BETWEEN paaf.effective_start_date AND paaf.effective_end_date
                  AND p_actual_termination_date BETWEEN pad.date_from(+) AND NVL (pad.date_to(+), p_actual_termination_date)
                  AND p_actual_termination_date BETWEEN ppos.date_start AND NVL (ppos.actual_termination_date, p_actual_termination_date)
                  AND p_actual_termination_date BETWEEN pcr.date_start(+) AND NVL(pcr.date_end(+),p_actual_termination_date)/*Change 1.4*/
                  AND pcr.person_id = papf.person_id
                  AND pcr.contact_person_id = papfc.person_id
                  AND pcr.contact_type IN ('R', 'A', 'S', 'C', 'D', 'O', 'T', 'LW')
                  AND pcr.date_start = (SELECT MAX (date_start)
                                          FROM per_contact_relationships
                                         WHERE contact_person_id = pcr.contact_person_id
                                           AND contact_type IN ('R', 'A', 'S', 'C', 'D', 'O', 'T', 'LW')
                                           AND person_id = papf.person_id)
                  AND p_actual_termination_date BETWEEN papfc.effective_start_date AND papfc.effective_end_date
             ORDER BY 1
                     ,4;

    CURSOR c_bnft_info (
      p_person_id                  IN    NUMBER
     ,p_pl_id                      IN    NUMBER
     ,p_per_type                   IN    VARCHAR2
     ,p_actual_termination_date    IN    DATE
    )
    IS
      SELECT DISTINCT pl_id
                     ,orgnl_enrt_dt
                     ,TO_DATE (enrt_cvg_thru_dt) enrt_cvg_thru_dt
                     ,enrt_cvg_strt_dt
                     ,bnft_amt
                     ,opt_type
                 FROM (SELECT bper.pl_id
                             ,bper.orgnl_enrt_dt
                             ,DECODE (TO_CHAR (bper.enrt_cvg_thru_dt, 'YYYY')
                                     ,'4712', ''
                                     ,bper.enrt_cvg_thru_dt
                                     ) enrt_cvg_thru_dt
                             ,bper.enrt_cvg_strt_dt
                             ,bper.bnft_amt
                             ,DECODE (bo.opt_attribute1
                                     ,'EMP', '1'
                                     ,'ESP', '3'
                                     ,'ECH', '2'
                                     ,'FAM', '4'
                                     ) opt_type
                         --START R12.2 Upgrade Remediation
						 /*FROM ben.ben_ler_f ler				-- Commented code by IXPRAVEEN-ARGANO,11-May-2023
                             ,ben.ben_per_in_ler pil            
                             ,ben.ben_prtt_enrt_rslt_f bper
                             ,ben.ben_oipl_f boif
                             ,ben.ben_opt_f bo*/
						 FROM apps.ben_ler_f ler				--  code Added by IXPRAVEEN-ARGANO,   11-May-2023
                             ,apps.ben_per_in_ler pil
                             ,apps.ben_prtt_enrt_rslt_f bper
                             ,apps.ben_oipl_f boif
                             ,apps.ben_opt_f bo	
								--END R12.2.11 Upgrade remediatio
                        WHERE bper.person_id = p_person_id
                          AND pil.ler_id = ler.ler_id
                          AND pil.business_group_id = 325
                          AND bper.per_in_ler_id = pil.per_in_ler_id
                          AND p_actual_termination_date BETWEEN bper.enrt_cvg_strt_dt AND bper.enrt_cvg_thru_dt
                          AND bper.sspndd_flag = 'N'
                          AND bper.pl_id IN (p_pl_id)
                          AND 'E' = p_per_type
                          AND bper.prtt_enrt_rslt_stat_cd IS NULL
                          AND bper.oipl_id = boif.oipl_id(+)
                          AND boif.opt_id = bo.opt_id(+)
                          AND p_actual_termination_date BETWEEN bo.effective_start_date(+) AND bo.effective_end_date(+)
                          AND p_actual_termination_date BETWEEN boif.effective_start_date(+) AND boif.effective_end_date(+)
                          AND p_actual_termination_date BETWEEN bper.effective_start_date AND bper.effective_end_date
                          AND p_actual_termination_date BETWEEN ler.effective_start_date AND ler.effective_end_date
                          AND ler.effective_end_date = '31-DEC-4712'
                       UNION
                       SELECT bper.pl_id
                             ,bper.orgnl_enrt_dt
                             ,DECODE (TO_CHAR (dpnt.cvg_thru_dt, 'YYYY')
                                     ,'4712', ''
                                     ,dpnt.cvg_thru_dt
                                     ) enrt_cvg_thru_dt
                             ,dpnt.cvg_strt_dt enrt_cvg_strt_dt
                             ,bper.bnft_amt
                             ,DECODE (bo.opt_attribute1
                                     ,'EMP', '1'
                                     ,'ESP', '3'
                                     ,'ECH', '2'
                                     ,'FAM', '4'
                                     ) opt_type
                         --START R12.2 Upgrade Remediation
						 /*FROM ben.ben_ler_f ler						-- Commented code by IXPRAVEEN-ARGANO,11-May-2023
                             ,ben.ben_per_in_ler pil                    
                             ,ben.ben_prtt_enrt_rslt_f bper
                             ,ben.ben_elig_cvrd_dpnt_f dpnt
                             ,ben.ben_oipl_f boif
                             ,ben.ben_opt_f bo*/
						 FROM apps.ben_ler_f ler						--  code Added by IXPRAVEEN-ARGANO,   11-May-2023
                             ,apps.ben_per_in_ler pil
                             ,apps.ben_prtt_enrt_rslt_f bper
                             ,apps.ben_elig_cvrd_dpnt_f dpnt
                             ,apps.ben_oipl_f boif
                             ,apps.ben_opt_f bo	 
						 --END R12.2.11 Upgrade remediation
                        WHERE dpnt.dpnt_person_id = p_person_id
                          AND pil.ler_id = ler.ler_id
                          AND pil.business_group_id = 325
                          AND bper.per_in_ler_id = pil.per_in_ler_id
                          AND bper.prtt_enrt_rslt_id = dpnt.prtt_enrt_rslt_id
                          AND p_actual_termination_date BETWEEN bper.enrt_cvg_strt_dt AND bper.enrt_cvg_thru_dt
                          AND p_actual_termination_date BETWEEN dpnt.cvg_strt_dt AND dpnt.cvg_thru_dt
                          AND bper.per_in_ler_id = dpnt.per_in_ler_id
                          AND bper.sspndd_flag = 'N'
                          AND bper.pl_id IN (p_pl_id)
                          AND 'D' = p_per_type
                          AND bper.prtt_enrt_rslt_stat_cd IS NULL
                          AND bper.oipl_id = boif.oipl_id(+)
                          AND boif.opt_id = bo.opt_id(+)
                          AND p_actual_termination_date BETWEEN bo.effective_start_date AND bo.effective_end_date
                          AND p_actual_termination_date BETWEEN boif.effective_start_date(+) AND boif.effective_end_date(+)
                          AND p_actual_termination_date BETWEEN bper.effective_start_date AND bper.effective_end_date
                          AND p_actual_termination_date BETWEEN dpnt.effective_start_date(+) AND dpnt.effective_end_date(+)
                          AND p_actual_termination_date BETWEEN ler.effective_start_date AND ler.effective_end_date
                          AND ler.effective_end_date = '31-DEC-4712'
                       UNION
                       SELECT bper.pl_id
                             ,bper.orgnl_enrt_dt
                             ,DECODE (TO_CHAR (bper.enrt_cvg_thru_dt, 'YYYY')
                                     ,'4712', ''
                                     ,bper.enrt_cvg_thru_dt
                                     ) enrt_cvg_thru_dt
                             ,bper.enrt_cvg_strt_dt
                             ,bper.bnft_amt
                             ,DECODE (bo.opt_attribute1
                                     ,'EMP', '1'
                                     ,'ESP', '3'
                                     ,'ECH', '2'
                                     ,'FAM', '4'
                                     ) opt_type                        
						  --START R12.2 Upgrade Remediation
						 /*FROM ben.ben_ler_f ler				-- Commented code by IXPRAVEEN-ARGANO,11-May-2023
                             ,ben.ben_per_in_ler pil            
                             ,ben.ben_prtt_enrt_rslt_f bper
                             ,ben.ben_oipl_f boif
                             ,ben.ben_opt_f bo*/
						 FROM apps.ben_ler_f ler				--  code Added by IXPRAVEEN-ARGANO,   11-May-2023
                             ,apps.ben_per_in_ler pil
                             ,apps.ben_prtt_enrt_rslt_f bper
                             ,apps.ben_oipl_f boif
                             ,apps.ben_opt_f bo	
								--END R12.2.11 Upgrade remediatio	 
                        WHERE bper.person_id = p_person_id
                          AND pil.ler_id = ler.ler_id
                          AND pil.business_group_id = 325
                          AND bper.per_in_ler_id = pil.per_in_ler_id
                          AND bper.sspndd_flag = 'N'
                          AND 'E' = p_per_type
                          AND bper.pl_id IN (p_pl_id)
                          AND bper.prtt_enrt_rslt_stat_cd IS NULL
                          AND bper.enrt_cvg_strt_dt = (SELECT MAX (enrt_cvg_strt_dt)
                                                         FROM ben_prtt_enrt_rslt_f
                                                        WHERE person_id = bper.person_id
                                                          AND pl_id IN (p_pl_id)
                                                          AND prtt_enrt_rslt_stat_cd IS NULL
                                                          AND sspndd_flag = 'N')
                          AND bper.oipl_id = boif.oipl_id(+)
                          AND boif.opt_id = bo.opt_id(+)
                          AND p_actual_termination_date BETWEEN bper.effective_start_date AND bper.effective_end_date
                          AND p_actual_termination_date BETWEEN bper.enrt_cvg_strt_dt AND bper.enrt_cvg_thru_dt
                          AND p_actual_termination_date BETWEEN bo.effective_start_date(+) AND bo.effective_end_date(+)
                          AND p_actual_termination_date BETWEEN boif.effective_start_date(+) AND boif.effective_end_date(+)
                          AND p_actual_termination_date BETWEEN ler.effective_start_date AND ler.effective_end_date
                          AND ler.effective_end_date = '31-DEC-4712'
                       UNION
                       SELECT bper.pl_id
                             ,bper.orgnl_enrt_dt
                             ,DECODE (TO_CHAR (dpnt.cvg_thru_dt, 'YYYY')
                                     ,'4712', ''
                                     ,dpnt.cvg_thru_dt
                                     ) enrt_cvg_thru_dt
                             ,dpnt.cvg_strt_dt enrt_cvg_strt_dt
                             ,bper.bnft_amt
                             ,DECODE (bo.opt_attribute1
                                     ,'EMP', '1'
                                     ,'ESP', '3'
                                     ,'ECH', '2'
                                     ,'FAM', '4'
                                     ) opt_type                       
						 --START R12.2 Upgrade Remediation
						 /*FROM ben.ben_ler_f ler						-- Commented code by IXPRAVEEN-ARGANO,11-May-2023
                             ,ben.ben_per_in_ler pil                    
                             ,ben.ben_prtt_enrt_rslt_f bper
                             ,ben.ben_elig_cvrd_dpnt_f dpnt
                             ,ben.ben_oipl_f boif
                             ,ben.ben_opt_f bo*/
						 FROM apps.ben_ler_f ler						--  code Added by IXPRAVEEN-ARGANO,   11-May-2023
                             ,apps.ben_per_in_ler pil
                             ,apps.ben_prtt_enrt_rslt_f bper
                             ,apps.ben_elig_cvrd_dpnt_f dpnt
                             ,apps.ben_oipl_f boif
                             ,apps.ben_opt_f bo	 
						 --END R12.2.11 Upgrade remediation
                        WHERE dpnt.dpnt_person_id = p_person_id
                          AND pil.ler_id = ler.ler_id
                          AND pil.business_group_id = 325
                          AND bper.per_in_ler_id = pil.per_in_ler_id
                          AND bper.prtt_enrt_rslt_id = dpnt.prtt_enrt_rslt_id
                          AND 'D' = p_per_type
                          AND dpnt.elig_cvrd_dpnt_id = (SELECT MAX (b.elig_cvrd_dpnt_id)
                                                          FROM ben_prtt_enrt_rslt_f a
                                                              --,ben.ben_elig_cvrd_dpnt_f b			-- Commented code by IXPRAVEEN-ARGANO,11-May-2023
                                                              ,apps.ben_elig_cvrd_dpnt_f b          --  code Added by IXPRAVEEN-ARGANO,   11-May-2023
                                                         WHERE a.prtt_enrt_rslt_id = b.prtt_enrt_rslt_id
                                                           AND a.person_id = bper.person_id
                                                           AND a.sspndd_flag = 'N'
                                                           AND a.prtt_enrt_rslt_stat_cd IS NULL
                                                           AND b.dpnt_person_id = dpnt.dpnt_person_id
                                                           AND a.pl_id = bper.pl_id)
                          AND bper.sspndd_flag = 'N'
                          AND bper.pl_id IN (p_pl_id)
                          AND bper.prtt_enrt_rslt_stat_cd IS NULL
                          AND bper.oipl_id = boif.oipl_id(+)
                          AND boif.opt_id = bo.opt_id(+)
                          AND p_actual_termination_date BETWEEN bper.enrt_cvg_strt_dt AND bper.enrt_cvg_thru_dt
                          AND p_actual_termination_date BETWEEN dpnt.cvg_strt_dt AND dpnt.cvg_thru_dt
                          AND p_actual_termination_date BETWEEN bo.effective_start_date(+) AND bo.effective_end_date(+)
                          AND p_actual_termination_date BETWEEN boif.effective_start_date(+) AND boif.effective_end_date(+)
                          AND p_actual_termination_date BETWEEN dpnt.effective_start_date AND dpnt.effective_end_date
                          AND p_actual_termination_date BETWEEN ler.effective_start_date AND ler.effective_end_date
                          AND ler.effective_end_date = '31-DEC-4712') qry
                WHERE pl_id IS NOT NULL;

    v_text                VARCHAR (32765)    DEFAULT NULL;
    v_file_name           VARCHAR2 (200)     DEFAULT NULL;
    v_file_type           UTL_FILE.FILE_TYPE;
    v_cut_off_date        DATE;
    v_current_run_date    DATE;
    v_pl_id               NUMBER             DEFAULT NULL;
    v_cnt                 NUMBER             DEFAULT 0;
    v_tot_fsa_cont        NUMBER             DEFAULT 0;
    v_tot_fsa_ele         NUMBER             DEFAULT 0;
    v_tot_dpc_cont        NUMBER             DEFAULT 0;
    v_tot_dpc_ele         NUMBER             DEFAULT 0;
    v_not_eli_fsa         VARCHAR2 (1)       DEFAULT NULL;
    v_not_eli_fsa1        VARCHAR2 (1)       DEFAULT NULL;
    v_not_eli_fsa2        VARCHAR2 (1)       DEFAULT NULL;
    v_not_eli_fsa3        VARCHAR2 (1)       DEFAULT NULL;   --changes 2018 1.3 hospital indemnity plan
    v_not_eli_dpc2        VARCHAR2 (1)       DEFAULT NULL;   --changes 2018 1.3 hospital indemnity plan
    v_not_eli_dpc         VARCHAR2 (1)       DEFAULT NULL;
    v_not_eli_dpc1        VARCHAR2 (1)       DEFAULT NULL;
    l_fsa_term_date       DATE               DEFAULT NULL;
    l_dpc_term_date       DATE               DEFAULT NULL;
    l_peo_count           NUMBER             DEFAULT 0;
    l_contact_type        VARCHAR2 (2)       DEFAULT NULL;
    v_ignore_emp          VARCHAR2 (1)       DEFAULT NULL;
    l_sub_code            VARCHAR2 (4)       DEFAULT NULL;
    l_value               VARCHAR2 (8)       DEFAULT NULL;
  BEGIN
    IF p_start_date IS NOT NULL
    THEN
      v_cut_off_date       := TO_DATE (p_start_date, 'YYYY/MM/DD HH24:MI:SS');
      v_current_run_date   := TO_DATE (p_end_date, 'YYYY/MM/DD HH24:MI:SS');
    ELSE
      v_cut_off_date       := TRUNC (SYSDATE);
      v_current_run_date   := TRUNC (SYSDATE);
    END IF;

    BEGIN
      SELECT 'TeleTechServices_vb.dat'
        INTO v_file_name
        FROM DUAL;
    EXCEPTION
      WHEN OTHERS
      THEN
        v_file_name   := NULL;
    END;

    v_file_type   := UTL_FILE.FOPEN (p_output_directory, v_file_name, 'w', 32765);
    v_cnt         := 0;

    --Header Info
    BEGIN
      v_text   := NULL;
      v_text   := 'A' || LPAD ('143329', 7, 0) || TO_CHAR (SYSDATE, 'MMDDYYYY') || RPAD ('', 1390, '');
      UTL_FILE.PUT_LINE (v_file_type, v_text);
      FND_FILE.PUT_LINE (FND_FILE.OUTPUT, v_text);
      v_cnt    := v_cnt + 1;
    EXCEPTION
      WHEN OTHERS
      THEN
        UTL_FILE.FCLOSE (v_file_type);
        FND_FILE.PUT_LINE (FND_FILE.LOG, 'Error out of header error-' || SQLERRM);
    END;

    FOR r_emp_rec IN c_emp_rec (v_cut_off_date, v_current_run_date)
    LOOP
      v_text           := NULL;
      v_not_eli_fsa    := 'N';
      v_not_eli_fsa1   := 'N';
      v_not_eli_fsa2   := 'N';
      v_not_eli_fsa3   := 'N';  --changes 2018 1.3 hospital indemnity plan
      v_not_eli_dpc    := 'N';
      v_not_eli_dpc1   := 'N';
      v_not_eli_dpc2   := 'N';

      FOR r_emp_info IN c_emp_info (r_emp_rec.person_id, r_emp_rec.actual_termination_date)
      LOOP
        l_dpc_term_date   := NULL;
        l_fsa_term_date   := NULL;
        l_contact_type    := NULL;

        BEGIN
          IF    LENGTH (r_emp_info.phone_num) < 10
             OR LENGTH (r_emp_info.phone_num) > 10
             OR r_emp_info.phone_num IS NULL
          THEN
            r_emp_info.phone_num   := NULL;
          ELSE
            r_emp_info.phone_num   := r_emp_info.phone_num;
          END IF;

          IF r_emp_info.contact_type = 'E'
          THEN
            l_contact_type   := '00';
          ELSIF r_emp_info.contact_type IN ('T', 'A', 'C', 'O', 'R', 'LW')
          THEN
            l_contact_type   := '02';
          ELSIF r_emp_info.contact_type IN ('S', 'D')
          THEN
            l_contact_type   := '01';
          END IF;

          v_text   := r_emp_info.per_type ||
                      RPAD (l_contact_type, 2, ' ') ||
                      LPAD ('143329', 7, 0) ||
                      NVL (LPAD (REPLACE (r_emp_info.national_identifier, '-'), 11, ' '), LPAD (' ', 11, ' ')) ||
                      NVL (LPAD (REPLACE (r_emp_info.member_ssn, '-'), 11, ' '), LPAD (' ', 11, ' ')) ||
                      NVL (RPAD (r_emp_info.employee_number, 20, ' '), RPAD (' ', 20, ' ')) ||
                      NVL (RPAD (ttec_library.remove_non_ascii (r_emp_info.last_name), 20, ' '), RPAD (' ', 20, ' ')) ||
                      NVL (RPAD (ttec_library.remove_non_ascii (r_emp_info.first_name), 12, ' '), RPAD (' ', 12, ' ')) ||
                      NVL (RPAD (ttec_library.remove_non_ascii (r_emp_info.middle_names), 1, ' '), RPAD (' ', 1, ' ')) ||
                      NVL (r_emp_info.dob, RPAD (' ', 8, ' ')) ||
                      NVL (r_emp_info.start_date, RPAD (' ', 8, ' ')) ||
                      NVL (SUBSTR (r_emp_info.user_status, 1, 1), RPAD (' ', 1, ' ')) ||
                      NVL (TO_CHAR (r_emp_info.actual_term_date, 'MMDDYYYY'), RPAD (' ', 8, ' ')) ||
                      NVL (RPAD (ttec_library.remove_non_ascii (r_emp_info.address_line1), 32, ' '), RPAD (' ', 32, ' ')) ||
                      NVL (RPAD (ttec_library.remove_non_ascii (r_emp_info.address_line2), 32, ' '), RPAD (' ', 32, ' ')) ||
                      NVL (RPAD (r_emp_info.town_or_city, 21, ' '), RPAD (' ', 21, ' ')) ||
                      NVL (RPAD (r_emp_info.state, 2, ' '), RPAD (' ', 2, ' ')) ||
                      NVL (RPAD (r_emp_info.postal_code, 9, ' '), RPAD (' ', 9, ' ')) ||
                      NVL (RPAD (r_emp_info.email_address, 40, ' '), RPAD (' ', 40, ' ')) ||
                      RPAD (' ', 1, ' ') ||
                      NVL (RPAD (r_emp_info.phone_num, 11, ' '), RPAD (' ', 11, ' ')) ||
                      RPAD (' ', 10, ' ') ||
                      RPAD (' ', 10, ' ') ||
                      RPAD (' ', 5, ' ') ||
                      RPAD (' ', 10, ' ') ||
                      RPAD (' ', 2, ' ') ||
                      'U' ||
                      'U' ||
                      RPAD (' ', 13, ' ');

          -- METLAW plan Converage for Employee
          IF r_emp_info.per_type = 'E'
          THEN
            BEGIN
              v_not_eli_fsa   := 'N';
              v_pl_id         := NULL;
              v_pl_id         := get_plan_id (NVL (r_emp_info.contact_person_id, r_emp_info.person_id), 'MLAW', r_emp_info.per_type, r_emp_rec.actual_termination_date);
              FND_FILE.PUT_LINE (FND_FILE.LOG, 'v_pl_id-' || v_pl_id);

              IF v_pl_id <> 0
              THEN
                FOR r_bnft_info IN c_bnft_info (NVL (r_emp_info.contact_person_id, r_emp_info.person_id), v_pl_id, r_emp_info.per_type, r_emp_rec.actual_termination_date)
                LOOP
                  FND_FILE.PUT_LINE (FND_FILE.LOG, 'v_pl_id loop-' || v_pl_id || r_emp_info.per_type || r_emp_rec.actual_termination_date);

                  BEGIN
                    l_fsa_term_date   := NULL;

                    SELECT TO_DATE (DECODE (TO_CHAR (val, 'YYYY')
                                           ,'4712', ''
                                           ,val
                                           ))
                      INTO l_fsa_term_date
                      FROM (SELECT NVL (r_emp_info.actual_term_date, NVL (DECODE (v_pl_id
                                                                                 ,7876, r_bnft_info.enrt_cvg_strt_dt
                                                                                 ), r_bnft_info.enrt_cvg_thru_dt)) val
                              FROM DUAL) DUAL;
                  EXCEPTION
                    WHEN NO_DATA_FOUND
                    THEN
                      l_fsa_term_date   := NULL;
                    WHEN OTHERS
                    THEN
                      l_fsa_term_date   := NULL;
                  END;

                  IF     r_bnft_info.enrt_cvg_strt_dt > l_fsa_term_date
                     AND l_fsa_term_date IS NOT NULL
                  THEN
                    r_bnft_info.enrt_cvg_strt_dt   := l_fsa_term_date;
                  END IF;

                  IF     l_fsa_term_date IS NOT NULL
                     AND l_fsa_term_date > v_current_run_date
                  THEN
                    l_fsa_term_date   := NULL;
                  END IF;

                  v_text   := v_text ||
                              RPAD (' ', 7, ' ') ||
                              'LE' ||
                              NVL (TO_CHAR (GREATEST (r_bnft_info.enrt_cvg_strt_dt, TRUNC (v_current_run_date, 'YYYY')), 'MMDDYYYY'), RPAD (' ', 8, ' ')) ||
                              NVL (TO_CHAR (GREATEST (l_fsa_term_date, TRUNC (v_current_run_date, 'YYYY')), 'MMDDYYYY'), RPAD (' ', 8, ' ')) ||
                              'P' ||
                              RPAD (' ', 156, ' ');
                  FND_FILE.PUT_LINE (FND_FILE.LOG, v_text);

                  IF    (    GREATEST (r_bnft_info.enrt_cvg_strt_dt, TRUNC (v_current_run_date, 'YYYY')) > v_current_run_date + 15
                         AND l_fsa_term_date IS NULL)
                     OR (    l_fsa_term_date < v_cut_off_date - 14
                         AND l_fsa_term_date IS NOT NULL)
                  THEN
                    v_not_eli_fsa   := 'Y';
                  END IF;
                END LOOP;
              ELSE
                v_not_eli_fsa   := 'Y';
                v_text          := v_text || RPAD (' ', 182, ' ');
              END IF;
            END;

            --- Critical Illness for Employee
            BEGIN
              v_not_eli_fsa1   := 'N';
              v_pl_id          := NULL;
              v_pl_id          := get_plan_id (NVL (r_emp_info.contact_person_id, r_emp_info.person_id), 'CRITICAL', r_emp_info.per_type, r_emp_rec.actual_termination_date);
              FND_FILE.PUT_LINE (FND_FILE.LOG, 'v_pl_id-' || v_pl_id);

              IF v_pl_id <> 0
              THEN
                FOR r_bnft_info IN c_bnft_info (NVL (r_emp_info.contact_person_id, r_emp_info.person_id), v_pl_id, r_emp_info.per_type, r_emp_rec.actual_termination_date)
                LOOP
                  FND_FILE.PUT_LINE (FND_FILE.LOG, 'v_pl_id loop-' || v_pl_id || r_emp_info.per_type || r_emp_rec.actual_termination_date);
                  l_sub_code   := NULL;
                  l_value      := NULL;

                  BEGIN
                    l_fsa_term_date   := NULL;

                    SELECT TO_DATE (DECODE (TO_CHAR (val, 'YYYY')
                                           ,'4712', ''
                                           ,val
                                           ))
                      INTO l_fsa_term_date
                      FROM (SELECT NVL (r_emp_info.actual_term_date, NVL (DECODE (v_pl_id
                                                                                 ,7872, r_bnft_info.enrt_cvg_strt_dt
                                                                                 ), r_bnft_info.enrt_cvg_thru_dt)) val
                              FROM DUAL) DUAL;
                  EXCEPTION
                    WHEN NO_DATA_FOUND
                    THEN
                      l_fsa_term_date   := NULL;
                    WHEN OTHERS
                    THEN
                      l_fsa_term_date   := NULL;
                  END;

                  IF     r_bnft_info.enrt_cvg_strt_dt > l_fsa_term_date
                     AND l_fsa_term_date IS NOT NULL
                  THEN
                    r_bnft_info.enrt_cvg_strt_dt   := l_fsa_term_date;
                  END IF;

                  IF     l_fsa_term_date IS NOT NULL
                     AND l_fsa_term_date > v_current_run_date
                  THEN
                    l_fsa_term_date   := NULL;
                  END IF;

                /* 1.6 begin */
--                  IF v_pl_id = 7874   --(Enhanced Critical Illness Plan sub code 1 and value 15000)--changes 1.2
--                  THEN
--                    l_sub_code   := '1';
--                    l_value      := '00015000';
--                  ELSIF v_pl_id = 7873
--                  THEN
--                    l_sub_code   := '3';
--                    l_value      := '00030000';
--                  END IF;
                  IF v_pl_id = 7874   --(Enhanced Critical Illness Plan sub code 3 and value 30000)--changes 1.6
                  THEN
                    l_sub_code   := '3';
                    l_value      := '00030000';
                  ELSIF v_pl_id = 7873
                  THEN
                    l_sub_code   := '1';
                    l_value      := '00015000';
                  END IF;
                 /* 1.6  end */
                  v_text       := v_text ||
                                  'DE' ||
                                  NVL (TO_CHAR (GREATEST (r_bnft_info.enrt_cvg_strt_dt, TRUNC (v_current_run_date, 'YYYY')), 'MMDDYYYY'), RPAD (' ', 8, ' ')) ||
                                  NVL (TO_CHAR (GREATEST (l_fsa_term_date, TRUNC (v_current_run_date, 'YYYY')), 'MMDDYYYY'), RPAD (' ', 8, ' ')) ||
                                  '0158755' ||
                                  '0001' ||
                                  NVL (LPAD (l_sub_code, 4, '0'), RPAD (' ', 4, ' ')) ||
                                  '1' ||
                                  'P' ||
                                  NVL (LPAD (l_value, '8', '0'), RPAD (' ', 8, ' ')) ||
                                  RPAD (' ', 63, ' ');
                  FND_FILE.PUT_LINE (FND_FILE.LOG, v_text);

                  IF    (    GREATEST (r_bnft_info.enrt_cvg_strt_dt, TRUNC (v_current_run_date, 'YYYY')) > v_current_run_date + 15
                         AND l_fsa_term_date IS NULL)
                     OR (    l_fsa_term_date < v_cut_off_date - 14
                         AND l_fsa_term_date IS NOT NULL)
                  THEN
                    v_not_eli_fsa1   := 'Y';
                  END IF;
                END LOOP;
              ELSE
                v_not_eli_fsa1   := 'Y';
                v_text           := v_text || RPAD (' ', 106, ' ');
              END IF;
            END;

            -- AIG for Employee
            BEGIN
              v_not_eli_fsa2   := 'N';
              v_pl_id          := NULL;
              v_pl_id          := get_plan_id (NVL (r_emp_info.contact_person_id, r_emp_info.person_id), 'AIG', r_emp_info.per_type, r_emp_rec.actual_termination_date);
              FND_FILE.PUT_LINE (FND_FILE.LOG, 'v_pl_id-' || v_pl_id);

              IF v_pl_id <> 0
              THEN
                FOR r_bnft_info IN c_bnft_info (NVL (r_emp_info.contact_person_id, r_emp_info.person_id), v_pl_id, r_emp_info.per_type, r_emp_rec.actual_termination_date)
                LOOP
                  FND_FILE.PUT_LINE (FND_FILE.LOG, 'v_pl_id loop-' || v_pl_id || r_emp_info.per_type || r_emp_rec.actual_termination_date);
                  l_sub_code   := NULL;

                  BEGIN
                    l_fsa_term_date   := NULL;

                    SELECT TO_DATE (DECODE (TO_CHAR (val, 'YYYY')
                                           ,'4712', ''
                                           ,val
                                           ))
                      INTO l_fsa_term_date
                      FROM (SELECT NVL (r_emp_info.actual_term_date, NVL (DECODE (v_pl_id
                                                                                 ,276, r_bnft_info.enrt_cvg_strt_dt
                                                                                 ), r_bnft_info.enrt_cvg_thru_dt)) val
                              FROM DUAL) DUAL;
                  EXCEPTION
                    WHEN NO_DATA_FOUND
                    THEN
                      l_fsa_term_date   := NULL;
                    WHEN OTHERS
                    THEN
                      l_fsa_term_date   := NULL;
                  END;

                  IF     r_bnft_info.enrt_cvg_strt_dt > l_fsa_term_date
                     AND l_fsa_term_date IS NOT NULL
                  THEN
                    r_bnft_info.enrt_cvg_strt_dt   := l_fsa_term_date;
                  END IF;

                  IF     l_fsa_term_date IS NOT NULL
                     AND l_fsa_term_date > v_current_run_date
                  THEN
                    l_fsa_term_date   := NULL;
                  END IF;

                  IF v_pl_id = 275   --this is enhaced plan hence subcode is 1(275-Enhanced Accident)--changes 1.2
                  THEN
                    l_sub_code   := '1';
                  ELSE
                    l_sub_code   := '3';
                  END IF;

                  v_text       := v_text ||
                                  RPAD (' ', 106, ' ')   --space for RE plan
                                                      ||
                                  'AH' ||
                                  NVL (TO_CHAR (GREATEST (r_bnft_info.enrt_cvg_strt_dt, TRUNC (v_current_run_date, 'YYYY')), 'MMDDYYYY'), RPAD (' ', 8, ' ')) ||
                                  NVL (TO_CHAR (GREATEST (l_fsa_term_date, TRUNC (v_current_run_date, 'YYYY')), 'MMDDYYYY'), RPAD (' ', 8, ' ')) ||
                                  '0158770' ||
                                  '0001' ||
                                  NVL (LPAD (l_sub_code, 4, '0'), RPAD (' ', 4, ' ')) ||
                                  NVL (r_bnft_info.opt_type, RPAD (' ', 1, ' ')) ||
                                  'P' ||
                                  RPAD (' ', 19, ' ');   --changes 2018 1.3 hospital indemnity plan --format changes 1.5
                  --|| RPAD (' ', 648, ' '); --changes 2018 1.3 hospital indemnity plan
                  FND_FILE.PUT_LINE (FND_FILE.LOG, v_text);

                  IF    (    GREATEST (r_bnft_info.enrt_cvg_strt_dt, TRUNC (v_current_run_date, 'YYYY')) > v_current_run_date + 15
                         AND l_fsa_term_date IS NULL)
                     OR (    l_fsa_term_date < v_cut_off_date - 14
                         AND l_fsa_term_date IS NOT NULL)
                  THEN
                    v_not_eli_fsa2   := 'Y';
                  END IF;
                END LOOP;
              ELSE
                v_not_eli_fsa2   := 'Y';
                v_text           := v_text || RPAD (' ', 160, ' ');   --changes 2018 1.3 hospital indemnity plan --format changes 1.5
              END IF;
            /* IF (   v_not_eli_fsa = 'N'
                 OR v_not_eli_fsa1 = 'N'
                 OR v_not_eli_fsa2 = 'N'
                )
             THEN
                UTL_FILE.put_line (v_file_type, v_text);
                fnd_file.put_line (fnd_file.output, v_text);
                v_cnt := v_cnt + 1;
             END IF;*/  --changes 2018 1.3 hospital indemnity plan
            END;

            ----added for  2018 1.3 hospital indemnity plan
            BEGIN
              v_not_eli_fsa3   := 'N';
              v_pl_id          := NULL;
              v_pl_id          := get_plan_id (NVL (r_emp_info.contact_person_id, r_emp_info.person_id), 'HOSPITAL', r_emp_info.per_type, r_emp_rec.actual_termination_date);
              FND_FILE.PUT_LINE (FND_FILE.LOG, 'v_pl_id-' || v_pl_id);

              IF v_pl_id <> 0
              THEN
                FOR r_bnft_info IN c_bnft_info (NVL (r_emp_info.contact_person_id, r_emp_info.person_id), v_pl_id, r_emp_info.per_type, r_emp_rec.actual_termination_date)
                LOOP
                  FND_FILE.PUT_LINE (FND_FILE.LOG, 'v_pl_id loop-' || v_pl_id || r_emp_info.per_type || r_emp_rec.actual_termination_date);
                  l_sub_code   := NULL;

                  BEGIN
                    l_fsa_term_date   := NULL;

                    SELECT TO_DATE (DECODE (TO_CHAR (val, 'YYYY')
                                           ,'4712', ''
                                           ,val
                                           ))
                      INTO l_fsa_term_date
                      FROM (SELECT NVL (r_emp_info.actual_term_date, NVL (DECODE (v_pl_id
                                                                                 ,17873, r_bnft_info.enrt_cvg_strt_dt
                                                                                 ), r_bnft_info.enrt_cvg_thru_dt)) val
                              FROM DUAL) DUAL;
                  EXCEPTION
                    WHEN NO_DATA_FOUND
                    THEN
                      l_fsa_term_date   := NULL;
                    WHEN OTHERS
                    THEN
                      l_fsa_term_date   := NULL;
                  END;

                  IF     r_bnft_info.enrt_cvg_strt_dt > l_fsa_term_date
                     AND l_fsa_term_date IS NOT NULL
                  THEN
                    r_bnft_info.enrt_cvg_strt_dt   := l_fsa_term_date;
                  END IF;

                  IF     l_fsa_term_date IS NOT NULL
                     AND l_fsa_term_date > v_current_run_date
                  THEN
                    l_fsa_term_date   := NULL;
                  END IF;

                  IF v_pl_id = 17872   --this is enhaced plan hence
                  THEN
                    l_sub_code   := '1';   --HIGH PLAN ENHANCED.
                  ELSE
                    l_sub_code   := '3';   --LOW PLAN 3
                  END IF;

                  v_text       := v_text
                                -- || RPAD (' ', 106, ' ') --format changes 1.5
                                 ||
                                  'HH' ||
                                  NVL (TO_CHAR (GREATEST (r_bnft_info.enrt_cvg_strt_dt, TRUNC (v_current_run_date, 'YYYY')), 'MMDDYYYY'), RPAD (' ', 8, ' ')) ||
                                  NVL (TO_CHAR (GREATEST (l_fsa_term_date, TRUNC (v_current_run_date, 'YYYY')), 'MMDDYYYY'), RPAD (' ', 8, ' ')) ||
                                  '0212432' ||
                                  '0001' ||
                                  NVL (LPAD (l_sub_code, 4, '0'), RPAD (' ', 4, ' ')) ||
                                  NVL (r_bnft_info.opt_type, RPAD (' ', 1, ' ')) ||
                                  'P' ||
                                  RPAD (' ', 20, ' ') ||
                                  RPAD (' ', 594, ' ');
                  FND_FILE.PUT_LINE (FND_FILE.LOG, v_text);

                  IF    (    GREATEST (r_bnft_info.enrt_cvg_strt_dt, TRUNC (v_current_run_date, 'YYYY')) > v_current_run_date + 15
                         AND l_fsa_term_date IS NULL)
                     OR (    l_fsa_term_date < v_cut_off_date - 14
                         AND l_fsa_term_date IS NOT NULL)
                  THEN
                    v_not_eli_fsa3   := 'Y';
                  END IF;
                END LOOP;
              ELSE
                v_not_eli_fsa3   := 'Y';
                v_text           := v_text || RPAD (' ', 649, ' ');
              END IF;


              IF (   v_not_eli_fsa = 'N'
                  OR v_not_eli_fsa1 = 'N'
                  OR v_not_eli_fsa2 = 'N'
                  OR v_not_eli_fsa3 = 'N'   --changes 2018 1.3 hospital indemnity plan
                                         )
              THEN
                UTL_FILE.PUT_LINE (v_file_type, v_text);
                FND_FILE.PUT_LINE (FND_FILE.OUTPUT, v_text);
                v_cnt   := v_cnt + 1;
              END IF;
            END;
            --added for  2018 1.3 hospital indemnity plan
          ELSE
            --- Critical Illness plan coverage for dependents
            BEGIN
              v_not_eli_dpc   := 'N';
              v_pl_id         := NULL;
              v_pl_id         := get_plan_id (NVL (r_emp_info.contact_person_id, r_emp_info.person_id), 'CRITICAL', r_emp_info.per_type, r_emp_rec.actual_termination_date);

              IF v_pl_id <> 0
              THEN
                FOR r_bnft_info IN c_bnft_info (NVL (r_emp_info.contact_person_id, r_emp_info.person_id), v_pl_id, r_emp_info.per_type, r_emp_rec.actual_termination_date)
                LOOP
                  FND_FILE.PUT_LINE (FND_FILE.LOG, 'v_pl_id loopD-' || v_pl_id || r_emp_info.per_type || r_emp_rec.actual_termination_date);
                  l_sub_code   := NULL;
                  l_value      := NULL;

                  BEGIN
                    l_dpc_term_date   := NULL;

                    SELECT TO_DATE (DECODE (TO_CHAR (val, 'YYYY')
                                           ,'4712', ''
                                           ,val
                                           ))
                      INTO l_dpc_term_date
                      FROM (SELECT NVL (r_bnft_info.enrt_cvg_thru_dt, NVL (DECODE (v_pl_id
                                                                                  ,7872, r_bnft_info.enrt_cvg_strt_dt
                                                                                  ), r_emp_info.actual_term_date)) val
                              FROM DUAL) DUAL;
                  EXCEPTION
                    WHEN NO_DATA_FOUND
                    THEN
                      l_dpc_term_date   := NULL;
                    WHEN OTHERS
                    THEN
                      l_dpc_term_date   := NULL;
                  END;

                  IF     r_bnft_info.enrt_cvg_strt_dt > l_dpc_term_date
                     AND l_dpc_term_date IS NOT NULL
                  THEN
                    r_bnft_info.enrt_cvg_strt_dt   := l_dpc_term_date;
                  END IF;

                  IF     l_dpc_term_date IS NOT NULL
                     AND l_dpc_term_date > v_current_run_date
                  THEN
                    l_dpc_term_date   := NULL;
                  END IF;

                 /* 1.6 begin */
--                  IF v_pl_id = 7874   --(Enhanced Critical Illness Plan sub code 1 and value 15000)--changes 1.2
--                  THEN
--                    l_sub_code   := '1';
--                    l_value      := '00015000';
--                  ELSIF v_pl_id = 7873
--                  THEN
--                    l_sub_code   := '3';
--                    l_value      := '00030000';
--                  END IF;
                  IF v_pl_id = 7874   --(Enhanced Critical Illness Plan sub code 3 and value 30000)--changes 1.6
                  THEN
                    l_sub_code   := '3';
                    l_value      := '00030000';
                  ELSIF v_pl_id = 7873
                  THEN
                    l_sub_code   := '1';
                    l_value      := '00015000';
                  END IF;
                 /* 1.6 End */
                  v_text       := v_text ||
                                  RPAD (' ', 182, ' ') ||
                                  RPAD (' ', 43, ' ') ||
                                  'DD' ||
                                  NVL (TO_CHAR (GREATEST (r_bnft_info.enrt_cvg_strt_dt, TRUNC (v_current_run_date, 'YYYY')), 'MMDDYYYY'), RPAD (' ', 8, ' ')) ||
                                  NVL (TO_CHAR (GREATEST (l_fsa_term_date, TRUNC (v_current_run_date, 'YYYY')), 'MMDDYYYY'), RPAD (' ', 8, ' ')) ||
                                  '0158755' ||
                                  '0001' ||
                                  NVL (LPAD (l_sub_code, 4, '0'), RPAD (' ', 4, ' ')) ||
                                  '4' ||
                                  'P' ||
                                  NVL (LPAD (l_value, '8', '0'), RPAD (' ', 8, ' ')) ||
                                  RPAD (' ', 20, ' ');
                  FND_FILE.PUT_LINE (FND_FILE.LOG, v_text);

                  IF    (    GREATEST (r_bnft_info.enrt_cvg_strt_dt, TRUNC (v_current_run_date, 'YYYY')) > v_current_run_date + 15
                         AND l_dpc_term_date IS NULL)
                     OR (    l_dpc_term_date < v_cut_off_date - 14
                         AND l_dpc_term_date IS NOT NULL)
                  THEN
                    v_not_eli_dpc   := 'Y';
                  END IF;
                END LOOP;
              ELSE
                v_not_eli_dpc   := 'Y';
                v_text          := v_text || RPAD (' ', 288, ' ');
              END IF;
            END;

            --- AIG plan coverage for dependents
            BEGIN
              v_not_eli_dpc1   := 'N';
              v_pl_id          := NULL;
              v_pl_id          := get_plan_id (NVL (r_emp_info.contact_person_id, r_emp_info.person_id), 'AIG', r_emp_info.per_type, r_emp_rec.actual_termination_date);

              IF v_pl_id <> 0
              THEN
                FOR r_bnft_info IN c_bnft_info (NVL (r_emp_info.contact_person_id, r_emp_info.person_id), v_pl_id, r_emp_info.per_type, r_emp_rec.actual_termination_date)
                LOOP
                  FND_FILE.PUT_LINE (FND_FILE.LOG, 'v_pl_id loopD-' || v_pl_id || r_emp_info.per_type || r_emp_rec.actual_termination_date);
                  l_sub_code   := NULL;

                  BEGIN
                    l_dpc_term_date   := NULL;

                    SELECT TO_DATE (DECODE (TO_CHAR (val, 'YYYY')
                                           ,'4712', ''
                                           ,val
                                           ))
                      INTO l_dpc_term_date
                      FROM (SELECT NVL (r_bnft_info.enrt_cvg_thru_dt, NVL (DECODE (v_pl_id
                                                                                  ,276, r_bnft_info.enrt_cvg_strt_dt
                                                                                  ), r_emp_info.actual_term_date)) val
                              FROM DUAL) DUAL;
                  EXCEPTION
                    WHEN NO_DATA_FOUND
                    THEN
                      l_dpc_term_date   := NULL;
                    WHEN OTHERS
                    THEN
                      l_dpc_term_date   := NULL;
                  END;

                  IF     r_bnft_info.enrt_cvg_strt_dt > l_dpc_term_date
                     AND l_dpc_term_date IS NOT NULL
                  THEN
                    r_bnft_info.enrt_cvg_strt_dt   := l_dpc_term_date;
                  END IF;

                  IF     l_dpc_term_date IS NOT NULL
                     AND l_dpc_term_date > v_current_run_date
                  THEN
                    l_dpc_term_date   := NULL;
                  END IF;

                  IF v_pl_id = 275   --this is enhaced plan hence subcode is 1(275-Enhanced Accident)--changes 1.2
                  THEN
                    l_sub_code   := '1';
                  ELSE
                    l_sub_code   := '3';
                  END IF;

                  v_text       := v_text ||
                                  RPAD (' ', 106, ' ') ||
                                  'AH' ||
                                  NVL (TO_CHAR (GREATEST (r_bnft_info.enrt_cvg_strt_dt, TRUNC (v_current_run_date, 'YYYY')), 'MMDDYYYY'), RPAD (' ', 8, ' ')) ||
                                  NVL (TO_CHAR (GREATEST (l_fsa_term_date, TRUNC (v_current_run_date, 'YYYY')), 'MMDDYYYY'), RPAD (' ', 8, ' ')) ||
                                  '0158770' ||
                                  '0001' ||
                                  NVL (LPAD (l_sub_code, 4, '0'), RPAD (' ', 4, ' ')) ||
                                  NVL (r_bnft_info.opt_type, RPAD (' ', 1, ' ')) ||
                                  'P' ||
                                  RPAD (' ', 19, ' '); --format changes 1.5
                  --|| RPAD (' ', 648, ' '); --changes 2018 1.3 hospital indemnity plan
                  FND_FILE.PUT_LINE (FND_FILE.LOG, v_text);

                  IF    (    GREATEST (r_bnft_info.enrt_cvg_strt_dt, TRUNC (v_current_run_date, 'YYYY')) > v_current_run_date + 15
                         AND l_dpc_term_date IS NULL)
                     OR (    l_dpc_term_date < v_cut_off_date - 14
                         AND l_dpc_term_date IS NOT NULL)
                  THEN
                    v_not_eli_dpc1   := 'Y';
                  END IF;
                END LOOP;
              ELSE
                v_not_eli_dpc1   := 'Y';
                v_text           := v_text || RPAD (' ', 160, ' '); --changes 2018 1.3 hospital indemnity plan --format changes 1.5
              END IF;
            END;

            -------------changes 2018 1.3 hospital indemnity plan--------------------
            BEGIN
              v_not_eli_dpc2   := 'N';
              v_pl_id          := NULL;
              v_pl_id          := get_plan_id (NVL (r_emp_info.contact_person_id, r_emp_info.person_id), 'HOSPITAL', r_emp_info.per_type, r_emp_rec.actual_termination_date);

              IF v_pl_id <> 0
              THEN
                FOR r_bnft_info IN c_bnft_info (NVL (r_emp_info.contact_person_id, r_emp_info.person_id), v_pl_id, r_emp_info.per_type, r_emp_rec.actual_termination_date)
                LOOP
                  FND_FILE.PUT_LINE (FND_FILE.LOG, 'v_pl_id loopD-' || v_pl_id || r_emp_info.per_type || r_emp_rec.actual_termination_date);
                  l_sub_code   := NULL;

                  BEGIN
                    l_dpc_term_date   := NULL;

                    SELECT TO_DATE (DECODE (TO_CHAR (val, 'YYYY')
                                           ,'4712', ''
                                           ,val
                                           ))
                      INTO l_dpc_term_date
                      FROM (SELECT NVL (r_bnft_info.enrt_cvg_thru_dt, NVL (DECODE (v_pl_id
                                                                                  ,17873, r_bnft_info.enrt_cvg_strt_dt
                                                                                  ), r_emp_info.actual_term_date)) val
                              FROM DUAL) DUAL;
                  EXCEPTION
                    WHEN NO_DATA_FOUND
                    THEN
                      l_dpc_term_date   := NULL;
                    WHEN OTHERS
                    THEN
                      l_dpc_term_date   := NULL;
                  END;

                  IF     r_bnft_info.enrt_cvg_strt_dt > l_dpc_term_date
                     AND l_dpc_term_date IS NOT NULL
                  THEN
                    r_bnft_info.enrt_cvg_strt_dt   := l_dpc_term_date;
                  END IF;

                  IF     l_dpc_term_date IS NOT NULL
                     AND l_dpc_term_date > v_current_run_date
                  THEN
                    l_dpc_term_date   := NULL;
                  END IF;

                  IF v_pl_id = 17872
                  THEN
                    l_sub_code   := '1';
                  ELSE
                    l_sub_code   := '3';
                  END IF;

                  v_text       := v_text
                                -- || RPAD (' ', 106, ' ')--format changes 1.5
                                 ||
                                  'HH' ||
                                  NVL (TO_CHAR (GREATEST (r_bnft_info.enrt_cvg_strt_dt, TRUNC (v_current_run_date, 'YYYY')), 'MMDDYYYY'), RPAD (' ', 8, ' ')) ||
                                  NVL (TO_CHAR (GREATEST (l_fsa_term_date, TRUNC (v_current_run_date, 'YYYY')), 'MMDDYYYY'), RPAD (' ', 8, ' ')) ||
                                  '0212432' ||
                                  '0001' ||
                                  NVL (LPAD (l_sub_code, 4, '0'), RPAD (' ', 4, ' ')) ||
                                  NVL (r_bnft_info.opt_type, RPAD (' ', 1, ' ')) ||
                                  'P' ||
                                  RPAD (' ', 20, ' ') ||
                                  RPAD (' ', 593, ' ');
                  FND_FILE.PUT_LINE (FND_FILE.LOG, v_text);

                  IF    (    GREATEST (r_bnft_info.enrt_cvg_strt_dt, TRUNC (v_current_run_date, 'YYYY')) > v_current_run_date + 15
                         AND l_dpc_term_date IS NULL)
                     OR (    l_dpc_term_date < v_cut_off_date - 14
                         AND l_dpc_term_date IS NOT NULL)
                  THEN
                    v_not_eli_dpc2   := 'Y';
                  END IF;
                END LOOP;
              ELSE
                v_not_eli_dpc2   := 'Y';
                v_text           := v_text || RPAD (' ', 809, ' ');
              END IF;
            END;

            -------------changes 2018 1.3 hospital indemnity plan--------------------
            IF (   v_not_eli_dpc = 'N'
                OR v_not_eli_dpc1 = 'N'
                OR v_not_eli_dpc2 = 'N')
            THEN
              UTL_FILE.PUT_LINE (v_file_type, v_text);
              FND_FILE.PUT_LINE (FND_FILE.OUTPUT, v_text);
              v_cnt   := v_cnt + 1;
            END IF;
          END IF;
        END;
      END LOOP;
    END LOOP;

    --Trailer Info
    BEGIN
      v_text   := NULL;
      v_cnt    := v_cnt + 1;
      v_text   := 'Z' || '0143329' || LPAD (v_cnt, 8, '0') || RPAD (' ', 1391, ' ');
      UTL_FILE.PUT_LINE (v_file_type, v_text);
      FND_FILE.PUT_LINE (FND_FILE.OUTPUT, v_text);
    EXCEPTION
      WHEN OTHERS
      THEN
        FND_FILE.PUT_LINE (FND_FILE.LOG, 'Error out of header error-' || SQLERRM);
    END;

    FND_FILE.PUT_LINE (FND_FILE.LOG, 'v_total_cnt -' || v_cnt);
    UTL_FILE.FCLOSE (v_file_type);
  EXCEPTION
    WHEN OTHERS
    THEN
      UTL_FILE.FCLOSE (v_file_type);
      FND_FILE.PUT_LINE (FND_FILE.LOG, 'Error out of main loop main_proc -' || SQLERRM);
  END main_proc;
END ttec_ben_3plan_metlife_intf;
/
show errors;
/