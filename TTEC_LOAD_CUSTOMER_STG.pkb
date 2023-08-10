create or replace PACKAGE BODY ttec_load_customer_stg IS

  -- #Version     1.0.00
  --
  --
  -- MODIFICATION HISTORY
  -- Person        Ver       Date           Comments
  ----------------------------------------------------------------------------------------------------------------------------------------------------------
  --  TCS          1.0.00    04.12.2013
  --                                        Initial version
  --                                        This package is created for Customer Migration
  -- RXNETHI-ARGANO 1.0      11/MAY/2023    R12.2 Upgrade Remediation
  ----------------------------------------------------------------------------------------------------------------------------------------------------------

  g_request_id NUMBER := fnd_global.conc_request_id;
  g_login_id   NUMBER := fnd_global.login_id;

  v_last_upd_by_user NUMBER := fnd_global.user_id;
  v_created_by_user  NUMBER;
  v_err_msg          VARCHAR2(5000);
  v_error_code       NUMBER := 1;
  skip_record EXCEPTION;
  ln_price_list_name      VARCHAR2(200) := NULL;
  v_payment_term_name_old VARCHAR2(200) := NULL;
  lv_error_msg            VARCHAR2(5000) := NULL;
  ln_order_type_name      VARCHAR2(200) := NULL;
  ln_gl_code_combination  VARCHAR2(5000);
  lv_sales_channel        VARCHAR2(200) := NULL;
  lv_bill_to_site_use_id  VARCHAR2(200) := NULL;
  v_pram_trx_date         DATE := to_date('01-jan-2010', 'dd-mon-yyyy');
  -- g_new_org_id            NUMBER := NULL;

  --------------------------------------------------------------
  --load_ttec_ra_customers_stg
  --------------------------------------------------------------

  PROCEDURE load_ttec_ra_customers_stg(p_org_id IN NUMBER) IS

    v_person_flag       VARCHAR2(50);
    g_cust_orig_sys_ref VARCHAR2(1000);
    g_address_ref       VARCHAR2(1000);
    gc_new_org_id       NUMBER;

    CURSOR c_ttec_ra_customers_stg IS
      SELECT hca.account_number customer_number,
             hca.orig_system_reference cust_orig_sys_ref,
             hca.customer_type customer_type,
             hp.party_number party_number,
             hp.party_name customer_name,
             hp.party_type party_type,
             hp.orig_system_reference party_orig_sys_ref,
             hl.address1 address1,
             hl.address2 address2,
             hl.address3 address3,
             hl.address4 address4,
             hl.city city,
             hl.state state,
             hl.province province,
             hl.county county,
             hl.postal_code postal_code,
             hl.country country,
             hl.location_id location_id,
             hcsua.site_use_code site_use_code,
             hcsua.primary_flag primary_flag,
             hcsua.location location,
             hcsua.bill_to_site_use_id bill_to_site_use_id,
             hcsa.cust_acct_site_id cust_acct_site_id,
             hcsua.site_use_id site_use_id,
             hcsua.payment_term_id payment_term_id,
             hcsua.order_type_id order_type_id,
             hcsua.price_list_id price_list_id,
             hcsua.freight_term freight_term,
             hcsua.demand_class_code demand_class_code,
             hca.ship_via ship_via,
             hcsua.tax_code site_use_tax_code,
             hcsua.tax_reference site_use_tax_reference,
             hcsua.ship_via site_ship_via_code,
             hca.status customer_status,
             hp.category_code customer_category_code,
             hca.customer_class_code customer_class_code,
             hca.sales_channel_code sales_channel_code,
             hca.account_name,
             hca.tax_code tax_code,
             hp.tax_reference tax_reference,
             hp.person_first_name first_name,
             hp.person_last_name last_name,
             hps.party_site_id party_site_id,
             hca.cust_account_id customer_id,
             (SELECT g.segment1 || '.' || g.segment2 || '.' || g.segment3 || '.' ||
                     g.segment4 || '.' || g.segment5 || '.' || g.segment6 || '.' ||
                     g.segment7 || '.' || g.segment8 || '.' || g.segment9
                FROM apps.gl_code_combinations g
               WHERE g.code_combination_id = hcsua.gl_id_rev) revenue_account

        FROM apps.hz_cust_site_uses_all  hcsua,
             apps.hz_cust_acct_sites_all hcsa,
             apps.hz_cust_accounts       hca,
             apps.hz_parties             hp,
             apps.hz_party_sites         hps,
             apps.hz_locations           hl
       WHERE hcsua.org_id = p_org_id
         AND hcsua.cust_acct_site_id = hcsa.cust_acct_site_id
         AND hcsa.cust_account_id = hca.cust_account_id
         AND hca.party_id = hp.party_id
         AND hp.party_id = hps.party_id
         AND hps.party_site_id = hcsa.party_site_id
         AND hl.location_id = hps.location_id
         AND hca.status = 'A'
         AND hcsa.status = 'A'
         AND hp.status = 'A'
         AND hcsua.status = 'A'
         AND substr(hca.account_number, 0, 2) IN ('7A', '7B', '76', '8A');

  BEGIN

    fnd_file.put_line(fnd_file.log, 'Inside RA CUSTOMER STAGING');

    FOR ttec_ra_customers_stg_rec IN c_ttec_ra_customers_stg LOOP

      -- Concatenating Orig_sys_customer_reference with _PSA2.
      gc_new_org_id       := NULL;
      g_cust_orig_sys_ref := ttec_ra_customers_stg_rec.cust_orig_sys_ref ||
                             '_PSA2';

      g_address_ref := ttec_ra_customers_stg_rec.cust_acct_site_id ||
                       '_PSA2';

      fnd_file.put_line(fnd_file.log,
                        'g_cust_orig_sys_ref ' || g_cust_orig_sys_ref);
      fnd_file.put_line(fnd_file.log, 'g_address_ref ' || g_address_ref);

      --Retriving the price_list  name

      IF ttec_ra_customers_stg_rec.price_list_id IS NOT NULL THEN

        BEGIN
          SELECT NAME
            INTO ln_price_list_name
            --FROM qp.qp_list_headers_tl qptl --code commented by RXNETHI-ARGANO,11/05/23
			FROM apps.qp_list_headers_tl qptl --code added by RXNETHI-ARGANO,11/05/23
           WHERE LANGUAGE = 'US'
             AND qptl.list_header_id =
                 ttec_ra_customers_stg_rec.price_list_id;

        EXCEPTION
          WHEN OTHERS THEN
            fnd_file.put_line(fnd_file.log,
                              'Issue retrieving PRICE LIST ID');
            lv_error_msg := lv_error_msg ||
                            'WARNING: Issue retrieving PRICE LIST ID|';

        END;
      END IF;
      -- End of Retriving the price_list  name

      -- Satrt of Retriving the Payment term name
      IF ttec_ra_customers_stg_rec.payment_term_id IS NOT NULL THEN

        BEGIN
          SELECT NAME
            INTO v_payment_term_name_old
            FROM apps.ra_terms_tl
           WHERE LANGUAGE = 'US'
             AND to_char(term_id) =
                 ttec_ra_customers_stg_rec.payment_term_id;

        EXCEPTION
          WHEN OTHERS THEN
            fnd_file.put_line(fnd_file.log,
                              'Issue retrieving Payment term ID');
            lv_error_msg := lv_error_msg ||
                            'WARNING: Issue retrieving Payment term ID|';

        END;
      END IF;
      -- End of Retriving the price_list  name

      --Retriving the order type name

      IF ttec_ra_customers_stg_rec.order_type_id IS NOT NULL THEN

        BEGIN
          SELECT NAME
            INTO ln_order_type_name
            --FROM ont.oe_transaction_types_tl otl --code commented by RXNETHI-ARGANO,11/05/23
			FROM apps.oe_transaction_types_tl otl --code added by RXNETHI-ARGANO,11/05/23
           WHERE otl.transaction_type_id =
                 ttec_ra_customers_stg_rec.order_type_id
             AND LANGUAGE = 'US';

        EXCEPTION
          WHEN OTHERS THEN
            fnd_file.put_line(fnd_file.log,
                              'Issue retrieving ORDER LIST ID');
            lv_error_msg := lv_error_msg ||
                            'WARNING: Issue retrieving ORDER Type ID|';

        END;
      END IF;
      -------End of Retriving the order type name

      ---Fetching the sales Channelname from sales channel code
      IF ttec_ra_customers_stg_rec.sales_channel_code IS NOT NULL THEN
        BEGIN
          SELECT meaning
            INTO lv_sales_channel
            FROM apps.so_lookups sol
           WHERE sol.lookup_type = 'SALES_CHANNEL'
             AND sol.lookup_code =
                 ttec_ra_customers_stg_rec.sales_channel_code;

        EXCEPTION
          WHEN OTHERS THEN
            fnd_file.put_line(fnd_file.log,
                              'Issue retrieving SALES CHANNEL');
            lv_error_msg := lv_error_msg ||
                            'WARNING: Issue retrieving SALES CHANNEL';
        END;
      END IF;
      ---End of Fetching the sales Channelname from sales channel code

      ---Fetching values for BILL_TO_ORIG_ADDRESS_REF----
      IF ttec_ra_customers_stg_rec.bill_to_site_use_id IS NOT NULL THEN

        BEGIN
          SELECT cust_acct_site_id || '_PSA2' --LOCATION||'_PSA2'
            INTO lv_bill_to_site_use_id
            --FROM ar.hz_cust_site_uses_all hcusa --code commented by RXNETHI-ARGANO,11/05/23
			FROM apps.hz_cust_site_uses_all hcusa --code added by RXNETHI-ARGANO,11/05/23
           WHERE hcusa.site_use_id =
                 ttec_ra_customers_stg_rec.bill_to_site_use_id;

        EXCEPTION
          WHEN OTHERS THEN
            fnd_file.put_line(fnd_file.log,
                              'Issue retrieving SALES CHANNEL');
            lv_error_msg := lv_error_msg ||
                            'WARNING: Issue retrieving SALES CHANNEL';
        END;

      END IF;
      ---End of Fetching values for BILL_TO_ORIG_ADDRESS_REF----

      IF ttec_ra_customers_stg_rec.site_use_code = 'BILL_TO' THEN
        lv_bill_to_site_use_id := NULL;
      END IF;

      IF ((substr(ttec_ra_customers_stg_rec.customer_number, 0, 2) = '7A') OR
         (substr(ttec_ra_customers_stg_rec.customer_number, 0, 2) = '7B')) THEN

        BEGIN
          SELECT organization_id
            INTO gc_new_org_id
            FROM apps.hr_operating_units
           WHERE NAME = 'Guidon';
        END;
      ELSIF substr(ttec_ra_customers_stg_rec.customer_number, 0, 2) = '76' THEN

        BEGIN
          SELECT organization_id
            INTO gc_new_org_id
            FROM apps.hr_operating_units
           WHERE NAME = 'iKnowtion';
        END;
      ELSIF substr(ttec_ra_customers_stg_rec.customer_number, 0, 2) = '8A' THEN

        BEGIN
          SELECT organization_id
            INTO gc_new_org_id
            FROM apps.hr_operating_units
           WHERE NAME = 'ELOYALTY CANADA';
        END;
      END IF;

      fnd_file.put_line(fnd_file.log,
                        'Loading of Customer Information in to staging table');

      IF substr(ttec_ra_customers_stg_rec.customer_number, 0, 2) IN
         ('7A', '7B', '76', '8A') THEN

        BEGIN

          fnd_file.put_line(fnd_file.log, 'Inside begin for RA CUSTOMERS');

          INSERT INTO ttec_ra_customers_stg
            (orig_system_customer_ref,
             site_use_code,
             orig_system_address_ref,
             insert_update_flag,
             customer_name,
             customer_number,
             customer_status,
             customer_type,
             primary_site_use_flag,
             location,
             address1,
             address2,
             address3,
             address4,
             city,
             state,
             province,
             county,
             postal_code,
             country,
             customer_category_code,
             customer_class_code,
             cust_tax_code,
             cust_tax_reference,
             demand_class_code,
             cust_ship_via_code,
             site_use_tax_code,
             site_use_tax_reference,
             site_ship_via_code,
             person_first_name,
             person_last_name,
             orig_system_party_ref,
             party_number,
             party_site_number,
             status_flag,
             org_id,
             last_updated_by,
             last_update_date,
             created_by,
             creation_date,
             last_update_login,
             customer_id,
             request_id,
             payment_term_id,
             order_type_id,
             price_list_id,
             freight_term,
             gl_code,
             bill_to_orig_address_ref,
             account_name,
             SOURCE,
             site_use_id,
             party_site_id)
          VALUES
            (g_cust_orig_sys_ref,
             ttec_ra_customers_stg_rec.site_use_code,
             g_address_ref,
             'I',
             ttec_ra_customers_stg_rec.customer_name,
             ttec_ra_customers_stg_rec.customer_number,
             ttec_ra_customers_stg_rec.customer_status,
             ttec_ra_customers_stg_rec.customer_type,
             ttec_ra_customers_stg_rec.primary_flag,
             ttec_ra_customers_stg_rec.location,
             ttec_ra_customers_stg_rec.address1,
             ttec_ra_customers_stg_rec.address2,
             ttec_ra_customers_stg_rec.address3,
             ttec_ra_customers_stg_rec.address4,
             ttec_ra_customers_stg_rec.city,
             ttec_ra_customers_stg_rec.state,
             ttec_ra_customers_stg_rec.province,
             ttec_ra_customers_stg_rec.county,
             ttec_ra_customers_stg_rec.postal_code,
             ttec_ra_customers_stg_rec.country,
             ttec_ra_customers_stg_rec.customer_category_code,
             ttec_ra_customers_stg_rec.customer_class_code,
             ttec_ra_customers_stg_rec.tax_code,
             ttec_ra_customers_stg_rec.tax_reference,
             ttec_ra_customers_stg_rec.demand_class_code,
             ttec_ra_customers_stg_rec.ship_via,
             ttec_ra_customers_stg_rec.site_use_tax_code,
             ttec_ra_customers_stg_rec.tax_reference,
             ttec_ra_customers_stg_rec.site_ship_via_code,
             ttec_ra_customers_stg_rec.first_name,
             ttec_ra_customers_stg_rec.last_name,
             NULL,
             ttec_ra_customers_stg_rec.party_number,
             NULL,
             'N',
             gc_new_org_id,
             v_last_upd_by_user,
             SYSDATE,
             v_last_upd_by_user,
             SYSDATE,
             g_login_id,
             ttec_ra_customers_stg_rec.customer_id,
             g_request_id,
             v_payment_term_name_old,
             ln_order_type_name,
             ln_price_list_name,
             ttec_ra_customers_stg_rec.freight_term,
             ttec_ra_customers_stg_rec.revenue_account,
             lv_bill_to_site_use_id,
             ttec_ra_customers_stg_rec.account_name,
             'r12',
             ttec_ra_customers_stg_rec.site_use_id,
             ttec_ra_customers_stg_rec.cust_acct_site_id);

          COMMIT;

        EXCEPTION
          WHEN OTHERS THEN

            fnd_file.put_line(fnd_file.log,
                              to_char(SYSDATE, 'dd-Mon-yyyy hh24:mi:ss') ||
                              '   ' ||
                              'Error in the CUSTOMER INSERTION PART1 ' ||
                              SQLERRM);

        END;

      END IF;
    END LOOP;

    COMMIT;

  END load_ttec_ra_customers_stg;

  ---------------------------------------------------------------
  --load_ttec_ra_cust_prof_stg
  ---------------------------------------------------------------

  PROCEDURE load_ttec_ra_cust_prof_stg(p_org_id IN NUMBER) IS

    g_new_prof_cust_name VARCHAR2(1000);
    gp_cust_orig_sys_ref VARCHAR2(1000);
    gp_address_ref       VARCHAR2(1000);
    gp_new_org_id        NUMBER;

    CURSOR c_ttec_ra_profiles_stg IS
      SELECT hca.account_number        customer_number,
             hca.orig_system_reference cust_orig_sys_ref,
             hcpc.NAME                 profile_class_name,
             hcp.credit_hold           credit_hold,
             hcp.site_use_id           site_use_id
        FROM apps.hz_customer_profiles    hcp,
             apps.hz_cust_accounts        hca,
             apps.hz_cust_profile_classes hcpc
       WHERE hca.cust_account_id = hcp.cust_account_id
         AND hcp.profile_class_id = hcpc.profile_class_id
         AND hca.status = 'A'
         AND hca.cust_account_id IN
             (SELECT DISTINCT hca.cust_account_id
                FROM apps.hz_cust_site_uses_all  hcsua,
                     apps.hz_cust_acct_sites_all hcsa,
                     apps.hz_cust_accounts       hca
               WHERE hcsua.org_id = p_org_id
                 AND hcsua.cust_acct_site_id = hcsa.cust_acct_site_id
                 AND hcsa.cust_account_id = hca.cust_account_id
                 AND hca.status = 'A'
                 AND hcsa.status = 'A'
                 AND hcsua.status = 'A'
                 AND hca.account_number IN
                     (SELECT customer_number
                        FROM apps.ttec_ra_customers_stg
                       WHERE substr(customer_number, 0, 2) IN
                             ('7A', '7B', '76', '8A')
                         AND SOURCE = 'r12'));

  BEGIN
    FOR ttec_profiles_stg_rec IN c_ttec_ra_profiles_stg LOOP

      gp_cust_orig_sys_ref := ttec_profiles_stg_rec.cust_orig_sys_ref ||
                              '_PSA2';
      gp_address_ref       := NULL;
      gp_new_org_id        := NULL;

      -- for site level ... start
      IF ttec_profiles_stg_rec.site_use_id IS NOT NULL THEN

        SELECT hcsa.cust_acct_site_id || '_PSA2'
          INTO gp_address_ref
          FROM apps.hz_cust_site_uses_all  hcsua,
               apps.hz_cust_acct_sites_all hcsa,
               apps.hz_cust_accounts       hca,
               apps.hz_parties             hp,
               apps.hz_party_sites         hps,
               apps.hz_locations           hl
         WHERE hcsua.org_id = p_org_id
           AND hcsua.cust_acct_site_id = hcsa.cust_acct_site_id
           AND hcsa.cust_account_id = hca.cust_account_id
           AND hca.party_id = hp.party_id
           AND hp.party_id = hps.party_id
           AND hps.party_site_id = hcsa.party_site_id
           AND hl.location_id = hps.location_id
           AND hca.status = 'A'
           AND hcsa.status = 'A'
           AND hp.status = 'A'
           AND hcsua.status = 'A'
           AND hcsua.site_use_id = ttec_profiles_stg_rec.site_use_id;

      END IF;

      -- for site level ... end

      fnd_file.put_line(fnd_file.log,
                        'Loading of Customer Profile Information in to staging table');

      fnd_file.put_line(fnd_file.log,
                        'gp_cust_orig_sys_ref ' || gp_cust_orig_sys_ref);

      fnd_file.put_line(fnd_file.log, 'gp_address_ref ' || gp_address_ref);

      fnd_file.put_line(fnd_file.log,
                        'PROFILE_CLASS_NAME ' ||
                        ttec_profiles_stg_rec.profile_class_name);

      IF ((substr(ttec_profiles_stg_rec.customer_number, 0, 2) = '7A') OR
         (substr(ttec_profiles_stg_rec.customer_number, 0, 2) = '7B')) THEN

        BEGIN
          SELECT organization_id
            INTO gp_new_org_id
            FROM apps.hr_operating_units
           WHERE NAME = 'Guidon';
        END;

      ELSIF substr(ttec_profiles_stg_rec.customer_number, 0, 2) = '76' THEN

        BEGIN
          SELECT organization_id
            INTO gp_new_org_id
            FROM apps.hr_operating_units
           WHERE NAME = 'iKnowtion';
        END;
      ELSIF substr(ttec_profiles_stg_rec.customer_number, 0, 2) = '8A' THEN

        BEGIN
          SELECT organization_id
            INTO gp_new_org_id
            FROM apps.hr_operating_units
           WHERE NAME = 'ELOYALTY CANADA';
        END;
      END IF;

      INSERT INTO ttec_ra_customer_profiles_stg
        (insert_update_flag,
         orig_system_customer_ref,
         orig_system_address_ref,
         customer_profile_class_name,
         credit_hold,
         last_updated_by,
         creation_date,
         created_by,
         last_update_date,
         last_update_login,
         request_id,
         org_id,
         status_flag,
         SOURCE)
      VALUES
        ('I',
         gp_cust_orig_sys_ref,
         gp_address_ref,
         ttec_profiles_stg_rec.profile_class_name,
         ttec_profiles_stg_rec.credit_hold,
         v_last_upd_by_user,
         SYSDATE,
         v_last_upd_by_user,
         SYSDATE,
         g_login_id,
         g_request_id,
         gp_new_org_id,
         'N',
         'r12');

    END LOOP;

    COMMIT;

  END load_ttec_ra_cust_prof_stg;

  ------------------------------------------------------------
  --Load_ttec_PHONES_STG
  ------------------------------------------------------------

  PROCEDURE load_ttec_phones_stg(p_org_id IN NUMBER) IS

    gpc_address_ref VARCHAR2(1000);
    gpc_new_org_id  NUMBER;

    CURSOR c_ttec_phones_stg IS
      SELECT distinct org_cont.party_site_id part_site_id,
             role_acct.account_number account_number,
             role_acct.orig_system_reference cust_orig_sys_ref,
             acct_role.cust_account_role_id contact_id,
             acct_role.cust_account_id customer_id,
             acct_role.cust_acct_site_id address_id,
             acct_role.object_version_number object_version,
             party.person_pre_name_adjunct title,
             org_cont.orig_system_reference org_cont_sys_ref,
             substrb(party.person_first_name, 1, 40) first_name,
             substrb(party.person_last_name, 1, 50) last_name,
             cont_point.contact_point_type,
             cont_point.phone_country_code,
             cont_point.contact_point_purpose,
             cont_point.phone_area_code,
             cont_point.phone_number,
             NULL first_name_alt,
             NULL last_name_alt,
             acct_role.status,
             org_cont.job_title job_title,
             org_cont.job_title_code job_title_code,
             org_cont.mail_stop mail_stop,
             party.customer_key contact_key,
             rel_party.email_address,
             org_cont.contact_number
        FROM apps.hz_contact_points       cont_point,
             apps.hz_cust_account_roles   acct_role,
             apps.hz_parties              party,
             apps.hz_parties              rel_party,
             apps.hz_relationships        rel,
             apps.hz_org_contacts         org_cont,
             apps.hz_cust_accounts        role_acct,
             apps.hz_contact_restrictions cont_res,
             apps.hz_person_language      per_lang,
             apps.hz_party_sites          hps,
             apps.ttec_ra_customers_stg   tstg
       WHERE acct_role.party_id = rel.party_id
         AND hps.party_site_id(+) = org_cont.party_site_id
         AND acct_role.role_type = 'CONTACT'
         AND org_cont.party_relationship_id = rel.relationship_id
         AND rel.subject_id = party.party_id
         AND rel_party.party_id = rel.party_id
         AND cont_point.owner_table_id(+) = rel_party.party_id
         AND cont_point.primary_flag(+) = 'Y'
         AND acct_role.cust_account_id = role_acct.cust_account_id
         AND role_acct.party_id = rel.object_id
         AND party.party_id = per_lang.party_id(+)
         AND per_lang.native_language(+) = 'Y'
         AND party.party_id = cont_res.subject_id(+)
         AND cont_res.subject_table(+) = 'HZ_PARTIES'
         AND cont_point.owner_table_name(+) = 'HZ_PARTIES'
         AND org_cont.status = 'A'
            --AND cont_point.status = 'A'
         AND acct_role.status = 'A'
         AND tstg.customer_number = role_acct.account_number
            --AND ((org_cont.party_site_id = tstg.party_site_id) OR
            --    (org_cont.party_site_id IS NULL))
         AND ((acct_role.cust_acct_site_id = tstg.party_site_id) OR
             (acct_role.cust_acct_site_id IS NULL))
         AND role_acct.account_number IN
             (SELECT customer_number
                FROM ttec_ra_customers_stg
               WHERE substr(customer_number, 0, 2) IN
                     ('7A', '7B', '76', '8A')
                 AND SOURCE = 'r12');

  BEGIN
    FOR ttec_phones_stg_rec IN c_ttec_phones_stg LOOP

      fnd_file.put_line(fnd_file.log,
                        'Loading of Customer Contact Information in to staging table');

      gpc_address_ref := NULL;
      gpc_new_org_id  := NULL;

      fnd_file.put_line(fnd_file.log,
                        'ttec_phones_stg_rec.address_id  ' ||
                        ttec_phones_stg_rec.address_id);

      IF ttec_phones_stg_rec.address_id IS NOT NULL THEN

        gpc_address_ref := ttec_phones_stg_rec.address_id || '_PSA2';

      END IF;

      IF ((substr(ttec_phones_stg_rec.account_number, 0, 2) = '7A') OR
         (substr(ttec_phones_stg_rec.account_number, 0, 2) = '7B')) THEN

        BEGIN
          SELECT organization_id
            INTO gpc_new_org_id
            FROM apps.hr_operating_units
           WHERE NAME = 'Guidon';
        END;
      ELSIF substr(ttec_phones_stg_rec.account_number, 0, 2) = '76' THEN

        BEGIN
          SELECT organization_id
            INTO gpc_new_org_id
            FROM apps.hr_operating_units
           WHERE NAME = 'iKnowtion';
        END;
      ELSIF substr(ttec_phones_stg_rec.account_number, 0, 2) = '8A' THEN

        BEGIN
          SELECT organization_id
            INTO gpc_new_org_id
            FROM apps.hr_operating_units
           WHERE NAME = 'ELOYALTY CANADA';
        END;
      END IF;

      --Loading Customer Phone Information

      INSERT INTO ttec_ra_contact_phones_stg
        (orig_system_customer_ref,
         orig_system_telephone_ref,
         orig_system_address_ref,
         orig_system_contact_ref,
         contact_first_name,
         contact_last_name,
         contact_point_type,
         contact_job_title,
         contact_title,
         insert_update_flag,
         telephone,
         telephone_type,
         telephone_area_code,
         phone_country_code,
         email_address,
         org_id,
         status_flag,
         last_updated_by,
         last_update_date,
         creation_date,
         created_by,
         request_id,
         SOURCE)
      VALUES
        (ttec_phones_stg_rec.cust_orig_sys_ref || '_PSA2',
         decode(ttec_phones_stg_rec.contact_point_type,
                NULL,
                NULL,
                ttec_cust_phone_ref_s.NEXTVAL || '_PSA2'),
         gpc_address_ref,
         ttec_phones_stg_rec.org_cont_sys_ref || '_CON_REF',
         ttec_phones_stg_rec.first_name,
         ttec_phones_stg_rec.last_name,
         ttec_phones_stg_rec.contact_point_type,
         ttec_phones_stg_rec.job_title_code,
         ttec_phones_stg_rec.title,
         'I',
         ttec_phones_stg_rec.phone_number,
         decode(ttec_phones_stg_rec.phone_number, NULL, NULL, 'GEN'),
         ttec_phones_stg_rec.phone_area_code,
         ttec_phones_stg_rec.phone_country_code,
         decode(ttec_phones_stg_rec.contact_point_type,
                'EMAIL',
                ttec_phones_stg_rec.email_address,
                NULL),
         gpc_new_org_id,
         'N',
         v_last_upd_by_user,
         SYSDATE,
         SYSDATE,
         g_login_id,
         g_request_id,
         'r12');

    END LOOP;
    COMMIT;
  END load_ttec_phones_stg;

  /*  --------------------------------------------------
    -- Load_H3G_PAY_METHOD_STG
    --------------------------------------------------

    PROCEDURE Load_ttec_PAY_METHOD_STG(p_org_id IN NUMBER) IS

      g_new_pay_cust_name varchar2(1000);

      CURSOR c_h3g_pay_method_stg IS
        SELECT hca.account_number       customer_number,
               acrm.receipt_method_name payment_method_name,
               --site_number
               acrm.primary_flag,
               acrm.start_date,
               acrm.end_date,
               --hcas.org_id,
               acrm.customer_id
          FROM apps.ar_cust_receipt_methods_v@H3G_SOURCE acrm,
               ar.hz_cust_accounts@H3G_SOURCE            hca
         WHERE hca.cust_account_id = acrm.customer_id
         and acrm.site_use_id is null -- only extracting header payment methods
           AND EXISTS (SELECT 'x'
                  FROM h3g_mig_uk.h3g_ra_customers_stg rcs
                 WHERE rcs.customer_id = acrm.customer_id
                   and rcs.org_id = p_org_id
                   and rcs.request_id = g_request_id);
      --and rownum<15

    BEGIN
      for H3G_PAY_METHOD_STG_REC in c_h3g_pay_method_stg LOOP

        if p_org_id = 2 then
          g_new_pay_cust_name := H3G_PAY_METHOD_STG_REC.CUSTOMER_NUMBER ||
                                 '_UK_MIG';
        else
          g_new_pay_cust_name := H3G_PAY_METHOD_STG_REC.CUSTOMER_NUMBER ||
                                 '_IE_MIG';
        end if;

        Fnd_File.PUT_LINE(Fnd_File.LOG,
                          'Loading of Customer Payment Information in to staging table');

        INSERT INTO h3g_mig_uk.h3g_RA_CUST_PAY_METHOD_STG
          (ORIG_SYSTEM_CUSTOMER_REF,
           PAYMENT_METHOD_NAME,
           PRIMARY_FLAG,
           --ORIG_SYSTEM_ADDRESS_REF ,
           START_DATE,
           END_DATE,
           STATUS_FLAG,
           org_id,
           LAST_UPDATE_DATE,
           LAST_UPDATED_BY,
           CREATED_BY,
           CREATION_DATE,
           LAST_UPDATE_LOGIN,
           request_id)
        VALUES
          (g_new_pay_cust_name,
           H3G_PAY_METHOD_STG_REC.PAYMENT_METHOD_NAME,
           H3G_PAY_METHOD_STG_REC.PRIMARY_FLAG,
           --H3G_PAY_METHOD_STG_REC.SITE_NUMBER,
           H3G_PAY_METHOD_STG_REC.START_DATE,
           H3G_PAY_METHOD_STG_REC.END_DATE,
           'N', -- Hard Coding as N to be picked by Interface Cursor
           p_org_id, --H3G_PAY_METHOD_STG_REC.org_id,
           sysdate,
           v_last_upd_by_user,
           v_last_upd_by_user,
           sysdate,
           g_login_id,
           g_request_id);
      END LOOP;

      commit;

    END Load_ttec_PAY_METHOD_STG;


    ------------------------------------------------------------
    --OUTPUT PROCEDURE
    ------------------------------------------------------------
    PROCEDURE LOAD_CUSTOMERS_OUT_REPORT(p_org_id IN NUMBER) AS

      l_Customers_count     NUMBER;
      l_Cust_profiles_count NUMBER;
      l_Cust_Contacts_count NUMBER;
      l_Cust_Payments_count NUMBER;

    BEGIN

      SELECT COUNT(*)
        INTO l_Customers_count
        FROM h3g_mig_uk.H3G_RA_CUSTOMERS_STG
       WHERE status_flag = 'N'
         AND TRUNC(CREATION_DATE) = TRUNC(SYSDATE)
         and request_id = g_request_id;

      --Total number of  Customers records inserted into staging table.
      Fnd_File.put_line(Fnd_File.output,
                        '*************************************************************** ');
      Fnd_File.put_line(Fnd_File.output,
                        '                        Start of Report                        ');
      Fnd_File.put_line(Fnd_File.output,
                        '*************************************************************** ');
      Fnd_File.put_line(Fnd_File.output,
                        '                                                                ');
      Fnd_File.put_line(Fnd_File.output,
                        '                                                                ');
      Fnd_File.put_line(Fnd_File.output,
                        ' Purpose                 : ' ||
                        'Record insertion into  Staging tables');
      Fnd_File.put_line(Fnd_File.output,
                        '                           ' || 'for Customers');
      Fnd_File.put_line(Fnd_File.output,
                        ' Staging Table Name      : ' ||
                        'H3G_RA_CUSTOMERS_STG');
      Fnd_File.put_line(Fnd_File.output,
                        ' Date Executed           : ' || sysdate);
      Fnd_File.put_line(Fnd_File.output,
                        ' Organization Id       : ' || p_org_id);
      Fnd_File.put_line(Fnd_File.output,
                        ' No. of records inserted : ' || l_Customers_count);
      Fnd_File.put_line(Fnd_File.output,
                        '                                                                ');
      Fnd_File.put_line(Fnd_File.output,
                        '                                                                ');
      Fnd_File.put_line(Fnd_File.output,
                        '*************************************************************** ');
      Fnd_File.put_line(Fnd_File.output,
                        '                        End of Report                           ');
      Fnd_File.put_line(Fnd_File.output,
                        '*************************************************************** ');

      --Customers Profiles Count
      SELECT COUNT(*)
        INTO l_Cust_profiles_count
        FROM h3g_mig_uk.H3G_RA_CUSTOMER_PROFILES_STG
       WHERE status_flag = 'N'
         AND TRUNC(CREATION_DATE) = TRUNC(SYSDATE)
         and request_id = g_request_id;

      --Total number of records inserted for Customers Profiles into staging table.
      Fnd_File.put_line(Fnd_File.output,
                        '*************************************************************** ');
      Fnd_File.put_line(Fnd_File.output,
                        '                        Start of Report                        ');
      Fnd_File.put_line(Fnd_File.output,
                        '*************************************************************** ');
      Fnd_File.put_line(Fnd_File.output,
                        '                                                                ');
      Fnd_File.put_line(Fnd_File.output,
                        '                                                                ');
      Fnd_File.put_line(Fnd_File.output,
                        ' Purpose                 : ' ||
                        'Record insertion into  Staging tables');
      Fnd_File.put_line(Fnd_File.output,
                        '                           ' ||
                        'for Customer Profiles');
      Fnd_File.put_line(Fnd_File.output,
                        ' Staging Table Name      : ' ||
                        'H3G_RA_CUSTOMER_PROFILES_STG');
      Fnd_File.put_line(Fnd_File.output,
                        ' Date Executed           : ' || sysdate);
      Fnd_File.put_line(Fnd_File.output,
                        ' Organization Id         : ' || p_org_id);
      Fnd_File.put_line(Fnd_File.output,
                        ' No. of records inserted : ' ||
                        l_Cust_profiles_count);
      Fnd_File.put_line(Fnd_File.output,
                        '                                                                ');
      Fnd_File.put_line(Fnd_File.output,
                        '                                                                ');
      Fnd_File.put_line(Fnd_File.output,
                        '*************************************************************** ');
      Fnd_File.put_line(Fnd_File.output,
                        '                        End of Report                           ');
      Fnd_File.put_line(Fnd_File.output,
                        '*************************************************************** ');

      Fnd_File.put_line(Fnd_File.output,
                        ' Report for Customers Profiles for Staging tables');
      Fnd_File.put_line(Fnd_File.output, ' Date Executed :' || sysdate);
      Fnd_File.put_line(Fnd_File.output, '              ');
      Fnd_File.put_line(Fnd_File.output, '              ');

      --Customers Contacts Count
      SELECT COUNT(*)
        INTO l_Cust_Contacts_count
        FROM h3g_mig_uk.H3G_RA_CONTACT_PHONES_STG
       WHERE status_flag = 'N'
         AND TRUNC(CREATION_DATE) = TRUNC(SYSDATE)
         and request_id = g_request_id;

      --Total number of records inserted for Customers Contacts into staging table.
      Fnd_File.put_line(Fnd_File.output,
                        '*************************************************************** ');
      Fnd_File.put_line(Fnd_File.output,
                        '                        Start of Report                        ');
      Fnd_File.put_line(Fnd_File.output,
                        '*************************************************************** ');
      Fnd_File.put_line(Fnd_File.output,
                        '                                                                ');
      Fnd_File.put_line(Fnd_File.output,
                        '                                                                ');
      Fnd_File.put_line(Fnd_File.output,
                        ' Purpose                 : ' ||
                        'Record insertion into  Staging tables');
      Fnd_File.put_line(Fnd_File.output,
                        '                           ' ||
                        'for Customers Contacts');
      Fnd_File.put_line(Fnd_File.output,
                        ' Staging Table Name      : ' ||
                        'H3G_RA_CONTACT_PHONES_STG');
      Fnd_File.put_line(Fnd_File.output,
                        ' Date Executed           : ' || sysdate);
      Fnd_File.put_line(Fnd_File.output,
                        ' Organization Id         : ' || p_org_id);
      Fnd_File.put_line(Fnd_File.output,
                        ' No. of records inserted : ' ||
                        l_Cust_Contacts_count);
      Fnd_File.put_line(Fnd_File.output,
                        '                                                                ');
      Fnd_File.put_line(Fnd_File.output,
                        '                                                                ');
      Fnd_File.put_line(Fnd_File.output,
                        '*************************************************************** ');
      Fnd_File.put_line(Fnd_File.output,
                        '                        End of Report                           ');
      Fnd_File.put_line(Fnd_File.output,
                        '*************************************************************** ');

      Fnd_File.put_line(Fnd_File.output,
                        ' Report for Customers Contacts for Staging tables');
      Fnd_File.put_line(Fnd_File.output, ' Date Executed :' || sysdate);
      Fnd_File.put_line(Fnd_File.output, '              ');
      Fnd_File.put_line(Fnd_File.output, '              ');

      --Customers Payments Count
      SELECT COUNT(*)
        INTO l_Cust_Payments_count
        FROM h3g_mig_uk.h3g_RA_CUST_PAY_METHOD_STG
       WHERE status_flag = 'N'
         AND TRUNC(CREATION_DATE) = TRUNC(SYSDATE)
         and request_id = g_request_id;

      --Total number of records inserted for Customers Contacts into staging table.
      Fnd_File.put_line(Fnd_File.output,
                        '*************************************************************** ');
      Fnd_File.put_line(Fnd_File.output,
                        '                        Start of Report                        ');
      Fnd_File.put_line(Fnd_File.output,
                        '*************************************************************** ');
      Fnd_File.put_line(Fnd_File.output,
                        '                                                                ');
      Fnd_File.put_line(Fnd_File.output,
                        '                                                                ');
      Fnd_File.put_line(Fnd_File.output,
                        ' Purpose                 : ' ||
                        'Record insertion into  Staging tables');
      Fnd_File.put_line(Fnd_File.output,
                        '                           ' ||
                        'for Customers Payments');
      Fnd_File.put_line(Fnd_File.output,
                        ' Staging Table Name      : ' ||
                        'H3G_RA_CUST_PAY_METHOD_STG');
      Fnd_File.put_line(Fnd_File.output,
                        ' Date Executed           : ' || sysdate);
      Fnd_File.put_line(Fnd_File.output,
                        ' Organization Id         : ' || p_org_id);
      Fnd_File.put_line(Fnd_File.output,
                        ' No. of records inserted : ' ||
                        l_Cust_Payments_count);
      Fnd_File.put_line(Fnd_File.output,
                        '                                                                ');
      Fnd_File.put_line(Fnd_File.output,
                        '                                                                ');
      Fnd_File.put_line(Fnd_File.output,
                        '*************************************************************** ');
      Fnd_File.put_line(Fnd_File.output,
                        '                        End of Report                           ');
      Fnd_File.put_line(Fnd_File.output,
                        '*************************************************************** ');

      Fnd_File.put_line(Fnd_File.output,
                        ' Report for Customers Payments for Staging tables');
      Fnd_File.put_line(Fnd_File.output, ' Date Executed :' || sysdate);
      Fnd_File.put_line(Fnd_File.output, '              ');
      Fnd_File.put_line(Fnd_File.output, '              ');

    EXCEPTION
      WHEN OTHERS THEN

        --  dbms_output.put_line ('exception1');
        Fnd_File.put_line(Fnd_File.LOG,
                          TO_CHAR(SYSDATE, 'dd-Mon-yyyy hh24:mi:ss') || '   ' ||
                          'Error in the output report ' || SQLERRM);

    END LOAD_CUSTOMERS_OUT_REPORT;


  */
  ------------------------------------------------------------
  --MAIN PROCEDURE
  ------------------------------------------------------------

  PROCEDURE load_customer_stg_main(p_errbuff OUT VARCHAR2,
                                   p_retcode OUT NUMBER,
                                   p_org_id  IN NUMBER) IS
  BEGIN

    fnd_file.put_line(fnd_file.log, 'Inside main PKG');
    fnd_file.put_line(fnd_file.log, 'Org id :' || p_org_id);

    load_ttec_ra_customers_stg(p_org_id);

    load_ttec_ra_cust_prof_stg(p_org_id);

    load_ttec_phones_stg(p_org_id);

    --Load_ttec_PAY_METHOD_STG(p_org_id);

    fnd_file.put_line(fnd_file.log, 'Insertion Ends');

    --LOAD_CUSTOMERS_OUT_REPORT(p_org_id);

  END load_customer_stg_main;

END ttec_load_customer_stg;
/
show errors;
/