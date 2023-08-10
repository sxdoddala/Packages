create or replace PACKAGE BODY      ttec_hr_new_work_arr_update
AS
      /*
     REM $Header:  APPS.TTEC_HR_NEW_WORK_ARR_UPDATE.pkb  1.0 Vaitheghi 5/13/2020 $
     REM
     REM Name          : TTEC_HR_NEW_WORK_ARR_UPDATE
     REM Special Notes : Package performs mass update of Work Arrangement (Work Arrangement
     REM                 and Work Arrangement Reason) for employees in assignment DFF form
     REM ===========================================================================SOFT======================================
     REM Modified on   Performed by     Version     Description
     REM 13-May-2020   Vaitheghi        1.0         Initial Version - STRY0049904
     REM 21-NOV-2020   Rajesh Koneru    2.0         Added Validation check for Work Arr Combination - TASK1739501
     REM 04-May-2023   RXNETHI-ARGANO   1.0         R12.2 Upgrade Remediation
	 REM =====================================================================================================================
     */
  -- declare who columns
  g_request_id    NUMBER := fnd_global.conc_request_id;
  g_created_by    NUMBER := fnd_global.user_id;

    /*************************************************************************************************************
  -- PROCEDURE print_output
  -- Description: This procedure standardizes concurrent program output calls.
  **************************************************************************************************************/
  PROCEDURE print_output (
    iv_data    IN    VARCHAR2
  )
  IS
  BEGIN
    FND_FILE.PUT_LINE (FND_FILE.OUTPUT, iv_data);
  END;   -- print_line


/*Start of version 2.0 */

FUNCTION ttec_check_work_arr_comb
                        (p_work_arr IN VARCHAR2,
                        p_work_arr_reas IN VARCHAR2)
                   RETURN NUMBER
   IS
   l_work_arr_comb_exists number;
   BEGIN
    IF p_work_arr IS NOT NULL and p_work_arr_reas IS NOT NULL
            then
         --     ln_wa_comb_cnt   := 1;

              BEGIN
           select 1
                   INTO l_work_arr_comb_exists
                          from fnd_flex_values_vl ffvv ,
                             FND_FLEX_VALUE_SETS ffvs
where ffvv.flex_value_set_id = ffvs.flex_value_set_id
and ffvs.flex_value_set_name = 'TTEC_HR_WORK_ARRANGEMENT_REASON_VS'
and
(ffvv.description=p_work_arr  or substr(ffvv.description,1,INSTR(ffvv.description,'|',1,1)-1)=p_work_arr
OR substr(ffvv.description,INSTR(ffvv.description,'|',1,1)+1,INSTR(ffvv.description,'|',1,2)-INSTR(ffvv.description,'|',1,1)-1)=p_work_arr
 OR substr(ffvv.description,INSTR(ffvv.description,'|',1,2)+1,INSTR(ffvv.description,'|',1,3)-INSTR(ffvv.description,'|',1,2)-1)=p_work_arr
 OR substr(ffvv.description,INSTR(ffvv.description,'|',1,3)+1,INSTR(ffvv.description,'|',1,4)-INSTR(ffvv.description,'|',1,3)-1)=p_work_arr
 OR substr(ffvv.description,INSTR(ffvv.description,'|',1,4)+1,INSTR(ffvv.description,'|',1,5)-INSTR(ffvv.description,'|',1,4)-1)=p_work_arr
 OR substr(ffvv.description,INSTR(ffvv.description,'|',1,5)+1,INSTR(ffvv.description,'|',1,6)-INSTR(ffvv.description,'|',1,5)-1)=p_work_arr
 OR substr(ffvv.description,INSTR(ffvv.description,'|',1,6)+1,INSTR(ffvv.description,'|',1,7)-INSTR(ffvv.description,'|',1,6)-1)=p_work_arr
 OR substr(ffvv.description,INSTR(ffvv.description,'|',1,7)+1,INSTR(ffvv.description,'|',1,8)-INSTR(ffvv.description,'|',1,7)-1)=p_work_arr
 OR substr(ffvv.description,INSTR(ffvv.description,'|',1,8)+1,INSTR(ffvv.description,'|',1,9)-INSTR(ffvv.description,'|',1,8)-1)=p_work_arr
 )
 and ffvv.flex_value = p_work_arr_reas
 and rownum=1
 ;
 RETURN 0;
 FND_FILE.PUT_LINE (FND_FILE.LOG, 'Valid Work Arrangement Combination' || SUBSTR (SQLERRM, 1, 100));
           EXCEPTION
                WHEN OTHERS
                THEN
                  RETURN 1;
                  FND_FILE.PUT_LINE (FND_FILE.LOG, 'Invalid Work Arrangement Combination' || SUBSTR (SQLERRM, 1, 100));
                 -- lc_work_arr_comb   := NULL;
                 -- v_error_msg        := 'Invalid Work Arrangement Combination';
              END;
           END IF;
   END;

