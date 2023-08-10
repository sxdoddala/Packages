create or replace PACKAGE BODY ttec_po_us_tsg_interface
IS
   /************************************************************************************
        Program Name: TTEC_PO_TSG_INTERFACE

        Description:  This program Interface PO data from TSG (Tiger Paw) to create Purchase orders in oracle

        Developed by : Kaushik Babu
        Date         : Jul 2 2013

       Modification Log
       Name                  Version #    Date            Description
       -----                 --------     -----           -------------
    Kaushik Babu G            1.0        JUL 02 2013     Initial Script
    Kaushik Babu G            1.1        NOV 19 2014     1. Store the PO Line Number at line level DFF while creating PO.
                                                            Please use the Customer Name from PO file and derive the client
                                                            code and build the charge account(Similar to what we are doing
                                                            with AR file).Store the customer name at header level DFF.
                                                         2. Use the PO Line number along with PPO Number stored while creating
                                                            PO and for receiving.
   Elango Pandu              1.2         jan 26 2015      fixing group by clause error. Add tsg_part_mum in group by clause
                                                          GROUP BY tsg_po_num, tsg_part_num, tsg_part_num,effective_date;

   Arun Kumar                1.3         MAR 09 2015      Change in error log print format. Removed bill_to and ship_to hard coding

   Arun Kumar                1.4         Mar 13 2015      Transactions of type 'DELIVER' to be used for open quantity calculation

   Arun Kumar                1.5         Mar 19 2015      Fixed bug in negative quantity validation.
                                                          Included quantity detail for error category 'PO Line Not Matching'
   MXKEERTHI(ARGANO)         1.0          May 02 2023      R12.2 Upgrade Remediation													  

    ****************************************************************************************/
   CURSOR c_po_insert
   IS
      SELECT tsg_po_num, UPPER (agent_name) agent_name,
             UPPER (customer_name) customer_name,
             UPPER (vendor_name) vendor_name, vendor_site_code,
             UPPER (category_name) category_name, item_desc, uom, quantity,
             unit_price, LPAD (charge_location, 5, '0') charge_location,
             LPAD (charge_client, 4, '0') charge_client,
             LPAD (charge_dept, 3, '0') charge_dept, tsg_part_num,
             tsg_po_line_num
	  --FROM cust.ttec_po_data_load_ext;  --Commented code by MXKEERTHI-ARGANO, 05/02/2023
        FROM APPS.ttec_po_data_load_ext;  --code Added  by MXKEERTHI-ARGANO, 05/02/2023

   CURSOR c_unique_rec
   IS
      SELECT DISTINCT tsg_po_num, line_num
	  --FROM cust.ttec_po_us_tsg_stg tpu --Commented code by MXKEERTHI-ARGANO, 05/02/2023
        FROM APPS.ttec_po_us_tsg_stg tpu  --code Added  by MXKEERTHI-ARGANO, 05/02/2023
               
                WHERE TO_DATE (effective_date) = TRUNC (SYSDATE)
                  AND tpu.create_request_id = fnd_global.conc_request_id;

   CURSOR c_po_rec_insert
   IS
      SELECT   tsg_po_num, line_num, agent_name, customer_name, vendor_name,
               vendor_site_code, category_name, item_desc, uom, quantity,
               unit_price, charge_location, charge_client, charge_dept,
               charge_account, tsg_part_num, effective_date, agent_id,
               vendor_id, vendor_site_id, charge_acct_id, status, error_desc
		  --FROM cust.ttec_po_us_tsg_stg tpu--Commented code by MXKEERTHI-ARGANO, 05/02/2023
          FROM APPS.ttec_po_us_tsg_stg tpu  --code Added  by MXKEERTHI-ARGANO, 05/02/2023
         
         WHERE tpu.status = 'READY'
           AND TO_DATE (tpu.effective_date) = TRUNC (SYSDATE)
           AND tpu.create_request_id = fnd_global.conc_request_id
      ORDER BY 1, 4;

   CURSOR c_clear_intf_rec
   IS
      SELECT DISTINCT phi.interface_header_id
	              --START R12.2 Upgrade Remediation
	              /*
		          Commented code by MXKEERTHI-ARGANO, 05/02/2023
				 FROM po.po_headers_interface phi,
                      po.po_lines_interface pln,
                      po.po_line_locations_interface pll,
                      po.po_distributions_interface pdi,
                      cust.ttec_po_us_tsg_stg tpu
                  
	              */
                  --code Added  by MXKEERTHI-ARGANO, 05/02/2023
				 FROM APPS.po_headers_interface phi,
                      APPS.po_lines_interface pln,
                      APPS.po_line_locations_interface pll,
                      APPS.po_distributions_interface pdi,
                      APPS.ttec_po_us_tsg_stg tpu
                  
	  
	            --END R12.2.10 Upgrade remediation
                 
                WHERE phi.attribute1 = tpu.tsg_po_num
                  AND phi.interface_header_id = pln.interface_header_id
                  AND pln.interface_line_id = pll.interface_line_id
                  AND pll.interface_header_id = phi.interface_header_id
                  AND pdi.interface_line_location_id =
                                                pll.interface_line_location_id
                  AND pdi.interface_header_id = phi.interface_header_id
                  AND pdi.interface_line_id = pln.interface_line_id
                  AND tpu.status = 'UNPROCESSED'
                  AND TO_DATE (tpu.effective_date) = TRUNC (SYSDATE)
                  AND tpu.create_request_id = fnd_global.conc_request_id;

   CURSOR c_po_rpt
   IS
      SELECT   tsg_po_num, line_num, agent_name, customer_name, vendor_name,
               vendor_site_code, category_name, item_desc, uom, quantity,
               unit_price, charge_location, charge_client, charge_dept,
               charge_account, tsg_part_num, effective_date, agent_id,
               vendor_id, vendor_site_id, charge_acct_id, status, error_desc,
               create_request_id, creation_date, created_by, last_update_date,
               last_updated_by, last_update_login
	     --FROM cust.ttec_po_us_tsg_stg tpu    --Commented code by MXKEERTHI-ARGANO, 05/02/2023
          FROM APPS.ttec_po_us_tsg_stg tpu   ----code Added  by MXKEERTHI-ARGANO, 05/02/2023
         WHERE TO_DATE (tpu.effective_date) = TRUNC (SYSDATE)
           AND tpu.create_request_id = fnd_global.conc_request_id
      ORDER BY 1;

   FUNCTION ttec_create_ccid (p_concat_segs IN VARCHAR2)
      RETURN VARCHAR2
   IS
      l_status   BOOLEAN;
      l_coa_id   NUMBER;
   BEGIN
      l_status :=
         fnd_flex_keyval.validate_segs ('CREATE_COMBINATION',
                                        'SQLGL',
                                        'GL#',
                                        101,
                                        p_concat_segs,
                                        'V',
                                        SYSDATE,
                                        'ALL',
                                        NULL,
                                        NULL,
                                        NULL,
                                        NULL,
                                        FALSE,
                                        FALSE,
                                        NULL,
                                        NULL,
                                        NULL
                                       );

      IF l_status
      THEN
         RETURN 'S';
      ELSE
         /*fnd_file.put_line (fnd_file.LOG,
                               'Failure in segment validation :'
                            || fnd_flex_keyval.error_message
                           );*/
         RETURN 'F';
      END IF;
   END;

   PROCEDURE main (errbuf OUT VARCHAR2, retcode OUT NUMBER)
   IS
      l_org_name                VARCHAR2 (50)               := 'Technology Solutions Group, Inc.'; --'TSG-TeleTech';
      -- 'TeleTech United States'
      l_neg_amt                 NUMBER                           DEFAULT NULL;
      l_org_id                  po_headers_interface.org_id%TYPE DEFAULT NULL;
      l_advance_shipment_flag   BOOLEAN                              := FALSE;
      l_ship_to_location_id     po_headers_interface.ship_to_location_id%TYPE
                                                                 DEFAULT NULL;
      l_bill_to_location_id     po_headers_interface.bill_to_location_id%TYPE
                                                                 DEFAULT NULL;
      l_agent_id                NUMBER                           DEFAULT NULL;
      l_category_item           mtl_categories_kfv.concatenated_segments%TYPE
                                                                 DEFAULT NULL;
      l_vendor_id               NUMBER                           DEFAULT NULL;
      l_vendor_site_id          NUMBER                           DEFAULT NULL;
      l_category_id             NUMBER                           DEFAULT NULL;
      l_charge_account_id       NUMBER                           DEFAULT NULL;
      l_seg_value               VARCHAR2 (5)                     DEFAULT NULL;
      l_seg_client              VARCHAR2 (4)                     DEFAULT NULL;
      l_status                  VARCHAR2 (10)                    DEFAULT NULL;
      l_error_desc              VARCHAR2 (5000)                  DEFAULT NULL;
      l_tsg_po_num              VARCHAR2 (100)                   DEFAULT NULL;
      l_line_num                NUMBER                              DEFAULT 0;
      l_exists                  VARCHAR2 (1)                      DEFAULT 'N';
      l_stg_line_num            NUMBER                              DEFAULT 0;
      v_rec                     VARCHAR2 (10000)                 DEFAULT NULL;
      l_cnt                     NUMBER                              DEFAULT 0;
      l_hdr_id                  NUMBER                           DEFAULT NULL;
      l_cc_status               VARCHAR2 (1)                     DEFAULT NULL;
   -- Teletech US Englewood
      TYPE po_error_log IS TABLE OF VARCHAR2(1000);
      po_err_neg_amt             po_error_log;
      po_err_agent               po_error_log;
      po_err_cat_item            po_error_log;
      po_err_supplier_site       po_error_log;
      po_err_acct_value          po_error_log;
      po_err_client_code         po_error_log;
      po_err_acct_comb           po_error_log;
   BEGIN
      l_stg_line_num := 0;
      po_err_neg_amt := po_error_log();
      po_err_agent := po_error_log();
      po_err_cat_item := po_error_log();
      po_err_supplier_site := po_error_log();
      po_err_acct_value := po_error_log();
      po_err_client_code := po_error_log();
      po_err_acct_comb := po_error_log();

      /* Assign org_id based on variable l_org_name */
      SELECT organization_id
        INTO l_org_id
        FROM hr_all_organization_units
       WHERE NAME = l_org_name;

       /* Ver 1.3 -- Start */
       /* Assign ship_to and bill to id based on org */
       SELECT ship_to_location_id, bill_to_location_id
         INTO l_ship_to_location_id, l_bill_to_location_id
         FROM apps.financials_system_parameters
        WHERE org_id = l_org_id;
        /* Ver 1.3 -- End */

      FOR r_po_insert IN c_po_insert
      LOOP
         l_error_desc := NULL;
         l_status := NULL;

         BEGIN

           SELECT 1
             INTO l_neg_amt
             FROM dual
            WHERE sign(r_po_insert.unit_price) IN (0,1); -- Ver 1.5

         EXCEPTION
           WHEN OTHERS THEN
             l_status := 'ERROR';

             po_err_neg_amt.extend();
             po_err_neg_amt(po_err_neg_amt.last) := r_po_insert.tsg_po_num || '/' ||
                                        r_po_insert.tsg_po_line_num || '/' ||
                                        r_po_insert.vendor_name || '/' ||
                                        r_po_insert.vendor_site_code;

         END;

         BEGIN
            l_agent_id := NULL;

            SELECT agent_id
              INTO l_agent_id
              FROM po_agents_v
             WHERE TRUNC (SYSDATE) BETWEEN start_date_active
                                       AND NVL (end_date_active,
                                                TRUNC (SYSDATE)
                                               )
               AND UPPER (agent_name) =
                      (SELECT UPPER (description)
                         FROM apps.fnd_lookup_values flv
                        WHERE lookup_type LIKE 'TTEC_PO_AUTO_BUYER_LIST'
                          AND LANGUAGE = 'US'
                          AND TRUNC (SYSDATE) BETWEEN flv.start_date_active
                                                  AND NVL
                                                         (flv.end_date_active,
                                                          TRUNC (SYSDATE)
                                                         )
                          AND flv.enabled_flag = 'Y'
                          AND UPPER (meaning) = UPPER('Technology Solutions Group, Inc.'));--UPPER ('TSG-TeleTech'));
         EXCEPTION
            /* Ver 1.3 -- Start */
            /*WHEN NO_DATA_FOUND
            THEN
               l_status := 'ERROR';
               l_error_desc := 'No Err Agent -' || r_po_insert.agent_name;
            WHEN TOO_MANY_ROWS
            THEN
               l_status := 'ERROR';
               l_error_desc :=
                             'Too Many Err Agent -' || r_po_insert.agent_name;
            WHEN OTHERS
            THEN
               l_status := 'ERROR';
               l_error_desc :=
                     'Other Err Agent -'
                  || r_po_insert.agent_name
                  || '-'
                  || SQLERRM;*/
            WHEN OTHERS
            THEN
               l_status := 'ERROR';

               po_err_agent.extend;
               po_err_agent(po_err_agent.last) := r_po_insert.tsg_po_num || '/' ||
                                          r_po_insert.tsg_po_line_num || '/' ||
                                          r_po_insert.vendor_name || '/' ||
                                          r_po_insert.vendor_site_code;
            /* Ver 1.3 -- End */
         END;

         /* 28-Aug-2014 -- Change to fetch category item based on department code -- Start */
         BEGIN
            l_category_item := NULL;

            SELECT concatenated_segments
              INTO l_category_item
              FROM apps.mtl_categories_kfv
             WHERE structure_id = 201                      -- PO_ITEM_CATEGORY
               AND attribute3 IS NOT NULL
               AND attribute3 = r_po_insert.category_name;
         /* Contains department code */
         EXCEPTION
            /* Ver 1.3 -- Start */
            /*WHEN NO_DATA_FOUND
            THEN
               l_status := 'ERROR';
               l_error_desc :=
                            'No Item Category -' || r_po_insert.category_name;
            WHEN TOO_MANY_ROWS
            THEN
               l_status := 'ERROR';
               l_error_desc :=
                      'Too Many Item Category -' || r_po_insert.category_name;
            WHEN OTHERS
            THEN
               l_status := 'ERROR';
               l_error_desc :=
                     'Other Item Category -'
                  || r_po_insert.category_name
                  || '-'
                  || SQLERRM;*/
            WHEN OTHERS
            THEN
               l_status := 'ERROR';

               po_err_cat_item.extend;
               po_err_cat_item(po_err_cat_item.last) := r_po_insert.tsg_po_num || '/' ||
                                          r_po_insert.tsg_po_line_num || '/' ||
                                          r_po_insert.vendor_name || '/' ||
                                          r_po_insert.vendor_site_code || '/' ||
                                          l_category_item;
             /* Ver 1.3 -- End */
         END;

         /* 28-Aug-2014 -- Change to fetch category item based on department code -- End */
         BEGIN
            l_vendor_id := NULL;
            l_vendor_site_id := NULL;

            SELECT asp.vendor_id, assa.vendor_site_id
              INTO l_vendor_id, l_vendor_site_id
			-- FROM ap.ap_suppliers asp, ap.ap_supplier_sites_all assa  --Commented code by MXKEERTHI-ARGANO, 05/02/2023
              FROM APPS.ap_suppliers asp, ap.ap_supplier_sites_all assa   --code Added  by MXKEERTHI-ARGANO, 05/02/2023
             WHERE asp.vendor_id = assa.vendor_id
               AND asp.enabled_flag = 'Y'
               AND TRUNC (SYSDATE) BETWEEN asp.start_date_active
                                       AND NVL (asp.end_date_active,
                                                TRUNC (SYSDATE)
                                               )
               AND assa.inactive_date IS NULL
               AND assa.org_id = l_org_id
               --  AND UPPER (asp.vendor_name) = /* 01-09-2014 -- Vendor number will be provided in data file instead of vendor name */
               AND asp.segment1 =
                      (ttec_library.remove_non_ascii (r_po_insert.vendor_name)
                      )
               AND assa.vendor_site_code =
                      UPPER
                         (ttec_library.remove_non_ascii
                                                 (r_po_insert.vendor_site_code)
                         );
         EXCEPTION
            /* Ver 1.3 -- Start */
            /*WHEN NO_DATA_FOUND
            THEN
               l_status := 'ERROR';
               l_error_desc :=
                     l_error_desc
                  || '-'
                  || 'No comb Err Vendor/Vensite -'
                  || r_po_insert.vendor_name;
            WHEN TOO_MANY_ROWS
            THEN
               l_status := 'ERROR';
               l_error_desc :=
                     l_error_desc
                  || '-'
                  || 'Too comb Err Vendor/Vensite -'
                  || r_po_insert.vendor_name;
            WHEN OTHERS
            THEN
               l_status := 'ERROR';
               l_error_desc :=
                     l_error_desc
                  || '-'
                  || 'Other comb Err Vendor/Vensite -'
                  || r_po_insert.vendor_name
                  || '-'
                  || SQLERRM;*/

            WHEN OTHERS
            THEN
               l_status := 'ERROR';

               po_err_supplier_site.extend;
               po_err_supplier_site(po_err_supplier_site.last) := r_po_insert.tsg_po_num || '/' ||
                                          r_po_insert.tsg_po_line_num || '/' ||
                                          r_po_insert.vendor_name || '/' ||
                                          r_po_insert.vendor_site_code;
             /* Ver 1.3 -- End */
         END;

         BEGIN
            l_seg_value := NULL;

            SELECT DISTINCT segment_value
                       INTO l_seg_value
                       FROM po_rule_expense_accounts_v
                      WHERE segment_num = 'SEGMENT4'
                        AND rule_type = 'ITEM CATEGORY'
                        AND UPPER (rule_value) =
                               UPPER
                                  (ttec_library.remove_non_ascii
                                                              (l_category_item)
--  (r_po_insert.category_name) /* 28-Aug-2014 -- Change to fetch category item based on department code -- Start */
                                  )
                        AND org_id = l_org_id;
         EXCEPTION
            /* Ver 1.3 -- Start */
            /*WHEN NO_DATA_FOUND
            THEN
               l_status := 'ERROR';
               l_error_desc :=
                     l_error_desc
                  || '-'
                  || 'No Seg Val -'
                  || r_po_insert.category_name;
            WHEN TOO_MANY_ROWS
            THEN
               l_status := 'ERROR';
               l_error_desc :=
                     l_error_desc
                  || '-'
                  || 'Too many Seg Val -'
                  || r_po_insert.category_name;
            WHEN OTHERS
            THEN
               l_status := 'ERROR';
               l_error_desc :=
                     l_error_desc
                  || '-'
                  || 'Other Seg Val -'
                  || r_po_insert.category_name
                  || '-'
                  || SQLERRM;*/

            WHEN OTHERS
            THEN
               l_status := 'ERROR';

               po_err_acct_value.extend;
               po_err_acct_value(po_err_acct_value.last) := r_po_insert.tsg_po_num || '/' ||
                                          r_po_insert.tsg_po_line_num || '/' ||
                                          r_po_insert.vendor_name || '/' ||
                                          r_po_insert.vendor_site_code || '/' ||
                                          l_category_item;
             /* Ver 1.3 -- End */
         END;

         BEGIN
            l_seg_client := NULL;

            SELECT hca.attribute1 --NVL (hca.attribute1, '9080')
              INTO l_seg_client
              FROM apps.hz_parties hp, apps.hz_cust_accounts_all hca
             WHERE hp.party_type = 'ORGANIZATION'
               AND hp.party_id = hca.party_id
               AND hca.attribute_category = 'TSG'
               AND UPPER (hp.party_name) = UPPER (r_po_insert.customer_name);
         EXCEPTION
            /* Ver 1.3 -- Start */
            /*WHEN NO_DATA_FOUND
            THEN
               l_status := 'ERROR';
               l_error_desc :=
                     l_error_desc
                  || '-'
                  || 'No Client Seg Val -'
                  || r_po_insert.customer_name;
            WHEN TOO_MANY_ROWS
            THEN
               l_status := 'ERROR';
               l_error_desc :=
                     l_error_desc
                  || '-'
                  || 'Too many client Seg Val -'
                  || r_po_insert.customer_name;
            WHEN OTHERS
            THEN
               l_status := 'ERROR';
               l_error_desc :=
                     l_error_desc
                  || '-'
                  || 'Other Client Seg Val -'
                  || r_po_insert.customer_name
                  || '-'
                  || SQLERRM;*/

            WHEN OTHERS
            THEN
               l_status := 'ERROR';

               po_err_client_code.extend;
               po_err_client_code(po_err_client_code.last) := r_po_insert.tsg_po_num || '/' ||
                                          r_po_insert.tsg_po_line_num || '/' ||
                                          r_po_insert.vendor_name || '/' ||
                                          r_po_insert.vendor_site_code || '/' ||
                                          r_po_insert.customer_name;
             /* Ver 1.3 -- End */

         END;

         IF     r_po_insert.charge_location IS NOT NULL
            --AND r_po_insert.charge_client IS NOT NULL
            AND l_seg_client IS NOT NULL
            -- AND r_po_insert.charge_dept IS NOT NULL
            AND r_po_insert.category_name IS NOT NULL
            /* 05-Sep-2014  -- As per request from Karthik */
            AND l_seg_value IS NOT NULL
         THEN
            BEGIN
               l_charge_account_id := NULL;

               SELECT code_combination_id
                 INTO l_charge_account_id
                 FROM gl_code_combinations
                WHERE segment1 = r_po_insert.charge_location
                  AND segment2 = l_seg_client      --r_po_insert.charge_client
                  -- AND segment3 = r_po_insert.charge_dept
                  AND segment3 = r_po_insert.category_name
                  /* 05-Sep-2014  -- As per request from Karthik */
                  AND segment4 = l_seg_value
                  AND segment5 = '0000'
                  AND segment6 = '0000'
                  AND enabled_flag = 'Y'
                  AND chart_of_accounts_id = 101;
            EXCEPTION
               WHEN NO_DATA_FOUND
               THEN
                  l_cc_status := NULL;
                  l_cc_status :=
                     ttec_create_ccid (   r_po_insert.charge_location
                                       || '.'
                                       || l_seg_client
                                       || '.'
                                       || r_po_insert.category_name
                                       -- r_po_insert.charge_dept /* 05-Sep-2014  -- As per request from Karthik */
                                       || '.'
                                       || l_seg_value
                                       || '.'
                                       || '0000'
                                       || '.'
                                       || '0000'
                                      );

                  IF l_cc_status = 'S'
                  THEN
                     BEGIN
                        SELECT code_combination_id
                          INTO l_charge_account_id
                          FROM gl_code_combinations
                         WHERE segment1 = r_po_insert.charge_location
                           AND segment2 = l_seg_client
                           --AND segment2 = r_po_insert.charge_client
                           AND segment3 = r_po_insert.category_name
                           -- r_po_insert.charge_dept /* 05-Sep-2014  -- As per request from Karthik */
                           AND segment4 = l_seg_value
                           AND segment5 = '0000'
                           AND segment6 = '0000'
                           AND enabled_flag = 'Y'
                           AND chart_of_accounts_id = 101;

                        fnd_file.put_line (fnd_file.LOG,
                                              'l_charge_account_id Created -'
                                           || l_charge_account_id
                                          );
                     EXCEPTION
                        WHEN OTHERS
                        THEN
                           l_charge_account_id := NULL;
                           l_status := 'ERROR';
                           l_error_desc :=
                                 l_error_desc
                              || ' New code combination created is missing';
                     END;
                  ELSIF l_cc_status = 'F'
                  THEN
                     l_status := 'ERROR';

                     po_err_acct_comb.extend;
                     po_err_acct_comb(po_err_acct_comb.last) := r_po_insert.tsg_po_num || '/' ||
                                          r_po_insert.tsg_po_line_num || '/' ||
                                          r_po_insert.vendor_name || '/' ||
                                          r_po_insert.vendor_site_code || '/' ||
                                          r_po_insert.customer_name;
                  END IF;
             /* Ver 1.3 -- Start */
               /*WHEN TOO_MANY_ROWS
               THEN
                  l_status := 'ERROR';
                  l_error_desc :=
                        l_error_desc
                     || '-'
                     || 'Too many Seg Val -'
                     || r_po_insert.charge_location
                     || '.'
                     || l_seg_client
                     || '.'
                     || r_po_insert.charge_dept
                     || '.'
                     || l_seg_value;
               WHEN OTHERS
               THEN
                  l_status := 'ERROR';
                  l_error_desc :=
                        l_error_desc
                     || '-'
                     || 'Other Seg Val -'
                     || r_po_insert.charge_location
                     || '.'
                     || l_seg_client
                     || '.'
                     || r_po_insert.charge_dept
                     || '.'
                     || l_seg_value
                     || '-'
                     || SQLERRM;*/

               WHEN OTHERS
               THEN
               l_status := 'ERROR';

               po_err_acct_comb.extend;
               po_err_acct_comb(po_err_acct_comb.last) := r_po_insert.tsg_po_num || '/' ||
                                          r_po_insert.tsg_po_line_num || '/' ||
                                          r_po_insert.vendor_name || '/' ||
                                          r_po_insert.vendor_site_code || '/' ||
                                          r_po_insert.customer_name;
             /* Ver 1.3 -- End */

            END;
         END IF;

         BEGIN
            l_stg_line_num := l_stg_line_num + 1;
                --INSERT INTO cust.ttec_po_us_tsg_stg--Commented code by MXKEERTHI-ARGANO, 05/08/2023
                INSERT INTO apps.ttec_po_us_tsg_stg --code added by MXKEERTHI-ARGANO, 05/08/2023
                        (tsg_po_num,
                         line_num,
                         agent_name, customer_name,
                         vendor_name,
                         vendor_site_code, category_name,
                         item_desc, uom,
                         quantity,
                         unit_price,
                         charge_location, charge_client,
                         charge_dept, charge_account,
                         tsg_part_num, effective_date,
                         agent_id, vendor_id, vendor_site_id,
                         charge_acct_id, status,
                         error_desc,
                         create_request_id, creation_date,
                         created_by, last_update_date, last_updated_by,
                         last_update_login
                        )
                 VALUES (r_po_insert.tsg_po_num,
                         r_po_insert.tsg_po_line_num,        --l_stg_line_num,
                         r_po_insert.agent_name, r_po_insert.customer_name,
                         r_po_insert.vendor_name,
                         r_po_insert.vendor_site_code, l_category_item,
-- r_po_insert.category_name /* 28-Aug-2014 -- Change to fetch category item based on department code -- Start */
                         r_po_insert.item_desc, r_po_insert.uom,
                         TO_NUMBER (r_po_insert.quantity),
                         TO_NUMBER (r_po_insert.unit_price),
                         r_po_insert.charge_location, l_seg_client,
                         r_po_insert.charge_dept, l_seg_value,
                         r_po_insert.tsg_part_num, TRUNC (SYSDATE),
                         l_agent_id, l_vendor_id, l_vendor_site_id,
                         l_charge_account_id, l_status,
                         SUBSTRB (l_error_desc, 1, 100),
                         fnd_global.conc_request_id, SYSDATE,
                         fnd_global.login_id, SYSDATE, fnd_global.login_id,
                         fnd_global.login_id
                        );

            COMMIT;
         EXCEPTION
            WHEN OTHERS
            THEN
               fnd_file.put_line (fnd_file.LOG,
                                  'Error during Stage1 Insert -' || SQLERRM
                                 );
         END;
      END LOOP;

      /* To print error in log if present for each record */
         /* Ver 1.3 -- Start */
         /*fnd_file.put_line (fnd_file.LOG, l_error_desc);*/
         IF po_err_neg_amt.count != 0 THEN
         fnd_file.put_line (fnd_file.LOG, 'Error Type: Negative Amount on a PO Line in the file');
         fnd_file.put_line (fnd_file.LOG, 'TSG PO Number/TSG PO Line Number/Supplier/Supplier Site');
         FOR i IN 1 .. po_err_neg_amt.count
         LOOP
         fnd_file.put_line (fnd_file.LOG, po_err_neg_amt(i));
         END LOOP;
         fnd_file.put_line (fnd_file.LOG,CHR(10));
         END IF;

         IF po_err_agent.count != 0 THEN
         fnd_file.put_line (fnd_file.LOG, 'Error Type: Default Agent missing');
         fnd_file.put_line (fnd_file.LOG, 'TSG PO Number/TSG PO Line Number/Supplier/Supplier Site');
         FOR i IN 1 .. po_err_agent.count
         LOOP
         fnd_file.put_line (fnd_file.LOG, po_err_agent(i));
         END LOOP;
         fnd_file.put_line (fnd_file.LOG,CHR(10));
         END IF;

         IF po_err_cat_item.count != 0 THEN
         fnd_file.put_line (fnd_file.LOG, 'Error Type: Department code not assigned to category item');
         fnd_file.put_line (fnd_file.LOG, 'TSG PO Number/TSG PO Line Number/Supplier/Supplier Site/Category Item');
         FOR i IN 1 .. po_err_cat_item.count
         LOOP
         fnd_file.put_line (fnd_file.LOG, po_err_cat_item(i));
         END LOOP;
         fnd_file.put_line (fnd_file.LOG,CHR(10));
         END IF;

         IF po_err_supplier_site.count != 0 THEN
         fnd_file.put_line (fnd_file.LOG, 'Error Type: Incorrect/In Active Supplier Site in the file');
         fnd_file.put_line (fnd_file.LOG, 'TSG PO Number/TSG PO Line Number/Supplier/Supplier Site');
         FOR i IN 1 .. po_err_supplier_site.count
         LOOP
         fnd_file.put_line (fnd_file.LOG, po_err_supplier_site(i));
         END LOOP;
         fnd_file.put_line (fnd_file.LOG,CHR(10));
         END IF;

         IF po_err_acct_value.count != 0 THEN
         fnd_file.put_line (fnd_file.LOG, 'Error Type: Account segment value not assigned to category item');
         fnd_file.put_line (fnd_file.LOG, 'TSG PO Number/TSG PO Line Number/Supplier/Supplier Site/Category Item');
         FOR i IN 1 .. po_err_acct_value.count
         LOOP
         fnd_file.put_line (fnd_file.LOG, po_err_acct_value(i));
         END LOOP;
         fnd_file.put_line (fnd_file.LOG,CHR(10));
         END IF;

         IF po_err_client_code.count != 0 THEN
         fnd_file.put_line (fnd_file.LOG, 'Error Type: Incorrect Customer in the file/Client code not assigned to Customer');
         fnd_file.put_line (fnd_file.LOG, 'TSG PO Number/TSG PO Line Number/Supplier/Supplier Site/Customer');
         FOR i IN 1 .. po_err_client_code.count
         LOOP
         fnd_file.put_line (fnd_file.LOG, po_err_client_code(i));
         END LOOP;
         fnd_file.put_line (fnd_file.LOG,CHR(10));
         END IF;

         IF po_err_acct_comb.count != 0 THEN
         fnd_file.put_line (fnd_file.LOG, 'Error Type: Incorrect account combination');
         fnd_file.put_line (fnd_file.LOG, 'TSG PO Number/TSG PO Line Number/Supplier/Supplier Site/Customer');
         FOR i IN 1 .. po_err_acct_comb.count
         LOOP
         fnd_file.put_line (fnd_file.LOG, po_err_acct_comb(i));
         END LOOP;
         fnd_file.put_line (fnd_file.LOG,CHR(10));
         END IF;
         /* Ver 1.3 -- End */

      BEGIN
         BEGIN
            l_cnt := 0;

            SELECT NVL (COUNT (*), 0)
              INTO l_cnt
			   --FROM cust.ttec_po_us_tsg_stg		--Commented code by MXKEERTHI-ARGANO, 05/02/2023
              FROM APPS.ttec_po_us_tsg_stg    --code Added  by MXKEERTHI-ARGANO, 05/02/2023
             WHERE status = 'ERROR'
               AND create_request_id =
                                     (SELECT MAX (create_request_id)
			                          --FROM cust.ttec_po_us_tsg_stg		--Commented code by MXKEERTHI-ARGANO, 05/02/2023
                                      FROM apps.ttec_po_us_tsg_stg  --code Added  by MXKEERTHI-ARGANO, 05/02/2023
                                       
                                       WHERE effective_date = TRUNC (SYSDATE));
         EXCEPTION
            WHEN NO_DATA_FOUND
            THEN
               l_cnt := -1;
            WHEN OTHERS
            THEN
               l_cnt := -1;
         END;

         IF l_cnt > 0
         THEN
            v_rec := NULL;
            v_rec :=
                  'tsg_po_num'
               || '|'
               || 'line_num'
               || '|'
               || 'agent_name'
               || '|'
               || 'customer_name'
               || '|'
               || 'vendor_name'
               || '|'
               || 'vendor_site_code'
               || '|'
               || 'category_name'
               || '|'
               || 'item_desc'
               || '|'
               || 'uom'
               || '|'
               || 'quantity'
               || '|'
               || 'unit_price'
               || '|'
               || 'charge_loction'
               || '|'
               || 'charge_client'
               || '|'
               || 'charge_dept'
               || '|'
               || 'charge_account'
               || '|'
               || 'effective_date'
               || '|'
               || 'agent_id'
               || '|'
               || 'vendor_id'
               || '|'
               || 'vendor_site_id'
               || '|'
               || 'charge_account_id'
               || '|'
               || 'tsg_part_num'
               || '|'
               || 'status'
               || '|'
               || 'error_desc'
               || '|'
               || 'create_request_id'
               || '|'
               || 'creation_date'
               || '|'
               || 'created_by'
               || '|'
               || 'last_update_date'
               || '|'
               || 'last_updated_by'
               || '|'
               || 'last_update_login';
            fnd_file.put_line (fnd_file.output, v_rec);

            FOR r_po_rpt IN c_po_rpt
            LOOP
               v_rec := NULL;
               v_rec :=
                     r_po_rpt.tsg_po_num
                  || '|'
                  || r_po_rpt.line_num
                  || '|'
                  || r_po_rpt.agent_name
                  || '|'
                  || r_po_rpt.customer_name
                  || '|'
                  || r_po_rpt.vendor_name
                  || '|'
                  || r_po_rpt.vendor_site_code
                  || '|'
                  || r_po_rpt.category_name
                  || '|'
                  || r_po_rpt.item_desc
                  || '|'
                  || r_po_rpt.uom
                  || '|'
                  || r_po_rpt.quantity
                  || '|'
                  || r_po_rpt.unit_price
                  || '|'
                  || r_po_rpt.charge_location
                  || '|'
                  || r_po_rpt.charge_client
                  || '|'
                  || r_po_rpt.charge_dept
                  || '|'
                  || r_po_rpt.charge_account
                  || '|'
                  || r_po_rpt.effective_date
                  || '|'
                  || r_po_rpt.agent_id
                  || '|'
                  || r_po_rpt.vendor_id
                  || '|'
                  || r_po_rpt.vendor_site_id
                  || '|'
                  || r_po_rpt.charge_acct_id
                  || '|'
                  || r_po_rpt.tsg_part_num
                  || '|'
                  || r_po_rpt.status
                  || '|'
                  || r_po_rpt.error_desc
                  || '|'
                  || r_po_rpt.create_request_id
                  || '|'
                  || r_po_rpt.creation_date
                  || '|'
                  || r_po_rpt.created_by
                  || '|'
                  || r_po_rpt.last_update_date
                  || '|'
                  || r_po_rpt.last_updated_by
                  || '|'
                  || r_po_rpt.last_update_login;
               fnd_file.put_line (fnd_file.output, v_rec);
            END LOOP;
            --DELETE FROM cust.ttec_po_us_tsg_stg tpu   --Commented code by MXKEERTHI-ARGANO, 05/02/2023
            DELETE FROM APPS.ttec_po_us_tsg_stg tpu   --code Added  by MXKEERTHI-ARGANO, 05/02/2023
                  WHERE tpu.create_request_id =
                                     (SELECT MAX (create_request_id)
									 --FROM cust.ttec_po_us_tsg_stg    --Commented code by MXKEERTHI-ARGANO, 05/02/2023
                                      FROM APPS.ttec_po_us_tsg_stg   --code Added  by MXKEERTHI-ARGANO, 05/02/2023
                                      WHERE effective_date = TRUNC (SYSDATE));

            COMMIT;
         ELSIF l_cnt = 0
         THEN
            FOR r_unique_rec IN c_unique_rec
            LOOP
               BEGIN
                  l_exists := 'N';

                  SELECT 'Y'
                    INTO l_exists
                    FROM po_headers_all pha, po_lines_all pla
                   WHERE pha.attribute1 = r_unique_rec.tsg_po_num
                     AND pha.po_header_id = pla.po_header_id
                     AND pla.attribute2 = r_unique_rec.line_num;

                  UPDATE cust.ttec_po_us_tsg_stg
                     SET status = 'AVAILABLE'
                   WHERE tsg_po_num = r_unique_rec.tsg_po_num
                     AND line_num = r_unique_rec.line_num
                     AND create_request_id =
                                     (SELECT MAX (create_request_id)
									  -- FROM cust.ttec_po_us_tsg_stg   --Commented code by MXKEERTHI-ARGANO, 05/02/2023
                                       FROM APPS.ttec_po_us_tsg_stg   --code Added  by MXKEERTHI-ARGANO, 05/02/2023
                                       
                                       WHERE effective_date = TRUNC (SYSDATE));
               EXCEPTION
                  WHEN NO_DATA_FOUND
                  THEN
                     UPDATE cust.ttec_po_us_tsg_stg
                        SET status = 'READY'
                      WHERE tsg_po_num = r_unique_rec.tsg_po_num
                        AND line_num = r_unique_rec.line_num
                        AND create_request_id =
                                     (SELECT MAX (create_request_id)
									 --  FROM cust.ttec_po_us_tsg_stg   --Commented code by MXKEERTHI-ARGANO, 05/02/2023
                                        FROM APPS.ttec_po_us_tsg_stg   --code Added  by MXKEERTHI-ARGANO, 05/02/2023
                                       
                                       WHERE effective_date = TRUNC (SYSDATE));
                  WHEN OTHERS
                  THEN
                     fnd_file.put_line
                        (fnd_file.LOG,
                            'Error in updating the status before inserting to seeded intf tables-'
                         || SQLERRM
                        );
               END;

               COMMIT;
            END LOOP;

            BEGIN
               l_tsg_po_num := NULL;

               FOR r_po_rec_insert IN c_po_rec_insert
               LOOP
                  BEGIN
                     l_status := NULL;

                     IF NVL (l_tsg_po_num, 1) <> r_po_rec_insert.tsg_po_num
                     THEN
                        BEGIN
                           l_line_num := 0;
                           --INSERT INTO po.po_headers_interface  --Commented code by MXKEERTHI-ARGANO, 05/08/2023
                            INSERT INTO apps.po_headers_interface  --code added by MXKEERTHI-ARGANO, 05/08/2023
                                       (interface_header_id,
                                        batch_id,
                                        process_code, action, org_id,
                                        document_type_code, currency_code,
                                        agent_id,
                                        vendor_id,
                                        vendor_site_id,
                                        ship_to_location_id,
                                        bill_to_location_id, style_id,
                                        attribute_category, attribute1,
                                        attribute2,
                                        creation_date
                                       )
                                VALUES (po_headers_interface_s.NEXTVAL,
                                        po_headers_interface_s.NEXTVAL,
                                        'PENDING', 'ORIGINAL', l_org_id,
                                        'STANDARD', 'USD',
                                        r_po_rec_insert.agent_id,
                                        r_po_rec_insert.vendor_id,
                                        r_po_rec_insert.vendor_site_id,
                                        l_ship_to_location_id,
                                        l_bill_to_location_id, NULL,
                                        'TSG', r_po_rec_insert.tsg_po_num,
                                        r_po_rec_insert.customer_name,
                                        SYSDATE
                                       );
                        EXCEPTION
                           WHEN OTHERS
                           THEN
						      -- UPDATE cust.ttec_po_us_tsg_stg  --Commented code by MXKEERTHI-ARGANO, 05/08/2023
                              UPDATE apps.ttec_po_us_tsg_stg--code added by MXKEERTHI-ARGANO, 05/08/2023
                                    SET status = 'UNPROCESSED',
                                     error_desc =
                                        SUBSTRB
                                           (   'Error Interfacing HDR Record -'
                                            || r_po_rec_insert.tsg_po_num
                                            || '-'
                                            || r_po_rec_insert.line_num,
                                            1,
                                            100
                                           )
                               WHERE tsg_po_num = r_po_rec_insert.tsg_po_num
                                 AND line_num = r_po_rec_insert.line_num
                                 AND create_request_id =
                                        (SELECT MAX (create_request_id)
										  --FROM cust.ttec_po_us_tsg_stg--Commented code by MXKEERTHI-ARGANO, 05/02/2023
                                           FROM APPS.ttec_po_us_tsg_stg   --code Added  by MXKEERTHI-ARGANO, 05/02/2023
                                          WHERE effective_date =
                                                               TRUNC (SYSDATE));

                              fnd_file.put_line
                                            (fnd_file.LOG,
                                                'Error Insert Header Record -'
                                             || SQLERRM
                                            );
                        END;
                     END IF;

                     BEGIN
                        ---Line Loop for Quantity Based line
                        l_line_num := l_line_num + 1;
                        --INSERT INTO po.po_lines_interface  --Commented code by MXKEERTHI-ARGANO, 05/08/2023
                        INSERT INTO apps.po_lines_interface --code added by MXKEERTHI-ARGANO, 05/08/2023

                        
                                    (interface_line_id,
                                     interface_header_id, action,
                                     line_num, line_type,
                                     CATEGORY,
                                     item_description,
                                     unit_of_measure,
                                     quantity,
                                     unit_price, ship_to_organization_id,
                                     ship_to_location_id, need_by_date,
                                     promised_date,
                                     line_attribute_category_lines,
                                     line_attribute1,
                                     line_attribute2, creation_date,
                                     line_loc_populated_flag
                                    )
                             VALUES (po_lines_interface_s.NEXTVAL,
                                     po_headers_interface_s.CURRVAL, 'ADD',
                                     l_line_num, 'Goods',
                                     r_po_rec_insert.category_name,
                                     r_po_rec_insert.item_desc,
                                     r_po_rec_insert.uom,
                                     r_po_rec_insert.quantity,
                                     r_po_rec_insert.unit_price, l_org_id,
                                     l_ship_to_location_id, SYSDATE,
                                     SYSDATE,
                                     'TSG',
                                     r_po_rec_insert.tsg_part_num,
                                     r_po_rec_insert.line_num, SYSDATE,
                                     'Y'
                                    );
                        --INSERT INTO po.po_line_locations_interface   --Commented code by MXKEERTHI-ARGANO, 05/08/2023
                        INSERT INTO apps.po_line_locations_interface  --code added by MXKEERTHI-ARGANO, 05/08/2023
 
                        
                                    (interface_line_location_id,
                                     interface_header_id,
                                     interface_line_id,
                                     shipment_type, payment_type,
                                     shipment_num, ship_to_organization_id,
                                     ship_to_location_id, need_by_date,
                                     promised_date, quantity,
                                     creation_date
                                    )
                             VALUES (po_line_locations_interface_s.NEXTVAL,
                                     po_headers_interface_s.CURRVAL,
                                     po_lines_interface_s.CURRVAL,
                                     'STANDARD', 'MILESTONE',
                                     l_line_num, l_org_id,
                                     l_ship_to_location_id, SYSDATE,
                                     SYSDATE, r_po_rec_insert.quantity,
                                     SYSDATE
                                    );
                         --INSERT INTO po.po_distributions_interface   --Commented code by MXKEERTHI-ARGANO, 05/08/2023
                         INSERT INTO apps.po_distributions_interface --code added by MXKEERTHI-ARGANO, 05/08/2023
                                    (interface_header_id,
                                     interface_line_id,
                                     interface_line_location_id,
                                     interface_distribution_id,
                                     distribution_num, org_id,
                                     quantity_ordered,
                                     charge_account_id,
                                     charge_account_segment1,
                                     charge_account_segment2,
                                     charge_account_segment3,
                                     charge_account_segment4,
                                     charge_account_segment5,
                                     charge_account_segment6, creation_date
                                    )
                             VALUES (po_headers_interface_s.CURRVAL,
                                     po_lines_interface_s.CURRVAL,
                                     po_line_locations_interface_s.CURRVAL,
									 --po.po_distributions_interface_s.NEXTVAL,  --Commented code by MXKEERTHI-ARGANO, 05/08/2023
                                     apps.po_distributions_interface_s.NEXTVAL,  --code added by MXKEERTHI-ARGANO, 05/08/2023

                                     
                                     l_line_num, l_org_id,
                                     r_po_rec_insert.quantity,
                                     r_po_rec_insert.charge_acct_id,
                                     r_po_rec_insert.charge_location,
                                     r_po_rec_insert.charge_client,
                                     r_po_rec_insert.charge_dept,
                                     r_po_rec_insert.charge_account,
                                     '0000',
                                     '0000', SYSDATE
                                    );
                        --UPDATE cust.ttec_po_us_tsg_stg  --Commented code by MXKEERTHI-ARGANO, 05/08/2023
                          UPDATE apps.ttec_po_us_tsg_stg --code added by MXKEERTHI-ARGANO, 05/08/2023
 
                      
                           SET status = 'PROCESSED'
                         WHERE tsg_po_num = r_po_rec_insert.tsg_po_num
                           AND create_request_id =
                                     (SELECT MAX (create_request_id)
									 --FROM cust.ttec_po_us_tsg_stg --Commented code by MXKEERTHI-ARGANO, 05/02/2023
                                       FROM APPS.ttec_po_us_tsg_stg   --code Added  by MXKEERTHI-ARGANO, 05/02/2023
                                       WHERE effective_date = TRUNC (SYSDATE));
                     EXCEPTION
                        WHEN OTHERS
                        THEN
						   --UPDATE cust.ttec_po_us_tsg_stg --Commented code by MXKEERTHI-ARGANO, 05/02/2023
                           UPDATE APPS.ttec_po_us_tsg_stg   --code Added  by MXKEERTHI-ARGANO, 05/02/2023
                           
                              SET status = 'UNPROCESSED',
                                  error_desc =
                                     SUBSTRB
                                        (   'Error Interfacing LINE Record -'
                                         || r_po_rec_insert.tsg_po_num
                                         || '-'
                                         || r_po_rec_insert.line_num,
                                         1,
                                         100
                                        )
                            WHERE tsg_po_num = r_po_rec_insert.tsg_po_num
                              AND line_num = r_po_rec_insert.line_num
                              AND create_request_id =
                                     (SELECT MAX (create_request_id)
									   --FROM cust.ttec_po_us_tsg_stg --Commented code by MXKEERTHI-ARGANO, 05/02/2023
                                        FROM APPS.ttec_po_us_tsg_stg   --code Added  by MXKEERTHI-ARGANO, 05/02/2023
                                        
                                       WHERE effective_date = TRUNC (SYSDATE));

                           fnd_file.put_line (fnd_file.LOG,
                                                 'Error Insert LINE Record -'
                                              || r_po_rec_insert.tsg_po_num
                                              || '-'
                                              || r_po_rec_insert.line_num
                                              || '-'
                                              || SQLERRM
                                             );
                     END;

                     l_tsg_po_num := NULL;
                     l_tsg_po_num := r_po_rec_insert.tsg_po_num;
                  END;

                  COMMIT;
               END LOOP;

               FOR r_clear_intf_rec IN c_clear_intf_rec
               LOOP
			      --DELETE FROM .po_distributions_interface --Commented code by MXKEERTHI-ARGANO, 05/02/2023
                  DELETE FROM APPS.po_distributions_interface   --code Added  by MXKEERTHI-ARGANO, 05/02/2023
                        WHERE interface_header_id =
                                         r_clear_intf_rec.interface_header_id;
										 
                  --DELETE FROM po.po_line_locations_interface --Commented code by MXKEERTHI-ARGANO, 05/02/2023
                  DELETE FROM APPS.po_line_locations_interface   --code Added  by MXKEERTHI-ARGANO, 05/02/2023
                        WHERE interface_header_id =
                                         r_clear_intf_rec.interface_header_id;
										 
                  --DELETE FROM  po.po_lines_interface --Commented code by MXKEERTHI-ARGANO, 05/02/2023
                  DELETE FROM APPS.po_lines_interface   --code Added  by MXKEERTHI-ARGANO, 05/02/2023
                        WHERE interface_header_id =
                                         r_clear_intf_rec.interface_header_id;
										 
                  --DELETE FROM po.po_headers_interface --Commented code by MXKEERTHI-ARGANO, 05/02/2023
                  DELETE FROM APPS.po_headers_interface   --code Added  by MXKEERTHI-ARGANO, 05/02/2023
                         WHERE interface_header_id =
                                         r_clear_intf_rec.interface_header_id;
               END LOOP;
			   
               --DELETE FROM cust.ttec_po_us_tsg_stg --Commented code by MXKEERTHI-ARGANO, 05/02/2023
               DELETE FROM APPS.ttec_po_us_tsg_stg   --code Added  by MXKEERTHI-ARGANO, 05/02/2023
               
                     WHERE TO_DATE (effective_date) = TRUNC (SYSDATE) - 45;

               COMMIT;

               BEGIN
                  v_rec := NULL;
                  v_rec :=
                        'tsg_po_num'
                     || '|'
                     || 'line_num'
                     || '|'
                     || 'agent_name'
                     || '|'
                     || 'vendor_name'
                     || '|'
                     || 'vendor_site_code'
                     || '|'
                     || 'category_name'
                     || '|'
                     || 'item_desc'
                     || '|'
                     || 'uom'
                     || '|'
                     || 'quantity'
                     || '|'
                     || 'unit_price'
                     || '|'
                     || 'charge_loction'
                     || '|'
                     || 'charge_client'
                     || '|'
                     || 'charge_dept'
                     || '|'
                     || 'effective_date'
                     || '|'
                     || 'agent_id'
                     || '|'
                     || 'vendor_id'
                     || '|'
                     || 'vendor_site_id'
                     || '|'
                     || 'category_id'
                     || '|'
                     || 'charge_acc_id'
                     || '|'
                     || 'status'
                     || '|'
                     || 'error_desc'
                     || '|'
                     || 'create_request_id'
                     || '|'
                     || 'creation_date'
                     || '|'
                     || 'created_by'
                     || '|'
                     || 'last_update_date'
                     || '|'
                     || 'last_updated_by'
                     || '|'
                     || 'last_update_login';
                  fnd_file.put_line (fnd_file.output, v_rec);

                  FOR r_po_rpt IN c_po_rpt
                  LOOP
                     v_rec := NULL;
                     v_rec :=
                           r_po_rpt.tsg_po_num
                        || '|'
                        || r_po_rpt.line_num
                        || '|'
                        || r_po_rpt.agent_name
                        || '|'
                        || r_po_rpt.vendor_name
                        || '|'
                        || r_po_rpt.vendor_site_code
                        || '|'
                        || r_po_rpt.category_name
                        || '|'
                        || r_po_rpt.item_desc
                        || '|'
                        || r_po_rpt.uom
                        || '|'
                        || r_po_rpt.quantity
                        || '|'
                        || r_po_rpt.unit_price
                        || '|'
                        || r_po_rpt.charge_location
                        || '|'
                        || r_po_rpt.charge_client
                        || '|'
                        || r_po_rpt.charge_dept
                        || '|'
                        || r_po_rpt.effective_date
                        || '|'
                        || r_po_rpt.agent_id
                        || '|'
                        || r_po_rpt.vendor_id
                        || '|'
                        || r_po_rpt.vendor_site_id
                        || '|'
                        || r_po_rpt.status
                        || '|'
                        || r_po_rpt.error_desc
                        || '|'
                        || r_po_rpt.create_request_id
                        || '|'
                        || r_po_rpt.creation_date
                        || '|'
                        || r_po_rpt.created_by
                        || '|'
                        || r_po_rpt.last_update_date
                        || '|'
                        || r_po_rpt.last_updated_by
                        || '|'
                        || r_po_rpt.last_update_login;
                     fnd_file.put_line (fnd_file.output, v_rec);
                  END LOOP;
               END;
            END;
         END IF;
      END;
   END main;

   PROCEDURE main_rcpt (errbuf OUT VARCHAR2, retcode OUT NUMBER)
   IS
      CURSOR c_rcpt_insert
      IS
         SELECT   tsg_po_num, tsg_po_line_num, tsg_part_num,
                  SUM (quantity) quantity, effective_date
		     --FROM cust.ttec_po_rcpt_load_ext   --Commented code by MXKEERTHI-ARGANO, 05/02/2023
             FROM APPS.ttec_po_rcpt_load_ext  --code Added  by MXKEERTHI-ARGANO, 05/02/2023
         GROUP BY tsg_po_num, tsg_po_line_num, tsg_part_num,effective_date;

      CURSOR c_rcpt_rpt
      IS
         SELECT   tsg_po_num, tsg_po_line_num, tsg_part_num, quantity,
                  effective_date, po_hdr_id, po_line_id, line_loc_id,
                  po_dis_id, vendor_id, status, error_desc,
                  create_request_id, creation_date, created_by,
                  last_update_date, last_updated_by, last_update_login
		     --FROM cust.ttec_po_rcpt_tsg_stg tpu  --Commented code by MXKEERTHI-ARGANO, 05/02/2023
             FROM apps.ttec_po_rcpt_tsg_stg tpu   --code Added  by MXKEERTHI-ARGANO, 05/02/2023
            WHERE TO_DATE (tpu.effective_date) = TRUNC (SYSDATE)
              AND tpu.create_request_id = fnd_global.conc_request_id
         ORDER BY 1;

      CURSOR c_rcpt_rec
      IS
         SELECT   tsg_po_num, tsg_po_line_num, tsg_part_num, quantity,
                  effective_date, po_hdr_id, po_line_id, line_loc_id,
                  po_dis_id, vendor_id, status, error_desc, create_request_id,
                  creation_date, created_by, last_update_date,
                  last_updated_by, last_update_login
		     --FROM cust.ttec_po_rcpt_tsg_stg tpu  --Commented code by MXKEERTHI-ARGANO, 05/02/2023
             FROM APPS.ttec_po_rcpt_tsg_stg tpu   --code Added  by MXKEERTHI-ARGANO, 05/02/2023
            WHERE TO_DATE (tpu.effective_date) = TRUNC (SYSDATE)
              AND tpu.status = 'READY'
              AND tpu.create_request_id = fnd_global.conc_request_id
         ORDER BY 1;

      l_org_name         VARCHAR2 (50)                      := 'Technology Solutions Group, Inc.';--'TSG-TeleTech';
      -- 'TeleTech United States'
      l_org_id           po_headers_interface.org_id%TYPE   DEFAULT NULL;
      l_status           VARCHAR2 (10)                      DEFAULT NULL;
      l_error_desc       VARCHAR2 (5000)                    DEFAULT NULL;
      l_po_hdr_id        NUMBER                             DEFAULT NULL;
      l_po_line_id       NUMBER                             DEFAULT NULL;
      l_line_loc_id      NUMBER                             DEFAULT NULL;
      l_po_dis_id        NUMBER                             DEFAULT NULL;
      l_ship_to_loc_id   NUMBER                             DEFAULT NULL;
      l_po_qty           NUMBER                             DEFAULT NULL;
      l_rcv_qty          NUMBER                             DEFAULT 0;
      l_cnt              NUMBER                             DEFAULT 0;
      v_rec              VARCHAR2 (10000)                   DEFAULT NULL;
      l_tsg_po_num       VARCHAR2 (100)                     DEFAULT NULL;
      l_vendor_id        po_vendors.vendor_id%TYPE          DEFAULT NULL;
      l_oracle_po        apps.po_headers_all.segment1%TYPE  DEFAULT NULL;
      l_oracle_po_line   apps.po_lines_all.line_num%TYPE    DEFAULT NULL;
      l_po_verify        NUMBER                             DEFAULT 0;

      TYPE po_rec_error_log IS TABLE OF VARCHAR2(1000);
      po_rec_not_available           po_rec_error_log;
      po_rec_line_match              po_rec_error_log;
