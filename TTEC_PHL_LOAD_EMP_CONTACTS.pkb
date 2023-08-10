create or replace PACKAGE BODY ttec_phl_load_emp_contacts AS
  /*
  -------------------------------------------------------------

  Program Name    : ttec_phl_load_emp_contacts specification

  Desciption      : For PHL Mass Upload Contacts in HRMS


  Input/Output Parameters

  Called From     :


  Created By      : TCS
  Date            : 07-31-2015

  Modification Log:
  -----------------
  Developer             Date        Version    Description
    Lalitha             07-31-2015   1.0 Created
	Lalitha             09-24-2015   1.1 Changes for benefit Group
    RXNETHI-ARGANO      18/MAY/2023  1.0 R12.2 Upgrade Remediation


  ---------------------------------------------------------------*/
  PROCEDURE LOAD_DATA(errbuff IN OUT NOCOPY VARCHAR2,
                      retcode IN OUT NOCOPY NUMBER) IS

    ln_contact_rel_id           PER_CONTACT_RELATIONSHIPS.CONTACT_RELATIONSHIP_ID%TYPE;
    ln_ctr_object_ver_num       PER_CONTACT_RELATIONSHIPS.OBJECT_VERSION_NUMBER%TYPE;
    ln_contact_person           PER_ALL_PEOPLE_F.PERSON_ID%TYPE;
    ln_object_version_number    PER_CONTACT_RELATIONSHIPS.OBJECT_VERSION_NUMBER%TYPE;
    ld_per_effective_start_date DATE;
    ld_per_effective_end_date   DATE;
    lc_full_name                PER_ALL_PEOPLE_F.FULL_NAME%TYPE;
    ln_per_comment_id           PER_ALL_PEOPLE_F.COMMENT_ID%TYPE;
    lb_name_comb_warning        BOOLEAN;
    lb_orig_hire_warning        BOOLEAN;
    skip_record EXCEPTION;
    l_benfts_grp_id               NUMBER;
    l_person_bnft_ovn             number;
    l_person_bnft_number          VARCHAR2(10);
    l_bn_effective_start_date     date;
    l_bn_effective_end_date       date;
    l_bn_full_name                varchar2(180);
    l_bn_comment_id               number;
    l_bn_name_combination_warning boolean;
    l_bn_assign_payroll_warning   boolean;
    l_bn_orig_hire_warning        boolean;

    --g_error_message cust.ttec_error_handling.error_message%TYPE := NULL;      --code commented by RXNETHI-ARGANO,18/05/23
    g_error_message apps.ttec_error_handling.error_message%TYPE := NULL;        --code added by RXNETHI-ARGANO,18/05/23

    CURSOR CSR_CONTACT_EXISTS(P_EMPLOYEE_NUMBER varchar2, p_contact_first_name VARCHAR2, p_contact_last_name VARCHAR2, p_contact_middle_name VARCHAR2, p_contact_suffix VARCHAR2) IS
      SELECT con.full_name,
             con.benefit_group_id,
             CON.PERSON_ID,
             CON.OBJECT_VERSION_NUMBER,
             con.effective_start_date
        FROM apps.per_all_people_f          con,
             apps.TTEC_PHL_CONTACT_EXT      e,
             apps.per_contact_relationships r,
             apps.per_all_people_f          ppf,
             apps.fnd_lookup_values         l
       WHERE to_date('01/10/2015', 'dd/mm/yyyy') BETWEEN
             con.effective_start_date AND con.effective_end_Date
         AND lower(con.first_name) like lower(e.contact_first_name)
         AND lower(con.last_name) like lower(e.contact_last_name)
         AND nvl(lower(con.middle_names), 'NA') like
             nvl(lower(e.contact_middle_name), 'NA')
         AND nvl(lower(con.suffix), 'NA') like
             nvl(lower(e.contact_suffix), 'NA')
         AND ppf.employee_number = e.employee_number
         AND ppf.employee_number = p_employee_number
         AND l.lookup_type = 'CONTACT'
         AND l.language = 'US'
         AND l.SECURITY_GROUP_ID = 0
         AND lower(l.meaning) = lower(e.contact_type)
         AND to_date('01/10/2015', 'dd/mm/yyyy') BETWEEN
             ppf.effective_start_date AND ppf.effective_end_Date
         AND r.person_id = ppf.person_id
         AND r.contact_person_id = con.person_id
         AND lower(e.contact_last_name) = lower(p_contact_last_name)
         AND lower(e.contact_first_name) = lower(p_contact_first_name)
         AND nvl(lower(e.contact_middle_name), 'NA') =
             NVL(lower(p_contact_middle_name), 'NA')
         AND nvl(lower(e.contact_suffix), 'NA') =
             NVL(lower(p_contact_suffix), 'NA');

    CURSOR CSR_emp_contact_rec IS
      SELECT ppf.employee_number,
             person_id,
             l.lookup_code contact_type,
             contact_first_name,
             contact_middle_name,
             contact_last_name,
             contact_gender,
             contact_birth_date,
             contact_suffix,
       BENEFITS_GROUP
        FROM apps.TTEC_PHL_CONTACT_EXT e,
             apps.per_all_people_f     ppf,
             apps.fnd_lookup_values    l
       WHERE ppf.business_group_id = 1517
         AND l.lookup_type = 'CONTACT'
         AND l.language = 'US'
         AND l.SECURITY_GROUP_ID = 0
         AND lower(l.meaning) = lower(e.contact_type)
         AND e.employee_number = ppf.employee_number
            --  AND e.employee_number = '2014358'
            --  AND e.employee_number LIKE '209%' --'20163%'
         AND trunc(sysdate) BETWEEN ppf.effective_start_date AND
             ppf.effective_end_Date;

    CURSOR csr_contact_sit_rec IS
      SELECT con.person_id
        FROM apps.per_all_people_f          con,
             apps.TTEC_PHL_CONTACT_EXT      e,
             apps.per_contact_relationships r,
             apps.per_all_people_f          ppf,
             apps.fnd_lookup_values         l
       WHERE to_date('01/10/2015', 'dd/mm/yyyy') BETWEEN
             con.effective_start_date AND con.effective_end_Date
         AND lower(con.first_name) like lower(e.contact_first_name)
         AND lower(con.last_name) like lower(e.contact_last_name)
         AND nvl(lower(con.middle_names), 'NA') like
             nvl(lower(e.contact_middle_name), 'NA')
         AND nvl(lower(con.suffix), 'NA') like
             nvl(lower(e.contact_suffix), 'NA')
         AND ppf.employee_number = e.employee_number
         AND l.lookup_type = 'CONTACT'
         AND l.language = 'US'
         AND l.SECURITY_GROUP_ID = 0
         AND upper(l.meaning) = upper(e.contact_type)
         AND to_date('01/10/2015', 'dd/mm/yyyy') BETWEEN
             ppf.effective_start_date AND ppf.effective_end_Date
         AND r.person_id = ppf.person_id
         AND r.contact_person_id = con.person_id;

    CURSOR c_id_flex IS
      SELECT id_flex_num
        FROM fnd_id_flex_structures
       WHERE id_flex_code = 'PEA'
         AND id_flex_structure_code = 'TTEC_PH_DEPENDENT_AUDIT';

    CURSOR c_audit_dependent(v_id_flex_num fnd_id_flex_structures_vl.id_flex_num%TYPE, v_person_id NUMBER) IS
      SELECT pa.person_analysis_id,
             ac.ANALYSIS_CRITERIA_ID,
             pa.object_version_number,
             ac.segment1
        --FROM hr.per_person_analyses pa, hr.per_analysis_criteria ac           --code commented by RXNETHI-ARGANO,18/05/23
        FROM apps.per_person_analyses pa, apps.per_analysis_criteria ac         --code added by RXNETHI-ARGANO,18/05/23
       WHERE pa.analysis_criteria_id = ac.analysis_criteria_id
         AND pa.id_flex_num = v_id_flex_num
         AND pa.person_id = v_person_id
         AND TRUNC(SYSDATE) BETWEEN date_from AND
             NVL(date_to, '31-DEC-4712');
    l_contact_full_name         VARCHAR2(240);
    l_id_flex_num               fnd_id_flex_structures_vl.id_flex_num%TYPE;
    v_pea_object_version_number NUMBER;
    v_id_flex_num               fnd_id_flex_structures_vl.id_flex_num%TYPE;
    v_person_analysis_id        per_person_analyses.person_analysis_id%TYPE;
    v_analysis_criteria_id      per_analysis_criteria.analysis_criteria_id%TYPE;
    l_sit_ovn                   NUMBER;
    l_con_benfts_grp_id         NUMBER;
    l_cur_eff_start_date        date;
    l_person_analysis_id        per_person_analyses.person_analysis_id%TYPE;
    l_analysis_criteria_id      per_analysis_criteria.analysis_criteria_id%TYPE;
    l_sit_segment1              per_analysis_criteria.segment1%TYPE;
  BEGIN
    OPEN c_id_flex;
    FETCH c_id_flex
      INTO l_id_flex_num;
    CLOSE c_id_flex;

    SELECT BENFTS_GRP_ID
      INTO l_benfts_grp_id
      FROM BEN_BENFTS_GRP
     WHERE BUSINESS_GROUP_ID = 1517
       AND UPPER(NAME) = 'GRANDFATHERED PARENT';

    FOR emprec IN CSR_emp_contact_rec LOOP
      BEGIN
        l_contact_full_name  := NULL;
        l_con_benfts_grp_id  := NULL;
        ln_contact_person    := NULL;
        l_person_bnft_ovn    := NULL;
        l_cur_eff_start_date := NULL;
        OPEN CSR_CONTACT_EXISTS(emprec.employee_number,
                                emprec.contact_first_name,
                                emprec.contact_last_name,
                                emprec.contact_middle_name,
                                emprec.contact_suffix);
        FETCH CSR_CONTACT_EXISTS
          INTO l_contact_full_name, l_con_benfts_grp_id, ln_contact_person, l_person_bnft_ovn, l_cur_eff_start_date;
        IF CSR_CONTACT_EXISTS%NOTFOUND THEN
          --  dbms_output.put_line('COntact does not exist');
          fnd_file.put_line(fnd_file.output,
                            'Contact does not exist. Creating');
          ln_contact_person := null;
          hr_contact_rel_api.create_contact(p_start_date        => to_date('01/10/2015',
                                                                           'dd/mm/yyyy'),
                                            p_business_group_id => 1517,
                                            p_person_id         => emprec.person_id,
                                            p_contact_type      => emprec.contact_type,

                                            p_date_start                  => to_date('01/10/2015',
                                                                                     'dd/mm/yyyy'),
                                            p_rltd_per_rsds_w_dsgntr_flag => 'Y',
                                            p_personal_flag               => 'Y',
                                            p_last_name                   => emprec.contact_last_name,
                                            p_sex                         => emprec.contact_gender,
                                            p_date_of_birth               => to_date(emprec.contact_birth_date,
                                                                                     'MM/DD/YYYY'),

                                            p_first_name                => emprec.contact_first_name,
                                            p_middle_names              => emprec.contact_middle_name,
                                            p_suffix                    => emprec.contact_suffix,
                                            p_contact_relationship_id   => ln_contact_rel_id,
                                            p_ctr_object_version_number => ln_ctr_object_ver_num,
                                            p_per_person_id             => ln_contact_person,
                                            p_per_object_version_number => ln_object_version_number,
                                            p_per_effective_start_date  => ld_per_effective_start_date,
                                            p_per_effective_end_date    => ld_per_effective_end_date,
                                            p_full_name                 => lc_full_name,
                                            p_per_comment_id            => ln_per_comment_id,
                                            p_name_combination_warning  => lb_name_comb_warning,
                                            p_orig_hire_warning         => lb_orig_hire_warning);
          fnd_file.put_line(fnd_file.output,
                            'Created Contact named :' ||
                            emprec.contact_last_name || ':with person_id: ' ||
                            ln_contact_person || ' :for employee: ' ||
                            emprec.employee_number);

          l_person_bnft_ovn    := ln_object_version_number;
          l_person_bnft_number := NULL;
        IF UPPER(emprec.benefits_group) = 'GRANDFATHERED PARENT' THEN
          hr_person_api.update_person(p_effective_date           => to_date('01/10/2015',
                                                                            'DD/MM/YYYY'),
                                      p_datetrack_update_mode    => 'CORRECTION',
                                      p_person_id                => ln_contact_person,
                                      p_object_version_number    => l_person_bnft_ovn,
                                      p_employee_number          => l_person_bnft_number,
                                      p_benefit_group_id         => l_benfts_grp_id,
                                      p_effective_start_date     => l_bn_effective_start_date,
                                      p_effective_end_date       => l_bn_effective_end_date,
                                      p_full_name                => l_bn_full_name,
                                      p_comment_id               => l_bn_comment_id,
                                      p_name_combination_warning => l_bn_name_combination_warning,
                                      p_assign_payroll_warning   => l_bn_assign_payroll_warning,
                                      p_orig_hire_warning        => l_bn_orig_hire_warning);
        END IF;
        ELSE
          -- dbms_output.put_line('COntact does not exist');
		  l_person_bnft_number := NULL;
          fnd_file.put_line(fnd_file.output,
                            'Contact already exists for employee:' ||
                            emprec.employee_number);
          IF l_con_benfts_grp_id IS NULL AND UPPER(emprec.benefits_group) = 'GRANDFATHERED PARENT' THEN
            hr_person_api.update_person(p_effective_date           => l_cur_eff_start_date,
                                        p_datetrack_update_mode    => 'CORRECTION',
                                        p_person_id                => ln_contact_person,
                                        p_object_version_number    => l_person_bnft_ovn,
                                        p_employee_number          => l_person_bnft_number,
                                        p_benefit_group_id         => l_benfts_grp_id,
                                        p_effective_start_date     => l_bn_effective_start_date,
                                        p_effective_end_date       => l_bn_effective_end_date,
                                        p_full_name                => l_bn_full_name,
                                        p_comment_id               => l_bn_comment_id,
                                        p_name_combination_warning => l_bn_name_combination_warning,
                                        p_assign_payroll_warning   => l_bn_assign_payroll_warning,
                                        p_orig_hire_warning        => l_bn_orig_hire_warning);
          END IF;

        END IF;
        CLOSE CSR_CONTACT_EXISTS;
      EXCEPTION
        WHEN OTHERS THEN

          fnd_file.put_line(fnd_file.log, 'Inside Exception block');
          fnd_file.put_line(fnd_file.log, SQLERRM);
          NULL;
          IF CSR_CONTACT_EXISTS%ISOPEN THEN
            CLOSE CSR_CONTACT_EXISTS;
          END IF;
      END;

    END LOOP;

    FOR contact_rec in csr_contact_sit_rec LOOP
      OPEN c_audit_dependent(l_id_flex_num, contact_rec.person_id);
      FETCH c_audit_dependent
        INTO l_person_analysis_id, l_analysis_criteria_id, l_sit_ovn, l_sit_segment1;
      IF c_audit_dependent%NOTFOUND THEN
        begin
          hr_sit_api.create_sit(p_person_id         => contact_rec.person_id,
                                p_business_group_id => 1517,
                                p_id_flex_num       => l_id_flex_num,
                                p_effective_date    => to_date('01/10/2015',
                                                               'dd/mm/yyyy'),
                                p_date_from         => to_date('01/10/2015',
                                                               'dd/mm/yyyy'),
                                p_segment1          => 'Y',

                                p_analysis_criteria_id      => v_analysis_criteria_id,
                                p_person_analysis_id        => v_person_analysis_id,
                                p_pea_object_version_number => v_pea_object_version_number);
        EXCEPTION

          WHEN OTHERS THEN
            g_error_message := 'Other Error at hr_sit_api api' || SQLERRM;

            RAISE skip_record;
        END;
      END IF;

      CLOSE c_audit_dependent;
    END LOOP;
  end;
end ttec_phl_load_emp_contacts;
/
show errors;
/