/*End of version 2.0 */

  /*************************************************************************************************************
   -- PROCEDURE update_hr_work_arr
   -- Description: Update Assignment dff work arrangement details
   **************************************************************************************************************/
  PROCEDURE update_hr_work_arr (
    retcode    OUT    NUMBER
   ,errbuf     OUT    VARCHAR2
  )
  IS
    v_loc                           NUMBER;
    v_from_date                     DATE;
    lc_dt_ud_mode                   VARCHAR2 (100)                                       := NULL;
    ln_assignment_id                per_all_assignments_f.assignment_id%TYPE;
    ln_assignment_id1               per_all_assignments_f.assignment_id%TYPE;
    lc_employee_number              NUMBER;
    la_max_effective_date           DATE;
    ln_a_object_version_number      per_all_assignments_f.object_version_number%TYPE;
    --- Out Variable
    lb_update                       BOOLEAN;
    lb_correction                   BOOLEAN;
    lb_update_override              BOOLEAN;
    lb_update_change_insert         BOOLEAN;
    ------for Assignment update
    ln_soft_coding_keyflex_id       hr_soft_coding_keyflex.soft_coding_keyflex_id%TYPE;
    ln_stage_cnt                    NUMBER;
    ln_processed_cnt                NUMBER;
    ln_unprocessed_cnt              NUMBER;
    v_error_msg                     VARCHAR2 (2000);
    ------for Assignment update
    l_cagr_grade_def_id             NUMBER;
    l_cagr_concatenated_segments    VARCHAR2 (1000);
    l_concatenated_segments         VARCHAR2 (1000);
    l_soft_coding_keyflex_id        NUMBER;
    l_comment_id                    NUMBER;
    l_effective_start_date          DATE;
    l_effective_end_date            DATE;
    l_no_managers_warning           BOOLEAN;
    l_other_manager_warning         BOOLEAN;
    l_hourly_salaried_warning       BOOLEAN;
    l_gsp_post_process_warning      VARCHAR2 (1000);
    api_error_msg                   VARCHAR2 (2000);
    lv_ass_attribute22              VARCHAR2 (150);
    lv_ass_attribute23              VARCHAR2 (150);
    lc_work_arr                     VARCHAR2 (150);
    lc_work_arr_reas                VARCHAR2 (150);
    ln_wa_cnt                       NUMBER;
    ln_wa_reas_cnt                  NUMBER;
    ln_wa_comb_cnt                  NUMBER;
    lc_work_arr_comb                VARCHAR2 (150);
    ln_att_cnt                      NUMBER;
    ln_business_group               NUMBER;
    lc_ass_attribute5               VARCHAR2 (150);
    lc_ass_attribute30              VARCHAR2 (150);
    lc_ass_attribute25              VARCHAR2 (150);
    lc_ass_attribute27              VARCHAR2 (150);
    lc_ass_attribute6               VARCHAR2 (150);
    lc_ass_attribute7               VARCHAR2 (150);
    lc_ass_attribute4               VARCHAR2 (150);
    lc_ass_attribute8               VARCHAR2 (150);
    lc_ass_attribute29              VARCHAR2 (150);
    lc_ass_attribute19              VARCHAR2 (150);

    --cursor for staging table
    CURSOR cur_stg
    IS
      SELECT a.ROWID
            ,a.*
        FROM apps.ttec_hr_new_work_arr_upd_stg a
       WHERE a.status = 'N';

    --cursor to print the output
    CURSOR cur_print
    IS
      SELECT   a.ROWID
              ,a.*
          FROM apps.ttec_hr_new_work_arr_upd_stg a
      ORDER BY a.status DESC
              ,a.employee_number;

    --cursor to get employee and assignment dff details
    CURSOR cur_base (
      c_emp     IN    NUMBER
     ,c_date    IN    CHAR
    )
    IS
      SELECT DISTINCT papf.employee_number
                     ,papf.full_name
                     ,papf.business_group_id
                     ,paaf.ass_attribute22 work_arrang
                     ,paaf.ass_attribute23 work_arrang_reas
                     ,paaf.soft_coding_keyflex_id
                 /*
				 START R12.2 Upgrade Remediation
				 --code commented by RXNETHI-ARGANO, 04/MAY/2023
				 FROM hr.per_all_people_f papf
                     ,hr.per_all_assignments_f paaf
					 */
				 --code added by RXNETHI-ARGANO, 04/MAY/2023
				 FROM apps.per_all_people_f papf
                     ,apps.per_all_assignments_f paaf
				--END R12.2 Upgrade Remediation
                WHERE 1 = 1
                  AND papf.employee_number = c_emp
                  AND papf.person_id = paaf.person_id
                  AND c_date BETWEEN papf.effective_start_date AND papf.effective_end_date
                  AND c_date BETWEEN paaf.effective_start_date AND paaf.effective_end_date
                  AND papf.current_employee_flag = 'Y'
                  AND paaf.assignment_type = 'E';
  BEGIN
    v_loc                := 5;

    DELETE FROM apps.ttec_hr_new_work_arr_upd_bkp
          WHERE TRUNC (creation_date) < TRUNC (SYSDATE - 30);

    INSERT INTO apps.ttec_hr_new_work_arr_upd_bkp
      (SELECT *
         FROM apps.ttec_hr_new_work_arr_upd_stg);

    DELETE FROM apps.ttec_hr_new_work_arr_upd_stg;

    COMMIT;
    v_loc                := 10;

    BEGIN
      INSERT INTO apps.ttec_hr_new_work_arr_upd_stg
                  (employee_number
                  ,work_arrangement
                  ,work_arrangement_reason
                  ,effective_start_date
                  ,creation_date
                  ,created_by
                  ,conc_request_id
                  )
        SELECT employee_number
              ,DECODE (work_arrangement
                      ,'NULL', NULL
                      ,'null', NULL
                      ,work_arrangement
                      )
              ,DECODE (work_arrangement_reason
                      ,'NULL', NULL
                      ,'null', NULL
                      ,work_arrangement_reason
                      )
              ,effective_start_date
              ,SYSDATE
              ,g_created_by
              ,g_request_id
          FROM apps.ttec_hr_new_work_arr_upd_ext;

      COMMIT;
    EXCEPTION
      WHEN OTHERS
      THEN
        FND_FILE.PUT_LINE (FND_FILE.LOG, 'Error while inserting data into custom table' || '' || SUBSTR (SQLERRM, 1, 100));
    END;

    ln_stage_cnt         := NULL;
    ln_processed_cnt     := NULL;
    ln_unprocessed_cnt   := NULL;
    v_loc                := 15;

    --Fetching records count for processing
    BEGIN
      SELECT COUNT (employee_number)
        INTO ln_stage_cnt
        FROM apps.ttec_hr_new_work_arr_upd_stg
       WHERE status = 'N';

      IF ln_stage_cnt = 0
      THEN
        FND_FILE.PUT_LINE (FND_FILE.LOG, 'No Records To Process');
      ELSIF ln_stage_cnt > 0
      THEN
        FND_FILE.PUT_LINE (FND_FILE.LOG, 'New Records Available To Process - ' || ln_stage_cnt);
      END IF;
    EXCEPTION
      WHEN OTHERS
      THEN
        FND_FILE.PUT_LINE (FND_FILE.LOG, 'Error while fetching staging table count. Error message - ' || SUBSTR (SQLERRM, 1, 100));
    END;

    v_loc                := 20;
    -- Writing to Output
    print_output ('Status:');
    print_output (' ');
    print_output ('Employee_Number|Work_Arrangement|Work_Arrangement_Reason|Effective_Start_Date|Status|Error_Message');

    IF ln_stage_cnt > 0
    THEN
      v_loc                := 25;

      --First for Loop for staging table validation
      FOR i IN cur_stg
      LOOP
        lc_dt_ud_mode                := NULL;
        ln_assignment_id             := NULL;
        ln_assignment_id1            := NULL;
        lc_employee_number           := NULL;
        ln_a_object_version_number   := NULL;
        -- Out Variable
        lb_update                    := NULL;
        lb_correction                := NULL;
        lb_update_override           := NULL;
        lb_update_change_insert      := NULL;
        --for Assignment update
        ln_soft_coding_keyflex_id    := NULL;
        v_error_msg                  := NULL;
        api_error_msg                := NULL;
        v_from_date                  := TO_CHAR (i.effective_start_date, 'DD-Mon-YYYY');
        lv_ass_attribute22           := NULL;
        lv_ass_attribute23           := NULL;
        lc_work_arr                  := NULL;
        lc_work_arr_reas             := NULL;
        lc_work_arr_comb             := NULL;
        ln_wa_cnt                    := 0;
        ln_wa_comb_cnt               := 0;
        ln_wa_reas_cnt               := 0;
        ln_att_cnt                   := 1;
        lc_employee_number           := NULL;
        ln_assignment_id             := NULL;
        ln_a_object_version_number   := NULL;
        ln_business_group            := NULL;
        lc_ass_attribute5            := NULL;
        lc_ass_attribute30           := NULL;
        lc_ass_attribute25           := NULL;
        lc_ass_attribute27           := NULL;
        lc_ass_attribute6            := NULL;
        lc_ass_attribute7            := NULL;
        lc_ass_attribute4            := NULL;
        lc_ass_attribute8            := NULL;
        lc_ass_attribute29           := NULL;
        lc_ass_attribute19           := NULL;
        v_loc                        := 30;
        FND_FILE.PUT_LINE (FND_FILE.LOG, 'Data Validation Start For Employee# - ' || i.employee_number);
        FND_FILE.PUT_LINE (FND_FILE.LOG, '===================================================================');

        --Check if the passing employee number is valid for the current date
        BEGIN
          SELECT DISTINCT papf.employee_number
                         ,paaf.assignment_id
                         ,paaf.object_version_number
                         ,papf.business_group_id
                     INTO lc_employee_number
                         ,ln_assignment_id
                         ,ln_a_object_version_number
                         ,ln_business_group
                     /*
					 START R12.2 Upgrade Remediation
					 code commented by RXNETHI-ARGANO, 04/MAY/2023
					 FROM hr.per_all_people_f papf
                         ,hr.per_all_assignments_f paaf
						 */
					 --code added by RXNETHI-ARGANO, 04/MAY/2023
					 FROM apps.per_all_people_f papf
                         ,apps.per_all_assignments_f paaf
					 --END R12.2 Upgrade Remediation
                    WHERE papf.employee_number = i.employee_number
                      AND papf.person_id = paaf.person_id
                      AND papf.current_employee_flag = 'Y'
                      AND paaf.assignment_type = 'E'
                      AND TRUNC (SYSDATE) BETWEEN papf.effective_start_date AND papf.effective_end_date
                      AND TRUNC (SYSDATE) BETWEEN paaf.effective_start_date AND paaf.effective_end_date;
        EXCEPTION
          WHEN OTHERS
          THEN
            lc_employee_number           := NULL;
            ln_assignment_id             := NULL;
            ln_a_object_version_number   := NULL;

            UPDATE apps.ttec_hr_new_work_arr_upd_stg
               SET status = 'E'
                  ,error_status = 'FAILURE'
                  ,error_msg = 'Employee EE# ' || i.employee_number || ' is not active for current date.'
                  ,error_loc = v_loc
             WHERE employee_number = i.employee_number;
        END;

        --Check if the passing employee number is valid for the passing effective date
        IF (    (lc_employee_number IS NOT NULL)
            AND (ln_assignment_id IS NOT NULL))
        THEN
          v_loc   := 35;

          BEGIN
            SELECT DISTINCT papf.employee_number
                           ,paaf.assignment_id
                           ,paaf.object_version_number
                           ,papf.business_group_id
                       INTO lc_employee_number
                           ,ln_assignment_id
                           ,ln_a_object_version_number
                           ,ln_business_group
                       /*
					   START R12.2 Upgrade Remediation
					   code commented by RXNETHI-ARGANO, 04/MAY/2023
					   FROM hr.per_all_people_f papf
                           ,hr.per_all_assignments_f paaf*/
					   FROM apps.per_all_people_f papf
                           ,apps.per_all_assignments_f paaf
					--END R12.2 Upgrade Remediation
                      WHERE papf.employee_number = i.employee_number
                        AND papf.person_id = paaf.person_id
                        AND papf.current_employee_flag = 'Y'
                        AND paaf.assignment_type = 'E'
                        AND i.effective_start_date BETWEEN papf.effective_start_date AND papf.effective_end_date
                        AND i.effective_start_date BETWEEN paaf.effective_start_date AND paaf.effective_end_date;
          EXCEPTION
            WHEN OTHERS
            THEN
              lc_employee_number           := NULL;
              ln_assignment_id             := NULL;
              ln_a_object_version_number   := NULL;

              UPDATE apps.ttec_hr_new_work_arr_upd_stg
                 SET status = 'E'
                    ,error_status = 'FAILURE'
                    ,error_msg = 'Employee EE# ' || i.employee_number || ' is not active for passing effective date - ' || v_from_date
                    ,error_loc = v_loc
               WHERE employee_number = i.employee_number;
          END;
        END IF;

        IF (    (lc_employee_number IS NOT NULL)
            AND (ln_assignment_id IS NOT NULL))
        THEN
          v_loc   := 40;

          ----finding date track mode to update Assignment form data
          BEGIN
            dt_api.find_dt_upd_modes (
                                      -- Input Data Elements
                                      -- ------------------------------
                                      p_effective_date            => i.effective_start_date
                                     ,p_base_table_name           => 'PER_ALL_ASSIGNMENTS_F'
                                     ,p_base_key_column           => 'ASSIGNMENT_ID'
                                     ,p_base_key_value            => ln_assignment_id
                                     ,
                                      -- Output data elements
                                      -- -------------------------------
                                      p_correction                => lb_correction
                                     ,p_update                    => lb_update
                                     ,p_update_override           => lb_update_override
                                     ,p_update_change_insert      => lb_update_change_insert
                                     );

            IF (   lb_update_change_insert
                OR lb_update_override)
            THEN
              --Future dated changes - do insert and keeps the future record
              lc_dt_ud_mode   := 'UPDATE_CHANGE_INSERT';
            ELSIF lb_update
            THEN
              --Inserts a new record effective as of the effective date parameter and keeps the history
              lc_dt_ud_mode   := 'UPDATE';
            ELSIF lb_correction
            THEN
              --Correction - Over writes the existing record,no history will be maintained
              lc_dt_ud_mode   := 'CORRECTION';
            END IF;
          END;

         FND_FILE.PUT_LINE (FND_FILE.LOG, 'lc_dt_ud_mode:'||lc_dt_ud_mode);

          v_loc   := 45;

          --Second for Loop for base table validation
          FOR ttec IN cur_base (i.employee_number, i.effective_start_date)
          LOOP
            ---Data validations
            v_loc   := 50;

            --checking: if Emp have future changes in Assignment screen.
            BEGIN
              SELECT ass_attribute22
                    ,ass_attribute23
                INTO lv_ass_attribute22
                    ,lv_ass_attribute23
                --FROM hr.per_all_assignments_f --code commented by RXNETHI-ARGANO, 04/MAY/2023
                FROM apps.per_all_assignments_f --code added by RXNETHI-ARGANO, 04/MAY/2023
			   WHERE 1 = 1
                 AND assignment_id = ln_assignment_id
                 AND i.effective_start_date BETWEEN effective_start_date AND effective_end_date;
            EXCEPTION
              WHEN OTHERS
              THEN
                ln_att_cnt           := 0;
                lv_ass_attribute22   := NULL;
                lv_ass_attribute23   := NULL;
            END;

            v_loc   := 55;

            --checking: Passing work arrangement value is valid.
            IF i.work_arrangement IS NOT NULL
            THEN
              ln_wa_cnt   := 1;

              BEGIN
                SELECT DISTINCT ffv.flex_value
                           INTO lc_work_arr
                           /*
						   START R12.2 Upgrade Remediation
						   code commented by RXNETHI-ARGANO, 04/MAY/2023
						   FROM applsys.fnd_flex_value_sets ffvs
                               ,applsys.fnd_flex_values ffv
							   */
						   --code added by RXNETHI-ARGANO, 04/MAY/2023
						   FROM apps.fnd_flex_value_sets ffvs
                               ,apps.fnd_flex_values ffv
                           --END R12.2 Upgrade Remediation							   
                          WHERE ffvs.flex_value_set_id = ffv.flex_value_set_id
                            AND ffv.enabled_flag = 'Y'
                            AND ffv.flex_value = i.work_arrangement
                            AND ffvs.flex_value_set_name = 'TTEC_HR_WORK_ARRANGEMENT_VS';
              EXCEPTION
                WHEN OTHERS
                THEN
                  FND_FILE.PUT_LINE (FND_FILE.LOG, 'Invalid Work Arrangement' || SUBSTR (SQLERRM, 1, 100));
                  lc_work_arr   := NULL;
                  v_error_msg   := 'Invalid Work Arrangement';
              END;
            END IF;

            v_loc   := 60;

            --checking: Passing work arrangement reason value is valid.
            IF i.work_arrangement_reason IS NOT NULL
            THEN
              ln_wa_reas_cnt   := 1;

              BEGIN
                SELECT DISTINCT ffv.flex_value
                           INTO lc_work_arr_reas
                           /*
						   START R12.2 Upgrade Remediation
						   code commented by RXNETHI-ARGANO, 04/MAY/2023
						   FROM applsys.fnd_flex_value_sets ffvs
                               ,applsys.fnd_flex_values ffv
							   */
						   --code commented by RXNETHI-ARGANO, 04/MAY/2023
						   FROM apps.fnd_flex_value_sets ffvs
                               ,apps.fnd_flex_values ffv
						   --END R12.2 Upgrade Remediation
                          WHERE ffvs.flex_value_set_id = ffv.flex_value_set_id
                            AND ffv.enabled_flag = 'Y'
                            AND ffv.flex_value = i.work_arrangement_reason
                            AND ffvs.flex_value_set_name = 'TTEC_HR_WORK_ARRANGEMENT_REASON_VS';
              EXCEPTION
                WHEN OTHERS
                THEN
                  FND_FILE.PUT_LINE (FND_FILE.LOG, 'Invalid Work Arrangement Reason' || SUBSTR (SQLERRM, 1, 100));
                  lc_work_arr_reas   := NULL;
                  v_error_msg        := 'Invalid Work Arrangement Reason';
              END;
            END IF;

