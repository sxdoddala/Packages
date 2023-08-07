create or replace PACKAGE BODY      ttec_agis_interface
AS
	/*--------------------------------------------------------------------

	Name: ttec_agis_interface (Package)
	Description: Creation of Intercompany Transactions for Invoices created on AP, AR & GL Modules
	Change History
	Changed By  Version Date  Reason for Change
	---------   ------- ----  -----------------
	Kaushik Babu  1.0  17-AUG-2011 Initial Creation For Argentina
    Kaushik Babu  1.1  01-JUN-2012 Fixed issue on the cr/db amount generated using get_intf_header_drcr procedure TTSD R 1544554
	IXPRAVEEN(ARGANO) 1.0	15-May-2023 R12.2 Upgrade Remediation
	--------------------------------------------------------------------*/
	--g_e_error_hand 			 cust.ttec_error_handling%ROWTYPE;			-- Commented code by IXPRAVEEN-ARGANO,15-May-2023
	g_e_error_hand 			 apps.ttec_error_handling%ROWTYPE;              --  code Added by IXPRAVEEN-ARGANO,   15-May-2023
	g_e_program_run_status	 NUMBER := 0;
	g_success_count			 NUMBER := 0;
	g_error_count				 NUMBER := 0;
	g_value						 VARCHAR2 (100) DEFAULT NULL;

	PROCEDURE print_line (p_data IN VARCHAR2)
	IS
	BEGIN
		fnd_file.put_line (fnd_file.LOG, p_data);
	END;

	PROCEDURE print_count (p_success_count IN NUMBER, p_error_count IN NUMBER, p_module IN VARCHAR2)
	IS
	BEGIN
		print_line ('**********************************');
		print_line ('Total Success Records Generated for ' || p_module || ' >>> ' || p_success_count);
		print_line ('Total Error Records Generated for ' || p_module || ' >>> ' || p_error_count);
		print_line ('**********************************');
	END;

	PROCEDURE get_file_open (p_filename IN VARCHAR2)
	IS
	BEGIN
		get_dir_name (v_dir_name);
		v_full_file_path := v_dir_name || '/' || p_filename;
		v_output_file :=
			UTL_FILE.fopen (
								 v_dir_name,
								 p_filename,
								 'w',
								 32000
								);
		print_line ('**********************************');
		print_line ('Output file created >>> ' || v_dir_name || '/' || p_filename);
		print_line ('**********************************');
		init_counts;
	END;

	PROCEDURE init_counts
	IS
	BEGIN
		g_success_count := 0;
		g_error_count := 0;
		g_value := NULL;
	END;

	PROCEDURE init_error_msg (p_module_name IN VARCHAR2)
	IS
	BEGIN
		g_e_error_hand := NULL;
		g_e_error_hand.module_name := p_module_name; 															--'main';
		g_e_error_hand.status := 'FAILURE';
		g_e_error_hand.application_code := 'FIN';
		g_e_error_hand.interface := 'TTECAGISINTF';
		g_e_error_hand.program_name := 'TTEC_AGIS_INTERFACE';
		g_e_error_hand.ERROR_CODE := 0;
	END;

	PROCEDURE log_error (
								p_label1 		IN VARCHAR2,
								p_reference1	IN VARCHAR2,
								p_label2 		IN VARCHAR2,
								p_reference2	IN VARCHAR2
							  )
	IS
	BEGIN
		-- not in this routine g_e_error_hand.module_name := 'log_error'

		-- g_e_error_hand := NULL;
		g_e_error_hand.ERROR_CODE := TO_CHAR (SQLCODE);
		g_e_error_hand.error_message := SUBSTR (SQLERRM, 1, 240);
		--cust.ttec_process_error (											-- Commented code by IXPRAVEEN-ARGANO,15-May-2023
		apps.ttec_process_error (                                           --  code Added by IXPRAVEEN-ARGANO,   15-May-2023
										 g_e_error_hand.application_code,
										 g_e_error_hand.interface,
										 g_e_error_hand.program_name,
										 g_e_error_hand.module_name,
										 g_e_error_hand.status,
										 g_e_error_hand.ERROR_CODE,
										 g_e_error_hand.error_message,
										 p_label1,
										 p_reference1,
										 p_label2,
										 p_reference2,
										 g_e_error_hand.label3,
										 g_e_error_hand.reference3,
										 g_e_error_hand.label4,
										 g_e_error_hand.reference4,
										 g_e_error_hand.label5,
										 g_e_error_hand.reference5,
										 g_e_error_hand.label6,
										 g_e_error_hand.reference6,
										 g_e_error_hand.label7,
										 g_e_error_hand.reference7,
										 g_e_error_hand.label8,
										 g_e_error_hand.reference8,
										 g_e_error_hand.label9,
										 g_e_error_hand.reference9,
										 g_e_error_hand.label10,
										 g_e_error_hand.reference10,
										 g_e_error_hand.label11,
										 g_e_error_hand.reference11,
										 g_e_error_hand.label12,
										 g_e_error_hand.reference12,
										 g_e_error_hand.label13,
										 g_e_error_hand.reference13,
										 g_e_error_hand.label14,
										 g_e_error_hand.reference14,
										 g_e_error_hand.label15,
										 g_e_error_hand.reference15
										);
	EXCEPTION
		WHEN OTHERS
		THEN
			-- log_error ('Routine', e_module_name, 'Error Message', SUBSTR (SQLERRM, 1, 80) );
			print_line ('Error in module: ' || g_e_error_hand.module_name);
			print_line ('Failed  with Error ' || TO_CHAR (SQLCODE) || '|' || SUBSTR (SQLERRM, 1, 64));
			g_e_program_run_status := 1;
	END;

	PROCEDURE get_host_name (p_host_name OUT VARCHAR2)
	IS
	BEGIN
		g_e_error_hand.module_name := 'Host Info';

		OPEN c_host;

		FETCH c_host INTO p_host_name;

		CLOSE c_host;
	EXCEPTION
		WHEN OTHERS
		THEN
			log_error (
						  'SQLCODE',
						  TO_CHAR (SQLCODE),
						  'Error Message',
						  SUBSTR (SQLERRM, 1, 64)
						 );
			print_line ('Error in module: ' || g_e_error_hand.module_name);
			print_line ('Failed  with Error ' || TO_CHAR (SQLCODE) || '|' || SUBSTR (SQLERRM, 1, 64));
	END;

	PROCEDURE get_dir_name (p_dir_name OUT VARCHAR2)
	IS
	BEGIN
		g_e_error_hand.module_name := 'Directory Path';

		OPEN c_directory_path;

		FETCH c_directory_path INTO p_dir_name;

		CLOSE c_directory_path;
	EXCEPTION
		WHEN OTHERS
		THEN
			log_error (
						  'SQLCODE',
						  TO_CHAR (SQLCODE),
						  'Error Message',
						  SUBSTR (SQLERRM, 1, 64)
						 );
			print_line ('Error in module: ' || g_e_error_hand.module_name);
			print_line ('Failed  with Error ' || TO_CHAR (SQLCODE) || '|' || SUBSTR (SQLERRM, 1, 64));
	END;

	FUNCTION ttec_create_ccid (p_concat_segs IN VARCHAR2)
		RETURN VARCHAR2
	IS
		l_status   BOOLEAN;
		l_coa_id   NUMBER;
	BEGIN
		l_status :=
			fnd_flex_keyval.validate_segs (
													 'CREATE_COMBINATION',
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
			RETURN 'F';
		END IF;

		print_line ('entered 17.5');
	END;

	PROCEDURE get_intf_header_drcr (
											  p_app_id		  IN		NUMBER,
                                              p_period_name   IN        VARCHAR2,       -- Ver 1.1
											  p_init_ledger_id IN	NUMBER,
											  p_init_le_id   IN		NUMBER,
											  p_rec_ledger_id IN 	NUMBER,
											  p_rec_le_id	  IN		NUMBER,
											  p_val			  IN		NUMBER,
											  p_dr				  OUT NUMBER,
											  p_cr				  OUT NUMBER
											 )
	IS
	BEGIN
		g_e_error_hand.module_name := 'Interface Header DR/CR';
		print_line (
				'entered 10.5'
			|| p_app_id
			|| '-'
            || p_period_name
            || '-'
			|| p_init_ledger_id
			|| '-'
			|| p_init_le_id
			|| '-'
			|| p_rec_ledger_id
			|| '-'
			|| p_rec_le_id
			|| '-'
			|| p_val);

		IF p_app_id IN (200, 222)
		THEN
			  SELECT SUM (xel.entered_dr), SUM (xel.entered_cr)
				 INTO p_dr, p_cr
				 --FROM xla.xla_transaction_entities xte,				-- Commented code by IXPRAVEEN-ARGANO,15-May-2023
				 FROM apps.xla_transaction_entities xte,                 --  code Added by IXPRAVEEN-ARGANO,   15-May-2023
						xla_ae_headers xah,
						xla_ae_lines xel,
						gl_code_combinations gcc,
						gl_legal_entities_bsvs gles,
						gl_legal_entities_bsvs glesb,
						xle_entity_profiles xle,
						xle_entity_profiles xleb,
						gl_ledger_config_details glcd,
						gl_ledgers igl,
						gl_ledger_config_details glcdb,
						gl_ledgers iglb,
						(SELECT trx_type_id, trx_type_code, trx_type_name
							FROM fun_trx_types_vl
						  WHERE enabled_flag = 'Y' AND trx_type_name = 'Automatic AGIS') trx_types
				WHERE 	 xte.entity_id = xah.entity_id
						AND xte.application_id = p_app_id
						AND xte.ledger_id = xah.ledger_id
						AND xah.accounting_entry_status_code = 'F'
						AND xah.gl_transfer_status_code = 'Y'
						AND xah.ae_header_id = xel.ae_header_id
						AND xah.ledger_id = xel.ledger_id
						AND xel.application_id != 101
						AND NVL (xel.attribute1, 'N') = 'N'
                        AND xah.period_name = NVL (p_period_name, xah.period_name)           -- Ver 1.1
						AND DECODE (xel.entered_dr,  '', 2,  xel.entered_cr, '',  1) = p_val
						AND xel.code_combination_id = gcc.code_combination_id
						AND gcc.enabled_flag = 'Y'
						AND TRUNC (SYSDATE) BETWEEN gcc.start_date_active
														AND NVL (gcc.end_date_active, TRUNC (SYSDATE))
						AND ( (gcc.segment4 <> '2500')
							  AND (gcc.segment5 <> '0000' AND (igl.ledger_id <> iglb.ledger_id)))
						AND gcc.segment1 = gles.flex_segment_value
						AND gles.legal_entity_id = glcd.object_id
						AND glcd.configuration_id = igl.configuration_id
						AND glcd.object_type_code = 'LEGAL_ENTITY'
						AND glcd.object_id = xle.legal_entity_id
						AND gcc.segment5 = glesb.flex_segment_value
						AND glesb.legal_entity_id = glcdb.object_id
						AND glcdb.configuration_id = iglb.configuration_id
						AND glcdb.object_type_code = 'LEGAL_ENTITY'
						AND glcdb.object_id = xleb.legal_entity_id
						AND (NVL (xel.entered_dr, 0) != 0 OR NVL (xel.entered_cr, 0) != 0)
						AND igl.ledger_id = p_init_ledger_id
						AND gles.legal_entity_id = p_init_le_id
						AND iglb.ledger_id = p_rec_ledger_id
						AND glesb.legal_entity_id = p_rec_le_id
			GROUP BY igl.ledger_id,
						gles.legal_entity_id,
						iglb.ledger_id,
						glesb.legal_entity_id;
		ELSE
			  SELECT SUM (gjl.entered_dr), SUM (gjl.entered_cr)
				 INTO p_dr, p_cr
				 FROM gl_je_headers gjh,
						gl_je_lines gjl,
						gl_code_combinations gcc,
						gl_legal_entities_bsvs gles,
						gl_legal_entities_bsvs glesb,
						xle_entity_profiles xle,
						xle_entity_profiles xleb,
						gl_ledger_config_details glcd,
						gl_ledgers igl,
						gl_ledger_config_details glcdb,
						gl_ledgers iglb,
						(SELECT trx_type_id, trx_type_code, trx_type_name
							FROM fun_trx_types_vl
						  WHERE enabled_flag = 'Y' AND trx_type_name = 'Automatic AGIS') trx_types
				WHERE 	 gjh.je_source IN ('Manual', 'Spreadsheet', 'Recurring')
						AND gjh.je_category <> '108'
						AND gjh.je_header_id = gjl.je_header_id
						AND gjh.ledger_id = gjl.ledger_id
						AND gjh.status = 'P'
						AND gjh.posted_date IS NOT NULL
                        AND gjh.period_name = NVL (p_period_name, gjh.period_name)           -- Ver 1.1
						AND DECODE (gjl.entered_dr,  '', 2,  gjl.entered_cr, '',  1) = p_val
						AND gjl.code_combination_id = gcc.code_combination_id
						AND gcc.enabled_flag = 'Y'
						AND TRUNC (SYSDATE) BETWEEN gcc.start_date_active
														AND NVL (gcc.end_date_active, TRUNC (SYSDATE))
						AND ( (gcc.segment4 <> '2500')
							  AND (gcc.segment5 <> '0000' AND (igl.ledger_id <> iglb.ledger_id)))
						AND gcc.segment1 = gles.flex_segment_value
						AND gles.legal_entity_id = glcd.object_id
						AND glcd.configuration_id = igl.configuration_id
						AND glcd.object_type_code = 'LEGAL_ENTITY'
						AND glcd.object_id = xle.legal_entity_id
						AND gcc.segment5 = glesb.flex_segment_value
						AND glesb.legal_entity_id = glcdb.object_id
						AND glcdb.configuration_id = iglb.configuration_id
						AND glcdb.object_type_code = 'LEGAL_ENTITY'
						AND NVL (gjl.attribute5, 'N') = 'N'
						AND glcdb.object_id = xleb.legal_entity_id
						AND (NVL (gjl.entered_dr, 0) != 0 OR NVL (gjl.entered_cr, 0) != 0)
						AND 101 = p_app_id
						AND igl.ledger_id = p_init_ledger_id
						AND gles.legal_entity_id = p_init_le_id
						AND iglb.ledger_id = p_rec_ledger_id
						AND glesb.legal_entity_id = p_rec_le_id
			GROUP BY igl.ledger_id,
						gles.legal_entity_id,
						iglb.ledger_id,
						glesb.legal_entity_id;
		END IF;

		print_line ('entered 10.7' || p_dr || '-' || p_cr);
	EXCEPTION
		WHEN OTHERS
		THEN
			log_error (
						  'SQLCODE',
						  TO_CHAR (SQLCODE),
						  'Error Message',
						  SUBSTR (SQLERRM, 1, 64)
						 );
			print_line ('Error in module: ' || g_e_error_hand.module_name);
			print_line ('Failed  with Error ' || TO_CHAR (SQLCODE) || '|' || SUBSTR (SQLERRM, 1, 64));
			v_error_flag := 'Y';
	END;

	PROCEDURE get_intercompany_info (
												p_le_name		IN 	 VARCHAR2,
												p_intcomp_id		OUT NUMBER,
												p_intcomp_name 	OUT VARCHAR2
											  )
	IS
	BEGIN
		g_e_error_hand.module_name := 'Intercompany Info';
		print_line ('entered 4.5' || p_le_name);

		SELECT qrslt.orgid, qrslt.orgname
		  INTO p_intcomp_id, p_intcomp_name
		  FROM (SELECT hzp.party_id orgid, hzp.party_name orgname,
							NVL (hzr_le.object_id, le.party_id) leid, NVL (hzp_le.party_name, le.name) lename,
							hzr_ou.subject_id ouid, hou.name ouname,
							DECODE (SIGN (NVL (hzusg.effective_end_date, SYSDATE) - SYSDATE), 1, 'Y', 'N') intercompanyflag,
							hzp.status status, arl.meaning statusdisplay,
							hzp.orig_system_reference systemreference
					 FROM hz_parties hzp,
							hz_party_usg_assignments hzusg,
							hz_relationships hzr_ou,
							hr_operating_units hou,
							hz_relationships hzr_le,
							hz_parties hzp_le,
							xle_entity_profiles le,
							ar_lookups arl
					WHERE 	 hzp.party_type = 'ORGANIZATION'
							AND hzr_ou.object_id(+) = hzp.party_id
							AND hzr_ou.subject_table_name(+) = 'HR_ALL_ORGANIZATION_UNITS'
							AND hzr_ou.object_table_name(+) = 'HZ_PARTIES'
							AND hzr_ou.relationship_type(+) = 'INTERCOMPANY_OPERATING_UNIT'
							AND hzr_ou.relationship_code(+) = 'OPERATING_UNIT_OF'
							AND hzr_ou.directional_flag(+) = 'B'
							AND hzr_ou.status(+) = 'A'
							AND TRUNC (hzr_ou.start_date(+)) <= TRUNC (SYSDATE)
							AND TRUNC (NVL (hzr_ou.end_date(+), SYSDATE)) >= TRUNC (SYSDATE)
							AND hou.organization_id(+) = hzr_ou.subject_id
							AND le.party_id(+) = hzp.party_id
							AND hzp_le.party_id(+) = hzr_le.object_id
							AND hzr_le.subject_id(+) = hzp.party_id
							AND hzr_le.subject_table_name(+) = 'HZ_PARTIES'
							AND hzr_le.object_table_name(+) = 'HZ_PARTIES'
							AND hzr_le.relationship_code(+) = 'INTERCOMPANY_ORGANIZATION_OF'
							AND hzr_le.relationship_type(+) = 'INTERCOMPANY_LEGAL_ENTITY'
							AND hzr_le.directional_flag(+) = 'F'
							AND hzr_le.status(+) = 'A'
							AND TRUNC (hzr_le.start_date(+)) <= TRUNC (SYSDATE)
							AND TRUNC (hzr_le.end_date(+)) >= TRUNC (SYSDATE)
							AND hzusg.party_id(+) = hzp.party_id
							AND hzusg.party_usage_code(+) = 'INTERCOMPANY_ORG'
							AND arl.lookup_code = hzp.status
							AND arl.lookup_type = 'REGISTRY_STATUS') qrslt
		 WHERE (lename = p_le_name
				  AND ( (EXISTS
								(SELECT 1
									FROM hz_party_usg_assignments hua
								  WHERE		hua.party_id = orgid
										  AND hua.party_usage_code = 'INTERCOMPANY_ORG'
										  AND SYSDATE BETWEEN hua.effective_start_date AND hua.effective_end_date))))
				 AND ROWNUM = 1;
	EXCEPTION
		WHEN NO_DATA_FOUND
		THEN
			p_intcomp_id := 1;
			p_intcomp_name := NULL;
		WHEN OTHERS
		THEN
			log_error (
						  'SQLCODE',
						  TO_CHAR (SQLCODE),
						  'Error Message',
						  SUBSTR (SQLERRM, 1, 64)
						 );
			print_line ('Error in module: ' || g_e_error_hand.module_name);
			print_line ('Failed  with Error ' || TO_CHAR (SQLCODE) || '|' || SUBSTR (SQLERRM, 1, 64));
			v_error_flag := 'Y';
	END;

	PROCEDURE init_agis_intf (p_ledger_id IN NUMBER, p_module_id IN NUMBER, p_period_name VARCHAR2)
	IS
		CURSOR c_inter_trx
		IS
			(SELECT xah.ae_header_id trx_id, xte.transaction_number transaction_num, igl.currency_code,
					  xel.entered_dr, xel.entered_cr, xel.code_combination_id, xel.ae_line_num line_num,
					  xel.accounting_date effective_date, trx_types.trx_type_name, trx_types.trx_type_id,
					  trx_types.trx_type_code, gcc.segment1, gcc.segment2, gcc.segment3, gcc.segment4,
					  gcc.segment5, gcc.segment6, gles.legal_entity_id init_le_id, xle.name init_le_name,
					  igl.ledger_id init_ledger_id, igl.name init_ledger_name,
					  glesb.legal_entity_id rec_le_id, xleb.name rec_le_name, iglb.ledger_id rec_ledger_id,
					  iglb.name rec_ledger_name, DECODE (xel.entered_dr,	'', 2,  xel.entered_cr, '',  1) val,
					  xah.period_name, xte.source_id_int_1
				--FROM xla.xla_transaction_entities xte,					-- Commented code by IXPRAVEEN-ARGANO,15-May-2023
				FROM apps.xla_transaction_entities xte,                      --  code Added by IXPRAVEEN-ARGANO,   15-May-2023
					  xla_ae_headers xah,
					  xla_ae_lines xel,
					  gl_code_combinations gcc,
					  gl_legal_entities_bsvs gles,
					  gl_legal_entities_bsvs glesb,
					  xle_entity_profiles xle,
					  xle_entity_profiles xleb,
					  gl_ledger_config_details glcd,
					  gl_ledgers igl,
					  gl_ledger_config_details glcdb,
					  gl_ledgers iglb,
					  (SELECT trx_type_id, trx_type_code, trx_type_name
						  FROM fun_trx_types_vl
						 WHERE enabled_flag = 'Y' AND trx_type_name = 'Automatic AGIS') trx_types
			  WHERE		xte.entity_id = xah.entity_id
					  AND xte.application_id = p_module_id
					  AND xte.ledger_id = xah.ledger_id
					  AND xah.accounting_entry_status_code = 'F'
					  AND xah.gl_transfer_status_code = 'Y'
					  AND xah.period_name = NVL (p_period_name, xah.period_name)
					  AND xah.ae_header_id = xel.ae_header_id
					  AND xah.ledger_id = xel.ledger_id
					  AND xel.application_id != 101
					  AND NVL (xel.attribute1, 'N') = 'N'
					  AND xel.code_combination_id = gcc.code_combination_id
					  AND gcc.enabled_flag = 'Y'
					  AND TRUNC (SYSDATE) BETWEEN gcc.start_date_active
													  AND NVL (gcc.end_date_active, TRUNC (SYSDATE))
					  AND ( (gcc.segment4 <> '2500')
							 AND (gcc.segment5 <> '0000' AND (igl.ledger_id <> iglb.ledger_id)))
					  AND gcc.segment1 = gles.flex_segment_value
					  AND gles.legal_entity_id = glcd.object_id
					  AND glcd.configuration_id = igl.configuration_id
					  AND igl.ledger_id = NVL (p_ledger_id, igl.ledger_id)
					  AND glcd.object_type_code = 'LEGAL_ENTITY'
					  AND glcd.object_id = xle.legal_entity_id
					  AND gcc.segment5 = glesb.flex_segment_value
					  AND glesb.legal_entity_id = glcdb.object_id
					  AND glcdb.configuration_id = iglb.configuration_id
					  AND glcdb.object_type_code = 'LEGAL_ENTITY'
					  AND glcdb.object_id = xleb.legal_entity_id
					  AND (NVL (xel.entered_dr, 0) != 0 OR NVL (xel.entered_cr, 0) != 0)
			 UNION ALL
			 SELECT gjh.je_header_id trx_id, gjh.name transaction_num, igl.currency_code, gjl.entered_dr,
					  gjl.entered_cr, gjl.code_combination_id, gjl.je_line_num line_num, gjl.effective_date,
					  trx_types.trx_type_name, trx_types.trx_type_id, trx_types.trx_type_code, gcc.segment1,
					  gcc.segment2, gcc.segment3, gcc.segment4, gcc.segment5, gcc.segment6,
					  gles.legal_entity_id init_le_id, xle.name init_le_name, igl.ledger_id init_ledger_id,
					  igl.name init_ledger_name, glesb.legal_entity_id rec_le_id, xleb.name rec_le_name,
					  iglb.ledger_id rec_ledger_id, iglb.name rec_ledger_name,
					  DECODE (gjl.entered_dr,	'', 2,  gjl.entered_cr, '',  1) val, gjh.period_name,
					  1 source_id_int_1
				FROM gl_je_headers gjh,
					  gl_je_lines gjl,
					  gl_code_combinations gcc,
					  gl_legal_entities_bsvs gles,
					  gl_legal_entities_bsvs glesb,
					  xle_entity_profiles xle,
					  xle_entity_profiles xleb,
					  gl_ledger_config_details glcd,
					  gl_ledgers igl,
					  gl_ledger_config_details glcdb,
					  gl_ledgers iglb,
					  (SELECT trx_type_id, trx_type_code, trx_type_name
						  FROM fun_trx_types_vl
						 WHERE enabled_flag = 'Y' AND trx_type_name = 'Automatic AGIS') trx_types
			  WHERE		gjh.je_source IN ('Manual', 'Spreadsheet', 'Recurring')
					  AND gjh.je_category <> '108'
					  AND gjh.je_header_id = gjl.je_header_id
					  AND gjh.ledger_id = gjl.ledger_id
					  AND gjh.status = 'P'
					  AND gjh.posted_date IS NOT NULL
					  AND gjh.period_name = NVL (p_period_name, gjh.period_name)
					  AND NVL (gjl.attribute5, 'N') = 'N'
					  AND gjl.code_combination_id = gcc.code_combination_id
					  AND gcc.enabled_flag = 'Y'
					  AND TRUNC (SYSDATE) BETWEEN gcc.start_date_active
													  AND NVL (gcc.end_date_active, TRUNC (SYSDATE))
					  AND ( (gcc.segment4 <> '2500')
							 AND (gcc.segment5 <> '0000' AND (igl.ledger_id <> iglb.ledger_id)))
					  AND gcc.segment1 = gles.flex_segment_value
					  AND gles.legal_entity_id = glcd.object_id
					  AND glcd.configuration_id = igl.configuration_id
					  AND igl.ledger_id = NVL (p_ledger_id, igl.ledger_id)
					  AND glcd.object_type_code = 'LEGAL_ENTITY'
					  AND glcd.object_id = xle.legal_entity_id
					  AND gcc.segment5 = glesb.flex_segment_value
					  AND glesb.legal_entity_id = glcdb.object_id
					  AND glcdb.configuration_id = iglb.configuration_id
					  AND glcdb.object_type_code = 'LEGAL_ENTITY'
					  AND glcdb.object_id = xleb.legal_entity_id
					  AND (NVL (gjl.entered_dr, 0) != 0 OR NVL (gjl.entered_cr, 0) != 0)
					  AND 101 = p_module_id)
			ORDER BY init_ledger_id, rec_ledger_id, val;

		CURSOR c_intf_report
		IS
			SELECT (   ftb.batch_number
					  || '|'
					  || fth.trx_number
					  || '|'
					  || ftd.dist_number
					  || '|'
					  || ftb.source
					  || '|'
					  || ftb.initiator_id
					  || '|'
					  || fth.recipient_id
					  || '|'
					  || ftb.initiator_name
					  || '|'
					  || fth.recipient_name
					  || '|'
					  || ftb.from_le_id
					  || '|'
					  || fth.to_le_id
					  || '|'
					  || ftb.from_le_name
					  || '|'
					  || fth.to_le_name
					  || '|'
					  || ftb.from_ledger_id
					  || '|'
					  || fth.to_ledger_id
					  || '|'
					  || ftb.currency_code
					  || '|'
					  || ftb.exchange_rate_type
					  || '|'
					  || ftb.trx_type_name
					  || '|'
					  || ftb.gl_date
					  || '|'
					  || ftb.batch_date
					  || '|'
					  || fth.init_amount_cr
					  || '|'
					  || fth.init_amount_dr
					  || '|'
					  || ftd.amount_cr
					  || '|'
					  || ftd.amount_dr
					  || '|'
					  || ftd.ccid
					  || '|'
					  || (	gcc.segment1
							|| '.'
							|| gcc.segment2
							|| '.'
							|| gcc.segment3
							|| '.'
							|| gcc.segment4
							|| '.'
							|| gcc.segment5
							|| '.'
							|| gcc.segment6)
					  || '|'
					  || ftd.attribute2
					  || '|'
					  || ftd.attribute3
					  || '|'
					  || ftd.attribute5)
						 c_output
			  FROM fun_interface_batches ftb,
					 fun_interface_headers fth,
					 fun_interface_dist_lines ftd,
					 gl_code_combinations gcc
			 WHERE	  ftb.batch_id = fth.batch_id
					 AND fth.trx_id = ftd.trx_id
					 AND ftd.ccid = gcc.code_combination_id
					 AND ftb.from_ledger_id = NVL (p_ledger_id, ftb.from_ledger_id)
					 AND ftb.batch_number = SUBSTRB (ftb.from_le_name, 1, 10) || fnd_global.conc_request_id;

		l_init_id					 NUMBER DEFAULT NULL;
		l_init_name 				 VARCHAR2 (30) DEFAULT NULL;
		l_recp_id					 NUMBER DEFAULT NULL;
		l_recp_name 				 VARCHAR2 (30) DEFAULT NULL;
		l_cnt_trx_num				 NUMBER DEFAULT 0;
		l_init_le_name 			 xle_entity_profiles.name%TYPE DEFAULT NULL;
		l_rec_le_name				 xle_entity_profiles.name%TYPE DEFAULT NULL;
		l_dist_cntr 				 NUMBER DEFAULT 0;
		l_code_combination_id	 gl_code_combinations.code_combination_id%TYPE DEFAULT NULL;
		l_retval 					 VARCHAR2 (200);
		l_line_att5 				 VARCHAR2 (150) DEFAULT NULL;
		l_line_att2 				 VARCHAR2 (150) DEFAULT NULL;
		l_line_att3 				 VARCHAR2 (150) DEFAULT NULL;
		l_dr							 NUMBER DEFAULT 0;
		l_cr							 NUMBER DEFAULT 0;
		l_trx_id 					 NUMBER;
		l_val 						 NUMBER;
		l_date						 gl_period_statuses_v.end_date%TYPE DEFAULT NULL;
		l_user_conversion_type	 gl_daily_conversion_types.user_conversion_type%TYPE DEFAULT NULL;
		e_error_upd 				 EXCEPTION;
	BEGIN
		g_e_error_hand.module_name := 'init_agis_intf';
		init_error_msg (g_e_error_hand.module_name);
		print_line ('entered 2');
		l_init_le_name := NULL;
		l_rec_le_name := NULL;
		l_cnt_trx_num := 0;
		l_dist_cntr := 0;
		l_val := NULL;
		l_date := NULL;
		l_user_conversion_type := NULL;
		v_error_flag := 'N';
		print_line ('entered 3');

		BEGIN
			SELECT g.user_conversion_type
			  INTO l_user_conversion_type
			  FROM fun_system_options s, gl_daily_conversion_types g
			 WHERE s.exchg_rate_type = g.conversion_type AND s.system_option_id = 0;
		EXCEPTION
			WHEN OTHERS
			THEN
				l_user_conversion_type := NULL;
		END;

		FOR r_inter_trx IN c_inter_trx
		LOOP
			print_line ('entered 4' || r_inter_trx.trx_id || '-' || r_inter_trx.transaction_num);

			BEGIN
				SELECT MAX (end_date)
				  INTO l_date
				  FROM gl_period_statuses_v
				 WHERE	  ledger_id = r_inter_trx.init_ledger_id
						 AND closing_status = 'O'
						 AND application_id = 101;

				print_line ('entered 4.2' || l_date);
			EXCEPTION
				WHEN OTHERS
				THEN
					l_date := LAST_DAY (SYSDATE);
			END;

			get_intercompany_info (r_inter_trx.init_le_name, l_init_id, l_init_name);
			print_line ('entered 5-' || l_init_id || '-' || l_init_name);
			get_intercompany_info (r_inter_trx.rec_le_name, l_recp_id, l_recp_name);
			print_line ('entered 5.5-' || l_recp_id || '-' || l_recp_name);

			IF (l_init_id != 1 AND l_recp_id != 1)
			THEN
				print_line ('entered 6' || l_init_le_name || '-' || r_inter_trx.init_le_name);

				IF NVL (l_init_le_name, 'TELE') != r_inter_trx.init_le_name
				THEN
					print_line ('entered 7');
					l_cnt_trx_num := 0;

					BEGIN
						INSERT INTO fun_interface_controls (
																		date_processed,
																		GROUP_ID,
																		request_id,
																		source
																	  )
							  VALUES (
										 NULL,
										 fun_interface_controls_s.NEXTVAL,
										 NULL,
										 'Automation AGIS'
										);
					EXCEPTION
						WHEN OTHERS
						THEN
							v_error_flag := 'Y';
					END;

					print_line ('entered 8');

					BEGIN
						INSERT INTO fun_interface_batches (
																	  source,
																	  GROUP_ID,
																	  batch_id,
																	  batch_number,
																	  initiator_id,
																	  initiator_name,
																	  from_le_id,
																	  from_le_name,
																	  from_ledger_id,
																	  currency_code,
																	  exchange_rate_type,
																	  description,
																	  trx_type_id,
																	  trx_type_code,
																	  trx_type_name,
																	  gl_date,
																	  batch_date,
																	  reject_allowed_flag,
																	  created_by,
																	  creation_date,
																	  last_updated_by,
																	  last_update_date,
																	  last_update_login,
																	  note
																	 )
							  VALUES (
											'Automation AGIS',
											fun_interface_controls_s.CURRVAL,
											fun_trx_batches_s.NEXTVAL,
											(SUBSTRB (r_inter_trx.init_le_name, 1, 10)
											 || fnd_global.conc_request_id),
											l_init_id,
											l_init_name,
											r_inter_trx.init_le_id,
											r_inter_trx.init_le_name,
											r_inter_trx.init_ledger_id,
											r_inter_trx.currency_code,
											l_user_conversion_type,
											NULL,
											r_inter_trx.trx_type_id,
											r_inter_trx.trx_type_code,
											r_inter_trx.trx_type_name,
											TO_DATE (l_date),
											TO_DATE (l_date),
											'Y',
											fnd_global.user_id,
											SYSDATE,
											fnd_global.user_id,
											SYSDATE,
											fnd_global.login_id,
											NULL);
					EXCEPTION
						WHEN OTHERS
						THEN
							v_error_flag := 'Y';
					END;
				END IF;

				print_line ('entered 9' || l_rec_le_name || '-' || r_inter_trx.rec_le_name);
				l_dr := 0;
				l_cr := 0;

				IF ( (NVL (l_init_le_name, 'TELE') = r_inter_trx.init_le_name
						AND NVL (l_rec_le_name, 'TELE') != r_inter_trx.rec_le_name)
					 OR (NVL (l_init_le_name, 'TELE') != r_inter_trx.init_le_name
						  AND NVL (l_rec_le_name, 'TELE') = r_inter_trx.rec_le_name)
					 OR (NVL (l_init_le_name, 'TELE') != r_inter_trx.init_le_name
						  AND NVL (l_rec_le_name, 'TELE') != r_inter_trx.rec_le_name)
					 OR l_val <> r_inter_trx.val)
				THEN
					print_line ('entered 10');
					l_cnt_trx_num := l_cnt_trx_num + 1;

					BEGIN
						get_intf_header_drcr (
													 p_module_id,
                                                     p_period_name,                          -- Ver 1.1
													 r_inter_trx.init_ledger_id,
													 r_inter_trx.init_le_id,
													 r_inter_trx.rec_ledger_id,
													 r_inter_trx.rec_le_id,
													 r_inter_trx.val,
													 l_dr,
													 l_cr
													);


						INSERT INTO fun_interface_headers (
																	  trx_id,
																	  trx_number,
																	  recipient_id,
																	  recipient_name,
																	  to_le_id,
																	  to_le_name,
																	  to_ledger_id,
																	  batch_id,
																	  init_amount_cr,
																	  init_amount_dr,
																	  invoicing_rule_flag,
																	  initiator_instance_flag,
																	  recipient_instance_flag,
																	  created_by,
																	  creation_date,
																	  last_updated_by,
																	  last_update_date,
																	  last_update_login
																	 )
							  VALUES (
										 fun_trx_headers_s.NEXTVAL,
										 l_cnt_trx_num,
										 l_recp_id,
										 l_recp_name,
										 r_inter_trx.rec_le_id,
										 r_inter_trx.rec_le_name,
										 r_inter_trx.rec_ledger_id,
										 fun_trx_batches_s.CURRVAL,
										 r_inter_trx.entered_cr,
										 r_inter_trx.entered_dr,
										 'N',
										 'N',
										 'N',
										 fnd_global.user_id,
										 SYSDATE,
										 fnd_global.user_id,
										 SYSDATE,
										 fnd_global.login_id
										);



						SELECT fun_trx_headers_s.CURRVAL INTO l_trx_id FROM DUAL;

						print_line ('entered 11' || l_dr || '-' || l_cr || l_trx_id);

						UPDATE fun_interface_headers
							SET init_amount_cr = l_cr, init_amount_dr = l_dr
						 WHERE	  to_le_id = r_inter_trx.rec_le_id
								 AND to_ledger_id = r_inter_trx.rec_ledger_id
								 AND trx_id = l_trx_id;
					EXCEPTION
						WHEN OTHERS
						THEN
							v_error_flag := 'Y';
					END;
				END IF;

				IF NVL (l_init_le_name, 'TELE') != r_inter_trx.init_le_name
				THEN
					l_dist_cntr := 0;
					print_line ('entered 12');
				END IF;

				l_dist_cntr := l_dist_cntr + 1;

				BEGIN
					BEGIN
						IF p_module_id = 200
						THEN
							SELECT ai.invoice_num, TO_CHAR (TO_DATE (ai.invoice_date), 'YYYY/MM/DD HH24:Mi:SS'),
									 asp.vendor_name
							  INTO l_line_att2, l_line_att3, l_line_att5
							  FROM ap_invoices_all ai, ap_suppliers asp
							 WHERE	  ai.invoice_num = r_inter_trx.transaction_num
									 AND ai.legal_entity_id = r_inter_trx.init_le_id
									 AND ai.vendor_id = asp.vendor_id
									 AND ai.invoice_id = r_inter_trx.source_id_int_1;

							print_line ('entered 13' || l_line_att5 || l_line_att2 || l_line_att3);
						ELSIF p_module_id = 222
						THEN
							SELECT rct.trx_number, TO_CHAR (TO_DATE (rct.trx_date), 'YYYY/MM/DD HH24:Mi:SS'),
									 arc.customer_name
							  INTO l_line_att2, l_line_att3, l_line_att5
							  FROM ra_customer_trx_all rct, ar_customers arc
							 WHERE	  rct.trx_number = r_inter_trx.transaction_num
									 AND rct.legal_entity_id = r_inter_trx.init_le_id
									 AND rct.bill_to_customer_id = arc.customer_id
									 AND rct.customer_trx_id = r_inter_trx.source_id_int_1;

							print_line ('entered 14' || l_line_att5 || l_line_att2 || l_line_att3);
						ELSIF p_module_id = 101
						THEN
							SELECT gjh.name,
									 TO_CHAR (TO_DATE (gjh.default_effective_date), 'YYYY/MM/DD HH24:Mi:SS'),
									 gjh.description
							  INTO l_line_att2, l_line_att3, l_line_att5
							  FROM gl_je_headers gjh
							 WHERE gjh.je_header_id = r_inter_trx.trx_id
									 AND gjh.ledger_id = r_inter_trx.init_ledger_id;
						END IF;
					EXCEPTION
						WHEN OTHERS
						THEN
							print_line ('entered 15');
							l_line_att5 := NULL;
							l_line_att2 := NULL;
							l_line_att3 := NULL;
					END;


					BEGIN
						INSERT INTO fun_interface_dist_lines (
																		  trx_id,
																		  dist_id,
																		  batch_dist_id,
																		  dist_number,
																		  party_id,
																		  party_type_flag,
																		  dist_type_flag,
																		  amount_cr,
																		  amount_dr,
																		  ccid,
																		  attribute2,
																		  attribute3,
																		  attribute5,
																		  created_by,
																		  creation_date,
																		  last_updated_by,
																		  last_update_date,
																		  last_update_login,
																		  description
																		 )
							  VALUES (
										 fun_trx_headers_s.CURRVAL,
										 fun_dist_lines_s.NEXTVAL,
										 NULL,
										 l_dist_cntr,
										 l_init_id,
										 'I',
										 'L',
										 r_inter_trx.entered_dr,
										 r_inter_trx.entered_cr,
										 r_inter_trx.code_combination_id,
										 l_line_att2,
										 l_line_att3,
										 l_line_att5,
										 fnd_global.user_id,
										 SYSDATE,
										 fnd_global.user_id,
										 SYSDATE,
										 fnd_global.login_id,
										 'Init dist desc'
										);
					EXCEPTION
						WHEN OTHERS
						THEN
							v_error_flag := 'Y';
					END;

					IF p_module_id IN (200, 222)
					THEN
						UPDATE xla_ae_lines
							SET attribute1 = 'Y'
						 WHERE	  ae_header_id = r_inter_trx.trx_id
								 AND ae_line_num = r_inter_trx.line_num
								 AND code_combination_id = r_inter_trx.code_combination_id;

						print_line ('entered 15.5');
					ELSIF p_module_id = 101
					THEN
						UPDATE gl_je_lines
							SET attribute5 = 'Y'
						 WHERE	  je_header_id = r_inter_trx.trx_id
								 AND je_line_num = r_inter_trx.line_num
								 AND code_combination_id = r_inter_trx.code_combination_id;

						print_line ('entered 15.5');
					END IF;

					print_line ('entered 16');

					BEGIN
						SELECT code_combination_id
						  INTO l_code_combination_id
						  FROM gl_code_combinations
						 WHERE	  segment1 = r_inter_trx.segment5
								 AND segment2 = r_inter_trx.segment2
								 AND segment3 = r_inter_trx.segment3
								 AND segment4 = r_inter_trx.segment4
								 AND segment5 = r_inter_trx.segment1
								 AND segment6 = r_inter_trx.segment6;

						print_line ('entered 17' || l_code_combination_id);
					EXCEPTION
						WHEN NO_DATA_FOUND
						THEN
							l_retval :=
								ttec_create_ccid (
										r_inter_trx.segment5
									|| '.'
									|| r_inter_trx.segment2
									|| '.'
									|| r_inter_trx.segment3
									|| '.'
									|| r_inter_trx.segment4
									|| '.'
									|| r_inter_trx.segment1
									|| '.'
									|| r_inter_trx.segment6);

							IF l_retval = 'S'
							THEN
								SELECT code_combination_id
								  INTO l_code_combination_id
								  FROM gl_code_combinations
								 WHERE	  segment1 = r_inter_trx.segment5
										 AND segment2 = r_inter_trx.segment2
										 AND segment3 = r_inter_trx.segment3
										 AND segment4 = r_inter_trx.segment4
										 AND segment5 = r_inter_trx.segment1
										 AND segment6 = r_inter_trx.segment6;
							ELSE
								l_code_combination_id := NULL;
							END IF;
						WHEN OTHERS
						THEN
							l_code_combination_id := NULL;
					END;

					print_line ('entered 18' || l_code_combination_id);

					BEGIN
						INSERT INTO fun_interface_dist_lines (
																		  trx_id,
																		  dist_id,
																		  batch_dist_id,
																		  dist_number,
																		  party_id,
																		  party_type_flag,
																		  dist_type_flag,
																		  amount_cr,
																		  amount_dr,
																		  ccid,
																		  attribute2,
																		  attribute3,
																		  attribute5,
																		  created_by,
																		  creation_date,
																		  last_updated_by,
																		  last_update_date,
																		  last_update_login,
																		  description
																		 )
							  VALUES (
										 fun_trx_headers_s.CURRVAL,
										 fun_dist_lines_s.NEXTVAL,
										 NULL,
										 l_dist_cntr,
										 l_recp_id,
										 'R',
										 'L',
										 r_inter_trx.entered_cr,
										 r_inter_trx.entered_dr,
										 l_code_combination_id,
										 l_line_att2,
										 l_line_att3,
										 l_line_att5,
										 fnd_global.user_id,
										 SYSDATE,
										 fnd_global.user_id,
										 SYSDATE,
										 fnd_global.login_id,
										 'Rec dist desc'
										);

						print_line ('entered 19');
					EXCEPTION
						WHEN OTHERS
						THEN
							v_error_flag := 'Y';
					END;
				EXCEPTION
					WHEN OTHERS
					THEN
						v_error_flag := 'Y';
				END;

				IF v_error_flag = 'Y'
				THEN
					print_line (
							'Error line Information: '
						|| 'Module ID'
						|| '-'
						|| p_module_id
						|| '-'
						|| 'Transaction_id'
						|| '-'
						|| r_inter_trx.trx_id
						|| '-'
						|| 'Line_Num'
						|| '-'
						|| r_inter_trx.line_num
						|| '-'
						|| 'Initiator'
						|| '-'
						|| l_init_name
						|| '-'
						|| 'Receipient'
						|| '-'
						|| l_recp_name);
					ttec_error_logging.process_error (
						application_code	 => g_e_error_hand.application_code,
						interface			 => g_e_error_hand.interface,
						program_name		 => g_e_error_hand.program_name,
						module_name 		 => g_e_error_hand.module_name,
						status				 => g_status_failure,
						ERROR_CODE			 => SQLCODE,
						error_message		 => SQLERRM,
						label1				 => 'Module ID' || '-' || 'Transaction_id' || '-' || 'Line_Num',
						reference1			 =>	p_module_id
													|| '-'
													|| r_inter_trx.trx_id
													|| '-'
													|| r_inter_trx.line_num,
						label2				 => 'Initiator' || '-' || 'Receipient',
						reference2			 => l_init_name || '-' || l_recp_name);
				END IF;

				print_line ('entered 20');
				l_init_le_name := NULL;
				l_rec_le_name := NULL;
				l_val := NULL;
				print_line ('entered 21' || l_init_le_name || '-' || l_rec_le_name);
				l_init_le_name := r_inter_trx.init_le_name;
				l_rec_le_name := r_inter_trx.rec_le_name;
				l_val := r_inter_trx.val;
				print_line ('entered 22' || l_init_le_name || '-' || l_rec_le_name);
			END IF;
		END LOOP;

		IF v_error_flag = 'Y'
		THEN
			ROLLBACK;
			RAISE e_error_upd;
		ELSE
			COMMIT;
			v_rec := NULL;

			SELECT	 'BATCH_NUM'
					 || '|'
					 || 'TRX_NUM'
					 || '|'
					 || 'DIST_NUM'
					 || '|'
					 || 'SOURCE'
					 || '|'
					 || 'INITIATOR_ID'
					 || '|'
					 || 'RECIPIENT_ID'
					 || '|'
					 || 'INITIATOR_NAME'
					 || '|'
					 || 'RECIPIENT_NAME'
					 || '|'
					 || 'FROM_LE_ID'
					 || '|'
					 || 'TO_LE_ID'
					 || '|'
					 || 'FROM_LE_NAME'
					 || '|'
					 || 'TO_LE_NAME'
					 || '|'
					 || 'FROM_LEDGER_ID'
					 || '|'
					 || 'TO_LEDGER_ID'
					 || '|'
					 || 'CURRENCY_CODE'
					 || '|'
					 || 'EXCHANGE_RATE_TYPE'
					 || '|'
					 || 'TRX_TYPE_NAME'
					 || '|'
					 || 'GL_DATE'
					 || '|'
					 || 'BATCH_DATE'
					 || '|'
					 || 'INIT_AMOUNT_CR'
					 || '|'
					 || 'INIT_AMOUNT_DR'
					 || '|'
					 || 'AMOUNT_CR'
					 || '|'
					 || 'AMOUNT_DR'
					 || '|'
					 || 'CCID'
					 || '|'
					 || 'CODE_COMBINATION'
					 || '|'
					 || 'TRX_NUM'
					 || '|'
					 || 'TRX_DATE'
					 || '|'
					 || 'TRX_VC_NAME'
			  INTO v_rec
			  FROM DUAL;

			fnd_file.put_line (fnd_file.output, v_rec);

			BEGIN
				v_rec := NULL;

				FOR r_intf_report IN c_intf_report
				LOOP
					v_rec := r_intf_report.c_output;
					fnd_file.put_line (fnd_file.output, v_rec);
				END LOOP;
			EXCEPTION
				WHEN OTHERS
				THEN
					print_line ('Error in Generating Interface Report' || SQLERRM);
			END;
		END IF;

		print_count (g_success_count, g_error_count, g_e_error_hand.module_name);
	EXCEPTION
		WHEN e_error_upd
		THEN
			RAISE;
		WHEN NO_DATA_FOUND
		THEN
			g_error_count := g_error_count + 1;
			print_count (g_success_count, g_error_count, g_e_error_hand.module_name);
			log_error (
						  'SQLCODE',
						  TO_CHAR (SQLCODE),
						  'Error Message',
						  SUBSTR (SQLERRM, 1, 64)
						 );
			print_line ('Error in module: ' || g_e_error_hand.module_name);
			v_msg := SQLERRM;
			raise_application_error (-20003, 'Exception NO_DATA_FOUND in init_agis_intf ' || v_msg);
			g_e_program_run_status := 1;
		WHEN OTHERS
		THEN
			g_error_count := g_error_count + 1;
			print_count (g_success_count, g_error_count, g_e_error_hand.module_name);
			log_error (
						  'SQLCODE',
						  TO_CHAR (SQLCODE),
						  'Error Message',
						  SUBSTR (SQLERRM, 1, 64)
						 );
			print_line ('Error in module: ' || g_e_error_hand.module_name);
			v_msg := SQLERRM;
			raise_application_error (-20003, 'Exception OTHERS in init_agis_intf ' || v_msg);
			g_e_program_run_status := 1;
	END;

	PROCEDURE initial_main (
									errcode				OUT VARCHAR2,
									errbuff				OUT VARCHAR2,
									p_ledger_id 	IN 	 NUMBER,
									p_module_id 	IN 	 NUMBER,
									p_period_name	IN 	 VARCHAR2
								  )
	IS
	BEGIN
		init_error_msg ('Main');
		init_agis_intf (p_ledger_id, p_module_id, p_period_name);
	END;

	PROCEDURE agis_report_output (
											errcode			OUT VARCHAR2,
											errbuff			OUT VARCHAR2,
											p_start_date		 VARCHAR2,
											p_end_date			 VARCHAR2
										  )
	IS
		CURSOR c_rpt_output
		IS
			SELECT ftb.batch_number, fth.trx_number, ftl.line_number, fdl.dist_number, ftb.initiator_id,
					 hzp.party_name initiator_name, fth.attribute1 inter_comp_invoice, fdl.party_id,
					 fth.recipient_id, hzp1.party_name recipient_name, ftb.from_le_id, xep.name from_le_name,
					 fth.to_le_id, xepb.name to_le_name, ftb.from_ledger_id, gl.name from_ledger_name,
					 fth.to_ledger_id, gl2.name to_ledger_name, ftb.currency_code, ftb.exchange_rate_type,
					 ftb.status batch_status, fth.status transaction_status, ftb.gl_date, ftb.batch_date,
					 ftb.running_total_cr, ftb.running_total_dr, fdl.party_type_flag, fdl.amount_cr,
					 fdl.amount_dr, fdl.ccid,
					 (gcc.segment1 || '.' || gcc.segment2 || '.' || gcc.segment3 || '.' || gcc.segment4 || '.' || gcc.segment5 || gcc.segment6) code_combination,
					 fdl.description, fdl.attribute2 mod_trx_num, fdl.attribute3 mod_trx_date,
					 fdl.attribute5 mod_cust_name
			  FROM fun_trx_batches ftb,
					 fun_trx_headers fth,
					 fun_trx_lines ftl,
					 fun_dist_lines fdl,
					 xle_entity_profiles xep,
					 xle_entity_profiles xepb,
					 gl_ledgers gl,
					 gl_ledgers gl2,
					 gl_code_combinations gcc,
					 hz_parties hzp,
					 hz_parties hzp1
			 WHERE	  ftb.batch_id = fth.batch_id
					 AND fth.trx_id = ftl.trx_id
					 AND ftl.line_id = fdl.line_id
					 AND xep.legal_entity_id = from_le_id
					 AND xepb.legal_entity_id = to_le_id
					 AND gl.ledger_id = from_ledger_id
					 AND gl2.ledger_id = to_ledger_id
					 AND fdl.ccid = gcc.code_combination_id
					 AND gcc.enabled_flag = 'Y'
					 AND ftb.initiator_id = hzp.party_id
					 AND fth.recipient_id = hzp1.party_id
					 AND TO_DATE (ftb.creation_date) BETWEEN TO_DATE (p_start_date, 'YYYY/MM/DD HH24:MI:SS')
																	 AND TO_DATE (p_end_date, 'YYYY/MM/DD HH24:MI:SS');
	BEGIN
		get_file_open ('AGIS_OUTPUT.csv');
		v_rec := NULL;
		v_rec :=
				'BATCH_NUMBER'
			|| '|'
			|| 'TRX_NUMBER'
			|| '|'
			|| 'LINE_NUMBER'
			|| '|'
			|| 'DIST_NUMBER'
			|| '|'
			|| 'INTER_COMP_INVOICE'
			|| '|'
			|| 'INITIATOR_NAME'
			|| '|'
			|| 'FROM_LE_NAME'
			|| '|'
			|| 'FROM_LEDGER_NAME'
			|| '-'
			|| 'RECIPIENT_NAME'
			|| '|'
			|| 'TO_LE_NAME'
			|| '|'
			|| 'TO_LEDGER_NAME'
			|| '|'
			|| 'CURRENCY_CODE'
			|| '|'
			|| 'EXCHANGE_RATE_TYPE'
			|| '|'
			|| 'GL_DATE'
			|| '|'
			|| 'BATCH_DATE'
			|| '|'
			|| 'RUNNING_TOTAL_CR'
			|| '|'
			|| 'RUNNING_TOTAL_DR'
			|| '|'
			|| 'PARTY_TYPE_FLAG'
			|| '-'
			|| 'AMOUNT_CR'
			|| '|'
			|| 'AMOUNT_DR'
			|| '|'
			|| 'CODE_COMBINATION'
			|| '|'
			|| 'MOD_TRX_NUM'
			|| '|'
			|| 'MOD_TRX_DATE'
			|| '|'
			|| 'MOD_CUST_NAME';
		fnd_file.put_line (fnd_file.output, v_rec);

		FOR r_rpt_output IN c_rpt_output
		LOOP
			v_rec := NULL;
			v_rec :=
					r_rpt_output.batch_number
				|| '|'
				|| r_rpt_output.trx_number
				|| '|'
				|| r_rpt_output.line_number
				|| '|'
				|| r_rpt_output.dist_number
				|| '|'
				|| r_rpt_output.inter_comp_invoice
				|| '|'
				|| r_rpt_output.initiator_name
				|| '|'
				|| r_rpt_output.from_le_name
				|| '|'
				|| r_rpt_output.from_ledger_name
				|| '-'
				|| r_rpt_output.recipient_name
				|| '|'
				|| r_rpt_output.to_le_name
				|| '|'
				|| r_rpt_output.to_ledger_name
				|| '|'
				|| r_rpt_output.currency_code
				|| '|'
				|| r_rpt_output.exchange_rate_type
				|| '|'
				|| r_rpt_output.gl_date
				|| '|'
				|| r_rpt_output.batch_date
				|| '|'
				|| r_rpt_output.running_total_cr
				|| '|'
				|| r_rpt_output.running_total_dr
				|| '|'
				|| r_rpt_output.party_type_flag
				|| '-'
				|| r_rpt_output.amount_cr
				|| '|'
				|| r_rpt_output.amount_dr
				|| '|'
				|| r_rpt_output.code_combination
				|| '|'
				|| r_rpt_output.mod_trx_num
				|| '|'
				|| r_rpt_output.mod_trx_date
				|| '|'
				|| r_rpt_output.mod_cust_name;
			fnd_file.put_line (fnd_file.output, v_rec);
		END LOOP;
	EXCEPTION
		WHEN NO_DATA_FOUND
		THEN
			log_error (
						  'SQLCODE',
						  TO_CHAR (SQLCODE),
						  'Error Message',
						  SUBSTR (SQLERRM, 1, 64)
						 );
			v_msg := SQLERRM;
			raise_application_error (-20003, 'Exception NO_DATA_FOUND in agis_report_output ' || v_msg);
		WHEN OTHERS
		THEN
			log_error (
						  'SQLCODE',
						  TO_CHAR (SQLCODE),
						  'Error Message',
						  SUBSTR (SQLERRM, 1, 64)
						 );

			v_msg := SQLERRM;
			raise_application_error (-20003, 'Exception OTHERS in agis_report_output ' || v_msg);
	END agis_report_output;
END ttec_agis_interface;
/
show errors;
/