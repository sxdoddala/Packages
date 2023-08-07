create or replace PACKAGE BODY ttec_ap_invoice_conv_load_intf AS

  -- #Version     1.0.00
  --
  --
  -- MODIFICATION HISTORY
  -- Person        Ver       Date           Comments
  ----------------------------------------------------------------------------------------------------------------------------------------------------------
  --  TCS          1.0.00    04.01.2013
  --                                        Initial version
  --                                        This package is created for AP Invoice Migration..
  --IXPRAVEEN(ARGANO) 1.0     09-May-2023     R12.2 Upgrade Remediation
  ----------------------------------------------------------------------------------------------------------------------------------------------------------
  --g_gl_date        DATE := SYSDATE-4;
  g_application_id NUMBER := fnd_profile.VALUE('RESP_APPL_ID');
  g_request_id NUMBER := fnd_global.conc_request_id;
  g_user_id    NUMBER := fnd_global.user_id;
  g_login_id   NUMBER := fnd_global.login_id;

  ---------------------------------------------------------
  ---------------------------------------------------------

  PROCEDURE do_commit IS
  BEGIN

    COMMIT;
    NULL;

  END do_commit;

  ---------------------------------------------------------
  ---------------------------------------------------------

  PROCEDURE do_rollback IS
  BEGIN
    ROLLBACK;
  END do_rollback;

  ---------------------------------------------------------
  ---------------------------------------------------------

  PROCEDURE log(p_str VARCHAR2) IS
  BEGIN

    fnd_file.put_line(fnd_file.log ,
                      p_str);

  END log;

  ---------------------------------------------------------
  ---------------------------------------------------------

  PROCEDURE show_sql_err IS
  BEGIN
    log('SQLCODE ' || SQLCODE);
    log('SQLERRM :' || SQLERRM || chr(10) ||
        dbms_utility.format_error_backtrace);
  END show_sql_err;

  ---------------------------------------------------------
  ---------------------------------------------------------

  PROCEDURE ttec_ap_out_report AS

    l_e_ap_total NUMBER;
    l_v_ap_total NUMBER;

    --Account Payables Cursor

    CURSOR cur_ap_error IS
      SELECT invoice_num, error_msg, status
        FROM ttec_ap_invoices_stg
       WHERE status = 'E';

  BEGIN

    SELECT COUNT(*)
      INTO l_e_ap_total
      FROM ttec_ap_invoices_stg
     WHERE status = 'E';

    --Fetching the Error records of Payables
    IF l_e_ap_total > 0 THEN

      fnd_file.put_line(fnd_file.output,
                        'Report for Account Payables Conversion');
      fnd_file.put_line(fnd_file.output, 'Date Executed :' || SYSDATE);
      fnd_file.put_line(fnd_file.output, '         ');
      fnd_file.put_line(fnd_file.output, '         ');

      -- Begin cur_upd cursor

      fnd_file.put_line(fnd_file.output,
                        ' Following Payable Invoices are in Error Status because of the reasons mentioned below ');
      fnd_file.put_line(fnd_file.output, '         ');
      fnd_file.put_line(fnd_file.output,
                        rpad(nvl(substr('INVOICE NUMBER', 1, 20), ''),
                             20,
                             ' ') ||
                        rpad(nvl(substr('STATUS', 1, 20), ''), 20, ' ') ||
                        rpad(nvl(substr('ERROR DESC', 1, 80), ''), 80, ' '));
      fnd_file.put_line(fnd_file.output,
                        rpad(nvl(substr('-----------------------', 1, 20),
                                 ''),
                             20,
                             ' ') ||
                        rpad(nvl(substr('-----------------------', 1, 20),
                                 ''),
                             20,
                             ' ') ||
                        rpad(nvl(substr('------------------------', 1, 20),
                                 ''),
                             20,
                             ' ') ||
                        rpad(nvl(substr('------------------------', 1, 80),
                                 ''),
                             80,
                             ' '));

      FOR cur_ap_error_rec IN cur_ap_error LOOP

        fnd_file.put_line(fnd_file.output,
                          rpad(nvl(substr(cur_ap_error_rec.invoice_num,
                                          1,
                                          20),
                                   ''),
                               20,
                               ' ') ||
                          rpad(nvl(substr(cur_ap_error_rec.status, 1, 20),
                                   ''),
                               20,
                               ' ') || rpad(nvl(substr(cur_ap_error_rec.error_msg,
                                                       1,
                                                       480),
                                                ''),
                                            480,
                                            ' '));

      END LOOP;
      fnd_file.put_line(fnd_file.output, '         ');
      fnd_file.put_line(fnd_file.output, '         ');
      fnd_file.put_line(fnd_file.output, '         ');
      fnd_file.put_line(fnd_file.output, '         ');

      fnd_file.put_line(fnd_file.output,
                        '     *****End Of The Report for Account Payables********');

      SELECT COUNT(*)
        INTO l_v_ap_total
        FROM ttec_ap_invoices_stg
       WHERE status = 'V';

      fnd_file.new_line(fnd_file.log, 2);
      fnd_file.put_line(fnd_file.log,
                        to_char(SYSDATE, 'dd-Mon-yyyy hh24:mi:ss') || '   ' ||
                        'Total Number of records Errored out are   :' ||
                        l_e_ap_total);

      fnd_file.put_line(fnd_file.log,
                        to_char(SYSDATE, 'dd-Mon-yyyy hh24:mi:ss') || '   ' ||
                        'Total Number of records Processed are     :' ||
                        l_v_ap_total);

    ELSE
      fnd_file.put_line(fnd_file.log,
                        to_char(SYSDATE, 'dd-Mon-yyyy hh24:mi:ss') || '   ' ||
                        'Error in the output report1 ' || SQLERRM);
    END IF;

    -- Fetching the error records of LINES

  EXCEPTION
    WHEN OTHERS THEN
      fnd_file.put_line(fnd_file.log,
                        to_char(SYSDATE, 'dd-Mon-yyyy hh24:mi:ss') || '   ' ||
                        'Error in the output report ' || SQLERRM);

  END ttec_ap_out_report;


  ------------#########---------------
  -- Validation Procedures---------

  -- po lookup code
  PROCEDURE chk_po_lookup_codes(p_lookup_type VARCHAR2,
                                p_lookup_code VARCHAR2,
                                p_err_msg     OUT VARCHAR2) AS
    l_lookup_code VARCHAR2(100);
  BEGIN

    l_lookup_code := NULL;

    SELECT lookup_code
      INTO l_lookup_code
      FROM apps.po_lookup_codes
     WHERE lookup_type = p_lookup_type
       AND lookup_code = p_lookup_code;

    IF l_lookup_code IS NOT NULL THEN
      log('Look up Code: ' || l_lookup_code);

      p_err_msg := NULL;

    ELSE
      log('No value matcing for Look up Code- ' || p_lookup_code);

      p_err_msg := 'No value matching for Look up Code- ' || p_lookup_code ||
                   ' for the given Look up Type- ' || p_lookup_type;

    END IF;

  EXCEPTION
    WHEN OTHERS THEN
      show_sql_err;
      p_err_msg := 'Excep.1 ' || 'Lookup Code: ' || p_lookup_code ||
                   ' Does Not Exist for Lookup Type: ' || p_lookup_type;
  END chk_po_lookup_codes;

  ---------------------------------------------------------
  ---------------------------------------------------------

  -- ap lookup code-----
  PROCEDURE chk_ap_lookup_codes(p_lookup_type VARCHAR2,
                                p_lookup_code VARCHAR2,
                                p_err_msg     OUT VARCHAR2) AS
    l_lookup_code VARCHAR2(100);
  BEGIN

    l_lookup_code := NULL;

    SELECT lookup_code
      INTO l_lookup_code
      FROM apps.ap_lookup_codes
     WHERE lookup_type = p_lookup_type
       AND lookup_code = p_lookup_code;

    IF l_lookup_code IS NOT NULL THEN
      log('Look up Code: ' || l_lookup_code);

      p_err_msg := NULL;

    ELSE
      log('No value matching for Look up Code- ' || p_lookup_code);

      p_err_msg := 'No value matching for Look up Code- ' || p_lookup_code ||
                   ' for the given Look up Type- ' || p_lookup_type;

    END IF;

  EXCEPTION
    WHEN OTHERS THEN
      show_sql_err;
      p_err_msg := 'Excep.2 ' || 'Lookup Code: ' || p_lookup_code ||
                   ' Does Not Exist for Lookup Type: ' || p_lookup_type;
  END chk_ap_lookup_codes;

  ---------------------------------------------------------
  ---------------------------------------------------------

  -- Invoice already existing
  PROCEDURE chk_invoice_number(p_inv_number  VARCHAR2,
                               p_vendor_name VARCHAR2,
                               p_ou_name     VARCHAR2,
                               p_err_msg     OUT VARCHAR2) AS
    l_cnt NUMBER;
  BEGIN

    SELECT COUNT(1)
      INTO l_cnt
      FROM ap_invoices_all aia,
           po_vendors      pv,
           --po_vendor_sites_all pvs,
           hr_operating_units hou
     WHERE aia.invoice_num = p_inv_number
       AND pv.vendor_name = p_vendor_name
       AND hou.NAME = p_ou_name
       AND aia.vendor_id = pv.vendor_id
          --and pv.vendor_id = pvs.vendor_id
       AND org_id = hou.organization_id;

    IF l_cnt > 0 THEN
      p_err_msg := 'Invoice already exists - ' || p_inv_number;
      log('Invoice :' || p_inv_number || ' already created');
    ELSE
      p_err_msg := NULL;

    END IF;

  EXCEPTION
    WHEN OTHERS THEN
      show_sql_err;
      p_err_msg := 'Excep.3 ' || 'Invoice Num Exception.' || p_inv_number;

  END chk_invoice_number;

  ---------------------------------------------------------
  ---------------------------------------------------------

  -- Terms Name
  PROCEDURE chk_term_name(p_term_name VARCHAR2,
                          p_term_id   OUT NUMBER,
                          p_err_msg   OUT VARCHAR2) AS
  BEGIN

    SELECT term_id INTO p_term_id FROM ap_terms WHERE NAME = p_term_name;

    IF p_term_name IS NOT NULL THEN

      IF p_term_id IS NULL THEN
        log('Term Name: ' || p_term_name || ' is not valid');
        p_err_msg := 'Term Name: ' || p_term_name || ' is not valid';
      ELSE
        log('Term ID: ' || p_term_id || ' for Term Name: ' || p_term_name);
        p_err_msg := '';
      END IF;

    END IF;

  EXCEPTION
    WHEN OTHERS THEN
      show_sql_err;
      p_err_msg := 'Excep.6 ' || 'Term Does Not Exist' || p_term_name;
  END chk_term_name;

  ---------------------------------------------------------
  ---------------------------------------------------------

  PROCEDURE tax_code(p_tax_code VARCHAR2,
                     p_tax_id   OUT NUMBER,
                     p_err_msg  OUT VARCHAR2) AS
  BEGIN

    SELECT tax_id
      INTO p_tax_id
      FROM ap_tax_codes_all
     WHERE NAME = p_tax_code;

    IF p_tax_code IS NOT NULL THEN

      IF p_tax_id IS NULL THEN
        log('Tax Code: ' || p_tax_code || ' is not valid');
        p_err_msg := 'Tax Code: ' || p_tax_code || ' is not valid';
      ELSE
        log('Tax ID: ' || p_tax_id || ' for Tax Code: ' || p_tax_code);
        p_err_msg := '';
      END IF;

    END IF;

  EXCEPTION
    WHEN OTHERS THEN
      show_sql_err;
      p_err_msg := 'Excep.7 ' || 'Tax Code Not Exists' || p_tax_code;
  END tax_code;

  ---------------------------------------------------------
  ---------------------------------------------------------

  -- Ou Name
  PROCEDURE chk_ou_name(p_org_name VARCHAR2,
                        p_org_id   OUT NUMBER,
                        p_err_msg  OUT VARCHAR2) AS
  BEGIN

    SELECT organization_id
      INTO p_org_id
      FROM hr_operating_units
     WHERE NAME = p_org_name;

    IF p_org_name IS NOT NULL THEN

      IF p_org_id IS NULL THEN
        log('OU Name: ' || p_org_name || ' is not valid');
        p_err_msg := 'OU Name: ' || p_org_name || ' is not valid';
      ELSE
        log('Org ID: ' || p_org_id || ' for OU Name: ' || p_org_name);
        p_err_msg := '';
      END IF;

    END IF;

  EXCEPTION
    WHEN OTHERS THEN
      show_sql_err;
      p_err_msg := 'Excep.8 ' || 'Operating Unit Not Found...' ||
                   p_org_name;
  END chk_ou_name;

  -- Ou Name

  ---------------------------------------------------------
  ---------------------------------------------------------

  --- Vendor Name and Vendor Site

  PROCEDURE chk_vendor_name_site(p_leg_vend_num     IN VARCHAR2,
                                 p_old_vend_num     IN VARCHAR2,
                                 p_old_vend_site    IN VARCHAR2,
                                 p_ou_name          IN VARCHAR2,
                                 x_new_vend_id      OUT NUMBER,
                                 x_new_vend_site_id OUT NUMBER,
                                 x_err_msg          OUT VARCHAR2) AS
    l_err_msg VARCHAR2(500);
  BEGIN

    l_err_msg := NULL;

    BEGIN

      SELECT vendor_id
        INTO x_new_vend_id
        FROM po_vendors
       WHERE vendor_name = p_old_vend_num
         AND nvl(end_date_active, SYSDATE) >= SYSDATE;

      IF x_new_vend_id IS NULL THEN
        log('Vendor Name: ' || p_old_vend_num || ' is not valid');
        l_err_msg := l_err_msg || ' Vendor Name: ' || p_old_vend_num ||
                     ' is not valid';
      ELSE
        log('Vendor ID: ' || x_new_vend_id || ' for Vendor Name: ' ||
            p_old_vend_num);
        l_err_msg := '';
      END IF;

    EXCEPTION
      WHEN OTHERS THEN

        log('INSIDE EXCEPTION*****');

        IF x_new_vend_id IS NULL THEN
          SELECT pv.vendor_id
            INTO x_new_vend_id
            FROM po_vendors pv, ttec_supplier_org_mapping smap
           WHERE trim(pv.vendor_name) = trim(smap.vendor_name)
             AND smap.legacy_vendor_number = p_leg_vend_num --'4637'--
             AND nvl(pv.end_date_active, SYSDATE) >= SYSDATE;
        END IF;

        log('Vendor ID: ' || x_new_vend_id ||
            ' EXCEPTION for Vendor Name: ' || p_old_vend_num);
           END;

    IF p_old_vend_site IS NOT NULL AND x_new_vend_id IS NOT NULL THEN



      BEGIN

        SELECT vendor_site_id
          INTO x_new_vend_site_id
          FROM po_vendor_sites_all pos, hr_operating_units hou
         WHERE pos.vendor_id = x_new_vend_id
           AND pos.vendor_site_code = p_old_vend_site
           AND pos.org_id = hou.organization_id
           AND hou.NAME = p_ou_name
           AND nvl(pos.inactive_date, SYSDATE) >= SYSDATE;

        IF x_new_vend_site_id IS NULL THEN
          log('Vendor Site: ' || p_old_vend_site || ' is not valid');
          l_err_msg := l_err_msg || ' Vendor Site: ' || p_old_vend_site ||
                       ' is not valid';
        ELSE
          log('Vendor Site ID: ' || x_new_vend_site_id ||
              ' for Vendor Name: ' || p_old_vend_num ||
              ' for Vendor Site: ' || p_old_vend_site || ' for OU Name: ' ||
              p_ou_name);
          l_err_msg := '';
        END IF;

      EXCEPTION
        WHEN OTHERS THEN
          show_sql_err;
          l_err_msg := l_err_msg || ' Excep.9.1 ' ||
                       'Vendor Site Code Not Found...' || p_old_vend_site;
      END;

    END IF;

    x_err_msg := l_err_msg;

  END chk_vendor_name_site;

  --- Vendor Name and Vendor Site\

  ---------------------------------------------------------
  ---------------------------------------------------------

  PROCEDURE chk_type_1099(p_type_1099 VARCHAR2, p_err_msg OUT VARCHAR2) AS

    ln_cnt NUMBER;

  BEGIN

    IF p_type_1099 IS NOT NULL THEN

      SELECT COUNT(1)
        INTO ln_cnt
        --FROM ap.ap_income_tax_types			-- Commented code by IXPRAVEEN-ARGANO,09-May-2023
		 FROM apps.ap_income_tax_types			--  code Added by IXPRAVEEN-ARGANO,09-May-2023
       WHERE income_tax_type = p_type_1099;

      IF ln_cnt < 1 THEN
        log('Type-1099: ' || p_type_1099 || ' is not valid');
        p_err_msg := 'Type-1099: ' || p_type_1099 || ' is not valid';
      ELSE
        log('TYPE-1099: ' || p_type_1099);
        p_err_msg := '';
      END IF;

    END IF;

  EXCEPTION
    WHEN OTHERS THEN
      show_sql_err;
      p_err_msg := 'Excep.10 ' || 'Type-1099 Not Found...' || p_type_1099;
  END chk_type_1099;

  ---------------------------------------------------------
  ---------------------------------------------------------

  -- code combination
  PROCEDURE chk_code_combination(p_segments     VARCHAR2,
                                 p_account_type VARCHAR2,
                                 p_err_msg      OUT VARCHAR2) AS
    l_count NUMBER;
  BEGIN

    IF p_segments IS NOT NULL AND p_account_type IS NOT NULL THEN

      SELECT COUNT(1)
        INTO l_count
        FROM apps.gl_code_combinations_kfv
       WHERE concatenated_segments = p_segments;

      IF l_count < 1 THEN
        log('The derived Code Combination-- ' || p_segments ||
            ' is invalid for ' || p_account_type);

        p_err_msg := 'The derived Code Combination-- ' || p_segments ||
                     ' is invalid for ' || p_account_type;

      ELSE
        log('Derived Code Combination is: ' || p_segments ||
            ' for Account - ' || p_account_type);

        p_err_msg := NULL;

      END IF;

    END IF;

  EXCEPTION
    WHEN OTHERS THEN
      show_sql_err;
      p_err_msg := 'Excep.11 ' || 'Derived Code Combination-- ' ||
                   p_segments || ' is invalid for ' || p_account_type;
  END chk_code_combination;

  ------------#########---------------
  ------End of Validation Procedures---------

  ---------------------------------------------------------
  ---------------------------------------------------------

  --Validation-------

  PROCEDURE validate_main(p_errbuff OUT VARCHAR2,
                          p_retcode OUT VARCHAR2,
                          p_org_id  IN NUMBER) AS

    -----Lines all incl headers
    CURSOR c_inv IS
      SELECT legacy_invoice_id,
             legacy_invoice_dist_id,
             invoice_num,
             invoice_type_lookup_code,
             invoice_date,
             vendor_name,
             legacy_vendor_number,
             vendor_site_code,
             invoice_amount,
             invoice_currency,
             exchange_rate_type,
             exchange_date,
             description,
             approval_flag,
             legacy_po_number,
             batch_source,
             old_batch_source,
             pay_group,
             old_pay_group,
             pay_code_combination,
             pay_acc_seg1,
             pay_acc_seg2,
             pay_acc_seg3,
             pay_acc_seg4,
             pay_acc_seg5,
             pay_acc_seg6,
             pay_acc_seg7,
             pay_acc_seg8,
             pay_acc_seg9,
             pay_acc_seg10,
             old_pay_acc_seg1,
             old_pay_acc_seg2,
             old_pay_acc_seg3,
             old_pay_acc_seg4,
             old_pay_acc_seg5,
             old_pay_acc_seg6,
             old_pay_acc_seg7,
             old_pay_acc_seg8,
             old_pay_acc_seg9,
             old_pay_acc_seg10,
             operating_unit,
             old_operating_unit,
             org_id,
             term_name,
             old_term_name,
             terms_date,
             line_type_lookup_code,
             exchange_rate,
             payment_status_flag,
             ERROR_CODE,
             error_msg,
             status,
             new_vendor_id,
             new_vendor_site_id,
             batch_id,
             distribution_line_number,
             dist_code_combination,
             dist_acc_seg1,
             dist_acc_seg2,
             dist_acc_seg3,
             dist_acc_seg4,
             dist_acc_seg5,
             dist_acc_seg6,
             dist_acc_seg7,
             dist_acc_seg8,
             dist_acc_seg9,
             dist_acc_seg10,
             old_dist_acc_seg1,
             old_dist_acc_seg2,
             old_dist_acc_seg3,
             old_dist_acc_seg4,
             old_dist_acc_seg5,
             old_dist_acc_seg6,
             old_dist_acc_seg7,
             old_dist_acc_seg8,
             old_dist_acc_seg9,
             old_dist_acc_seg10,
             line_amount,
             dist_description,
             type_1099,
             income_tax,
             last_update_date,
             last_updated_by,
             creation_date,
             created_by,
             last_update_login,
             request_id,
             program_application_id,
             program_id,
             program_update_date,
             attribute1,
             attribute2,
             attribute3,
             attribute4,
             attribute5,
             attribute6,
             attribute7,
             attribute8,
             attribute9,
             attribute10,
             new_pay_ccid,
             new_dist_ccid,
             new_bank_acct_id
        FROM ttec_ap_invoices_stg
       WHERE 1 = 1
         AND status = 'N'
         AND org_id = p_org_id;

    v_error_msg             VARCHAR2(4000);
    v_error_flag            VARCHAR2(1) := 'N';
    v_temp_text             VARCHAR2(100);
    v_temp_num              NUMBER;
    v_org_id                NUMBER;
    v_err_msg_concat        VARCHAR2(4000);
    v_new_vendor_id         NUMBER;
    v_new_vendor_site_id    NUMBER;
    v_gl_code_comb_segments VARCHAR2(1000);
    v_gl_sob_id             NUMBER;
    v_pay_segments          VARCHAR2(1000);
    v_dist_segments         VARCHAR2(1000);
    v_bank_count            NUMBER;

  BEGIN

    FOR v_inv IN c_inv LOOP

      BEGIN
        --begin inv validations

        log('Inside validation for legacy invoice id :' ||
            v_inv.legacy_invoice_id);

        v_error_msg          := NULL;
        v_error_flag         := 'N';
        v_temp_text          := NULL;
        v_temp_num           := NULL;
        v_org_id             := NULL;
        v_err_msg_concat     := NULL;
        v_new_vendor_id      := NULL;
        v_new_vendor_site_id := NULL;
        v_bank_count         := NULL;

        ----------------------------------------------------------------------
        -- Validation for INVOICE_TYPE_LOOKUP_CODE......Start
        ----------------------------------------------------------------------
        IF v_inv.invoice_type_lookup_code IS NOT NULL THEN
          chk_ap_lookup_codes('INVOICE TYPE',
                              v_inv.invoice_type_lookup_code,
                              v_error_msg);
          IF v_error_msg IS NOT NULL THEN
            v_error_flag     := 'Y';
            v_err_msg_concat := v_err_msg_concat || '***' || v_error_msg;

            log('error in lookup type - invoice_type : ' ||
                v_inv.invoice_type_lookup_code || ' * ' || v_error_msg);
          END IF;
        END IF;

        ----------------------------------------------------------------------
        -- Validation for INVOICE_TYPE_LOOKUP_CODE......End
        ----------------------------------------------------------------------

        ----------------------------------------------------------------------
        -- Validation for OPERATING_UNIT ......Start
        ----------------------------------------------------------------------
        v_error_msg := NULL;

        chk_ou_name(v_inv.operating_unit, v_org_id, v_error_msg);

        IF v_error_msg IS NOT NULL THEN
          v_error_flag     := 'Y';
          v_err_msg_concat := v_err_msg_concat || '***' || v_error_msg;

          log(' error in OU NAME : ' || v_inv.operating_unit || ' * ' ||
              v_error_msg);
        END IF;
        ----------------------------------------------------------------------
        -- Validation for OPERATING_UNIT ......End
        ----------------------------------------------------------------------

        ----------------------------------------------------------------------
        -- Validation for BATCH_SOURCE ......Start
        ----------------------------------------------------------------------
        IF v_inv.batch_source IS NOT NULL THEN

          v_error_msg := NULL;

          chk_ap_lookup_codes('SOURCE', v_inv.batch_source, v_error_msg);

          IF v_error_msg IS NOT NULL THEN
            v_error_flag     := 'Y';
            v_err_msg_concat := v_err_msg_concat || '***' || v_error_msg;

            log('error in lookup type source : ' || v_inv.batch_source ||
                ' * ' || v_error_msg);
          END IF;
        END IF;

        ----------------------------------------------------------------------
        -- Validation for BATCH_SOURCE ......End
        ----------------------------------------------------------------------

        ----------------------------------------------------------------------
        -- Validation for VENDOR_NAME and VENDOR_SITE ......Start
        ----------------------------------------------------------------------
        v_error_msg := NULL;

        chk_vendor_name_site(p_leg_vend_num     => v_inv.legacy_vendor_number,
                             p_old_vend_num     => v_inv.vendor_name,
                             p_old_vend_site    => v_inv.vendor_site_code,
                             p_ou_name          => v_inv.operating_unit,
                             x_new_vend_id      => v_new_vendor_id,
                             x_new_vend_site_id => v_new_vendor_site_id,
                             x_err_msg          => v_error_msg);

        IF v_error_msg IS NOT NULL THEN

          v_error_flag     := 'Y';
          v_err_msg_concat := v_err_msg_concat || '***' || v_error_msg;

        END IF;

        ----------------------------------------------------------------------
        -- Validation for BATCH_SOURCE ......End
        ----------------------------------------------------------------------

        ----------------------------------------------------------------------
        -- Validation for INVOICE_NUMBER ......Start
        ----------------------------------------------------------------------
        v_error_msg := NULL;

        IF v_inv.invoice_num IS NOT NULL THEN

          chk_invoice_number(v_inv.invoice_num,
                             v_inv.vendor_name,
                             v_inv.operating_unit,
                             v_error_msg);

          IF v_error_msg IS NOT NULL THEN
            v_error_flag     := 'Y';
            v_err_msg_concat := v_err_msg_concat || '***' || v_error_msg;

            log('err -  invoice_number :' || v_inv.invoice_num || ' * ' ||
                v_error_msg);
          END IF;
        ELSE
          log('INVOICE NUM is NULL');
          v_err_msg_concat := v_err_msg_concat || '***' ||
                              'INVOICE NUM is NULL';

        END IF;

        ----------------------------------------------------------------------
        -- Validation for INVOIVE_NUMBER ......End
        ----------------------------------------------------------------------

        ----------------------------------------------------------------------
        -- Validation for TERM_NAME ......Start
        ----------------------------------------------------------------------
        v_error_msg := NULL;

        IF v_inv.term_name IS NOT NULL THEN

          v_error_msg := NULL;

          chk_term_name(v_inv.term_name, v_temp_num, v_error_msg);

          IF v_error_msg IS NOT NULL THEN
            v_error_flag := 'Y';

            v_err_msg_concat := v_err_msg_concat || '***' || v_error_msg;

            log(' err payment terms :' || v_inv.term_name || ' * ' ||
                v_error_msg);
          END IF;
        END IF;

        ----------------------------------------------------------------------
        -- Validation for TERM_NAME ......End
        ----------------------------------------------------------------------

        ----------------------------------------------------------------------
        -- Validation for LINE_TYPE_LOOKUP_CODE ......Start
        ----------------------------------------------------------------------
        v_error_msg := NULL;

        IF v_inv.line_type_lookup_code IS NOT NULL THEN

          chk_ap_lookup_codes('INVOICE DISTRIBUTION TYPE',
                              v_inv.line_type_lookup_code,
                              v_error_msg);

          IF v_error_msg IS NOT NULL THEN
            v_error_flag := 'Y';

            v_err_msg_concat := v_err_msg_concat || '***' || v_error_msg;

            log(' error at lookup type invoice distribution type : ' ||
                v_inv.line_type_lookup_code || ' * ' || v_error_msg);
          END IF;

        END IF;

        ----------------------------------------------------------------------
        -- Validation for LINE_TYPE_LOOKUP_CODE ......End
        ----------------------------------------------------------------------

        ----------------------------------------------------------------------
        -- Validation for PAY_GROUP ......Start
        ----------------------------------------------------------------------

        IF v_inv.pay_group IS NOT NULL THEN

          v_error_msg := NULL;

          chk_po_lookup_codes('PAY GROUP', v_inv.pay_group, v_error_msg);

          IF v_error_msg IS NOT NULL THEN

            v_error_flag := 'Y';

            v_err_msg_concat := v_err_msg_concat || '***' || v_error_msg;

            log(' error at lookup type pay_group : ' || v_inv.pay_group ||
                ' * ' || v_error_msg);
          END IF;

        END IF;

        ----------------------------------------------------------------------
        -- Validation for PAY_GROUP ......End
        ----------------------------------------------------------------------

        ----------------------------------------------------------------------
        -- Validation for TYPE_1099 ......Start
        ----------------------------------------------------------------------

        IF v_inv.type_1099 IS NOT NULL THEN

          v_error_msg := NULL;

          chk_type_1099(v_inv.type_1099, v_error_msg);

          IF v_error_msg IS NOT NULL THEN

            v_error_flag     := 'Y';
            v_err_msg_concat := v_err_msg_concat || '***' || v_error_msg;

            log(' error at type_1099 : ' || v_inv.type_1099 || ' * ' ||
                v_error_msg);

          END IF;

        END IF;

        ----------------------------------------------------------------------
        -- Validation for TYPE_1099 ......End
        ----------------------------------------------------------------------

        v_temp_num              := NULL;
        v_error_msg             := NULL;
        v_gl_code_comb_segments := NULL;
        v_gl_sob_id             := NULL;

        BEGIN

          SELECT set_of_books_id
            INTO v_gl_sob_id
            FROM hr_operating_units
           WHERE organization_id = v_org_id;

        EXCEPTION
          WHEN OTHERS THEN
            log('Excec. Unable to derive SOB ID');
            v_error_flag     := 'Y';
            v_error_msg      := 'Excec. Unable to derive SOB ID';
            v_err_msg_concat := v_err_msg_concat || '***' ||
                                'Excec. Unable to derive SOB ID';

        END;

        ------------Validating Dist Account derivation
        BEGIN
          SELECT (SELECT gcc.concatenated_segments
                    FROM apps.gl_code_combinations_kfv gcc
                   WHERE gcc.code_combination_id =
                         asp.accts_pay_code_combination_id) expense_account
            INTO v_gl_code_comb_segments
            FROM apps.ap_system_parameters_all asp
           WHERE org_id = v_org_id;

        EXCEPTION
          WHEN OTHERS THEN
            log('Excec. Unable to derive dist CCID');
            v_error_flag     := 'Y';
            v_error_msg      := 'Excec. UNABLE to derive dist CCID';
            v_err_msg_concat := v_err_msg_concat || '***' ||
                                'Excec. UNABLE to derive dist CCID';

        END;

        ------------Validating Dist Account derivation ERROR

        v_error_msg := NULL;

      EXCEPTION
        WHEN OTHERS THEN

          v_error_flag     := 'Y';
          v_err_msg_concat := v_err_msg_concat || '***' ||
                              'UNEXPECTED_ERROR';
          show_sql_err;
      END;
      --end inv validations

      IF v_error_flag = 'Y' THEN
        UPDATE ttec_ap_invoices_stg
           SET error_msg          = v_err_msg_concat,
               status             = 'E',
               new_vendor_id      = v_new_vendor_id,
               new_vendor_site_id = v_new_vendor_site_id
         WHERE 1 = 1
           AND legacy_invoice_id = v_inv.legacy_invoice_id
           AND legacy_invoice_dist_id = v_inv.legacy_invoice_dist_id;

      ELSE
        UPDATE ttec_ap_invoices_stg
           SET error_msg          = '',
               status             = 'V',
               new_vendor_id      = v_new_vendor_id,
               new_vendor_site_id = v_new_vendor_site_id
         WHERE 1 = 1
           AND legacy_invoice_id = v_inv.legacy_invoice_id
           AND legacy_invoice_dist_id = v_inv.legacy_invoice_dist_id;

      END IF;

    END LOOP;

    p_retcode := 'S';

  EXCEPTION
    WHEN OTHERS THEN
      log('UNEXPECTED Error in validate_main..');
      log('sql :' || SQLCODE || '->' || SQLERRM);

      p_retcode := 'E';

      show_sql_err;

  END validate_main;

  PROCEDURE load_main(p_errbuff OUT VARCHAR2,
                      p_retcode OUT VARCHAR2,
                      p_org_id  IN NUMBER) AS

    CURSOR c_inv IS
      SELECT DISTINCT legacy_invoice_id,
                      invoice_num,
                      invoice_type_lookup_code,
                      invoice_date,
                      vendor_name,
                      vendor_site_code,
                      invoice_amount,
                      invoice_currency,
                      exchange_rate_type,
                      exchange_date,
                      description,
                      approval_flag,
                      --LEGACY_PO_NUMBER,
                      batch_source,
                      old_batch_source,
                      pay_group,
                      old_pay_group,
                      pay_code_combination,
                      pay_acc_seg1,
                      pay_acc_seg2,
                      pay_acc_seg3,
                      pay_acc_seg4,
                      pay_acc_seg5,
                      pay_acc_seg6,
                      pay_acc_seg7,
                      pay_acc_seg8,
                      pay_acc_seg9,
                      pay_acc_seg10,
                      old_pay_acc_seg1,
                      old_pay_acc_seg2,
                      old_pay_acc_seg3,
                      old_pay_acc_seg4,
                      old_pay_acc_seg5,
                      old_pay_acc_seg6,
                      old_pay_acc_seg7,
                      old_pay_acc_seg8,
                      old_pay_acc_seg9,
                      old_pay_acc_seg10,
                      operating_unit,
                      old_operating_unit,
                      org_id,
                      term_name,
                      old_term_name,
                      terms_date,
                      --LINE_TYPE_LOOKUP_CODE     ,
                      exchange_rate,
                      payment_status_flag,
                      ERROR_CODE,
                      error_msg,
                      status,
                      new_vendor_id,
                      new_vendor_site_id,
                      batch_id,
                      attribute1,
                      attribute2,
                      attribute3,
                      attribute4,
                      attribute5,
                      attribute6,
                      attribute7,
                      attribute8,
                      attribute9,
                      attribute10,
                      new_pay_ccid,
                      new_dist_ccid,
                      new_bank_acct_id
        FROM ttec_ap_invoices_stg
       WHERE status = 'V'
            --AND line_type_lookup_code = 'ITEM'
         AND org_id = p_org_id;

    CURSOR c_dist_inv(p_invoice_id NUMBER) IS
      SELECT DISTINCT legacy_invoice_id,
                      LEGACY_INVOICE_DIST_ID,
                      invoice_num,
                      invoice_type_lookup_code,
                      invoice_date,
                      vendor_name,
                      vendor_site_code,
                      invoice_amount,
                      line_amount, --decode(attribute10, 'OPEN', line_amount, 0) line_amount,
                      invoice_currency,
                      exchange_rate_type,
                      exchange_date,
                      description,
                      approval_flag,
                      --LEGACY_PO_NUMBER,
                      batch_source,
                      old_batch_source,
                      pay_group,
                      old_pay_group,
                      pay_code_combination,
                      pay_acc_seg1,
                      pay_acc_seg2,
                      pay_acc_seg3,
                      pay_acc_seg4,
                      pay_acc_seg5,
                      pay_acc_seg6,
                      pay_acc_seg7,
                      pay_acc_seg8,
                      pay_acc_seg9,
                      pay_acc_seg10,
                      old_pay_acc_seg1,
                      old_pay_acc_seg2,
                      old_pay_acc_seg3,
                      old_pay_acc_seg4,
                      old_pay_acc_seg5,
                      old_pay_acc_seg6,
                      old_pay_acc_seg7,
                      old_pay_acc_seg8,
                      old_pay_acc_seg9,
                      old_pay_acc_seg10,
                      operating_unit,
                      old_operating_unit,
                      org_id,
                      term_name,
                      old_term_name,
                      terms_date,
                      line_type_lookup_code,
                      exchange_rate,
                      payment_status_flag,
                      ERROR_CODE,
                      error_msg,
                      status,
                      new_vendor_id,
                      new_vendor_site_id,
                      batch_id,
                      distribution_line_number distribution_line_number,
                      --decode(attribute10,
                      --      'OPEN',
                      --      distribution_line_number,
                      --     1) distribution_line_number,
                      type_1099,
                      income_tax,
                      attribute10,
                      new_pay_ccid,
                      new_dist_ccid,
                      dist_description
        FROM ttec_ap_invoices_stg
       WHERE status = 'V'
            --AND line_type_lookup_code = 'ITEM'
         AND legacy_invoice_id = p_invoice_id
         AND org_id = p_org_id;

    v_ap_inv_line_rec ap_invoice_lines_interface%ROWTYPE;
    v_ap_inv_hdr_rec  ap_invoices_interface%ROWTYPE;

    v_null_ap_inv_line_rec ap_invoice_lines_interface%ROWTYPE;
    v_null_ap_inv_hdr_rec  ap_invoices_interface%ROWTYPE;

    v_error_msg              VARCHAR2(2000);
    v_error_flag             VARCHAR2(2000);
    v_temp_num               NUMBER;
    v_org_id                 NUMBER;
    l_gl_dist_ccid           NUMBER;
    v_gl_code_comb_segments  VARCHAR2(1000);
    v_gl_sob_id              NUMBER;
    v_liability_ccid         NUMBER;
    lc_vendor_type           VARCHAR2(200);
    lc_concatenated_segments VARCHAR2(500);
    v_acct_date              DATE;
    v_line_amount            NUMBER;
    v_tax_amount             NUMBER;
    v_dist_line_num          NUMBER;

  BEGIN
    FOR v_inv IN c_inv LOOP

      v_ap_inv_line_rec := v_null_ap_inv_line_rec;
      v_ap_inv_hdr_rec  := v_null_ap_inv_hdr_rec;

      v_error_msg  := NULL;
      v_error_flag := NULL;
      v_temp_num   := NULL;
      v_org_id     := NULL;
      v_gl_sob_id  := NULL;

      log(' INSIDE LOAD MAIN FOR LOOP ');

      BEGIN

        chk_ou_name(v_inv.operating_unit,
                    v_ap_inv_line_rec.org_id,
                    v_error_msg);

        log(' ORG ' || v_ap_inv_line_rec.org_id);

        v_ap_inv_hdr_rec.org_id := v_ap_inv_line_rec.org_id;

        SELECT set_of_books_id
          INTO v_gl_sob_id
          FROM apps.hr_operating_units
         WHERE organization_id = v_ap_inv_line_rec.org_id;

        v_gl_code_comb_segments := NULL;
        l_gl_dist_ccid          := NULL;

        BEGIN
          SELECT (SELECT gcc.concatenated_segments
                    FROM apps.gl_code_combinations_kfv gcc
                   WHERE gcc.code_combination_id =
                         asp.accts_pay_code_combination_id) expense_account
            INTO v_gl_code_comb_segments
            --FROM ap.ap_system_parameters_all asp --where org_id = aii.org_id		-- Commented code by IXPRAVEEN-ARGANO,09-May-2023
			FROM apps.ap_system_parameters_all asp --where org_id = aii.org_id		--  code Added by IXPRAVEEN-ARGANO,09-May-2023
           WHERE org_id = v_ap_inv_line_rec.org_id;

        EXCEPTION
          WHEN OTHERS THEN
            log('Unable to derive dist CCID');

        END;

        log('gl dist code ' || v_gl_code_comb_segments);

        BEGIN
          SELECT MAX(end_date)
            INTO v_acct_date
           -- FROM gl.gl_period_statuses			-- Commented code by IXPRAVEEN-ARGANO,09-May-2023
			FROM apps.gl_period_statuses				--  code Added by IXPRAVEEN-ARGANO,09-May-2023
           WHERE closing_status = 'O'
             AND application_id = 200
             AND set_of_books_id IN
                 (SELECT set_of_books_id
                   -- FROM ar.ar_system_parameters_all				-- Commented code by IXPRAVEEN-ARGANO,09-May-2023
					FROM apps.ar_system_parameters_all				--  code Added by IXPRAVEEN-ARGANO,09-May-2023
                   WHERE org_id = p_org_id);

        EXCEPTION
          WHEN OTHERS THEN
            log('Unable to derive the accounting date');
        END;

        BEGIN
          SELECT gcc.code_combination_id
            INTO l_gl_dist_ccid
            FROM apps.gl_code_combinations_kfv gcc
           WHERE gcc.concatenated_segments = v_gl_code_comb_segments;

        EXCEPTION
          WHEN OTHERS THEN
            log('Unable to derive dist CCID');

        END;

        log('gl dist ccid ' || l_gl_dist_ccid);


        ------liability ccid from supplier sites
        BEGIN

          v_liability_ccid := NULL;

          SELECT accts_pay_code_combination_id
            INTO v_liability_ccid
            FROM po_vendor_sites_all
           WHERE vendor_site_id = v_inv.new_vendor_site_id;
          --

        EXCEPTION
          WHEN OTHERS THEN
            show_sql_err;
            log('Error in Retrieving Interface liability ID ' || SQLERRM);
        END;

        ------

        BEGIN
          SELECT ap.ap_invoices_interface_s.NEXTVAL
            INTO v_ap_inv_line_rec.invoice_id
            FROM dual;
          v_ap_inv_hdr_rec.invoice_id := v_ap_inv_line_rec.invoice_id;
        EXCEPTION
          WHEN OTHERS THEN
            show_sql_err;
            log('Error in Retrieving Interface Invoice ID ' || SQLERRM);
        END;

        v_ap_inv_hdr_rec.vendor_id      := v_inv.new_vendor_id;
        v_ap_inv_hdr_rec.vendor_site_id := v_inv.new_vendor_site_id;

        -----------------ap invoice headers
        v_ap_inv_hdr_rec.invoice_num              := v_inv.invoice_num;
        v_ap_inv_hdr_rec.invoice_date             := v_inv.invoice_date;
        v_ap_inv_hdr_rec.invoice_type_lookup_code := v_inv.invoice_type_lookup_code;
        v_ap_inv_hdr_rec.invoice_amount           := v_inv.invoice_amount;

        v_ap_inv_hdr_rec.invoice_currency_code         := v_inv.invoice_currency;
        v_ap_inv_hdr_rec.exchange_rate                 := v_inv.exchange_rate;
        v_ap_inv_hdr_rec.exchange_rate_type            := v_inv.exchange_rate_type;
        v_ap_inv_hdr_rec.exchange_date                 := v_inv.exchange_date;
        v_ap_inv_hdr_rec.terms_name                    := v_inv.term_name;
        v_ap_inv_hdr_rec.description                   := v_inv.description;
        v_ap_inv_hdr_rec.SOURCE                        := v_inv.batch_source;
        v_ap_inv_hdr_rec.pay_group_lookup_code         := v_inv.pay_group;
        v_ap_inv_hdr_rec.accts_pay_code_combination_id := v_inv.new_pay_ccid;
        v_ap_inv_hdr_rec.terms_date                    := v_inv.terms_date;
        ----
        v_ap_inv_hdr_rec.attribute9               := v_inv.attribute9;
        v_ap_inv_hdr_rec.attribute6               := v_inv.attribute6;
        v_ap_inv_hdr_rec.attribute13              := v_inv.vendor_site_code;
        v_ap_inv_hdr_rec.external_bank_account_id := v_inv.new_bank_acct_id;

        BEGIN



          log(
              --'Inserting for Ledger Id '||v_ap_inv_hdr_rec.legal_entity_id||
              'Inserting for Invoice Num ' || v_ap_inv_hdr_rec.invoice_num ||
              ' Vendor id ' || v_ap_inv_hdr_rec.vendor_id ||
              ' Vendor Site Id ' || v_ap_inv_hdr_rec.vendor_site_id);

          ----- Inserting into the Interface Tables
          --INSERT INTO ap.ap_invoices_interface		-- Commented code by IXPRAVEEN-ARGANO,09-May-2023
		  INSERT INTO apps.ap_invoices_interface		--  code Added by IXPRAVEEN-ARGANO,09-May-2023
            (invoice_id,
             invoice_num,
             invoice_date,
             invoice_type_lookup_code,
             invoice_amount,
             vendor_id ,
             vendor_site_id ,
             invoice_currency_code,
             exchange_rate,
             exchange_rate_type,
             exchange_date,
             terms_id,
             terms_name,
             description,
             SOURCE,
             org_id,
             pay_group_lookup_code,
             accts_pay_code_combination_id,
             terms_date,
             gl_date,
             attribute9,
             attribute6,
             external_bank_account_id,
             request_id,
             last_update_date,
             last_updated_by,
             last_update_login,
             creation_date,
             created_by

             )
          VALUES
            (v_ap_inv_hdr_rec.invoice_id -- invoice_id
            ,
             v_ap_inv_hdr_rec.invoice_num -- invoice_num
            ,
             v_ap_inv_hdr_rec.invoice_date -- invoice_date
            ,
             v_ap_inv_hdr_rec.invoice_type_lookup_code -- invoice_type_lookup_code
            ,
             v_ap_inv_hdr_rec.invoice_amount -- invoice_amount
             ,
             v_ap_inv_hdr_rec.vendor_id,
             v_ap_inv_hdr_rec.vendor_site_id -- VENDOR_SITE_ID
              ,
             v_ap_inv_hdr_rec.invoice_currency_code -- invoice_currency_code
            ,
             v_ap_inv_hdr_rec.exchange_rate -- EXCHANGE_RATE
            ,
             decode(v_ap_inv_hdr_rec.exchange_rate,
                    nvl(v_ap_inv_hdr_rec.exchange_rate, '1230123'),
                    'User',
                    v_ap_inv_hdr_rec.exchange_rate_type)
             -- EXCHANGE_RATE_TYPE
            ,
             v_ap_inv_hdr_rec.exchange_date -- EXCHANGE_DATE
            ,
             v_ap_inv_hdr_rec.terms_id -- TERMS_ID
            ,
             v_ap_inv_hdr_rec.terms_name -- TERMS_NAME
            ,
             v_ap_inv_hdr_rec.description -- DESCRIPTION
            ,
             v_ap_inv_hdr_rec.SOURCE -- SOURCE
            ,
             v_ap_inv_hdr_rec.org_id -- org_id
            ,
             v_ap_inv_hdr_rec.pay_group_lookup_code -- PAY_GROUP_LOOKUP_CODE
            ,
             v_ap_inv_hdr_rec.accts_pay_code_combination_id -- ACCTS_PAY_CODE_COMBINATION_ID
            ,
             v_ap_inv_hdr_rec.terms_date -- TERMS_DATE

            ,
             --  SYSDATE -- CREATION_DATE
             --,
             v_acct_date,--g_gl_date, -- GL_DATE
             --,
             v_ap_inv_hdr_rec.attribute9, -- ATTRIBUTE11
             --,
             v_ap_inv_hdr_rec.attribute6, -- ATTRIBUTE12
             --,
             -- v_ap_inv_hdr_rec.attribute13 -- ATTRIBUTE13,
             v_ap_inv_hdr_rec.external_bank_account_id,
             g_request_id,
             SYSDATE,
             g_user_id,
             g_login_id,
             SYSDATE,
             g_user_id

             );
        EXCEPTION
          WHEN OTHERS THEN
            show_sql_err;
            log('Error in inserting into ap_invoices_interface');
            v_error_msg := SQLERRM;

            v_error_flag := 'Y';
        END;

        -------------Insert AP Invoice Lines-----------------
        FOR v_dist_inv IN c_dist_inv(v_inv.legacy_invoice_id) LOOP

          BEGIN

            BEGIN

              v_tax_amount := 0;

              SELECT SUM(nvl(stg.line_amount, 0))
                INTO v_tax_amount
                FROM ttec_ap_invoices_stg stg
               WHERE 1 = 1
                 AND stg.line_type_lookup_code = 'TAX'
                 AND stg.legacy_invoice_id = v_inv.legacy_invoice_id;
              --  AND stg.status = 'V';
              log('TAX AMOUNT  IS' || v_tax_amount);

            EXCEPTION
              WHEN OTHERS THEN

                v_tax_amount := 0;

                show_sql_err;
                log(v_inv.invoice_num ||
                    ' Error in summing the Tax amount ' || SQLERRM);
                v_error_msg := SQLERRM;

                v_error_flag := 'Y';
            END;

            BEGIN

              v_dist_line_num := NULL;

              SELECT distribution_line_number --MIN(distribution_line_number)
                INTO v_dist_line_num
                FROM ttec_ap_invoices_stg
               WHERE 1 = 1
                 AND legacy_invoice_id = v_inv.legacy_invoice_id
                 and legacy_invoice_dist_id = v_dist_inv.LEGACY_INVOICE_DIST_ID ;
              -- AND line_type_lookup_code = 'ITEM';
              --AND status = 'V';

              log(' LINE NUMBER  IS' || v_dist_line_num);

            EXCEPTION
              WHEN OTHERS THEN
                show_sql_err;
                log(v_inv.invoice_num ||
                    ' Error in fetching the min. dist. line number ' ||
                    SQLERRM);
                v_error_msg := SQLERRM;

                v_error_flag := 'Y';
            END;

            v_line_amount := NULL;

            IF v_dist_inv.attribute10 = 'OPEN' AND
               v_dist_inv.distribution_line_number = v_dist_line_num THEN

              BEGIN

                SELECT (stg.line_amount + v_tax_amount)
                  INTO v_line_amount
                  FROM ttec_ap_invoices_stg stg
                 WHERE 1 = 1
                      -- AND stg.line_type_lookup_code = 'ITEM'
                      --AND rownum = 1
                   AND distribution_line_number = v_dist_line_num
                   AND stg.legacy_invoice_id = v_inv.legacy_invoice_id;
                --AND stg.status = 'V';

                log('total_amount is   IS' || v_line_amount);
              EXCEPTION
                WHEN OTHERS THEN
                  show_sql_err;
                  log(v_inv.invoice_num ||
                      ' Error in adding the Tax amount to Lines ' ||
                      SQLERRM);
                  v_error_msg := SQLERRM;

                  v_error_flag := 'Y';
              END;

            END IF;

            v_ap_inv_line_rec.line_number           := v_dist_inv.distribution_line_number;
            v_ap_inv_line_rec.line_type_lookup_code := v_dist_inv.line_type_lookup_code;
            --Commented to exclude tax amount
            --v_ap_inv_line_rec.amount                := v_dist_inv.line_amount;
            --v_ap_inv_line_rec.amount                := v_dist_inv.invoice_amount;

            IF v_dist_inv.attribute10 = 'PARTIAL_PAID' THEN
              -- v_ap_inv_line_rec.amount := v_dist_inv.invoice_amount;
              v_ap_inv_line_rec.amount := nvl(v_line_amount,
                                              v_dist_inv.line_amount);
            ELSE
              v_ap_inv_line_rec.amount := nvl(v_line_amount,
                                              v_dist_inv.line_amount);

              log('line + tax amount is   IS' || v_line_amount);
              log('amount to be inserted is   IS' ||
                  v_ap_inv_line_rec.amount);

            END IF;

            v_ap_inv_line_rec.description := v_dist_inv.dist_description;
            -------------------------1099 data-------------
            v_ap_inv_line_rec.type_1099                := v_dist_inv.type_1099;
            v_ap_inv_line_rec.income_tax_region        := v_dist_inv.income_tax;
            v_ap_inv_line_rec.accounting_date          := v_acct_date;
            v_ap_inv_line_rec.dist_code_combination_id := v_dist_inv.new_dist_ccid;

            --INSERT INTO ap.ap_invoice_lines_interface			-- Commented code by IXPRAVEEN-ARGANO,09-May-2023
			INSERT INTO apps.ap_invoice_lines_interface				--  code Added by IXPRAVEEN-ARGANO,09-May-2023
              (invoice_id,
               line_number,
               line_type_lookup_code,
               accounting_date,
               amount,
               description,
               dist_code_combination_id,
               org_id
               --,TAX_CODE
              ,
               -- creation_date
               --,user_defined_fisc_class
               --,
               type_1099,
               income_tax_region,
               --request_id,
               last_update_date,
               last_updated_by,
               last_update_login,
               creation_date,
               created_by)
            VALUES
              (v_ap_inv_line_rec.invoice_id --invoice_id
              ,
               v_ap_inv_line_rec.line_number --line_number
              ,
               v_ap_inv_line_rec.line_type_lookup_code --line_type_lookup_code
              ,
               v_ap_inv_line_rec.accounting_date,
               v_ap_inv_line_rec.amount --amount
              ,
               v_ap_inv_line_rec.description --description
              ,
               v_ap_inv_line_rec.dist_code_combination_id --l_gl_dist_ccid --dist_code_combination_id
              ,
               v_ap_inv_line_rec.org_id --org_id
               --,NULL --ZERO                                   --tax_code
              ,
               -- SYSDATE --CREATION_DATE
               --,'CONVERSION'                                  --user_defined_fisc_class
               --,
               v_ap_inv_line_rec.type_1099 --TYPE_1099
              ,
               v_ap_inv_line_rec.income_tax_region, --INCOME_TAX_REGION
               --g_request_id,
               SYSDATE,
               g_user_id,
               g_login_id,
               SYSDATE,
               g_user_id

               );
            do_commit;
          EXCEPTION
            WHEN OTHERS THEN
              show_sql_err;
              log(v_inv.invoice_num ||
                  ' Error in Inserting AP Lines Invoice interface ' ||
                  SQLERRM);
              v_error_msg := SQLERRM;

              v_error_flag := 'Y';
          END;

          -- Updating the status of insertion in stg table
          IF v_error_flag = 'Y' THEN

            UPDATE ttec_ap_invoices_stg
               SET status     = 'E',
                   error_msg  = error_msg ||
                                ' *Error in Inserting to interface tables ' ||
                                v_error_msg,
                   attribute2 = v_ap_inv_hdr_rec.invoice_id
             WHERE 1 = 1
               AND legacy_invoice_id = v_inv.legacy_invoice_id;
            --AND LEGACY_INVOICE_DIST_ID =
            --v_dist_inv.LEGACY_INVOICE_DIST_ID;

          ELSE

            UPDATE ttec_ap_invoices_stg
               SET status     = 'P',
                   attribute3 = v_ap_inv_line_rec.invoice_id,
                   attribute2 = v_ap_inv_hdr_rec.invoice_id
             WHERE 1 = 1
               AND legacy_invoice_id = v_inv.legacy_invoice_id;
            --AND LEGACY_INVOICE_DIST_ID =
            -- v_dist_inv.LEGACY_INVOICE_DIST_ID;

          END IF;

          do_commit;

        END LOOP; --  v_dist_inv IN c_dist_inv

      EXCEPTION
        WHEN OTHERS THEN

          v_error_msg := SQLERRM;

          show_sql_err;

      END;

    END LOOP; -- v_inv in c_inv

    p_retcode := 'S';

  EXCEPTION
    WHEN OTHERS THEN
      log('Unexpected Error in Load');
      show_sql_err;
      p_retcode := 'E';
  END load_main;

  PROCEDURE main(p_errbuff        OUT VARCHAR2,
                 p_retcode        OUT VARCHAR2,
                 p_org_id         IN NUMBER,
                 p_translate_flag IN VARCHAR2,
                 p_validate_flag  IN VARCHAR2,
                 p_load_flag      IN VARCHAR2
                 ) IS

    l_err_msg  VARCHAR2(4000);
    l_err_flag VARCHAR2(4000);

    l_main_error_msg   VARCHAR2(4000);
    l_main_status_flag VARCHAR2(10);

    l_to_trsl_count   NUMBER := 0;
    l_to_validn_count NUMBER := 0;
    l_to_load_count   NUMBER := 0;
    l_to_recon_count  NUMBER := 0;
    l_errored_count   NUMBER := 0;
    l_completed_count NUMBER := 0;

    p_reconsile_flag VARCHAR2(10) := 'N';
  BEGIN

    SELECT COUNT(1)
      INTO l_to_trsl_count
      FROM ttec_ap_invoices_stg
     WHERE status = 'N'
       AND org_id = p_org_id;

    log(' **** INSIDE MAIN **** ');

    log('No. of Eligible Records: ' || l_to_trsl_count);


    ---Translated

    SELECT COUNT(1)
      INTO l_to_validn_count
      FROM ttec_ap_invoices_stg
     WHERE status = 'T'
       AND org_id = p_org_id;


    IF p_validate_flag = 'Y' THEN

      log(' --------- calling validation procedure  ---------- ');

      validate_main(p_errbuff => l_err_msg,
                    p_retcode => l_err_flag,
                    p_org_id  => p_org_id);

      log(' AFTER OUT OF VALIDATE PROCEDURE -- l_err_flag ' || l_err_flag);

      IF (l_err_flag = 'S') THEN
        NULL;
      ELSE
        l_main_error_msg   := l_err_msg;
        l_main_status_flag := l_err_flag;
      END IF;
    END IF;

    SELECT COUNT(1)
      INTO l_to_load_count
      FROM ttec_ap_invoices_stg
     WHERE status = 'V'
       AND org_id = p_org_id;

    --log('No. of Valid Reocrds: '||l_validn_count);

    log(' BEFORE GOING TO LOAD MAIN -- l_main_status_flag ' ||
        l_main_status_flag);

    IF (p_load_flag = 'Y' AND nvl(l_main_status_flag, 'S') = 'S') THEN
      log('calling loading procedure');
      load_main(p_errbuff => l_err_msg,
                p_retcode => l_err_flag,
                p_org_id  => p_org_id);

      IF (l_err_flag = 'S') THEN
        NULL;
      ELSE
        l_main_error_msg   := l_err_msg;
        l_main_status_flag := l_err_flag;
      END IF;

    END IF;

    SELECT COUNT(1)
      INTO l_to_recon_count
      FROM ttec_ap_invoices_stg
     WHERE status = 'P'
       AND org_id = p_org_id;

    IF (p_reconsile_flag = 'Y' AND nvl(l_main_status_flag, 'S') = 'S') THEN
      log('calling recon procedure');

    END IF;

    --log('No. of Processed Records loaded to Interface: '||l_loaded_count);

    SELECT COUNT(1)
      INTO l_completed_count
      FROM ttec_ap_invoices_stg
     WHERE status = 'C'
       AND org_id = p_org_id;

    SELECT COUNT(1)
      INTO l_errored_count
      FROM ttec_ap_invoices_stg
     WHERE status = 'E'
       AND org_id = p_org_id;

    p_errbuff := l_main_error_msg;
    p_retcode := l_main_status_flag;
    NULL;

    do_commit;

    ttec_ap_out_report;

  EXCEPTION
    WHEN OTHERS THEN
      NULL;
      log('UNEXPECTED Error in inv_load_main');
      log('sql :' || SQLCODE || '->' || SQLERRM);
      show_sql_err;
      ROLLBACK;
  END main;

 /* PROCEDURE recon_main(p_errbuff OUT VARCHAR2,
                       p_retcode OUT VARCHAR2,
                       p_org_id  IN NUMBER) IS
  BEGIN
    NULL;
  END recon_main;*/

END ttec_ap_invoice_conv_load_intf;
/
show errors;
/