/*      po_rec_item_match              po_rec_error_log;*/
      po_rec_qty                     po_rec_error_log;

   BEGIN
      po_rec_not_available := po_rec_error_log();
      po_rec_line_match := po_rec_error_log();
/*      po_rec_item_match := po_rec_error_log();*/
      po_rec_qty := po_rec_error_log();

/* Assign org_id based on variable l_org_name */
      SELECT organization_id
        INTO l_org_id
        FROM hr_all_organization_units
       WHERE NAME = l_org_name;

      FOR r_rcpt_insert IN c_rcpt_insert
      LOOP
         BEGIN
            BEGIN
            SELECT 1
              INTO l_po_verify
			   --FROM po.po_headers_all poh  --Commented code by MXKEERTHI-ARGANO, 05/02/2023
              FROM APPS.po_headers_all poh  --code Added  by MXKEERTHI-ARGANO, 05/02/2023
             WHERE poh.attribute1 = r_rcpt_insert.tsg_po_num
               AND poh.org_id = l_org_id;
            EXCEPTION
            WHEN OTHERS
            THEN
                  po_rec_not_available.extend;
                  po_rec_not_available(po_rec_not_available.last) := r_rcpt_insert.tsg_po_num || '/' ||
                                          r_rcpt_insert.tsg_po_line_num;
            END;

            BEGIN
               l_po_qty := NULL;
               l_po_hdr_id := NULL;
               l_po_line_id := NULL;
               l_line_loc_id := NULL;
               l_po_dis_id := NULL;
               l_vendor_id := NULL;
               l_error_desc := NULL;
               l_status := NULL;

               SELECT NVL (pla.quantity, 0), poh.po_header_id,
                      pla.po_line_id, plla.line_location_id,
                      pda.po_distribution_id, poh.vendor_id,
                      plla.ship_to_location_id
                 INTO l_po_qty, l_po_hdr_id,
                      l_po_line_id, l_line_loc_id,
                      l_po_dis_id, l_vendor_id,
                      l_ship_to_loc_id
                 --FROM po.po_headers_all poh,  --Commented code by MXKEERTHI-ARGANO, 05/02/2023
                  FROM APPS.po_headers_all poh, --code Added  by MXKEERTHI-ARGANO, 05/02/2023
			  
                      po_lines_all pla,
                      po_line_locations_all plla,
                      po_distributions_all pda
                WHERE poh.po_header_id = pla.po_header_id
                  AND pla.po_line_id = plla.po_line_id
                  AND poh.po_header_id = plla.po_header_id
                  AND pda.po_header_id = poh.po_header_id
                  AND pda.po_line_id = pla.po_line_id
                  AND poh.attribute1 = r_rcpt_insert.tsg_po_num
                  AND pla.attribute1 = r_rcpt_insert.tsg_part_num
                  AND pla.attribute2 = r_rcpt_insert.tsg_po_line_num;
            EXCEPTION
              /* WHEN NO_DATA_FOUND
               THEN
                  l_status := 'ERROR';
                  l_error_desc := l_error_desc || 'NO PO Available';
               WHEN OTHERS
               THEN
                  l_status := 'ERROR';
                  l_error_desc := l_error_desc || 'Error PO Query Validation';*/

                  WHEN OTHERS
                  THEN
                  po_rec_line_match.extend;
                  po_rec_line_match(po_rec_line_match.last) := r_rcpt_insert.tsg_po_num || '/' ||
                                          r_rcpt_insert.tsg_po_line_num || '/' || r_rcpt_insert.quantity; -- Ver 1.5
            END;

            IF l_po_qty > 0
            THEN
               BEGIN
                  l_rcv_qty := 0;

                  SELECT NVL (SUM (quantity), 0)
                    INTO l_rcv_qty
                    FROM rcv_transactions
                   WHERE po_header_id = l_po_hdr_id
                     AND po_line_id = l_po_line_id
                     AND transaction_type = 'DELIVER'; -- Ver 1.4
               EXCEPTION
                  WHEN NO_DATA_FOUND
                  THEN
                     l_rcv_qty := 0;
                  WHEN OTHERS
                  THEN
                     l_rcv_qty := 0;
               END;

               IF (l_rcv_qty + r_rcpt_insert.quantity) <= l_po_qty
               THEN
                  l_status := 'READY';
               ELSE
                  l_status := 'ERROR';
                  /*l_error_desc := l_error_desc || 'Provided Qty is Wrong';*/
                   BEGIN

                   SELECT a.segment1, b.line_num
                   INTO l_oracle_po, l_oracle_po_line
                   FROM apps.po_headers_all a, apps.po_lines_all b
                  WHERE a.po_header_id = b.po_header_id
                    AND a.org_id = l_org_id
                    AND a.attribute1 = r_rcpt_insert.tsg_po_num
                    AND b.attribute2 = r_rcpt_insert.tsg_po_line_num;

                    po_rec_qty.extend;
                    po_rec_qty(po_rec_qty.last) := r_rcpt_insert.tsg_po_num || '/' ||
                                            r_rcpt_insert.tsg_po_line_num || '/' ||
                                            r_rcpt_insert.quantity || '/' ||
                                            (l_po_qty - l_rcv_qty) || '/' ||
                                            l_oracle_po || '/' || l_oracle_po_line;
                   EXCEPTION
                   WHEN OTHERS THEN

                    po_rec_qty.extend;
                    po_rec_qty(po_rec_qty.last) := r_rcpt_insert.tsg_po_num || '/' ||
                                            r_rcpt_insert.tsg_po_line_num || '/' ||
                                            r_rcpt_insert.quantity || '/' ||
                                            (l_po_qty - l_rcv_qty);

                   END;

               END IF;
            END IF;

            INSERT INTO ttec_po_rcpt_tsg_stg
                        (tsg_po_num,
                         tsg_po_line_num,
                         tsg_part_num, quantity,
                         effective_date, po_hdr_id, po_line_id,
                         line_loc_id, po_dis_id, vendor_id, status,
                         error_desc,
                         create_request_id, creation_date,
                         created_by, last_update_date, last_updated_by,
                         last_update_login
                        )
                 VALUES (r_rcpt_insert.tsg_po_num,
                         r_rcpt_insert.tsg_po_line_num,
                         r_rcpt_insert.tsg_part_num, r_rcpt_insert.quantity,
                         TRUNC (SYSDATE), l_po_hdr_id, l_po_line_id,
                         l_line_loc_id, l_po_dis_id, l_vendor_id, l_status,
                         SUBSTRB (l_error_desc, 1, 100),
                         fnd_global.conc_request_id, SYSDATE,
                         fnd_global.login_id, SYSDATE, fnd_global.login_id,
                         fnd_global.login_id
                        );
         END;
      END LOOP;