/*Start of version 2.0 */
IF i.work_arrangement IS NOT NULL and i.work_arrangement_reason IS NOT NULL
THEN
    if ttec_check_work_arr_comb(i.work_arrangement,i.work_arrangement_reason) = 0
    then
    lc_work_arr_comb:= 'Combination Exists';
    ln_wa_comb_cnt:=1;
    else
    lc_work_arr_comb:=NULL;
    end if;
/*End of version 2.0 */
end if;
   /*    --checking: Checking if combination is valid or not
            IF i.work_arrangement IS NOT NULL and i.work_arrangement_reason IS NOT NULL
            then
              ln_wa_comb_cnt   := 1;

              BEGIN
            select ffvv.flex_value
                   INTO lc_work_arr_comb
                          from fnd_flex_values_vl ffvv ,
                             FND_FLEX_VALUE_SETS ffvs
where ffvv.flex_value_set_id = ffvs.flex_value_set_id
and ffvs.flex_value_set_name = 'TTEC_HR_WORK_ARRANGEMENT_REASON_VS'
and
(ffvv.description=i.work_arrangement  or substr(ffvv.description,1,INSTR(ffvv.description,'|',1,1)-1)=i.work_arrangement
OR substr(ffvv.description,INSTR(ffvv.description,'|',1,1)+1,INSTR(ffvv.description,'|',1,2)-INSTR(ffvv.description,'|',1,1)-1)=i.work_arrangement
 OR substr(ffvv.description,INSTR(ffvv.description,'|',1,2)+1,INSTR(ffvv.description,'|',1,3)-INSTR(ffvv.description,'|',1,2)-1)=i.work_arrangement
 OR substr(ffvv.description,INSTR(ffvv.description,'|',1,3)+1,INSTR(ffvv.description,'|',1,4)-INSTR(ffvv.description,'|',1,3)-1)=i.work_arrangement
 OR substr(ffvv.description,INSTR(ffvv.description,'|',1,4)+1,INSTR(ffvv.description,'|',1,5)-INSTR(ffvv.description,'|',1,4)-1)=i.work_arrangement
 OR substr(ffvv.description,INSTR(ffvv.description,'|',1,5)+1,INSTR(ffvv.description,'|',1,6)-INSTR(ffvv.description,'|',1,5)-1)=i.work_arrangement
 OR substr(ffvv.description,INSTR(ffvv.description,'|',1,6)+1,INSTR(ffvv.description,'|',1,7)-INSTR(ffvv.description,'|',1,6)-1)=i.work_arrangement
 OR substr(ffvv.description,INSTR(ffvv.description,'|',1,7)+1,INSTR(ffvv.description,'|',1,8)-INSTR(ffvv.description,'|',1,7)-1)=i.work_arrangement
 OR substr(ffvv.description,INSTR(ffvv.description,'|',1,8)+1,INSTR(ffvv.description,'|',1,9)-INSTR(ffvv.description,'|',1,8)-1)=i.work_arrangement
 )
 and ffvv.flex_value = i.work_arrangement_reason
 and rownum=1
 ;
           EXCEPTION
                WHEN OTHERS
                THEN
                  FND_FILE.PUT_LINE (FND_FILE.LOG, 'Invalid Work Arrangement Combination' || SUBSTR (SQLERRM, 1, 100));
                  lc_work_arr_comb   := NULL;
                  v_error_msg        := 'Invalid Work Arrangement Combination';
              END;
           END IF;
           */


            IF (   (    lc_work_arr IS NULL
                    AND ln_wa_cnt = 1)
                OR (    lc_work_arr_reas IS NULL
                    AND ln_wa_reas_cnt = 1)
                OR (    lc_work_arr_comb IS NULL
                    AND ln_wa_comb_cnt = 1)

                    )
            THEN
              v_loc   := 65;

              UPDATE apps.ttec_hr_new_work_arr_upd_stg
                 SET status = 'E'
                    ,error_status = 'FAILURE'
                    ,error_msg = 'Invalid Work Arrangement/Work Arrangement Reason/Wrong Combination in data file'
                    ,error_loc = v_loc
               WHERE ROWID = i.ROWID;
            ELSIF (   (    lv_ass_attribute22 = lc_work_arr
                       AND lv_ass_attribute23 = lc_work_arr_reas)
                   OR (    ln_att_cnt = 1
                       AND lv_ass_attribute22 IS NULL
                       AND lv_ass_attribute23 IS NULL
                       AND i.work_arrangement IS NULL
                       AND i.work_arrangement_reason IS NULL)
                   OR (    lv_ass_attribute22 = lc_work_arr
                       AND lv_ass_attribute23 IS NULL
                       AND i.work_arrangement_reason IS NULL
                       AND ln_att_cnt = 1)
                   OR (    lv_ass_attribute23 = lc_work_arr_reas
                       AND lv_ass_attribute22 IS NULL
                       AND i.work_arrangement IS NULL
                       AND ln_att_cnt = 1)
                  )
            THEN
              v_loc   := 70;

              UPDATE apps.ttec_hr_new_work_arr_upd_stg
                 SET status = 'E'
                    ,error_status = 'FAILURE'
                    ,error_msg = 'Work Arrangement Details are Already updated for the passing effective date'
                    ,error_loc = v_loc
               WHERE ROWID = i.ROWID;
            ELSE
              v_loc   := 75;

              --checking: existing attribute values for phl employees
              BEGIN
                IF ln_business_group = 1517
                THEN
                  --Only for PHL BG
                  v_loc   := 80;

                  BEGIN
                    SELECT DISTINCT paaf.ass_attribute5
                                   ,paaf.ass_attribute30
                                   ,paaf.ass_attribute25
                                   ,paaf.ass_attribute27
                                   ,paaf.ass_attribute6
                                   ,paaf.ass_attribute7
                                   ,paaf.ass_attribute4
                                   ,paaf.ass_attribute8
                                   ,paaf.ass_attribute29
                                   ,paaf.ass_attribute19
                                   ,paaf.soft_coding_keyflex_id
                               INTO lc_ass_attribute5
                                   ,lc_ass_attribute30
                                   ,lc_ass_attribute25
                                   ,lc_ass_attribute27
                                   ,lc_ass_attribute6
                                   ,lc_ass_attribute7
                                   ,lc_ass_attribute4
                                   ,lc_ass_attribute8
                                   ,lc_ass_attribute29
                                   ,lc_ass_attribute19
                                   ,ln_soft_coding_keyflex_id
                               /*
							   START R12.2 Upgrade Remediation
							   code commented by RXNETHI-ARGANO, 04/MAY/2023
							   FROM hr.per_all_assignments_f paaf
                                   ,hr.per_all_people_f papf*/
							   --code added by RXNETHI-ARGANO, 04/MAY/2023
							   FROM apps.per_all_assignments_f paaf
                                   ,apps.per_all_people_f papf
							   --END R12.2 Upgrade Remediation
                              WHERE papf.person_id = paaf.person_id
                                AND papf.employee_number = i.employee_number
                                AND papf.current_employee_flag = 'Y'
                                AND paaf.assignment_type = 'E'
                                AND paaf.assignment_id = ln_assignment_id
                                AND i.effective_start_date BETWEEN papf.effective_start_date AND papf.effective_end_date
                                AND i.effective_start_date BETWEEN paaf.effective_start_date AND paaf.effective_end_date
                                AND papf.business_group_id = ln_business_group;
                  EXCEPTION
                    WHEN OTHERS
                    THEN
                      FND_FILE.PUT_LINE (FND_FILE.LOG
                                        , v_loc || '- Error while fetching existing attribute values for PHL employee## ' || i.employee_number || SUBSTR (SQLERRM, 1, 100));
                      lc_work_arr_reas   := NULL;
                      v_error_msg        := 'Error while fetching existing attribute values for PHL employee. ' || SQLERRM;

                      UPDATE apps.ttec_hr_new_work_arr_upd_stg
                         SET status = 'E'
                            ,error_status = 'FAILURE'
                            ,error_msg = v_error_msg
                            ,error_loc = v_loc
                       WHERE ROWID = i.ROWID;
                  END;

                  --API: to update assignment details in Assignment additional detail form
                  hr_assignment_api.update_emp_asg (
                                                    -- ------------------------------
                                                    p_validate                        => FALSE
                                                   ,p_effective_date                  => i.effective_start_date
                                                   ,p_datetrack_update_mode           => lc_dt_ud_mode
                                                   ,p_assignment_id                   => ln_assignment_id
                                                   ,p_soft_coding_keyflex_id          => ln_soft_coding_keyflex_id
                                                   ,
                                                    -- this parameter value needs to be passed only for PHL employees
                                                    p_ass_attribute5                  => lc_ass_attribute5
                                                   ,p_ass_attribute30                 => lc_ass_attribute30
                                                   ,p_ass_attribute25                 => lc_ass_attribute25
                                                   ,p_ass_attribute27                 => lc_ass_attribute27
                                                   ,p_ass_attribute6                  => lc_ass_attribute6
                                                   ,p_ass_attribute7                  => lc_ass_attribute7
                                                   ,p_ass_attribute4                  => lc_ass_attribute4
                                                   ,p_ass_attribute8                  => lc_ass_attribute8
                                                   ,p_ass_attribute29                 => lc_ass_attribute29
                                                   ,p_ass_attribute19                 => lc_ass_attribute19
                                                   ,p_ass_attribute22                 => lc_work_arr
                                                   ,p_ass_attribute23                 => lc_work_arr_reas
                                                   ,p_object_version_number           => ln_a_object_version_number
                                                   ,p_cagr_grade_def_id               => l_cagr_grade_def_id
                                                   ,p_cagr_concatenated_segments      => l_cagr_concatenated_segments
                                                   ,p_concatenated_segments           => l_concatenated_segments
                                                   ,p_comment_id                      => l_comment_id
                                                   ,p_effective_start_date            => l_effective_start_date
                                                   ,p_effective_end_date              => l_effective_end_date
                                                   ,p_no_managers_warning             => l_no_managers_warning
                                                   ,p_other_manager_warning           => l_other_manager_warning
                                                   ,p_hourly_salaried_warning         => l_hourly_salaried_warning
                                                   ,p_gsp_post_process_warning        => l_gsp_post_process_warning
                                                   --p_other_manager_warning            => lb_other_manager_warning
                                                   );
                ELSE   --All BG except PHL
                  v_loc   := 85;
                  FND_FILE.PUT_LINE (FND_FILE.LOG, v_loc || 'lc_work_arr: ' || lc_work_arr);
                  FND_FILE.PUT_LINE (FND_FILE.LOG, v_loc || 'lc_work_arr_reas:' || lc_work_arr_reas);
                  --API: to update assignment details in Assignment additional detail form
                  hr_assignment_api.update_emp_asg (   -- Input data elements
                                                    -- ------------------------------
                                                    p_validate                        => FALSE
                                                   ,p_effective_date                  => i.effective_start_date
                                                   ,p_datetrack_update_mode           => lc_dt_ud_mode
                                                   ,p_assignment_id                   => ln_assignment_id
                                                   ,p_soft_coding_keyflex_id          => ln_soft_coding_keyflex_id
                                                   ,p_ass_attribute22                 => lc_work_arr
                                                   ,p_ass_attribute23                 => lc_work_arr_reas
                                                   ,p_object_version_number           => ln_a_object_version_number
                                                   ,p_cagr_grade_def_id               => l_cagr_grade_def_id
                                                   ,p_cagr_concatenated_segments      => l_cagr_concatenated_segments
                                                   ,p_concatenated_segments           => l_concatenated_segments
                                                   ,p_comment_id                      => l_comment_id
                                                   ,p_effective_start_date            => l_effective_start_date
                                                   ,p_effective_end_date              => l_effective_end_date
                                                   ,p_no_managers_warning             => l_no_managers_warning
                                                   ,p_other_manager_warning           => l_other_manager_warning
                                                   ,p_hourly_salaried_warning         => l_hourly_salaried_warning
                                                   ,p_gsp_post_process_warning        => l_gsp_post_process_warning
                                                   --p_other_manager_warning            => lb_other_manager_warning
                                                   );
                END IF;   --end if for BG check

                v_loc   := 90;

                BEGIN
                  SELECT MAX (effective_start_date)
                    INTO la_max_effective_date
                    --FROM hr.per_all_assignments_f --code commented by RXNETHI-ARGANO, 04/MAY/2023
                    FROM apps.per_all_assignments_f --code added by RXNETHI-ARGANO, 04/MAY/2023
				   WHERE 1 = 1
                     AND assignment_id = ln_assignment_id;
                EXCEPTION
                  WHEN OTHERS
                  THEN
                    ROLLBACK;
                    FND_FILE.PUT_LINE (FND_FILE.LOG, v_loc || 'EXCEPTION - ASSIGNMENT FUTURE DATE VALIDATION - ' || SQLERRM);
                END;

                --To update future dated records in CORRECTION mode
                IF (la_max_effective_date > i.effective_start_date)
                THEN
                  v_loc   := 95;

                  FOR c IN (SELECT   paaf.assignment_id
                                    ,paaf.effective_start_date
                                    ,paaf.object_version_number
                                    ,papf.business_group_id
                                /*
								START R12.2 Upgrade Remediaiton
								code commented by RXNETHI-ARGANO, 04/MAY/2023
								FROM hr.per_all_people_f papf
                                    ,hr.per_all_assignments_f paaf
									*/
								--code added by RXNETHI-ARGANO, 04/MAY/2023
								FROM apps.per_all_people_f papf
                                    ,apps.per_all_assignments_f paaf
								--END R12.2 Upgrade Remediation
                               WHERE 1 = 1
                                 AND papf.person_id = paaf.person_id
                                 AND paaf.assignment_id = ln_assignment_id
                                 AND papf.employee_number = i.employee_number
                                 AND paaf.effective_start_date > i.effective_start_date
                                 AND i.effective_start_date BETWEEN papf.effective_start_date AND papf.effective_end_date
                            ORDER BY paaf.effective_start_date)
                  LOOP
                    ln_a_object_version_number   := c.object_version_number;

                    IF ln_business_group = 1517
                    THEN
                      v_loc   := 100;

                      BEGIN
                        SELECT DISTINCT paaf.ass_attribute5
                                       ,paaf.ass_attribute30
                                       ,paaf.ass_attribute25
                                       ,paaf.ass_attribute27
                                       ,paaf.ass_attribute6
                                       ,paaf.ass_attribute7
                                       ,paaf.ass_attribute4
                                       ,paaf.ass_attribute8
                                       ,paaf.ass_attribute29
                                       ,paaf.ass_attribute19
                                       ,paaf.soft_coding_keyflex_id
                                   INTO lc_ass_attribute5
                                       ,lc_ass_attribute30
                                       ,lc_ass_attribute25
                                       ,lc_ass_attribute27
                                       ,lc_ass_attribute6
                                       ,lc_ass_attribute7
                                       ,lc_ass_attribute4
                                       ,lc_ass_attribute8
                                       ,lc_ass_attribute29
                                       ,lc_ass_attribute19
                                       ,ln_soft_coding_keyflex_id
                                   /*
								   START R12.2 Upgrade Remediation
								   code commented by RXNETHI-ARGANO, 04/MAY/2023
								   FROM hr.per_all_assignments_f paaf
                                       ,hr.per_all_people_f papf
									   */
								   --code added by RXNETHI-ARGANO, 04/MAY/2023
								   FROM apps.per_all_assignments_f paaf
                                       ,apps.per_all_people_f papf
                                   --END R12.2 Upgrade Remediation									   
                                  WHERE papf.person_id = paaf.person_id
                                    AND papf.employee_number = i.employee_number
                                    AND papf.current_employee_flag = 'Y'
                                    AND paaf.assignment_type = 'E'
                                    AND paaf.assignment_id = ln_assignment_id
                                    AND i.effective_start_date BETWEEN papf.effective_start_date AND papf.effective_end_date
                                    AND i.effective_start_date BETWEEN paaf.effective_start_date AND paaf.effective_end_date
                                    AND papf.business_group_id = ln_business_group;
                      EXCEPTION
                        WHEN OTHERS
                        THEN
                          FND_FILE.PUT_LINE (FND_FILE.LOG
                                            , v_loc || '- Error while fetching existing attribute values for PHL employee## ' || i.employee_number || SUBSTR (SQLERRM, 1, 100));
                          lc_work_arr_reas   := NULL;
                          v_error_msg        := 'Error while fetching existing attribute values for PHL employee. ' || SQLERRM;

                          UPDATE apps.ttec_hr_new_work_arr_upd_stg
                             SET status = 'E'
                                ,error_status = 'FAILURE'
                                ,error_msg = v_error_msg
                           WHERE ROWID = i.ROWID;
                      END;

                      --API: to update assignment details in Assignment additional detail form
                      hr_assignment_api.update_emp_asg (   -- Input data elements
                                                        -- ------------------------------
                                                        p_validate                        => FALSE
                                                       ,p_effective_date                  => c.effective_start_date
                                                       ,p_datetrack_update_mode           => 'CORRECTION'
                                                       ,
                                                        --lc_dt_ud_mode,
                                                        p_assignment_id                   => ln_assignment_id
                                                       ,p_soft_coding_keyflex_id          => ln_soft_coding_keyflex_id
                                                       ,
                                                        -- this parameter value needs to be passed only for PHL employees
                                                        p_ass_attribute5                  => lc_ass_attribute5
                                                       ,p_ass_attribute30                 => lc_ass_attribute30
                                                       ,p_ass_attribute25                 => lc_ass_attribute25
                                                       ,p_ass_attribute27                 => lc_ass_attribute27
                                                       ,p_ass_attribute6                  => lc_ass_attribute6
                                                       ,p_ass_attribute7                  => lc_ass_attribute7
                                                       ,p_ass_attribute4                  => lc_ass_attribute4
                                                       ,p_ass_attribute8                  => lc_ass_attribute8
                                                       ,p_ass_attribute29                 => lc_ass_attribute29
                                                       ,p_ass_attribute19                 => lc_ass_attribute19
                                                       ,p_ass_attribute22                 => lc_work_arr
                                                       ,p_ass_attribute23                 => lc_work_arr_reas
                                                       ,p_object_version_number           => ln_a_object_version_number
                                                       ,p_cagr_grade_def_id               => l_cagr_grade_def_id
                                                       ,p_cagr_concatenated_segments      => l_cagr_concatenated_segments
                                                       ,p_concatenated_segments           => l_concatenated_segments
                                                       ,p_comment_id                      => l_comment_id
                                                       ,p_effective_start_date            => l_effective_start_date
                                                       ,p_effective_end_date              => l_effective_end_date
                                                       ,p_no_managers_warning             => l_no_managers_warning
                                                       ,p_other_manager_warning           => l_other_manager_warning
                                                       ,p_hourly_salaried_warning         => l_hourly_salaried_warning
                                                       ,p_gsp_post_process_warning        => l_gsp_post_process_warning
                                                       --p_other_manager_warning            => lb_other_manager_warning
                                                       );
                    ELSE
                      --All BGs except PHL
                      v_loc   := 105;
                      --API: to update assignment details in Assignment additional detail form
                      hr_assignment_api.update_emp_asg (   -- Input data elements
                                                        -- ------------------------------
                                                        p_validate                        => FALSE
                                                       ,p_effective_date                  => c.effective_start_date
                                                       ,p_datetrack_update_mode           => 'CORRECTION'
                                                       ,   --default correction mode for all future records
                                                        p_assignment_id                   => ln_assignment_id
                                                       ,p_soft_coding_keyflex_id          => ln_soft_coding_keyflex_id
                                                       ,p_ass_attribute22                 => lc_work_arr
                                                       ,p_ass_attribute23                 => lc_work_arr_reas
                                                       ,p_object_version_number           => ln_a_object_version_number
                                                       ,p_cagr_grade_def_id               => l_cagr_grade_def_id
                                                       ,p_cagr_concatenated_segments      => l_cagr_concatenated_segments
                                                       ,p_concatenated_segments           => l_concatenated_segments
                                                       ,p_comment_id                      => l_comment_id
                                                       ,p_effective_start_date            => l_effective_start_date
                                                       ,p_effective_end_date              => l_effective_end_date
                                                       ,p_no_managers_warning             => l_no_managers_warning
                                                       ,p_other_manager_warning           => l_other_manager_warning
                                                       ,p_hourly_salaried_warning         => l_hourly_salaried_warning
                                                       ,p_gsp_post_process_warning        => l_gsp_post_process_warning
                                                       --p_other_manager_warning            => lb_other_manager_warning
                                                       );
                    END IF;
                  END LOOP;
                END IF;

                v_loc   := 110;

                --Validating assignment_id
                BEGIN
                  SELECT paaf.assignment_id
                    INTO ln_assignment_id1
                     /*
								START R12.2 Upgrade Remediaiton
								code commented by RXNETHI-ARGANO, 04/MAY/2023
								FROM hr.per_all_people_f papf
                                    ,hr.per_all_assignments_f paaf
									*/
								--code added by RXNETHI-ARGANO, 04/MAY/2023
								FROM apps.per_all_people_f papf
                                    ,apps.per_all_assignments_f paaf
								--END R12.2 Upgrade Remediation
                   WHERE 1 = 1
                     AND papf.person_id = paaf.person_id
                     AND paaf.assignment_id = ln_assignment_id
                     AND papf.employee_number = i.employee_number
                     AND i.effective_start_date BETWEEN papf.effective_start_date AND papf.effective_end_date
                     AND i.effective_start_date BETWEEN paaf.effective_start_date AND paaf.effective_end_date;
                EXCEPTION
                  WHEN OTHERS
                  THEN
                    FND_FILE.PUT_LINE (FND_FILE.LOG, v_loc || '- Error while fetching the assignment id after the assignment update' || SUBSTR (SQLERRM, 1, 100));
                END;

                IF ln_assignment_id1 <> ln_assignment_id
                THEN
                  v_loc   := 115;
                  FND_FILE.PUT_LINE (FND_FILE.LOG
                                    , v_loc ||
                                      ' - Assignment ID## ' ||
                                      ln_assignment_id1 ||
                                      ' is updated after the data loaded in assignment form for the emp## - ' ||
                                      i.employee_number);
                  ROLLBACK;

                  UPDATE apps.ttec_hr_new_work_arr_upd_stg
                     SET status = 'E'
                        ,error_status = 'FAILURE'
                        ,error_msg = 'Assignment ID is updated after the data loaded in assignment form'
                        ,error_loc = v_loc
                   WHERE ROWID = i.ROWID;

                  COMMIT;
                ELSIF ln_assignment_id1 = ln_assignment_id
                THEN
                  v_loc   := 120;
                  COMMIT;

                  UPDATE apps.ttec_hr_new_work_arr_upd_stg
                     SET status = 'P'
                        ,error_status = 'SUCCESS'
                        ,error_msg = 'Successfully updated in assignment form'
                        ,error_loc = v_loc
                   WHERE ROWID = i.ROWID;
                END IF;
              EXCEPTION
                WHEN OTHERS
                THEN
                  ROLLBACK;
                  FND_FILE.PUT_LINE (FND_FILE.LOG
                                    , v_loc || ' - For #Emp: ' || '' || i.employee_number || '-' || ' while uplaoding data in assignment screen - ' || SUBSTR (SQLERRM, 1, 1000));
                  v_error_msg   := 'For #Emp: ' || '' || i.employee_number || '-' || ' while uplaoding data in assignment screen - ' || SUBSTR (SQLERRM, 1, 1000);

                  UPDATE apps.ttec_hr_new_work_arr_upd_stg
                     SET status = 'E'
                        ,error_status = 'FAILURE'
                        ,error_msg = 'API error while uplaoding data in assignment screen - ' || v_error_msg
                        ,error_loc = v_loc
                   WHERE ROWID = i.ROWID;

                  COMMIT;
              END;
            END IF;

            COMMIT;
          END LOOP;
        END IF;

        COMMIT;
      END LOOP;

      FND_FILE.PUT_LINE (FND_FILE.LOG, '');
      FND_FILE.PUT_LINE (FND_FILE.LOG, '*****************************************************');

      --Fetching processed record count
      BEGIN
        SELECT COUNT (stg.employee_number)
          INTO ln_processed_cnt
          FROM apps.ttec_hr_new_work_arr_upd_stg stg
         WHERE status = 'P';

        FND_FILE.PUT_LINE (FND_FILE.LOG, 'Processed Records - ' || ln_processed_cnt);
      EXCEPTION
        WHEN OTHERS
        THEN
          ROLLBACK;
          FND_FILE.PUT_LINE (FND_FILE.LOG, 'Exception - Processed Records - ' || SQLERRM);
      END;

      ln_unprocessed_cnt   := ln_stage_cnt - ln_processed_cnt;
      FND_FILE.PUT_LINE (FND_FILE.LOG, 'Unprocessed Records - ' || ln_unprocessed_cnt);
      FND_FILE.PUT_LINE (FND_FILE.LOG, '*****************************************************');
      FND_FILE.PUT_LINE (FND_FILE.LOG, '');

      ---Printing output
      BEGIN
        FOR j IN cur_print
        LOOP
          print_output (j.employee_number || '|' || j.work_arrangement || '|' || j.work_arrangement_reason || '|' || j.effective_start_date || '|' || j.error_status || '|'
                        || j.error_msg);
        END LOOP;
      EXCEPTION
        WHEN OTHERS
        THEN
          FND_FILE.PUT_LINE (FND_FILE.LOG, 'Error while printing output');
      END;
    END IF;
  EXCEPTION
    WHEN OTHERS
    THEN
      ROLLBACK;
      retcode   := 2;
      FND_FILE.PUT_LINE (FND_FILE.LOG, 'EXCEPTION - Assignment Additional Detail Update - ' || SQLERRM);
  END;
END ttec_hr_new_work_arr_update;
/
show errors;
/