/* To print error in log if present for each record */
/*      fnd_file.put_line (fnd_file.LOG, l_error_desc);*/
    IF po_rec_not_available.count != 0 THEN
     fnd_file.put_line (fnd_file.LOG, 'Error Type: PO Not available');
     fnd_file.put_line (fnd_file.LOG, 'TSG PO Number/TSG PO Line Number');
     FOR i IN 1 .. po_rec_not_available.count
     LOOP
     fnd_file.put_line (fnd_file.LOG, po_rec_not_available(i));
     END LOOP;
     fnd_file.put_line (fnd_file.LOG,CHR(10));
     END IF;

     IF po_rec_line_match.count != 0 THEN
     fnd_file.put_line (fnd_file.LOG, 'Error Type: PO Line Not Matching');
     fnd_file.put_line (fnd_file.LOG, 'TSG PO Number/TSG PO Line Number/Line Quantity'); -- Ver 1.5
     FOR i IN 1 .. po_rec_line_match.count
     LOOP
     fnd_file.put_line (fnd_file.LOG, po_rec_line_match(i));
     END LOOP;
     fnd_file.put_line (fnd_file.LOG,CHR(10));
     END IF;

     IF po_rec_qty.count != 0 THEN
     fnd_file.put_line (fnd_file.LOG, 'Error Type: Open PO Qty is less than Qty on receipt file');
     fnd_file.put_line (fnd_file.LOG, 'TSG PO Number/TSG PO Line Number/Qty In Recipt File/Open Qty on PO Line/Oracle PO/Oracle PO Line');
     FOR i IN 1 .. po_rec_qty.count
     LOOP
     fnd_file.put_line (fnd_file.LOG, po_rec_qty(i));
     END LOOP;
     fnd_file.put_line (fnd_file.LOG,CHR(10));
     END IF;

      BEGIN
         l_cnt := 0;

         BEGIN
            SELECT NVL (COUNT (*), 0)
              INTO l_cnt
              --FROM cust.ttec_po_rcpt_tsg_stg  --Commented code by MXKEERTHI-ARGANO, 05/02/2023
			  FROM APPS.ttec_po_rcpt_tsg_stg    ----code Added  by MXKEERTHI-ARGANO, 05/02/2023
             WHERE status = 'ERROR'
               AND effective_date = TRUNC (SYSDATE)
     AND create_request_id =
                           (SELECT MAX (create_request_id)
						      --FROM cust.ttec_po_rcpt_tsg_stg  --Commented code by MXKEERTHI-ARGANO, 05/02/2023
                              FROM apps.ttec_po_rcpt_tsg_stg     ----code Added  by MXKEERTHI-ARGANO, 05/02/2023
                             WHERE effective_date = TRUNC (SYSDATE));
         EXCEPTION
            WHEN NO_DATA_FOUND
            THEN
               l_cnt := -1;
            WHEN OTHERS
            THEN
               l_cnt := -1;
         END;

         IF l_cnt > 0
         THEN
            v_rec := NULL;
            v_rec :=
                  'tsg_po_num'
               || '|'
               || 'tsg_po_line_num'
               || '|'
               || 'tsg_part_num'
               || '|'
               || 'quantity'
               || '|'
               || 'effective_date'
               || '|'
               || 'po_hdr_id'
               || '|'
               || 'po_line_id'
               || '|'
               || 'line_loc_id'
               || '|'
               || 'po_dis_id'
               || '|'
               || 'vendor_id'
               || '|'
               || 'status'
               || '|'
               || 'error_desc'
               || '|'
               || 'create_request_id'
               || '|'
               || 'creation_date'
               || '|'
               || 'created_by'
               || '|'
               || 'last_update_date'
               || '|'
               || 'last_updated_by'
               || '|'
               || 'last_update_login';
            fnd_file.put_line (fnd_file.output, v_rec);

            FOR r_rcpt_rpt IN c_rcpt_rpt
            LOOP
               v_rec := NULL;
               v_rec :=
                     r_rcpt_rpt.tsg_po_num
                  || '|'
                  || r_rcpt_rpt.tsg_po_line_num
                  || '|'
                  || r_rcpt_rpt.tsg_part_num
                  || '|'
                  || r_rcpt_rpt.quantity
                  || '|'
                  || r_rcpt_rpt.effective_date
                  || '|'
                  || r_rcpt_rpt.po_hdr_id
                  || '|'
                  || r_rcpt_rpt.po_line_id
                  || '|'
                  || r_rcpt_rpt.po_dis_id
                  || '|'
                  || r_rcpt_rpt.vendor_id
                  || '|'
                  || r_rcpt_rpt.status
                  || '|'
                  || r_rcpt_rpt.error_desc
                  || '|'
                  || r_rcpt_rpt.create_request_id
                  || '|'
                  || r_rcpt_rpt.creation_date
                  || '|'
                  || r_rcpt_rpt.created_by
                  || '|'
                  || r_rcpt_rpt.last_update_date
                  || '|'
                  || r_rcpt_rpt.last_updated_by
                  || '|'
                  || r_rcpt_rpt.last_update_login;
               fnd_file.put_line (fnd_file.output, v_rec);
            END LOOP;
            --DELETE FROM cust.ttec_po_rcpt_tsg_stg tpu --Commented code by MXKEERTHI-ARGANO, 05/02/2023
            DELETE FROM APPS.ttec_po_rcpt_tsg_stg tpu   ----code Added  by MXKEERTHI-ARGANO, 05/02/2023
                  WHERE tpu.create_request_id =
                                     (SELECT MAX (create_request_id)
									    --FROM cust.ttec_po_rcpt_tsg_stg --Commented code by MXKEERTHI-ARGANO, 05/02/2023
                                        FROM APPS.ttec_po_rcpt_tsg_stg   ----code Added  by MXKEERTHI-ARGANO, 05/02/2023
                                        
                                       WHERE effective_date = TRUNC (SYSDATE));

            COMMIT;
         ELSIF l_cnt = 0
         THEN
            BEGIN
               FOR r_rcpt_rec IN c_rcpt_rec
               LOOP
                  BEGIN
                     l_status := NULL;

                     IF NVL (l_tsg_po_num, 1) <> r_rcpt_rec.tsg_po_num
                     THEN
                        BEGIN
                           INSERT INTO rcv_headers_interface
                                       (header_interface_id,
                                        GROUP_ID,
                                        processing_status_code,
                                        receipt_source_code,
                                        transaction_type, test_flag,
                                        auto_transact_code,
                                        last_update_date, last_updated_by,
                                        creation_date, created_by,
                                        expected_receipt_date,
                                        comments, validation_flag,
                                        transaction_date, org_id,
                                        vendor_id,
                                        location_id
                                       )
                                VALUES (rcv_headers_interface_s.NEXTVAL,
                                        rcv_interface_groups_s.NEXTVAL,
                                        'PENDING',
                                        'VENDOR',
                                        'NEW', 'N',
                                        'RECEIVE',
                                        SYSDATE, fnd_global.user_id,
                                        SYSDATE, fnd_global.user_id,
                                        SYSDATE,
                                        'Auto Custom Receipt Creation', 'Y',
                                        SYSDATE, l_org_id,
                                        r_rcpt_rec.vendor_id,
                                        l_ship_to_loc_id
                                       );
                        EXCEPTION
                           WHEN OTHERS
                           THEN
						      --UPDATE cust.ttec_po_rcpt_tsg_stg --Commented code by MXKEERTHI-ARGANO, 05/02/2023
                                 UPDATE APPS.ttec_po_rcpt_tsg_stg  ----code Added  by MXKEERTHI-ARGANO, 05/02/2023
                              
                                 SET status = 'UNPROCESSED',
                                     error_desc =
                                        SUBSTRB
                                           (   'Error Interfacing HDR Record -'
                                            || r_rcpt_rec.tsg_po_num
                                            || '-'
                                            || r_rcpt_rec.tsg_part_num,
                                            1,
                                            100
                                           )
                               WHERE tsg_po_num = r_rcpt_rec.tsg_po_num
                                 AND tsg_part_num = r_rcpt_rec.tsg_part_num
                                 AND create_request_id =
                                        (SELECT MAX (create_request_id)
										   --FROM cust.ttec_po_rcpt_tsg_stg  --Commented code by MXKEERTHI-ARGANO, 05/02/2023
                                            FROM APPS.ttec_po_rcpt_tsg_stg ----code Added  by MXKEERTHI-ARGANO, 05/02/2023
                              
                                          
                                          WHERE effective_date =
                                                               TRUNC (SYSDATE));

                              fnd_file.put_line
                                            (fnd_file.LOG,
                                                'Error Insert Header Record -'
                                             || SQLERRM
                                            );
                        END;
                     END IF;

                     BEGIN
                        INSERT INTO rcv_transactions_interface
                                    (interface_transaction_id,
                                     header_interface_id,
                                     GROUP_ID,
                                     processing_status_code,
                                     transaction_status_code,
                                     auto_transact_code,
                                     receipt_source_code,
                                     destination_type_code,
                                     transaction_type, processing_mode_code,
                                     quantity,
                                     primary_quantity, source_document_code,
                                     transaction_date, po_header_id,
                                     po_line_id,
                                     po_line_location_id,
                                     po_distribution_id,
                                     vendor_id, location_id,
                                     deliver_to_location_id,
                                     comments,
                                     last_update_date, last_updated_by,
                                     creation_date, created_by, org_id,
                                     to_organization_id, validation_flag
                                    )
                             VALUES (rcv_transactions_interface_s.NEXTVAL,
                                     rcv_headers_interface_s.CURRVAL,
                                     rcv_interface_groups_s.CURRVAL,
                                     'PENDING',
                                     'PENDING',
                                     'DELIVER',
                                     'VENDOR',
                                     'RECEIVING',
                                     'RECEIVE', 'BATCH',
                                     r_rcpt_rec.quantity,
                                     r_rcpt_rec.quantity, 'PO',
                                     SYSDATE, r_rcpt_rec.po_hdr_id,
                                     r_rcpt_rec.po_line_id,
                                     r_rcpt_rec.line_loc_id,
                                     r_rcpt_rec.po_dis_id,
                                     r_rcpt_rec.vendor_id, l_ship_to_loc_id,
                                     l_ship_to_loc_id,
                                     'Auto Custom Receipt Creation',
                                     SYSDATE, fnd_global.user_id,
                                     SYSDATE, fnd_global.user_id, l_org_id,
                                     l_org_id, 'Y'
                                    );
                         --UPDATE cust.ttec_po_rcpt_tsg_stg  --Commented code by MXKEERTHI-ARGANO, 05/02/2023
                           
						   UPDATE APPS.ttec_po_rcpt_tsg_stg ----code Added  by MXKEERTHI-ARGANO, 05/02/2023
                           SET status = 'PROCESSED'
                         WHERE tsg_po_num = r_rcpt_rec.tsg_po_num
                           AND tsg_part_num = r_rcpt_rec.tsg_part_num
                           AND tsg_po_line_num = r_rcpt_rec.tsg_po_line_num
                           AND TO_DATE (effective_date) = TRUNC (SYSDATE);
                     EXCEPTION
                        WHEN OTHERS
                        THEN
                           UPDATE cust.ttec_po_rcpt_tsg_stg
                              SET status = 'UNPROCESSED',
                                  error_desc =
                                        'Error to insert -'
                                     || r_rcpt_rec.tsg_po_num
                                     || '-'
                                     || r_rcpt_rec.tsg_po_line_num
                                     || '-'
                                     || r_rcpt_rec.tsg_part_num
                            WHERE tsg_po_num = r_rcpt_rec.tsg_po_num
                              AND tsg_po_line_num = r_rcpt_rec.tsg_po_line_num
                              AND tsg_part_num = r_rcpt_rec.tsg_part_num
                              AND create_request_id =
                                     (SELECT MAX (create_request_id)
									    --FROM cust.ttec_po_rcpt_tsg_stg  --Commented code by MXKEERTHI-ARGANO, 05/02/2023
                           
						               FROM APPS.ttec_po_rcpt_tsg_stg----code Added  by MXKEERTHI-ARGANO, 05/02/2023
                                        
                                       WHERE effective_date = TRUNC (SYSDATE));

                           fnd_file.put_line (fnd_file.LOG,
                                                 'Error to Insert Receipt -'
                                              || r_rcpt_rec.tsg_po_num
                                              || '-'
                                              || r_rcpt_rec.tsg_po_line_num
                                              || '-'
                                              || r_rcpt_rec.tsg_part_num
                                              || '-'
                                              || r_rcpt_rec.po_hdr_id
                                              || '-'
                                              || r_rcpt_rec.po_line_id
                                              || '-'
                                              || r_rcpt_rec.po_dis_id
                                             );
                     END;

                     l_tsg_po_num := NULL;
                     l_tsg_po_num := r_rcpt_rec.tsg_po_num;
                  END;

                  COMMIT;
               END LOOP;
            END;
         END IF;
      END;
   END main_rcpt;
END ttec_po_us_tsg_interface;
/
show errors;
/